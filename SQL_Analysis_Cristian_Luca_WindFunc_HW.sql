/*Task 1
Create a query to produce a sales report highlighting the top customers with the highest sales across different sales channels.
This report should list the top 5 customers for each channel. Additionally, calculate a key performance indicator (KPI) called 'sales_percentage,' 
which represents the percentage of a customer's sales relative to the total sales within their respective channel.
Please format the columns as follows:
Display the total sales amount with two decimal places
Display the sales percentage with four decimal places and include the percent sign (%) at the end
Display the result for each channel in descending order of sales

Note:
Please add comments why you chose a particular way to solve each tasks.
You cannot use window frames*/

-- 1.1 --> Prepare summarized sales data per customer per channel
WITH sales_data AS (
    SELECT
        ch.channel_desc,                           -- Select channel description (such as Direct Sales, Internet)
        c.cust_last_name,                          -- Customer last name
        c.cust_first_name,                         -- Customer first name
        ROUND(SUM(s.amount_sold), 2) AS amount_sold, -- Sum amount_sold per customer, formatted to 2 decimal places
        SUM(SUM(s.amount_sold)) OVER (PARTITION BY ch.channel_desc) AS total_channel_sales
          -- Total sales for the channel 
    FROM
        sh.sales s
    INNER JOIN sh.customers c ON s.cust_id = c.cust_id       -- Join sales with customers to get customer info
    INNER JOIN sh.channels ch ON s.channel_id = ch.channel_id -- Join sales with channels to get channel info
    GROUP BY
        ch.channel_desc,
        c.cust_last_name,
        c.cust_first_name
        -- Group by customer and channel to aggregate sales at the right level
),

-- 1.2 --> Rank customers within each channel based on amount_sold
ranked_sales AS (
    SELECT
        channel_desc,
        cust_last_name,
        cust_first_name,
        amount_sold,
        total_channel_sales,
        ROUND((amount_sold / total_channel_sales) * 100, 4) || ' %' AS sales_percentage, 
          -- Calculate the sales percentage, format it with 4 decimal places and append %
        ROW_NUMBER() OVER (PARTITION BY channel_desc ORDER BY amount_sold DESC) AS rn
          -- Rank customers per channel: 1 for highest sales, 2 for next, etc. (using ROW_NUMBER)
    FROM
        sales_data
)

-- 1.3. --> Select only top 5 customers per channel and order results
SELECT
    channel_desc,
    cust_last_name,
    cust_first_name,
    amount_sold,
    sales_percentage
FROM
    ranked_sales
WHERE
    rn <= 5
    -- Keep only top 5 customers per channel
ORDER BY
    channel_desc,
    amount_sold DESC;
    -- Order output by channel and then by amount sold descending

/*
  Step                                                                     |Why this method?
  
CTE sales_data                                                       |Separates sales aggregation logic clearly, calculates both customer sales and channel total in one clean step
SUM() OVER (PARTITION BY channel_desc)       |Needed to calculate total sales per channel, using a basic window function 
CTE ranked_sales                                                   |Helps rank customers per channel cleanly, makes final filtering easy (top 5).
ROW_NUMBER()                                                 |Best for strict top-N ranking per group (no ties handled; only one #1, #2, etc.)
ROUND() formatting                                             |Matches requirement to format amount_sold and sales_percentage accurately
Simple final SELECT                                             |Filters for only the needed top 5 rows 
*/
  
-- ================================================================================================

 /* Task 2
Create a query to retrieve data for a report that displays the total sales for all products in the Photo category in the Asian region 
for the year 2000. Calculate the overall report total and name it 'YEAR_SUM'
Display the sales amount with two decimal places
Display the result in descending order of 'YEAR_SUM'
For this report, consider exploring the use of the crosstab function. Additional details and guidance can be found at this link
https://www.postgresql.org/docs/12/tablefunc.html
*/

--  Be sure you have tablefunc extension installed
CREATE EXTENSION IF NOT EXISTS tablefunc;
 
 -- 2.1 --> Use crosstab() directly with  SELECT inside
