---
category: general
id: 87ff57d8-333e-404e-8031-2111771a4476
load_mode: always
status: published
---

# docs/CUSTOMERS.md

# 👤 Customer Domain — DVD Rental Database

> **Purpose:** Understanding customer behavior, segmentation, and lifetime value.

---

## Domain Overview

The Customer domain tracks who rents DVDs, their activity status, geographic distribution, and spending patterns. This is the central entity for customer analytics, segmentation, and retention analysis.

```
┌──────────────────────────────────────────────────────────────┐
│                     CUSTOMER DOMAIN                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌─────────────┐         ┌─────────────┐                   │
│   │  CUSTOMER   │────────▶│   ADDRESS   │                   │
│   │             │         │   CITY      │                   │
│   │  • identity │         │   COUNTRY   │                   │
│   │  • status   │         └─────────────┘                   │
│   │  • spend    │                                           │
│   └──────┬──────┘                                           │
│          │                                                   │
│          ▼                                                   │
│   ┌─────────────────────────────────────┐                   │
│   │         DERIVED METRICS             │                   │
│   │  • total_rentals                    │                   │
│   │  • total_amount_paid                │                   │
│   │  • customer_lifetime_value          │                   │
│   │  • average_customer_spend           │                   │
│   └─────────────────────────────────────┘                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 📊 Tables & Columns

### `dim_customers`

Primary customer dimension table with enriched rental statistics.

| Column | Type | Description | Rules |
|--------|------|-------------|-------|
| `customer_id` | INTEGER | **Primary Key** | Unique, never null |
| `first_name` | VARCHAR(45) | First name | |
| `last_name` | VARCHAR(45) | Last name | |
| `email` | VARCHAR(50) | Email address | May be NULL |
| `active` | SMALLINT | Activity status | `1` = active, `0` = inactive |
| `create_date` | TIMESTAMP | Account creation | |
| `address` | VARCHAR(50) | Street address | Denormalized from address table |
| `city` | VARCHAR(50) | City | Denormalized |
| `country` | VARCHAR(50) | Country | Denormalized |
| `total_rentals` | INTEGER | Lifetime rentals | **Derived:** count from payments |
| `total_amount_paid` | DECIMAL(10,2) | Lifetime spend USD | **Derived:** sum from payments |

---

## 🔗 Relationships

```
dim_customers
    │
    ├──< fact_rentals         (customer_id → customer_id)
    ├──< fact_payments        (customer_id → customer_id)
    └──< fact_daily_rentals   (aggregated via customer_id)
```

**Join Patterns:**

```sql
-- Customer to their rentals
FROM dim_customers c
JOIN fact_rentals r ON c.customer_id = r.customer_id

-- Customer to their payments
FROM dim_customers c
JOIN stg_payments p ON c.customer_id = p.customer_id
```

---

## 📈 Available Metrics

| Metric | Calculation | Dimensions | Use Case |
|--------|-------------|------------|----------|
| `active_customers` | COUNT DISTINCT where active=1 | city, country | Active user count |
| `average_customer_spend` | AVG(total_amount_paid) | city, country | Spending benchmarks |
| `customer_lifetime_value` | SUM(total_amount_paid) | city, country | Revenue attribution |

---

## ⚠️ Business Rules

### Rule 1: Active Status
```
active = 1  →  Customer can rent DVDs
active = 0  →  Customer account is suspended/inactive
```
**Always filter by `active = 1`** when calculating operational metrics.

### Rule 2: New vs. Returning Customer
```sql
-- New customer: no prior rentals before a given date
-- Returning: has rental history
CASE 
    WHEN total_rentals = 0 OR total_rentals IS NULL THEN 'new'
    ELSE 'returning'
END AS customer_type
```

### Rule 3: Customer Segmentation by Value
```sql
CASE 
    WHEN total_amount_paid >= 150 THEN 'high_value'
    WHEN total_amount_paid >= 75 THEN 'medium_value'
    WHEN total_amount_paid > 0 THEN 'low_value'
    ELSE 'no_purchases'
END AS customer_segment
```

### Rule 4: Geographic Hierarchy
```
country → city → address → customer
```
Use `country` for highest-level aggregation, `city` for regional analysis.

---

## 🔍 Sample Queries

### Get all active customers with their spending
```sql
SELECT 
    customer_id,
    first_name || ' ' || last_name AS full_name,
    email,
    city,
    country,
    total_rentals,
    total_amount_paid
FROM dim_customers
WHERE active = 1
ORDER BY total_amount_paid DESC NULLS LAST;
```

### Customer count by country
```sql
SELECT 
    country,
    COUNT(*) AS total_customers,
    COUNT(*) FILTER (WHERE active = 1) AS active_customers,
    ROUND(AVG(total_amount_paid), 2) AS avg_spend
FROM dim_customers
GROUP BY country
ORDER BY total_customers DESC;
```

### High-value customers (top 10%)
```sql
WITH ranked AS (
    SELECT 
        *,
        PERCENT_RANK() OVER (ORDER BY total_amount_paid DESC) AS pct_rank
    FROM dim_customers
    WHERE total_amount_paid IS NOT NULL
)
SELECT * FROM ranked
WHERE pct_rank <= 0.10;
```

### Customers with no rentals (churn candidates)
```sql
SELECT 
    customer_id,
    first_name,
    last_name,
    email,
    create_date
FROM dim_customers
WHERE total_rentals IS NULL OR total_rentals = 0;
```

---

## 🚫 Common Mistakes to Avoid

| ❌ Don't | ✅ Do Instead |
|----------|---------------|
| Count all customers for operational metrics | Filter `WHERE active = 1` |
| Assume `total_amount_paid` is never NULL | Handle NULLs: `COALESCE(total_amount_paid, 0)` |
| Join customers directly to inventory | Join through `fact_rentals` |
| Use email as unique identifier | Use `customer_id` (email may be NULL) |

---

## 💡 LLM Query Guidelines

When asked about customers:

1. **"Who are the best customers?"** → Use `total_amount_paid DESC`
2. **"How many active users?"** → Filter `active = 1`, use COUNT
3. **"Customer distribution by region"** → Group by `country` or `city`
4. **"Customer lifetime value"** → Use `customer_lifetime_value` metric or `total_amount_paid`
5. **"Inactive customers"** → Filter `active = 0`

