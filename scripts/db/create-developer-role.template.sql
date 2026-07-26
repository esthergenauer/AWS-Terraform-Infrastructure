-- =============================================================================
-- SBL — Per-developer PostgreSQL role template (LIMITED privileges)
-- =============================================================================
-- Run ONCE per developer, connected to the target database (e.g. shuli_staging).
-- Replace placeholders before execution:
--   {{DEV_USERNAME}}  e.g. dev_avigail
--   {{DEV_PASSWORD}}  strong unique password (NEVER commit real values)
--
-- Master credentials are for break-glass / DDL only — never share them.
-- =============================================================================

-- 1) Create login role
CREATE ROLE {{DEV_USERNAME}} WITH LOGIN PASSWORD '{{DEV_PASSWORD}}';

-- 2) Database connect
GRANT CONNECT ON DATABASE shuli_staging TO {{DEV_USERNAME}};

-- 3) Schema usage (repeat per schema if you add more later)
GRANT USAGE ON SCHEMA public TO {{DEV_USERNAME}};

-- 4) DML on existing tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO {{DEV_USERNAME}};
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO {{DEV_USERNAME}};

-- 5) Default privileges for future tables created by master/migrations
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {{DEV_USERNAME}};
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO {{DEV_USERNAME}};

-- 6) Explicitly deny DDL (no CREATE/DROP/ALTER) — least privilege by omission
-- Developers should NOT receive: CREATE, DROP, ALTER, TRUNCATE on schema objects.

-- Verify
SELECT rolname, rolcanlogin FROM pg_roles WHERE rolname = '{{DEV_USERNAME}}';
