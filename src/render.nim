import tables, unicode
import pixie, boxy
import syntax_highlighting

type
  Key = tuple[c: Rune; fg, bg: ColorRgb]

  GlyphTable* = object
    font*: Font
    boxy*: Boxy
    glyphs: Table[Key, int32]


proc `$@`[T](i: T): string =
  cast[string](cast[ptr array[T.sizeof, byte]](i.unsafeaddr)[].`@`)


proc vertical_line*(gt: GlyphTable; x, y, h: int32, color: ColorRgb) =
  gt.boxy.drawRect rect(vec2(x.float32, y.float32), vec2(1, h.float32)), color.color


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
    gt.glyphs[(c, fg, bg)] = 0
  else:
    gt.glyphs[(c, fg, bg)] = img.width.int32
    gt.boxy.addImage $(c, fg, bg), img

proc clear*(gt: var GlyphTable) =
  clear gt.glyphs
  clearAtlas gt.boxy


proc draw*(text: seq[ColoredText], box: Rect, gt: var GlyphTable, bg: ColorRgb) =
  var (x, y, w, _) = (box.x.round.int32, box.y.round.int32, box.w.round.int32, box.h.round.int32)
  for cs in text:
    let color = cs.color
    
    for c in cs.text.runes:
      let bx =
        try: gt.glyphs[(c, color, bg)]
        except KeyError:
          gt.render(c, color, bg)
          gt.glyphs[(c, color, bg)]

      
      if bx != 0 and not c.isWhiteSpace:
        gt.boxy.drawImage $(c, color, bg), vec2(x.float32, y.float32)
      
      x += bx
      w -= bx
      if w <= 0: return


proc width*(text: string, gt: var GlyphTable): int32 =
  for c in text.runes:
    let w =
      try: gt.glyphs[(c, rgb(0, 0, 0), rgb(0, 0, 0))]
      except KeyError:
        gt.render(c, rgb(0, 0, 0), rgb(0, 0, 0))
        gt.glyphs[(c, rgb(0, 0, 0), rgb(0, 0, 0))]
    
    result += w
