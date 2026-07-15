-- =============================================================================
-- SBL Staging — create ALL developer roles on shuli_staging
-- =============================================================================
-- Run as shuli_admin, connected to database: shuli_staging
-- Replace each CHANGE_ME_* with a unique strong password BEFORE running.
-- Send each developer ONLY their username + password (private message).
-- NEVER commit this file with real passwords.
-- =============================================================================

-- Avigail8532
CREATE ROLE dev_avigail WITH LOGIN PASSWORD 'CHANGE_ME_avigail';
GRANT CONNECT ON DATABASE shuli_staging TO dev_avigail;
GRANT USAGE ON SCHEMA public TO dev_avigail;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO dev_avigail;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO dev_avigail;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dev_avigail;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO dev_avigail;

-- HilaGeula
CREATE ROLE dev_hila WITH LOGIN PASSWORD 'CHANGE_ME_hila';
GRANT CONNECT ON DATABASE shuli_staging TO dev_hila;
GRANT USAGE ON SCHEMA public TO dev_hila;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO dev_hila;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO dev_hila;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dev_hila;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO dev_hila;

-- MalkyDoutsch
CREATE ROLE dev_malky WITH LOGIN PASSWORD 'CHANGE_ME_malky';
GRANT CONNECT ON DATABASE shuli_staging TO dev_malky;
GRANT USAGE ON SCHEMA public TO dev_malky;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO dev_malky;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO dev_malky;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dev_malky;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO dev_malky;

-- SaraDinaKelerman
CREATE ROLE dev_sara WITH LOGIN PASSWORD 'CHANGE_ME_sara';
GRANT CONNECT ON DATABASE shuli_staging TO dev_sara;
GRANT USAGE ON SCHEMA public TO dev_sara;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO dev_sara;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO dev_sara;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dev_sara;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO dev_sara;

-- shirasiroka
CREATE ROLE dev_shira WITH LOGIN PASSWORD 'CHANGE_ME_shira';
GRANT CONNECT ON DATABASE shuli_staging TO dev_shira;
GRANT USAGE ON SCHEMA public TO dev_shira;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO dev_shira;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO dev_shira;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dev_shira;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO dev_shira;

-- Ayala
CREATE ROLE dev_ayala WITH LOGIN PASSWORD 'CHANGE_ME_ayala';
GRANT CONNECT ON DATABASE shuli_staging TO dev_ayala;
GRANT USAGE ON SCHEMA public TO dev_ayala;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO dev_ayala;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO dev_ayala;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dev_ayala;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO dev_ayala;

-- Verify
SELECT rolname, rolcanlogin FROM pg_roles WHERE rolname LIKE 'dev_%' ORDER BY rolname;
