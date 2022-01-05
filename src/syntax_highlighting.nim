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
    text: string

  ColoredText* = tuple
    color: ColorRgb
    text: string


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

func lines*(scs: seq[CodeSegment]): seq[seq[CodeSegment]] =
  result = @[newSeq[CodeSegment]()]
  for x in scs:
    let s = x.text.split("\n")
    result[^1].add (kind: x.kind, text: s[0])
    if s.len > 1:
      result.add s[1..^1].mapit(@[(kind: x.kind, text: it)])

func color*(scs: seq[CodeSegment]): seq[ColoredText] =
  scs.mapit((color: it.kind.color, text: it.text))

proc parseNimCode*(code: string): seq[CodeSegment] =
  const parser = peg("segments", d: seq[CodeSegment]):
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
      d.add (kind: kind, text: $1)
    
    operator       <- >+(Graph - (Alnum|'"'|'\''|'`')):
      d.add (kind: sOperator, text: $1)
    
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
    
    something <- string|number|todoComment|comment|ttype|functionCall|word|operator

    text <- >1:
      d.add (kind: sText, text: $1)

    segment  <- something|text
    segments <- *segment
    
  doassert parser.match(code, result).ok
