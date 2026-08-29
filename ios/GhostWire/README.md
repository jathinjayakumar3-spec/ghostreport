# GhostWire

A native iOS network diagnostics app built for a network/security engineer's
daily toolkit: connection overview, Wi-Fi/interface detail, a real speed
test against Cloudflare (latency to `1.1.1.1`), ICMP traceroute, `dig`-style
DNS lookups, ping, a TCP port scanner, WHOIS, and a diagnostics log — all in
one glassy, dark SwiftUI app. No third-party SDKs, no API keys.

This was written in an environment with no macOS/Xcode available, so it has
**not** been compiled. Everything below is written to be correct Swift on
first build, but budget time for the inevitable first-build fixes any
hand-written Xcode project needs.

## Requirements

- Xcode 15+ (iOS 17 SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- A physical iPhone is strongly recommended. The Simulator has no real Wi-Fi
  interface, no real ICMP path, and `NEHotspotNetwork` returns nothing —
  ping/traceroute/speed test/DNS still work over the Mac's network path in
  Simulator, but the Wi-Fi card will always be empty.

## Build & run

```bash
cd ios/GhostWire
xcodegen generate       # produces GhostWire.xcodeproj from project.yml
open GhostWire.xcodeproj
```

Then in Xcode:

1. Select the `GhostWire` target → **Signing & Capabilities** → set your
   Team. `project.yml` already requests the **Access WiFi Information**
   entitlement (`com.apple.developer.networking.wifi-info`), which is free
   for any developer account — Xcode will provision it automatically.
2. Build & run on a device (⌘R).
3. On first launch, iOS will prompt for **Local Network** access (needed for
   ping/traceroute/port-scan to LAN devices and your gateway) and, on some
   iOS versions, **Location — When In Use** (needed for `NEHotspotNetwork`
   to hand back the joined SSID/BSSID on those OS versions). Both prompts
   are expected; GhostWire doesn't otherwise touch location.

The `.xcodeproj` itself isn't committed — `xcodegen generate` produces it
from `project.yml` on your machine, so it never goes stale in git.

## What's real vs. what iOS won't allow

Every number in this app is a genuine measurement — nothing is
estimated-and-labeled-as-fact. A few things worth knowing:

- **Wi-Fi RSSI, channel, band, PHY/IEEE mode, negotiated link rate — not
  available.** No public iOS API has exposed these to third-party apps in
  years, with or without entitlements, App Store or not. Any app claiming
  to show them is guessing. GhostWire shows SSID/BSSID/security (via
  `NEHotspotNetwork`, the one thing iOS *does* expose) and instead computes
  a **measured link quality** score from live latency/jitter/loss probes to
  your gateway — real data, honestly labeled as a substitute.
- **Ping & traceroute use unprivileged ICMP** (`SOCK_DGRAM` +
  `IPPROTO_ICMP`), the same "ping socket" technique as Apple's own
  `SimplePing` sample. No jailbreak, no root, no raw sockets.
- **DNS lookup** uses `DNSServiceQueryRecord` (the public `dnssd`/Bonjour C
  API) so it can query any record type (A/AAAA/CNAME/MX/TXT/NS/SOA/SRV/PTR/
  CAA) against your configured resolver — `getaddrinfo` alone only ever
  gives you A/AAAA. If Xcode can't resolve `import dnssd`, add
  `dnssd.tbd`/`dnssd.framework` under the target's **Link Binary With
  Libraries** build phase — some SDK configurations need it linked
  explicitly even though the header auto-imports.
- **Speed test** hits `speed.cloudflare.com`'s public, key-free `__down`/
  `__up` endpoints — the same infrastructure the official 1.1.1.1 speed
  test page uses — with time-bounded transfers so results are comparable
  regardless of link speed. Latency/jitter/loss are separately measured
  with real ICMP echoes straight to `1.1.1.1`.
- **Port scanner** is a TCP-connect scan via `Network.framework` — no raw
  SYN scanning (iOS doesn't allow it). Only scan hosts/networks you're
  authorized to test.
- **Live throughput** on the Dashboard reads the interface's rx/tx byte
  counters via `getifaddrs`/`if_data` (what `netstat -i` reads) and diffs
  two samples — a real measurement, not a smoothed estimate. If iOS
  doesn't hand back interface stats in a given context it shows "—" rather
  than fabricating a number.

## Project layout

```
GhostWire/
  App/            Entry point, tab shell, design tokens (Theme, glass modifiers)
  Core/
    Networking/   ICMP ping/traceroute, DNS (dnssd), port scanner, speed
                  test, Wi-Fi/interface info, WHOIS, public IP
    Models/       Shared value types
    Persistence/  Lightweight JSON-backed history/log store
    Utilities/    Formatters
  Components/     Reusable glass UI (cards, gauges, sparklines, tiles)
  Features/       One folder per screen (Dashboard, WLAN, SpeedTest,
                  Traceroute, DNS, Ping, PortScan, WHOIS, Logs, Settings)
  Resources/      Assets.xcassets (add a 1024×1024 app icon here)
```

## Design

Dark, glassy, cyan/violet signal palette with `.ultraThinMaterial` cards,
soft blurred gradient orbs drifting behind content, and a floating pill tab
bar — the aesthetic referenced from the Figma "smart home" community file,
adapted into a network/security-tool palette (electric cyan primary,
violet secondary, amber/rose/green status colors).
