# 生成するファイル
import
  std/[macros, json, strformat, sequtils]

type
  TypeRelation = enum
    trInheritance = "<|--"
    trRealization = "<|.."
    trAssociation = "<--"
    trAggregation = "o--"
    trComposition = "*--"
    trDependency  = "<.."
    trGeneralization = "<|--"

  Type* = ref object
    ## Objectの関係を示すObject
    name* : string
      ## Object名
    parent* : string
      ## 継承元のObject名
    refFrom* : string
      ## ref元のObject名
    vars* : seq[string]
      ## obj内変数
    varTypes* : seq[string]
      ## Obj内変数の型

  Connection = ref object
    a, b: string
    relation: TypeRelation
    msg: string

proc toType(nn: NimNode): Type =
  let
    name = nn[0].strVal

    isRef = (nn[2].kind == nnkRefTy)
    isRefSpecific = (isRef and nn[2][0].kind == nnkIdent)

    nnObj = 
      if isRefSpecific: nil
      elif isRef: nn[2][0]
      else:     nn[2]
    refFrom =
      if isRefSpecific: nn[2][0].strVal
      else: ""

    isInherit = (not isRefSpecific and nnObj[1].kind == nnkOfInherit)

    parent =
      if isInherit: nnObj[1][0].strVal
      else:""

    (vars, varTypes) =
      if isRefSpecific: (@[], @[])
      else:
        var
          vars, varTypes: seq[string]
        block:
          for recs in nnObj[2]:
            vars.add(recs[0].strVal)
            varTypes.add(recs[1].strVal)
        (vars, varTypes)

  result = Type(
            name: name,
            parent: parent,
            refFrom: refFrom,
            vars: vars,
            varTypes: varTypes
          )


macro parseContent() =
  let lit = parseStmt """
    type
      Obj = object
        i: int
      ObjOf = object of RootObj
        i: int
      ObjSpecific = ref Obj

      refObj = ref object
        i: int
      refObjOf = ref object of RootObj
        i: int

      AllObj = object
        obj: Obj
        robj: refObj
    """
  #echo lit.treeRepr

  var
    types: seq[Type]
    conns: seq[Connection]
  for node1 in lit:
    if node1.kind != nnkTypeSection: continue
    for node2 in node1:
      assert node2.kind == nnkTypeDef
      let t = node2.toType
      types.add(t)
      # parent
      if t.parent != "":
        conns.add(Connection(
          a: t.parent,
          b: t.name,
          relation: trInheritance,
          msg: "継承<br>（object of ~）"
        ))
      # ref
      if t.refFrom != "":
        conns.add(
          Connection(
            a: t.refFrom,
            b: t.name,
            relation: trDependency,
            msg: "依存<br>（ref ~）"
          )
        )
      # var
      for (v, vt) in zip(t.vars, t.varTypes):
        if vt in ["int", "float", "bool", "string", "char", "bit"]:
          continue
        conns.add(
          Connection(
            a: t.name,
            b: vt,
            relation: trComposition,
            msg: "構成<br>（クラス内変数で使用）"
          )
        )

  # display
  var mermaid: string

  # class
  mermaid &= """
```mermaid
classDiagram

"""

  for t in types:
    mermaid &= fmt( """
class [t.name] {
""", '[', ']')
    for (v, vt) in zip(t.vars, t.varTypes):
      mermaid &= fmt( """
  [vt] [v]
""", '[', ']')
    if t.vars.len==0:
      mermaid &= "  \n"
    mermaid &= "}\n"
  
  # relation
  mermaid &= "\n"
  for conn in conns:
    mermaid &= fmt"{conn.a} {$conn.relation} {conn.b}: {conn.msg}"&"\n"

  mermaid &= "```"

  echo mermaid
  writeFile("classDiagram.md", mermaid)

# run
parseContent()
