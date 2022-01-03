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
  if bounds.x < 1 or bounds.y < 1: return newImage(1, font.size.ceil.int)
  result = newImage(bounds.x.ceil.int, bounds.y.ceil.int)
  result.fillText(ts)

proc render(gt: var GlyphTable, c: Rune) =
  let img = c.render(gt.font)
  gt.glyphs[c] = (width: img.width.int32, height: img.height.int32, data: img.data.mapit(it.a))

proc clear*(gt: var GlyphTable) =
  clear gt.glyphs


proc draw*(r: Image, text: seq[CodeSegment], box: Rect, gt: var GlyphTable) =
  var (x, y, w, h) = (box.x, box.y, box.w, box.h)
  for cs in text:
    for c in cs.text.runes:
      if c notin gt.glyphs: gt.render(c)
      r.drawGlyph gt.glyphs[c], ivec2(x.round.int32, y.round.int32), ivec2(w.round.int32, h.round.int32), cs.kind.color
      let b = vec2(gt.glyphs[c].width.float32, gt.glyphs[c].height.float32)
      x += b.x
      w -= b.x
