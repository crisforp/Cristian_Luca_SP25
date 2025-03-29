-- Task 1

--Start a Transaction

BEGIN;
--Task 1a: 
/*Choose your top-3 favorite movies and add them to the 'film' table (films with the title Film1, Film2, etc - 
will not be taken into account and grade will be reduced)*/

-- ensure movies don’t already exist before inserting
INSERT INTO film (title, description, release_year, language_id, rental_duration, rental_rate, replacement_cost, rating, last_update)
                                                                                                     -- which columns will be populated in the film table  
                                                                                                     -- the last_update column is always set to today’s date to track changes
                                                                                                      
--  inserts multiple rows in a single query instead of running INSERT multiple times
SELECT title, description, release_year, language_id, rental_duration, rental_rate, replacement_cost, CAST(rating AS mpaa_rating), CURRENT_DATE
FROM (VALUES                                                                        -- uses VALUES to insert multiple rows
                                                                                                    -- sets last_update dynamically instead of hardcoding a date
                          ('Morometii', 'Povestea familiei Moromete în anii 1930.', 1987, 1, 1, 4.99, 19.99, 'PG'),
                          ('Filantropica', 'Un scriitor se implică într-o retea de cersetorie.', 2002, 1, 2, 9.99, 24.99, 'PG-13'),
                          ('4 luni, 3 săptămâni si 2 zile', 'Drama a două studente în perioada comunistă.', 2007, 1, 3, 19.99, 29.99, 'R')
) AS new_movies(title, description, release_year, language_id, rental_duration, rental_rate, replacement_cost, rating)
WHERE NOT EXISTS (                                                             -- prevents duplicates
    SELECT 1 FROM film WHERE film.title = new_movies.title   -- only insert this movie if no movie already exists with the same title
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
INSERT INTO actor (first_name, last_name, last_update)
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
    SELECT 1 FROM actor WHERE actor.first_name = new_actors.first_name AND actor.last_name = new_actors.last_name
                                                                                        -- for each actor: this query checks if the combination of 
                                                                                        -- (first_name, last_name) already exists in the actor table using NOT EXISTS
                                                                                        -- if not, it inserts the actor into the actor table
    )
RETURNING actor_id;

-- link actors to movies
INSERT INTO film_actor (actor_id, film_id, last_update)
SELECT a.actor_id, f.film_id, CURRENT_DATE                         -- this query reads from the actor table (using first_name, last_name)
                                                                                                       -- CURRENT_DATE fills the last_update field automatically
FROM actor a
INNER JOIN film f ON ( (a.first_name, a.last_name), f.title ) IN (   -- it creates pairs of (actor_id, film_id) for the film_actor bridge table
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
    SELECT 1 FROM film_actor WHERE film_actor.actor_id = a.actor_id AND film_actor.film_id = f.film_id
);
-- I used INNER JOIN and WHERE NOT EXISTS to avoid duplicate actor-film relationships


-- Task 1d
-- Add your favorite movies to any store's inventory.

INSERT INTO inventory (film_id, store_id, last_update)
SELECT f.film_id, s.store_id, CURRENT_DATE
FROM film f
INNER JOIN store s ON s.store_id IN (                           -- it combine every film with every store
    SELECT store_id FROM store
)                                                                                         -- dynamically selects all stores for add copies of the favorite movies
WHERE f.title IN ('Morometii', 'Filantropica', '4 luni, 3 săptămâni si 2 zile')     -- filter the favorites films
AND NOT EXISTS (                                                        -- only insert if this movie isn't already present in that  store's inventory
    SELECT 1 FROM inventory WHERE inventory.film_id = f.film_id AND inventory.store_id = s.store_id
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
        SELECT c.customer_id FROM customer c
        INNER JOIN rental r ON c.customer_id = r.customer_id
        INNER JOIN payment p ON c.customer_id = p.customer_id
        GROUP BY c.customer_id                                                                -- is grouping by customer; I get counts for every customer
        HAVING COUNT(DISTINCT r.rental_id) >= 43 AND COUNT(DISTINCT p.payment_id) >= 43
        LIMIT 1                                                                                           -- picks only one customer
)
-- Update selected customer’s personal details
UPDATE customer
SET first_name = 'Monica',
        last_name = 'Luca',
        email = 'lucamonicadaniela@yahoo.com',
        address_id = ( SELECT address_id FROM address ORDER BY RANDOM() LIMIT 1), -- address_id is picked randomly from the existing addresses
                                                                                                               -- this ensures I'm reusing an existing address instead of creating one
        last_update = CURRENT_DATE                                                   -- update to CURRENT_DATE
