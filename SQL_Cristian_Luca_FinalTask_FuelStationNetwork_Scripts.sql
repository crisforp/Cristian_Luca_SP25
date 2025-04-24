-- 3. 
-- Physical Design -- Create the database and schema 

-- CREATE DATABASE fuel_station_network;
-- CREATE SCHEMA fuel_station; 

-- Create Tables with Surrogate Keys, Constraints, and Indexes

 -- Fuel_Station Table 
 CREATE TABLE fuel_station.Fuel_Station (
                  station_id SERIAL PRIMARY KEY, 
                  name VARCHAR(100) NOT NULL,
                  location VARCHAR(150) NOT NULL 
 );
 
 -- Fuel_Type Table with UNIQUE constraint on fuel_name
  CREATE TABLE fuel_station.Fuel_Type ( 
                   fuel_type_id SERIAL PRIMARY KEY, 
                   fuel_name VARCHAR(50) NOT NULL UNIQUE, 
                   price_per_liter DECIMAL(10,2) NOT NULL CHECK (price_per_liter > 0)
);

-- Customer Table with GENERATED full_name

 CREATE TABLE fuel_station.Customer ( 
                 customer_id SERIAL PRIMARY KEY, 
                 first_name VARCHAR(50) NOT NULL, 
                 last_name VARCHAR(50) NOT NULL, 
                 full_name VARCHAR(100) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
                 contact_number VARCHAR(20) 
 );
 
 -- Employee Table
 
CREATE TABLE fuel_station.Employee (
                   employee_id SERIAL PRIMARY KEY,
                   full_name VARCHAR(100) NOT NULL,
                   position VARCHAR(50) NOT NULL,
                   station_id INT NOT NULL,
                   FOREIGN KEY (station_id) REFERENCES fuel_station.Fuel_Station(station_id)
);

-- Inventory Table with CHECK constraint

CREATE TABLE fuel_station.Inventory (
                 inventory_id SERIAL PRIMARY KEY,
                 station_id INT NOT NULL,
                 fuel_type_id INT NOT NULL,
                 quantity_available DECIMAL(10,2) NOT NULL CHECK (quantity_available >= 0),
                 FOREIGN KEY (station_id) REFERENCES fuel_station.Fuel_Station(station_id),
                 FOREIGN KEY (fuel_type_id) REFERENCES fuel_station.Fuel_Type(fuel_type_id)
);
 
-- Create the Transaction table 

CREATE TABLE fuel_station.Transaction (
                  transaction_id SERIAL PRIMARY KEY,
                  station_id INT NOT NULL,
                  fuel_type_id INT NOT NULL,
                  customer_id INT NOT NULL,
                  transaction_date DATE NOT NULL CHECK (transaction_date > '2024-01-01'),
                  quantity_sold DECIMAL(10,2) NOT NULL CHECK (quantity_sold > 0),
                  payment_method VARCHAR(20) NOT NULL CHECK (payment_method IN ('cash', 'card', 'mobile')),
                  total_amount DECIMAL(10,2) NOT NULL, 
                  FOREIGN KEY (station_id) REFERENCES fuel_station.Fuel_Station(station_id),
                  FOREIGN KEY (fuel_type_id) REFERENCES fuel_station.Fuel_Type(fuel_type_id),
                  FOREIGN KEY (customer_id) REFERENCES fuel_station.Customer(customer_id)
);

-- Create a function for the trigger to calculate total_amount

CREATE OR REPLACE FUNCTION fuel_station.calculate_total_amount()
RETURNS TRIGGER AS $$

DECLARE
v_price_per_liter DECIMAL(10,2);
BEGIN
-- Fetch price_per_liter from Fuel_Type
SELECT price_per_liter INTO v_price_per_liter
FROM fuel_station.Fuel_Type
WHERE fuel_type_id = NEW.fuel_type_id;

-- Calculate total_amount
NEW.total_amount := NEW.quantity_sold * v_price_per_liter;

RETURN NEW;
END; $$ LANGUAGE plpgsql;


-- Create the trigger to execute before INSERT or UPDATE

CREATE TRIGGER calculate_total_amount_trigger
BEFORE INSERT OR UPDATE ON fuel_station.Transaction
FOR EACH ROW
EXECUTE FUNCTION fuel_station.calculate_total_amount();


-- Insert sample data to test the table and trigger

