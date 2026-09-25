# Architecture

The Phase 1 platform is a local ELT system. A deterministic Python process writes synthetic transactional records into PostgreSQL's `raw` schema. dbt then builds progressively more business-oriented schemas.

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
```

## Layer responsibilities

- **Raw:** source-shaped records with database constraints, UTC timestamps, and load metadata.
- **Staging:** one-to-one views that rename, normalize, and cast without joins or aggregation.
- **Intermediate:** reusable joins and calculations at explicit grains.
- **Core:** customer/product dimensions plus order and order-item facts.
- **Reporting:** daily sales and current-state customer analytics.

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

## Scope boundary

This phase is local PostgreSQL and dbt only. It does not contain Terraform, AWS resources, ML feature snapshots, model training, APIs, Kubernetes, or cloud deployment.

