"""Generate deterministic e-commerce records and load them into PostgreSQL."""

from __future__ import annotations

import argparse
import os
import random
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from typing import Any, Iterable

import psycopg


BUSINESS_START = datetime(2025, 1, 1, 9, 0, tzinfo=timezone.utc)
COUNTRIES = ("DE", "AT", "CH", "NL", "FR")
ACQUISITION_CHANNELS = ("organic", "paid_search", "referral", "affiliate")
CATEGORIES = ("electronics", "home", "sports", "books", "beauty")
SALES_CHANNELS = ("web", "mobile", "marketplace")
PAYMENT_METHODS = ("card", "paypal", "bank_transfer")
RETURN_REASONS = ("damaged", "unwanted", "wrong_item", "defective", "late_delivery")
MONEY = Decimal("0.01")


def money(value: Decimal | float | int | str) -> Decimal:
    return Decimal(str(value)).quantize(MONEY, rounding=ROUND_HALF_UP)


@dataclass(frozen=True)
class DatasetSizes:
    customers: int
    products: int
    orders: int


def sizes(scale: int) -> DatasetSizes:
    if scale < 1:
        raise ValueError("--scale must be at least 1")
    return DatasetSizes(customers=12 * scale, products=8 * scale, orders=20 * scale)


def connection_string() -> str:
    return (
        f"host={os.getenv('DB_HOST', 'localhost')} "
        f"port={os.getenv('POSTGRES_PORT', '5432')} "
        f"dbname={os.getenv('POSTGRES_DB', 'ecommerce')} "
        f"user={os.getenv('POSTGRES_USER', 'ecommerce')} "
        f"password={os.getenv('POSTGRES_PASSWORD', 'ecommerce_local')}"
    )


def upsert_many(
    cursor: psycopg.Cursor[Any],
    table: str,
    columns: tuple[str, ...],
    rows: Iterable[tuple[Any, ...]],
    conflict_key: str,
) -> None:
    rows = list(rows)
    if not rows:
        return
    placeholders = ", ".join(["%s"] * len(columns))
    assignments = ", ".join(
        f"{column} = EXCLUDED.{column}"
        for column in columns
        if column != conflict_key
    )
    statement = (
        f"INSERT INTO raw.{table} ({', '.join(columns)}) "
        f"VALUES ({placeholders}) "
        f"ON CONFLICT ({conflict_key}) DO UPDATE SET {assignments}"
    )
    cursor.executemany(statement, rows)


def baseline_records(seed: int, scale: int, loaded_at: datetime) -> dict[str, list[tuple[Any, ...]]]:
    rng = random.Random(seed)
    n = sizes(scale)

    customers: list[tuple[Any, ...]] = []
    for customer_id in range(1, n.customers + 1):
        created_at = BUSINESS_START + timedelta(days=customer_id)
        customers.append(
            (
                customer_id,
                f"customer{customer_id:05d}@example.test",
                COUNTRIES[(customer_id - 1) % len(COUNTRIES)],
                ACQUISITION_CHANNELS[(customer_id + seed) % len(ACQUISITION_CHANNELS)],
                created_at,
                created_at,
                loaded_at,
            )
        )

    products: list[tuple[Any, ...]] = []
    product_prices: dict[int, tuple[Decimal, Decimal]] = {}
    for product_id in range(1, n.products + 1):
        list_price = money(20 + ((product_id * 17 + seed) % 180))
        unit_cost = money(list_price * Decimal("0.55"))
        product_prices[product_id] = (list_price, unit_cost)
        created_at = BUSINESS_START - timedelta(days=30 - product_id)
        products.append(
            (
                product_id,
                f"SKU-{product_id:05d}",
                f"Synthetic {CATEGORIES[(product_id - 1) % len(CATEGORIES)].title()} Product {product_id}",
                CATEGORIES[(product_id - 1) % len(CATEGORIES)],
                list_price,
                unit_cost,
                True,
                created_at,
                created_at,
                loaded_at,
            )
        )

    orders: list[tuple[Any, ...]] = []
    order_items: list[tuple[Any, ...]] = []
    payments: list[tuple[Any, ...]] = []
    returns: list[tuple[Any, ...]] = []
    order_totals: dict[int, Decimal] = {}
    next_item_id = 1
    next_payment_id = 1
    next_return_id = 1

    for order_id in range(1, n.orders + 1):
        ordered_at = BUSINESS_START + timedelta(days=20 + order_id, hours=order_id % 8)
        if order_id == 2:
            status = "pending"
        elif order_id % 10 == 0:
            status = "cancelled"
        elif order_id % 3 == 0:
            status = "paid"
        else:
            status = "completed"
        customer_id = ((order_id * 7 + seed) % n.customers) + 1
        order_updated_at = ordered_at + timedelta(hours=2)
        orders.append(
            (
                order_id,
                customer_id,
                status,
                SALES_CHANNELS[(order_id + seed) % len(SALES_CHANNELS)],
                "EUR",
                ordered_at,
                order_updated_at,
                loaded_at,
            )
        )

        line_count = 2 if order_id % 4 == 0 else 1
        if order_id == 1:
            line_count = 1
        order_total = Decimal("0.00")
        item_ids_for_order: list[int] = []
        for line_number in range(line_count):
            product_id = ((order_id + line_number + seed) % n.products) + 1
            quantity = 3 if order_id == 1 else rng.randint(1, 3)
            unit_price = product_prices[product_id][0]
            gross = money(unit_price * quantity)
            discount = money(gross * Decimal("0.10")) if (order_id + line_number) % 5 == 0 else money(0)
            item_created_at = ordered_at + timedelta(minutes=5 + line_number)
            order_items.append(
                (
                    next_item_id,
                    order_id,
                    product_id,
                    quantity,
                    unit_price,
                    discount,
                    item_created_at,
                    item_created_at,
                    loaded_at,
                )
            )
            item_ids_for_order.append(next_item_id)
            order_total += gross - discount
            next_item_id += 1
        order_totals[order_id] = money(order_total)

        attempted_at = ordered_at + timedelta(minutes=15)
        if order_id == 2:
            payment_status = "failed"
        elif status == "cancelled":
            payment_status = "failed"
        else:
            payment_status = "succeeded"
        payments.append(
            (
                next_payment_id,
                order_id,
                PAYMENT_METHODS[(order_id + seed) % len(PAYMENT_METHODS)],
                payment_status,
                order_totals[order_id],
                attempted_at,
                attempted_at,
                loaded_at,
            )
        )
        next_payment_id += 1

        if status == "completed" and order_id > 2 and order_id % 7 == 0:
            item = order_items[item_ids_for_order[0] - 1]
            quantity = item[3]
            unit_price = item[4]
            discount = item[5]
            refundable_unit = money((unit_price * quantity - discount) / quantity)
            returned_at = ordered_at + timedelta(days=8)
            returns.append(
                (
                    next_return_id,
                    item_ids_for_order[0],
                    1,
                    refundable_unit,
                    RETURN_REASONS[order_id % len(RETURN_REASONS)],
                    returned_at,
                    returned_at,
                    loaded_at,
                )
            )
            next_return_id += 1

    return {
        "customers": customers,
        "products": products,
        "orders": orders,
        "order_items": order_items,
        "payments": payments,
        "returns": returns,
    }


