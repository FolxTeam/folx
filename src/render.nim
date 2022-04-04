import tables, unicode, sequtils
import pixie

type
  GlyphTable* = object
    ## table of pre-renered text images
    font*: Font
    glyphs: Table[tuple[c: Rune; fg, bg: ColorRgb], Image]


proc newGlyphTable*(font: Font, fontSize: float32): GlyphTable =
  font.size = fontSize
  font.paint.color = color(1, 1, 1, 1)
  GlyphTable(font: font)


proc bound*(a, b: Rect): Rect =
  let pos2 = vec2(
    max(b.x - a.x, 0),
    max(b.y - a.y, 0)
  )
  result.xy = a.xy + pos2
  result.wh = vec2(
    (a.w - pos2.x).max(0),
    (a.h - pos2.y).max(0)
  )


{.push, checks: off.}

func draw*(r: Image, g: Image, pos: IVec2, size: IVec2, srcPos: IVec2) =
  ## draw image (fast)

  # clip
  let pos2 = ivec2(max(-pos.x, 0), max(-pos.y, 0)) + srcPos
  let pos = pos + pos2
  let size = ivec2(
    (size.x - srcPos.x).min(g.width.int32 - pos2.x).min(r.width.int32 - pos.x),
    (size.y - srcPos.y).min(g.height.int32 - pos2.y).min(r.height.int32 - pos.y)
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

proc vertical_line*(r: Image; x, y, h: int32, box: Rect, color: ColorRgb) =
  ## draw vertical line (fast)
  let (bx, by, bw, bh) = (box.x.round.int32, box.y.round.int32, box.w.round.int32, box.h.round.int32)
  let x = x.min(bx + bw).min(r.width).max(bx).max(0)
  for i in countup(
    y.min(by + bh).min(r.height - 1).max(by).max(0) * r.width + x,
    ((y + h).min(by + bh).min(r.height).max(by).max(0) - 1) * r.width + x, r.width
  ):
    r.data[i] = rgbx(color.r, color.g, color.b, 255)

proc clear*(image: Image, color: ColorRgbx) =
  ## fill image (fast)
  if image.data.len == 0:
    return

  let c = cast[uint64]([color, color])
  var p = cast[int](image.data[0].addr)
  var rem = image.data.len div 8
  while rem != 0:
    # parallel assignments
    cast[ptr uint64](p)[] = c
    cast[ptr uint64](p + 8)[] = c
    cast[ptr uint64](p + 16)[] = c
    cast[ptr uint64](p + 24)[] = c
    dec rem
    inc p, 32
  
  for _ in 1..(image.data.len mod 8):
    cast[ptr ColorRgbx](p)[] = color
    inc p, 4

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

proc `[]`(gt: var GlyphTable, c: Rune; fg, bg: ColorRgb): Image =
  const space = " ".runeAt(0)

  result =
    try: gt.glyphs[(c, fg, bg)]
    except KeyError:
      gt.render(c, fg, bg)
      gt.glyphs[(c, fg, bg)]
  
  if result == nil:
    result = 
      try: gt.glyphs[(space, fg, bg)]
      except KeyError:
        gt.render(space, fg, bg)
        gt.glyphs[(space, fg, bg)]


proc draw*(r: Image, text: openarray[Rune], colors: openarray[ColorRgb], pos: Vec2, box: Rect, gt: var GlyphTable, bg: ColorRgb) =
  ## draw colored text
  assert text.len == colors.len

  var (x, y, w, h) = (pos.x.round.int32, pos.y.round.int32, (box.w - pos.x + box.x).round.int32, (box.h - pos.y + box.y).round.int32)
  # todo: clip x (from start)
  let hd = max(box.y - pos.y, 0).round.int32

  for i, c in text:
    let color = colors[i]
    
    let glyph = gt[c, color, bg]
    
    if glyph == nil:
      continue

    if not c.isWhiteSpace:
      r.draw glyph, ivec2(x, y), ivec2(w, h), ivec2(0, hd)

    let bx = glyph.width.int32
    x += bx
    w -= bx
    if w <= 0: return


proc draw*(r: Image, text: openarray[Rune], color: ColorRgb, pos: Vec2, box: Rect, gt: var GlyphTable, bg: ColorRgb) =
  r.draw text, color.repeat(text.len), pos, box, gt, bg


proc width*(text: openarray[Rune], gt: var GlyphTable): int32 =
  ## get width of text in pixels for font, specified in gt
  const black = rgb(0, 0, 0) 
  
  for c in text:
    let glyph = gt[c, black, black]
    
    if glyph == nil:
      continue

    result += glyph.width.int32
