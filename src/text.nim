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
    data:
      if x.len == 0: nil
      else: cast[ptr UncheckedArray[T]](cast[int](x[0].unsafeaddr) + first * T.sizeof),
    len: last - first + 1
  )

proc slice*[T](x: seq[T]; first: int, last: BackwardsIndex): SeqView[T] =
  x.slice(first, x.len - last.int)

template toOpenArray*[T](x: SeqView[T]): openarray[T] = toOpenArray(x.data, 0, x.len - 1)

proc `[]`[T, A, B](x: seq[T], slice: HSlice[A, B]): SeqView[T] = x.slice(slice.a, slice.b)

proc high*(x: SeqView): int = x.len - 1

iterator items*[T](x: SeqView[T]): T =
  for i in 0..<x.len: yield x.data[i]

iterator mitems*[T](x: SeqView[T]): var T =
  for i in 0..<x.len: yield x.data[i]


proc lines(s: seq[Rune]): seq[tuple[first, last: int]] =
  template rune(x): Rune = static(x.runeAt(0))
  var b = 0
  var p = 0
  while p < s.len:
    if s[p] == "\n".rune:
      result.add (b, p - 1)
      inc p
      b = p
    elif s[p] == "\r".rune and p + 1 < s.len and s[p + 1] == "\n".rune:
      result.add (b, p - 1)
      inc p, 2
      b = p
    else:
      inc p
  result.add (b, p - 1)

proc `+=`(line: var tuple[first, last: int], v: int) =
  line.first += v
  line.last += v

proc `-=`(line: var tuple[first, last: int], v: int) =
  line.first -= v
  line.last -= v


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

proc `{}`*(text: Text, line: BackwardsIndex): SeqView[Rune] = text{text.lines.len - line.int}


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
    text.lines[i] += v.len


proc insert*(text: var Text, v: Text; col, line: int) =
  if v.lines.len == 0:
    text.insert(v.runes, col, line)
    return
  
  let
    line = line.bound(0..text.lines.high)
    col = col.bound(0..text{line}.len)
  
  text.runes.insert v.runes, text.lines[line].first + col
  
  let selfLen = text.lines[line].first
  let insertedLen = v.runes.len

  var v = v
  v.insert text{line}.toOpenArray[0..<col], 0, 0
  v.insert text{line}.toOpenArray[col..^1], v{^1}.len, v.lines.high
  for l in v.lines.mitems:
    l += selfLen

  text.lines[line].last += v{0}.len
  for l in text.lines[line + 1 .. ^1].mitems:
    l += insertedLen

  text.lines[line..line] = v.lines


proc erase*(text: var Text; col, line: int) =
  if text.lines.len == 0: return

  let
    line = line.bound(0..text.lines.high)
    col = col.bound(0..text{line}.high)
  
  text.runes.delete text.lines[line].first + col

  text.lines[line].last -= 1
  for i in line+1 .. text.lines.high:
    text.lines[i] -= 1


proc joinLine*(text: var Text; line: int) =
  if line notin 0 .. text.lines.high-1: return
  
  text.runes.delete text.lines[line].last + 1
  text.lines[line].last += text{line+1}.len
  text.lines.delete line+1
  for i in line+1 .. text.lines.high:
    text.lines[i] -= 1


proc `$`*(text: Text): string =
  $text.runes
