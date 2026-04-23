## Minimal repro: self-referential struct with List[UnsafePointer[Self, MutExternalOrigin]]
##
## Pattern follows https://docs.modular.com/mojo/manual/structs/reference/
## (UnsafePointer[Self, MutExternalOrigin] for recursive refs).
##
## On Mojo 0.26.x this file fails with:
##
##   error: struct has recursive reference to itself
##   struct Expr(Movable):
##          ^
##
## A struct with only pointer fields (e.g. left/right) compiles;
## adding List[Self.ExprPointer] (e.g. args/steps) triggers the recursive-reference
## error. So the documented pattern works for a single "next" pointer but not
## for a list of pointers to self.

from std.collections import List
from std.memory import UnsafePointer, ArcPointer, alloc

comptime Arc = ArcPointer


struct Expr(Movable):
    comptime ExprPointer = UnsafePointer[Self, MutExternalOrigin]

    var kind: String
    var value: String
    var left: Self.ExprPointer
    var right: Self.ExprPointer
    var args: List[Arc[Expr]]
    var steps: List[Self.ExprPointer]

    def __init__(
        out self,
        kind: String,
        value: String,
        left: Self.ExprPointer,
        right: Self.ExprPointer,
        var args: List[Arc[Expr]],
        var steps: List[Self.ExprPointer],
    ):
        self.kind = kind
        self.value = value
        self.left = left
        self.right = right
        self.args = args^
        self.steps = steps^

    @staticmethod
    def number(v: String) -> Self.ExprPointer:
        var ptr = alloc[Self](1)
        ptr.init_pointee_move(
            Self(
                "number", v,
                Self.ExprPointer(),
                Self.ExprPointer(),
                List[Arc[Expr]](),
                List[Self.ExprPointer](),
            )
        )
        return ptr

    ## Recursively free this node and all children. Call on the pointee (ptr[]).
    def free_tree(self):
        if self.left:
            self.left[].free_tree()
            self.left.destroy_pointee()
            self.left.free()
        if self.right:
            self.right[].free_tree()
            self.right.destroy_pointee()
            self.right.free()
        for i in range(len(self.args)):
            self.args[i][].free_tree()
        for i in range(len(self.steps)):
            self.steps[i][].free_tree()
            self.steps[i].destroy_pointee()
            self.steps[i].free()


def main():
    var p = Expr.number("42")
    print(p[].kind, p[].value)
    p[].free_tree()
    p.destroy_pointee()
    p.free()
