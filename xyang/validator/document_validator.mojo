## YANG document validator.
## Walks the data tree in lockstep with the schema tree (YangModule AST).
## Performs: structural (mandatory, unknown field), choice mandatory, when, type checks, must (XPath evaluator).
## Includes leafref referential integrity checks for configured leafref paths.

from std.memory import ArcPointer
from emberjson import Value, Object, Array
from xyang.ast import (
    YangModule,
    YangContainer,
    YangList,
    YangChoice,
    YangChoiceCase,
    YangLeaf,
    YangLeafList,
    YangType,
)
from xyang.yang.tokens import YANG_TYPE_LEAFREF
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

def _container_valid_child_names(container: YangContainer) -> List[String]:
    """Return set of valid child names for a container (for unknown-field check)."""
    var names = List[String]()
    for i in range(len(container.leaves)):
        names.append(container.leaves[i][].name)
    for i in range(len(container.leaf_lists)):
        names.append(container.leaf_lists[i][].name)
    for c in container.containers:
        names.append(c[].name)
    for i in range(len(container.lists)):
        names.append(container.lists[i][].name)
    for i in range(len(container.choices)):
        ref ch = container.choices[i][]
        for j in range(len(ch.case_names)):
            names.append(ch.case_names[j])
    return names.copy()


def _list_valid_child_names(list_node: YangList) -> List[String]:
    var names = List[String]()
    for i in range(len(list_node.leaves)):
        names.append(list_node.leaves[i][].name)
    for i in range(len(list_node.leaf_lists)):
        names.append(list_node.leaf_lists[i][].name)
    for c in list_node.containers:
        names.append(c[].name)
    for i in range(len(list_node.lists)):
        names.append(list_node.lists[i][].name)
    for i in range(len(list_node.choices)):
        ref ch = list_node.choices[i][]
        for j in range(len(ch.case_names)):
            names.append(ch.case_names[j])
    return names.copy()


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


def _default_text_to_value(default_text: String, type_name: String) -> Value:
    var text = String(default_text.strip())
    if type_name == "boolean":
        if text == "true":
            return Value(True)
        if text == "false":
            return Value(False)
        return Value(default_text)
    if _is_integer_type_name(type_name):
        try:
            return Value(Int64(atol(text)))
        except:
            return Value(default_text)
    if _is_float_type_name(type_name):
        try:
            return Value(atof(text))
        except:
            return Value(default_text)
    return Value(default_text)


