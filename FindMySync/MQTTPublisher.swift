//
//  MQTTPublisher.swift
//  FindMySync
//
//  Publishes Find My locations to Home Assistant over MQTT using MQTT
//  discovery, replacing the deprecated device_tracker.see action
//  (removed in Home Assistant Core 2027.5).
//
//  Two retained topics per device:
//
//    <discovery_prefix>/device_tracker/findmy_<id>/config
//    <topic_prefix>/findmy_<id>/attributes
//
//  The discovery message deliberately omits `state_topic`. When a device
//  tracker has no state topic but its json_attributes carry latitude,
//  longitude and gps_accuracy, Home Assistant resolves the zone itself and
//  sets home / not_home / <zone name>. That reproduces what device_tracker.see
//  did. Publishing a state topic here would override that with a literal
//  string and break zone detection.
//
//  Both topics are retained, so the last known position is republished to
//  Home Assistant the moment it reconnects — the state survives a restart,
//  which template device trackers do not.
//

import CocoaMQTT
import Foundation

final class MQTTPublisher {

    static let shared = MQTTPublisher()

    /// Assigned by Synchronizer so broker activity appears in the Status pane.
    var log: (_ message: String) -> Void = { debugPrint($0) }

    private let queue = DispatchQueue(label: "com.findmysync.mqtt")
    private var client: CocoaMQTT?
    private var connectionSignature = ""

    /// entity ID -> the name last announced for it. Discovery is republished
    /// only when a device is new or has been renamed in Find My.
    private var announced = [String: String]()

    private init() {}

    // MARK: - Entity naming

    /// Entity IDs must stay stable across the migration. `binary_sensor.findmy_feed_stale`
    /// matches on `^device_tracker\.findmy_`, and these are the same IDs
    /// device_tracker.see produced from known_devices.yaml.
    static func entityId(for identifier: String) -> String {
        "findmy_" + identifier.replacingOccurrences(of: "-", with: "")
    }

    // MARK: - Settings

    private struct Settings {
        var host = ""
        var port: UInt16 = 1883
        var username = ""
        var password = ""
        var discoveryPrefix = "homeassistant"
        var topicPrefix = "findmysync"
        var publishAvailability = false

        /// Changing any of these forces a reconnect.
        var signature: String {
            [host, String(port), username, password, discoveryPrefix, topicPrefix]
                .joined(separator: "|")
        }

        var statusTopic: String {
            "\(topicPrefix)/status"
        }

        func attributesTopic(_ entityId: String) -> String {
            "\(topicPrefix)/\(entityId)/attributes"
        }

        func discoveryTopic(_ entityId: String) -> String {
            "\(discoveryPrefix)/device_tracker/\(entityId)/config"
        }
    }

