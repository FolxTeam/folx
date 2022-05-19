import gui, configuration
import explorer, side_explorer

type 
  Title* = object
    name*: string

proc onMouseMove*(
  title: var Title,
  window: var Window,
  ) =
  if config.window.customTitleBar:
    if window.mouse.pressed[MouseButton.left]:
      if window.mouse.pos.y in 0..<40:
        window.startInteractiveMove
  
proc onClick*(
  title: var Title,
  e: ClickEvent,
  window: var Window,
  explorer: var Explorer,
  side_explorer: var SideExplorer,
  pos: var float32
  ) =
  case e.button:
  of MouseButton.left:
    if config.window.customTitleBar:
      if window.mouse.pos.x >= window.size.x - 50 and window.mouse.pos.x < window.size.x and window.mouse.pos.y >= 0 and window.mouse.pos.y <= 40:
        quit()
      
      if window.mouse.pos.x >= window.size.x - 100 and window.mouse.pos.x < window.size.x - 50 and window.mouse.pos.y >= 0 and window.mouse.pos.y <= 40:
        window.maximized = not window.maximized
      
      if window.mouse.pos.x >= window.size.x - 150 and window.mouse.pos.x < window.size.x - 100 and window.mouse.pos.y >= 0 and window.mouse.pos.y <= 40:
        window.minimized = not window.minimized

      if window.mouse.pos.x >= 0 and window.mouse.pos.x < 65 and window.mouse.pos.y >= 0 and window.mouse.pos.y <= 40:

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
