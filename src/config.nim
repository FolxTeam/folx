import std/json

type
  Config* = object
    file*: string
    font*: string
    fontSize*: float32

  WindowSize* = object
    width*: int
    height*: int

proc getConfig*(): Config =
  
  try:
    let file = readFile"config.json"

    let json_config = parseJSON(file)

    return Config(
      file: json_config["file"].getStr(),
      font: json_config["font_file"].getStr(),
      fontSize: json_config["font_size"].getFloat(),
    )
  except:
    # if could not read the file or parse json
    return Config(
      file: "src/folx.nim",
      font: "resources/FiraCode-Regular.ttf",
      fontSize: 11,
    )