    private func loadSettings() -> Settings {
        let defaults = UserDefaults.standard
        var settings = Settings()

        settings.host = (defaults.string(forKey: "mqtt_host") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        settings.port = UInt16(defaults.string(forKey: "mqtt_port") ?? "1883") ?? 1883
        settings.username = defaults.string(forKey: "mqtt_username") ?? ""
        settings.password = defaults.string(forKey: "mqtt_password") ?? ""
        settings.discoveryPrefix = MQTTPublisher.cleanPrefix(
            defaults.string(forKey: "mqtt_discovery_prefix"), fallback: "homeassistant")
        settings.topicPrefix = MQTTPublisher.cleanPrefix(
            defaults.string(forKey: "mqtt_topic_prefix"), fallback: "findmysync")
        settings.publishAvailability = defaults.bool(forKey: "mqtt_availability")

        return settings
    }

    private static func cleanPrefix(_ value: String?, fallback: String) -> String {
        let trimmed =
            (value ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? fallback : trimmed
    }

    // MARK: - Public API

    /// Called once at the start of every sync pass, before any publish.
    /// Everything runs on one serial queue, so this always completes first.
    func begin() {
        queue.async {
            let settings = self.loadSettings()

            guard !settings.host.isEmpty else {
                self.log("MQTT: no broker host configured — nothing will be published")
                return
            }

            if self.ensureConnected(settings) {
                self.log("MQTT: connected to \(settings.host):\(settings.port)")
                if settings.publishAvailability {
                    self.send(topic: settings.statusTopic, payload: "online")
                }
            } else {
                self.log(
                    "MQTT: \(settings.host):\(settings.port) not reachable yet — "
                        + "messages are queued and flush on connect")
            }
        }
    }

    func publish(
        identifier: String, name: String, latitude: NSNumber, longitude: NSNumber,
        accuracy: NSNumber, battery: NSNumber, address: String
    ) {
        queue.async {
            let settings = self.loadSettings()
            guard !settings.host.isEmpty else { return }

            _ = self.ensureConnected(settings)

            let entityId = MQTTPublisher.entityId(for: identifier)
            let displayName = name.isEmpty ? entityId : name

            if self.announced[entityId] != displayName {
                self.sendDiscovery(entityId: entityId, name: displayName, settings: settings)
                self.announced[entityId] = displayName
            }

            var attributes: [String: Any] = [
                "latitude": latitude.doubleValue,
                "longitude": longitude.doubleValue,
                "gps_accuracy": accuracy.doubleValue,
            ]

            if !address.isEmpty {
                attributes["address"] = address
            }

            // Find My reports battery as a 0–1 fraction, and -1 when unknown.
            if battery.doubleValue > 0 {
                attributes["battery_level"] = Int((battery.doubleValue * 100).rounded())
            }

            guard let payload = MQTTPublisher.json(attributes) else {
                self.log("[\(identifier)] MQTT: could not encode attributes")
                return
            }

            self.send(topic: settings.attributesTopic(entityId), payload: payload)
            self.log("[\(identifier)] MQTT: published to \(settings.attributesTopic(entityId))")
        }
    }

    // MARK: - Publishing

    private func sendDiscovery(entityId: String, name: String, settings: Settings) {
        // `default_entity_id` is what pins the entity ID. `object_id` is ignored by
        // Home Assistant 2026.8 — verified against the live instance, where a discovery
        // payload carrying object_id "findmy_testb" still landed as
        // device_tracker.mqtt_test_b, derived from `name`. `default_entity_id` takes the
        // full entity ID including the domain.
        var config: [String: Any] = [
            "name": name,
            "unique_id": entityId,
            "default_entity_id": "device_tracker.\(entityId)",
            "json_attributes_topic": settings.attributesTopic(entityId),
            "source_type": "gps",
        ]

        if settings.publishAvailability {
            config["availability_topic"] = settings.statusTopic
            config["payload_available"] = "online"
            config["payload_not_available"] = "offline"
        }

        guard let payload = MQTTPublisher.json(config) else {
            log("[\(entityId)] MQTT: could not encode discovery config")
            return
        }

        send(topic: settings.discoveryTopic(entityId), payload: payload)
        log("[\(entityId)] MQTT: discovery published")
    }

    private func send(topic: String, payload: String) {
        guard let client = client else { return }
        _ = client.publish(topic, withString: payload, qos: .qos1, retained: true)
    }

    private static func json(_ object: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [])
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Connection

    private func ensureConnected(_ settings: Settings) -> Bool {
        if let existing = client, connectionSignature == settings.signature,
            existing.connState == .connected
        {
            return true
        }

        // Settings changed: tear the old connection down and re-announce everything.
        if connectionSignature != settings.signature, let existing = client {
            existing.disconnect()
            client = nil
            announced.removeAll()
        }

        if client == nil {
            let suffix =
                ProcessInfo.processInfo.hostName
                .replacingOccurrences(of: ".", with: "-")
                .replacingOccurrences(of: " ", with: "-")

            let mqtt = CocoaMQTT(
                clientID: "findmysync-" + suffix, host: settings.host, port: settings.port)

            if !settings.username.isEmpty { mqtt.username = settings.username }
            if !settings.password.isEmpty { mqtt.password = settings.password }
            mqtt.keepAlive = 60
            mqtt.cleanSession = true
            mqtt.autoReconnect = true

            if settings.publishAvailability {
                let will = CocoaMQTTMessage(topic: settings.statusTopic, string: "offline")
                will.qos = .qos1
                will.retained = true
                mqtt.willMessage = will
            }

            client = mqtt
            connectionSignature = settings.signature
            _ = mqtt.connect()
        } else if client?.connState != .connected {
            _ = client?.connect()
        }

        // Bounded wait. This runs on our own serial queue, never the main thread.
        // Publishing before the handshake completes is safe anyway — CocoaMQTT
        // queues messages internally — but waiting makes the Status log honest.
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if client?.connState == .connected {
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }

        return client?.connState == .connected
    }
}
