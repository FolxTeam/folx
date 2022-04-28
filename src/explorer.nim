import std/options, os, std/unicode, math, macros
import pixwindy, pixie, std/algorithm, times
import render, configuration, markup

when defined(windows):
  import winim/com
  import strformat except `&`

  proc getWindowsDisks(): seq[string] =
    var list: seq[string] = @[]
    var wmi = GetObject("winmgmts:{impersonationLevel=impersonate}!//.")
    for drive in wmi.ExecQuery("SELECT * FROM Win32_DiskDrive"):
      for partition in wmi.ExecQuery(fmt"""ASSOCIATORS OF {{Win32_DiskDrive.DeviceID='{drive.deviceid}'}} WHERE AssocClass = Win32_DiskDriveToDiskPartition"""):
        for disk in wmi.ExecQuery(fmt"""ASSOCIATORS OF {{Win32_DiskPartition.DeviceID='{partition.deviceid}'}} WHERE AssocClass = Win32_LogicalDiskToPartition"""):
          list.add(disk.deviceid)
    return list

type 
  File* = object
    path*: string
    dir*: string
    name*: string
    ext*: string
    info*: FileInfo
  
  Explorer* = object
    display_disk_list*: bool
    disk_list*: seq[string]
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

proc getIcon(file: File): Image =
  if file.info.kind == PathComponent.pcDir:
    result = iconTheme.folder
  else:
    case file.ext
    of ".nim": result = iconTheme.nim
    else: 
      case file.name
      of ".gitignore": result = iconTheme.gitignore
      else: result = iconTheme.file


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
    if explorer.current_dir.isRootDir():
      when defined(linux): return
      elif defined(windows):
        explorer.display_disk_list = true
        explorer.disk_list = getWindowsDisks()
        return
      else: return
    
    explorer.item_index = 0
    explorer.current_dir = explorer.current_dir.parentDir
    
    explorer.updateDir path
    
  of KeyUp:
    if explorer.display_disk_list:
      if explorer.item_index > 0:
        dec explorer.item_index
      else:
        if explorer.disk_list.len != 0:
          explorer.item_index = explorer.disk_list.high
      return

    if explorer.item_index > 0:
      dec explorer.item_index
    else:
      if explorer.files.len != 0:
        explorer.item_index = explorer.files.high  # cycle
  
  of KeyDown:
    if explorer.display_disk_list:
      if explorer.item_index < explorer.disk_list.high:
        inc explorer.item_index
      else:
        explorer.item_index = 0
      return

    if explorer.item_index < explorer.files.high:
      inc explorer.item_index
    else:
      explorer.item_index = 0

  of KeyRight:
    if explorer.item_index notin 0..explorer.files.high: return

    if explorer.display_disk_list:
      explorer.current_dir = explorer.disk_list[explorer.item_index]
      explorer.display_disk_list = false
      explorer.updateDir explorer.current_dir
      return

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

component Disk {.noexport.}:
  proc handle(
    disk: string,
    gt: var GlyphTable,
  )

  let box = parentBox
  let dy = round(gt.font.size * 1.27)

  image.draw (disk).toRunes, colorTheme.cActive, vec2(box.x + 10, box.y), box, gt, colorTheme.bgSelection

component SelectedDisk {.noexport.}:
  proc handle(
    disk: string,
    gt: var GlyphTable,
  )

  let box = parentBox
  let dy = round(gt.font.size * 1.27)

  r.fillStyle = colorTheme.bgSelection
  r.fillRect rect(vec2(0, box.y), vec2(box.w, dy))

  r.fillStyle = colorTheme.bgSelectionLabel
  r.fillRect rect(vec2(0, box.y), vec2(2, dy))

  image.draw (disk).toRunes, colorTheme.cActive, vec2(box.x + 10, box.y), box, gt, colorTheme.bgSelection

component SelectedItem {.noexport.}:
  proc handle(
    file: File,
    gt: var GlyphTable,
  )

  let box = parentBox
  let dy = round(gt.font.size * 1.27)

  r.fillStyle = colorTheme.bgSelection
  r.fillRect rect(vec2(0,box.y), vec2(box.w, dy))

  r.fillStyle = colorTheme.bgSelectionLabel
  r.fillRect rect(vec2(0,box.y), vec2(2, dy))
  
  image.draw(getIcon(file), translate(vec2(box.x + 20, box.y + 4)) * scale(vec2(0.06 * dy, 0.06 * dy)))

  image.draw (file.name & file.ext).toRunes, colorTheme.cActive, vec2(box.x + 40, box.y), box, gt, colorTheme.bgSelection
  image.draw ($file.info.size).toRunes, colorTheme.cActive, vec2(box.x + 250, box.y), box, gt, colorTheme.bgSelection
  image.draw ($file.info.lastWriteTime.format("hh:mm dd/MM/yy")).toRunes, colorTheme.cActive, vec2(box.x + 350, box.y), box, gt, colorTheme.bgSelection


component Dir {.noexport.}:
  proc handle(
    file: File,
    gt: var GlyphTable,
  )

  let box = parentBox
  let dy = round(gt.font.size * 1.27)

  image.draw(getIcon(file), translate(vec2(box.x + 20, box.y + 4)) * scale(vec2(0.06 * dy, 0.06 * dy)))

  image.draw (file.name & file.ext).toRunes, colorTheme.cActive, vec2(box.x + 40, box.y), box, gt, colorTheme.bgTextArea
  image.draw ($file.info.size).toRunes, colorTheme.cActive, vec2(box.x + 250, box.y), box, gt, colorTheme.bgTextArea
  image.draw ($file.info.lastWriteTime.format("hh:mm dd/MM/yy")).toRunes, colorTheme.cActive, vec2(box.x + 350, box.y), box, gt, colorTheme.bgTextArea

component File {.noexport.}:
  proc handle(
    file: File,
    gt: var GlyphTable,
  )

  let box = parentBox
  let dy = round(gt.font.size * 1.27)

  image.draw(getIcon(file), translate(vec2(box.x + 20, box.y + 4)) * scale(vec2(0.06 * dy, 0.06 * dy)))

  image.draw (file.name & file.ext).toRunes, colorTheme.cActive, vec2(box.x + 40, box.y), box, gt, colorTheme.bgTextArea
  image.draw ($file.info.size).toRunes, colorTheme.cActive, vec2(box.x + 250, box.y), box, gt, colorTheme.bgTextArea
  image.draw ($file.info.lastWriteTime.format("hh:mm dd/MM/yy")).toRunes, colorTheme.cActive, vec2(box.x + 350, box.y), box, gt, colorTheme.bgTextArea


component Explorer:
  proc handle(
    expl: var Explorer,
    gt: var GlyphTable,
    bg: ColorRgb,
  )

  let box = parentBox

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

  if not expl.display_disk_list:
    for i, file in expl.files.pairs:
      if i == int(expl.item_index):
        SelectedItem file(x = parentBox.x, y = y, w = parentBox.w):
          gt = gt
      else:
        if file.info.kind == PathComponent.pcDir:
          Dir file(x = parentBox.x, y = y, w = parentBox.w):
            gt = gt
        else:
          File file(x = parentBox.x, y = y, w = parentBox.w):
            gt = gt

      y += dy
  else:
    for i, disk in expl.disk_list:
      if i == int(expl.item_index):
        SelectedDisk disk(x = parentBox.x, y = y, w = parentBox.w):
          gt = gt
      else:
        Disk disk(x = parentBox.x, y = y, w = parentBox.w):
          gt = gt

      y += dy
