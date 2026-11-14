-- @prisma/adapter-pg sends timestamps as UTC without an offset and reads timestamptz as UTC, so the
-- session timezone must be UTC: elsewhere every stored time is shifted by the server's offset.
-- Applies to new connections (restart the API after migrating). Neon already defaults to UTC.
DO $$
BEGIN
  EXECUTE format('ALTER DATABASE %I SET timezone TO %L', current_database(), 'UTC');
END
$$;
