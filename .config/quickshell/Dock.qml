import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// macOS-style dock, on the empty desktop of whichever workspace is focused.
//
// The window is taller than the dock: the pill floats `edgeGap` above the screen
// edge and the hover label sits in the strip above it, so the surface needs room
// for both. Only the pill is masked for input — the empty band above it passes
// clicks through to whatever is behind.
PanelWindow {
    id: dock

    // ── where the dock belongs ──
    // a layer surface is global, so the dock decides for itself when to exist.
    // it belongs to the *empty* desktop — the screen with the clock and the
    // tiles — on whichever workspace you are looking at, so it follows you
    // across workspaces and steps away as soon as a window lands on the one in
    // front of you. windows behind you on other workspaces don't matter.
    //
    // a special workspace is drawn over the focused one, so focusedWorkspace
    // still names the desktop underneath while the minimized overlay is up.
    // that state only arrives on the activespecial event, tracked below.
    property bool specialOpen: false

    // windows on the workspace in front of you. HyprlandToplevel on this build
    // exposes workspace (id -98 for the minimized overlay) but no class or
    // hidden properties, so the workspace is the only thing worth asking.
    readonly property int windowsHere: {
        const w = Hyprland.focusedWorkspace
        const id = w ? Number(w.id) : NaN
        const ts = Hyprland.toplevels.values
        let n = 0
        for (let i = 0; i < ts.length; i++) {
            const tw = ts[i].workspace
            if (tw && Number(tw.id) === id) n++
        }
        return n
    }

    readonly property bool onHome: dock.windowsHere === 0 && !dock.specialOpen
    property bool hidden: false

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activespecial" && event.name !== "activespecialv2") return
            // data arrives as one comma-joined string, not a list:
            // "special:minimized,eDP-1" when shown, ",eDP-1" when hidden
            const raw = event.data
            const first = Array.isArray(raw) ? String(raw[0] || "")
                                            : String(raw || "").split(",")[0]
            dock.specialOpen = first !== ""
        }
    }

    // the event only fires on a change, so the state has to be seeded — a
    // reload while the overlay is up would otherwise show the dock through it
    Process {
        id: pSpecial
        running: true
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const mons = JSON.parse(text)
                    for (let i = 0; i < mons.length; i++) {
                        const sw = mons[i].specialWorkspace
                        if (sw && Number(sw.id) !== 0) dock.specialOpen = true
                    }
                } catch (e) {
                    console.warn("dock: could not read monitor state: " + e)
                }
            }
        }
    }

    // ── geometry, in the proportions of a real dock ──
    readonly property int iconPx: 44
    readonly property int cellPx: 50
    readonly property int slotGap: 6
    readonly property int padX: 16
    readonly property int bodyH: 70
    readonly property int edgeGap: 8
    readonly property int tipH: 22
    readonly property int tipGap: 14

    // ── magnification ──
    // one pointer read for the whole row; every cell then curves its own icon
    // from its distance to that point, so the peak follows the pointer instead
    // of snapping to whichever cell happened to be entered first.
    readonly property real ptrX: ptr.containsMouse ? (ptr.mouseX - dockRow.x) : -1000000
    readonly property real magMax: 0.36
    readonly property real magSigma: 68
    readonly property int hoverIdx: {
        if (dock.ptrX < -100000) return -1
        // nearest cell centre, so the label always names the icon the
        // magnification curve is currently peaking on
        const step = dock.cellPx + dock.slotGap
        const i = Math.round((dock.ptrX - dock.cellPx / 2) / step)
        return (i >= 0 && i < dock.apps.length) ? i : -1
    }

    function magAt(i) {
        if (dock.ptrX < -100000) return 1.0
        const d = (i * (dock.cellPx + dock.slotGap) + dock.cellPx / 2) - dock.ptrX
        return 1.0 + dock.magMax * Math.exp(-(d * d) / (2 * dock.magSigma * dock.magSigma))
    }

    readonly property var apps: [
        { label: "Terminal", icon: "kitty",              cls: "kitty",         cmd: "kitty" },
        { label: "Files",    icon: "org.xfce.thunar",    cls: "thunar",        cmd: "thunar" },
        { label: "Browser",  icon: "firefox",            cls: "firefox",       cmd: "firefox" },
        { label: "Chrome",   icon: "google-chrome",      cls: "google-chrome", cmd: "google-chrome-stable" },
        { label: "Music",    icon: "spotify",            cls: "Spotify",       cmd: "spotify" },
        { label: "Settings", icon: "preferences-system", cls: "", sep: true,
          cmd: "qs ipc call settings toggle" }
    ]

    // ── what is running ──
    // Hyprland.toplevels is a list model, not an array: the live entries are on
    // .values. XWayland clients have no lastIpcObject, native ones have no
    // .wayland, so both are tried. appId and class disagree on case (Spotify vs
    // spotify), so both sides of the comparison are lowercased.
    function appIdOf(t) {
        if (!t) return ""
        try { if (t.wayland && t.wayland.appId) return String(t.wayland.appId) } catch (e) {}
        try {
            const c = t.lastIpcObject ? String(t.lastIpcObject["class"] || "") : ""
            if (c !== "" && c !== "undefined") return c
        } catch (e) {}
        return ""
    }

    readonly property var toplevelList: Hyprland.toplevels ? Hyprland.toplevels.values : []

    readonly property var runningClasses: {
        const out = []
        const tl = dock.toplevelList
        for (let i = 0; i < tl.length; i++) {
            const c = dock.appIdOf(tl[i])
            if (c !== "") out.push(c.toLowerCase())
        }
        return out
    }

    function isRunning(app) {
        if (!app.cls) return false
        const want = String(app.cls).toLowerCase()
        const got = dock.runningClasses
        for (let i = 0; i < got.length; i++) {
            if (got[i] === want) return true
        }
        return false
    }

    function toplevelFor(app) {
        if (!app.cls) return null
        const want = String(app.cls).toLowerCase()
        const tl = dock.toplevelList
        for (let i = 0; i < tl.length; i++) {
            if (dock.appIdOf(tl[i]).toLowerCase() === want) return tl[i]
        }
        return null
    }

    // the mac behaviour: a running app comes forward, a stopped one launches.
    // HyprlandToplevel exposes no activate(), so this goes through the
    // dispatcher — and this config runs Hyprland's Lua dispatcher syntax.
    function activate(app) {
        const t = dock.toplevelFor(app)
        if (!t) {
            Quickshell.execDetached(["sh", "-c", app.cmd])
            return
        }
        const addr = String(t.address || "").replace(/^0x/, "")
        const target = addr !== "" ? "address:0x" + addr : "class:^(" + app.cls + ")$"
        if (Hyprland.usingLua) {
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({window="' + target + '"})'])
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", target])
        }
    }

    // ── material ──
    // same wall-following fill as the menu bar, measured from the band the dock
    // actually covers (the bottom of the image) rather than its mean.
    readonly property string themeState: Quickshell.env("HOME") + "/.local/state/43pr/state.json"
    property string wallPath: ""
    property real wallLum: 0.12
    // denser than the menu bar on purpose: the bar always sits on the wallpaper,
    // the dock sits on whatever window happens to be under it
    readonly property real wallDensity: Math.min(0.88, 0.60 + 0.28 * Math.min(1, dock.wallLum))
    readonly property color fill: Qt.rgba(0.05, 0.052, 0.06, dock.wallDensity)

    function readWallpaper(raw) {
        try {
            const st = JSON.parse(raw)
            const p = st && st.wallpaper ? String(st.wallpaper) : ""
            if (p !== "" && p !== dock.wallPath) {
                dock.wallPath = p
                pLum.running = true
            }
        } catch (e) {
            console.warn("dock: malformed theme state: " + e)
        }
    }

    FileView {
        id: themeStateFile
        path: dock.themeState
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: dock.readWallpaper(text())
    }

    Process {
        id: pLum
        running: false
        // -alpha off matters: an opaque alpha channel is averaged into fx:mean,
        // which reports a black band as ~0.5 and washes the glass out
        command: ["magick", dock.wallPath, "-alpha", "off", "-gravity", "South",
                  "-crop", "100%x10%+0+0", "+repage", "-colorspace", "Gray",
                  "-resize", "1x1", "-format", "%[fx:mean]", "info:"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text)
                if (!isNaN(v)) dock.wallLum = v
            }
        }
    }

    anchors { bottom: true; left: true; right: true }
    implicitHeight: dock.bodyH + dock.edgeGap + dock.tipGap + dock.tipH
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: dock.onHome && !dock.hidden
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-dock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // the label above the pill never takes input; only the pill does
    mask: Region { item: bodyItem }

    // ── label ──
    Rectangle {
        id: tip
        readonly property string label: {
            const i = dock.hoverIdx
            return (i >= 0 && dock.apps[i]) ? dock.apps[i].label : ""
        }
        visible: tip.label !== ""
        width: tipText.implicitWidth + 16
        height: dock.tipH
        radius: 7
        anchors.horizontalCenter: bodyItem.horizontalCenter
        anchors.bottom: bodyItem.top
        anchors.bottomMargin: dock.tipGap
        color: dock.fill
        border.width: 1
        border.color: Theme.glassStroke

        Text {
            id: tipText
            anchors.centerIn: parent
            text: tip.label.toUpperCase()
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.letterSpacing: 0.8
        }
    }

    // ── the pill ──
    Item {
        id: bodyItem
        anchors { bottom: parent.bottom; bottomMargin: dock.edgeGap; horizontalCenter: parent.horizontalCenter }
        width: dockRow.width + dock.padX * 2
        height: dock.bodyH

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusTile
            color: dock.fill
            border.width: 1
            border.color: Theme.glassStroke
        }

        // one pointer read drives the whole row: the tooltip index and every
        // icon's magnification curve come out of it. Declared under the icons so
        // the taps still land on the cells.
        MouseArea {
            id: ptr
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: dock.slotGap

            Repeater {
                model: dock.apps

                Item {
                    id: cell
                    required property int index
                    required property var modelData
                    width: dock.cellPx
                    height: dock.bodyH - 16
                    readonly property bool running: dock.isRunning(cell.modelData)
                    readonly property real mag: dock.magAt(cell.index)
                    readonly property bool hovered: dock.hoverIdx === cell.index

                    // mac separator before the trailing group
                    Rectangle {
                        visible: cell.modelData.sep === true
                        width: 1
                        height: 30
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: -Math.round(dock.slotGap / 2) - 1
                        color: Theme.glassStroke
                    }

                    Image {
                        id: appIcon
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 9
                        width: dock.iconPx
                        height: dock.iconPx
                        source: Quickshell.iconPath(cell.modelData.icon, true)
                        sourceSize.width: 132
                        sourceSize.height: 132
                        smooth: true
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                        // grows upward from the shelf it sits on, like a dock icon
                        scale: cell.mag
                        transformOrigin: Item.Bottom
                        // supplier logos are the loudest thing on the desktop:
                        // spotify green, chrome red and yellow, on a shell that
                        // is otherwise value only. drop the hue, then pull every
                        // icon part of the way to the shell's ink so a near-black
                        // logo (kitty) and a near-white one (settings) carry the
                        // same weight on the glass. hover lifts the icon off the
                        // shelf.
                        opacity: cell.hovered ? 1.0 : 0.92
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            saturation: -1.0
                            colorization: cell.hovered ? 0.66 : 0.46
                            colorizationColor: Theme.text
                            contrast: 0.14
                        }
                    }

                    Rectangle {
                        visible: cell.running
                        width: 4
                        height: 4
                        radius: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        color: Qt.alpha(Theme.accent, 0.6)
                    }

                    TapHandler {
                        onTapped: dock.activate(cell.modelData)
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "dock"
        function toggle(): void { dock.hidden = !dock.hidden }
        function reveal(): void { dock.hidden = false }
        function conceal(): void { dock.hidden = true }
    }
}
