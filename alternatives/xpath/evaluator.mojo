## XPath evaluator for alternative parser AST (LiteralNode, PathNode, BinaryOpNode, FunctionCallNode).
## Same EvalResult / EvalContext as xyang.xpath.evaluator; dispatches on ASTNodeVariant.

from std.collections import List
from std.memory import ArcPointer
from std.utils import Variant

from alternatives.xpath.ast import (
    ASTNodeVariant,
    BinaryOpNode,
    FunctionCallNode,
    LiteralNode,
    PathNode,
    PathSegment,
)
from xyang.xpath.token import Token

comptime Arc = ArcPointer

# -----------------------------
# Evaluation value and context (mirror xyang.xpath.evaluator)
# -----------------------------

@fieldwise_init
struct XPathNode(Movable):
    var path: String
    var value: String


def _parent_path(path: String) -> String:
    var parts = path.split("/")
    if len(parts) <= 1:
        return ""
    if len(parts) == 2 and len(parts[0]) == 0:
        return "/"
    var out = ""
    for i in range(len(parts) - 1):
        if i > 0:
            out += "/"
        out += parts[i]
    return out


comptime EvalResultVariant = Variant[Float64, String, Bool, List[Arc[XPathNode]]]
comptime EvalResult = EvalResultVariant


@fieldwise_init
struct EvalContext:
    var current: Arc[XPathNode]
    var root: Arc[XPathNode]
    var expression: String


# -----------------------------
# Eval visitor and dispatch for alternative AST
# -----------------------------

trait AltExprEvalVisitor:
    def visit_literal(self, ref node: LiteralNode, ctx: EvalContext, current: Arc[XPathNode]) raises -> EvalResult:
        return EvalResult(0.0)

    def visit_path(self, ref node: PathNode, ctx: EvalContext, current: Arc[XPathNode]) raises -> EvalResult:
        return EvalResult(List[Arc[XPathNode]]())

    def visit_binary_op(self, ref node: BinaryOpNode, ctx: EvalContext, current: Arc[XPathNode]) raises -> EvalResult:
        return EvalResult(0.0)

    def visit_function_call(self, ref node: FunctionCallNode, ctx: EvalContext, current: Arc[XPathNode]) raises -> EvalResult:
        return EvalResult(0.0)


def eval_accept[V: AltExprEvalVisitor](
    visitor: V, ref node: ASTNodeVariant, ctx: EvalContext, current: Arc[XPathNode]
) raises -> EvalResult:
    if node.isa[LiteralNode]():
        return visitor.visit_literal(node[LiteralNode], ctx, current)
    if node.isa[PathNode]():
        return visitor.visit_path(node[PathNode], ctx, current)
    if node.isa[BinaryOpNode]():
        return visitor.visit_binary_op(node[BinaryOpNode], ctx, current)
    if node.isa[FunctionCallNode]():
        return visitor.visit_function_call(node[FunctionCallNode], ctx, current)
    return EvalResult(0.0)


def eval_accept[V: AltExprEvalVisitor](
    visitor: V, node: Arc[ASTNodeVariant], ctx: EvalContext, current: Arc[XPathNode]
) raises -> EvalResult:
    return eval_accept(visitor, node[], ctx, current)


# -----------------------------
# Helpers
# -----------------------------

def _yang_bool(result: EvalResult) -> Bool:
    var r = result
    if r.isa[Bool]():
        return r[Bool]
    if r.isa[Float64]():
        return r[Float64] != 0.0
    if r.isa[String]():
        return len(r[String]) > 0
    if r.isa[List[Arc[XPathNode]]]():
        return len(r[List[Arc[XPathNode]]]) > 0
    return False


def _first_value(result: EvalResult) -> EvalResult:
    var r = result
    if r.isa[List[Arc[XPathNode]]]():
        ref nodes = r[List[Arc[XPathNode]]]
        if len(nodes) > 0:
            return EvalResult(nodes[0][].value)
    return result


