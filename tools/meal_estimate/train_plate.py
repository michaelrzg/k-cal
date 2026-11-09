#!/usr/bin/env python3
"""Train the plate model: SigLIP 2 fine-tuned on real phone photos, with a head for macros and one for ingredients.

    python tools/meal_estimate/train_plate.py --jfb <dir> --nutrition5k <dir> --fold 0     # one held-out score
    python tools/meal_estimate/train_plate.py --jfb <dir> --nutrition5k <dir> --out plate.pt   # the model to ship

Data, both CC BY 4.0:
- January Food Benchmark, github.com/January-ai/food-scan-benchmarks: 1,000 phone photos with checked nutrition. This
  is what the model is scored on and what it answers for. --jfb holds food_scan_bench_v1.csv and fsb_images/.
- Nutrition5k overhead scans, as huggingface.co/datasets/shalev396/calorie-lens-data: weighed plates. --nutrition5k holds
  dishes.parquet and overhead/.

Each batch is half of each, but the two have separate macro heads. A shared head is what doesn't work: cafeteria plates
pulled the JFB error from 31% to 35%. Sharing only the encoder lets weighed plates teach it about portions, and took the
hardest fold from 35.6% to 32.6%. Fine-tuning on JFB alone overfits, and scored no better than a linear head.

The ingredient head is there to steady the encoder, and also names meals on phones without Apple Intelligence.
"""
from __future__ import annotations

import argparse
import ast
import glob
import io
import json
import math
import time
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd
import pyarrow.parquet as pq
import torch
import torch.nn.functional as F
from PIL import Image, ImageOps
from sklearn.model_selection import KFold
from torch import nn
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms as T
from transformers import AutoModel

import network

ENCODER = "google/siglip2-base-patch16-384"
TARGETS = ["total_calories", "total_carbs", "total_protein", "total_fat"]
SIZE = network.PLATE_SIZE
BLOCKS = 3             # of the encoder's 12, counting from the end
EPOCHS = 16
HALF_BATCH = 6
MINIMUM_INGREDIENT_PHOTOS = 3

AUGMENT = T.Compose([
    T.RandomResizedCrop(SIZE, scale=(0.65, 1), ratio=(0.8, 1.25), interpolation=T.InterpolationMode.BICUBIC),
    T.RandomHorizontalFlip(), T.RandomRotation(12), T.ColorJitter(0.15, 0.15, 0.15, 0.03), T.ToTensor(),
])
PLAIN = T.Compose([T.Resize((SIZE, SIZE), interpolation=T.InterpolationMode.BICUBIC), T.ToTensor()])


def ingredients(cell: str) -> list[dict]:
    try:
        value = ast.literal_eval(cell)
        return ast.literal_eval(value) if isinstance(value, str) else value
    except (ValueError, SyntaxError):
        return []


class Photos(Dataset):
    def __init__(self, folder: Path, names: list[str], totals: np.ndarray, present: np.ndarray, transform):
        self.folder, self.names, self.totals, self.present, self.transform = folder, names, totals, present, transform

    def __len__(self) -> int:
        return len(self.names)

    def __getitem__(self, index: int):
        image = ImageOps.exif_transpose(Image.open(self.folder / self.names[index])).convert("RGB")
        return self.transform(image), torch.tensor(self.totals[index], dtype=torch.float32), torch.tensor(self.present[index])


class WeighedPlates(Dataset):
    """A fresh random plate each time, so an epoch's worth is the same length as the JFB photos."""

    def __init__(self, plates: list[tuple[bytes, np.ndarray]], length: int):
        self.plates, self.length = plates, length

    def __len__(self) -> int:
        return self.length

    def __getitem__(self, _: int):
        image, totals = self.plates[np.random.randint(len(self.plates))]
        return AUGMENT(Image.open(io.BytesIO(image)).convert("RGB")), torch.tensor(totals, dtype=torch.float32)


def weighed_plates(root: Path) -> list[tuple[bytes, np.ndarray]]:
    dishes = pd.read_parquet(root / "dishes.parquet").set_index("dish_id")
    plates = []
    for shard in sorted(glob.glob(str(root / "overhead/train-*.parquet"))):
        for row in pq.read_table(shard, columns=["dish_id", "image"]).to_pylist():
            dish = dishes.loc[row["dish_id"]]
            if dish.split != "test" and dish.kcal > 0:
                plates.append((row["image"]["bytes"], np.log1p([dish.kcal, dish.carb, dish.protein, dish.fat])))
    return plates


