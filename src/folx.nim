import os, times, math, strformat
import plainwindy, pixie
import render, syntax_highlighting

proc `{}`[T](x: seq[T], s: Slice[int]): seq[T] =
  ## safe slice a seq
  if x.len == 0: return
  let s = Slice[int](a: s.a.max(x.low).min(x.high), b: s.b.max(x.low).min(x.high))
  x[s]


let window = newWindow("folx", ivec2(1280, 900), visible=false)

let font = readFont"resources/FiraCode-Regular.ttf"
font.size = 11
font.paint.color = color(1, 1, 1, 1)
var gt = GlyphTable(font: font)

let text = "src/folx.nim".readFile.parseNimCode.lines


var
  pos = 0
  visual_pos = pos.float32
  image = newImage(1280, 720)
  r = image.newContext


proc animate(dt: float32): bool =
  if pos.float32 != visual_pos:
    let pvp = (visual_pos * font.size).round.int32
    visual_pos += (pos.float32 - visual_pos) * (0.000005 / dt).min(1)
    if abs(visual_pos - pos.float32) < 1 / font.size / 2.1:
      visual_pos = pos.float32
    if pvp != (visual_pos * font.size).round.int32: result = true


proc line_numbers(r: Context, box: Rect, pos: float32, size: int) =
  var y = round(box.y - font.size * 1.27 * (pos mod 1))
  for i in pos.int..(pos.ceil.int+size).min(text.high):
    image.draw @[(sLineNumber, &"{i+1:>5} ")], rect(vec2(box.x, y), vec2(box.x + box.w, y + box.h)), gt
    y += round(font.size * 1.27)

proc text_area(r: Context, box: Rect, pos: float32, size: int) =
  var y = round(box.y - font.size * 1.27 * (pos mod 1))
  for i, s in text{pos.int..pos.ceil.int+size}:
    image.draw s, rect(vec2(box.x, y), vec2(box.x + box.w, y + box.h)), gt
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
    total = text.len

  image.fill rgba(32, 32, 32, 255)

  r.line_numbers(
    box = rect(vec2(), vec2(58, window.size.vec2.y)),
    pos = visual_pos,
    size = size,
  )
  r.text_area(
    box = rect(vec2(58, 0), window.size.vec2 - vec2(10, 0)),
    pos = visual_pos,
    size = size,
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
    pos = (pos - window.scrollDelta.y.ceil.int * 3).max(0).min(text.high)

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
