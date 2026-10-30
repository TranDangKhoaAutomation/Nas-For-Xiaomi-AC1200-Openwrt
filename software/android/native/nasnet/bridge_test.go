package nasnet

import (
	"context"
	"strings"
	"testing"
)

func TestPathsStayWithinShare(t *testing.T) {
	for _, p := range []string{"../file", "a/../file", "/root", "\\root", "a\x00b"} {
		if _, err := cleanPath(p, true); err == nil {
			t.Fatalf("accepted unsafe path %q", p)
		}
	}
	if p, err := cleanPath("folder/file.txt", false); err != nil || p != "folder\\file.txt" {
		t.Fatal(p, err)
	}
	if _, err := cleanPath("", false); err == nil {
		t.Fatal("allowed modifying share root")
	}
}
func TestServerAddressBoundaries(t *testing.T) {
	for _, host := range []string{"8.8.8.8", "example.com", "127.0.0.1", "192.168.1.1:445"} {
		if _, err := validateHost(host); err == nil {
			t.Fatal("accepted unsupported destination", host)
		}
	}
	for _, host := range []string{"192.168.1.1", "100.114.53.95", "10.0.2.2"} {
		if _, err := validateHost(host); err != nil {
			t.Fatal(err)
		}
	}
}

func TestRemoteModeDoesNotFallBackToLAN(t *testing.T) {
	connection, err := dial(context.Background(), "192.168.1.1", "445", true)
	if connection != nil {
		connection.Close()
		t.Fatal("remote mode connected without an embedded node")
	}
	if err == nil || !strings.Contains(err.Error(), "Tailscale") {
		t.Fatal("expected embedded transport requirement")
	}
}