def _node_set_to_list(result: EvalResult) -> List[Arc[XPathNode]]:
    var r = result
    if r.isa[List[Arc[XPathNode]]]():
        return r[List[Arc[XPathNode]]].copy()
    return List[Arc[XPathNode]]()


def _result_to_float(result: EvalResult) -> Float64:
    var r = result
    if r.isa[Float64]():
        return r[Float64]
    if r.isa[String]():
        return 0.0
    if r.isa[Bool]():
        return 1.0 if r[Bool] else 0.0
    if r.isa[List[Arc[XPathNode]]]():
        return Float64(len(r[List[Arc[XPathNode]]]))
    return 0.0


def _result_to_string(result: EvalResult) -> String:
    var r = result
    if r.isa[String]():
        return r[String]
    if r.isa[Float64]():
        return String(r[Float64])
    if r.isa[Bool]():
        return "true" if r[Bool] else "false"
    if r.isa[List[Arc[XPathNode]]]():
        ref nodes = r[List[Arc[XPathNode]]]
        if len(nodes) == 0:
            return ""
        return nodes[0][].value
    return ""


def _compare_eq(left: EvalResult, right: EvalResult) -> Bool:
    var lf = _result_to_float(left)
    var rf = _result_to_float(right)
    if left.isa[Float64]() or right.isa[Float64]():
        return lf == rf
    var ls = _result_to_string(left)
    var rs = _result_to_string(right)
    return ls == rs


# -----------------------------
# XPathEvaluator
# -----------------------------

