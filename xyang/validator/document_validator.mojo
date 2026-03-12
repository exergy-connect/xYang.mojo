## YANG document validator.
## Walks the data tree in lockstep with the schema tree (YangModule AST).
## Performs: structural (mandatory, unknown field), choice mandatory, type checks.
## No when/must/leafref (not in current Mojo AST).

from emberjson import Value, Object
from xyang.ast import (
    YangModule,
    YangContainer,
    YangList,
    YangChoice,
    YangLeaf,
    YangType,
)
from xyang.validator.validation_error import ValidationError, Severity
from xyang.validator.path_builder import PathBuilder
from xyang.validator.type_checker import check_leaf_value


def _container_valid_child_names(container: YangContainer) -> List[String]:
    """Return set of valid child names for a container (for unknown-field check)."""
    var names = List[String]()
    for i in range(len(container.leaves)):
        names.append(container.leaves[i][].name)
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
    for c in list_node.containers:
        names.append(c[].name)
    for i in range(len(list_node.lists)):
        names.append(list_node.lists[i][].name)
    for i in range(len(list_node.choices)):
        ref ch = list_node.choices[i][]
        for j in range(len(ch.case_names)):
            names.append(ch.case_names[j])
    return names.copy()


def _entry_key_string(entry: Value, key_names: List[String]) -> String:
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


struct DocumentValidator:
    var _errors: List[ValidationError]

    def __init__(out self):
        self._errors = List[ValidationError]()

    def validate(mut self, module: YangModule, data: Value) -> List[ValidationError]:
        """Validate root data (object) against the module. Returns list of errors."""
        self._errors = List[ValidationError]()
        if not data.is_object():
            self._errors.append(
                ValidationError(
                    path="/",
                    message="Root must be a JSON object",
                    expression="",
                    severity=Severity("error"),
                ),
            )
            return self._errors.copy()
        ref root_obj = data.object()
        var path = PathBuilder()
        for i in range(len(module.top_level_containers)):
            ref cont = module.top_level_containers[i][]
            if cont.name in root_obj:
                path.push(cont.name)
                self._visit_container(root_obj[cont.name], cont, path)
                path.pop()
        for key in root_obj.keys():
            var found = False
            for i in range(len(module.top_level_containers)):
                if module.top_level_containers[i][].name == key:
                    found = True
                    break
            if not found:
                self._errors.append(
                    ValidationError(
                        path="/" + key,
                        message="Unknown field '" + key + "'",
                        expression="",
                        severity=Severity("error"),
                    ),
                )
        return self._errors.copy()

    def _visit_container(
        mut self,
        data: Value,
        container: YangContainer,
        mut path: PathBuilder,
    ) -> None:
        if not data.is_object():
            return
        ref obj = data.object()
        var valid_names = _container_valid_child_names(container)
        for key in obj.keys():
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
        for i in range(len(container.leaves)):
            self._visit_leaf(obj, container.leaves[i][], path)
        for c in container.containers:
            ref child_cont = c[]
            if child_cont.name in obj:
                path.push(child_cont.name)
                self._visit_container(obj[child_cont.name], child_cont, path)
                path.pop()
        for i in range(len(container.lists)):
            self._visit_list(obj, container.lists[i][], path)
        for i in range(len(container.choices)):
            self._visit_choice(obj, container.choices[i][], path)

    def _visit_leaf(
        mut self,
        obj: Object,
        leaf: YangLeaf,
        path: PathBuilder,
    ) -> None:
        var name = leaf.name
        var child_path = path.child(name)
        var present = name in obj
        if not present:
            if leaf.mandatory:
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
                self._errors.append(
                    ValidationError(
                        path=child_path,
                        message="Mandatory leaf '" + name + "' is missing",
                        expression="",
                        severity=Severity("error"),
                    ),
                )
            return
        for msg in check_leaf_value(val, leaf.type, child_path):
            self._errors.append(
                ValidationError(
                    path=child_path,
                    message=msg,
                    expression="",
                    severity=Severity("error"),
                ),
            )

    def _visit_list(
        mut self,
        obj: Object,
        list_node: YangList,
        mut path: PathBuilder,
    ) -> None:
        var name = list_node.name
        if name not in obj:
            return
        ref arr_val = obj[name]
        if not arr_val.is_array():
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
        var key_names = _key_names_from_key(list_node.key)
        for idx in range(len(arr)):
            ref entry = arr[idx]
            var key_str = _entry_key_string(entry, key_names)
            path.push(name, key_str)
            if entry.is_object():
                self._visit_list_entry(entry.object(), list_node, path)
            path.pop()

    def _visit_list_entry(
        mut self,
        obj: Object,
        list_node: YangList,
        mut path: PathBuilder,
    ) -> None:
        var valid_names = _list_valid_child_names(list_node)
        for key in obj.keys():
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
            self._visit_leaf(obj, list_node.leaves[i][], path)
        for c in list_node.containers:
            ref child_cont = c[]
            if child_cont.name in obj:
                path.push(child_cont.name)
                self._visit_container(obj[child_cont.name], child_cont, path)
                path.pop()
        for i in range(len(list_node.lists)):
            self._visit_list(obj, list_node.lists[i][], path)
        for i in range(len(list_node.choices)):
            self._visit_choice(obj, list_node.choices[i][], path)

    def _visit_choice(
        mut self,
        obj: Object,
        choice: YangChoice,
        path: PathBuilder,
    ) -> None:
        var active = False
        for i in range(len(choice.case_names)):
            if choice.case_names[i] in obj:
                active = True
                break
        if not active and choice.mandatory:
            self._errors.append(
                ValidationError(
                    path=path.current(),
                    message="Mandatory choice '" + choice.name + "' has no active case",
                    expression="",
                    severity=Severity("error"),
                ),
            )
