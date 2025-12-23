---
category: general
load_mode: intelligent
references:
- public.payment
- public.rental
status: archived
---

# docs/REVENUE_PAYMENTS.md

# 💰 Revenue & Payments Domain — DVD Rental Database
great
> **Purpose:** Financial analysis, revenue tracking, payment processing, and monetary metrics.

---

## Domain Overview

The Revenue domain tracks all monetary transactions. Every rental generates a payment, connecting customers to revenue through staff-processed transactions at specific stores.

```
┌────────────────────────────────────────────────────────────────────────────┐
│                       REVENUE & PAYMENTS DOMAIN                             │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   ┌─────────────┐                                                          │
│   │   RENTAL    │──────────────┐                                           │
│   └─────────────┘              │                                           │
│          │                     ▼                                           │
│          │              ┌─────────────┐                                    │
│          │              │   PAYMENT   │                                    │
│          │              │             │                                    │
│          │              │  • amount   │◀────────── STAFF                   │
│          │              │  • date     │                │                   │
│          │              │  • method   │                │                   │
│          │              └──────┬──────┘                ▼                   │
│          │                     │                 ┌─────────────┐           │
│          ▼                     ▼                 │    STORE    │           │
│   ┌─────────────┐       ┌─────────────┐         └─────────────┘           │
│   │  CUSTOMER   │       │   REVENUE   │                                    │
│   │  (payer)    │       │  METRICS    │                                    │
│   └─────────────┘       │             │                                    │
│                         │ • total_revenue                                  │
│                         │ • avg_transaction                                │
│                         │ • revenue_by_store                               │
│                         │ • revenue_by_film                                │
│                         └─────────────┘                                    │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Tables & Columns

### `stg_payments` / `fact_payments`

Individual payment transactions.

| Column | Type | Description | Rules |
|--------|------|-------------|-------|
| `payment_id` | INTEGER | **Primary Key** | Unique |
| `customer_id` | INTEGER | FK → customer who paid | |
| `staff_id` | INTEGER | FK → employee who processed | |
| `rental_id` | INTEGER | FK → associated rental | |
| `amount` | DECIMAL(5,2) | Payment amount in **USD** | Always positive |
| `payment_date` | TIMESTAMP | When payment was made | |

### Payment ↔ Customer Summary (in `dim_customers`)

| Column | Type | Description |
|--------|------|-------------|
| `total_amount_paid` | DECIMAL(10,2) | Lifetime customer spend |
| `total_rentals` | INTEGER | Count of payment records |

---

## 🔗 Relationships

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│ dim_customers│◀────────│ stg_payments │────────▶│  dim_staff   │
└──────────────┘         └──────┬───────┘         └──────────────┘
                               │
                               │ rental_id
                               ▼
                        ┌──────────────┐
                        │  stg_rentals │
                        └──────┬───────┘
                               │
                               │ inventory_id
                               ▼
                        ┌──────────────┐
                        │  dim_films   │
                        └──────────────┘
```

**Revenue to Film Path:**
```sql
-- To get revenue by film:
stg_payments → stg_rentals → stg_inventory → dim_films
```

---

## 📈 Available Metrics

| Metric | Calculation | Time Grains | Dimensions |
|--------|-------------|-------------|------------|
| `total_rental_revenue` | SUM(amount) | day, week, month, quarter, year | staff_id, store_id, customer_id |
| `film_revenue` | SUM(amount) by film | day, week, month | film_id, category_id, rating |

---

## 💵 Currency & Amounts

| Property | Value |
|----------|-------|
| **Currency** | USD (US Dollars) |
| **Precision** | 2 decimal places |
| **Typical Range** | $0.99 – $9.99 per rental |
| **Storage** | DECIMAL(5,2) for single, DECIMAL(10,2) for aggregates |

---

## ⚠️ Business Rules

### Rule 1: Payment-Rental Relationship
Every payment maps to exactly ONE rental.
```sql
-- One payment per rental (1:1)
payment.rental_id → rental.rental_id
```

### Rule 2: Payment Timing
Payments are processed at checkout (rental start), not return.
```sql
-- Payment date ≈ Rental date
payment_date ≈ rental_date  -- Same day typically
```

### Rule 3: Amount Validation
```sql
-- Valid payment amounts
amount > 0              -- Always positive
amount <= 10.00         -- Typical ceiling for DVD rental
```

### Rule 4: Revenue Recognition
Revenue is recognized at payment date, not rental completion.
```sql
-- Revenue by period
SELECT DATE_TRUNC('month', payment_date), SUM(amount)
FROM stg_payments
GROUP BY 1;
```

