import os, times, math, sequtils, unicode, strutils
import windy, pixie, opengl, boxy
import render, syntax_highlighting
import config

proc bound[T](x: T, s: Slice[T]): T = x.max(s.a).min(s.b)
proc bound[T](x, s: Slice[T]): Slice[T] = Slice[T](a: x.a.bound(s), b: x.b.bound(s))

proc indentation(text: seq[string]): seq[tuple[len: seq[int], has_graph: bool]] =
  proc indentation(line: string, prev: seq[int]): tuple[len: seq[int], has_graph: bool] =
    var sl = block:
      var i = 0
      for c in line.runes:
        if not c.isWhiteSpace:
          result.has_graph = true
          break
        inc i
      i
    if not result.has_graph:
      result.len = prev
    else:
      for l in prev:
        if sl < l: return
        sl -= l
        result.len.add l
      if sl > 0:
        result.len.add sl

  for i, line in text:
    result.add line.indentation(if i == 0: @[] else: result[^1].len)
  
  var lgl = 0
  for i in countdown(result.high, 0):
    if result[i].has_graph: lgl = result[i].len.len
    elif result[i].len.len > lgl: result[i].len = result[i].len[0..<lgl]


proc line_numbers(
  box: Rect,
  pos: float32,
  gt: var GlyphTable,
  bg: ColorRgb,
  text: seq[seq[ColoredText]],
  ) =
  let
    size = (box.h / gt.font.size).ceil.int

  var y = round(box.y - gt.font.size * 1.27 * (pos mod 1))
  for i in (pos.int..pos.ceil.int+size).bound(text.low..text.high):
    let s = $(i+1)
    let w = float32 s.width(gt)
    draw @[(sLineNumber.color, s)], rect(vec2(box.x + box.w - w, y), vec2(w, box.h - y)), gt, bg
    y += round(gt.font.size * 1.27)

proc text_area(
  box: Rect,
  pos: float32,
  gt: var GlyphTable,
  bg: ColorRgb,
  text: seq[seq[ColoredText]],
  indentation: seq[tuple[len: seq[int], has_graph: bool]],
  ) =
  assert text.len == indentation.len

  let
    size = (box.h / gt.font.size).ceil.int
    space_w = " ".width(gt)

  let dy = round(gt.font.size * 1.27)
  var y = box.y - dy * (pos mod 1)

  for i in (pos.int..pos.ceil.int+size).bound(text.low..text.high):
    draw text[i], rect(vec2(box.x, y), vec2(box.x + box.w, y + box.h)), gt, bg

    var x = box.x.round.int
    for i, l in indentation[i].len:
      gt.vertical_line x.int32, y.int32, dy.int32, rgb(64, 64, 64)
      x += l * space_w

    y += dy

proc scrollbar(r: Boxy, box: Rect, pos: float32, size: int, total: int) =
  if total == 0: return
  let
    a = pos / total.float32
    b = (pos + size.float32) / total.float32
  
  var box = box
  box.xy = vec2(box.x, box.y + (box.h * a))
  box.wh = vec2(box.w, box.h * (b - a))

  r.drawRect box, rgba(48, 48, 48, 255).color

#TODO: add window size to config, rename configuration to something better
let configuration = Config(
  file: "src/folx.nim",
  font: "resources/FiraCode-Regular.ttf",
  fontSize: 11,
)

let window = newWindow("folx", ivec2(1280, 900), visible=false)

window.makeContextCurrent()
loadExtensions()

window.title = configuration.file & " - folx"

let font = readFont(configuration.font)
font.size = configuration.fontSize
font.paint.color = color(1, 1, 1, 1)

var
  pos = 0'f32
  visual_pos = pos
  r = newBoxy()

var gt = GlyphTable(font: font, boxy: r)

let text = configuration.file.readFile
let text_indentation = text.split("\n").indentation
let text_colored = text.parseNimCode.lines.map(color)


proc animate(dt: float32): bool =
  if pos != visual_pos:
    let pvp = (visual_pos * font.size).round.int32
    
    let d = (abs(pos - visual_pos) * (0.000005 / dt)).max(0.1).min(abs(pos - visual_pos))
    if pos > visual_pos: visual_pos += d
    else:                visual_pos -= d

    if abs(visual_pos - pos) < 1 / font.size / 2.1:
      visual_pos = pos
    if pvp != (visual_pos * font.size).round.int32: result = true


proc display =
  let
    size = (window.size.y.float32 / font.size).ceil.int
    total = text_colored.len

    line_number_width = float32 ($total).width(gt)

  r.beginFrame window.size
  r.drawRect rect(vec2(0, 0), window.size.vec2), color(0.13, 0.13, 0.13, 1)

  line_numbers(
    box = rect(vec2(10, 0), vec2(line_number_width, window.size.vec2.y)),
    pos = visual_pos,
    gt = gt,
    bg = rgb(32, 32, 32),
    text = text_colored,
  )
  text_area(
    box = rect(vec2(line_number_width + 30, 0), window.size.vec2 - vec2(10, 0)),
    pos = visual_pos,
    gt = gt,
    bg = rgb(32, 32, 32),
    text = text_colored,
    indentation = text_indentation,
  )
  scrollbar(
    r = r,
    box = rect(vec2(window.size.vec2.x - 10, 0), vec2(10, window.size.vec2.y)),
    pos = visual_pos,
    size = size,
    total = total + size - 1,
  )
  r.endFrame

  window.swapBuffers


var displayRequest = false

window.onCloseRequest = proc =
  close window
  quit(0)

window.onScroll = proc =
  if window.scrollDelta.y == 0: return
  if window.buttonDown[KeyLeftControl] or window.buttonDown[KeyRightControl]:
    font.size = (font.size + window.scrollDelta.y.ceil).max(1)
    clear gt
    displayRequest = true
  else:
    pos = (pos - window.scrollDelta.y * 3).max(0).min(text_colored.high.float32)

window.onResize = proc =
  display()


display()
window.visible = true

var pt = now()
while not window.closeRequested:
  let nt = now()
  pollEvents()
  
  let dt = now()
  displayRequest = displayRequest or animate((dt - nt).inMicroseconds.int / 1_000_000)
  if displayRequest:
    display()
    displayRequest = false
  pt = dt

  let ct = now()
  if (ct - nt).inMilliseconds < 10:
    sleep(10 - (ct - nt).inMilliseconds.int)
