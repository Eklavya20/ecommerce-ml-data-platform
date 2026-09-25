"""Load the dbt-owned training dataset from PostgreSQL."""

from __future__ import annotations

import os
from dataclasses import dataclass

import pandas as pd
import psycopg


FEATURE_COLUMNS = [
    "customer_tenure_days",
    "days_since_last_order",
    "orders_last_30d",
    "orders_last_90d",
    "orders_lifetime_before_cutoff",
    "units_last_30d",
    "units_last_90d",
    "revenue_last_30d",
    "revenue_last_90d",
    "lifetime_revenue_before_cutoff",
    "avg_order_value_90d",
    "avg_order_value_lifetime",
    "discount_usage_rate_90d",
    "lifetime_discount_usage_rate",
    "returned_quantity_90d",
    "return_rate_90d",
    "successful_payment_rate_90d",
]
TARGET_COLUMN = "repeat_purchase_30d"


@dataclass(frozen=True)
class TemporalSplit:
    train: pd.DataFrame
    validation: pd.DataFrame
    test: pd.DataFrame
    train_cutoffs: list[str]
    validation_cutoffs: list[str]
    test_cutoffs: list[str]


def connection_string() -> str:
    return (
        f"host={os.getenv('DB_HOST', '127.0.0.1')} "
        f"port={os.getenv('POSTGRES_PORT', '5432')} "
        f"dbname={os.getenv('POSTGRES_DB', 'ecommerce')} "
        f"user={os.getenv('POSTGRES_USER', 'ecommerce')} "
        f"password={os.getenv('POSTGRES_PASSWORD', 'ecommerce_local')}"
    )


def load_training_data() -> pd.DataFrame:
    schema = os.getenv("DBT_SCHEMA", "analytics") + "_ml"
    query = f"select * from {schema}.ml_customer_training_dataset"
    with psycopg.connect(connection_string()) as connection:
        with connection.cursor() as cursor:
            cursor.execute(query)
            rows = cursor.fetchall()
            columns = [column.name for column in cursor.description]

    frame = pd.DataFrame(rows, columns=columns)
    if frame.empty:
        raise ValueError("The dbt training dataset is empty. Generate larger data and run dbt build first.")
    frame["prediction_cutoff_date"] = pd.to_datetime(frame["prediction_cutoff_date"])
    frame = frame.sort_values(["prediction_cutoff_date", "customer_id"]).reset_index(drop=True)
    return frame


def temporal_split(frame: pd.DataFrame) -> TemporalSplit:
    cutoffs = sorted(frame["prediction_cutoff_date"].drop_duplicates().tolist())
    if len(cutoffs) < 3:
        raise ValueError("At least three cutoff dates are required for train/validation/test splitting.")

    validation_cutoff = cutoffs[-2]
    test_cutoff = cutoffs[-1]
    train = frame.loc[frame["prediction_cutoff_date"] < validation_cutoff].copy()
    validation = frame.loc[frame["prediction_cutoff_date"] == validation_cutoff].copy()
    test = frame.loc[frame["prediction_cutoff_date"] == test_cutoff].copy()

    if train.empty or validation.empty or test.empty:
        raise ValueError("Temporal split produced an empty partition.")
    if train[TARGET_COLUMN].nunique() < 2:
        raise ValueError("Training data must contain both target classes.")

    to_strings = lambda values: [pd.Timestamp(value).date().isoformat() for value in values]
    return TemporalSplit(
        train=train,
        validation=validation,
        test=test,
        train_cutoffs=to_strings(cutoffs[:-2]),
        validation_cutoffs=to_strings([validation_cutoff]),
        test_cutoffs=to_strings([test_cutoff]),
    )