def _string_in_list(name: String, names: List[String]) -> Bool:
    for i in range(len(names)):
        if names[i] == name:
            return True
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

    def __init__(out self, debug_trace: Bool = False):
        self._errors = List[ValidationError]()
        self.debug_trace = debug_trace
        self._integer_bounds = make_integer_type_bounds_table()

    def _trace(ref self, message: String):
        if self.debug_trace:
            print("[document-validator] " + message)

    def validate(mut self, module: YangModule, data: Value) raises -> List[ValidationError]:
        """Validate root data (object) against the module. Returns list of errors."""
        self._errors = List[ValidationError]()
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
                self._visit_container(root_obj[cont.name], cont, path, effective_data)
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
        obj[leaf.name] = _default_text_to_value(leaf.default_value, leaf.type.name)

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
                _default_text_to_value(
                    leaf_list.default_values[i],
                    leaf_list.type.name,
                ),
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
    ) raises:
        self._trace("Enter container path=" + path.current() + " schema='" + container.name + "'")
        if not data.is_object():
            self._trace("Container data is not object at path=" + path.current())
            return
        ref obj = data.object()
        var valid_names = _container_valid_child_names(container)
        for ref pair in obj.items():
            var key = pair.key
            var known = False
            for j in range(len(valid_names)):
                if valid_names[j] == key:
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
        for i in range(len(container.leaves)):
            self._visit_leaf(obj, container.leaves[i][], path, root_data)
        for i in range(len(container.leaf_lists)):
            self._visit_leaf_list(obj, container.leaf_lists[i][], path, root_data)
        for c in container.containers:
            ref child_cont = c[]
            if child_cont.name in obj:
                path.push(child_cont.name)
                self._visit_container(obj[child_cont.name], child_cont, path, root_data)
                path.pop()
        for i in range(len(container.lists)):
            self._visit_list(obj, container.lists[i][], path, root_data)
        for i in range(len(container.choices)):
            self._visit_choice(obj, container.choices[i][], path)

    def _visit_leaf(
        mut self,
        obj: Object,
        leaf: YangLeaf,
        path: PathBuilder,
        root_data: Value,
    ) raises:
        var name = leaf.name
        var child_path = path.child(name)
        self._trace("Check leaf path=" + child_path + " type='" + leaf.type.name + "'")
        var present = name in obj
        if not present:
            if leaf.mandatory:
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
            if leaf.mandatory:
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
            elif when_ref.parsed and when_ref.xpath_ast:
                try:
                    var root_node = XPathNode("/", "/")
                    var root_arc = Arc[XPathNode](root_node^)
                    var leaf_str = _leaf_value_to_string(val)
                    var current_node = XPathNode(child_path, leaf_str)
                    var current_arc = Arc[XPathNode](current_node^)
                    var ctx = EvalContext(current_arc, root_arc, when_ref.expression)
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
                        expression=leaf.type.leafref_path,
                        severity=Severity("error"),
                    ),
                )
            if len(leafref_errors) > 0:
                return
        for i in range(len(leaf.must_statements)):
            ref must_ref = leaf.must_statements[i][]
            self._trace("Evaluate must at " + child_path + ": " + must_ref.expression)
            if not must_ref.parsed or not must_ref.xpath_ast:
                continue
            try:
                var root_node = XPathNode("/", "/")
                var root_arc = Arc[XPathNode](root_node^)
                var leaf_str = _leaf_value_to_string(val)
                var current_node = XPathNode(child_path, leaf_str)
                var current_arc = Arc[XPathNode](current_node^)
                var ctx = EvalContext(current_arc, root_arc, must_ref.expression)
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

    def _visit_leaf_list(
        mut self,
        obj: Object,
        leaf_list: YangLeafList,
        path: PathBuilder,
        root_data: Value,
    ) raises:
        var name = leaf_list.name
        var child_path = path.child(name)
        self._trace("Check leaf-list path=" + child_path + " type='" + leaf_list.type.name + "'")
        if name not in obj:
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
            if simple_when != 1 and when_ref.parsed and when_ref.xpath_ast:
                try:
                    var root_node = XPathNode("/", "/")
                    var root_arc = Arc[XPathNode](root_node^)
                    var current_node = XPathNode(child_path, child_path)
                    var current_arc = Arc[XPathNode](current_node^)
                    var ctx = EvalContext(current_arc, root_arc, when_ref.expression)
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
                            expression=leaf_list.type.leafref_path,
                            severity=Severity("error"),
                        ),
                    )
            for j in range(len(leaf_list.must_statements)):
                ref must_ref = leaf_list.must_statements[j][]
                if not must_ref.parsed or not must_ref.xpath_ast:
                    continue
                try:
                    var root_node = XPathNode("/", "/")
                    var root_arc = Arc[XPathNode](root_node^)
                    var item_str = _leaf_value_to_string(item)
                    var current_node = XPathNode(item_path, item_str)
                    var current_arc = Arc[XPathNode](current_node^)
                    var ctx = EvalContext(current_arc, root_arc, must_ref.expression)
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
    ) raises:
        var name = list_node.name
        self._trace("Check list path=" + path.child(name) + " schema='" + name + "'")
        if name not in obj:
            self._trace("List missing at " + path.child(name))
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
        self._trace("List entries at " + path.child(name) + ": " + String(len(arr)))
        var key_names = _key_names_from_key(list_node.key)
        for idx in range(len(arr)):
            ref entry = arr[idx]
            var key_str = _entry_key_string(entry, key_names)
            self._trace("Visit list entry " + path.child(name, key_str))
            path.push(name, key_str)
            if entry.is_object():
                self._visit_list_entry(entry.object(), list_node, path, root_data)
            path.pop()

    def _visit_list_entry(
        mut self,
        obj: Object,
        list_node: YangList,
        mut path: PathBuilder,
        root_data: Value,
    ) raises:
        var valid_names = _list_valid_child_names(list_node)
        for ref pair in obj.items():
            var key = pair.key
            var known = False
            for j in range(len(valid_names)):
                if valid_names[j] == key:
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
        for i in range(len(list_node.leaves)):
            self._visit_leaf(obj, list_node.leaves[i][], path, root_data)
        for i in range(len(list_node.leaf_lists)):
            self._visit_leaf_list(obj, list_node.leaf_lists[i][], path, root_data)
        for c in list_node.containers:
            ref child_cont = c[]
            if child_cont.name in obj:
                path.push(child_cont.name)
                self._visit_container(obj[child_cont.name], child_cont, path, root_data)
                path.pop()
        for i in range(len(list_node.lists)):
            self._visit_list(obj, list_node.lists[i][], path, root_data)
        for i in range(len(list_node.choices)):
            self._visit_choice(obj, list_node.choices[i][], path)

    def _visit_choice(
        mut self,
        obj: Object,
        choice: YangChoice,
        path: PathBuilder,
    ) raises:
        var active_case_names = List[String]()
        if len(choice.cases) > 0:
            for i in range(len(choice.cases)):
                ref c = choice.cases[i][]
                for j in range(len(c.node_names)):
                    if c.node_names[j] in obj:
                        active_case_names.append(c.name)
                        break
        else:
            for i in range(len(choice.case_names)):
                if choice.case_names[i] in obj:
                    active_case_names.append(choice.case_names[i])

        if len(active_case_names) > 1:
            var names = ""
            for i in range(len(active_case_names)):
                if i > 0:
                    names += ", "
                names += active_case_names[i]
            self._errors.append(
                ValidationError(
                    path=path.current(),
                    message=(
                        "Choice '" + choice.name + "' allows only one case; active cases: " + names
                    ),
                    expression="",
                    severity=Severity("error"),
                ),
            )
            return

        if len(active_case_names) == 1:
            self._trace("Choice '" + choice.name + "' active case '" + active_case_names[0] + "' at " + path.current())
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

        if choice.mandatory:
            self._trace("Mandatory choice missing active case at " + path.current() + " choice='" + choice.name + "'")
            self._errors.append(
                ValidationError(
                    path=path.current(),
                    message="Mandatory choice '" + choice.name + "' has no active case",
                    expression="",
                    severity=Severity("error"),
                ),
            )
