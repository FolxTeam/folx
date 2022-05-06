import render, siwin
export render, siwin

type
  KeyCombination* = object
    pressed*: set[Key]
    key*: Key

proc check*(e: KeyEvent, kc: KeyCombination): bool =
  e.pressed and (kc.pressed - e.keyboard.pressed).len == 0 and e.key == kc.key

proc kc*(pressed: set[Key], key: Key): KeyCombination =
  KeyCombination(pressed: pressed, key: key)
