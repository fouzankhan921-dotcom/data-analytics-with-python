-- ============================================================
--  ASSIGNMENT 11 — Window Functions
--  Database : BikeStores
--  Topics   : OVER(), PARTITION BY, ROW_NUMBER, RANK,
--             DENSE_RANK, LAG, LEAD, running totals,
--             window functions with CTEs
-- ============================================================


-- ============================================================
--  Question 1 — Aggregate as a Window Function
--  a) Return product_name, list_price and the overall average
--     list_price of all products as a column named overall_avg
--     (use AVG with an empty OVER()).
--  b) Extend the query to add price_difference, i.e. each
--     product's list_price minus overall_avg.
--  c) Explain in a comment how this differs from using
--     GROUP BY with AVG.
-- ============================================================

-- Part a:

SELECT product_name,
       list_price,
       AVG(list_price) OVER () AS overall_avg
FROM production.products;

-- Part b:

SELECT product_name,
       list_price,
       AVG(list_price) OVER ()               AS overall_avg,
       list_price - AVG(list_price) OVER ()  AS price_difference
FROM production.products;

-- Part c (answer as a comment):

-- GROUP BY AVG(...)   → collapses rows into 1 summary row (loses product details).
-- AVG(...) OVER ()    → keeps every row, broadcasts the same average onto all.
--                       Enables per-row columns like price_difference alongside
--                       a global aggregate in the same SELECT list.


-- ============================================================
--  Question 2 — PARTITION BY
--  a) Return product_name, category_id, list_price and the
--     average list_price of that product's category as
--     category_avg_price (rounded to 2 decimals).
--  b) Return product_name, brand_id, list_price and the
--     MAX list_price within the brand as brand_max_price.
--  c) Return order_id, item_id, product_id, quantity and the
--     total quantity of the whole order as order_total_qty
--     (from sales.order_items).
-- ============================================================

-- Part a:

SELECT product_name,
       category_id,
       list_price,
       ROUND(AVG(list_price) OVER (PARTITION BY category_id), 2) AS category_avg_price
FROM production.products
ORDER BY category_id, product_name;

-- Part b:

SELECT product_name,
       brand_id,
       list_price,
       MAX(list_price) OVER (PARTITION BY brand_id) AS brand_max_price
FROM production.products
ORDER BY brand_id, list_price DESC;

-- Part c:

SELECT order_id,
       item_id,
       product_id,
       quantity,
       SUM(quantity) OVER (PARTITION BY order_id) AS order_total_qty
FROM sales.order_items
ORDER BY order_id, item_id;


-- ============================================================
--  Question 3 — ROW_NUMBER
--  a) Assign a sequential number to every customer ordered by
--     last_name, then first_name. Show row_num, first_name,
--     last_name and city.
--  b) Restart the numbering for each city (PARTITION BY city),
--     ordered by first_name.
--  c) For each category_id, number the products from the most
--     expensive to the cheapest. Show category_id,
--     product_name, list_price and row_num.
-- ============================================================

-- Part a:

SELECT ROW_NUMBER() OVER (ORDER BY last_name, first_name) AS row_num,
       first_name,
       last_name,
       city
FROM sales.customers
ORDER BY row_num;

-- Part b:

SELECT ROW_NUMBER() OVER (PARTITION BY city ORDER BY first_name) AS row_num,
       first_name,
       last_name,
       city
FROM sales.customers
ORDER BY city, row_num;

-- Part c:

SELECT ROW_NUMBER() OVER (PARTITION BY category_id
                          ORDER BY list_price DESC) AS row_num,
       category_id,
       product_name,
       list_price
FROM production.products
ORDER BY category_id, row_num;


-- ============================================================
--  Question 4 — Top N per Group
--  a) Return the 3 most expensive products of EACH category.
--     Show category_id, product_name, list_price.
--     Hint: use ROW_NUMBER inside a CTE or derived table, then
--     filter on it in the outer query (window functions cannot
--     be used directly in WHERE).
--  b) Return the most recent order of EACH customer.
--     Show customer_id, order_id and order_date.
-- ============================================================

-- Part a:

WITH ranked AS (
    SELECT ROW_NUMBER() OVER (PARTITION BY category_id
                              ORDER BY list_price DESC,
                                       product_id ASC) AS row_num,
           category_id,
           product_name,
           list_price
    FROM production.products
)
SELECT category_id,
       product_name,
       list_price
