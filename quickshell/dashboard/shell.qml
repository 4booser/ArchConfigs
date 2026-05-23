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
    property string avatarPath: "file://" + assetDir + "/avatar.png"
    property string bongoCatPath: "file://" + assetDir + "/bongo-cat.gif"

    property var payload: ({})
    property var media: payload.media || ({})
    property var sys: payload.system || ({})
    property var weather: payload.weather || ({})
    property var current: weather.current || ({})

    property string clockText: Qt.formatDateTime(new Date(), "hh:mm")
    property string dateText: Qt.formatDateTime(new Date(), "dddd, dd MMMM")
    property string pendingPowerAction: ""
    property var cpuHistory: []
    property var gpuHistory: []
    property var ramHistory: []
    property var netHistory: []

    readonly property color panelBg: "#e00b2228"
    readonly property color sidebarBg: "#6b10242b"
    readonly property color cardBg: "#9d0e2a31"
    readonly property color cardBg2: "#ad123139"
    readonly property color borderSoft: "#30ffffff"
    readonly property color borderActive: "#754aa3ff"
    readonly property color textMain: "#eff8f6"
    readonly property color textSoft: "#aebfc3"
    readonly property color textMuted: "#6c888e"
    readonly property color cyan: "#48d6c2"
    readonly property color blue: "#4aa4ff"
    readonly property color pink: "#e879d6"
    readonly property color purple: "#9674ff"
    readonly property color danger: "#ff6f9f"

    function n(value, fallback) {
        if (value === undefined || value === null || value === "" || isNaN(value)) return fallback
        return Number(value)
    }

    function s(value, fallback) {
        if (value === undefined || value === null || value === "") return fallback
        return String(value)
    }

    function clamp(value, minValue, maxValue) {
        return Math.max(minValue, Math.min(maxValue, n(value, minValue)))
    }

    function pushHistory(propName, value) {
        var arr = root[propName] || []
        arr = arr.concat([clamp(value, 0, 100)])
        while (arr.length > 52) arr.shift()
        root[propName] = arr
    }

    function ingestPayload() {
        pushHistory("cpuHistory", sys.cpu || 0)
        pushHistory("gpuHistory", sys.gpu || 0)
        pushHistory("ramHistory", sys.ram || 0)
        pushHistory("netHistory", sys.netGraph || 0)
    }

    function tabLabel(index) {
        return ["Dashboard", "Media", "Performance", "Weather", "Power", "Launcher", "Network", "Settings"][index]
    }

    function tabIcon(index) {
        return ["grid", "music", "activity", "cloud", "power", "apps", "network", "settings"][index]
    }

    function weatherIcon(code) {
        code = n(code, 3)
        if (code === 0) return "☀"
        if (code === 1 || code === 2) return "◐"
        if (code === 3) return "☁"
        if (code >= 45 && code <= 48) return "≋"
        if (code >= 51 && code <= 67) return "☂"
        if (code >= 71 && code <= 77) return "❄"
        if (code >= 80 && code <= 82) return "☔"
        if (code >= 95) return "⚡"
        return "☁"
    }

    function weatherText(code) {
        code = n(code, 3)
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
        if (!weather || !weather.daily || !weather.daily[name]) return []
        return weather.daily[name]
    }

    function setAppVolume(value) {
        const volume = Math.round(value) + "%"
        if ((media.sinkId || "") !== "")
            Quickshell.execDetached(["pactl", "set-sink-input-volume", String(media.sinkId), volume])
        else
            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volume])
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
        pendingPowerAction = ""
    }

    function refreshData(): void {
        if (!dataProcess.running) dataProcess.running = true
    }

    function runPower(action) {
        if (pendingPowerAction !== action) {
            pendingPowerAction = action
            return
        }
        if (action === "lock") Quickshell.execDetached(["hyprlock"])
        if (action === "logout") Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
        if (action === "reboot") Quickshell.execDetached(["systemctl", "reboot"])
        if (action === "poweroff") Quickshell.execDetached(["systemctl", "poweroff"])
        pendingPowerAction = ""
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
                    root.ingestPayload()
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
            clockText = Qt.formatDateTime(new Date(), "hh:mm")
            dateText = Qt.formatDateTime(new Date(), "dddd, dd MMMM")
        }
    }

    Timer {
        interval: 7000
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
        implicitWidth: 920
        implicitHeight: 535

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors { top: true }
        margins { top: 34 }

        Rectangle {
            anchors.fill: parent
            radius: 24
            color: root.panelBg
            border.color: "#304bdfff"
            border.width: 1
            clip: true
            antialiasing: true

            Rectangle {
                anchors.fill: parent
                opacity: 0.9
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#ee0b2b31" }
                    GradientStop { position: 0.58; color: "#de081d24" }
                    GradientStop { position: 1.0; color: "#e0120d24" }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                HeaderBar { Layout.fillWidth: true; Layout.preferredHeight: 54 }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Sidebar { Layout.preferredWidth: 130; Layout.fillHeight: true }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        DashboardPage { anchors.fill: parent; visible: root.activeTab === 0 }
                        MediaPage { anchors.fill: parent; visible: root.activeTab === 1 }
                        PerformancePage { anchors.fill: parent; visible: root.activeTab === 2 }
                        WeatherPage { anchors.fill: parent; visible: root.activeTab === 3 }
                        PowerPage { anchors.fill: parent; visible: root.activeTab === 4 }
                        LauncherPage { anchors.fill: parent; visible: root.activeTab === 5 }
                        NetworkPage { anchors.fill: parent; visible: root.activeTab === 6 }
                        SettingsPage { anchors.fill: parent; visible: root.activeTab === 7 }
                    }
                }
            }
        }
    }

    component HeaderBar: RowLayout {
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 46
            Layout.preferredHeight: 46
            radius: 15
            color: "#10242a"
            border.color: root.borderSoft
            clip: true
            Image { id: avatar; anchors.fill: parent; source: root.avatarPath; fillMode: Image.PreserveAspectCrop; cache: false }
            Text { anchors.centerIn: parent; visible: avatar.status === Image.Error || avatar.status === Image.Null; text: root.userName.slice(0, 1).toUpperCase(); color: root.textMain; font.pixelSize: 24; font.weight: Font.Black }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { text: "Dashboard"; color: root.textMain; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 23; font.weight: Font.Black }
            Text { text: root.dateText + "  ·  " + root.s(root.sys.uptime, "--") + " uptime"; color: root.textSoft; font.pixelSize: 10 }
        }

        HeaderPill { main: root.clockText; sub: dataProcess.running ? "updating" : "live" }
        HeaderIconButton { iconName: "refresh"; onClicked: root.refreshData() }
        HeaderIconButton { iconName: "close"; danger: true; onClicked: root.close() }
    }

    component Sidebar: Rectangle {
        radius: 20
        color: root.sidebarBg
        border.color: root.borderSoft
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
            Repeater {
                model: 8
                delegate: NavButton {
                    label: root.tabLabel(index)
                    iconName: root.tabIcon(index)
                    active: root.activeTab === index
                    onClicked: root.activeTab = index
                }
            }
            Item { Layout.fillHeight: true }
            Text { Layout.fillWidth: true; text: "No fullscreen input layer.\nPanel exists only while opened."; color: root.textMuted; font.pixelSize: 9; wrapMode: Text.WordWrap }
        }
    }

    component DashboardPage: GridLayout {
        columns: 4
        rowSpacing: 10
        columnSpacing: 10

        ClockCard { Layout.preferredWidth: 120; Layout.fillHeight: true }
        WeatherMiniCard { Layout.preferredWidth: 190; Layout.fillHeight: true }
        CalendarCard { Layout.columnSpan: 2; Layout.fillWidth: true; Layout.fillHeight: true }

        MediaMiniCard { Layout.columnSpan: 2; Layout.fillWidth: true; Layout.fillHeight: true }
        BongoCard { Layout.preferredWidth: 155; Layout.fillHeight: true }
        UserCard { Layout.preferredWidth: 155; Layout.fillHeight: true }
    }

    component MediaPage: RowLayout {
        spacing: 10
        Card {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 12
                AvatarDisc { Layout.alignment: Qt.AlignHCenter; size: 138 }
                Text { Layout.fillWidth: true; text: root.media.title || "No active track"; color: root.textMain; font.pixelSize: 18; font.weight: Font.Black; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; maximumLineCount: 2 }
                Text { Layout.fillWidth: true; text: root.media.artist || root.media.album || root.media.player || "playerctl"; color: root.textSoft; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight }
                MediaControls { Layout.alignment: Qt.AlignHCenter }
            }
        }
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 12
                Text { text: "Equalizer"; color: root.textMain; font.pixelSize: 20; font.weight: Font.Black }
                RowLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
                    EqSlider { label: "Bass"; value: 58 }
                    EqSlider { label: "Low"; value: 46 }
                    EqSlider { label: "Mid"; value: 52 }
                    EqSlider { label: "High"; value: 61 }
                    EqSlider { label: "Treble"; value: 48 }
                    BongoCard { Layout.fillWidth: true; Layout.fillHeight: true }
                }
                Text { text: "App volume · " + root.n(root.media.appVolume, root.media.volume || 100) + "%"; color: root.textSoft; font.pixelSize: 11 }
                Slider { Layout.fillWidth: true; from: 0; to: 150; value: root.n(root.media.appVolume, root.media.volume || 100); onMoved: root.setAppVolume(value) }
            }
        }
    }

    component PerformancePage: ColumnLayout {
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 175
            spacing: 10

            GraphCard {
                title: "CPU — " + root.s(root.sys.cpuName, "CPU")
                value: root.n(root.sys.cpu, 0)
                temp: root.n(root.sys.cpuTemp, 0)
                points: root.cpuHistory
                accentColor: root.blue
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
            }

            GraphCard {
                title: "GPU — " + root.s(root.sys.gpuName, "GPU")
                value: root.n(root.sys.gpu, 0)
                temp: root.n(root.sys.gpuTemp, 0)
                points: root.gpuHistory
                accentColor: root.cyan
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            RowLayout {
                Layout.preferredWidth: 390
                Layout.fillHeight: true
                spacing: 10

                RingCard {
                    title: "Memory"
                    value: root.n(root.sys.ram, 0)
                    sub: root.s(root.sys.ramUsed, "0") + " / " + root.s(root.sys.ramTotal, "0") + " GiB"
                    accentColor: root.purple
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                RingCard {
                    title: "Storage"
                    value: root.n(root.sys.disk, 0)
                    sub: root.s(root.sys.diskUsed, "0") + " / " + root.s(root.sys.diskTotal, "0")
                    accentColor: root.cyan
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 300

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 9

                    Text {
                        text: "Network — " + root.s(root.sys.netInterface, "--")
                        color: root.textMain
                        font.pixelSize: 16
                        font.weight: Font.Black
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    SparkGraph {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: 90
                        points: root.netHistory
                        strokeColor: root.pink
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 6
                        columnSpacing: 12
                        LabelValue { label: "Download"; value: root.n(root.sys.netDown, 0) + " KiB/s" }
                        LabelValue { label: "Upload"; value: root.n(root.sys.netUp, 0) + " KiB/s" }
                        LabelValue { label: "IP"; value: root.s(root.sys.ip, "--") }
                        LabelValue { label: "Total"; value: "↓ " + root.n(root.sys.netRxTotalMb, 0) + "MB · ↑ " + root.n(root.sys.netTxTotalMb, 0) + "MB" }
                    }
                }
            }
        }
    }

    component WeatherPage: ColumnLayout {
        spacing: 10
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 165
            RowLayout { anchors.fill: parent; anchors.margins: 18; spacing: 18
                Text { text: root.weatherIcon(root.current.weather_code); color: root.cyan; font.pixelSize: 62 }
                ColumnLayout { Layout.fillWidth: true; spacing: 5
                    Text { text: "Kyiv"; color: root.textMain; font.pixelSize: 26; font.weight: Font.Black }
                    Text { text: Math.round(root.n(root.current.temperature_2m, 0)) + "°C"; color: root.blue; font.pixelSize: 42; font.weight: Font.Black }
                    Text { text: root.weatherText(root.current.weather_code); color: root.textSoft; font.pixelSize: 13 }
                }
                ColumnLayout { Layout.preferredWidth: 260; spacing: 8
                    WeatherFact { label: "Sunrise"; value: root.s(root.daily("sunrise")[0], "--T--").slice(-5) }
                    WeatherFact { label: "Sunset"; value: root.s(root.daily("sunset")[0], "--T--").slice(-5) }
                    WeatherFact { label: "Humidity"; value: root.n(root.current.relative_humidity_2m, 0) + "%" }
                    WeatherFact { label: "Wind"; value: Math.round(root.n(root.current.wind_speed_10m, 0)) + " km/h" }
                }
            }
        }
        RowLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
            Repeater { model: Math.min(7, root.daily("time").length); delegate: WeatherDayCard { dayIndex: index; Layout.fillWidth: true; Layout.fillHeight: true } }
        }
    }

    component PowerPage: GridLayout {
        columns: 2
        rowSpacing: 10
        columnSpacing: 10
        PowerButton { title: "Lock"; sub: "Lock session"; action: "lock" }
        PowerButton { title: "Logout"; sub: "Exit Hyprland"; action: "logout" }
        PowerButton { title: "Reboot"; sub: "Confirm twice"; action: "reboot"; dangerAction: true }
        PowerButton { title: "Power off"; sub: "Confirm twice"; action: "poweroff"; dangerAction: true }
    }

    component LauncherPage: ColumnLayout {
        spacing: 10
        Text { text: "Launcher"; color: root.textMain; font.pixelSize: 21; font.weight: Font.Black }
        RowLayout { Layout.fillWidth: true; spacing: 10
            ActionTile { title: "Terminal"; command: ["kitty"] }
            ActionTile { title: "Files"; command: ["nautilus"] }
            ActionTile { title: "Browser"; command: ["xdg-open", "https://www.google.com"] }
        }
        Text { Layout.fillWidth: true; text: "Search launcher can be added next. Send preferred apps and browser command."; color: root.textMuted; font.pixelSize: 12; wrapMode: Text.WordWrap }
    }

    component NetworkPage: ColumnLayout {
        spacing: 10
        Card { Layout.fillWidth: true; Layout.preferredHeight: 140
            GridLayout { anchors.fill: parent; anchors.margins: 16; columns: 2; rowSpacing: 8; columnSpacing: 18
                LabelValue { label: "Interface"; value: root.s(root.sys.netInterface, "--") }
                LabelValue { label: "IP"; value: root.s(root.sys.ip, "--") }
                LabelValue { label: "Download"; value: root.n(root.sys.netDown, 0) + " KiB/s" }
                LabelValue { label: "Upload"; value: root.n(root.sys.netUp, 0) + " KiB/s" }
            }
        }
        Card { Layout.fillWidth: true; Layout.fillHeight: true
            ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 10
                Text { text: "Internet load"; color: root.textMain; font.pixelSize: 18; font.weight: Font.Black }
                SparkGraph { Layout.fillWidth: true; Layout.fillHeight: true; points: root.netHistory; strokeColor: root.cyan }
            }
        }
    }

    component SettingsPage: ColumnLayout {
        spacing: 10
        Text { text: "Settings"; color: root.textMain; font.pixelSize: 21; font.weight: Font.Black }
        Card { Layout.fillWidth: true; Layout.preferredHeight: 110
            ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 7
                Text { text: "Assets"; color: root.cyan; font.pixelSize: 14; font.weight: Font.Bold }
                Text { text: "avatar.png -> ~/.config/quickshell/dashboard/assets/avatar.png"; color: root.textSoft; font.pixelSize: 11 }
                Text { text: "bongo-cat.gif -> ~/.config/quickshell/dashboard/assets/bongo-cat.gif"; color: root.textSoft; font.pixelSize: 11 }
            }
        }
        Card { Layout.fillWidth: true; Layout.fillHeight: true
            Text { anchors.centerIn: parent; text: "Theme editor and toggles are planned after layout is approved."; color: root.textMuted; font.pixelSize: 12 }
        }
    }

    component ClockCard: Card {
        ColumnLayout { anchors.centerIn: parent; spacing: 0
            Text { text: root.clockText.split(":")[0]; color: root.cyan; font.pixelSize: 34; font.weight: Font.Black; Layout.alignment: Qt.AlignHCenter }
            Text { text: root.clockText.split(":")[1] || "00"; color: root.purple; font.pixelSize: 34; font.weight: Font.Black; Layout.alignment: Qt.AlignHCenter }
        }
    }

    component UserCard: Card {
        ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 8
            AvatarDisc { Layout.alignment: Qt.AlignHCenter; size: 80 }
            Text { Layout.fillWidth: true; text: root.userName; color: root.textMain; font.pixelSize: 15; font.weight: Font.Black; horizontalAlignment: Text.AlignHCenter }
            Text { Layout.fillWidth: true; text: "Arch · Hyprland"; color: root.textMuted; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
        }
    }

    component WeatherMiniCard: Card {
        RowLayout { anchors.fill: parent; anchors.margins: 14; spacing: 10
            Text { text: root.weatherIcon(root.current.weather_code); color: root.cyan; font.pixelSize: 42 }
            ColumnLayout { Layout.fillWidth: true; spacing: 3
                Text { text: Math.round(root.n(root.current.temperature_2m, 0)) + "°C"; color: root.textMain; font.pixelSize: 25; font.weight: Font.Black }
                Text { text: root.weatherText(root.current.weather_code); color: root.textSoft; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: "humidity " + root.n(root.current.relative_humidity_2m, 0) + "%"; color: root.textMuted; font.pixelSize: 10 }
            }
        }
    }

    component CalendarCard: Card {
        property date now: new Date()
        property int firstOffset: (new Date(now.getFullYear(), now.getMonth(), 1).getDay() + 6) % 7
        property int daysInMonth: new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
        ColumnLayout { anchors.fill: parent; anchors.margins: 12; spacing: 8
            Text { text: Qt.formatDateTime(parent.parent.now, "MMMM yyyy"); color: root.textMain; font.pixelSize: 15; font.weight: Font.Black; Layout.alignment: Qt.AlignHCenter }
            GridLayout { Layout.alignment: Qt.AlignHCenter; columns: 7; rowSpacing: 4; columnSpacing: 7
                Repeater { model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]; delegate: Text { text: modelData; color: root.textMuted; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; Layout.preferredWidth: 24 } }
                Repeater { model: 42; delegate: Rectangle {
                    property int dayNum: index - firstOffset + 1
                    property bool valid: dayNum > 0 && dayNum <= daysInMonth
                    property bool today: valid && dayNum === now.getDate()
                    Layout.preferredWidth: 24; Layout.preferredHeight: 19; radius: 8
                    color: today ? "#4b8fd3ff" : "transparent"
                    Text { anchors.centerIn: parent; text: parent.valid ? parent.dayNum : ""; color: parent.today ? root.textMain : root.textSoft; font.pixelSize: 10; font.weight: parent.today ? Font.Black : Font.Normal }
                }}
            }
        }
    }

    component MediaMiniCard: Card {
        RowLayout { anchors.fill: parent; anchors.margins: 14; spacing: 13
            AvatarDisc { size: 70 }
            ColumnLayout { Layout.fillWidth: true; spacing: 7
                Text { text: root.media.title || "No active track"; color: root.textMain; font.pixelSize: 17; font.weight: Font.Black; maximumLineCount: 1; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: root.media.artist || root.media.player || "playerctl"; color: root.textSoft; font.pixelSize: 11; maximumLineCount: 1; elide: Text.ElideRight; Layout.fillWidth: true }
                MediaControls {}
            }
        }
    }

    component BongoCard: Card {
        Rectangle { anchors.centerIn: parent; width: Math.min(parent.width - 24, parent.height - 24); height: width; radius: 22; color: "#f3f6f3"; clip: true
            AnimatedImage { anchors.fill: parent; source: root.bongoCatPath; fillMode: Image.PreserveAspectCrop; playing: root.opened; cache: false }
        }
    }

    component AvatarDisc: Rectangle {
        property int size: 100
        Layout.preferredWidth: size
        Layout.preferredHeight: size
        width: size
        height: size
        radius: size / 2
        color: "#10242a"
        border.color: root.borderSoft
        border.width: 2
        clip: true
        Image { id: avatarImg; anchors.fill: parent; source: root.avatarPath; fillMode: Image.PreserveAspectCrop; cache: false }
        Text { anchors.centerIn: parent; visible: avatarImg.status === Image.Error || avatarImg.status === Image.Null; text: root.userName.slice(0,1).toUpperCase(); color: root.textMain; font.pixelSize: size * 0.38; font.weight: Font.Black }
    }

    component MediaControls: RowLayout {
        spacing: 8
        ActionButton { label: "◀"; command: ["playerctl", "previous"]; Layout.preferredWidth: 44 }
        ActionButton { label: root.media.status === "Playing" ? "Ⅱ" : "▶"; command: ["playerctl", "play-pause"]; highlight: true; Layout.preferredWidth: 52 }
        ActionButton { label: "▶"; command: ["playerctl", "next"]; Layout.preferredWidth: 44 }
    }

    component EqSlider: ColumnLayout {
        property string label: "EQ"
        property real value: 50
        spacing: 6
        Text { text: label; color: root.textSoft; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
        Slider { orientation: Qt.Vertical; from: 0; to: 100; value: parent.value; Layout.preferredHeight: 118; Layout.alignment: Qt.AlignHCenter }
    }

    component GraphCard: Card {
        id: graphCard
        property string title: ""
        property real value: 0
        property real temp: 0
        property var points: []
        property color accentColor: root.cyan

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { Layout.fillWidth: true; text: graphCard.title; color: root.textMain; font.pixelSize: 15; font.weight: Font.Black; elide: Text.ElideRight }
                Text { text: Math.round(graphCard.value) + "%"; color: graphCard.accentColor; font.pixelSize: 18; font.weight: Font.Black }
            }

            Text { text: Math.round(graphCard.temp) + "°C Temp"; color: root.textSoft; font.pixelSize: 11 }

            SparkGraph {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 95
                points: graphCard.points
                strokeColor: graphCard.accentColor
            }
        }
    }

    component RingCard: Card {
        id: ringCard
        property string title: ""
        property real value: 0
        property string sub: ""
        property color accentColor: root.purple

        RowLayout {
            anchors.fill: parent
            anchors.margins: 13
            spacing: 11

            RingMeter { value: ringCard.value; meterColor: ringCard.accentColor; Layout.preferredWidth: 82; Layout.preferredHeight: 82 }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { text: ringCard.title; color: root.textMain; font.pixelSize: 14; font.weight: Font.Black; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: Math.round(ringCard.value) + "%"; color: ringCard.accentColor; font.pixelSize: 18; font.weight: Font.Black }
                Text { text: ringCard.sub; color: root.textMuted; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true }
            }
        }
    }

    component RingMeter: Canvas {
        property real value: 0
        property color meterColor: root.cyan
        onValueChanged: requestPaint()
        onMeterColorChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            const cx = w / 2, cy = h / 2, r = Math.min(w, h) / 2 - 7
            ctx.lineWidth = 8
            ctx.strokeStyle = "#24323a"
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
            ctx.strokeStyle = meterColor
            ctx.lineCap = "round"
            ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI/2, -Math.PI/2 + Math.PI * 2 * Math.max(0, Math.min(100, value)) / 100); ctx.stroke()
        }
        Text { anchors.centerIn: parent; text: Math.round(parent.value) + "%"; color: root.textMain; font.pixelSize: 15; font.weight: Font.Black }
    }

    component SparkGraph: Canvas {
        property var points: []
        property color strokeColor: root.cyan
        onPointsChanged: requestPaint()
        onStrokeColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = "#26132128"
            ctx.fillRect(0, 0, width, height)
            ctx.strokeStyle = "#18ffffff"
            ctx.lineWidth = 1
            for (let i = 1; i < 4; i++) {
                const y = height * i / 4
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
            }
            if (!points || points.length < 2) return
            ctx.strokeStyle = strokeColor
            ctx.lineWidth = 2.4
            ctx.lineJoin = "round"
            ctx.lineCap = "round"
            ctx.beginPath()
            for (let i = 0; i < points.length; i++) {
                const x = i * width / Math.max(1, points.length - 1)
                const y = height - (Math.max(0, Math.min(100, Number(points[i]))) / 100 * height)
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
    }

    component WeatherDayCard: Card {
        property int dayIndex: 0
        ColumnLayout { anchors.fill: parent; anchors.margins: 10; spacing: 5
            Text { text: dayIndex === 0 ? "Today" : Qt.formatDateTime(new Date(root.daily("time")[dayIndex]), "ddd"); color: root.textMain; font.pixelSize: 12; font.weight: Font.Black; Layout.alignment: Qt.AlignHCenter }
            Text { text: root.weatherIcon(root.daily("weather_code")[dayIndex]); color: root.cyan; font.pixelSize: 24; Layout.alignment: Qt.AlignHCenter }
            Text { text: Math.round(root.n(root.daily("temperature_2m_min")[dayIndex], 0)) + "° / " + Math.round(root.n(root.daily("temperature_2m_max")[dayIndex], 0)) + "°"; color: root.textMain; font.pixelSize: 11; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
            Text { text: "wind " + Math.round(root.n(root.daily("wind_speed_10m_max")[dayIndex], 0)) + " km/h"; color: root.textMuted; font.pixelSize: 9; Layout.alignment: Qt.AlignHCenter }
            Text { text: "hum " + Math.round(root.n(root.daily("relative_humidity_2m_mean")[dayIndex], 0)) + "%"; color: root.textMuted; font.pixelSize: 9; Layout.alignment: Qt.AlignHCenter }
        }
    }

    component WeatherFact: Rectangle {
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 12
        color: "#6411222b"
        border.color: root.borderSoft
        RowLayout { anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
            Text { Layout.fillWidth: true; text: label; color: root.textMuted; font.pixelSize: 11 }
            Text { text: value; color: root.textMain; font.pixelSize: 12; font.weight: Font.Bold }
        }
    }

    component LabelValue: ColumnLayout {
        property string label: ""
        property string value: ""
        spacing: 1
        Text { text: label; color: root.textMuted; font.pixelSize: 10 }
        Text { text: value; color: root.textMain; font.pixelSize: 12; font.weight: Font.Bold; elide: Text.ElideRight; Layout.fillWidth: true }
    }

    component ActionTile: Card {
        property string title: ""
        property var command: []
        Layout.fillWidth: true
        Layout.preferredHeight: 90
        Text { anchors.centerIn: parent; text: title; color: root.textMain; font.pixelSize: 15; font.weight: Font.Black }
        MouseArea { anchors.fill: parent; onClicked: if (command.length > 0) Quickshell.execDetached(command) }
    }

    component PowerButton: Card {
        property string title: ""
        property string sub: ""
        property string action: ""
        property bool dangerAction: false
        Layout.fillWidth: true
        Layout.fillHeight: true
        border.color: root.pendingPowerAction === action ? (dangerAction ? root.danger : root.cyan) : root.borderSoft
        ColumnLayout { anchors.centerIn: parent; spacing: 7
            Text { text: root.pendingPowerAction === action ? "Confirm " + title : title; color: dangerAction ? root.danger : root.textMain; font.pixelSize: 20; font.weight: Font.Black; Layout.alignment: Qt.AlignHCenter }
            Text { text: sub; color: root.textMuted; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
        }
        MouseArea { anchors.fill: parent; onClicked: root.runPower(action) }
    }

    component HeaderPill: Rectangle {
        property string main: ""
        property string sub: ""
        Layout.preferredWidth: 92
        Layout.preferredHeight: 40
        radius: 15
        color: "#7713222b"
        border.color: root.borderSoft
        ColumnLayout { anchors.centerIn: parent; spacing: 0
            Text { text: main; color: root.textMain; font.pixelSize: 18; font.weight: Font.Black; Layout.alignment: Qt.AlignHCenter }
            Text { text: sub; color: root.textMuted; font.pixelSize: 9; Layout.alignment: Qt.AlignHCenter }
        }
    }

    component HeaderIconButton: Rectangle {
        property string iconName: ""
        property bool danger: false
        signal clicked()
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        radius: 14
        color: danger ? "#4b1b33" : "#5c122832"
        border.color: danger ? "#80ff80b7" : root.borderSoft
        SvgIcon { anchors.centerIn: parent; iconName: parent.iconName; size: 17 }
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }

    component NavButton: Rectangle {
        property string label: ""
        property string iconName: "grid"
        property bool active: false
        signal clicked()
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: 13
        color: active ? "#5b244451" : "transparent"
        border.color: active ? root.borderActive : "transparent"
        border.width: 1
        RowLayout { anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
            SvgIcon { iconName: parent.parent.iconName; size: 15 }
            Text { Layout.fillWidth: true; text: label; color: active ? root.textMain : root.textMuted; font.pixelSize: 11; font.weight: Font.Bold; elide: Text.ElideRight }
        }
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }

    component SvgIcon: Image {
        property string iconName: "grid"
        property int size: 18
        width: size
        height: size
        source: root.assetDir + "/icons/" + iconName + ".svg"
        fillMode: Image.PreserveAspectFit
        cache: true
        opacity: status === Image.Error ? 0 : 1
    }

    component Card: Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 20
        color: root.cardBg
        border.color: root.borderSoft
        border.width: 1
        antialiasing: true
    }

    component ActionButton: Rectangle {
        property string label: ""
        property var command: []
        property bool highlight: false
        signal clicked()
        Layout.preferredHeight: 38
        radius: 14
        color: highlight ? "#473b69" : "#52162932"
        border.color: highlight ? root.borderActive : root.borderSoft
        border.width: 1
        Text { anchors.centerIn: parent; text: label; color: root.textMain; font.pixelSize: 12; font.weight: Font.Bold }
        MouseArea { anchors.fill: parent; onClicked: { if (command.length > 0) Quickshell.execDetached(command); parent.clicked() } }
    }
}
