import gui, configuration
import explorer, side_explorer

type 
  Title* = object
    name*: string

proc onMouseMove*(
  title: var Title,
  window: Window,
  ) =
  if config.window.customTitleBar:
    if MouseButton.left in window.mouse.pressed:
      if window.mouse.pos.y in 0..<40:
        window.startInteractiveMove

component TitleBarButton {.noexport.}:
  proc handle(
    icon: Image,  # todo: use texture instead
    bg: ColorRgb = colorTheme.bgTitleBar,
  )

  Rect:
    color =
      if mouseHover parentBox: colorTheme.bgTitleBarSelect.color
      else: bg.color

  frame(centerIn = parentBox, w = icon.width, h = icon.height):
    Image icon(w = icon.width, h = icon.height):
      discard


component TitleBar:
  proc handle(
    window: Window,
    explorer: var Explorer,
    side_explorer: var SideExplorer,
    pos: var float32,
    focusTextEditor: var bool,
  )
  
  Rect: color = colorTheme.bgTitleBar.color

  TitleBarButton iconTheme.explorer(w = 65, h = 40):
    bg =
      if side_explorer.display: colorTheme.bgTitleBarSelect
      else: colorTheme.bgTitleBar
    
    if isLeftClick and mouseHover parentBox:
      explorer.display = false
      side_explorer.display = not side_explorer.display
      focusTextEditor = not side_explorer.display
      
      if side_explorer.display:
        pos = side_explorer.pos
        side_explorer.updateDir config.file

  TitleBarButton iconTheme.search(x = 65, w = 65, h = 40):
    discard

  TitleBarButton iconTheme.gitbranch(x = 130, w = 65, h = 40):
    discard

  TitleBarButton iconTheme.extention(x = 195, w = 65, h = 40):
    discard

  if config.window.customTitleBar:
    TitleBarButton iconTheme.minimaze(x = parentBox.w - 150, w = 50, h = 40):
      if isLeftClick and mouseHover parentBox:
        window.minimized = not window.minimized

    TitleBarButton iconTheme.maximaze(x = parentBox.w - 100, w = 50, h = 40):
      if isLeftClick and mouseHover parentBox:
        window.maximized = not window.maximized

    TitleBarButton iconTheme.close(x = parentBox.w - 50, w = 50, h = 40):
      if isLeftClick and mouseHover parentBox:
        quit()
