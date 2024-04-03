import sequtils, unicode, math, strutils
import gui, syntax_highlighting, configuration, text

type
  Indentation* = seq[tuple[len: seq[int], has_graph: bool]]

  TextEditor* = object
    pos*, visual_pos*: float32
    text*: Text
    file*: string
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
  result.file = file
  result.text = newText(file.readFile)
  result.colors = result.text.parseNimCode(NimParseState(), result.text.len).segments.colors
  assert result.colors.len == result.text.len
  result.indentation = result.text.indentation


component TextArea {.noexport.}:
  proc handle(
    pos: float32,
    bg: ColorRgb,
    text: Text,
    colors: seq[ColorRgb],
    indentation: Indentation,
    window: Window,
  )

  if mouseHover parentBox:
    setCursor Cursor(kind: builtin, builtin: BuiltinCursor.arrow)

  let
    gt = glyphTableStack[^1]
    size = (parentBox.h / gt.font.size).ceil.int
    space_w = static(" ".toRunes).width(gt)

    dy = round(gt.font.size * 1.27)
  
  var y = -dy * (pos mod 1)

  Frame(clip = true):
    for i in (pos.int..pos.ceil.int+size).bound(0..text.lines.high):
      Text text{i}.toOpenArray(y=y):
        colors = colors.toOpenArray(text.lines[i].first, text.lines[i].last)
        bg = bg

      var x = 0
      for i, l in indentation[i].len:
        VerticalLine(x=x, y=y, h=dy):
          color = colorTheme.bgVerticalLine
        x += l * space_w

      y += dy


component LineNumbers {.noexport.}:
  proc handle(
    pos: float32,
    bg: ColorRgb,
    lineCount: int,
    cursor: IVec2,
  )

  let
    gt = glyphTableStack[^1]
    size = (parentBox.h / gt.font.size).ceil.int
    dy = round(gt.font.size * 1.27)

  var y = round(-gt.font.size * 1.27 * (pos mod 1))
  for i in (pos.int..pos.ceil.int+size).bound(0..<lineCount):
    let s = toRunes $(i+1)
    let w = float32 s.width(gt)

    if i == cursor.y:
      Rect(y=y, h=dy):
        color = colorTheme.bgLineNumbersSelect.color

    Text s(left = parentBox.w - 10 - w, y = y, h = dy):
      color = sLineNumber.color
      bg =
        if i == cursor.y: colorTheme.bgLineNumbersSelect
        else: bg

    y += dy


component ScrollBar {.noexport.}:
  proc handle(
    pos: float32,
    size: int,
    total: int
  )
  if total == 0: return

  let
    a = pos / total.float32
    b = (pos + size.float32) / total.float32

  Rect(y = parentBox.h * a, h = parentBox.h * (b - a)):
    color = colorTheme.bgScrollBar.color

#todo: move variables
var blink* = true;
var blink_time* = 0;

component Cursor:
  proc handle(
    pos: float32,
    cpos: IVec2,
    text: Text,
  )
  if text.len == 0: return

  let gt = glyphTableStack[^1]
  
  var width = gt.font.size / 8

  let
    y = cpos.y.int.bound(0..text.lines.high)
    lineStart = text.lines[y].first
    lineEnd = text.lines[y].last
    x = cpos.x.int.bound(0 .. lineEnd-lineStart + 1)
  
  var cursor_width = case config.caretStyle
  of CaretStyle.rect, CaretStyle.underline:
    # set caret width like a symbol
    width = gt.font.size / 1.8
    width / 10
  of CaretStyle.line:
    # set narrow caret
    -(width / 2)

  if (config.caretBlink and blink) or not config.caretBlink:
    Rect(w = width, h = round(gt.font.size * 1.27)):
      x = text[lineStart ..< lineStart + x].toOpenArray.width(gt).float32 + cursor_width
      y = round(gt.font.size * 1.27) * (y.float32 - pos)
      color = colorTheme.sText.color


