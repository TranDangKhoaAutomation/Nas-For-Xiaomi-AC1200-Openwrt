package nasnet

import (
	"context"
	"errors"
	"net/netip"
	"sort"
	"strings"
	"time"

	"tailscale.com/ipn/ipnstate"
)

type tailnetDevice struct {
	Name   string `json:"name"`
	IP     string `json:"ip"`
	OS     string `json:"os"`
	Online bool   `json:"online"`
}

func peerDevices(status *ipnstate.Status) []tailnetDevice {
	devices := []tailnetDevice{}
	if status == nil {
		return devices
	}
	seen := map[string]bool{}
	tailnet := netip.MustParsePrefix("100.64.0.0/10")
	for _, peer := range status.Peer {
		if peer == nil {
			continue
		}
		for _, ip := range peer.TailscaleIPs {
			if !ip.Is4() || !tailnet.Contains(ip) || seen[ip.String()] {
				continue
			}
			name := strings.TrimSpace(peer.HostName)
			if name == "" {
				name = strings.Split(peer.DNSName, ".")[0]
			}
			if name == "" {
				name = ip.String()
			}
			devices = append(devices, tailnetDevice{name, ip.String(), peer.OS, peer.Online})
			seen[ip.String()] = true
			break
		}
	}
	sort.Slice(devices, func(i, j int) bool {
		if devices[i].Online != devices[j].Online {
			return devices[i].Online
		}
		if devices[i].Name != devices[j].Name {
			return devices[i].Name < devices[j].Name
		}
		return devices[i].IP < devices[j].IP
	})
	if len(devices) > 128 {
		devices = devices[:128]
	}
	return devices
}

// Discover lists only peers visible to this app's authenticated Tailscale node.
// It does not scan an address range, send credentials or use the OS VPN/LAN.
func Discover() (string, error) {
	nodeMu.Lock()
	s := node
	nodeMu.Unlock()
	if s == nil {
		return "", errors.New("Hãy đăng nhập Tailscale trong ứng dụng trước")
	}
	lc, err := s.LocalClient()
	if err != nil {
		return "", err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	status, err := lc.Status(ctx)
	if err != nil {
		return "", err
	}
	if status.BackendState != "Running" {
		return "", errors.New("Hãy đăng nhập Tailscale trong ứng dụng trước")
	}
	return encode(map[string]any{"devices": peerDevices(status)}), nil
}
