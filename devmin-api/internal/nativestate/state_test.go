package nativestate

import (
	"os"
	"path/filepath"
	"testing"
)

func TestReadMergedStateLaterOverrides(t *testing.T) {
	dir := t.TempDir()
	first := filepath.Join(dir, "first.json")
	second := filepath.Join(dir, "second.json")
	if err := os.WriteFile(first, []byte(`{"processes":[{"name":"exa","role":"webui","port":5197,"url":"http://127.0.0.1:5197/"}]}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(second, []byte(`{"processes":[{"name":"exa","role":"webui","port":5188,"url":"http://127.0.0.1:5188/"}]}`), 0o644); err != nil {
		t.Fatal(err)
	}

	state, err := ReadMergedState(first, second)
	if err != nil {
		t.Fatal(err)
	}
	_, webuiPort, _, webuiURL := PortsForStem(state, "exa")
	if webuiPort != 5188 || webuiURL != "http://127.0.0.1:5188/" {
		t.Fatalf("got port=%d url=%q", webuiPort, webuiURL)
	}
}
