'use strict';
import { cursor } from 'uci';
let cfg = cursor(), found = false;
function words(value) { return type(value) == 'array' ? value : split(value || '', /\s+/); }
cfg.foreach('firewall', 'zone', function(s) {
    if (index(words(s.device), 'tailscale0') >= 0) found = true;
    for (let network in words(s.network))
        if (cfg.get('network', network, 'device') == 'tailscale0' ||
            cfg.get('network', network, 'ifname') == 'tailscale0') found = true;
});
print(found ? '1' : '0');
