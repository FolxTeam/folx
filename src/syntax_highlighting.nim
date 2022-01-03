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
    sBuiltinType
    sStringLit
    sNumberLit

    sStringLitEscape

    sTodoComment
  
  CodeSegment* = tuple
    kind: CodeSegmentKind
    text: string

  ColoredText* = tuple
    text: string
    color: Color


proc color*(sk: CodeSegmentKind): ColorRGB =
  case sk
  of sKeyword, sOperatorWord, sBuiltinType: rgb(86, 156, 214)
  of sControlFlow: rgb(197, 134, 192)
  of sType: rgb(78, 201, 176)
  of sStringLit: rgb(206, 145, 120)
  of sNumberLit: rgb(181, 206, 168)
  of sFunction: rgb(220, 220, 170)
  of sComment: rgb(106, 153, 85)
  of sTodoComment: rgb(255, 140, 0)
  else: rgb(212, 212, 212)


let nimparser = peg("segments", d: seq[CodeSegment]):
  ident <- Alpha * *(Alnum|'_')
  
  functionDeclKeyword <- "func"|"proc"|"template"|"iterator"|"converter"|"macro"|"method"
  keyword_str <- (
    functionDeclKeyword|
    "addr"|"asm"|"bind"|"concept"|"const"|"discard"|"distinct"|"enum"|"export"|"from"|
    "import"|"include"|"interface"|"let"|"mixin"|"nil"|"object"|"of"|"out"|"ptr"|
    "ref"|"static"|"tuple"|"type"|"using"|"var"|"true"|"false"|"off"|"on"|"low"|"high"|"lent"
  )
  controlFlow_str <- (
    "block"|"break"|"case"|"continue"|"defer"|"do"|"elif"|"else"|"end"|"except"|"finally"|"for"|"if"|"raise"|"return"|
    "try"|"when"|"while"|"yield"
  )
  operatorWord_str <- (
    "and"|"as"|"cast"|"div"|"in"|"isnot"|"is"|"mod"|"notin"|"not"|"or"|"shl"|"shr"|"xor"
  )
  builtinType_str <- (
    "int8"|"int16"|"int32"|"int64"|"uint8"|"uint16"|"uint32"|"uint64"|"float32"|"float64"|
    "int"|"float"|"string"|"bool"|"byte"|"uint"|"seq"|"set"
  )

  word <- >ident:
    d.add (kind: sText, text: $1)

  keyword        <- >keyword_str * &!(Alnum|'_'):
    d.add (kind: sKeyword, text: $1)

  controlFlow    <- >controlFlow_str * &!(Alnum|'_'):
    d.add (kind: sControlFlow, text: $1)
  
  operatorWord   <- >operatorWord_str * &!(Alnum|'_'):
    d.add (kind: sOperatorWord, text: $1)
  
  operator       <- >+(Graph - (Alnum|'"'|'\''|'`')):
    d.add (kind: sOperator, text: $1)
  
  builtinType    <- >builtinType_str * &!(Alnum|'_'):
    d.add (kind: sBuiltinType, text: $1)
  
  ttype          <- >(Upper * *(Alnum|'_')):
    d.add (kind: sType, text: $1)
  
  todoComment    <- >(+'#' * *Space * (i"todo" | i"to do") * &!(Alnum|'_') * *(1 - '\n')):
    d.add (kind: sTodoComment, text: $1)

  comment        <- >('#' * *(1 - '\n')):
    d.add (kind: sComment, text: $1)
  
  hexNumber     <- Xdigit * *(Xdigit|'_') * ?('.' * Xdigit * *(Xdigit|'_')) * ?('\'' * ident)
  classicNumber <- Digit * *(Digit|'_') * ?('.' * Digit * *(Digit|'_')) * ?('\'' * ident)
  number        <- >(("0x" * hexNumber) | classicNumber): # todo: bin and oct number
    d.add (kind: sNumberLit, text: $1)
  
  unicodeEscape <- 'u' * Xdigit[4]
  escape        <- '\\' * ({ '{', '"', '|', '\\', 'b', 'f', 'n', 'r', 't' } | unicodeEscape)
  stringBody    <- ?escape * *( +( {'\x20'..'\xff'} - {'"'} - {'\\'}) * *escape)
  string        <- >('"' * stringBody * '"'):
    d.add (kind: sStringLit, text: $1)
  
  functionCall <- >ident * &'(':
    d.add (kind: sFunction, text: $1)
  
  something <- string|number|todoComment|comment|keyword|controlFlow|operatorWord|builtinType|ttype|functionCall|word|operator

  text <- >1:
    d.add (kind: sText, text: $1)

  segment  <- something|text
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
