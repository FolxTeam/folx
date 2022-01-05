import tables, sequtils, unicode
import pixie, pixie/blends
import syntax_highlighting

type
  Glyph* = tuple[width, height: int32, data: seq[byte]]

  GlyphTable* = object
    font*: Font
    glyphs: Table[Rune, Glyph]


{.push, checks: off.}

proc drawGlyph(r: Image, g: Glyph, pos: IVec2, size: IVec2, color: ColorRGB) =
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
      r.data[idst] = blendNormal(r.data[idst], rgba(color.r, color.g, color.b, g.data[isrc]))
      inc isrc
      inc idst

{.pop.}


proc render(text: Rune, font: Font): Image =
  let ts = font.typeset($text)
  let bounds = ts.computeBounds
  if bounds.x < 1 or bounds.y < 1: return nil
  result = newImage(bounds.x.ceil.int, bounds.y.ceil.int)
  result.fillText(ts)

proc render(gt: var GlyphTable, c: Rune) =
  let img = c.render(gt.font)
  if img == nil:
    gt.glyphs[c] = Glyph.default
  else:
    gt.glyphs[c] = (width: img.width.int32, height: img.height.int32, data: img.data.mapit(it.a))

proc clear*(gt: var GlyphTable) =
  clear gt.glyphs


proc draw*(r: Image, text: seq[ColoredText], box: Rect, gt: var GlyphTable) =
  var (x, y, w, h) = (box.x.round.int32, box.y.round.int32, box.w.round.int32, box.h.round.int32)
  for cs in text:
    let color = cs.color
    for c in cs.text.runes:
      if c notin gt.glyphs: gt.render(c)
      r.drawGlyph gt.glyphs[c], ivec2(x, y), ivec2(w, h), color
      let bx = gt.glyphs[c].width
      x += bx
      w -= bx
