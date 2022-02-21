import os, times, math, sequtils, unicode, strutils
import pixwindy, pixie
import render, syntax_highlighting, configuration, text_editor, filesystem


proc status_bar(
  r: Context,
  box: Rect,
  gt: var GlyphTable,
  bg: ColorRgb,
  text: seq[Rune],
  ) =
  const margin = vec2(8, 2)

  r.fillStyle = bg
  r.fillRect box

  r.image.draw text, @[(sText.color, 0)], box.xy + margin, rect(box.xy, box.wh - margin), gt, bg

proc explorer_area(
  r: Context,
  image: Image,
  box: Rect,
  pos: float32,
  gt: var GlyphTable,
  bg: ColorRgb,
  explorer: Explorer,
  ) =

  var
    i = 0
    text: seq[string]

  text.add(explorer.current_dir)

  for file in explorer.files:
    if i == int(explorer.item_index):
      text.add("--- " & file.name & file.ext & " " & $file.info.size & " " & $file.info.lastWriteTime & " ---") 
    else:
      text.add(file.name & file.ext & " " & $file.info.size & " " & $file.info.lastWriteTime)

    inc i  

  let
    size = (box.h / gt.font.size).ceil.int
    space_w = static(" ".toRunes).width(gt)

  let dy = round(gt.font.size * 1.27)
  var y = box.y - dy * (pos mod 1)

  for i in explorer.files.low..explorer.files.high+1:
    r.image.draw text[i].toRunes, @[(sText.color, 0)], vec2(box.x, y), box, gt, bg

    # var x = box.x.round.int
    # for i, l in indentation[i].len:
    #   image.vertical_line x.int32, y.int32, dy.int32, configuration.colorTheme.verticalline
    #   x += l * space_w

    y += dy

let window = newWindow("folx", config.window.size, visible=false)

window.title = config.file & " - folx"

var
  editor_gt    = readFont(config.font).newGlyphTable(config.fontSize)
  interface_gt = readFont(config.interfaceFont).newGlyphTable(config.interfaceFontSize)

  text = config.file.readFile
  
  lines = text.splitLines.map(toRunes)
  text_indentation = lines.indentation
  colors = text.parseNimCode.map(color)

  displayRequest = false

doassert colors.len == lines.len


var
  pos = 0'f32
  visual_pos = pos
  image = newImage(1280, 720)
  r = image.newContext

var explorer = Explorer(current_dir: "", item_index: 0, files: @[], display: false)

proc update_file*(file: string) =
  window.title = file & " - folx"
  text = file.readFile
  colors = text.parseNimCode.map(color)
  lines = text.splitLines.map(toRunes)
  text_indentation = lines.indentation
  doassert colors.len == lines.len

proc animate(dt: float32): bool =
  if pos != visual_pos:
    let
      fontSize = editor_gt.font.size
      pvp = (visual_pos * fontSize).round.int32
      
      d = (abs(pos - visual_pos) * (0.00001 / dt)).max(0.1).min(abs(pos - visual_pos))

    if pos > visual_pos: visual_pos += d
    else:                visual_pos -= d

    if abs(visual_pos - pos) < 1 / fontSize / 2.1:
      visual_pos = pos
    if pvp != (visual_pos * fontSize).round.int32: result = true


proc display =
  image.fill colorTheme.textarea

  if explorer.display:
    r.explorer_area(
      image = image,
      box = rect(vec2(0, 0), window.size.vec2 - vec2(10, 20)),
      pos = visual_pos,
      gt = editor_gt,
      bg = configuration.colorTheme.textarea,
      explorer = explorer,
    )
  else:  
    r.text_editor(
      box = rect(vec2(), window.size.vec2 - vec2(0, 20)),
      gt = editor_gt,
      pos = visual_pos,
      bg = colorTheme.textarea,
      text = lines,
      colors = colors,
      indentation = text_indentation,
    )

    r.status_bar(
      box = rect(vec2(0, window.size.vec2.y - 20), vec2(window.size.vec2.x, 20)),
      gt = interface_gt,
      bg = colorTheme.statusBarBg,
      text = toRunes "visual_pos: " & $visual_pos,
    )

  window.draw image



window.onCloseRequest = proc =
  close window
  quit(0)


window.onScroll = proc =
  if window.scrollDelta.y == 0: return
  if window.buttonDown[KeyLeftControl] or window.buttonDown[KeyRightControl]:
    let newSize = (editor_gt.font.size * (pow(17 / 16, window.scrollDelta.y))).round.max(1)
    
    if editor_gt.font.size != newSize:
      editor_gt.font.size = newSize
    else:
      editor_gt.font.size = (editor_gt.font.size + window.scrollDelta.y).max(1)
    
    clear editor_gt
    displayRequest = true
  else:
    pos = (pos - window.scrollDelta.y * 3).max(0).min(lines.high.float32)


window.onResize = proc =
  if window.size.x * window.size.y == 0: return
  image = newImage(window.size.x, window.size.y)
  r = image.newContext
  display()

window.onButtonPress = proc(button: Button) =
  
  if explorer.display:

    if button == KeyDown:
      discard explorer.move(MoveCommand.Down, config.file, colors)
    if button == KeyUp:
      discard explorer.move(MoveCommand.Up, config.file, colors)
    if button == KeyLeft:
      discard explorer.move(MoveCommand.Left, config.file, colors)
    if button == KeyRight:
      update_file(explorer.move(MoveCommand.Right, config.file, colors))

  if window.buttonDown[KeyLeftControl] and button == KeyO:
    echo "Ctrl+O"
    explorer.display = not explorer.display
  
  discard explorer.move(MoveCommand.None, config.file, colors)

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
