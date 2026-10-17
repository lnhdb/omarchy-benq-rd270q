// Pure helpers for the BenQ panel: VCP table, parsing, and the coalescing
// write queue's bookkeeping. Kept free of QML so it can be tested with node.

var VCP = {
  brightness: 0x10,
  lowblue: 0x19,
  nightLevel: 0xd0,
  night: 0xd1,
  vo: 0x81          // 0 = off, 1 = bri + color temp, 2 = brightness only
}

var VO_BRI_CT = 1
var VO_BRI = 2

function clamp(v, lo, hi) {
  var n = Math.round(Number(v))
  if (!isFinite(n)) n = lo
  return Math.max(lo, Math.min(hi, n))
}

// Parses `ddcutil --brief getvcp 10 19 d1 d0 81` into {code: current}.
// On the RD270Q, 19 and D1 report as CNC and D0 as SNC.
//   VCP 10 C 44 100            continuous: current max
//   VCP D0 SNC x09             simple non-continuous
//   VCP 81 CNC x00 x02 x00 x02 complex: mh ml sh sl (current = sh*256+sl)
function parseBrief(text) {
  var out = {}
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var f = lines[i].trim().split(/\s+/)
    if (f[0] !== "VCP" || f.length < 4) continue
    var code = parseInt(f[1], 16)
    var v = NaN
    if (f[2] === "C") v = parseInt(f[3], 10)
    else if (f[2] === "SNC") v = parseInt(f[3].replace(/^x/, ""), 16)
    else if (f[2] === "CNC" && f.length >= 7)
      v = parseInt(f[5].replace(/^x/, ""), 16) * 256 + parseInt(f[6].replace(/^x/, ""), 16)
    if (isFinite(code) && isFinite(v)) out[code] = v
  }
  return out
}

// Coalescing queue: one pending value per code. Setting a code again replaces
// its value, so only the newest value is ever sent. Returns a new object.
function enqueue(pending, code, value) {
  var next = {}
  for (var k in pending) next[k] = pending[k]
  next[code] = value
  return next
}

// Takes the next write out of the queue: {code, value, rest} or null.
function takeNext(pending) {
  for (var k in pending) {
    var rest = {}
    for (var j in pending) if (j !== k) rest[j] = pending[j]
    return { code: Number(k), value: pending[k], rest: rest }
  }
  return null
}

// Parses `ddcutil detect --brief` into [{bus, mfg, model}], one per display
// with an I2C bus. Blocks look like:
//   Display 1
//      I2C bus:  /dev/i2c-12
//      DRM connector:    card1-DP-1
//      drm_connector_id: 408
//      Monitor:  BNQ:BenQ RD270Q:<serial>
function parseDetect(text) {
  var out = []
  var blocks = String(text || "").split(/\n(?=\S)/)
  for (var i = 0; i < blocks.length; i++) {
    var bus = /I2C bus:\s*\/dev\/i2c-(\d+)/.exec(blocks[i])
    if (!bus) continue
    var mon = /Monitor:\s*([^:\n]*):([^:\n]*)/.exec(blocks[i])
    out.push({ bus: bus[1], mfg: mon ? mon[1].trim() : "", model: mon ? mon[2].trim() : "" })
  }
  return out
}

// Picks the bus to talk to: the RD270Q first, then any BenQ display, else "".
function pickBus(displays) {
  for (var i = 0; i < displays.length; i++)
    if (/RD270Q/i.test(displays[i].model)) return displays[i].bus
  for (var j = 0; j < displays.length; j++)
    if (displays[j].mfg === "BNQ") return displays[j].bus
  return ""
}

function hex(code) {
  return "0x" + ("0" + Number(code).toString(16)).slice(-2)
}

if (typeof module !== "undefined") {
  module.exports = { VCP: VCP, VO_BRI_CT: VO_BRI_CT, VO_BRI: VO_BRI, clamp: clamp,
                     parseBrief: parseBrief, parseDetect: parseDetect, pickBus: pickBus, enqueue: enqueue, takeNext: takeNext, hex: hex }
}
