-- Performance Monitoring Tables for CrossStreets
-- These tables track app performance, errors, and user behavior for continuous improvement

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

-- Enable Row Level Security (RLS)
ALTER TABLE performance_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_issues ENABLE ROW LEVEL SECURITY;

-- RLS Policies for anonymous inserts
CREATE POLICY "Allow anonymous performance metrics" ON performance_metrics
    FOR INSERT WITH CHECK (user_id IS NULL);

CREATE POLICY "Allow anonymous error logs" ON error_logs
    FOR INSERT WITH CHECK (user_id IS NULL);

CREATE POLICY "Allow anonymous user actions" ON user_actions
    FOR INSERT WITH CHECK (user_id IS NULL);

CREATE POLICY "Allow anonymous user issues" ON user_issues
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

-- Service role read access for analytics
CREATE POLICY "Allow service role read access" ON performance_metrics
    FOR SELECT USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role read access" ON error_logs
    FOR SELECT USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role read access" ON user_actions
    FOR SELECT USING (auth.role() = 'service_role');

CREATE POLICY "Allow service role read access" ON user_issues
    FOR SELECT USING (auth.role() = 'service_role');

-- Analytics Views
CREATE OR REPLACE VIEW performance_summary AS
SELECT 
    metric_name,
    COUNT(*) as total_measurements,
    AVG(value) as average_value,
    MIN(value) as min_value,
    MAX(value) as max_value,
    unit,
    DATE_TRUNC('day', created_at) as date
FROM performance_metrics
GROUP BY metric_name, unit, DATE_TRUNC('day', created_at)
ORDER BY date DESC, metric_name;

CREATE OR REPLACE VIEW error_summary AS
SELECT 
    error_type,
    COUNT(*) as occurrence_count,
    COUNT(DISTINCT device_model) as affected_devices,
    MIN(created_at) as first_occurrence,
    MAX(created_at) as last_occurrence
FROM error_logs
GROUP BY error_type
ORDER BY occurrence_count DESC;

CREATE OR REPLACE VIEW user_action_summary AS
SELECT 
    action,
    screen,
    COUNT(*) as total_actions,
    SUM(CASE WHEN success THEN 1 ELSE 0 END) as successful_actions,
    AVG(duration) as average_duration,
    DATE_TRUNC('day', created_at) as date
FROM user_actions
GROUP BY action, screen, DATE_TRUNC('day', created_at)
ORDER BY date DESC, total_actions DESC;

-- Comments for documentation
COMMENT ON TABLE performance_metrics IS 'Tracks app performance metrics for optimization';
COMMENT ON TABLE error_logs IS 'Tracks app errors and crashes for debugging';
COMMENT ON TABLE user_actions IS 'Tracks user interactions for UX improvement'; 