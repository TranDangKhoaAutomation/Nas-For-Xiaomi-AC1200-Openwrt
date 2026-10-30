package nasnet

import (
	"encoding/json"
	"net"
	"runtime"
	"sync"

	"tailscale.com/net/netmon"
)

type interfaceInfo struct {
	Name      string   `json:"name"`
	Index     int      `json:"index"`
	MTU       int      `json:"mtu"`
	Up        bool     `json:"up"`
	Loopback  bool     `json:"loopback"`
	Addresses []string `json:"addresses"`
}

var interfaceMu sync.RWMutex
var androidInterfaces []netmon.Interface

func init() {
	if runtime.GOOS == "android" {
		// Android app sandboxes may not use Go's netlink enumeration. The host
		// activity supplies java.net.NetworkInterface snapshots instead.
		netmon.RegisterInterfaceGetter(func() ([]netmon.Interface, error) {
			interfaceMu.RLock()
			defer interfaceMu.RUnlock()
			return append([]netmon.Interface(nil), androidInterfaces...), nil
		})
	}
}

func UpdateInterfaces(snapshot string) error {
	var input []interfaceInfo
	if err := json.Unmarshal([]byte(snapshot), &input); err != nil {
		return err
	}
	output := make([]netmon.Interface, 0, len(input))
	for _, item := range input {
		flags := net.FlagMulticast
		if item.Up {
			flags |= net.FlagUp | net.FlagRunning
		}
		if item.Loopback {
			flags |= net.FlagLoopback
		}
		base := &net.Interface{Name: item.Name, Index: item.Index, MTU: item.MTU, Flags: flags}
		addrs := []net.Addr{}
		for _, value := range item.Addresses {
			ip, prefix, err := net.ParseCIDR(value)
			if err == nil {
				prefix.IP = ip
				addrs = append(addrs, prefix)
			}
		}
		output = append(output, netmon.Interface{Interface: base, AltAddrs: addrs})
	}
	interfaceMu.Lock()
	androidInterfaces = output
	interfaceMu.Unlock()
	nodeMu.Lock()
	s := node
	nodeMu.Unlock()
	if s != nil {
		s.Sys().NetMon.Get().InjectEvent()
	}
	return nil
}
