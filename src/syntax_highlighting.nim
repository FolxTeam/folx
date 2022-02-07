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

    sLineNumber
  
  CodeSegment* = tuple
    kind: CodeSegmentKind
    startPos: int

  ColoredPos* = tuple
    color: ColorRgb
    startPos: int


func color*(sk: CodeSegmentKind): ColorRGB =
  case sk
  of sKeyword, sOperatorWord, sBuiltinType: rgb(86, 156, 214)
  of sControlFlow: rgb(197, 134, 192)
  of sType: rgb(78, 201, 176)
  of sStringLit: rgb(206, 145, 120)
  of sNumberLit: rgb(181, 206, 168)
  of sFunction: rgb(220, 220, 170)
  of sComment: rgb(106, 153, 85)
  of sTodoComment: rgb(255, 140, 0)
  of sLineNumber: rgb(133, 133, 133)
  else: rgb(212, 212, 212)

func color*(scs: seq[CodeSegment]): seq[ColoredPos] =
  scs.mapit((color: it.kind.color, startPos: it.startPos))

proc parseNimCode*(code: string): seq[seq[CodeSegment]] =
  var i = 0
  let parser = peg("segments", d: seq[seq[CodeSegment]]):
    ident <- Alpha * *(Alnum|'_')

    word <- >ident:
      let s = $1
      let kind = case s
      of "func", "proc", "template", "iterator", "converter", "macro", "method", 
        "addr", "asm", "bind", "concept", "const", "discard", "distinct", "enum", "export", "from", 
        "import", "include", "interface", "let", "mixin", "nil", "object", "of", "out", "ptr", 
        "ref", "static", "tuple", "type", "using", "var", "true", "false", "off", "on", "low", "high", "lent":
        sKeyword
      of "block", "break", "case", "continue", "defer", "do", "elif", "else", "end", "except", 
        "finally", "for", "if", "raise", "return", "try", "when", "while", "yield":
        sControlFlow
      of "and", "as", "cast", "div", "in", "isnot", "is", "mod", "notin", "not", "or", "shl", "shr", "xor":
        sOperatorWord
      of "int8", "int16", "int32", "int64", "uint8", "uint16", "uint32", "uint64", "float32", "float64", 
        "int", "float", "string", "bool", "byte", "uint", "seq", "set":
        sBuiltinType
      else: sText
      d[^1].add (kind: kind, startPos: i)
      inc i, len s
    
    operator       <- >+(Graph - (Alnum|'"'|'\''|'`')):
      d[^1].add (kind: sOperator, startPos: i)
      inc i, len $1
    
    ttype          <- >(Upper * *(Alnum|'_')):
      d[^1].add (kind: sType, startPos: i)
      inc i, len $1
    
    todoComment    <- >(+'#' * *Space * (i"todo" | i"to do") * &!(Alnum|'_') * *(1 - '\n')):
      d[^1].add (kind: sTodoComment, startPos: i)

    comment        <- >('#' * *(1 - '\n')):
      d[^1].add (kind: sComment, startPos: i)
      inc i, len $1
    
    hexNumber     <- Xdigit * *(Xdigit|'_') * ?('.' * Xdigit * *(Xdigit|'_')) * ?('\'' * ident)
    classicNumber <- Digit * *(Digit|'_') * ?('.' * Digit * *(Digit|'_')) * ?('\'' * ident)
    number        <- >(("0x" * hexNumber) | classicNumber): # todo: bin and oct number
      d[^1].add (kind: sNumberLit, startPos: i)
      inc i, len $1
    
    unicodeEscape <- 'u' * Xdigit[4]
    escape        <- '\\' * ({ '{', '"', '|', '\\', 'b', 'f', 'n', 'r', 't' } | unicodeEscape)
    stringBody    <- ?escape * *( +( {'\x20'..'\xff'} - {'"'} - {'\\'}) * *escape)
    string        <- >('"' * stringBody * '"'):
      let s = $1
      d[^1].add (kind: sStringLit, startPos: i)
      inc i, len s
      # let (c, n) = block:
      #   var c, n: int
      #   for i, c2 in s:
      #     if c2 == '\n':
      #       inc c
      #       n = i
      #   (c, n)
      # if c != 0:
      #   d.add (kind: sStringLit, startPos: 0).repeat(c)
      #   inc i, s.high - n
    
    functionCall <- >ident * &'(':
      d[^1].add (kind: sFunction, startPos: i)
      inc i, len $1
    
    something <- string|number|todoComment|comment|ttype|functionCall|word|operator

    text <- 1:
      if d[^1].len == 0 or d[^1][^1].kind != sText:
        d[^1].add (kind: sText, startPos: i)
      inc i
    
    newline <- ?'\r' * '\n':
      d.add @[]
      i = 0
    
    init <- 0:
      d.add @[]

    segment  <- newline|something|text
    segments <- init * *segment
    
  doassert parser.match(code, result).ok
