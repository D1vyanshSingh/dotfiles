pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property string stateDir: Quickshell.env("HOME") + "/.config/quickshell/state"
    readonly property string statePath: stateDir + "/bluetooth-state.json"
    readonly property var sink: Pipewire.defaultAudioSink

    property var removingDevices: ({})
    property int removalHideDurationMs: 10000
    property var rememberedDevices: []
    property var deviceVolumes: ({})
    property bool stateLoaded: false
    property bool reconnectPaused: false
    property string trackedSink: ""
    property real settleUntil: 0
    property int settleMs: 6000

    function init() {}

    // --- power ---------------------------------------------------------------
    // A soft rfkill block (Lenovo WMI switch, or a state restored by
    // systemd-rfkill at boot) makes BlueZ reject Adapter1.Powered = true, so the
    // adapter just stays off with no error surfaced. Unblock, then retry.
    property int powerAttempts: 0

    function powerOn() {
        if (!root.adapter)
            return
        root.reconnectPaused = false
        root.powerAttempts = 0

        // Only BlueZ's PowerState reports "off-blocked"; the unblock itself has to
        // go through /dev/rfkill, which the session user is allowed to write.
        if (rfkillUnblock.running)
            rfkillUnblock.running = false
        rfkillUnblock.running = true
    }

    Process {
        id: rfkillUnblock
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: root.attemptPowerOn()
    }

    function attemptPowerOn() {
        if (!root.adapter || root.adapter.enabled)
            return
        if (root.powerAttempts >= 3)
            return
        root.powerAttempts += 1
        root.adapter.enabled = true
        powerOnRetry.restart()
    }

    Timer {
        id: powerOnRetry
        interval: 900
        onTriggered: if (root.adapter && !root.adapter.enabled) root.attemptPowerOn()
    }

    // --- naming --------------------------------------------------------------
    // BlueZ reports Alias == "AA-BB-CC-DD-EE-FF" until the device advertises its
    // GAP name, and Quickshell's `name` mirrors that alias, so a row can end up
    // titled with a raw MAC. Prefer the real remote name, then a class label.
    function isMacLike(text) {
        if (!text)
            return true
        return /^[0-9A-Fa-f]{2}([-:]?[0-9A-Fa-f]{2}){5}$/.test(String(text).trim())
    }

    function friendlyName(dev) {
        if (!dev)
            return ""
        var candidates = [dev.deviceName, dev.name]
        for (var i = 0; i < candidates.length; i++) {
            var c = candidates[i]
            if (c && !root.isMacLike(c))
                return c
        }
        return ""
    }

    function deviceKind(dev) {
        var icon = dev && dev.icon ? String(dev.icon) : ""

        if (icon.indexOf("headset") >= 0)
            return "Headset"
        if (icon.indexOf("headphone") >= 0)
            return "Headphones"
        if (icon.indexOf("keyboard") >= 0)
            return "Keyboard"
        if (icon.indexOf("mouse") >= 0)
            return "Mouse"
        if (icon.indexOf("gaming") >= 0 || icon.indexOf("joystick") >= 0)
            return "Gamepad"
        if (icon.indexOf("phone") >= 0)
            return "Phone"
        if (icon.indexOf("computer") >= 0)
            return "Computer"
        if (icon.indexOf("watch") >= 0)
            return "Watch"
        if (icon.indexOf("printer") >= 0)
            return "Printer"
        if (icon.indexOf("speaker") >= 0 || icon.indexOf("audio") >= 0)
            return "Speaker"

        return "Bluetooth device"
    }

    function displayName(dev) {
        var name = root.friendlyName(dev)
        return name !== "" ? name : root.deviceKind(dev)
    }

    function deviceIcon(dev) {
        var icon = dev && dev.icon ? String(dev.icon) : ""

        if (icon.indexOf("headset") >= 0 || icon.indexOf("headphone") >= 0)
            return "\uf025"
        if (icon.indexOf("keyboard") >= 0)
            return "\uf11c"
        if (icon.indexOf("mouse") >= 0)
            return "\uefba"
        if (icon.indexOf("gaming") >= 0 || icon.indexOf("joystick") >= 0)
            return "\uf11b"
        if (icon.indexOf("phone") >= 0)
            return "\uf10b"
        if (icon.indexOf("computer") >= 0)
            return "\uf109"
        if (icon.indexOf("printer") >= 0)
            return "\uf02f"
        if (icon.indexOf("speaker") >= 0 || icon.indexOf("audio") >= 0)
            return "\uf028"

        return "\uf294"
    }

    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        onLoaded: root.loadState()
        onLoadFailed: error => root.stateLoaded = true
    }

    function deviceList() {
        if (!root.adapter || !root.adapter.devices)
            return []
        var d = root.adapter.devices
        return d.values !== undefined ? d.values : d
    }

    function loadState() {
        var text = stateFile.text()
        if (text) {
            try {
                var s = JSON.parse(text)
                if (s && typeof s === "object") {
                    if (s.removing && typeof s.removing === "object")
                        root.removingDevices = s.removing
                    if (Array.isArray(s.devices))
                        root.rememberedDevices = s.devices.filter(function (a) { return typeof a === "string" })
                    if (s.volumes && typeof s.volumes === "object")
                        root.deviceVolumes = s.volumes
                }
            } catch (error) {
                console.warn("bluetooth: could not read saved state:", error)
            }
        }
        root.stateLoaded = true
        root.pruneRemovingDevices()
    }

    function saveState() {
        if (!root.stateLoaded)
            return
        stateFile.setText(JSON.stringify({
            removing: root.removingDevices,
            devices: root.rememberedDevices,
            volumes: root.deviceVolumes
        }))
    }

    function remember(address) {
        if (!address || root.rememberedDevices.indexOf(address) >= 0)
            return
        var list = root.rememberedDevices.slice()
        list.push(address)
        root.rememberedDevices = list
        root.saveState()
    }

    function forget(address) {
        var i = root.rememberedDevices.indexOf(address)
        if (i < 0)
            return
        var list = root.rememberedDevices.slice()
        list.splice(i, 1)
        root.rememberedDevices = list
        root.saveState()
    }

    function markRemoved(dev) {
        if (!dev)
            return
        var key = dev.address || dev.name || ""
        if (!key)
            return
        var updated = Object.assign({}, root.removingDevices)
        updated[key] = Date.now()
        root.removingDevices = updated
        root.forget(dev.address)
        if (dev.address && root.deviceVolumes[dev.address] !== undefined) {
            var vols = Object.assign({}, root.deviceVolumes)
            delete vols[dev.address]
            root.deviceVolumes = vols
        }
        root.saveState()
    }

    function syncConnected() {
        if (!root.stateLoaded)
            return
        var devs = root.deviceList()
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].state === BluetoothDeviceState.Connected && devs[i].address)
                root.remember(devs[i].address)
        }
    }

    function reconnectRemembered() {
        if (!root.stateLoaded || !root.adapter || !root.powered || root.reconnectPaused)
            return
        var devs = root.deviceList()
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i]
            if (!d.address || root.rememberedDevices.indexOf(d.address) < 0)
                continue
            if (root.removingDevices[d.address])
                continue
            // Never auto-connect something that was never bonded: BlueZ has no
            // agent work to do, the attempt hangs, and the row sticks on
            // "CONNECTING..." until the shell restarts.
            if (!d.paired)
                continue
            if (d.pairing)
                continue
            if (d.state !== BluetoothDeviceState.Disconnected)
                continue
            d.trusted = true
            d.connect()
        }
    }

    function pruneRemovingDevices() {
        var now = Date.now()
        var present = ({})
        var devs = root.deviceList()

        for (var i = 0; i < devs.length; i++) {
            var key = devs[i].address || devs[i].name || ""
            if (key) present[key] = true
        }

        var updated = {}
        var changed = false

        for (var k in root.removingDevices) {
            var ts = root.removingDevices[k]
            if (present[k] && (now - ts) <= root.removalHideDurationMs)
                updated[k] = ts
            else
                changed = true
        }

        if (changed) {
            root.removingDevices = updated
            root.saveState()
        }
    }

    function sinkAddressFor(node) {
        if (!node || !node.name || node.name.indexOf("bluez") < 0)
            return ""
        var name = node.name.toUpperCase()
        var devs = root.deviceList()
        for (var i = 0; i < devs.length; i++) {
            var a = devs[i].address
            if (a && name.indexOf(a.toUpperCase().replace(/:/g, "_")) >= 0)
                return a
        }
        return ""
    }

    function volumeTick() {
        if (!root.stateLoaded)
            return

        var node = root.sink
        var addr = root.sinkAddressFor(node)

        if (!node || !node.audio || addr === "") {
            root.trackedSink = ""
            return
        }

        if (root.trackedSink !== node.name) {
            root.trackedSink = node.name
            root.settleUntil = Date.now() + root.settleMs
        }

        var saved = root.deviceVolumes[addr]
        var current = node.audio.volume

        if (Date.now() < root.settleUntil) {
            if (typeof saved === "number" && Math.abs(current - saved) > 0.005)
                node.audio.volume = Math.max(0, Math.min(1.0, saved))
            return
        }

        var v = Math.round(current * 100) / 100
        if (saved === v)
            return

        var updated = Object.assign({}, root.deviceVolumes)
        updated[addr] = v
        root.deviceVolumes = updated
        root.saveState()
    }

    Timer {
        interval: 250
        running: root.stateLoaded
        repeat: true
        onTriggered: root.volumeTick()
    }

    Timer {
        interval: 5000
        running: root.stateLoaded && root.powered && !root.reconnectPaused
        repeat: true
        triggeredOnStart: true
        onTriggered: root.reconnectRemembered()
    }

    Timer {
        interval: 2000
        running: root.stateLoaded
        repeat: true
        onTriggered: {
            root.pruneRemovingDevices()
            root.syncConnected()
        }
    }

    Connections {
        target: root.adapter
        function onEnabledChanged() {
            if (root.adapter && root.adapter.enabled)
                root.reconnectPaused = false
            root.reconnectRemembered()
        }
    }
}