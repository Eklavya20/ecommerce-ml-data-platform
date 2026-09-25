"""Deterministic binary-classification evaluation helpers."""

from __future__ import annotations

from typing import Any

import numpy as np
from sklearn.metrics import (
    average_precision_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)


def evaluate_classifier(model: Any, features: Any, target: Any, threshold: float = 0.5) -> dict[str, Any]:
    probabilities = model.predict_proba(features)[:, 1]
    predictions = (probabilities >= threshold).astype(int)
    target_array = np.asarray(target, dtype=int)
    has_both_classes = np.unique(target_array).size == 2

    return {
        "threshold": threshold,
        "roc_auc": float(roc_auc_score(target_array, probabilities)) if has_both_classes else None,
        "pr_auc": float(average_precision_score(target_array, probabilities)) if has_both_classes else None,
        "precision": float(precision_score(target_array, predictions, zero_division=0)),
        "recall": float(recall_score(target_array, predictions, zero_division=0)),
        "f1": float(f1_score(target_array, predictions, zero_division=0)),
        "confusion_matrix": confusion_matrix(target_array, predictions, labels=[0, 1]).tolist(),
    }

