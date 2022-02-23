import std/options, os
import pixwindy

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


proc folderUpCmp*(x, y: explorer.File): int =
  if (x.info.kind, y.info.kind) == (PathComponent.pcFile, PathComponent.pcDir): 1
  else: -1

proc folderDownCmp*(x, y: explorer.File): int =
  if (x.info.kind, y.info.kind) == (PathComponent.pcDir, PathComponent.pcFile): 1
  else: -1

proc bySizeUpCmp*(x, y: explorer.File): int =
  if x.info.size < y.info.size: 1
  else: -1

proc bySizeDownCmp*(x, y: explorer.File): int =
  if x.info.size > y.info.size: 1
  else: -1


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
  let (dir, name, ext) = splitFile(file_path)
    
  if explorer.current_dir == "":
    explorer.current_dir = dir
 
  for file in walkDir(explorer.current_dir):
    let file_type = newFile(file.path)
    if file_type.isSome():
      explorer.files.add(file_type.get())


proc explorer_onButtonDown*(
  button: Button,
  explorer: var Explorer,
  path: string,
  onFileOpen: proc(file: string)
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
    if file.info.kind == PathComponent.pcFile:
      onFileOpen(file.path)
    elif file.info.kind == PathComponent.pcDir:
      explorer.item_index = 0
      explorer.current_dir = explorer.current_dir / file.name
      explorer.updateDir explorer.current_dir
  
  else: discard
