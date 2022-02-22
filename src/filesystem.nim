import os, syntax_highlighting
import std/options

type 
  File* = object
    path*: string
    dir*: string
    name*: string
    ext*: string
    info*: FileInfo
  
  Explorer* = object
    current_dir*: string
    item_index*: uint
    files*: seq[File]
    display*: bool
  
  MoveCommand* = enum
    None,
    Up,
    Down,
    Left,
    Right


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


proc move*(explorer: var Explorer, command: MoveCommand, path: string, colors: var seq[seq[ColoredPos]]): string =

  explorer.files = @[]

  var dir_files: seq[File]

  let file_path = absolutePath(path)
  let (dir, name, ext) = splitFile(file_path)

  if command == MoveCommand.Left:
    if explorer.current_dir.isRootDir():
      explorer.current_dir = normalizedPath(joinPath(explorer.current_dir, "/"))
    else:
      explorer.current_dir = parentDir(explorer.current_dir)
    
  if explorer.current_dir == "":
    explorer.current_dir = dir
 
  for file in walkDir(explorer.current_dir):
    let file_type = newFile(file.path)
    if file_type.isSome():
      dir_files.add(file_type.get())

  if command == MoveCommand.Up:
    if explorer.item_index > 0: explorer.item_index -= 1 else: explorer.item_index = 0
  if command == MoveCommand.Down:
    if int(explorer.item_index) < dir_files.len-1: explorer.item_index += 1 else: explorer.item_index = uint(dir_files.len - 1)

  explorer.files = dir_files

  var i = 0
  for file in dir_files:
    if i == int(explorer.item_index):
      if command == MoveCommand.Right:
        if file.info.kind == PathComponent.pcFile:
          return file.path
        elif file.info.kind == PathComponent.pcDir:
          explorer.current_dir = normalizedPath(joinPath(explorer.current_dir, file.name))
          return path
    inc i
    