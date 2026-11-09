#!/usr/bin/env python3
"""Build the on-device food database from public bulk downloads.

    python tools/food_database/build.py --data <dir> --out k-cal/Data/foods.sqlite [--open-food-facts]

<dir> holds the extracted USDA FoodData Central CSV folders (x_branded, x_foundation, x_sr, x_survey), the
Canadian Nutrient File CSVs (x_cnf), en.openfoodfacts.org.products.csv.gz as off.csv.gz, and NYC Open Data's
DOHMH MenuStat (Historical) CSV as menustat.csv. All are public downloads needing no key. Foundation releases sometimes omit food.csv: use the latest one that has it.
All values are stored per serving, multiplied by 10, as integers.
"""
from __future__ import annotations

import argparse
import collections
import csv
import gzip
import re
import sqlite3
import sys
import unicodedata
from pathlib import Path

csv.field_size_limit(sys.maxsize)

USDA, OPEN_FOOD_FACTS, HEALTH_CANADA, RESTAURANT = 1, 2, 3, 4
DATA_DATE_MARGIN = 2 * 24 * 60 * 60
LARGEST_RESTAURANT_ITEM = 5000   # past this it's a catering platter, not something one person logs
MINIMUM_WORD_FREQUENCY = 3     # rarer words are mostly typos, which must not count as correct spellings
# Survey files key food_nutrient by nutrient number, the others by nutrient id.
NUTRIENTS = {"1008": 0, "208": 0, "1003": 1, "203": 1, "1005": 2, "205": 2, "1004": 3, "204": 3,
             "1093": 4, "307": 4, "2000": 5, "269": 5, "1079": 6, "291": 6}
ATWATER = {"2047": 0, "957": 0, "2048": 0, "958": 0}   # only used when plain energy is missing


def normalized(text: str) -> str:
    """What gets indexed. FoodSearchText.normalized in the app must do exactly the same to a query."""
    folded = "".join(c for c in unicodedata.normalize("NFKD", text) if not unicodedata.combining(c))
    return re.sub(r"['\u2019`]", "", folded.lower()).replace("&", " and ")


def words(text: str) -> list[str]:
    return re.findall(r"[^\W_]+", normalized(text))


def aliases(name: str, brand: str) -> str:
    """Joined spellings the tokenizer would otherwise split: Chick-fil-A as chickfila, Dr Pepper as drpepper."""
    found = set()
    brand_words = words(brand)
    if len(brand_words) > 1:
        found.add("".join(brand_words))
        found.add("".join(w for w in brand_words if w != "and"))
    for compound in re.findall(r"[^\W_]+(?:-[^\W_]+)+", normalized(name)):
        found.add(compound.replace("-", ""))
    return " ".join(sorted(found))


def readable(text: str) -> str:
    text = " ".join(text.split())
    return text.title() if text.isupper() else text


def canonical(raw: str) -> int | None:
    digits = re.sub(r"\D", "", raw)
    if not 8 <= len(digits) <= 14:
        return None
    return int(digits) or None


def read(path: Path, encoding: str = "utf-8"):
    with open(path, newline="", encoding=encoding, errors="replace") as handle:
        yield from csv.DictReader(handle)


def only(folder: Path, name: str) -> Path:
    return next(folder.rglob(name))


def nutrients(path: Path, wanted: set[str] | None = None) -> dict[str, list]:
    found: dict[str, list] = {}
    backup: dict[str, float] = {}
    for row in read(path):
        fdc, nutrient = row["fdc_id"], row["nutrient_id"]
        if wanted is not None and fdc not in wanted:
            continue
        try:
            if nutrient in NUTRIENTS:
                found.setdefault(fdc, [None] * 7)[NUTRIENTS[nutrient]] = float(row["amount"])
            elif nutrient in ATWATER:
                backup[fdc] = float(row["amount"])
        except ValueError:
            continue
    for fdc, energy in backup.items():
        values = found.setdefault(fdc, [None] * 7)
        if values[0] is None:
            values[0] = energy
    return found


def scaled(values: list, grams: float) -> list[int]:
    """Per-100 g values for a serving, followed by the serving's weight. The weight is what lets the app work out
    nutrition for any amount, as it must for a photographed portion."""
    return [round((v or 0) * grams / 100 * 10) for v in values] + [round(grams)]