SELECT 
              product_name,
                                q1,
                                q2,
                                q3,
                                q4,
                                ROUND(COALESCE(q1, 0) + COALESCE(q2, 0) + COALESCE(q3, 0) + COALESCE(q4, 0), 2) AS year_sum 
                                -- Calculate and display YEAR_SUM

FROM crosstab(
    $$
    -- Inner query for crosstab: return product name, quarter number, and sales amount
    SELECT
        p.prod_name,                                                -- Product name (row identifier)
        t.calendar_quarter_number,                            -- Quarter number (column pivot key: 1, 2, 3, 4)
        ROUND(SUM(s.amount_sold), 2)                -- Total sales amount, rounded to 2 decimal places
    FROM
        sh.sales s
    INNER JOIN sh.customers cust ON s.cust_id = cust.cust_id       -- sales linked to customers
    INNER JOIN sh.countries c ON cust.country_id = c.country_id  --  customers linked to countries
    INNER JOIN sh.products p ON s.prod_id = p.prod_id               -- join sales to products
    INNER JOIN sh.times t ON s.time_id = t.time_id                       -- join sales to time dimension
    WHERE
        p.prod_category = 'Photo'                        -- Filter by Photo category
        AND c.country_region = 'Asia'                -- Filter by Asia region
        AND t.calendar_year = 2000                   -- Filter by year 2000
    GROUP BY
        p.prod_name, t.calendar_quarter_number      -- Group by product and quarter
    ORDER BY
        p.prod_name, t.calendar_quarter_number      -- Important: must order for crosstab
    $$,
    $$
-- 2.2 --> Specify the set of quarter keys manually
    VALUES (1), (2), (3), (4)
    $$
) AS ct (
-- 2.3 --> Define output columns
    product_name text,   -- Product Name
    q1 numeric,             -- Quarter 1 Sales
    q2 numeric,             -- Quarter 2 Sales
    q3 numeric,             -- Quarter 3 Sales
    q4 numeric              -- Quarter 4 Sales
)

-- 2.4 -->Order results by the total yearly sales descending
ORDER BY year_sum DESC;


/*
 Step                                              | Why I chose this approach

Use crosstab()                                 | Task hints at using pivot layout; crosstab() is official PostgreSQL pivot tool.
ROUND(SUM()) inside SELECT    | Rounding makes data clean; saves later work.
Join sales ➔ customers ➔ countries  | Database structure requires this path (sales table does not have country_id).
COALESCE()                                | Protect against NULL values when calculating year_sum.
ORDER BY year_sum DESC         | Match requirement: order by best-selling products.
Inline SQL inside crosstab()            | PostgreSQL crosstab() cannot read CTEs — must have full standalone SQL inside
*/

-- ===========================================================================

/*Task 3
Create a query to generate a sales report for customers ranked in the top 300 based on total sales in the years 1998, 1999, and 2001. The report should be categorized based on sales channels, and separate calculations should be performed for each channel.
Retrieve customers who ranked among the top 300 in sales for the years 1998, 1999, and 2001
Categorize the customers based on their sales channels
Perform separate calculations for each sales channel
Include in the report only purchases made on the channel specified
Format the column so that total sales are displayed with two decimal places*/

