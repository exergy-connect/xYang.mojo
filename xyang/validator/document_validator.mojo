## YANG document validator.
## Walks the data tree in lockstep with the schema tree (YangModule AST).
## Performs: structural (mandatory, unknown field), choice mandatory, when, type checks, must (XPath evaluator).
## Includes leafref referential integrity checks for configured leafref paths.

from std.collections import Dict
from std.memory import ArcPointer
from emberjson import Value, Object, Array
import xyang.ast as ast
from xyang.yang.parser.yang_token import YANG_TYPE_LEAFREF
from xyang.validator.validation_error import ValidationError, Severity
from xyang.validator.path_builder import PathBuilder
from xyang.validator.type_checker import (
    IntegerTypeBounds,
    check_leaf_value,
    check_leafref_reference,
    make_integer_type_bounds_table,
)
from xyang.xpath import (
    XPathNode,
    EvalContext,
    XPathEvaluator,
    eval_result_to_bool,
)

comptime Arc = ArcPointer
comptime YangModule = ast.YangModule
comptime YangContainer = ast.YangContainer
comptime YangList = ast.YangList
comptime YangChoice = ast.YangChoice
comptime YangChoiceCase = ast.YangChoiceCase
comptime YangLeaf = ast.YangLeaf
comptime YangLeafList = ast.YangLeafList
comptime YangAnydata = ast.YangAnydata
comptime YangAnyxml = ast.YangAnyxml
comptime YangMust = ast.YangMust
comptime YangType = ast.YangType
comptime YangWhen = ast.YangWhen

def _entry_key_string(entry: Value, key_names: List[String]) raises -> String:
    """Format list entry key for path, e.g. name='foo' or name='a', entity='b'."""
    if len(key_names) == 0:
        return ""
    var parts = List[String]()
    ref obj = entry.object()
    for i in range(len(key_names)):
        var k = key_names[i]
        if k in obj:
            ref v = obj[k]
            var vstr: String
            if v.is_string():
                vstr = v.string()
            elif v.is_int():
                vstr = String(v.int())
            else:
                vstr = "<value>"
            parts.append(k + "='" + vstr + "'")
    var out = ""
    for i in range(len(parts)):
        if i > 0:
            out += ", "
        out += parts[i]
    return out


def _key_names_from_key(key: String) -> List[String]:
    """Split key string (e.g. 'name entity') into list of key leaf names."""
    var split_result = key.split()
    var parts = List[String]()
    for i in range(len(split_result)):
        parts.append(String(split_result[i]))
    return parts.copy()


def _leaf_value_to_string(ref val: Value) -> String:
    """Convert a leaf Value to string for XPath current context (e.g. '.' in must)."""
    if val.is_string():
        return val.string()
    if val.is_int():
        return String(val.int())
    if val.is_uint():
        return String(val.uint())
    if val.is_float():
        return String(val.float())
    if val.is_bool():
        return "true" if val.bool() else "false"
    if val.is_null():
        return ""
    return ""


def _eval_simple_when_on_object(expr: String, obj: Object) raises -> Int:
    """Fast-path for common leaf when expressions like '../admin-up = false()'.
    Returns: 1=true, 0=false, -1=unsupported expression shape.
    """
    var parts = expr.split("=")
    if len(parts) != 2:
        return -1
    var lhs = String(String(parts[0]).strip())
    var rhs = String(String(parts[1]).strip())
    if len(lhs) < 3 or String(lhs[byte=0 : 3]) != "../":
        return -1
    if rhs != "true()" and rhs != "false()":
        return -1
    var sibling = String(lhs[byte=3 : len(lhs)])
    if sibling not in obj:
        return 0
    ref v = obj[sibling]
    if not v.is_bool():
        return 0
    var expected = rhs == "true()"
    return 1 if v.bool() == expected else 0


def _is_integer_type_name(type_name: String) -> Bool:
    return (
        type_name == "integer"
        or type_name == "int8"
        or type_name == "int16"
        or type_name == "int32"
        or type_name == "int64"
        or type_name == "uint8"
        or type_name == "uint16"
        or type_name == "uint32"
        or type_name == "uint64"
    )


def _is_float_type_name(type_name: String) -> Bool:
    return type_name == "decimal64" or type_name == "number"


def _default_text_to_value_for_type(
    default_text: String, read t: YangType
) -> Optional[Value]:
    var text = String(default_text.strip())
    var type_name = t.name
    if type_name == "boolean":
        if text == "true":
            return Optional(Value(True))
        if text == "false":
            return Optional(Value(False))
        return Optional[Value]()
    if type_name == "enumeration":
        return Optional(Value(default_text))
    if _is_integer_type_name(type_name):
        try:
            var n = Int64(atol(text))
            if t.has_range() and (n < t.range_min() or n > t.range_max()):
                return Optional[Value]()
            return Optional(Value(n))
        except:
            return Optional[Value]()
    if _is_float_type_name(type_name):
        try:
            var n = atof(text)
            if t.has_decimal64_range() and type_name == "decimal64":
                if n < t.decimal64_range_min() or n > t.decimal64_range_max():
                    return Optional[Value]()
            elif t.has_range() and (
                n < Float64(t.range_min()) or n > Float64(t.range_max())
            ):
                return Optional[Value]()
            return Optional(Value(n))
        except:
            return Optional[Value]()
    return Optional(Value(default_text))


def _default_text_to_value(default_text: String, type_stmt: YangType) -> Value:
    if type_stmt.name == "union":
        for i in range(type_stmt.union_members_len()):
            var maybe = _default_text_to_value_for_type(
                default_text, type_stmt.union_member_arc(i)[]
            )
            if maybe:
                return maybe.value().copy()
        return Value(default_text)
    var maybe = _default_text_to_value_for_type(default_text, type_stmt)
    if maybe:
        return maybe.value().copy()
    return Value(default_text)


def _string_in_list(name: String, names: List[String]) -> Bool:
    for i in range(len(names)):
        if names[i] == name:
            return True
    return False


def _case_has_any_data(read c: YangChoiceCase, obj: Object) -> Bool:
    for j in range(len(c.node_names)):
        if c.node_names[j] in obj:
            return True
    return False


def _choice_active_case_indexes(obj: Object, choice: YangChoice) -> List[Int]:
    var r = List[Int]()
    for i in range(len(choice.cases)):
        if _case_has_any_data(choice.cases[i][], obj):
            r.append(i)
    return r^


def _choice_instance_keys(obj: Object, choice: YangChoice) -> List[String]:
    var active = _choice_active_case_indexes(obj, choice)
    if len(active) == 0:
        return List[String]()
    if len(active) > 1:
        var keys = List[String]()
        for ai in range(len(active)):
            ref c = choice.cases[active[ai]][]
            for j in range(len(c.node_names)):
                var nm = c.node_names[j]
                if nm in obj and not _string_in_list(nm, keys):
                    keys.append(nm)
        return keys^
    ref c0 = choice.cases[active[0]][]
    var keys = List[String]()
    for j in range(len(c0.node_names)):
        var nm = c0.node_names[j]
        if nm in obj:
            keys.append(nm)
    return keys^


