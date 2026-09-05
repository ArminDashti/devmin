package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"time"
)

type Client struct {
	BaseURL    string
	HTTPClient *http.Client
	Token      string
	TokenPath  string
}

func NewClient(baseURL, tokenPath string) *Client {
	return &Client{
		BaseURL:    baseURL,
		HTTPClient: &http.Client{Timeout: 30 * time.Second},
		TokenPath:  tokenPath,
	}
}

func (c *Client) LoadToken() error {
	b, err := os.ReadFile(c.TokenPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}
	c.Token = string(bytes.TrimSpace(b))
	return nil
}

func (c *Client) SaveToken(token string) error {
	if err := os.MkdirAll(filepath.Dir(c.TokenPath), 0o700); err != nil {
		return err
	}
	c.Token = token
	return os.WriteFile(c.TokenPath, []byte(token), 0o600)
}

func (c *Client) Health(ctx context.Context) (*HealthResponse, error) {
	var out HealthResponse
	if err := c.do(ctx, http.MethodGet, "/health", nil, false, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

func (c *Client) Login(ctx context.Context, username, password string) (*LoginResponse, error) {
	body := map[string]string{"username": username, "password": password}
	var out LoginResponse
	if err := c.do(ctx, http.MethodPost, "/api/v1/auth/login", body, false, &out); err != nil {
		return nil, err
	}
	if out.Token == "" {
		return nil, fmt.Errorf("login returned empty token")
	}
	if err := c.SaveToken(out.Token); err != nil {
		return nil, err
	}
	return &out, nil
}

func (c *Client) EnsureAuth(ctx context.Context, username, password string) error {
	if err := c.LoadToken(); err != nil {
		return err
	}
	if c.Token != "" {
		if _, err := c.ListStacks(ctx); err == nil {
			return nil
		}
	}
	_, err := c.Login(ctx, username, password)
	return err
}

func (c *Client) ListStacks(ctx context.Context) ([]Stack, error) {
	var wrap struct {
		Stacks []Stack `json:"stacks"`
	}
	if err := c.do(ctx, http.MethodGet, "/api/v1/stacks", nil, true, &wrap); err != nil {
		return nil, err
	}
	return wrap.Stacks, nil
}

func (c *Client) GetStack(ctx context.Context, stem string) (*Stack, error) {
	var out Stack
	path := "/api/v1/stacks/" + url.PathEscape(stem)
	if err := c.do(ctx, http.MethodGet, path, nil, true, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

func (c *Client) GetApplication(ctx context.Context, appID string) (*Application, *Stack, error) {
	var wrap struct {
		Application Application `json:"application"`
		Stack       Stack       `json:"stack"`
	}
	path := "/api/v1/applications/" + url.PathEscape(appID)
	if err := c.do(ctx, http.MethodGet, path, nil, true, &wrap); err != nil {
		return nil, nil, err
	}
	return &wrap.Application, &wrap.Stack, nil
}

func (c *Client) PostAction(ctx context.Context, req ActionRequest) (*ActionJob, error) {
	var out ActionJob
	if err := c.do(ctx, http.MethodPost, "/api/v1/actions", req, true, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

func (c *Client) GetAction(ctx context.Context, id string) (*ActionJob, error) {
	var out ActionJob
	path := "/api/v1/actions/" + url.PathEscape(id)
	if err := c.do(ctx, http.MethodGet, path, nil, true, &out); err != nil {
		return nil, err
	}
	return &out, nil
}

func (c *Client) PollAction(ctx context.Context, id string, onUpdate func(*ActionJob)) (*ActionJob, error) {
	ticker := time.NewTicker(1500 * time.Millisecond)
	defer ticker.Stop()
	for i := 0; i < 120; i++ {
		job, err := c.GetAction(ctx, id)
		if err != nil {
			return nil, err
		}
		if onUpdate != nil {
			onUpdate(job)
		}
		if job.Status != "running" {
			return job, nil
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-ticker.C:
		}
	}
	return nil, fmt.Errorf("action %s timed out still running", id)
}

func (c *Client) do(ctx context.Context, method, path string, body any, auth bool, out any) error {
	var reader io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return err
		}
		reader = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.BaseURL+path, reader)
	if err != nil {
		return err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if auth {
		if c.Token == "" {
			return fmt.Errorf("not authenticated")
		}
		req.Header.Set("Authorization", "Bearer "+c.Token)
	}
	res, err := c.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer res.Body.Close()
	raw, err := io.ReadAll(res.Body)
	if err != nil {
		return err
	}
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		msg := string(bytes.TrimSpace(raw))
		if msg == "" {
			msg = res.Status
		}
		return fmt.Errorf("%s %s: %s", method, path, msg)
	}
	if out == nil || len(raw) == 0 {
		return nil
	}
	if err := json.Unmarshal(raw, out); err != nil {
		return fmt.Errorf("decode %s: %w", path, err)
	}
	return nil
}
