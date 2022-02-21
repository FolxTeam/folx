import unicode, math
import pixie
import render, syntax_highlighting, configuration

type
  Indentation = seq[tuple[len: seq[int], has_graph: bool]]


proc bound[T](x: T, s: Slice[T]): T = x.max(s.a).min(s.b)
proc bound[T](x, s: Slice[T]): Slice[T] = Slice[T](a: x.a.bound(s), b: x.b.bound(s))

proc bound(a, b: Rect): Rect = rect(
  a.x.bound(b.x .. b.x+b.w),
  a.y.bound(b.y .. b.y+b.h),
  a.w.bound(0'f32 .. b.x+b.w-a.x),
  a.h.bound(0'f32 .. b.y+b.h-a.y),
)

proc indentation*(text: seq[seq[Rune]]): Indentation =
  proc indentation(line: seq[Rune], prev: seq[int]): tuple[len: seq[int], has_graph: bool] =
    var sl = block:
      var i = 0
      for c in line:
        if not c.isWhiteSpace:
          result.has_graph = true
          break
        inc i
      i
    if not result.has_graph:
      result.len = prev
    else:
      for l in prev:
        if sl < l: return
        sl -= l
        result.len.add l
      if sl > 0:
        result.len.add sl

  for i, line in text:
    result.add line.indentation(if i == 0: @[] else: result[^1].len)

  var lgl = 0
  for i in countdown(result.high, 0):
    if result[i].has_graph: lgl = result[i].len.len
    elif result[i].len.len > lgl: result[i].len = result[i].len[0..<lgl]


proc text_area(
  r: Context,
  box: Rect,
  gt: var GlyphTable,
  pos: float32,
  bg: ColorRgb,
  text: seq[seq[Rune]],
  colors: seq[seq[ColoredPos]],
  indentation: Indentation,
  ) =
  assert text.len == indentation.len

  let
    size = (box.h / gt.font.size).ceil.int
    space_w = static(" ".toRunes).width(gt)

  let dy = round(gt.font.size * 1.27)
  var y = box.y - dy * (pos mod 1)

  for i in (pos.int..pos.ceil.int+size).bound(text.low..text.high):
    r.image.draw text[i], colors[i], rect(vec2(box.x, y), vec2(box.x + box.w, y + box.h)), gt, bg

    var x = box.x.round.int
    for i, l in indentation[i].len:
      r.image.vertical_line x.int32, y.int32, dy.int32, colorTheme.verticaLline
      x += l * space_w

    y += dy


proc line_numbers(
  r: Context,
  box: Rect,
  gt: var GlyphTable,
  pos: float32,
  bg: ColorRgb,
  text: seq[seq[Rune]],
  ) =
  let
    size = (box.h / gt.font.size).ceil.int

  var y = round(box.y - gt.font.size * 1.27 * (pos mod 1))
  for i in (pos.int..pos.ceil.int+size).bound(text.low..text.high):
    let s = toRunes $(i+1)
    let w = float32 s.width(gt)
    r.image.draw s, @[(sLineNumber.color, 0)], rect(vec2(box.x + box.w - w, y), vec2(w, box.h - y)), gt, bg
    y += round(gt.font.size * 1.27)


proc scroll_bar(
  r: Context,
  box: Rect,
  pos: float32,
  size: int,
  total: int
  ) =
  if total == 0: return
  let
    a = pos / total.float32
    b = (pos + size.float32) / total.float32

  let box = rect(
    vec2(box.x, box.y + (box.h * a)),
    vec2(box.w, box.h * (b - a))
  )

  r.fillStyle = colorTheme.scrollbar
  r.fillRect box


proc cursor(
  r: Context,
  box: Rect,
  gt: var GlyphTable,
  pos: float32,
  cpos: IVec2,
  text: seq[seq[Rune]],
  ) =
  if text.len == 0: return
  
  let y = cpos.y.int.bound(0..text.high)
  let x = cpos.x.int.bound(0..text[y].high)
  
  r.fillStyle = colorTheme.sElse
  r.fillRect rect(
    box.xy + vec2(
      text[y][0..x].width(gt).float32 - 1,
      round(gt.font.size * 1.27) * (y.float32 - pos) + gt.font.size * 0.125
    ),
    vec2(2, gt.font.size)
  ).bound(box)



proc text_editor*(
  r: Context,
  box: Rect,
  gt: var GlyphTable,
  bg: ColorRgb,
  pos: float32,
  text: seq[seq[Rune]],
  colors: seq[seq[ColoredPos]],
  indentation: Indentation,
  ) =
  let
    size = (box.h / gt.font.size).ceil.int
    total = text.len

    line_number_width = float32 ($total).toRunes.width(gt)
  
  r.line_numbers(
    box = rect(vec2(10, 0), vec2(line_number_width, box.h)),
    gt = gt,
    pos = pos,
    bg = colorTheme.textarea,
    text = text,
  )

  r.text_area(
    box = rect(vec2(line_number_width + 30, 0), box.wh - vec2(10, 0)),
    gt = gt,
    pos = pos,
    bg = colorTheme.textarea,
    text = text,
    colors = colors,
    indentation = indentation,
  )

  r.cursor(
    box = rect(vec2(line_number_width + 30, 0), box.wh - vec2(10, 0)),
    gt = gt,
    pos = pos,
    cpos = ivec2(5, pos.round.int32 + 5),
    text = text,
  )

  r.scroll_bar(
    box = rect(vec2(box.w - 10, 0), vec2(10, box.h)),
    pos = pos,
    size = size,
    total = total + size - 1,
  )
