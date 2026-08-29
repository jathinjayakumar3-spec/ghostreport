import Foundation
import SystemConfiguration

/// Reads the device's active gateway (router) IP and DNS resolver list from
/// the `SCDynamicStore` global state — the same public SystemConfiguration
/// keys macOS/iOS themselves populate from DHCP/manual config. No entitlement
/// required.
enum SystemNetworkConfig {

    static func gatewayInfo() -> GatewayInfo {
        var info = GatewayInfo()
        guard let store = SCDynamicStoreCreate(nil, "GhostWire" as CFString, nil, nil) else { return info }

        if let raw = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
           let router = raw["Router"] as? String {
            info.routerIPv4 = router
        }

        if let dns = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any],
           let servers = dns["ServerAddresses"] as? [String] {
            info.dnsServers = servers
        }

        return info
    }
}
