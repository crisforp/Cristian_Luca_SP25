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

--Before creating a new view, you want to make sure an old version of the view,if it exists, is removed.
DROP VIEW IF EXISTS sales_revenue_by_category_qtr;

--Create the View
CREATE VIEW sales_revenue_by_category_qtr AS
SELECT
    c.name AS category_name,                    -- pulls the name of the category
    SUM(p.amount) AS total_sales_revenue --calculates sum of payments for each category
FROM
    payment p
    INNER JOIN rental r ON p.rental_id = r.rental_id
    INNER JOIN inventory i ON r.inventory_id = i.inventory_id
    INNER JOIN film f ON i.film_id = f.film_id
    INNER JOIN film_category fc ON f.film_id = fc.film_id
    INNER JOIN category c ON fc.category_id = c.category_id
    -- inner join multiple tables to connect a payment to its film category, because payments are made for rentals,
    -- and I have to trace them all the way back to the film's category
WHERE -- filters only current year and current quarter
    EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)   --only payments made this year are considered
    AND EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
    -- it matches the current quarter dynamically
GROUP BY -- group results per category name
    c.name
HAVING
    SUM(p.amount) > 0 -- only show categories that actually had sales (revenue > 0)
ORDER BY
    total_sales_revenue DESC; -- sorts the output by highest revenue first
    
    
/*Task 2. Create a query language functions
Create a query language function called 'get_sales_revenue_by_category_qtr' that accepts one parameter representing
the current quarter and year and returns the same result as the 'sales_revenue_by_category_qtr' view.*/
    
-- drop function safely, if exists
DROP FUNCTION IF EXISTS get_sales_revenue_by_category_qtr_safe(DATE);

-- create PostgreSQL Function 
CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr_safe(p_date DATE)
-- create new or update the existing function       
RETURNS TABLE ( -- output a table with two columns: category_name (text) and total_sales_revenue (numeric)
    category_name TEXT,
    total_sales_revenue NUMERIC(10,2)
)
LANGUAGE plpgsql -- tells PostgreSQL this is PL/pgSQL
AS $$                         -- dollar quoted function body to hold code
DECLARE
    v_year INT := EXTRACT(YEAR FROM p_date);
    v_quarter INT := EXTRACT(QUARTER FROM p_date);
BEGIN
    IF p_date IS NULL THEN
        RAISE EXCEPTION 'Input date cannot be NULL.';
    END IF;

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
        EXTRACT(YEAR FROM p.payment_date) = v_year
        AND EXTRACT(QUARTER FROM p.payment_date) = v_quarter
    GROUP BY
        c.name
    HAVING
        SUM(p.amount) > 0
    ORDER BY
        total_sales_revenue DESC;
END;
$$;

-- testing the function:

-- usually use
-- SELECT * FROM get_sales_revenue_by_category_qtr_safe(DATE '2025-04-01');



/*Task 3.
Create procedure language functions
Create a function that takes a country as an input parameter and returns the most popular film in that specific country. 
The function should format the result set as follows:
                    Query (example):select * from core.most_popular_films_by_countries(array['Afghanistan','Brazil','United States’]);*/


DROP FUNCTION IF EXISTS core.most_popular_films_by_countries(TEXT[]);

