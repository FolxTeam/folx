import sequtils, os, times, math, unicode, std/monotimes, options
import pixwindy, pixie, cligen
import render, syntax_highlighting, configuration, git, text
import text_editor, side_explorer, explorer, title

proc contains*(b: Rect, a: GVec2): bool =
  let a = a.vec2
  a.x >= b.x and a.x <= b.x + b.w and a.y >= b.y and a.y <= b.y + b.h

proc getFileExt*(file: string): string =
  if file != "":
    let (dir, name, ext) = splitFile(file)
    if ext.len > 0:
      return ext[1..^1]
    else:
      return "Plain Text"
  else:
    return ""


proc status_bar(
  r: Context,
  box: Rect,
  gt: var GlyphTable,
  bg: ColorRgb,
  fieldsStart: seq[tuple[field: string, value: string]],
  fieldsEnd: seq[tuple[field: string, value: string]],
  ) =

  const margin = vec2(8, 2)
  const marginEnd = vec2(0, 2)
  var s = ""

  for i in fieldsStart:
    s.add(i.field & i.value & "   ")
  
  r.fillStyle = bg
  r.fillRect box

  r.image.draw toRunes(s), colorTheme.cInActive, box.xy + margin, rect(box.xy, box.wh - margin), gt, bg

  s = ""

  for i in fieldsEnd:
    if(i.field == "git: "):
      s.add(i.value & "   ")
    else:
      s.add(i.field & i.value & "   ")

  let start = box.xy + vec2(box.w - toRunes(s).width(gt).float32, 0) + marginEnd

  for i in fieldsEnd:
    if(i.field == "git: "):
      r.image.draw(readImage rc"icons/git.svg", translate(start - vec2(10, -2)))

  r.image.draw toRunes(s), colorTheme.cInActive, start, rect(box.xy, box.wh), gt, bg


