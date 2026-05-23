import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool opened: false
    property int activeTab: 0
    property string homeDir: Quickshell.env("HOME") || "/home/abooser"
    property string userName: Quickshell.env("USER") || "abooser"
    property string assetDir: homeDir + "/.config/quickshell/dashboard/assets"
    property string bongoCatPath: "file://" + assetDir + "/bongo-cat.gif"
    property var payload: ({})
    property var media: payload.media || ({})
    property var sys: payload.system || ({})
    property var weather: payload.weather || ({})
    property var current: weather.current || ({})
    property string clockText: Qt.formatDateTime(new Date(), "hh:mm")
    property string dateText: Qt.formatDateTime(new Date(), "dddd, dd MMMM")
    property bool dataBusy: dataProcess.running

    readonly property color bg: "#ee0f141d"
    readonly property color cardBg: "#e918202b"
    readonly property color cardBg2: "#d9151b25"
    readonly property color borderSoft: "#22ffffff"
    readonly property color accent: "#8fd3ff"
    readonly property color accent2: "#ff9fd7"
    readonly property color textMain: "#ffffff"
    readonly property color textMuted: "#9ca8b8"

    function n(value, fallback) {
        if (value === undefined || value === null || value === "" || isNaN(value)) return fallback
        return Number(value)
    }

    function s(value, fallback) {
        if (value === undefined || value === null || value === "") return fallback
        return String(value)
    }

    function weatherIcon(code) {
        code = root.n(code, 3)
        if (code === 0) return "☀"
        if (code === 1 || code === 2) return ""
        if (code === 3) return "☁"
        if (code >= 45 && code <= 48) return ""
        if (code >= 51 && code <= 67) return "☂"
        if (code >= 71 && code <= 77) return "❄"
        if (code >= 80 && code <= 82) return "☔"
        if (code >= 95) return "⚡"
        return "☁"
    }

    function weatherText(code) {
        code = root.n(code, 3)
        if (code === 0) return "Clear"
        if (code === 1 || code === 2) return "Partly cloudy"
        if (code === 3) return "Overcast"
        if (code >= 45 && code <= 48) return "Fog"
        if (code >= 51 && code <= 67) return "Drizzle"
        if (code >= 71 && code <= 77) return "Snow"
        if (code >= 80 && code <= 82) return "Rain showers"
        if (code >= 95) return "Thunderstorm"
        return "Cloudy"
    }

    function daily(name) {
        if (!root.weather || !root.weather.daily || !root.weather.daily[name]) return []
        return root.weather.daily[name]
    }

    function tabLabel(index) {
        return ["Home", "Media", "System", "Weather"][index]
    }

    function toggle(): void {
        opened = !opened
        if (opened) refreshData()
    }

    function open(): void {
        opened = true
        refreshData()
    }

    function close(): void {
        opened = false
    }

    function refreshData(): void {
        if (!dataProcess.running) dataProcess.running = true
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { root.toggle() }
        function open(): void { root.open() }
        function close(): void { root.close() }
        function refresh(): void { root.refreshData() }
    }

    Process {
        id: dataProcess
        command: ["bash", root.homeDir + "/.config/quickshell/dashboard/scripts/dashboard-data.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const text = this.text.trim()
                    root.payload = text.length > 0 ? JSON.parse(text) : ({})
                } catch (e) {
                    console.warn("dashboard-data parse error", e)
                    root.payload = ({})
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.clockText = Qt.formatDateTime(new Date(), "hh:mm")
            root.dateText = Qt.formatDateTime(new Date(), "dddd, dd MMMM")
        }
    }

    Timer {
        interval: 10000
        running: root.opened
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refreshData()
    }

    PanelWindow {
        id: win
        visible: root.opened
        color: "transparent"
        aboveWindows: true
        focusable: false
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 1040
        implicitHeight: 620

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            right: true
        }

        margins {
            top: 42
            right: 18
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: 30
            color: root.bg
            border.color: "#334fd1ff"
            border.width: 1
            clip: true
            antialiasing: true

            gradient: Gradient {
                GradientStop { position: 0.0; color: "#f0131b26" }
                GradientStop { position: 0.55; color: "#ee0d111a" }
                GradientStop { position: 1.0; color: "#f0161220" }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 70
                        radius: 22
                        color: "#f7f7f7"
                        clip: true
                        border.color: "#20ffffff"
                        AnimatedImage {
                            id: bongo
                            anchors.fill: parent
                            source: root.bongoCatPath
                            fillMode: Image.PreserveAspectCrop
                            playing: root.opened
                            cache: false
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: bongo.status === AnimatedImage.Error
                            text: "ฅ"
                            color: "#111111"
                            font.pixelSize: 36
                            font.weight: Font.Black
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            text: "Dashboard"
                            color: root.textMain
                            font.family: "Inter"
                            font.pixelSize: 28
                            font.weight: Font.Black
                        }
                        Text {
                            text: root.dateText + " · Quickshell production panel"
                            color: root.textMuted
                            font.family: "Inter"
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 110
                        Layout.preferredHeight: 50
                        radius: 18
                        color: "#261f2a36"
                        border.color: root.borderSoft
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 0
                            Text { text: root.clockText; color: root.textMain; font.pixelSize: 22; font.weight: Font.Black; Layout.alignment: Qt.AlignHCenter }
                            Text { text: root.dataBusy ? "updating" : "live"; color: root.dataBusy ? root.accent2 : root.textMuted; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                        }
                    }

                    IconButton { label: "↻"; tip: "Refresh"; onClicked: root.refreshData() }
                    IconButton { label: "×"; tip: "Close"; danger: true; onClicked: root.close() }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 160
                        Layout.fillHeight: true
                        radius: 24
                        color: "#90141a24"
                        border.color: root.borderSoft

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Repeater {
                                model: 4
                                delegate: NavButton {
                                    label: root.tabLabel(index)
                                    active: root.activeTab === index
                                    onClicked: root.activeTab = index
                                }
                            }

                            Item { Layout.fillHeight: true }

                            Text {
                                Layout.fillWidth: true
                                text: "SUPER+M toggles this panel. Closed state creates no fullscreen overlay."
                                color: root.textMuted
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        HomePage { anchors.fill: parent; visible: root.activeTab === 0 }
                        MediaPage { anchors.fill: parent; visible: root.activeTab === 1 }
                        SystemPage { anchors.fill: parent; visible: root.activeTab === 2 }
                        WeatherPage { anchors.fill: parent; visible: root.activeTab === 3 }
                    }
                }
            }
        }
    }

    component HomePage: GridLayout {
        columns: 3
        rowSpacing: 12
        columnSpacing: 12

        BigWeatherCard { Layout.columnSpan: 1; Layout.fillWidth: true; Layout.fillHeight: true }
        BigMediaCard { Layout.columnSpan: 2; Layout.fillWidth: true; Layout.fillHeight: true }

        MetricCard { title: "CPU"; value: root.n(root.sys.cpu, 0) + "%"; sub: root.n(root.sys.cpuTemp, 0) + "°C"; percent: root.n(root.sys.cpu, 0) }
        MetricCard { title: "RAM"; value: root.n(root.sys.ram, 0) + "%"; sub: root.s(root.sys.ramUsed, "0") + "/" + root.s(root.sys.ramTotal, "0") + " GiB"; percent: root.n(root.sys.ram, 0) }
        MetricCard { title: "Disk"; value: root.n(root.sys.disk, 0) + "%"; sub: root.s(root.sys.diskUsed, "0") + "/" + root.s(root.sys.diskTotal, "0"); percent: root.n(root.sys.disk, 0) }

        Card {
            Layout.columnSpan: 3
            Layout.fillWidth: true
            Layout.preferredHeight: 95
            RowLayout { anchors.fill: parent; anchors.margins: 16; spacing: 12
                ActionButton { label: "Lock"; command: ["hyprlock"]; Layout.fillWidth: true }
                ActionButton { label: "Play / Pause"; command: ["playerctl", "play-pause"]; Layout.fillWidth: true }
                ActionButton { label: "Previous"; command: ["playerctl", "previous"]; Layout.fillWidth: true }
                ActionButton { label: "Next"; command: ["playerctl", "next"]; Layout.fillWidth: true }
            }
        }
    }

    component MediaPage: RowLayout {
        spacing: 12

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            RowLayout { anchors.fill: parent; anchors.margins: 22; spacing: 24
                Rectangle {
                    Layout.preferredWidth: 250
                    Layout.preferredHeight: 250
                    radius: 30
                    color: "#f7f7f7"
                    border.color: root.borderSoft
                    clip: true
                    AnimatedImage {
                        anchors.fill: parent
                        source: root.bongoCatPath
                        fillMode: Image.PreserveAspectCrop
                        playing: root.opened && root.activeTab === 1
                        cache: false
                    }
                }
                ColumnLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 16
                    Text { text: root.media.title || "No active track"; color: root.textMain; font.pixelSize: 30; font.weight: Font.Black; elide: Text.ElideRight; maximumLineCount: 2; Layout.fillWidth: true }
                    Text { text: root.media.artist || root.media.album || root.media.player || "playerctl"; color: root.textMuted; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                    RowLayout { spacing: 12
                        ActionButton { label: "⏮"; command: ["playerctl", "previous"]; Layout.preferredWidth: 74; Layout.preferredHeight: 58 }
                        ActionButton { label: root.media.status === "Playing" ? "⏸" : "▶"; command: ["playerctl", "play-pause"]; Layout.preferredWidth: 86; Layout.preferredHeight: 68; highlight: true }
                        ActionButton { label: "⏭"; command: ["playerctl", "next"]; Layout.preferredWidth: 74; Layout.preferredHeight: 58 }
                    }
                    Text { text: "System volume · " + root.n(root.media.volume, 100) + "%"; color: root.textMuted; font.pixelSize: 12 }
                    Slider { Layout.fillWidth: true; from: 0; to: 150; value: root.n(root.media.volume, 100); onMoved: Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(value) + "%"]) }
                    Item { Layout.fillHeight: true }
                    Text { text: "EQ integration is not wired yet. Recommended backend: EasyEffects preset switching over CLI."; color: "#728092"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
            }
        }
    }

    component SystemPage: GridLayout {
        columns: 3
        rowSpacing: 12
        columnSpacing: 12

        MetricCard { title: "CPU"; value: root.n(root.sys.cpu, 0) + "%"; sub: root.n(root.sys.cpuTemp, 0) + "°C"; percent: root.n(root.sys.cpu, 0) }
        MetricCard { title: "GPU"; value: root.n(root.sys.gpu, 0) + "%"; sub: root.n(root.sys.gpuTemp, 0) + "°C"; percent: root.n(root.sys.gpu, 0) }
        MetricCard { title: "Memory"; value: root.n(root.sys.ram, 0) + "%"; sub: root.s(root.sys.ramUsed, "0") + "/" + root.s(root.sys.ramTotal, "0") + " GiB"; percent: root.n(root.sys.ram, 0) }
        MetricCard { title: "Storage"; value: root.n(root.sys.disk, 0) + "%"; sub: root.s(root.sys.diskUsed, "0") + "/" + root.s(root.sys.diskTotal, "0"); percent: root.n(root.sys.disk, 0) }
        MetricCard { title: "Network"; value: "↓ " + root.n(root.sys.netDown, 0); sub: "↑ " + root.n(root.sys.netUp, 0) + " KiB/s"; percent: root.n(root.sys.netGraph, 0) }
        MetricCard { title: "IP"; value: root.sys.ip || "--"; sub: "IPv4 active interface"; percent: 100 }

        Card {
            Layout.columnSpan: 3
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 12
                Text { text: "Runtime safety"; color: root.accent; font.pixelSize: 14; font.weight: Font.Bold }
                Text { text: "No fullscreen overlay, no keyboard focus, no background mouse catcher. Data polling is bounded and runs only while the panel is open."; color: root.textMuted; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                ActionButton { label: "Stop dashboard process"; command: ["bash", root.homeDir + "/.config/hypr/scripts/dashboard.sh", "--kill"]; Layout.preferredWidth: 230 }
            }
        }
    }

    component WeatherPage: ColumnLayout {
        spacing: 12

        BigWeatherCard { Layout.fillWidth: true; Layout.preferredHeight: 170 }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            Repeater {
                model: Math.min(7, root.daily("time").length)
                delegate: WeatherDayCard { dayIndex: index; Layout.fillWidth: true; Layout.fillHeight: true }
            }
        }
    }

    component BigWeatherCard: Card {
        RowLayout { anchors.fill: parent; anchors.margins: 20; spacing: 16
            Text { text: root.weatherIcon(root.current.weather_code); color: root.accent; font.pixelSize: 72; Layout.alignment: Qt.AlignVCenter }
            ColumnLayout { Layout.fillWidth: true; spacing: 4
                Text { text: "Kyiv"; color: root.textMain; font.pixelSize: 16; font.weight: Font.Bold }
                Text { text: Math.round(root.n(root.current.temperature_2m, 0)) + "°C"; color: root.textMain; font.pixelSize: 44; font.weight: Font.Black }
                Text { text: root.weatherText(root.current.weather_code); color: root.textMuted; font.pixelSize: 13 }
                Text { text: "humidity " + root.n(root.current.relative_humidity_2m, 0) + "% · wind " + Math.round(root.n(root.current.wind_speed_10m, 0)) + " km/h"; color: root.textMuted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
    }

    component BigMediaCard: Card {
        RowLayout { anchors.fill: parent; anchors.margins: 20; spacing: 16
            Rectangle {
                Layout.preferredWidth: 118
                Layout.preferredHeight: 118
                radius: 24
                color: "#f7f7f7"
                clip: true
                AnimatedImage { anchors.fill: parent; source: root.bongoCatPath; fillMode: Image.PreserveAspectCrop; playing: root.opened; cache: false }
            }
            ColumnLayout { Layout.fillWidth: true; spacing: 8
                Text { text: root.media.title || "No active track"; color: root.textMain; font.pixelSize: 23; font.weight: Font.Black; maximumLineCount: 1; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: root.media.artist || root.media.player || "playerctl"; color: root.textMuted; font.pixelSize: 13; maximumLineCount: 1; elide: Text.ElideRight; Layout.fillWidth: true }
                RowLayout { spacing: 10
                    ActionButton { label: "⏮"; command: ["playerctl", "previous"]; Layout.preferredWidth: 56 }
                    ActionButton { label: root.media.status === "Playing" ? "⏸" : "▶"; command: ["playerctl", "play-pause"]; highlight: true; Layout.preferredWidth: 66 }
                    ActionButton { label: "⏭"; command: ["playerctl", "next"]; Layout.preferredWidth: 56 }
                }
            }
        }
    }

    component WeatherDayCard: Card {
        property int dayIndex: 0
        ColumnLayout { anchors.fill: parent; anchors.margins: 12; spacing: 8
            Text { text: dayIndex === 0 ? "Today" : Qt.formatDateTime(new Date(root.daily("time")[dayIndex]), "ddd"); color: root.textMain; font.pixelSize: 13; font.weight: Font.Black; Layout.alignment: Qt.AlignHCenter }
            Text { text: root.weatherIcon(root.daily("weather_code")[dayIndex]); color: root.accent; font.pixelSize: 30; Layout.alignment: Qt.AlignHCenter }
            Text { text: Math.round(root.n(root.daily("temperature_2m_min")[dayIndex], 0)) + "° / " + Math.round(root.n(root.daily("temperature_2m_max")[dayIndex], 0)) + "°"; color: root.textMain; font.pixelSize: 14; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
            Text { text: "☂ " + Math.round(root.n(root.daily("relative_humidity_2m_mean")[dayIndex], 0)) + "%"; color: root.textMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
        }
    }

    component MetricCard: Card {
        property string title: ""
        property string value: "--"
        property string sub: ""
        property real percent: 0

        ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 9
            Text { text: title; color: root.accent; font.pixelSize: 13; font.weight: Font.Bold; Layout.fillWidth: true; elide: Text.ElideRight }
            Text { text: value; color: root.textMain; font.pixelSize: 27; font.weight: Font.Black; Layout.fillWidth: true; elide: Text.ElideRight }
            Text { text: sub; color: root.textMuted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4; color: "#26303b"
                Rectangle { width: parent.width * Math.max(0, Math.min(100, percent)) / 100; height: parent.height; radius: 4; color: root.accent2; Behavior on width { NumberAnimation { duration: 180 } } }
            }
        }
    }

    component Card: Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 22
        color: root.cardBg
        border.color: root.borderSoft
        border.width: 1
        antialiasing: true
    }

    component NavButton: Rectangle {
        property string label: ""
        property bool active: false
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        radius: 15
        color: active ? "#38415a" : "transparent"
        border.color: active ? "#558fd3ff" : "transparent"
        border.width: 1
        Text { anchors.centerIn: parent; text: label; color: active ? root.textMain : root.textMuted; font.pixelSize: 13; font.weight: Font.Bold }
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }

    component IconButton: Rectangle {
        property string label: ""
        property string tip: ""
        property bool danger: false
        signal clicked()
        Layout.preferredWidth: 46
        Layout.preferredHeight: 46
        radius: 16
        color: danger ? "#3b1f2b" : "#222b38"
        border.color: danger ? "#66ff8fb7" : root.borderSoft
        Text { anchors.centerIn: parent; text: label; color: danger ? "#ffb1ca" : root.textMain; font.pixelSize: 20; font.weight: Font.Black }
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }

    component ActionButton: Rectangle {
        property string label: ""
        property var command: []
        property bool highlight: false
        signal clicked()
        Layout.preferredHeight: 46
        radius: 16
        color: highlight ? "#465174" : "#222b38"
        border.color: highlight ? "#668fd3ff" : root.borderSoft
        border.width: 1
        Text { anchors.centerIn: parent; text: label; color: root.textMain; font.pixelSize: 13; font.weight: Font.Bold }
        MouseArea { anchors.fill: parent; onClicked: { if (command.length > 0) Quickshell.execDetached(command); parent.clicked() } }
    }
}
