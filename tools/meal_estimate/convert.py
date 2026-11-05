#!/usr/bin/env python3
"""Build the two Core ML models behind the meal-photo estimate.

    python tools/meal_estimate/convert.py --portion-dir <dir> --dish-dir <dir>

Each directory holds that repo's config.json and model.safetensors, and is downloaded at the pinned
revision if omitted. Needs: torch torchvision transformers coremltools scikit-learn safetensors huggingface_hub.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import coremltools as ct
import torch
from coremltools.optimize.coreml import OpPalettizerConfig, OptimizationConfig, palettize_weights

import network

PORTION_REPO = ("shalev396/calorie-lens", "f0d34a638b6b572e2df601067881b56fe6848c79")
DISH_REPO = ("shalev396/foodvision-big", "3b889d4a42f86ff64087d3a4354c0e5a330c208f")
FILES = ["config.json", "model.safetensors"]   # data only: no code from either repo is fetched or run


def fetch(repo: tuple[str, str], local: Path | None) -> Path:
    if local:
        return local
    from huggingface_hub import snapshot_download
    return Path(snapshot_download(repo[0], revision=repo[1], allow_patterns=FILES))


def to_coreml(net: torch.nn.Module, height: int, width: int, **kwargs) -> ct.models.MLModel:
    with torch.no_grad():
        traced = torch.jit.trace(net, torch.rand(1, 3, height, width), strict=False)
    return ct.convert(
        traced,
        inputs=[ct.ImageType(name="image", shape=(1, 3, height, width), scale=1 / 255.0,
                             color_layout=ct.colorlayout.RGB)],
        minimum_deployment_target=ct.target.iOS18,
        compute_precision=ct.precision.FLOAT16,
        convert_to="mlprogram",
        **kwargs,
    )


def save(model: ct.models.MLModel, path: Path, bits: int, description: str, author: str, licence: str, rev: str) -> None:
    if bits:
        model = palettize_weights(model, OptimizationConfig(OpPalettizerConfig(mode="kmeans", nbits=bits)))
    model.short_description, model.author, model.license, model.version = description, author, licence, rev[:7]
    path.parent.mkdir(parents=True, exist_ok=True)
    model.save(str(path))
    print(f"{path}: {sum(f.stat().st_size for f in path.rglob('*') if f.is_file()) / 1e6:.1f} MB")


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--portion-dir", type=Path)
    ap.add_argument("--dish-dir", type=Path)
    ap.add_argument("--out", type=Path, default=root / "k-cal/ML")
    ap.add_argument("--portion-bits", type=int, default=6, help="palettize to this many bits, 0 = off")
    ap.add_argument("--dish-bits", type=int, default=8, help="palettize to this many bits, 0 = off")
    args = ap.parse_args()

    portion = network.load_portion(fetch(PORTION_REPO, args.portion_dir))
    portion.freeze_position_embedding()
    height, width = network.PORTION_SIZE
    save(to_coreml(portion, height, width, outputs=[ct.TensorType(name="logTotals")]),
         args.out / "MealPortion.mlpackage", args.portion_bits,
         "Estimates a meal's calories, weight and macros from a photo. Output: log1p of kcal, grams, fat, carbs, protein.",
         "Shalev Ben Moshe (shalev396/calorie-lens)", "MIT; DINOv2 weights Apache-2.0", PORTION_REPO[1])

    dish, classes = network.load_dish(fetch(DISH_REPO, args.dish_dir))
    save(to_coreml(dish, network.DISH_SIZE, network.DISH_SIZE, classifier_config=ct.ClassifierConfig(classes)),
         args.out / "DishClassifier.mlpackage", args.dish_bits,
         "Names the dish in a photo out of the 101 Food-101 categories.",
         "Shalev Ben Moshe (shalev396/foodvision-big)", "MIT", DISH_REPO[1])


if __name__ == "__main__":
    main()
