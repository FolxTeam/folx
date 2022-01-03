import strutils, sequtils
import pixie, npeg

type
  CodeSegmentKind* = enum
    sText

    sComment
    
    sKeyword
    sControlFlow
    sOperator
    sOperatorWord
    sFunction
    sType
    sStringLit
    sNumerberLit

    sTodoComment

    sStringLitEscape
  
  CodeSegment* = tuple
    kind: CodeSegmentKind
    text: string

  ColoredText* = tuple
    text: string
    color: Color


proc color*(sk: CodeSegmentKind): ColorRGB =
  case sk
  of sKeyword, sOperatorWord: rgb(86, 156, 214)
  of sControlFlow: rgb(197, 134, 192)
  else: rgb(255, 255, 255)


# todo: improve
let nimparser = peg("segments", d: seq[CodeSegment]):
  ident <- Alpha * *(Alnum|'_')
  
  keyword_str <- (
    "addr"|"asm"|"bind"|"concept"|"const"|"converter"|"discard"|"distinct"|"enum"|"export"|"from"|"func"|
    "import"|"include"|"interface"|"iterator"|"let"|"macro"|"method"|"mixin"|"nil"|"object"|"of"|"out"|"proc"|"ptr"|
    "ref"|"static"|"template"|"tuple"|"type"|"using"|"var"
  )
  controlFlow_str <- (
    "block"|"break"|"case"|"continue"|"defer"|"do"|"elif"|"else"|"end"|"except"|"finally"|"for"|"if"|"raise"|"return"|
    "try"|"when"|"while"|"yield"
  )
  operatorWord_str <- (
    "and"|"as"|"cast"|"div"|"in"|"is"|"isnot"|"mod"|"not"|"notin"|"or"|"shl"|"shr"|"xor"
  )

  word <- >ident:
    d.add (kind: sText, text: $1)

  keyword <- >keyword_str * &!(Alnum|'_'):
    d.add (kind: sKeyword, text: $1)

  controlFlow <- >controlFlow_str * &!(Alnum|'_'):
    d.add (kind: sControlFlow, text: $1)
  
  operatorWord <- >operatorWord_str * &!(Alnum|'_'):
    d.add (kind: sOperatorWord, text: $1)
  
  operator <- >+(Graph - (Alnum|'"'|'\'')):
    d.add (kind: sOperator, text: $1)

  something <- keyword|controlFlow|operatorWord|operator|word

  text <- >1:
    d.add (kind: sText, text: $1)

  segment <- something|text
  segments <- *segment

proc parseNimCode*(code: string): seq[CodeSegment] =
  doassert nimparser.match(code, result).ok

proc lines*(scs: seq[CodeSegment]): seq[seq[CodeSegment]] =
  ## todo
  result = @[newSeq[CodeSegment]()]
  for x in scs:
    let s = x.text.split("\n")
    result[^1].add (kind: x.kind, text: s[0])
    if s.len > 1:
      result.add s[1..^1].mapit(@[(kind: x.kind, text: it)])
