import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../"

Item {
    id: page

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property bool blocked:
        adapter ? adapter.state === BluetoothAdapterState.Blocked : false
    readonly property bool scanning: adapter ? adapter.discovering : false
    property string statusText: ""
    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0

    function setStatus(text, hold) {
        page.statusText = text
        statusTimer.interval = hold === undefined ? 3000 : hold
        statusTimer.restart()
    }

    Timer {
        id: statusTimer
        interval: 3000
        onTriggered: page.statusText = ""
    }

    function setDiscovering(on) {
        if (!page.adapter || !page.powered)
            return
        page.adapter.discovering = on
    }

    function togglePower() {
        if (!page.adapter)
            return

        if (page.adapter.enabled) {
            BluetoothState.reconnectPaused = true
            setDiscovering(false)

            var devs = BluetoothState.deviceList()
            for (var i = 0; i < devs.length; i++) {
                var s = devs[i].state
                if (s === BluetoothDeviceState.Connected || s === BluetoothDeviceState.Connecting)
                    devs[i].disconnect()
            }

            powerOffTimer.restart()
            return
        }

        BluetoothState.powerOn()
    }

    Timer {
        id: powerOffTimer
        interval: 800
        onTriggered: if (page.adapter) page.adapter.enabled = false
    }

    // The attempt the user started, so a row that never resolves can be
    // reported and released instead of sitting on "CONNECTING..." forever.
    property string pendingAddress: ""
    property string pendingName: ""
    property int pendingTicks: 0
    property bool pendingConnected: false

    function deviceAction(dev) {
        if (!dev) return

        var name = BluetoothState.displayName(dev)

        if (dev.state === BluetoothDeviceState.Connected) {
            setStatus("Disconnecting " + name + "...")
            BluetoothState.forget(dev.address)
            dev.disconnect()
            return
        }

        if (dev.state === BluetoothDeviceState.Connecting) {
            // Let a pending attempt be abandoned, otherwise a device that went
            // out of range leaves the row stuck on CONNECTING...
            setStatus("Cancelled " + name)
            dev.cancelPair()
            dev.disconnect()
            page.clearPending()
            return
        }

        if (dev.state === BluetoothDeviceState.Disconnecting) {
            setStatus("Disconnecting " + name + "...")
            return
        }

        setDiscovering(false)
        dev.trusted = true

        page.pendingAddress = dev.address
        page.pendingName = name
        page.pendingTicks = 0
        page.pendingConnected = false

        if (dev.paired) {
            setStatus("Connecting to " + name + "...")
            dev.connect()
        } else {
            // BlueZ cannot finish a pairing without a registered agent;
            // bluez-agent.service provides one. Connect once the bond exists.
            setStatus("Pairing with " + name + "...")
            dev.pair()
        }

        pendingTimer.start()
    }

    function clearPending() {
        page.pendingAddress = ""
        page.pendingName = ""
        page.pendingTicks = 0
        page.pendingConnected = false
        pendingTimer.stop()
    }

    function pendingTick() {
        if (page.pendingAddress === "")
            return page.clearPending()

        page.pendingTicks += 1

        var devs = BluetoothState.deviceList()
        var dev = null
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].address === page.pendingAddress)
                dev = devs[i]
        }

        if (!dev)
            return page.clearPending()

        if (dev.state === BluetoothDeviceState.Connected) {
            setStatus("Connected to " + page.pendingName)
            return page.clearPending()
        }

        // Bond exists but BlueZ did not auto-connect; kick it once.
        if (dev.paired && !page.pendingConnected
                && dev.state === BluetoothDeviceState.Disconnected) {
            page.pendingConnected = true
            dev.connect()
        }

        // ~15s budget, then hand the row back with an explanation.
        if (page.pendingTicks > 25) {
            setStatus("Couldn't connect to " + page.pendingName, 8000)
            dev.cancelPair()
            dev.disconnect()
            page.clearPending()
        }
    }

    Timer {
        id: pendingTimer
        interval: 600
        repeat: true
        onTriggered: page.pendingTick()
    }

    function removeDevice(dev) {
        if (!dev) return

        BluetoothState.markRemoved(dev)

        if (dev.state === BluetoothDeviceState.Connected ||
            dev.state === BluetoothDeviceState.Connecting ||
            dev.state === BluetoothDeviceState.Disconnecting) {
            dev.disconnect()
        }

        dev.forget()
    }

    function actionLabel(dev) {
        if (!dev) return ""
        if (dev.pairing) return "PAIRING..."

        switch (dev.state) {
        case BluetoothDeviceState.Connected:
            return "DISCONNECT"
        case BluetoothDeviceState.Connecting:
            return "CONNECTING..."
        case BluetoothDeviceState.Disconnecting:
            return "DISCONNECTING..."
        default:
            return "CONNECT"
        }
    }

    onVisibleChanged: setDiscovering(page.visible && page.powered)
    onPoweredChanged: setDiscovering(page.visible && page.powered)
    Component.onCompleted: if (page.visible && page.powered) setDiscovering(true)
    Component.onDestruction: setDiscovering(false)

    Connections {
        target: page.adapter
        function onEnabledChanged() {
            page.setDiscovering(page.visible && page.powered)
        }
    }

    Timer {
        id: discoveryRetryTimer
        interval: 1500
        repeat: true
        running: page.visible && page.powered && !powerOffTimer.running
        onTriggered: {
            if (page.adapter && page.powered && !page.adapter.discovering)
                page.adapter.discovering = true
        }
    }

    Column {
        anchors.fill: parent
        anchors.leftMargin: page.marginLeft; anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop; anchors.bottomMargin: page.marginBottom
        spacing: 14

        Text {
            text: "BLUETOOTH"; color: Theme.text
            font.family: Theme.fontFamily; font.pixelSize: 19; font.letterSpacing: 3
        }

        Rectangle { width: parent.width; height: 1; color: Theme.border }

        Rectangle {
            id: bluetoothToggle
            width: parent.width
            height: 36
            radius: Theme.radius
            color: page.powered
                ? Theme.alpha(Theme.accent, 0.1)
                : Theme.alpha(Theme.textFaint, 0.15)
            border.width: 1
            border.color: page.powered ? Theme.accent : Theme.textFaint

            Text {
                anchors.centerIn: parent
                text: !page.adapter ? "NO BLUETOOTH ADAPTER"
                    : page.powered ? "BLUETOOTH ON"
                    : page.blocked ? "BLUETOOTH BLOCKED — TAP TO UNBLOCK"
                    : "BLUETOOTH OFF"
                color: page.blocked && !page.powered
                    ? Theme.danger
                    : page.powered ? Theme.accent
                    : Theme.textFaint
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.bold: true
                font.letterSpacing: 1
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: page.togglePower()
            }
        }

        Text {
            width: parent.width
            visible: page.statusText !== ""
            text: page.statusText
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
        }

        Flickable {
            id: flick
            width: parent.width
            height: parent.height - y
            clip: true
            contentWidth: width
            contentHeight: list.height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list
                width: flick.width
                spacing: 6

                Item {
                    width: list.width
                    height: 100
                    visible: !page.adapter

                    Text {
                        anchors.centerIn: parent
                        text: "NO BLUETOOTH ADAPTER"
                        color: Theme.textDim
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.letterSpacing: 1
                    }
                }

                Item {
                    width: list.width
                    height: 100
                    visible: page.adapter && !page.powered

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "\uf294"
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 24
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: page.blocked ? "BLUETOOTH IS BLOCKED" : "BLUETOOTH IS OFF"
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }
                    }
                }

                Item {
                    width: list.width
                    height: 100
                    visible: page.powered && repeater.count === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "\uf1eb"
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 22
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "SCANNING FOR DEVICES..."
                            color: Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Keep this open while devices appear."
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                        }
                    }
                }

                Repeater {
                    id: repeater
                    model: (page.adapter && page.powered) ? page.adapter.devices : null

                    delegate: Rectangle {
                        id: card

                        required property BluetoothDevice modelData

                        readonly property bool isConnected:
                            modelData.state === BluetoothDeviceState.Connected

                        readonly property string deviceKey:
                            modelData.address || modelData.name || ""

                        visible: !BluetoothState.removingDevices[deviceKey]
                        width: list.width
                        height: visible ? 52 : 0
                        radius: Theme.radius

                        color: isConnected
                            ? Theme.alpha(Theme.accent, 0.10)
                            : "transparent"

                        border.width: 1
                        border.color: isConnected
                            ? Theme.accent
                            : Theme.border

                        Item {
                            id: actionArea
                            width: 120
                            height: card.height
                            x: 14
                            y: 0

                            Text {
                                id: actionText
                                x: 0
                                y: (parent.height - height) / 2

                                width: Math.min(
                                    implicitWidth,
                                    parent.width - removeButton.width - 12
                                )

                                text: page.actionLabel(card.modelData)

                                color: card.isConnected
                                    ? Theme.danger
                                    : Theme.accent

                                font.family: Theme.fontFamily
                                font.pixelSize: 10
                                verticalAlignment: Text.AlignVCenter

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked:
                                        page.deviceAction(card.modelData)
                                }
                            }

                            Item {
                                id: removeButton
                                width: 28
                                height: 28
                                x: actionText.width + 12
                                y: (parent.height - height) / 2

                                Text {
                                    anchors.centerIn: parent
                                    text: "\uf293"
                                    color: Theme.textDim
                                    font.family: Theme.iconFont
                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    id: unpairMouseArea
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked:
                                        page.removeDevice(card.modelData)
                                }

                                Rectangle {
                                    visible: unpairMouseArea.containsMouse
                                    z: 100
                                    x: -8
                                    y: height + 6
                                    width: tooltipText.width + 16
                                    height: 24
                                    radius: 4
                                    color: "transparent"

                                    Text {
                                        id: tooltipText
                                        anchors.centerIn: parent
                                        text: "Unpair"
                                        color: "white"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }

                        Item {
                            id: deviceInfo
                            x: actionArea.width + 28
                            y: 0
                            width: Math.max(
                                100,
                                card.width - actionArea.width - 42
                            )
                            height: card.height

                            Text {
                                id: deviceIcon
                                x: 0
                                y: (parent.height - height) / 2
                                width: 18
                                height: 18
                                text: BluetoothState.deviceIcon(card.modelData)
                                color: card.isConnected
                                    ? Theme.accent
                                    : Theme.textDim
                                font.family: Theme.iconFont
                                font.pixelSize: 15
                                verticalAlignment: Text.AlignVCenter
                            }

                            Column {
                                id: deviceText
                                x: 28
                                y: (parent.height - height) / 2
                                width: parent.width - x
                                spacing: 2

                                Text {
                                    width: parent.width
                                    text: BluetoothState.displayName(card.modelData)
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                }

                                Text {
                                    width: parent.width

                                    text: {
                                        var parts = []

                                        // Only fall back to the MAC when BlueZ never
                                        // learned a name, so rows stay distinguishable.
                                        if (BluetoothState.friendlyName(card.modelData) === "")
                                            parts.push(card.modelData.address)

                                        if (card.isConnected)
                                            parts.push("connected")
                                        else if (card.modelData.paired)
                                            parts.push("paired")
                                        else
                                            parts.push("not paired")

                                        if (card.modelData.batteryAvailable)
                                            parts.push(
                                                Math.round(
                                                    card.modelData.battery * 100
                                                ) + "%"
                                            )

                                        return parts.join("  •  ")
                                    }

                                    color: card.isConnected
                                        ? Theme.accent
                                        : Theme.textFaint

                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}