---
status: published
load_mode: always
category: general
---

# docs/STORES_OPERATIONS.md

# 🏪 Stores & Operations Domain — DVD Rental Database

> **Purpose:** Store locations, staff management, and operational performance metrics.
hi hi
---

## Domain Overview

The Stores & Operations domain covers the physical business operations: where stores are located, who works there, and how each location performs. This is essential for multi-location business analysis.

```
┌────────────────────────────────────────────────────────────────────────────┐
│                     STORES & OPERATIONS DOMAIN                              │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│    ┌─────────────────────────────────────────────────────────────┐        │
│    │                      STORE                                   │        │
│    │                                                              │        │
│    │   ┌──────────────┐                                          │        │
│    │   │   LOCATION   │  • address                               │        │
│    │   │              │  • city                                  │        │
│    │   │              │  • country                               │        │
│    │   └──────────────┘                                          │        │
│    │          │                                                   │        │
│    │          ▼                                                   │        │
│    │   ┌──────────────┐                                          │        │
│    │   │    STAFF     │  • employees                             │        │
│    │   │   (team)     │  • manager                               │        │
│    │   └──────────────┘                                          │        │
│    │          │                                                   │        │
│    └──────────┼──────────────────────────────────────────────────┘        │
│               │                                                            │
│               ▼                                                            │
│    ┌─────────────────────────────────────────────────────────────┐        │
│    │                  OPERATIONS                                  │        │
│    │                                                              │        │
│    │   INVENTORY ◀──────── STORE ────────▶ RENTALS               │        │
│    │   (what's in stock)              (transactions)              │        │
│    │                                       │                      │        │
│    │                                       ▼                      │        │
│    │                                   PAYMENTS                   │        │
│    │                                   (revenue)                  │        │
│    └─────────────────────────────────────────────────────────────┘        │
│                                                                            │
│    ┌─────────────────────────────────────────────────────────────┐        │
│    │                    METRICS                                   │        │
│    │                                                              │        │
│    │   • Rentals per store         • Revenue per store           │        │
│    │   • Staff performance         • Inventory utilization       │        │
│    │   • Customer traffic          • Operational efficiency      │        │
│    └─────────────────────────────────────────────────────────────┘        │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Tables & Columns

### `dim_stores`

Store location dimension.

| Column | Type | Description | Rules |
|--------|------|-------------|-------|
| `store_id` | INTEGER | **Primary Key** | Unique |
| `manager_staff_id` | INTEGER | FK → staff (manager) | |
| `address` | VARCHAR(50) | Street address | |
| `city` | VARCHAR(50) | City | |
| `country` | VARCHAR(50) | Country | |

### `dim_staff`

Employee dimension.

| Column | Type | Description | Rules |
|--------|------|-------------|-------|
| `staff_id` | INTEGER | **Primary Key** | Unique |
| `first_name` | VARCHAR(45) | First name | |
| `last_name` | VARCHAR(45) | Last name | |
| `email` | VARCHAR(50) | Employee email | |
| `store_id` | INTEGER | FK → primary store | |
| `active` | BOOLEAN | Employment status | true = employed |
| `username` | VARCHAR(16) | System login | |

### `fact_daily_rentals` (Operations View)

Daily operational metrics by store.

| Column | Type | Description |
|--------|------|-------------|
| `rental_day` | DATE | Date |
| `store_id` | INTEGER | Store location |
| `total_rentals` | INTEGER | Transaction count |
| `unique_customers` | INTEGER | Customer traffic |
| `unique_films` | INTEGER | Product variety |

---

## 🔗 Relationships

```
┌──────────────┐         ┌──────────────┐
│  dim_stores  │◀───────▶│  dim_staff   │
└──────┬───────┘         └──────┬───────┘
       │                        │
       │ store_id               │ staff_id
       ▼                        ▼
┌──────────────┐         ┌──────────────┐
│stg_inventory │         │ stg_payments │
└──────────────┘         └──────────────┘
       │                        │
       │                        │
       └───────────┬────────────┘
                   ▼
            ┌──────────────┐
            │ stg_rentals  │
            └──────────────┘
                   │
                   ▼
            ┌──────────────┐
            │fact_daily_   │
            │rentals       │
            └──────────────┘
