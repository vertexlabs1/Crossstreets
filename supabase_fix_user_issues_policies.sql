-- Fix user_issues table policies to match other tables
-- This will update the RLS policies for user_issues to be consistent

-- Drop existing policies for user_issues
DROP POLICY IF EXISTS "Allow insert for anon" ON user_issues;
DROP POLICY IF EXISTS "Allow read own feedback" ON user_issues;

-- Create the correct policies to match other tables
CREATE POLICY "Allow anonymous user issues" ON user_issues
    FOR INSERT WITH CHECK (user_id IS NULL);

CREATE POLICY "Allow authenticated user issues" ON user_issues
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow service role read access" ON user_issues
    FOR SELECT USING (auth.role() = 'service_role');

-- Verify the policies were created correctly
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_issues'
ORDER BY policyname; 