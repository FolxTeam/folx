import strutils, sequtils, unicode
import pixie, npeg, npeg/lib/utf8
import configuration

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
    sCharLit
    sNumberLit

    sStringLitEscape
    sCharLitEscape

    sTodoComment

    sLineNumber
  
  CodeSegment* = tuple
    kind: CodeSegmentKind
    startPos: int

  ColoredPos* = tuple
    color: ColorRgb
    startPos: int


proc color*(sk: CodeSegmentKind): ColorRGB =
  case sk
  of sKeyword, sOperatorWord, sBuiltinType:
    colorTheme.sKeyword

  of sControlFlow:
    colorTheme.sControlFlow
  
  of sType:
    colorTheme.sType
  
  of sStringLit, sCharLit:
    colorTheme.sStringLit
  
  of sStringLitEscape, sCharLitEscape:
    colorTheme.sStringLitEscape
  
  of sNumberLit:
    colorTheme.sNumberLit
  
  of sFunction:
    colorTheme.sFunction
  
  of sComment:
    colorTheme.sComment
  
  of sTodoComment:
    colorTheme.sTodoComment
  
  of sLineNumber:
    colorTheme.sLineNumber
  
  else: colorTheme.sElse

proc color*(scs: seq[CodeSegment]): seq[ColoredPos] =
  scs.mapit((color: it.kind.color, startPos: it.startPos))

proc parseNimCode*(code: string): seq[seq[CodeSegment]] =
  var i = 0

  proc add(d: var seq[CodeSegment], k: CodeSegmentKind) =
    if d.len == 0 or d[^1].kind != k:
      system.add d, (k, i)

  template add(k: CodeSegmentKind) =
    d[^1].add k

  let parser = peg("segments", d: seq[seq[CodeSegment]]):
    ident <- utf8.alpha * *(utf8.alpha|Digit|'_')

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
        "int", "float", "string", "bool", "byte", "uint", "seq", "set", "char", "void", "auto", "any":
        sBuiltinType
      else: sText
      add kind
      inc i, len s
    
    operator       <- >+(Graph - (Alnum|'"'|'\''|'`')):
      add sOperator
      inc i, len $1
    
    ttype          <- >(utf8.upper * *(utf8.alpha|Digit|'_')):
      add sType
      inc i, len $1
    
    todoComment    <- >(+'#' * *Space * (i"todo" | i"to do") * &!(Alnum|'_') * *(1 - '\n')):
      add sTodoComment
      inc i, len $1

    comment        <- >('#' * *(1 - '\n')):
      add sComment
      inc i, len $1
    
    bdigit        <- {'0'..'1'}
    odigit        <- {'0'..'7'}
    binNumber     <- bdigit * *(bdigit|'_') * ?('.' * bdigit * *(bdigit|'_')) * ?('\'' * ident)
    octNumber     <- odigit * *(odigit|'_') * ?('.' * odigit * *(odigit|'_')) * ?('\'' * ident)
    hexNumber     <- Xdigit * *(Xdigit|'_') * ?('.' * Xdigit * *(Xdigit|'_')) * ?('\'' * ident)
    classicNumber <- Digit * *(Digit|'_') * ?('.' * Digit * *(Digit|'_')) * ?('\'' * ident)
    number        <- >(("0b" * binNumber) | ("0o" * octNumber) | ("0x" * hexNumber) | classicNumber):
      d[^1].add (kind: sNumberLit, startPos: i)
      inc i, len $1
    
    unicodeEscape <- 'u' * Xdigit[4]
    xEscape       <- 'x' * Xdigit[2]
    escape        <- '\\' * ({ '{', '"', '\'', '|', '\\', 'b', 'f', 'n', 'r', 't' } | unicodeEscape | xEscape)

    stringEscape  <- >escape:
      add sStringLitEscape
      inc i, len $1
    stringChar    <- >(utf8.any - '"' - '\\' - {0..31}):
      add sStringLit
      inc i, len $1
    stringStart   <- '"':
      add sStringLit
      inc i
    string        <- stringStart * *(stringEscape|stringChar) * '"':
      add sStringLit
      inc i
    
    charEscape  <- >escape:
      add sCharLitEscape
      inc i, len $1
    charChar    <- >(utf8.any - '\'' - '\\' - {0..31}):
      add sCharLit
      inc i, len $1
    charStart   <- '\'':
      add sCharLit
      inc i
    charLit     <- charStart * *(charEscape|charChar) * '\'':
      add sCharLit
      inc i
    
    functionCall <- >ident * &'(':
      add sFunction
      inc i, len $1
    
    something <- string|charLit|number|todoComment|comment|ttype|functionCall|word|operator

    text <- 1:
      add sText
      inc i
    
    newline <- ?'\r' * '\n':
      d.add @[]
      i = 0
    
    init <- 0:
      d.add @[]

    segment  <- newline|something|text
    segments <- init * *segment
    
  doassert parser.match(code, result).ok
