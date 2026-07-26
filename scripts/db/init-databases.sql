-- =============================================================================
-- SBL — PostgreSQL database initialization (run as RDS master user)
-- =============================================================================
-- Context:
--   Terraform creates the PRIMARY application database automatically via
--   aws_db_instance.db_name on first RDS provision:
--     Staging : shuli_staging   (org alias: sbl_staging)
--     Prod    : shuli_prod      (org alias: sbl_production)
--
-- Use this script ONLY when:
--   • Provisioning a fresh RDS manually (outside Terraform), or
--   • Creating additional logical databases on an existing instance.
--
-- Connect first:
--   psql -h <rds-host> -U <master-user> -d postgres
-- =============================================================================

-- Staging application database
CREATE DATABASE shuli_staging
  WITH ENCODING 'UTF8'
       LC_COLLATE 'en_US.UTF-8'
       LC_CTYPE 'en_US.UTF-8'
       TEMPLATE template0;

-- Production application database
CREATE DATABASE shuli_prod
  WITH ENCODING 'UTF8'
       LC_COLLATE 'en_US.UTF-8'
       LC_CTYPE 'en_US.UTF-8'
       TEMPLATE template0;

-- Verify
SELECT datname FROM pg_database WHERE datname IN ('shuli_staging', 'shuli_prod');
