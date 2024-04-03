import ./[gl, shaders]
import pkg/[chroma, vmath]

proc mat4*(x: Mat2): Mat4 = discard
  ## note: this function exists in Glsl, but do not in vmath

proc vec4*(color: Color): Vec4 =
  vec4(color.r, color.g, color.b, color.a)


proc passTransform*(ctx: DrawContext, shader: tuple|object|ref object, pos = vec2(), size = vec2(10, 10), angle: float32 = 0, flipY = false) =
  shader.transform.uniform =
    translate(vec3(ctx.px*(vec2(pos.x, -pos.y) - ctx.wh - (if flipY: vec2(0, size.y) else: vec2())), 0)) *
    scale(if flipY: vec3(1, -1, 1) else: vec3(1, 1, 1)) *
    rotate(angle, vec3(0, 0, 1))
  shader.size.uniform = size
  shader.px.uniform = ctx.px


var gltex*: Uniform[Sampler2d]


proc transformation*(glpos: var Vec4, pos: var Vec2, size, px, ipos: Vec2, transform: Mat4) =
  let scale = vec2(px.x * size.x, px.y * -size.y)
  glpos = transform * mat2(scale.x, 0, 0, scale.y).mat4 * vec4(ipos, vec2(0, 1))
  pos = vec2(ipos.x * size.x, ipos.y * size.y)


proc roundRectOpacityAtFragment*(pos, size: Vec2, radius: float32): float32 =
  if radius == 0: return 1
  
  if pos.x < radius and pos.y < radius:
    let d = length(pos - vec2(radius, radius))
    return (radius - d + 0.5).max(0).min(1)
  
  elif pos.x > size.x - radius and pos.y < radius:
    let d = length(pos - vec2(size.x - radius, radius))
    return (radius - d + 0.5).max(0).min(1)
  
  elif pos.x < radius and pos.y > size.y - radius:
    let d = length(pos - vec2(radius, size.y - radius))
    return (radius - d + 0.5).max(0).min(1)
  
  elif pos.x > size.x - radius and pos.y > size.y - radius:
    let d = length(pos - vec2(size.x - radius, size.y - radius))
    return (radius - d + 0.5).max(0).min(1)

  return 1


proc updateSizeRender*(ctx: var DrawContext, size: IVec2) =
  # update size
  ctx.px = vec2(2'f32 / size.x.float32, 2'f32 / size.y.float32)
  ctx.wh = ivec2(size.x, -size.y).vec2 / 2