def nearest_portion(portions: list[tuple[float, str]]) -> tuple[float, str]:
    return min(portions, key=lambda p: abs(p[0] - 100)) if portions else (100.0, "100 g")


def usda_generic(data: Path) -> list[tuple]:
    rows = []
    for folder, kind in (("x_foundation", "foundation_food"), ("x_sr", "sr_legacy_food"), ("x_survey", "survey_fndds_food")):
        root = data / folder
        foods = {r["fdc_id"]: r["description"] for r in read(only(root, "food.csv")) if r["data_type"] == kind}
        units = {r["id"]: r["name"] for r in read(only(root, "measure_unit.csv"))}
        portions = collections.defaultdict(list)
        for r in read(only(root, "food_portion.csv")):
            try:
                grams = float(r["gram_weight"])
            except ValueError:
                continue
            unit = units.get(r["measure_unit_id"], "")
            label = r["portion_description"] or " ".join(
                x for x in (r["amount"].removesuffix(".0"), "" if unit == "undetermined" else unit, r["modifier"]) if x)
            if grams > 0 and label and "not specified" not in label.lower():
                portions[r["fdc_id"]].append((grams, label))
        values = nutrients(only(root, "food_nutrient.csv"), set(foods))
        for fdc, name in foods.items():
            nutrition = values.get(fdc)
            if nutrition and nutrition[0] is not None:
                grams, label = nearest_portion(portions[fdc])
                rows.append((name, "", None, label, USDA, *scaled(nutrition, grams)))
        print(f"{kind}: {len(foods)} foods, {sum(1 for r in rows)} kept so far", flush=True)
    return rows


def usda_branded(data: Path, report: collections.Counter) -> tuple[list[tuple], set[int]]:
    root = data / "x_branded"
    latest: dict[int, dict] = {}
    for row in read(only(root, "branded_food.csv")):
        report["branded rows"] += 1
        report[f"market {row['market_country'] or 'unknown'}"] += 1
        if row["discontinued_date"]:
            report["branded discontinued"] += 1
            continue
        code = canonical(row["gtin_upc"])
        if code is None:
            report["branded bad barcode"] += 1
            continue
        current = latest.get(code)
        if current is None or (row["available_date"], row["fdc_id"]) > (current["available_date"], current["fdc_id"]):
            latest[code] = row
    report["branded unique barcodes"] = len(latest)
    names = {r["fdc_id"]: r["description"] for r in read(only(root, "food.csv")) if r["data_type"] == "branded_food"}
    values = nutrients(only(root, "food_nutrient.csv"), {r["fdc_id"] for r in latest.values()})
    rows, kept = [], set()
    for code, row in latest.items():
        nutrition = values.get(row["fdc_id"])
        name = names.get(row["fdc_id"], "").strip()
        if not name or not nutrition or nutrition[0] is None:
            report["branded no name or energy"] += 1
            continue
        try:
            grams = float(row["serving_size"])
        except ValueError:
            grams = 0
        unit = {"G": "g", "GRM": "g", "ML": "ml", "MLT": "ml"}.get(row["serving_size_unit"].upper())
        if grams > 0 and unit:
            weight = f"{grams:g} {unit}"
            household = " ".join(row["household_serving_fulltext"].split())
            label = f"{household} ({weight})" if household else weight
        else:
            grams, label = 100.0, "100 g"
        brand = readable(row["brand_name"] or row["brand_owner"])
        rows.append((readable(name), brand, code, label, USDA, *scaled(nutrition, grams)))
        kept.add(code)
    report["branded kept"] = len(rows)
    return rows, kept


