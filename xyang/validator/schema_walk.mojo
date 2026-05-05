## Resolve JSON instance keys against YANG `container` / `grouping` bodies by walking
## the statement tree, including `uses` expansion and `choice` / `case` selection
## from keys present in the instance (RFC 7950 §7.9 — case is not a data node).

from std.collections import Dict, List
from std.memory import ArcPointer

from xyang.json.parser import JsonValue
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule
from xyang.yang.spec import (
    `case`,
    `choice`,
    `container`,
    `leaf`,
    `leaf-list`,
    `list`,
    `mandatory`,
    `uses`,
)

comptime Arc = ArcPointer
comptime KeySet = Dict[String, Bool]


def _instance_key_intersects_keyset(
    read instance: JsonValue, read keys: KeySet
) -> Bool:
    if instance.kind != JsonValue.OBJECT:
        return False
    for i in range(len(instance.object_keys)):
        if instance.object_keys[i] in keys:
            return True
    return False


def _accumulate_keys_under_stmt(
    read module: YangModule,
    read stmt: Arc[YangConstruct],
    mut keys: KeySet,
) raises:
    ref n = stmt[]
    var kw = n.spec
    if (
        kw == `leaf` or kw == `leaf-list` or kw == `container` or kw == `list`
    ) and n.has_argument():
        keys[n.argument_text()] = True
        return
    if kw == `uses`:
        if not n.has_argument():
            return
        var g = module.find_grouping(n.argument_text())
        if not g:
            return
        for ch in g.value()[].children:
            _accumulate_keys_under_stmt(module, ch, keys)
        return
    if kw == `choice`:
        for ch in n.children:
            if ch[].spec != `case`:
                continue
            for inner in ch[].children:
                _accumulate_keys_under_stmt(module, inner, keys)
        return


def _keys_union_under_case(
    read module: YangModule, read case_node: YangConstruct
) raises -> KeySet:
    var keys = KeySet()
    for child in case_node.children:
        _accumulate_keys_under_stmt(module, child, keys)
    return keys^


def select_choice_case_from_instance(
    read module: YangModule,
    read choice_node: YangConstruct,
    read instance: JsonValue,
) raises -> Optional[Arc[YangConstruct]]:
    ## Return the active `case` statement for `choice_node`, or empty when no
    ## instance key belongs to any branch.
    var candidates = List[Arc[YangConstruct]]()
    for ch in choice_node.children:
        if ch[].spec != `case`:
            continue
        var ku = _keys_union_under_case(module, ch[])
        if _instance_key_intersects_keyset(instance, ku):
            candidates.append(ch.copy())
    if len(candidates) == 0:
        return Optional[Arc[YangConstruct]]()
    if len(candidates) == 1:
        return Optional[Arc[YangConstruct]](candidates[0].copy())
    raise Error(
        "ambiguous YANG `choice`: multiple cases match the same instance keys"
    )


def find_schema_child_for_json_key(
    read module: YangModule,
    read parent: YangConstruct,
    read name: String,
    read instance: JsonValue,
) raises -> Optional[Arc[YangConstruct]]:
    ## Resolve property `name` under a `container` or `grouping` body `parent`,
    ## visiting `uses` and selecting `choice` branches from `instance` keys.
    for child in parent.children:
        ref c = child[]
        var kw = c.spec
        if (
            (
                kw == `leaf`
                or kw == `leaf-list`
                or kw == `container`
                or kw == `list`
            )
            and c.has_argument()
            and c.argument_text() == name
        ):
            return Optional[Arc[YangConstruct]](child.copy())
        if kw == `uses`:
            if not c.has_argument():
                continue
            var g = module.find_grouping(c.argument_text())
            if not g:
                continue
            var found = find_schema_child_for_json_key(
                module,
                g.value()[],
                name,
                instance,
            )
            if found:
                return found^
            continue
        if kw == `choice`:
            ## RFC 7950: `case` is not a data node — instance keys are the leaves
            ## (and containers/lists) nested under a branch. Try every `case` so
            ## lookup matches the branch that actually declares `name`, not only
            ## the first branch whose key-set intersects the instance.
            for ch in c.children:
                if ch[].spec != `case`:
                    continue
                var inner = find_schema_child_for_json_key(
                    module,
                    ch[],
                    name,
                    instance,
                )
                if inner:
                    return inner^
            continue
    return Optional[Arc[YangConstruct]]()


def validate_mandatory_choices_under_container(
    read module: YangModule,
    read container: YangConstruct,
    read instance: JsonValue,
    read path: String,
    read json_path: String,
) raises:
    for child in container.children:
        ref c = child[]
        if c.spec == `uses`:
            if not c.has_argument():
                continue
            var g = module.find_grouping(c.argument_text())
            if not g:
                continue
            validate_mandatory_choices_under_container(
                module,
                g.value()[],
                instance,
                path,
                json_path,
            )
            continue
        if c.spec != `choice`:
            continue
        var m = module.find_child(c, `mandatory`)
        var is_mandatory = m and m.value()[].argument_text() == "true"
        var sel = select_choice_case_from_instance(module, c, instance)
        if is_mandatory and not sel:
            var pfx = String()
            if json_path.byte_length() > 0:
                pfx += json_path + " "
            if instance.source_line > 0:
                pfx += "line " + String(instance.source_line) + ": "
            raise Error(
                pfx
                + path
                + ": mandatory `choice` is not satisfied (no branch matches"
                " instance keys)"
            )
        if not sel:
            continue
        for inner in sel.value()[].children:
            if inner[].spec == `choice`:
                _validate_mandatory_choices_for_choice(
                    module,
                    inner[],
                    instance,
                    path,
                    json_path,
                )
            elif inner[].spec == `uses` and inner[].has_argument():
                var g2 = module.find_grouping(inner[].argument_text())
                if g2:
                    validate_mandatory_choices_under_container(
                        module,
                        g2.value()[],
                        instance,
                        path,
                        json_path,
                    )


def _validate_mandatory_choices_for_choice(
    read module: YangModule,
    read choice_node: YangConstruct,
    read instance: JsonValue,
    read path: String,
    read json_path: String,
) raises:
    var m = module.find_child(choice_node, `mandatory`)
    var is_mandatory = m and m.value()[].argument_text() == "true"
    var sel = select_choice_case_from_instance(module, choice_node, instance)
    if is_mandatory and not sel:
        var pfx = String()
        if json_path.byte_length() > 0:
            pfx += json_path + " "
        if instance.source_line > 0:
            pfx += "line " + String(instance.source_line) + ": "
        raise Error(
            pfx
            + path
            + ": mandatory `choice` is not satisfied (no branch matches"
            " instance keys)"
        )
    if not sel:
        return
    for inner in sel.value()[].children:
        if inner[].spec == `choice`:
            _validate_mandatory_choices_for_choice(
                module,
                inner[],
                instance,
                path,
                json_path,
            )
        elif inner[].spec == `uses` and inner[].has_argument():
            var g = module.find_grouping(inner[].argument_text())
            if g:
                validate_mandatory_choices_under_container(
                    module,
                    g.value()[],
                    instance,
                    path,
                    json_path,
                )
