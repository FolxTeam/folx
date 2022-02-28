import std/sequtils, os, std/unicode, math, strutils, std/algorithm
import pixwindy, pixie
import render, syntax_highlighting, configuration

type 
  File* = object
    path*: string
    dir*: string
    name*: string
    ext*: string
    open*: bool
    files*: seq[File]
    info*: FileInfo
  
  OpenDir* = object
    path*: string
  
  SideExplorer* = object
    current_dir*: string
    current_item*: PathComponent
    current_item_name*: string
    current_item_path*: string
    current_item_ext*: string
    count_items*: int
    item_index*: int
    dir*: File
    display*: bool
    open_dirs*: seq[OpenDir]
    new_dir_item_index*: bool 

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

proc newFiles(file_path: string): seq[File] =
  var info: FileInfo
  var files: seq[File] = @[]
  
  for file in walkDir(file_path):
    try:
      let (dir, name, ext) = splitFile(file.path)
      info = getFileInfo(file.path)

      var new_file = File(
        path: file_path,
        dir: dir,
        name: name,
        ext: ext,
        open: false,
        files: @[],
        info: info
      )
      files.add(new_file)
    except:
      discard

  return files


proc updateDir*(explorer: var SideExplorer, path: string) =
  let (dir, name, ext) = splitFile(explorer.current_dir)
  let info = getFileInfo(explorer.current_dir)
  explorer.dir = File(
    path: explorer.current_dir,
    dir: dir,
    name: name,
    ext: ext,
    open: false,
    files: newFiles(explorer.current_dir),
    info: info,
  )

proc side_explorer_onButtonDown*(
  button: Button,
  explorer: var SideExplorer,
  path: string,
  onFileOpen: proc(file: string)
  ) =
  case button
  
  of KeyLeft:
    if explorer.current_item == PathComponent.pcDir:
      explorer.open_dirs = explorer.open_dirs.filterIt(it != OpenDir(path: explorer.current_item_path / explorer.current_item_name))
    
  of KeyUp:
    if explorer.item_index > 1:
      dec explorer.item_index
  
  of KeyDown:
    if explorer.item_index < explorer.count_items:
      inc explorer.item_index

  of KeyRight:
    if explorer.current_item == PathComponent.pcFile:
      onFileOpen(explorer.current_item_path / explorer.current_item_name & explorer.current_item_ext)
    elif explorer.current_item == PathComponent.pcDir:
      explorer.open_dirs.add(OpenDir(path: explorer.current_item_path / explorer.current_item_name))

  else: discard

proc side_explorer_area*(
  r: Context,
  image: Image,
  box: Rect,
  pos: float32,
  gt: var GlyphTable,
  bg: ColorRgb,
  dir: File,
  explorer: var SideExplorer,
  count_items: int32,
  y: float32,
  nesting: int32,
  ) : (float32, int32) {.discardable.} =

  let dy = round(gt.font.size * 1.27)
  var y = y
  var dir = dir
  var count_items = count_items
  
  var max_file_length = 0
  var max_file_size: BiggestInt = 0
  var size = (box.h / gt.font.size).ceil.int
  
  # todo: refactor long expressions
  for file in dir.files:
    max_file_length = if (file.name & file.ext).len() > max_file_length: (file.name & file.ext).len() else: max_file_length
    max_file_size = if file.info.size > max_file_size: file.info.size else: max_file_size

  # ! sorted on each component rerender | check if seq already sorted or take the sort to updateDir
  sort(dir.files, folderUpCmp)
  
  for i, file in dir.files.pairs:

    let text = " ".repeat(nesting * 2) & file.name & file.ext
    
    inc count_items

    if file.info.kind == PathComponent.pcDir:

      if count_items in pos.int..pos.ceil.int+size:

        if count_items == int(explorer.item_index):

          explorer.current_item = file.info.kind
          explorer.current_item_path = file.path
          explorer.current_item_name = file.name
          explorer.current_item_ext = file.ext

          r.fillStyle = colorTheme.statusBarBg
          r.fillRect rect(vec2(0,y), vec2(text.toRunes.width(gt).float32, dy))
          r.image.draw toRunes(text), rgb(0, 0, 0), vec2(box.x, y), box, gt, colorTheme.statusBarBg
          y += dy
          
        else:
          r.image.draw text.toRunes, sStringLitEscape.color, vec2(box.x, y), box, gt, bg
          y += dy
      

      if OpenDir(path: file.path / file.name) in explorer.open_dirs:

        dir.files[i].files = newFiles(file.path / file.name)

        let (y2, count_items2) = r.side_explorer_area(
          image = image,
          box = box,
          pos = pos,
          gt = gt,
          bg = configuration.colorTheme.textarea,
          dir = dir.files[i],
          explorer = explorer,
          count_items = count_items,
          y = y,
          nesting = nesting + 1
        )

        y = y2
        count_items = count_items2

    else:
      if count_items in pos.int..pos.ceil.int+size:
        if count_items == int(explorer.item_index):

          explorer.current_item = file.info.kind
          explorer.current_item_path = file.path
          explorer.current_item_name = file.name
          explorer.current_item_ext = file.ext

          r.fillStyle = colorTheme.statusBarBg
          r.fillRect rect(vec2(0,y), vec2(text.toRunes.width(gt).float32, dy))
          r.image.draw toRunes(text), rgb(0, 0, 0), vec2(box.x, y), box, gt, colorTheme.statusBarBg
          y += dy

          explorer.current_item = file.info.kind
        else:
          r.image.draw text.toRunes, sText.color, vec2(box.x, y), box, gt, bg
          y += dy
    
    
  explorer.count_items = count_items
  return (y, count_items)
    