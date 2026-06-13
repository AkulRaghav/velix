-- Local-machine setup for integration testing (Windows winget Postgres).
-- Creates the velix role and the six per-service databases.
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'velix') THEN
    CREATE ROLE velix LOGIN PASSWORD 'velix';
  END IF;
END
$$;
