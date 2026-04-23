## Doc-pattern self-referential Node (single next pointer)
##
## From https://docs.modular.com/mojo/manual/structs/reference/
## Node with Optional[ElementType] and next: NodePointer (UnsafePointer[Self, MutExternalOrigin]).
## Use this to verify the documented pattern compiles and runs.

from std.collections.optional import Optional
from std.memory import UnsafePointer, alloc


struct Node(Movable):
    comptime NodePointer = UnsafePointer[Self, MutExternalOrigin]

    var value: String
    var next: Self.NodePointer

    fn __init__(out self, value: String):
        self.value = value
        self.next = Self.NodePointer()

    @staticmethod
    fn make_node(value: String) -> Self.NodePointer:
        var node_ptr = alloc[Self](1)
        node_ptr.init_pointee_move(Self(value))
        return node_ptr


def main():
    comptime ListNode = Node
    var head = ListNode.make_node("one")
    print(head[].value)
    head.destroy_pointee()
    head.free()
