--Part 1: Write SQL queries to retrieve the following data

--All animation movies released between 2017 and 2019 with rate more than 1, alphabetical


SELECT f.title AS movie_name
FROM public.film f                                                           -- film (f): contains movie details such as title aliasing movie_name                                    
                                                                                         -- film_category (f_c): a bridge table that handles the many-to-many relationship between film and category
INNER JOIN public.film_category f_c ON f.film_id = f_c.film_id    --connects the film table with film_category, ensuring we only retrieve films that have an entry in the film_category table
            INNER JOIN public.category c ON f_c.category_id = c.category_id   --links film_category with category
WHERE upper(c.name) = upper( 'Animation')                 -- filter animation movies
            AND f.release_year BETWEEN 2017 AND 2019  -- filter years with releases from 2017 to 2019
            AND f.rental_rate > 1                                            -- filter only movies with a rate greater than 1
ORDER BY movie_name;                                                 -- sorting alphabetical order


-- The revenue earned by each rental store after March 2017 (columns: address and address2 – as one column, revenue)

SELECT 
            trim(a.address ||' '||COALESCE(a.address2, ''))  AS entire_address,  -- leading/trailing/both ---> concatenate address and address2 into one column; COALESCE() is used to handle NULL values in address2
            SUM(p.amount) AS revenue                                                              -- aggregates the total revenue for each store from the payment table
FROM public.payment p
            INNER JOIN public.rental r ON p.rental_id = r.rental_id                 -- links payments to rentals
            INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id  -- finds which inventory item was rented
            INNER JOIN public.store s ON i.store_id = s.store_id                     -- identifies the store
            INNER JOIN public.address a ON s.address_id = a.address_id         -- fetches the store's address
WHERE p.payment_date >= '2017-04-01'                                                     -- filters payments made after March 2017
GROUP BY entire_address                                                                           -- groups results by store address to calculate revenue for each store
ORDER BY revenue DESC;                                                                        -- sorts stores from highest to smallest revenue



--Top-5 actors by number of movies (released after 2015) they took part in 
--(columns: first_name, last_name, number_of_movies, sorted by number_of_movies in descending order)

SELECT 
              a.first_name, 
              a.last_name, 
              COUNT(f.film_id) AS number_movies                                             -- counts the number of films each actor appeared in
FROM   public.actor a
              INNER JOIN public.film_actor f_a ON a.actor_id = f_a.actor_id     -- links actors to the movies they acted in
              INNER JOIN public.film f ON f_a.film_id = f.film_id                    -- gets movie details, including the release year
WHERE f.release_year > 2015                                                                       -- filters only movies released after 2015
GROUP BY a.actor_id, a.first_name, a.last_name                                            -- groups by actor: actor_id, first_name, last_name to get their movie count
ORDER BY number_movies DESC                                                                -- sorts actors by the greatest number of movies first
LIMIT 5;                                                                                                      -- returns only the top 5 actors


--Number of Drama, Travel, Documentary per year (columns: release_year, number_of_drama_movies, 
--number_of_travel_movies, number_of_documentary_movies), sorted by release year in descending order.
-- Dealing with NULL values is encouraged)

SELECT 
              f.release_year,
             SUM(CASE                                                                                                -- counts movies for each category for each year; 
                                WHEN c.name = 'Drama' THEN 1 ELSE 0                           -- I use CASE to count only relevant movies while treating others as 0
                       END) AS number_of_drama_movies,                                                
              SUM(CASE 
                                 WHEN c.name = 'Travel' THEN 1 ELSE 0 
                       END) AS number_of_travel_movies,
              SUM(CASE 
                                 WHEN c.name = 'Documentary' THEN 1 ELSE 0 
                       END) AS number_of_documentary_movies
FROM   public.film f
              INNER JOIN public.film_category f_c ON f.film_id = f_c.film_id                  -- connects movies with their respective categories
              INNER JOIN public.category c ON f_c.category_id = c.category_id                 -- gets the category names
WHERE upper(c.name)  IN (upper('Drama') , upper('Travel') , upper('Documentary')) --filters only these three categories of interest
GROUP BY f.release_year                                                                                             -- aggregates counts for each release year
ORDER BY f.release_year DESC;                                                                                 -- sorts results by release year in descending order



 
 
/* 
Part 2: Solve the following problems using SQL

1. Which three employees generated the most revenue in 2017? They should be awarded a bonus for their outstanding performance. 

Assumptions: 
staff could work in several stores in a year, please indicate which store the staff worked in (the last one);
if staff processed the payment then he works in the same store; 
take into account only payment_date
*/

