import sequtils, os, times, math, unicode, std/monotimes, options
import pixwindy, pixie
import render, syntax_highlighting, configuration, text_editor, side_explorer, git, text


proc status_bar(
  r: Context,
  box: Rect,
  gt: var GlyphTable,
  bg: ColorRgb,
  fields: seq[tuple[field: string, value: string]],
  ) =

  const margin = vec2(8, 2)
  var s = ""

  for i in fields:
    s.add(i.field & ": " & i.value & "   ")
  
  r.fillStyle = bg
  r.fillRect box

  r.image.draw toRunes(s), sText.color, box.xy + margin, rect(box.xy, box.wh - margin), gt, bg


let window = newWindow("folx", config.window.size, visible=false)

var
  editor_gt    = readFont(config.font).newGlyphTable(config.fontSize)
  interface_gt = readFont(config.interfaceFont).newGlyphTable(config.interfaceFontSize)

  opened_file: Text
  
  text_indentation: Indentation
  text_colors: seq[ColorRgb]

  displayRequest = false
  image = newImage(1280, 720)
  r = image.newContext

  pos = 0'f32
  visual_pos = pos
  cursor = ivec2(0, 0)

var main_explorer = SideExplorer(current_dir: config.workspace, item_index: 1, display: false, pos: 0)

proc open_file*(file: string) =
  window.title = file & " - folx"
  opened_file = newText(file.readFile)
  text_colors = opened_file.parseNimCode(NimParseState(), opened_file.len).segments.colors
  assert text_colors.len == opened_file.len
  text_indentation = toSeq(0..opened_file.lines.high).mapit(opened_file{it}.toOpenArray.toSeq).indentation

open_file config.file

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
  else:
    if pos != visual_pos:
      let
        fontSize = editor_gt.font.size
        pvp = (visual_pos * fontSize).round.int32  # visual position in pixels
        
        # position delta
        d = (abs(pos - visual_pos) * pow(1 / 2, (1 / dt) / 50)).max(0.1).min(abs(pos - visual_pos))

      # move position by delta
      if pos > visual_pos: visual_pos += d
      else:                visual_pos -= d

      # if position close to integer number, round it
      if abs(visual_pos - pos) < 1 / fontSize / 2.1:
        visual_pos = pos
      
      # if position changed, signal to display by setting result to true
      if pvp != (visual_pos * fontSize).round.int32: result = true


proc display =
  image.clear colorTheme.textarea.color.rgbx

  if main_explorer.display:

    var box = rect(vec2(0, 0), vec2(200, window.size.vec2.y))
    var dy = round(editor_gt.font.size * 1.27)
    var y = box.y - dy * (pos mod 1)

    r.image.draw toRunes(main_explorer.dir.path), sKeyword.color, vec2(box.x, y), box, editor_gt, configuration.colorTheme.textarea
    y += dy

    r.side_explorer_area(
      image = image,
      box = box,
      pos = main_explorer.pos,
      gt = editor_gt,
      bg = configuration.colorTheme.textarea,
      dir = main_explorer.dir,
      explorer = main_explorer,
      count_items = 0,
      y = y,
      nesting = 0,
    )

    r.text_editor(
      box = rect(vec2(box.w, 0), window.size.vec2 - vec2(box.w, 20)),
      gt = editor_gt,
      pos = visual_pos,
      bg = colorTheme.textarea,
      text = opened_file,
      colors = text_colors,
      indentation = text_indentation,
      cursor = cursor,
    )

    r.status_bar(
      box = rect(vec2(0, window.size.vec2.y - 20), vec2(window.size.vec2.x, 20)),
      gt = interface_gt,
      bg = colorTheme.statusBarBg,
      fields = @[
        ("count_items", $main_explorer.count_items),
        ("item", $main_explorer.item_index),
      ] & (
        if main_explorer.current_dir.gitBranch.isSome: @[
          ("git", main_explorer.current_dir.gitBranch.get),
        ] else: @[]
      ) & @[
        ("visual_pos", $main_explorer.pos),  
      ]
    )
  else:  
    r.text_editor(
      box = rect(vec2(0, 0), window.size.vec2 - vec2(0, 20)),
      gt = editor_gt,
      pos = visual_pos,
      bg = colorTheme.textarea,
      text = opened_file,
      colors = text_colors,
      indentation = text_indentation,
      cursor = cursor,
    )

    r.status_bar(
      box = rect(vec2(0, window.size.vec2.y - 20), vec2(window.size.vec2.x, 20)),
      gt = interface_gt,
      bg = colorTheme.statusBarBg,
      fields = @[
        ("line", $cursor[1]),
        ("col", $cursor[0]),
      ] & (
        if main_explorer.current_dir.gitBranch.isSome: @[
          ("git", main_explorer.current_dir.gitBranch.get),
        ] else: @[]
      ) & @[
        ("visual_pos", $visual_pos),  
      ]
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
    let lines_count = if main_explorer.display: main_explorer.count_items.float32 else: opened_file.lines.high.float32
    pos = (pos - window.scrollDelta.y * 3).max(0).min(lines_count)



window.onResize = proc =
  if window.size.x * window.size.y == 0: return
  image = newImage(window.size.x, window.size.y)
  r = image.newContext
  display()

window.onButtonPress = proc(button: Button) =
  if window.buttonDown[KeyLeftControl] and button == KeyE:
    main_explorer.display = not main_explorer.display
    
    if main_explorer.display:
      pos = main_explorer.pos
      main_explorer.updateDir config.file
    else:
      pos = visual_pos

  elif main_explorer.display:
    side_explorer_onButtonDown(
      button = button,
      explorer = main_explorer,
      path = config.file,
      onFileOpen = (proc(file: string) =
        open_file file
      ),
    )

  else:
    text_editor_onButtonDown(
      button = button,
      cursor = cursor,
      text = opened_file,
    )
  
  display()


display()
window.visible = true

var pt = getMonoTime()  # main clock
while not window.closeRequested:
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