def delta_records(seed: int, scale: int, loaded_at: datetime) -> dict[str, list[tuple[Any, ...]]]:
    rng = random.Random(seed + 10_000)
    n = sizes(scale)
    baseline = baseline_records(seed, scale, loaded_at)
    baseline_item_count = len(baseline["order_items"])
    baseline_payment_count = len(baseline["payments"])
    baseline_return_count = len(baseline["returns"])

    customers: list[tuple[Any, ...]] = []
    for offset in range(1, 3 * scale + 1):
        customer_id = n.customers + offset
        created_at = BUSINESS_START + timedelta(days=120 + offset)
        customers.append(
            (
                customer_id,
                f"customer{customer_id:05d}@example.test",
                COUNTRIES[(customer_id - 1) % len(COUNTRIES)],
                ACQUISITION_CHANNELS[(customer_id + seed) % len(ACQUISITION_CHANNELS)],
                created_at,
                created_at,
                loaded_at,
            )
        )

    orders: list[tuple[Any, ...]] = []
    order_items: list[tuple[Any, ...]] = []
    payments: list[tuple[Any, ...]] = []
    new_order_totals: dict[int, Decimal] = {}
    next_item_id = baseline_item_count + 1
    next_payment_id = baseline_payment_count + 1

    for offset in range(1, 5 * scale + 1):
        order_id = n.orders + offset
        customer_id = n.customers + ((offset - 1) % (3 * scale)) + 1
        ordered_at = BUSINESS_START + timedelta(days=150 + offset, hours=offset)
        status = "paid" if offset == 1 else "completed"
        orders.append(
            (
                order_id,
                customer_id,
                status,
                SALES_CHANNELS[(order_id + seed) % len(SALES_CHANNELS)],
                "EUR",
                ordered_at,
                ordered_at + timedelta(hours=1),
                loaded_at,
            )
        )
        product_id = ((order_id + seed) % n.products) + 1
        product = baseline["products"][product_id - 1]
        unit_price = product[4]
        quantity = rng.randint(1, 3)
        gross = money(unit_price * quantity)
        discount = money(gross * Decimal("0.10")) if offset % 2 == 0 else money(0)
        new_order_totals[order_id] = gross - discount
        order_items.append(
            (
                next_item_id,
                order_id,
                product_id,
                quantity,
                unit_price,
                discount,
                ordered_at + timedelta(minutes=5),
                ordered_at + timedelta(minutes=5),
                loaded_at,
            )
        )

        attempted_at = ordered_at + timedelta(minutes=10)
        if offset == 1:
            payments.append(
                (
                    next_payment_id,
                    order_id,
                    "card",
                    "failed",
                    new_order_totals[order_id],
                    attempted_at,
                    attempted_at,
                    loaded_at,
                )
            )
            next_payment_id += 1
            payments.append(
                (
                    next_payment_id,
                    order_id,
                    "card",
                    "succeeded",
                    new_order_totals[order_id],
                    attempted_at + timedelta(minutes=8),
                    attempted_at + timedelta(minutes=8),
                    loaded_at,
                )
            )
        else:
            payments.append(
                (
                    next_payment_id,
                    order_id,
                    PAYMENT_METHODS[(order_id + seed) % len(PAYMENT_METHODS)],
                    "succeeded",
                    new_order_totals[order_id],
                    attempted_at,
                    attempted_at,
                    loaded_at,
                )
            )
        next_payment_id += 1
        next_item_id += 1

    # Promote baseline order 2 after a late successful payment.
    baseline_order_2 = baseline["orders"][1]
    late_payment_at = BUSINESS_START + timedelta(days=170)
    orders.append(
        (
            baseline_order_2[0],
            baseline_order_2[1],
            "paid",
            baseline_order_2[3],
            baseline_order_2[4],
            baseline_order_2[5],
            late_payment_at,
            loaded_at,
        )
    )
    baseline_order_2_total = sum(
        item[3] * item[4] - item[5]
        for item in baseline["order_items"]
        if item[1] == 2
    )
    payments.append(
        (
            next_payment_id,
            2,
            "paypal",
            "succeeded",
            money(baseline_order_2_total),
            late_payment_at,
            late_payment_at,
            loaded_at,
        )
    )

    # Two late, partial return events for baseline order item 1.
    target_item = baseline["order_items"][0]
    refundable_unit = money((target_item[3] * target_item[4] - target_item[5]) / target_item[3])
    returns = [
        (
            baseline_return_count + 1,
            1,
            1,
            refundable_unit,
            "unwanted",
            BUSINESS_START + timedelta(days=171),
            BUSINESS_START + timedelta(days=171),
            loaded_at,
        ),
        (
            baseline_return_count + 2,
            1,
            1,
            refundable_unit,
            "damaged",
            BUSINESS_START + timedelta(days=172),
            BUSINESS_START + timedelta(days=172),
            loaded_at,
        ),
    ]

    return {
        "customers": customers,
        "products": [],
        "orders": orders,
        "order_items": order_items,
        "payments": payments,
        "returns": returns,
    }


