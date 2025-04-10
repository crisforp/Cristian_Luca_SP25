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
    c.name AS category_name,                                                             -- pulls the name of the category
    SUM(p.amount) AS total_sales_revenue c.name AS category_name: --calculates sum of payments for each category
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
    EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE) --only payments made this year are considered
    AND CEIL(EXTRACT(MONTH FROM p.payment_date) / 3.0) = CEIL(EXTRACT(MONTH FROM CURRENT_DATE) / 3.0)
    -- only payments from the same quarter are considered      EXTRACT(MONTH FROM p.payment_date) gets the month
    -- dividing the month by 3 and applying CEIL(), mathematical function --> rounds up to the correct quarter number 
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
DROP FUNCTION IF EXISTS get_sales_revenue_by_category_qtr_safe(qtr INT, yr INT);

-- create PostgreSQL Function 
CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr_safe(qtr INT, yr INT) 
-- create new or update the existing function       input parameters: quarter (like 1-4) and year (like 2025)    
RETURNS TABLE ( -- output a table with two columns: category_name (text) and total_sales_revenue (numeric)
    category_name TEXT,
    total_sales_revenue NUMERIC(10,2)
)
LANGUAGE plpgsql -- tells PostgreSQL this is PL/pgSQL
AS $$                         -- dollar quoted function body to hold code
BEGIN
    -- validate quarter input: if it’s NULL or invalid, the function stops immediately with an error ( RAISE EXCEPTION) 
    IF qtr IS NULL THEN
        RAISE EXCEPTION 'Quarter value cannot be NULL.';
    ELSIF qtr NOT BETWEEN 1 AND 4 THEN
        RAISE EXCEPTION 'Quarter value (%) is invalid. Must be between 1 and 4.', qtr;
    END IF;

    -- validate year input: first checks for NULL; allows only years from 1900 up to current year + 15 (for future planning)
    IF yr IS NULL THEN
        RAISE EXCEPTION 'Year value cannot be NULL.';
    ELSIF yr < 1900 OR yr > EXTRACT(YEAR FROM CURRENT_DATE)::INT + 15 THEN
        RAISE EXCEPTION 'Year value (%) is invalid. Must be between 1900 and %.', yr, EXTRACT(YEAR FROM CURRENT_DATE)::INT + 15;
    --  EXTRACT(YEAR FROM CURRENT_DATE)::INT gets current year
  END IF;

    -- run the main query
    RETURN QUERY 
    -- PostgreSQL execute SELECT, collect all the resulting rows and columns, and send them back (all at once) to person who called the function
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
        EXTRACT(YEAR FROM p.payment_date) = yr   -- it filters by year and quarter passed in from the function parameters: yr, qtr
        AND CEIL(EXTRACT(MONTH FROM p.payment_date) / 3.0) = qtr
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
SELECT * FROM get_sales_revenue_by_category_qtr_safe(3, 2025);

-- error test: invalid quarter
SELECT * FROM get_sales_revenue_by_category_qtr_safe(6, 2025);

-- error test: invalid year
SELECT * FROM get_sales_revenue_by_category_qtr_safe(3, 1851);

-- error test: NULL input
SELECT * FROM get_sales_revenue_by_category_qtr_safe(NULL, 2025);

-- each wrong case will RAISE EXCEPTION.


/*Task 3.
Create procedure language functions
Create a function that takes a country as an input parameter and returns the most popular film in that specific country. 
The function should format the result set as follows:
                    Query (example):select * from core.most_popular_films_by_countries(array['Afghanistan','Brazil','United States’]);*/


DROP FUNCTION IF EXISTS core.most_popular_film_by_country(single_country TEXT);

CREATE OR REPLACE FUNCTION core.most_popular_film_by_country(single_country TEXT) --takes one country name as text input (such as 'Afghanistan')
RETURNS TABLE ( -- this function will return multiple columns (like a table structure)
    country_name TEXT,
    film_title TEXT,
    rating TEXT,
    language TEXT,
    length INT,
    release_year INT
)
LANGUAGE plpgsql
AS $$
BEGIN -- every PL/pgSQL function must have a BEGIN ... END block, where you control the operations
    -- input validation
  IF single_country IS NULL OR TRIM(single_country) = '' THEN
        RAISE EXCEPTION 'Input country cannot be NULL or empty.';
    END IF;

    RETURN QUERY  --  used to run a SELECT and return its rows directly; it fills the output table structure
    WITH film_rentals AS ( -- a CTE: temporary result set to organize the complex query more clean
        SELECT
            co.country AS country_name,
            f.title AS film_title,
            f.rating,
            l.name AS language,
            f.length,
            f.release_year,
            COUNT(*) AS rental_count, -- counts how many times each film was rented
            ROW_NUMBER() OVER (PARTITION BY co.country ORDER BY COUNT(*) DESC) AS rn -- for each country orders the films by rental count ( first will be most rented)
        FROM
            rental r
        INNER JOIN inventory i ON r.inventory_id = i.inventory_id -- joining tables to follow how rentals are linked to films and customer locations
        INNER JOIN  film f ON i.film_id = f.film_id
        INNER JOIN  language l ON f.language_id = l.language_id
        INNER JOIN  customer cu ON r.customer_id = cu.customer_id
        INNER JOIN  address a ON cu.address_id = a.address_id
        INNER JOIN  city ci ON a.city_id = ci.city_id
        INNER JOIN  country co ON ci.country_id = co.country_id
        WHERE
            co.country = single_country -- filter rentals for the country given as input
        GROUP BY
            co.country, f.title, f.rating, l.name, f.length, f.release_year -- groups data in the correct order for aggregation 
    )
    select -- returns the six fields expected by the function's RETURNS TABLE
        country_name,
        film_title,
        rating,
        language,
        length,
        release_year
    FROM
        film_rentals
    WHERE
        rn = 1;  -- pick the most rented film for the country
