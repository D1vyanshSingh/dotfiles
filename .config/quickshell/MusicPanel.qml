import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

// ── music ──
// The marquee in the bar is the door; this is the room behind it. Same glass as
// the rest of the shell: a blurred surface, one hairline edge, mono type. The
// player itself is Marquee.player — the singleton the bar already reads — so
// both always agree on which track is up.
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    implicitHeight: 380
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "music-panel"
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.showing ? card : null }

    property bool showing: false
    property bool scrubbing: false
    property real scrubRatio: 0

    readonly property var player: Marquee.player
    readonly property bool hasTrack: root.player !== null && (root.player.trackTitle || "") !== ""
    readonly property bool playing: root.player !== null && root.player.isPlaying === true
    // Players only shout about position when you seek — they don't tick — so the
    // panel keeps its own clock between reports and re-syncs when one arrives.
    property real clockPos: 0
    readonly property real pos: root.scrubbing ? root.scrubRatio * root.len : root.clockPos
    readonly property real len: root.hasTrack ? Math.max(0, root.player.length || 0) : 0
    readonly property real progress: root.len > 0 ? Math.max(0, Math.min(1, root.pos / root.len)) : 0
    readonly property string art: (root.player && root.player.trackArtUrl) ? root.player.trackArtUrl : ""

    // ── output volume ──
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: (root.sink && root.sink.audio) ? Math.max(0, Math.min(1, root.sink.audio.volume)) : 0
    readonly property bool muted: (root.sink && root.sink.audio) ? root.sink.audio.muted === true : false

    // the card is 372 wide; hang it from the marquee's middle, and only fall back
    // to the screen's middle when there is no marquee to hang from
    readonly property real cardW: 372
    readonly property real cardX: {
        if (!MusicAnchor.valid || MusicAnchor.center <= 0)
            return Math.max(12, (root.width - root.cardW) / 2)
        return Math.max(12, Math.min(root.width - root.cardW - 12, MusicAnchor.center - root.cardW / 2))
    }
    readonly property real cardTop: MusicAnchor.valid ? MusicAnchor.bottom + 8 : 34

    readonly property string mono: Theme.fontFamily
    readonly property color cardFill: Qt.rgba(0.055, 0.057, 0.066, 0.93)
    readonly property color hair: Qt.rgba(1, 1, 1, 0.09)

    function inkA(a) { return Qt.rgba(1, 1, 1, a) }

    function fmt(secs) {
        var s = Math.max(0, Math.round(secs || 0))
        var m = Math.floor(s / 60)
        var r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    function open() {
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr) root.screen = scr
        }
        root.showing = true
        root.syncPos()
        root.refreshPos()
    }

    function close() {
        root.showing = false
        root.scrubbing = false
    }

    function toggle() { root.showing ? root.close() : root.open() }

    // MPRIS seeking is relative, so land on the spot by asking for the distance
    // from wherever the track is right now
    function seekTo(ratio) {
        var p = root.player
        if (!p || !p.canSeek || root.len <= 0) return
        var target = Math.max(0, Math.min(1, ratio)) * root.len
        // position is writable on Quickshell's player: that is an absolute
        // SetPosition, which lands on the spot instead of drifting by however
        // stale our idea of "now" was
        if (p.positionSupported) p.position = target
        else p.seek(target - root.clockPos)
        root.clockPos = target
    }

    function syncPos() {
        if (!root.player || root.scrubbing) return
        var p = root.player.position
        if (typeof p === "number" && p >= 0) root.clockPos = p
    }

    // a zero offset seek is a no-op for playback but makes the player report
    // where it really is, which is how a freshly opened panel catches up
    function refreshPos() {
        var p = root.player
        if (p && p.canSeek && p.positionSupported) p.seek(0)
    }

    Connections {
        target: root.player
        enabled: root.player !== null
        ignoreUnknownSignals: true
        function onPositionChanged() { root.syncPos() }
        function onTrackChanged() { root.clockPos = 0; root.syncPos() }
        function onIsPlayingChanged() { root.syncPos() }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.showing && root.playing && !root.scrubbing && root.len > 0
        onTriggered: root.clockPos = Math.min(root.len, root.clockPos + 0.25)
    }

    function setVolume(v) {
        if (!root.sink || !root.sink.audio) return
        root.sink.audio.volume = Math.max(0, Math.min(1, v))
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    IpcHandler {
        target: "music"
        function toggle(): void { root.toggle() }
        function show(): void { root.open() }
        function hide(): void { root.close() }
    }

    // a slider: rail, fill, and a knob that only shows itself under the pointer
    component Rail: Item {
        id: rail
        property real value: 0
        property bool live: false       // emit while dragging, not only on release
        property bool active: true
        signal moved(real ratio)
        signal committed(real ratio)

        height: 14

        function ratioAt(mx) {
            return Math.max(0, Math.min(1, mx / Math.max(1, width)))
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 3
            radius: 2
            color: root.inkA(0.16)
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * Math.max(0, Math.min(1, rail.value))
            height: 3
            radius: 2
            color: rail.active ? root.inkA(0.92) : root.inkA(0.3)
        }

        Rectangle {
            readonly property real cx: parent.width * Math.max(0, Math.min(1, rail.value))
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, cx - width / 2))
            width: 9
            height: 9
            radius: 4.5
            color: "#ffffff"
            visible: rail.active && (railArea.containsMouse || railArea.pressed)
        }

        MouseArea {
            id: railArea
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            hoverEnabled: true
            enabled: rail.active
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function push(mx) { rail.moved(rail.ratioAt(mx)) }

            onPressed: mouse => push(mouse.x)
            onPositionChanged: mouse => { if (pressed) push(mouse.x) }
            onReleased: mouse => {
                push(mouse.x)
                rail.committed(rail.ratioAt(mouse.x))
            }
        }
    }

    Rectangle {
        id: card

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: root.showing ? root.cardTop : root.cardTop - 6
        anchors.leftMargin: root.cardX

        width: root.cardW
        height: body.height + 40
        radius: Theme.radiusTile
        color: root.cardFill
        border.width: 1
        border.color: root.inkA(0.13)

        opacity: root.showing ? 1 : 0
        visible: opacity > 0.01
        transformOrigin: Item.Top
        scale: root.showing ? 1 : 0.97

        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on anchors.topMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on anchors.leftMargin { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        MouseArea { anchors.fill: parent }

        Column {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 13

            // ── label + close ──
            Item {
                width: parent.width
                height: 16

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NOW PLAYING"
                    color: root.inkA(0.4)
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2.6
                }

                Item {
                    id: closeBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 18
                    height: 18

                    Rectangle {
                        anchors.centerIn: parent
                        width: 15
                        height: 1
                        rotation: 45
                        color: closeArea.containsMouse ? "#ffffff" : root.inkA(0.42)
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: 15
                        height: 1
                        rotation: -45
                        color: closeArea.containsMouse ? "#ffffff" : root.inkA(0.42)
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            // ── sleeve + title ──
            Item {
                width: parent.width
                height: 96

                Item {
                    id: sleeve
                    anchors.left: parent.left
                    anchors.top: parent.top
                    width: 96
                    height: 96

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: root.inkA(0.07)
                        border.width: 1
                        border.color: root.inkA(0.1)

                        Text {
                            anchors.centerIn: parent
                            visible: root.art === ""
                            text: "\u266A"
                            color: root.inkA(0.35)
                            font.family: root.mono
                            font.pixelSize: 28
                        }
                    }

                    Image {
                        id: sleeveImg
                        anchors.fill: parent
                        visible: root.art !== ""
                        source: root.art
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        layer.enabled: visible
                        layer.effect: OpacityMask { maskSource: sleeveMask }
                    }

                    Rectangle {
                        id: sleeveMask
                        anchors.fill: parent
                        radius: 16
                        visible: false
                        layer.enabled: true
                    }
                }

                Column {
                    anchors {
                        left: sleeve.right; leftMargin: 16
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 6

                    Text {
                        width: parent.width
                        text: root.hasTrack ? root.player.trackTitle : "nothing playing"
                        color: root.hasTrack ? root.inkA(0.96) : root.inkA(0.4)
                        font.family: root.mono
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: root.hasTrack && (root.player.trackArtist || "") !== ""
                        text: root.hasTrack ? (root.player.trackArtist || "") : ""
                        color: root.inkA(0.56)
                        font.family: root.mono
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: root.hasTrack && (root.player.trackAlbum || "") !== ""
                        text: root.hasTrack ? (root.player.trackAlbum || "") : ""
                        color: root.inkA(0.3)
                        font.family: root.mono
                        font.pixelSize: 8
                        font.letterSpacing: 1
                        elide: Text.ElideRight
                    }
                }
            }

            // ── the line you can drag ──
            Item {
                width: parent.width
                height: 30

                Rail {
                    id: seekRail
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    active: root.hasTrack && root.player !== null && root.len > 0 && root.player.canSeek !== false
                    value: root.scrubbing ? root.scrubRatio : root.progress

                    onMoved: ratio => {
                        root.scrubRatio = ratio
                        root.scrubbing = true
                    }

                    // the seek only lands on release: seeking every pixel would
                    // fight the position the player keeps reporting back
                    onCommitted: ratio => {
                        root.seekTo(ratio)
                        root.scrubbing = false
                    }
                }

                Text {
                    anchors { left: parent.left; bottom: parent.bottom }
                    text: root.fmt(root.scrubbing ? root.scrubRatio * root.len : root.pos)
                    color: root.inkA(0.42)
                    font.family: root.mono
                    font.pixelSize: 8
                }

                Text {
                    anchors { right: parent.right; bottom: parent.bottom }
                    text: "-" + root.fmt(Math.max(0, root.len - (root.scrubbing ? root.scrubRatio * root.len : root.pos)))
                    color: root.inkA(0.42)
                    font.family: root.mono
                    font.pixelSize: 8
                }
            }

            // ── transport ──
            Item {
                width: parent.width
                height: 30

                Row {
                    anchors.centerIn: parent
                    spacing: 34

                Text {
                    text: "\u25C0\u25C0"
                    color: prevArea.containsMouse ? root.inkA(0.95) : root.inkA(0.62)
                    font.family: root.mono
                    font.pixelSize: 14
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        anchors.margins: -10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.previous()
                    }
                }

                Text {
                    text: root.playing ? "\u25AE\u25AE" : "\u25B6"
                    color: playArea.containsMouse ? "#ffffff" : root.inkA(0.95)
                    font.family: root.mono
                    font.pixelSize: 22
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        anchors.margins: -10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.togglePlaying()
                    }
                }

                Text {
                    text: "\u25B6\u25B6"
                    color: nextArea.containsMouse ? root.inkA(0.95) : root.inkA(0.62)
                    font.family: root.mono
                    font.pixelSize: 14
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        anchors.margins: -10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player) root.player.next()
                    }
                }
                }
            }

            // ── volume ──
            Item {
                width: parent.width
                height: 18

                Text {
                    id: volIcon
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: 20
                    text: root.muted || root.vol <= 0 ? "\uDB81\uDF5F"
                        : root.vol > 0.66 ? "\uDB81\uDD7E"
                        : root.vol > 0.33 ? "\uDB81\uDD80" : "\uDB81\uDD7F"
                    color: volArea.containsMouse ? "#ffffff" : root.inkA(0.66)
                    font.family: Theme.iconFont
                    font.pixelSize: 13
                    Behavior on color { ColorAnimation { duration: 100 } }

                    MouseArea {
                        id: volArea
                        anchors.fill: parent
                        anchors.margins: -10
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.muted
                    }
                }

                Text {
                    id: volPct
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 34
                    horizontalAlignment: Text.AlignRight
                    text: root.muted ? "MUTE" : Math.round(root.vol * 100) + "%"
                    color: root.inkA(0.42)
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 1
                }

                Rail {
                    anchors {
                        left: volIcon.right; leftMargin: 12
                        right: volPct.left; rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    live: true
                    value: root.muted ? 0 : root.vol
                    onMoved: ratio => root.setVolume(ratio)
                }
            }
        }
    }
}
