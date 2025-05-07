--====================================================================
/*Task 1
 
Create a query for analyzing the annual sales data for the years 1999 to 2001, focusing on different sales channels
and regions: 'Americas,' 'Asia,' and 'Europe.' 
The resulting report should contain the following columns:
AMOUNT_SOLD: This column should show the total sales amount for each sales channel
% BY CHANNELS: In this column, we should display the percentage of total sales for each channel 
(e.g. 100% - total sales for Americas in 1999, 63.64% - percentage of sales for the channel “Direct Sales”)
% PREVIOUS PERIOD: This column should display the same percentage values as in the '% BY CHANNELS'
column but for the previous year
% DIFF: This column should show the difference between the '% BY CHANNELS' and '% PREVIOUS PERIOD' 
columns, indicating the change in sales percentage from the previous year.
The final result should be sorted in ascending order based on three criteria: first by 'country_region,' then by 
'calendar_year,' and finally by 'channel_desc' */


-- 1: Aggregate sales by region, year, and channel
WITH sales_by_region_year_channel AS (
    SELECT
        co.country_region,        -- Region (like Americas, Asia, Europe)
        t.calendar_year,             -- Year (1999–2001)
        ch.channel_desc,           -- Sales channel (like Internet, Partners)
        SUM(s.amount_sold) AS amount_sold -- Total sales per group
    FROM sh.sales s
    INNER JOIN sh.times t ON s.time_id = t.time_id
    INNER JOIN sh.customers cu ON s.cust_id = cu.cust_id
    INNER JOIN sh.countries co ON cu.country_id = co.country_id
    INNER JOIN sh.channels ch ON s.channel_id = ch.channel_id
    WHERE
        t.calendar_year BETWEEN 1999 AND 2001
        AND co.country_region IN ('Americas', 'Asia', 'Europe')
    GROUP BY
        co.country_region,
        t.calendar_year,
        ch.channel_desc
),

-- 2: Calculate % of total sales for every region-year (channel share)
sales_with_pct AS (
    SELECT
        sbr.country_region,
        sbr.calendar_year,
        sbr.channel_desc,
        sbr.amount_sold,

        -- % of region-year total = channel sales / total for that region and year
        ROUND(
            100.0 * sbr.amount_sold / 
            SUM(sbr.amount_sold) OVER (
                PARTITION BY sbr.country_region, sbr.calendar_year
            ),
            2
        ) AS pct_by_channels
    FROM sales_by_region_year_channel sbr
)

-- 3: Use LAG to compare with previous year, and handle NULLs
SELECT
    country_region,
    calendar_year,
    channel_desc,
    amount_sold,
    pct_by_channels,

    -- Get previous year's percentage (use 0 if NULL)
    COALESCE(
        LAG(pct_by_channels) OVER (
            PARTITION BY country_region, channel_desc
            ORDER BY calendar_year
        ), 0
    ) AS pct_previous_period,

    -- Difference in % (current − previous), replacing NULLs with 0
    ROUND(
        pct_by_channels -
        COALESCE(
            LAG(pct_by_channels) OVER (
                PARTITION BY country_region, channel_desc
                ORDER BY calendar_year
            ), 0
        ),
        2
    ) AS pct_diff

FROM sales_with_pct
ORDER BY country_region, calendar_year, channel_desc;

--====================================================================

/*Task 2
You need to create a query that meets the following requirements:
Generate a sales report for the 49th, 50th, and 51st weeks of 1999.
Include a column named CUM_SUM to display the amounts accumulated during each week.
Include a column named CENTERED_3_DAY_AVG to show the average sales for the previous,
current, and following days using a centered moving average.
For Monday, calculate the average sales based on the weekend sales (Saturday and Sunday) as well as 
Monday and Tuesday.
For Friday, calculate the average sales on Thursday, Friday, and the weekend.
Ensure that your calculations are accurate for the beginning of week 49 and the end of week 51.*/


-- 1: Get daily sales from week 49 to 51 of 1999
WITH base_sales AS (
    SELECT
        t.time_id AS time_id,                          -- Date of the sale
        t.calendar_week_number,                    -- Week number
        t.day_name AS day_name,                   --Column for day name
        s.amount_sold
    FROM sh.sales s
    INNER JOIN sh.times t ON s.time_id = t.time_id
    WHERE
        t.calendar_year = 1999
        AND t.calendar_week_number BETWEEN 49 AND 51
),

-- 2: Aggregate total sales for every day
daily_sales AS (
    SELECT
        time_id,
        calendar_week_number,
        day_name,
        SUM(amount_sold) AS sales
    FROM base_sales
    GROUP BY time_id, calendar_week_number, day_name
),

