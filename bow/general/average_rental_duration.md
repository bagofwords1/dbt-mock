---
category: general
id: 75e0d370-7c1b-462b-ba13-789305a7e4e3
load_mode: intelligent
status: published
---

# average_rental_duration

# average_rental_duration

**Type:** dbt metric
**Path:** `metrics/rental_metrics.yml`

Average duration of rentals in days

**Calculation:** average
**Expression:** `{{ calculate_rental_duration('return_date', 'rental_date') }}`
**Timestamp:** rental_day
**Time grains:** day, week, month, quarter, year