component TextEditor:
  proc handle(
    editor: var TextEditor,
    bg: ColorRgb,
    window: Window,
  )

  let
    gt = glyphTableStack[^1]
    size = (parentBox.h / gt.font.size).ceil.int
    total = editor.text.lines.len

    line_number_width = float32 ($total).toRunes.width(gt)

  TextArea(left = line_number_width + 20, right = 10):
    pos = editor.visual_pos
    bg = colorTheme.bgTextArea
    text = editor.text
    colors = editor.colors
    indentation = editor.indentation
    window = window

    if isLeftDown and mouseHover parentBox:
      let mousePos = mousePos - parentBox.xy
      editor.cursor = ivec2((mousePos.x / (" ".width(gt)).float32).round.int32, (mousePos.y / round(gt.font.size * 1.27) + editor.visual_pos - 0.5).round.int32)
      editor.cursor.y = editor.cursor.y.bound(0'i32..editor.text.lines.high.int32)
      editor.cursor.x = editor.cursor.x.bound(0'i32..editor.text{editor.cursor.y}.len.int32)

    Cursor:
      pos = editor.visual_pos
      cpos = editor.cursor
      text = editor.text
  
  LineNumbers(w = line_number_width + 20):
    pos = editor.visual_pos
    bg = colorTheme.bgLineNumbers
    lineCount = total
    cursor = editor.cursor

  ScrollBar(left = parentBox.w - 10):
    pos = editor.visual_pos
    size = size
    total = total + size - 1

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


proc reparse(editor: var TextEditor) =
  editor.colors = editor.text.parseNimCode(NimParseState(), editor.text.len).segments.colors
  assert editor.colors.len == editor.text.len
  editor.indentation = editor.text.indentation


proc onKeydown*(
  editor: var TextEditor,
  e: KeyEvent,
  window: Window,
  onTextChange: proc(),
  onTextSave: proc(),
) =
  if editor.text.len < 0: return

  # if cursor move don't blink (reset timer)
  blink_time = 0
  blink = true

  case e.key
  of Key.right:
    moveRight editor.cursor, editor.text
  
  of Key.left:
    moveLeft editor.cursor, editor.text
  
  of Key.down:
    moveDown editor.cursor, editor.text
  
  of Key.up:
    moveUp editor.cursor, editor.text
  
  of Key.backspace:  # erase character before cursor
    bound editor.cursor, editor.text

    if editor.cursor.x == 0:
      # erase \n (join lines)
      if editor.cursor.y notin 1..editor.text.lines.high: return
      editor.cursor.y -= 1
      editor.cursor.x = editor.text{editor.cursor.y}.len.int32
      editor.text.joinLine editor.cursor.y

      reparse editor
      onTextChange()
    
    else:
      editor.text.erase editor.cursor.x.int - 1, editor.cursor.y.int
      if editor.cursor.x <= editor.text{editor.cursor.y}.len.int32:
        moveLeft editor.cursor, editor.text
      else:
        bound editor.cursor, editor.text

      reparse editor
      onTextChange()
  
  of Key.del:  # erase character after cursor
    bound editor.cursor, editor.text

    if editor.cursor.x == editor.text{editor.cursor.y}.len.int32:
      # erase \n (join lines)
      if editor.cursor.y notin 1..editor.text.lines.high: return
      editor.text.joinLine editor.cursor.y

      reparse editor
      onTextChange()
    
    else:
      editor.text.erase editor.cursor.x.int, editor.cursor.y.int

      reparse editor
      onTextChange()
  
  of Key.enter:  # insert new line
    bound editor.cursor, editor.text
    editor.text.`\n` editor.cursor.x.int, editor.cursor.y.int
    if window.check(e, kc({Key.lcontrol}, Key.enter)):
      inc editor.cursor.y
      editor.cursor.x = 0
    else:
      inc editor.cursor.y
      editor.cursor.x = block:
        var i = 0
        block a:
          for l in countdown(editor.cursor.y-1, 0):
            for c in editor.text{l}:
              if not c.isWhiteSpace:
                break a
              inc i
            i = 0
        i.int32
      editor.text.insert(" ".repeat(editor.cursor.x).toRunes, 0, editor.cursor.y)
    
    reparse editor
    onTextChange()

  of Key.home:
    if Key.lcontrol in window.keyboard.pressed:
      moveToFileStart editor.cursor, editor.text, editor.pos
    else:
      moveToLineStart editor.cursor, editor.text

  of Key.End:
    if Key.lcontrol in window.keyboard.pressed:
      moveToFileEnd editor.cursor, editor.text, editor.pos
    else:
      moveToLineEnd editor.cursor, editor.text
  
  elif window.check(e, kc({Key.lcontrol}, Key.s)):
    writeFile editor.file, $editor.text
    onTextSave()
  
  else: discard


proc onRuneInput*(
  editor: var TextEditor,
  rune: Rune,
  onTextChange: proc(),
) =
  if rune.int32 in 0..31 or rune.int32 == 127: return
  
  bound editor.cursor, editor.text
  editor.text.insert [rune], editor.cursor.x.int, editor.cursor.y.int
  moveRight editor.cursor, editor.text

  reparse editor
  onTextChange()


proc onPaste*(
  editor: var TextEditor,
  text: Text,
  onTextChange: proc(),
) =
  if editor.text.len < 0: return

  bound editor.cursor, editor.text
  editor.text.insert text, editor.cursor.x.int, editor.cursor.y.int
  if text.lines.len > 1:
    editor.cursor.y += text.lines.high.int32
    editor.cursor.x = text{^1}.len.int32
  else:
    editor.cursor.x += text.len.int32

  reparse editor
  onTextChange()


proc onScroll*(
  editor: var TextEditor,
  delta: Vec2,
) =
  editor.pos = (editor.pos + delta.y * 3).max(0).min(editor.text.lines.len.float32)
