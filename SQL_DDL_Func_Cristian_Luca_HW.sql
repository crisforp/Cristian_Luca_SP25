/*Create a view, query language functions, and procedure language functions using a DVD rental database.

Note:

Please pay attention that your code must be reusable and rerunnable and executes without errors.
Don't hardcode IDs
Add RAISE EXCEPTION to identify errors
Don't forget to check for duplicates, ensure that the object has not already been created
Check that the function is run correctly and returns the desired result. Don't forget about optional parameters*/


/*Task 1. Create a view

Create a view called 'sales_revenue_by_category_qtr' that shows the film category and total sales revenue
for the current quarter and year. The view should only display categories with at least one sale in the current quarter. 
Note: when the next quarter begins, it will be considered as the current quarter.*/

-- ===============================
-- Task 1: Create a view showing total sales revenue
--         by film category for the current quarter
-- ===============================

-- 1.1: Drop the view if it already exists
-- This makes the script rerunnable and avoids errors due to duplication
DROP VIEW IF EXISTS sales_revenue_by_category_qtr;

-- 1.2: Create the new view
CREATE VIEW sales_revenue_by_category_qtr AS
SELECT
    c.name AS category_name,                             -- Film category name (such as Comedy, Action)
    SUM(p.amount) AS total_sales_revenue          -- Total revenue from payments for this category
FROM
    payment p
    -- Join payment to rental to get rental details
    INNER JOIN rental r ON p.rental_id = r.rental_id
    -- Join rental to inventory to get the specific physical item rented
    INNER JOIN inventory i ON r.inventory_id = i.inventory_id
    -- Join inventory to film to get film details
    INNER JOIN film f ON i.film_id = f.film_id
    -- Join film to film_category (many-to-many bridge)
    INNER JOIN film_category fc ON f.film_id = fc.film_id
    -- Join film_category to category to get the category name
    INNER JOIN category c ON fc.category_id = c.category_id
WHERE
    -- Filter to include only payments made during the current calendar year
    EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
    -- Further filter to only include payments from the current quarter (1 to 4)
    AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
GROUP BY
    c.name                                                    -- Group by category so we can sum revenue per category
HAVING
    SUM(p.amount) > 0                                 -- Only include categories that actually made money
ORDER BY
    total_sales_revenue DESC;                        -- Show highest earning categories first

   -- Test Task 1: View
-- This will return total sales by category for the current quarter
--SELECT * FROM sales_revenue_by_category_qtr;

 --you can check if your DVD rental database has payment data in the current quarter and year, and what to do if it doesn’t:
 
/* SELECT
    COUNT(*) AS payments_this_quarter,
    MIN(payment_date) AS earliest_payment,
    MAX(payment_date) AS latest_payment
FROM payment
WHERE
    EXTRACT(YEAR FROM payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
    AND EXTRACT(QUARTER FROM payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE);*/
    
-- If payments_this_quarter = 0, then Task 1 view will return nothing.
-- If MIN() and MAX() dates are way in the past, then you may need to adjust test data.

 
    
/*Task 2. Create a query language functions
Create a query language function called 'get_sales_revenue_by_category_qtr' that accepts one parameter representing
the current quarter and year and returns the same result as the 'sales_revenue_by_category_qtr' view.*/
    
-- =====================================
-- Task 2: Create a query language function
--         that returns sales revenue by category for a given quarter
-- =====================================

-- 2.1: Drop the function if it already exists to allow rerunning safely
DROP FUNCTION IF EXISTS get_sales_revenue_by_category_qtr(DATE);

