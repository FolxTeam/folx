import std/options, os, std/unicode, math, strutils
import pixwindy, pixie, std/algorithm, times
import render, configuration

type 
  File* = object
    path*: string
    dir*: string
    name*: string
    ext*: string
    info*: FileInfo
  
  Explorer* = object
    current_dir*: string
    item_index*: int
    files*: seq[File]
    display*: bool
    pos*: float32

proc folderUpCmp*(x, y: File): int =
  if (x.info.kind, y.info.kind) == (PathComponent.pcFile, PathComponent.pcDir): 1
  else: -1

proc folderDownCmp*(x, y: File): int =
  if (x.info.kind, y.info.kind) == (PathComponent.pcDir, PathComponent.pcFile): 1
  else: -1

proc bySizeUpCmp*(x, y: File): int =
  if x.info.size < y.info.size: 1
  else: -1

proc bySizeDownCmp*(x, y: File): int =
  if x.info.size > y.info.size: 1
  else: -1


proc digits(x: BiggestInt): int =
  var x = x
  if x == 0:
    return 1

  while x != 0:
    inc result
    x = x div 10

proc newFile(file_path: string): Option[File] =
  let (dir, name, ext) = splitFile(file_path)
  var info: FileInfo 
  try:
    info = getFileInfo(file_path)
    return some(File(
      path: file_path,
      dir: dir,
      name: name,
      ext: ext,
      info: info
    ))
  except:
    return none(File)

proc updateDir*(explorer: var Explorer, path: string) =
  ## todo: refactor
  explorer.files = @[]

  let file_path = absolutePath(path)
  let (dir, _, _) = splitFile(file_path)
    
  if explorer.current_dir == "":
    explorer.current_dir = dir
 
  for file in walkDir(explorer.current_dir):
    let file_type = newFile(file.path)
    if file_type.isSome():
      explorer.files.add(file_type.get())


proc onButtonDown*(
  explorer: var Explorer,
  button: Button,
  path: string,
  window: Window,
  onWorkspaceOpen: proc(path: string)
  ) =
  case button
  
  of KeyLeft:
    if explorer.current_dir.isRootDir(): return
    
    explorer.item_index = 0
    explorer.current_dir = explorer.current_dir.parentDir
    
    explorer.updateDir path
    
  of KeyUp:
    if explorer.item_index > 0:
      dec explorer.item_index
    else:
      if explorer.files.len != 0:
        explorer.item_index = explorer.files.high  # cycle
  
  of KeyDown:
    if explorer.item_index < explorer.files.high:
      inc explorer.item_index
    else:
      explorer.item_index = 0

  of KeyRight:
    if explorer.item_index notin 0..explorer.files.high: return

    let file = explorer.files[explorer.item_index]

    if file.info.kind == PathComponent.pcDir:
        explorer.item_index = 0
        explorer.current_dir = explorer.current_dir / file.name & file.ext
        explorer.updateDir explorer.current_dir

  of KeyEnter:
    let file = explorer.files[explorer.item_index]
    
    if file.info.kind == PathComponent.pcDir:
      config.workspace = explorer.current_dir / file.name & file.ext
      onWorkspaceOpen(config.workspace)
      
  
  else: discard

proc explorer_area*(
  r: Context,
  image: Image,
  box: Rect,
  gt: var GlyphTable,
  bg: ColorRgb,
  expl: var Explorer,
  ) =

  let dy = round(gt.font.size * 1.27)
  var y = box.y - dy * (expl.pos mod 1)

  var max_file_length = 0
  var max_file_size: BiggestInt = 0
  
  # todo: refactor long expressions
  for file in expl.files:
    max_file_length = if (file.name & file.ext).len() > max_file_length: (file.name & file.ext).len() else: max_file_length
    max_file_size = if file.info.size > max_file_size: file.info.size else: max_file_size

  # ! sorted on each component rerender | check if seq already sorted or take the sort to updateDir
  sort(expl.files, folderUpCmp)

  r.image.draw expl.current_dir.toRunes, colorTheme.sKeyword, vec2(box.x, y), box, gt, bg
  y += dy

  for i, file in expl.files.pairs:
    let spaces_after_name = " ".repeat(max_file_length + 1 - (file.name & file.ext).runeLen())
    let spaces_after_size = " ".repeat(max_file_size.digits() + 1 - digits(file.info.size))

    let text = file.name & file.ext & spaces_after_name & $file.info.size & spaces_after_size & $file.info.lastWriteTime.format("hh:mm dd/MM/yy")
    if i == int(expl.item_index):
      r.fillStyle = colorTheme.bgSelection
      r.fillRect rect(vec2(0,y), vec2(text.toRunes.width(gt).float32, dy))
      r.image.draw toRunes(text), rgb(0, 0, 0), vec2(box.x, y), box, gt, colorTheme.cInActive

    else:
      if file.info.kind == PathComponent.pcDir:
        r.image.draw text.toRunes, colorTheme.sStringLitEscape, vec2(box.x, y), box, gt, bg
      else:
        r.image.draw text.toRunes, colorTheme.sText, vec2(box.x, y), box, gt, bg
    y += dy
