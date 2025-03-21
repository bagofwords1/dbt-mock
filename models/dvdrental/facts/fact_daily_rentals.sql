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