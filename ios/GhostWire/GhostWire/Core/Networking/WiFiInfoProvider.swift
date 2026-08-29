import Foundation
import NetworkExtension

/// Wraps `NEHotspotNetwork`, the only public, non-jailbreak API iOS offers
/// for the SSID/BSSID of the network currently joined.
///
/// Deliberately NOT provided anywhere in the app: RSSI, channel, band,
/// PHY/IEEE mode, or negotiated link rate. No public iOS API exposes those —
/// not with entitlements, not with Location permission, nothing short of a
/// jailbreak. Apps that claim to show them are estimating or fabricating.
/// GhostWire instead measures a real "link quality" from active probes
/// (see `PingSummary.qualityScore`) and labels it as measured.
enum WiFiInfoProvider {

    static func current() async -> WiFiInfo {
        await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { network in
                guard let network else {
                    continuation.resume(returning: WiFiInfo())
                    return
                }
                let info = WiFiInfo(
                    ssid: network.ssid,
                    bssid: network.bssid,
                    isSecure: network.isSecure
                )
                continuation.resume(returning: info)
            }
        }
    }
}
