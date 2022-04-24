import pixwindy, pixie
import render, configuration, markup

proc title_bar_button_minimaze(
    r: Context,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect parentBox

  r.image.draw(iconTheme.minimaze, translate(vec2(parentBox.x + 16, 19)))

proc title_bar_button_maximaze(
    r: Context,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect parentBox

  r.image.draw(iconTheme.maximaze, translate(vec2(parentBox.x + 16, 16)))

proc title_bar_button_close(
    r: Context,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect parentBox

  r.image.draw(iconTheme.close, translate(vec2(parentBox.x + 16, 16)))

proc title_bar_button_extention(
    r: Context,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect parentBox

  r.image.draw(iconTheme.extention, translate(vec2(220, 12)))

proc title_bar_button_git(
    r: Context,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect parentBox

  r.image.draw(iconTheme.gitbranch, translate(vec2(155, 12)))

proc title_bar_button_search(
    r: Context,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect parentBox

  r.image.draw(iconTheme.search, translate(vec2(90, 12)))

proc title_bar_button_explorer(
    r: Context,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect parentBox

  r.image.draw(iconTheme.explorer, translate(vec2(25, 13)))

proc title_bar*(
  r: Context,
  gt: var GlyphTable,
  ) =
  
  r.fillStyle = colorTheme.bgTitleBar
  r.fillRect parentBox


  frame(x = 0, y = 0, w = 65, h = 40):
    r.title_bar_button_explorer(
      gt = gt,
      bg = colorTheme.bgTitleBarSelect
    )

  frame(x = 65, y = 0, w = 65, h = 40):
    r.title_bar_button_search(
      gt = gt,
      bg = colorTheme.bgTitleBar
    )

  frame(x = 130, y = 0, w = 65, h = 40): 
    r.title_bar_button_git(
      gt = gt,
      bg = colorTheme.bgTitleBar
    )

  frame(x = 195, y = 0, w = 65, h = 40): 
    r.title_bar_button_extention(
      gt = gt,
      bg = colorTheme.bgTitleBar
    )

  frame(x = parentBox.w - 150, y = 0, w = 50, h = 40): 
    r.title_bar_button_minimaze(
      gt = gt,
      bg = colorTheme.bgTitleBar
    )

  frame(x = parentBox.w - 100, y = 0, w = 50, h = 40): 
    r.title_bar_button_maximaze(
      gt = gt,
      bg = colorTheme.bgTitleBar
    )

  frame(x = parentBox.w - 50, y = 0, w = 50, h = 40): 
    r.title_bar_button_close(
      gt = gt,
      bg = colorTheme.bgTitleBar
    )
