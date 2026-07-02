-- Create a security definer function to update a user's active status.
-- This bypasses Row Level Security (RLS) on the User table, allowing
-- authenticated sales associates to update their login/logout status.

CREATE OR REPLACE FUNCTION public.update_user_active_status(user_id uuid, is_active boolean)
RETURNS void AS $$
BEGIN
    UPDATE public."User"
    SET "isActive" = is_active
    WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
