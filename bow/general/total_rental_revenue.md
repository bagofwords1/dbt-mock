---
category: general
id: 25b323f4-6700-4ddc-bc60-6a3bee2b8ea8
load_mode: intelligent
status: published
---

# total_rental_revenue

# total_rental_revenue

**Type:** dbt metric
**Path:** `metrics/rental_metrics.yml`

Total revenue from all rentals

**Calculation:** sum
**Expression:** `amount`
**Timestamp:** payment_date
**Time grains:** day, week, month, quarter, year