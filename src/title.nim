import pixwindy, pixie
import render, configuration, markup
import explorer, side_explorer

type 
  Title* = object
    name*: string

var 
  mouseMove: bool = false
  oldPosition: IVec2 = ivec2(0,0)

proc onMouseMove*(
  title: var Title,
  window: Window,
  ) =
  if config.window.customTitleBar:
    if window.buttonDown[MouseLeft]:
      if window.mousePos.x >= 260 and window.mousePos.x < window.size.x - 150 and
        window.mousePos.y >= 0 and window.mousePos.y <= 40:
        mouseMove = true
        if oldPosition == ivec2(0,0):
          oldPosition = window.mousePos
      else:
        if oldPosition == ivec2(0,0):
          mouseMove = false
      if mouseMove:
        var newPosition: IVec2 = window.mousePos - oldPosition
        window.pos = ivec2(window.pos.x + newPosition.x, window.pos.y + newPosition.y)
    else:
      oldPosition = ivec2(0,0)
  
proc onButtonDown*(
  title: var Title,
  button: Button,
  window: Window,
  explorer: var Explorer,
  side_explorer: var SideExplorer,
  pos: var float32
  ) =

  case button
  of MouseLeft:
    if config.window.customTitleBar:
      if window.mousePos.x >= window.size.x - 50 and window.mousePos.x < window.size.x and
        window.mousePos.y >= 0 and window.mousePos.y <= 40:
        quit()
      
      if window.mousePos.x >= window.size.x - 100 and window.mousePos.x < window.size.x - 50 and
        window.mousePos.y >= 0 and window.mousePos.y <= 40:
        window.maximized = not window.maximized
      
      if window.mousePos.x >= window.size.x - 150 and window.mousePos.x < window.size.x - 100 and
        window.mousePos.y >= 0 and window.mousePos.y <= 40:
        window.minimized = not window.minimized

      if window.mousePos.x >= 0 and window.mousePos.x < 65 and
        window.mousePos.y >= 0 and window.mousePos.y <= 40:

        explorer.display = false
        side_explorer.display = not side_explorer.display
        
        if side_explorer.display:
          pos = side_explorer.pos
          side_explorer.updateDir config.file

  else: discard

component TitleBarButton {.noexport.}:
  proc handle(
    icon: Image,
    bg: ColorRgb,
    action: proc() = (proc() = discard),
  )

  Rect: color = bg

  frame(centerIn = parentBox, w = icon.width, h = icon.height):
    contextStack[^1].image.draw(icon, translate(parentBox.xy))


component TitleBar:
  proc handle()
  
  Rect: color = colorTheme.bgTitleBar

  TitleBarButton iconTheme.explorer(w = 65, h = 40):
    bg = colorTheme.bgTitleBarSelect

  TitleBarButton iconTheme.search(x = 65, w = 65, h = 40):
    bg = colorTheme.bgTitleBar

  TitleBarButton iconTheme.gitbranch(x = 130, w = 65, h = 40):
    bg = colorTheme.bgTitleBar

  TitleBarButton iconTheme.extention(x = 195, w = 65, h = 40):
    bg = colorTheme.bgTitleBar

  if config.window.customTitleBar:
    TitleBarButton iconTheme.minimaze(x = parentBox.w - 150, w = 50, h = 40):
      bg = colorTheme.bgTitleBar

    TitleBarButton iconTheme.maximaze(x = parentBox.w - 100, w = 50, h = 40):
      bg = colorTheme.bgTitleBar

    TitleBarButton iconTheme.close(x = parentBox.w - 50, w = 50, h = 40):
      bg = colorTheme.bgTitleBar
