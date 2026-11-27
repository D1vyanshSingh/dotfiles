import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Desktop wall — a glass tile cluster over the wallpaper, composed on a grid.
// The compositor blurs the wallpaper behind these surfaces (see hypr/rules.lua),
// so every tile paints at low alpha and carries a 1px light stroke for its edge.
Scope {
    id: root

    // ───────────────────────── tuning ─────────────────────────
    property bool hideWhenBusy: false
    property int edge: 48
    property int topOffset: 76
    property int gap: 12
    property int leftWidth: 480
    property int rightWidth: 480
    property int maxTodos: 5

    readonly property string mono: Theme.iconFont
    readonly property string display: "Iosevka NF"
    readonly property string todoPath: Quickshell.env("HOME") + "/.config/quickshell/state/todo-state.json"
    readonly property string themeState: Quickshell.env("HOME") + "/.local/state/43pr/state.json"

    // ── the wall itself ──
    // tiles sit straight on the wallpaper, so their material follows that image
    // rather than the UI palette. Type stays white, which means the card has to
    // get denser as the wall gets brighter — on a bright wall the compositor's
    // blur turns a thin tile to fog and the labels vanish into it.
    property string wallPath: ""
    property real wallLum: 0.12
    readonly property string wallUrl: root.wallPath !== "" ? "file://" + root.wallPath : ""
    readonly property color ink: "#ffffff"
    readonly property real tileDensity: Math.min(0.84, 0.50 + 0.36 * Math.min(1, root.wallLum))
    readonly property color tileFill: Qt.rgba(0.07, 0.072, 0.085, root.tileDensity)
    readonly property color tileStroke: root.inkA(0.10)

    function inkA(a) { return Qt.rgba(1, 1, 1, a) }
    function inkCss(a) { return "rgba(255,255,255," + a + ")" }

    // ───────────────────────── state ─────────────────────────
    property bool userHidden: false
    property int winCount: 0

    property string clock: "00:00"
    property string dateStr: ""
    property string uptimeStr: ""
    property string dayNum: ""
    property string monthShort: ""
    property string dowShort: ""

    property var todoItems: []
    property int todoLeft: 0

    property var calCells: []
    property int calRows: 6
    property string monthStr: ""
    // what the agenda has written down, read straight from its state file: the
    // tile only needs the days, not the words
    property var calMarks: []

    // the datesheet, recounted once a day rather than once a second
    property var examRows: []
    property var examNext: null
    property int examDays: -1
    property string examDayKey: ""

    function pad2(n) { return (n < 10 ? "0" : "") + n }

    function dayHasEvent(day) {
        if (day < 1) return false
        var d = new Date()
        var full = d.getFullYear() + "-" + root.pad2(d.getMonth() + 1) + "-" + root.pad2(day)
        var md = root.pad2(d.getMonth() + 1) + "-" + root.pad2(day)
        for (var i = 0; i < root.calMarks.length; i++) {
            var e = root.calMarks[i]
            if (!e || typeof e.date !== "string" || e.date.length < 10) continue
            if (e.bday === true ? e.date.substring(5) === md : e.date === full) return true
        }
        return false
    }

    property var player: null
    property string artUrl: ""

    property real ramPct: 0
    property real volPct: 0
    property real batPct: 0
    property bool charging: false

    readonly property bool wantVisible: !root.userHidden && (!root.hideWhenBusy || root.winCount === 0)
    readonly property bool hasTrack: player !== null && player.trackTitle !== undefined && player.trackTitle !== ""
    readonly property bool showArt: hasTrack && artUrl !== ""

    // ───────────────────────── helpers ─────────────────────────
    function refreshClock() {
        var d = new Date()
        root.clock = Qt.formatTime(d, "HH:mm")
        root.dateStr = Qt.formatDate(d, "ddd, d MMM").toUpperCase()
        root.buildCalendar()
        root.buildExams()
    }

    // one row per paper, with the day count against today's local midnight. The
    // first paper still ahead is the one the hero counts down to.
    function buildExams() {
        var now = new Date()
        var key = now.getFullYear() + "-" + (now.getMonth() + 1) + "-" + now.getDate()
        if (key === root.examDayKey) return
        root.examDayKey = key

        var list = ExamDays.exams
        var rows = []
        var next = null
        for (var i = 0; i < list.length; i++) {
            var e = list[i]
            var left = ExamDays.daysUntil(e.date)
            var row = {
                subject: e.subject,
                date: ExamDays.shortDate(e.date),
                dow: ExamDays.dow(e.date),
                days: left,
                past: left < 0,
                next: false
            }
            if (next === null && left >= 0) {
                next = row
                row.next = true
            }
            rows.push(row)
        }
        root.examRows = rows
        root.examNext = next
        root.examDays = next === null ? -1 : next.days
    }

    function buildCalendar() {
        var now = new Date()
        var y = now.getFullYear()
        var m = now.getMonth()
        var first = new Date(y, m, 1)
        var startDow = (first.getDay() + 6) % 7
        var days = new Date(y, m + 1, 0).getDate()
        var rows = Math.ceil((startDow + days) / 7)
        var cells = []
        for (var i = 0; i < rows * 7; i++) {
            var n = i - startDow + 1
            cells.push({ day: n, current: n >= 1 && n <= days, today: n === now.getDate() })
        }
        root.calCells = cells
        root.calRows = rows
        root.monthStr = Qt.formatDate(first, "MMMM").toUpperCase()
        root.dayNum = Qt.formatDate(now, "dd")
        root.monthShort = Qt.formatDate(now, "MMM").toUpperCase()
        root.dowShort = Qt.formatDate(now, "ddd").toUpperCase()
    }

    function parseTodos(raw) {
        var items = []
        try {
            var data = JSON.parse(raw)
            var arr = Array.isArray(data) ? data : (data.items || [])
            for (var i = 0; i < arr.length; i++)
                if (typeof arr[i].title === "string" && arr[i].done !== true)
                    items.push(arr[i].title)
        } catch (e) {
            console.warn("desktop wall: could not read todo state:", e)
        }
        root.todoLeft = items.length
        root.todoItems = items.slice(0, root.maxTodos)
    }

    function parseRam(raw) {        var total = 0, avail = 0
        var lines = raw.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].indexOf("MemTotal:") === 0) total = parseInt(lines[i].replace(/\D/g, ""))
            if (lines[i].indexOf("MemAvailable:") === 0) avail = parseInt(lines[i].replace(/\D/g, ""))
        }
        if (total > 0) root.ramPct = Math.round(((total - avail) / total) * 100)
    }

    function pickPlayer() {
        var list = Mpris.players
        if (!list) return null
        var arr = list.values !== undefined ? list.values : list
        if (!arr || arr.length === undefined) return null
        for (var i = 0; i < arr.length; i++)
            if (arr[i].playbackState === MprisPlaybackState.Playing) return arr[i]
        return arr.length > 0 ? arr[0] : null
    }

    function fmtSecs(s) {
        s = Math.max(0, Math.floor(Number(s) || 0))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    function refreshPlayer() {
        var p = root.pickPlayer()
        root.player = p
        var art = p && p.trackArtUrl ? String(p.trackArtUrl) : ""
        if (art !== root.artUrl) root.artUrl = art
    }

    function readWallpaper(raw) {
        try {
            var st = JSON.parse(raw)
            var p = st && st.wallpaper ? String(st.wallpaper) : ""
            if (p !== "" && p !== root.wallPath) {
                root.wallPath = p
                pLum.running = true
            }
        } catch (e) {
            console.warn("desktop wall: malformed theme state: " + e)
        }
    }

    // ───────────────────────── data ─────────────────────────
    FileView {
        id: themeStateFile
        path: root.themeState
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.readWallpaper(text())
        onLoadFailed: console.warn("desktop wall: theme state not readable at " + root.themeState)
    }

    Process {
        id: pLum
        running: false
        command: ["magick", root.wallPath, "-colorspace", "Gray", "-resize", "1x1",
                  "-format", "%[fx:mean]", "info:"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseFloat(text)
                if (!isNaN(v)) root.wallLum = v
            }
        }
    }

    FileView {
        id: todoStore
        path: root.todoPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.parseTodos(text())
        onLoadFailed: { root.todoLeft = 0; root.todoItems = [] }
    }

    Process {
        id: pRam
        running: false
        command: ["cat", "/proc/meminfo"]
        stdout: StdioCollector { onStreamFinished: root.parseRam(text) }
    }

    Process {
        id: pUptime
        running: false
        // uptime -p gives "up 1 hour, 7 minutes"; keep one space between the
        // units and zero-pad the minutes, so the clock reads "1H 07M" instead
        // of the ambiguous "1H7M"
        command: ["sh", "-c", "uptime -p | sed -E 's/^up //; s/ hours?/h/; s/ minutes?/m/; s/ days?/d/; s/,//g; s/ ([0-9])m$/ 0\\1m/'"]
        stdout: StdioCollector { onStreamFinished: root.uptimeStr = text.trim().toUpperCase() }
    }

    Process {
        id: pWindows
        running: false
        command: ["sh", "-c", "hyprctl activeworkspace -j 2>/dev/null | jq -r .windows"]
        stdout: StdioCollector { onStreamFinished: root.winCount = Math.max(0, parseInt(text.trim()) || 0) }
    }

    Process {
        id: openTodoPanel
        running: false
        command: ["qs", "ipc", "call", "todo", "toggle"]
    }

    Process {
        id: openDatesheet
        running: false
        command: ["qs", "ipc", "call", "datesheet", "toggle"]
    }

    Timer {
        interval: 1000
        running: !root.userHidden
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.refreshClock()
            root.refreshPlayer()
            pWindows.running = true
        }
    }

    Timer {
        interval: 5000
        running: !root.userHidden
        repeat: true
        triggeredOnStart: true
        onTriggered: pRam.running = true
    }

    Timer {
        interval: 30000
        running: !root.userHidden
        repeat: true
        triggeredOnStart: true
        onTriggered: pUptime.running = true
    }

    // volume + battery come from services, not processes
    Connections {
        target: Pipewire.defaultAudioSink
        function onAudioChanged() { root.updateVol() }
    }

    function updateVol() {
        var sink = Pipewire.defaultAudioSink
        root.volPct = sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    }

    Connections {
        target: UPower.displayDevice
        function onPercentageChanged() { root.batPct = Math.round(UPower.displayDevice.percentage * 100) }
        function onStateChanged() { root.charging = UPower.displayDevice.state === UPowerDeviceState.Charging }
    }

    Component.onCompleted: {
        root.refreshClock()
        root.updateVol()
        root.batPct = Math.round(UPower.displayDevice.percentage * 100)
        root.charging = UPower.displayDevice.state === UPowerDeviceState.Charging
    }

    IpcHandler {
        target: "desktop"
        function toggle(): void { root.userHidden = !root.userHidden }
        function show(): void { root.userHidden = false }
        function hide(): void { root.userHidden = true }
    }

    FileView {
        id: calStore
        path: Quickshell.env("HOME") + "/.config/quickshell/state/calendar-state.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var data = JSON.parse(text())
                var arr = Array.isArray(data) ? data : (data.events || [])
                root.calMarks = Array.isArray(arr) ? arr : []
            } catch (e) {
                root.calMarks = []
            }
        }
        onLoadFailed: root.calMarks = []
    }

    // ───────────────────────── pieces ─────────────────────────
    component Tile: Rectangle {
        id: tile
        property string label: ""
        property string badge: ""
        property string photo: ""       // explicit file: album art, sleeves
        property bool wallCrop: false   // take the image from the current wall
        property real cropZoom: 2.2
        property real cropX: 0.5        // 0–1 across the overflow the crop hides
        property real cropY: 0.5
        property real scrimTop: 0.12
        property real scrimBottom: 0.72
        // extra weight at the very bottom, where the type sits. tiles whose
        // caption crosses a bright part of the image set this and keep their
        // artwork legible everywhere else
        property real bottomScrim: 0
        default property alias content: body.data

        radius: Theme.radiusTile
        color: root.tileFill
        border.width: 1
        border.color: root.tileStroke

        Item {
            id: photoBox
            anchors.fill: parent
            clip: true
            visible: tile.photo !== "" || tile.wallCrop
            layer.enabled: visible
            layer.effect: OpacityMask { maskSource: mask }

            Image {
                id: pimg
                source: tile.photo !== "" ? tile.photo
                                           : (tile.wallCrop ? root.wallUrl : "")
                width: tile.wallCrop ? tile.width * tile.cropZoom : tile.width
                height: tile.wallCrop ? tile.height * tile.cropZoom : tile.height
                x: tile.wallCrop ? -(width - tile.width) * tile.cropX : 0
                y: tile.wallCrop ? -(height - tile.height) * tile.cropY : 0
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            // the mask rides on the clipped container, so a panned wall crop and
            // a square album cover round the same way
            Rectangle {
                id: mask
                width: tile.width
                height: tile.height
                radius: tile.radius
                visible: false
                layer.enabled: true
            }

            Rectangle {
                anchors.fill: parent
                radius: tile.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, tile.scrimTop) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, tile.scrimBottom) }
                }
            }

            Rectangle {
                visible: tile.bottomScrim > 0
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 92
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, tile.bottomScrim) }
                }
            }
        }

        Text {
            id: labelText
            anchors { top: parent.top; left: parent.left; leftMargin: 20; topMargin: 16 }
            text: tile.label
            color: root.inkA(0.55)
            font.family: root.mono
            font.pixelSize: 9
            font.letterSpacing: 3
            visible: tile.label !== ""
        }

        Text {
            anchors { top: parent.top; right: parent.right; rightMargin: 20; topMargin: 16 }
            text: tile.badge
            color: root.inkA(0.38)
            font.family: root.mono
            font.pixelSize: 9
            font.letterSpacing: 2
            visible: tile.badge !== ""
        }

        Item {
            id: body
            anchors.fill: parent
        }
    }

    // small ring gauge, drawn rather than font-dependent
    component Ring: Item {
        id: ring
        property real value: 0
        property string caption: ""
        property string reading: ""
        width: 62
        height: 78

        Canvas {
            id: canvas
            width: 62
            height: 62
            anchors.horizontalCenter: parent.horizontalCenter
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.lineWidth = 3
                ctx.lineCap = "round"
                var r = 27
                var cx = 31, cy = 31
                ctx.strokeStyle = root.inkCss("0.14")
                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.stroke()
                ctx.strokeStyle = root.inkCss("0.88")
                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0, Math.min(1, ring.value / 100)))
                ctx.stroke()
            }
            Connections {
                target: ring
                function onValueChanged() { canvas.requestPaint() }
            }
            Component.onCompleted: requestPaint()
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: canvas.top
            anchors.topMargin: 21
            text: ring.reading
            color: root.ink
            font.family: root.mono
            font.pixelSize: 12
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: canvas.bottom
            anchors.topMargin: 2
            text: ring.caption
            color: root.inkA(0.4)
            font.family: root.mono
            font.pixelSize: 8
            font.letterSpacing: 2
        }
    }

    // ───────────────────────── left cluster ─────────────────────────
    PanelWindow {
        id: leftWindow
        anchors { top: true; left: true }
        margins { top: root.topOffset; left: root.edge }
        implicitWidth: root.leftWidth
        implicitHeight: leftColumn.implicitHeight
        color: "transparent"
        visible: contentLeft.opacity > 0.01
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "desktop-widgets-left"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item {
            id: contentLeft
            anchors.fill: parent
            opacity: root.wantVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            Column {
                id: leftColumn
                width: parent.width
                spacing: root.gap

                // ── clock ──
                Tile {
                    width: root.leftWidth
                    height: 196
                    wallCrop: true
                    cropZoom: 1.7
                    cropX: 0.62
                    cropY: 0.12
                    scrimTop: 0.30
                    scrimBottom: 0.55
                    // the date line crosses the bright dome of the helmet in
                    // the wall crop, so the bottom band carries extra weight
                    // and the artwork above it stays untouched
                    bottomScrim: 0.72

                    Text {
                        anchors { left: parent.left; leftMargin: 24; bottom: parent.bottom; bottomMargin: 54 }
                        text: root.clock
                        color: root.ink
                        font.family: root.display
                        font.weight: Font.ExtraLight
                        font.pixelSize: 96
                        font.letterSpacing: -6
                    }

                    Text {
                        anchors { left: parent.left; leftMargin: 27; bottom: parent.bottom; bottomMargin: 26 }
                        text: root.dowShort + " " + root.dayNum + " " + root.monthShort + " · " + root.uptimeStr
                        color: root.inkA(0.6)
                        font.family: root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 2
                    }
                }

                // ── date numeral + todo ──
                Row {
                    spacing: root.gap

                    Tile {
                        width: 152
                        height: 152
                        label: "TODAY"

                        Text {
                            anchors { left: parent.left; leftMargin: 20; bottom: parent.bottom; bottomMargin: 34 }
                            text: root.dayNum
                            color: root.ink
                            font.family: root.display
                            font.weight: Font.ExtraLight
                            font.pixelSize: 58
                            font.letterSpacing: -3
                        }

                        Text {
                            anchors { left: parent.left; leftMargin: 22; bottom: parent.bottom; bottomMargin: 18 }
                            text: root.monthShort + " · " + root.dowShort
                            color: root.inkA(0.45)
                            font.family: root.mono
                            font.pixelSize: 8
                            font.letterSpacing: 2
                        }
                    }

                    Item {
                        width: root.leftWidth - 152 - root.gap
                        height: 152

                        Tile {
                            anchors.fill: parent
                            label: "TODO"
                            badge: root.todoLeft > 0 ? root.todoLeft + " LEFT" : ""

                            Column {
                                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 20; rightMargin: 20; topMargin: 46 }
                                spacing: 9

                                Repeater {
                                    model: root.todoItems

                                    Item {
                                        required property var modelData
                                        width: parent.width
                                        height: 16

                                        Rectangle {
                                            id: box
                                            width: 8
                                            height: 8
                                            radius: 2
                                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                            color: "transparent"
                                            border.width: 1
                                            border.color: root.inkA(0.45)
                                        }

                                        Text {
                                            anchors {
                                                left: box.right; leftMargin: 10
                                                right: parent.right
                                                verticalCenter: parent.verticalCenter
                                            }
                                            text: modelData
                                            color: root.ink
                                            font.family: root.mono
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                }

                                Text {
                                    visible: root.todoItems.length === 0
                                    text: "nothing planned"
                                    color: root.inkA(0.4)
                                    font.family: root.mono
                                    font.pixelSize: 11
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: openTodoPanel.running = true
                        }
                    }
                }

                // ── portrait + signature ──
                // the photo is pre-cropped to this tile's 1.56 aspect and
                // desaturated to the wall's own white-on-black register, so it
                // reads as part of the wall rather than a pasted-in picture
                Row {
                    spacing: root.gap

                    Tile {
                        width: root.leftWidth - 234 - root.gap
                        height: 150
                        // carti.png is 640x410, the same 1.56 aspect as this
                        // slot, so the crop takes nothing off the frame
                        photo: Qt.resolvedUrl("assets/carti.png")
                        scrimTop: 0.18
                        scrimBottom: 0.42
                    }

                    Tile {
                        width: 234
                        height: 150

                        Column {
                            anchors.centerIn: parent
                            spacing: 9

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "STAY NARC"
                                color: root.inkA(0.88)
                                font.family: root.mono
                                font.pixelSize: 15
                                font.letterSpacing: 6
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 26
                                height: 1
                                color: root.inkA(0.22)
                            }
                        }
                    }
                }

                // ── sleeves ──
                // square so the artwork sits uncropped: a landscape crop would
                // slice the letterforms off the swag print
                Row {
                    spacing: root.gap

                    Tile {
                        width: 234
                        height: 234
                        photo: Qt.resolvedUrl("assets/swag.png")
                        scrimTop: 0
                        scrimBottom: 0
                    }

                    Tile {
                        width: 234
                        height: 234
                        photo: Qt.resolvedUrl("assets/iam-music.png")
                        scrimTop: 0
                        scrimBottom: 0
                    }
                }

                // ── work harder ──
                // a mindset poster: the frame cropped square to the face and
                // the stacks, the line set like it was stamped on
                Tile {
                    width: root.leftWidth
                    height: 168

                    Item {
                        id: grindPhoto
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 168
                        clip: true
                        layer.enabled: true
                        layer.effect: OpacityMask { maskSource: grindMask }

                        Image {
                            anchors.fill: parent
                            source: Qt.resolvedUrl("assets/work-harder.png")
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        // the print is dark already; a whisper of extra weight at
                        // the foot keeps it from floating over the wallpaper
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.30) }
                            }
                        }

                        Rectangle {
                            id: grindMask
                            width: grindPhoto.width
                            height: grindPhoto.height
                            radius: Theme.radiusTile
                            visible: false
                            layer.enabled: true
                        }
                    }

                    Column {
                        anchors {
                            left: grindPhoto.right; leftMargin: 16
                            right: parent.right; rightMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 9

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "NOBODY CARES"
                            color: root.inkA(0.88)
                            font.family: root.mono
                            font.pixelSize: 15
                            font.letterSpacing: 6
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 26
                            height: 1
                            color: root.inkA(0.22)
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: "WORK HARDER"
                            color: root.inkA(0.62)
                            font.family: root.mono
                            font.pixelSize: 10
                            font.letterSpacing: 4
                        }
                    }
                }
            }
        }
    }

    // ───────────────────────── right cluster ─────────────────────────
    PanelWindow {
        id: rightWindow
        anchors { top: true; right: true }
        margins { top: root.topOffset; right: root.edge }
        implicitWidth: root.rightWidth
        implicitHeight: rightColumn.implicitHeight
        color: "transparent"
        visible: contentRight.opacity > 0.01
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "desktop-widgets-right"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item {
            id: contentRight
            anchors.fill: parent
            opacity: root.wantVisible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            Column {
                id: rightColumn
                width: parent.width
                spacing: root.gap

                // ── now playing, art bleeding under the controls ──
                Tile {
                    width: root.rightWidth
                    height: 296
                    label: "NOW PLAYING"
                    photo: root.showArt ? root.artUrl : ""
                    wallCrop: !root.showArt
                    cropZoom: 1.4
                    cropX: 0.5
                    cropY: 0.35
                    scrimTop: 0.42
                    scrimBottom: 0.88

                    Column {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 22; rightMargin: 22; bottomMargin: 20 }
                        spacing: 12

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 26
                            visible: root.player !== null

                            Text {
                                text: "\u25C0\u25C0"
                                color: root.inkA(0.7)
                                font.family: root.mono
                                font.pixelSize: 15
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -8
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.previous()
                                }
                            }

                            Text {
                                text: root.player && root.player.isPlaying ? "\u25AE\u25AE" : "\u25B6"
                                color: root.ink
                                font.family: root.mono
                                font.pixelSize: 26
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -8
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.togglePlaying()
                                }
                            }

                            Text {
                                text: "\u25B6\u25B6"
                                color: root.inkA(0.7)
                                font.family: root.mono
                                font.pixelSize: 15
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -8
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.player) root.player.next()
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 3

                            Text {
                                width: parent.width
                                text: root.hasTrack ? root.player.trackTitle : "nothing playing"
                                color: root.hasTrack ? root.ink : root.inkA(0.4)
                                font.family: root.mono
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                visible: root.player && root.player.trackArtist
                                text: root.player ? (root.player.trackArtist || "") : ""
                                color: root.inkA(0.55)
                                font.family: root.mono
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        Item {
                            width: parent.width
                            height: 12
                            visible: root.player !== null && root.player.length > 0

                            Rectangle {
                                id: bar
                                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 3 }
                                height: 2
                                radius: 1
                                color: root.inkA(0.18)

                                Rectangle {
                                    height: 2
                                    radius: 1
                                    color: root.inkA(0.9)
                                    width: {
                                        var p = root.player
                                        if (!p || !p.length || p.length <= 0) return 0
                                        return bar.width * Math.max(0, Math.min(1, p.position / p.length))
                                    }
                                }
                            }

                            Text {
                                anchors { left: parent.left; bottom: parent.bottom }
                                text: root.fmtSecs(root.player ? root.player.position : 0)
                                color: root.inkA(0.4)
                                font.family: root.mono
                                font.pixelSize: 8
                            }

                            Text {
                                anchors { right: parent.right; bottom: parent.bottom }
                                text: "-" + root.fmtSecs(root.player ? Math.max(0, (root.player.length || 0) - (root.player.position || 0)) : 0)
                                color: root.inkA(0.4)
                                font.family: root.mono
                                font.pixelSize: 8
                            }
                        }
                    }
                }

                // ── calendar + rings ──
                Row {
                    spacing: root.gap

                    Tile {
                        width: 234
                        height: 214
                        label: "CALENDAR"
                        badge: calHover.hovered ? "OPEN \u203A" : root.monthStr

                        // the tile is a door: its edge brightens under the
                        // pointer and a click opens the agenda on the month it
                        // is already showing
                        HoverHandler { id: calHover }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusTile
                            color: "transparent"
                            border.width: 1
                            border.color: root.inkA(0.30)
                            opacity: calHover.hovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached(["qs", "ipc", "call", "agenda", "toggle"])
                        }

                        Column {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 18; rightMargin: 18; bottomMargin: 16 }
                            spacing: 6

                            Item {
                                width: parent.width
                                height: 10

                                Repeater {
                                    model: ["M", "T", "W", "T", "F", "S", "S"]
                                    Text {
                                        required property int index
                                        required property string modelData
                                        width: (234 - 36) / 7
                                        x: index * width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData
                                        color: root.inkA(0.34)
                                        font.family: root.mono
                                        font.pixelSize: 8
                                    }
                                }
                            }

                            Item {
                                width: parent.width
                                height: root.calRows * 21

                                Repeater {
                                    model: root.calCells

                                    Item {
                                        required property int index
                                        required property var modelData
                                        width: (234 - 36) / 7
                                        height: 21
                                        x: (index % 7) * width
                                        y: Math.floor(index / 7) * height

                                        Rectangle {
                                            visible: modelData.today
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            radius: 6
                                            color: root.inkA(0.1)
                                            border.width: 1
                                            border.color: root.inkA(0.55)
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: -2
                                            visible: modelData.current
                                            text: modelData.day
                                            color: modelData.today ? root.ink : root.inkA(0.62)
                                            font.family: root.mono
                                            font.pixelSize: 9
                                            font.bold: modelData.today
                                        }

                                        // a day with something on it keeps a
                                        // dot, so the wall is worth glancing at
                                        Rectangle {
                                            visible: modelData.current && root.dayHasEvent(modelData.day)
                                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                                            width: 3
                                            height: 3
                                            radius: 1.5
                                            color: root.inkA(modelData.today ? 0.85 : 0.45)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Tile {
                        width: 234
                        height: 246
                        label: "SYSTEM"

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Ring { value: root.ramPct; caption: "RAM"; reading: Math.round(root.ramPct) + "%" }
                            Ring { value: root.volPct; caption: "VOL"; reading: root.volPct + "%" }
                            Ring {
                                value: root.batPct
                                caption: root.charging ? "CHRG" : "BAT"
                                reading: root.batPct + "%"
                            }
                        }
                    }
                }

                // ── datesheet ──
                // the next paper counted big, then the whole sheet in order.
                // the tile is a door: a click opens the syllabus behind it.
                Tile {
                    width: root.rightWidth
                    height: 252
                    label: "DATESHEET"
                    badge: root.examDays < 0 ? "CLEAR" : (root.examDays === 0 ? "TODAY" : "IN " + root.examDays + "D")

                    HoverHandler { id: dsHover }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusTile
                        color: "transparent"
                        border.width: 1
                        border.color: root.inkA(0.30)
                        opacity: dsHover.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: openDatesheet.running = true
                    }

                    Item {
                        id: examHero
                        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 20; rightMargin: 20; topMargin: 38 }
                        height: 56

                        Text {
                            id: examNum
                            anchors { left: parent.left; bottom: parent.bottom; bottomMargin: -8 }
                            text: root.examDays < 0 ? "\u2014" : root.examDays
                            color: root.ink
                            font.family: root.display
                            font.weight: Font.ExtraLight
                            font.pixelSize: 52
                            font.letterSpacing: -3
                        }

                        Column {
                            anchors { left: examNum.right; leftMargin: 14; bottom: parent.bottom; bottomMargin: 6 }
                            spacing: 3

                            Text {
                                text: "DAYS TO"
                                color: root.inkA(0.34)
                                font.family: root.mono
                                font.pixelSize: 7
                                font.letterSpacing: 2
                            }

                            Text {
                                text: root.examNext ? root.examNext.subject : "NOTHING LEFT"
                                color: root.inkA(0.92)
                                font.family: root.mono
                                font.pixelSize: 14
                                font.letterSpacing: 4
                            }

                            Text {
                                text: root.examNext ? root.examNext.dow + " " + root.examNext.date : ""
                                color: root.inkA(0.38)
                                font.family: root.mono
                                font.pixelSize: 8
                                font.letterSpacing: 1
                            }
                        }
                    }

                    Column {
                        anchors { left: parent.left; right: parent.right; top: examHero.bottom; topMargin: 6; leftMargin: 20; rightMargin: 20 }
                        spacing: 0

                        Repeater {
                            model: root.examRows

                            Item {
                                id: examRow
                                required property var modelData
                                width: parent.width
                                height: 27

                                Rectangle {
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                    height: 1
                                    color: root.inkA(0.05)
                                }

                                Rectangle {
                                    id: examMark
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                    width: 3
                                    height: 3
                                    radius: 1.5
                                    color: examRow.modelData.next ? root.inkA(0.9)
                                         : root.inkA(examRow.modelData.past ? 0.16 : 0.4)
                                }

                                Text {
                                    anchors { left: examMark.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
                                    text: examRow.modelData.subject
                                    color: examRow.modelData.past ? root.inkA(0.26)
                                         : root.inkA(examRow.modelData.next ? 0.95 : 0.68)
                                    font.family: root.mono
                                    font.pixelSize: 10
                                    font.letterSpacing: 2
                                }

                                Text {
                                    id: examDaysText
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    text: examRow.modelData.days < 0 ? "DONE"
                                         : (examRow.modelData.days === 0 ? "TODAY" : examRow.modelData.days + "D")
                                    color: examRow.modelData.days === 0 ? root.ink
                                         : root.inkA(examRow.modelData.past ? 0.18 : 0.42)
                                    font.family: root.mono
                                    font.pixelSize: 8
                                    font.letterSpacing: 1
                                }

                                Text {
                                    anchors { right: examDaysText.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                    text: examRow.modelData.date
                                    color: root.inkA(examRow.modelData.past ? 0.16 : 0.3)
                                    font.family: root.mono
                                    font.pixelSize: 8
                                    font.letterSpacing: 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
