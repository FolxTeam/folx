import tables, unicode
import pixie
import syntax_highlighting

type
  GlyphTable* = object
    ## table of pre-renered text images
    font*: Font
    glyphs: Table[tuple[c: Rune; fg, bg: ColorRgb], Image]


{.push, checks: off.}

func draw*(r: Image, g: Image, pos: IVec2, size: IVec2) =
  ## draw image (fast)

  # clip
  let pos2 = ivec2(max(-pos.x, 0), max(-pos.y, 0))
  let pos = pos + pos2
  let size = ivec2(
    size.x.min(g.width.int32 - pos2.x).min(r.width.int32 - pos.x),
    size.y.min(g.height.int32 - pos2.y).min(r.height.int32 - pos.y)
  )
  if size.x <= 0 or size.y <= 0: return

  # draw
  for y in 0..<size.y:
    var
      idst = (pos.y + y) * r.width + pos.x
      isrc = (pos2.y + y) * g.width + pos2.x
    for _ in 0..<size.x:
      r.data[idst] = g.data[isrc]
      inc isrc
      inc idst

proc vertical_line*(r: Image; x, y, h: int32, color: ColorRgb) =
  ## draw vertical line (fast)
  let x = x.min(r.width).max(0)
  for i in countup(y.min(r.height - 1).max(0) * r.width + x, (y + h).min(r.height - 1).max(0) * r.width + x, r.width):
    r.data[i] = rgbx(color.r, color.g, color.b, 255)

{.pop.}


proc render(c: Rune, font: Font; fg, bg: ColorRgb): Image =
  ## renter text to image
  let ts = font.typeset($c)
  let bounds = ts.computeBounds
  if bounds.x < 1 or bounds.y < 1: return nil
  result = newImage(bounds.x.ceil.int, bounds.y.ceil.int)
  result.fill bg
  font.paint.color = fg.color
  result.fillText(ts)

proc render(gt: var GlyphTable, c: Rune; fg, bg: ColorRgb) =
  ## pre-rener text and save it in table
  let img = c.render(gt.font, fg, bg)
  if img == nil:
    gt.glyphs[(c, fg, bg)] = nil
  else:
    gt.glyphs[(c, fg, bg)] = img

func clear*(gt: var GlyphTable) =
  clear gt.glyphs


proc draw*(r: Image, text: string, colors: seq[ColoredPos], box: Rect, gt: var GlyphTable, bg: ColorRgb) =
  ## draw colored text
  var (x, y, w, h) = (box.x.round.int32, box.y.round.int32, box.w.round.int32, box.h.round.int32)
  var i = 0
  var ic = -1
  var color: ColorRgb
  for c in text.runes:
    defer: inc i, c.size
    if colors.len > ic + 1 and colors[ic + 1].startPos == i:
      inc ic
      color = colors[ic].color
    
    var glyph =
      try: gt.glyphs[(c, color, bg)]
      except KeyError:
        gt.render(c, color, bg)
        gt.glyphs[(c, color, bg)]
    
    if glyph == nil:
      glyph = 
        try: gt.glyphs[(" ".runeAt(0), color, bg)]
        except KeyError:
          gt.render(" ".runeAt(0), color, bg)
          gt.glyphs[(" ".runeAt(0), color, bg)]
    
    if glyph == nil:
      continue

    if not c.isWhiteSpace:
      r.draw glyph, ivec2(x, y), ivec2(w, h)

    let bx = glyph.width.int32
    x += bx
    w -= bx
    if w <= 0: return


proc width*(text: string, gt: var GlyphTable): int32 =
  ## get width of text in pixels for font, specified in gt
  for c in text.runes:
    if (c, rgb(0, 0, 0), rgb(0, 0, 0)) notin gt.glyphs: gt.render(c, rgb(0, 0, 0), rgb(0, 0, 0))
    result += gt.glyphs[(c, rgb(0, 0, 0), rgb(0, 0, 0))].width.int32