-- 3.1 --> Build a Common Table Expression (CTE) to rank customers per year
WITH ranked_customers AS (
    SELECT
        ch.channel_desc,           -- Get the descriptive sales channel name from the 'channels' table
        c.cust_id,                     -- Customer ID needed for grouping and output
        c.cust_last_name,         -- Customer last name for reporting
        c.cust_first_name,        -- Customer first name for reporting
        SUM(s.amount_sold) AS total_sales, -- Total amount sold by each customer in a year
        RANK() OVER (
            PARTITION BY EXTRACT(YEAR FROM s.time_id) -- Partition by year: ranks reset every year
            ORDER BY SUM(s.amount_sold) DESC                       -- Rank customers from highest to lowest sales
        ) AS sales_rank,                                                                   -- Ranking number assigned based on yearly sales
        EXTRACT(YEAR FROM s.time_id) AS sales_year            -- Extract the year from the sale's timestamp
    FROM
        sh.sales s                
        INNER JOIN sh.customers c ON s.cust_id = c.cust_id              -- Join with customers to get names
        INNER JOIN sh.channels ch ON s.channel_id = ch.channel_id  -- Join with channels to get channel descriptions
    WHERE
        EXTRACT(YEAR FROM s.time_id) IN (1998, 1999, 2001)      -- Only consider sales made in 1998, 1999, or 2001
    GROUP BY
        ch.channel_desc,           -- Group by channel description (since it's selected)
        c.cust_id,                     -- Group by customer ID
        c.cust_last_name,         -- Group by last name (required because selected)
        c.cust_first_name,        -- Group by first name (required because selected)
        EXTRACT(YEAR FROM s.time_id) -- Group by year to correctly partition sales
)

-- 3.2 --> Query the CTE to produce the final report
SELECT
    channel_desc,                -- Output the sales channel
    cust_id,                         -- Output customer ID
    cust_last_name,             -- Output last name
    cust_first_name,            -- Output first name
    TO_CHAR(SUM(total_sales), '999,999,990.00') AS amount_sold 
    -- Sum the total sales over the selected years and format as a string with exactly two decimal places
FROM
    ranked_customers
WHERE
    sales_rank <= 300           -- Only include customers who ranked in the top 300 in their sales year
GROUP BY
    channel_desc,
    cust_id,
    cust_last_name,
    cust_first_name
ORDER BY
    channel_desc,                 -- Sort first by channel description
    amount_sold DESC;      -- Then sort within each channel by highest total sales


-- STRUCTURE:
-- CTE (Common Table Expression) keeps the logic clean and modular
-- Separates calculation (rank, sum) from presentation (final output)
-- Performance efficient: only ranks necessary data, and filters early
-- Readable: easy for everyone to understand and update   

   -- ===============================================================================

    /*Task 4
Create a query to generate a sales report for January 2000, February 2000, and March 2000 specifically for the Europe and Americas regions.
Display the result by months and by product category in alphabetical order.*/
    

--4.1 --> Build a CTE to aggregate sales by month, product category, and region
WITH sales_data AS (
    SELECT
        t.calendar_month_desc,                    -- Month description like '2000-01'
        p.prod_category,                              -- Product category name
        co.country_region,                           -- Country region from 'countries' table (Europe or Americas)
        SUM(s.amount_sold) AS total_sales -- Total sales amount aggregated
    FROM
        sh.sales s                                                                      -- Sales table
        INNER JOIN sh.products p ON s.prod_id = p.prod_id            -- Join products to get product category
        INNER JOIN sh.customers c ON s.cust_id = c.cust_id             -- Join customers to get country_id
        INNER JOIN sh.countries co ON c.country_id = co.country_id -- Join countries to get region 
        INNER JOIN sh.times t ON s.time_id = t.time_id                    -- Join times to get month
    WHERE
        t.calendar_month_desc IN ('2000-01', '2000-02', '2000-03') -- Only sales from Jan, Feb, Mar 2000
        AND co.country_region IN ('Europe', 'Americas')             -- Only Europe and Americas regions
    GROUP BY
        t.calendar_month_desc,
        p.prod_category,
        co.country_region         -- Group by month, product category, and region
)

-- 4.2 --> Pivot the sales totals into Americas and Europe
SELECT
    calendar_month_desc, -- Month
    prod_category,            -- Product category
    SUM(CASE WHEN country_region = 'Americas' THEN total_sales ELSE 0 END) AS "Americas SALES",
    SUM(CASE WHEN country_region = 'Europe' THEN total_sales ELSE 0 END) AS "Europe SALES"
FROM
    sales_data
GROUP BY
    calendar_month_desc,
    prod_category
ORDER BY
    calendar_month_desc, -- Sort first by month
    prod_category;           -- Then by product category alphabetically

-- STRUCTURE:
-- CTE separates logic and makes it modular and readable
-- Pivoting (with CASE WHEN) makes output user-friendly
-- Joins are necessary because of normalized table structure
-- Early filtering ensures performance and relevance