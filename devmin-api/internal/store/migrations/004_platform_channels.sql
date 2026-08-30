ALTER TABLE app_preferences
  ADD COLUMN IF NOT EXISTS hot_reload_enabled BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE app_preferences
  ADD COLUMN IF NOT EXISTS server_docker_enabled BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE app_preferences
  ADD COLUMN IF NOT EXISTS server_enabled BOOLEAN NOT NULL DEFAULT false;

UPDATE app_preferences
SET
  hot_reload_enabled = COALESCE(local_enabled, false),
  server_docker_enabled = COALESCE(public_enabled, false)
WHERE hot_reload_enabled = false AND server_docker_enabled = false;

UPDATE app_preferences
SET hot_reload_enabled = true
WHERE local_enabled = true AND hot_reload_enabled = false;

UPDATE app_preferences
SET server_docker_enabled = true
WHERE public_enabled = true AND server_docker_enabled = false;

CREATE TABLE IF NOT EXISTS global_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS action_jobs (
  id TEXT PRIMARY KEY,
  stem TEXT NOT NULL,
  app_id TEXT,
  channel TEXT NOT NULL,
  action TEXT NOT NULL,
  status TEXT NOT NULL,
  output TEXT NOT NULL DEFAULT '',
  error TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
