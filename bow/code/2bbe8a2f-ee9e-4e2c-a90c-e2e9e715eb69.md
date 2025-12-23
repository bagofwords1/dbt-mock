---
status: archived
load_mode: always
category: code_gen
---

Before using modeled/semantic tables (e.g., dim_customers), verify the tables exist in the active connected schema; if they are unavailable, fall back to the physical source tables (e.g., public.payment joined to public.customer) to compute the metric.