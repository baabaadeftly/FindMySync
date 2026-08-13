//
//  ExtrasView.swift
//  FindMySync
//
//  Created by ZZZ on 17/01/23.
//

import AXSwift
import SwiftUI
import UniformTypeIdentifiers

struct ExtrasView: View {
	@Binding var config: String

    @State private var interval: String = UserDefaults.standard.string(
        forKey: "extra_interval")!
    @State private var beacon_key: String = UserDefaults.standard.string(
        forKey: "extra_beacon_key")!
	@State private var hide_findmy_app: Bool = UserDefaults.standard.bool(
		forKey: "extra_hide_findmy_app")
	@State private var generate_config: Bool = UserDefaults.standard.bool(
		forKey: "extra_generate_config")

	var body: some View {
		ScrollView {
			VStack {
				TextFieldView(
					title: "Update interval",
					value: $interval,
					subtitle:
						"How many minutes between updates, 1–60. Also settable "
						+ "from Home Assistant as number.findmy_update_interval.",
					onChange: {
						// Same clamp the MQTT command path applies. The old
						// nil-only guard let "0" through, which scheduled a
						// zero-second timer and span the sync loop.
						let requested = Int(interval) ?? MQTTPublisher.currentInterval()
						let clamped = min(
							max(requested, MQTTPublisher.minIntervalMinutes),
							MQTTPublisher.maxIntervalMinutes)
						interval = clamped.description
						UserDefaults.standard.set(
							interval, forKey: "extra_interval")

						Synchronizer.shared.fetchData()
					}
				)
                
                if #available(macOS 14.4, *) {
                    TextFieldView(
                        title: "Beacon decrypt key",
                        value: $beacon_key,
                        subtitle: "",
                        onChange: {
                            UserDefaults.standard.set(
                                beacon_key, forKey: "extra_beacon_key")

                            Synchronizer.shared.fetchData()
                        }
                    )
                }
                
				CheckboxView(
					title: "Hide Find My app",
					value: $hide_findmy_app,
					subtitle: "Not showing Apple Find My app window",
					onChange: {
						hide_findmy_app.toggle()
						UserDefaults.standard.set(
							hide_findmy_app,
							forKey: "extra_hide_findmy_app")

						if hide_findmy_app {
							_ = UIElement.isProcessTrusted(
								withPrompt: true)
						}

					}
				)
				CheckboxView(
					title: "Generate Home Assistant config",
					value: $generate_config,
					subtitle:
						"Show entity IDs created in Home Assistant",
					onChange: {
						generate_config.toggle()
						UserDefaults.standard.set(
							generate_config,
							forKey: "extra_generate_config")

						Synchronizer.shared.fetchData()
					}
				)

				if generate_config {
					VStack(alignment: .leading, spacing: 10) {
						BackportText(
							config,
							font: NSFont(name: "Courier", size: 14)!)
					}
					.padding()
					.background(Color(NSColor.controlBackgroundColor))
					.cornerRadius(12)

				}
			}
			.padding()
			.onAppear {
				// Home Assistant can change the interval behind this pane's
				// back, so re-read on every appearance rather than trusting
				// the value captured at init.
				interval = String(MQTTPublisher.currentInterval())
			}
		}

	}
}
