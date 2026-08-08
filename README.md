<div align="center">
  <p>
    <h3>
      <b>
        FindMySync
      </b>
    </h3>
  </p>
  <p>
    <b>
      Synchronize Apple FindMy data with Remote server
    </b>
  </p>
  <p>

  </p>
  <br />
  <p>

![FindMySync](./docs/screenshot.png)

  </p>
</div>

<details open>
  <summary><b>Table of contents</b></summary>

---

- [Features](#features)
- [Usage](#usage)
- [Contributing](#contributing)
- [Changelog](#changelog)
- [License](#license)

---

</details>

## **Homepage**



## **Features**

- Supporting both Devices and Items data, including iPhones, iPads, Airtags,...
- Synchronizing data with a custom endpoint, with Authorization header
- Supporting macOS Catalina 10.15 - Sonoma 14.4
- ...

**To suggest anything, please join our [Discussion board](https://github.com/MartinPham/FindMySync/discussions).**


## **Usage**
Check here [martinpham.com/findmysync](https://www.martinpham.com/findmysync/).


## **Contributing**

Please contribute using [GitHub Flow](https://guides.github.com/introduction/flow). Create a branch, add commits, and then [open a pull request](https://github.com/MartinPham/FindMySync/compare).

## **Changelog**

- **Fork: MQTT transport**
  - Publishes to Home Assistant over MQTT discovery instead of the `device_tracker.see`
    action, which is deprecated and removed in Home Assistant Core 2027.5.
  - Two retained topics per device: a discovery config under `homeassistant/device_tracker/`
    and a `json_attributes` topic carrying latitude, longitude, gps_accuracy and battery.
  - No `state_topic` is published, so Home Assistant resolves zones from the coordinates
    itself — `home` / `not_home` / zone name, as `device_tracker.see` used to.
  - Retained topics mean the last known position survives a Home Assistant restart.
  - Entity IDs are unchanged: `device_tracker.findmy_<identifier>`.
  - The Endpoint pane is now Broker: host, port, credentials, discovery and topic
    prefixes, and an optional availability (LWT) topic.
  - `known_devices.yaml` is no longer generated or needed.

- **v1.2 / 20240318-2212**
  - Add Sonoma 14.4 support (Thanks to [@YeapGuy](https://github.com/YeapGuy) and [@airy10](https://github.com/airy10))

## **License**

This project is licensed under the [GNU General Public License v3.0](https://opensource.org/licenses/gpl-3.0.html) - see the [`LICENSE`](LICENSE) file for details.
