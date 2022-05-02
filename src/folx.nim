import sequtils, os, times, math, unicode, std/monotimes, options
import cligen
import render, configuration, git, text, text_editor, side_explorer, explorer, title, status_bar, welcome

proc contains*(b: Rect, a: GVec2): bool =
  let a = a.vec2
  a.x >= b.x and a.x <= b.x + b.w and a.y >= b.y and a.y <= b.y + b.h

proc getFileExt*(file: string): string =
  if file != "":
    let (_, _, ext) = splitFile(file)
    if ext.len > 0:
      return ext[1..^1]
    else:
      return "Plain Text"
  else:
    return ""


proc folx(files: seq[string] = @[], workspace: string = "", preferWorkFolderResources: bool = false, args: seq[string]) =
  let files =
    if files.len != 0 or (args.len != 0 and not args.any(dirExists)): files & args
    elif files.len != 0: files
    else: @[config.file]
  
  let workspace = absolutePath:
    if workspace != "": workspace
    elif args.len != 0 and args[0].dirExists: args[0]
    elif files.len == 0 or files == @[config.file]: config.workspace
    else: files[0].splitPath.head

  if preferWorkFolderResources: configuration.workFolderResources()
  
  let window = newWindow("folx", config.window.size, visible=false)
  window.runeInputEnabled = true

  if config.window.customTitleBar: window.style = Undecorated

  var
    editor_gt    = readFont(rc config.font).newGlyphTable(config.fontSize)
    interface_gt = readFont(rc config.interfaceFont).newGlyphTable(config.interfaceFontSize)

    opened_files: seq[string]
    text_editor: TextEditor

    displayRequest = false
    image = newImage(window.size.x, window.size.y)
    r = image.newContext

    # for explorer
    pos = 0.0'f32

  var side_explorer = SideExplorer(current_dir: workspace, item_index: 1, display: false, pos: 0, y: 40, count_items: 0)
  var explorer = Explorer(display_disk_list: false, current_dir: "", item_index: 0, files: @[], display: false, pos: 0)
  var title = Title(name: "")

  proc open_file(file: string) =
    window.title = file & " - folx"
    text_editor = newTextEditor(file)
    opened_files = @[file]

  if files[0] != "":
    open_file files[0]

  proc animate(dt: float32): bool =
    # todo: refactor repeat code
    if side_explorer.display:
      if pos != side_explorer.pos:
        let
          fontSize = editor_gt.font.size
          pvp = (side_explorer.pos * fontSize).round.int32  # visual position in pixels
          
          # position delta
          d = (abs(pos - side_explorer.pos) * pow(1 / 2, (1 / dt) / 50)).max(0.1).min(abs(pos - side_explorer.pos))

        # move position by delta
        if pos > side_explorer.pos: side_explorer.pos += d
        else:                side_explorer.pos -= d

        # if position close to integer number, round it
        if abs(side_explorer.pos - pos) < 1 / fontSize / 2.1:
          side_explorer.pos = pos
        
        # if position changed, signal to display by setting result to true
        if pvp != (side_explorer.pos * fontSize).round.int32: result = true
    
    if opened_files.len != 0:
      result = result or text_editor.animate(
        dt = dt,
        gt = editor_gt
      )


  component Folx {.noexport.}:
    if explorer.display:
      withGlyphTable interface_gt:
        TitleBar(w = window.size.vec2.x, h = 40):
          discard

        Explorer explorer(top = 40, right = 10, bottom = 20):
          bg = colorTheme.bgTextArea

        StatusBar(top = window.size.vec2.y - 20):
          bg = colorTheme.bgStatusBar

          fieldsStart = @[
            ("Items", if explorer.display_disk_list: $explorer.disk_list.len else: $explorer.files.len)
          ]

          fieldsEnd = @[]

    elif side_explorer.display:
      withGlyphTable editor_gt:
        if opened_files.len != 0:
          TextEditor text_editor(left = 260, top = 40, bottom = 20):
            bg = colorTheme.bgTextArea

      withGlyphTable interface_gt:
        TitleBar(w = window.size.vec2.x, h = 40):
          discard

        SideExplorer side_explorer(top = 40, bottom = 20, w = 260):
          dir = side_explorer.dir

        if opened_files.len == 0:
          Welcome(left = 260, top = 40, bottom = 20):
            discard

        StatusBar(top = window.size.vec2.y - 20):
          bg = colorTheme.bgStatusBar

          fieldsStart = @[
            ("Items", $side_explorer.count_items),
            ("Item", $side_explorer.item_index),
          ]

          fieldsEnd = @[
            ("", ""),
          ] & (
            if side_explorer.current_dir.gitBranch.isSome: @[
              ("git", side_explorer.current_dir.gitBranch.get),
            ] else: @[]
          ) & @[
            ("", if opened_files.len > 0: getFileExt(opened_files[0]) else: getFileExt(""))
          ]

    else:
      withGlyphTable editor_gt:
        if opened_files.len != 0:
          TextEditor text_editor(top = 40, bottom = 20):
            bg = colorTheme.bgTextArea

      withGlyphTable interface_gt:
        TitleBar(w = window.size.vec2.x, h = 40):
          discard

        if opened_files.len == 0:
          Welcome(top = 40, bottom = 20):
            discard

        StatusBar(top = window.size.vec2.y - 20):
          bg = colorTheme.bgStatusBar

          fieldsStart = @[
            ("Line", $text_editor.cursor[1]),
            ("Col", $text_editor.cursor[0]),
          ]

          fieldsEnd = @[
            ("", ""),
          ] & (
            if side_explorer.current_dir.gitBranch.isSome: @[
              ("git", side_explorer.current_dir.gitBranch.get),
            ] else: @[]
          ) & @[
            ("", if opened_files.len > 0: getFileExt(opened_files[0]) else: getFileExt(""))
          ]


  proc display =
    image.clear colorTheme.bgTextArea.color.rgbx

    frame(wh = window.size, clip=true):
      withContext r:
        handleFolx()

    window.draw image


  window.onCloseRequest = proc =
    close window
    quit(0)


  window.onScroll = proc =
    if window.scrollDelta.y == 0: return
    if window.buttonDown[KeyLeftControl] or window.buttonDown[KeyRightControl]:
      let newSize = (editor_gt.font.size * (pow(17 / 16, window.scrollDelta.y))).round.max(1)
      
      if editor_gt.font.size != newSize:
        editor_gt.font.size = newSize
      else:
        editor_gt.font.size = (editor_gt.font.size + window.scrollDelta.y).max(1)
      
      clear editor_gt
      displayRequest = true

    else:
      if side_explorer.display:
        if window.mousePos in rect(vec2(0, 0), vec2(260, window.size.vec2.y)):
          let lines_count = side_explorer.count_items.float32
          pos = (pos - window.scrollDelta.y * 3).max(0).min(lines_count)
        
        elif opened_files.len != 0:
          text_editor.onScroll(
            delta = window.scrollDelta,
          )
      
      elif opened_files.len != 0:
        text_editor.onScroll(
          delta = window.scrollDelta,
        )


  window.onResize = proc =
    if window.size.x * window.size.y == 0: return
    image = newImage(window.size.x, window.size.y)
    r = image.newContext
    display()

  window.onMouseMove = proc() =
    title.onMouseMove(
      window = window
    )

  window.onButtonPress = proc(button: Button) =
    if window.buttonDown[KeyLeftControl] and button == KeyE:
      explorer.display = false
      side_explorer.display = not side_explorer.display
      
      if side_explorer.display:
        pos = side_explorer.pos
        side_explorer.updateDir config.file

    elif window.buttonDown[KeyLeftControl] and button == KeyO:
      side_explorer.display = false
      explorer.display = not explorer.display
      
      if explorer.display:
        explorer.updateDir config.file
    
    elif window.buttonDown[KeyLeftControl] and button == KeyV:
      if not side_explorer.display and opened_files.len != 0:
        text_editor.onPaste(
          text = newText(getClipboardString()),
          onTextChange = (proc =
            display()
          )
        )

    elif side_explorer.display:
      side_explorer.onButtonDown(
        button = button,
        path = config.file,
        onFileOpen = (proc(file: string) =
          open_file file
        ),
      )
    
    elif explorer.display:
      explorer.onButtonDown(
        button = button,
        path = config.file,
        window = window,
        onWorkspaceOpen = (proc(path: string) =
          side_explorer.current_dir = path
          config.workspace = path
          writeConfig()
          side_explorer.item_index = 1
          side_explorer.pos = 0.0
          explorer.display = false
        ),
      )

    elif opened_files.len != 0:
      text_editor.onButtonDown(
        button = button,
        window = window,
        onTextChange = (proc = 
          window.title = text_editor.file & "* - folx"
        ),
        onTextSave = (proc() =
          window.title = text_editor.file & " - folx"
        ),
      )
    
    title.onButtonDown(
      button = button, 
      window = window,
      explorer = explorer,
      side_explorer = side_explorer,
      pos = pos,
    )

    display()

  window.onRune = proc(rune: Rune) =
    if window.buttonDown[KeyLeftSuper] or window.buttonDown[KeyRightSuper]: return

    if not side_explorer.display and opened_files.len != 0:
      text_editor.onRuneInput(
        rune = rune,
        onTextChange = (proc =
          display()
          window.title = text_editor.file & "* - folx"
        )
      )

  window.visible = true
  display()

  var pt = getMonoTime()  # main clock
  while not window.closeRequested:
    # blink timeout
    if config.caretBlink:
      if blink_time > 35: 
        blink = not blink
        blink_time = 0
        display()
      else: 
        blink_time += 1

    let nt = getMonoTime()  # tick start time
    pollEvents()
    
    let dt = getMonoTime()
    # animate
    displayRequest = displayRequest or animate((dt - pt).inMicroseconds.int / 1_000_000)

    if displayRequest:
      display()
      displayRequest = false
    
    pt = dt  # update main clock

    # sleep when no events happen
    let ct = getMonoTime()
    if (ct - nt).inMilliseconds < 10:
      sleep(10 - (ct - nt).inMilliseconds.int)

dispatch folx