### Rule 5: Staff Commission Attribution
The `staff_id` on payment indicates who processed and gets credit.
```sql
-- Sales by staff member
SELECT staff_id, SUM(amount) AS total_sales
FROM stg_payments
GROUP BY staff_id;
```

---

## 🔍 Sample Queries

### Total revenue by period
```sql
SELECT 
    DATE_TRUNC('month', payment_date) AS revenue_month,
    COUNT(*) AS transactions,
    SUM(amount) AS total_revenue,
    ROUND(AVG(amount), 2) AS avg_transaction
FROM stg_payments
GROUP BY 1
ORDER BY 1 DESC;
```

### Revenue by store
```sql
SELECT 
    s.store_id,
    COUNT(p.payment_id) AS transactions,
    SUM(p.amount) AS total_revenue,
    ROUND(AVG(p.amount), 2) AS avg_transaction
FROM stg_payments p
JOIN dim_staff s ON p.staff_id = s.staff_id
GROUP BY s.store_id
ORDER BY total_revenue DESC;
```

### Top 10 revenue-generating customers
```sql
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.total_amount_paid AS lifetime_value,
    c.total_rentals,
    ROUND(c.total_amount_paid / NULLIF(c.total_rentals, 0), 2) AS avg_per_rental
FROM dim_customers c
WHERE c.total_amount_paid IS NOT NULL
ORDER BY c.total_amount_paid DESC
LIMIT 10;
```

### Revenue by film category
```sql
SELECT 
    f.category_name,
    COUNT(*) AS rentals,
    SUM(p.amount) AS category_revenue,
    ROUND(AVG(p.amount), 2) AS avg_rental_price
FROM stg_payments p
JOIN stg_rentals r ON p.rental_id = r.rental_id
JOIN stg_inventory i ON r.inventory_id = i.inventory_id
JOIN dim_films f ON i.film_id = f.film_id
GROUP BY f.category_name
ORDER BY category_revenue DESC;
```

### Daily revenue trend with 7-day moving average
```sql
WITH daily_revenue AS (
    SELECT 
        DATE_TRUNC('day', payment_date) AS revenue_date,
        SUM(amount) AS daily_total
    FROM stg_payments
    GROUP BY 1
)
SELECT 
    revenue_date,
    daily_total,
    ROUND(AVG(daily_total) OVER (
        ORDER BY revenue_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_7d
FROM daily_revenue
ORDER BY revenue_date DESC
LIMIT 30;
```

### Revenue by staff member (sales performance)
```sql
SELECT 
    s.staff_id,
    s.first_name || ' ' || s.last_name AS staff_name,
    s.store_id,
    COUNT(p.payment_id) AS transactions_processed,
    SUM(p.amount) AS total_revenue,
    ROUND(AVG(p.amount), 2) AS avg_transaction
FROM stg_payments p
JOIN dim_staff s ON p.staff_id = s.staff_id
GROUP BY s.staff_id, s.first_name, s.last_name, s.store_id
ORDER BY total_revenue DESC;
```

---

## 📊 Key Financial KPIs

| KPI | Formula | Query Pattern |
|-----|---------|---------------|
| **Total Revenue** | SUM(amount) | `SELECT SUM(amount) FROM stg_payments` |
| **Average Transaction Value** | AVG(amount) | `SELECT AVG(amount) FROM stg_payments` |
| **Revenue per Customer** | SUM(amount) / COUNT(DISTINCT customer_id) | Divide totals |
| **Daily Run Rate** | Total Revenue / Days | Revenue ÷ date range |
| **Month-over-Month Growth** | (This Month - Last Month) / Last Month | Window functions |

---

## 🚫 Common Mistakes to Avoid

| ❌ Don't | ✅ Do Instead |
|----------|---------------|
| Assume all rentals have payments | Use LEFT JOIN from rentals to payments |
| Double-count via duplicate joins | Use DISTINCT or proper grain |
| Use `rental_date` for revenue timing | Use `payment_date` for financial reporting |
| Sum `total_amount_paid` from dim_customers for period revenue | Query stg_payments with date filters |
| Ignore NULL amounts | Handle with `COALESCE(amount, 0)` |

---

## 💡 LLM Query Guidelines

When asked about revenue/payments:

1. **"What's total revenue?"** → `SUM(amount)` from stg_payments
2. **"Revenue by month/week/day?"** → `DATE_TRUNC` on payment_date
3. **"Top paying customers?"** → Use `total_amount_paid` from dim_customers
4. **"Revenue by film/category?"** → Join payments → rentals → inventory → films
5. **"Average transaction value?"** → `AVG(amount)` from stg_payments
6. **"Staff sales performance?"** → Group by staff_id
7. **"Store revenue comparison?"** → Join to staff → group by store_id