CREATE OR REPLACE FUNCTION core.most_popular_films_by_countries(countries TEXT[])
RETURNS TABLE (
    country_name TEXT,
    film_title TEXT,
    rating TEXT,
    language TEXT,
    length INT,
    release_year INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF countries IS NULL OR array_length(countries, 1) IS NULL THEN
        RAISE EXCEPTION 'Input country list cannot be NULL or empty.';
    END IF;

    RETURN QUERY
    WITH film_rentals AS (
        SELECT
            UPPER(co.country) AS country_name,
            f.title AS film_title,
            f.rating,
            l.name AS language,
            f.length,
            f.release_year,
            COUNT(*) AS rental_count,
            RANK() OVER (PARTITION BY UPPER(co.country) ORDER BY COUNT(*) DESC) AS rk
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
            UPPER(co.country) = ANY (SELECT DISTINCT UPPER(c) FROM unnest(countries) AS c)
        GROUP BY
            co.country, f.title, f.rating, l.name, f.length, f.release_year
    )
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


-- testing function 

-- good input
-- SELECT * FROM core.most_popular_films_by_countries(ARRAY['Afghanistan','Brazil','United States']);


/*Task 4. 
Create procedure language functions
Create a function that generates a list of movies available in stock based on a partial title match (e.g., movies containing the word 'love' in their title). 
The titles of these movies are formatted as '%...%', and if a movie with the specified title is not in stock, return a message indicating that it was not found.
The function should produce the result set in the following format (note: the 'row_num' field is an automatically generated counter field, starting from 1 and incrementing for each entry, e.g., 1, 2, ..., 100, 101, ...).

Query (example):select * from core.films_in_stock_by_title('%love%’);*/

DROP FUNCTION IF EXISTS core.films_in_stock_by_title(TEXT);

CREATE OR REPLACE FUNCTION core.films_in_stock_by_title(p_title TEXT)
RETURNS TABLE (
    row_num INT,
    film_title TEXT,
    language TEXT,
    customer_name TEXT,
    rental_date TIMESTAMP
)
LANGUAGE plpgsql
AS $$
DECLARE
    clean_title TEXT := TRIM(p_title);
    counter INT := 0;
BEGIN
    IF clean_title IS NULL OR clean_title = '' THEN
        RAISE EXCEPTION 'Input title cannot be NULL or empty.';
    END IF;

    RETURN QUERY
    SELECT
        nextval('row_seq')::INT AS row_num,
        f.title,
        l.name,
        CONCAT(cu.first_name, ' ', cu.last_name),
        r.rental_date
    FROM
        inventory i
        INNER JOIN film f ON i.film_id = f.film_id
        INNER JOIN language l ON f.language_id = l.language_id
        LEFT JOIN rental r ON i.inventory_id = r.inventory_id
        LEFT JOIN customer cu ON r.customer_id = cu.customer_id
    WHERE
        f.title ILIKE clean_title
        AND i.inventory_id NOT IN (
            SELECT inventory_id FROM rental WHERE return_date IS NULL
        );

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No films matching "%" are currently available.', clean_title;
    END IF;
END;
$$;

-- testing procedure

-- it must be defined this sequence once:
-- CREATE SEQUENCE IF NOT EXISTS row_seq START 1;
-- correct input
-- SELECT * FROM core.films_in_stock_by_title('%love%');




/*Task 5.
Create procedure language functions

Create a procedure language function called 'new_movie' that takes a movie title as a parameter and inserts a new movie
with the given title in the film table. The function should generate a new unique film ID, set the rental rate to 4.99, the rental 
duration to three days, the replacement cost to 19.99. The release year and language are optional and by default should be current year 
and Klingon respectively. The function should also verify that the language exists in the 'language' table. 
Then, ensure that no such function has been created before; if so, replace it.*/


DROP FUNCTION IF EXISTS new_movie(TEXT, INT, TEXT);

CREATE OR REPLACE FUNCTION new_movie(
    p_title TEXT,
    p_release_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
    p_language TEXT DEFAULT 'Klingon'
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_language_id INT;
    v_new_film_id INT;
BEGIN
    IF EXISTS (
        SELECT 1 FROM film WHERE UPPER(title) = UPPER(p_title)
    ) THEN
        RAISE EXCEPTION 'A film with the title "%" already exists.', p_title;
    END IF;

    SELECT language_id
    INTO v_language_id
    FROM language
    WHERE UPPER(name) = UPPER(p_language);

    IF v_language_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist.', p_language;
    END IF;

    SELECT COALESCE(MAX(film_id), 0) + 1
    INTO v_new_film_id
    FROM film;

    INSERT INTO film (
        film_id, title, release_year, language_id,
        rental_duration, rental_rate, replacement_cost, last_update
    )
    VALUES (
        v_new_film_id, p_title, p_release_year, v_language_id,
        3, 4.99, 19.99, NOW()
    );

    RETURN v_new_film_id;
END;
$$;

-- testing procedure

-- SELECT new_movie('Sky Raiders');







