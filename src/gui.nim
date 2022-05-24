import render, siwin
export render, siwin

type
  KeyCombination* = object
    pressed*: set[Key]
    key*: Key

var
  cursor*: Cursor
  isLeftClick*: bool
  isLeftDown*: bool
  isLeftUp*: bool
  mousePos*: Vec2

proc check*(w: Window, e: KeyEvent, kc: KeyCombination): bool =
  e.pressed and (kc.pressed - w.keyboard.pressed).len == 0 and e.key == kc.key

proc kc*(pressed: set[Key], key: Key): KeyCombination =
  KeyCombination(pressed: pressed, key: key)

proc contains*(r: Rect, v: tuple[x, y: int]): bool =
  v.x.float32 >= r.x and v.x.float32 <= r.x + r.w and
  v.y.float32 >= r.y and v.y.float32 <= r.y + r.h

proc contains*(r: Rect, v: IVec2): bool =
  v.x.float32 >= r.x and v.x.float32 <= r.x + r.w and
  v.y.float32 >= r.y and v.y.float32 <= r.y + r.h

proc contains*(r: Rect, v: Vec2): bool =
  v.x >= r.x and v.x <= r.x + r.w and
  v.y >= r.y and v.y <= r.y + r.h

proc mouseHover*(box: Rect): bool =
  mousePos in box
