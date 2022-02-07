import json
import jsony, pixie

type
  Config* = object
    font*: string
    fontSize*: float32

    window*: WindowConfig

    file*: string

  WindowConfig* = object
    size*: IVec2

  ColorTheme* = object
    scrollbar*: ColorRGBA
    verticalline*: ColorRGB
    linenumbers*: ColorRGB
    textarea*: ColorRGB

    sKeyword*: ColorRGB
    sOperatorWord*: ColorRGB
    sBuiltinType*: ColorRGB
    sControlFlow*: ColorRGB
    sType*: ColorRGB
    sStringLit*: ColorRGB
    sStringLitEscape*: ColorRGB
    sNumberLit*: ColorRGB
    sFunction*: ColorRGB
    sComment*: ColorRGB
    sTodoComment*: ColorRGB
    sLineNumber*: ColorRGB
    sElse*: ColorRGB


proc parseHook*[T](s: string, i: var int, v: var GVec2[T]) =
  var a: array[2, T]
  parseHook(s, i, a)
  v.x = a[0]
  v.y = a[1]

proc dumpHook*[T](s: var string, v: GVec2[T]) =
  s.add [v.x, v.y].toJson


let colorTheme* = ColorTheme(
  scrollbar: rgba(48, 48, 48, 255),
  verticalline: rgb(64, 64, 64),
  linenumbers: rgb(32, 32, 32),
  textarea: rgb(32, 32, 32),

  sKeyword: rgb(86, 156, 214),
  sOperatorWord: rgb(86, 156, 214),
  sBuiltinType: rgb(86, 156, 214),
  sControlFlow: rgb(197, 134, 192),
  sType: rgb(78, 201, 176),
  sStringLit: rgb(206, 145, 120),
  sStringLitEscape: rgb(242, 225, 162),
  sNumberLit: rgb(181, 206, 168),
  sFunction: rgb(220, 220, 170),
  sComment: rgb(106, 153, 85),
  sTodoComment: rgb(255, 140, 0),
  sLineNumber: rgb(133, 133, 133),
  sElse: rgb(212, 212, 212),
)

const defaultConfig = Config(
  font: "resources/FiraCode-Regular.ttf",
  fontSize: 11'f32,
  
  window: WindowConfig(
    size: ivec2(1280, 720),
  ),

  file: "src/folx.nim",
)
static: writeFile "config.default.json", defaultConfig.toJson.parseJson.pretty


proc newHook*(x: var Config) =
  x = defaultConfig


proc readConfig*(file="config.json"): Config =
  try:    file.readFile.fromJson(Config)
  except: defaultConfig
