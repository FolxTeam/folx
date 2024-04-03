import gui, configuration

component Item {.noexport.}:
  proc handle(
    label: string,
    hotkey: string,
  )

  Text label:
    color = colorTheme.cMiddle
    bg = colorTheme.bgTextArea

  Rect(x = label.width(glyphTableStack[^1]) + 8, y = -2, w = hotkey.width(glyphTableStack[^1]) + 14, h = parentBox.h + 4):
    color = colorTheme.cMiddle.color
    radius = 5

    Rect(left = 2, top = 2, right = 2, bottom = 2):
      color = colorTheme.bgTextArea.color
      radius = 5

      Text hotkey(left = 5, top = 1, right = 5, bottom = 1):
        color = colorTheme.cMiddle
        bg = colorTheme.bgTextArea


component Welcome:
  proc handle()

  let fsize = glyphTableStack[^1].font.size + 4

  Frame(verticalCenterIn = parentBox, h = fsize * 3 + 20):
    Text "folx"(horisontalCenterIn = parentBox, w = "folx".width(glyphTableStack[^1]), h = fsize):
      color = colorTheme.cMiddle
      bg = colorTheme.bgTextArea

    Item(horisontalCenterIn = parentBox, y = fsize + 10, w = "Open Folder".width(glyphTableStack[^1]) + "Ctrl+O".width(glyphTableStack[^1]) + 20, h = fsize):
      label = "Open Folder"
      hotkey = "Ctrl+O"

    Item(horisontalCenterIn = parentBox, y = fsize * 2 + 20, w = "Open Explorer".width(glyphTableStack[^1]) + "Ctrl+E".width(glyphTableStack[^1]) + 20, h = fsize):
      label = "Open Explorer"
      hotkey = "Ctrl+E"