FROM ranked
WHERE row_num <= 3
ORDER BY category_id, row_num;

-- Part b:

WITH ranked AS (
    SELECT ROW_NUMBER() OVER (PARTITION BY customer_id
                              ORDER BY order_date DESC,
                                       order_id   DESC) AS rn,
           customer_id,
           order_id,
           order_date
    FROM sales.orders
)
SELECT customer_id,
       order_id,
       order_date
FROM ranked
WHERE rn = 1
ORDER BY customer_id;


-- ============================================================
--  Question 5 — RANK vs DENSE_RANK
--  a) Rank all products by list_price (highest first) using
--     both RANK() and DENSE_RANK() in the same query. Show
--     product_name, list_price, price_rank and dense_price_rank.
--  b) Do the same ranking, but restart it inside each brand_id
--     (PARTITION BY brand_id).
--  c) Explain in a comment what happens to the numbers after
--     a tie with RANK and with DENSE_RANK. Point to a row from
--     your own result as an example.
-- ============================================================

-- Part a:

SELECT product_name,
       list_price,
       RANK()       OVER (ORDER BY list_price DESC) AS price_rank,
       DENSE_RANK() OVER (ORDER BY list_price DESC) AS dense_price_rank
FROM production.products
ORDER BY list_price DESC, product_name;

-- Part b:

SELECT product_name,
       brand_id,
       list_price,
       RANK()       OVER (PARTITION BY brand_id ORDER BY list_price DESC) AS price_rank,
       DENSE_RANK() OVER (PARTITION BY brand_id ORDER BY list_price DESC) AS dense_price_rank
FROM production.products
ORDER BY brand_id,
         list_price DESC,
         product_name;

-- Part c (answer as a comment):

-- After a tie, RANK() skips numbers (1, 1, 3) — gaps preserve "position."
-- DENSE_RANK() never skips (1, 1, 2) — no gaps preserves "tier."
-- Example above: two Trek bikes at $11,999.99 → next price $8,499.99 gets
-- price_rank = 3 but dense_price_rank = 2.


-- ============================================================
--  Question 6 — Ranking with Aggregates
--  Calculate the total revenue of each customer
--  (SUM(quantity * list_price * (1 - discount))) and rank the
--  customers from the highest spender to the lowest using
--  DENSE_RANK. Show customer_id, total_spent and spend_rank.
--  Hint: aggregate in a CTE first, then apply the window
--  function in the next step.
-- ============================================================

-- Write your query below:

WITH customer_spend AS (
    SELECT o.customer_id,
           SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_spent
    FROM sales.order_items AS oi
    JOIN sales.orders     AS o ON o.order_id = oi.order_id
    GROUP BY o.customer_id
)
SELECT customer_id,
       total_spent,
       DENSE_RANK() OVER (ORDER BY total_spent DESC) AS spend_rank
FROM customer_spend
ORDER BY spend_rank, customer_id;


-- ============================================================
--  Question 7 — LAG
--  For the brand 'Electra' in the year 2018, calculate the net
--  sales per month (SUM(quantity * list_price * (1 - discount))).
--  Then use LAG to show:
--    month, net_sales, previous_month_sales and the percentage
--    change versus the previous month.
--  Hint: a CTE for the monthly sales, a second step for LAG.
-- ============================================================

-- Write your query below:

WITH monthly_sales AS (
    SELECT MONTH(o.order_date)                                        AS month_num,
           SUM(oi.quantity * oi.list_price * (1 - oi.discount))       AS net_sales
    FROM sales.order_items  AS oi
    JOIN sales.orders       AS o  ON o.order_id   = oi.order_id
    JOIN production.products AS p ON p.product_id = oi.product_id
    JOIN production.brands   AS b ON b.brand_id   = p.brand_id
    WHERE b.brand_name = 'Electra'
      AND o.order_date >= '2018-01-01'
      AND o.order_date <  '2019-01-01'
    GROUP BY MONTH(o.order_date)
),
with_lag AS (
    SELECT month_num,
           net_sales,
           LAG(net_sales) OVER (ORDER BY month_num) AS previous_month_sales
    FROM monthly_sales
)
SELECT month_num                                                     AS month,
       net_sales,
       previous_month_sales,
       ROUND(100.0 * (net_sales - previous_month_sales)
             / NULLIF(previous_month_sales, 0), 2)                   AS percentage_change
FROM with_lag
ORDER BY month_num;


