import pixwindy, pixie
import render, configuration

proc title_bar_button_minimaze(
    r: Context,
    box: Rect,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect box

  r.image.draw(iconTheme.minimaze, translate(vec2(box.x + 16, 19)))

proc title_bar_button_maximaze(
    r: Context,
    box: Rect,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect box

  r.image.draw(iconTheme.maximaze, translate(vec2(box.x + 16, 16)))

proc title_bar_button_close(
    r: Context,
    box: Rect,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect box

  r.image.draw(iconTheme.close, translate(vec2(box.x + 16, 16)))

proc title_bar_button_extention(
    r: Context,
    box: Rect,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect box

  r.image.draw(iconTheme.extention, translate(vec2(220, 12)))

proc title_bar_button_git(
    r: Context,
    box: Rect,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect box

  r.image.draw(iconTheme.gitbranch, translate(vec2(155, 12)))

proc title_bar_button_search(
    r: Context,
    box: Rect,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect box

  r.image.draw(iconTheme.search, translate(vec2(90, 12)))

proc title_bar_button_explorer(
    r: Context,
    box: Rect,
    gt: var GlyphTable,
    bg: ColorRgb
  ) =

  r.fillStyle = bg
  r.fillRect box

  r.image.draw(iconTheme.explorer, translate(vec2(25, 13)))

proc title_bar*(
  r: Context,
  box: Rect,
  gt: var GlyphTable,
  ) =
  
  r.fillStyle = colorTheme.bgTitleBar
  r.fillRect box

  r.title_bar_button_explorer(
    box = rect(vec2(0, 0), vec2(65, 40)),
    gt = gt,
    bg = colorTheme.bgTitleBarSelect
  )

  r.title_bar_button_search(
    box = rect(vec2(65, 0), vec2(65, 40)),
    gt = gt,
    bg = colorTheme.bgTitleBar
  )

  r.title_bar_button_git(
    box = rect(vec2(130, 0), vec2(65, 40)),
    gt = gt,
    bg = colorTheme.bgTitleBar
  )

  r.title_bar_button_extention(
    box = rect(vec2(195, 0), vec2(65, 40)),
    gt = gt,
    bg = colorTheme.bgTitleBar
  )

  r.title_bar_button_minimaze(
    box = rect(vec2(box.w - 150, 0), vec2(50, 40)),
    gt = gt,
    bg = colorTheme.bgTitleBar
  )

  r.title_bar_button_maximaze(
    box = rect(vec2(box.w - 100, 0), vec2(50, 40)),
    gt = gt,
    bg = colorTheme.bgTitleBar
  )

  r.title_bar_button_close(
    box = rect(vec2(box.w - 50, 0), vec2(50, 40)),
    gt = gt,
    bg = colorTheme.bgTitleBar
  )
