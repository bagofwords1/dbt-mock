---
category: code_gen
id: 2bbe8a2f-ee9e-4e2c-a90c-e2e9e715eb69
load_mode: always
status: draft
---

Before using modeled/semantic tables (e.g., dim_customers), verify the tables exist in the active connected schema; if they are unavailable, fall back to the physical source tables (e.g., public.payment joined to public.customer) to compute the metric.