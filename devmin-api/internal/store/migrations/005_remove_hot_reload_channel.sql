-- Migrate former hot-reload channel preferences to local Docker (script-based deploy).
UPDATE app_preferences
SET docker_enabled = true
WHERE hot_reload_enabled = true AND docker_enabled = false;

UPDATE app_preferences
SET run_mode = 'localDocker'
WHERE run_mode = 'hotReload';

UPDATE app_preferences
SET hot_reload_enabled = false
WHERE hot_reload_enabled = true;