def _choice_member_choice_index_container(container: YangContainer, member: String) -> Int:
    for ci in range(len(container.choices)):
        ref ch = container.choices[ci][]
        for i in range(len(ch.cases)):
            ref c = ch.cases[i][]
            for j in range(len(c.node_names)):
                if c.node_names[j] == member:
                    return ci
    return -1


def _choice_member_choice_index_list(list_node: YangList, member: String) -> Int:
    for ci in range(len(list_node.choices)):
        ref ch = list_node.choices[ci][]
        for i in range(len(ch.cases)):
            ref c = ch.cases[i][]
            for j in range(len(c.node_names)):
                if c.node_names[j] == member:
                    return ci
    return -1


def _container_allowed_instance_keys(obj: Object, container: YangContainer) raises -> List[String]:
    var keys = List[String]()
    for i in range(len(container.leaves)):
        var nm = container.leaves[i][].name
        if _choice_member_choice_index_container(container, nm) < 0:
            if not _string_in_list(nm, keys):
                keys.append(nm)
    for i in range(len(container.leaf_lists)):
        var nm = container.leaf_lists[i][].name
        if _choice_member_choice_index_container(container, nm) < 0:
            if not _string_in_list(nm, keys):
                keys.append(nm)
    for c in container.containers:
        var nm = c[].name
        if _choice_member_choice_index_container(container, nm) < 0:
            if not _string_in_list(nm, keys):
                keys.append(nm)
    for i in range(len(container.lists)):
        var nm = container.lists[i][].name
        if _choice_member_choice_index_container(container, nm) < 0:
            if not _string_in_list(nm, keys):
                keys.append(nm)
    for i in range(len(container.anydatas)):
        var nm = container.anydatas[i][].name
        if _choice_member_choice_index_container(container, nm) < 0:
            if not _string_in_list(nm, keys):
                keys.append(nm)
    for i in range(len(container.anyxmls)):
        var nm = container.anyxmls[i][].name
        if _choice_member_choice_index_container(container, nm) < 0:
            if not _string_in_list(nm, keys):
                keys.append(nm)
    for i in range(len(container.choices)):
        var extra = _choice_instance_keys(obj, container.choices[i][])
        for j in range(len(extra)):
            if not _string_in_list(extra[j], keys):
                keys.append(extra[j])
    return keys^


def _list_allowed_instance_keys(obj: Object, list_node: YangList) raises -> List[String]:
    var keys = List[String]()
    for i in range(len(list_node.leaves)):
        var nm = list_node.leaves[i][].name
        if _choice_member_choice_index_list(list_node, nm) < 0:
            if not _string_in_list(nm, keys):
                keys.append(nm)
    for i in range(len(list_node.leaf_lists)):
        var nm = list_node.leaf_lists[i][].name
        if _choice_member_choice_index_list(list_node, nm) < 0:
            if not _string_in_list(nm, keys):
                keys.append(nm)
    for c in list_node.containers:
        var nm = c[].name
        if _choice_member_choice_index_list(list_node, nm) < 0:
            if not _string_in_list(nm, keys):
                keys.append(nm)
    for i in range(len(list_node.lists)):
        var nm = list_node.lists[i][].name
        if _choice_member_choice_index_list(list_node, nm) < 0:
            if not _string_in_list(nm, keys):
                keys.append(nm)
    for i in range(len(list_node.anydatas)):
        var nm = list_node.anydatas[i][].name
        if _choice_member_choice_index_list(list_node, nm) < 0:
            if not _string_in_list(nm, keys):
                keys.append(nm)
    for i in range(len(list_node.anyxmls)):
        var nm = list_node.anyxmls[i][].name
        if _choice_member_choice_index_list(list_node, nm) < 0:
            if not _string_in_list(nm, keys):
                keys.append(nm)
    for i in range(len(list_node.choices)):
        var extra = _choice_instance_keys(obj, list_node.choices[i][])
        for j in range(len(extra)):
            if not _string_in_list(extra[j], keys):
                keys.append(extra[j])
    return keys^


def _leaf_mandatory_must_exist(
    leaf: YangLeaf,
    obj: Object,
    enforce_mandatory_choice: Bool,
    read case_stack: List[Arc[YangChoiceCase]],
) -> Bool:
    if enforce_mandatory_choice:
        return True
    if len(case_stack) == 0:
        return True
    return _case_has_any_data(case_stack[len(case_stack) - 1][], obj)


def _open_node_mandatory_must_exist(
    mandatory: Bool,
    obj: Object,
    enforce_mandatory_choice: Bool,
    read case_stack: List[Arc[YangChoiceCase]],
) -> Bool:
    if not mandatory:
        return False
    if enforce_mandatory_choice:
        return True
    if len(case_stack) == 0:
        return True
    return _case_has_any_data(case_stack[len(case_stack) - 1][], obj)


def _case_has_other_choice_data(
    read outer_case: YangChoiceCase,
    obj: Object,
    read inner_choice: YangChoice,
) -> Bool:
    var inner = List[String]()
    for i in range(len(inner_choice.cases)):
        ref c = inner_choice.cases[i][]
        for j in range(len(c.node_names)):
            inner.append(c.node_names[j])
    for j in range(len(outer_case.node_names)):
        var nm = outer_case.node_names[j]
        if _string_in_list(nm, inner):
            continue
        if nm in obj:
            return True
    return False


def _mandatory_choice_violation(
    read choice: YangChoice,
    obj: Object,
    enforce_mandatory_choice: Bool,
    read case_stack: List[Arc[YangChoiceCase]],
) -> Bool:
    if not choice.mandatory:
        return False
    if enforce_mandatory_choice:
        return True
    if len(case_stack) == 0:
        return True
    return _case_has_other_choice_data(case_stack[len(case_stack) - 1][], obj, choice)


def _choice_has_any_branch_data(read choice: YangChoice, obj: Object) -> Bool:
    for i in range(len(choice.cases)):
        if _case_has_any_data(choice.cases[i][], obj):
            return True
    return False


def _object_get_path_value(ref root: Object, path: String) raises -> Optional[Value]:
    var raw = path.split("/")
    var segs = List[String]()
    for i in range(len(raw)):
        var t = String(String(raw[i]).strip())
        if len(t) > 0:
            segs.append(t^)
    if len(segs) == 0:
        return Optional[Value]()
    var cur_obj = root.copy()
    for si in range(len(segs)):
        var seg = segs[si]
        if seg not in cur_obj:
            return Optional[Value]()
        var v = cur_obj[seg].copy()
        if si == len(segs) - 1:
            return Optional(v^)
        if not v.is_object():
            return Optional[Value]()
        cur_obj = v.object().copy()
    return Optional[Value]()


def _unique_tuple_key_for_entry(ref entry_obj: Object, read components: List[String]) raises -> String:
    var parts = List[String]()
    for i in range(len(components)):
        var opt = _object_get_path_value(entry_obj, components[i])
        if not opt:
            parts.append("<missing>")
        else:
            parts.append(_leaf_value_to_string(opt.value()))
    var s = ""
    for i in range(len(parts)):
        if i > 0:
            s += "\x01"
        s += parts[i]
    return s


def _child_enforce_mandatory_choice_container(
    enforce_mandatory_choice: Bool,
) -> Bool:
    ## Non-presence containers inherit (RFC 7950 §7.9.4); presence not modeled — inherit parent.
    return enforce_mandatory_choice


