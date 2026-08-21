import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// VoxType: always-visible bar control for dictation.
//
// Omarchy already ships a hover-only Dictation indicator that opens the
// configure TUI. This chip stays on the bar: live state, right-click
// toggles recording, the panel owns daemon control and a door into
// `voxtype configure`.
Panel {
  id: root

  moduleName: "contra.voxtype"
  ipcTarget: "contra.voxtype"
  manageIpc: true

  property string daemonState: "idle"
  property bool daemonActive: false
  property string modelName: ""
  property string backendName: ""
  property bool cursorActive: false
  property int focusIndex: 0

  readonly property color fg: bar ? bar.barForeground : Color.bar.text
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string runtimeDir: {
    var xdg = Quickshell.env("XDG_RUNTIME_DIR")
    return xdg && xdg.length > 0 ? xdg : "/run/user/1000"
  }
  readonly property bool engaged: Model.barActive(daemonState, daemonActive)
  readonly property int controlCount: 4

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refreshDaemon() {
    if (!daemonProc.running) daemonProc.running = true
  }

  function refreshStatus() {
    if (!statusProc.running) statusProc.running = true
  }

  function runAction(command) {
    if (actionProc.running) return
    actionProc.command = command
    actionProc.running = true
  }

  function toggleRecording() {
    if (!root.daemonActive) {
      runAction(Model.startDaemonCommand())
      return
    }
    runAction(Model.recordToggleCommand())
  }

  function setDaemon(on) {
    if (on === root.daemonActive && !actionProc.running) return
    runAction(on ? Model.startDaemonCommand() : Model.stopDaemonCommand())
  }

  function restartDaemon() {
    runAction(Model.restartDaemonCommand())
  }

  function openSettings() {
    if (root.bar) root.bar.run("omarchy-voxtype-config")
    root.close()
  }

  function activateFocused() {
    if (focusIndex === 0) setDaemon(!root.daemonActive)
    else if (focusIndex === 1) toggleRecording()
    else if (focusIndex === 2) openSettings()
    else restartDaemon()
  }

  onOpenedChanged: if (opened) {
    refreshDaemon()
    refreshStatus()
    cursorActive = false
    focusIndex = 0
  }

  Component.onCompleted: {
    refreshDaemon()
    refreshStatus()
  }

  FileView {
    id: stateFile
    path: root.runtimeDir + "/voxtype/state"
    watchChanges: true
    printErrors: false
    onLoaded: root.daemonState = Model.normalizeState(text())
    onLoadFailed: {
      if (!root.daemonActive) root.daemonState = "stopped"
    }
    onFileChanged: reload()
  }

  Process {
    id: daemonProc
    command: Model.daemonCommand()
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.daemonActive = Model.daemonActiveFromShow(text)
    }
  }

  Process {
    id: statusProc
    command: Model.statusCommand()
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseStatusJson(text)
        if (parsed.model) root.modelName = parsed.model
        if (parsed.backend) root.backendName = parsed.backend
        if (parsed.state && parsed.state !== "idle")
          root.daemonState = parsed.state
      }
    }
  }

  Process {
    id: actionProc
    onExited: {
      Qt.callLater(root.refreshDaemon)
      Qt.callLater(root.refreshStatus)
    }
  }

  Timer {
    interval: root.opened ? 1500 : 4000
    running: true
    repeat: true
    onTriggered: root.refreshDaemon()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.glyph(root.daemonState, root.daemonActive)
    active: root.engaged
    dimmed: !root.daemonActive
    useActiveColor: true
    tooltipText: Model.tooltip(root.daemonState, root.daemonActive, root.modelName, root.backendName)
    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggleRecording()
      else if (b === Qt.MiddleButton) root.openSettings()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        root.cursorActive = true
        var delta = dy !== 0 ? dy : dx
        root.focusIndex = Math.max(0, Math.min(root.controlCount - 1, root.focusIndex + delta))
      }
      onActivateRequested: if (root.cursorActive) root.activateFocused()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        PanelHero {
          title: "VoxType"
          meta: Model.heroMeta(root.daemonState, root.daemonActive, root.modelName, root.backendName)
          detail: Model.heroDetail(root.daemonState, root.daemonActive)
          foreground: root.fg
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              width: Style.font.display
              height: Style.font.display
              text: Model.glyph(root.daemonState, root.daemonActive)
              color: root.engaged ? (root.bar ? root.bar.urgent : Color.urgent) : root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }

        PanelSeparator { foreground: root.fg }

        Toggle {
          width: parent.width
          label: "Daemon"
          description: root.daemonActive
            ? "Dictation is running. F9 and Super+Ctrl+X still toggle it."
            : "Start the dictation daemon."
          checked: root.daemonActive
          hasCursor: root.cursorActive && root.focusIndex === 0
          foreground: root.fg
          fontFamily: root.fontFamily
          onClicked: root.setDaemon(!root.daemonActive)
          onHovered: function(isHovered) {
            if (isHovered) {
              root.cursorActive = true
              root.focusIndex = 0
            }
          }
        }

        Toggle {
          width: parent.width
          label: "Recording"
          description: "Same as F9 or Super+Ctrl+X."
          checked: root.engaged
          hasCursor: root.cursorActive && root.focusIndex === 1
          foreground: root.fg
          fontFamily: root.fontFamily
          onClicked: root.toggleRecording()
          onHovered: function(isHovered) {
            if (isHovered) {
              root.cursorActive = true
              root.focusIndex = 1
            }
          }
        }

        PanelSeparator { foreground: root.fg }

        Button {
          width: parent.width
          text: "Settings"
          iconText: "󰒓"
          bordered: true
          leftAlign: true
          foreground: root.fg
          fontFamily: root.fontFamily
          hasCursor: root.cursorActive && root.focusIndex === 2
          onClicked: root.openSettings()
          onHovered: function(isHovered) {
            if (isHovered) {
              root.cursorActive = true
              root.focusIndex = 2
            }
          }
        }

        Button {
          width: parent.width
          text: "Restart daemon"
          iconText: "󰜉"
          bordered: true
          leftAlign: true
          foreground: root.fg
          fontFamily: root.fontFamily
          hasCursor: root.cursorActive && root.focusIndex === 3
          onClicked: root.restartDaemon()
          onHovered: function(isHovered) {
            if (isHovered) {
              root.cursorActive = true
              root.focusIndex = 3
            }
          }
        }
      }
    }
  }
}
