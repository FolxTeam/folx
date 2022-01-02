import pixie, pixie/blends

{.push, checks: off.}

proc drawByImage*(r: Image, img: Image, pos: IVec2, size: IVec2, color: ColorRGBA) =
  ## fast draw image
  if color.a == 0: return

  # clip
  let pos2 = ivec2(max(-pos.x, 0), max(-pos.y, 0))
  let pos = pos + pos2
  let size = ivec2(
    size.x.min(img.width.int32 - pos2.x).min(r.width.int32 - pos.x),
    size.y.min(img.height.int32 - pos2.y).min(r.height.int32 - pos.y)
  )
  if size.x <= 0 or size.y <= 0: return

  # draw
  for y in 0..<size.y:
    var
      idst = (pos.y + y) * r.width + pos.x
      isrc = (pos2.y + y) * img.width + pos2.x
    for _ in 0..<size.x:
      r.data[idst] = blendNormal(r.data[idst], img.data[isrc])
      inc isrc
      inc idst

{.pop.}
