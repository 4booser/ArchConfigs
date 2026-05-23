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
    property string userName: Quickshell.env("USER") || "abooser"
    property string homeDir: Quickshell.env("HOME") || "/home/abooser"
    property var payload: ({})
    property var media: payload.media || ({})
    property var sys: payload.system || ({})
    property var weather: payload.weather || ({})
    property int panelW: 1180
    property int panelH: 690

    function toggle(): void {
        opened = !opened
        if (opened) dataProcess.running = true
    }

    function open(): void {
        opened = true
        dataProcess.running = true
    }

    function close(): void {
        opened = false
    }

    function tabName(i) {
        return ["Dashboard", "Media", "Performance", "Weather"][i]
    }

    function weatherIcon(code) {
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

    function dayName(dateText, index) {
        if (index === 0) return "Today"
        const d = new Date(dateText)
        return d.toLocaleDateString(Qt.locale(), "ddd")
    }

    function shortDate(dateText) {
        const d = new Date(dateText)
        return d.toLocaleDateString(Qt.locale(), "dd.MM")
    }

    Process {
        id: dataProcess
        command: [root.homeDir + "/.config/quickshell/dashboard/scripts/dashboard-data.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.payload = JSON.parse(this.text)
                } catch (e) {
                    console.warn("dashboard-data parse error", e, this.text)
                }
            }
        }
    }

    Timer {
        interval: 1500
        running: root.opened
        repeat: true
        triggeredOnStart: true
        onTriggered: dataProcess.running = true
    }

    IpcHandler {
        target: "dashboard"
        function toggle(): void { root.toggle() }
        function open(): void { root.open() }
        function close(): void { root.close() }
    }

    PanelWindow {
        id: win
        visible: true
        color: "transparent"
        aboveWindows: true
        focusable: root.opened
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: screen ? screen.width : 1920
        implicitHeight: screen ? screen.height : 1080

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.opened
            onClicked: root.close()

            Rectangle {
                anchors.fill: parent
                opacity: root.opened ? 1 : 0
                color: "#22000000"
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
        }

        Rectangle {
            id: panel
            width: root.panelW
            height: root.panelH
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.opened ? 34 : -height - 40
            radius: 32
            color: "#d80b1b22"
            border.color: "#3affb8ea"
            border.width: 1
            clip: true
            layer.enabled: true
            antialiasing: true

            Behavior on y {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: mouse.accepted = true
            }

            Rectangle {
                anchors.fill: parent
                opacity: 0.85
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#42132735" }
                    GradientStop { position: 0.48; color: "#23101a24" }
                    GradientStop { position: 1.0; color: "#37142630" }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Dashboard"
                            color: "#ffffff"
                            font.family: "Inter"
                            font.pixelSize: 26
                            font.weight: Font.Black
                        }
                        Text {
                            text: "music · weather · calendar · performance"
                            color: "#a99cb3"
                            font.family: "Inter"
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 548
                        Layout.preferredHeight: 42
                        radius: 21
                        color: "#d014101c"
                        border.color: "#20ffffff"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 4
                            spacing: 4
                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 18
                                    color: root.activeTab === index ? "#7d8fd3ff" : "transparent"
                                    border.color: root.activeTab === index ? "#77ffd6f5" : "transparent"
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 160 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.tabName(index)
                                        color: root.activeTab === index ? "#ffffff" : "#c9bed2"
                                        font.family: "Inter"
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.activeTab = index
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 19
                        color: "#33ff6f9d"
                        border.color: "#66ff9bb9"
                        Text { anchors.centerIn: parent; text: "×"; color: "#ffd3df"; font.pixelSize: 18; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; onClicked: root.close() }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    DashboardPage { visible: root.activeTab === 0; anchors.fill: parent }
                    MediaPage { visible: root.activeTab === 1; anchors.fill: parent }
                    PerformancePage { visible: root.activeTab === 2; anchors.fill: parent }
                    WeatherPage { visible: root.activeTab === 3; anchors.fill: parent }
                }
            }
        }
    }

    component Card: Rectangle {
        property string title: ""
        radius: 24
        color: "#ef15111d"
        border.color: "#18ffffff"
        border.width: 1
        antialiasing: true
    }

    component ActionButton: Rectangle {
        property string textValue: ""
        property string command: ""
        radius: 18
        color: "#ee1d1726"
        border.color: "#20ffffff"
        border.width: 1
        Layout.preferredHeight: 58
        Text {
            anchors.centerIn: parent
            text: parent.textValue
            color: "#ffffff"
            font.family: "Inter"
            font.pixelSize: 14
            font.weight: Font.Bold
        }
        MouseArea {
            anchors.fill: parent
            onClicked: Quickshell.execDetached(["sh", "-lc", command])
        }
    }

    component MediaControls: RowLayout {
        spacing: 12
        ActionButton { textValue: "⏮"; command: "playerctl previous"; Layout.preferredWidth: 56 }
        ActionButton { textValue: (root.media.status || "") === "Playing" ? "⏸" : "▶"; command: "playerctl play-pause"; Layout.preferredWidth: 66; Layout.preferredHeight: 66; radius: 33; color: "#aa9a72ff" }
        ActionButton { textValue: "⏭"; command: "playerctl next"; Layout.preferredWidth: 56 }
    }

    component AlbumArt: Rectangle {
        property int artSize: 160
        width: artSize
        height: artSize
        radius: 22
        color: "#ff0f0d14"
        border.color: "#24ffffff"
        clip: true
        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            cache: false
            source: {
                const art = root.media.art || ""
                if (art.startsWith("file://") || art.startsWith("http")) return art
                return ""
            }
        }
        Text {
            anchors.centerIn: parent
            visible: !((root.media.art || "").length > 0)
            text: "♪"
            color: "#a88fd3ff"
            font.pixelSize: 56
        }
    }

    component DashboardPage: GridLayout {
        columns: 3
        rowSpacing: 12
        columnSpacing: 12

        Card {
            Layout.preferredWidth: 270
            Layout.preferredHeight: 180
            ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 4
                Text { text: "Kyiv"; color: "#ffffff"; font.pixelSize: 22; font.weight: Font.Black }
                Text { text: Math.round(root.weather.current?.temperature_2m || 0) + "°C"; color: "#ffffff"; font.pixelSize: 52; font.weight: Font.Black }
                Text { text: "humidity " + (root.weather.current?.relative_humidity_2m || 0) + "% · wind " + Math.round(root.weather.current?.wind_speed_10m || 0) + " km/h"; color: "#b8acbf"; font.pixelSize: 12 }
            }
        }

        Card {
            Layout.preferredWidth: 420
            Layout.preferredHeight: 180
            RowLayout { anchors.fill: parent; anchors.margins: 18; spacing: 16
                AlbumArt { artSize: 132 }
                ColumnLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: root.media.title || "No active track"; color: "#ffffff"; font.pixelSize: 20; font.weight: Font.Black; elide: Text.ElideRight; Layout.fillWidth: true; maximumLineCount: 1 }
                    Text { text: root.media.artist || root.media.player || ""; color: "#b8acbf"; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                    MediaControls {}
                    Text { text: "App volume · " + (root.media.volume || 100) + "%"; color: "#b8acbf"; font.pixelSize: 12 }
                    Slider { Layout.fillWidth: true; from: 0; to: 150; value: root.media.volume || 100; onMoved: if (root.media.sinkId) Quickshell.execDetached(["pactl", "set-sink-input-volume", String(root.media.sinkId), Math.round(value) + "%"]) }
                }
            }
        }

        Card {
            Layout.preferredWidth: 390
            Layout.preferredHeight: 180
            RowLayout { anchors.fill: parent; anchors.margins: 18; spacing: 12
                ActionButton { textValue: "Lock"; command: "hyprlock"; Layout.fillWidth: true }
                ActionButton { textValue: "Reboot"; command: "systemctl reboot"; Layout.fillWidth: true }
                ActionButton { textValue: "Power"; command: "systemctl poweroff"; Layout.fillWidth: true }
            }
        }

        Card {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            CalendarGrid { anchors.fill: parent; anchors.margins: 18 }
        }

        Card {
            Layout.preferredWidth: 390
            Layout.fillHeight: true
            ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 14
                Text { text: root.userName; color: "#ffffff"; font.pixelSize: 22; font.weight: Font.Black }
                Text { text: "Arch · Hyprland"; color: "#b8acbf"; font.pixelSize: 13 }
                Item { Layout.fillHeight: true }
                Text { text: new Date().toLocaleTimeString(Qt.locale(), "hh:mm"); color: "#ffffff"; font.pixelSize: 56; font.weight: Font.Black; Layout.alignment: Qt.AlignHCenter }
            }
        }
    }

    component MediaPage: RowLayout {
        spacing: 12
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            RowLayout { anchors.fill: parent; anchors.margins: 26; spacing: 28
                AlbumArt { artSize: 260 }
                ColumnLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 16
                    Text { text: root.media.title || "No active track"; color: "#ffffff"; font.pixelSize: 28; font.weight: Font.Black; elide: Text.ElideRight; maximumLineCount: 1; Layout.fillWidth: true }
                    Text { text: root.media.artist || ""; color: "#b8acbf"; font.pixelSize: 15; elide: Text.ElideRight; Layout.fillWidth: true }
                    MediaControls {}
                    Slider { Layout.fillWidth: true; from: 0; to: 150; value: root.media.volume || 100; onMoved: if (root.media.sinkId) Quickshell.execDetached(["pactl", "set-sink-input-volume", String(root.media.sinkId), Math.round(value) + "%"]) }
                    Text { text: "Equalizer"; color: "#ffb8ea"; font.pixelSize: 13; font.weight: Font.Bold }
                    RowLayout { Layout.fillWidth: true; spacing: 20
                        EqSlider { label: "Bass"; value: 58 }
                        EqSlider { label: "Mid"; value: 42 }
                        EqSlider { label: "Treble"; value: 50 }
                        EqSlider { label: "Reverb"; value: 24 }
                    }
                    Text { text: "EQ sliders are UI-ready. For real audio EQ install EasyEffects and I’ll wire these sliders to presets."; color: "#8d8294"; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
            }
        }
        Card {
            Layout.preferredWidth: 330
            Layout.fillHeight: true
            ColumnLayout { anchors.fill: parent; anchors.margins: 20; spacing: 12
                Image { Layout.fillWidth: true; Layout.fillHeight: true; fillMode: Image.PreserveAspectFit; cache: false; source: root.homeDir + "/.config/quickshell/dashboard/assets/bongo-cat.gif" }
            }
        }
    }

    component EqSlider: ColumnLayout {
        property string label: "EQ"
        property int value: 50
        spacing: 8
        Text { text: label; color: "#cdbed7"; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }
        Slider { orientation: Qt.Vertical; from: 0; to: 100; value: parent.value; Layout.preferredHeight: 150; Layout.alignment: Qt.AlignHCenter }
    }

    component PerformancePage: GridLayout {
        columns: 3
        rowSpacing: 12
        columnSpacing: 12
        PerfCard { title: "CPU"; value: (root.sys.cpu || 0) + "% · " + (root.sys.cpuTemp || 0) + "°C" }
        PerfCard { title: "GPU"; value: (root.sys.gpu || 0) + "% · " + (root.sys.gpuTemp || 0) + "°C" }
        PerfCard { title: "Memory"; value: (root.sys.ram || 0) + "% · " + (root.sys.ramUsed || "0") + "/" + (root.sys.ramTotal || "0") + " GiB" }
        PerfCard { title: "Storage"; value: (root.sys.disk || 0) + "% · " + (root.sys.diskUsed || "0") + "/" + (root.sys.diskTotal || "0") }
        PerfCard { title: "Network"; value: "↓ " + (root.sys.netDown || 0) + " KiB/s · ↑ " + (root.sys.netUp || 0) + " KiB/s" }
        PerfCard { title: "IP"; value: root.sys.ip || "--" }
        GraphCard { title: "CPU graph"; value: root.sys.cpu || 0; Layout.columnSpan: 1; Layout.fillWidth: true; Layout.fillHeight: true }
        GraphCard { title: "GPU graph"; value: root.sys.gpu || 0; Layout.columnSpan: 1; Layout.fillWidth: true; Layout.fillHeight: true }
        GraphCard { title: "Internet graph"; value: root.sys.netGraph || 0; Layout.columnSpan: 1; Layout.fillWidth: true; Layout.fillHeight: true }
    }

    component PerfCard: Card {
        property string title: ""
        property string value: ""
        Layout.preferredHeight: 92
        Layout.fillWidth: true
        ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 8
            Text { text: title; color: "#ffb8ea"; font.pixelSize: 13; font.weight: Font.Bold }
            Text { text: value; color: "#ffffff"; font.pixelSize: 20; font.weight: Font.Black; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }

    component GraphCard: Card {
        property string title: ""
        property int value: 0
        ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 8
            Text { text: title; color: "#ffb8ea"; font.pixelSize: 13; font.weight: Font.Bold }
            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: 16; color: "#55100d15"; clip: true
                Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: parent.width; height: Math.max(6, parent.height * value / 100); color: "#88ff74d6"; Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } } }
            }
        }
    }

    component WeatherPage: ColumnLayout {
        spacing: 12
        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: 200
            RowLayout { anchors.fill: parent; anchors.margins: 24; spacing: 24
                Text { text: root.weatherIcon(root.weather.current?.weather_code || 3); color: "#7ee0d4"; font.pixelSize: 90; Layout.alignment: Qt.AlignVCenter }
                ColumnLayout { Layout.fillWidth: true; spacing: 8
                    Text { text: "Kyiv · " + Math.round(root.weather.current?.temperature_2m || 0) + "°C"; color: "#ffffff"; font.pixelSize: 48; font.weight: Font.Black }
                    Text { text: root.weatherText(root.weather.current?.weather_code || 3); color: "#cfc3d8"; font.pixelSize: 18 }
                    RowLayout { spacing: 12
                        WeatherMini { title: "Humidity"; value: (root.weather.current?.relative_humidity_2m || 0) + "%" }
                        WeatherMini { title: "Wind"; value: Math.round(root.weather.current?.wind_speed_10m || 0) + " km/h" }
                        WeatherMini { title: "Sunrise"; value: (root.weather.daily?.sunrise?.[0] || "--T--").slice(-5) }
                        WeatherMini { title: "Sunset"; value: (root.weather.daily?.sunset?.[0] || "--T--").slice(-5) }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            Repeater {
                model: root.weather.daily?.time?.length ? 7 : 0
                delegate: Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: index === 0 ? "#bf37224a" : "#ef15111d"
                    border.color: index === 0 ? "#88ffd6f5" : "#18ffffff"
                    ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 8
                        Text { text: root.dayName(root.weather.daily.time[index], index); color: "#ffffff"; font.pixelSize: 14; font.weight: Font.Black }
                        Text { text: root.shortDate(root.weather.daily.time[index]); color: "#94889e"; font.pixelSize: 12 }
                        Item { Layout.fillHeight: true }
                        Text { text: root.weatherIcon(root.weather.daily.weather_code[index]); color: "#7ee0d4"; font.pixelSize: 34; Layout.alignment: Qt.AlignHCenter }
                        Text { text: Math.round(root.weather.daily.temperature_2m_min[index]) + "° / " + Math.round(root.weather.daily.temperature_2m_max[index]) + "°"; color: "#ffffff"; font.pixelSize: 15; font.weight: Font.Bold }
                        Text { text: "☂ " + Math.round(root.weather.daily.relative_humidity_2m_mean[index]) + "%"; color: "#cfc3d8"; font.pixelSize: 12 }
                        Text { text: "≋ " + Math.round(root.weather.daily.wind_speed_10m_max[index]) + " km/h"; color: "#cfc3d8"; font.pixelSize: 12 }
                    }
                }
            }
        }
    }

    component WeatherMini: Rectangle {
        property string title: ""
        property string value: ""
        Layout.preferredWidth: 130
        Layout.preferredHeight: 56
        radius: 16
        color: "#661b1420"
        border.color: "#18ffffff"
        ColumnLayout { anchors.centerIn: parent; spacing: 0
            Text { text: title; color: "#9d91a7"; font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
            Text { text: value; color: "#ffffff"; font.pixelSize: 14; font.weight: Font.Bold; Layout.alignment: Qt.AlignHCenter }
        }
    }

    component CalendarGrid: ColumnLayout {
        spacing: 10
        property date now: new Date()
        Text { text: now.toLocaleDateString(Qt.locale(), "MMMM yyyy"); color: "#ffffff"; font.pixelSize: 18; font.weight: Font.Black; Layout.alignment: Qt.AlignHCenter }
        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 7
            rowSpacing: 8
            columnSpacing: 8
            Repeater {
                model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                delegate: Text { text: modelData; color: "#ffb8ea"; font.pixelSize: 12; font.weight: Font.Bold; horizontalAlignment: Text.AlignHCenter; Layout.preferredWidth: 34 }
            }
            Repeater {
                model: 35
                delegate: Rectangle {
                    property int firstOffset: (new Date(now.getFullYear(), now.getMonth(), 1).getDay() + 6) % 7
                    property int dayNum: index - firstOffset + 1
                    property int daysInMonth: new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
                    property bool valid: dayNum > 0 && dayNum <= daysInMonth
                    property bool today: valid && dayNum === now.getDate()
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 30
                    radius: 10
                    color: today ? "#66ff74d6" : "transparent"
                    border.color: today ? "#99ffd6f5" : "transparent"
                    Text { anchors.centerIn: parent; text: parent.valid ? parent.dayNum : ""; color: parent.today ? "#ffffff" : "#cfc3d8"; font.pixelSize: 13; font.weight: parent.today ? Font.Black : Font.Bold }
                }
            }
        }
    }
}
