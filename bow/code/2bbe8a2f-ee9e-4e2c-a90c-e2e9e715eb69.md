---
category: code_gen
load_mode: always
status: archived
---

Before using modeled/semantic tables (e.g., dim_customers), verify the tables exist in the active connected schema; if they are unavailable, fall back to the physical source tables (e.g., public.payment joined to public.customer) to compute the metric.