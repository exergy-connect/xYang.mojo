## AST nodes for XPath expressions in Mojo.
## All nodes support: accept(ev, ctx, node) -> value (evaluator to be added).

from std.collections import List
from std.collections.optional import Optional
from std.memory import ArcPointer, UnsafePointer, alloc
from std.utils import Variant
from xyang.xpath.token import Token

comptime Arc = ArcPointer

struct Context:
    var expression: String

    fn __init__(out self, expression: String = ""):
        self.expression = expression


struct Node:
    pass


## Discriminated union of all concrete AST node types.
comptime ASTNodeVariant = Variant[LiteralNode, PathNode, BinaryOpNode, FunctionCallNode]

comptime ASTNodePointer = ArcPointer[ASTNodeVariant]


## Visitor for walking the AST. Implement this to evaluate or transform the tree.
## Use accept(visitor, node, ctx) to dispatch; inside visit_* recurse by calling accept(visitor, child, ctx).
trait ASTVisitor:
    def visit_literal(self, node: LiteralNode, ctx: Context) -> String:
        return ""

    def visit_path(self, node: PathNode, ctx: Context) -> String:
        return ""

    def visit_binary_op(self, node: BinaryOpNode, ctx: Context) -> String:
        return ""

    def visit_function_call(self, node: FunctionCallNode, ctx: Context) -> String:
        return ""


## Dispatch to the appropriate visitor method for the root node. Recurse from within visit_* by calling this again.
def accept[V: ASTVisitor](visitor: V, node: ASTNodeVariant, ctx: Context) -> String:
    if node.isa[LiteralNode]():
        return visitor.visit_literal(node[LiteralNode], ctx)
    if node.isa[PathNode]():
        return visitor.visit_path(node[PathNode], ctx)
    if node.isa[BinaryOpNode]():
        return visitor.visit_binary_op(node[BinaryOpNode], ctx)
    if node.isa[FunctionCallNode]():
        return visitor.visit_function_call(node[FunctionCallNode], ctx)
    return ""


struct XPathEvaluator(ASTVisitor):
    def visit_literal(self, node: LiteralNode, ctx: Context) -> String:
        return node.value.text(ctx.expression)

    def visit_path(self, node: PathNode, ctx: Context) -> String:
        return node.to_string(ctx.expression)

    def visit_binary_op(self, node: BinaryOpNode, ctx: Context) -> String:
        var left_val = accept(self, node.left[], ctx)
        var right_val = accept(self, node.right[], ctx)
        return "(" + left_val + " " + node.operator + " " + right_val + ")"

    def visit_function_call(self, node: FunctionCallNode, ctx: Context) -> String:
        var out = node.name + "("
        for i in range(len(node.args)):
            if i > 0:
                out += ", "
            out += accept(self, node.args[i][], ctx)
        out += ")"
        return out


@fieldwise_init
struct LiteralNode(Movable):
    var value: Token

    def accept(self, ev: XPathEvaluator, ctx: Context, node: Node) -> ASTNodeVariant:
        return ASTNodeVariant(value = self.value.copy())


@fieldwise_init
struct PathSegment(Movable):
    var step: Token
    var predicate: Optional[ASTNodePointer]


@fieldwise_init
struct PathNode(Movable):
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
struct BinaryOpNode(Movable):
    var left: ASTNodePointer
    var operator: Token
    var right: ASTNodePointer

    def accept(self, ev: XPathEvaluator, ctx: Context, node: Node) -> ASTNodeVariant:
        raise Error("BinaryOpNode.accept not implemented")


@fieldwise_init
struct FunctionCallNode(Movable):
    var name: Token
    var args: List[ASTNodePointer]

    def accept(self, ev: XPathEvaluator, ctx: Context, node: Node) -> ASTNodeVariant:
        raise Error("FunctionCallNode.accept not implemented")

