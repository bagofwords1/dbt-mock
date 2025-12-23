---
category: general
id: 4e9958cc-6342-4ed8-9d86-0ad0ef4ee3fe
load_mode: intelligent
status: published
---

# fact_daily_rentals

# fact_daily_rentals

**Type:** dbt model
**Path:** `models/dvdrental/facts/fact_daily_rentals.sql`

## SQL

```sql
with rental_base as (
    select * from {{ ref('stg_rentals') }}
),

daily_rentals as (
    select 
        date_trunc('day', rental_date) as rental_day,
        store_id,
        count(*) as total_rentals,
        count(distinct customer_id) as unique_customers,
        count(distinct inventory_id) as unique_films
    from rental_base
    group by 1, 2
)

select
    rental_day,
    store_id,
    total_rentals,
    unique_customers,
    unique_films
from daily_rentals 
```