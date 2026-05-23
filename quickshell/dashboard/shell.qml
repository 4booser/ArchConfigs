import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool opened: false
    property string homeDir: Quickshell.env("HOME") || "/home/abooser"
    property string userName: Quickshell.env("USER") || "abooser"
    property var payload: ({})
    property var media: payload.media || ({})
    property var sys: payload.system || ({})
    property var weather: payload.weather || ({})
    property var current: weather.current || ({})

    function numberValue(value, fallback) {
        if (value === undefined || value === null || value === "") return fallback
        return value
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
        implicitWidth: 980
        implicitHeight: 560

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
        }

        margins {
            top: 34
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            anchors.margins: 0
            radius: 28
            color: "#ee111821"
            border.color: "#334fd1ff"
            border.width: 1
            clip: true
            antialiasing: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Dashboard"
                            color: "#ffffff"
                            font.family: "Inter"
                            font.pixelSize: 24
                            font.weight: Font.Black
                        }
                        Text {
                            text: "Quickshell safe panel · no fullscreen overlay"
                            color: "#9ba6b2"
                            font.family: "Inter"
                            font.pixelSize: 12
                        }
                    }

                    Button {
                        text: "Refresh"
                        onClicked: root.refreshData()
                    }

                    Button {
                        text: "Close"
                        onClicked: root.close()
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 3
                    rowSpacing: 12
                    columnSpacing: 12

                    InfoCard {
                        title: "Weather · Kyiv"
                        main: Math.round(root.numberValue(root.current.temperature_2m, 0)) + "°C"
                        sub: "humidity " + root.numberValue(root.current.relative_humidity_2m, 0) + "% · wind " + Math.round(root.numberValue(root.current.wind_speed_10m, 0)) + " km/h"
                    }

                    InfoCard {
                        title: "Media"
                        main: root.media.title || "No active track"
                        sub: root.media.artist || root.media.player || "playerctl"
                    }

                    InfoCard {
                        title: "Session"
                        main: root.userName
                        sub: "Arch · Hyprland · Quickshell"
                    }

                    InfoCard {
                        title: "CPU"
                        main: root.numberValue(root.sys.cpu, 0) + "%"
                        sub: root.numberValue(root.sys.cpuTemp, 0) + "°C"
                    }

                    InfoCard {
                        title: "Memory"
                        main: root.numberValue(root.sys.ram, 0) + "%"
                        sub: root.numberValue(root.sys.ramUsed, "0") + "/" + root.numberValue(root.sys.ramTotal, "0") + " GiB"
                    }

                    InfoCard {
                        title: "Disk"
                        main: root.numberValue(root.sys.disk, 0) + "%"
                        sub: root.numberValue(root.sys.diskUsed, "0") + "/" + root.numberValue(root.sys.diskTotal, "0")
                    }

                    InfoCard {
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        title: "Network"
                        main: "↓ " + root.numberValue(root.sys.netDown, 0) + " KiB/s · ↑ " + root.numberValue(root.sys.netUp, 0) + " KiB/s"
                        sub: root.sys.ip || "no IPv4"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 22
                        color: "#dd151d28"
                        border.color: "#22ffffff"
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            Text { text: "Actions"; color: "#86d7ff"; font.pixelSize: 13; font.weight: Font.Bold }
                            Button { Layout.fillWidth: true; text: "Lock"; onClicked: Quickshell.execDetached(["hyprlock"]) }
                            Button { Layout.fillWidth: true; text: "Play / Pause"; onClicked: Quickshell.execDetached(["playerctl", "play-pause"]) }
                            Button { Layout.fillWidth: true; text: "Kill Dashboard"; onClicked: Quickshell.execDetached(["bash", root.homeDir + "/.config/hypr/scripts/dashboard.sh", "--kill"]) }
                        }
                    }
                }
            }
        }
    }

    component InfoCard: Rectangle {
        property string title: ""
        property string main: "--"
        property string sub: ""

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 22
        color: "#dd151d28"
        border.color: "#22ffffff"
        border.width: 1
        antialiasing: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            Text {
                text: title
                color: "#86d7ff"
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.Bold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: main
                color: "#ffffff"
                font.family: "Inter"
                font.pixelSize: 26
                font.weight: Font.Black
                elide: Text.ElideRight
                maximumLineCount: 1
                Layout.fillWidth: true
            }

            Text {
                text: sub
                color: "#9ba6b2"
                font.family: "Inter"
                font.pixelSize: 12
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
