# Metric definitions

All monetary metrics are denominated in EUR.

| Metric | Definition |
|---|---|
| Gross sales | `quantity × unit_price`, before discounts and refunds. |
| Discount | Line-level reduction applied to gross sales. |
| Net sales | `gross sales - discount`; this is the amount that a paid or completed order should successfully collect before later refunds. |
| Refund | Sum of refund amounts across all return events for an order item. |
| Post-refund revenue | `net sales - refund`. |
| Cost | `quantity × product unit_cost`. Product costs are stable in the Phase 1 synthetic catalogue. |
| Margin | `post-refund revenue - cost`. It may legitimately be negative and is therefore not subject to the non-negative test. |
| Average order value (AOV) | Average post-refund revenue across paid and completed orders. |
| Unit return rate | `returned quantity / purchased units` for paid and completed orders. |

Cancelled and pending orders are retained in core facts but excluded from reporting revenue and customer commercial metrics.

