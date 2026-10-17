// BenQ RD270Q bar widget + popup: brightness, Low Blue Light,
// Night Hours (+ level), Visual Optimizer (+ mode).
// Modeled on the built-in omarchy.monitor panel.
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "lnhdb.benq-rd270q"
  ipcTarget: "lnhdb.benq-rd270q"

  // An explicit "bus" setting wins; otherwise `ddcutil detect` finds the monitor once.
  readonly property string busOverride: String(setting("bus", ""))
  property string detectedBus: ""
  readonly property string bus: busOverride !== "" ? busOverride : detectedBus

  // "detecting" until a bus is known, "missing" when no BenQ display was found,
  // then "ready" or "silent" depending on whether the last read answered.
  property string status: busOverride !== "" ? "silent" : "detecting"
  readonly property bool ready: status === "ready"

  // Last known monitor values, keyed by VCP code.
  property int brightness: 0
  property int lowblue: 0
  property bool night: false
  property int nightLevel: 1
  property int voMode: 0          // 0 = off, 1 = bri + ct, 2 = brightness
  property int lastVoMode: Model.VO_BRI

  // Coalescing writer: one slot per code, one ddcutil process at a time.
  property var pending: ({})
  property int inflightCode: -1
  readonly property var switchCodes: [Model.VCP.night, Model.VCP.vo, Model.VCP.lowblue]

  // Keyboard cursor: one entry per visible row.
  readonly property var rows: {
    var r = ["brightness", "lowblue", "night"]
    if (night) r.push("nightLevel")
    r.push("vo")
    if (voMode !== 0) r.push("voMode")
    return r
  }
  property string cursorRow: "brightness"
  property bool cursorActive: false
  onRowsChanged: if (rows.indexOf(cursorRow) < 0) cursorRow = rows[0]

  function write(code, value) {
    pending = Model.enqueue(pending, code, value)
    pump()
  }

  function pump() {
    if (writer.running || bus === "") return
    var next = Model.takeNext(pending)
    if (!next) {
      // Switches make the monitor move other values (V.O. off can change
      // brightness), so re-read once the queue drains after one.
      if (switchCodes.indexOf(inflightCode) >= 0) refresh()
      inflightCode = -1
      return
    }
    pending = next.rest
    inflightCode = next.code
    writer.command = ["ddcutil", "--bus", root.bus, "--permit-unknown-feature", "--noverify",
                      "setvcp", Model.hex(next.code), String(next.value)]
    writer.running = true
  }

  function busy(code) {
    return inflightCode === code || pending[code] !== undefined
  }

  function setBrightness(v) { brightness = Model.clamp(v, 0, 100); write(Model.VCP.brightness, brightness) }
  function setLowblue(v)    { lowblue = Model.clamp(v, 0, 5); write(Model.VCP.lowblue, lowblue) }
  function setNight(on)     { night = on; write(Model.VCP.night, on ? 1 : 0) }
  function setNightLevel(v) { nightLevel = Model.clamp(v, 1, 10); write(Model.VCP.nightLevel, nightLevel) }
  function setVoMode(m)     { voMode = m; if (m !== 0) lastVoMode = m; write(Model.VCP.vo, m) }
  function setVo(on)        { setVoMode(on ? lastVoMode : 0) }

  function refresh() {
    if (bus === "") detect()
    else if (!reader.running) reader.running = true
  }

  function detect() {
    if (detector.running) return
    status = "detecting"
    detector.running = true
  }

  function applyDetect(displays) {
    detectedBus = Model.pickBus(displays)
    if (bus === "") { status = "missing"; return }
    status = "silent"
    refresh()
  }

  function applyRead(s) {
    var V = Model.VCP
    // Skip codes with a write queued or in flight so the UI never bounces back.
    if (s[V.brightness] !== undefined && !busy(V.brightness)) brightness = s[V.brightness]
    if (s[V.lowblue] !== undefined && !busy(V.lowblue)) lowblue = s[V.lowblue]
    if (s[V.night] !== undefined && !busy(V.night)) night = s[V.night] !== 0
    if (s[V.nightLevel] !== undefined && !busy(V.nightLevel)) nightLevel = s[V.nightLevel]
    if (s[V.vo] !== undefined && !busy(V.vo)) { voMode = s[V.vo]; if (voMode !== 0) lastVoMode = voMode }
    status = s[V.brightness] !== undefined ? "ready" : "silent"
  }

  // Keyboard: j/k move rows, h/l adjust, Enter toggles.
  function moveCursor(d) {
    var i = rows.indexOf(cursorRow) + d
    cursorRow = rows[Math.max(0, Math.min(rows.length - 1, i))]
  }
  function adjust(d) {
    switch (cursorRow) {
      case "brightness": setBrightness(brightness + d * 5); break
      case "lowblue": setLowblue(lowblue + d); break
      case "nightLevel": setNightLevel(nightLevel + d); break
      case "voMode": setVoMode(d > 0 ? Model.VO_BRI : Model.VO_BRI_CT); break
      case "night": setNight(d > 0); break
      case "vo": setVo(d > 0); break
    }
  }
  function activate() {
    if (cursorRow === "night") setNight(!night)
    else if (cursorRow === "vo") setVo(voMode === 0)
    else if (cursorRow === "voMode") setVoMode(voMode === Model.VO_BRI ? Model.VO_BRI_CT : Model.VO_BRI)
  }

  property real wheelAccumulator: 0

  function stateJson() {
    return JSON.stringify({ brightness: brightness, lowblue: lowblue, night: night,
                            nightLevel: nightLevel, voMode: voMode, rows: rows,
                            status: status, bus: bus, queued: Object.keys(pending).length })
  }

  // Same entry points the popup uses, so scripts (and tests) drive the real path:
  //   quickshell -p $OMARCHY_PATH/shell ipc call lnhdb.benq-rd270q.monitor set brightness 40
  function setIpc(name, value) {
    var n = parseInt(value, 10)
    switch (name) {
      case "brightness": setBrightness(n); break
      case "lowblue": setLowblue(n); break
      case "night": setNight(value === "on" || n === 1); break
      case "night-level": setNightLevel(n); break
      case "vo": setVo(value === "on" || n === 1); break
      case "vo-mode": setVoMode(value === "bri-ct" ? Model.VO_BRI_CT : Model.VO_BRI); break
      default: return "unknown " + name
    }
    return stateJson()
  }

  // The host owns the "lnhdb.benq-rd270q" target (open/close/toggle); state and
  // set live on their own target.
  IpcHandler {
    target: "lnhdb.benq-rd270q.monitor"
    function state(): string { return root.stateJson() }
    function refresh(): void { root.refresh() }
    function set(name: string, value: string): string { return root.setIpc(name, value) }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()
  onOpenedChanged: if (opened) {
    // A silent auto-detected bus may be stale (monitor moved ports), so look again.
    if (status === "silent" && busOverride === "") detectedBus = ""
    refresh(); cursorActive = false; cursorRow = "brightness"
  }

  Timer { interval: 5000; repeat: true; running: root.opened; onTriggered: root.refresh() }
  // Keep the bar glyph (moon while Night Hours is on) roughly current. Detection
  // is not retried here; opening the popup retries it.
  Timer { interval: 60000; repeat: true; running: !root.opened && root.bus !== ""; onTriggered: root.refresh() }

  Process {
    id: detector
    command: ["ddcutil", "detect", "--brief"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyDetect(Model.parseDetect(text))
    }
  }

  Process {
    id: reader
    command: ["ddcutil", "--bus", root.bus, "--permit-unknown-feature", "--brief",
              "getvcp", "10", "19", "d1", "d0", "81"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyRead(Model.parseBrief(text))
    }
  }

  Process {
    id: writer
    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: if (!running) root.pump()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.status === "missing" ? "󰶐" : root.night ? "󰖔" : "󰃞"
    onPressed: function(b) { root.toggle() }
    onWheelMoved: function(delta) {
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps !== 0) root.setBrightness(root.brightness + wheel.steps * 5)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.adjust(dx)
      }
      onActivateRequested: if (root.cursorActive) root.activate()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        // ---------- Hero ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroText.implicitHeight)
          Text {
            id: heroIcon
            text: "󰃞"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.verticalCenter: parent.verticalCenter
          }
          Column {
            id: heroText
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)
            Text {
              text: "BenQ RD270Q"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: ({ detecting: "LOOKING FOR MONITOR",
                       missing: "NO BENQ MONITOR FOUND",
                       silent: "MONITOR NOT RESPONDING ON BUS " + root.bus,
                       ready: "DDC/CI · BUS " + root.bus })[root.status]
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }
        }

        Column {
          visible: root.ready
          width: parent.width
          spacing: Style.space(12)

          PanelSeparator { foreground: root.bar.foreground }

          SliderRow {
            row: "brightness"; icon: "󰃠"; label: "BRIGHTNESS"
            minimum: 0; maximum: 100; value: root.brightness; suffix: "%"
            onPicked: function(v) { root.setBrightness(v) }
          }

          SliderRow {
            row: "lowblue"; icon: "󰈈"; label: "LOW BLUE LIGHT"
            minimum: 0; maximum: 5; ticks: 6; value: root.lowblue
            valueText: root.lowblue === 0 ? "Off" : String(root.lowblue)
            onPicked: function(v) { root.setLowblue(v) }
          }

          PanelSeparator { foreground: root.bar.foreground }

          ToggleRow {
            row: "night"; icon: "󰖔"; label: "Night Hours Protection"
            checked: root.night
            onToggled: root.setNight(!root.night)
          }

          SliderRow {
            visible: root.night
            row: "nightLevel"; icon: "󰽥"; label: "NIGHT LEVEL"
            minimum: 1; maximum: 10; ticks: 10; value: root.nightLevel
            onPicked: function(v) { root.setNightLevel(v) }
          }

          PanelSeparator { foreground: root.bar.foreground }

          ToggleRow {
            row: "vo"; icon: "󰃡"; label: "Visual Optimizer"
            checked: root.voMode !== 0
            onToggled: root.setVo(root.voMode === 0)
          }

          CursorSurface {
            id: voModeRow
            visible: root.voMode !== 0
            width: parent.width
            implicitHeight: voModeButtons.implicitHeight + Style.spacing.controlGap
            hasCursor: root.cursorActive && root.cursorRow === "voMode"
            foreground: root.bar.foreground
            outline: true
            HoverHandler { onHoveredChanged: if (hovered) { root.cursorActive = true; root.cursorRow = "voMode" } }

            Row {
              id: voModeButtons
              anchors.centerIn: parent
              width: parent.width - Style.space(12)
              spacing: Style.spacing.xs
              Repeater {
                model: [{ mode: Model.VO_BRI_CT, text: "󰃠 Bri + Color Temp" },
                        { mode: Model.VO_BRI, text: "󰃠 Brightness" }]
                Button {
                  required property var modelData
                  width: (voModeButtons.width - voModeButtons.spacing) / 2
                  text: modelData.text
                  fontSize: Style.font.caption
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  verticalPadding: Style.spacing.controlPaddingY
                  bordered: true
                  active: root.voMode === modelData.mode
                  onClicked: root.setVoMode(modelData.mode)
                }
              }
            }
          }
        }

        Item { width: parent.width; height: Style.space(4) }
      }
    }
  }

  component SliderRow: Column {
    id: sr
    property string row
    property string icon
    property string label
    property real minimum: 0
    property real maximum: 100
    property int ticks: 0
    property int value: 0
    property string suffix: ""
    property string valueText: String(Math.round(slider.dragging ? slider.liveValue : value)) + suffix
    signal picked(int v)

    width: parent ? parent.width : 0
    spacing: Style.space(6)

    Item {
      width: parent.width
      implicitHeight: header.implicitHeight
      PanelSectionHeader {
        id: header
        text: sr.icon + "  " + sr.label
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: sr.valueText
        color: Qt.darker(root.bar.foreground, 1.4)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.right: parent.right
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    CursorSurface {
      width: parent.width
      height: slider.implicitHeight + Style.spacing.controlGap
      hasCursor: root.cursorActive && root.cursorRow === sr.row
      foreground: root.bar.foreground
      outline: true
      PanelSlider {
        id: slider
        bar: root.bar
        anchors.fill: parent
        anchors.leftMargin: Style.space(6)
        anchors.rightMargin: Style.space(6)
        minimum: sr.minimum
        maximum: sr.maximum
        step: 1
        integer: true
        tickCount: sr.ticks
        value: sr.value
        // Instant: every move is written; the queue drops superseded values.
        onMoved: function(v) { if (Math.round(v) !== sr.value) sr.picked(Math.round(v)) }
        onReleased: function(v) { if (Math.round(v) !== sr.value) sr.picked(Math.round(v)) }
      }
      HoverHandler { onHoveredChanged: if (hovered) { root.cursorActive = true; root.cursorRow = sr.row } }
    }
  }

  component ToggleRow: CursorSurface {
    id: tr
    property string row
    property string icon
    property string label
    property bool checked: false
    signal toggled()

    width: parent ? parent.width : 0
    implicitHeight: sw.implicitHeight + Style.spacing.controlGap
    hasCursor: root.cursorActive && root.cursorRow === tr.row
    foreground: root.bar.foreground

    Text {
      text: tr.icon + "  " + tr.label
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      anchors.left: parent.left
      anchors.leftMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }
    ToggleSwitch {
      id: sw
      checked: tr.checked
      foreground: root.bar.foreground
      cursorRing: false
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      onToggled: tr.toggled()
    }
    MouseArea {
      anchors.fill: parent
      anchors.rightMargin: sw.width + Style.space(6)
      hoverEnabled: true
      onContainsMouseChanged: if (containsMouse) { root.cursorActive = true; root.cursorRow = tr.row }
      onClicked: tr.toggled()
    }
  }
}