def canadian(data: Path) -> list[tuple]:
    root = data / "x_cnf"
    names = {r["FoodID"]: r["FoodDescription"] for r in read(only(root, "FOOD NAME.csv"), "latin-1")}
    measures = {r["MeasureID"]: r["MeasureDescription"] for r in read(only(root, "MEASURE NAME.csv"), "latin-1")}
    columns = {"208": 0, "203": 1, "205": 2, "204": 3, "307": 4, "269": 5, "291": 6}
    ids = {r["NutrientID"]: columns[r["NutrientCode"]] for r in read(only(root, "NUTRIENT NAME.csv"), "latin-1") if r["NutrientCode"] in columns}
    values: dict[str, list] = {}
    for r in read(only(root, "NUTRIENT AMOUNT.csv"), "latin-1"):
        if r["NutrientID"] in ids:
            values.setdefault(r["FoodID"], [None] * 7)[ids[r["NutrientID"]]] = float(r["NutrientValue"])
    portions = collections.defaultdict(list)
    for r in read(only(root, "CONVERSION FACTOR.csv"), "latin-1"):
        factor, label = float(r["ConversionFactorValue"] or 0), measures.get(r["MeasureID"], "")
        if factor > 0 and label and "no serving" not in label:
            portions[r["FoodID"]].append((factor * 100, label))
    rows = []
    for food, name in names.items():
        nutrition = values.get(food)
        if nutrition and nutrition[0] is not None:
            grams, label = nearest_portion(portions[food])
            rows.append((name, "", None, label, HEALTH_CANADA, *scaled(nutrition, grams)))
    return rows


def restaurants(data: Path) -> list[tuple]:
    """Chain menus from MenuStat, each item once at its latest year. Labelled with that year, as menus change."""
    latest: dict[str, dict] = {}
    for row in read(data / "menustat.csv"):
        if not row["Calories"].strip():
            continue
        current = latest.get(row["Menu_Item_ID"])
        if current is None or row["Year"] > current["Year"]:
            latest[row["Menu_Item_ID"]] = row

    def amount(row: dict, key: str) -> float:
        try:
            return float(row[key])
        except ValueError:
            return 0.0

    rows: dict[tuple[str, str], tuple] = {}
    for row in sorted(latest.values(), key=lambda r: r["Year"]):
        calories = amount(row, "Calories")
        # Toppings are parts of an item, like "Bacon, for Small Hand Tossed Pizza", and would bury the item itself.
        if calories > LARGEST_RESTAURANT_ITEM or row["Food_Category"] == "Toppings & Ingredients":
            continue
        brand = "Chick-fil-A" if row["restaurant"] == "Chick-Fil-A" else row["restaurant"]
        name = re.sub(r"(?i)chick[- ]fil[- ]a", "Chick-fil-A", " ".join(row["Item_Name"].split()))
        size, unit = row["Serving_Size"].strip(), row["Serving_Size_Unit"].strip()
        portion = row["Serving_Size_household"].strip() or (f"{float(size):g} {unit}" if size and unit else "1 item")
        values = [calories, amount(row, "Protein"), amount(row, "Carbohydrates"), amount(row, "Total_Fat"),
                  amount(row, "Sodium"), amount(row, "Sugar"), amount(row, "Dietary_Fiber")]
        weight = float(size) if size and unit == "g" else None
        rows[(brand.lower(), name.lower())] = (name, brand, None, f"{portion}, {row['Year']} menu", RESTAURANT, *scaled(values, 100)[:-1], weight and round(weight))
    return list(rows.values())


def open_food_facts(data: Path, known: set[int], report: collections.Counter, scans: dict[int, int]) -> list[tuple]:
    def number(row: dict, key: str) -> float | None:
        try:
            return float(row[key])
        except (KeyError, TypeError, ValueError):
            return None

    rows, seen = [], set()
    with gzip.open(data / "off.csv.gz", "rt", encoding="utf-8", errors="replace", newline="") as handle:
        for row in csv.DictReader(handle, delimiter="\t", quoting=csv.QUOTE_NONE):
            countries = row.get("countries_tags") or ""
            canada, america = "en:canada" in countries, "en:united-states" in countries
            if not (canada or america):
                continue
            report["off US/CA rows"] += 1
            if canada:
                report["off Canada rows"] += 1
            code, name = canonical(row.get("code") or ""), (row.get("product_name") or "").strip()
            if code is not None:
                scans[code] = int(number(row, "unique_scans_n") or 0)
            energy = number(row, "energy-kcal_100g")
            if code is None or not name or energy is None or not 0 <= energy <= 900:
                report["off no barcode, name or energy"] += 1
                continue
            if code in known or code in seen:
                report["off already in USDA"] += 1
                continue
            seen.add(code)
            grams = number(row, "serving_quantity") or 0
            label = " ".join((row.get("serving_size") or "").split()) or f"{grams:g} g"
            if not 0 < grams < 3000:
                grams, label = 100.0, "100 g"
            per100 = [energy, number(row, "proteins_100g"), number(row, "carbohydrates_100g"), number(row, "fat_100g"),
                      (number(row, "sodium_100g") or 0) * 1000, number(row, "sugars_100g"), number(row, "fiber_100g")]
            brand = (row.get("brands") or "").split(",")[0].strip()
            rows.append((name, brand, code, label[:60], OPEN_FOOD_FACTS, *scaled(per100, grams)))
            report["off kept (Canada)" if canada else "off kept (US only)"] += 1
    return rows


