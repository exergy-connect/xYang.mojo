## Leafref path resolution against a JSON document tree (RFC 7950 §9.9.2).
##
## Context node for ``path`` is the leafref leaf; leading ``../`` ascends the
## instance path built during validation. ``current()`` in list predicates
## refers to the leafref leaf itself (§9.9.2).

from std.collections import Dict, List
from std.memory import ArcPointer

from xyang.json.value import JsonValue, JsonArray, JsonObject, json_get, json_scalar_text
import xyang.yang.ast.util as ast_util
from xyang.yang.path import (
    YangPath,
    YangPathKeyExpression,
    YangPathPredicate,
    YangPathStep,
    YangQName,
    parse_yang_path,
)


comptime Arc = ArcPointer
comptime TargetSet = Dict[String, Bool]
comptime `_slash` = ast_util.to_byte["/"]()
comptime `[` = ast_util.to_byte["["]()
comptime `]` = ast_util.to_byte["]"]()
comptime `_0` = ast_util.to_byte["0"]()
comptime `_9` = ast_util.to_byte["9"]()


def _parent_instance_path(read p: String) -> String:
    if p.byte_length() == 0:
        return ""
    var b = p.as_bytes()
    var i = len(b) - 1
    while i > 0:
        if b[i] == `_slash`:
            return String(StringSlice(unsafe_from_utf8=b[0:i]))
        i -= 1
    return ""


def _ancestor_rev_chain(read leaf_parent_path: String) -> List[String]:
    var rev = List[String]()
    var cur = leaf_parent_path.copy()
    while True:
        rev.append(cur.copy())
        if cur.byte_length() == 0:
            break
        cur = _parent_instance_path(cur)
    return rev^


def _parse_ascii_int(read s: String) raises -> Int:
    var b = s.as_bytes()
    if len(b) == 0:
        raise Error("empty list index in instance path")
    var n = 0
    for i in range(len(b)):
        if b[i] < `_0` or b[i] > `_9`:
            raise Error("non-digit in list index")
        n = n * 10 + Int(b[i] - `_0`)
    return n


def _parse_step_segment(
    read seg: String,
) raises -> Tuple[String, Optional[Int]]:
    var b = seg.as_bytes()
    var bracket = -1
    for i in range(len(b)):
        if b[i] == `[`:
            bracket = i
            break
    if bracket < 0:
        return Tuple[String, Optional[Int]](String(seg), Optional[Int]())
    var base = String(StringSlice(unsafe_from_utf8=b[0:bracket]))
    var close = -1
    for j in range(bracket + 1, len(b)):
        if b[j] == `]`:
            close = j
            break
    if close < 0:
        raise Error("invalid instance path segment `" + seg + "`")
    var inside = String(StringSlice(unsafe_from_utf8=b[bracket + 1 : close]))
    var ix = _parse_ascii_int(inside)
    return Tuple[String, Optional[Int]](base^, Optional[Int](ix))


def _instance_path_segments(read path: String) raises -> List[String]:
    var segs = List[String]()
    var raw = path.split("/")
    for i in range(len(raw)):
        var seg = String(String(raw[i]).strip())
        if seg.byte_length() > 0:
            segs.append(seg^)
    return segs^


def _json_arc_at_path(
    read root: JsonValue, read path: String
) raises -> Arc[JsonValue]:
    var segs = _instance_path_segments(path)
    if len(segs) == 0:
        raise Error("empty instance path")
    var p0 = _parse_step_segment(segs[0])
    var nm0 = p0[0]
    var ix0 = p0[1]
    var slot0 = json_get(root, nm0)
    if not slot0:
        raise Error("instance path missing key `" + nm0 + "`")
    ref node0 = slot0.value()[]
    var cur_arc: Arc[JsonValue]
    if ix0:
        if node0.kind != JsonValue.ARRAY:
            raise Error("expected JSON array in instance path segment")
        var ixv = ix0.value()
        ref arr0 = node0.payload[JsonArray]
        if ixv < 0 or ixv >= len(arr0.values):
            raise Error("list index out of range in instance path")
        cur_arc = arr0.values[ixv].copy()
    else:
        cur_arc = slot0.value().copy()
    for sidx in range(1, len(segs)):
        ref node = cur_arc[]
        var ps = _parse_step_segment(segs[sidx])
        var nm = ps[0]
        var ix = ps[1]
        if ix:
            if node.kind != JsonValue.OBJECT:
                raise Error("expected JSON object in instance path")
            var slot = json_get(node, nm)
            if not slot:
                raise Error("instance path missing key `" + nm + "`")
            ref arrw = slot.value()[]
            if arrw.kind != JsonValue.ARRAY:
                raise Error("expected JSON array in instance path")
            var jx = ix.value()
            ref arw = arrw.payload[JsonArray]
            if jx < 0 or jx >= len(arw.values):
                raise Error("list index out of range in instance path")
            cur_arc = arw.values[jx].copy()
        else:
            if node.kind != JsonValue.OBJECT:
                raise Error("expected JSON object in instance path")
            var slot = json_get(node, nm)
            if not slot:
                raise Error("instance path missing key `" + nm + "`")
            cur_arc = slot.value().copy()
    return cur_arc^


