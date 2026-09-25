# Architecture

The platform is a local ELT and ML data system. A deterministic Python process writes synthetic transactional records into PostgreSQL's `raw` schema. dbt builds progressively more business-oriented schemas and owns the historical feature and label definitions. Python loads the resulting training table for model fitting and evaluation.

```text
Python generator
      |
      v
PostgreSQL raw
      |
      v
analytics_staging      one-to-one typed source views
      |
      v
analytics_intermediate reusable business transformations
      |
      v
analytics_core         dimensions and facts
      |
      v
analytics_marts        reporting-ready tables
      |
      v
analytics_ml           cutoffs, feature snapshots, labelled data
      |
      v
temporal split -> train-only preprocessing -> models -> metrics JSON
```

## Layer responsibilities

- **Raw:** source-shaped records with database constraints, UTC timestamps, and load metadata.
- **Staging:** one-to-one views that rename, normalize, and cast without joins or aggregation.
- **Intermediate:** reusable joins and calculations at explicit grains.
- **Core:** customer/product dimensions plus order and order-item facts.
- **Reporting:** daily sales and current-state customer analytics.
- **ML:** monthly historical snapshots and labels at customer/cutoff grain.
- **Python ML:** database loading, chronological splitting, preprocessing, training, and evaluation only.

All dbt dependencies use `source()` or `ref()`. PostgreSQL relation names are never hard-coded into downstream models.

## Return fan-out prevention

`raw.returns` contains one row per return event. An order item can therefore have several partial returns. Joining these events directly to order items would duplicate the order-item row and overstate sales, cost, and margin.

The model `int_returns_by_order_item` first aggregates every return event to exactly one row per `order_item_id`. Only this relation is joined to `stg_order_items` in `int_order_item_financials`:

```text
stg_returns
    -> int_returns_by_order_item (one row per returned item)
        -> left join to stg_order_items
            -> int_order_item_financials (one row per order item)
```

Unique and reconciliation tests enforce both grains.

## Incremental order fact

`fct_orders` is an incremental model keyed by `order_id`. Its `source_updated_at` is the greatest relevant timestamp contributed by the order header, order lines, product cost, payments, and returns. A three-day watermark lookback reprocesses recent changes, while `delete+insert` replaces affected order rows rather than appending duplicates.

This supports new orders, late successful payments, and late returns. The generator's delta batch contains all three cases and can be loaded repeatedly without duplicating raw keys.

## Point-in-time ML design

`ml_prediction_cutoffs` creates deterministic first-of-month cutoffs. A cutoff needs at least 90 days of preceding order history and is retained only when `cutoff + 30 days` is no later than the source observation end date. This makes every target window fully observable.

`ml_customer_features` has exactly one row per customer and cutoff. Its event-time boundaries are:

- qualifying order date `<= prediction_cutoff_date`;
- qualifying order update date `<= prediction_cutoff_date`;
- successful payment attempt and update dates `<= prediction_cutoff_date`;
- return and return-update dates `<= prediction_cutoff_date`.

The feature model reuses stable order-item quantities, prices, and discounts from `fct_order_items`. It does not reuse its current-state refund measures. Instead, return events are filtered and aggregated by order item separately for each historical cutoff. Payment attempts are similarly filtered by event and update timestamps. Audit columns record the latest order, return, and payment event/update admitted to each snapshot, and a singular test rejects any date beyond its cutoff.

`ml_customer_training_dataset` adds `repeat_purchase_30d`. This is the only step that looks forward: it checks for at least one qualifying customer order strictly after the cutoff and through the inclusive 30-day observation end. A second singular test ensures no training row extends beyond the dataset observation end.

```text
raw PostgreSQL
  -> staging/intermediate/core dbt models
  -> monthly historical cutoffs
  -> point-in-time customer features
  -> labelled customer/cutoff training rows
  -> earlier cutoffs: train
  -> penultimate cutoff: validation
  -> latest cutoff: test
  -> train-fitted imputation/scaling
  -> DummyClassifier + LogisticRegression
  -> ml/artifacts/metrics.json
```

No random split is used. With the seed-42, scale-20 fixture, May through November 2025 train the models, December 2025 is validation, and January 2026 is test. Fixed data and model seeds plus a timestamp-free, sorted JSON artifact make repeat runs deterministic.

## Scope boundary

This phase is local PostgreSQL, dbt, and scikit-learn only. It does not contain Terraform, AWS resources, APIs, Kubernetes, orchestration platforms, model registries, or cloud deployment.
