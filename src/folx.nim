import os, times, math, sequtils, unicode, strutils, std/monotimes, std/algorithm
import pixwindy, pixie
import render, syntax_highlighting, configuration, text_editor, explorer

proc digits(x: BiggestInt): int =
  var x = x
  if x == 0:
    return 1

  while x != 0:
    inc result
    x = x div 10
  

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
  expl: var Explorer,
  ) =

  let dy = round(gt.font.size * 1.27)
  var y = box.y - dy * (pos mod 1)

  var max_file_length = 0
  var max_file_size: BiggestInt = 0
  
  # todo: refactor long expressions
  for file in expl.files:
    max_file_length = if (file.name & file.ext).len() > max_file_length: (file.name & file.ext).len() else: max_file_length
    max_file_size = if file.info.size > max_file_size: file.info.size else: max_file_size

  # ! sorted on each component rerender | check if seq already sorted or take the sort to explorer.nim
  sort(expl.files, explorer.folderUpCmp)

  r.image.draw expl.current_dir.toRunes, @[(sKeyword.color, 0)], vec2(box.x, y), box, gt, bg
  y += dy

  for i, file in expl.files.pairs:
    let spaces_after_name = " ".repeat(max_file_length + 1 - (file.name & file.ext).len())
    let spaces_after_size = " ".repeat(max_file_size.digits() + 1 - digits(file.info.size))

    let text = file.name & file.ext & spaces_after_name & $file.info.size & spaces_after_size & $file.info.lastWriteTime.format("hh:mm dd/MM/yy")
    if i == int(expl.item_index):
      r.fillStyle = colorTheme.statusBarBg
      r.fillRect rect(vec2(0,y), vec2(text.toRunes.width(gt).float32, dy))
      r.image.draw toRunes(text), @[(rgb(0, 0, 0), 0)], vec2(box.x, y), box, gt, colorTheme.statusBarBg

    else:
      if file.info.kind == PathComponent.pcDir:
        r.image.draw text.toRunes, @[(sStringLitEscape.color, 0)], vec2(box.x, y), box, gt, bg
      else:
        r.image.draw text.toRunes, @[(sText.color, 0)], vec2(box.x, y), box, gt, bg
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
  image = newImage(1280, 720)
  r = image.newContext

  pos = 0'f32
  visual_pos = pos
  cursor = ivec2(0, 0)

var main_explorer = Explorer(current_dir: "", item_index: 0, files: @[], display: false)

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
    r.explorer_area(
      image = image,
      box = rect(vec2(0, 0), window.size.vec2 - vec2(10, 20)),
      pos = visual_pos,
      gt = editor_gt,
      bg = configuration.colorTheme.textarea,
      expl = main_explorer,
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
    pos = (pos - window.scrollDelta.y * 3).max(0).min(lines.high.float32)


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
    explorer_onButtonDown(
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
