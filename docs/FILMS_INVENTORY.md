# 🎬 Films & Inventory Domain — DVD Rental Database

> **Purpose:** Film catalog, categories, ratings, and physical inventory management.

---

## Domain Overview

The Films & Inventory domain manages what's available to rent. Films are the logical catalog (titles, ratings, categories), while Inventory tracks the physical DVD copies that exist at each store.

```
┌────────────────────────────────────────────────────────────────────────────┐
│                      FILMS & INVENTORY DOMAIN                               │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   ┌─────────────────────────────────────────────────────────┐             │
│   │                    FILM CATALOG                          │             │
│   │                                                          │             │
│   │   ┌──────────┐      ┌──────────┐      ┌──────────┐     │             │
│   │   │  ACTORS  │◀────▶│   FILM   │◀────▶│ CATEGORY │     │             │
│   │   └──────────┘      └────┬─────┘      └──────────┘     │             │
│   │                          │                              │             │
│   │                          │ title, rating                │             │
│   │                          │ rental_rate, length          │             │
│   │                          │ release_year                 │             │
│   └──────────────────────────┼──────────────────────────────┘             │
│                              │                                             │
│                              ▼                                             │
│   ┌──────────────────────────────────────────────────────────┐            │
│   │                  PHYSICAL INVENTORY                       │            │
│   │                                                           │            │
│   │   ┌──────────────┐         ┌──────────────┐              │            │
│   │   │  INVENTORY   │────────▶│    STORE     │              │            │
│   │   │  (DVD copy)  │         │  (location)  │              │            │
│   │   └──────┬───────┘         └──────────────┘              │            │
│   │          │                                                │            │
│   │          │ One film → Many inventory items                │            │
│   │          │ Each copy at ONE store                         │            │
│   │          ▼                                                │            │
│   │   ┌──────────────┐                                       │            │
│   │   │   RENTALS    │  (inventory_id used for checkout)     │            │
│   │   └──────────────┘                                       │            │
│   └──────────────────────────────────────────────────────────┘            │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Tables & Columns

### `dim_films`

Film catalog dimension.

| Column | Type | Description | Rules |
|--------|------|-------------|-------|
| `film_id` | INTEGER | **Primary Key** | Unique |
| `title` | VARCHAR(255) | Film title | |
| `description` | TEXT | Plot summary | |
| `release_year` | YEAR | Year released | 4-digit year |
| `rental_rate` | DECIMAL(4,2) | Price per rental | USD |
| `length` | SMALLINT | Duration in minutes | |
| `replacement_cost` | DECIMAL(5,2) | Cost if lost/damaged | USD |
| `rating` | VARCHAR(5) | MPAA rating | See ratings below |
| `category_id` | INTEGER | FK → category | |
| `category_name` | VARCHAR(25) | Genre name | Denormalized |

### `stg_inventory`

Physical DVD copies.

| Column | Type | Description | Rules |
|--------|------|-------------|-------|
| `inventory_id` | INTEGER | **Primary Key** | Unique per physical copy |
| `film_id` | INTEGER | FK → film | Multiple copies per film |
| `store_id` | INTEGER | FK → store location | Each copy at ONE store |

### `dim_categories`

Film genre categories.

| Column | Type | Description |
|--------|------|-------------|
| `category_id` | INTEGER | **Primary Key** |
| `category_name` | VARCHAR(25) | Genre name |

---

## 🎭 MPAA Film Ratings

| Rating | Description | Typical Audience |
|--------|-------------|------------------|
| `G` | General Audiences | All ages |
| `PG` | Parental Guidance Suggested | Some material may not suit children |
| `PG-13` | Parents Strongly Cautioned | Some material inappropriate for under 13 |
| `R` | Restricted | Under 17 requires parent/guardian |
| `NC-17` | Adults Only | No one 17 and under admitted |

```sql
-- Filter by rating
WHERE rating IN ('G', 'PG')           -- Family-friendly
WHERE rating IN ('R', 'NC-17')        -- Adult content
```

---

## 📂 Film Categories (Genres)

Typical categories in the DVD rental catalog:

| Category | Example Films |
|----------|---------------|
| Action | Die Hard, The Matrix |
| Animation | Finding Nemo, Shrek |
| Comedy | The Hangover, Bridesmaids |
| Drama | The Shawshank Redemption |
| Documentary | March of the Penguins |
| Family | Home Alone |
| Horror | The Ring, Scream |
| Music | School of Rock |
| Sci-Fi | Star Wars, Blade Runner |
| Sports | Rocky, Remember the Titans |

---

## 🔗 Relationships

```
┌──────────────┐         ┌──────────────┐
│   dim_films  │◀───────▶│dim_categories│
└──────┬───────┘         └──────────────┘
       │
       │ 1:Many
       ▼
┌──────────────┐         ┌──────────────┐
│stg_inventory │────────▶│  dim_stores  │
└──────┬───────┘         └──────────────┘
       │
       │ 1:Many
       ▼
