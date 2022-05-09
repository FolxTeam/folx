import tables, unicode, sequtils
import pixie, markup
export markup

type
  GlyphTable* = ref object
    ## table of pre-renered text images
    font*: Font
    glyphs: Table[tuple[c: Rune; fg, bg: ColorRgb], Glyph]
  
  Glyph = object
    size: IVec2
    data: seq[ColorRgbx]


var
  contextStack*: seq[Context]
  glyphTableStack*: seq[GlyphTable]


template withGlyphTable*(x: GlyphTable, body) =
  glyphTableStack.add x
  block: body
  glyphTableStack.del glyphTableStack.high

template withContext*(x: Context, body) =
  contextStack.add x
  block: body
  contextStack.del contextStack.high


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

component Image {.noexport.}:
  # image (unscaled)
  proc handle(
    g: Glyph,
    srcPos: IVec2 = ivec2(0, 0),
  )
  let
    pos1 = parentBox.xy.ivec2
    size1 = parentBox.wh.ivec2
    r = contextStack[^1].image

  # clip
  let pos2 = ivec2(max(-pos1.x, 0), max(-pos1.y, 0)) + srcPos
  let pos = pos1 + pos2
  let size = ivec2(
    (size1.x - srcPos.x).min(g.size.x - pos2.x).min(r.width.int32 - pos.x),
    (size1.y - srcPos.y).min(g.size.y - pos2.y).min(r.height.int32 - pos.y)
  )
  if size.x <= 0 or size.y <= 0: return

  # draw
  for y in 0..<size.y:
    let
      idst = (pos.y + y) * r.width + pos.x
      isrc = (pos2.y + y) * g.size.x + pos2.x
    for x in 0..<size.x:
      r.data[idst + x] = g.data[isrc + x]

component Image:
  # image (unscaled)
  proc handle(
    g: Image,
    srcPos: IVec2 = ivec2(0, 0),
  )
  let
    pos1 = parentBox.xy.ivec2
    size1 = parentBox.wh.ivec2
    r = contextStack[^1].image

  # clip
  let pos2 = ivec2(max(-pos1.x, 0), max(-pos1.y, 0)) + srcPos
  let pos = pos1 + pos2
  let size = ivec2(
    (size1.x - srcPos.x).min(g.width.int32 - pos2.x).min(r.width.int32 - pos.x),
    (size1.y - srcPos.y).min(g.height.int32 - pos2.y).min(r.height.int32 - pos.y)
  )
  if size.x <= 0 or size.y <= 0: return

  # draw
  for y in 0..<size.y:
    let
      idst = (pos.y + y) * r.width + pos.x
      isrc = (pos2.y + y) * g.width + pos2.x
    for x in 0..<size.x:
      r.data[idst + x] = g.data[isrc + x]


component VerticalLine:
  # draw vertical line (fast)
  proc handle(
    color: ColorRgb
  )
  let
    pbox = parentBox
    r = contextStack[^1].image
    y = pbox.y.int32
    h = pbox.h.int32
    box = clipStack[^1]
    (bx, by, bw, bh) = (box.x.round.int32, box.y.round.int32, box.w.round.int32, box.h.round.int32)
    x = pbox.x.int32.min(bx + bw).min(r.width).max(bx).max(0)
  
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


proc render(c: Rune, font: Font; fg, bg: ColorRgb): Glyph =
  ## renter text to image
  if not font.typeface.hasGlyph(c) and c != static(" ".runeAt(0)):
    return render(static(" ".runeAt(0)), font, fg, bg)

  let ts = font.typeset($c)
  let bounds = ts.layoutBounds
  if bounds.x <= 0 or bounds.y <= 0: return
  result.size = ivec2(bounds.x.ceil.int32, bounds.y.ceil.int32)
  let img = newImage(result.size.x, result.size.y)
  img.fill bg
  font.paint.color = fg.color
  img.fillText(ts)
  result.data = img.data

proc render(gt: GlyphTable, c: Rune; fg, bg: ColorRgb) =
  ## pre-rener text and save it in table
  gt.glyphs[(c, fg, bg)] = c.render(gt.font, fg, bg)

func clear*(gt: GlyphTable) =
  clear gt.glyphs

proc `[]`(gt: GlyphTable, c: Rune; fg, bg: ColorRgb): ptr Glyph =
  try: gt.glyphs[(c, fg, bg)].addr
  except KeyError:
    gt.render(c, fg, bg)
    gt.glyphs[(c, fg, bg)].addr


proc width*(text: openarray[Rune], gt: GlyphTable): int32 =
  ## get width of text in pixels for font, specified in gt
  const white = rgb(255, 255, 255)
  
  for c in text:
    result += gt[c, white, white].size.x

proc width*(text: string, gt: GlyphTable): int32 =
  ## get width of text in pixels for font, specified in gt
  const white = rgb(255, 255, 255)
  
  for c in text.runes:
    result += gt[c, white, white].size.x


component Text:
  # colored text
  proc handle(
    text: openarray[Rune],
    colors: openarray[ColorRgb],
    bg: ColorRgb,
  )
  let gt = glyphTableStack[^1]

  assert text.len == colors.len
  let
    box = clipStack[^1]

  var (x, y, w, h) = (0'i32, 0'i32, (box.w - parentBox.x + box.x).round.int32, (box.h - parentBox.y + box.y).round.int32)
  # todo: clip x (from start)
  let hd = max(box.y - parentBox.y, 0).round.int32

  for i, c in text:
    let
      color = colors[i]
      glyph = gt[c, color, bg]
      bx = glyph.size.x

    if not c.isWhiteSpace:
      Image glyph[](x=x, y=y, w=w, h=h):
        srcPos = ivec2(0, hd)

    x += bx
    w -= bx
    if w <= 0: return


component Text:
  # colored text
  proc handle(
    text: string,
    colors: openarray[ColorRgb],
    bg: ColorRgb,
  )
  
  Text text.toRunes:
    colors = colors
    bg = bg


component Text:
  # colored text
  proc handle(
    text: openarray[Rune],
    color: ColorRgb,
    bg: ColorRgb,
  )
  
  Text text:
    colors = color.repeat(text.len)
    bg = bg


component Text:
  # colored text
  proc handle(
    text: string,
    color: ColorRgb,
    bg: ColorRgb,
  )
  
  Text text:
    colors = color.repeat(text.runeLen)
    bg = bg


component Frame:
  discard

component Rect:
  proc handle(
    color: SomeColor,
  )

  let r = contextStack[^1]
  r.fillStyle = color
  r.fillRect parentBox

component Rect:
  # rounded rect
  proc handle(
    color: SomeColor,
    radius: SomeNumber,
  )

  let r = contextStack[^1]
  r.fillStyle = color
  r.fillRoundedRect parentBox, radius.float32