struct AltXPathEvaluator(AltExprEvalVisitor):
    fn __init__(out self):
        pass

    def eval(
        self, node: Arc[ASTNodeVariant], ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return eval_accept(self, node, ctx, current)

    def visit_literal(
        self, ref node: LiteralNode, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var tt = node.value.type
        if tt == Token.STRING:
            return EvalResult(node.value.text(ctx.expression, strip_quotes=True))
        if tt == Token.NUMBER or tt == Token.FLOAT_NUMBER:
            var v = node.value.text(ctx.expression)
            try:
                return EvalResult(Float64(atol(v)))
            except:
                return EvalResult(Float64(0.0))
        if tt == Token.IDENTIFIER:
            var text = node.value.text(ctx.expression).lower()
            if text == "true":
                return EvalResult(True)
            if text == "false":
                return EvalResult(False)
        return EvalResult(node.value.text(ctx.expression))

    def visit_path(
        self, ref node: PathNode, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var nodes = List[Arc[XPathNode]]()
        if node.is_absolute:
            nodes.append(ctx.root.copy())
        else:
            nodes.append(current.copy())
        for i in range(len(node.segments)):
            ref seg = node.segments[i][]
            var step_name = seg.step.text(ctx.expression)
            var next_nodes = List[Arc[XPathNode]]()
            if step_name == ".":
                next_nodes = nodes.copy()
            elif step_name == "..":
                for j in range(len(nodes)):
                    var pp = _parent_path(nodes[j][].path)
                    if len(pp) > 0:
                        next_nodes.append(Arc[XPathNode](XPathNode(pp, pp)))
            else:
                for j in range(len(nodes)):
                    var child_path = nodes[j][].path + "/" + step_name
                    next_nodes.append(Arc[XPathNode](XPathNode(child_path, child_path)))
            nodes = next_nodes.copy()
            if seg.predicate:
                nodes = self._apply_predicate(nodes, seg.predicate.value(), ctx)
        return EvalResult(nodes^)

    def _apply_predicate(
        self,
        nodes: List[Arc[XPathNode]],
        predicate: Arc[ASTNodeVariant],
        ctx: EvalContext,
    ) raises -> List[Arc[XPathNode]]:
        var results = List[Arc[XPathNode]]()
        for i in range(len(nodes)):
            var val = eval_accept(self, predicate, ctx, nodes[i])
            var keep = False
            if val.isa[Float64]():
                if Int(val[Float64]) == i + 1:
                    keep = True
            elif _yang_bool(val):
                keep = True
            if keep:
                results.append(nodes[i].copy())
        return results.copy()

    def visit_binary_op(
        self, ref node: BinaryOpNode, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var op = node.operator.text(ctx.expression)
        if op == "or":
            var left = eval_accept(self, node.left, ctx, current)
            if _yang_bool(left):
                return EvalResult(True)
            return EvalResult(_yang_bool(eval_accept(self, node.right, ctx, current)))
        if op == "and":
            var left = eval_accept(self, node.left, ctx, current)
            if not _yang_bool(left):
                return EvalResult(False)
            return EvalResult(_yang_bool(eval_accept(self, node.right, ctx, current)))
        if op == "/":
            return self._eval_composition(node, ctx, current)
        var left = eval_accept(self, node.left, ctx, current)
        var right = eval_accept(self, node.right, ctx, current)
        if op == "=":
            return EvalResult(_compare_eq(left, right))
        if op == "!=":
            return EvalResult(not _compare_eq(left, right))
        if op == "+":
            return EvalResult(_result_to_float(left) + _result_to_float(right))
        if op == "-":
            return EvalResult(_result_to_float(left) - _result_to_float(right))
        if op == "*":
            return EvalResult(_result_to_float(left) * _result_to_float(right))
        if op == "<":
            return EvalResult(_result_to_float(left) < _result_to_float(right))
        if op == ">":
            return EvalResult(_result_to_float(left) > _result_to_float(right))
        if op == "<=":
            return EvalResult(_result_to_float(left) <= _result_to_float(right))
        if op == ">=":
            return EvalResult(_result_to_float(left) >= _result_to_float(right))
        return EvalResult(0.0)

    def _eval_composition(
        self, ref node: BinaryOpNode, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var left_res = eval_accept(self, node.left, ctx, current)
        var left_nodes = _node_set_to_list(left_res)
        if not left_res.isa[List[Arc[XPathNode]]]():
            left_nodes = List[Arc[XPathNode]]()

        var results = List[Arc[XPathNode]]()
        for i in range(len(left_nodes)):
            var r = eval_accept(self, node.right, ctx, left_nodes[i])
            var rlist = _node_set_to_list(r)
            for j in range(len(rlist)):
                results.append(rlist[j].copy())
        return EvalResult(results^)

    def visit_function_call(
        self, ref node: FunctionCallNode, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var name = node.name.text(ctx.expression)
        if name == "current":
            var single = List[Arc[XPathNode]]()
            single.append(ctx.current.copy())
            return EvalResult(single^)
        if name == "true":
            return EvalResult(True)
        if name == "false":
            return EvalResult(False)
        if name == "not":
            if len(node.args) == 1:
                var a = eval_accept(self, node.args[0], ctx, current)
                return EvalResult(not _yang_bool(a))
            return EvalResult(False)
        if name == "count":
            if len(node.args) == 1:
                var a = eval_accept(self, node.args[0], ctx, current)
                return EvalResult(Float64(len(_node_set_to_list(a))))
            return EvalResult(0.0)
        if name == "string":
            if len(node.args) == 1:
                var a = eval_accept(self, node.args[0], ctx, current)
                return EvalResult(_result_to_string(_first_value(a)))
            return EvalResult("")
        if name == "number":
            if len(node.args) == 1:
                var a = eval_accept(self, node.args[0], ctx, current)
                return EvalResult(_result_to_float(_first_value(a)))
            return EvalResult(0.0)
        if name == "boolean" or name == "bool":
            if len(node.args) == 1:
                var a = eval_accept(self, node.args[0], ctx, current)
                return EvalResult(_yang_bool(a))
            return EvalResult(False)
        if name == "position":
            return EvalResult(1.0)
        if name == "last":
            return EvalResult(1.0)
        if name == "string-length":
            if len(node.args) == 1:
                var a = eval_accept(self, node.args[0], ctx, current)
                return EvalResult(Float64(len(_result_to_string(_first_value(a)))))
            return EvalResult(0.0)
        return EvalResult(0.0)


def eval_result_to_bool(result: EvalResult) -> Bool:
    return _yang_bool(result)
