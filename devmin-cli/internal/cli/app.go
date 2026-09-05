package cli

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/ArminDashti/devmin-cli/internal/api"
	"github.com/ArminDashti/devmin-cli/internal/resolve"
	"github.com/ArminDashti/devmin-cli/internal/ui"
)

func newAppCmd() *cobra.Command {
	app := &cobra.Command{
		Use:   "app",
		Short: "List, doctor, and deploy applications",
	}

	app.AddCommand(newListParent("online", "List apps with any channel UP", filterOnline))
	app.AddCommand(newListParent("offline", "List apps with no channel UP", filterOffline))
	app.AddCommand(newListParent("online-offline", "List all apps with status matrix", filterAll))

	app.AddCommand(&cobra.Command{
		Use:   "doctor <appname>",
		Short: "Diagnose one app / stack by name",
		Args:  cobra.ExactArgs(1),
		RunE:  runAppDoctor,
	})

	for _, verb := range []string{"install", "remove", "update", "reinstall"} {
		verb := verb
		cmd := &cobra.Command{
			Use:   verb + " <channel> <appname>",
			Short: fmt.Sprintf("%s app on local|local-docker|server-docker", verb),
			Args:  cobra.ExactArgs(2),
			RunE: func(cmd *cobra.Command, args []string) error {
				return runAppAction(verb, args[0], args[1])
			},
		}
		app.AddCommand(cmd)
	}

	return app
}

type listFilter int

const (
	filterOnline listFilter = iota
	filterOffline
	filterAll
)

func newListParent(name, short string, f listFilter) *cobra.Command {
	parent := &cobra.Command{
		Use:   name,
		Short: short,
	}
	parent.AddCommand(&cobra.Command{
		Use:   "list",
		Short: short,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runAppList(f)
		},
	})
	return parent
}

func runAppList(f listFilter) error {
	ctx, cancel := withTimeout()
	defer cancel()
	if err := ensureAPI(ctx); err != nil {
		return err
	}
	stacks, err := apiClient.ListStacks(ctx)
	if err != nil {
		return err
	}
	apps := resolve.FlattenApps(stacks)
	filtered := make([]api.Application, 0, len(apps))
	for _, a := range apps {
		online := resolve.AppIsOnline(a)
		switch f {
		case filterOnline:
			if online {
				filtered = append(filtered, a)
			}
		case filterOffline:
			if !online {
				filtered = append(filtered, a)
			}
		default:
			filtered = append(filtered, a)
		}
	}

	if jsonOutput {
		type row struct {
			ID           string            `json:"id"`
			Name         string            `json:"name"`
			Stem         string            `json:"stem"`
			Online       bool              `json:"online"`
			Local        string            `json:"local"`
			LocalDocker  string            `json:"localDocker"`
			ServerDocker string            `json:"serverDocker"`
			URLs         map[string]string `json:"urls"`
		}
		out := make([]row, 0, len(filtered))
		for _, a := range filtered {
			r := row{
				ID: a.ID, Name: a.Name, Stem: a.Stem,
				Online: resolve.AppIsOnline(a),
				URLs:   map[string]string{},
			}
			r.Local, r.URLs["local"] = channelJSON(a, resolve.ChannelLocal)
			r.LocalDocker, r.URLs["localDocker"] = channelJSON(a, resolve.ChannelLocalDocker)
			r.ServerDocker, r.URLs["serverDocker"] = channelJSON(a, resolve.ChannelServerDocker)
			out = append(out, r)
		}
		return printJSON(out)
	}

	headers := []string{"APP", "STEM", "LOCAL", "LOCAL DOCKER", "SERVER DOCKER", "URLS"}
	rows := make([][]string, 0, len(filtered))
	for _, a := range filtered {
		label := a.Name
		if a.Role != "" {
			label = fmt.Sprintf("%s (%s)", a.Name, a.Role)
		}
		urls := []string{}
		localCell, u := channelCell(a, resolve.ChannelLocal)
		if u != "" {
			urls = append(urls, u)
		}
		dockerCell, u := channelCell(a, resolve.ChannelLocalDocker)
		if u != "" {
			urls = append(urls, u)
		}
		serverCell, u := channelCell(a, resolve.ChannelServerDocker)
		if u != "" {
			urls = append(urls, u)
		}
		rows = append(rows, []string{
			label,
			a.Stem,
			localCell,
			dockerCell,
			serverCell,
			ui.JoinURLs(urls),
		})
	}

	title := "online-offline"
	switch f {
	case filterOnline:
		title = "online"
	case filterOffline:
		title = "offline"
	}
	fmt.Println(ui.TitleStyle.Render("◆ app " + title + " list"))
	fmt.Println(ui.DimStyle.Render(fmt.Sprintf("%d apps", len(filtered))))
	fmt.Println()
	if len(rows) == 0 {
		ui.Warnf("no matching apps")
		return nil
	}
	fmt.Println(ui.RenderTable(headers, rows))
	return nil
}

