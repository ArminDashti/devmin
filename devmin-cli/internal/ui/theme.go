package ui

import (
	"fmt"
	"os"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

var (
	ColorCyan   = lipgloss.Color("51")
	ColorGreen  = lipgloss.Color("46")
	ColorRed    = lipgloss.Color("196")
	ColorYellow = lipgloss.Color("226")
	ColorDim    = lipgloss.Color("240")
	ColorWhite  = lipgloss.Color("255")
	ColorMagenta = lipgloss.Color("201")

	BannerStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorCyan).
			Border(lipgloss.DoubleBorder()).
			BorderForeground(ColorMagenta).
			Padding(0, 2)

	TitleStyle = lipgloss.NewStyle().Bold(true).Foreground(ColorCyan)
	DimStyle   = lipgloss.NewStyle().Foreground(ColorDim)
	OkStyle    = lipgloss.NewStyle().Foreground(ColorGreen).Bold(true)
	FailStyle  = lipgloss.NewStyle().Foreground(ColorRed).Bold(true)
	WarnStyle  = lipgloss.NewStyle().Foreground(ColorYellow)
	HeaderStyle = lipgloss.NewStyle().Bold(true).Foreground(ColorWhite).Background(lipgloss.Color("236")).Padding(0, 1)
	CellStyle   = lipgloss.NewStyle().Padding(0, 1)
)

func Banner(version string) string {
	inner := fmt.Sprintf("◆ DEVMIN CLI  v%s\n  ops · deploy · doctor", version)
	return BannerStyle.Render(inner)
}

func StatusGlyph(up bool) string {
	if up {
		return OkStyle.Render("● UP")
	}
	return FailStyle.Render("○ Down")
}

func StatusOrNA(available bool, up bool, reason string) string {
	if !available {
		if reason == "" {
			reason = "n/a"
		}
		return DimStyle.Render("· " + truncate(reason, 18))
	}
	return StatusGlyph(up)
}

func Errf(format string, args ...any) {
	fmt.Fprintln(os.Stderr, FailStyle.Render("✗ "+fmt.Sprintf(format, args...)))
}

func Okf(format string, args ...any) {
	fmt.Println(OkStyle.Render("✓ " + fmt.Sprintf(format, args...)))
}

func Infof(format string, args ...any) {
	fmt.Println(DimStyle.Render("→ " + fmt.Sprintf(format, args...)))
}

func Warnf(format string, args ...any) {
	fmt.Println(WarnStyle.Render("! " + fmt.Sprintf(format, args...)))
}

func truncate(s string, n int) string {
	s = strings.TrimSpace(s)
	if len(s) <= n {
		return s
	}
	return s[:n-1] + "…"
}
