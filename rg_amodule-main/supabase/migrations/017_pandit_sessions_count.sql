-- Migration 017: Add sessions_count override to pandit_details
-- Allows admin to manually set a pandit's displayed session count
-- (e.g. to include pre-app history). When set, this takes precedence
-- over the live count from the consultations table.

ALTER TABLE pandit_details
  ADD COLUMN IF NOT EXISTS sessions_count integer DEFAULT NULL;
