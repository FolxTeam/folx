import macros
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
  of sKeyword, sOperatorWord: rgb(84, 144, 185)
  of sControlFlow: rgb(160, 117, 176)
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

  keyword <- >keyword_str * &!(Alnum|'_'):
    d.add (kind: sKeyword, text: $1)

  controlFlow <- >controlFlow_str * &!(Alnum|'_'):
    d.add (kind: sControlFlow, text: $1)
  
  operatorWord <- >operatorWord_str * &!(Alnum|'_'):
    d.add (kind: sOperatorWord, text: $1)
  
  operator <- >+(Graph - (Alnum|'"'|'\'')):
    d.add (kind: sOperator, text: $1)

  something <- keyword|controlFlow|operatorWord|operator

  text <- >@&something:
    d.add (kind: sText, text: $1)

  segment <- something|text
  segments <- *segment

proc parseNimCode*(code: string): seq[CodeSegment] =
  doassert nimparser.match(code, result).ok