-- Insert data into dependent tables
INSERT INTO fuel_station.Fuel_Station (name, location) VALUES
('City Fuel', '123 Downtown Rd, Bucuresti'),
('Highway Stop', '456 Highway 1, Brasov');

INSERT INTO fuel_station.Fuel_Type (fuel_name, price_per_liter) VALUES
('Petrol', 6.50),
('Diesel', 6.20);

INSERT INTO fuel_station.Customer (first_name, last_name, contact_number) VALUES
('Mihai', 'Popescu', '0712345678'),
('Ana', 'Ionescu', '0723456789');

-- Insert into Transaction (trigger will calculate total_amount)
INSERT INTO fuel_station.Transaction (station_id, fuel_type_id, customer_id, transaction_date, quantity_sold, payment_method) VALUES
(1, 1, 1, '2025-01-15', 50.00, 'card'),  -- 50.00 * 6.50 = 325.00
(1, 2, 2, '2025-01-20', 40.00, 'cash');  -- 40.00 * 6.20 = 248.00

-- Query the Transaction table to verify
SELECT * FROM fuel_station.Transaction;



-- Replenishment Table with CHECK constraints

CREATE TABLE fuel_station.Replenishment (
                  replenishment_id SERIAL PRIMARY KEY,
                  station_id INT NOT NULL,
                  fuel_type_id INT NOT NULL,
                  delivery_date DATE NOT NULL CHECK (delivery_date > '2024-01-01'),
                  quantity_received DECIMAL(10,2) NOT NULL CHECK (quantity_received > 0),
                  supplier_name VARCHAR(100) NOT NULL,
                  FOREIGN KEY (station_id) REFERENCES fuel_station.Fuel_Station(station_id),
                  FOREIGN KEY (fuel_type_id) REFERENCES fuel_station.Fuel_Type(fuel_type_id)
);

-- Create Indexes for Performance Optimization

CREATE INDEX idx_transaction_date ON fuel_station.Transaction(transaction_date);
CREATE INDEX idx_transaction_station_id ON fuel_station.Transaction(station_id);

-- Add CHECK constraint for non-negative quantity_available 
ALTER TABLE fuel_station.Inventory ADD CONSTRAINT chk_quantity_non_negative CHECK (quantity_available >= 0); -- CHECK constraint #1(quantity_available >= 0)

-- Add CHECK constraints to Transaction table
 ALTER TABLE fuel_station.Transaction ADD CONSTRAINT chk_transaction_date_after_2024 CHECK (transaction_date > '2024-01-01'); -- CHECK constraint #2 (date > 2024-01-01)
 
 ALTER TABLE fuel_station.Transaction ADD CONSTRAINT chk_quantity_sold_positive CHECK (quantity_sold > 0); -- CHECK constraint #3 (non-negative value)
 
 ALTER TABLE fuel_station.Transaction ADD CONSTRAINT chk_payment_method_allowed CHECK (payment_method IN ('cash', 'card', 'mobile')); -- CHECK constraint #4 (specific allowed values)
 
 -- constraint #5 UNIQUE: Fuel_Type.fuel_name (unique_fuel_name)
 
 -- constraint #6 NOT NULL: Customer.first_name (implicit constraint)
 
