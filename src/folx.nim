import os, times, math, sequtils, unicode, strutils
import plainwindy, pixie
import render, syntax_highlighting

proc `{}`[T](x: seq[T], s: Slice[int]): seq[T] =
  ## safe slice a seq
  if x.len == 0: return
  let s = Slice[int](a: s.a.max(x.low).min(x.high), b: s.b.max(x.low).min(x.high))
  x[s]

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


let window = newWindow("folx", ivec2(1280, 900), visible=false)

let font = readFont"resources/FiraCode-Regular.ttf"
font.size = 11
font.paint.color = color(1, 1, 1, 1)
var gt = GlyphTable(font: font)

let text = "src/folx.nim".readFile
let text_indentation = text.split("\n").indentation
let text_colored = text.parseNimCode.lines.map(color)


var
  pos = 0'f32
  visual_pos = pos
  image = newImage(1280, 720)
  r = image.newContext


proc animate(dt: float32): bool =
  if pos != visual_pos:
    let pvp = (visual_pos * font.size).round.int32
    
    let d = (abs(pos - visual_pos) * (0.000005 / dt)).max(0.1).min(abs(pos - visual_pos))
    if pos > visual_pos: visual_pos += d
    else:                visual_pos -= d

    if abs(visual_pos - pos) < 1 / font.size / 2.1:
      visual_pos = pos
    if pvp != (visual_pos * font.size).round.int32: result = true


proc line_numbers(
  r: Context,
  box: Rect,
  pos: float32,
  size: int,
  gt: var GlyphTable,
  text: seq[seq[ColoredText]],
  ) =
  var y = round(box.y - font.size * 1.27 * (pos mod 1))
  for i in pos.int..(pos.ceil.int+size).min(text.high):
    let s = $(i+1)
    let w = float32 s.width(gt)
    image.draw @[(sLineNumber.color, s)], rect(vec2(box.x + box.w - w, y), vec2(w, box.h - y)), gt
    y += round(font.size * 1.27)

proc text_area(
  r: Context,
  box: Rect,
  pos: float32,
  size: int,
  gt: var GlyphTable,
  text: seq[seq[ColoredText]],
  indentation: seq[tuple[len: seq[int], has_graph: bool]],
  ) =
  assert text.len == indentation.len

  var y = round(box.y - font.size * 1.27 * (pos mod 1))
  let space_w = " ".width(gt)

  for i, s in text{pos.int..pos.ceil.int+size}:
    let l = i + pos.int.max(text.low).min(text.high)

    image.draw s, rect(vec2(box.x, y), vec2(box.x + box.w, y + box.h)), gt

    r.fillStyle = rgb(64, 64, 64)
    var x = box.x.round.int
    for i, l in indentation[l].len:
      r.fillRect rect(vec2(x.float32, y), vec2(1, font.size * 1.27))
      x += l * space_w

    y += round(font.size * 1.27)

proc scrollbar(r: Context, box: Rect, pos: float32, size: int, total: int) =
  if total == 0: return
  let
    a = pos / total.float32
    b = (pos + size.float32) / total.float32
  
  var box = box
  box.xy = vec2(box.x, box.y + (box.h * a))
  box.wh = vec2(box.w, box.h * (b - a))

  r.fillStyle = rgba(48, 48, 48, 255)
  r.fillRect box


proc display =
  let
    size = (window.size.y.float32 / font.size).ceil.int
    total = text_colored.len

    line_number_width = float32 ($total).width(gt)

  image.fill rgba(32, 32, 32, 255)

  r.line_numbers(
    box = rect(vec2(10, 0), vec2(line_number_width, window.size.vec2.y)),
    pos = visual_pos,
    size = size,
    gt = gt,
    text = text_colored,
  )
  r.text_area(
    box = rect(vec2(line_number_width + 30, 0), window.size.vec2 - vec2(10, 0)),
    pos = visual_pos,
    size = size,
    gt = gt,
    text = text_colored,
    indentation = text_indentation,
  )
  r.scrollbar(
    box = rect(vec2(window.size.vec2.x - 10, 0), vec2(10, window.size.vec2.y)),
    pos = visual_pos,
    size = size,
    total = total + size - 1,
  )

  window.draw image


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
  if window.size.x * window.size.y == 0: return
  image = newImage(window.size.x, window.size.y)
  r = image.newContext
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