COLUMNS = {
    "customers": (
        "customer_id", "email", "country_code", "acquisition_channel",
        "created_at", "updated_at", "_loaded_at",
    ),
    "products": (
        "product_id", "sku", "product_name", "category", "list_price",
        "unit_cost", "is_active", "created_at", "updated_at", "_loaded_at",
    ),
    "orders": (
        "order_id", "customer_id", "order_status", "sales_channel", "currency",
        "ordered_at", "updated_at", "_loaded_at",
    ),
    "order_items": (
        "order_item_id", "order_id", "product_id", "quantity", "unit_price",
        "discount_amount", "created_at", "updated_at", "_loaded_at",
    ),
    "payments": (
        "payment_id", "order_id", "payment_method", "payment_status", "amount",
        "attempted_at", "updated_at", "_loaded_at",
    ),
    "returns": (
        "return_id", "order_item_id", "return_quantity", "refund_amount",
        "return_reason", "returned_at", "updated_at", "_loaded_at",
    ),
}


def load(batch: str, seed: int, scale: int) -> dict[str, int]:
    loaded_at = datetime.now(timezone.utc).replace(microsecond=0)
    records = (
        baseline_records(seed, scale, loaded_at)
        if batch == "baseline"
        else delta_records(seed, scale, loaded_at)
    )
    keys = {
        "customers": "customer_id",
        "products": "product_id",
        "orders": "order_id",
        "order_items": "order_item_id",
        "payments": "payment_id",
        "returns": "return_id",
    }

    with psycopg.connect(connection_string()) as connection:
        with connection.cursor() as cursor:
            if batch == "baseline":
                cursor.execute(
                    "TRUNCATE raw.returns, raw.payments, raw.order_items, raw.orders, "
                    "raw.products, raw.customers RESTART IDENTITY CASCADE"
                )
            for table in ("customers", "products", "orders", "order_items", "payments", "returns"):
                upsert_many(cursor, table, COLUMNS[table], records[table], keys[table])
        connection.commit()

        counts: dict[str, int] = {}
        with connection.cursor() as cursor:
            for table in keys:
                cursor.execute(f"SELECT COUNT(*) FROM raw.{table}")
                counts[table] = cursor.fetchone()[0]
    return counts


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--scale", type=int, default=1)
    parser.add_argument("--batch", choices=("baseline", "delta"), default="baseline")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    counts = load(args.batch, args.seed, args.scale)
    print(f"Loaded {args.batch} batch (seed={args.seed}, scale={args.scale})")
    for table, count in counts.items():
        print(f"  raw.{table}: {count}")


if __name__ == "__main__":
    main()

