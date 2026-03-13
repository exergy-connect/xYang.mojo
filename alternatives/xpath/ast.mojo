## AST nodes for XPath expressions in Mojo.
## All nodes support: accept(ev, ctx, node) -> value (evaluator to be added).

from std.collections import List
from std.collections.optional import Optional
from std.memory import ArcPointer
from std.utils import Variant

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
    var value: String

    def accept(self, ev: XPathEvaluator, ctx: Context, node: Node) -> ASTNodeVariant:
        return ASTNodeVariant(value = LiteralNode(value = self.value))


@fieldwise_init
struct PathSegment(Movable):
    var step: String
    var predicate: Optional[String]


@fieldwise_init
struct PathNode(ASTNode, Movable):
    var segments: List[Arc[PathSegment]]
    var is_absolute: Bool
    var is_cacheable: Bool

    def copy(self) -> PathNode:
        return PathNode(segments=self.segments.copy(), is_absolute=self.is_absolute, is_cacheable=self.is_cacheable)

    def accept(self, ev: XPathEvaluator, ctx: Context, node: Node) -> ASTNodeVariant:
        raise Error("PathNode.accept not implemented")

    def to_string(self) -> String:
        var prefix = "/" if self.is_absolute else ""
        var out = String(prefix)
        for i in range(len(self.segments)):
            if i > 0:
                out += "/"
            out += self.segments[i][].step
        return out


@fieldwise_init
struct BinaryOpNode(ASTNode, Movable):
    var left: ASTNodeVariant
    var operator: String
    var right: ASTNodeVariant

    def accept(self, ev: XPathEvaluator, ctx: Context, node: Node) -> ASTNodeVariant:
        raise Error("BinaryOpNode.accept not implemented")


@fieldwise_init
struct FunctionCallNode(ASTNode, Movable):
    var name: String
    var args: List[Arc[ASTNodeVariant]]

    def accept(self, ev: XPathEvaluator, ctx: Context, node: Node) -> ASTNodeVariant:
        raise Error("FunctionCallNode.accept not implemented")

