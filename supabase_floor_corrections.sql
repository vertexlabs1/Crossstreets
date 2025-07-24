-- Floor Corrections Table for CrossStreets
-- This table tracks floor detection accuracy and user corrections for machine learning

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
CREATE INDEX IF NOT EXISTS idx_floor_corrections_garage_name ON floor_corrections(garage_name);
CREATE INDEX IF NOT EXISTS idx_floor_corrections_created_at ON floor_corrections(created_at);
CREATE INDEX IF NOT EXISTS idx_floor_corrections_was_correct ON floor_corrections(was_correct);
CREATE INDEX IF NOT EXISTS idx_floor_corrections_altitude_source ON floor_corrections(altitude_source);

-- Enable Row Level Security (RLS)
ALTER TABLE floor_corrections ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Allow anonymous inserts (for users without accounts)
CREATE POLICY "Allow anonymous inserts" ON floor_corrections
    FOR INSERT WITH CHECK (user_id IS NULL);

-- Allow authenticated users to insert their own data
CREATE POLICY "Allow authenticated inserts" ON floor_corrections
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Allow users to view their own data
CREATE POLICY "Allow users to view own data" ON floor_corrections
    FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

-- Allow service role to read all data (for analytics)
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

-- View for analytics (garage accuracy statistics)
CREATE OR REPLACE VIEW garage_accuracy_stats AS
SELECT 
    garage_name,
    COUNT(*) as total_corrections,
    SUM(CASE WHEN was_correct THEN 1 ELSE 0 END) as correct_predictions,
    ROUND(
        (SUM(CASE WHEN was_correct THEN 1 ELSE 0 END)::DECIMAL / COUNT(*)::DECIMAL) * 100, 
        2
    ) as accuracy_percentage,
    AVG(altitude) as avg_altitude,
    altitude_source,
    MIN(created_at) as first_correction,
    MAX(created_at) as last_correction
FROM floor_corrections
GROUP BY garage_name, altitude_source
ORDER BY total_corrections DESC;

-- View for floor-specific statistics
CREATE OR REPLACE VIEW floor_accuracy_stats AS
SELECT 
    garage_name,
    actual_floor,
    COUNT(*) as total_occurrences,
    SUM(CASE WHEN was_correct THEN 1 ELSE 0 END) as correct_predictions,
    ROUND(
        (SUM(CASE WHEN was_correct THEN 1 ELSE 0 END)::DECIMAL / COUNT(*)::DECIMAL) * 100, 
        2
    ) as accuracy_percentage,
    AVG(altitude) as avg_altitude,
    altitude_source
FROM floor_corrections
GROUP BY garage_name, actual_floor, altitude_source
ORDER BY garage_name, actual_floor;

-- Comments for documentation
COMMENT ON TABLE floor_corrections IS 'Tracks floor detection accuracy and user corrections for machine learning improvements';
COMMENT ON COLUMN floor_corrections.user_id IS 'User ID if authenticated, NULL for anonymous users';
COMMENT ON COLUMN floor_corrections.altitude_source IS 'Source of altitude data: barometric (more accurate) or gps';
COMMENT ON COLUMN floor_corrections.barometric_pressure IS 'Barometric pressure in kPa, NULL if not available';
COMMENT ON COLUMN floor_corrections.was_correct IS 'Whether the detected floor matched the actual floor';
COMMENT ON COLUMN floor_corrections.altitude IS 'Altitude in meters, rounded to 3m precision (typical floor height)';
COMMENT ON COLUMN floor_corrections.detected_floor IS 'Floor detected by algorithm (e.g., F1, F2, G, B1)';
COMMENT ON COLUMN floor_corrections.actual_floor IS 'Floor selected by user (e.g., F1, F2, G, B1)'; 