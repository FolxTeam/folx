import std/sequtils, os, std/unicode, math, strutils, std/algorithm
import pixwindy, pixie
import render, configuration, markup

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
    pos*: float32
    y*: float32
    item_index*: int
    dir*: File
    display*: bool
    open_dirs*: seq[OpenDir]
    new_dir_item_index*: bool 

proc nameUpCmp*(x, y: File): int =
  if x.name & x.ext >= y.name & y.ext: 1
  else: -1

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


proc getIcon(explorer: SideExplorer, file: File): Image =
  if file.info.kind == PathComponent.pcFile:
    case file.ext
    of ".nim": result = iconTheme.nim
    else: 
      case file.name
      of ".gitignore": result = iconTheme.gitignore
      else: result = iconTheme.file
  elif file.info.kind == PathComponent.pcDir:
    if OpenDir(path: file.path / file.name & file.ext) in explorer.open_dirs:
      result = iconTheme.openfolder
    else:
      result = iconTheme.folder

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

proc onButtonDown*(
  explorer: var SideExplorer,
  button: Button,
  path: string,
  onFileOpen: proc(file: string)
  ) =
  case button
  
  of KeyLeft:
    if explorer.current_item == PathComponent.pcDir:
      explorer.open_dirs = explorer.open_dirs.filterIt(it != OpenDir(path: explorer.current_item_path / explorer.current_item_name & explorer.current_item_ext))
    
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
      explorer.open_dirs.add(OpenDir(path: explorer.current_item_path / explorer.current_item_name & explorer.current_item_ext))

  else: discard


proc updateExplorer(explorer: var SideExplorer, file: File) =
  explorer.current_item = file.info.kind
  explorer.current_item_path = file.path
  explorer.current_item_name = file.name
  explorer.current_item_ext = file.ext

component SelectedItem {.noexport.}:
  proc handle(
    explorer: var SideExplorer,
    file: File,
    nesting_indent: string,
    text: string,
    gt: var GlyphTable,
    icon_const: float32,
    count_item: int,
  )

  let box = parentBox
  let dy = round(gt.font.size * 1.40)

  updateExplorer(explorer, file)

  r.fillStyle = colorTheme.bgSelection
  r.fillRect rect(vec2(0, explorer.y), vec2(box.w, dy))

  r.fillStyle = colorTheme.bgSelectionLabel
  r.fillRect rect(vec2(0, explorer.y), vec2(2, dy))

  image.draw(getIcon(explorer, file), translate(vec2(box.x + 20 + nesting_indent.toRunes.width(gt).float32, explorer.y + 4)) * scale(vec2(icon_const * dy, icon_const * dy)))

  image.draw text.toRunes, colorTheme.cActive, vec2(box.x + 40, explorer.y), box, gt, colorTheme.bgSelection
  explorer.y += dy

component Item {.noexport.}:
  proc handle(
    explorer: var SideExplorer,
    file: File,
    nesting_indent: string,
    text: string,
    gt: var GlyphTable,
    icon_const: float32,
    count_item: int,
  )

  let box = parentBox
  let dy = round(gt.font.size * 1.40)

  image.draw(getIcon(explorer, file), translate(vec2(box.x + 20 + nesting_indent.toRunes.width(gt).float32, explorer.y + 4)) * scale(vec2(icon_const * dy, icon_const * dy)))

  image.draw text.toRunes, colorTheme.cActive, vec2(box.x + 40, explorer.y), box, gt, colorTheme.bgExplorer
  explorer.y += dy
    

component SideExplorer:
  proc handle(
    main_explorer: var SideExplorer,
    gt: var GlyphTable,
    dir: File,
    nesting: int32 = 0,
  )

  
  var box = parentBox
  var dy = round(gt.font.size * 1.40)
  let
    icon_const = 0.06
  var
    dir = dir
    size = (box.h / gt.font.size).ceil.int
    count_items = main_explorer.count_items
    pos = main_explorer.pos

  if nesting == 0:
    main_explorer.y = 40
    count_items = 0
    main_explorer.count_items = 0
    
    var middle_x = box.x + ( ( box.w - "Explorer".toRunes.width(gt).float32 ) / 2 )

    r.fillStyle = colorTheme.bgExplorer
    r.fillRect box

    r.image.draw "Explorer".toRunes, colorTheme.cActive, vec2(middle_x.float32, main_explorer.y), box, gt, configuration.colorTheme.bgExplorer
    main_explorer.y += dy

    r.image.draw toRunes(main_explorer.dir.path), colorTheme.cInActive, vec2(box.x, main_explorer.y), box, gt, configuration.colorTheme.bgExplorer
    main_explorer.y += dy

  # ! sorted on each component rerender | check if seq already sorted or take the sort to updateDir

  var dir_files: seq[File] = @[]
  var dir_folders: seq[File] = @[]
  for file in dir.files:
    if file.info.kind == PathComponent.pcFile:
      dir_files.add(file)
    elif file.info.kind == PathComponent.pcDir:
      dir_folders.add(file)


  sort(dir_files, nameUpCmp)
  sort(dir_folders, nameUpCmp)
  dir.files = dir_folders & dir_files
  
  for i, file in dir.files.pairs:

    inc count_items

    let nesting_indent = " ".repeat(nesting * 2)
    let text = nesting_indent & file.name & file.ext

    if count_items in pos.int..pos.ceil.int+size:
      if count_items == int(main_explorer.item_index):
        SelectedItem():
          explorer = main_explorer
          file = file
          nesting_indent = nesting_indent
          text = text
          gt = gt
          icon_const = icon_const
          count_item = count_items
      else:
        Item():
          explorer = main_explorer
          file = file
          nesting_indent = nesting_indent
          text = text
          gt = gt
          icon_const = icon_const
          count_item = count_items
    
    if file.info.kind == PathComponent.pcDir:
      if OpenDir(path: file.path / file.name & file.ext) in main_explorer.open_dirs:

        dir.files[i].files = newFiles(file.path / file.name & file.ext)

        main_explorer.count_items = count_items

        SideExplorer main_explorer(x = parentBox.x, y = parentBox.y, w = parentBox.w, h = parentBox.h):
          gt = gt
          dir = dir.files[i]
          nesting = nesting + 1
        
        count_items = main_explorer.count_items

  main_explorer.count_items = count_items
