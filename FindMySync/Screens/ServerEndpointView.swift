//
//  ServerEndpointView.swift
//  FindMySync
//
//  Created by ZZZ on 11/01/23.
//

import SwiftUI

struct ServerEndpointView: View {

	@State private var host: String = UserDefaults.standard.string(forKey: "mqtt_host") ?? ""
	@State private var port: String = UserDefaults.standard.string(forKey: "mqtt_port") ?? "1883"
	@State private var username: String = UserDefaults.standard.string(forKey: "mqtt_username")
		?? ""
	@State private var password: String = UserDefaults.standard.string(forKey: "mqtt_password")
		?? ""
	@State private var discoveryPrefix: String = UserDefaults.standard.string(
		forKey: "mqtt_discovery_prefix") ?? "homeassistant"
	@State private var topicPrefix: String = UserDefaults.standard.string(
		forKey: "mqtt_topic_prefix") ?? "findmysync"
	@State private var availability: Bool = UserDefaults.standard.bool(
		forKey: "mqtt_availability")

	var body: some View {
		ScrollView {
			VStack {
				TextFieldView(
					title: "Broker host",
					value: $host,
					subtitle: "Address of Mosquitto, e.g. 192.168.100.30",
					onChange: { save("mqtt_host", host) }
				)
				TextFieldView(
					title: "Port",
					value: $port,
					subtitle: "1883 for plain MQTT",
					onChange: {
						if UInt16(port) == nil {
							port = "1883"
						}
						save("mqtt_port", port)
					}
				)
				TextFieldView(
					title: "Username",
					value: $username,
					subtitle: "Home Assistant user the broker authenticates against",
					onChange: { save("mqtt_username", username) }
				)
				TextFieldView(
					title: "Password",
					value: $password,
					subtitle: "Stored in app preferences, shown in the clear",
					onChange: { save("mqtt_password", password) }
				)
				TextFieldView(
					title: "Discovery prefix",
					value: $discoveryPrefix,
					subtitle: "Leave as homeassistant unless you have changed it",
					onChange: { save("mqtt_discovery_prefix", discoveryPrefix) }
				)
				TextFieldView(
					title: "Topic prefix",
					value: $topicPrefix,
					subtitle: "Where attribute topics are published",
					onChange: { save("mqtt_topic_prefix", topicPrefix) }
				)
				CheckboxView(
					title: "Publish availability",
					value: $availability,
					subtitle:
						"Mark trackers unavailable when this Mac stops publishing",
					onChange: {
						availability.toggle()
						UserDefaults.standard.set(
							availability, forKey: "mqtt_availability")

						Synchronizer.shared.fetchData()
					}
				)
			}
			.padding()
		}
	}

	private func save(_ key: String, _ value: String) {
		UserDefaults.standard.set(value, forKey: key)

		Synchronizer.shared.fetchData()
	}
}
