-- Task 1

--Start a Transaction

BEGIN;
--Task 1a: 
/*Choose your top-3 favorite movies and add them to the 'film' table (films with the title Film1, Film2, etc - 
will not be taken into account and grade will be reduced)*/


-- ensure movies don’t already exist before inserting
INSERT INTO public.film (title, description, release_year, language_id, rental_duration, rental_rate, replacement_cost, rating, last_update)
                                                                                                     -- which columns will be populated in the film table  
                                                                                                     -- the last_update column is always set to today’s date to track changes
                                                                                                      
--  inserts multiple rows in a single query instead of running INSERT multiple times
SELECT title, description, release_year,
               (SELECT language_id FROM public.language WHERE name = 'Romanian'),   -- get Romanian language_id dynamically
                rental_duration, rental_rate, replacement_cost, CAST(rating AS mpaa_rating), CURRENT_DATE
FROM (VALUES                                                                        -- uses VALUES to insert multiple rows
                                                                                                    -- sets last_update dynamically instead of hardcoding a date
                          ('Morometii', 'Povestea familiei Moromete în anii 1930.', 1987, 7, 4.99, 19.99, 'PG'),
                          ('Filantropica', 'Un scriitor se implică într-o retea de cersetorie.', 2002, 14, 9.99, 24.99, 'PG-13'),
                          ('4 luni, 3 săptămâni si 2 zile', 'Drama a două studente în perioada comunistă.', 2007, 21, 19.99, 29.99, 'R')
) AS new_movies(title, description, release_year, language_id, rental_duration, rental_rate, replacement_cost, rating)
WHERE NOT EXISTS (                                                             -- prevents duplicates
    SELECT 1 FROM public.film WHERE film.title = new_movies.title   -- only insert this movie if no movie already exists with the same title
)
RETURNING film_id;                                                                 -- returns the ids of newly inserted movies; maybe adding them later to inventory table


-- Task 1b
-- Fill in rental rates with 4.99, 9.99 and 19.99 and rental durations with 1, 2 and 3 weeks respectively.

-- See the solution for Task 1a:
-- Moromtii  -> duration=1, rate=4.99
-- Filantropica -> duration=2, rate=9.99
-- 4 luni, 3 săptămâni si 2 zile -> duration=3, rate=19.99


-- Task 1c
/*Add the actors who play leading roles in your favorite movies to the 'actor' and 'film_actor' tables (6 or more actors in total). 
Actors with the name Actor1, Actor2, etc - will not be taken into account and grade will be reduced.*/

-- insert actors if they do not exist
INSERT INTO public.actor (first_name, last_name, last_update)
SELECT first_name, last_name, CURRENT_DATE
FROM (VALUES                                                            -- define a list of new actors using VALUES (...)
                                                                                        -- this list becomes a temporary dataset called new_actors
            ('Victor', 'Rebengiuc'),
            ('Luminita', 'Gheorghiu'),
            ('Mircea', 'Diaconu'),
            ('Gheorghe', 'Dinica'),
            ('Anamaria', 'Marinca'),
            ('Vlad', 'Ivanov')
) AS new_actors(first_name, last_name)
WHERE NOT EXISTS (
    SELECT 1 FROM public.actor WHERE actor.first_name = new_actors.first_name AND actor.last_name = new_actors.last_name
                                                                                        -- for each actor: this query checks if the combination of 
                                                                                        -- (first_name, last_name) already exists in the actor table using NOT EXISTS
                                                                                        -- if not, it inserts the actor into the actor table
    )
RETURNING actor_id;

-- link actors to movies
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE                         -- this query reads from the actor table (using first_name, last_name)
                                                                                                       -- CURRENT_DATE fills the last_update field automatically
FROM public.actor a
INNER JOIN public.film f ON ( (a.first_name, a.last_name), f.title ) IN (   -- it creates pairs of (actor_id, film_id) for the film_actor bridge table
             (('Victor', 'Rebengiuc'), 'Morometii'),
            (('Luminita', 'Gheorghiu'), 'Morometii'),
            (('Mircea', 'Diaconu'), 'Filantropica'),
            (('Gheorghe', 'Dinică'), 'Filantropica'),
            (('Anamaria', 'Marinca'), '4 luni, 3 săptămâni si 2 zile'),
            (('Vlad', 'Ivanov'), '4 luni, 3 săptămâni si 2 zile')
)
WHERE NOT EXISTS (                                                               -- checks if the combination of actor_id and film_id already exists using NOT EXISTS.
                                                                                                        -- if not, it inserts the record into film_actor
                                                                                                        -- ensures actors don’t already exist
    SELECT 1 FROM public.film_actor WHERE film_actor.actor_id = a.actor_id AND film_actor.film_id = f.film_id
);
-- I used INNER JOIN and WHERE NOT EXISTS to avoid duplicate actor-film relationships


-- Task 1d
-- Add your favorite movies to any store's inventory.

INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT f.film_id, s.store_id, CURRENT_DATE
FROM public.film f
INNER JOIN public.store s ON s.store_id IN (                           -- it combine every film with every store
    SELECT store_id FROM store
)                                                                                         -- dynamically selects all stores for add copies of the favorite movies
WHERE f.title IN ('Morometii', 'Filantropica', '4 luni, 3 săptămâni si 2 zile')     -- filter the favorites films
AND NOT EXISTS (                                                        -- only insert if this movie isn't already present in that  store's inventory
    SELECT 1 FROM public.inventory WHERE inventory.film_id = f.film_id AND inventory.store_id = s.store_id
)
RETURNING inventory_id;                                               -- after inserting, I will get back the ids of the new inventory records I just added


