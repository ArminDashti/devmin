package runner

import (
	"context"
	"fmt"

	"github.com/ArminDashti/devmin-api/internal/discover"
	"github.com/ArminDashti/devmin-api/internal/runmode"
)

// ModeRunner starts/stops an app pair for one deployment channel.
type ModeRunner interface {
	Start(ctx context.Context, pair discover.Pair) error
	Stop(ctx context.Context, pair discover.Pair) error
}

// Router dispatches start/stop by channel and tracks in-flight actions.
type Router struct {
	flight       *Flight
	hotReload    ModeRunner
	local        ModeRunner
	localDocker  ModeRunner
	serverDocker ModeRunner
	server       ModeRunner
}

func NewRouter(hotReload, local, localDocker, serverDocker, server ModeRunner, flight *Flight) *Router {
	if flight == nil {
		flight = NewFlight()
	}
	return &Router{
		flight:       flight,
		hotReload:    hotReload,
		local:        local,
		localDocker:  localDocker,
		serverDocker: serverDocker,
		server:       server,
	}
}

func (r *Router) IsRunning(stem string) bool {
	return r.flight.IsRunning(stem)
}

func (r *Router) Start(ctx context.Context, mode runmode.Mode, pair discover.Pair) error {
	return r.withFlight(pair.Stem, func() error {
		mr, err := r.forMode(mode)
		if err != nil {
			return err
		}
		return mr.Start(ctx, pair)
	})
}

func (r *Router) Stop(ctx context.Context, mode runmode.Mode, pair discover.Pair) error {
	return r.withFlight(pair.Stem, func() error {
		mr, err := r.forMode(mode)
		if err != nil {
			return err
		}
		return mr.Stop(ctx, pair)
	})
}

func (r *Router) withFlight(stem string, fn func() error) error {
	if err := r.flight.acquire(stem); err != nil {
		return err
	}
	defer r.flight.release(stem)
	return fn()
}

func (r *Router) forMode(mode runmode.Mode) (ModeRunner, error) {
	switch mode {
	case runmode.HotReload:
		return r.hotReload, nil
	case runmode.Local:
		return r.local, nil
	case runmode.LocalDocker:
		return r.localDocker, nil
	case runmode.ServerDocker:
		return r.serverDocker, nil
	case runmode.Server:
		return r.server, nil
	default:
		return nil, fmt.Errorf("unhandled channel %q", mode)
	}
}
