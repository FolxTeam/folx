import json, os
import jsony, pixie

type
  Config* = object
    colorTheme*: string

    font*: string
    fontSize*: float32

    interfaceFont*: string
    interfaceFontSize*: float32

    window*: WindowConfig

    file*: string
    workspace*: string

  WindowConfig* = object
    size*: IVec2

  ColorTheme* = object
    cActive*: ColorRGB
    cInActive*: ColorRGB
  
    bgScrollBar*: ColorRGB
    bgVerticalLine*: ColorRGB
    bgLineNumbers*: ColorRGB
    bgLineNumbersSelect*: ColorRGB
    bgTextArea*: ColorRGB
    bgStatusBar*: ColorRGB
    bgExplorer*: ColorRGB
    bgSelectionLabel*: ColorRGB
    bgSelection*: ColorRGB

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
    sError*: ColorRGB
    
    sLineNumber*: ColorRGB
    
    sText*: ColorRGB


proc parseHook*[T](s: string, i: var int, v: var GVec2[T]) =
  try:
    var a: array[2, T]
    parseHook(s, i, a)
    v.x = a[0]
    v.y = a[1]
  except: discard

proc dumpHook*[T](s: var string, v: GVec2[T]) =
  s.add [v.x, v.y].toJson


proc parseHook*(s: string, i: var int, v: var ColorRGB) =
  try:
    var str: string
    parseHook(s, i, str)
    v = parseHex(str).rgb
  except: discard

proc dumpHook*(s: var string, v: ColorRGB) =
  s.add v.color.toHex.toJson


const defaultConfig = Config(
  colorTheme: "themes/dark.json",

  font: "FiraCode-Regular.ttf",
  fontSize: 11'f32,

  interfaceFont: "Roboto-Regular.ttf",
  interfaceFontSize: 13'f32,
  
  window: WindowConfig(
    size: ivec2(1280, 720),
  ),

  file: "",
  workspace: getHomeDir()
)
static: writeFile "config.default.json", defaultConfig.toJson.parseJson.pretty


const defaultColorTheme = ColorTheme(

  cActive: rgb(221, 221, 221),
  cInActive: rgb(170, 170, 170),

  bgScrollBar: rgb(48, 48, 48),
  bgVerticalLine: rgb(64, 64, 64),
  bgLineNumbers: rgb(32, 32, 32),
  bgLineNumbersSelect: rgb(15, 15, 15),
  bgTextArea: rgb(32, 32, 32),
  bgStatusBar: rgb(0, 122, 204),
  bgExplorer: rgb(38, 38, 38),
  bgSelectionLabel: rgb(56, 175, 255),
  bgSelection: rgb(48, 48, 48),

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
  sError: rgb(255, 64, 64),
  sText: rgb(212, 212, 212),
)
static: writeFile "resources/themes/default.json", defaultColorTheme.toJson.parseJson.pretty


proc newHook*(x: var Config) =
  x = defaultConfig

proc newHook*(x: var ColorTheme) =
  x = defaultColorTheme


let configDir* =
  when defined(linux): getHomeDir()/".config"/"folx"
  elif defined(windows): getHomeDir()/"AppData"/"Roaming"/"folx"
  else: "."

let dataDir* =
  when defined(linux): getHomeDir()/".local"/"share"/"folx"
  elif defined(windows): getHomeDir()/"AppData"/"Roaming"/"folx"
  else: "."

createDir configDir
createDir dataDir


proc rc*(file: string): string =
  ## get resouce path
  if file.isAbsolute and (file.fileExists or file.dirExists):
    file
  else:
    dataDir/"resources"/file


proc readConfig*(file = configDir/"config.json"): Config =
  try:    file.readFile.fromJson(Config)
  except: defaultConfig

proc readTheme*(file: string): ColorTheme =
  try:    file.readFile.fromJson(ColorTheme)
  except: defaultColorTheme


let config* = readConfig()
let colorTheme* = readTheme(rc config.colorTheme)


proc writeConfig*(file = configDir/"config.json") =
  createDir file.splitPath.head
  writeFile file, config.toJson.parseJson.pretty

writeConfig()
