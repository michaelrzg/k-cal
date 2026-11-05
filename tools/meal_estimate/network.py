"""The two networks behind the meal-photo estimate, as plain PyTorch modules.

Written for this repo so that converting them never executes code downloaded with the weights: each
repo's config.json and model.safetensors are the only upstream files read, and both are data. Module
names follow the weight files, so the loads are strict.

- PortionNet: stage 1 of https://huggingface.co/shalev396/calorie-lens up to its totals head. The rest of
  that model (ingredient queries, per-ingredient grams) is left out: on photos unlike its cafeteria
  training set the ingredient list is unreliable, while the totals head holds up.
- DishNet: https://huggingface.co/shalev396/foodvision-big, torchvision's EfficientNet-B2 on Food-101.
"""
from __future__ import annotations

import json
from pathlib import Path

import torch
from safetensors.torch import load_file
from torch import nn
from torchvision.models import efficientnet_b2
from transformers import AutoConfig, AutoModel

MEAN = (0.485, 0.456, 0.406)
STD = (0.229, 0.224, 0.225)
PORTION_SIZE = (378, 504)    # (H, W): 27 x 36 patches of 14 px
DISH_SIZE = 288


class Normalize(nn.Module):
    def __init__(self):
        super().__init__()
        self.register_buffer("mean", torch.tensor(MEAN).view(1, 3, 1, 1), persistent=False)
        self.register_buffer("std", torch.tensor(STD).view(1, 3, 1, 1), persistent=False)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return (x - self.mean) / self.std


class PortionNet(nn.Module):
    """(1, 3, H, W) image in [0, 1] -> (1, 5) log1p totals (kcal, mass g, fat g, carb g, protein g).

    The photo and its mirror image are averaged, as upstream does.
    """

    def __init__(self, vit_config: dict):
        super().__init__()
        self.normalize = Normalize()
        self.vit = AutoModel.from_config(AutoConfig.for_model(**vit_config))
        hidden = self.vit.config.hidden_size
        self.first_patch = 1 + self.vit.config.num_register_tokens
        self.totals_head = nn.Sequential(nn.LayerNorm(2 * hidden), nn.Linear(2 * hidden, 512), nn.GELU(), nn.Linear(512, 5))

    def freeze_position_embedding(self) -> None:
        """Replace DINOv2's bicubic resize, which Core ML has no op for, with its result at the fixed input size."""
        embeddings = self.vit.embeddings
        with torch.no_grad():
            height, width = PORTION_SIZE
            patch = self.vit.config.patch_size
            tokens = torch.zeros(1, 1 + (height // patch) * (width // patch), self.vit.config.hidden_size)
            frozen = embeddings.interpolate_pos_encoding(tokens, height, width).detach().clone()
        self.register_buffer("frozen_pos", frozen, persistent=False)
        embeddings.interpolate_pos_encoding = lambda *_: self.frozen_pos

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        hidden = self.vit(pixel_values=self.normalize(torch.cat([x, x.flip(-1)], dim=0))).last_hidden_state
        pooled = torch.cat([hidden[:, 0], hidden[:, self.first_patch:].mean(1)], dim=1)
        return self.totals_head(pooled).mean(0, keepdim=True)


class DishNet(nn.Module):
    """(1, 3, 288, 288) image in [0, 1] -> (1, 101) class probabilities."""

    def __init__(self, classes: int):
        super().__init__()
        self.normalize = Normalize()
        self.net = efficientnet_b2(weights=None)
        self.net.classifier = nn.Sequential(nn.Dropout(0.3), nn.Linear(1408, classes))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return torch.softmax(self.net(self.normalize(x)), dim=1)


def load_portion(model_dir: Path) -> PortionNet:
    config = json.loads((model_dir / "config.json").read_text())
    net = PortionNet(config["backbone_config"])
    state = {k.removeprefix("backbone."): v for k, v in load_file(model_dir / "model.safetensors").items()
             if k.startswith(("backbone.vit.", "totals_head."))}
    net.load_state_dict(state, strict=True)
    return net.eval()


def load_dish(model_dir: Path) -> tuple[DishNet, list[str]]:
    classes = json.loads((model_dir / "config.json").read_text())["class_names"]
    net = DishNet(len(classes))
    state = load_file(model_dir / "model.safetensors")
    net.net.load_state_dict({k.removeprefix("backbone."): v for k, v in state.items()}, strict=True)
    return net.eval(), classes
