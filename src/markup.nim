import macros, tables, unicode
import pixie, fusion/matching, fusion/astdsl
export pixie

{.experimental: "caseStmtMacros".}

proc ivec2*(v: (int, int)): IVec2 = ivec2(v[0].int32, v[1].int32)
proc vec2*(v: (int, int)): Vec2 = vec2(v[0].float32, v[1].float32)

var
  boxStack*: seq[Rect]
  clipStack*: seq[Rect]

template frameImpl(fbox: Rect; fclip: bool; body) =
  bind boxStack
  bind clipStack

  block:
    var box {.inject.}: Rect = fbox
    if boxStack.len == 0:
      boxStack.add box
    else:
      box.xy = box.xy + boxStack[^1].xy
      boxStack.add box
    
    if fclip:
      clipStack.add box

    block: body

    boxStack.del boxStack.high
    if fclip:
      clipStack.del clipStack.high

template parentBox*: Rect =
  bind boxStack
  boxStack[^1]


proc makeFrame(args: seq[NimNode]): NimNode =
  # todo: use anchors (like in qml)
  let body = args[^1]
  let
    whs = gensym(nskLet, "wh")
    xys = gensym(nskLet, "xy")
    lms = gensym(nskLet, "lm")
    tms = gensym(nskLet, "tm")
  let a = block:
    var r: seq[(string, NimNode)]
    for it in args[0..^2]:
      case it
      of ExprEqExpr[Ident(strVal: @s), @b]:
        r.add (s, b)
      of Asgn[Ident(strVal: @s), @b]:
        r.add (s, b)
      else: error("unexpected syntax", it)
    r
  let d = a.toTable

  # checks
  if "wh" in d and ("w" in d or "h" in d): error("duplicated property", d["wh"][1])
  if "xy" in d and ("x" in d or "y" in d): error("duplicated property", d["xy"][1])
  if ("centerIn" in d) and ("xy" in d or "x" in d or "y" in d): error("duplicated property", d["xy"][1])
  if ("left" in d or "right" in d) and ("xy" in d or "centerIn" in d or "x" in d or "w" in d or "wh" in d):
    error("can't use both margin and coordinate", (if "left" in d: d["left"] else: d["right"]))
  if ("top" in d or "bottom" in d) and ("xy" in d or "centerIn" in d or "y" in d or "h" in d or "wh" in d):
    error("can't use both margin and coordinate", (if "left" in d: d["left"] else: d["right"]))
  # todo: improve checks

  buildAst: blockStmt empty(), stmtList do:
    if "left" in d or "right" in d or "top" in d or "bottom" in d:
      letSection:
        if "left" in d:
          identDefs:
            lms
            empty()
            call ident"float32", d["left"]
        if "top" in d:
          identDefs:
            tms
            empty()
            call ident"float32", d["top"]
        identDefs:
          whs
          empty()
          call ident"vec2":
            if "left" in d and "right" in d:
              infix ident"-":
                dotExpr(call(bindSym"parentBox"), ident"w")
                infix ident"+":
                  lms
                  call ident"float32", d["right"]
            elif "left" in d:
              infix ident"-":
                dotExpr(call(bindSym"parentBox"), ident"w")
                lms
            elif "right" in d:
              infix ident"-":
                dotExpr(call(bindSym"parentBox"), ident"w")
                call ident"float32", d["right"]
            elif "w" in d:
              d["w"]
            else:
              dotExpr(call(bindSym"parentBox"), ident"w")

            if "top" in d and "bottom" in d:
              infix ident"-":
                dotExpr(call(bindSym"parentBox"), ident"h")
                infix ident"+":
                  tms
                  call ident"float32", d["bottom"]
            elif "top" in d:
              infix ident"-":
                dotExpr(call(bindSym"parentBox"), ident"h")
                tms
            elif "bottom" in d:
              infix ident"-":
                dotExpr(call(bindSym"parentBox"), ident"h")
                call ident"float32", d["bottom"]
            elif "h" in d:
              d["h"]
            else:
              dotExpr(call(bindSym"parentBox"), ident"h")

    elif "wh" in d:
      letSection: identDefs:
        whs
        empty()
        call ident"vec2", d["wh"]
    else:
      letSection: identDefs:
        whs
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
        xys
        empty()
        infix ident"/":
          infix ident"-":
            dotExpr(d["centerIn"], ident"wh")
            whs
          newLit 2

    else:
      if "horisontalCenterIn" in d:
        letSection: identDefs:
          xys
          empty()
          call ident"vec2":
            infix ident"/":
              infix ident"-":
                dotExpr(d["horisontalCenterIn"], ident"w")
                dotExpr whs, ident"x"
              newLit 2
            call ident"float32":
              if "y" in d:   d["y"]
              elif "top" in d: tms
              else:          newLit 0

      elif "verticalCenterIn" in d:
        letSection: identDefs:
          xys
          empty()
          call ident"vec2":
            call ident"float32":
              if "x" in d:    d["x"]
              elif "left" in d: lms
              else:           newLit 0
            infix ident"/":
              infix ident"-":
                dotExpr(d["verticalCenterIn"], ident"h")
                dotExpr whs, ident"y"
              newLit 2

      elif "xy" in d:
        letSection: identDefs:
          xys
          empty()
          call ident"vec2", d["xy"]

      else:
        letSection: identDefs:
          xys
          empty()
          call ident"vec2":
            call ident"float32":
              if "x" in d:    d["x"]
              elif "left" in d: lms
              else:           newLit 0
            call ident"float32":
              if "y" in d:   d["y"]
              elif "top" in d: tms
              else:          newLit 0

    call bindSym"frameImpl":
      call bindSym"rect", xys, whs
      if "clip" in d: d["clip"]
      else:           newLit false
      body


