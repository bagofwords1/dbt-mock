---
category: general
id: e9e51dce-e9d2-41cf-97cf-d96fc8983a4a
load_mode: intelligent
status: published
---

# rental_count

# rental_count

**Type:** dbt metric
**Path:** `metrics/rental_metrics.yml`

Total number of rentals

**Calculation:** sum
**Expression:** `total_rentals`
**Timestamp:** rental_day
**Time grains:** day, week, month, quarter, year