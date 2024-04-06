import tables, unicode, sequtils
import pixie, markup
import ./graphics/[gl, shaders, shaderutils, globals]
export markup

type
  GlyphTable* = ref object
    ## table of pre-renered text images
    font*: Font
    glyphs: Table[tuple[c: Rune], Glyph]
  
  Glyph = object
    size: IVec2
    data: Textures


var
  # contextStack*: seq[Context]
  glyphTableStack*: seq[GlyphTable]
  oneLoadTexture: Textures  # workaround https://github.com/FolxTeam/folx/issues/21 until rendering will be completely refactored


template withGlyphTable*(x: GlyphTable, body) =
  glyphTableStack.add x
  block: body
  glyphTableStack.del glyphTableStack.high

# template withContext*(x: Context, body) =
#   contextStack.add x
#   block: body
#   contextStack.del contextStack.high


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
    color: Color,
  )
  let shader = global_drawContext.makeShader:
    proc vert(
      gl_Position: var Vec4,
      pos: var Vec2,
      uv: var Vec2,
      ipos: Vec2,
      transform: Uniform[Mat4],
      size: Uniform[Vec2],
      px: Uniform[Vec2],
    ) =
      transformation(gl_Position, pos, size, px, ipos, transform)
      uv = ipos

    proc frag(
      glCol: var Vec4,
      pos: Vec2,
      uv: Vec2,
      size: Uniform[Vec2],
      color: Uniform[Vec4],
      clipRectXy: Uniform[Vec2],
      clipRectWh: Uniform[Vec2],
    ) =
      let c = gltex.texture(uv)
      glCol = vec4(c.rgb, c.a) * vec4(color.rgb * color.a, color.a)
      if (
        pos.x < clipRectXy.x or pos.x > (clipRectXy.x + clipRectWh.x) or
        pos.y < clipRectXy.y or pos.y > (clipRectXy.y + clipRectWh.y)
      ):
        glCol = vec4(0, 0, 0, 0)

  if g.data == nil: return

  glEnable(GlBlend)
  glBlendFuncSeparate(GlOne, GlOneMinusSrcAlpha, GlOne, GlOne)

  glBindTexture(GlTexture2d, g.data[0])
  
  use shader.shader
  global_drawContext.passTransform(shader, pos=parentBox.xy.ivec2.vec2, size=g.size.vec2)
  shader.color.uniform = color.vec4
  if clipStack.len > 0:
    shader.clipRectXy.uniform = clipStack[^1].xy - parentBox.xy
    shader.clipRectWh.uniform = clipStack[^1].wh
  else:
    shader.clipRectXy.uniform = boxStack[0].xy - parentBox.xy
    shader.clipRectWh.uniform = boxStack[0].wh
  
  draw global_drawContext.rect

  glBindTexture(GlTexture2d, 0)

  glDisable(GlBlend)


component Image:
  # image (unscaled)
  proc handle(
    g: Image,
    srcPos: IVec2 = ivec2(0, 0),
    color: Color = color(1, 1, 1, 1),
  )
  let shader = global_drawContext.makeShader:
    proc vert(
      gl_Position: var Vec4,
      pos: var Vec2,
      uv: var Vec2,
      ipos: Vec2,
      transform: Uniform[Mat4],
      size: Uniform[Vec2],
      px: Uniform[Vec2],
    ) =
      transformation(gl_Position, pos, size, px, ipos, transform)
      uv = ipos

    proc frag(
      glCol: var Vec4,
      pos: Vec2,
      uv: Vec2,
      size: Uniform[Vec2],
      color: Uniform[Vec4],
      clipRectXy: Uniform[Vec2],
      clipRectWh: Uniform[Vec2],
    ) =
      let c = gltex.texture(uv)
      glCol = vec4(c.rgb, c.a) * vec4(color.rgb * color.a, color.a)
      if (
        pos.x < clipRectXy.x or pos.x > (clipRectXy.x + clipRectWh.x) or
        pos.y < clipRectXy.y or pos.y > (clipRectXy.y + clipRectWh.y)
      ):
        glCol = vec4(0, 0, 0, 0)


  glEnable(GlBlend)
  glBlendFuncSeparate(GlOne, GlOneMinusSrcAlpha, GlOne, GlOne)

  if oneLoadTexture == nil:
    oneLoadTexture = newTextures(1)
  oneLoadTexture[0].loadTexture g
  glBindTexture(GlTexture2d, oneLoadTexture[0])
  
  use shader.shader
  global_drawContext.passTransform(shader, pos=parentBox.xy.ivec2.vec2, size=parentBox.wh)
  shader.color.uniform = color.vec4
  if clipStack.len > 0:
    shader.clipRectXy.uniform = clipStack[^1].xy - parentBox.xy
    shader.clipRectWh.uniform = clipStack[^1].wh
  else:
    shader.clipRectXy.uniform = boxStack[0].xy - parentBox.xy
    shader.clipRectWh.uniform = boxStack[0].wh
  
  draw global_drawContext.rect

  glBindTexture(GlTexture2d, 0)

  glDisable(GlBlend)


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


