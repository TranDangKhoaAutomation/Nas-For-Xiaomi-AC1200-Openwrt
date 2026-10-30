package nasnet

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// This opt-in test uses only a disposable share on router RAM, never real NAS data.
func TestDisposableSMBShare(t *testing.T) {
	location := os.Getenv("KHOANAS_TEST_CREDENTIAL_FILE")
	if location == "" {
		t.Skip("No disposable SMB fixture configured")
	}
	raw, err := os.ReadFile(location)
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct {
		User     string `json:"user"`
		Password string `json:"password"`
	}
	if err = json.Unmarshal(raw, &fixture); err != nil {
		t.Fatal(err)
	}
	if _, err = Connect("192.168.1.1", fixture.User, fixture.Password, "", false); err != nil {
		t.Fatal("connect:", err)
	}
	defer Disconnect()
	if _, err = Mount("KHOANAS_TEST"); err != nil {
		t.Fatal("mount:", err)
	}
	initial := fmt.Sprintf("native-%d", time.Now().UnixNano())
	renamed := initial + "-renamed"
	defer func() { Remove(renamed + "/roundtrip.txt"); Remove(renamed); Remove(initial) }()
	if err = Mkdir(initial); err != nil {
		t.Fatal(err)
	}
	if err = Rename(initial, renamed); err != nil {
		t.Fatal(err)
	}
	local := t.TempDir()
	source, target := filepath.Join(local, "source.txt"), filepath.Join(local, "target.txt")
	content := append(bytes.Repeat([]byte("Khoa NAS native SMB round-trip\n"), 16384), []byte("end")...)
	if err = os.WriteFile(source, content, 0600); err != nil {
		t.Fatal(err)
	}
	if err = Upload(source, renamed+"/roundtrip.txt"); err != nil {
		t.Fatal(err)
	}
	if err = Upload(source, renamed+"/roundtrip.txt"); err == nil {
		t.Fatal("overwrote existing file")
	}
	if err = Download(renamed+"/roundtrip.txt", target); err != nil {
		t.Fatal(err)
	}
	result, err := os.ReadFile(target)
	if err != nil || string(result) != string(content) {
		t.Fatal("round-trip mismatch")
	}
	if err = Remove(renamed + "/roundtrip.txt"); err != nil {
		t.Fatal(err)
	}
	if err = Remove(renamed); err != nil {
		t.Fatal(err)
	}
}
