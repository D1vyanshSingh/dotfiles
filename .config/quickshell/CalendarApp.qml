import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// ── agenda ──
// The wall's calendar tile is a glance, not a place to write. This is the place:
// click the tile, pick a day, type a title and press return. Everything lands in
// calendar-state.json next to the todo and shelf state, and the days that hold
// something keep a dot on the tile so the wall still tells the truth at a glance.
//
// A birthday is the one kind of event that repeats: it is stored with the year
// it was written down, but it is matched by month and day afterwards, so a date
// entered once keeps coming back.
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "calendar-app"
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.showing ? backdrop : null }

    property bool showing: false
    property bool ready: false
    property bool bdayMode: false

    property int viewYear: 2026
    property int viewMonth: 0
    property string selectedKey: ""

    // { id, date: "YYYY-MM-DD", time: "HH:MM" | "", title: "...", bday: bool }
    property var events: []

    readonly property string mono: Theme.fontFamily
    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/calendar-state.json"

    readonly property color cardFill: Qt.rgba(0.055, 0.057, 0.066, 0.93)
    readonly property color hair: Qt.rgba(1, 1, 1, 0.09)
    readonly property color ink: "#ffffff"
    readonly property string todayKey: {
        var d = new Date()
        return root.keyOf(d.getFullYear(), d.getMonth(), d.getDate())
    }

    function inkA(a) { return Qt.rgba(1, 1, 1, a) }
    function pad2(n) { return (n < 10 ? "0" : "") + n }
    function keyOf(y, m, d) { return y + "-" + root.pad2(m + 1) + "-" + root.pad2(d) }
    function dateOf(k) {
        var p = String(k).split("-")
        if (p.length !== 3) return new Date()
        return new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]))
    }

    // "930" and "9:30" and "21" all mean something; anything else is all day
    function normTime(raw) {
        var digits = String(raw).replace(/\D/g, "")
        if (digits === "") return ""
        if (digits.length <= 2) {
            var h = parseInt(digits)
            return (h > 23 ? "" : root.pad2(h) + ":00")
        }
        if (digits.length === 3) digits = "0" + digits
        if (digits.length > 4) return ""
        var hh = parseInt(digits.substring(0, 2))
        var mm = parseInt(digits.substring(2, 4))
        if (hh > 23 || mm > 59) return ""
        return root.pad2(hh) + ":" + root.pad2(mm)
    }

    function matches(e, k) {
        if (!e || typeof e.date !== "string" || e.date.length < 10) return false
        if (e.bday === true) return e.date.substring(5) === k.substring(5)
        return e.date === k
    }

    function eventsFor(k) {
        var out = []
        if (k === "") return out
        for (var i = 0; i < root.events.length; i++)
            if (root.matches(root.events[i], k)) out.push(root.events[i])
        out.sort(function (a, b) {
            var ta = a.time || "", tb = b.time || ""
            if (ta === tb) return String(a.title) < String(b.title) ? -1 : 1
            if (ta === "") return -1
            if (tb === "") return 1
            return ta < tb ? -1 : 1
        })
        return out
    }

    function dayDotCount(k) {
        var n = 0
        for (var i = 0; i < root.events.length; i++)
            if (root.matches(root.events[i], k)) n++
        return Math.min(3, n)
    }

    function buildCells() {
        var y = root.viewYear, m = root.viewMonth
        var offset = (new Date(y, m, 1).getDay() + 6) % 7
        var out = []
        for (var i = 0; i < 42; i++) {
            var d = new Date(y, m, i - offset + 1)
            var k = root.keyOf(d.getFullYear(), d.getMonth(), d.getDate())
            out.push({
                day: d.getDate(),
                key: k,
                inMonth: d.getMonth() === m,
                isToday: k === root.todayKey,
                selected: k === root.selectedKey,
                dots: root.dayDotCount(k)
            })
        }
        return out
    }

    function upcoming(limit) {
        var out = []
        var tk = root.todayKey
        var year = parseInt(tk.substring(0, 4))
        for (var i = 0; i < root.events.length; i++) {
            var e = root.events[i]
            if (!e || typeof e.date !== "string" || e.date.length < 10) continue
            var k = e.date
            if (e.bday === true) {
                k = year + "-" + e.date.substring(5)
                if (k < tk) k = (year + 1) + "-" + e.date.substring(5)
            }
            if (k < tk) continue
            out.push({ key: k, time: e.time || "", title: e.title, bday: e.bday === true })
        }
        out.sort(function (a, b) {
            if (a.key !== b.key) return a.key < b.key ? -1 : 1
            var ta = a.time, tb = b.time
            if (ta === tb) return 0
            if (ta === "") return -1
            if (tb === "") return 1
            return ta < tb ? -1 : 1
        })
        return out.slice(0, limit)
    }

    readonly property var cells: root.buildCells()
    readonly property var selectedEvents: root.eventsFor(root.selectedKey)
    readonly property var upNext: root.upcoming(3)
    readonly property date selectedDate: root.dateOf(root.selectedKey)
    readonly property string monthLabel: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM").toUpperCase()

    // ── actions ──
    function saveNow() {
        store.setText(JSON.stringify(root.events))
    }

    function addEvent() {
        var title = titleInput.text.trim()
        if (title === "" || root.selectedKey === "") return
        var list = root.events.slice()
        list.push({
            id: "e" + Date.now() + Math.floor(Math.random() * 1000),
            date: root.selectedKey,
            time: root.bdayMode ? "" : root.normTime(timeInput.text),
            title: title,
            bday: root.bdayMode
        })
        root.events = list
        titleInput.text = ""
        timeInput.text = ""
        root.saveNow()
        titleInput.forceActiveFocus()
    }

    function removeEvent(id) {
        var list = []
        for (var i = 0; i < root.events.length; i++)
            if (root.events[i].id !== id) list.push(root.events[i])
        root.events = list
        root.saveNow()
    }

    function shiftMonth(delta) {
        var m = root.viewMonth + delta
        var y = root.viewYear
        while (m < 0) { m += 12; y -= 1 }
        while (m > 11) { m -= 12; y += 1 }
        root.viewMonth = m
        root.viewYear = y
    }

    function goToday() {
        var d = new Date()
        root.viewYear = d.getFullYear()
        root.viewMonth = d.getMonth()
        root.selectedKey = root.todayKey
    }

    function pick(k) {
        root.selectedKey = k
        var d = root.dateOf(k)
        if (d.getMonth() !== root.viewMonth || d.getFullYear() !== root.viewYear) {
            root.viewMonth = d.getMonth()
            root.viewYear = d.getFullYear()
        }
        titleInput.forceActiveFocus()
    }

    function open() {
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr) root.screen = scr
        }
        root.goToday()
        root.showing = true
        Qt.callLater(function () {
            if (root.showing) titleInput.forceActiveFocus()
        })
    }

    function close() { root.showing = false }
    function toggle() { root.showing ? root.close() : root.open() }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    // ‹ and › for the month, one shape used twice
    component NavBtn: Item {
        id: nb
        property string glyph: ""
        property int size: 20
        signal clicked()
        width: 24
        height: 22

        Text {
            anchors.centerIn: parent
            text: nb.glyph
            color: nbArea.containsMouse ? root.ink : root.inkA(0.5)
            font.family: root.mono
            font.pixelSize: nb.size
        }

        MouseArea {
            id: nbArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: nb.clicked()
        }
    }

    IpcHandler {
        target: "agenda"
        function toggle(): void { root.toggle() }
        function show(): void { root.open() }
        function hide(): void { root.close() }
        // `qs ipc call agenda add 2026-11-24 "Dentist" 09:30`
        function add(date: string, title: string, time: string): void {
            if (date === "" || title === "") return
            var list = root.events.slice()
            list.push({
                id: "e" + Date.now() + Math.floor(Math.random() * 1000),
                date: date,
                time: root.normTime(time),
                title: title,
                bday: false
            })
            root.events = list
            root.saveNow()
        }
    }

    FileView {
        id: store
        path: root.statePath
        printErrors: false
        onLoaded: {
            try {
                var data = JSON.parse(store.text())
                var arr = Array.isArray(data) ? data : (data.events || [])
                var out = []
                for (var i = 0; i < arr.length; i++) {
                    var e = arr[i]
                    if (!e || typeof e.title !== "string" || typeof e.date !== "string") continue
                    out.push({
                        id: typeof e.id === "string" ? e.id : ("e" + i + e.date),
                        date: e.date,
                        time: typeof e.time === "string" ? e.time : "",
                        title: e.title,
                        bday: e.bday === true
                    })
                }
                root.events = out
            } catch (e) {
                console.warn("agenda: could not read saved state:", e)
            }
            root.ready = true
        }
        onLoadFailed: root.ready = true
    }

    // click anywhere off the card and it goes away
    Item {
        id: backdrop
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(880, root.width - 96)
            height: Math.min(560, root.height - 120)
            radius: Theme.radiusTile
            color: root.cardFill
            border.width: 1
            border.color: root.inkA(0.13)
            opacity: root.showing ? 1 : 0
            scale: root.showing ? 1 : 0.985
            visible: opacity > 0.01

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            // swallows presses that land on the card's dead space, so a click
            // on the panel never reaches the dismiss area behind it
            MouseArea { anchors.fill: parent }

            Text {
                anchors { top: parent.top; left: parent.left; leftMargin: 28; topMargin: 22 }
                text: "CALENDAR"
                color: root.inkA(0.5)
                font.family: root.mono
                font.pixelSize: 9
                font.letterSpacing: 3
            }

            // ── close ──
            Item {
                id: closeBtn
                anchors { top: parent.top; right: parent.right; topMargin: 16; rightMargin: 18 }
                width: 26
                height: 26

                Rectangle {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    radius: 13
                    color: closeArea.containsMouse ? root.inkA(0.14) : "transparent"
                    Behavior on color { ColorAnimation { duration: 110 } }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 9
                    height: 1
                    rotation: 45
                    color: closeArea.containsMouse ? root.ink : root.inkA(0.45)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 9
                    height: 1
                    rotation: -45
                    color: closeArea.containsMouse ? root.ink : root.inkA(0.45)
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }

            // ───────────────────────── left: the month ─────────────────────────
            Item {
                id: leftPane
                anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
                anchors.topMargin: 52
                anchors.leftMargin: 28
                anchors.bottomMargin: 24
                width: 420

                Item {
                    id: monthRow
                    width: parent.width
                    height: 30

                    Text {
                        id: monthText
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: root.monthLabel
                        color: root.inkA(0.94)
                        font.family: root.mono
                        font.pixelSize: 22
                        font.letterSpacing: 6
                    }
                    Text {
                        anchors { left: monthText.right; leftMargin: 10; baseline: monthText.baseline }
                        text: root.viewYear
                        color: root.inkA(0.34)
                        font.family: root.mono
                        font.pixelSize: 11
                        font.letterSpacing: 3
                    }
                }

                // ‹ today ›
                Row {
                    anchors { right: parent.right; verticalCenter: monthRow.verticalCenter }
                    spacing: 4

                    NavBtn {
                        glyph: "\u2039"
                        onClicked: root.shiftMonth(-1)
                    }

                    Item {
                        width: todayText.width + 18
                        height: 22
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: 22
                            radius: 11
                            color: todayArea.containsMouse ? root.inkA(0.14) : "transparent"
                            border.width: 1
                            border.color: root.inkA(0.14)
                        }
                        Text {
                            id: todayText
                            anchors.centerIn: parent
                            text: "TODAY"
                            color: todayArea.containsMouse ? root.ink : root.inkA(0.55)
                            font.family: root.mono
                            font.pixelSize: 8
                            font.letterSpacing: 2
                        }
                        MouseArea {
                            id: todayArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.goToday()
                                titleInput.forceActiveFocus()
                            }
                        }
                    }

                    NavBtn {
                        glyph: "\u203A"
                        onClicked: root.shiftMonth(1)
                    }
                }

                // weekday heads
                Item {
                    id: weekRow
                    anchors { top: monthRow.bottom; topMargin: 18 }
                    width: parent.width
                    height: 12

                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        Text {
                            required property int index
                            required property string modelData
                            width: weekRow.width / 7
                            x: index * width
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: root.inkA(0.3)
                            font.family: root.mono
                            font.pixelSize: 9
                        }
                    }
                }

                // the grid
                Item {
                    id: grid
                    anchors { top: weekRow.bottom; topMargin: 10 }
                    width: parent.width
                    height: 6 * 46

                    WheelHandler {
                        onWheel: (e) => root.shiftMonth(e.angleDelta.y > 0 ? -1 : 1)
                    }

                    Repeater {
                        model: root.cells

                        Item {
                            id: cell
                            required property int index
                            required property var modelData
                            width: grid.width / 7
                            height: 46
                            x: (index % 7) * width
                            y: Math.floor(index / 7) * height

                            readonly property bool hot: cellArea.containsMouse || modelData.selected

                            Rectangle {
                                visible: modelData.isToday
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 12
                                color: "transparent"
                                border.width: 1
                                border.color: root.inkA(modelData.selected ? 0.85 : 0.45)
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 12
                                color: modelData.selected && !modelData.isToday ? root.inkA(0.12)
                                     : (cellArea.containsMouse ? root.inkA(0.07) : "transparent")
                                Behavior on color { ColorAnimation { duration: 110 } }
                            }

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -4
                                text: modelData.day
                                color: modelData.selected || modelData.isToday ? root.ink
                                     : (modelData.inMonth ? root.inkA(0.7) : root.inkA(0.22))
                                font.family: root.mono
                                font.pixelSize: 11
                                font.bold: modelData.isToday
                            }

                            Row {
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 5 }
                                spacing: 3

                                Repeater {
                                    model: modelData.dots
                                    Rectangle {
                                        required property int index
                                        width: 3
                                        height: 3
                                        radius: 1.5
                                        color: root.inkA(cell.modelData.selected ? 0.85 : 0.42)
                                    }
                                }
                            }

                            MouseArea {
                                id: cellArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pick(modelData.key)
                            }
                        }
                    }
                }

                // ── next up ──
                Item {
                    id: upNextBlock
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 74

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 1
                        color: root.hair
                    }

                    Text {
                        id: upNextLabel
                        anchors { left: parent.left; top: parent.top; topMargin: 12 }
                        text: "UP NEXT"
                        color: root.inkA(0.34)
                        font.family: root.mono
                        font.pixelSize: 8
                        font.letterSpacing: 2
                    }

                    Column {
                        anchors { left: parent.left; right: parent.right; top: upNextLabel.bottom; topMargin: 8 }
                        spacing: 4

                        Repeater {
                            model: root.upNext

                            Row {
                                required property var modelData
                                width: parent.width
                                spacing: 12

                                Text {
                                    width: 42
                                    text: Qt.formatDate(root.dateOf(modelData.key), "d MMM").toUpperCase()
                                    color: root.inkA(0.4)
                                    font.family: root.mono
                                    font.pixelSize: 8
                                    font.letterSpacing: 1
                                }
                                Text {
                                    width: parent.width - 54
                                    text: modelData.title + (modelData.bday ? "  ·  BDAY" : "")
                                    color: root.inkA(0.78)
                                    font.family: root.mono
                                    font.pixelSize: 9
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Text {
                        anchors { left: parent.left; top: parent.top; topMargin: 12 }
                        visible: root.upNext.length === 0
                        x: 0
                        text: "NOTHING ON THE HORIZON"
                        color: root.inkA(0.2)
                        font.family: root.mono
                        font.pixelSize: 8
                        font.letterSpacing: 2
                    }
                }
            }

            Rectangle {
                id: divider
                anchors { top: parent.top; bottom: parent.bottom; left: leftPane.right }
                anchors.topMargin: 24
                anchors.bottomMargin: 24
                anchors.leftMargin: 26
                width: 1
                color: root.hair
            }

            // ───────────────────────── right: one day ─────────────────────────
            Item {
                id: rightPane
                anchors { top: parent.top; bottom: parent.bottom; left: divider.right; right: parent.right }
                anchors.topMargin: 22
                anchors.bottomMargin: 20
                anchors.leftMargin: 26
                anchors.rightMargin: 28

                Text {
                    id: agendaLabel
                    text: "AGENDA"
                    color: root.inkA(0.34)
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                }

                Row {
                    id: dayHead
                    anchors { top: agendaLabel.bottom; topMargin: 2; left: parent.left; right: parent.right }
                    spacing: 16

                    Text {
                        text: root.pad2(root.selectedDate.getDate())
                        color: root.ink
                        font.family: root.mono
                        font.weight: Font.Light
                        font.pixelSize: 46
                        font.letterSpacing: -2
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: Qt.formatDate(root.selectedDate, "dddd").toUpperCase()
                            color: root.inkA(0.72)
                            font.family: root.mono
                            font.pixelSize: 10
                            font.letterSpacing: 2
                        }
                        Text {
                            text: (Qt.formatDate(root.selectedDate, "MMMM") + " " + root.selectedDate.getFullYear()).toUpperCase()
                            color: root.inkA(0.3)
                            font.family: root.mono
                            font.pixelSize: 8
                            font.letterSpacing: 2
                        }
                    }
                }

                Rectangle {
                    id: dayRule
                    anchors { top: dayHead.bottom; topMargin: 10; left: parent.left; right: parent.right }
                    height: 1
                    color: root.hair
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.selectedEvents.length === 0
                    text: "NO EVENTS"
                    color: root.inkA(0.2)
                    font.family: root.mono
                    font.pixelSize: 9
                    font.letterSpacing: 2
                }

                ListView {
                    id: eventList
                    anchors { top: dayRule.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: form.top }
                    anchors.bottomMargin: 10
                    clip: true
                    spacing: 0
                    model: root.selectedEvents
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: evRow
                        required property var modelData
                        required property int index
                        width: eventList.width
                        height: 34

                        HoverHandler { id: evHover }

                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 1
                            color: root.inkA(0.05)
                        }

                        Rectangle {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: 3
                            height: 3
                            radius: 1.5
                            color: root.inkA(modelData.bday ? 0.75 : 0.4)
                        }

                        Text {
                            anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                            width: 44
                            text: modelData.time !== "" ? modelData.time : "ALL DAY"
                            color: root.inkA(0.4)
                            font.family: root.mono
                            font.pixelSize: 8
                            font.letterSpacing: modelData.time !== "" ? 0 : 1
                        }

                        Text {
                            anchors { left: parent.left; leftMargin: 62; right: tag.visible ? tag.left : parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            text: modelData.title
                            color: root.inkA(0.86)
                            font.family: root.mono
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            id: tag
                            visible: modelData.bday
                            anchors { right: dismiss.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            width: tagText.implicitWidth + 12
                            height: 15
                            radius: 4
                            color: "transparent"
                            border.width: 1
                            border.color: root.inkA(0.2)

                            Text {
                                id: tagText
                                anchors.centerIn: parent
                                text: "BDAY"
                                color: root.inkA(0.5)
                                font.family: root.mono
                                font.pixelSize: 7
                                font.letterSpacing: 1
                            }
                        }

                        Item {
                            id: dismiss
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 18
                            height: 18
                            opacity: evHover.hovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 110 } }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                radius: 9
                                color: dismissArea.containsMouse ? root.inkA(0.16) : "transparent"
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 7
                                height: 1
                                rotation: 45
                                color: dismissArea.containsMouse ? root.ink : root.inkA(0.45)
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 7
                                height: 1
                                rotation: -45
                                color: dismissArea.containsMouse ? root.ink : root.inkA(0.45)
                            }

                            MouseArea {
                                id: dismissArea
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: evHover.hovered
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.removeEvent(modelData.id)
                            }
                        }
                    }
                }

                // ── the one thing to type in ──
                Item {
                    id: form
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 84

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        height: 1
                        color: root.hair
                    }

                    Row {
                        id: inputRow
                        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 14 }
                        spacing: 8

                        Rectangle {
                            id: timeField
                            width: 62
                            height: 32
                            radius: 8
                            color: root.inkA(0.05)
                            border.width: 1
                            border.color: timeInput.activeFocus ? root.inkA(0.4) : root.hair

                            TextInput {
                                id: timeInput
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 6
                                verticalAlignment: TextInput.AlignVCenter
                                color: root.inkA(0.9)
                                font.family: root.mono
                                font.pixelSize: 10
                                selectionColor: root.inkA(0.25)
                                selectedTextColor: "#000000"
                                clip: true
                                enabled: !root.bdayMode
                                opacity: root.bdayMode ? 0.35 : 1

                                onAccepted: root.addEvent()
                                onEditingFinished: text = root.normTime(text)
                                Keys.onEscapePressed: (e) => { root.close(); e.accepted = true }
                            }

                            Text {
                                anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
                                visible: timeInput.text === ""
                                text: root.bdayMode ? "—" : "18:30"
                                color: root.inkA(0.22)
                                font.family: root.mono
                                font.pixelSize: 10
                            }
                        }

                        Rectangle {
                            id: titleField
                            width: parent.width - timeField.width - addBtn.width - 16
                            height: 32
                            radius: 8
                            color: root.inkA(0.05)
                            border.width: 1
                            border.color: titleInput.activeFocus ? root.inkA(0.4) : root.hair

                            TextInput {
                                id: titleInput
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: root.inkA(0.92)
                                font.family: root.mono
                                font.pixelSize: 11
                                selectionColor: root.inkA(0.25)
                                selectedTextColor: "#000000"
                                clip: true

                                onAccepted: root.addEvent()
                                Keys.onEscapePressed: (e) => { root.close(); e.accepted = true }
                            }

                            Text {
                                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                                visible: titleInput.text === ""
                                text: root.bdayMode ? "whose birthday?" : "what is it?"
                                color: root.inkA(0.22)
                                font.family: root.mono
                                font.pixelSize: 11
                            }
                        }

                        Rectangle {
                            id: addBtn
                            width: 32
                            height: 32
                            radius: 8
                            color: addArea.containsMouse ? root.inkA(0.18) : root.inkA(0.06)
                            border.width: 1
                            border.color: root.inkA(0.14)
                            Behavior on color { ColorAnimation { duration: 110 } }

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -1
                                text: "+"
                                color: root.inkA(0.8)
                                font.family: root.mono
                                font.pixelSize: 15
                            }

                            MouseArea {
                                id: addArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.addEvent()
                            }
                        }
                    }

                    Row {
                        anchors { left: parent.left; right: parent.right; top: inputRow.bottom; topMargin: 10 }
                        spacing: 10

                        Rectangle {
                            id: bdayChip
                            height: 20
                            width: bdayChipText.implicitWidth + 20
                            radius: 10
                            color: root.bdayMode ? root.inkA(0.16) : "transparent"
                            border.width: 1
                            border.color: root.bdayMode ? root.inkA(0.45) : root.inkA(0.12)
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                id: bdayChipText
                                anchors.centerIn: parent
                                text: "BIRTHDAY · YEARLY"
                                color: root.bdayMode ? root.ink : root.inkA(0.4)
                                font.family: root.mono
                                font.pixelSize: 8
                                font.letterSpacing: 1
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.bdayMode = !root.bdayMode
                            }
                        }

                        Text {
                            anchors.verticalCenter: bdayChip.verticalCenter
                            text: "RETURN ADDS · ESC CLOSES"
                            color: root.inkA(0.18)
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
