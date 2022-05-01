import std/unicode, strformat
import pixwindy, pixie
import render, configuration, markup

component StatusBar:
  proc handle(
    bg: ColorRgb,
    fieldsStart: seq[tuple[field: string, value: string]],
    fieldsEnd: seq[tuple[field: string, value: string]],
  )

  const margin = vec2(10, 2)
  const marginEnd = vec2(10, 2)
  const spacing = 20

  Rect: color = bg

  var x = margin.x
  for (f, v) in fieldsStart:
    let s = &"{f}: {v}"
    let w = s.toRunes.width(glyphTableStack[^1])
    Text s(x = x, y = margin.y):
      color = colorTheme.cInActive
      bg = bg
    
    x += spacing + w.float32

  x = parentBox.w - marginEnd.x
  for i in fieldsEnd:
    let s =
      if i.field == "git": i.value
      else: i.field & i.value
    
    let w = s.toRunes.width(glyphTableStack[^1])
    
    Text s(x = x - w.float32, y = margin.y):
      color = colorTheme.cInActive
      bg = bg
    
    x -= spacing + w.float32

    if i.field == "git":
      let wh = vec2(iconTheme.git.width.float32, iconTheme.git.height.float32)
      Image iconTheme.git(x = x, y = 2, wh = wh)
      x -= spacing
