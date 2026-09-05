package api

import "time"

type EndpointLine struct {
	Channel string `json:"channel"`
	URL     string `json:"url"`
	Status  string `json:"status"`
}

type ChannelState struct {
	Enabled   bool   `json:"enabled"`
	Available bool   `json:"available"`
	Reason    string `json:"reason,omitempty"`
}

type Application struct {
	ID           string                  `json:"id"`
	Name         string                  `json:"name"`
	Role         string                  `json:"role"`
	Stem         string                  `json:"stem"`
	InternalPort int                     `json:"internalPort"`
	Endpoints    []EndpointLine          `json:"endpoints"`
	Channels     map[string]ChannelState `json:"channels"`
}

type Stack struct {
	Stem         string        `json:"stem"`
	Type         string        `json:"type"`
	RootDir      string        `json:"rootDir"`
	SkipReason   string        `json:"skipReason,omitempty"`
	Applications []Application `json:"applications"`
}

type ActionJob struct {
	ID        string    `json:"id"`
	Stem      string    `json:"stem"`
	AppID     string    `json:"appId,omitempty"`
	Channel   string    `json:"channel"`
	Action    string    `json:"action"`
	Status    string    `json:"status"`
	Output    string    `json:"output"`
	Error     string    `json:"error,omitempty"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

type LoginResponse struct {
	Token    string `json:"token"`
	Username string `json:"username"`
}

type ActionRequest struct {
	Stem    string `json:"stem,omitempty"`
	AppID   string `json:"appId,omitempty"`
	Channel string `json:"channel"`
	Action  string `json:"action"`
}

type HealthResponse struct {
	Status string `json:"status"`
}