WITH staff_revenue AS (    --First part
    SELECT 
                  p.staff_id, 
                  SUM(p.amount) AS total_revenue
    FROM public.payment p
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
    GROUP BY p.staff_id
)
SELECT                            --Third part
              s_r.staff_id, 
              s.first_name, 
              s.last_name, 
    (
        SELECT s2.store_id    --Second part
        FROM public.payment p2
        INNER JOIN staff s2 ON p2.staff_id = s2.staff_id
        WHERE p2.staff_id = s_r.staff_id
        ORDER BY p2.payment_date DESC 
        LIMIT 1
    ) AS store_id,
    s_r.total_revenue
FROM staff_revenue s_r
JOIN public.staff s ON s_r.staff_id = s.staff_id
ORDER BY s_r.total_revenue DESC
LIMIT 3;

/*Explanation:
 
First part (CTE, operator WITH) --->  calculate total revenue for every staff for 2017:
-get only payments from 2017 (EXTRACT(YEAR FROM p.payment_date) = 2017).
-groups data by staff_id.
-calculates total revenue (SUM(p.amount)) for every staff.

Second part(subquery) ---> for each staff in staff_revenue find the last store the staff worked in:
-finds all their payment transactions (FROM payment p2).
-joins with staff to get the store_id (JOIN staff s2 ON p2.staff_id = s2.staff_id).
-filters records only for the current staff (WHERE p2.staff_id = sr.staff_id).
-sorts by payment_date DESC to obtain the most recent payment.
-I use LIMIT 1 to return only the last store.

Third part:
- joins the staff_revenue table with the staff table to get names.
- fetches the last store using subquery.
-sorts by total revenue in descending order (ORDER BY sr.total_revenue DESC).
- I use LIMIT 3 to return three employees generated the most revenue in 2017.

 */


/*
 Part 2: Solve the following problems using SQL
 
 2. Which 5 movies were rented more than others (number of rentals), 
 and what's the expected age of the audience for these movies? 
 To determine expected age please use 'Motion Picture Association film rating system
 */


WITH movie_rentals AS ( -- First part: count the number of times each film was rented
    SELECT 
                  f.film_id,
                  f.title,
                  f.rating,
                  COUNT(r.rental_id) AS rental_count
    FROM public.rental r
    INNER JOIN  public.inventory i ON r.inventory_id = i.inventory_id
    INNER JOIN public.film f ON i.film_id = f.film_id
    GROUP BY f.film_id, f.title, f.rating
)
SELECT                      -- Second part: determine expected audience age using 'Motion Picture Association' film rating system
              film_id, 
              title, 
              rental_count, 
              rating , 
    CASE 
              WHEN rating = 'G' THEN 'All ages'
              WHEN rating = 'PG-13' THEN 'Inappropriate for Children Under 13'
              WHEN rating = 'R' THEN 'Children Under 17 Require Accompanying Adult'
              WHEN rating = 'NC-17' THEN 'Inappropriate for Children Under 17'
              WHEN rating = 'PG' THEN 'Parental Guidance Suggested'
              ELSE 'unknown'
    END AS expected_audience_age
FROM movie_rentals
ORDER BY rental_count DESC
LIMIT 5;
    

/*
Explanation:
 
- count rentals for every film (COUNT(r.rental_id) AS rental_count):
joins rental ---> inventory --> film to count rentals for every film_id.
- group by film (GROUP BY f.film_id, f.title, f.rating):
ensures I get counts for every  movie.
- determine expected_audience_age (CASE Statement):
using recomended 'Motion Picture Association' film rating system.
'G' -> 'All Ages'
'PG-13'-> 'Inappropriate for Children Under 13'
'R'->'Children Under 17 Require Accompanying Adult'
'NC-17'->'Inappropriate for Children Under 17'
'PG'-> 'Parental Guidance Suggested'
 */



--Part 3. Which actors/actresses didn't act for a longer period of time than the others? 

--V1:  gap between the latest release_year and current year per each actor;

SELECT 
             a.first_name, 
             a.last_name, 
             MAX(f.release_year) AS latest_movie_year,                                                             --  gets the most recent movie an actor appeared in
             (DATE_PART('Year', NOW()) - MAX(f.release_year)) AS years_since_last_movie   -- calculates how many years have passed since their last movie
FROM public.actor a
            INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
            INNER JOIN public.film f ON fa.film_id = f.film_id
GROUP BY a.actor_id, a.first_name, a.last_name                                                                -- ensures I get the most recent movie for each unique actor
ORDER BY years_since_last_movie DESC;                                                                       -- actors which didn't act for the longest period of time appears first



 


