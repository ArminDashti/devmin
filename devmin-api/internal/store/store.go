package store

import (
	"context"
	"embed"
	"encoding/json"
	"errors"

	"github.com/ArminDashti/devmin-api/internal/runmode"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

var ErrNotFound = errors.New("not found")

//go:embed migrations/*.sql
var migrationFS embed.FS

type Store struct {
	pool *pgxpool.Pool
}

type User struct {
	ID           int64
	Username     string
	PasswordHash string
}

type AppPreference struct {
	LocalEnabled        bool
	LocalDockerEnabled  bool
	ServerDockerEnabled bool
	ServerEnabled       bool
	DockerEnabled       bool
	PublicEnabled       bool
}

func Connect(ctx context.Context, databaseURL string) (*Store, error) {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, err
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	s := &Store{pool: pool}
	if err := s.Migrate(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	return s, nil
}

func (s *Store) Close() {
	if s != nil && s.pool != nil {
		s.pool.Close()
	}
}

func (s *Store) Migrate(ctx context.Context) error {
	for _, name := range []string{
		"migrations/001_users.sql",
		"migrations/002_app_run_mode.sql",
		"migrations/003_app_mode_flags.sql",
		"migrations/004_platform_channels.sql",
		"migrations/005_remove_hot_reload_channel.sql",
	} {
		sqlBytes, err := migrationFS.ReadFile(name)
		if err != nil {
			return err
		}
		if _, err := s.pool.Exec(ctx, string(sqlBytes)); err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) CountUsers(ctx context.Context) (int64, error) {
	var n int64
	err := s.pool.QueryRow(ctx, `SELECT COUNT(*) FROM users`).Scan(&n)
	return n, err
}

func (s *Store) CreateUser(ctx context.Context, username, passwordHash string) error {
	_, err := s.pool.Exec(ctx, `INSERT INTO users (username, password_hash) VALUES ($1, $2)`, username, passwordHash)
	return err
}

func (s *Store) GetUserByUsername(ctx context.Context, username string) (*User, error) {
	var u User
	err := s.pool.QueryRow(ctx, `SELECT id, username, password_hash FROM users WHERE username = $1`, username).
		Scan(&u.ID, &u.Username, &u.PasswordHash)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return &u, nil
}

func normalizePreference(pref AppPreference) AppPreference {
	if !pref.ServerDockerEnabled && pref.PublicEnabled {
		pref.ServerDockerEnabled = pref.PublicEnabled
	}
	if !pref.LocalDockerEnabled && pref.DockerEnabled {
		pref.LocalDockerEnabled = pref.DockerEnabled
	}
	pref.DockerEnabled = pref.LocalDockerEnabled
	pref.PublicEnabled = pref.ServerDockerEnabled
	return pref
}

func (s *Store) GetAppPreference(ctx context.Context, stem string) (AppPreference, bool, error) {
	var pref AppPreference
	var legacyHotReload bool
	err := s.pool.QueryRow(ctx, `
		SELECT local_enabled, docker_enabled, public_enabled,
		       hot_reload_enabled, server_docker_enabled, server_enabled
		FROM app_preferences WHERE stem = $1
	`, stem).Scan(
		&pref.LocalEnabled, &pref.DockerEnabled, &pref.PublicEnabled,
		&legacyHotReload, &pref.ServerDockerEnabled, &pref.ServerEnabled,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return AppPreference{}, false, nil
		}
		return AppPreference{}, false, err
	}
	if legacyHotReload && !pref.LocalDockerEnabled {
		pref.LocalDockerEnabled = true
		pref.DockerEnabled = true
	}
	return normalizePreference(pref), true, nil
}

func (s *Store) SetModeEnabled(ctx context.Context, stem string, mode runmode.Mode, enabled bool) error {
	pref, _, err := s.GetAppPreference(ctx, stem)
	if err != nil {
		return err
	}
	switch mode {
	case runmode.Local:
		pref.LocalEnabled = enabled
	case runmode.LocalDocker:
		pref.LocalDockerEnabled = enabled
		pref.DockerEnabled = enabled
	case runmode.ServerDocker:
		pref.ServerDockerEnabled = enabled
		pref.PublicEnabled = enabled
	case runmode.Server:
		pref.ServerEnabled = enabled
	default:
		return errors.New("invalid mode")
	}
	pref.DockerEnabled = pref.LocalDockerEnabled
	pref.PublicEnabled = pref.ServerDockerEnabled
	return s.SetAppPreference(ctx, stem, pref)
}

func (s *Store) SetAppPreference(ctx context.Context, stem string, pref AppPreference) error {
	pref = normalizePreference(pref)
	legacyMode := runmode.Default()
	legacyEnabled := false
	if pref.ServerEnabled {
		legacyMode = runmode.Server
		legacyEnabled = true
	} else if pref.ServerDockerEnabled {
		legacyMode = runmode.ServerDocker
		legacyEnabled = true
	} else if pref.LocalDockerEnabled {
		legacyMode = runmode.LocalDocker
		legacyEnabled = true
	} else if pref.LocalEnabled {
		legacyMode = runmode.Local
		legacyEnabled = true
	}
	_, err := s.pool.Exec(ctx, `
		INSERT INTO app_preferences (
			stem, local_enabled, docker_enabled, public_enabled,
			hot_reload_enabled, server_docker_enabled, server_enabled,
			enabled, run_mode, updated_at
		)
		VALUES ($1, $2, $3, $4, false, $5, $6, $7, $8, NOW())
		ON CONFLICT (stem) DO UPDATE SET
			local_enabled = EXCLUDED.local_enabled,
			docker_enabled = EXCLUDED.docker_enabled,
			public_enabled = EXCLUDED.public_enabled,
			hot_reload_enabled = false,
			server_docker_enabled = EXCLUDED.server_docker_enabled,
			server_enabled = EXCLUDED.server_enabled,
			enabled = EXCLUDED.enabled,
			run_mode = EXCLUDED.run_mode,
			updated_at = NOW()
	`, stem,
		pref.LocalEnabled, pref.DockerEnabled, pref.PublicEnabled,
		pref.ServerDockerEnabled, pref.ServerEnabled,
		legacyEnabled, string(legacyMode),
	)
	return err
}

func (s *Store) ListAppPreferences(ctx context.Context) (map[string]AppPreference, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT stem, local_enabled, docker_enabled, public_enabled,
		       hot_reload_enabled, server_docker_enabled, server_enabled
		FROM app_preferences
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]AppPreference{}
	for rows.Next() {
		var stem string
		var pref AppPreference
		var legacyHotReload bool
		if err := rows.Scan(
			&stem,
			&pref.LocalEnabled, &pref.DockerEnabled, &pref.PublicEnabled,
			&legacyHotReload, &pref.ServerDockerEnabled, &pref.ServerEnabled,
		); err != nil {
			return nil, err
		}
		if legacyHotReload && !pref.LocalDockerEnabled {
			pref.LocalDockerEnabled = true
			pref.DockerEnabled = true
		}
		out[stem] = normalizePreference(pref)
	}
	return out, rows.Err()
}

func (s *Store) GetGlobalSetting(ctx context.Context, key string) (json.RawMessage, bool, error) {
	var raw json.RawMessage
	err := s.pool.QueryRow(ctx, `SELECT value FROM global_settings WHERE key = $1`, key).Scan(&raw)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, false, nil
		}
		return nil, false, err
	}
	return raw, true, nil
}

func (s *Store) SetGlobalSetting(ctx context.Context, key string, value json.RawMessage) error {
	_, err := s.pool.Exec(ctx, `
		INSERT INTO global_settings (key, value, updated_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
	`, key, value)
	return err
}