def _child_enforce_mandatory_choice_list() -> Bool:
    return True


def _child_enforce_mandatory_choice_case() -> Bool:
    return False


def _choice_member_names(choice: YangChoice) -> List[String]:
    var names = List[String]()
    if len(choice.cases) > 0:
        for i in range(len(choice.cases)):
            ref c = choice.cases[i][]
            for j in range(len(c.node_names)):
                names.append(c.node_names[j])
        return names^
    for i in range(len(choice.case_names)):
        names.append(choice.case_names[i])
    return names^


def _find_leaf_index_by_name(leaves: List[Arc[YangLeaf]], name: String) -> Int:
    for i in range(len(leaves)):
        if leaves[i][].name == name:
            return i
    return -1


def _find_leaf_list_index_by_name(leaf_lists: List[Arc[YangLeafList]], name: String) -> Int:
    for i in range(len(leaf_lists)):
        if leaf_lists[i][].name == name:
            return i
    return -1


def _find_choice_case_index(choice: YangChoice, case_name: String) -> Int:
    for i in range(len(choice.cases)):
        if choice.cases[i][].name == case_name:
            return i
    return -1


def _active_choice_case_indexes(obj: Object, choice: YangChoice) -> List[Int]:
    var active = List[Int]()
    if len(choice.cases) > 0:
        for i in range(len(choice.cases)):
            ref c = choice.cases[i][]
            for j in range(len(c.node_names)):
                if c.node_names[j] in obj:
                    active.append(i)
                    break
        return active^
    # Backward-compatible fallback for models that only carry case_names.
    for i in range(len(choice.case_names)):
        if choice.case_names[i] in obj:
            active.append(i)
    return active^


