-- ================================================
-- Task 2: Implement role-based authentication model for dvd_rental database
-- ================================================

-- Cleanup section 
DROP ROLE IF EXISTS rentaluser;
DROP ROLE IF EXISTS rental;

-- Create rentaluser login role (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rentaluser') THEN
        CREATE ROLE rentaluser WITH LOGIN PASSWORD 'rentalpassword';
    END IF;
END $$;

-- Grant SELECT on customer table to rentaluser
GRANT SELECT ON TABLE public.customer TO rentaluser;

-- Create 'rental' group role for privilege grouping (if not exists)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'rental') THEN
        CREATE ROLE rental;
    END IF;
END $$;

-- Assign rentaluser to rental group
GRANT rental TO rentaluser;

-- Grant INSERT and UPDATE on rental table to rental group
GRANT INSERT, UPDATE ON TABLE public.rental TO rental;


-- Procedure to dynamically create a personalized client role
-- and grant appropriate SELECT permissions


DROP PROCEDURE IF EXISTS create_client_role;

CREATE OR REPLACE PROCEDURE create_client_role(p_first_name TEXT, p_last_name TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id INTEGER;
    v_role_name TEXT;
BEGIN
    -- Find a customer with rental and payment history
    SELECT c.customer_id INTO v_customer_id
    FROM public.customer c
    JOIN public.rental r ON c.customer_id = r.customer_id
    JOIN public.payment p ON c.customer_id = p.customer_id
    WHERE c.first_name = p_first_name AND c.last_name = p_last_name
    GROUP BY c.customer_id
    HAVING COUNT(r.rental_id) > 0 AND COUNT(p.payment_id) > 0
    LIMIT 1;

    IF v_customer_id IS NULL THEN
        RAISE EXCEPTION 'No qualifying customer found for: % %', p_first_name, p_last_name;
    END IF;

    -- Construct role name
    v_role_name := format('client_%s_%s', lower(p_first_name), lower(p_last_name));

    -- Create role if not exists
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = v_role_name) THEN
        EXECUTE format('CREATE ROLE %I WITH LOGIN PASSWORD %L;', v_role_name, p_first_name || 'pass');
    END IF;

    -- Grant necessary table privileges to the role
    EXECUTE format('GRANT SELECT ON public.customer TO %I;', v_role_name);
    EXECUTE format('GRANT SELECT ON public.rental TO %I;', v_role_name);
    EXECUTE format('GRANT SELECT ON public.payment TO %I;', v_role_name);

    RAISE NOTICE 'Client role created and privileges granted to: %', v_role_name;
END;
$$;


-- Example usage: dynamically create access for any client
CALL create_client_role('Maria', 'Stefania');
-- CALL create_client_role('Tudor', 'Alexandru'); -- another example



--========================
-- Task 3: Implement Row-Level Security
--========================

-- Task 3: Dynamic Row-Level Security Setup
-- Avoids hardcoded user IDs and names


DROP PROCEDURE IF EXISTS enable_rls_for_client;

CREATE OR REPLACE PROCEDURE enable_rls_for_client(
    p_first_name TEXT,
    p_last_name TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id INTEGER;
    v_role_name TEXT;
BEGIN
    -- Enable RLS on required tables
    ALTER TABLE public.rental ENABLE ROW LEVEL SECURITY;
    ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;

    -- Fetch customer_id dynamically
    SELECT customer_id INTO v_customer_id
    FROM public.customer
    WHERE first_name = p_first_name AND last_name = p_last_name
    LIMIT 1;

    IF v_customer_id IS NULL THEN
        RAISE EXCEPTION 'No customer found for % %', p_first_name, p_last_name;
    END IF;

    -- Build dynamic role name
    v_role_name := format('client_%s_%s', lower(p_first_name), lower(p_last_name));

    -- Create the client role if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = v_role_name) THEN
        EXECUTE format('CREATE ROLE %I LOGIN PASSWORD ''default123'';', v_role_name);
    END IF;

    -- Drop existing policies if they exist
    EXECUTE format('DROP POLICY IF EXISTS rental_own_data ON public.rental;');
    EXECUTE format('DROP POLICY IF EXISTS payment_own_data ON public.payment;');

    -- Create RLS policy for rental table
    EXECUTE format($f$
        CREATE POLICY rental_own_data ON public.rental
        FOR SELECT TO %I
        USING (customer_id = %s);
    $f$, v_role_name, v_customer_id);

    -- Create RLS policy for payment table
    EXECUTE format($f$
        CREATE POLICY payment_own_data ON public.payment
        FOR SELECT TO %I
        USING (customer_id = %s);
    $f$, v_role_name, v_customer_id);

    RAISE NOTICE 'RLS setup completed for role: %', v_role_name;
END;
$$;


-- Example usage:
CALL enable_rls_for_client('Maria', 'Stefania');
-- CALL enable_rls_for_client('Tudor', 'Alexandru');