-- 3: Calculate cumulative sum of sales by date
cumulative_and_raw_avg AS (
    SELECT
        ds.time_id,
        ds.calendar_week_number,
        ds.day_name,
        ds.sales,

        -- Running cumulative sum ordered by date
        SUM(ds.sales) OVER (
            ORDER BY ds.time_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cum_sum
    FROM daily_sales ds
)

-- 4: Compute centered 3-day average with Monday/Friday logic
SELECT
    calendar_week_number,
    time_id,
    day_name,
    sales,
    cum_sum,

    -- Custom logic for centered 3-day average
    ROUND(
        CASE
            WHEN day_name = 'Monday' THEN (
                (
                    COALESCE(LAG(sales, 2) OVER (ORDER BY time_id), 0) +  -- Saturday
                    COALESCE(LAG(sales, 1) OVER (ORDER BY time_id), 0) +  -- Sunday
                    sales +
                    COALESCE(LEAD(sales, 1) OVER (ORDER BY time_id), 0)   -- Tuesday
                ) / 4.0
            )
            WHEN day_name = 'Friday' THEN (
                (
                    COALESCE(LAG(sales, 1) OVER (ORDER BY time_id), 0) +  -- Thursday
                    sales +
                    COALESCE(LEAD(sales, 1) OVER (ORDER BY time_id), 0) + -- Saturday
                    COALESCE(LEAD(sales, 2) OVER (ORDER BY time_id), 0)   -- Sunday
                ) / 4.0
            )
            ELSE (
                COALESCE(LAG(sales, 1) OVER (ORDER BY time_id), 0) +
                sales +
                COALESCE(LEAD(sales, 1) OVER (ORDER BY time_id), 0)
            ) / 3.0
        END,
        2
    ) AS centered_3_day_avg

FROM cumulative_and_raw_avg
ORDER BY time_id;

--========================================================

/*Task 3
Please provide 3 instances of utilizing window functions that include a frame clause,
using RANGE, ROWS, and GROUPS modes. 
Additionally, explain the reason for choosing a specific frame type for each example. 
This can be presented as a single query or as three distinct queries.*/



--3.1. ROWS frame type: physical row-based running total of daily sales

-- 3.1.1: Aggregate daily sales using SUM()
-- CTE defines total sales for every day 

WITH daily_sales AS (
    SELECT
        t.time_id,                    -- The date of the sales
        t.day_name,                -- The day name (like Monday)
        SUM(s.amount_sold) AS daily_sales  -- Aggregate total sales per date
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    WHERE 
        t.calendar_year = 1999 AND
        t.calendar_week_number = 49
    GROUP BY 
        t.time_id,
        t.day_name
)


-- 3.1.2: Apply ROWS-based window frame
-- Running total using physical row order

SELECT
    time_id,
    day_name,
    daily_sales,

    -- Running total using ROWS: sums all physical rows up to current
    SUM(daily_sales) OVER (
        ORDER BY time_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_rows

FROM daily_sales
ORDER BY time_id;


--The ROWS frame type is chosen here because it gives precise, row-by-row control over which records 
--are included in the window function's frame. 

--ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--This tells SQL: "Start from the first physical row in the result (unbounded preceding), 
--and include all rows up to and including the current row (ordered by date)."

--A running total by calendar day should simply add each day's total to the previous one — exactly what ROWS does.


--3.2. RANGE frame type: logical cumulative total of sales using value-based range

-- 3.2.1: Aggregate daily sales per date
-- This CTE calculates the total amount_sold for every time_id

WITH daily_sales AS (
    SELECT
        t.time_id,                        -- Actual sales date
        t.day_name,                     -- Weekday name (like Monday)
        SUM(s.amount_sold) AS daily_sales -- Total sales for that day
    FROM sh.sales s
    INNER JOIN sh.times t ON s.time_id = t.time_id
    WHERE 
        t.calendar_year = 1999 AND
        t.calendar_week_number = 49
    GROUP BY t.time_id, t.day_name
)

-- 3.2.2: Compute logical running total using RANGE frame
-- RANGE includes all rows with time_id values <= current row's time_id

SELECT
    time_id,
    day_name,
    daily_sales,

    -- Logical cumulative total: includes all rows with lesser or equal date values
    SUM(daily_sales) OVER (
        ORDER BY time_id
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_range

FROM daily_sales
ORDER BY time_id;


--RANGE is value-based, not row-based.

--Includes all rows where ORDER BY column (time_id)  <=  current row’s value.

--If multiple rows share the same date (like same time_id), they're all included in the frame.

--RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT row explained:
--RANGE --> the frame includes rows based on the value of the ORDER BY column.
--UNBOUNDED PRECEDING --> start from the lowest value in the partition.
--CURRENT ROW--> end at the current row's value (not row position).


--3.3. Groups frame type: running count of distinct weekday groups

-- 3.3.1: Aggregate daily sales for every date
-- This CTE produces one row per day with total sales

WITH daily_sales AS (
    SELECT
        t.time_id,
        t.day_name,
        SUM(s.amount_sold) AS daily_sales  
    FROM sh.sales s
    INNER JOIN sh.times t ON s.time_id = t.time_id
    WHERE 
        t.calendar_year = 1999 AND
        t.calendar_week_number = 49
    GROUP BY t.time_id, t.day_name
)


-- 3.3.2: Apply GROUPS window frame
-- This calculates a running total by grouping rows
-- with the same daily_sales value(peer groups)

SELECT
    time_id,
    day_name,
    daily_sales,

    -- GROUPS frame: includes all peer groups (same daily_sales)
    -- and groups with lesser values up to the current row's group
    SUM(daily_sales) OVER (
        ORDER BY daily_sales
        GROUPS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_group_total

FROM daily_sales
ORDER BY daily_sales;

--GROUPS works in the following way:
--Rows are grouped based on the value of daily_sales
--All rows with the same daily_sales form a peer group
--The frame accumulates totals group-by-group, not row-by-row or value-by-value

--GROUPS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
--It tells SQL: "Include all rows with the same value in the ORDER BY column (peer groups)
--starting from the beginning of the partition up to and including the peer group of the current row (same ORDER BY value as this row)."


--A little conclusion:

--| Frame Type       | What defines inclusion?                | Includes rows                                       |

--| ROWS              | Physical position                          | Based on row count                               |
--| RANGE           | Value-based                                 | Based on ORDER BY value                   |
--| GROUPS          | Peer group-based (value + group) | Whole peer groups by ORDER BY value |

--=================================================================================