struct DocumentValidator:
    var _errors: List[ValidationError]
    var debug_trace: Bool
    var _integer_bounds: Dict[String, IntegerTypeBounds]
    var _case_stack: List[Arc[YangChoiceCase]]

    def __init__(out self, debug_trace: Bool = False):
        self._errors = List[ValidationError]()
        self.debug_trace = debug_trace
        self._integer_bounds = make_integer_type_bounds_table()
        self._case_stack = List[Arc[YangChoiceCase]]()

    def _trace(ref self, message: String):
        if self.debug_trace:
            print("[document-validator] " + message)

    def validate(mut self, module: YangModule, data: Value) raises -> List[ValidationError]:
        """Validate root data (object) against the module. Returns list of errors."""
        self._errors = List[ValidationError]()
        self._case_stack = List[Arc[YangChoiceCase]]()
        self._trace("Start validate module='" + module.name + "'")
        if not data.is_object():
            self._trace("Root is not an object")
            self._errors.append(
                ValidationError(
                    path="/",
                    message="Root must be a JSON object",
                    expression="",
                    severity=Severity("error"),
                ),
            )
            return self._errors.copy()
        # Validate against an effective instance tree where schema defaults are realized.
        var effective_data = data.copy()
        self._realize_defaults_module(module, effective_data)
        ref root_obj = effective_data.object()
        var path = PathBuilder()
        for i in range(len(module.top_level_containers)):
            ref cont = module.top_level_containers[i][]
            if cont.name in root_obj:
                self._trace("Visit top-level container '" + cont.name + "'")
                path.push(cont.name)
                self._visit_container(
                    root_obj[cont.name],
                    cont,
                    path,
                    effective_data,
                    enforce_mandatory_choice=True,
                )
                path.pop()
        for ref pair in root_obj.items():
            var key = pair.key
            var found = False
            for i in range(len(module.top_level_containers)):
                if module.top_level_containers[i][].name == key:
                    found = True
                    break
            if not found:
                self._trace("Unknown top-level field '" + key + "'")
                self._errors.append(
                    ValidationError(
                        path="/" + key,
                        message="Unknown field '" + key + "'",
                        expression="",
                        severity=Severity("error"),
                    ),
                )
        self._trace("Validation complete with errors=" + String(len(self._errors)))
        return self._errors.copy()

    def _realize_defaults_module(mut self, module: YangModule, mut data: Value) raises:
        if not data.is_object():
            return
        ref root_obj = data.object()
        for i in range(len(module.top_level_containers)):
            ref cont = module.top_level_containers[i][]
            if cont.name in root_obj:
                self._realize_defaults_in_container(root_obj[cont.name], cont)

    def _realize_leaf_default(mut self, mut obj: Object, leaf: YangLeaf) raises:
        if leaf.name in obj or not leaf.has_default:
            return
        if leaf.has_when():
            ref when_ref = leaf.when.value()
            var simple_when = _eval_simple_when_on_object(when_ref.expression, obj)
            if simple_when == 0:
                return
            if simple_when < 0:
                # Conservative: if we cannot determine effective when context cheaply,
                # do not realize the default value.
                return
        obj[leaf.name] = _default_text_to_value(leaf.default_value, leaf.type)

    def _realize_leaf_list_default(mut self, mut obj: Object, leaf_list: YangLeafList) raises:
        if leaf_list.name in obj or len(leaf_list.default_values) == 0:
            return
        if leaf_list.has_when():
            ref when_ref = leaf_list.when.value()
            var simple_when = _eval_simple_when_on_object(when_ref.expression, obj)
            if simple_when == 0:
                return
            if simple_when < 0:
                return
        var arr = Array()
        for i in range(len(leaf_list.default_values)):
            arr.append(
                _default_text_to_value(leaf_list.default_values[i], leaf_list.type),
            )
        obj[leaf_list.name] = Value(arr^)

    def _realize_choice_defaults(
        mut self,
        mut obj: Object,
        choice: YangChoice,
        leaves: List[Arc[YangLeaf]],
        leaf_lists: List[Arc[YangLeafList]],
    ) raises:
        var active = _active_choice_case_indexes(obj, choice)
        if len(active) > 0:
            return
        if len(choice.default_case) == 0:
            return

        if len(choice.cases) > 0:
            var idx = _find_choice_case_index(choice, choice.default_case)
            if idx < 0:
                return
            ref chosen = choice.cases[idx][]
            for i in range(len(chosen.node_names)):
                var node_name = chosen.node_names[i]
                var leaf_idx = _find_leaf_index_by_name(leaves, node_name)
                if leaf_idx >= 0:
                    self._realize_leaf_default(obj, leaves[leaf_idx][])
                var leaf_list_idx = _find_leaf_list_index_by_name(leaf_lists, node_name)
                if leaf_list_idx >= 0:
                    self._realize_leaf_list_default(obj, leaf_lists[leaf_list_idx][])
            return

        # Backward-compatible fallback.
        var leaf_idx = _find_leaf_index_by_name(leaves, choice.default_case)
        if leaf_idx >= 0:
            self._realize_leaf_default(obj, leaves[leaf_idx][])
        var leaf_list_idx = _find_leaf_list_index_by_name(leaf_lists, choice.default_case)
        if leaf_list_idx >= 0:
            self._realize_leaf_list_default(obj, leaf_lists[leaf_list_idx][])

    def _realize_defaults_in_container(mut self, mut data: Value, container: YangContainer) raises:
        if not data.is_object():
            return
        ref obj = data.object()
        var choice_member_names = List[String]()
        for i in range(len(container.choices)):
            ref choice = container.choices[i][]
            var members = _choice_member_names(choice)
            for j in range(len(members)):
                choice_member_names.append(members[j])
            self._realize_choice_defaults(
                obj,
                choice,
                container.leaves,
                container.leaf_lists,
            )
        for i in range(len(container.leaves)):
            ref leaf = container.leaves[i][]
            if _string_in_list(leaf.name, choice_member_names):
                continue
            self._realize_leaf_default(obj, leaf)
        for i in range(len(container.leaf_lists)):
            ref leaf_list = container.leaf_lists[i][]
            if _string_in_list(leaf_list.name, choice_member_names):
                continue
            self._realize_leaf_list_default(obj, leaf_list)

        for i in range(len(container.containers)):
            ref child = container.containers[i][]
            if child.name in obj:
                self._realize_defaults_in_container(obj[child.name], child)
        for i in range(len(container.lists)):
            ref child_list = container.lists[i][]
            if child_list.name in obj and obj[child_list.name].is_array():
                ref arr = obj[child_list.name].array()
                for j in range(len(arr)):
                    self._realize_defaults_in_list_entry(arr[j], child_list)

    def _realize_defaults_in_list_entry(mut self, mut entry: Value, list_node: YangList) raises:
        if not entry.is_object():
            return
        ref obj = entry.object()
        var choice_member_names = List[String]()
        for i in range(len(list_node.choices)):
            ref choice = list_node.choices[i][]
            var members = _choice_member_names(choice)
            for j in range(len(members)):
                choice_member_names.append(members[j])
            self._realize_choice_defaults(
                obj,
                choice,
                list_node.leaves,
                list_node.leaf_lists,
            )
        for i in range(len(list_node.leaves)):
            ref leaf = list_node.leaves[i][]
            if _string_in_list(leaf.name, choice_member_names):
                continue
            self._realize_leaf_default(obj, leaf)
        for i in range(len(list_node.leaf_lists)):
            ref leaf_list = list_node.leaf_lists[i][]
            if _string_in_list(leaf_list.name, choice_member_names):
                continue
            self._realize_leaf_list_default(obj, leaf_list)

        for i in range(len(list_node.containers)):
            ref child = list_node.containers[i][]
            if child.name in obj:
                self._realize_defaults_in_container(obj[child.name], child)
        for i in range(len(list_node.lists)):
            ref child_list = list_node.lists[i][]
            if child_list.name in obj and obj[child_list.name].is_array():
                ref arr = obj[child_list.name].array()
                for j in range(len(arr)):
                    self._realize_defaults_in_list_entry(arr[j], child_list)

    def _visit_container(
        mut self,
        data: Value,
        container: YangContainer,
        mut path: PathBuilder,
        root_data: Value,
        enforce_mandatory_choice: Bool,
    ) raises:
        self._trace("Enter container path=" + path.current() + " schema='" + container.name + "'")
        if not data.is_object():
            self._trace("Container data is not object at path=" + path.current())
            return
        ref obj = data.object()
        self._evaluate_must_on_object_node(path.current(), obj, container.must_statements)
        var allowed = _container_allowed_instance_keys(obj, container)
        for ref pair in obj.items():
            var key = pair.key
            var known = False
            for j in range(len(allowed)):
                if allowed[j] == key:
                    known = True
                    break
            if not known:
                self._trace("Unknown field at " + path.child(key))
                self._errors.append(
                    ValidationError(
                        path=path.child(key),
                        message="Unknown field '" + key + "'",
                        expression="",
                        severity=Severity("error"),
                    ),
                )
        var child_enforce = _child_enforce_mandatory_choice_container(enforce_mandatory_choice)
        for i in range(len(container.leaves)):
            var nm = container.leaves[i][].name
            if _choice_member_choice_index_container(container, nm) >= 0:
                continue
            self._visit_leaf(obj, container.leaves[i][], path, root_data, child_enforce)
        for i in range(len(container.leaf_lists)):
            var nm = container.leaf_lists[i][].name
            if _choice_member_choice_index_container(container, nm) >= 0:
                continue
            self._visit_leaf_list(obj, container.leaf_lists[i][], path, root_data, child_enforce)
        for i in range(len(container.anydatas)):
            var nm = container.anydatas[i][].name
            if _choice_member_choice_index_container(container, nm) >= 0:
                continue
            ref ad = container.anydatas[i][]
            self._visit_untyped_data_node(
                obj,
                ad.name,
                ad.mandatory,
                ad.must_statements,
                ad.when,
                path,
                root_data,
                child_enforce,
                "anydata",
            )
        for i in range(len(container.anyxmls)):
            var nm = container.anyxmls[i][].name
            if _choice_member_choice_index_container(container, nm) >= 0:
                continue
            ref ax = container.anyxmls[i][]
            self._visit_untyped_data_node(
                obj,
                ax.name,
                ax.mandatory,
                ax.must_statements,
                ax.when,
                path,
                root_data,
                child_enforce,
                "anyxml",
            )
        for c in container.containers:
            ref child_cont = c[]
            if child_cont.name in obj:
                path.push(child_cont.name)
                self._visit_container(
                    obj[child_cont.name],
                    child_cont,
                    path,
                    root_data,
                    child_enforce,
                )
                path.pop()
        for i in range(len(container.lists)):
            self._visit_list(obj, container.lists[i][], path, root_data, child_enforce)
        for i in range(len(container.choices)):
            self._visit_choice(
                obj,
                container.choices[i][],
                path,
                root_data,
                child_enforce,
                container.leaves,
                container.leaf_lists,
                container.anydatas,
                container.anyxmls,
                container.containers,
                container.lists,
                container.choices,
            )

    def _visit_leaf(
        mut self,
        obj: Object,
        leaf: YangLeaf,
        path: PathBuilder,
        root_data: Value,
        enforce_mandatory_choice: Bool,
    ) raises:
        var name = leaf.name
        var child_path = path.child(name)
        self._trace("Check leaf path=" + child_path + " type='" + leaf.type.name + "'")
        var present = name in obj
        if not present:
            if leaf.mandatory and _leaf_mandatory_must_exist(
                leaf,
                obj,
                enforce_mandatory_choice,
                self._case_stack,
            ):
                self._trace("Mandatory leaf missing at " + child_path)
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message="Mandatory leaf '" + name + "' is missing",
                        expression="",
                        severity=Severity("error"),
                    ),
                )
            return
        ref val = obj[name]
        if val.is_null():
            if leaf.mandatory and _leaf_mandatory_must_exist(
                leaf,
                obj,
                enforce_mandatory_choice,
                self._case_stack,
            ):
                self._trace("Mandatory leaf null at " + child_path)
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message="Mandatory leaf '" + name + "' is null",
                        expression="",
                        severity=Severity("error"),
                    ),
                )
            return
        if leaf.has_when():
            ref when_ref = leaf.when.value()
            self._trace("Evaluate when at " + child_path + ": " + when_ref.expression)
            var simple_when = _eval_simple_when_on_object(when_ref.expression, obj)
            if simple_when == 0:
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message=(
                            "Node '" + name + "' is present but its 'when' condition is false"
                        ),
                        expression=when_ref.expression,
                        severity=Severity("error"),
                    ),
                )
                return
            if simple_when == 1:
                pass
            elif not when_ref.parsed or not when_ref.xpath_ast:
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message="When expression could not be parsed",
                        expression=when_ref.expression,
                        severity=Severity("error"),
                    ),
                )
                return
            else:
                try:
                    var root_node = XPathNode("/", "/")
                    var root_arc = Arc[XPathNode](root_node^)
                    var leaf_str = _leaf_value_to_string(val)
                    var current_node = XPathNode(child_path, leaf_str)
                    var current_arc = Arc[XPathNode](current_node^)
                    var ctx = EvalContext(current_arc, root_arc, when_ref.expression, 0, 0)
                    var ev = XPathEvaluator()
                    var when_result = ev.eval(when_ref.xpath_ast, ctx, current_arc)
                    if not eval_result_to_bool(when_result):
                        self._errors.append(
                            ValidationError(
                                path=child_path,
                                message=(
                                    "Node '" + name + "' is present but its 'when' condition is false"
                                ),
                                expression=when_ref.expression,
                                severity=Severity("error"),
                            ),
                        )
                        return
                except:
                    self._errors.append(
                        ValidationError(
                            path=child_path,
                            message="When expression could not be evaluated",
                            expression=when_ref.expression,
                            severity=Severity("error"),
                        ),
                    )
                    return
        var type_errors = check_leaf_value(val, leaf.type, child_path, self._integer_bounds)
        for msg in type_errors:
            self._errors.append(
                ValidationError(
                    path=child_path,
                    message=msg,
                    expression="",
                    severity=Severity("error"),
                ),
            )
        if leaf.type.name == YANG_TYPE_LEAFREF:
            if len(type_errors) > 0:
                return
            var leafref_errors = check_leafref_reference(val, leaf.type, child_path, root_data)
            for i in range(len(leafref_errors)):
                var msg = leafref_errors[i]
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message=msg,
                        expression=leaf.type.leafref_path(),
                        severity=Severity("error"),
                    ),
                )
            if len(leafref_errors) > 0:
                return
        for i in range(len(leaf.must_statements)):
            ref must_ref = leaf.must_statements[i][]
            self._trace("Evaluate must at " + child_path + ": " + must_ref.expression)
            if not must_ref.parsed or not must_ref.xpath_ast:
                if len(must_ref.expression) > 0:
                    self._errors.append(
                        ValidationError(
                            path=child_path,
                            message="Must expression could not be parsed",
                            expression=must_ref.expression,
                            severity=Severity("error"),
                        ),
                    )
                continue
            try:
                var root_node = XPathNode("/", "/")
                var root_arc = Arc[XPathNode](root_node^)
                var leaf_str = _leaf_value_to_string(val)
                var current_node = XPathNode(child_path, leaf_str)
                var current_arc = Arc[XPathNode](current_node^)
                var ctx = EvalContext(current_arc, root_arc, must_ref.expression, 0, 0)
                var ev = XPathEvaluator()
                var result = ev.eval(must_ref.xpath_ast, ctx, current_arc)
                if not eval_result_to_bool(result):
                    self._trace("Must failed at " + child_path)
                    var msg = must_ref.error_message
                    if len(msg) == 0:
                        msg = "Must constraint violated"
                    self._errors.append(
                        ValidationError(
                            path=child_path,
                            message=msg,
                            expression=must_ref.expression,
                            severity=Severity("error"),
                        ),
                    )
            except:
                self._trace("Must evaluation raised at " + child_path)
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message="Must expression could not be evaluated",
                        expression=must_ref.expression,
                        severity=Severity("error"),
                    ),
                )

    def _visit_untyped_data_node(
        mut self,
        obj: Object,
        name: String,
        mandatory: Bool,
        read must_statements: List[Arc[YangMust]],
        when_stmt: Optional[YangWhen],
        mut path: PathBuilder,
        root_data: Value,
        enforce_mandatory_choice: Bool,
        kind_keyword: String,
    ) raises:
        var child_path = path.child(name)
        self._trace("Check " + kind_keyword + " path=" + child_path)
        var present = name in obj
        if not present:
            if _open_node_mandatory_must_exist(
                mandatory,
                obj,
                enforce_mandatory_choice,
                self._case_stack,
            ):
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message="Mandatory "
                        + kind_keyword
                        + " '"
                        + name
                        + "' is missing",
                        expression="",
                        severity=Severity("error"),
                    ),
                )
            return
        ref val = obj[name]
        if val.is_null():
            if _open_node_mandatory_must_exist(
                mandatory,
                obj,
                enforce_mandatory_choice,
                self._case_stack,
            ):
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message="Mandatory "
                        + kind_keyword
                        + " '"
                        + name
                        + "' is null",
                        expression="",
                        severity=Severity("error"),
                    ),
                )
            return
        if when_stmt:
            ref when_ref = when_stmt.value()
            self._trace("Evaluate when at " + child_path + ": " + when_ref.expression)
            var simple_when = _eval_simple_when_on_object(when_ref.expression, obj)
            if simple_when == 0:
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message=(
                            "Node '"
                            + name
                            + "' is present but its 'when' condition is false"
                        ),
                        expression=when_ref.expression,
                        severity=Severity("error"),
                    ),
                )
                return
            if simple_when == 1:
                pass
            elif not when_ref.parsed or not when_ref.xpath_ast:
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message="When expression could not be parsed",
                        expression=when_ref.expression,
                        severity=Severity("error"),
                    ),
                )
                return
            else:
                try:
                    var root_node = XPathNode("/", "/")
                    var root_arc = Arc[XPathNode](root_node^)
                    var current_node = XPathNode(child_path, child_path)
                    var current_arc = Arc[XPathNode](current_node^)
                    var ctx = EvalContext(current_arc, root_arc, when_ref.expression, 0, 0)
                    var ev = XPathEvaluator()
                    var when_result = ev.eval(when_ref.xpath_ast, ctx, current_arc)
                    if not eval_result_to_bool(when_result):
                        self._errors.append(
                            ValidationError(
                                path=child_path,
                                message=(
                                    "Node '"
                                    + name
                                    + "' is present but its 'when' condition is false"
                                ),
                                expression=when_ref.expression,
                                severity=Severity("error"),
                            ),
                        )
                        return
                except:
                    self._errors.append(
                        ValidationError(
                            path=child_path,
                            message="When expression could not be evaluated",
                            expression=when_ref.expression,
                            severity=Severity("error"),
                        ),
                    )
                    return
        for i in range(len(must_statements)):
            ref must_ref = must_statements[i][]
            self._trace("Evaluate must at " + child_path + ": " + must_ref.expression)
            if not must_ref.parsed or not must_ref.xpath_ast:
                if len(must_ref.expression) > 0:
                    self._errors.append(
                        ValidationError(
                            path=child_path,
                            message="Must expression could not be parsed",
                            expression=must_ref.expression,
                            severity=Severity("error"),
                        ),
                    )
                continue
            try:
                var root_node = XPathNode("/", "/")
                var root_arc = Arc[XPathNode](root_node^)
                var current_node = XPathNode(child_path, child_path)
                var current_arc = Arc[XPathNode](current_node^)
                var ctx = EvalContext(current_arc, root_arc, must_ref.expression, 0, 0)
                var ev = XPathEvaluator()
                var result = ev.eval(must_ref.xpath_ast, ctx, current_arc)
                if not eval_result_to_bool(result):
                    var msg = must_ref.error_message
                    if len(msg) == 0:
                        msg = "Must constraint violated"
                    self._errors.append(
                        ValidationError(
                            path=child_path,
                            message=msg,
                            expression=must_ref.expression,
                            severity=Severity("error"),
                        ),
                    )
            except:
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message="Must expression could not be evaluated",
                        expression=must_ref.expression,
                        severity=Severity("error"),
                    ),
                )
        _ = root_data

    def _evaluate_must_on_object_node(
        mut self,
        node_path: String,
        obj: Object,
        read must_statements: List[Arc[YangMust]],
    ) raises:
        for i in range(len(must_statements)):
            ref must_ref = must_statements[i][]
            self._trace("Evaluate must at " + node_path + ": " + must_ref.expression)
            if not must_ref.parsed or not must_ref.xpath_ast:
                if len(must_ref.expression) > 0:
                    self._errors.append(
                        ValidationError(
                            path=node_path,
                            message="Must expression could not be parsed",
                            expression=must_ref.expression,
                            severity=Severity("error"),
                        ),
                    )
                continue
            try:
                var root_node = XPathNode("/", "/")
                var root_arc = Arc[XPathNode](root_node^)
                var current_node = XPathNode(node_path, node_path)
                var current_arc = Arc[XPathNode](current_node^)
                var ctx = EvalContext(current_arc, root_arc, must_ref.expression, 0, 0)
                var ev = XPathEvaluator()
                var result = ev.eval(must_ref.xpath_ast, ctx, current_arc)
                if not eval_result_to_bool(result):
                    var msg = must_ref.error_message
                    if len(msg) == 0:
                        msg = "Must constraint violated"
                    self._errors.append(
                        ValidationError(
                            path=node_path,
                            message=msg,
                            expression=must_ref.expression,
                            severity=Severity("error"),
                        ),
                    )
            except:
                self._errors.append(
                    ValidationError(
                        path=node_path,
                        message="Must expression could not be evaluated",
                        expression=must_ref.expression,
                        severity=Severity("error"),
                    ),
                )

    ## Returns: 1 when true, 0 when false, -1 on parse/eval error (errors appended).
    def _eval_when_on_parent_object(
        mut self,
        obj: Object,
        when_path: String,
        read when_ref: YangWhen,
    ) raises -> Int:
        var simple_when = _eval_simple_when_on_object(when_ref.expression, obj)
        if simple_when == 0:
            return 0
        if simple_when == 1:
            return 1
        if not when_ref.parsed or not when_ref.xpath_ast:
            self._errors.append(
                ValidationError(
                    path=when_path,
                    message="When expression could not be parsed",
                    expression=when_ref.expression,
                    severity=Severity("error"),
                ),
            )
            return -1
        try:
            var root_node = XPathNode("/", "/")
            var root_arc = Arc[XPathNode](root_node^)
            var current_node = XPathNode(when_path, when_path)
            var current_arc = Arc[XPathNode](current_node^)
            var ctx = EvalContext(current_arc, root_arc, when_ref.expression, 0, 0)
            var ev = XPathEvaluator()
            var when_result = ev.eval(when_ref.xpath_ast, ctx, current_arc)
            return 1 if eval_result_to_bool(when_result) else 0
        except:
            self._errors.append(
                ValidationError(
                    path=when_path,
                    message="When expression could not be evaluated",
                    expression=when_ref.expression,
                    severity=Severity("error"),
                ),
            )
            return -1

    def _list_has_duplicate_keys(
        mut self,
        read arr: Array,
        read key_names: List[String],
        list_name: String,
        list_path: String,
    ) raises -> Bool:
        if len(key_names) == 0:
            return False
        var seen = Dict[String, Int]()
        for i in range(len(arr)):
            ref entry = arr[i]
            if not entry.is_object():
                continue
            var key_str = _entry_key_string(entry, key_names)
            if key_str in seen:
                self._errors.append(
                    ValidationError(
                        path=list_path,
                        message="Duplicate key in list '"
                        + list_name
                        + "' (entries at index "
                        + String(seen[key_str])
                        + " and "
                        + String(i)
                        + ")",
                        expression="",
                        severity=Severity("error"),
                    ),
                )
                return True
            seen[key_str] = i
        return False

    def _validate_list_unique_specs(
        mut self,
        read arr: Array,
        read list_node: YangList,
        list_path: String,
    ) raises:
        for si in range(len(list_node.unique_specs)):
            ref spec = list_node.unique_specs[si]
            var seen = Dict[String, Int]()
            for ei in range(len(arr)):
                ref ent = arr[ei]
                if not ent.is_object():
                    continue
                ref entry_obj = ent.object()
                var tup = _unique_tuple_key_for_entry(entry_obj, spec)
                if tup in seen:
                    self._errors.append(
                        ValidationError(
                            path=list_path,
                            message="List '"
                            + list_node.name
                            + "': duplicate unique tuple (spec "
                            + String(si)
                            + ", entries "
                            + String(seen[tup])
                            + " and "
                            + String(ei)
                            + ")",
                            expression="",
                            severity=Severity("error"),
                        ),
                    )
                else:
                    seen[tup] = ei

    def _visit_named_schema_child(
        mut self,
        obj: Object,
        name: String,
        read pleaves: List[Arc[YangLeaf]],
        read pleaf_lists: List[Arc[YangLeafList]],
        read panydatas: List[Arc[YangAnydata]],
        read panyxmls: List[Arc[YangAnyxml]],
        read pcontainers: List[Arc[YangContainer]],
        read plists: List[Arc[YangList]],
        read pchoices: List[Arc[YangChoice]],
        mut path: PathBuilder,
        root_data: Value,
        inner_enforce: Bool,
    ) raises:
        for i in range(len(pleaves)):
            if pleaves[i][].name == name:
                self._visit_leaf(obj, pleaves[i][], path, root_data, inner_enforce)
                return
        for i in range(len(pleaf_lists)):
            if pleaf_lists[i][].name == name:
                self._visit_leaf_list(obj, pleaf_lists[i][], path, root_data, inner_enforce)
                return
        for i in range(len(panydatas)):
            if panydatas[i][].name == name:
                ref ad = panydatas[i][]
                self._visit_untyped_data_node(
                    obj,
                    ad.name,
                    ad.mandatory,
                    ad.must_statements,
                    ad.when,
                    path,
                    root_data,
                    inner_enforce,
                    "anydata",
                )
                return
        for i in range(len(panyxmls)):
            if panyxmls[i][].name == name:
                ref ax = panyxmls[i][]
                self._visit_untyped_data_node(
                    obj,
                    ax.name,
                    ax.mandatory,
                    ax.must_statements,
                    ax.when,
                    path,
                    root_data,
                    inner_enforce,
                    "anyxml",
                )
                return
        for c in pcontainers:
            ref ch = c[]
            if ch.name == name:
                if name in obj:
                    path.push(ch.name)
                    self._visit_container(obj[ch.name], ch, path, root_data, inner_enforce)
                    path.pop()
                return
        for i in range(len(plists)):
            if plists[i][].name == name:
                if name in obj:
                    self._visit_list(obj, plists[i][], path, root_data, inner_enforce)
                return
        for i in range(len(pchoices)):
            if pchoices[i][].name == name:
                self._visit_choice(
                    obj,
                    pchoices[i][],
                    path,
                    root_data,
                    inner_enforce,
                    pleaves,
                    pleaf_lists,
                    panydatas,
                    panyxmls,
                    pcontainers,
                    plists,
                    pchoices,
                )
                return

    def _visit_leaf_list(
        mut self,
        obj: Object,
        leaf_list: YangLeafList,
        path: PathBuilder,
        root_data: Value,
        enforce_mandatory_choice: Bool,
    ) raises:
        _ = enforce_mandatory_choice
        var name = leaf_list.name
        var child_path = path.child(name)
        self._trace("Check leaf-list path=" + child_path + " type='" + leaf_list.type.name + "'")
        var present = name in obj
        if not present:
            return
        ref arr_val = obj[name]
        if not arr_val.is_array():
            self._errors.append(
                ValidationError(
                    path=child_path,
                    message="'" + name + "' must be an array",
                    expression="",
                    severity=Severity("error"),
                ),
            )
            return
        if leaf_list.has_when():
            ref when_ref = leaf_list.when.value()
            self._trace("Evaluate when at " + child_path + ": " + when_ref.expression)
            var simple_when = _eval_simple_when_on_object(when_ref.expression, obj)
            if simple_when == 0:
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message=(
                            "Node '" + name + "' is present but its 'when' condition is false"
                        ),
                        expression=when_ref.expression,
                        severity=Severity("error"),
                    ),
                )
                return
            if simple_when == 1:
                pass
            elif not when_ref.parsed or not when_ref.xpath_ast:
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message="When expression could not be parsed",
                        expression=when_ref.expression,
                        severity=Severity("error"),
                    ),
                )
                return
            else:
                try:
                    var root_node = XPathNode("/", "/")
                    var root_arc = Arc[XPathNode](root_node^)
                    var current_node = XPathNode(child_path, child_path)
                    var current_arc = Arc[XPathNode](current_node^)
                    var ctx = EvalContext(current_arc, root_arc, when_ref.expression, 0, 0)
                    var ev = XPathEvaluator()
                    var when_result = ev.eval(when_ref.xpath_ast, ctx, current_arc)
                    if not eval_result_to_bool(when_result):
                        self._errors.append(
                            ValidationError(
                                path=child_path,
                                message=(
                                    "Node '" + name + "' is present but its 'when' condition is false"
                                ),
                                expression=when_ref.expression,
                                severity=Severity("error"),
                            ),
                        )
                        return
                except:
                    self._errors.append(
                        ValidationError(
                            path=child_path,
                            message="When expression could not be evaluated",
                            expression=when_ref.expression,
                            severity=Severity("error"),
                        ),
                    )
                    return
        ref arr = arr_val.array()
        var count = len(arr)
        if leaf_list.min_elements >= 0 and count < leaf_list.min_elements:
            self._errors.append(
                ValidationError(
                    path=child_path,
                    message="'"
                    + name
                    + "' has "
                    + String(count)
                    + " element(s) but requires at least "
                    + String(leaf_list.min_elements),
                    expression="",
                    severity=Severity("error"),
                ),
            )
        if leaf_list.max_elements >= 0 and count > leaf_list.max_elements:
            self._errors.append(
                ValidationError(
                    path=child_path,
                    message="'"
                    + name
                    + "' has "
                    + String(count)
                    + " element(s) but allows at most "
                    + String(leaf_list.max_elements),
                    expression="",
                    severity=Severity("error"),
                ),
            )
        for i in range(len(arr)):
            ref item = arr[i]
            var item_path = child_path + "[" + String(i) + "]"
            var type_errors = check_leaf_value(item, leaf_list.type, item_path, self._integer_bounds)
            for msg in type_errors:
                self._errors.append(
                    ValidationError(
                        path=item_path,
                        message=msg,
                        expression="",
                        severity=Severity("error"),
                    ),
                )
            if leaf_list.type.name == YANG_TYPE_LEAFREF:
                if len(type_errors) > 0:
                    continue
                var leafref_errors = check_leafref_reference(item, leaf_list.type, item_path, root_data)
                for j in range(len(leafref_errors)):
                    self._errors.append(
                        ValidationError(
                            path=item_path,
                            message=leafref_errors[j],
                            expression=leaf_list.type.leafref_path(),
                            severity=Severity("error"),
                        ),
                    )
            for j in range(len(leaf_list.must_statements)):
                ref must_ref = leaf_list.must_statements[j][]
                if not must_ref.parsed or not must_ref.xpath_ast:
                    if len(must_ref.expression) > 0:
                        self._errors.append(
                            ValidationError(
                                path=item_path,
                                message="Must expression could not be parsed",
                                expression=must_ref.expression,
                                severity=Severity("error"),
                            ),
                        )
                    continue
                try:
                    var root_node = XPathNode("/", "/")
                    var root_arc = Arc[XPathNode](root_node^)
                    var item_str = _leaf_value_to_string(item)
                    var current_node = XPathNode(item_path, item_str)
                    var current_arc = Arc[XPathNode](current_node^)
                    var ctx = EvalContext(current_arc, root_arc, must_ref.expression, 0, 0)
                    var ev = XPathEvaluator()
                    var result = ev.eval(must_ref.xpath_ast, ctx, current_arc)
                    if not eval_result_to_bool(result):
                        var msg = must_ref.error_message
                        if len(msg) == 0:
                            msg = "Must constraint violated"
                        self._errors.append(
                            ValidationError(
                                path=item_path,
                                message=msg,
                                expression=must_ref.expression,
                                severity=Severity("error"),
                            ),
                        )
                except:
                    self._errors.append(
                        ValidationError(
                            path=item_path,
                            message="Must expression could not be evaluated",
                            expression=must_ref.expression,
                            severity=Severity("error"),
                        ),
                    )

    def _visit_list(
        mut self,
        obj: Object,
        list_node: YangList,
        mut path: PathBuilder,
        root_data: Value,
        enforce_mandatory_choice: Bool,
    ) raises:
        var name = list_node.name
        self._trace("Check list path=" + path.child(name) + " schema='" + name + "'")
        var present = name in obj
        if not present:
            return
        ref arr_val = obj[name]
        if not arr_val.is_array():
            self._trace("List value is not array at " + path.child(name))
            self._errors.append(
                ValidationError(
                    path=path.child(name),
                    message="'" + name + "' must be an array",
                    expression="",
                    severity=Severity("error"),
                ),
            )
            return
        ref arr = arr_val.array()
        var list_path = path.child(name)
        self._trace("List entries at " + list_path + ": " + String(len(arr)))
        var key_names = _key_names_from_key(list_node.key)
        if self._list_has_duplicate_keys(arr, key_names, name, list_path):
            return
        var count = len(arr)
        if list_node.min_elements >= 0 and present and count < list_node.min_elements:
            self._errors.append(
                ValidationError(
                    path=list_path,
                    message="'"
                    + name
                    + "' has "
                    + String(count)
                    + " element(s) but requires at least "
                    + String(list_node.min_elements),
                    expression="",
                    severity=Severity("error"),
                ),
            )
        if list_node.max_elements >= 0 and present and count > list_node.max_elements:
            self._errors.append(
                ValidationError(
                    path=list_path,
                    message="'"
                    + name
                    + "' has "
                    + String(count)
                    + " element(s) but allows at most "
                    + String(list_node.max_elements),
                    expression="",
                    severity=Severity("error"),
                ),
            )
        self._validate_list_unique_specs(arr, list_node, list_path)
        var entry_enforce = _child_enforce_mandatory_choice_list()
        for idx in range(len(arr)):
            ref entry = arr[idx]
            var key_str = _entry_key_string(entry, key_names)
            self._trace("Visit list entry " + path.child(name, key_str))
            path.push(name, key_str)
            if entry.is_object():
                self._visit_list_entry(
                    entry.object(),
                    list_node,
                    path,
                    root_data,
                    entry_enforce,
                )
            path.pop()

    def _visit_list_entry(
        mut self,
        obj: Object,
        list_node: YangList,
        mut path: PathBuilder,
        root_data: Value,
        enforce_mandatory_choice: Bool,
    ) raises:
        self._evaluate_must_on_object_node(path.current(), obj, list_node.must_statements)
        var allowed = _list_allowed_instance_keys(obj, list_node)
        for ref pair in obj.items():
            var key = pair.key
            var known = False
            for j in range(len(allowed)):
                if allowed[j] == key:
                    known = True
                    break
            if not known:
                self._errors.append(
                    ValidationError(
                        path=path.child(key),
                        message="Unknown field '" + key + "'",
                        expression="",
                        severity=Severity("error"),
                    ),
                )
        var child_enforce = _child_enforce_mandatory_choice_container(enforce_mandatory_choice)
        for i in range(len(list_node.leaves)):
            var nm = list_node.leaves[i][].name
            if _choice_member_choice_index_list(list_node, nm) >= 0:
                continue
            self._visit_leaf(obj, list_node.leaves[i][], path, root_data, child_enforce)
        for i in range(len(list_node.leaf_lists)):
            var nm = list_node.leaf_lists[i][].name
            if _choice_member_choice_index_list(list_node, nm) >= 0:
                continue
            self._visit_leaf_list(obj, list_node.leaf_lists[i][], path, root_data, child_enforce)
        for i in range(len(list_node.anydatas)):
            var nm = list_node.anydatas[i][].name
            if _choice_member_choice_index_list(list_node, nm) >= 0:
                continue
            ref ad = list_node.anydatas[i][]
            self._visit_untyped_data_node(
                obj,
                ad.name,
                ad.mandatory,
                ad.must_statements,
                ad.when,
                path,
                root_data,
                child_enforce,
                "anydata",
            )
        for i in range(len(list_node.anyxmls)):
            var nm = list_node.anyxmls[i][].name
            if _choice_member_choice_index_list(list_node, nm) >= 0:
                continue
            ref ax = list_node.anyxmls[i][]
            self._visit_untyped_data_node(
                obj,
                ax.name,
                ax.mandatory,
                ax.must_statements,
                ax.when,
                path,
                root_data,
                child_enforce,
                "anyxml",
            )
        for c in list_node.containers:
            ref child_cont = c[]
            if child_cont.name in obj:
                path.push(child_cont.name)
                self._visit_container(
                    obj[child_cont.name],
                    child_cont,
                    path,
                    root_data,
                    child_enforce,
                )
                path.pop()
        for i in range(len(list_node.lists)):
            self._visit_list(obj, list_node.lists[i][], path, root_data, child_enforce)
        for i in range(len(list_node.choices)):
            self._visit_choice(
                obj,
                list_node.choices[i][],
                path,
                root_data,
                child_enforce,
                list_node.leaves,
                list_node.leaf_lists,
                list_node.anydatas,
                list_node.anyxmls,
                list_node.containers,
                list_node.lists,
                list_node.choices,
            )

    def _visit_choice(
        mut self,
        obj: Object,
        choice: YangChoice,
        mut path: PathBuilder,
        root_data: Value,
        enforce_mandatory_choice: Bool,
        read pleaves: List[Arc[YangLeaf]],
        read pleaf_lists: List[Arc[YangLeafList]],
        read panydatas: List[Arc[YangAnydata]],
        read panyxmls: List[Arc[YangAnyxml]],
        read pcontainers: List[Arc[YangContainer]],
        read plists: List[Arc[YangList]],
        read pchoices: List[Arc[YangChoice]],
    ) raises:
        if choice.has_when():
            ref wf = choice.when.value()
            var when_res = self._eval_when_on_parent_object(obj, path.current(), wf)
            if when_res < 0:
                return
            if when_res == 0:
                if _choice_has_any_branch_data(choice, obj):
                    self._errors.append(
                        ValidationError(
                            path=path.current(),
                            message="Choice '"
                            + choice.name
                            + "' has data but its 'when' condition is false",
                            expression=wf.expression,
                            severity=Severity("error"),
                        ),
                    )
                return

        var active = _choice_active_case_indexes(obj, choice)
        if len(active) > 1:
            var names = ""
            for i in range(len(active)):
                if i > 0:
                    names += ", "
                names += choice.cases[active[i]][].name
            self._errors.append(
                ValidationError(
                    path=path.current(),
                    message=(
                        "Choice '"
                        + choice.name
                        + "' allows only one case; data matches multiple cases: "
                        + names
                    ),
                    expression="",
                    severity=Severity("error"),
                ),
            )
            return

        if len(active) == 1:
            ref act = choice.cases[active[0]][]
            if act.has_when():
                ref cw = act.when.value()
                var case_when = self._eval_when_on_parent_object(obj, path.current(), cw)
                if case_when < 0:
                    return
                if case_when == 0:
                    if _case_has_any_data(act, obj):
                        self._errors.append(
                            ValidationError(
                                path=path.current(),
                                message="Case '"
                                + act.name
                                + "' of choice '"
                                + choice.name
                                + "' has data but its 'when' condition is false",
                                expression=cw.expression,
                                severity=Severity("error"),
                            ),
                        )
                    return
            var inner_enforce = _child_enforce_mandatory_choice_case()
            self._case_stack.append(choice.cases[active[0]].copy())
            try:
                for j in range(len(act.node_names)):
                    self._visit_named_schema_child(
                        obj,
                        act.node_names[j],
                        pleaves,
                        pleaf_lists,
                        panydatas,
                        panyxmls,
                        pcontainers,
                        plists,
                        pchoices,
                        path,
                        root_data,
                        inner_enforce,
                    )
            finally:
                _ = self._case_stack.pop()

            return

        if len(choice.default_case) > 0:
            self._trace(
                "Choice '"
                + choice.name
                + "' uses default case '"
                + choice.default_case
                + "' at "
                + path.current(),
            )
            return

        if _mandatory_choice_violation(choice, obj, enforce_mandatory_choice, self._case_stack):
            self._trace("Mandatory choice missing active case at " + path.current() + " choice='" + choice.name + "'")
            self._errors.append(
                ValidationError(
                    path=path.current(),
                    message="Mandatory choice '" + choice.name + "' has no active case",
                    expression="",
                    severity=Severity("error"),
                ),
            )
