import pixwindy, pixie
import render, configuration, markup

component Name {.noexport.}:
  proc handle(
    gt: var GlyphTable,
  )

  let 
    box = parentBox
    dy = round(gt.font.size * 1.27)

  image.draw ("folx").toRunes, colorTheme.cMiddle, vec2(box.x, box.y), box, gt, colorTheme.bgTextArea

component Item {.noexport.}:
  proc handle(
    gt: var GlyphTable,
    label: string,
    hotkey: string,
  )

  let 
    box = parentBox
    dy = round(gt.font.size * 1.27)

  image.draw (label).toRunes, colorTheme.cMiddle, vec2(box.x, box.y), box, gt, colorTheme.bgTextArea

  r.fillStyle = colorTheme.cMiddle
  r.fillRoundedRect rect(vec2(box.x + 265, box.y - 2), vec2(130, 40)), 10.0

  r.fillStyle = colorTheme.bgTextArea
  r.fillRoundedRect rect(vec2(box.x + 267, box.y), vec2(126, 36)), 10.0

  image.draw (hotkey).toRunes, colorTheme.cMiddle, vec2(box.x + 280, box.y), box, gt, colorTheme.bgTextArea


component Welcome:
  proc handle(
    gt: var GlyphTable,
  )

  let box = parentBox

  gt.font.size = gt.font.size * 2.5

  Name(x = (box.w - 400) / 2, y = 200, w = 400, h = 50):
    gt = gt

  Item(x = (box.w - 400) / 2, y = 300, w = 400, h = 50):
    gt = gt
    label = "Open Folder"
    hotkey = "Ctrl+O"

  Item(x = (box.w - 400) / 2, y = 400, w = 400, h = 50):
    gt = gt
    label = "Open Explorer"
    hotkey = "Ctrl+E"

  gt.font.size = gt.font.size / 2.5

