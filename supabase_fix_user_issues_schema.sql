-- Fix user_issues table schema to match app expectations
-- This will add missing columns and ensure the table structure is correct

-- First, let's see what columns currently exist
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_issues' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Add missing columns if they don't exist
DO $$ 
BEGIN
    -- Add user_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_issues' 
        AND column_name = 'user_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE user_issues ADD COLUMN user_id UUID REFERENCES auth.users(id);
    END IF;

    -- Add issue_type column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_issues' 
        AND column_name = 'issue_type'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE user_issues ADD COLUMN issue_type TEXT;
    END IF;

    -- Add notes column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_issues' 
        AND column_name = 'notes'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE user_issues ADD COLUMN notes TEXT;
    END IF;

    -- Add latitude column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_issues' 
        AND column_name = 'latitude'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE user_issues ADD COLUMN latitude DOUBLE PRECISION;
    END IF;

    -- Add longitude column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_issues' 
        AND column_name = 'longitude'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE user_issues ADD COLUMN longitude DOUBLE PRECISION;
    END IF;

    -- Add address column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_issues' 
        AND column_name = 'address'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE user_issues ADD COLUMN address TEXT;
    END IF;

    -- Add created_at column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_issues' 
        AND column_name = 'created_at'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE user_issues ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;

    -- Remove uuid column if it exists (we don't need it, id is the primary key)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_issues' 
        AND column_name = 'uuid'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE user_issues DROP COLUMN uuid;
    END IF;

    -- Remove timestamp column if it exists (we use created_at instead)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'user_issues' 
        AND column_name = 'timestamp'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE user_issues DROP COLUMN timestamp;
    END IF;

END $$;

-- Show the final table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_issues' 
AND table_schema = 'public'
ORDER BY ordinal_position; 