┌──────────────┐
│ stg_rentals  │
└──────────────┘
```

**Key Cardinalities:**
- One **film** → Many **inventory items** (copies)
- One **inventory item** → One **store**
- One **inventory item** → Many **rentals** (over time)
- One **film** → One **category**

---

## 📈 Available Metrics

| Metric | Calculation | Time Grains | Dimensions |
|--------|-------------|-------------|------------|
| `film_rental_frequency` | COUNT(inventory_id) | day, week, month | film_id, category_id, rating |
| `film_revenue` | SUM(amount) | day, week, month | film_id, category_id, rating |
| `average_film_rating` | AVG(rental_rate) | — | rating, category_id |

---

## ⚠️ Business Rules

### Rule 1: Film vs. Inventory
```
FILM = logical title (e.g., "The Matrix")
INVENTORY = physical copy (e.g., DVD #4521 at Store 1)
```
Always join through `inventory_id` for rental analysis.

### Rule 2: Inventory Availability
```sql
-- Available copies (not currently rented)
SELECT i.inventory_id, f.title
FROM stg_inventory i
JOIN dim_films f ON i.film_id = f.film_id
WHERE i.inventory_id NOT IN (
    SELECT inventory_id 
    FROM stg_rentals 
    WHERE return_date IS NULL
);
```

### Rule 3: Store-Specific Inventory
Each inventory item belongs to exactly one store. Customers can only rent from their store's inventory.
```sql
-- Inventory by store
SELECT store_id, COUNT(*) AS total_copies
FROM stg_inventory
GROUP BY store_id;
```

### Rule 4: Rental Rate = Standard Price
The `rental_rate` on `dim_films` is the standard price charged per rental of that film.

### Rule 5: Replacement Cost
If a DVD is not returned or damaged, the `replacement_cost` is charged to the customer.

---

## 🔍 Sample Queries

### Film catalog overview
```sql
SELECT 
    film_id,
    title,
    release_year,
    rating,
    category_name,
    rental_rate,
    length AS duration_minutes
FROM dim_films
ORDER BY title;
```

### Inventory count by film
```sql
SELECT 
    f.film_id,
    f.title,
    f.rating,
    COUNT(i.inventory_id) AS total_copies,
    COUNT(DISTINCT i.store_id) AS stores_stocking
FROM dim_films f
LEFT JOIN stg_inventory i ON f.film_id = i.film_id
GROUP BY f.film_id, f.title, f.rating
ORDER BY total_copies DESC;
```

### Most rented films (all time)
```sql
SELECT 
    f.film_id,
    f.title,
    f.category_name,
    f.rating,
    COUNT(r.rental_id) AS total_rentals
FROM dim_films f
JOIN stg_inventory i ON f.film_id = i.film_id
JOIN stg_rentals r ON i.inventory_id = r.inventory_id
GROUP BY f.film_id, f.title, f.category_name, f.rating
ORDER BY total_rentals DESC
LIMIT 20;
```

### Revenue by film
```sql
SELECT 
    f.film_id,
    f.title,
    f.category_name,
    COUNT(p.payment_id) AS rentals,
    SUM(p.amount) AS total_revenue,
    ROUND(AVG(p.amount), 2) AS avg_revenue_per_rental
FROM dim_films f
JOIN stg_inventory i ON f.film_id = i.film_id
JOIN stg_rentals r ON i.inventory_id = r.inventory_id
JOIN stg_payments p ON r.rental_id = p.rental_id
GROUP BY f.film_id, f.title, f.category_name
ORDER BY total_revenue DESC
LIMIT 20;
```

### Films by category with rental stats
```sql
SELECT 
    f.category_name,
    COUNT(DISTINCT f.film_id) AS film_count,
    COUNT(DISTINCT i.inventory_id) AS total_copies,
    COUNT(r.rental_id) AS total_rentals,
    ROUND(COUNT(r.rental_id)::DECIMAL / COUNT(DISTINCT f.film_id), 1) AS avg_rentals_per_film
FROM dim_films f
LEFT JOIN stg_inventory i ON f.film_id = i.film_id
LEFT JOIN stg_rentals r ON i.inventory_id = r.inventory_id
GROUP BY f.category_name
ORDER BY total_rentals DESC;
```

### Available inventory by store and category
```sql
WITH rented_out AS (
    SELECT inventory_id 
    FROM stg_rentals 
    WHERE return_date IS NULL
)
SELECT 
    i.store_id,
    f.category_name,
    COUNT(i.inventory_id) AS total_copies,
    COUNT(i.inventory_id) FILTER (WHERE i.inventory_id NOT IN (SELECT * FROM rented_out)) AS available_copies
FROM stg_inventory i
JOIN dim_films f ON i.film_id = f.film_id
GROUP BY i.store_id, f.category_name
ORDER BY i.store_id, f.category_name;
```

---

## 🚫 Common Mistakes to Avoid

| ❌ Don't | ✅ Do Instead |
|----------|---------------|
| Use `film_id` directly in rental queries | Join through `inventory_id` |
| Assume every film has inventory | Use LEFT JOIN from films to inventory |
| Count films when you mean copies | Distinguish `film_id` vs `inventory_id` |
| Ignore store_id when checking availability | Filter by store for location-specific inventory |
| Use `rental_rate` as actual revenue | Use `amount` from payments for actual revenue |

---

## 💡 LLM Query Guidelines

When asked about films/inventory:

1. **"What films are available?"** → dim_films, optionally filter by rating/category
2. **"How many copies of X?"** → COUNT from stg_inventory WHERE film_id = X
3. **"Most popular films?"** → Join to rentals, COUNT by film_id
4. **"Films by category/genre?"** → Filter or group by category_name
5. **"What's in stock at store X?"** → Filter inventory by store_id, exclude active rentals
6. **"Revenue by film?"** → Full join path: films → inventory → rentals → payments
7. **"Family-friendly films?"** → Filter `rating IN ('G', 'PG')`