def write(rows: list[tuple], out: Path, data_date: int, scans: dict[int, int]) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    out.unlink(missing_ok=True)
    db = sqlite3.connect(out)
    db.executescript("""
        PRAGMA page_size = 4096; PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF;
        CREATE TABLE brand(id INTEGER PRIMARY KEY, name TEXT NOT NULL);
        CREATE TABLE food(id INTEGER PRIMARY KEY, name TEXT NOT NULL, brand INTEGER, barcode INTEGER, serving TEXT NOT NULL,
            source INTEGER NOT NULL, calories INTEGER, protein INTEGER, carbohydrates INTEGER, fat INTEGER,
            sodium INTEGER, sugars INTEGER, fiber INTEGER, popularity INTEGER NOT NULL DEFAULT 0, grams INTEGER);
        CREATE TABLE vocabulary(word TEXT PRIMARY KEY, frequency INTEGER NOT NULL) WITHOUT ROWID;
        CREATE TABLE meta(key TEXT PRIMARY KEY, value INTEGER NOT NULL);
        CREATE VIRTUAL TABLE food_search USING fts5(name, brand, alias, content='',
            tokenize="porter unicode61 remove_diacritics 2", prefix='2 3');
    """)
    db.execute("INSERT INTO meta VALUES ('data_date', ?)", (data_date,))
    brands: dict[str, int] = {}
    vocabulary: collections.Counter = collections.Counter()
    for index, row in enumerate(rows, start=1):
        name, brand, code, serving, source, *values, grams = row
        brand_id = None
        if brand:
            brand_id = brands.get(brand)
            if brand_id is None:
                brand_id = brands[brand] = len(brands) + 1
                db.execute("INSERT INTO brand VALUES (?, ?)", (brand_id, brand))
        db.execute("INSERT INTO food VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                   (index, name, brand_id, code, serving, source, *values, scans.get(code, 0) if code else 0, grams))
        alias = aliases(name, brand)
        db.execute("INSERT INTO food_search(rowid, name, brand, alias) VALUES (?, ?, ?, ?)",
                   (index, normalized(name), normalized(brand), alias))
        vocabulary.update(set(words(f"{name} {brand} {alias}")))
    db.executemany("INSERT INTO vocabulary VALUES (?, ?)",
                   ((w, n) for w, n in vocabulary.items() if n >= MINIMUM_WORD_FREQUENCY and 2 <= len(w) <= 24))
    db.execute("CREATE INDEX food_barcode ON food(barcode) WHERE barcode IS NOT NULL")
    db.execute("INSERT INTO food_search(food_search) VALUES ('optimize')")
    db.commit()
    db.execute("VACUUM")
    db.close()


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--data", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--open-food-facts", action="store_true")
    args = ap.parse_args()

    report: collections.Counter = collections.Counter()
    generic = usda_generic(args.data) + canadian(args.data)
    menus = restaurants(args.data)
    print(f"{len(menus):>10,}  restaurant items", flush=True)
    branded, known = usda_branded(args.data, report)
    scans: dict[int, int] = {}
    extra = open_food_facts(args.data, known, report, scans) if args.open_food_facts else []
    # When the export was downloaded, less a margin so updates overlap it instead of leaving a gap.
    source = args.data / "off.csv.gz" if args.open_food_facts else only(args.data / "x_branded", "branded_food.csv")
    write(generic + menus + branded + extra, args.out, int(source.stat().st_mtime) - DATA_DATE_MARGIN, scans)
    for key, value in sorted(report.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"{value:>10,}  {key}")
    print(f"{len(generic):>10,}  generic foods\n{len(generic) + len(menus) + len(branded) + len(extra):>10,}  total")
    print(f"{args.out.stat().st_size / 1e6:.1f} MB", flush=True)


if __name__ == "__main__":
    main()
