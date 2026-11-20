import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// ── shelf ──
// A Dynamic-Island drop target that lives on the clock.
//
// The clock already sits in the middle of the menu bar, so the island starts as
// an invisible patch exactly over it: same size, same place. A drag crossing
// that patch opens the pill with a spring, the way the phone's island stretches
// out of the notch, and the contents fade in after the geometry settles instead
// of scaling with it.
//
// Idle it must stay invisible and still be the thing under the pointer at the
// clock's pixels — a layer surface takes input wherever it is not masked, so the
// calendar click the clock normally handles is forwarded from here.
//
// The shelf is a surface between apps, not a scratch buffer: what it holds
// outlives a config reload (see shelf-state.json) and a chip can be delivered
// straight into the focused window with one click, no drag.
Scope {
    id: root

    // held items: { path, name }
    property var items: []
    property bool dragging: false
    property bool hovering: false
    property bool peek: false          // stays open for a beat after a drop
    property bool stateReady: false    // state file loaded (or failed) once
    // a drag out of the shelf takes the pointer away, so hover stops and the
    // island would collapse out from under the drag it just started
    property bool draggingOut: false

    // hovering only matters once there is something to show, and it must not be
    // gated on `showing` — that reads back into hover and Qt reports a loop
    readonly property bool showing: root.dragging || root.draggingOut
                                   || (root.hovering && root.items.length > 0) || root.peek

    Timer {
        id: dragOutGuard
        interval: 8000
        onTriggered: root.draggingOut = false
    }

    readonly property int idleW: 92
    readonly property int idleH: 26
    readonly property int openW: 392
    readonly property int openH: 64

    // with something held, the collapsed pill steps aside so it never sits on
    // top of the clock it grew out of
    readonly property real xOffset: (!root.showing && root.items.length > 0) ? -(root.idleW / 2 + 38) : 0

    Timer {
        id: peekTimer
        interval: 2400
        onTriggered: root.peek = false
    }

    function decodePath(url) {
        var s = String(url)
        if (s.indexOf("file://") === 0) s = s.substring(7)
        try { return decodeURIComponent(s) } catch (e) { return s }
    }

    function encodeUri(path) {
        return "file://" + String(path).split("/").map(function (p) {
            return encodeURIComponent(p)
        }).join("/")
    }

    function addUrls(urls) {
        var next = root.items.slice()
        for (var i = 0; i < urls.length; i++) {
            var p = root.decodePath(urls[i])
            if (p === "") continue
            var dup = false
            for (var j = 0; j < next.length; j++) if (next[j].path === p) dup = true
            if (dup) continue
            var name = p.split("/").pop()
            next.push({ path: p, name: name === "" ? p : name })
        }
        while (next.length > 8) next.shift()
        root.items = next
        root.peek = next.length > 0
        if (next.length > 0) peekTimer.restart()
        saveTimer.restart()
        console.log("shelf: holding " + root.items.length + " item(s)")
    }

    // ── one click, done ──
    // hyprctl cannot paste anything itself, but it can inject the key that
    // pastes: send_shortcut lands on the focused window, which is still the app
    // underneath because a layer surface with no keyboard focus does not steal
    // it. A terminal wants the plain path and Ctrl+Shift+V; everything else
    // wants the file as a uri-list and a normal Ctrl+V.
    function pasteAt(i) {
        var it = root.items[i]
        if (!it) return
        var term = "*kitty*|*foot*|*alacritty*|*wezterm*|*ghostty*|*konsole*|*xterm*|*terminal*"
        var script = [
            "cls=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // \"\"' | tr 'A-Z' 'a-z')",
            "case \"$cls\" in",
            "  " + term + ")",
            "    printf %s \"$1\" | wl-copy -t text/plain >/dev/null 2>&1",
            "    sleep 0.15",
            "    hyprctl dispatch 'hl.dsp.send_shortcut({ mods = \"CTRL SHIFT\", key = \"V\" })' >/dev/null ;;",
            "  *)",
            "    printf %s \"$2\" | wl-copy -t text/uri-list >/dev/null 2>&1",
            "    sleep 0.15",
            "    hyprctl dispatch 'hl.dsp.send_shortcut({ mods = \"CTRL\", key = \"V\" })' >/dev/null ;;",
            "esac"
        ].join("\n")
        // $0 is the "sh" placeholder, so the path lands in $1 and the file uri in $2
        Quickshell.execDetached(["sh", "-c", script, "sh", it.path, root.encodeUri(it.path)])
        console.log("shelf: pasting " + it.path)
    }

    // right click: the file itself on the clipboard, so it can be pasted by
    // hand into anything the automatic paste could not reach
    function copyUri(i) {
        var it = root.items[i]
        if (!it) return
        // wl-copy forks a daemon that keeps the selection alive; detach its
        // streams too, or the inherited pipe stays open and the copy stalls
        Quickshell.execDetached(["sh", "-c",
                                 "printf %s \"$1\" | wl-copy -t text/uri-list >/dev/null 2>&1 &",
                                 "sh", root.encodeUri(it.path)])
        console.log("shelf: copied uri-list " + it.path)
    }

    function removeAt(i) {
        var next = root.items.slice()
        next.splice(i, 1)
        root.items = next
        saveTimer.restart()
    }

    // ── surviving a reload ──
    // same state file convention as the bar, the notifications and the power
    // menu, so a `qs` restart or a config reload comes back holding the same
    // files instead of an empty pill
    function restore(arr) {
        var keep = []
        for (var i = 0; i < arr.length && keep.length < 8; i++) {
            var it = arr[i]
            if (!it || typeof it.path !== "string" || it.path === "") continue
            keep.push({
                path: it.path,
                name: (typeof it.name === "string" && it.name !== "")
                      ? it.name : (it.path.split("/").pop() || it.path)
            })
        }
        if (keep.length === 0) return
        root.items = keep
        prune(keep)
        console.log("shelf: restored " + keep.length + " item(s)")
    }

    // a scratch file that was deleted while the shelf was closed must not come
    // back as a chip that cannot be pasted anywhere
    function prune(list) {
        var args = ["sh", "-c",
                    "for p in \"$@\"; do [ -e \"$p\" ] || printf '%s\\0' \"$p\"; done", "sh"]
        for (var i = 0; i < list.length; i++) args.push(list[i].path)
        pruneProc.command = args
        pruneProc.running = true
    }

    PanelWindow {
        id: win
        anchors { top: true; left: true; right: true }
        implicitHeight: 130
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-shelf"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { item: island }

        Item {
            id: island
            anchors.horizontalCenter: parent.horizontalCenter
            // an anchored item ignores x, so the aside has to be an offset
            anchors.horizontalCenterOffset: root.xOffset
            anchors.top: parent.top
            width: root.showing ? root.openW : root.idleW
            height: root.showing ? root.openH : root.idleH

            // the phone's island is a spring, not a tween: it overshoots the
            // target width by a hair and settles back
            Behavior on width {
                NumberAnimation { duration: 430; easing.type: Easing.OutBack; easing.overshoot: 1.12 }
            }
            Behavior on height {
                NumberAnimation { duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.06 }
            }
            Behavior on anchors.horizontalCenterOffset {
                NumberAnimation { duration: 380; easing.type: Easing.OutCubic }
            }

            Rectangle {
                id: slab
                anchors.fill: parent
                radius: root.showing ? 22 : 13
                // near opaque when open: the clock it grew out of must not
                // read through the slab, the way it doesn't on the phone
                color: root.showing ? Qt.rgba(0.03, 0.03, 0.036, 0.995)
                     : root.items.length > 0 ? Qt.rgba(0.035, 0.035, 0.042, 0.94)
                     : "transparent"
                border.width: root.showing || root.items.length > 0 ? 1 : 0
                border.color: root.dragging ? Qt.rgba(1, 1, 1, 0.42) : Qt.rgba(1, 1, 1, 0.12)

                Behavior on radius { NumberAnimation { duration: 330; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }
            }

            // ── collapsed: a count beside the clock ──
            Text {
                anchors.centerIn: parent
                visible: !root.showing && root.items.length > 0
                text: "\u25A3" + (root.items.length > 1 ? " " + root.items.length : "")
                color: Qt.rgba(1, 1, 1, 0.62)
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                font.letterSpacing: 1
                opacity: visible ? 1 : 0
            }

            // ── open: prompt or chips ──
            Text {
                anchors.centerIn: parent
                visible: root.showing && root.items.length === 0
                text: root.dragging ? "DROP TO HOLD" : "SHELF EMPTY"
                color: root.dragging ? "white" : Qt.rgba(1, 1, 1, 0.45)
                font.family: "JetBrains Mono"
                font.pixelSize: 10
                font.letterSpacing: 3
                opacity: root.showing ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 190; easing.type: Easing.OutCubic }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 8
                visible: root.showing && root.items.length > 0

                Repeater {
                    model: root.items

                    Rectangle {
                        id: chip
                        required property int index
                        required property var modelData

                        width: Math.min(150, chipText.implicitWidth + 26)
                        height: 30
                        radius: 15
                        color: chipMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.10)

                        Behavior on color { ColorAnimation { duration: 120 } }

                        // a chip is a drag SOURCE as well as a button: pull it out
                        // and drop it on a folder, a chat window, anywhere. the
                        // automatic drag starts when Drag.active flips, so the
                        // MouseArea below only decides when the pointer has
                        // travelled far enough to mean "drag", not "click".
                        Drag.active: chipMouse.dragging
                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction
                        Drag.hotSpot: Qt.point(14, 15)
                        Drag.mimeData: ({
                            "text/uri-list": root.encodeUri(chip.modelData.path),
                            "text/plain": chip.modelData.path
                        })

                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 18, implicitWidth)
                            text: chip.modelData.name
                            color: Qt.rgba(1, 1, 1, 0.82)
                            font.family: "JetBrains Mono"
                            font.pixelSize: 9
                            elide: Text.ElideMiddle
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            property bool dragging: false
                            property point pressAt: Qt.point(0, 0)

                            onPressed: (m) => {
                                pressAt = Qt.point(m.x, m.y)
                                dragging = false
                            }
                            onPositionChanged: (m) => {
                                if (!pressed || dragging) return
                                const dx = m.x - pressAt.x
                                const dy = m.y - pressAt.y
                                if (Math.sqrt(dx * dx + dy * dy) > 7) {
                                    dragging = true
                                    root.draggingOut = true
                                    dragOutGuard.restart()
                                }
                            }
                            onDraggingChanged: {
                                if (dragging) console.log("shelf: drag out " + chip.modelData.path)
                            }
                            onReleased: { dragging = false; root.draggingOut = false }
                            onCanceled: { dragging = false; root.draggingOut = false }

                            // left hands the file to the focused window, right
                            // puts it on the clipboard for a manual paste,
                            // middle drops it
                            onClicked: (m) => {
                                if (m.button === Qt.LeftButton) root.pasteAt(chip.index)
                                else if (m.button === Qt.RightButton) root.copyUri(chip.index)
                                else root.removeAt(chip.index)
                            }
                        }
                    }
                }
            }

            // the drag surface. it has to sit under the chips so a click still
            // lands on the chip, but cover the island so a drag can arrive
            DropArea {
                anchors.fill: parent
                z: -1

                onEntered: (drag) => {
                    root.dragging = true
                    console.log("shelf: drag enter formats=" + drag.formats)
                }
                onExited: {
                    root.dragging = false
                    console.log("shelf: drag exit")
                }
                onDropped: (drop) => {
                    root.dragging = false
                    console.log("shelf: drop formats=" + drop.formats + " urls=" + drop.urls)
                    root.addUrls(drop.urls)
                }
            }

            // idle, empty: the island is invisible over the clock, so the clock
            // click has to be relayed to the calendar the bar owns
            MouseArea {
                anchors.fill: parent
                visible: !root.showing && root.items.length === 0
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (m) => {
                    var cmd = m.button === Qt.LeftButton ? "calendar" : "settings"
                    Quickshell.execDetached(["sh", "-c", "qs ipc call " + cmd + " toggle"])
                }
            }

            // one hover read for the whole island: true while the pointer is
            // anywhere in it, children included, so the shelf stays open while
            // you move across the chips
            HoverHandler {
                id: hover
                onHoveredChanged: root.hovering = hover.hovered
            }
        }
    }

    // persisted between runs: the shelf's whole point is that it survives the
    // trip between two apps, so it should survive the shell restarting too
    FileView {
        id: shelfState
        path: Quickshell.env("HOME") + "/.config/quickshell/state/shelf-state.json"
        printErrors: false
        onLoaded: {
            try {
                const arr = JSON.parse(text())
                if (Array.isArray(arr)) root.restore(arr)
            } catch (e) { console.warn("Shelf: bad state file: " + e) }
            root.stateReady = true
        }
        onLoadFailed: root.stateReady = true
    }

    Timer {
        id: saveTimer
        interval: 250
        onTriggered: if (root.stateReady) shelfState.setText(JSON.stringify(root.items))
    }

    Process {
        id: pruneProc
        stdout: StdioCollector {
            onStreamFinished: {
                const dead = text.split("\u0000").filter(function (p) { return p !== "" })
                if (dead.length === 0) return
                root.items = root.items.filter(function (it) { return dead.indexOf(it.path) < 0 })
                saveTimer.restart()
                console.log("shelf: dropped " + dead.length + " vanished item(s)")
            }
        }
    }

    IpcHandler {
        target: "shelf"
        // put the newest item on the clipboard without touching the UI — the
        // path that still works when a grab (rofi) owns the pointer
        function grabLast(): void {
            if (root.items.length > 0) root.copyUri(root.items.length - 1)
        }
        // hold a file from the command line: `qs ipc call shelf hold <path>`
        function hold(path: string): void {
            if (path === "") return
            root.addUrls(["file://" + path])
        }
        // deliver the newest held file to whatever has focus, for a keybind or
        // a script: `qs ipc call shelf paste`
        function paste(): void {
            if (root.items.length > 0) root.pasteAt(root.items.length - 1)
        }
        function toggle(): void { root.peek = !root.peek }
        function clear(): void { root.items = []; saveTimer.restart() }
        function list(): string { return JSON.stringify(root.items) }
    }
}
