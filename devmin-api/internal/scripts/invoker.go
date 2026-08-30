package scripts

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"
)

type JobStatus string

const (
	JobRunning   JobStatus = "running"
	JobSucceeded JobStatus = "succeeded"
	JobFailed    JobStatus = "failed"
)

type Job struct {
	ID        string    `json:"id"`
	Stem      string    `json:"stem"`
	AppID     string    `json:"appId,omitempty"`
	Channel   string    `json:"channel"`
	Action    string    `json:"action"`
	Status    JobStatus `json:"status"`
	Output    string    `json:"output"`
	Error     string    `json:"error,omitempty"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

type JobManager struct {
	mu   sync.RWMutex
	jobs map[string]*Job
}

func NewJobManager() *JobManager {
	return &JobManager{jobs: map[string]*Job{}}
}

func (m *JobManager) Get(id string) (*Job, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	j, ok := m.jobs[id]
	if !ok {
		return nil, false
	}
	copy := *j
	return &copy, true
}

func (m *JobManager) Start(ctx context.Context, stem, appID, channel string, action Action, fn func() (string, error)) (*Job, error) {
	id := newJobID()
	job := &Job{
		ID:        id,
		Stem:      stem,
		AppID:     appID,
		Channel:   channel,
		Action:    string(action),
		Status:    JobRunning,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}
	m.mu.Lock()
	m.jobs[id] = job
	m.mu.Unlock()

	go func() {
		out, err := fn()
		m.mu.Lock()
		defer m.mu.Unlock()
		j := m.jobs[id]
		j.UpdatedAt = time.Now()
		j.Output = tail(out, 8000)
		if err != nil {
			j.Status = JobFailed
			j.Error = err.Error()
		} else {
			j.Status = JobSucceeded
		}
	}()

	return job, nil
}

func tail(s string, max int) string {
	if len(s) <= max {
		return s
	}
	return s[len(s)-max:]
}

type Invoker struct {
	jobs *JobManager
}

func NewInvoker(jobs *JobManager) *Invoker {
	return &Invoker{jobs: jobs}
}

func (i *Invoker) RunScript(ctx context.Context, stem, appID, channel string, action Action, scriptPath string, extraArgs []string) (*Job, error) {
	return i.jobs.Start(ctx, stem, appID, channel, action, func() (string, error) {
		out, err := runPowerShellCapture(scriptPath, extraArgs)
		return out, err
	})
}

func (i *Invoker) Job(id string) (*Job, bool) {
	return i.jobs.Get(id)
}

func runPowerShellCapture(scriptPath string, extraArgs []string) (string, error) {
	if runtime.GOOS != "windows" {
		return "", fmt.Errorf("runner requires Windows")
	}
	if _, err := os.Stat(scriptPath); err != nil {
		return "", fmt.Errorf("runner script not found: %w", err)
	}
	args := []string{
		"-NoProfile", "-ExecutionPolicy", "Bypass",
		"-File", scriptPath,
	}
	args = append(args, extraArgs...)
	cmd := exec.Command("powershell.exe", args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	combined := stdout.String() + stderr.String()
	if err != nil {
		msg := strings.TrimSpace(stderr.String())
		if msg == "" {
			msg = err.Error()
		}
		return combined, fmt.Errorf("%s", msg)
	}
	return combined, nil
}

func newJobID() string {
	b := make([]byte, 8)
	_, _ = rand.Read(b)
	return fmt.Sprintf("%d-%s", time.Now().UnixNano(), hex.EncodeToString(b))
}
