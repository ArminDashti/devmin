package nativestate

import (
	"bytes"
	"encoding/json"
	"os"
	"strings"
)

type StateFile struct {
	StartedAt string     `json:"startedAt"`
	Processes []ProcRow  `json:"processes"`
}

type ProcRow struct {
	Name    string `json:"name"`
	Role    string `json:"role"`
	PID     int    `json:"pid"`
	Port    int    `json:"port"`
	URL     string `json:"url"`
	Wait    bool   `json:"wait"`
	LogPath string `json:"logPath"`
}

func ReadState(path string) (*StateFile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return &StateFile{Processes: []ProcRow{}}, nil
		}
		return nil, err
	}
	// Strip UTF-8 BOM if present (PowerShell Set-Content may write one).
	data = bytes.TrimPrefix(data, []byte{0xEF, 0xBB, 0xBF})
	var state StateFile
	if err := json.Unmarshal(data, &state); err != nil {
		return &StateFile{Processes: []ProcRow{}}, nil
	}
	return &state, nil
}

// ReadMergedState loads one or more state files; later files override same name+role rows.
func ReadMergedState(paths ...string) (*StateFile, error) {
	byKey := map[string]ProcRow{}
	var startedAt string
	for _, path := range paths {
		if strings.TrimSpace(path) == "" {
			continue
		}
		state, err := ReadState(path)
		if err != nil {
			return nil, err
		}
		if startedAt == "" && state.StartedAt != "" {
			startedAt = state.StartedAt
		}
		for _, p := range state.Processes {
			key := strings.ToLower(p.Name) + "|" + strings.ToLower(p.Role)
			byKey[key] = p
		}
	}
	out := make([]ProcRow, 0, len(byKey))
	for _, p := range byKey {
		out = append(out, p)
	}
	return &StateFile{StartedAt: startedAt, Processes: out}, nil
}

// PortsForStem returns api and webui host ports for a stem (app name).
func PortsForStem(state *StateFile, stem string) (apiPort, webuiPort int, apiURL, webuiURL string) {
	if state == nil {
		return 0, 0, "", ""
	}
	needle := strings.ToLower(stem)
	for _, p := range state.Processes {
		if !strings.EqualFold(p.Name, needle) && strings.ToLower(p.Name) != needle {
			continue
		}
		role := strings.ToLower(p.Role)
		switch role {
		case "api":
			apiPort = p.Port
			apiURL = p.URL
		case "webui", "ui", "web":
			webuiPort = p.Port
			webuiURL = p.URL
		}
	}
	return apiPort, webuiPort, apiURL, webuiURL
}

func OnLocal(state *StateFile, stem string) bool {
	if state == nil {
		return false
	}
	needle := strings.ToLower(stem)
	for _, p := range state.Processes {
		if strings.EqualFold(p.Name, needle) && strings.ToLower(p.Role) != "dashboard" {
			return true
		}
	}
	return false
}
