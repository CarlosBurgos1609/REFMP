-- Fix RLS policies for guests table to allow registration

-- Drop existing policies
DROP POLICY IF EXISTS "Users can read own guest record" ON guests;
DROP POLICY IF EXISTS "Users can update own guest record" ON guests;
DROP POLICY IF EXISTS "Allow insert for authenticated users" ON guests;

-- Policy: Allow INSERT for anyone (needed for registration)
-- During signup, the user is being created so auth.uid() won't match yet
CREATE POLICY "Allow guest registration"
ON guests FOR INSERT
WITH CHECK (true);

-- Policy: Users can only read their own guest record
CREATE POLICY "Users can read own guest record"
ON guests FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Users can update their own guest record
CREATE POLICY "Users can update own guest record"
ON guests FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own guest record
CREATE POLICY "Users can delete own guest record"
ON guests FOR DELETE
USING (auth.uid() = user_id);

-- Add comment
COMMENT ON POLICY "Allow guest registration" ON guests IS 
'Permite el registro de nuevos invitados sin autenticación previa';
