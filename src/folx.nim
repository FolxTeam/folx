import os, times, math, sequtils, unicode, strutils
import pixwindy, pixie
import render, syntax_highlighting, configuration, text_editor


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

  r.image.draw text, @[(sText.color, 0)], rect(box.xy + margin, box.wh - margin), gt, bg



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