func channelCell(a api.Application, channel string) (cell, url string) {
	url, up, available, reason := resolve.EndpointStatus(a, channel)
	return ui.StatusOrNA(available, up, reason), url
}

func channelJSON(a api.Application, channel string) (status, url string) {
	url, up, available, reason := resolve.EndpointStatus(a, channel)
	if !available {
		if reason == "" {
			return "n/a", url
		}
		return reason, url
	}
	if up {
		return "UP", url
	}
	return "Down", url
}

func runAppDoctor(cmd *cobra.Command, args []string) error {
	ctx, cancel := withTimeout()
	defer cancel()
	if err := ensureAPI(ctx); err != nil {
		return err
	}
	stacks, err := apiClient.ListStacks(ctx)
	if err != nil {
		return err
	}
	target, err := resolve.AppName(stacks, args[0])
	if err != nil {
		return err
	}

	apps := []api.Application{}
	if target.App != nil {
		apps = append(apps, *target.App)
	} else if target.Stack != nil {
		apps = append(apps, target.Stack.Applications...)
	}

	if jsonOutput {
		return printJSON(map[string]any{
			"stem":  target.Stem,
			"appId": target.AppID,
			"apps":  apps,
			"stack": target.Stack,
		})
	}

	fmt.Println(ui.TitleStyle.Render("◆ app doctor " + target.Name))
	if target.Stack != nil && target.Stack.SkipReason != "" {
		ui.Warnf("skip: %s", target.Stack.SkipReason)
	}
	fmt.Println(ui.DimStyle.Render(fmt.Sprintf("stem=%s  apps=%d", target.Stem, len(apps))))
	fmt.Println()

	headers := []string{"APP", "CHANNEL", "STATUS", "AVAILABLE", "URL", "REASON"}
	rows := [][]string{}
	for _, a := range apps {
		for _, ch := range []string{resolve.ChannelLocal, resolve.ChannelLocalDocker, resolve.ChannelServerDocker} {
			url, up, available, reason := resolve.EndpointStatus(a, ch)
			status := "Down"
			if !available {
				status = "n/a"
			} else if up {
				status = "UP"
			}
			rows = append(rows, []string{
				a.Name,
				ch,
				status,
				fmt.Sprintf("%v", available),
				url,
				reason,
			})
		}
	}
	fmt.Println(ui.RenderTable(headers, rows))

	online := false
	for _, a := range apps {
		if resolve.AppIsOnline(a) {
			online = true
			break
		}
	}
	fmt.Println()
	if online {
		ui.Okf("%s has at least one UP channel", target.Name)
	} else {
		ui.Warnf("%s is offline on all channels", target.Name)
	}
	return nil
}

func runAppAction(verb, channelRaw, appName string) error {
	ctx, cancel := withTimeout()
	defer cancel()
	if err := ensureAPI(ctx); err != nil {
		return err
	}

	channel, err := resolve.CLIChannel(channelRaw)
	if err != nil {
		return err
	}
	action, err := resolve.CLIAction(verb)
	if err != nil {
		return err
	}

	stacks, err := apiClient.ListStacks(ctx)
	if err != nil {
		return err
	}
	target, err := resolve.AppName(stacks, appName)
	if err != nil {
		return err
	}

	req := api.ActionRequest{
		Stem:    target.Stem,
		AppID:   target.AppID,
		Channel: channel,
		Action:  action,
	}

	ui.Infof("%s %s → %s (%s)", action, channel, target.Name, target.Stem)
	job, err := apiClient.PostAction(ctx, req)
	if err != nil {
		return err
	}

	spinFrames := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
	frame := 0
	done := make(chan struct{})
	go func() {
		t := time.NewTicker(80 * time.Millisecond)
		defer t.Stop()
		for {
			select {
			case <-done:
				return
			case <-t.C:
				fmt.Fprintf(os.Stderr, "\r%s job %s  %s", spinFrames[frame%len(spinFrames)], job.ID, job.Status)
				frame++
			}
		}
	}()

	final, err := apiClient.PollAction(ctx, job.ID, func(j *api.ActionJob) {
		job = j
	})
	close(done)
	fmt.Fprint(os.Stderr, "\r"+strings.Repeat(" ", 60)+"\r")
	if err != nil {
		return err
	}

	if jsonOutput {
		return printJSON(final)
	}

	fmt.Println(ui.TitleStyle.Render(fmt.Sprintf("◆ %s / %s", final.Action, final.Channel)))
	fmt.Println(ui.DimStyle.Render(fmt.Sprintf("job=%s  stem=%s  status=%s", final.ID, final.Stem, final.Status)))
	if strings.TrimSpace(final.Output) != "" {
		fmt.Println()
		fmt.Println(ui.DimStyle.Render("── output ──"))
		fmt.Println(final.Output)
	}
	if strings.TrimSpace(final.Error) != "" {
		fmt.Println()
		ui.Errf("%s", final.Error)
	}
	if final.Status != "succeeded" {
		return fmt.Errorf("action %s", final.Status)
	}
	ui.Okf("%s completed", final.Action)
	return nil
}
