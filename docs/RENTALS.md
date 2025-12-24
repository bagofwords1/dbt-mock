# docs/RENTALS.md

# 📀 Rentals Domain — DVD Rental Database

> **Purpose:** Tracking rental transactions, patterns, duration, and operational volume.
123
---

## Domain Overview

The Rentals domain captures when DVDs are checked out and returned. It's the transactional heart of the business—connecting customers to films through inventory items at specific stores.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          RENTALS DOMAIN                                   │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│    CUSTOMER ─────┐                                                       │
│                  │                                                       │
│    INVENTORY ────┼────▶  RENTAL  ◀────── STAFF                          │
│    (film copy)   │         │              │                              │
│                  │         │              │                              │
│    STORE ────────┘         ▼              ▼                              │
│                      ┌──────────┐   ┌──────────┐                        │
│                      │ DURATION │   │ PAYMENT  │                        │
│                      │ (days)   │   │ (amount) │                        │
│                      └──────────┘   └──────────┘                        │
│                                                                          │
│    ┌─────────────────────────────────────────────────────────┐          │
│    │                  AGGREGATIONS                            │          │
│    │  fact_daily_rentals:                                     │          │
│    │    • total_rentals per store/day                        │          │
│    │    • unique_customers per store/day                     │          │
│    │    • unique_films per store/day                         │          │
│    └─────────────────────────────────────────────────────────┘          │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Tables & Columns

### `fact_daily_rentals`

Daily aggregated rental activity by store.

| Column | Type | Description | Derivation |
|--------|------|-------------|------------|
| `rental_day` | DATE | Date of activity | `DATE_TRUNC('day', rental_date)` |
| `store_id` | INTEGER | Store location | Group by |
| `total_rentals` | INTEGER | Rentals on this day | `COUNT(*)` |
| `unique_customers` | INTEGER | Distinct renters | `COUNT(DISTINCT customer_id)` |
| `unique_films` | INTEGER | Distinct DVDs rented | `COUNT(DISTINCT inventory_id)` |

### `stg_rentals` (Staging)

Raw rental transactions.

| Column | Type | Description | Rules |
|--------|------|-------------|-------|
| `rental_id` | INTEGER | **Primary Key** | Unique |
| `rental_date` | TIMESTAMP | Checkout timestamp | Never NULL |
| `inventory_id` | INTEGER | FK → inventory item | |
| `customer_id` | INTEGER | FK → customer | |
| `return_date` | TIMESTAMP | Return timestamp | **NULL = not returned** |
| `staff_id` | INTEGER | Employee who processed | |
| `store_id` | INTEGER | Store location | |

---

## 🔗 Relationships

```
                    ┌──────────────┐
                    │ dim_customers│
                    └──────┬───────┘
                           │
                           ▼
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│  dim_films  │◀───│  stg_rentals │───▶│  dim_staff  │
└─────────────┘    └──────┬───────┘    └─────────────┘
       ▲                  │                   │
       │                  │                   │
┌──────┴──────┐           ▼                   ▼
│ stg_inventory│   ┌──────────────┐    ┌─────────────┐
└─────────────┘    │ stg_payments │    │ dim_stores  │
                   └──────────────┘    └─────────────┘
```

**Key Foreign Keys:**
```sql
stg_rentals.customer_id    → dim_customers.customer_id
stg_rentals.inventory_id   → stg_inventory.inventory_id
stg_rentals.staff_id       → dim_staff.staff_id
stg_rentals.store_id       → dim_stores.store_id
stg_inventory.film_id      → dim_films.film_id
```

---

## 📈 Available Metrics

| Metric | Calculation | Time Grains | Dimensions |
|--------|-------------|-------------|------------|
| `rental_count` | SUM(total_rentals) | day, week, month, quarter, year | store_id |
| `average_rental_duration` | AVG(rental_duration) | day, week, month, quarter, year | — |

---

## 🧮 Rental Duration Calculation

Uses the `calculate_rental_duration` macro:

```sql
CASE 
    WHEN return_date IS NULL THEN 
        DATEDIFF('day', rental_date, CURRENT_DATE)  -- Still out
    ELSE 
        DATEDIFF('day', rental_date, return_date)   -- Returned
END AS rental_duration_days
```

