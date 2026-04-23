## Doc-pattern self-referential Expr (single next pointer, no lists)
##
## From https://docs.modular.com/mojo/manual/structs/reference/
## Expr with kind, value, next (UnsafePointer[Self, MutExternalOrigin]).
## Same shape as Node docs example; no List fields so this compiles on Mojo 0.26.x.

from std.memory import UnsafePointer, alloc


struct Expr(Movable):
    comptime ExprPointer = UnsafePointer[Self, MutExternalOrigin]

    var kind: String
    var value: String
    var next: Self.ExprPointer

    fn __init__(out self, kind: String, value: String):
        self.kind = kind
        self.value = value
        self.next = Self.ExprPointer()

    @staticmethod
    fn make_expr(kind: String, value: String) -> Self.ExprPointer:
        var ptr = alloc[Self](1)
        ptr.init_pointee_move(Self(kind, value))
        return ptr


def main():
    var head = Expr.make_expr("number", "one")
    print(head[].kind, head[].value)
    head.destroy_pointee()
    head.free()
