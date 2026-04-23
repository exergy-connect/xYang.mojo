## XPath evaluator for Expr AST.
## Uses a visitor-style dispatch to walk the tree; evaluates to EvalResult (number, string, bool, node-set).
## Similar to Python xyang.xpath.evaluator; context holds root, current node is passed per eval.

from std.collections import List
from std.memory import ArcPointer
from std.utils import Variant

from xyang.xpath.pratt_parser import Expr

comptime Arc = ArcPointer

# -----------------------------
# Evaluation value and context
# -----------------------------

@fieldwise_init
struct XPathNode(Movable):
    """Minimal node for path evaluation: path string only. Parent derived via _parent_path() for '..'. Extensible with data/schema later."""
    var path: String


def _parent_path(path: String) -> String:
    """Return path with last segment removed, or "" if single segment."""
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


## Result of evaluating an XPath expression: number, string, boolean, or node-set.
comptime EvalResultVariant = Variant[Float64, String, Bool, List[Arc[XPathNode]]]

comptime EvalResult = EvalResultVariant


@fieldwise_init
struct EvalContext:
    """Fixed for one expression evaluation: root node and source expression (for Token.text). Current node is passed to eval_accept.
    When validating a leaf, set current_leaf_value to the leaf's string value so '.' evaluates to it."""
    var root: Arc[XPathNode]
    var expression: String
    var current_leaf_value: String


# -----------------------------
# Eval visitor trait and dispatch
# -----------------------------

trait ExprEvalVisitor:
    def visit_number(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) raises -> EvalResult:
        return EvalResult(0.0)

    def visit_string(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) raises -> EvalResult:
        return EvalResult("")

    def visit_name(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) raises -> EvalResult:
        return EvalResult("")

    def visit_binary(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) raises -> EvalResult:
        return EvalResult(0.0)

    def visit_call(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) raises -> EvalResult:
        return EvalResult(0.0)

    def visit_path(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) raises -> EvalResult:
        return EvalResult(List[Arc[XPathNode]]())

    def visit_step(self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]) raises -> EvalResult:
        return EvalResult(List[Arc[XPathNode]]())


def eval_accept[V: ExprEvalVisitor](
    visitor: V, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
) raises -> EvalResult:
    if node.kind == Expr.NUMBER:
        return visitor.visit_number(node, ctx, current)
    if node.kind == Expr.STRING:
        return visitor.visit_string(node, ctx, current)
    if node.kind == Expr.NAME:
        return visitor.visit_name(node, ctx, current)
    if node.kind == Expr.BINARY:
        return visitor.visit_binary(node, ctx, current)
    if node.kind == Expr.CALL:
        return visitor.visit_call(node, ctx, current)
    if node.kind == Expr.PATH:
        return visitor.visit_path(node, ctx, current)
    if node.kind == Expr.STEP:
        return visitor.visit_step(node, ctx, current)
    return EvalResult(0.0)


def eval_accept[V: ExprEvalVisitor](
    visitor: V, root: Expr.ExprPointer, ctx: EvalContext, current: Arc[XPathNode]
) raises -> EvalResult:
    return eval_accept(visitor, root[], ctx, current)


# -----------------------------
# Helpers (YANG boolean, first value, comparison)
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
            return EvalResult(nodes[0][].path) # TODO resolve the path
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
        _ = r[String]
        return 0.0  # TODO: parse string to float
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
        return nodes[0][].path
    return ""


# -----------------------------
# XPathEvaluator
# -----------------------------

