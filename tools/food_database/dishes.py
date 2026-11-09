#!/usr/bin/env python3
"""Build the table linking each Food-101 dish to the database food that stands for it.

    python tools/food_database/dishes.py k-cal/Data/foods.sqlite k-cal/Data/dish_foods.json

Chosen by hand, because a text search gets this badly wrong: it matches samosa to salsa and macarons to macaroni.
Every name must exist in the database or the build fails. Dishes with no honest equivalent, like carbonara, are left
out on purpose: they keep the photo model's estimate instead of borrowing numbers from something else. So are ones
whose nearest entry misleads, like raw prime rib or a Caesar salad with no dressing.

Single foods come after them, keyed by the labels of Apple's image classifier, because Food-101 has no fruit and the
photo models can't size one item. Each has the edible weight of a typical one, and a name for the labels that lack one.
"""
import json
import sqlite3
import sys

DISHES = {
    "apple_pie": "Pie, apple",
    "baby_back_ribs": "Pork, back ribs, lean and fat, roasted",
    "baklava": "Baklava",
    "beef_tartare": "Steak tartare",
    "beignets": "Beignet",
    "bread_pudding": "Bread pudding, with raisins, homemade",
    "breakfast_burrito": "Fast foods, breakfast burrito, with egg, cheese, and sausage",
    "bruschetta": "Bruschetta",
    "ceviche": "Ceviche",
    "cheesecake": "Cheesecake, plain",
    "chicken_curry": "Chicken curry",
    "chicken_quesadilla": "Quesadilla, chicken",
    "chicken_wings": "Chicken wing, NS as to cooking method",
    "chocolate_mousse": "Dessert, mousse, chocolate, homemade",
    "churros": "Churros",
    "clam_chowder": "Soup, New England clam chowder",
    "club_sandwich": "Club sandwich on white",
    "cup_cakes": "Cake or cupcake, NFS",
    "deviled_eggs": "Egg, deviled",
    "donuts": "Doughnut, NFS",
    "dumplings": "Potsticker or wonton, pork and vegetable, frozen, unprepared",
    "edamame": "Edamame, cooked",
    "eggs_benedict": "Egg Benedict",
    "escargots": "Escargot",
    "falafel": "Falafel",
    "filet_mignon": "Beef, steak, tenderloin",
    "foie_gras": "Pate de foie gras, canned (goose liver pate), smoked",
    "french_fries": "DENNY'S, french fries",
    "french_onion_soup": "Soup, French onion",
    "french_toast": "French toast, NFS",
    "fried_calamari": "Calamari, fried",
    "fried_rice": "Chicken fried rice, with peas, onion and eggs",
    "frozen_yogurt": "Frozen yogurt, NFS",
    "garlic_bread": "Garlic bread, frozen",
    "gnocchi": "Gnocchi, potato",
    "grilled_cheese_sandwich": "Grilled cheese sandwich, NFS",
    "guacamole": "Guacamole, NFS",
    "gyoza": "Potsticker or wonton, pork and vegetable, frozen, unprepared",
    "hamburger": "Hamburger, NFS",
    "hot_and_sour_soup": "Soup, hot and sour",
    "hot_dog": "Hot dog, NFS",
    "huevos_rancheros": "Huevos rancheros",
    "hummus": "Hummus, plain",
    "ice_cream": "Ice cream, NFS",
    "lasagna": "Lasagna with meat",
    "macaroni_and_cheese": "Macaroni or noodles with cheese",
    "macarons": "Cookie, macaroon",
    "miso_soup": "Soup, miso or tofu",
    "mussels": "Mussels",
    "nachos": "Nachos, NFS",
    "omelette": "Egg, whole, cooked, omelet",
    "onion_rings": "Onion rings, breaded, par fried, frozen, heated",
    "oysters": "Oysters, raw",
    "pad_thai": "Pad Thai, NFS",
    "paella": "Paella, NFS",
    "pancakes": "Pancakes, NFS",
    "peking_duck": "Duck, Peking",
    "pho": "Soup, pho, with meat",
    "pizza": "Pizza, cheese, from frozen, thin crust",
    "poutine": "Poutine",
    "pulled_pork_sandwich": "Barbecue pork sandwich, on white bun",
    "ramen": "Ramen bowl, NFS",
    "ravioli": "Ravioli, NS as to filling, no sauce",
    "red_velvet_cake": "Cake or cupcake, red velvet",
    "samosa": "Samosa",
    "sashimi": "Fish, tuna, raw",
    "scallops": "Scallops, grilled",
    "spaghetti_bolognese": "Spaghetti with meat sauce",
    "spring_rolls": "Egg roll, with beef and/or pork",
    "steak": "Steak, NS as to type of meat, NS as to fat eaten",
    "strawberry_shortcake": "Cake, strawberry shortcake",
    "sushi": "Sushi, NFS",
    "tacos": "Taco, NFS",
    "tiramisu": "Tiramisu",
    "tuna_tartare": "Fish, tuna, raw",
    "waffles": "Waffle, NFS",
}

