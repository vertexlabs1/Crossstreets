-- Diagnostic script to check existing tables and their structure
-- Run this in your Supabase SQL Editor to see what's currently in your database

-- Check if tables exist
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('performance_metrics', 'error_logs', 'user_actions', 'user_issues', 'floor_corrections')
ORDER BY table_name;

-- Check table structure for each table (if they exist)
-- Performance Metrics
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'performance_metrics' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Error Logs
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'error_logs' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- User Actions
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_actions' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- User Issues
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_issues' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Floor Corrections
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'floor_corrections' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check RLS policies
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
WHERE tablename IN ('performance_metrics', 'error_logs', 'user_actions', 'user_issues', 'floor_corrections')
ORDER BY tablename, policyname; 