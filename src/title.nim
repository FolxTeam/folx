import pixwindy, pixie
import render, configuration, markup

component TitleBarButton {.noexport.}:
  proc handle(
    icon: Image,
    bg: ColorRgb,
    gt: var GlyphTable,
    action: proc() = (proc() = discard),
  )

  r.fillStyle = bg
  r.fillRect parentBox

  frame(centerIn = parentBox, w = icon.width, h = icon.height):
    image.draw(icon, translate(parentBox.xy))


component TitleBar:
  proc handle(
    gt: var GlyphTable,
  )
  
  r.fillStyle = colorTheme.bgTitleBar
  r.fillRect parentBox


  TitleBarButton iconTheme.explorer(w = 65, h = 40):
    gt = gt
    bg = colorTheme.bgTitleBarSelect

  TitleBarButton iconTheme.search(x = 65, w = 65, h = 40):
    gt = gt
    bg = colorTheme.bgTitleBar

  TitleBarButton iconTheme.gitbranch(x = 130, w = 65, h = 40):
    gt = gt
    bg = colorTheme.bgTitleBar

  TitleBarButton iconTheme.extention(x = 195, w = 65, h = 40):
    gt = gt
    bg = colorTheme.bgTitleBar

  TitleBarButton iconTheme.minimaze(x = parentBox.w - 150, w = 50, h = 40):
    gt = gt
    bg = colorTheme.bgTitleBar

  TitleBarButton iconTheme.maximaze(x = parentBox.w - 100, w = 50, h = 40):
    gt = gt
    bg = colorTheme.bgTitleBar

  TitleBarButton iconTheme.close(x = parentBox.w - 50, w = 50, h = 40):
    gt = gt
    bg = colorTheme.bgTitleBar
