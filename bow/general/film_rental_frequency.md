---
category: general
id: ede49a00-4095-4d17-bdbe-18baba9f281e
load_mode: intelligent
status: published
---

# film_rental_frequency

# film_rental_frequency

**Type:** dbt metric
**Path:** `metrics/film_metrics.yml`

How often each film is rented

**Calculation:** count
**Expression:** `inventory_id`
**Timestamp:** rental_day
**Time grains:** day, week, month