-- 2.2: Define the function
-- This function takes a single date input and calculates the quarter and year from it
-- It then returns the same data as the view from Task 1, but for the input quarter, year
CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr(p_date DATE)
RETURNS TABLE (
    category_name TEXT,                                    -- Name of the film category
    total_sales_revenue NUMERIC(10,2)              -- Total revenue in that category
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_year INT := EXTRACT(YEAR FROM p_date);              -- Extract year from the input date
    v_quarter INT := EXTRACT(QUARTER FROM p_date); -- Extract quarter from the input date
BEGIN
    -- Check for NULL input date
    IF p_date IS NULL THEN
        RAISE EXCEPTION 'Input date cannot be NULL.';
    END IF;

    -- Return the aggregated revenue per category
    RETURN QUERY
    SELECT
        c.name AS category_name,
        SUM(p.amount)::NUMERIC(10,2) AS total_sales_revenue
    FROM
        payment p
        INNER JOIN rental r ON p.rental_id = r.rental_id
        INNER JOIN inventory i ON r.inventory_id = i.inventory_id
        INNER JOIN film f ON i.film_id = f.film_id
        INNER JOIN film_category fc ON f.film_id = fc.film_id
        INNER JOIN category c ON fc.category_id = c.category_id
    WHERE
        EXTRACT(YEAR FROM p.payment_date) = v_year                        -- Match year
        AND EXTRACT(QUARTER FROM p.payment_date) = v_quarter -- Match quarter
    GROUP BY
        c.name
    HAVING
        SUM(p.amount) > 0                                     -- Only include categories with sales
    ORDER BY
        total_sales_revenue DESC;                           -- Highest to lowest revenue
END;
$$;

-- Test Task 2: Function with date parameter
-- This will show Q1 2024 revenue (January–March)
-- SELECT * FROM get_sales_revenue_by_category_qtr(DATE '2024-01-01');




/*Task 3.
Create procedure language functions
Create a function that takes a country as an input parameter and returns the most popular film in that specific country. 
The function should format the result set as follows:
                    Query (example):select * from core.most_popular_films_by_countries(array['Afghanistan','Brazil','United States’]);*/


-- =======================================
-- Task 3: Create a function to return the most rented (popular) film
--         in each specified country
-- =======================================

-- 3.1: Drop the function if it already exists
DROP FUNCTION IF EXISTS core.most_popular_films_by_countries(TEXT[]);

-- 3.2: Create the function
-- Accepts an array of country names (case-insensitive)
-- Returns one top-ranked film per country based on rental count
CREATE OR REPLACE FUNCTION core.most_popular_films_by_countries(countries TEXT[])
RETURNS TABLE (
    country_name TEXT,         -- Name of the country
    film_title TEXT,                -- Most popular film in that country
    rating TEXT,                     -- Film rating (such as PG, R)
    language TEXT,               -- Language of the film
    length INT,                      -- Duration of the film in minutes
    release_year INT                -- Year the film was released
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validate input array
    IF countries IS NULL OR array_length(countries, 1) IS NULL THEN
        RAISE EXCEPTION 'Input country list cannot be NULL or empty.';
    END IF;

    -- Use a CTE to calculate rentals and ranking
    RETURN QUERY
    WITH film_rentals AS (
        SELECT
            UPPER(co.country) AS country_name,          -- Normalize country name to uppercase
            f.title AS film_title,
            f.rating,
            l.name AS language,
            f.length,
            f.release_year,
            COUNT(*) AS rental_count,                       -- Count number of rentals per film per country
            RANK() OVER (PARTITION BY UPPER(co.country)
                        ORDER BY COUNT(*) DESC) AS rk   -- Rank films by rentals within each country
        FROM
            rental r
            INNER JOIN inventory i ON r.inventory_id = i.inventory_id
            INNER JOIN film f ON i.film_id = f.film_id
            INNER JOIN language l ON f.language_id = l.language_id
            INNER JOIN customer cu ON r.customer_id = cu.customer_id
            INNER JOIN address a ON cu.address_id = a.address_id
            INNER JOIN city ci ON a.city_id = ci.city_id
            INNER JOIN country co ON ci.country_id = co.country_id
        WHERE
            UPPER(co.country) = ANY (SELECT UPPER(c) FROM unnest(countries) AS c)
            -- unnest(countries): Turns the input array into rows.
            -- UPPER(...): Normalizes casing so comparisons are case-insensitive.
            -- = ANY (...): Matches if the current country is equal to any of the values in the expanded array.
        GROUP BY
            co.country, f.title, f.rating, l.name, f.length, f.release_year
    )
    -- Select only top-ranked films (rk = 1)
    SELECT
        country_name,
        film_title,
        rating,
        language,
        length,
        release_year
    FROM film_rentals
    WHERE rk = 1;
END;
$$;


-- Test Task 3: Function for top film in specified countries
-- SELECT * FROM core.most_popular_films_by_countries(ARRAY['United States', 'Brazil', 'Mexico']);
-- the input is case-insesitive



/*Task 4. 
Create procedure language functions
Create a function that generates a list of movies available in stock based on a partial title match (e.g., movies containing the word 'love' in their title). 
The titles of these movies are formatted as '%...%', and if a movie with the specified title is not in stock, return a message indicating that it was not found.
The function should produce the result set in the following format (note: the 'row_num' field is an automatically generated counter field, starting from 1 and incrementing for each entry, e.g., 1, 2, ..., 100, 101, ...).

Query (example):select * from core.films_in_stock_by_title('%love%’);*/

-- =====================================================
-- Task 4: Create a function that returns available films
--         matching a title pattern, with row numbers 
-- =====================================================

-- 4.1: Drop function if it exists
DROP FUNCTION IF EXISTS core.films_in_stock_by_title(TEXT);

-- 4.2: Create the function
-- Accepts a pattern like '%love%' to search film titles (case-insensitive)
CREATE OR REPLACE FUNCTION core.films_in_stock_by_title(p_title TEXT)
RETURNS TABLE (
    row_num INT,                       -- Row counter, starting from 1
    film_title TEXT,                     -- Film title matching the search
    language TEXT,                    -- Language of the film
    customer_name TEXT,           -- Name of customer who rented it (if available)
    rental_date TIMESTAMP       -- Date when it was rented (if available)
)
LANGUAGE plpgsql
AS $$
DECLARE
    clean_title TEXT := TRIM(p_title);  -- Trim whitespace from input
    counter INT := 1;                             -- Manual counter for row numbers
    rec RECORD;                                   -- Loop record
BEGIN
    -- Validate input
    IF clean_title IS NULL OR clean_title = '' THEN
        RAISE EXCEPTION 'Input title cannot be NULL or empty.';
    END IF;

    -- Loop through matching available films and return each with a counter
    FOR rec IN
        SELECT
            f.title AS film_title,
            l.name AS language,
            CONCAT(cu.first_name, ' ', cu.last_name) AS customer_name,
            r.rental_date
        FROM
            inventory i
            INNER JOIN film f ON i.film_id = f.film_id                        -- Only include inventory that has a matching film.
            INNER JOIN language l ON f.language_id = l.language_id   -- Only include films that have a language.
            LEFT JOIN rental r ON i.inventory_id = r.inventory_id          -- Give me all inventory that matches the title filter
            LEFT JOIN customer cu ON r.customer_id = cu.customer_id -- and if it was rented, also show me who and when.
        WHERE
            f.title ILIKE clean_title -- Use ILIKE for case-insensitive match
            AND i.inventory_id NOT IN (
                SELECT inventory_id FROM rental WHERE return_date IS NULL
            ) -- Only include available items (not currently rented)
    LOOP
        -- Assign counter values and return each row
        row_num := counter;
        film_title := rec.film_title;
        language := rec.language;
        customer_name := rec.customer_name;
        rental_date := rec.rental_date;

        RETURN NEXT;
        counter := counter + 1;
    END LOOP;

    -- If no rows matched, raise an error
    IF counter = 1 THEN
        RAISE EXCEPTION 'No films matching "%" are currently available.', clean_title;
    END IF;
END;
$$;
 

-- Task 4: Function to search available films matching pattern
-- Example: Finds films with “love” in the title that are currently in stock
-- SELECT * FROM core.films_in_stock_by_title('%love%');





/*Task 5.
Create procedure language functions

Create a procedure language function called 'new_movie' that takes a movie title as a parameter and inserts a new movie
with the given title in the film table. The function should generate a new unique film ID, set the rental rate to 4.99, the rental 
duration to three days, the replacement cost to 19.99. The release year and language are optional and by default should be current year 
and Klingon respectively. The function should also verify that the language exists in the 'language' table. 
Then, ensure that no such function has been created before; if so, replace it.*/


-- ===============================
-- Task 5: Create a function to insert a new film
--         with default values and validations
-- ===============================

-- 5.1: Drop the function if it already exists
DROP FUNCTION IF EXISTS new_movie(TEXT, INT, TEXT);

-- 5.2: Create the function
-- Accepts a title, and optional release year and language (default: current year + Klingon)
CREATE OR REPLACE FUNCTION new_movie(
    p_title TEXT,
    p_release_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
    p_language TEXT DEFAULT 'Klingon'
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_language_id INT;     -- ID of the language selected
    v_new_film_id INT;    -- New unique film ID
BEGIN
    -- Validate that title is not null or blank
    IF p_title IS NULL OR TRIM(p_title) = '' THEN
        RAISE EXCEPTION 'Movie title cannot be NULL or empty.';
    END IF;

    -- Prevent duplicate film titles (case-insensitive check)
    IF EXISTS (
        SELECT 1 FROM film WHERE UPPER(title) = UPPER(p_title)
    ) THEN
        RAISE EXCEPTION 'A film with the title "%" already exists.', p_title;
    END IF;

    -- Look up the language ID from the language name
    SELECT language_id
    INTO v_language_id
    FROM language
    WHERE UPPER(name) = UPPER(p_language);

    -- Raise error if language does not exist
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Language "%" does not exist in the language table.', p_language;
    END IF;

    -- Generate a new unique film_id by incrementing the current maximum
    SELECT COALESCE(MAX(film_id), 0) + 1
    INTO v_new_film_id
    FROM film;

    -- Insert the new film with fixed rental values and default cost
    INSERT INTO film (
        film_id,
        title,
        release_year,
        language_id,
        rental_duration,
        rental_rate,
        replacement_cost,
        last_update
    ) VALUES (
        v_new_film_id,
        p_title,
        p_release_year,
        v_language_id,
        3,               -- rental duration (days)
        4.99,          -- rental rate
        19.99,        -- replacement cost
        NOW()     -- current timestamp
    );

    -- Give the unique film_id of the new movie — so you can refer back to it when you need.
    RETURN v_new_film_id;
END;
$$;

-- Test Function new_movie(p_title TEXT, p_release_year INT, p_language TEXT)

-- Add with default year & language:
-- Test inserting a new film with default release year and Klingon language
-- SELECT new_movie('Starborn Legacy');

-- Add with custom language and year:
-- Test inserting a new film with explicit release year and language
-- SELECT new_movie('The Ancient Scroll', 2022, 'English');

--  Test duplicate title (should raise exception):
-- SELECT new_movie('Starborn Legacy'); -- Should fail if already inserted above

-- Test invalid language (should raise exception):
-- SELECT new_movie('Ghost Circuit', 2024, 'Elvishi'); -- Assuming 'Elvishi' language does not exist







