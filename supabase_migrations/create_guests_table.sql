-- Create guests table for temporary users
CREATE TABLE IF NOT EXISTS guests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    identification_number TEXT,
    profile_image TEXT DEFAULT NULL,
    charge TEXT NOT NULL DEFAULT 'Invitado',
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_guests_user_id ON guests(user_id);

-- Create index on created_at for cleanup queries
CREATE INDEX IF NOT EXISTS idx_guests_created_at ON guests(created_at);

-- Enable Row Level Security
ALTER TABLE guests ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only read their own guest record
CREATE POLICY "Users can read own guest record"
ON guests FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can update their own guest record
CREATE POLICY "Users can update own guest record"
ON guests FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Allow insert for authenticated users (for registration)
CREATE POLICY "Allow insert for authenticated users"
ON guests FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Function to delete old guest users (older than 1 month)
CREATE OR REPLACE FUNCTION delete_old_guests()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    guest_record RECORD;
BEGIN
    -- Find all guests older than 1 month
    FOR guest_record IN
        SELECT user_id, email
        FROM guests
        WHERE created_at < NOW() - INTERVAL '1 month'
    LOOP
        -- Delete the auth user (which will cascade to guests table)
        DELETE FROM auth.users WHERE id = guest_record.user_id;
        
        RAISE NOTICE 'Deleted guest user: %', guest_record.email;
    END LOOP;
END;
$$;

-- Function to be called periodically (can be triggered by cron job or edge function)
-- To set up automatic deletion, you need to either:
-- 1. Use pg_cron extension (if available):
--    SELECT cron.schedule('delete-old-guests', '0 0 * * *', 'SELECT delete_old_guests();');
-- 2. Or create a Supabase Edge Function that calls this function daily
-- 3. Or call this function manually from your app periodically

-- Example: Create a trigger that checks on every insert (optional, but adds overhead)
-- CREATE OR REPLACE FUNCTION cleanup_on_activity()
-- RETURNS TRIGGER
-- LANGUAGE plpgsql
-- AS $$
-- BEGIN
--     PERFORM delete_old_guests();
--     RETURN NEW;
-- END;
-- $$;

-- CREATE TRIGGER trigger_cleanup_guests
-- AFTER INSERT ON guests
-- EXECUTE FUNCTION cleanup_on_activity();

COMMENT ON TABLE guests IS 'Temporary guest users that are automatically deleted after 1 month';
COMMENT ON FUNCTION delete_old_guests() IS 'Deletes guest users older than 1 month along with their auth records';
