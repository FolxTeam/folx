import os, times, math, sequtils, unicode, strutils
import pixwindy, pixie
import render, syntax_highlighting, configuration

type
  Indentation = seq[tuple[len: seq[int], has_graph: bool]]


proc bound[T](x: T, s: Slice[T]): T = x.max(s.a).min(s.b)
proc bound[T](x, s: Slice[T]): Slice[T] = Slice[T](a: x.a.bound(s), b: x.b.bound(s))

proc indentation(text: seq[string]): Indentation =
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
  r: Context,
  image: Image,
  box: Rect,
  pos: float32,
  gt: var GlyphTable,
  bg: ColorRgb,
  text: seq[string],
  ) =
  let
    size = (box.h / gt.font.size).ceil.int

  var y = round(box.y - gt.font.size * 1.27 * (pos mod 1))
  for i in (pos.int..pos.ceil.int+size).bound(text.low..text.high):
    let s = $(i+1)
    let w = float32 s.width(gt)
    image.draw s, @[(sLineNumber.color, 0)], rect(vec2(box.x + box.w - w, y), vec2(w, box.h - y)), gt, bg
    y += round(gt.font.size * 1.27)


proc text_area(
  r: Context,
  image: Image,
  box: Rect,
  pos: float32,
  gt: var GlyphTable,
  bg: ColorRgb,
  text: seq[string],
  colors: seq[seq[ColoredPos]],
  indentation: Indentation,
  ) =
  assert text.len == indentation.len

  let
    size = (box.h / gt.font.size).ceil.int
    space_w = " ".width(gt)

  let dy = round(gt.font.size * 1.27)
  var y = box.y - dy * (pos mod 1)

  for i in (pos.int..pos.ceil.int+size).bound(text.low..text.high):
    image.draw text[i], colors[i], rect(vec2(box.x, y), vec2(box.x + box.w, y + box.h)), gt, bg

    var x = box.x.round.int
    for i, l in indentation[i].len:
      image.vertical_line x.int32, y.int32, dy.int32, colorTheme.verticaLline
      x += l * space_w

    y += dy


proc scroll_bar(r: Context, box: Rect, pos: float32, size: int, total: int) =
  if total == 0: return
  let
    a = pos / total.float32
    b = (pos + size.float32) / total.float32

  var box = box
  box.xy = vec2(box.x, box.y + (box.h * a))
  box.wh = vec2(box.w, box.h * (b - a))

  r.fillStyle = colorTheme.scrollbar
  r.fillRect box


proc status_bar(
  r: Context,
  image: Image,
  box: Rect,
  pos: float32,
  gt: var GlyphTable,
  bg: ColorRgb,
  text: string,
  ) =
  const margin = vec2(8, 2)

  r.fillStyle = bg
  r.fillRect box

  image.draw text, @[(sText.color, 0)], rect(box.xy + margin, box.wh - margin), gt, bg



let window = newWindow("folx", config.window.size, visible=false)

window.title = config.file & " - folx"

let editor_font = readFont(config.font)
editor_font.size = config.fontSize
editor_font.paint.color = color(1, 1, 1, 1)
var editor_gt = GlyphTable(font: editorFont)

let interface_font = readFont(config.interfaceFont)
interface_font.size = config.interfaceFontSize
interface_font.paint.color = color(1, 1, 1, 1)
var interface_gt = GlyphTable(font: interfaceFont)

var text = config.file.readFile
let text_indentation = text.splitLines.indentation
let colors = text.parseNimCode.map(color)
let lines = text.splitLines
doassert colors.len == lines.len


var
  pos = 0'f32
  visual_pos = pos
  image = newImage(1280, 720)
  r = image.newContext


proc animate(dt: float32): bool =
  if pos != visual_pos:
    let pvp = (visual_pos * editor_font.size).round.int32

    let d = (abs(pos - visual_pos) * (0.00001 / dt)).max(0.1).min(abs(pos - visual_pos))
    if pos > visual_pos: visual_pos += d
    else:                visual_pos -= d

    if abs(visual_pos - pos) < 1 / editor_font.size / 2.1:
      visual_pos = pos
    if pvp != (visual_pos * editor_font.size).round.int32: result = true


proc display =
  let
    size = (window.size.y.float32 / editor_font.size).ceil.int
    total = lines.len

    line_number_width = float32 ($total).width(editor_gt)

  image.fill colorTheme.textarea

  r.line_numbers(
    image = image,
    box = rect(vec2(10, 0), vec2(line_number_width, window.size.vec2.y)),
    pos = visual_pos,
    gt = editor_gt,
    bg = colorTheme.textarea,
    text = lines,
  )
  r.text_area(
    image = image,
    box = rect(vec2(line_number_width + 30, 0), window.size.vec2 - vec2(10, 20)),
    pos = visual_pos,
    gt = editor_gt,
    bg = colorTheme.textarea,
    text = lines,
    colors = colors,
    indentation = text_indentation,
  )
  r.scroll_bar(
    box = rect(vec2(window.size.vec2.x - 10, 0), vec2(10, window.size.vec2.y-20)),
    pos = visual_pos,
    size = size,
    total = total + size - 1,
  )
  r.status_bar(
    image = image,
    box = rect(vec2(0, window.size.vec2.y - 20), vec2(window.size.vec2.x, 20)),
    pos = visual_pos,
    gt = interface_gt,
    bg = colorTheme.statusBarBg,
    text = "visual_pos: " & $visual_pos,
  )

  window.draw image


var displayRequest = false

window.onCloseRequest = proc =
  close window
  quit(0)

window.onScroll = proc =
  if window.scrollDelta.y == 0: return
  if window.buttonDown[KeyLeftControl] or window.buttonDown[KeyRightControl]:
    editor_font.size = (editor_font.size + window.scrollDelta.y.ceil).max(1)
    clear editor_gt
    displayRequest = true
  else:
    pos = (pos - window.scrollDelta.y * 3).max(0).min(lines.high.float32)

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
