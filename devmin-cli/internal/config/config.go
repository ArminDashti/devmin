package config

import (
	"os"
	"path/filepath"
	"strings"
)

const (
	DefaultAPIURL   = "http://127.0.0.1:8195"
	DefaultUsername = "armin"
	DefaultPassword = "dopadopa123"
	Version         = "0.1.0"
)

type Config struct {
	APIURL   string
	Username string
	Password string
	TokenDir string
	JSON     bool
}

func Load() Config {
	home, _ := os.UserHomeDir()
	tokenDir := filepath.Join(home, ".devmin")
	return Config{
		APIURL:   firstNonEmpty(os.Getenv("DEVMIN_API_URL"), DefaultAPIURL),
		Username: firstNonEmpty(os.Getenv("DEVMIN_USERNAME"), DefaultUsername),
		Password: firstNonEmpty(os.Getenv("DEVMIN_PASSWORD"), DefaultPassword),
		TokenDir: tokenDir,
	}
}

func (c Config) TokenPath() string {
	return filepath.Join(c.TokenDir, "token")
}

func firstNonEmpty(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return strings.TrimRight(strings.TrimSpace(v), "/")
		}
	}
	return ""
}
