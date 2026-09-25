"""Train and evaluate deterministic repeat-purchase classifiers."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.dummy import DummyClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from ml.data import FEATURE_COLUMNS, TARGET_COLUMN, load_training_data, temporal_split
from ml.evaluate import evaluate_classifier


RANDOM_SEED = 42
CLASSIFICATION_THRESHOLD = 0.5


def numeric_preprocessor() -> ColumnTransformer:
    numeric_pipeline = Pipeline(
        steps=[
            ("imputer", SimpleImputer(strategy="median")),
            ("scaler", StandardScaler()),
        ]
    )
    return ColumnTransformer(
        transformers=[("numeric", numeric_pipeline, FEATURE_COLUMNS)],
        remainder="drop",
    )


def model_pipeline(classifier: Any) -> Pipeline:
    return Pipeline(
        steps=[
            ("preprocess", numeric_preprocessor()),
            ("classifier", classifier),
        ]
    )


def partition_summary(frame: pd.DataFrame) -> dict[str, Any]:
    positives = int(frame[TARGET_COLUMN].sum())
    rows = int(len(frame))
    return {
        "rows": rows,
        "positive_rows": positives,
        "negative_rows": rows - positives,
        "positive_rate": positives / rows if rows else 0.0,
    }


def train_and_evaluate(frame: pd.DataFrame) -> dict[str, Any]:
    split = temporal_split(frame)
    train_x = split.train[FEATURE_COLUMNS]
    train_y = split.train[TARGET_COLUMN].astype(int)

    models = {
        "dummy_classifier": DummyClassifier(strategy="prior", random_state=RANDOM_SEED),
        "logistic_regression": LogisticRegression(
            max_iter=1000,
            class_weight="balanced",
            random_state=RANDOM_SEED,
        ),
    }

    evaluations: dict[str, Any] = {}
    for name, classifier in models.items():
        pipeline = model_pipeline(classifier)
        pipeline.fit(train_x, train_y)
        evaluations[name] = {
            "validation": evaluate_classifier(
                pipeline,
                split.validation[FEATURE_COLUMNS],
                split.validation[TARGET_COLUMN],
                threshold=CLASSIFICATION_THRESHOLD,
            ),
            "test": evaluate_classifier(
                pipeline,
                split.test[FEATURE_COLUMNS],
                split.test[TARGET_COLUMN],
                threshold=CLASSIFICATION_THRESHOLD,
            ),
        }

    cutoff_strings = sorted(
        pd.Timestamp(value).date().isoformat()
        for value in frame["prediction_cutoff_date"].drop_duplicates()
    )
    return {
        "problem": "repeat_purchase_30d",
        "random_seed": RANDOM_SEED,
        "classification_threshold": CLASSIFICATION_THRESHOLD,
        "features": FEATURE_COLUMNS,
        "dataset": {
            "rows": int(len(frame)),
            "customers": int(frame["customer_id"].nunique()),
            "cutoff_count": len(cutoff_strings),
            "cutoffs": cutoff_strings,
            "class_balance": partition_summary(frame),
        },
        "temporal_split": {
            "train_cutoffs": split.train_cutoffs,
            "validation_cutoffs": split.validation_cutoffs,
            "test_cutoffs": split.test_cutoffs,
            "train": partition_summary(split.train),
            "validation": partition_summary(split.validation),
            "test": partition_summary(split.test),
        },
        "models": evaluations,
        "limitations": "Metrics use synthetic data and demonstrate engineering behavior, not business value.",
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("ml/artifacts/metrics.json"),
        help="Location for the deterministic JSON evaluation artifact.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    frame = load_training_data()
    metrics = train_and_evaluate(frame)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(metrics, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(metrics, indent=2, sort_keys=True))
    print(f"Metrics written to {args.output}")


if __name__ == "__main__":
    main()

