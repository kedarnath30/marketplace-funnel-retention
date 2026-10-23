"""Download the Olist Brazilian E-Commerce public dataset (no login required).

Source: official Olist GitHub repository https://github.com/olist/work-at-olist-data
(the same data is published on Kaggle as "Brazilian E-Commerce Public Dataset by Olist",
licensed CC BY-NC-SA 4.0). Files land in data/raw/ and are git-ignored.
"""
from pathlib import Path
import urllib.request

BASE = "https://raw.githubusercontent.com/olist/work-at-olist-data/master/datasets/"
FILES = [
    "olist_customers_dataset.csv",
    "olist_orders_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "product_category_name_translation.csv",
]
RAW = Path(__file__).resolve().parents[1] / "data" / "raw"


def main() -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    for f in FILES:
        dest = RAW / f
        if dest.exists() and dest.stat().st_size > 0:
            print(f"exists  {f}")
            continue
        print(f"fetch   {f}")
        urllib.request.urlretrieve(BASE + f, dest)
        print(f"        {dest.stat().st_size/1e6:.1f} MB")


if __name__ == "__main__":
    main()
