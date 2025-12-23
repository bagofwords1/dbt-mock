---
category: general
id: 644d0d59-a592-40d7-942f-70198ec3a962
load_mode: intelligent
status: published
---

# dim_customers

# dim_customers

**Type:** dbt model
**Path:** `models/dvdrental/dims/dim_customers.yml`

Dimension table for customers with their rental statistics

## Columns

- **customer_id**: Primary key of the customer dimension
- **first_name**: Customer's first name
- **last_name**: Customer's last name
- **email**: Customer's email address
- **active**: Whether the customer is active (1) or not (0)
- **total_rentals**: Total number of rentals by this customer
- **total_amount_paid**: Total amount paid by this customer

## SQL

```sql
with customer_base as (
    select * from {{ ref('stg_customers') }}
),

rental_stats as (
    select 
        customer_id,
        count(*) as total_rentals,
        sum(amount) as total_amount_paid
    from {{ ref('stg_payments') }}
    group by 1
)

select
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.active,
    c.create_date,
    c.address,
    c.city,
    c.country,
    r.total_rentals,
    r.total_amount_paid
from customer_base c
left join rental_stats r using(customer_id) 
```