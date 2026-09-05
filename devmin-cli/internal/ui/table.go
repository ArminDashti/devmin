package ui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/lipgloss/table"
)

func RenderTable(headers []string, rows [][]string) string {
	t := table.New().
		Border(lipgloss.NormalBorder()).
		BorderStyle(lipgloss.NewStyle().Foreground(ColorDim)).
		StyleFunc(func(row, col int) lipgloss.Style {
			if row == table.HeaderRow {
				return HeaderStyle
			}
			return CellStyle
		}).
		Headers(headers...).
		Rows(rows...)
	return t.String()
}

func JoinURLs(urls []string) string {
	filtered := make([]string, 0, len(urls))
	for _, u := range urls {
		u = strings.TrimSpace(u)
		if u != "" {
			filtered = append(filtered, u)
		}
	}
	if len(filtered) == 0 {
		return DimStyle.Render("-")
	}
	return strings.Join(filtered, "\n")
}

func CheckLine(ok bool, label, detail string) string {
	mark := FailStyle.Render("[FAIL]")
	if ok {
		mark = OkStyle.Render("[ OK ]")
	}
	line := fmt.Sprintf("%s  %s", mark, TitleStyle.Render(label))
	if detail != "" {
		line += "  " + DimStyle.Render(detail)
	}
	return line
}
