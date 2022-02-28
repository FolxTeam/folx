import sequtils, unicode, streams
import pixie
import configuration

type
  CodeKind* = enum
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

  NimParseState* = object
    pos: int
    last: CodeKind
    inQuote, inComment: bool
    inMultiline: bool


proc color*(sk: CodeKind): ColorRGB =
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

proc colors*(scs: openarray[CodeKind]): seq[ColorRgb] =
  scs.map(color)



proc parseNimCode*(s: seq[Rune], state: NimParseState, len = 100): tuple[segments: seq[CodeKind], state: NimParseState] =
  result.state = state
  result.segments = newSeqOfCap[CodeKind](len)

  proc parseNext(s: seq[Rune], state: var NimParseState, res: var seq[CodeKind]) =
    template rune(s: string): Rune = static(s.runeAt(0))
    template runes(s: string): seq[Rune] = static(s.toRunes)
    
    template peek(i: int = 0): Rune =
      s[state.pos + i]
    
    template skip(n: int = 1) =
      inc state.pos, n
    
    template exist(n: int): bool =
      state.pos + n < s.len
    
    template add(kind: CodeKind, len: int = 1) =
      let i = len
      for _ in 1..i:
        res.add kind
      skip i
    
    template ident =
      var l = 1
      
      while true:
        if not exist(l): break
        let r = peek(l)
        if (not r.isAlpha) and (r notin "0123456789_".runes): break
        inc l

      let kind =
        if peek().isUpper:
          sType

        else:
          case $s[state.pos ..< state.pos + l]
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
        
          elif exist(l) and (peek(l) == "(".rune or peek(l) == "\"".rune):
            sFunction
        
          else: sText
      
      add kind, l
    
    template comment =
      var l = 1
      var isTodo: bool
      var wasAlpha: bool

      template checkTodo =
        if (not wasAlpha) and (not isTodo) and (
          (peek(l).toLower == rune"t") and
          (exist(l + 1) and peek(l + 1).toLower == rune"o") and
          (exist(l + 2) and peek(l + 2).toLower == rune"d") and
          (exist(l + 3) and peek(l + 3).toLower == rune"o") and
          (exist(l + 4) and (not peek(l + 4).isAlpha))
        ):
          isTodo = true
          inc l, 4
          continue

        elif (not wasAlpha) and (not isTodo) and (
          (peek(l).toLower == rune"t") and
          (exist(l + 1) and peek(l + 1).toLower == rune"o") and
          (exist(l + 2) and peek(l + 2).isWhiteSpace) and
          (exist(l + 3) and peek(l + 3).toLower == rune"d") and
          (exist(l + 4) and peek(l + 4).toLower == rune"o") and
          (exist(l + 5) and (not peek(l + 5).isAlpha))
        ):
          isTodo = true
          inc l, 5
          continue
      
      if exist(l) and peek(l) == rune"[":  # multiline comment
        while true:
          if not exist(l): break
          checkTodo
          if (
            (peek(l) == rune"]") and
            (exist(l + 1) and peek(l + 1) == rune"#")
          ): 
            inc l, 2
            break
          if (not wasAlpha) and (peek(l).isAlpha): wasAlpha = true
          inc l
      
      else:  # single line comment
        while true:
          if not exist(l): break
          checkTodo
          let r = peek(l)
          if r == "\n".rune: break
          if (not wasAlpha) and (r.isAlpha): wasAlpha = true
          inc l
      
      if isTodo: add sTodoComment, l
      else:      add sComment, l
    
    template number =
      var l = 1
      var wasDot: bool
      var wasQuote: bool
      var digits = "0123456789_".runes

      if (peek(0) == rune"0") and ((peek(l) == rune"x") or (peek(l) == rune"X")) and exist(l + 1) and (peek(l + 1) in "0123456789abcdefABCDEF_".runes):
        inc l
        digits = "0123456789abcdefABCDEF_".runes
      
      elif (peek(0) == rune"0") and ((peek(l) == rune"o") or (peek(l) == rune"O")) and exist(l + 1) and (peek(l + 1) in "01234567_".runes):
        inc l
        digits = "01234567_".runes
      
      elif (peek(0) == rune"0") and ((peek(l) == rune"b") or (peek(l) == rune"B")) and exist(l + 1) and (peek(l + 1) in "01_".runes):
        inc l
        digits = "01_".runes

      while true:
        if not exist(l): break
        let r = peek(l)
        if wasQuote:
          if (not r.isAlpha) and (r notin "0123456789_".runes):
            break
        else:
          if (not wasDot) and (r == rune"."):
            wasDot = true
          elif (not wasDot) and (r == rune"'") and exist(l + 1) and (peek(l + 1).isAlpha):
            wasQuote = true
          elif (r notin digits):
            break
        inc l
      
      add sNumberLit, l
      # todo: errors in numbers

    let r = peek()
    if r.isAlpha:                 ident
    elif r in "0123456789".runes: number
    elif r == rune"#":            comment
    else:
      add sText
    
    # todo: operators

  
  for _ in 1..len:
    if result.state.pos > s.high: return
    s.parseNext(result.state, result.segments)


#   let parser = peg("segments", d: seq[seq[CodeSegment]]):
#     unicodeEscape <- 'u' * Xdigit[4]
#     xEscape       <- 'x' * Xdigit[2]
#     escape        <- '\\' * ({ '{', '"', '\'', '|', '\\', 'b', 'f', 'n', 'r', 't' } | unicodeEscape | xEscape)

#     stringEscape  <- >escape:
#       add sStringLitEscape
#       inc i, len $1
#     stringChar    <- >(utf8.any - '"' - '\\' - {0..31}):
#       add sStringLit
#       inc i, len $1
#     stringStart   <- '"':
#       add sStringLit
#       inc i
#     string        <- stringStart * *(stringEscape|stringChar) * '"':
#       add sStringLit
#       inc i
    
#     charEscape  <- >escape:
#       add sCharLitEscape
#       inc i, len $1
#     charChar    <- >(utf8.any - '\'' - '\\' - {0..31}):
#       add sCharLit
#       inc i, len $1
#     charStart   <- '\'':
#       add sCharLit
#       inc i
#     charLit     <- charStart * *(charEscape|charChar) * '\'':
#       add sCharLit
#       inc i