END;
$$;

-- testing function 

-- good input
SELECT * FROM core.most_popular_film_by_country('Afganistan');

-- NULL input
SELECT * FROM core.most_popular_film_by_country(NULL);

-- empty input
SELECT * FROM core.most_popular_film_by_country('');



/*Task 4. 
Create procedure language functions
Create a function that generates a list of movies available in stock based on a partial title match (e.g., movies containing the word 'love' in their title). 
The titles of these movies are formatted as '%...%', and if a movie with the specified title is not in stock, return a message indicating that it was not found.
The function should produce the result set in the following format (note: the 'row_num' field is an automatically generated counter field, starting from 1 and incrementing for each entry, e.g., 1, 2, ..., 100, 101, ...).

Query (example):select * from core.films_in_stock_by_title('%love%’);*/

CREATE OR REPLACE FUNCTION core.films_in_stock_by_title(partial_title TEXT) -- input text for partial search (example: %love%)
RETURNS TABLE ( -- outputs a table with row number, film title, language, customer name, rental date
    row_num INT,
    film_title TEXT,
    language TEXT,
    customer_name TEXT,
    rental_date TIMESTAMP
)
LANGUAGE plpgsql
AS
$$

  DECLARE
    clean_title TEXT;
BEGIN
    -- trim input (spaces)
    clean_title := TRIM(partial_title);

    -- validate input after trimming
    IF clean_title IS NULL OR clean_title = '' THEN -- checks if trimmed input is empty or NULL
        RAISE EXCEPTION 'input title cannot be NULL or empty after trimming.'; 
    END IF;
  
    RETURN QUERY -- executes and returns the SELECT query result set
    WITH available_films AS ( -- CTE: organizes all logic about available films
        SELECT
            f.title AS film_title,
            l.name AS language,
            CONCAT(cu.first_name, ' ', cu.last_name) AS customer_name,
            r.rental_date
        FROM
            inventory i
        INNER JOIN film f ON i.film_id = f.film_id
        INNER JOIN language l ON f.language_id = l.language_id
        LEFT JOIN rental r ON i.inventory_id = r.inventory_id --show last rental, last customer information if available
        LEFT JOIN customer cu ON r.customer_id = cu.customer_id
        WHERE
            f.title ILIKE partial_title --  case-insensitive search
            AND i.inventory_id NOT IN ( -- only show films that are not rented
                SELECT rental.inventory_id
                FROM rental
                WHERE return_date IS NULL
            )
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY film_title) AS row_num, --  adds auto-incrementing row number to results
        film_title,
        language,
        customer_name,
        rental_date
    FROM available_films;

    -- raise EXCEPTION if no rows found
    IF NOT FOUND then --FOUND is a special variable automatically set by PostgreSQL: TRUE if rows were found, FALSE if no rows were found
        RAISE EXCEPTION 'no films matching "%" are currently available', clean_title;
    END IF;

END;
$$;

-- testing procedure

-- correct input
SELECT * FROM core.films_in_stock_by_title('  %love%  ');

-- empty input
SELECT * FROM core.films_in_stock_by_title('   ');

-- no matching films
SELECT * FROM core.films_in_stock_by_title('%nonexistentfilm%');



/*Task 5.
Create procedure language functions

Create a procedure language function called 'new_movie' that takes a movie title as a parameter and inserts a new movie
with the given title in the film table. The function should generate a new unique film ID, set the rental rate to 4.99, the rental 
duration to three days, the replacement cost to 19.99. The release year and language are optional and by default should be current year 
and Klingon respectively. The function should also verify that the language exists in the 'language' table. 
Then, ensure that no such function has been created before; if so, replace it.*/


CREATE OR REPLACE FUNCTION new_movie(
    p_title TEXT, -- input: movie title (required)
    p_release_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE), -- input: release year, defaults to this year if not given
    p_language TEXT DEFAULT 'Klingon' --  input: Language name, defaults to 'Klingon'
)
RETURNS INT  -- function: returns the new film_id
LANGUAGE plpgsql
AS
$$
DECLARE
    v_language_id INT; -- declare local variables: v_language_id, v_new_film_id
    v_new_film_id INT;
BEGIN
    -- check if the language exists
    SELECT language_id
    INTO v_language_id -- saves language_id into v_language_id
    FROM language
    WHERE name = p_language;

    IF v_language_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" does not exist.', p_language; --throws an error 
    END IF;

    -- takes the highest existing film_id, adds 1;     manual id generation (because maybe no auto-increment)
    SELECT COALESCE(MAX(film_id), 0) + 1 -- COALESCE(MAX(...), 0) ensures if no films exist, it starts from 1
    INTO v_new_film_id
    FROM film;

    -- adds the new movie into the film table
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
        3,                 -- rental_duration (default value)
        4.99,             -- rental_rate (default value)
        19.99,           -- replacement_cost (default value)
        NOW()        -- NOW() records the timestamp for last update
    );

    -- after inserting, returns the new id so you know which movie was created
    RETURN v_new_film_id;
END;
$$;

-- testing procedure

-- insert a film with default release year and default language
SELECT new_movie('The Space Adventure');

-- insert with specific release year and specific language
SELECT new_movie('Alien Returns', 2024, 'English');







