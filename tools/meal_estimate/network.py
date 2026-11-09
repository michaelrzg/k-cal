"""The two networks behind the meal-photo estimate, as plain PyTorch modules.

- PlateNet: SigLIP 2's image encoder (google/siglip2-base-patch16-384, Apache-2.0), fine-tuned by train_plate.py, with
  heads for a meal's calories and macros and for which ingredients are in it.
- DishNet: https://huggingface.co/shalev396/foodvision-big, torchvision's EfficientNet-B2 on Food-101.

Written for this repo so that converting them never executes code downloaded with the weights: each repo's
config.json and model.safetensors are the only upstream files read, and both are data. Module names follow
the weight files, so the loads are strict.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
import torch
from safetensors.torch import load_file
from torch import nn
from torchvision.models import efficientnet_b2
from transformers import SiglipVisionConfig, SiglipVisionModel

MEAN = (0.485, 0.456, 0.406)
STD = (0.229, 0.224, 0.225)
PLATE_SIZE = 384
PLATE_FEATURES = 1536
DISH_SIZE = 288


class Normalize(nn.Module):
    def __init__(self):
        super().__init__()
        self.register_buffer("mean", torch.tensor(MEAN).view(1, 3, 1, 1), persistent=False)
        self.register_buffer("std", torch.tensor(STD).view(1, 3, 1, 1), persistent=False)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return (x - self.mean) / self.std


class AttentionPool(nn.Module):
    """SigLIP's attention pooling in plain operations.

    Core ML silently mistranslates nn.MultiheadAttention: the model converts and runs, but this layer's output
    only matches at a cosine of 0.80, which cost three points of accuracy. Written out, it matches at 0.99995.
    """

    def __init__(self, head: nn.Module):
        super().__init__()
        attention = head.attention
        self.heads, self.dim = attention.num_heads, attention.embed_dim
        self.probe, self.out, self.norm, self.mlp = head.probe, attention.out_proj, head.layernorm, head.mlp

        def linear(weight: torch.Tensor, bias: torch.Tensor) -> nn.Linear:
            layer = nn.Linear(self.dim, self.dim)
            layer.weight.data, layer.bias.data = weight.clone(), bias.clone()
            return layer

        weights, biases = attention.in_proj_weight.chunk(3, 0), attention.in_proj_bias.chunk(3, 0)
        self.query, self.key, self.value = (linear(w, b) for w, b in zip(weights, biases))

    def forward(self, tokens: torch.Tensor) -> torch.Tensor:
        batch, count, _ = tokens.shape
        size = self.dim // self.heads

        def split(x: torch.Tensor, length: int) -> torch.Tensor:
            return x.reshape(batch, length, self.heads, size).transpose(1, 2)

        query = split(self.query(self.probe.expand(batch, -1, -1)), 1)
        key, value = split(self.key(tokens), count), split(self.value(tokens), count)
        weights = torch.softmax(torch.matmul(query, key.transpose(-1, -2)) / math.sqrt(size), -1)
        pooled = self.out(torch.matmul(weights, value).transpose(1, 2).reshape(batch, 1, self.dim))
        return (pooled + self.mlp(self.norm(pooled)))[:, 0]


class Plate(nn.Module):
    """The model as trained: the encoder with heads for macros, other macros, and which ingredients are there."""

    def __init__(self, vision: nn.Module, ingredients: int, typical: np.ndarray):
        super().__init__()
        self.vision = vision
        self.norm = nn.LayerNorm(PLATE_FEATURES)
        self.drop = nn.Dropout(0.3)
        self.macro = self.macro_head()
        self.other = self.macro_head()
        self.ingredients = nn.Linear(PLATE_FEATURES, ingredients)
        nn.init.zeros_(self.macro[-1].weight)
        self.macro[-1].bias.data = torch.tensor(typical, dtype=torch.float32)

    @staticmethod
    def macro_head() -> nn.Sequential:
        return nn.Sequential(nn.Linear(PLATE_FEATURES, 256), nn.GELU(), nn.Dropout(0.2), nn.Linear(256, 4))

    def encode(self, x: torch.Tensor) -> torch.Tensor:
        out = self.vision(pixel_values=(x - 0.5) / 0.5)
        return self.drop(self.norm(torch.cat([out.pooler_output, out.last_hidden_state.mean(1)], 1)))

    def heads(self, features: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        return self.macro(features), self.other(features), self.ingredients(features)

    def macros(self, x: torch.Tensor) -> torch.Tensor:
        return self.macro(self.encode(x))


class PlateNet(nn.Module):
    """(1, 3, 384, 384) image in [0, 1] -> (1, 4) log1p totals (kcal, carbs g, protein g, fat g), and a score for each
    ingredient, whose sigmoid is its chance. The photo and its mirror image are averaged."""

    def __init__(self, plate: Plate):
        super().__init__()
        plate.vision.head = AttentionPool(plate.vision.head)
        self.plate = plate.eval()

    def forward(self, x: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        features = self.plate.encode(torch.cat([x, x.flip(-1)], 0))
        return self.plate.macro(features).mean(0, keepdim=True), self.plate.ingredients(features).mean(0, keepdim=True)


class DishNet(nn.Module):
    """(1, 3, 288, 288) image in [0, 1] -> (1, 101) class probabilities."""

    def __init__(self, classes: int):
        super().__init__()
        self.normalize = Normalize()
        self.net = efficientnet_b2(weights=None)
        self.net.classifier = nn.Sequential(nn.Dropout(0.3), nn.Linear(1408, classes))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return torch.softmax(self.net(self.normalize(x)), dim=1)


def load_plate(checkpoint: Path, encoder_dir: Path) -> tuple[PlateNet, list[str]]:
    """Weights from train_plate.py. The encoder's config comes from its repo, and its weights all from the checkpoint."""
    saved = torch.load(checkpoint, map_location="cpu", weights_only=True)
    config = json.loads((encoder_dir / "config.json").read_text())
    vision = SiglipVisionModel(SiglipVisionConfig(**config["vision_config"]))
    plate = Plate(vision, len(saved["vocabulary"]), np.zeros(4))
    plate.load_state_dict({k: v.float() for k, v in saved["state"].items()}, strict=True)
    return PlateNet(plate), saved["vocabulary"]


def load_dish(model_dir: Path) -> tuple[DishNet, list[str]]:
    classes = json.loads((model_dir / "config.json").read_text())["class_names"]
    net = DishNet(len(classes))
    state = load_file(model_dir / "model.safetensors")
    net.net.load_state_dict({k.removeprefix("backbone."): v for k, v in state.items()}, strict=True)
    return net.eval(), classes
