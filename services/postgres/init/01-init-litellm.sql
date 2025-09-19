-- LiteLLM Database Initialization
-- This script runs automatically when the PostgreSQL container starts for the first time

-- Create additional indexes for performance if needed
-- (LiteLLM will create its own tables automatically)

-- Enable logging for debugging (optional)
-- ALTER SYSTEM SET log_statement = 'all';
-- ALTER SYSTEM SET log_min_duration_statement = 0;

-- Create a read-only user for monitoring (optional)
-- CREATE USER litellm_readonly WITH PASSWORD 'readonly_password';
-- GRANT CONNECT ON DATABASE litellm_db TO litellm_readonly;
-- GRANT USAGE ON SCHEMA public TO litellm_readonly;
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO litellm_readonly;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO litellm_readonly;

-- Log initialization completion
SELECT 'LiteLLM PostgreSQL database initialized successfully' AS status;
