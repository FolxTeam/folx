import tables, unicode
import pixie
import syntax_highlighting

type
  Glyph* = tuple[width, height: int32, data: seq[ColorRgbx]]

  GlyphTable* = object
    font*: Font
    glyphs: Table[tuple[c: Rune; fg, bg: ColorRgb], Glyph]


{.push, checks: off.}

func drawGlyph(r: Image, g: Glyph, pos: IVec2, size: IVec2) =
  ## fast draw image

  # clip
  let pos2 = ivec2(max(-pos.x, 0), max(-pos.y, 0))
  let pos = pos + pos2
  let size = ivec2(
    size.x.min(g.width - pos2.x).min(r.width.int32 - pos.x),
    size.y.min(g.height - pos2.y).min(r.height.int32 - pos.y)
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
  let x = x.min(r.width).max(0)
  for i in countup(y.min(r.height).max(0) * r.width + x, (y + h).min(r.height).max(0) * r.width + x, r.width):
    r.data[i] = rgbx(color.r, color.g, color.b, 255)

{.pop.}


proc render(c: Rune, font: Font; fg, bg: ColorRgb): Image =
  let ts = font.typeset($c)
  let bounds = ts.computeBounds
  if bounds.x < 1 or bounds.y < 1: return nil
  result = newImage(bounds.x.ceil.int, bounds.y.ceil.int)
  result.fill bg
  font.paint.color = fg.color
  result.fillText(ts)

proc render(gt: var GlyphTable, c: Rune; fg, bg: ColorRgb) =
  let img = c.render(gt.font, fg, bg)
  if img == nil:
    gt.glyphs[(c, fg, bg)] = Glyph.default
  else:
    gt.glyphs[(c, fg, bg)] = (width: img.width.int32, height: img.height.int32, data: img.data)

func clear*(gt: var GlyphTable) =
  clear gt.glyphs


proc draw*(r: Image, text: seq[ColoredText], box: Rect, gt: var GlyphTable, bg: ColorRgb) =
  var (x, y, w, h) = (box.x.round.int32, box.y.round.int32, box.w.round.int32, box.h.round.int32)
  for cs in text:
    let color = cs.color
    for c in cs.text.runes:
      let glyph =
        try: gt.glyphs[(c, color, bg)].addr
        except KeyError:
          gt.render(c, color, bg)
          gt.glyphs[(c, color, bg)].addr
      if not c.isWhiteSpace:
        r.drawGlyph glyph[], ivec2(x, y), ivec2(w, h)
      let bx = glyph[].width
      x += bx
      w -= bx
      if w <= 0: return


proc width*(text: string, gt: var GlyphTable): int32 =
  for c in text.runes:
    if (c, rgb(0, 0, 0), rgb(0, 0, 0)) notin gt.glyphs: gt.render(c, rgb(0, 0, 0), rgb(0, 0, 0))
    result += gt.glyphs[(c, rgb(0, 0, 0), rgb(0, 0, 0))].width
