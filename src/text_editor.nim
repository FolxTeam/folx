import unicode, math
import pixie, pixwindy
import render, syntax_highlighting, configuration

type
  Indentation* = seq[tuple[len: seq[int], has_graph: bool]]


proc bound[T](x: T, s: Slice[T]): T = x.max(s.a).min(s.b)
proc bound[T](x, s: Slice[T]): Slice[T] = Slice[T](a: x.a.bound(s), b: x.b.bound(s))

proc indentation*(text: seq[seq[Rune]]): Indentation =
  proc indentation(line: seq[Rune], prev: seq[int]): tuple[len: seq[int], has_graph: bool] =
    var sl = block:
      var i = 0
      for c in line:
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


proc text_area(
  r: Context,
  box: Rect,
  gt: var GlyphTable,
  pos: float32,
  bg: ColorRgb,
  text: seq[Rune],
  colors: seq[ColorRgb],
  lineStarts: seq[int],
  indentation: Indentation,
  ) =

  let
    size = (box.h / gt.font.size).ceil.int
    space_w = static(" ".toRunes).width(gt)

    dy = round(gt.font.size * 1.27)
  
  var y = box.y - dy * (pos mod 1)

  for i in (pos.int..pos.ceil.int+size).bound(0..lineStarts.high):
    let
      lineStart = lineStarts[i]
      lineEnd =
        if i == lineStarts.high: text.high
        else: lineStarts[i + 1] - 1  # todo: \n and \r\n handling
    
    r.image.draw text.toOpenArray(lineStart, lineEnd), colors.toOpenArray(lineStart, lineEnd), vec2(box.x, y), box, gt, bg

    var x = box.x.round.int
    for i, l in indentation[i].len:
      r.image.vertical_line x.int32, y.int32, dy.int32, box, colorTheme.verticaLline
      x += l * space_w

    y += dy



proc line_numbers(
  r: Context,
  box: Rect,
  gt: var GlyphTable,
  pos: float32,
  bg: ColorRgb,
  lineCount: int,
  ) =
  let
    size = (box.h / gt.font.size).ceil.int

  var y = round(box.y - gt.font.size * 1.27 * (pos mod 1))
  for i in (pos.int..pos.ceil.int+size).bound(0..<lineCount):
    let s = toRunes $(i+1)
    let w = float32 s.width(gt)
    r.image.draw s, sLineNumber.color, vec2(box.x + box.w - w, y), box, gt, bg
    y += round(gt.font.size * 1.27)


proc scroll_bar(
  r: Context,
  box: Rect,
  pos: float32,
  size: int,
  total: int
  ) =
  if total == 0: return
  let
    a = pos / total.float32
    b = (pos + size.float32) / total.float32

  let box = rect(
    vec2(box.x, box.y + (box.h * a)),
    vec2(box.w, box.h * (b - a))
  )

  r.fillStyle = colorTheme.scrollbar
  r.fillRect box


proc cursor(
  r: Context,
  box: Rect,
  gt: var GlyphTable,
  pos: float32,
  cpos: IVec2,
  text: seq[Rune],
  lineStarts: seq[int],
  ) =
  if text.len == 0: return
  
  let
    width = gt.font.size / 8
    
    y = cpos.y.int.bound(0..lineStarts.high)
    lineStart = lineStarts[y]
    lineEnd =
      if y == lineStarts.high: text.high
      else: lineStarts[y + 1] - 1  # todo: \n and \r\n handling
    x = cpos.x.int.bound(0 .. lineEnd-lineStart)

  r.fillStyle = colorTheme.sElse
  r.fillRect rect(
    box.xy + vec2(
      text.toOpenArray(lineStart, x - 1).width(gt).float32 - width / 2,
      round(gt.font.size * 1.27) * (y.float32 - pos) + gt.font.size * 0.125
    ),
    vec2(width, gt.font.size)
  ).bound(box)



proc text_editor*(
  r: Context,
  box: Rect,
  gt: var GlyphTable,
  bg: ColorRgb,
  pos: float32,
  text: seq[Rune],
  colors: seq[ColorRgb],
  lineStarts: seq[int],
  indentation: Indentation,
  cursor: IVec2,
  ) =
  let
    size = (box.h / gt.font.size).ceil.int
    total = lineStarts.len

    line_number_width = float32 ($total).toRunes.width(gt)
  
  r.line_numbers(
    box = rect(box.xy + vec2(10, 0), vec2(line_number_width, box.h)),
    gt = gt,
    pos = pos,
    bg = colorTheme.textarea,
    lineCount = total,
  )

  r.text_area(
    box = rect(box.xy + vec2(line_number_width + 30, 0), box.wh - vec2(10, 0) - vec2(line_number_width + 30, 0)),
    gt = gt,
    pos = pos,
    bg = colorTheme.textarea,
    text = text,
    colors = colors,
    lineStarts = lineStarts,
    indentation = indentation,
  )

  r.cursor(
    box = rect(box.xy + vec2(line_number_width + 30, 0), box.wh - vec2(10, 0) - vec2(line_number_width + 30, 0)),
    gt = gt,
    pos = pos,
    cpos = cursor,
    text = text,
    lineStarts = lineStarts,
  )

  r.scroll_bar(
    box = rect(box.xy + vec2(box.w - 10, 0), vec2(10, box.h)),
    pos = pos,
    size = size,
    total = total + size - 1,
  )


proc text_editor_onButtonDown*(
  button: Button,
  cursor: var IVec2,
  text: seq[seq[Rune]],
  ) =
  if text.len < 0: return

  case button
  of KeyRight:
    cursor.y = cursor.y.bound(0'i32..text.high.int32)
    cursor.x = cursor.x.bound(0'i32..text[cursor.y].len.int32)
    
    cursor.x += 1
    if cursor.x > text[cursor.y].len and cursor.y < text.high:
      cursor.y += 1
      cursor.x = 0
    cursor.x = cursor.x.bound(0'i32..text[cursor.y].len.int32)
  
  of KeyLeft:
    cursor.y = cursor.y.bound(0'i32..text.high.int32)
    cursor.x = cursor.x.bound(0'i32..text[cursor.y].len.int32)

    cursor.x -= 1
    if cursor.x < 0 and cursor.y > 0:
      cursor.y -= 1
      cursor.x = text[cursor.y].len.int32
    cursor.x = cursor.x.bound(0'i32..text[cursor.y].len.int32)
  
  of KeyDown:
    cursor.y += 1
    cursor.y = cursor.y.bound(0'i32..text.high.int32)
  
  of KeyUp:
    cursor.y -= 1
    cursor.y = cursor.y.bound(0'i32..text.high.int32)
  
  else: discard
