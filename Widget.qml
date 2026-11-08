import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Live system monitor for the bar: CPU %, RAM %, and download speed, each
// fronted by an icon glyph instead of a text label. Data is read straight
// from /proc on a timer, so the widget needs no external service or helper
// process. Left click opens btop in a floating terminal.
BarWidget {
  id: root
  moduleName: "tanzil.sysmon"

  readonly property int intervalMs: Math.max(250, Number(root.setting("intervalMs", 1000)) || 1000)
  readonly property string netInterface: String(root.setting("netInterface", "") || "").trim()

  property int cpuUsage: 0
  property int memUsage: 0
  property real downSpeed: 0

  readonly property color foreground: root.bar ? root.bar.barForeground : Color.foreground
  readonly property string family: root.bar ? root.bar.fontFamily : Style.font.family

  // ---- /proc sources ---------------------------------------------------
  property FileView statFile: FileView { path: "/proc/stat";    preload: false; blockLoading: true; printErrors: false }
  property FileView memFile:  FileView { path: "/proc/meminfo"; preload: false; blockLoading: true; printErrors: false }
  property FileView netFile:  FileView { path: "/proc/net/dev"; preload: false; blockLoading: true; printErrors: false }

  function refresh() {
    statFile.reload()
    memFile.reload()
    netFile.reload()
    root.cpuUsage = Model.readCpuUsage(statFile.text())
    root.memUsage = Model.readMemUsage(memFile.text())
    root.downSpeed = Model.readNetDownload(netFile.text(), root.netInterface)
  }

  Timer {
    id: ticker
    interval: root.intervalMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // ---- layout ----------------------------------------------------------
  readonly property real contentWidth: row.implicitWidth + Style.space(10)
  readonly property real contentHeight: root.barSize

  implicitWidth: root.vertical ? contentHeight : contentWidth
  implicitHeight: root.vertical ? contentWidth : contentHeight

  Item {
    id: layout
    anchors.fill: parent

    Row {
      id: row
      anchors.centerIn: parent
      spacing: Style.space(10)
      rotation: root.vertical ? 90 : 0
      transformOrigin: Item.Center

      SysSegment { icon: "\uf2db"; value: root.cpuUsage + "%"; fixedValueWidth: 40 }
      SysSegment { icon: "\uefc5"; value: root.memUsage + "%"; fixedValueWidth: 40 }
      SysSegment { icon: "\uf019"; value: Model.formatSpeed(root.downSpeed); fixedValueWidth: 76 }
    }
  }

  component SysSegment: Row {
    id: segment
    required property string icon
    required property string value
    // Fixed-width, right-aligned value cell: digit changes never reflow the
    // bar, so 1/2/3-digit values occupy identical space.
    readonly property real valueWidth: segment.fixedValueWidth
    property real fixedValueWidth: 0

    spacing: Style.space(4)

    Item {
      width: Style.bar.iconFont
      height: Style.bar.iconFont

      OpticalGlyph {
        anchors.centerIn: parent
        text: segment.icon
        fontFamily: root.family
        fontSize: Style.bar.iconFont
        color: root.foreground
      }
    }

    Text {
      width: segment.valueWidth
      anchors.verticalCenter: parent.verticalCenter
      text: segment.value
      horizontalAlignment: Text.AlignRight
      color: root.foreground
      font.family: "monospace"
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering
    }
  }

  // ---- interaction -----------------------------------------------------
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    keepSpace: true
    hasVisualContent: true
    labelVisible: false
    tooltipText: "CPU " + root.cpuUsage + "%  ·  RAM " + root.memUsage + "%  ·  " + Model.formatSpeed(root.downSpeed) + " down"
    onPressed: function(b) {
      if (b === Qt.LeftButton && root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation btop")
    }
  }
}