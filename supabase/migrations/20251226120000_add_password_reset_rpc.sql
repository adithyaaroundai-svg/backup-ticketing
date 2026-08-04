-- Migration: 20251226120000_add_password_reset_rpc.sql
-- Description: Add RPC to reset customer password via secret email verification.

-- Ensure pgcrypto is available for hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.reset_customer_password_by_secret_email(
    p_secret_email TEXT,
    p_new_password TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER -- Runs as database owner to access auth schema
SET search_path = public, auth
AS $$
DECLARE
    v_customer_id UUID;
    v_contact_email TEXT;
    v_auth_user_id UUID;
BEGIN
    -- 1. Verify existence of secret email
    SELECT id, contact_email, auth_user_id 
    INTO v_customer_id, v_contact_email, v_auth_user_id
    FROM public.customers
    WHERE secret_email = p_secret_email
    LIMIT 1;

    IF v_customer_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Invalid secret email address.');
    END IF;

    -- 2. Update DB password
    UPDATE public.customers 
    SET password = p_new_password
    WHERE id = v_customer_id;

    -- 3. Update Supabase Auth password if linked
    IF v_auth_user_id IS NOT NULL THEN
        UPDATE auth.users
        SET encrypted_password = crypt(p_new_password, gen_salt('bf')),
            updated_at = NOW()
        WHERE id = v_auth_user_id;
    ELSE
        -- If not linked by ID, try linking by email
        UPDATE auth.users
        SET encrypted_password = crypt(p_new_password, gen_salt('bf')),
            updated_at = NOW()
        WHERE email = v_contact_email;
    END IF;

    RETURN json_build_object('success', true);
END;
$$;

-- Grant execution to anon (for forgot password page)
GRANT EXECUTE ON FUNCTION public.reset_customer_password_by_secret_email TO anon;
GRANT EXECUTE ON FUNCTION public.reset_customer_password_by_secret_email TO authenticated;
