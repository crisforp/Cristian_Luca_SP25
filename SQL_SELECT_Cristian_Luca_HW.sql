--Part 1: Write SQL queries to retrieve the following data

--All animation movies released between 2017 and 2019 with rate more than 1, alphabetical

SELECT f.title,
            f.release_year, 
            f.rental_rate
FROM film f
            inner JOIN film_category f_c ON f.film_id = f_c.film_id
            inner JOIN category c ON fc.category_id = c.category_id
WHERE c.name = 'Animation'
            AND f.release_year BETWEEN 2017 AND 2019
            AND f.rental_rate > 1
ORDER BY f.title;

/*
 Explanation:
 
- film (f): contains movie details (title, release_year, rental_rate).
- film_category (f_c): a bridge table that handles the many-to-many relationship between film and category.
- inner JOIN film_category fc ON f.film_id = fc.film_id:
connects the film table with film_category, ensuring we only retrieve films that have an entry in the film_category table.
- inner JOIN category c ON fc.category_id = c.category_id:
links film_category with category, allowing us to filter animation movies (c.name = 'Animation').
- category (c): a table which contains film genres or classifications with primary key category_id.
- release_year BETWEEN 2017 AND 2019:  filter years with releases from 2017 to 2019.
- rental_rate > 1: filter only movies with a rate greater than 1.
- ORDER BY f.title: sorting alphabetical order.

 */

-- The revenue earned by each rental store after March 2017 (columns: address and address2 – as one column, revenue)

SELECT 
           a.address ||' '||COALESCE(a.address2, '') AS entire_address,
           SUM(p.amount) AS revenue
FROM payment p
          JOIN rental r ON p.rental_id = r.rental_id
          JOIN inventory i ON r.inventory_id = i.inventory_id
          JOIN store s ON i.store_id = s.store_id
          JOIN address a ON s.address_id = a.address_id
WHERE p.payment_date >= '2017-04-01'
GROUP BY entire_address
ORDER BY revenue DESC;

/*
 Explanation:
 
- a.address ||' ' || COALESCE(a.address2, '')) AS enire_address:
concatenate address and address2 into one column; COALESCE() is used to handle NULL values in address2.
- SUM(p.amount) AS revenue:
aggregates the total revenue for each store from the payment table.
- joins:
payment → rental: links payments to rentals.
rental → inventory: finds which inventory item was rented.
inventory → store: identifies the store.
store → address: Fetches the store's address.
- WHERE p.payment_date > '2017-04-01':
filters payments made after March 2017.
- GROUP BY entire_address:
groups results by store address to calculate revenue for each store.
- ORDER BY revenue DESC:
sorts stores from highest to smallest revenue.

 * */

--Top-5 actors by number of movies (released after 2015) they took part in 
--(columns: first_name, last_name, number_of_movies, sorted by number_of_movies in descending order)

SELECT 
              a.first_name, 
              a.last_name, 
              COUNT(f.film_id) AS number_movies
FROM actor a
              inner JOIN film_actor f_a ON a.actor_id = f_a.actor_id
              inner JOIN film f ON f_a.film_id = f.film_id
WHERE f.release_year > 2015
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY number_movies DESC
LIMIT 5;

/*
 Explanation:
 
- inner JOIN film_actor fa ON a.actor_id = fa.actor_id:
links actors to the movies they acted in.
- inner JOIN film f ON fa.film_id = f.film_id:
gets movie details, including the release year.
- WHERE f.release_year > 2015:
filters only movies released after 2015.
- COUNT(f.film_id) AS number_movies:
counts the number of films each actor appeared in.
- GROUP BY a.actor_id, a.first_name, a.last_name:
groups by actor: actor_id, first_name, last_name to get their movie count.
- ORDER BY number_movies DESC:
sorts actors by the greatest number of movies first.
- LIMIT 5:
returns only the top 5 actors.

 */

--Number of Drama, Travel, Documentary per year (columns: release_year, number_of_drama_movies, 
--number_of_travel_movies, number_of_documentary_movies), sorted by release year in descending order.
-- Dealing with NULL values is encouraged)

SELECT 
              f.release_year,
              COALESCE(SUM(CASE 
                                                    WHEN c.name = 'Drama' THEN 1 ELSE 0
                                             END), 0) AS number_of_drama_movies,
              COALESCE(SUM(CASE 
                                                    WHEN c.name = 'Travel' THEN 1 ELSE 0 
                                             END), 0) AS number_of_travel_movies,
              COALESCE(SUM(CASE 
                                                  WHEN c.name = 'Documentary' THEN 1 ELSE 0 
                                             END), 0) AS number_of_documentary_movies
FROM   film f
              inner JOIN film_category f_c ON f.film_id = f_c.film_id
              inner JOIN category c ON f_c.category_id = c.category_id
WHERE c.name IN ('Drama', 'Travel', 'Documentary')
GROUP BY f.release_year
ORDER BY f.release_year DESC;

/*
 Explanation:
 
- if a year has no Travel or Documentary movies, without COALESCE, it would return NULL.
- using COALESCE(..., 0), I ensure that missing counts appear as 0 (in case a year has no movies in a category), making the data more readable.
- inner JOIN film_category fc ON f.film_id = fc.film_id:
connects movies with their respective categories.
- inner JOIN category c ON fc.category_id = c.category_id:
gets the category names.
- WHERE c.name IN ('Drama', 'Travel', 'Documentary'):
filters only these three categories of interest.
- SUM(CASE WHEN c.name = 'Drama' THEN 1 ELSE 0 END):
counts movies for each category for each year; I use CASE to count only relevant movies while treating others as 0.
- GROUP BY f.release_year:
aggregates counts for each release year.
- ORDER BY f.release_year DESC:
sorts results by release year in descending order.

 */

-- Part 2: Solve the following problems using SQL

/*
 1. Which three employees generated the most revenue in 2017? 
 They should be awarded a bonus for their outstanding performance. 

Assumptions: 
staff could work in several stores in a year, please indicate which store the staff worked in (the last one);
if staff processed the payment then he works in the same store; 
take into account only payment_date

2. Which 5 movies were rented more than others (number of rentals), 
and what's the expected age of the audience for these movies? 
To determine expected age please use 'Motion Picture Association film rating system

*/

--Can these tasks be solved using CTE? I'm studying! Thank you so much!


--Part 3. Which actors/actresses didn't act for a longer period of time than the others? 

--V1: V1: gap between the latest release_year and current year per each actor;

SELECT 
             a.first_name, 
             a.last_name, 
             MAX(f.release_year) AS latest_movie_year, 
             (DATE_PART('Year', NOW()) - MAX(f.release_year)) AS years_since_last_movie
FROM actor a
            inner JOIN film_actor fa ON a.actor_id = fa.actor_id
            inner JOIN film f ON fa.film_id = f.film_id
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY years_since_last_movie DESC;

/*
 Explanation:
 
-  to extract the desired date field from the current date, let’s pass a field to be extracted ( 'Year' in our case)
 as a first argument and a NOW() function as the second argument to the DATE_PART() function.
 - find the latest movie per actor:
MAX(f.release_year) gets the most recent movie an actor appeared in.
- calculate the gap from the current year:
(DATE_PART('Year', NOW()) - MAX(f.release_year))  AS years_since_last_movie
---> calculates how many years have passed since their last movie.
-group by actor:
ensures I get the most recent movie for each unique actor.
- sort by years_since_last_movie DESC:
 actors which didn't act for the longest period of time appears first.

 */
 
--V2: gaps between sequential films per each actor;
-- Can this task be solved using CTE? I'm studying! Thank you so much! 

