-- =============================================================================
-- Portfolio 1 — schema/01_extensions.sql
-- TestPoint CBT case study.
--
-- Enables the two extensions the schema relies on:
--   * btree_gist   — needed for the EXCLUDE constraint that stops a candidate
--                    being booked into two overlapping sessions (gist index
--                    over a tstzrange + scalar candidate_id).
--   * pgcrypto     — used by seed/bulk generators for gen_random_uuid() so
--                    every candidate / registration has a stable UUID if we
--                    ever need one (not required by the schema, harmless).
--
-- Run as the testpoint superuser through the Unix socket:
--   sudo runuser -u postgres -- psql -d testpoint -f schema/01_extensions.sql
-- =============================================================================
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
