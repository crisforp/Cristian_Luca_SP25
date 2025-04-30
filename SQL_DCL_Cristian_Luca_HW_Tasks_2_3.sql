-- ================================================
-- Task 2: Implement role-based authentication model for dvd_rental database
-- ================================================


-- Cleanup: Drop roles if they exist to ensure a clean setup
DROP ROLE IF EXISTS rentaluser;
DROP ROLE IF EXISTS rental;
DROP ROLE IF EXISTS client_maria_stefania;

-- 2.1. Create rentaluser with login capability but no initial permissions
-- Note: PostgreSQL does not support IF NOT EXISTS in CREATE ROLE directly,
-- so use a conditional check on pg_roles

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rentaluser') THEN
        CREATE ROLE rentaluser WITH LOGIN PASSWORD 'rentalpassword';
    END IF;
END $$;

-- 2.2. Grant SELECT on public.customer to rentaluser
GRANT SELECT ON TABLE public.customer TO rentaluser;

-- Test SELECT as rentaluser

SET ROLE rentaluser;
SELECT customer_id, first_name, last_name FROM public.customer LIMIT 5;
RESET ROLE;

-- 2.3. Create rental group role for privilege inheritance

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rental') THEN
        CREATE ROLE rental;
    END IF;
END $$;

-- Add rentaluser to rental group

GRANT rental TO rentaluser;

-- 2.4. Grant INSERT and UPDATE on public.rental to rental group

GRANT INSERT, UPDATE ON TABLE public.rental TO rental;

-- Validate IDs for INSERT and UPDATE (to respect FK constraints)

SELECT inventory_id FROM public.inventory WHERE inventory_id = 1;
SELECT customer_id FROM public.customer WHERE customer_id = 1;
SELECT staff_id FROM public.staff WHERE staff_id = 1;

-- Test INSERT as rentaluser

SET ROLE rentaluser;
INSERT INTO public.rental (rental_date, inventory_id, customer_id, staff_id, last_update)
VALUES (CURRENT_TIMESTAMP, 1, 1, 1, CURRENT_TIMESTAMP)
RETURNING rental_id;
RESET ROLE;

-- Test UPDATE as rentaluser

SET ROLE rentaluser;
UPDATE public.rental 
SET return_date = CURRENT_TIMESTAMP 
WHERE rental_id = (SELECT MAX(rental_id) FROM public.rental)
RETURNING rental_id, return_date;
RESET ROLE;

-- 2.5. Revoke INSERT on public.rental from rental group and test denial

REVOKE INSERT ON TABLE public.rental FROM rental;

-- Test INSERT denial as rentaluser (should raise permission error)
SET ROLE rentaluser;
-- Expect: ERROR: permission denied for table rental
INSERT INTO public.rental (rental_date, inventory_id, customer_id, staff_id, last_update)
VALUES (CURRENT_TIMESTAMP, 2, 2, 2, CURRENT_TIMESTAMP);
RESET ROLE;

-- 2.6. Create personalized role dynamically for a customer with non-empty history

DO $$
DECLARE
    v_first_name VARCHAR := 'MARIA';
    v_last_name VARCHAR := 'STEFANIA';
    v_customer_id INTEGER;
    v_role_name VARCHAR;
BEGIN
    -- Find a customer with rental and payment history
    SELECT c.customer_id INTO v_customer_id
    FROM public.customer c
    INNER JOIN public.rental r ON c.customer_id = r.customer_id
    INNER JOIN public.payment p ON c.customer_id = p.customer_id
    WHERE c.first_name = v_first_name AND c.last_name = v_last_name
    GROUP BY c.customer_id
    HAVING COUNT(r.rental_id) > 0 AND COUNT(p.payment_id) > 0
    LIMIT 1;

    v_role_name := 'client_' || LOWER(v_first_name) || '_' || LOWER(v_last_name);

    -- Create personalized role if not exists
    
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = v_role_name) THEN
        EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L', v_role_name, v_first_name || 'pass');
    END IF;

    -- Grant SELECT privileges to personalized role
    
    EXECUTE format('GRANT SELECT ON TABLE public.customer TO %I', v_role_name);
    EXECUTE format('GRANT SELECT ON TABLE public.rental TO %I', v_role_name);
    EXECUTE format('GRANT SELECT ON TABLE public.payment TO %I', v_role_name);
END $$;


--========================
-- Task 3: Implement Row-Level Security
--========================

-- 3.1 Enable RLS on target tables

ALTER TABLE public.rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;

-- 3.2 Create RLS policies for personalized role with specific customer_id

DO $$
DECLARE
    v_customer_id INTEGER;
BEGIN
    SELECT customer_id INTO v_customer_id
    FROM public.customer
    WHERE first_name = 'MARIA' AND last_name = 'STEFANIA'
    LIMIT 1;

    -- Drop policies if they already exist to avoid conflict
    
    DROP POLICY IF EXISTS rental_own_data ON public.rental;
    DROP POLICY IF EXISTS payment_own_data ON public.payment;

    -- Create policy for SELECT access only (more secure than FOR ALL)
    
    EXECUTE format('
        CREATE POLICY rental_own_data ON public.rental
        FOR SELECT TO client_maria_stefania
        USING (customer_id = %L)', v_customer_id);
    COMMENT ON POLICY rental_own_data ON public.rental 
        IS 'Allows client_maria_stefania to view only her rental records.';

    EXECUTE format('
        CREATE POLICY payment_own_data ON public.payment
        FOR SELECT TO client_maria_stefania
        USING (customer_id = %L)', v_customer_id);
    COMMENT ON POLICY payment_own_data ON public.payment 
        IS 'Allows client_maria_stefania to view only her payment records.';
END $$;

-- 3.3 Test RLS access as client_maria_stefania

SET ROLE client_maria_stefania;
SELECT customer_id, rental_id, rental_date 
FROM public.rental 
LIMIT 5;

SELECT customer_id, payment_id, amount 
FROM public.payment 
LIMIT 5;
RESET ROLE;

-- 3.4 Test full SELECT access (no RLS filter) for rentaluser

GRANT SELECT ON TABLE public.rental TO rentaluser;
SET ROLE rentaluser;
SELECT customer_id, rental_id, rental_date FROM public.rental LIMIT 5;
RESET ROLE;


