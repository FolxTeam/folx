import unicode, sequtils

type
  SeqView*[T] = object
    ## sequence slice (view)
    data*: ptr UncheckedArray[T]
    len*: int
  
  Text* = object
    ## multiline text for processing and displaying
    ## todo: make data structure more efficient for text editing
    runes: seq[Rune]
    lines*: seq[tuple[first, last: int]]


proc bound*[T](x: T, s: HSlice[T, T]): T = x.max(s.a).min(s.b)
proc bound*[T](x, s: HSlice[T, T]): HSlice[T, T] = HSlice[T, T](a: x.a.bound(s), b: x.b.bound(s))


proc slice*[T](x: seq[T]; first, last: int): SeqView[T] =
  ## get slice view to seq
  ## note: seq lifetime must be >= slice lifetime
  SeqView[T](
    data: cast[ptr UncheckedArray[T]](x[first].unsafeaddr),
    len: last - first + 1
  )

template toOpenArray*[T](x: SeqView[T]): openarray[T] = toOpenArray(x.data, 0, x.len - 1)

proc high*(x: SeqView): int = x.len - 1


proc lines(s: seq[Rune]): seq[tuple[first, last: int]] =
  template rune(x): Rune = static(x.runeAt(0))
  var b = 0
  var p = 0
  while p < s.high:
    if s[p] == "\n".rune:
      result.add (b, p - 1)
      inc p
      b = p
    elif s[p] == "\r".rune and p + 1 < s.high and s[p + 1] == "\n".rune:
      result.add (b, p - 1)
      inc p, 2
      b = p
    else:
      inc p


proc newText*(runes: sink seq[Rune]): Text =
  result.runes = move runes
  result.lines = result.runes.lines

proc newText*(s: string): Text =
  newText(s.toRunes)


proc `[]`*(text: Text, i: int): Rune =
  ## get char by index
  text.runes[i]

proc `[]`*(text: Text; col, line: int): Rune =
  ## get char by line and column
  assert col in 0 .. text.lines[line].last - text.lines[line].first
  text.runes[text.lines[line].first + col]

proc `{}`*(text: Text, line: int): SeqView[Rune] =
  ## get line slice
  text.runes.slice(text.lines[line].first, text.lines[line].last)


proc `[]`*[A, B](text: Text, slice: HSlice[A, B]): SeqView[Rune] =
  ## slice by indices
  text.runes.slice(slice.a.int, slice.b.int)


proc len*(text: Text): int = text.runes.len
proc high*(text: Text): int = text.runes.high


proc insert*(text: var Text; v: openarray[Rune]; col, line: int) =
  if text.lines.len == 0 or v.len == 0: return

  let
    line = line.bound(0..text.lines.high)
    col = col.bound(0..text{line}.len)
  
  text.runes.insert v, text.lines[line].first + col

  text.lines[line].last += v.len
  for i in line+1 .. text.lines.high:
    text.lines[i].first += v.len
    text.lines[i].last += v.len


proc erase*(text: var Text; col, line: int) =
  if text.lines.len == 0: return

  let
    line = line.bound(0..text.lines.high)
    col = col.bound(0..text{line}.high)
  
  text.runes.delete text.lines[line].first + col

  text.lines[line].last -= 1
  for i in line+1 .. text.lines.high:
    text.lines[i].first -= 1
    text.lines[i].last -= 1
