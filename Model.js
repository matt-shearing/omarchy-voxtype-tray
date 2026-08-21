.pragma library

var GLYPH_IDLE = "󰍬"
var GLYPH_RECORDING = "󰍬"
var GLYPH_TRANSCRIBING = "󰔟"
var GLYPH_STREAMING = "󰝚"
var GLYPH_STOPPED = "󰍭"

function normalizeState(raw) {
  var s = String(raw || "idle").trim().toLowerCase()
  if (s === "recording" || s === "streaming" || s === "transcribing" || s === "idle")
    return s
  if (s === "stopped" || s === "inactive") return "stopped"
  return "idle"
}

function parseStatusJson(text) {
  var out = { state: "idle", model: "", backend: "", device: "", tooltip: "" }
  var raw = String(text || "").trim()
  if (raw === "") return out
  var line = raw.split(/\r?\n/)[0]
  try {
    var data = JSON.parse(line)
    out.state = normalizeState(data.alt || data.class || data.state)
    out.model = String(data.model || "")
    out.backend = String(data.backend || "")
    out.device = String(data.device || "")
    out.tooltip = String(data.tooltip || "")
  } catch (e) {
    out.state = normalizeState(raw)
  }
  return out
}

function daemonActiveFromShow(text) {
  return String(text || "").trim() === "active"
}

function glyph(state, daemonActive) {
  if (!daemonActive) return GLYPH_STOPPED
  if (state === "transcribing") return GLYPH_TRANSCRIBING
  if (state === "streaming") return GLYPH_STREAMING
  if (state === "recording") return GLYPH_RECORDING
  return GLYPH_IDLE
}

function stateLabel(state, daemonActive) {
  if (!daemonActive) return "Stopped"
  if (state === "recording") return "Recording"
  if (state === "streaming") return "Streaming"
  if (state === "transcribing") return "Transcribing"
  return "Idle"
}

function barActive(state, daemonActive) {
  return !!(daemonActive && (state === "recording" || state === "streaming"))
}

function tooltip(state, daemonActive, model, backend) {
  var label = stateLabel(state, daemonActive)
  var extra = []
  if (model) extra.push(model)
  if (backend) extra.push(backend)
  if (!daemonActive)
    return "VoxType Tray · stopped\nLeft-click for controls"
  return "VoxType Tray · " + label.toLowerCase() + (extra.length ? "\n" + extra.join(" · ") : "\nRight-click to toggle dictation")
}

function heroMeta(state, daemonActive, model, backend) {
  var parts = [stateLabel(state, daemonActive)]
  if (model) parts.push(model)
  if (backend) parts.push(backend)
  return parts.join(" · ")
}

function heroDetail(state, daemonActive) {
  if (!daemonActive) return "OFF"
  if (state === "recording" || state === "streaming") return "REC"
  if (state === "transcribing") return "WAIT"
  return "ON"
}

function daemonCommand() {
  return ["systemctl", "--user", "show", "-p", "ActiveState", "--value", "voxtype.service"]
}

function statusCommand() {
  return ["voxtype", "status", "--extended", "--format", "json"]
}

function recordToggleCommand() {
  return ["voxtype", "record", "toggle"]
}

function startDaemonCommand() {
  return ["systemctl", "--user", "start", "voxtype.service"]
}

function stopDaemonCommand() {
  return ["systemctl", "--user", "stop", "voxtype.service"]
}

function restartDaemonCommand() {
  return ["systemctl", "--user", "restart", "voxtype.service"]
}