def report(predicted: np.ndarray, truth: np.ndarray) -> str:
    """JFB's own macro wMAPE, so the result compares with its published table."""
    wmape = (np.abs(predicted - truth).sum(1) / truth.sum(1)).mean() * 100
    calories = np.abs(predicted[:, 0] - truth[:, 0])
    return f"macro wMAPE {wmape:.1f}%, calories off by {calories.mean():.0f} kcal, {(calories / truth[:, 0] < 0.25).mean() * 100:.0f}% within 25%"


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--jfb", type=Path, required=True)
    ap.add_argument("--nutrition5k", type=Path, required=True)
    ap.add_argument("--fold", type=int, help="0 to 4: hold this fifth of JFB out and score it")
    ap.add_argument("--out", type=Path, default=Path("plate.pt"))
    ap.add_argument("--device", default="mps")
    args = ap.parse_args()
    torch.manual_seed(0)

    table = pd.read_csv(args.jfb / "food_scan_bench_v1.csv")
    table["ingredients"] = table.ingredients_list.map(ingredients)
    totals = np.log1p(table[TARGETS].to_numpy())
    every = np.arange(len(table))
    train, test = (every, every[:0]) if args.fold is None else list(KFold(5, shuffle=True, random_state=0).split(every))[args.fold]

    seen = Counter(item["name"].lower() for row in train for item in table.ingredients[row])
    vocabulary = [name for name, count in seen.most_common() if count >= MINIMUM_INGREDIENT_PHOTOS]
    index = {name: i for i, name in enumerate(vocabulary)}
    present = np.zeros((len(table), len(vocabulary)), np.float32)
    for row, items in enumerate(table.ingredients):
        for item in items:
            if item["name"].lower() in index:
                present[row, index[item["name"].lower()]] = 1

    folder = args.jfb / "fsb_images"
    names = table.image_filename.tolist()
    subset = lambda rows, transform: Photos(folder, [names[r] for r in rows], totals[rows], present[rows], transform)
    photos = DataLoader(subset(train, AUGMENT), batch_size=HALF_BATCH, shuffle=True, drop_last=True)
    plates = DataLoader(WeighedPlates(weighed_plates(args.nutrition5k), len(train)), batch_size=HALF_BATCH, drop_last=True)

    vision = AutoModel.from_pretrained(ENCODER, dtype=torch.float32).vision_model
    net = network.Plate(vision, len(vocabulary), totals[train].mean(0)).to(args.device)
    for parameter in vision.parameters():
        parameter.requires_grad = False
    for module in [*vision.encoder.layers[-BLOCKS:], vision.head, vision.post_layernorm]:
        for parameter in module.parameters():
            parameter.requires_grad = True
    encoder = [p for p in vision.parameters() if p.requires_grad]
    heads = [p for name, p in net.named_parameters() if not name.startswith("vision.")]
    optimizer = torch.optim.AdamW([{"params": encoder, "lr": 2e-5}, {"params": heads, "lr": 1e-3}], weight_decay=0.05)
    steps = EPOCHS * len(photos)
    schedule = torch.optim.lr_scheduler.LambdaLR(optimizer, lambda s: min(1, (s + 1) / 50) * (0.5 + 0.5 * math.cos(math.pi * s / steps)))
    share = present[train].mean(0).clip(1e-4)
    rarity = torch.tensor(np.clip((1 - share) / share, 1, 30), dtype=torch.float32, device=args.device)

    start = time.time()
    for epoch in range(EPOCHS):
        net.train()
        for (photo, photo_totals, photo_present), (plate, plate_totals) in zip(photos, plates):
            images = torch.cat([photo, plate]).to(args.device)
            macros, other, present_logits = net.heads(net.encode(images))
            loss = (macros[:HALF_BATCH] - photo_totals.to(args.device)).abs().mean() \
                + 0.5 * (other[HALF_BATCH:] - plate_totals.to(args.device)).abs().mean() \
                + 0.3 * F.binary_cross_entropy_with_logits(present_logits[:HALF_BATCH], photo_present.to(args.device), pos_weight=rarity)
            optimizer.zero_grad()
            loss.backward()
            nn.utils.clip_grad_norm_(encoder, 1.0)
            optimizer.step()
            schedule.step()
        print(f"epoch {epoch + 1}/{EPOCHS}, {time.time() - start:.0f} s", flush=True)

    torch.save({"state": {k: v.cpu().half() for k, v in net.state_dict().items()}, "vocabulary": vocabulary}, args.out)
    if len(test):
        net.eval()
        predicted = []
        with torch.no_grad():
            for images, _, _ in DataLoader(subset(test, PLAIN), batch_size=16):
                images = images.to(args.device)
                predicted.append(((net.macros(images) + net.macros(images.flip(-1))) / 2).cpu().numpy())
        print(f"fold {args.fold}:", report(np.expm1(np.concatenate(predicted)), np.expm1(totals[test])))


if __name__ == "__main__":
    main()
