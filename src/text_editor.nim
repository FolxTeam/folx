import sequtils, unicode, math
import pixie, pixwindy
import render, syntax_highlighting, configuration, text

type
  Indentation* = seq[tuple[len: seq[int], has_graph: bool]]

  TextEditor* = object
    pos*, visual_pos*: float32
    text*: Text
    colors*: seq[ColorRgb]
    indentation*: Indentation
    cursor*: IVec2


proc bound(cursor: var IVec2, text: Text) =
  if text.len < 0: return

  cursor.y = cursor.y.bound(0'i32..text.lines.high.int32)
  cursor.x = cursor.x.bound(0'i32..text{cursor.y}.len.int32)


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


proc indentation*(text: Text): Indentation =
  proc indentation(line: SeqView[Rune], prev: seq[int]): tuple[len: seq[int], has_graph: bool] =
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

  for i in 0..text.lines.high:
    result.add text{i}.indentation(if i == 0: @[] else: result[^1].len)

  var lgl = 0
  for i in countdown(result.high, 0):
    if result[i].has_graph: lgl = result[i].len.len
    elif result[i].len.len > lgl: result[i].len = result[i].len[0..<lgl]


proc newTextEditor*(file: string): TextEditor =
  result.text = newText(file.readFile)
  result.colors = result.text.parseNimCode(NimParseState(), result.text.len).segments.colors
  assert result.colors.len == result.text.len
  result.indentation = result.text.indentation


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
      r.image.vertical_line x.int32, y.int32, dy.int32, box, colorTheme.bgVerticalLine
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
  ) =
  let
    size = (box.h / gt.font.size).ceil.int
    dy = round(gt.font.size * 1.27)
    right = (box.w + toRunes($lineCount).width(gt).float32) / 2

  var y = round(box.y - gt.font.size * 1.27 * (pos mod 1))
  for i in (pos.int..pos.ceil.int+size).bound(0..<lineCount):
    let s = toRunes $(i+1)
    let w = float32 s.width(gt)
    if i == cursor.y:
      r.fillStyle = colorTheme.bgLineNumbersSelect.color
      r.fillRect rect(vec2(box.x,y), vec2(box.w, dy))
      r.image.draw s, sLineNumber.color, vec2(box.x + right - w, y), box, gt, colorTheme.bgLineNumbersSelect
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

  r.fillStyle = colorTheme.bgScrollBar
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
  editor: TextEditor,
  gt: var GlyphTable,
  bg: ColorRgb,
  ) =
  let
    size = (box.h / gt.font.size).ceil.int
    total = editor.text.lines.len

    line_number_width = float32 ($total).toRunes.width(gt)
  
  r.line_numbers(
    box = rect(box.xy + vec2(0, 0), vec2(line_number_width + 20, box.h)),
    gt = gt,
    pos = editor.visual_pos,
    bg = colorTheme.bgLineNumbers,
    lineCount = total,
    cursor = editor.cursor,
  )

  r.text_area(
    box = rect(box.xy + vec2(line_number_width + 20, 0), box.wh - vec2(10, 0) - vec2(line_number_width + 20, 0)),
    gt = gt,
    pos = editor.visual_pos,
    bg = colorTheme.bgTextArea,
    text = editor.text,
    colors = editor.colors,
    indentation = editor.indentation,
  )

  r.cursor(
    box = rect(box.xy + vec2(line_number_width + 20, 0), box.wh - vec2(10, 0) - vec2(line_number_width + 20, 0)),
    gt = gt,
    pos = editor.visual_pos,
    cpos = editor.cursor,
    text = editor.text,
  )

  r.scroll_bar(
    box = rect(box.xy + vec2(box.w - 10, 0), vec2(10, box.h)),
    pos = editor.visual_pos,
    size = size,
    total = total + size - 1,
  )