```

**Store Connections:**
- Store → Staff (1:Many) - employees assigned
- Store → Inventory (1:Many) - DVDs in stock
- Store → Rentals (1:Many) - transactions occurred
- Store → fact_daily_rentals (1:Many) - aggregated metrics

---

## 🏢 Store Configuration

Typical DVD Rental setup:

| Store ID | Role | Description |
|----------|------|-------------|
| 1 | Primary | Main location, larger inventory |
| 2 | Secondary | Branch location |

```sql
-- Store overview
SELECT 
    s.store_id,
    s.city || ', ' || s.country AS location,
    st.first_name || ' ' || st.last_name AS manager
FROM dim_stores s
JOIN dim_staff st ON s.manager_staff_id = st.staff_id;
```

---

## 👥 Staff Roles

| Role | Responsibilities | Identified By |
|------|-----------------|---------------|
| **Manager** | Store oversight, staff supervision | `store.manager_staff_id = staff.staff_id` |
| **Clerk** | Customer service, rental processing | Staff assigned to store |

---

## 📈 Operational Metrics

| Metric | Calculation | Use Case |
|--------|-------------|----------|
| **Rentals per Store** | SUM(total_rentals) by store_id | Volume comparison |
| **Customers per Day** | unique_customers from fact table | Traffic analysis |
| **Revenue per Store** | SUM(amount) by store | Financial performance |
| **Staff Productivity** | Revenue or Rentals per staff_id | Performance review |
| **Inventory Turnover** | Rentals / Inventory Count | Efficiency |

---

## ⚠️ Business Rules

### Rule 1: Staff Store Assignment
Each staff member is assigned to one primary store.
```sql
-- Staff by store
SELECT store_id, COUNT(*) AS staff_count
FROM dim_staff
WHERE active = true
GROUP BY store_id;
```

### Rule 2: Manager Identification
```sql
-- Find store managers
SELECT 
    s.store_id,
    st.first_name || ' ' || st.last_name AS manager_name
FROM dim_stores s
JOIN dim_staff st ON s.manager_staff_id = st.staff_id;
```

### Rule 3: Revenue Attribution
Revenue is attributed to the **staff member** who processed the payment, which links to their store.
```sql
-- Revenue by store (via staff)
SELECT 
    st.store_id,
    SUM(p.amount) AS store_revenue
FROM stg_payments p
JOIN dim_staff st ON p.staff_id = st.staff_id
GROUP BY st.store_id;
```

### Rule 4: Inventory Belongs to Store
Each inventory item (DVD copy) is permanently assigned to one store.
```sql
-- Inventory per store
SELECT store_id, COUNT(*) AS inventory_count
FROM stg_inventory
GROUP BY store_id;
```

### Rule 5: Active Staff Only
Filter by `active = true` for current employee analysis.
```sql
WHERE active = true  -- Only current employees
```

---

## 🔍 Sample Queries

### Store performance comparison
```sql
SELECT 
    fdr.store_id,
    s.city || ', ' || s.country AS location,
    SUM(fdr.total_rentals) AS total_rentals,
    SUM(fdr.unique_customers) AS total_customers,
    ROUND(AVG(fdr.total_rentals), 1) AS avg_daily_rentals
FROM fact_daily_rentals fdr
JOIN dim_stores s ON fdr.store_id = s.store_id
GROUP BY fdr.store_id, s.city, s.country
ORDER BY total_rentals DESC;
```

### Staff productivity (rentals processed)
```sql
SELECT 
    st.staff_id,
    st.first_name || ' ' || st.last_name AS staff_name,
    st.store_id,
    COUNT(r.rental_id) AS rentals_processed,
    SUM(p.amount) AS revenue_generated,
    ROUND(AVG(p.amount), 2) AS avg_transaction