-- ============================================================
--  Question 8 — LEAD
--  a) For each customer, show order_id, order_date and the
--     order_date of their NEXT order as next_order_date.
--  b) Add a column days_to_next_order using DATEDIFF.
--     Orders with no next order should show NULL.
--  c) Repeat part (a) but use the third argument of LEAD to
--     replace NULL with '2099-12-31'.
-- ============================================================

-- Part a:

SELECT customer_id,
       order_id,
       order_date,
       LEAD(order_date) OVER (PARTITION BY customer_id
                              ORDER BY order_date,
                                       order_id) AS next_order_date
FROM sales.orders
ORDER BY customer_id, order_date, order_id;

-- Part b:

WITH order_neighbors AS (
    SELECT customer_id,
           order_id,
           order_date,
           LEAD(order_date) OVER (PARTITION BY customer_id
                                  ORDER BY order_date, order_id) AS next_order_date
    FROM sales.orders
)
SELECT customer_id,
       order_id,
       order_date,
       next_order_date,
       DATEDIFF(DAY, order_date, next_order_date) AS days_to_next_order
FROM order_neighbors
ORDER BY customer_id, order_date, order_id;

-- Part c:

WITH order_neighbors AS (
    SELECT customer_id,
           order_id,
           order_date,
           LEAD(order_date, 1, CAST('2099-12-31' AS DATE)) OVER (
               PARTITION BY customer_id
               ORDER BY order_date, order_id
           ) AS next_order_date
    FROM sales.orders
)
SELECT customer_id,
       order_id,
       order_date,
       next_order_date,
       DATEDIFF(DAY, order_date, next_order_date) AS days_to_next_order
FROM order_neighbors
ORDER BY customer_id, order_date, order_id;


-- ============================================================
--  Question 9 — Running Total
--  a) Show each order's order_id, order_date and its total
--     order value, together with a running total of the order
--     value ordered by order_date, order_id.
--     Hint: SUM(...) OVER (ORDER BY order_date, order_id).
--  b) Restart the running total for every store_id
--     (PARTITION BY store_id).
-- ============================================================

-- Part a:

WITH order_value AS (
    SELECT o.order_id,
           o.order_date,
           SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS order_value
    FROM sales.orders      AS o
    JOIN sales.order_items AS oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, o.order_date
)
SELECT order_id,
       order_date,
       order_value,
       SUM(order_value) OVER (ORDER BY order_date, order_id) AS running_total
FROM order_value
ORDER BY order_date, order_id;

-- Part b:

WITH order_value AS (
    SELECT o.store_id,
           o.order_id,
           o.order_date,
           SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS order_value
    FROM sales.orders      AS o
    JOIN sales.order_items AS oi ON oi.order_id = o.order_id
    GROUP BY o.store_id, o.order_id, o.order_date
)
SELECT store_id,
       order_id,
       order_date,
       order_value,
       SUM(order_value) OVER (PARTITION BY store_id
                              ORDER BY order_date, order_id) AS store_running_total
FROM order_value
ORDER BY store_id, order_date, order_id;


-- ============================================================
--  Question 10 — Challenge
--  Build a report for the year 2017 with one row per month:
--    month, total_sales, previous_month_sales,
--    sales_change (in %), and sales_rank
--    (rank of the month by total_sales, highest first).
--  Use a CTE for the monthly totals and combine LAG with
--  RANK in the final SELECT.
-- ============================================================

-- Write your query below:

WITH monthly_sales AS (
    SELECT MONTH(o.order_date)                                  AS month_num,
           SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS total_sales
    FROM sales.orders      AS o
    JOIN sales.order_items AS oi ON oi.order_id = o.order_id
    WHERE o.order_date >= '2017-01-01'
      AND o.order_date <  '2018-01-01'
    GROUP BY MONTH(o.order_date)
)
SELECT month_num                                                       AS month,
       ROUND(total_sales, 2)                                           AS total_sales,
       ROUND(LAG(total_sales) OVER (ORDER BY month_num), 2)            AS previous_month_sales,
       ROUND(100.0 * (total_sales - LAG(total_sales) OVER (ORDER BY month_num))
             / NULLIF(LAG(total_sales) OVER (ORDER BY month_num), 0), 2) AS sales_change,
       RANK() OVER (ORDER BY total_sales DESC)                         AS sales_rank
FROM monthly_sales
ORDER BY month_num;