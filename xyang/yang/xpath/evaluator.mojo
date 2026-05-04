## XPath evaluator for XPathExpr AST.
## Stateful ``XPathEvaluator`` implements ``XPathExprVisitor``; walk via ``accept`` from ``pratt_parser``.

from std.collections import List
from std.memory import ArcPointer
from std.utils import Variant

import xyang.yang.xpath.pratt_parser as xp
from xyang.yang.xpath.token import Token

comptime Arc = ArcPointer

# -----------------------------
# Evaluation value
# -----------------------------


@fieldwise_init
struct XPathNode(Movable):
    """Minimal eval node: path plus string value used by first-value/string() on node-sets.
    """

    var path: String
    var value: String


def _parent_path(path: String) -> String:
    """Return path with last segment removed, or "" if single segment."""
    var parts = path.split("/")
    if len(parts) <= 1:
        return ""
    if len(parts) == 2 and parts[0].byte_length() == 0:
        return "/"
    var out = ""
    for i in range(len(parts) - 1):
        if i > 0:
            out += "/"
        out += parts[i]
    return out


def _path_child(parent_path: String, child_segment: String) -> String:
    """One XPath step under parent — avoids `//` when `parent` is the document root `/` or empty.
    """
    if parent_path == "":
        return child_segment
    if parent_path == "/":
        return "/" + child_segment
    return parent_path + "/" + child_segment


comptime EvalResultVariant = Variant[
    Float64, String, Bool, List[Arc[XPathNode]]
]

comptime EvalResult = EvalResultVariant


# -----------------------------
# Helpers (YANG boolean, first value, comparison)
# -----------------------------


def _yang_bool(read result: EvalResult) -> Bool:
    if result.isa[Bool]():
        return result[Bool]
    if result.isa[Float64]():
        return result[Float64] != 0.0
    if result.isa[String]():
        return result[String].byte_length() > 0
    if result.isa[List[Arc[XPathNode]]]():
        return len(result[List[Arc[XPathNode]]]) > 0
    return False


def _first_value(var result: EvalResult) -> EvalResult:
    if result.isa[List[Arc[XPathNode]]]():
        ref nodes = result[List[Arc[XPathNode]]]
        if len(nodes) > 0:
            return EvalResult(nodes[0][].value)
    return result^


def _node_set_to_list(read result: EvalResult) -> List[Arc[XPathNode]]:
    if result.isa[List[Arc[XPathNode]]]():
        return result[List[Arc[XPathNode]]].copy()
    return List[Arc[XPathNode]]()


def _result_to_float(read result: EvalResult) -> Float64:
    if result.isa[Float64]():
        return result[Float64]
    if result.isa[String]():
        _ = result[String]
        return 0.0  # TODO: parse string to float
    if result.isa[Bool]():
        return 1.0 if result[Bool] else 0.0
    if result.isa[List[Arc[XPathNode]]]():
        return Float64(len(result[List[Arc[XPathNode]]]))
    return 0.0


def _result_to_string(read result: EvalResult) -> String:
    if result.isa[String]():
        return result[String]
    if result.isa[Float64]():
        return String(result[Float64])
    if result.isa[Bool]():
        return "true" if result[Bool] else "false"
    if result.isa[List[Arc[XPathNode]]]():
        ref nodes = result[List[Arc[XPathNode]]]
        if len(nodes) == 0:
            return ""
        return nodes[0][].value
    return ""


# -----------------------------
# XPathEvaluator (visitor state: expression text, anchor, root, eval position, predicate index, result)
# -----------------------------


