-- Robust fix for user_issues table policies
-- This script will properly handle existing policies and ensure they're replaced correctly

-- First, let's see what policies currently exist
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_issues'
ORDER BY policyname;

-- Drop ALL existing policies for user_issues (using CASCADE to ensure they're removed)
DO $$ 
BEGIN
    -- Drop policies by name if they exist
    DROP POLICY IF EXISTS "Allow insert for anon" ON user_issues;
    DROP POLICY IF EXISTS "Allow read own feedback" ON user_issues;
    DROP POLICY IF EXISTS "Allow anonymous user issues" ON user_issues;
    DROP POLICY IF EXISTS "Allow authenticated user issues" ON user_issues;
    DROP POLICY IF EXISTS "Allow service role read access" ON user_issues;
    
    -- Also try to drop any other policies that might exist
    EXECUTE (
        'DROP POLICY IF EXISTS "' || 
        (SELECT string_agg(policyname, '" ON user_issues; DROP POLICY IF EXISTS "') 
         FROM pg_policies 
         WHERE tablename = 'user_issues') || 
        '" ON user_issues;'
    );
EXCEPTION
    WHEN OTHERS THEN
        -- If the dynamic drop fails, continue with individual drops
        NULL;
END $$;

-- Now create the correct policies
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