-- Task 1e
/*Alter any existing customer in the database with at least 43 rental and 43 payment records. 
Change their personal data to yours (first name, last name, address, etc.). 
You can use any existing address from the "address" table. 
Please do not perform any updates on the "address" table, 
as this can impact multiple records with the same address.*/


-- select a customer I'm focusing on
WITH target_customers AS (
        SELECT c.customer_id FROM public.customer c
        INNER JOIN public.rental r ON c.customer_id = r.customer_id
        INNER JOIN public.payment p ON c.customer_id = p.customer_id
        GROUP BY c.customer_id                                                                -- is grouping by customer; I get counts for every customer
        HAVING COUNT(DISTINCT r.rental_id) >= 43 AND COUNT(DISTINCT p.payment_id) >= 43
        LIMIT 1                                                                                           -- picks only one customer
)
-- Update selected customer’s personal details
UPDATE public.customer
SET first_name = 'Monica',
        last_name = 'Luca',
        email = 'lucamonicadaniela@yahoo.com',
        address_id = ( SELECT address_id FROM public.address ORDER BY RANDOM() LIMIT 1), -- address_id is picked randomly from the existing addresses
                                                                                                               -- this ensures I'm reusing an existing address instead of creating one
        last_update = CURRENT_DATE                                                   -- update to CURRENT_DATE
WHERE customer_id = (SELECT customer_id FROM target_customers);


-- Task 1f: Delete Records Related to Customer (Except Customer & Inventory)
-- Remove any records related to you (as a customer) from all tables except 'Customer' and 'Inventory'


-- get customer id for deletion
WITH target AS (
    SELECT customer_id FROM public.customer WHERE email = 'lucamonicadaniela@yahoo.com'
)
/*this CTE is useful for:
avoid repeating the SELECT customer_id query twice.
improve readability.
improve performance if more queries depend on this customer.*/

-- delete payments to this customer 
WITH target AS (SELECT customer_id FROM public.customer WHERE email = 'lucamonicadaniela@yahoo.com')
DELETE FROM public.payment WHERE customer_id IN (SELECT public.customer_id FROM target);
-- delete rentals related to this customer
WITH target AS (SELECT customer_id FROM public.customer WHERE email = 'lucamonicadaniela@yahoo.com')
DELETE FROM public.rental WHERE customer_id IN (SELECT customer_id FROM target);

-- Task 1g
/*Rent you favorite movies from the store they are in and pay for them
(add corresponding records to the database to represent this activity)
(Note: to insert the payment_date into the table payment, you can create a new partition 
(see the scripts to install the training database ) or add records for the
first half of 2017)*/


-- adds new rental records to the rental table
INSERT INTO public.rental (rental_date, inventory_id, customer_id, staff_id, return_date, last_update)
/*rental_date set to CURRENT_DATE
inventory_id  set the idof the movie copy being rented
customer_id set the customer making the rental (in this case the one with email lucamonicadaniela@yahoo.com)
staff_id set the staff member responsible for this rental, associated with the store
return_date: planned return date is set to 7 days later using CURRENT_DATE + INTERVAL '7 days'
last_update: records the insertion date.*/
SELECT CURRENT_DATE, i.inventory_id, c.customer_id, s.staff_id, CURRENT_DATE + INTERVAL '7 days', CURRENT_DATE
FROM public.inventory i
INNER JOIN public.store st ON i.store_id = st.store_id                                         --connect inventory → store by store_id
INNER JOIN public.staff s ON st.store_id = s.store_id                                           --connect store → staff by store_id (a store has staff)
INNER JOIN public.customer c ON c.email = 'lucamonicadaniela@yahoo.com'        --connect customer → filters specifically for Monica Luca
WHERE i.film_id IN (SELECT film_id FROM public.film WHERE title IN ('Morometii', 'Filantropica', '4 luni, 3 săptămâni și 2 zile'));   --only adds rentals for the 3 favorite movies

-- insert payments into partition + compute payments using correct formula
INSERT INTO public.payment_p2017_01 (customer_id, staff_id, rental_id, amount, payment_date)   -- inserting into a specific partition of the payment table
SELECT 
    r.customer_id,
    r.staff_id,
    r.rental_id,
    CASE                                               -- calculates how much the customer must pay based on how many days they kept the movie using EXTRACT(DAY FROM (r.return_date - r.rental_date))
        WHEN EXTRACT(DAY FROM (r.return_date - r.rental_date)) <= f.rental_duration THEN f.rental_rate
        WHEN EXTRACT(DAY FROM (r.return_date - r.rental_date)) > f.rental_duration * 3 THEN f.replacement_cost
        ELSE f.rental_rate + (EXTRACT(DAY FROM (r.return_date - r.rental_date)) - f.rental_duration)
    END AS amount,
    CURRENT_DATE
FROM public.rental r
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
WHERE r.customer_id = (SELECT customer_id FROM public.customer WHERE email = 'lucamonicadaniela@yahoo.com');



-- commit Transaction
COMMIT;



/*Before COMMIT, it's okay to verify changes:
SELECT * FROM public.film WHERE title IN ('Morometii', 'Filantropica', '4 luni, 3 săptămâni si 2 zile');
SELECT * FROM public.actor WHERE last_name IN ('Rebengiuc', 'Diaconu');
SELECT * FROM public.inventory WHERE film_id IN (SELECT film_id FROM public.film WHERE title IN ('Morometii', 'Filantropica', '4 luni, 3 săptămâni si 2 zile') );
SELECT * FROM public.rental WHERE customer_id = (SELECT customer_id FROM public.customer WHERE email = 'lucamonicadaniela@yahoo.com');
SELECT * FROM public.payment WHERE customer_id = (SELECT customer_id FROM public.customer WHERE email = 'lucamonicadaniela@yahoo.com');*/
