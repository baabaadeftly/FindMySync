# FindMySyncMQTT

A macOS app that reads Apple's Find My data and publishes it to Home Assistant over MQTT.

Fork of [MartinPham/FindMySync](https://github.com/MartinPham/FindMySync), rebuilt around a
different transport. The original pushes locations through the `device_tracker.see` action,
which Home Assistant deprecated in 2026.4 and removes in Core 2027.5. This version publishes
MQTT discovery messages instead, so the trackers are ordinary config-entry-backed entities.

Everything the original does on the macOS side — decrypting the local Find My cache, handling
Apple's UUID rotation, keeping the Find My app refreshing — is unchanged and is the reason this
is a fork rather than a rewrite.

## What it does

- Tracks iPhones, iPads, Macs, Watches and AirTags — anything visible in Find My.
- Publishes two retained topics per device: an MQTT discovery config, and a `json_attributes`
  topic carrying latitude, longitude, GPS accuracy, battery level and reverse-geocoded address.
- Leaves zone resolution to Home Assistant. No state topic is published, so Home Assistant
  derives `home`, `not_home` or a zone name from the coordinates, exactly as `device_tracker.see`
  used to.
- Survives a Home Assistant restart. Both topics are retained, so the last known position is
  republished on reconnect — which template device trackers cannot do.
- Optionally publishes an availability topic backed by an MQTT last will, so trackers go
  `unavailable` when the Mac stops publishing. Off by default.

## Requirements

- macOS 10.15 (Catalina) or newer.
- A Mac signed into iCloud with Find My enabled, left running. The cache the app reads is only
  written while Find My is refreshing.
- Full Disk Access for the app, so it can read the Find My cache.
- An MQTT broker Home Assistant is connected to. The Mosquitto add-on is the easy option.

On macOS 14.4 and later, Apple encrypts the Find My store. The app reads the key from the
keychain automatically where it can; if that fails, the Status pane prints the `security`
command to retrieve it and you paste the value into Extras. Below 14.4 the cache is plain JSON
and no key is needed.

## Setting it up

**1. Home Assistant.** Install the Mosquitto broker add-on, then add the MQTT integration
(Settings → Devices & services → Add integration → MQTT). Create a dedicated non-admin Home
Assistant user for the app rather than reusing your own login.

**2. The app.** Open the Broker pane and fill in:

| Field | Notes |
|---|---|
| Broker host | Address of the broker, e.g. `192.168.1.10` |
| Port | `1883` for plain MQTT |
| Username / Password | The dedicated Home Assistant user |
| Discovery prefix | `homeassistant` unless you have changed it |
| Topic prefix | `findmysync` by default |
| Publish availability | Optional last-will topic, off by default |

Set the polling interval in Extras. Five minutes is a reasonable starting point.

**3. Check.** The Status pane logs the broker connection and every publish. Entities appear in
Home Assistant within a few seconds of the first sync.

## Topics

```
<discovery_prefix>/device_tracker/findmy_<id>/config     # retained, published once per device
<topic_prefix>/findmy_<id>/attributes                    # retained, published every sync
<topic_prefix>/status                                    # retained, only if availability is on
```

`<id>` is the Find My identifier with dashes stripped, giving entity IDs of the form
`device_tracker.findmy_<id>`. These match what `device_tracker.see` produced, so templates that
key off `device_tracker.findmy_*` keep working across the migration.

The entity ID is pinned with `default_entity_id` in the discovery payload. `object_id`, which
the Home Assistant documentation still lists, is ignored as of 2026.8 — a payload carrying
`object_id: findmy_testb` lands as `device_tracker.mqtt_test_b`, slugified from the name.

## Migrating from device_tracker.see

If you are coming from the original app, the order matters. Discovery arriving while the old
entities still exist gets you `findmy_..._2` and loses the entity IDs.

1. Quit the old app.
2. Back up and delete `known_devices.yaml` from your Home Assistant config directory. It is not
   used by this version.
3. Restart Home Assistant and confirm the old `device_tracker.findmy_*` entities are gone.
4. Install this app, enter the broker settings, and wait for the first sync.

To roll back, reinstall the old build and restore `known_devices.yaml`. The MQTT entities remain
until their retained discovery topics are cleared with an empty retained payload.

## Building

Pushes to `main` build a DMG through GitHub Actions and attach it to the `latest` prerelease.
Locally:

```bash
bundle install
bundle exec pod install
bundle exec fastlane release
```

Builds are unsigned, so macOS will refuse the app on first launch — right-click → Open rather
than double-clicking.

## Known limitations

- The broker password is stored in app preferences and shown in the clear in the Broker pane.
- No device registry entries are created, only entities. Trackers can be assigned to areas
  individually but not grouped as devices.
- The app must stay running, and so must Find My. If either stops, positions freeze silently
  unless you turn on the availability topic or watch staleness from the Home Assistant side.

## Credit and licence

Original work by [Martin Pham](https://github.com/MartinPham), including the Find My cache
decryption that this depends on. Sonoma 14.4 support came from
[@YeapGuy](https://github.com/YeapGuy) and [@airy10](https://github.com/airy10).

GPL-3.0, as upstream. See [`LICENSE`](LICENSE).
