
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
#[
  AllObj = object
    obj: Obj
    robj: refObj]#