proc animate*(editor: var TextEditor, dt: float32, gt: GlyphTable): bool =
  if editor.pos != editor.visual_pos:
    let
      fontSize = gt.font.size
      pvp = (editor.visual_pos * fontSize).round.int32  # visual position in pixels
      
      # position delta
      d = (abs(editor.pos - editor.visual_pos) * pow(1 / 2, (1 / dt) / 50)).max(0.1).min(abs(editor.pos - editor.visual_pos))

    # move position by delta
    if editor.pos > editor.visual_pos:
      editor.visual_pos += d
    else:
      editor.visual_pos -= d

    # if position close to integer number, round it
    if abs(editor.visual_pos - editor.pos) < 1 / fontSize / 2.1:
      editor.visual_pos = editor.pos
    
    # if position changed, signal to display by setting result to true
    if pvp != (editor.visual_pos * fontSize).round.int32: result = true


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

proc moveDown(cursor: var IVec2, text: Text) =
  cursor.y += 1
  cursor.y = cursor.y.bound(0'i32..text.lines.high.int32)

proc moveUp(cursor: var IVec2, text: Text) =
  cursor.y -= 1
  cursor.y = cursor.y.bound(0'i32..text.lines.high.int32)

proc moveToLineStart(cursor: var IVec2, text: Text) =
  cursor.x = 0
  cursor.x = cursor.x.bound(0'i32..text{cursor.y}.len.int32)

proc moveToLineEnd(cursor: var IVec2, text: Text) =
  cursor.x = text{cursor.y}.len.int32
  cursor.x = cursor.x.bound(0'i32..text{cursor.y}.len.int32)

proc moveToFileStart(cursor: var IVec2, text: Text, pos: var float32) =
  cursor.y = 0
  cursor.y = cursor.y.bound(0'i32..text.lines.high.int32)

  cursor.x = 0
  cursor.x = cursor.x.bound(0'i32..text{cursor.y}.len.int32)
  pos = 0'f32

proc moveToFileEnd(cursor: var IVec2, text: Text, pos: var float32) =
  cursor.y = text.lines.high.int32
  cursor.y = cursor.y.bound(0'i32..text.lines.high.int32)

  cursor.x = text{cursor.y}.len.int32
  cursor.x = cursor.x.bound(0'i32..text{cursor.y}.len.int32)
  pos = text.lines.high.float32


proc onButtonDown*(
  editor: var TextEditor,
  button: Button,
  window: Window,
  onTextChange: proc(),
  ) =
  if editor.text.len < 0: return

  case button
  of KeyRight:
    moveRight editor.cursor, editor.text
  
  of KeyLeft:
    moveLeft editor.cursor, editor.text
  
  of KeyDown:
    moveDown editor.cursor, editor.text
  
  of KeyUp:
    moveUp editor.cursor, editor.text
  
  of KeyHome:
    if window.buttonDown[KeyLeftControl]:
      moveToFileStart editor.cursor, editor.text, editor.pos
    else:
      moveToLineStart editor.cursor, editor.text

  of KeyEnd:
    if window.buttonDown[KeyLeftControl]:
      moveToFileEnd editor.cursor, editor.text, editor.pos
    else:
      moveToLineEnd editor.cursor, editor.text
  
  of KeyBackspace:
    bound editor.cursor, editor.text

    if editor.cursor.x == 0:
      ## todo: erase \n
    
    else:
      editor.text.erase editor.cursor.x.int - 1, editor.cursor.y.int
      if editor.cursor.x <= editor.text{editor.cursor.y}.len.int32:
        moveLeft editor.cursor, editor.text
      else:
        bound editor.cursor, editor.text

      editor.colors = editor.text.parseNimCode(NimParseState(), editor.text.len).segments.colors
      assert editor.colors.len == editor.text.len
      editor.indentation = editor.text.indentation

      onTextChange()
  
  else: discard


proc onRuneInput*(
  editor: var TextEditor,
  rune: Rune,
  onTextChange: proc(),
) =
  if rune.int32 in 0..31: return
  
  bound editor.cursor, editor.text
  editor.text.insert [rune], editor.cursor.x.int, editor.cursor.y.int
  moveRight editor.cursor, editor.text

  editor.colors = editor.text.parseNimCode(NimParseState(), editor.text.len).segments.colors
  assert editor.colors.len == editor.text.len
  editor.indentation = editor.text.indentation

  onTextChange()


proc onScroll*(
  editor: var TextEditor,
  delta: Vec2,
) =
  editor.pos = (editor.pos - delta.y * 3).max(0).min(editor.text.lines.len.float32)