struct XPathEvaluator(xp.XPathExprVisitor):
    """XPath evaluation: ``eval`` builds ``XPathContext``, then ``accept``.
    """

    var anchor: Arc[XPathNode]
    var root: Arc[XPathNode]
    var eval_node: Arc[XPathNode]
    var pred_index: Int
    var pred_size: Int
    var result: EvalResult

    def __init__(out self):
        var n = XPathNode("/", "/")
        var a = Arc[XPathNode](n^)
        self.anchor = a.copy()
        self.root = a.copy()
        self.eval_node = a.copy()
        self.pred_index = 0
        self.pred_size = 0
        self.result = EvalResult(0.0)

    def eval(
        mut self,
        expr: Arc[xp.XPathExpr],
        anchor: Arc[XPathNode],
        root: Arc[XPathNode],
        var expression: String,
        current: Arc[XPathNode],
    ) raises -> EvalResult:
        self.anchor = anchor.copy()
        self.root = root.copy()
        self.eval_node = current.copy()
        self.pred_index = 0
        self.pred_size = 0
        var text = expression^
        var ctx = xp.XPathContext(text.as_bytes())
        xp.accept(self, expr, ctx)
        return self.result.copy()

    def _is_comma_list(self, ref node: xp.XPathExpr) raises -> Bool:
        return (
            node.kind() == xp.XPathExpr.BINARY
            and node.value.type == Token.COMMA
        )

    def _compare_left_against_list[
        origin: ImmutOrigin
    ](
        mut self,
        read left_value: EvalResult,
        ref list_node: xp.XPathExpr,
        ref ctx: xp.XPathContext[origin],
    ) raises -> Bool:
        if self._is_comma_list(list_node):
            ref comma_bin = list_node.payload[xp.XPathBinaryOp]
            return self._compare_left_against_list(
                left_value, comma_bin.left[], ctx
            ) or self._compare_left_against_list(
                left_value, comma_bin.right[], ctx
            )
        xp.accept(self, list_node, ctx)
        return _compare_eq(left_value, self.result)

    def visit_number[
        origin: ImmutOrigin
    ](mut self, ref expr: xp.XPathExpr, ref ctx: xp.XPathContext[origin]) raises -> None:
        var v = expr.value.text(ctx.source)
        try:
            self.result = EvalResult(Float64(atol(v)))
        except:
            self.result = EvalResult(Float64(0.0))

    def visit_string[
        origin: ImmutOrigin
    ](mut self, ref expr: xp.XPathExpr, ref ctx: xp.XPathContext[origin]) raises -> None:
        self.result = EvalResult(expr.value.text(ctx.source, strip_quotes=True))

    def visit_name[
        origin: ImmutOrigin
    ](mut self, ref expr: xp.XPathExpr, ref ctx: xp.XPathContext[origin]) raises -> None:
        var ty = expr.value.type
        if ty == Token.DOT:
            var single = List[Arc[XPathNode]]()
            single.append(self.eval_node.copy())
            self.result = EvalResult(single^)
            return
        if ty == Token.DOTDOT:
            var pp = _parent_path(self.eval_node[].path)
            if pp.byte_length() > 0:
                var single = List[Arc[XPathNode]]()
                single.append(Arc[XPathNode](XPathNode(pp, pp)))
                self.result = EvalResult(single^)
                return
            self.result = EvalResult(List[Arc[XPathNode]]())
            return
        self.result = EvalResult(expr.value.text(ctx.source))

    def visit_binary[
        origin: ImmutOrigin
    ](mut self, ref expr: xp.XPathExpr, ref ctx: xp.XPathContext[origin]) raises -> None:
        ref bin = expr.payload[xp.XPathBinaryOp]
        var ty = expr.value.type
        if ty == Token.KW_OR:
            xp.accept(self, bin.left[], ctx)
            if _yang_bool(self.result):
                self.result = EvalResult(True)
                return
            xp.accept(self, bin.right[], ctx)
            self.result = EvalResult(_yang_bool(self.result))
            return
        if ty == Token.KW_AND:
            xp.accept(self, bin.left[], ctx)
            if not _yang_bool(self.result):
                self.result = EvalResult(False)
                return
            xp.accept(self, bin.right[], ctx)
            self.result = EvalResult(_yang_bool(self.result))
            return
        if ty == Token.SLASH:
            self._eval_composition(expr, ctx)
            return
        if ty == Token.EQ:
            xp.accept(self, bin.left[], ctx)
            var left = self.result.copy()
            if self._is_comma_list(bin.right[]):
                self.result = EvalResult(
                    self._compare_left_against_list(left, bin.right[], ctx)
                )
                return
            xp.accept(self, bin.right[], ctx)
            self.result = EvalResult(_compare_eq(left, self.result))
            return
        if ty == Token.NE:
            xp.accept(self, bin.left[], ctx)
            var left = self.result.copy()
            if self._is_comma_list(bin.right[]):
                self.result = EvalResult(
                    not self._compare_left_against_list(left, bin.right[], ctx)
                )
                return
            xp.accept(self, bin.right[], ctx)
            self.result = EvalResult(not _compare_eq(left, self.result))
            return
        xp.accept(self, bin.left[], ctx)
        var left = self.result.copy()
        xp.accept(self, bin.right[], ctx)
        var right = self.result.copy()
        if ty == Token.PLUS:
            self.result = EvalResult(
                _result_to_float(left) + _result_to_float(right)
            )
            return
        if ty == Token.MINUS:
            self.result = EvalResult(
                _result_to_float(left) - _result_to_float(right)
            )
            return
        if ty == Token.LT:
            self.result = EvalResult(
                _result_to_float(left) < _result_to_float(right)
            )
            return
        if ty == Token.GT:
            self.result = EvalResult(
                _result_to_float(left) > _result_to_float(right)
            )
            return
        if ty == Token.LE:
            self.result = EvalResult(
                _result_to_float(left) <= _result_to_float(right)
            )
            return
        if ty == Token.GE:
            self.result = EvalResult(
                _result_to_float(left) >= _result_to_float(right)
            )
            return
        self.result = EvalResult(0.0)

    def _eval_composition[
        origin: ImmutOrigin
    ](mut self, ref expr: xp.XPathExpr, ref ctx: xp.XPathContext[origin]) raises -> None:
        ref bin = expr.payload[xp.XPathBinaryOp]
        xp.accept(self, bin.left[], ctx)
        var left_res = self.result.copy()
        var left_nodes = _node_set_to_list(left_res)
        if not left_res.isa[List[Arc[XPathNode]]]():
            left_nodes = List[Arc[XPathNode]]()
            if left_res.isa[String]():
                var step_name = left_res[String]
                if step_name.byte_length() > 0:
                    var child_path = _path_child(self.eval_node[].path, step_name)
                    var child = XPathNode(child_path, child_path)
                    left_nodes.append(Arc[XPathNode](child^))

        var results = List[Arc[XPathNode]]()
        var saved_eval = self.eval_node.copy()
        for i in range(len(left_nodes)):
            self.eval_node = left_nodes[i].copy()
            xp.accept(self, bin.right[], ctx)
            var r = self.result.copy()
            var rlist = _node_set_to_list(r)
            for j in range(len(rlist)):
                results.append(rlist[j].copy())
            if r.isa[String]():
                var step_name = r[String]
                if step_name.byte_length() > 0:
                    var child_path = _path_child(
                        left_nodes[i][].path, step_name
                    )
                    var child = XPathNode(child_path, child_path)
                    results.append(Arc[XPathNode](child^))
        self.eval_node = saved_eval
        self.result = EvalResult(results^)

    def visit_path[
        origin: ImmutOrigin
    ](mut self, ref expr: xp.XPathExpr, ref ctx: xp.XPathContext[origin]) raises -> None:
        ref path_node = expr.payload[xp.XPathPath]
        var saved_pred_i = self.pred_index
        var saved_pred_n = self.pred_size
        self.pred_index = 0
        self.pred_size = 0
        var nodes = List[Arc[XPathNode]]()
        nodes.append(self.root.copy())
        for i in range(len(path_node.steps)):
            var next_nodes = List[Arc[XPathNode]]()
            ref step_expr = path_node.steps[i][]
            var step_ty = step_expr.value.type
            if step_ty == Token.DOT:
                next_nodes = nodes.copy()
            elif step_ty == Token.DOTDOT:
                for j in range(len(nodes)):
                    var pp = _parent_path(nodes[j][].path)
                    if pp.byte_length() > 0:
                        next_nodes.append(Arc[XPathNode](XPathNode(pp, pp)))
            else:
                var step_name = step_expr.value.text(ctx.source)
                for j in range(len(nodes)):
                    var child_path = _path_child(nodes[j][].path, step_name)
                    var child = XPathNode(child_path, child_path)
                    next_nodes.append(Arc[XPathNode](child^))
            nodes = next_nodes.copy()
            ref step_pl = step_expr.payload[xp.XPathStep]
            for k in range(len(step_pl.predicates)):
                nodes = self._apply_predicate(nodes, step_pl.predicates[k][], ctx)
        self.pred_index = saved_pred_i
        self.pred_size = saved_pred_n
        self.result = EvalResult(nodes^)

    def _apply_predicate[
        origin: ImmutOrigin
    ](
        mut self,
        nodes: List[Arc[XPathNode]],
        ref predicate: xp.XPathExpr,
        ref ctx: xp.XPathContext[origin],
    ) raises -> List[Arc[XPathNode]]:
        var n = len(nodes)
        var results = List[Arc[XPathNode]]()
        var saved_pred_i = self.pred_index
        var saved_pred_n = self.pred_size
        var saved_eval = self.eval_node.copy()
        for i in range(n):
            self.pred_index = i + 1
            self.pred_size = n
            self.eval_node = nodes[i].copy()
            xp.accept(self, predicate, ctx)
            var keep = False
            if self.result.isa[Float64]():
                if Int(self.result[Float64]) == i + 1:
                    keep = True
            elif _yang_bool(self.result):
                keep = True
            if keep:
                results.append(nodes[i].copy())
        self.pred_index = saved_pred_i
        self.pred_size = saved_pred_n
        self.eval_node = saved_eval
        return results.copy()

    def visit_step[
        origin: ImmutOrigin
    ](mut self, ref expr: xp.XPathExpr, ref ctx: xp.XPathContext[origin]) raises -> None:
        ref st = expr.payload[xp.XPathStep]
        var nodes = List[Arc[XPathNode]]()
        var step_ty = expr.value.type
        if step_ty == Token.DOT:
            nodes.append(self.eval_node.copy())
        elif step_ty == Token.DOTDOT:
            var pp = _parent_path(self.eval_node[].path)
            if pp.byte_length() > 0:
                nodes.append(Arc[XPathNode](XPathNode(pp, pp)))
        else:
            var step_name = expr.value.text(ctx.source)
            var child_path = _path_child(self.eval_node[].path, step_name)
            var child = XPathNode(child_path, child_path)
            nodes.append(Arc[XPathNode](child^))
        for i in range(len(st.predicates)):
            nodes = self._apply_predicate(nodes, st.predicates[i][], ctx)
        self.result = EvalResult(nodes^)

    def visit_call[
        origin: ImmutOrigin
    ](mut self, ref expr: xp.XPathExpr, ref ctx: xp.XPathContext[origin]) raises -> None:
        ref c = expr.payload[xp.XPathCall]
        var callee = expr.value.text(ctx.source)
        if callee == "current":
            var single = List[Arc[XPathNode]]()
            single.append(self.anchor.copy())
            self.result = EvalResult(single^)
            return
        if callee == "true":
            self.result = EvalResult(True)
            return
        if callee == "false":
            self.result = EvalResult(False)
            return
        if callee == "not":
            if len(c.args) == 1:
                xp.accept(self, c.args[0][], ctx)
                self.result = EvalResult(not _yang_bool(self.result))
                return
            self.result = EvalResult(False)
            return
        if callee == "count":
            if len(c.args) == 1:
                xp.accept(self, c.args[0][], ctx)
                self.result = EvalResult(Float64(len(_node_set_to_list(self.result))))
                return
            self.result = EvalResult(0.0)
            return
        if callee == "string":
            if len(c.args) == 1:
                xp.accept(self, c.args[0][], ctx)
                self.result = EvalResult(
                    _result_to_string(_first_value(self.result^))
                )
                return
            self.result = EvalResult("")
            return
        if callee == "number":
            if len(c.args) == 1:
                xp.accept(self, c.args[0][], ctx)
                self.result = EvalResult(
                    _result_to_float(_first_value(self.result^))
                )
                return
            self.result = EvalResult(0.0)
            return
        if callee == "boolean" or callee == "bool":
            if len(c.args) == 1:
                xp.accept(self, c.args[0][], ctx)
                self.result = EvalResult(_yang_bool(self.result))
                return
            self.result = EvalResult(False)
            return
        if callee == "position":
            if self.pred_size > 0:
                self.result = EvalResult(Float64(self.pred_index))
                return
            self.result = EvalResult(1.0)
            return
        if callee == "last":
            if self.pred_size > 0:
                self.result = EvalResult(Float64(self.pred_size))
                return
            self.result = EvalResult(1.0)
            return
        if callee == "string-length":
            if len(c.args) == 1:
                xp.accept(self, c.args[0][], ctx)
                self.result = EvalResult(
                    Float64(
                        _result_to_string(
                            _first_value(self.result^)
                        ).byte_length()
                    )
                )
                return
            self.result = EvalResult(0.0)
            return
        self.result = EvalResult(0.0)


def eval_result_to_bool(read result: EvalResult) -> Bool:
    """YANG boolean coercion of an EvalResult. Use after eval for must/when."""
    return _yang_bool(result)


def _compare_eq(read left: EvalResult, read right: EvalResult) -> Bool:
    var lf = _result_to_float(left)
    var rf = _result_to_float(right)
    if left.isa[Float64]() or right.isa[Float64]():
        return lf == rf
    var ls = _result_to_string(left)
    var rs = _result_to_string(right)
    return ls == rs
