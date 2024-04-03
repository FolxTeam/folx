import std/[tables, macros, sequtils]
import pkg/[shady]
import pkg/fusion/[matching, astdsl]
import ./[gl]
export shady

type
  DrawContext* = object
    rect*: Shape
    shaders*: Table[int, RootRef]

    px*, wh*: Vec2
    frameBufferHierarchy*: seq[tuple[fbo: GlUint, size: IVec2]]
    offset*: Vec2


var newShaderId {.compileTime.}: int = 1

macro makeShader*(ctx: DrawContext, body: untyped): auto =
  ## 
  ## .. code-block:: nim
  ##   let solid = ctx.makeShader:
  ##     {.version: "330 core".}
  ##     proc vert(
  ##       gl_Position: var Vec4,
  ##       pos: var Vec2,
  ##       ipos: Vec2,
  ##       transform: Uniform[Mat4],
  ##       size: Uniform[Vec2],
  ##       px: Uniform[Vec2],
  ##     ) =
  ##       transformation(gl_Position, pos, size, px, ipos, transform)
  ##    
  ##     proc frag(
  ##       glCol: var Vec4,
  ##       pos: Vec2,
  ##       radius: Uniform[float],
  ##       size: Uniform[Vec2],
  ##       color: Uniform[Vec4],
  ##     ) =
  ##       glCol = vec4(color.rgb * color.a, color.a) * roundRect(pos, size, radius)
  ##
  ## convers to (roughly):
  ## 
  ## .. code-block:: nim
  ##   proc vert(
  ##     gl_Position: var Vec4,
  ##     pos: var Vec2,
  ##     ipos: Vec2,
  ##     transform: Uniform[Mat4],
  ##     size: Uniform[Vec2],
  ##     px: Uniform[Vec2],
  ##   ) =
  ##     transformation(gl_Position, pos, size, px, ipos, transform)
  ##  
  ##   proc frag(
  ##     glCol: var Vec4,
  ##     pos: Vec2,
  ##     radius: Uniform[float],
  ##     size: Uniform[Vec2],
  ##     color: Uniform[Vec4],
  ##   ) =
  ##     glCol = vec4(color.rgb * color.a, color.a) * roundRect(pos, size, radius)
  ##   
  ##   type MyShader = ref object of RootObj
  ##     shader: Shader
  ##     transform: OpenglUniform[Mat4]
  ##     size: OpenglUniform[Vec2]
  ##     px: OpenglUniform[Vec2]
  ##     radius: OpenglUniform[float]
  ##     color: OpenglUniform[Vec4]
  ##   
  ##   if not ctx.shaders.hasKey(1):
  ##     let x = MyShader()
  ##     x.shader = newShader {GlVertexShader: vert.toGLSL("330 core"), GlFragmentShader: frag.toGLSL("330 core")}
  ##     x.transform =  OpenglUniform[Mat4](result.solid.shader["transform"])
  ##     x.size = OpenglUniform[Vec2](result.solid.shader["size"])
  ##     x.px = OpenglUniform[Vec2](result.solid.shader["px"])
  ##     x.radius = OpenglUniform[float](result.solid.shader["radius"])
  ##     x.color = OpenglUniform[Vec4](result.solid.shader["color"])
  ##     ctx.shaders[1] = RootRef(x)
  ##   
  ##   MyShader(ctx.shaders[1])
  let id = newShaderId
  inc newShaderId
  var
    vert: NimNode
    frag: NimNode
    uniforms: Table[string, NimNode]
  
  var version: NimNode = newLit "330 core"
  var origBody = body
  var body = body
  if body.kind != nnkStmtList:
    body = newStmtList(body)

  proc findUniforms(uniforms: var Table[string, NimNode], params: seq[NimNode]) =
    for x in params:
      x.expectKind nnkIdentDefs
      var names = x[0..^3].mapit($it)
      case x[^2]
      of BracketExpr[Ident(strVal: "Uniform"), @t]:
        for name in names:
          uniforms[name] = t

  result = buildAst(stmtList):
    for x in body:
      case x
      of Pragma[ExprColonExpr[Ident(strVal: "version"), @ver]]:
        version = ver
      of ProcDef[@name is Ident(strVal: "vert"), _, _, FormalParams[Empty(), all @params], .._]:
        x
        vert = name
        (uniforms.findUniforms(params))
      of ProcDef[@name is Ident(strVal: "frag"), _, _, FormalParams[Empty(), all @params], .._]:
        x
        frag = name
        (uniforms.findUniforms(params))
      else: x

    if vert == nil:
      (error("vert shader proc not defined", origBody))
    if frag == nil:
      (error("frag shader proc not defined", origBody))
    
    let shaderT = genSym(nskType)

    typeSection:
      typeDef:
        shaderT
        empty()
        refTy:
          objectTy:
            empty()
            ofInherit:
              bindSym"RootObj"
            recList:
              identDefs(ident "shader"):
                bindSym"Shader"
                empty()

              for n, t in uniforms:
                identDefs(ident n):
                  bracketExpr bindSym"OpenglUniform": t
                  empty()
    
    ifExpr:
      elifBranch:
        call bindSym"not":
          call bindSym"hasKey":
            dotExpr(ctx, ident "shaders")
            newLit id
        stmtList:
          let shaderX = genSym(nskLet)
          letSection:
            identDefs(shaderX, empty(), call(bindSym"new", shaderT))
          
          asgn dotExpr(shaderX, ident"shader"):
            call bindSym"newShader":
              tableConstr:
                exprColonExpr:
                  ident "GlVertexShader"
                  call bindSym"toGLSL":
                    vert
                    version
                exprColonExpr:
                  ident "GlFragmentShader"
                  call bindSym"toGLSL":
                    frag
                    version
          
          for n, t in uniforms:
            asgn dotExpr(shaderX, ident n):
              call bracketExpr(bindSym"OpenglUniform", t):
                bracketExpr:
                  dotExpr(shaderX, ident "shader")
                  newLit n
          
          call bindSym"[]=":
            dotExpr(ctx, ident "shaders")
            newLit id
            call bindSym"RootRef": shaderX
    
    call shaderT: call(bindSym"[]", dotExpr(ctx, ident "shaders"), newLit id)
  
  result = nnkBlockStmt.newTree(newEmptyNode(), result)


proc newDrawContext*: DrawContext =
  result.rect = newShape(
    [
      vec2(0, 1),   # top left
      vec2(0, 0),   # bottom left
      vec2(1, 0),   # bottom right
      vec2(1, 1),   # top right
    ], [
      0'u32, 1, 2,
      2, 3, 0,
    ]
  )
