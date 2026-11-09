#!/usr/bin/env python3
"""Build the two Core ML models behind the meal-photo estimate.

    python tools/meal_estimate/convert.py --plate plate.pt --plate-dir <dir> --dish-dir <dir>

--plate is the checkpoint from train_plate.py. Each directory holds that repo's config.json and model.safetensors, and
is downloaded at the pinned revision if omitted.
Needs: torch torchvision transformers coremltools safetensors huggingface_hub.

With torch newer than coremltools supports, its int cast fails on one-element arrays: in its torch ops.py, _cast
has to take np.asarray(x.val).reshape(-1)[0] rather than x.val.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import json

import coremltools as ct
import numpy as np
import torch
from coremltools.optimize.coreml import OpPalettizerConfig, OptimizationConfig, palettize_weights

import network

PLATE_REPO = ("google/siglip2-base-patch16-384", "f775b65a79762255128c981547af89addcfe0f88")
DISH_REPO = ("shalev396/foodvision-big", "3b889d4a42f86ff64087d3a4354c0e5a330c208f")
FILES = ["config.json", "model.safetensors"]   # data only: no code from either repo is fetched or run


def fetch(repo: tuple[str, str], local: Path | None) -> Path:
    if local:
        return local
    from huggingface_hub import snapshot_download
    return Path(snapshot_download(repo[0], revision=repo[1], allow_patterns=FILES))


def to_coreml(net: torch.nn.Module, size: int, **kwargs) -> ct.models.MLModel:
    with torch.no_grad():
        traced = torch.jit.trace(net, torch.rand(1, 3, size, size), strict=False)
    return ct.convert(
        traced,
        inputs=[ct.ImageType(name="image", shape=(1, 3, size, size), scale=1 / 255.0,
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
    ap.add_argument("--plate-dir", type=Path)
    ap.add_argument("--plate", type=Path, default=Path("plate.pt"))
    ap.add_argument("--dish-dir", type=Path)
    ap.add_argument("--out", type=Path, default=root / "k-cal/ML")
    ap.add_argument("--plate-bits", type=int, default=8, help="palettize to this many bits, 0 = off. 6 costs a point")
    ap.add_argument("--dish-bits", type=int, default=8, help="palettize to this many bits, 0 = off")
    ap.add_argument("--plate-only", action="store_true", help="leave the dish classifier as it is")
    args = ap.parse_args()

    # 32-bit outputs: at 16 bits the Simulator hands back zeros for the ingredients, though Macs read them correctly.
    plate, ingredients = network.load_plate(args.plate, fetch(PLATE_REPO, args.plate_dir))
    save(to_coreml(plate.eval(), network.PLATE_SIZE, outputs=[ct.TensorType(name="logTotals", dtype=np.float32), ct.TensorType(name="ingredients", dtype=np.float32)]),
         args.out / "MealPlate.mlpackage", args.plate_bits,
         "Estimates a meal's calories and macros from a photo. Outputs: log1p of kcal, carbs, protein, fat, and a score for each ingredient.",
         "SigLIP 2 by Google, fine-tuned for k-cal on the January Food Benchmark and Nutrition5k", "Apache-2.0; CC BY 4.0", PLATE_REPO[1])
    (root / "k-cal/Data/plate_ingredients.json").write_text(json.dumps(ingredients))

    if args.plate_only:
        return
    dish, classes = network.load_dish(fetch(DISH_REPO, args.dish_dir))
    save(to_coreml(dish, network.DISH_SIZE, classifier_config=ct.ClassifierConfig(classes)),
         args.out / "DishClassifier.mlpackage", args.dish_bits,
         "Names the dish in a photo out of the 101 Food-101 categories.",
         "Shalev Ben Moshe (shalev396/foodvision-big)", "MIT", DISH_REPO[1])


if __name__ == "__main__":
    main()