proc folx(files: seq[string] = @[], workspace: string = "", args: seq[string]) =
  let files =
    if files.len != 0 or (args.len != 0 and not args.any(dirExists)): files & args
    elif files.len != 0: files
    else: @[config.file]
  
  let workspace = absolutePath:
    if workspace != "": workspace
    elif args.len != 0 and args[0].dirExists: args[0]
    elif files.len == 0 or files == @[config.file]: config.workspace
    else: files[0].splitPath.head
  
  let window = newWindow("folx", config.window.size, visible=false)
  window.runeInputEnabled = true

  var
    editor_gt    = readFont(rc config.font).newGlyphTable(config.fontSize)
    interface_gt = readFont(rc config.interfaceFont).newGlyphTable(config.interfaceFontSize)

    opened_files: seq[string]
    text_editor: TextEditor

    displayRequest = false
    image = newImage(1280, 720)
    r = image.newContext

    # for explorer
    pos = 0.0'f32

  var main_explorer = SideExplorer(current_dir: workspace, item_index: 1, display: false, pos: 0)
  var explorer = Explorer(current_dir: "", item_index: 0, files: @[], display: false, pos: 0)

  proc open_file(file: string) =
    window.title = file & " - folx"
    text_editor = newTextEditor(file)
    opened_files = @[file]

  if files[0] != "":
    open_file files[0]

  proc animate(dt: float32): bool =
    # todo: refactor repeat code
    if main_explorer.display:
      if pos != main_explorer.pos:
        let
          fontSize = editor_gt.font.size
          pvp = (main_explorer.pos * fontSize).round.int32  # visual position in pixels
          
          # position delta
          d = (abs(pos - main_explorer.pos) * pow(1 / 2, (1 / dt) / 50)).max(0.1).min(abs(pos - main_explorer.pos))

        # move position by delta
        if pos > main_explorer.pos: main_explorer.pos += d
        else:                main_explorer.pos -= d

        # if position close to integer number, round it
        if abs(main_explorer.pos - pos) < 1 / fontSize / 2.1:
          main_explorer.pos = pos
        
        # if position changed, signal to display by setting result to true
        if pvp != (main_explorer.pos * fontSize).round.int32: result = true
    
    if opened_files.len != 0:
      result = result or text_editor.animate(
        dt = dt,
        gt = editor_gt
      )


  proc display =
    image.clear colorTheme.bgTextArea.color.rgbx

    if main_explorer.display:
      var box = rect(vec2(0, 40), vec2(260, window.size.vec2.y - 60))
      var dy = round(editor_gt.font.size * 1.27)
      var y = box.y - dy * (pos mod 1)
      var middle_x = box.x + ( ( box.w - toRunes("Explorer").width(editor_gt).float32 ) / 2 )

      r.fillStyle = colorTheme.bgExplorer
      r.fillRect box

      r.image.draw toRunes("Explorer"), colorTheme.cActive, vec2(middle_x.float32, y), box, editor_gt, configuration.colorTheme.bgExplorer
      y += dy

      r.image.draw toRunes(main_explorer.dir.path), colorTheme.cInActive, vec2(box.x, y), box, editor_gt, configuration.colorTheme.bgExplorer
      y += dy

      r.side_explorer_area(
        image = image,
        box = box,
        pos = main_explorer.pos,
        gt = editor_gt,
        bg = configuration.colorTheme.bgExplorer,
        dir = main_explorer.dir,
        explorer = main_explorer,
        count_items = 0,
        y = y,
        nesting = 0,
      )

      if opened_files.len != 0:
        r.text_editor(
          box = rect(vec2(box.w, 40), window.size.vec2 - vec2(box.w, 60)),
          gt = editor_gt,
          bg = colorTheme.bgTextArea,
          editor = text_editor,
        )

      r.title_bar(
        box = rect(vec2(0, 0), vec2(window.size.vec2.x, 40)),
        gt = interface_gt,
      )

      r.status_bar(
        box = rect(vec2(0, window.size.vec2.y - 20), vec2(window.size.vec2.x, 20)),
        gt = interface_gt,
        bg = colorTheme.bgStatusBar,
        fieldsStart = @[
          ("Items: ", $main_explorer.count_items),
          ("Item: ", $main_explorer.item_index),
        ],
        fieldsEnd = @[
          ("", ""),
        ] & (
          if main_explorer.current_dir.gitBranch.isSome: @[
            ("git: ", main_explorer.current_dir.gitBranch.get),
          ] else: @[]
        ) & @[
          ("", if opened_files.len > 0: getFileExt(opened_files[0]) else: getFileExt(""))
        ],
      )
    elif explorer.display:
      r.explorer_area(
        image = image,
        box = rect(vec2(0, 0), window.size.vec2 - vec2(10, 20)),
        gt = editor_gt,
        bg = colorTheme.bgTextArea,
        expl = explorer,
      )
    else:

      if opened_files.len != 0:
        r.text_editor(
          box = rect(vec2(0, 40), window.size.vec2 - vec2(0, 60)),
          gt = editor_gt,
          bg = colorTheme.bgTextArea,
          editor = text_editor,
        )

      r.title_bar(
        box = rect(vec2(0, 0), vec2(window.size.vec2.x, 40)),
        gt = interface_gt,
      )

      r.status_bar(
        box = rect(vec2(0, window.size.vec2.y - 20), vec2(window.size.vec2.x, 20)),
        gt = interface_gt,
        bg = colorTheme.bgStatusBar,
        fieldsStart = @[
          ("Line: ", $text_editor.cursor[1]),
          ("Col: ", $text_editor.cursor[0]),
        ],
        fieldsEnd = @[
          ("", ""),
        ] & (
          if main_explorer.current_dir.gitBranch.isSome: @[
            ("git: ", main_explorer.current_dir.gitBranch.get),
          ] else: @[]
        ) & @[
          ("", if opened_files.len > 0: getFileExt(opened_files[0]) else: getFileExt(""))
        ],
      )

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
      if main_explorer.display:
        if window.mousePos in rect(vec2(0, 0), vec2(260, window.size.vec2.y)):
          let lines_count = main_explorer.count_items.float32
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

  window.onButtonPress = proc(button: Button) =
    if window.buttonDown[KeyLeftControl] and button == KeyE:
      explorer.display = false
      main_explorer.display = not main_explorer.display
      
      if main_explorer.display:
        pos = main_explorer.pos
        main_explorer.updateDir config.file

    elif window.buttonDown[KeyLeftControl] and button == KeyO:
      main_explorer.display = false
      explorer.display = not explorer.display
      
      if explorer.display:
        explorer.updateDir config.file
    
    elif window.buttonDown[KeyLeftControl] and button == KeyV:
      if not main_explorer.display and opened_files.len != 0:
        text_editor.onPaste(
          text = newText(getClipboardString()),
          onTextChange = (proc =
            display()
          )
        )

    elif main_explorer.display:
      main_explorer.onButtonDown(
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
          main_explorer.current_dir = path
          main_explorer.item_index = 1
          explorer.display = false
        ),
      )

    elif opened_files.len != 0:
      text_editor.onButtonDown(
        button = button,
        window = window,
        onTextChange = (proc = discard),
      )
    
    display()

  window.onRune = proc(rune: Rune) =
    if window.buttonDown[KeyLeftSuper] or window.buttonDown[KeyRightSuper]: return

    if not main_explorer.display and opened_files.len != 0:
      text_editor.onRuneInput(
        rune = rune,
        onTextChange = (proc =
          display()
        )
      )

  display()
  window.visible = true

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
