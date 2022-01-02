import pixie

type
  CodeSegmentKind* = enum
    sText

    sComment
    
    sKeyword
    sControlFlow
    sFunction
    sType
    sStringLit
    sNumerberLit

    sTodoComment

    sStringLitEscape
  
  CodeSegment* = tuple
    text: string
    kind: CodeSegmentKind

  ColoredText* = tuple
    text: string
    color: Color


proc color(sk: CodeSegmentKind): Color =
  case sk
  else: color(1, 1, 1, 1)


proc parseNimCode(code: string): seq[CodeSegment] =
  ## todo
