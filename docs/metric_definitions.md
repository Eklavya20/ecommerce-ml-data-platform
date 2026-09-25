# Metric definitions

All monetary metrics are denominated in EUR.

| Metric | Definition |
|---|---|
| Gross sales | `quantity × unit_price`, before discounts and refunds. |
| Discount | Line-level reduction applied to gross sales. |
| Net sales | `gross sales - discount`; this is the amount that a paid or completed order should successfully collect before later refunds. |
| Refund | Sum of refund amounts across all return events for an order item. |
| Post-refund revenue | `net sales - refund`. |
| Cost | `quantity × product unit_cost`. Product costs are stable in the synthetic catalogue. |
| Margin | `post-refund revenue - cost`. It may legitimately be negative and is therefore not subject to the non-negative test. |
| Average order value (AOV) | Average post-refund revenue across paid and completed orders. |
| Unit return rate | `returned quantity / purchased units` for paid and completed orders. |

Cancelled and pending orders are retained in core facts but excluded from reporting revenue and customer commercial metrics.

## ML target and features

All historical feature windows end on and include `prediction_cutoff_date`. A 30-day window means `(cutoff - 30 days, cutoff]`; the 90-day window follows the same convention.

| Field | Definition |
|---|---|
| `repeat_purchase_30d` | 1 when the customer has a paid/completed order with a successful payment in `(cutoff, cutoff + 30 days]`; otherwise 0. |
| `customer_tenure_days` | Days from customer creation through the cutoff. |
| `days_since_last_order` | Days from the most recent qualifying order through the cutoff. |
| `orders_last_30d`, `orders_last_90d` | Qualifying order counts in the corresponding trailing window. |
| `orders_lifetime_before_cutoff` | All qualifying orders on or before the cutoff. |
| `units_last_30d`, `units_last_90d` | Purchased units on qualifying orders in the corresponding trailing window. |
| `revenue_last_30d`, `revenue_last_90d` | Post-refund revenue known by the cutoff in the corresponding trailing order window. |
| `lifetime_revenue_before_cutoff` | Post-refund revenue known by the cutoff across qualifying order history. |
| `avg_order_value_90d`, `avg_order_value_lifetime` | Average post-refund revenue per qualifying order for the period. |
| `discount_usage_rate_90d`, `lifetime_discount_usage_rate` | Share of qualifying orders containing a positive discount. |
| `returned_quantity_90d` | Quantity returned by the cutoff for qualifying orders in the trailing 90-day order window. |
| `return_rate_90d` | `returned_quantity_90d / units_last_90d`. |
| `successful_payment_rate_90d` | Successful payment attempts divided by all attempts observed by the cutoff for orders in the trailing 90-day window. |