struct XPathEvaluator(ExprEvalVisitor):
    """Stateless XPath evaluator. Walk Expr via eval_accept; implements path, binary, literals, and basic functions."""

    fn __init__(out self):
        pass

    def eval(
        self, expr: Expr.ExprPointer, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return eval_accept(self, expr, ctx, current)

    def visit_number(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var v = node.value.text(ctx.expression)
        try:
            return EvalResult(Float64(atol(v)))
        except:
            return EvalResult(Float64(0.0))

    def visit_string(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        return EvalResult(node.value.text(ctx.expression, strip_quotes=True))

    def visit_name(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var text = node.value.text(ctx.expression)
        if text == ".":
            if len(ctx.current_leaf_value) > 0:
                return EvalResult(ctx.current_leaf_value)
            var single = List[Arc[XPathNode]]()
            single.append(current.copy())
            return EvalResult(single^)
        if text == "..":
            var pp = _parent_path(current[].path)
            if len(pp) > 0:
                var single = List[Arc[XPathNode]]()
                single.append(Arc[XPathNode](XPathNode(pp)))
                return EvalResult(single^)
            return EvalResult(List[Arc[XPathNode]]())
        return EvalResult(text)

    def visit_binary(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var op = node.value.text(ctx.expression)
        if op == "or":
            var left = eval_accept(self, node.left[], ctx, current)
            if _yang_bool(left):
                return EvalResult(True)
            return EvalResult(_yang_bool(eval_accept(self, node.right[], ctx, current)))
        if op == "and":
            var left = eval_accept(self, node.left[], ctx, current)
            if not _yang_bool(left):
                return EvalResult(False)
            return EvalResult(_yang_bool(eval_accept(self, node.right[], ctx, current)))
        if op == "/":
            return self._eval_composition(node, ctx, current)
        var left = eval_accept(self, node.left[], ctx, current)
        var right = eval_accept(self, node.right[], ctx, current)
        if op == "=":
            return EvalResult(_compare_eq(left, right))
        if op == "!=":
            return EvalResult(not _compare_eq(left, right))
        if op == "+":
            return EvalResult(_result_to_float(left) + _result_to_float(right))
        if op == "-":
            return EvalResult(_result_to_float(left) - _result_to_float(right))
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
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var left_res = eval_accept(self, node.left[], ctx, current)
        var left_nodes = _node_set_to_list(left_res)
        if not left_res.isa[List[Arc[XPathNode]]]():
            left_nodes = List[Arc[XPathNode]]()

        var results = List[Arc[XPathNode]]()
        for i in range(len(left_nodes)):
            var r = eval_accept(self, node.right[], ctx, left_nodes[i])
            var rlist = _node_set_to_list(r)
            for j in range(len(rlist)):
                results.append(rlist[j].copy())
        return EvalResult(results^)

    def visit_path(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var nodes = List[Arc[XPathNode]]()
        nodes.append(ctx.root.copy())
        for i in range(len(node.steps)):
            var next_nodes = List[Arc[XPathNode]]()
            ref step_expr = node.steps[i][]
            var step_name = step_expr.value.text(ctx.expression)
            if step_name == ".":
                next_nodes = nodes.copy()
            elif step_name == "..":
                for j in range(len(nodes)):
                    var pp = _parent_path(nodes[j][].path)
                    if len(pp) > 0:
                        next_nodes.append(Arc[XPathNode](XPathNode(pp)))
            else:
                for j in range(len(nodes)):
                    var child_path = nodes[j][].path + "/" + step_name
                    var child = XPathNode(child_path)
                    next_nodes.append(Arc[XPathNode](child^))
            nodes = next_nodes.copy()
            for k in range(len(step_expr.args)):
                nodes = self._apply_predicate(nodes, step_expr.args[k][], ctx)
        return EvalResult(nodes^)

    def _apply_predicate(
        self,
        nodes: List[Arc[XPathNode]],
        ref predicate: Expr,
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

    def visit_step(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var nodes = List[Arc[XPathNode]]()
        var step_name = node.value.text(ctx.expression)
        if step_name == ".":
            nodes.append(current.copy())
        elif step_name == "..":
            var pp = _parent_path(current[].path)
            if len(pp) > 0:
                nodes.append(Arc[XPathNode](XPathNode(pp)))
        else:
            var child_path = current[].path + "/" + step_name
            var child = XPathNode(child_path)
            nodes.append(Arc[XPathNode](child^))
        for i in range(len(node.args)):
            nodes = self._apply_predicate(nodes, node.args[i][], ctx)
        return EvalResult(nodes^)

    def visit_call(
        self, ref node: Expr, ctx: EvalContext, current: Arc[XPathNode]
    ) raises -> EvalResult:
        var name = node.value.text(ctx.expression)
        if name == "current":
            return EvalResult(current[].path) # TODO resolve the path
        if name == "true":
            return EvalResult(True)
        if name == "false":
            return EvalResult(False)
        if name == "not":
            if len(node.args) == 1:
                var a = eval_accept(self, node.args[0][], ctx, current)
                return EvalResult(not _yang_bool(a))
            return EvalResult(False)
        if name == "count":
            if len(node.args) == 1:
                var a = eval_accept(self, node.args[0][], ctx, current)
                return EvalResult(Float64(len(_node_set_to_list(a))))
            return EvalResult(0.0)
        if name == "string":
            if len(node.args) == 1:
                var a = eval_accept(self, node.args[0][], ctx, current)
                return EvalResult(_result_to_string(_first_value(a)))
            return EvalResult("")
        if name == "number":
            if len(node.args) == 1:
                var a = eval_accept(self, node.args[0][], ctx, current)
                return EvalResult(_result_to_float(_first_value(a)))
            return EvalResult(0.0)
        if name == "boolean" or name == "bool":
            if len(node.args) == 1:
                var a = eval_accept(self, node.args[0][], ctx, current)
                return EvalResult(_yang_bool(a))
            return EvalResult(False)
        if name == "position":
            return EvalResult(1.0)
        if name == "last":
            return EvalResult(1.0)
        if name == "string-length":
            if len(node.args) == 1:
                var a = eval_accept(self, node.args[0][], ctx, current)
                return EvalResult(Float64(len(_result_to_string(_first_value(a)))))
            return EvalResult(0.0)
        return EvalResult(0.0)


def eval_result_to_bool(result: EvalResult) -> Bool:
    """YANG boolean coercion of an EvalResult. Use after eval for must/when."""
    return _yang_bool(result)


def _compare_eq(left: EvalResult, right: EvalResult) -> Bool:
    var lf = _result_to_float(left)
    var rf = _result_to_float(right)
    if left.isa[Float64]() or right.isa[Float64]():
        return lf == rf
    var ls = _result_to_string(left)
    var rs = _result_to_string(right)
    return ls == rs
