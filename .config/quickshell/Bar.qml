import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Scope {
    id: root
    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/quickshell/state/bar-state.json"
        printErrors: false
        onAdapterUpdated: saveTimer.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter();
        }

        adapter: JsonAdapter {
            id: cfg
            property string position: "top"       // top | right | bottom | left
            property string style: "menubar"      // menubar | floating | joined | strip
            property int thickness: 26
            property int margin: 4
            property real scale: 1.0
            property real bgOpacity: 1.0
            property bool border: false
            property bool showStats: true
            property bool showWs: true
            property bool showMedia: true
            property bool showVolume: true
            property bool showBattery: true
            property bool showNet: true
            property bool showWarp: true
        }
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: cfgFile.writeAdapter()
    }

    function resetSettings() {
        cfg.position = "top"; cfg.style = "menubar"; cfg.thickness = 26; cfg.margin = 4;
        cfg.scale = 1.0; cfg.bgOpacity = 0.7; cfg.border = false;
        cfg.showStats = false; cfg.showWs = true; cfg.showMedia = true;
        cfg.showVolume = true; cfg.showBattery = true; cfg.showNet = true;
    }

    // ───────────────────────── Derived layout values ─────────────────────────
    // "menubar" is the flush strip: full screen width, no gap, no radius, and a
    // fill that follows the wallpaper (see below).
    readonly property bool menubar: cfg.style === "menubar"
    readonly property bool vertical: cfg.position === "left" || cfg.position === "right"
    readonly property bool joined: cfg.style !== "floating"
    readonly property int panelThick: vertical ? cfg.thickness + 12 : cfg.thickness
    readonly property int effEdge: root.menubar || cfg.style === "strip" ? 0 : cfg.margin
    readonly property int effGap: root.menubar || cfg.style === "strip" ? 0 : 6
    readonly property real barRadius: root.menubar || cfg.style === "strip" ? 0 : Theme.radiusBar
    readonly property color bgColor: root.menubar ? root.wallGlass
        : cfg.style === "strip" ? Theme.glass : Theme.glassRaised
    readonly property color borderColor: Qt.alpha(Theme.accent, 0.25)
    readonly property int edgePad: root.menubar ? 10 : 0

    // ── menubar material ──
    // the strip sits flush on the wall, so its fill has to follow that image. a
    // fill tuned for a night wall turns to fog over a bright one — but only the
    // band actually behind the bar matters, not the whole picture: a dark-top,
    // bright-bottom wall needs a light strip even though its mean is mid grey.
    readonly property string themeState: Quickshell.env("HOME") + "/.local/state/43pr/state.json"
    property string wallPath: ""
    property real wallLum: 0.12
    readonly property real wallDensity: Math.min(0.82, 0.46 + 0.32 * Math.min(1, root.wallLum))
    readonly property color wallGlass: Qt.rgba(0.05, 0.052, 0.06, root.wallDensity)

    readonly property var lumArgs: {
        const g = cfg.position === "bottom" ? "South"
                : cfg.position === "left" ? "West"
                : cfg.position === "right" ? "East" : "North";
        // -alpha off matters: most wallpapers carry an opaque alpha channel and
        // fx:mean then averages it in, reporting a black band as ~0.5
        return ["magick", root.wallPath, "-alpha", "off", "-gravity", g,
                "-crop", root.vertical ? "8%x100%+0+0" : "100%x8%+0+0", "+repage",
                "-colorspace", "Gray", "-resize", "1x1", "-format", "%[fx:mean]", "info:"];
    }

    // ── focused app (menubar) ──
    readonly property var activeTop: Hyprland.activeToplevel
    readonly property string activeApp: {
        const t = root.activeTop
        if (!t) return "DESKTOP"
        let s = ""
        try { if (t.wayland && t.wayland.appId) s = String(t.wayland.appId) } catch (e) {}
        if (s === "") {
            try {
                const c = t.lastIpcObject ? String(t.lastIpcObject["class"] || "") : ""
                if (c !== "" && c !== "undefined") s = c
            } catch (e) {}
        }
        // some apps report a package id instead of a name
        // ("@codebuff/freebuff-desktop"); there is nothing readable in that, so
        // leave the label empty and let the menubar collapse it
        if (s.indexOf("/") >= 0) return ""
        return s === "" ? "DESKTOP" : s.toUpperCase()
    }

    function s(n) { return Math.round(n * cfg.scale); }

    readonly property int sizeCpuRam: s(12)
    readonly property int sizeClock: s(12)
    readonly property int sizeMarquee: s(11)
    readonly property int sizeNetIcon: s(14)
    readonly property int sizeVolIcon: s(16)
    readonly property int sizeVolText: s(13)
    readonly property int sizeBatIcon: s(13)
    readonly property int sizeBatText: s(12)
    readonly property int sizePowerIcon: s(13)
    readonly property int sizeIconGap: 12
    readonly property int iconYOffset: 1

    readonly property int sizeCalTime: s(30)
    readonly property int sizeCalDate: s(12)
    readonly property int sizeCalMonth: s(13)
    readonly property int sizeCalArrow: s(16)
    readonly property int sizeCalWeekday: s(11)
    readonly property int sizeCalDay: s(12)

    // ───────────────────────── Battery ─────────────────────────
    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery)
        ?? (UPower.displayDevice && UPower.displayDevice.isPresent
            && UPower.displayDevice.type === UPowerDeviceType.Battery
            ? UPower.displayDevice : null)
    readonly property int batPct: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool batCharging: battery !== null
        && (battery.state === UPowerDeviceState.Charging
            || battery.state === UPowerDeviceState.PendingCharge
            || battery.state === UPowerDeviceState.FullyCharged)
    readonly property bool batLow: battery !== null && !batCharging && batPct <= 15
    readonly property var batIcons: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"]
    readonly property string batIcon: batIcons[batPct >= 90 ? 4 : batPct >= 65 ? 3 : batPct >= 40 ? 2 : batPct >= 15 ? 1 : 0]

    // ───────────────────────── State + IPC ─────────────────────────
    property bool barVisible: true
    property bool settingsOpen: false

    property bool barLive: true
    function rebuildBar() { barLive = false; rebuildTimer.restart(); }
    Timer { id: rebuildTimer; interval: 80; onTriggered: root.barLive = true }
    Connections {
        target: cfg
        function onPositionChanged() { root.rebuildBar(); wallLumProc.running = true; }
        function onStyleChanged() { root.rebuildBar(); }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
        function show(): void { root.barVisible = true; }
        function hide(): void { root.barVisible = false; }
        function setPosition(pos: string): void {
            if (["top", "right", "bottom", "left"].indexOf(pos) >= 0) cfg.position = pos;
        }
        function cyclePosition(): void {
            const order = ["top", "right", "bottom", "left"];
            cfg.position = order[(order.indexOf(cfg.position) + 1) % order.length];
        }
        function setStyle(st: string): void {
            if (["menubar", "floating", "joined", "strip"].indexOf(st) >= 0) cfg.style = st;
        }
        function customize(): void { root.settingsOpen = !root.settingsOpen; }
        function warp(): void { root.warpOpen = !root.warpOpen; }
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void {
            if (!clockPanel) return;
            clockPanel.monthOffset = 0;
            clockPanel.calOpen = !clockPanel.calOpen;
        }
        function show(): void {
            if (!clockPanel) return;
            clockPanel.monthOffset = 0;
            clockPanel.calOpen = true;
        }
        function hide(): void { if (clockPanel) clockPanel.calOpen = false; }
    }

    property int cpuUsage: 0
    property int memPercent: 0
    property string netState: "disconnected"

    // ───────────────────────── Cloudflare WARP ─────────────────────────
    property string warpState: "disconnected"   // connected | connecting | disconnecting | disconnected
    property bool warpOpen: false
    readonly property bool warpOn: warpState === "connected" || warpState === "connecting"
    readonly property string warpLabel: warpState === "connected" ? "Connected"
        : warpState === "connecting" ? "Connecting…"
        : warpState === "disconnecting" ? "Disconnecting…"
        : "Disconnected"

    property real _prevTotal: 0
    property real _prevIdle: 0

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            const total = f.reduce((a, b) => a + b, 0);
            const idle = f[3] + f[4];
            const dT = total - root._prevTotal;
            const dI = idle - root._prevIdle;
            if (root._prevTotal > 0 && dT > 0)
                root.cpuUsage = Math.round(100 * (dT - dI) / dT);
            root._prevTotal = total;
            root._prevIdle = idle;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const kb = k => Number(t.match(new RegExp(k + ":\\s+(\\d+)"))[1]);
            root.memPercent = Math.round(100 * (kb("MemTotal") - kb("MemAvailable")) / kb("MemTotal"));
        }
    }

    Process {
        id: netProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s = "disconnected";
                for (const l of text.split("\n")) {
                    if (l === "ethernet:connected") { s = "ethernet"; break; }
                    if (l === "wifi:connected") s = "wifi";
                }
                if (s !== root.netState) root.netState = s;
            }
        }
    }

    // the wallpaper currently on screen, straight from 43pr's state file, so the
    // menubar re-measures itself when the wall changes instead of keeping a
    // density that belonged to the previous image
    FileView {
        id: wallState
        path: root.themeState
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const st = JSON.parse(text());
                const p = st && st.wallpaper ? String(st.wallpaper) : "";
                if (p !== "" && p !== root.wallPath) {
                    root.wallPath = p;
                    wallLumProc.running = true;
                }
            } catch (e) {
                console.warn("bar: malformed theme state: " + e);
            }
        }
    }

    Process {
        id: wallLumProc
        running: false
        command: root.lumArgs
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text);
                if (!isNaN(v)) root.wallLum = v;
            }
        }
    }

    Timer {
        interval: 2000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: { statFile.reload(); memFile.reload(); }
    }

    Timer {
        interval: 10000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: if (!netProc.running) netProc.running = true
    }

    Process {
        id: warpProc
        command: ["warp-cli", "--accept-tos", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.toLowerCase();
                // "disconnecting" contains "connecting" and "disconnected" contains
                // "connected", so the transitional states have to win first.
                root.warpState = t.indexOf("disconnecting") >= 0 ? "disconnecting"
                    : t.indexOf("connecting") >= 0 ? "connecting"
                    : t.indexOf("connected") >= 0 && t.indexOf("disconnected") < 0 ? "connected"
                    : "disconnected";
            }
        }
    }

    Process {
        id: warpAction
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: if (!warpProc.running) warpProc.running = true
    }

    function warpToggle(on) {
        root.warpState = on ? "connecting" : "disconnecting";
        warpAction.command = ["warp-cli", "--accept-tos", on ? "connect" : "disconnect"];
        warpAction.running = true;
    }

    Timer {
        interval: 3000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: if (!warpProc.running) warpProc.running = true
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    Process { id: runner }
    function run(cmd) {
        runner.command = ["sh", "-c", cmd];
        runner.running = true;
    }

    // ───────────────────────── Reusable components ─────────────────────────

    // Flows left→right on horizontal bars, top→bottom on vertical ones.
    component Lane: GridLayout {
        property int gap: 0
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: gap
        columnSpacing: gap
    }

    component Panel: Rectangle {
        property Item lane
        width: root.vertical ? root.panelThick : (lane ? lane.implicitWidth + 4 : 0)
        height: root.vertical ? (lane ? lane.implicitHeight + 4 : 0) : root.panelThick
        radius: root.barRadius
        color: root.joined ? "transparent" : root.bgColor
        border.width: cfg.border && !root.joined ? 1 : 0
        border.color: root.borderColor
    }

    component Mod: Item {
        id: mod
        property string text: ""
        property string vtext: text          // text shown on vertical bars
        property string glyph: ""
        property string vglyph: glyph        // glyph used on vertical bars
        property real glyphSize: 16
        property real baseSize: 11
        property color color: Theme.text
        property bool bold: false
        property real yOffset: 0
        signal clicked(var mouse)
        signal scrolled(real delta)

        readonly property string shown: root.vertical ? vtext : text
        readonly property string shownGlyph: root.vertical ? vglyph : glyph

        Layout.alignment: Qt.AlignCenter
        // vertical: every module is exactly as wide as the bar, content is centered inside
        implicitWidth: root.vertical ? root.panelThick
                                   : content.implicitWidth + (root.menubar ? 14 : 20)
        implicitHeight: root.vertical ? Math.max(20, content.implicitHeight + 8)
                                      : Math.max(root.panelThick - 2, content.implicitHeight)

        // menubar items take a soft pad on hover, the way a menu bar item does
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: 5
            visible: root.menubar
            color: Qt.rgba(1, 1, 1, ma.containsMouse ? 0.09 : 0.0)
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        GridLayout {
            id: content
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.vertical ? 0 : mod.yOffset
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 2
            columnSpacing: root.sizeIconGap

            Text {
                visible: mod.shownGlyph !== ""
                Layout.alignment: Qt.AlignCenter
                horizontalAlignment: Text.AlignHCenter
                text: mod.shownGlyph
                color: mod.color
                font.family: Theme.iconFont
                font.pixelSize: mod.glyphSize
                renderType: Text.NativeRendering
            }

            Text {
                visible: mod.shown !== ""
                Layout.alignment: Qt.AlignCenter
                text: mod.shown
                color: mod.color
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.iconFont
                font.bold: mod.bold
                font.pixelSize: mod.baseSize
                renderType: Text.NativeRendering
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mouse => mod.clicked(mouse)
            onWheel: wheel => mod.scrolled(wheel.angleDelta.y)
        }
    }

    // ── settings-popup widgets ──
    component Lbl: Text {
        color: Theme.text
        font.family: Theme.iconFont
        font.pixelSize: 12
    }

    component Seg: Row {
        id: seg
        property var options: []
        property string current: ""
        signal picked(string v)
        spacing: 4
        Repeater {
            model: seg.options
            delegate: Rectangle {
                id: opt
                required property string modelData
                width: Math.max(44, lbl.implicitWidth + 16)
                height: 22
                radius: Theme.radius
                color: opt.modelData === seg.current ? Qt.alpha(Theme.accent, 0.4)
                     : segMa.containsMouse ? Qt.alpha(Theme.text, 0.14)
                     : Qt.alpha(Theme.text, 0.07)
                Text {
                    id: lbl
                    anchors.centerIn: parent
                    text: opt.modelData
                    color: Theme.text
                    font.family: Theme.iconFont
                    font.pixelSize: 11
                }
                MouseArea {
                    id: segMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: seg.picked(opt.modelData)
                }
            }
        }
    }

    component Toggle: Rectangle {
        id: tg
        property bool checked: false
        signal toggled(bool v)
        implicitWidth: 34
        implicitHeight: 18
        radius: 9
        color: checked ? Qt.alpha(Theme.accent, 0.6) : Qt.alpha(Theme.text, 0.15)
        Rectangle {
            width: 14; height: 14; radius: 7; y: 2
            x: tg.checked ? 18 : 2
            color: Theme.text
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        }
        MouseArea { anchors.fill: parent; onClicked: tg.toggled(!tg.checked) }
    }

    component Slide: Item {
        id: sl
        property real from: 0
        property real to: 1
        property real value: 0
        readonly property real frac: (value - from) / (to - from)
        signal moved(real v)
        implicitWidth: 140
        implicitHeight: 20

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 4; radius: 2
            color: Qt.alpha(Theme.text, 0.15)
            Rectangle { width: parent.width * sl.frac; height: 4; radius: 2; color: Theme.accent }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: (sl.width - width) * sl.frac
            width: 12; height: 12; radius: 6
            color: Theme.text
        }
        MouseArea {
            anchors.fill: parent
            function upd(px) {
                const f = Math.max(0, Math.min(1, px / width));
                sl.moved(sl.from + f * (sl.to - sl.from));
            }
            onPressed: m => upd(m.x)
            onPositionChanged: m => { if (pressed) upd(m.x); }
        }
    }

    // ───────────────────────── Settings popup ─────────────────────────
    LazyLoader {
        active: root.settingsOpen

        PanelWindow {
            id: sw
            implicitWidth: 380
            implicitHeight: col.implicitHeight + 32
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "bar-settings"

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: Theme.bg
                border.width: 1
                border.color: root.borderColor

                ColumnLayout {
                    id: col
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: "Bar settings"
                            color: Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Mod {
                            text: "\u2715"
                            onClicked: root.settingsOpen = false
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Position"; Layout.fillWidth: true }
                        Seg {
                            options: ["top", "right", "bottom", "left"]
                            current: cfg.position
                            onPicked: v => cfg.position = v
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Style"; Layout.fillWidth: true }
                        Seg {
                            options: ["menubar", "floating", "joined", "strip"]
                            current: cfg.style
                            onPicked: v => cfg.style = v
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Thickness  " + cfg.thickness; Layout.fillWidth: true }
                        Slide {
                            from: 16; to: 40; value: cfg.thickness
                            onMoved: v => cfg.thickness = Math.round(v)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Edge margin  " + cfg.margin; Layout.fillWidth: true }
                        Slide {
                            from: 0; to: 16; value: cfg.margin
                            onMoved: v => cfg.margin = Math.round(v)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Text scale  " + cfg.scale.toFixed(2); Layout.fillWidth: true }
                        Slide {
                            from: 0.8; to: 1.5; value: cfg.scale
                            onMoved: v => cfg.scale = Math.round(v * 20) / 20
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Background  " + Math.round(cfg.bgOpacity * 100) + "%"; Layout.fillWidth: true }
                        Slide {
                            from: 0; to: 1; value: cfg.bgOpacity
                            onMoved: v => cfg.bgOpacity = Math.round(v * 20) / 20
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Lbl { text: "Border"; Layout.fillWidth: true }
                        Toggle { checked: cfg.border; onToggled: v => cfg.border = v }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(Theme.text, 0.12)
                    }

                    Repeater {
                        model: [
                            { k: "showStats", l: "CPU / RAM (horizontal)" },
                            { k: "showWs", l: "Workspaces" },
                            { k: "showMedia", l: "Media" },
                            { k: "showVolume", l: "Volume" },
                            { k: "showBattery", l: "Battery" },
                            { k: "showNet", l: "Network" },
                            { k: "showWarp", l: "Cloudflare WARP" }
                        ]
                        delegate: RowLayout {
                            id: trow
                            required property var modelData
                            Layout.fillWidth: true
                            Lbl { text: trow.modelData.l; Layout.fillWidth: true }
                            Toggle {
                                checked: cfg[trow.modelData.k]
                                onToggled: v => cfg[trow.modelData.k] = v
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 24
                        Mod {
                            anchors.right: parent.right
                            text: "Reset to defaults"
                            baseSize: 11
                            onClicked: root.resetSettings()
                        }
                    }
                }
            }
        }
    }

    // ───────────────────────── The bar ─────────────────────────
    Variants {
        model: root.barLive ? Quickshell.screens : []

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors {
                top: cfg.position !== "bottom"
                bottom: cfg.position !== "top"
                left: cfg.position !== "right"
                right: cfg.position !== "left"
            }
            implicitWidth: root.vertical ? root.panelThick + root.effEdge : 0
            implicitHeight: root.vertical ? 0 : root.panelThick + root.effEdge
            color: "transparent"
            visible: root.barVisible
            WlrLayershell.namespace: "quickshell-bar"

            Item {
                id: frame
                anchors {
                    fill: parent
                    topMargin: cfg.position === "top" ? root.effEdge : (root.vertical ? root.effGap : 0)
                    bottomMargin: cfg.position === "bottom" ? root.effEdge : (root.vertical ? root.effGap : 0)
                    leftMargin: cfg.position === "left" ? root.effEdge : (root.vertical ? 0 : root.effGap)
                    rightMargin: cfg.position === "right" ? root.effEdge : (root.vertical ? 0 : root.effGap)
                }

                // continuous background for "joined" / "strip" / "menubar"
                Rectangle {
                    visible: root.joined
                    anchors.fill: parent
                    radius: root.barRadius
                    color: root.bgColor
                    border.width: cfg.border ? 1 : 0
                    border.color: root.borderColor
                }

                // the strip is flush with the screen edge, so this hairline is the
                // only thing separating it from the desktop
                Rectangle {
                    visible: root.menubar
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.09)
                }

                // ── start section ──
                Panel {
                    lane: startLane
                    anchors.left: frame.left
                    anchors.top: frame.top
                    anchors.leftMargin: root.edgePad

                    Lane {
                        id: startLane
                        anchors.centerIn: parent
                        gap: root.menubar ? 4 : 0

                        Mod {
                            visible: cfg.showStats && !root.vertical && !root.menubar
                            baseSize: root.sizeCpuRam
                            glyphSize: root.sizeCpuRam + 4
                            vglyph: "\uDB81\uDE1A"
                            text: "CPU " + root.cpuUsage + "%"
                            vtext: ""
                            color: root.vertical && root.cpuUsage >= 85 ? Theme.danger : Theme.text
                        }
                        Mod {
                            visible: cfg.showStats && !root.vertical && !root.menubar
                            baseSize: root.sizeCpuRam
                            glyphSize: root.sizeCpuRam + 4
                            vglyph: "\uDB80\uDF5B"
                            text: "RAM " + root.memPercent + "%"
                            vtext: ""
                            color: root.vertical && root.memPercent >= 85 ? Theme.danger : Theme.text
                        }

                        Item {
                            visible: cfg.showWs
                            Layout.alignment: Qt.AlignCenter
                            implicitWidth: root.vertical ? root.panelThick : wsLane.implicitWidth + 12
                            implicitHeight: wsLane.implicitHeight + (root.vertical ? 12 : 0)

                            Lane {
                                id: wsLane
                                anchors.centerIn: parent
                                gap: 8

                                Repeater {
                                    model: Hyprland.workspaces
                                    delegate: Rectangle {
                                        id: dot
                                        required property var modelData
                                        visible: modelData.id > 0
                                        Layout.alignment: Qt.AlignCenter
                                        implicitWidth: root.vertical ? 10 : (modelData.focused ? 32 : 10)
                                        implicitHeight: root.vertical ? (modelData.focused ? 24 : 10) : 10
                                        radius: 5
                                        color: modelData.urgent ? Theme.danger
                                             : modelData.focused ? Qt.alpha(Theme.accent, 0.2)
                                             : dotMa.containsMouse ? Theme.accent2
                                             : Qt.alpha(Theme.textFaint, 0.5)

                                        Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
                                        Behavior on implicitHeight { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }

                                        MouseArea {
                                            id: dotMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: dot.modelData.activate()
                                        }
                                    }
                                }
                            }

                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                onWheel: e => root.run(e.angleDelta.y > 0
                                    ? "hyprctl dispatch 'hl.dsp.focus({workspace=\"e+1\"})'"
                                    : "hyprctl dispatch 'hl.dsp.focus({workspace=\"e-1\"})'")
                            }
                        }

                        // menubar: the focused window's app id, the way a title bar
                        // would read it — mono caps, dimmer than the clock. apps with
                        // no readable name (package-style ids) drop the whole section
                        Rectangle {
                            visible: root.menubar && root.activeApp !== ""
                            Layout.alignment: Qt.AlignCenter
                            implicitWidth: 1
                            implicitHeight: 11
                            color: Qt.rgba(1, 1, 1, 0.14)
                        }

                        Text {
                            visible: root.menubar && root.activeApp !== ""
                            Layout.alignment: Qt.AlignCenter
                            text: root.activeApp
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: root.s(10)
                            font.bold: true
                            font.letterSpacing: 0.6
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // ── center section (clock + calendar) ──
                Panel {
                    id: clockPanel
                    lane: clockLane
                    anchors.horizontalCenter: root.vertical ? undefined : frame.horizontalCenter
                    anchors.verticalCenter: root.vertical ? frame.verticalCenter : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined

                    property bool calOpen: false
                    property int monthOffset: 0

                    SystemClock { id: clk; precision: SystemClock.Minutes }

                    Lane {
                        id: clockLane
                        anchors.centerIn: parent

                        Mod {
                            id: clockMod
                            bold: true
                            baseSize: root.sizeClock
                            text: Qt.formatDateTime(clk.date, "HH:mm")
                            vtext: Qt.formatDateTime(clk.date, "HH") + "\n" + Qt.formatDateTime(clk.date, "mm")
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    root.settingsOpen = !root.settingsOpen;
                                    return;
                                }
                                if (mouse.button !== Qt.LeftButton) return;
                                clockPanel.monthOffset = 0;
                                clockPanel.calOpen = !clockPanel.calOpen;
                            }
                        }
                    }

                    LazyLoader {
                        active: clockPanel.calOpen

                        PopupWindow {
                            readonly property point p: bar.contentItem.mapFromItem(clockPanel, 0, 0)

                            anchor.window: bar
                            anchor.rect.x: root.vertical
                                ? (cfg.position === "left" ? p.x + clockPanel.width + 6
                                                           : p.x - implicitWidth - 6)
                                : p.x + (clockPanel.width - implicitWidth) / 2
                            anchor.rect.y: root.vertical
                                ? p.y + (clockPanel.height - implicitHeight) / 2
                                : (cfg.position === "top" ? p.y + clockPanel.height + 4
                                                          : p.y - implicitHeight - 4)
                            implicitWidth: calBox.gridW + 2 * calBox.pad
                            implicitHeight: calCol.implicitHeight + 2 * calBox.pad
                            color: "transparent"
                            visible: true

                            Rectangle {
                                id: calBox
                                anchors.fill: parent
                                radius: 4
                                color: Theme.bg
                                border.width: cfg.border ? 1 : 0
                                border.color: root.borderColor

                                readonly property int firstDay: 1
                                readonly property int cellW: 36
                                readonly property int cellH: 30
                                readonly property int pad: 16
                                readonly property int gridW: cellW * 7

                                readonly property date now: clk.date
                                readonly property date view: new Date(now.getFullYear(), now.getMonth() + clockPanel.monthOffset, 1)

                                readonly property var cells: {
                                    const first = (view.getDay() - firstDay + 7) % 7;
                                    const y = view.getFullYear(), m = view.getMonth();
                                    const ty = now.getFullYear(), tm = now.getMonth(), td = now.getDate();
                                    const out = [];
                                    for (let i = 0; i < 42; i++) {
                                        const d = new Date(y, m, i - first + 1);
                                        out.push({
                                            n: d.getDate(),
                                            inMonth: d.getMonth() === m,
                                            today: d.getFullYear() === ty && d.getMonth() === tm && d.getDate() === td
                                        });
                                    }
                                    return out;
                                }

                                WheelHandler {
                                    onWheel: e => clockPanel.monthOffset += (e.angleDelta.y > 0 ? -1 : 1)
                                }

                                Column {
                                    id: calCol
                                    anchors.centerIn: parent
                                    spacing: 12

                                    Column {
                                        spacing: 2
                                        Text {
                                            text: Qt.formatTime(calBox.now, "HH:mm")
                                            color: Theme.text
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.sizeCalTime
                                            font.bold: true
                                        }
                                        Text {
                                            text: Qt.formatDate(calBox.now, "dddd, d MMMM yyyy")
                                            color: Theme.textDim
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.sizeCalDate
                                        }
                                    }

                                    Rectangle {
                                        width: calBox.gridW
                                        height: 1
                                        color: Qt.alpha(Theme.text, 0.12)
                                    }

                                    Item {
                                        width: calBox.gridW
                                        height: 26

                                        Item {
                                            width: 28; height: parent.height
                                            anchors.left: parent.left
                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uDB80\uDD41"
                                                color: prevMa.containsMouse ? Theme.accent : Theme.text
                                                font.family: Theme.iconFont
                                                font.pixelSize: root.sizeCalArrow
                                            }
                                            MouseArea {
                                                id: prevMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: clockPanel.monthOffset -= 1
                                            }
                                        }

                                        Item {
                                            anchors.centerIn: parent
                                            width: monthTitle.implicitWidth + 16
                                            height: parent.height
                                            Text {
                                                id: monthTitle
                                                anchors.centerIn: parent
                                                text: Qt.formatDate(calBox.view, "MMMM yyyy")
                                                color: titleMa.containsMouse ? Theme.accent : Theme.text
                                                font.family: Theme.iconFont
                                                font.pixelSize: root.sizeCalMonth
                                                font.bold: true
                                            }
                                            MouseArea {
                                                id: titleMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: clockPanel.monthOffset = 0
                                            }
                                        }

                                        Item {
                                            width: 28; height: parent.height
                                            anchors.right: parent.right
                                            Text {
                                                anchors.centerIn: parent
                                                text: "\uDB80\uDD42"
                                                color: nextMa.containsMouse ? Theme.accent : Theme.text
                                                font.family: Theme.iconFont
                                                font.pixelSize: root.sizeCalArrow
                                            }
                                            MouseArea {
                                                id: nextMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: clockPanel.monthOffset += 1
                                            }
                                        }
                                    }

                                    Row {
                                        Repeater {
                                            model: 7
                                            delegate: Text {
                                                required property int index
                                                width: calBox.cellW
                                                horizontalAlignment: Text.AlignHCenter
                                                text: Qt.locale().dayName((index + calBox.firstDay) % 7, Locale.ShortFormat)
                                                color: Theme.textDim
                                                font.family: Theme.iconFont
                                                font.pixelSize: root.sizeCalWeekday
                                            }
                                        }
                                    }

                                    Grid {
                                        columns: 7
                                        Repeater {
                                            model: calBox.cells
                                            delegate: Item {
                                                required property var modelData
                                                width: calBox.cellW
                                                height: calBox.cellH

                                                Rectangle {
                                                    visible: parent.modelData.today
                                                    anchors.fill: parent
                                                    anchors.margins: 2
                                                    radius: Theme.radius
                                                    color: Qt.alpha(Theme.accent, 0.45)
                                                    border.width: 1
                                                    border.color: Theme.accent
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: parent.modelData.n
                                                    color: parent.modelData.inMonth ? Theme.text : Theme.textFaint
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: root.sizeCalDay
                                                    font.bold: parent.modelData.today
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── end section ──
                Panel {
                    lane: endLane
                    anchors.right: root.vertical ? undefined : frame.right
                    anchors.rightMargin: root.vertical ? 0 : root.edgePad
                    anchors.bottom: root.vertical ? frame.bottom : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined

                    Lane {
                        id: endLane
                        anchors.centerIn: parent
                        gap: root.menubar ? 4 : 0

                        // on the strip the stats live on the right, small and dim,
                        // like a status item rather than a headline
                        Mod {
                            visible: cfg.showStats && root.menubar
                            baseSize: root.s(10)
                            glyphSize: root.s(12)
                            glyph: "\uDB81\uDE1A"
                            text: root.cpuUsage + "%"
                            color: Theme.textDim
                        }
                        Mod {
                            visible: cfg.showStats && root.menubar
                            baseSize: root.s(10)
                            glyphSize: root.s(12)
                            glyph: "\uDB80\uDF5B"
                            text: root.memPercent + "%"
                            color: Theme.textDim
                        }

                        // horizontal: scrolling title
                        Item {
                            id: mediaMarquee
                            visible: cfg.showMedia && !root.vertical && Marquee.player !== null && Marquee.title !== ""
                            Layout.alignment: Qt.AlignCenter
                            implicitWidth: Math.min(Marquee.textW, Marquee.maxW) + 20
                            implicitHeight: 18

                            // hand the panel this widget's place on screen, so the
                            // card can hang from it rather than from the middle

                            Item {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                clip: true

                                Row {
                                    x: Marquee.animating ? Marquee.x : 0
                                    spacing: Marquee.gap
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: root.iconYOffset

                                    Text {
                                        text: Marquee.text
                                        color: Theme.text
                                        font.family: Theme.iconFont
                                        font.pixelSize: root.sizeMarquee
                                        renderType: Text.NativeRendering
                                        width: Marquee.animating ? Marquee.textW
                                                                 : Math.min(Marquee.textW, Marquee.maxW)
                                        elide: Marquee.animating ? Text.ElideNone : Text.ElideRight
                                    }

                                    Text {
                                        visible: Marquee.animating
                                        text: Marquee.text
                                        color: Theme.text
                                        font.family: Theme.iconFont
                                        font.pixelSize: root.sizeMarquee
                                        renderType: Text.NativeRendering
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // left is the door to the panel, where play/pause and
                                // everything else lives; the other buttons stay skips
                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        Quickshell.execDetached(["qs", "ipc", "call", "music", "toggle"]);
                                        return;
                                    }
                                    const p = Marquee.player;
                                    if (!p) return;
                                    if (mouse.button === Qt.RightButton) p.next();
                                    else p.previous();
                                }
                            }

                            function syncAnchor() {
                                const p = bar.contentItem.mapFromItem(mediaMarquee, mediaMarquee.width / 2, mediaMarquee.height)
                                MusicAnchor.center = p.x
                                MusicAnchor.bottom = p.y
                                MusicAnchor.valid = mediaMarquee.visible && mediaMarquee.width > 0
                            }

                            onXChanged: syncAnchor()
                            onWidthChanged: syncAnchor()
                            onVisibleChanged: if (visible) syncAnchor()
                            Component.onCompleted: syncAnchor()
                        }

                        // vertical: compact media button
                        Mod {
                            visible: cfg.showMedia && root.vertical && Marquee.player !== null && Marquee.title !== ""
                            text: "\u266A"
                            baseSize: root.sizeVolIcon - 2
                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) {
                                    Quickshell.execDetached(["qs", "ipc", "call", "music", "toggle"]);
                                    return;
                                }
                                const p = Marquee.player;
                                if (!p) return;
                                if (mouse.button === Qt.RightButton) p.next();
                                else p.previous();
                            }
                        }

                        Mod {
                            visible: cfg.showVolume
                            readonly property var sink: Pipewire.defaultAudioSink
                            readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
                            readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
                            baseSize: root.sizeVolText
                            glyphSize: root.sizeVolIcon
                            glyph: muted || vol <= 0 ? "\uDB81\uDF5F"
                                 : vol > 0.66 ? "\uDB81\uDD7E"
                                 : vol > 0.33 ? "\uDB81\uDD80" : "\uDB81\uDD7F"
                            // the reading sits beside the speaker on every bar style,
                            // the menubar included — the icon alone doesn't say 30% or 80%
                            text: muted ? "Muted" : Math.round(vol * 100) + "%"
                            vtext: ""
                            color: muted ? Theme.danger : Theme.text
                            onScrolled: delta => {
                                if (!sink || !sink.audio) return;
                                const v = sink.audio.volume + (delta / 120) * 0.02;
                                sink.audio.volume = Math.max(0, Math.min(1.0, v));
                            }
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    root.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle");
                                else
                                    root.run("qs ipc call settings sound");
                            }
                        }

                        Mod {
                            visible: cfg.showBattery && root.battery !== null
                            baseSize: root.sizeBatText
                            glyphSize: root.sizeBatIcon
                            glyph: (root.batCharging ? "\uf0e7 " : "") + root.batIcon
                            vglyph: root.batIcon
                            text: root.batPct + "%"
                            vtext: root.batPct + ""
                            color: root.batLow ? Theme.danger
                                 : root.vertical && root.batCharging ? Theme.accent : Theme.text
                        }

                        Mod {
                            visible: cfg.showNet
                            baseSize: root.sizeNetIcon
                            yOffset: root.iconYOffset
                            text: root.netState === "wifi" ? "\uDB81\uDDA9"
                                : root.netState === "ethernet" ? "\uDB80\uDE00" : "\uDB81\uDDAA"
                            onClicked: root.run("qs ipc call settings network")
                        }

                        Mod {
                            id: warpMod
                            visible: cfg.showWarp
                            // outline cloud = off, filled cloud = on (the theme is monochrome,
                            // so shape carries the state rather than colour)
                            baseSize: root.warpOn ? root.sizeNetIcon + 1 : root.sizeNetIcon + 2
                            yOffset: root.iconYOffset
                            text: root.warpOn ? "\uf0c2" : "\uebaa"
                            color: root.warpState === "connecting" || root.warpState === "disconnecting"
                                ? Theme.textDim : Theme.text
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    root.warpToggle(!root.warpOn);
                                else
                                    root.warpOpen = !root.warpOpen;
                            }
                        }

                        Mod {
                            baseSize: root.sizePowerIcon
                            yOffset: root.iconYOffset
                            text: "\u23FB"
                            onClicked: root.run("qs ipc call powermenu toggle")
                        }
                    }

                    LazyLoader {
                        active: root.warpOpen

                        PopupWindow {
                            readonly property point p: bar.contentItem.mapFromItem(warpMod, 0, 0)

                            anchor.window: bar
                            anchor.rect.x: root.vertical
                                ? (cfg.position === "left" ? p.x + warpMod.width + 6
                                                           : p.x - implicitWidth - 6)
                                : p.x + warpMod.width - implicitWidth
                            anchor.rect.y: root.vertical
                                ? p.y + (warpMod.height - implicitHeight) / 2
                                : (cfg.position === "top" ? p.y + warpMod.height + 4
                                                          : p.y - implicitHeight - 4)
                            implicitWidth: 252
                            implicitHeight: warpCol.implicitHeight + 28
                            color: "transparent"
                            visible: true

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: Qt.alpha(Theme.bgPanel, 0.97)
                                border.width: cfg.border ? 1 : 0
                                border.color: root.borderColor

                                Column {
                                    id: warpCol
                                    anchors.centerIn: parent
                                    width: 224
                                    spacing: 12

                                    // header: mark · title · switch
                                    Item {
                                        width: parent.width
                                        height: 22

                                        Text {
                                            id: warpMark
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.warpOn ? "\uf0c2" : "\uebaa"
                                            color: root.warpOn ? Theme.text : Theme.textDim
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.warpOn ? 16 : 17
                                            renderType: Text.NativeRendering

                                            SequentialAnimation on opacity {
                                                running: root.warpState === "connecting"
                                                         || root.warpState === "disconnecting"
                                                loops: Animation.Infinite
                                                NumberAnimation { from: 1; to: 0.3; duration: 550; easing.type: Easing.InOutQuad }
                                                NumberAnimation { from: 0.3; to: 1; duration: 550; easing.type: Easing.InOutQuad }
                                            }
                                        }

                                        Text {
                                            anchors.left: warpMark.right
                                            anchors.leftMargin: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "CLOUDFLARE WARP"
                                            color: Theme.text
                                            font.family: Theme.iconFont
                                            font.pixelSize: 11
                                            font.bold: true
                                            font.letterSpacing: 0.5
                                        }

                                        Toggle {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            checked: root.warpOn
                                            onToggled: v => root.warpToggle(v)
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: Qt.alpha(Theme.text, 0.1)
                                    }

                                    // status line
                                    Item {
                                        width: parent.width
                                        height: 16

                                        Rectangle {
                                            id: warpDot
                                            width: 6; height: 6; radius: 3
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: root.warpState === "connected" ? Theme.ok
                                                 : root.warpState === "connecting" ? Theme.accent
                                                 : root.warpState === "disconnecting" ? Theme.textDim
                                                 : Qt.alpha(Theme.textFaint, 1)
                                        }

                                        Text {
                                            anchors.left: warpDot.right
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.warpLabel
                                            color: root.warpState === "connected" ? Theme.text : Theme.textDim
                                            font.family: Theme.iconFont
                                            font.pixelSize: 11
                                        }
                                    }

                                    Text {
                                        width: parent.width
                                        text: root.warpOn ? "Traffic is encrypted and routed through Cloudflare."
                                                          : "Traffic uses your normal connection."
                                        color: Theme.textFaint
                                        font.family: Theme.iconFont
                                        font.pixelSize: 10
                                        wrapMode: Text.WordWrap
                                        lineHeight: 1.2
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}