macro frame*(args: varargs[untyped]) =
  runnableExamples:
    frame(center in parentBox, w=100, h=50, clip=true):
      frame(x=10, wh=vec2(10, 10)):
        frame(center=boxStack[^2].xy, wh=vec2(20, 20)):
          ## ...

  makeFrame(args[0..^1])


macro component*(name, body: untyped) =
  var noexport: bool
  var name = case name
  of PragmaExpr[Ident(strVal: @ni), Pragma[Ident(strVal: "noexport")]]:
    noexport = true
    ni
  of Ident(strVal: @ni): ni
  else:
    error("unexpected syntax", name)

  proc isTypename(x: NimNode): bool =
    x.kind == nnkIdent and x.strVal.runeAt(0).isUpper

  proc impl(x: NimNode): NimNode =
    proc handleComponent(name: string, args: seq[NimNode], firstArg: NimNode): NimNode =
      var body1: seq[NimNode]
      var body2: seq[NimNode]
      var d: Table[string, NimNode]
      var fd: seq[NimNode]
      var lasteq: int
      for i, a in args:
        if a.kind in {nnkExprEqExpr, nnkAsgn} and a[0].kind == nnkIdent:
          lasteq = i
      for i, a in args:
        if a.kind in {nnkExprEqExpr, nnkAsgn} and a[0].kind == nnkIdent:
          let s = a[0].strVal
          case s
          of "w", "h", "wh", "x", "y", "xy", "clip", "left", "right", "top", "bottom", "centerIn", "verticalCenterIn", "horisontalCenterIn":
            fd.add a
          else:
            if s in d: error("duplicated property", a[0])
            d[s] = a[1]

        else:
          if i > lasteq:
            body2.add a
          else:
            body1.add a

      buildAst blockStmt:
        empty()
        stmtList:
          for x in body1: impl(x)

          let b = buildAst stmtList:
            call:
              ident "handle" & name
              if firstArg != nil: firstArg
              for k, v in d:
                exprEqExpr:
                  ident k
                  v
            for x in body2: impl(x)

          if fd.len != 0:
            for x in fd.mitems:
              if x[1] == ident"auto":
                x = buildAst exprEqExpr:
                  x[0]
                  call:
                    ident "getAuto" & name & $x[0]
                    if firstArg != nil: firstArg
                    for k, v in d:
                      exprEqExpr:
                        ident k
                        v
            makeFrame(fd & b)
          else: b

    case x
    # T: d=e and T(b=c): d=e
    of Call[Ident(isTypename: true, strVal: @name), @arg, all @args]:
      if args.len == 0 and arg.kind == nnkStmtList:
        handleComponent name, arg[0..^1], nil
      elif args.len != 0 and args[^1].kind == nnkStmtList:
        handleComponent name, arg & args[0..^2] & args[^1][0..^1], nil
      else:
        x

    # T a(b=c)
    of Command[Ident(isTypename: true, strVal: @name), Call[@arg, all @args]]:
      handleComponent name, args, arg

    # T a(b=c): d=e
    of Command[Ident(isTypename: true, strVal: @name), Call[@arg, all @args], @args2 is StmtList()]:
      handleComponent name, args & args2[0..^1], arg

    # T a: d=e
    of Command[Ident(isTypename: true, strVal: @name), @arg, @args is StmtList()]:
      handleComponent name, args[0..^1], arg


    elif x.len > 0:
      var y = x
      for i in 0..<y.len: y[i] = impl(y[i])
      y

    else: x


  buildAst stmtList:
    var body = body[0..^1]
    var props: seq[NimNode]
    if body.len != 0 and body[0].kind == nnkProcDef and body[0][0] == ident"handle":
      props = body[0].params[1..^1]
      body = body[1..^1]

    var b: seq[NimNode]
    for x in body:
      case x
      # auto a: v
      of Command[Ident(strVal: "auto"), Ident(strVal: @prop), @e]:
        procDef:
          # todo: copy line info
          if noexport:
            ident "getAuto" & name & prop
          else: postfix:
            ident"*"
            ident "getAuto" & name & prop
          empty()
          empty()
          formalParams:
            bindsym"auto"
            for x in props: x
          empty()
          empty()
          stmtList:
            for x in b: x
            e
        
      else:
        b.add impl(x)

    procDef:
      if noexport:
        ident "handle" & name
      else: postfix:
        ident"*"
        ident "handle" & name
      empty()
      empty()
      formalParams:
        empty()
        for x in props: x
      empty()
      empty()
      stmtList:
        for x in b: x
