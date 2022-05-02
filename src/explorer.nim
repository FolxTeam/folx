import options, os, math, algorithm, times
import pixwindy, pixie
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
    if explorer.display_disk_list:
      explorer.current_dir = explorer.disk_list[explorer.item_index]
      explorer.display_disk_list = false
      config.workspace = explorer.current_dir
      onWorkspaceOpen(config.workspace)
      return

    let file = explorer.files[explorer.item_index]
    
    if file.info.kind == PathComponent.pcDir:
      config.workspace = explorer.current_dir / file.name & file.ext
      onWorkspaceOpen(config.workspace)
      
  else: discard

component Disk {.noexport.}:
  proc handle(
    disk: string,
    selected: bool,
    bg: ColorRgb,
  )
  
  if selected:
    Rect: color = colorTheme.bgSelection
    Rect(w = 2): color = colorTheme.bgSelectionLabel

  Text disk(x = 10):
    color = colorTheme.cActive
    bg =
      if selected: colorTheme.bgSelection
      else: bg

component File {.noexport.}:
  proc handle(
    file: File,
    selected: bool,
    bg: ColorRgb,
  )

  let dy = round(glyphTableStack[^1].font.size * 1.27)
  
  if selected:
    Rect: color = colorTheme.bgSelection
    Rect(w = 2): color = colorTheme.bgSelectionLabel
  
  let bg =
    if selected: colorTheme.bgSelection
    else: bg
  
  contextStack[^1].image.draw(getIcon(file), translate(parentBox.xy + vec2(20, 4)) * scale(vec2(0.06 * dy, 0.06 * dy)))

  Text (file.name & file.ext)(x = 40, w = 200, clip = true):
    color = colorTheme.cActive
    bg = bg

  Text ($file.info.size)(x = 250, w = 90, clip = true):
    color = colorTheme.cActive
    bg = bg

  Text ($file.info.lastWriteTime.format("hh:mm dd/MM/yy"))(left = 350, clip = true):
    color = colorTheme.cActive
    bg = bg


component Explorer:
  proc handle(
    explorer: var Explorer,
    bg: ColorRgb,
  )

  let dy = round(glyphTableStack[^1].font.size * 1.27)
  var y = -dy * (explorer.pos mod 1)

  #! sorted on each component rerender
  # todo: check if seq already sorted or take the sort to updateDir
  sort(explorer.files, folderUpCmp)

  Text explorer.current_dir(y = y):
    color = colorTheme.sKeyword
    bg = bg
  y += dy

  if not explorer.display_disk_list:
    for i, file in explorer.files.pairs:
      File file(y = y, h = dy):
        selected = i == explorer.item_index
        bg = bg
      y += dy

  else:
    for i, disk in explorer.disk_list:
      Disk disk(y = y, h = dy):
        selected = i == explorer.item_index
        bg = bg
      y += dy
