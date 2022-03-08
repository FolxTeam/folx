import sequtils, unicode, math
import pixie, pixwindy
import render, syntax_highlighting, configuration, text

type
  Indentation* = seq[tuple[len: seq[int], has_graph: bool]]


proc color*(sk: CodeKind): ColorRGB =
  case sk
  of sKeyword, sOperatorWord, sBuiltinType:
    colorTheme.sKeyword

  of sControlFlow:
    colorTheme.sControlFlow
  
  of sType:
    colorTheme.sType
  
  of sStringLit, sCharLit:
    colorTheme.sStringLit
  
  of sStringLitEscape, sCharLitEscape:
    colorTheme.sStringLitEscape
  
  of sNumberLit:
    colorTheme.sNumberLit
  
  of sFunction:
    colorTheme.sFunction
  
  of sComment:
    colorTheme.sComment
  
  of sTodoComment:
    colorTheme.sTodoComment
  
  of sLineNumber:
    colorTheme.sLineNumber
  
  of sError:
    colorTheme.sError
  
  else: colorTheme.sText

proc colors*(scs: openarray[CodeKind]): seq[ColorRgb] =
  scs.map(color)


proc indentation*(text: seq[seq[Rune]]): Indentation =
  ## todo: use Text
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
  text: Text,
  colors: seq[ColorRgb],
  indentation: Indentation,
  ) =

  let
    size = (box.h / gt.font.size).ceil.int
    space_w = static(" ".toRunes).width(gt)

    dy = round(gt.font.size * 1.27)
  
  var y = box.y - dy * (pos mod 1)

  for i in (pos.int..pos.ceil.int+size).bound(0..text.lines.high):
    r.image.draw text{i}.toOpenArray, colors.toOpenArray(text.lines[i].first, text.lines[i].last), vec2(box.x, y), box, gt, bg

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
  cursor: IVec2,
  total: int,
  ) =
  let
    size = (box.h / gt.font.size).ceil.int
    dy = round(gt.font.size * 1.27)
    right = (box.w + toRunes($total).width(gt).float32) / 2

  var y = round(box.y - gt.font.size * 1.27 * (pos mod 1))
  for i in (pos.int..pos.ceil.int+size).bound(0..<lineCount):
    let s = toRunes $(i+1)
    let w = float32 s.width(gt)
    if i == cursor.y:
      r.fillStyle = colorTheme.lineNumbersSelect.color
      r.fillRect rect(vec2(box.x,y), vec2(box.w, dy))
      r.image.draw s, sLineNumber.color, vec2(box.x + right - w, y), box, gt, colorTheme.lineNumbersSelect
    else:
      r.image.draw s, sLineNumber.color, vec2(box.x + right - w, y), box, gt, bg
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
  text: Text,
  ) =
  if text.len == 0: return
  
  let
    width = gt.font.size / 8
    
    y = cpos.y.int.bound(0..text.lines.high)
    lineStart = text.lines[y].first
    lineEnd = text.lines[y].last
    x = cpos.x.int.bound(0 .. lineEnd-lineStart + 1)
  
  r.fillStyle = colorTheme.sText
  r.fillRect rect(
    box.xy + vec2(
      text[lineStart ..< lineStart + x].toOpenArray.width(gt).float32 - width / 2,
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
  text: Text,
  colors: seq[ColorRgb],
  indentation: Indentation,
  cursor: IVec2,
  ) =
  let
    size = (box.h / gt.font.size).ceil.int
    total = text.lines.len

    line_number_width = float32 ($total).toRunes.width(gt)
  
  r.line_numbers(
    box = rect(box.xy + vec2(0, 0), vec2(line_number_width + 20, box.h)),
    gt = gt,
    pos = pos,
    bg = colorTheme.textarea,
    lineCount = total,
    cursor = cursor,
    total = total,
  )

  r.text_area(
    box = rect(box.xy + vec2(line_number_width + 20, 0), box.wh - vec2(10, 0) - vec2(line_number_width + 20, 0)),
    gt = gt,
    pos = pos,
    bg = colorTheme.textarea,
    text = text,
    colors = colors,
    indentation = indentation,
  )

  r.cursor(
    box = rect(box.xy + vec2(line_number_width + 20, 0), box.wh - vec2(10, 0) - vec2(line_number_width + 20, 0)),
    gt = gt,
    pos = pos,
    cpos = cursor,
    text = text,
  )

  r.scroll_bar(
    box = rect(box.xy + vec2(box.w - 10, 0), vec2(10, box.h)),
    pos = pos,
    size = size,
    total = total + size - 1,
  )


proc bound(cursor: var IVec2, text: Text) =
  if text.len < 0: return

  cursor.y = cursor.y.bound(0'i32..text.lines.high.int32)
  cursor.x = cursor.x.bound(0'i32..text{cursor.y}.len.int32)


proc moveRight(cursor: var IVec2, text: Text) =
  bound cursor, text
  
  cursor.x += 1
  if cursor.x > text{cursor.y}.len and cursor.y < text.lines.high:
    cursor.y += 1
    cursor.x = 0
  cursor.x = cursor.x.bound(0'i32..text{cursor.y}.len.int32)


proc moveLeft(cursor: var IVec2, text: Text) =
  bound cursor, text
  
  cursor.x -= 1
  if cursor.x < 0 and cursor.y > 0:
    cursor.y -= 1
    cursor.x = text{cursor.y}.len.int32
  cursor.x = cursor.x.bound(0'i32..text{cursor.y}.len.int32)



proc text_editor_onButtonDown*(
  button: Button,
  cursor: var IVec2,
  window: Window,
  pos: var float32,
  text: Text,
  ) =
  if text.len < 0: return

  case button
  of KeyRight:
    moveRight cursor, text
  
  of KeyLeft:
    moveLeft cursor, text
  
  of KeyDown:
    cursor.y += 1
    cursor.y = cursor.y.bound(0'i32..text.lines.high.int32)
  
  of KeyUp:
    cursor.y -= 1
    cursor.y = cursor.y.bound(0'i32..text.lines.high.int32)
  
  of KeyHome:
    if window.buttonDown[KeyLeftControl]:
      cursor.y = 0
      cursor.y = cursor.y.bound(0'i32..text.lines.high.int32)

      cursor.x = 0
      cursor.x = cursor.x.bound(0'i32..text{cursor.y}.len.int32)
      pos = 0'f32
    else:
      cursor.x = 0
      cursor.x = cursor.x.bound(0'i32..text{cursor.y}.len.int32)

  of KeyEnd:
    if window.buttonDown[KeyLeftControl]:
      cursor.y = text.lines.high.int32
      cursor.y = cursor.y.bound(0'i32..text.lines.high.int32)

      cursor.x = text{cursor.y}.len.int32
      cursor.x = cursor.x.bound(0'i32..text{cursor.y}.len.int32)
      pos = text.lines.high.float32
    else:
      cursor.x = text{cursor.y}.len.int32
      cursor.x = cursor.x.bound(0'i32..text{cursor.y}.len.int32)
  
  else: discard


proc text_editor_onRuneInput*(
  rune: Rune,
  cursor: var IVec2,
  text: var Text,
  onTextChange: proc(),
) =
  if rune.int32 in 0..31: return
  
  bound cursor, text
  text.insert [rune], cursor.x.int, cursor.y.int
  moveRight cursor, text
  
  onTextChange()
