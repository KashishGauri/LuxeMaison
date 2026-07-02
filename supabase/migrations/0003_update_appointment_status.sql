-- Create a security definer function to update an appointment's status.
-- This bypasses Row Level Security (RLS) on the Appointment table, allowing
-- authenticated sales associates to update the status of any appointment.

CREATE OR REPLACE FUNCTION public.update_appointment_status(appointment_id uuid, new_status text)
RETURNS void AS $$
BEGIN
    UPDATE public."Appointment"
    SET status = new_status
    WHERE id = appointment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
