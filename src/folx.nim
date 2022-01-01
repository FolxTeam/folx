import strutils, sugar
import opengl, windy, boxy, pixie

proc `{}`[T](x: seq[T], s: Slice[int]): seq[T] =
  ## safe slice a seq
  if x.len == 0: return
  let s = Slice[int](a: s.a.max(x.low).min(x.high), b: s.b.max(x.low).min(x.high))
  x[s]

proc `$@`(i: SomeInteger): string =
  cast[string](cast[ptr array[i.typeof.sizeof, byte]](i.unsafeaddr)[].`@`)


proc render(text: string, font: Font): Image =
  let ts = font.typeset(text)
  let bounds = ts.computeBounds
  if bounds.x < 1 or bounds.y < 1: return newImage(1, font.size.ceil.int)
  result = newImage(bounds.x.ceil.int, bounds.y.ceil.int)
  result.fillText(ts)


let window = newWindow("folx", ivec2(1280, 900))


makeContextCurrent window
loadExtensions()

let r = newBoxy()


let font = readFont"resources/FiraCode-Regular.ttf"
font.size = 11
font.paint.color = color(1, 1, 1, 1)

let text = "src/folx.nim".readFile.split("\n")
var textr: seq[Image]

for i, s in text:
  textr.add s.render(font)
  r.addImage "line" & $@i, textr[^1]


proc text_area(r: Boxy, box: Rect, pos: float32, size: int) =
  var box = box
  var y = box.y + 1 - font.size * (pos mod 1)
  for i, img in textr{pos.int..pos.ceil.int+size}:
    let i = i + pos.int
    r.drawImage "line" & $@i, rect(vec2(box.x, y), vec2(img.width.float32, img.height.float32))
    y += img.height.float32


proc scrollbar(r: Boxy, box: Rect, pos: float32, size: int, total: int) =
  if total == 0: return
  let
    a = pos / total.float32
    b = (pos + size.float32) / total.float32
  
  var box = box
  box.xy = vec2(box.x, box.y + (box.h * a))
  box.wh = vec2(box.w, box.h * (b - a))

  r.drawRect box, color(0.2, 0.2, 0.2, 1)


var
  pos = 0
  visual_pos = pos.float32

window.onCloseRequest = proc =
  close window
  quit(0)

window.onScroll = proc =
  if window.scrollDelta.y == 0: return
  pos = (pos - window.scrollDelta.y.ceil.int * 3).max(0).min(text.high)

proc display =
  let
    size = (window.size.y.float32 / font.size).ceil.int
    total = text.len
  
  if abs(visual_pos - pos.float32) < 0.01:
    visual_pos = pos.float32
  else:
    visual_pos += (pos.float32 - visual_pos) / 3

  r.beginFrame window.size
  r.drawRect rect(vec2(0, 0), window.size.vec2), color(0.13, 0.13, 0.13, 1)

  r.text_area(
    box = rect(vec2(), window.size.vec2 - vec2(10, 0)),
    pos = visual_pos,
    size = size,
  )
  r.scrollbar(
    box = rect(vec2(window.size.vec2.x - 10, 0), vec2(10, window.size.vec2.y)),
    pos = visual_pos,
    size = size,
    total = total + size - 1,
  )

  r.endFrame
  swapBuffers window


while not window.closeRequested:
  display()
  pollEvents()
