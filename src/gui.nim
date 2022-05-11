import render, siwin
export render, siwin

type
  KeyCombination* = object
    pressed*: set[Key]
    key*: Key

var
  cursor*: Cursor

proc check*(e: KeyEvent, kc: KeyCombination): bool =
  e.pressed and (kc.pressed - e.keyboard.pressed).len == 0 and e.key == kc.key

proc kc*(pressed: set[Key], key: Key): KeyCombination =
  KeyCombination(pressed: pressed, key: key)

proc contains*(r: Rect, v: tuple[x, y: int]): bool =
  v.x.float32 >= r.x and v.x.float32 <= r.x + r.w and
  v.y.float32 >= r.y and v.y.float32 <= r.y + r.h
