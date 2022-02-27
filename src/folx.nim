import os, times, math, sequtils, unicode, strutils, std/monotimes
import pixwindy, pixie
import render, syntax_highlighting, configuration, text_editor, side_explorer


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
  image = newImage(1280, 720)
  r = image.newContext

  pos = 0'f32
  visual_pos = pos
  cursor = ivec2(0, 0)

var main_explorer = SideExplorer(current_dir: config.workspace, item_index: 1, display: false)

proc reopen_file*(file: string) =
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
      pvp = (visual_pos * fontSize).round.int32  # visual position in pixels
      
      # position delta
      d = (abs(pos - visual_pos) * pow(1 / 2, (1 / dt) / 50)).max(0.1).min(abs(pos - visual_pos))

    # move position by delta
    if pos > visual_pos: visual_pos += d
    else:                visual_pos -= d

    # if position close to integer number, round it
    if abs(visual_pos - pos) < 1 / fontSize / 2.1:
      visual_pos = pos
    
    # if position changed, signal to display by setting result to true
    if pvp != (visual_pos * fontSize).round.int32: result = true


proc display =
  image.clear colorTheme.textarea.color.rgbx

  if main_explorer.display:

    var box = rect(vec2(0, 0), window.size.vec2 - vec2(10, 20))
    var dy = round(editor_gt.font.size * 1.27)
    var y = box.y - dy * (pos mod 1)

    r.image.draw toRunes(main_explorer.dir.path), @[(sKeyword.color, 0)], vec2(box.x, y), box, editor_gt, configuration.colorTheme.textarea
    y += dy

    r.side_explorer_area(
      image = image,
      box = box,
      pos = visual_pos,
      gt = editor_gt,
      bg = configuration.colorTheme.textarea,
      dir = main_explorer.dir,
      explorer = main_explorer,
      count_items = 0,
      y = y,
      nesting = 0,
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
      cursor = cursor,
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
    let lines_count = if main_explorer.display: main_explorer.count_items.float32 else: lines.high.float32
    pos = (pos - window.scrollDelta.y * 3).max(0).min(lines_count)



window.onResize = proc =
  if window.size.x * window.size.y == 0: return
  image = newImage(window.size.x, window.size.y)
  r = image.newContext
  display()

window.onButtonPress = proc(button: Button) =
  if window.buttonDown[KeyLeftControl] and button == KeyO:
    main_explorer.display = not main_explorer.display
    
    if main_explorer.display:
      main_explorer.updateDir config.file

  elif main_explorer.display:
    side_explorer_onButtonDown(
      button = button,
      explorer = main_explorer,
      path = config.file,
      onFileOpen = (proc(file: string) =
        reopen_file file
        main_explorer.display = false
      ),
    )

  else:
    text_editor_onButtonDown(
      button,
      cursor,
      text = lines,
    )
  
  display()


display()
window.visible = true

var pt = getMonoTime()  # main clock
while not window.closeRequested:
  let nt = getMonoTime()  # tick start time
  pollEvents()
  
  let dt = getMonoTime()
  # animate
  displayRequest = displayRequest or animate((dt - pt).inMicroseconds.int / 1_000_000)

  if displayRequest:
    display()
    displayRequest = false
  
  pt = dt  # update main clock

  # sleep when no events happen
  let ct = getMonoTime()
  if (ct - nt).inMilliseconds < 10:
    sleep(10 - (ct - nt).inMilliseconds.int)