-- Test CHECK constraints (I'm going to do these tests!)
-- Test CHECK on quantity_sold (should fail for negative value)
-- Test CHECK on transaction_date (should fail for date before 2024-01-01)
-- Test CHECK on quantity_sold (zero value) 
-- Test CHECK on payment_method (should fail for invalid value)
-- Test UNIQUE constraint on fuel_name
-- Test NOT NULL constraint on first_name

 -- 4. 
/* Populate the tables with the sample data generated, ensuring each table has at least 6+ rows (for a total of 36+ rows in all the tables) for the last 3 months.
Create DML scripts for insert your data. 
Ensure that the DML scripts do not include values for surrogate keys, as these keys should be generated by the database during runtime. 
Also, ensure that any DEFAULT values required are specified appropriately in the DML scripts. 
These DML scripts should be designed to successfully adhere to all previously defined constraints*/

 -- Truncate all tables to clear existing data and reset SERIAL sequences
 
-- Use CASCADE to handle foreign key dependencies
TRUNCATE TABLE fuel_station.Transaction, 
                                    fuel_station.Inventory, 
                                    fuel_station.Customer, 
                                    fuel_station.Fuel_Type, 
                                    fuel_station.Fuel_Station 
                                    RESTART IDENTITY CASCADE;
                                  
 -- Insert into Fuel_Station (6 rows) 
 INSERT INTO fuel_station.Fuel_Station (name, location) 
            VALUES ('City Fuel', '123 Downtown Rd, Bucuresti'), 
                            ('Highway Stop', '456 Highway 1, Brasov'),
                            ('Lakeside Fuel', '789 Lakeview Dr, Cluj'), 
                            ('Mountain Gas', '101 Mountain Rd, Sibiu'), 
                            ('Urban Pump', '202 City Center, Timisoara'),
                            ('Coastal Fuel', '303 Seaside Blvd, Constanta');

-- Insert into Fuel_Type (6 rows) 
INSERT INTO fuel_station.Fuel_Type (fuel_name, price_per_liter ) 
           VALUES ('Petrol', 6.50), 
                           ('Diesel', 6.20), 
                           ('Premium Petrol', 7.00),
                           ('Kerosene', 5.80), 
                           ('Biofuel', 6.80),
                           ('LPG', 4.50);

-- Insert into Customer (6 rows)
 INSERT INTO fuel_station.Customer (first_name, last_name, contact_number)
            VALUES ('Mihai', 'Popescu', '0712345678'), 
                            ('Ana', 'Ionescu', '0723456789'),
                            ('Stefan', 'Marin', '0734567890'), 
                            ('Elena', 'Dumitrescu', '0745678901'), 
                            ('Andrei', 'Popa', '0756789012'), 
                            ('Ioana', 'Georgescu', '0767890123');

-- Insert into Inventory (6 rows) -- Note: station_id and fuel_type_id correspond to the auto-generated IDs (1 to 6) from Fuel_Station and Fuel_Type 
INSERT INTO fuel_station.Inventory (station_id, fuel_type_id, quantity_available)
           VALUES (1, 1, 5000.00), -- City Fuel, Petrol
                           (1, 2, 3000.00), -- City Fuel, Diesel 
                           (2, 3, 4000.00), -- Highway Stop, Premium Petrol 
                           (3, 4, 2000.00), -- Lakeside Fuel, Kerosene 
                           (4, 5, 2500.00), -- Mountain Gas, Biofuel 
                           (5, 6, 1500.00); -- Urban Pump, LPG

-- Insert into Transaction (12 rows) -- Note: total_amount is manually calculated here for clarity, but in a real scenario, a trigger (like calculate_total_amount) would compute it -- station_id, fuel_type_id, and customer_id correspond to the auto-generated IDs (1 to 6) 
INSERT INTO fuel_station.Transaction (station_id, fuel_type_id, customer_id, transaction_date, quantity_sold, payment_method, total_amount)
           VALUES (1, 1, 1, '2025-01-25', 50.00, 'card', 325.00), -- City Fuel, Petrol, Mihai, 50 * 6.50 
                           (1, 2, 2, '2025-01-30', 40.00, 'cash', 248.00), -- City Fuel, Diesel, Ana, 40 * 6.20 
                           (2, 3, 3, '2025-02-05', 30.00, 'mobile', 210.00), -- Highway Stop, Premium Petrol, Stefan, 30 * 7.00 
                           (2, 3, 4, '2025-02-15', 45.00, 'card', 315.00), -- Highway Stop, Premium Petrol, Elena, 45 * 7.00 
                           (3, 4, 5, '2025-02-20', 20.00, 'cash', 116.00), -- Lakeside Fuel, Kerosene, Andrei, 20 * 5.80 
                           (3, 4, 6, '2025-03-01', 25.00, 'mobile', 145.00), -- Lakeside Fuel, Kerosene, Ioana, 25 * 5.80 
                           (4, 5, 1, '2025-03-05', 35.00, 'card', 238.00), -- Mountain Gas, Biofuel, Mihai, 35 * 6.80 
                           (4, 5, 2, '2025-03-15', 50.00, 'cash', 340.00), -- Mountain Gas, Biofuel, Ana, 50 * 6.80 
                           (5, 6, 3, '2025-03-20', 60.00, 'mobile', 270.00), -- Urban Pump, LPG, Stefan, 60 * 4.50 
                           (5, 6, 4, '2025-04-01', 55.00, 'card', 247.50), -- Urban Pump, LPG, Elena, 55 * 4.50 
                           (1, 1, 5, '2025-04-10', 70.00, 'cash', 455.00), -- City Fuel, Petrol, Andrei, 70 * 6.50 
                           (2, 3, 6, '2025-04-20', 65.00, 'mobile', 455.00); -- Highway Stop, Premium Petrol, Ioana, 65 * 7.00

-- Verify the number of rows in each table 
SELECT 'Fuel_Station', COUNT(*) 
   FROM fuel_station.Fuel_Station 
UNION 
SELECT 'Fuel_Type', COUNT(*)
   FROM fuel_station.Fuel_Type 
UNION 
SELECT 'Customer', COUNT(*) 
   FROM fuel_station.Customer 
UNION
SELECT 'Inventory', COUNT(*)
  FROM fuel_station.Inventory 
UNION SELECT 'Transaction', COUNT(*) 
  FROM fuel_station.Transaction;


-- 5. 
-- Create the following functions.

/*5.1 Create a function that updates data in one of your tables. This function should take the following input arguments:
The primary key value of the row you want to update
The name of the column you want to update
The new value you want to set for the specified column

This function should be designed to modify the specified row in the table, updating the specified column with the new value.*/

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS fuel_station.update_fuel_station(INTEGER, TEXT, TEXT);

-- Create the function to update a column in the Fuel_Station table
CREATE OR REPLACE FUNCTION fuel_station.update_fuel_station(
p_station_id INTEGER,
p_column_name TEXT,
p_new_value TEXT
)
RETURNS TEXT AS $$

DECLARE
v_valid_columns TEXT[] := ARRAY['name', 'location'];
v_query TEXT;
v_schema TEXT;
BEGIN
-- Debug: Check the current schema
SELECT current_schema() INTO v_schema;
RAISE NOTICE 'Current schema in function: %', v_schema;

-- Validate the column name
IF p_column_name NOT IN (SELECT unnest(v_valid_columns)) THEN
RETURN 'Error: Invalid column name. Must be one of: ' || array_to_string(v_valid_columns, ', ');
END IF;

-- Validate that p_new_value is not NULL (since name and location are NOT NULL)
IF p_new_value IS NULL THEN
RETURN 'Error: New value cannot be NULL for column ' || p_column_name;
END IF;

-- Construct the dynamic UPDATE statement
v_query := format(
'UPDATE fuel_station.Fuel_Station SET %I = $1 WHERE station_id = $2',
p_column_name
);

-- Debug: Show the constructed query
RAISE NOTICE 'Executing query: %', v_query;

-- Execute the UPDATE statement
EXECUTE v_query
USING p_new_value, p_station_id;

-- Check if the update affected any rows
IF NOT FOUND THEN
RETURN 'Error: No row found with station_id = ' || p_station_id;
END IF;

RETURN 'Success: Updated ' || p_column_name || ' for station_id = ' || p_station_id || ' to ' || p_new_value;
EXCEPTION
WHEN OTHERS THEN
RETURN 'Error: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;



-- Verify the current database
SELECT current_database();

-- Set the schema
SET search_path TO fuel_station;

-- Verify the schema
SELECT current_schema();

-- Reset the Fuel_Station table and its dependent tables
TRUNCATE TABLE fuel_station.Transaction, fuel_station.Inventory, fuel_station.Fuel_Station
RESTART IDENTITY CASCADE;

-- Verify the sequence after truncation
SELECT last_value, is_called FROM fuel_station.Fuel_Station_station_id_seq;

-- Insert a row with station_id = 1 for testing
INSERT INTO fuel_station.Fuel_Station (station_id, name, location)
           VALUES (1, 'City Fuel', '123 Downtown Rd, Bucuresti')
ON CONFLICT (station_id) DO UPDATE
SET name = EXCLUDED.name, location = EXCLUDED.location;

-- Verify the inserted row
SELECT * FROM fuel_station.Fuel_Station WHERE station_id = 1;

-- Test the update_fuel_station function with sample calls

-- Test 1: Update the name of a fuel station
SELECT fuel_station.update_fuel_station(1, 'name', 'City Fuel Updated');

-- Test 2: Update the location of a fuel station
SELECT fuel_station.update_fuel_station(1, 'location', '456 Updated Rd, Bucharest');

-- Test 3: Invalid column name (should fail)
SELECT fuel_station.update_fuel_station(1, 'invalid_column', 'Some Value');

-- Test 4: Non-existent station_id (should fail)
SELECT fuel_station.update_fuel_station(999, 'name', 'Non Existent Station');

-- Test 5: NULL value for a NOT NULL column (should fail)
SELECT fuel_station.update_fuel_station(1, 'name', NULL);

-- Verify the updates
SELECT * FROM fuel_station.Fuel_Station WHERE station_id = 1;


/*5.2 Create a function that adds a new transaction to your transaction table. 
You can define the input arguments and output format. 
Make sure all transaction attributes can be set with the function (via their natural keys). 
The function does not need to return a value but should confirm the successful insertion of the new transaction.*/

-- =================================================================
-- Function: fn_add_transaction_natural_keys
-- Purpose:  Adds a new fuel transaction using natural keys
-- Inputs:
--    p_station_name                 = name of the fuel station
--    p_fuel_name                     = name of the fuel type
--    p_customer_full_name      = full name of the customer
--    p_transaction_date            = date of the transaction (must be > 2024-01-01)
--    p_quantity_sold                = fuel quantity sold (must be > 0)
--    p_payment_method           = payment method (must be 'cash', 'card', or 'mobile')
-- Output:
--    Returns a TEXT message confirming the result
-- Notes:
--    Uses SELECT INTO for key resolution, validates existence, and returns feedback.
-- =================================================================

CREATE OR REPLACE FUNCTION fuel_station.fn_add_transaction_natural_keys(
    p_station_name VARCHAR,
    p_fuel_name VARCHAR,
    p_customer_full_name VARCHAR,
    p_transaction_date DATE,
    p_quantity_sold DECIMAL(10,2),
    p_payment_method VARCHAR
) RETURNS TEXT AS $$
DECLARE
    v_station_id INT;
    v_fuel_type_id INT;
    v_customer_id INT;
BEGIN
    -- Debug lookups
    RAISE NOTICE 'Looking for station: %', p_station_name;
    SELECT station_id INTO v_station_id
    FROM fuel_station.Fuel_Station
    WHERE name = p_station_name;

    IF v_station_id IS NULL THEN
        RAISE NOTICE '❌ Station not found';
        RETURN '❌ Station not found';
    END IF;

    RAISE NOTICE 'Looking for fuel: %', p_fuel_name;
    SELECT fuel_type_id INTO v_fuel_type_id
    FROM fuel_station.Fuel_Type
    WHERE fuel_name = p_fuel_name;

    IF v_fuel_type_id IS NULL THEN
        RAISE NOTICE '❌ Fuel type not found';
        RETURN '❌ Fuel type not found';
    END IF;

    RAISE NOTICE 'Looking for customer: %', p_customer_full_name;
    SELECT customer_id INTO v_customer_id
    FROM fuel_station.Customer
    WHERE full_name = p_customer_full_name;

    IF v_customer_id IS NULL THEN
        RAISE NOTICE '❌ Customer not found';
        RETURN '❌ Customer not found';
    END IF;

    -- Insert
    RAISE NOTICE '✅ Inserting transaction...';
    INSERT INTO fuel_station.Transaction (
        station_id, fuel_type_id, customer_id,
        transaction_date, quantity_sold, payment_method
    )
    VALUES (
        v_station_id, v_fuel_type_id, v_customer_id,
        p_transaction_date, p_quantity_sold, p_payment_method
    );

    RETURN format('✅ Transaction inserted for %s on %s: %.2f L of %s paid by %s',
        p_customer_full_name,
        p_transaction_date,
        p_quantity_sold,
        p_fuel_name,
        p_payment_method
    );
END;
$$ LANGUAGE plpgsql;


-- Testing

-- Check if entities exist
SELECT * FROM fuel_station.Customer WHERE full_name = 'Mihai Popescu';
SELECT * FROM fuel_station.Fuel_Station WHERE name = 'City Fuel Updated';
SELECT * FROM fuel_station.Fuel_Type WHERE fuel_name = 'Petrol';

INSERT INTO fuel_station.Inventory (station_id, fuel_type_id, quantity_available)
VALUES (1, 1, 1000.00);  -- Start with 1000 liters available

-- A Separate Trigger for Inventory Updates
-- Create the trigger and function to decrease inventory automatically after each transaction.

-- Create the Trigger Function

CREATE OR REPLACE FUNCTION fuel_station.update_inventory_after_transaction()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE fuel_station.Inventory
    SET quantity_available = quantity_available - NEW.quantity_sold
    WHERE station_id = NEW.station_id AND fuel_type_id = NEW.fuel_type_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Create the Trigger

DROP TRIGGER IF EXISTS update_inventory_trigger ON fuel_station.Transaction;

CREATE TRIGGER update_inventory_trigger
AFTER INSERT ON fuel_station.Transaction
FOR EACH ROW
EXECUTE FUNCTION fuel_station.update_inventory_after_transaction();

-- Test It Works
-- Now insert another transaction:

DO $$
DECLARE
    result TEXT;
BEGIN
    result := fuel_station.fn_add_transaction_natural_keys(
        'City Fuel Updated',
        'Petrol',
        'Mihai Popescu',
        '2025-03-28',
        30.00,
        'card'
    );
    RAISE NOTICE 'Function result: %', result;
END $$;

--Run this to see the most recent transaction

SELECT * FROM fuel_station.Transaction
ORDER BY transaction_id DESC
LIMIT 1;

-- Then check inventory again:

SELECT i.quantity_available
FROM fuel_station.Inventory i
INNER JOIN fuel_station.Fuel_Station s ON s.station_id = i.station_id
INNER JOIN fuel_station.Fuel_Type f ON f.fuel_type_id = i.fuel_type_id
WHERE s.name = 'City Fuel Updated' AND f.fuel_name = 'Petrol';



/*6.
Create a view that presents analytics for the most recently added quarter in your database. 
Ensure that the result excludes irrelevant fields such as surrogate keys and duplicate entries.*/

-- =====================================================
-- View: vw_quarterly_analytics
-- Purpose: Present summary analytics for the most recently added quarter.
-- Shows: Total transactions, fuel volume sold, and revenue grouped by station and fuel type.
-- Notes:
--   - Excludes surrogate keys (IDs).
--   - Dynamically filters to the most recent quarter.
-- =====================================================

CREATE OR REPLACE VIEW fuel_station.vw_quarterly_analytics AS
SELECT
    -- Display the station name (not the surrogate key)
    s.name AS station_name,

    -- Display the fuel name (readable format)
    f.fuel_name,

    -- Count number of transactions per station and fuel type
    COUNT(*) AS total_transactions,

    -- Total volume of fuel sold
    SUM(t.quantity_sold) AS total_quantity_sold,

    -- Total revenue from the sales (uses generated total_amount column)
    SUM(t.total_amount) AS total_revenue

FROM
    fuel_station.Transaction t

    -- Join to station to get human-readable station name
    INNER JOIN fuel_station.Fuel_Station s ON t.station_id = s.station_id

    -- Join to fuel type for readable fuel name
    INNER JOIN fuel_station.Fuel_Type f ON t.fuel_type_id = f.fuel_type_id

-- Only include transactions from the most recent quarter 
WHERE t.transaction_date >= date_trunc('quarter', CURRENT_DATE - INTERVAL '3 months')
  AND t.transaction_date < date_trunc('quarter', CURRENT_DATE)

-- Group results by station and fuel type to aggregate data properly
GROUP BY s.name, f.fuel_name

-- Optional: Order the output for readability
ORDER BY s.name, f.fuel_name;



SELECT * FROM fuel_station.vw_quarterly_analytics;


/*7.
Create a read-only role for the manager. This role should have permission to perform SELECT 
queries on the database tables, and also be able to log in. 
Please ensure that you adhere to best practices for database security when defining this role.*/

-- Create manager_readonly Role

-- Create the Role with Login Access

-- Create a read-only role for managers
CREATE ROLE manager_readonly
LOGIN
PASSWORD 'StrongP@ssw0rd2025'; -- Use a strong, secure password
-- This allows the manager to connect to the DB
-- PostgreSQL automatically hashes the password
-- Ensure password_encryption = 'scram-sha-256' is enabled in postgresql.conf

-- Grant Access to the Schema and Tables

-- Grant basic usage on schema (to resolve object names)
GRANT USAGE ON SCHEMA fuel_station TO manager_readonly;

-- Grant SELECT on all current tables
GRANT SELECT ON ALL TABLES IN SCHEMA fuel_station TO manager_readonly;

-- Ensure future tables also grant SELECT to manager_readonly
ALTER DEFAULT PRIVILEGES IN SCHEMA fuel_station
GRANT SELECT ON TABLES TO manager_readonly;

-- DML (INSERT/UPDATE/DELETE)  --> Not granted (read-only enforcement)



-- How to Test the Role

-- Connect as manager_readonly

SELECT * FROM fuel_station.Transaction;
-- Should work

INSERT INTO fuel_station.Customer (first_name, last_name, contact_number)
VALUES ('Test', 'User', '0700000000');
-- Should throw permission denied



