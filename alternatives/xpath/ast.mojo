## AST nodes for XPath expressions in Mojo.
## All nodes support: accept(ev, ctx, node) -> value (evaluator to be added).

from std.collections import List
from std.collections.optional import Optional
from std.memory import ArcPointer, UnsafePointer, alloc
from std.utils import Variant
from xyang.xpath.token import Token

comptime Arc = ArcPointer

struct XPathEvaluator:
    pass


struct Context:
    pass


struct Node:
    pass


## Discriminated union of all concrete AST node types.
comptime ASTNodeVariant = Variant[LiteralNode, PathNode, BinaryOpNode, FunctionCallNode]


trait ASTNode:
    def accept(self, ev: XPathEvaluator, ctx: Context, node: Node) -> ASTNodeVariant:
        raise Error("ASTNode.accept not implemented")


@fieldwise_init
struct LiteralNode(ASTNode, Movable):
    var value: Token

    def accept(self, ev: XPathEvaluator, ctx: Context, node: Node) -> ASTNodeVariant:
        return ASTNodeVariant(value = self.value.copy())


@fieldwise_init
struct PathSegment(Movable):
    var step: Token
    var predicate: Optional[ASTNodeVariant]


@fieldwise_init
struct PathNode(ASTNode, Movable):
    var segments: List[Arc[PathSegment]]
    var is_absolute: Bool
    var is_cacheable: Bool

    def accept(self, ev: XPathEvaluator, ctx: Context, node: Node) -> ASTNodeVariant:
        raise Error("PathNode.accept not implemented")

    def to_string(self, source: String) -> String:
        var prefix = "/" if self.is_absolute else ""
        var out = String(prefix)
        for i in range(len(self.segments)):
            if i > 0:
                out += "/"
            out += self.segments[i][].step.text(source)
        return out


@fieldwise_init
struct BinaryOpNode(ASTNode, Movable):
    comptime ASTNodePointer = UnsafePointer[ASTNodeVariant, MutExternalOrigin]
    var left: Self.ASTNodePointer
    var operator: String
    var right: Self.ASTNodePointer

    def accept(self, ev: XPathEvaluator, ctx: Context, node: Node) -> ASTNodeVariant:
        raise Error("BinaryOpNode.accept not implemented")


def alloc_node(var n: ASTNodeVariant) -> UnsafePointer[ASTNodeVariant, MutExternalOrigin]:
    var p = alloc[ASTNodeVariant](1)
    p.init_pointee_move(n^)
    return p

## Recursively free heap memory owned by the tree. Only BinaryOpNode owns alloc'd
## left/right; LiteralNode, PathNode, FunctionCallNode do not. Call when done with
## an AST returned from the parser (e.g. parse()).
def free_tree(mut node: ASTNodeVariant):
    if node.isa[BinaryOpNode]():
        ref bin = node[BinaryOpNode]
        free_tree(bin.left[])
        bin.left.destroy_pointee()
        bin.left.free()
        free_tree(bin.right[])
        bin.right.destroy_pointee()
        bin.right.free()


@fieldwise_init
struct FunctionCallNode(ASTNode, Movable):
    var name: String
    var args: List[Arc[ASTNodeVariant]]

    def accept(self, ev: XPathEvaluator, ctx: Context, node: Node) -> ASTNodeVariant:
        raise Error("FunctionCallNode.accept not implemented")