def _join_path(read parent: String, read tail: String) -> String:
    if parent.byte_length() == 0:
        return "/" + tail
    return parent + "/" + tail


def _chain_qnames_scalar(
    read cur: JsonValue, read segments: List[YangQName], seg_idx: Int
) raises -> String:
    if seg_idx >= len(segments):
        return json_scalar_text(cur)
    var nxt = json_get(cur, segments[seg_idx].local_name)
    if not nxt:
        raise Error(
            "missing key in leafref key-expression: `"
            + segments[seg_idx].local_name
            + "`"
        )
    return _chain_qnames_scalar(nxt.value()[], segments, seg_idx + 1)


def _evaluate_key_expression(
    read root: JsonValue,
    read expr: YangPathKeyExpression,
    read path_to_current: String,
) raises -> String:
    var rev = _ancestor_rev_chain(path_to_current)
    if expr.parent_steps >= len(rev):
        raise Error("leafref key-expression has too many parent steps")
    var start_path = rev[expr.parent_steps]
    if start_path.byte_length() == 0:
        return _chain_qnames_scalar(root, expr.segments, 0)
    var start_arc = _json_arc_at_path(root, start_path)
    return _chain_qnames_scalar(start_arc[], expr.segments, 0)


def _predicate_matches(
    read root: JsonValue,
    read pred: YangPathPredicate,
    read leafref_leaf_path: String,
    read candidate_obj: JsonValue,
) raises -> Bool:
    var key_local = pred.key.local_name
    var want = _evaluate_key_expression(root, pred.target, leafref_leaf_path)
    if candidate_obj.kind != JsonValue.OBJECT:
        return False
    var got_slot = json_get(candidate_obj, key_local)
    if not got_slot:
        return False
    return json_scalar_text(got_slot.value()[]) == want


def _collect_resolved_values_from_object(
    read root: JsonValue,
    read start: JsonValue,
    read steps: List[YangPathStep],
    step_index: Int,
    read path_to_start: String,
    read leafref_leaf_path: String,
    mut out: List[String],
) raises:
    if step_index >= len(steps):
        out.append(json_scalar_text(start))
        return
    var step = steps[step_index].copy()
    var local = step.node.local_name
    if start.kind != JsonValue.OBJECT:
        return
    var child_slot = json_get(start, local)
    if not child_slot:
        return
    ref child = child_slot.value()[]
    if child.kind == JsonValue.ARRAY:
        ref ca = child.payload[JsonArray]
        for i in range(len(ca.values)):
            ref elem = ca.values[i][]
            var cand_path = _join_path(
                path_to_start, local + "[" + String(i) + "]"
            )
            var ok = True
            for pr in step.predicates:
                if not _predicate_matches(
                    root, pr, leafref_leaf_path, elem
                ):
                    ok = False
                    break
            if ok:
                _collect_resolved_values_from_object(
                    root, elem, steps, step_index + 1, cand_path,
                    leafref_leaf_path, out,
                )
        return
    var down = _join_path(path_to_start, local)
    _collect_resolved_values_from_object(
        root, child, steps, step_index + 1, down, leafref_leaf_path, out
    )


def collect_leafref_target_values(
    read root: JsonValue,
    read yang_path: YangPath,
    read leaf_parent_path: String,
) raises -> List[String]:
    var out = List[String]()
    if yang_path.absolute:
        _collect_resolved_values_from_object(
            root, root, yang_path.segments, 0, "", leaf_parent_path, out
        )
        return out^
    var rev = _ancestor_rev_chain(leaf_parent_path)
    if yang_path.parent_steps >= len(rev):
        raise Error("leafref path has too many leading `../` steps")
    var start_path = rev[yang_path.parent_steps]
    if start_path.byte_length() == 0:
        _collect_resolved_values_from_object(
            root, root, yang_path.segments, 0, "", leaf_parent_path, out
        )
    else:
        var start_arc = _json_arc_at_path(root, start_path)
        _collect_resolved_values_from_object(
            root, start_arc[], yang_path.segments, 0, start_path,
            leaf_parent_path, out,
        )
    return out^


struct LeafrefCache:
    var target_sets: Dict[String, TargetSet]

    def __init__(out self):
        self.target_sets = Dict[String, TargetSet]()

    def contains(
        mut self,
        read root: JsonValue,
        read path_argument: String,
        read leaf_parent_path: String,
        read value: String,
    ) raises -> Bool:
        var key = path_argument + "\x1f" + leaf_parent_path
        if key not in self.target_sets:
            var parsed = parse_yang_path(path_argument, 0)
            var values = collect_leafref_target_values(
                root, parsed, leaf_parent_path
            )
            var target_set = TargetSet()
            for i in range(len(values)):
                target_set[values[i]] = True
            self.target_sets[key] = target_set^
        return value in self.target_sets[key]


