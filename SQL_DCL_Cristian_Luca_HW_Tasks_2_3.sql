
-- Task 2: Implement role-based authentication model for dvd_rental database


/*1.  Create a new user with the username "rentaluser" and the password "rentalpassword".
Give the user the ability to connect to the database but no other permissions.*/

CREATE ROLE rentaluser WITH LOGIN PASSWORD 'rentalpassword';

-- This creates a role with login capability but no database privileges by default.

/*2.  Grant "rentaluser" SELECT permission for the "customer" table. 
Сheck to make sure this permission works correctly—write a SQL query to select all customers.*/

GRANT SELECT ON TABLE customer TO rentaluser;

-- This allows rentaluser to query the customer table.

/*3.  Create a new user group called "rental" and add "rentaluser" to the group. */

SET ROLE rentaluser;
SELECT * FROM customer;
RESET ROLE;

-- Running this as rentaluser should return all rows from customer. If an error occurs (such as: permission denied), the grant failed.
-- The output will include columns like customer_id, first_name, last_name, etc.

/*4.   Grant the "rental" group INSERT and UPDATE permissions for the "rental" table.
Insert a new row and update one existing row in the "rental" table under that role. */

CREATE ROLE rental;
GRANT rental TO rentaluser;

-- rental is a group role (no LOGIN by default), and rentaluser is now a member, inheriting its privileges.


/*5.  Revoke the "rental" group's INSERT permission for the "rental" table. 
Try to insert new rows into the "rental" table make sure this action is denied.*/

GRANT INSERT, UPDATE ON TABLE rental TO rental;

-- This allows members of the rental group to insert new rows and update existing rows in the rental table.

/*6. Create a personalized role for any customer already existing in the dvd_rental database. 
The name of the role name must be client_{first_name}_{last_name} (omit curly brackets).
The customer's payment and rental history must not be empty. */

 -- Insert a new row and update an existing row
 
-- Insert a new row (as rentaluser): 

SET ROLE rentaluser;
INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id, last_update)
VALUES (CURRENT_TIMESTAMP, 1, 1, 1, CURRENT_TIMESTAMP);
RESET ROLE;

-- This adds a new rental record. Adjust inventory_id, customer_id, and staff_id to valid existing IDs from the inventory, customer, and staff tables.


-- Update an existing row (as rentaluser): 

SET ROLE rentaluser;
UPDATE rental SET return_date = CURRENT_TIMESTAMP WHERE rental_id = 1;
RESET ROLE;

-- This updates the return_date for rental_id = 1 (use an existing ID from the table).


-- Revoke INSERT permission and test denial

-- REVOKE INSERT ON TABLE rental FROM rental;

-- Test insertion denial (as rentaluser): 

-- Check inventory ID
SELECT inventory_id FROM inventory WHERE inventory_id = 1;

-- Check customer ID
SELECT customer_id FROM customer WHERE customer_id = 1;

-- Check staff ID
SELECT staff_id FROM staff WHERE staff_id = 1;

SET ROLE rentaluser;
INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id, last_update)
VALUES (CURRENT_TIMESTAMP, 2, 2, 2, CURRENT_TIMESTAMP);
RESET ROLE;

-- This should fail with a permission denied error, confirming the revocation.


 -- Create a personalized role for an existing customer
-- Find a customer with non-empty payment and rental history: 

SELECT c.customer_id, c.first_name, c.last_name
FROM customer c
JOIN rental r ON c.customer_id = r.customer_id
JOIN payment p ON c.customer_id = p.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(r.rental_id) > 0 AND COUNT(p.payment_id) > 0
LIMIT 1;

-- Suppose the result is customer_id = 1, first_name = 'MARIA', last_name = 'STEFANIA'.

-- Create the role: 

CREATE ROLE client maria Stefania WITH LOGIN PASSWORD 'mariapass';

--This creates a role named client_maria stefania for the customer.
-- ======================================================


-- Task 3: Implement row-level security

/*3.1:  Read about Row-Level Security
• Refer to https://www.postgresql.org/docs/12/ddl-rowsecurity.html for details on enabling and using RLS. 
Key points include using ALTER TABLE ... ENABLE ROW LEVEL SECURITY and CREATE POLICY to define access rules.*/

/*3.2:  Configure RLS for the "rental" and "payment" tables
 Enable RLS on rental and payment: */

ALTER TABLE rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment ENABLE ROW LEVEL SECURITY;

--Create policies to restrict access to the customer’s own data: 

SELECT customer_id FROM customer
WHERE first_name = 'MARIA' AND last_name = 'STEFANIA';
-- For rental
CREATE POLICY rental_own_data ON rental
FOR ALL
TO client_maria_stefania
USING (customer_id = 1);

-- For payment
CREATE POLICY payment_own_data ON payment
FOR ALL
TO client_maria_stefania
USING (customer_id = 1);

-- Now it will restrict all access to only rows where customer_id = 1.

/*3.3:  Write a query to verify the restriction
Test the query as client_maria stefania: */

SET ROLE client_maria stefania;
SELECT * FROM rental;
SELECT * FROM payment;
RESET ROLE;

-- This should return only the rows where customer_id matches Maria Stefania’s ID. If other rows appear, the policy is misconfigured.

-- Test with a different user (such as:  rentaluser): 
SET ROLE rentaluser;
SELECT * FROM rental;
RESET ROLE;

-- Without a matching policy, rentaluser should see all rows (if it has SELECT on rental), 
-- confirming the policy applies only to client_maria stefania.

