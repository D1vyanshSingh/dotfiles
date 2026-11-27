import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// ── datesheet ──
// The wall's countdown tile is the glance; this is the paper behind it. Left:
// every exam in the order it falls, with the days left. Right: the units of the
// picked paper, each one a row that opens into the topics inside it. Escape or
// a click off the card closes it.
PanelWindow {
    id: root

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "datesheet-app"
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: root.showing ? backdrop : null }

    property bool showing: false
    property int selected: 0

    readonly property string mono: Theme.fontFamily
    readonly property color cardFill: Qt.rgba(0.055, 0.057, 0.066, 0.93)
    readonly property color hair: Qt.rgba(1, 1, 1, 0.09)
    readonly property var exams: ExamDays.exams
    readonly property var exam: (root.selected >= 0 && root.selected < root.exams.length) ? root.exams[root.selected] : null
    readonly property int topicTotal: ExamDays.topicCount(root.exam)

    function inkA(a) { return Qt.rgba(1, 1, 1, a) }

    function open() {
        // land on the next paper that has not been sat yet
        var i = 0
        for (var k = 0; k < root.exams.length; k++) {
            i = k
            if (ExamDays.daysUntil(root.exams[k].date) >= 0) break
        }
        root.selected = i
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr) root.screen = scr
        }
        root.showing = true
    }

    function close() { root.showing = false }
    function toggle() { root.showing ? root.close() : root.open() }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    IpcHandler {
        target: "datesheet"
        function toggle(): void { root.toggle() }
        function show(): void { root.open() }
        function hide(): void { root.close() }
        function select(subject: string): void {
            var want = subject.toLowerCase()
            for (var i = 0; i < root.exams.length; i++) {
                if (String(root.exams[i].subject).toLowerCase() === want) {
                    root.selected = i
                    return
                }
            }
        }
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
            width: Math.min(900, root.width - 96)
            height: Math.min(620, root.height - 120)
            radius: Theme.radiusTile
            color: root.cardFill
            border.width: 1
            border.color: root.inkA(0.13)
            opacity: root.showing ? 1 : 0
            scale: root.showing ? 1 : 0.985
            visible: opacity > 0.01

            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            // swallows presses that land on the card's dead space
            MouseArea { anchors.fill: parent }

            Text {
                anchors { top: parent.top; left: parent.left; leftMargin: 28; topMargin: 22 }
                text: "DATESHEET"
                color: root.inkA(0.5)
                font.family: root.mono
                font.pixelSize: 9
                font.letterSpacing: 3
            }

            Text {
                anchors { top: parent.top; left: parent.left; leftMargin: 128; topMargin: 22 }
                text: root.exams.length + " PAPERS · DECEMBER"
                color: root.inkA(0.24)
                font.family: root.mono
                font.pixelSize: 9
                font.letterSpacing: 2
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
                    color: closeArea.containsMouse ? "#ffffff" : root.inkA(0.45)
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 9
                    height: 1
                    rotation: -45
                    color: closeArea.containsMouse ? "#ffffff" : root.inkA(0.45)
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }

            // ───────────────────────── left: the papers ─────────────────────────
            Item {
                id: leftPane
                anchors { top: parent.top; left: parent.left; bottom: parent.bottom }
                anchors.topMargin: 54
                anchors.leftMargin: 28
                anchors.bottomMargin: 24
                width: 300

                Text {
                    id: listLabel
                    text: "ORDER"
                    color: root.inkA(0.28)
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                }

                Column {
                    id: list
                    anchors { top: listLabel.bottom; topMargin: 12; left: parent.left; right: parent.right }
                    spacing: 2

                    Repeater {
                        model: root.exams

                        Item {
                            id: paperRow
                            required property int index
                            required property var modelData
                            width: list.width
                            height: 60

                            readonly property bool sel: root.selected === index
                            readonly property int daysLeft: ExamDays.daysUntil(modelData.date)

                            HoverHandler { id: paperHover }

                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: paperRow.sel ? root.inkA(0.09)
                                     : (paperHover.hovered ? root.inkA(0.045) : "transparent")
                                border.width: 1
                                border.color: paperRow.sel ? root.inkA(0.22) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Column {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                spacing: 1

                                Text {
                                    text: ExamDays.dayNum(paperRow.modelData.date)
                                    color: paperRow.sel ? "#ffffff" : root.inkA(0.72)
                                    font.family: root.mono
                                    font.weight: Font.Light
                                    font.pixelSize: 22
                                    font.letterSpacing: -1
                                }
                                Text {
                                    text: ExamDays.monthShort(paperRow.modelData.date)
                                    color: root.inkA(0.32)
                                    font.family: root.mono
                                    font.pixelSize: 7
                                    font.letterSpacing: 2
                                }
                            }

                            Column {
                                anchors {
                                    left: parent.left; leftMargin: 74
                                    right: leftDays.left; rightMargin: 10
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: paperRow.modelData.subject
                                    color: paperRow.sel ? root.inkA(0.96) : root.inkA(0.68)
                                    font.family: root.mono
                                    font.pixelSize: 11
                                    font.letterSpacing: 3
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: ExamDays.dow(paperRow.modelData.date) + " · END SEM"
                                    color: root.inkA(paperRow.daysLeft < 0 ? 0.16 : 0.3)
                                    font.family: root.mono
                                    font.pixelSize: 7
                                    font.letterSpacing: 2
                                }
                            }

                            Text {
                                id: leftDays
                                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                                text: paperRow.daysLeft < 0 ? "DONE"
                                     : (paperRow.daysLeft === 0 ? "TODAY" : paperRow.daysLeft + "D")
                                color: paperRow.daysLeft === 0 ? "#ffffff"
                                     : root.inkA(paperRow.sel ? 0.7 : (paperRow.daysLeft < 0 ? 0.18 : 0.38))
                                font.family: root.mono
                                font.pixelSize: 8
                                font.letterSpacing: 1
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selected = paperRow.index
                            }
                        }
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

            // ───────────────────────── right: units and their topics ─────────────────────────
            Item {
                id: rightPane
                anchors { top: parent.top; bottom: parent.bottom; left: divider.right; right: parent.right }
                anchors.topMargin: 54
                anchors.bottomMargin: 22
                anchors.leftMargin: 26
                anchors.rightMargin: 28

                Text {
                    id: sylLabel
                    text: "SYLLABUS"
                    color: root.inkA(0.3)
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                }

                Text {
                    id: sylSubject
                    anchors { top: sylLabel.bottom; topMargin: 6; left: parent.left; right: parent.right }
                    text: root.exam ? root.exam.subject + (root.exam.code ? "  ·  " + root.exam.code : "") : ""
                    color: root.inkA(0.95)
                    font.family: root.mono
                    font.pixelSize: 21
                    font.letterSpacing: 6
                    elide: Text.ElideRight
                }

                Text {
                    id: sylMeta
                    anchors { top: sylSubject.bottom; topMargin: 6; left: parent.left }
                    text: {
                        if (!root.exam) return ""
                        var d = ExamDays.daysUntil(root.exam.date)
                        var left = d < 0 ? "SAT" : (d === 0 ? "TODAY" : "IN " + d + (d === 1 ? " DAY" : " DAYS"))
                        return ExamDays.shortDate(root.exam.date) + "  ·  " + left
                             + "  ·  " + root.exam.units.length + " UNITS  ·  " + root.topicTotal + " TOPICS"
                    }
                    color: root.inkA(0.34)
                    font.family: root.mono
                    font.pixelSize: 8
                    font.letterSpacing: 2
                }

                Rectangle {
                    id: sylRule
                    anchors { top: sylMeta.bottom; topMargin: 11; left: parent.left; right: parent.right }
                    height: 1
                    color: root.hair
                }

                Flickable {
                    id: unitScroll
                    anchors { top: sylRule.bottom; topMargin: 2; left: parent.left; right: parent.right; bottom: footer.top }
                    anchors.bottomMargin: 4
                    clip: true
                    contentHeight: unitColumn.height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    Column {
                        id: unitColumn
                        width: unitScroll.width
                        spacing: 0

                        Repeater {
                            model: root.exam ? root.exam.units : []

                            Item {
                                id: unitBlock
                                required property int index
                                required property var modelData
                                width: unitColumn.width
                                // the row, plus the topics it opens into
                                height: head.height + (unitBlock.open ? topicColumn.height + 8 : 0)
                                clip: true

                                property bool open: false

                                Behavior on height { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }

                                HoverHandler { id: unitHover }

                                Rectangle {
                                    anchors.fill: parent
                                    color: unitHover.hovered && !unitBlock.open ? root.inkA(0.03) : "transparent"
                                }

                                Rectangle {
                                    anchors { left: parent.left; right: parent.right; top: parent.top }
                                    height: 1
                                    color: root.inkA(unitBlock.open ? 0.16 : 0.06)
                                }

                                // ── the row itself ──
                                Item {
                                    id: head
                                    width: parent.width
                                    height: 42

                                    Text {
                                        id: unitNum
                                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                        text: (unitBlock.index + 1 < 10 ? "0" : "") + (unitBlock.index + 1)
                                        color: root.inkA(unitBlock.open ? 0.6 : 0.24)
                                        font.family: root.mono
                                        font.pixelSize: 8
                                    }

                                    Text {
                                        id: unitName
                                        anchors {
                                            left: unitNum.right; leftMargin: 14
                                            right: unitCount.left; rightMargin: 12
                                            verticalCenter: parent.verticalCenter
                                        }
                                        text: unitBlock.modelData.name
                                        color: root.inkA(unitBlock.open ? 0.96 : 0.78)
                                        font.family: root.mono
                                        font.pixelSize: 9
                                        font.letterSpacing: 2
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: unitCount
                                        anchors { right: chevron.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                        text: unitBlock.modelData.topics.length + " " + (unitBlock.modelData.topics.length === 1 ? "TOPIC" : "TOPICS")
                                        color: root.inkA(0.24)
                                        font.family: root.mono
                                        font.pixelSize: 7
                                        font.letterSpacing: 1
                                    }

                                    // the dropdown mark on the side of the row
                                    Text {
                                        id: chevron
                                        anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
                                        text: "\u203A"
                                        color: root.inkA(unitBlock.open ? 0.85 : (unitHover.hovered ? 0.7 : 0.34))
                                        font.family: root.mono
                                        font.pixelSize: 15
                                        rotation: unitBlock.open ? 90 : 0
                                        Behavior on rotation { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: unitBlock.open = !unitBlock.open
                                    }
                                }

                                // ── what the dropdown holds ──
                                Column {
                                    id: topicColumn
                                    y: head.height
                                    width: parent.width
                                    spacing: 0

                                    Repeater {
                                        model: unitBlock.modelData.topics

                                        Item {
                                            id: topicRow
                                            required property int index
                                            required property string modelData
                                            width: topicColumn.width
                                            height: 26

                                            HoverHandler { id: topicHover }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: topicHover.hovered ? root.inkA(0.04) : "transparent"
                                            }

                                            Rectangle {
                                                id: topicTick
                                                anchors { left: parent.left; leftMargin: 22; verticalCenter: parent.verticalCenter }
                                                width: 3
                                                height: 1
                                                color: root.inkA(0.28)
                                            }

                                            Text {
                                                anchors {
                                                    left: topicTick.right; leftMargin: 12
                                                    right: parent.right; rightMargin: 10
                                                    verticalCenter: parent.verticalCenter
                                                }
                                                text: topicRow.modelData
                                                color: root.inkA(0.72)
                                                font.family: root.mono
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

                Item {
                    id: footer
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 18

                    Text {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: "CLICK A UNIT TO OPEN IT · ESC CLOSES"
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
