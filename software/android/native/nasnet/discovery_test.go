package nasnet

import (
	"fmt"
	"net/netip"
	"strings"
	"testing"

	"tailscale.com/ipn/ipnstate"
	"tailscale.com/types/key"
)

func TestDiscoveryRequiresEmbeddedLogin(t *testing.T) {
	if result, err := Discover(); err == nil || result != "" {
		t.Fatal("discovery should require the app's authenticated node")
	}
}

func TestDiscoveryUsesOnlyVisibleTailnetIPv4(t *testing.T) {
	status := &ipnstate.Status{Peer: map[key.NodePublic]*ipnstate.PeerStatus{}}
	for _, p := range []*ipnstate.PeerStatus{
		{HostName: "router", Online: true, TailscaleIPs: []netip.Addr{netip.MustParseAddr("100.64.1.2")}},
		{DNSName: "offline.example.ts.net.", TailscaleIPs: []netip.Addr{netip.MustParseAddr("100.64.1.3")}},
		{HostName: "public", TailscaleIPs: []netip.Addr{netip.MustParseAddr("8.8.8.8")}},
		{HostName: "lan", TailscaleIPs: []netip.Addr{netip.MustParseAddr("192.168.1.1")}},
		{HostName: "v6", TailscaleIPs: []netip.Addr{netip.MustParseAddr("fd7a:115c:a1e0::1")}},
	} {
		status.Peer[key.NewNode().Public()] = p
	}
	got := peerDevices(status)
	if len(got) != 2 || got[0].Name != "router" || got[1].Name != "offline" {
		t.Fatalf("unexpected candidates: %v", got)
	}
	result := encode(got)
	for _, private := range []string{"UserID", "PublicKey", "AuthURL", "example.ts.net"} {
		if strings.Contains(result, private) {
			t.Fatal("unnecessary tailnet metadata exported")
		}
	}
}

func TestDiscoveryHasStableBoundedResults(t *testing.T) {
	status := &ipnstate.Status{Peer: map[key.NodePublic]*ipnstate.PeerStatus{}}
	for i := 1; i <= 140; i++ {
		status.Peer[key.NewNode().Public()] = &ipnstate.PeerStatus{HostName: fmt.Sprintf("node-%03d", i), Online: true,
			TailscaleIPs: []netip.Addr{netip.MustParseAddr(fmt.Sprintf("100.64.0.%d", i))}}
	}
	got := peerDevices(status)
	if len(got) != 128 || got[0].Name != "node-001" || got[127].Name != "node-128" {
		t.Fatal("unbounded or unordered discovery")
	}
}
