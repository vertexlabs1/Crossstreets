-- Cleanup and Setup script for CrossStreets database
-- This will drop existing tables and recreate them with the correct schema

-- Drop existing tables if they exist (this will also drop associated policies)
DROP TABLE IF EXISTS user_issues CASCADE;
DROP TABLE IF EXISTS floor_corrections CASCADE;
DROP TABLE IF EXISTS performance_metrics CASCADE;
DROP TABLE IF EXISTS error_logs CASCADE;
DROP TABLE IF EXISTS user_actions CASCADE;

-- Drop the function if it exists
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Now run the complete setup scripts
-- (Copy and paste the contents of supabase_monitoring_tables.sql and supabase_floor_corrections.sql here)

-- Performance Metrics Table
CREATE TABLE IF NOT EXISTS performance_metrics (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id), -- NULL for anonymous users
    metric_name TEXT NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    unit TEXT NOT NULL,
    context JSONB DEFAULT '{}',
    device_model TEXT,
    os_version TEXT,
    app_version TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Error Logs Table
CREATE TABLE IF NOT EXISTS error_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id), -- NULL for anonymous users
    error_type TEXT NOT NULL,
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    context JSONB DEFAULT '{}',
    device_model TEXT,
    os_version TEXT,
    app_version TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Actions Table
CREATE TABLE IF NOT EXISTS user_actions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id), -- NULL for anonymous users
    action TEXT NOT NULL,
    screen TEXT NOT NULL,
    success BOOLEAN NOT NULL,
    duration DOUBLE PRECISION, -- in seconds
    context JSONB DEFAULT '{}',
    device_model TEXT,
    os_version TEXT,
    app_version TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Issues Table
CREATE TABLE IF NOT EXISTS user_issues (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id), -- NULL for anonymous users
    issue_type TEXT NOT NULL,
    notes TEXT,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address TEXT,
    device_info JSONB DEFAULT '{}',
    app_version TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Floor Corrections Table
CREATE TABLE IF NOT EXISTS floor_corrections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id), -- NULL for anonymous users
    garage_name TEXT NOT NULL,
    detected_floor TEXT NOT NULL,
    actual_floor TEXT NOT NULL,
    altitude DOUBLE PRECISION NOT NULL,
    altitude_source TEXT NOT NULL CHECK (altitude_source IN ('barometric', 'gps')),
    barometric_pressure DOUBLE PRECISION, -- NULL if not available
    gps_accuracy DOUBLE PRECISION,
    was_correct BOOLEAN NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_performance_metrics_metric_name ON performance_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_created_at ON performance_metrics(created_at);
CREATE INDEX IF NOT EXISTS idx_error_logs_error_type ON error_logs(error_type);
CREATE INDEX IF NOT EXISTS idx_error_logs_created_at ON error_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_user_actions_action ON user_actions(action);
CREATE INDEX IF NOT EXISTS idx_user_actions_screen ON user_actions(screen);
CREATE INDEX IF NOT EXISTS idx_user_actions_created_at ON user_actions(created_at);
CREATE INDEX IF NOT EXISTS idx_user_issues_issue_type ON user_issues(issue_type);
CREATE INDEX IF NOT EXISTS idx_user_issues_created_at ON user_issues(created_at);
CREATE INDEX IF NOT EXISTS idx_floor_corrections_garage_name ON floor_corrections(garage_name);
CREATE INDEX IF NOT EXISTS idx_floor_corrections_created_at ON floor_corrections(created_at);
CREATE INDEX IF NOT EXISTS idx_floor_corrections_was_correct ON floor_corrections(was_correct);
CREATE INDEX IF NOT EXISTS idx_floor_corrections_altitude_source ON floor_corrections(altitude_source);

-- Enable Row Level Security (RLS)
ALTER TABLE performance_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE floor_corrections ENABLE ROW LEVEL SECURITY;

-- RLS Policies for anonymous inserts
CREATE POLICY "Allow anonymous performance metrics" ON performance_metrics
    FOR INSERT WITH CHECK (user_id IS NULL);

CREATE POLICY "Allow anonymous error logs" ON error_logs
    FOR INSERT WITH CHECK (user_id IS NULL);

CREATE POLICY "Allow anonymous user actions" ON user_actions
    FOR INSERT WITH CHECK (user_id IS NULL);

CREATE POLICY "Allow anonymous user issues" ON user_issues
    FOR INSERT WITH CHECK (user_id IS NULL);

CREATE POLICY "Allow anonymous inserts" ON floor_corrections
    FOR INSERT WITH CHECK (user_id IS NULL);

-- RLS Policies for authenticated users
CREATE POLICY "Allow authenticated performance metrics" ON performance_metrics
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow authenticated error logs" ON error_logs
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow authenticated user actions" ON user_actions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow authenticated user issues" ON user_issues
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow authenticated inserts" ON floor_corrections
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Service role read access for analytics
CREATE POLICY "Allow service role read access" ON performance_metrics
    FOR SELECT USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role read access" ON error_logs
    FOR SELECT USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role read access" ON user_actions
    FOR SELECT USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role read access" ON user_issues
    FOR SELECT USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role read access" ON floor_corrections
    FOR SELECT USING (auth.role() = 'service_role');

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to automatically update updated_at
CREATE TRIGGER update_floor_corrections_updated_at
    BEFORE UPDATE ON floor_corrections
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Verify tables were created successfully
SELECT 
    table_name,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('performance_metrics', 'error_logs', 'user_actions', 'user_issues', 'floor_corrections')
ORDER BY table_name; 