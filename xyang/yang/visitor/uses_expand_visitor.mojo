## Deep-copy `YangConstruct` trees with every `uses` statement replaced by the
## referenced grouping body. Clones preserve typed argument payloads.

from std.collections import List
from std.memory import ArcPointer

from xyang.yang.arguments import QNameArgument
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule
from xyang.yang.spec import (
    `if-feature`,
    `reference`,
    `refine`,
    `status`,
    `uses`,
    `when`,
)

comptime Arc = ArcPointer


def _line_prefix(line: UInt) -> String:
    if line > 0:
        return "line " + String(line) + ": "
    return ""


def _slice_string(read text: String, start: Int, end: Int) -> String:
    return String(StringSlice(unsafe_from_utf8=text.as_bytes()[start:end]))


def _uses_grouping_name(
    read module: YangModule, ref node: YangConstruct
) raises -> String:
    if node.argument.isa[QNameArgument]():
        ref qname = node.argument.get[QNameArgument]()
        var module_prefix = module.get_prefix()
        if qname.prefix != module_prefix:
            raise Error(
                _line_prefix(node.line)
                + "uses expansion: external grouping reference `"
                + node.argument_text()
                + "` uses prefix `"
                + qname.prefix
                + "`, expected local module prefix `"
                + module_prefix
                + "`"
            )
        return qname.local_name.copy()
    return node.argument_text()


def _clone_statement_header(read n: YangConstruct) -> YangConstruct:
    var c = YangConstruct(n.keyword.copy(), n.line)
    c.spec = n.spec
    c.set_argument(n.argument.copy())
    return c^


def _clone_statement(read n: YangConstruct) -> YangConstruct:
    var c = _clone_statement_header(n)
    for child in n.children:
        c.children.append(Arc[YangConstruct](_clone_statement(child[])))
    return c^


def _replace_or_append_child(mut node: YangConstruct, read stmt: YangConstruct):
    var replacement = Arc[YangConstruct](_clone_statement(stmt))
    for i in range(len(node.children)):
        if node.children[i][].spec == stmt.spec:
            node.children[i] = replacement.copy()
            return
    node.children.append(replacement^)


def _append_uses_conditionals(mut node: YangConstruct, read uses_node: YangConstruct):
    for child in uses_node.children:
        if (
            child[].spec == `when`
            or child[].spec == `if-feature`
            or child[].spec == `status`
            or child[].spec == `reference`
        ):
            node.children.append(Arc[YangConstruct](_clone_statement(child[])))


def _path_first_segment(read path: String) -> String:
    var slash = path.find("/")
    if slash < 0:
        return path.copy()
    return _slice_string(path, 0, slash)


def _path_tail(read path: String) -> String:
    var slash = path.find("/")
    if slash < 0:
        return String()
    return _slice_string(path, slash + 1, path.byte_length())


def _apply_refine(mut node: YangConstruct, read refine_stmt: YangConstruct) -> Bool:
    if not refine_stmt.has_argument():
        return False
    var segment = _path_first_segment(refine_stmt.argument_text())
    if segment != node.argument_text():
        return False
    var tail = _path_tail(refine_stmt.argument_text())
    if tail.byte_length() > 0:
        for child in node.children:
            if _apply_refine(child[], refine_stmt):
                return True
        return False
    # Refine body: only REFINE_SPEC substatements (parser-validated).
    for rchild in refine_stmt.children:
        _replace_or_append_child(node, rchild[])
    return True


def _apply_uses_refines(mut node: YangConstruct, read uses_node: YangConstruct):
    for child in uses_node.children:
        if child[].spec == `refine`:
            _ = _apply_refine(node, child[])


def _stack_includes(read stack: List[String], read name: String) -> Bool:
    for i in range(len(stack)):
        if stack[i] == name:
            return True
    return False


def _stack_with_name(
    read stack: List[String], read name: String
) -> List[String]:
    var out = List[String]()
    for i in range(len(stack)):
        out.append(stack[i])
    out.append(name)
    return out^


def expand_uses_throughout_module(
    read module: YangModule,
) raises -> YangConstruct:
    """Return a new module root with every ``uses`` replaced by expanded grouping children.
    """
    var root = module.root_construct()
    return _expand_arc(module, root, List[String]())


def expand_construct(
    read module: YangModule, read node: Arc[YangConstruct]
) raises -> YangConstruct:
    """Expand ``uses`` under ``node`` into a new ``YangConstruct`` subtree."""
    return _expand_arc(module, node, List[String]())


def _expand_arc(
    read module: YangModule,
    read node: Arc[YangConstruct],
    stack: List[String],
) raises -> YangConstruct:
    ref n = node[]
    var out = _clone_statement_header(n)
    out.children = _expand_child_list(module, n.children, stack)
    return out^


def _expand_child_list(
    read module: YangModule,
    read children: List[Arc[YangConstruct]],
    stack: List[String],
) raises -> List[Arc[YangConstruct]]:
    var out = List[Arc[YangConstruct]]()
    for ch in children:
        ref c = ch[]
        if c.spec == `uses` and c.has_argument():
            var gname = _uses_grouping_name(module, c)
            if _stack_includes(stack, gname):
                raise Error(
                    "uses expansion cycle involving grouping `" + gname + "`"
                )
            var g = module.find_grouping(gname)
            if not g:
                raise Error("uses expansion: unknown grouping `" + gname + "`")
            var stack2 = _stack_with_name(stack, gname)
            var expanded_children = _expand_child_list(
                module, g.value()[].children, stack2
            )
            for expanded_child in expanded_children:
                var expanded = _clone_statement(expanded_child[])
                _append_uses_conditionals(expanded, c)
                _apply_uses_refines(expanded, c)
                out.append(Arc[YangConstruct](expanded^))
        else:
            out.append(Arc[YangConstruct](_expand_arc(module, ch, stack)))
    return out^