SINGLE_FOODS = {
    "bagel": ("Bagel", 105, None),
    "beer": ("Beer", 356, "Beer"),
    "coffee": ("Coffee, brewed", 240, "Coffee"),
    "cookie": ("Cookie, chocolate chip", 30, None),
    "croissant": ("Croissant", 60, None),
    "cupcake": ("Cake or cupcake, NFS", 70, None),
    "donut": ("Doughnut, NFS", 75, None),
    "muffin": ("Muffin, blueberry, commercial", 113, None),
    "pretzel": ("Pretzels, soft", 115, "Soft Pretzel"),
    "red_wine": ("Wine, red", 147, "Red Wine"),
    "white_wine": ("Wine, white", 147, "White Wine"),
    "apple": ("Apple, raw, with skin", 182, None),
    "avocado": ("Avocado, raw", 150, None),
    "banana": ("Bananas, raw", 118, None),
    "kiwi": ("Kiwi fruit, raw", 75, None),
    "mandarine": ("Clementine, raw", 75, "Mandarin"),
    "mango": ("Mango, raw", 200, None),
    "nectarine": ("Nectarine, raw", 140, None),
    "oranges": ("Orange, raw", 140, "Orange"),
    "peach": ("Peach, raw", 150, None),
    "pear": ("Pear, raw", 178, None),
    "plum": ("Plum, raw", 66, None),
}


def main() -> None:
    db = sqlite3.connect(sys.argv[1])
    table, missing = {}, []
    single = {label: name for label, (name, _, _) in SINGLE_FOODS.items()}
    for dish, name in {**DISHES, **single}.items():
        row = db.execute(
            """SELECT name, source, grams, calories, protein, carbohydrates, fat, sodium, sugars, fiber FROM food
               WHERE (name = ? OR name LIKE ?) AND brand IS NULL AND barcode IS NULL AND grams > 0
               ORDER BY length(name) LIMIT 1""", (name, name + "%")).fetchone()
        if row is None:
            missing.append(f"{dish}: {name}")
            continue
        grams = row[2]
        per_gram = [round(v / 10 / grams, 4) for v in row[3:]]
        table[dish] = {"food": row[0], "source": row[1], "perGram": per_gram}
        if dish in SINGLE_FOODS:
            _, item_grams, title = SINGLE_FOODS[dish]
            table[dish]["itemGrams"] = item_grams
            if title:
                table[dish]["title"] = title
    if missing:
        sys.exit("Not in the database:\n" + "\n".join(missing))
    with open(sys.argv[2], "w") as output:
        json.dump(table, output, indent=0, sort_keys=True)
    for dish, entry in sorted(table.items(), key=lambda kv: kv[1]["perGram"][0]):
        print(f"{entry['perGram'][0] * 100:5.0f} kcal/100g  {dish:26} {entry['food'][:52]}")
    print(len(table) - len(SINGLE_FOODS), "dishes of 101, and", len(SINGLE_FOODS), "single foods")


if __name__ == "__main__":
    main()