FROM dim_staff st
LEFT JOIN stg_rentals r ON st.staff_id = r.staff_id
LEFT JOIN stg_payments p ON st.staff_id = p.staff_id
WHERE st.active = true
GROUP BY st.staff_id, st.first_name, st.last_name, st.store_id
ORDER BY revenue_generated DESC;
```

### Store revenue by month
```sql
SELECT 
    DATE_TRUNC('month', p.payment_date) AS revenue_month,
    st.store_id,
    COUNT(p.payment_id) AS transactions,
    SUM(p.amount) AS revenue
FROM stg_payments p
JOIN dim_staff st ON p.staff_id = st.staff_id
GROUP BY 1, 2
ORDER BY 1 DESC, 2;
```

### Inventory utilization by store
```sql
WITH inventory_counts AS (
    SELECT store_id, COUNT(*) AS total_inventory
    FROM stg_inventory
    GROUP BY store_id
),
rental_counts AS (
    SELECT store_id, SUM(total_rentals) AS total_rentals
    FROM fact_daily_rentals
    GROUP BY store_id
)
SELECT 
    i.store_id,
    s.city AS store_city,
    i.total_inventory,
    r.total_rentals,
    ROUND(r.total_rentals::DECIMAL / i.total_inventory, 2) AS rentals_per_copy
FROM inventory_counts i
JOIN rental_counts r ON i.store_id = r.store_id
JOIN dim_stores s ON i.store_id = s.store_id
ORDER BY rentals_per_copy DESC;
```

### Daily traffic pattern by store
```sql
SELECT 
    DAYNAME(rental_day) AS day_of_week,
    store_id,
    ROUND(AVG(unique_customers), 1) AS avg_customers,
    ROUND(AVG(total_rentals), 1) AS avg_rentals
FROM fact_daily_rentals
GROUP BY 1, 2, DAYOFWEEK(rental_day)
ORDER BY DAYOFWEEK(rental_day), store_id;
```

### Store-level customer value
```sql
SELECT 
    i.store_id,
    s.city AS store_location,
    COUNT(DISTINCT c.customer_id) AS customers,
    SUM(c.total_amount_paid) AS total_revenue,
    ROUND(AVG(c.total_amount_paid), 2) AS avg_customer_value
FROM dim_customers c
JOIN stg_rentals r ON c.customer_id = r.customer_id
JOIN stg_inventory i ON r.inventory_id = i.inventory_id
JOIN dim_stores s ON i.store_id = s.store_id
GROUP BY i.store_id, s.city
ORDER BY total_revenue DESC;
```

---

## 📊 Operational KPIs Dashboard

| KPI | Formula | Target |
|-----|---------|--------|
| **Daily Rentals** | SUM(total_rentals) | Track trend |
| **Customer Traffic** | unique_customers | Footfall |
| **Revenue per Employee** | Revenue / Staff Count | Productivity |
| **Inventory Turnover** | Annual Rentals / Inventory | Efficiency |
| **Avg Transaction Value** | Revenue / Transactions | Upsell success |

---

## 🚫 Common Mistakes to Avoid

| ❌ Don't | ✅ Do Instead |
|----------|---------------|
| Assume store_id is on payments | Join via staff_id to get store |
| Count inactive staff | Filter `WHERE active = true` |
| Use rental.store_id (may not exist) | Use inventory → store relationship |
| Compare stores without normalizing | Account for inventory size differences |
| Aggregate staff without store context | Always include store_id in staff analysis |

---

## 💡 LLM Query Guidelines

When asked about stores/operations:

1. **"Which store performs better?"** → Compare revenue/rentals by store_id
2. **"Who's the best employee?"** → Staff performance by transactions/revenue
3. **"Store locations?"** → Query dim_stores for address/city/country
4. **"How many staff at each store?"** → COUNT from dim_staff GROUP BY store_id
5. **"Store inventory size?"** → COUNT from stg_inventory GROUP BY store_id
6. **"Manager of store X?"** → Join dim_stores to dim_staff on manager_staff_id
7. **"Daily traffic by store?"** → Use fact_daily_rentals.unique_customers
8. **"Operational trends?"** → Time series on fact_daily_rentals by store