WHERE customer_id = (SELECT customer_id FROM target_customers);


-- Task 1f: Delete Records Related to Customer (Except Customer & Inventory)
-- Remove any records related to you (as a customer) from all tables except 'Customer' and 'Inventory'


-- get customer id for deletion
WITH target AS (
    SELECT customer_id FROM customer WHERE email = 'lucamonicadaniela@yahoo.com'
)
/*this CTE is useful for:
avoid repeating the SELECT customer_id query twice.
improve readability.
improve performance if more queries depend on this customer.*/

-- delete payments to this customer 
WITH target AS (SELECT customer_id FROM customer WHERE email = 'lucamonicadaniela@yahoo.com')
DELETE FROM payment WHERE customer_id IN (SELECT customer_id FROM target);
-- delete rentals related to this customer
WITH target AS (SELECT customer_id FROM customer WHERE email = 'lucamonicadaniela@yahoo.com')
DELETE FROM rental WHERE customer_id IN (SELECT customer_id FROM target);

-- Task 1g
/*Rent you favorite movies from the store they are in and pay for them
(add corresponding records to the database to represent this activity)
(Note: to insert the payment_date into the table payment, you can create a new partition 
(see the scripts to install the training database ) or add records for the
first half of 2017)*/

-- insert rentals
INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id, return_date, last_update)
SELECT CURRENT_DATE, i.inventory_id, c.customer_id, s.staff_id, CURRENT_DATE + INTERVAL '7 days', CURRENT_DATE
FROM inventory i
INNER JOIN store st ON i.store_id = st.store_id
INNER JOIN staff s ON st.store_id = s.store_id
INNER JOIN customer c ON c.email = 'lucamonicadaniela@yahoo.com'
WHERE i.film_id IN (SELECT film_id FROM film WHERE title IN ('Morometii', 'Filantropica', '4 luni, 3 săptămâni si 2 zile'));

/*Explanation 
Column           Meaning

rental_date       set to CURRENT_DATE = today
inventory_id    pick inventory items of the favorite movies
customer_id     get the customer id for 'lucamonicadaniela@yahoo.com'
staff_id            get the staff member associated with the store
return_date      return it in 7 days
last_update      logging that this record was created(modified)today

The flow:

->find all inventory items where the film is either Inception, The Matrix, or Interstellar.
->join this to the related store and its assigned staff.
->link the rental to the customer whose email is 'lucamonicadaniela@yahoo.com'.
->insert a rental record for each found inventory item.*/


-- insert payment
INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT r.customer_id, r.staff_id, r.rental_id, f.rental_rate, CURRENT_DATE
FROM rental r
JOIN inventory i ON r.inventory_id = i.inventory_id
JOIN film f ON i.film_id = f.film_id
WHERE r.customer_id = (SELECT customer_id FROM customer WHERE email =  'lucamonicadaniela@yahoo.com');

/*
Column          Meaning
customer_id    same customer
staff_id           staff who processed the rental
rental_id         the newly created rental
amount           the rental price, extracted from the film.rental_rate
payment_date  today

The flow:

for each rental made by 'lucamonicadaniela@yahoo.com':
->find the linked inventory_id.
->from inventory, find the associated film_id.
->from film, get the rental_rate.
->create a payment record for each rental.
->the amount will match exactly the rental price for each movie.*/



-- commit Transaction
COMMIT;



/*Before COMMIT, it's okay to verify changes:
SELECT * FROM film WHERE title IN ('Morometii', 'Filantropica', '4 luni, 3 săptămâni si 2 zile');
SELECT * FROM actor WHERE last_name IN ('Rebengiuc', 'Diaconu');
SELECT * FROM inventory WHERE film_id IN (SELECT film_id FROM film WHERE title IN ('Morometii', 'Filantropica', '4 luni, 3 săptămâni si 2 zile') );
SELECT * FROM rental WHERE customer_id = (SELECT customer_id FROM customer WHERE email = 'lucamonicadaniela@yahoo.com');
SELECT * FROM payment WHERE customer_id = (SELECT customer_id FROM customer WHERE email = 'lucamonicadaniela@yahoo.com');*/