**Important:** Unreturned DVDs calculate duration from rental date to today.

---

## ⚠️ Business Rules

### Rule 1: Rental Status
```sql
CASE 
    WHEN return_date IS NULL THEN 'outstanding'
    ELSE 'returned'
END AS rental_status
```

### Rule 2: Overdue Rentals
Standard rental period is **7 days**.
```sql
-- Overdue calculation
CASE 
    WHEN return_date IS NULL 
         AND DATEDIFF('day', rental_date, CURRENT_DATE) > 7 
    THEN 'overdue'
    WHEN return_date IS NOT NULL 
         AND DATEDIFF('day', rental_date, return_date) > 7 
    THEN 'late_return'
    ELSE 'on_time'
END AS rental_timing
```

### Rule 3: Same-Day Rentals
Multiple rentals by same customer on same day = single visit.
```sql
-- Count unique customer visits
COUNT(DISTINCT DATE_TRUNC('day', rental_date) || '-' || customer_id::text)
```

### Rule 4: Inventory Availability
A DVD (inventory_id) can only have ONE active rental at a time.
```sql
-- Find currently unavailable inventory
SELECT inventory_id 
FROM stg_rentals 
WHERE return_date IS NULL;
```

---

## 🔍 Sample Queries

### Daily rental volume trend
```sql
SELECT 
    rental_day,
    SUM(total_rentals) AS daily_rentals,
    SUM(unique_customers) AS daily_customers,
    ROUND(SUM(total_rentals)::DECIMAL / SUM(unique_customers), 2) AS rentals_per_customer
FROM fact_daily_rentals
GROUP BY rental_day
ORDER BY rental_day DESC
LIMIT 30;
```

### Rental volume by store
```sql
SELECT 
    store_id,
    SUM(total_rentals) AS total_rentals,
    ROUND(AVG(total_rentals), 1) AS avg_daily_rentals,
    SUM(unique_customers) AS total_customers
FROM fact_daily_rentals
GROUP BY store_id
ORDER BY total_rentals DESC;
```

### Outstanding (unreturned) rentals
```sql
SELECT 
    r.rental_id,
    r.rental_date,
    r.customer_id,
    r.inventory_id,
    DATEDIFF('day', r.rental_date, CURRENT_DATE) AS days_out
FROM stg_rentals r
WHERE r.return_date IS NULL
ORDER BY days_out DESC;
```

### Average rental duration by month
```sql
SELECT 
    DATE_TRUNC('month', rental_date) AS rental_month,
    COUNT(*) AS rentals,
    ROUND(AVG(
        CASE 
            WHEN return_date IS NULL THEN NULL  -- Exclude outstanding
            ELSE DATEDIFF('day', rental_date, return_date)
        END
    ), 1) AS avg_duration_days
FROM stg_rentals
WHERE return_date IS NOT NULL  -- Only completed rentals
GROUP BY 1
ORDER BY 1 DESC;
```

### Busiest rental days of week
```sql
SELECT 
    DAYNAME(rental_day) AS day_of_week,
    DAYOFWEEK(rental_day) AS day_num,
    AVG(total_rentals) AS avg_rentals
FROM fact_daily_rentals
GROUP BY 1, 2
ORDER BY day_num;
```

---

## 🚫 Common Mistakes to Avoid

| ❌ Don't | ✅ Do Instead |
|----------|---------------|
| Include NULL return_date in duration AVG | Filter `WHERE return_date IS NOT NULL` |
| Count `rental_id` for volume | Use pre-aggregated `total_rentals` from fact table |
| Assume all rentals have payments | Join with LEFT JOIN to payments |
| Use `inventory_id` as film identifier | Join to inventory → film for film details |

---

## 💡 LLM Query Guidelines

When asked about rentals:

1. **"How many rentals per day/week/month?"** → Use `fact_daily_rentals`, SUM `total_rentals`
2. **"What's the average rental duration?"** → Use macro logic, exclude NULL return_dates
3. **"Which store has most rentals?"** → Group by `store_id`
4. **"Overdue rentals?"** → Filter `return_date IS NULL` AND duration > 7
5. **"Rental trends?"** → Time series on `rental_day` from fact table
6. **"How many customers rented today?"** → Use `unique_customers` from fact table

