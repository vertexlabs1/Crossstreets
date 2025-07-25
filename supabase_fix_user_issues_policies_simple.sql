-- Simple fix for user_issues table policies
-- This script only creates missing policies without dropping existing ones

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

-- Create missing policies only if they don't exist
DO $$ 
BEGIN
    -- Create "Allow anonymous user issues" policy if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_issues' 
        AND policyname = 'Allow anonymous user issues'
    ) THEN
        CREATE POLICY "Allow anonymous user issues" ON user_issues
            FOR INSERT WITH CHECK (user_id IS NULL);
    END IF;

    -- Create "Allow authenticated user issues" policy if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_issues' 
        AND policyname = 'Allow authenticated user issues'
    ) THEN
        CREATE POLICY "Allow authenticated user issues" ON user_issues
            FOR INSERT WITH CHECK (auth.uid() = user_id);
    END IF;

    -- Create "Allow service role read access" policy if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_issues' 
        AND policyname = 'Allow service role read access'
    ) THEN
        CREATE POLICY "Allow service role read access" ON user_issues
            FOR SELECT USING (auth.role() = 'service_role');
    END IF;
END $$;

-- Show final policies
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