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