proc render(c: Rune, font: Font): Glyph =
  ## renter text to image
  if not font.typeface.hasGlyph(c) and c != static(" ".runeAt(0)):
    return render(static(" ".runeAt(0)), font)

  let ts = font.typeset($c)
  let bounds = ts.layoutBounds
  if bounds.x <= 0 or bounds.y <= 0: return
  result.size = ivec2(bounds.x.ceil.int32, bounds.y.ceil.int32)
  let img = newImage(result.size.x, result.size.y)
  img.fill color(0, 0, 0, 0)
  font.paint.color = color(1, 1, 1, 1)
  img.fillText(ts)
  result.data = newTextures(1)
  result.data[0].loadTexture img

proc render(gt: GlyphTable, c: Rune) =
  ## pre-rener text and save it in table
  gt.glyphs[(c,)] = c.render(gt.font)

func clear*(gt: GlyphTable) =
  clear gt.glyphs

proc `[]`(gt: GlyphTable, c: Rune): ptr Glyph =
  try: gt.glyphs[(c,)].addr
  except KeyError:
    gt.render(c)
    gt.glyphs[(c,)].addr


proc width*(text: openarray[Rune], gt: GlyphTable): int32 =
  ## get width of text in pixels for font, specified in gt
  for c in text:
    result += gt[c].size.x

proc width*(text: string, gt: GlyphTable): int32 =
  ## get width of text in pixels for font, specified in gt
  for c in text.runes:
    result += gt[c].size.x


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
  # let hd = max(box.y - parentBox.y, 0).round.int32

  for i, c in text:
    let
      color = colors[i]
      glyph = gt[c]
      bx = glyph.size.x

    if not c.isWhiteSpace:
      Image glyph[](x=x, y=y, w=w, h=h):
        # srcPos = ivec2(0, hd)
        color = color.color

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
    color: Color,
  )
  let shader = global_drawContext.makeShader:
    proc vert(
      gl_Position: var Vec4,
      pos: var Vec2,
      ipos: Vec2,
      transform: Uniform[Mat4],
      size: Uniform[Vec2],
      px: Uniform[Vec2],
    ) =
      transformation(gl_Position, pos, size, px, ipos, transform)

    proc frag(
      glCol: var Vec4,
      pos: Vec2,
      size: Uniform[Vec2],
      color: Uniform[Vec4],
    ) =
      glCol = vec4(color.rgb * color.a, color.a)

  if color.a != 1:
    glEnable(GlBlend)
    glBlendFuncSeparate(GlOne, GlOneMinusSrcAlpha, GlOne, GlOne)

  use shader.shader
  global_drawContext.passTransform(shader, pos=parentBox.xy, size=parentBox.wh)
  shader.color.uniform = color.vec4
  
  draw global_drawContext.rect

  if color.a != 1:
    glDisable(GlBlend)


component Rect:
  # rounded rect
  proc handle(
    color: Color,
    radius: float,
  )
  let shader = global_drawContext.makeShader:
    proc vert(
      gl_Position: var Vec4,
      pos: var Vec2,
      ipos: Vec2,
      transform: Uniform[Mat4],
      size: Uniform[Vec2],
      px: Uniform[Vec2],
    ) =
      transformation(gl_Position, pos, size, px, ipos, transform)

    proc frag(
      glCol: var Vec4,
      pos: Vec2,
      radius: Uniform[float],
      size: Uniform[Vec2],
      color: Uniform[Vec4],
    ) =
      glCol = vec4(color.rgb * color.a, color.a) * roundRectOpacityAtFragment(pos, size, radius)
  
  glEnable(GlBlend)
  glBlendFuncSeparate(GlOne, GlOneMinusSrcAlpha, GlOne, GlOne)

  use shader.shader
  global_drawContext.passTransform(shader, pos=parentBox.xy, size=parentBox.wh)
  shader.radius.uniform = radius
  shader.color.uniform = color.vec4

  draw global_drawContext.rect

  glDisable(GlBlend)


component VerticalLine:
  # draw vertical line
  proc handle(
    color: ColorRgb
  )

  Rect(w = 1, h = parentBox.h):
    color = color.color
