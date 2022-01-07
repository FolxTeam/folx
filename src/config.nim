import std/json
import pixie

type
  Config* = object
    file*: string
    font*: string
    fontSize*: float32
    height*: int
    width*: int

  WindowSize* = object
    width*: int
    height*: int

  ColorTheme* = object
    sKeyword*: ColorRGB
    sOperatorWord*: ColorRGB
    sBuiltinType*: ColorRGB
    sControlFlow*: ColorRGB
    sType*: ColorRGB
    sStringLit*: ColorRGB
    sNumberLit*: ColorRGB
    sFunction*: ColorRGB
    sComment*: ColorRGB
    sTodoComment*: ColorRGB
    sLineNumber*: ColorRGB
    sElse*: ColorRGB
    scrollbar: ColorRGBA
    verticalline: ColorRGB
    linenumbers: ColorRGB
    textarea: ColorRGB

proc getConfig*(): Config =
  
  try:
    let file = readFile"config.json"

    let json_config = parseJSON(file)

    return Config(
      file: json_config["file"].getStr(),
      font: json_config["font_file"].getStr(),
      fontSize: json_config["font_size"].getFloat(),
      height: json_config["height"].getInt(),
      width: json_config["width"].getInt(),
    )
  except:
    # if could not read the file or parse json
    return Config(
      file: "src/folx.nim",
      font: "resources/FiraCode-Regular.ttf",
      fontSize: 11,
      height: 900,
      width: 1280
    )

proc getColorTheme*(): ColorTheme = 
  return ColorTheme(
    sKeyword: rgb(86, 156, 214),
    sOperatorWord: rgb(86, 156, 214),
    sBuiltinType: rgb(86, 156, 214),
    sControlFlow: rgb(197, 134, 192),
    sType: rgb(78, 201, 176),
    sStringLit: rgb(206, 145, 120),
    sNumberLit: rgb(181, 206, 168),
    sFunction: rgb(220, 220, 170),
    sComment: rgb(106, 153, 85),
    sTodoComment: rgb(255, 140, 0),
    sLineNumber: rgb(133, 133, 133),
    sElse: rgb(212, 212, 212),
    scrollbar: rgba(48, 48, 48, 255),
    verticalline: rgb(64, 64, 64),
    linenumbers: rgb(32, 32, 32),
    textarea: rgb(32, 32, 32),
  )