-- Row Level Security Policies for Guest Users
-- These policies restrict what guest users can access in the application

-- Helper function to check if current user is a guest
CREATE OR REPLACE FUNCTION is_guest_user()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_charge TEXT;
BEGIN
    SELECT charge INTO user_charge
    FROM guests
    WHERE user_id = auth.uid();
    
    RETURN user_charge = 'Invitado';
END;
$$;

-- Example policies for other tables (adjust based on your specific tables)
-- You should apply these patterns to tables like: students, teachers, advisors, etc.

-- ============================================
-- EXAMPLE: Restrict guests from students table
-- ============================================
-- ALTER TABLE students ENABLE ROW LEVEL SECURITY;

-- CREATE POLICY "Guests cannot access students"
-- ON students FOR ALL
-- USING (NOT is_guest_user());

-- ============================================
-- EXAMPLE: Restrict guests from teachers table
-- ============================================
-- ALTER TABLE teachers ENABLE ROW LEVEL SECURITY;

-- CREATE POLICY "Guests cannot access teachers"
-- ON teachers FOR ALL
-- USING (NOT is_guest_user());

-- ============================================
-- EXAMPLE: Allow guests limited access to games
-- ============================================
-- If you have a games or game_data table, you might want to allow read-only access:

-- ALTER TABLE games ENABLE ROW LEVEL SECURITY;

-- CREATE POLICY "Guests can view games"
-- ON games FOR SELECT
-- USING (true); -- All authenticated users can read

-- CREATE POLICY "Guests cannot modify games"
-- ON games FOR ALL
-- USING (NOT is_guest_user());

-- ============================================
-- EXAMPLE: users_games table (game progress)
-- ============================================
-- Allow guests to save their own game progress

-- ALTER TABLE users_games ENABLE ROW LEVEL SECURITY;

-- CREATE POLICY "Users can manage own game progress"
-- ON users_games FOR ALL
-- USING (user_id = auth.uid());

-- ============================================
-- EXAMPLE: objets table (user objects/items)
-- ============================================
-- Allow guests to manage their own objects

-- ALTER TABLE objets ENABLE ROW LEVEL SECURITY;

-- CREATE POLICY "Users can manage own objects"
-- ON objets FOR ALL
-- USING (user_id = auth.uid());

-- ============================================
-- EXAMPLE: Restrict guests from rewards table
-- ============================================
-- If you want to prevent guests from claiming certain rewards:

-- ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;

-- CREATE POLICY "Guests have limited reward access"
-- ON rewards FOR SELECT
-- USING (true); -- Can view rewards

-- CREATE POLICY "Only non-guests can claim rewards"
-- ON rewards FOR INSERT
-- USING (NOT is_guest_user());

-- ============================================
-- STORAGE POLICIES (Images, Files, etc.)
-- ============================================
-- Restrict guests from uploading profile images or certain files

-- CREATE POLICY "Guests cannot upload profile images"
-- ON storage.objects FOR INSERT
-- WITH CHECK (
--     bucket_id = 'profile-images' AND
--     NOT is_guest_user()
-- );

-- Allow guests to view images (but not upload)
-- CREATE POLICY "Guests can view images"
-- ON storage.objects FOR SELECT
-- USING (bucket_id IN ('profile-images', 'game-assets'));

-- ============================================
-- NOTES FOR IMPLEMENTATION:
-- ============================================
-- 1. Review all your existing tables and decide which ones guests should access
-- 2. Apply RLS policies to each table based on guest restrictions
-- 3. Test thoroughly to ensure guests can authenticate but have limited access
-- 4. Common pattern: Allow guests to read public data but restrict modifications
-- 5. Use is_guest_user() function in any policy to check guest status

-- ============================================
-- VERIFICATION QUERIES:
-- ============================================
-- To verify policies are working, run these as a guest user:

-- SELECT * FROM guests WHERE user_id = auth.uid(); -- Should work
-- SELECT * FROM students; -- Should be restricted
-- SELECT * FROM users_games WHERE user_id = auth.uid(); -- Should work for own data

COMMENT ON FUNCTION is_guest_user() IS 'Returns true if current authenticated user is a guest (charge = Invitado)';
