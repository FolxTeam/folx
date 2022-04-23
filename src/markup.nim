import macros, tables
import pixwindy, pixie, fusion/matching, fusion/astdsl
import render
export pixwindy, pixie, render

{.experimental: "caseStmtMacros".}

var
  boxStack*: seq[Rect]
  clipStack*: seq[Rect]

template frameImpl(fbox: Rect; clip: bool; body) =
  bind boxStack
  bind clipStack
  bind bound
  block:
    assert boxStack.len == clipStack.len

    var box {.inject.}: Rect
    if boxStack.len == 0:
      box = fbox
      boxStack.add box
      clipStack.add box
    else:
      box = fbox
      box.xy = box.xy + boxStack[^1].xy
      box = box.bound(clipStack[^1])
      boxStack.add box
      if clip: clipStack.add box
      else: clipStack.add clipStack[^1]

    block:
      body

    boxStack.del boxStack.high
    clipStack.del clipStack.high

template parentBox*: Rect =
  bind boxStack
  boxStack[^1]

macro frame*(args: varargs[untyped]) =
  runnableExamples:
    frame(center in parentBox, w=100, h=50, clip=true):
      frame(x=10, wh=vec2(10, 10)):
        frame(center=boxStack[^2].xy, wh=vec2(20, 20)):
          ## ...

  let body = args[^1]
  let a = block:
    var r: seq[(string, NimNode)]
    for it in args[0..^2]:
      case it
      of Infix[Ident(strVal: "in"), Ident(strVal: "center"), @b]:
        r.add ("centerIn", b)
      of ExprEqExpr[Ident(strVal: @s), @b]:
        r.add (s, b)
      else: error("unexpected syntax", it)
    r
  let d = a.toTable

  # checks
  if "wh" in d and ("w" in d or "h" in d): error("duplicated property", d["wh"][1])
  if "xy" in d and ("x" in d or "y" in d): error("duplicated property", d["xy"][1])
  if ("centerIn" in d) and ("xy" in d or "x" in d or "y" in d): error("duplicated property", d["xy"][1])

  buildAst: blockStmt empty(), stmtList do:
    if "wh" in d:
      letSection: identDefs:
        ident"wh"
        empty()
        call ident"vec2", d["wh"]
    else:
      letSection: identDefs:
        ident"wh"
        empty()
        call ident"vec2":
          call ident"float32":
            if "w" in d: d["w"]
            else:        dotExpr(call(bindSym"parentBox"), ident"w")
          call ident"float32": 
            if "h" in d: d["h"]
            else:        dotExpr(call(bindSym"parentBox"), ident"h")

    if "centerIn" in d:
      letSection: identDefs:
        ident"xy"
        empty()
        infix ident"+":
          dotExpr(call(bindSym"parentBox", ident"xy"))
          infix ident"-":
            infix ident"/", dotExpr(call(bindSym"parentBox"), ident"wh"), newLit 2
            infix ident"/", ident"wh", newLit 2

    else:
      if "xy" in d:
        letSection: identDefs:
          ident"xy"
          empty()
          call ident"vec2", d["xy"]
      else:
        letSection: identDefs:
          ident"xy"
          empty()
          call ident"vec2":
            call ident"float32": 
              if "x" in d: d["x"]
              else:        newLit 0
            call ident"float32": 
              if "y" in d: d["y"]
              else:        newLit 0

    call bindSym"frameImpl":
      call bindSym"rect", ident"xy", ident"wh"
      if "clip" in d: d["clip"]
      else:           newLit false
      body
