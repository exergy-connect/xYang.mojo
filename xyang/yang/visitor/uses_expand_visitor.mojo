## `YangConstruct` tree walking with a **visitor trait** (same idea as `XPathExprVisitor`
## in `xyang/yang/xpath/pratt_parser.mojo` / `ASTVisitor` in `alternatives/xpath/ast.mojo`):
## default implementations recurse into children; override `visit_uses` to expand
## `grouping` bodies via `YangModule.find_grouping`.
##
## Walk the module root after parse (override `visit_uses` on a custom visitor, or
## use `UsesExpandVisitor` which inlines grouping bodies without cloning the AST):
##   var v = UsesExpandVisitor()
##   walk_yang_construct(v, yang_module, yang_module.root_construct())
##
## Deep copy with every `uses` inlined (separate traversal API):
##   var expanded = expand_uses_throughout_module(yang_module)

from std.collections import List
from std.memory import ArcPointer

from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule
from xyang.yang.spec import (
    `case`,
    `choice`,
    `container`,
    `grouping`,
    `leaf`,
    `leaf-list`,
    `list`,
    `module`,
    `typedef`,
    `uses`,
)

comptime Arc = ArcPointer


def _clone_statement_header(read n: YangConstruct) -> YangConstruct:
    var c = YangConstruct(n.keyword.copy(), n.line)
    c.spec = n.spec
    c.set_raw_argument(n.argument_text())
    return c^


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


## -----------------------------------------------------------------------------
## Visitor trait (default bodies recurse like `ASTVisitor` in alternatives/xpath).
## -----------------------------------------------------------------------------


trait YangConstructVisitor:
    def visit_leaf(
        mut self, read yang: YangModule, read node: Arc[YangConstruct]
    ) raises -> None:
        walk_yang_children(self, yang, node)

    def visit_leaf_list(
        mut self, read yang: YangModule, read node: Arc[YangConstruct]
    ) raises -> None:
        walk_yang_children(self, yang, node)

    def visit_container(
        mut self, read yang: YangModule, read node: Arc[YangConstruct]
    ) raises -> None:
        walk_yang_children(self, yang, node)

    def visit_list(
        mut self, read yang: YangModule, read node: Arc[YangConstruct]
    ) raises -> None:
        walk_yang_children(self, yang, node)

    def visit_choice(
        mut self, read yang: YangModule, read node: Arc[YangConstruct]
    ) raises -> None:
        walk_yang_children(self, yang, node)

    def visit_case(
        mut self, read yang: YangModule, read node: Arc[YangConstruct]
    ) raises -> None:
        walk_yang_children(self, yang, node)

    def visit_uses(
        mut self, read yang: YangModule, read node: Arc[YangConstruct]
    ) raises -> None:
        walk_yang_children(self, yang, node)

    def visit_grouping(
        mut self, read yang: YangModule, read node: Arc[YangConstruct]
    ) raises -> None:
        walk_yang_children(self, yang, node)

    def visit_typedef(
        mut self, read yang: YangModule, read node: Arc[YangConstruct]
    ) raises -> None:
        walk_yang_children(self, yang, node)

    def visit_yang_module(
        mut self, read yang: YangModule, read node: Arc[YangConstruct]
    ) raises -> None:
        walk_yang_children(self, yang, node)

    def visit_other(
        mut self, read yang: YangModule, read node: Arc[YangConstruct]
    ) raises -> None:
        walk_yang_children(self, yang, node)


def walk_yang_children[
    V: YangConstructVisitor
](
    mut visitor: V, read yang: YangModule, read parent: Arc[YangConstruct]
) raises -> None:
    for ch in parent[].children:
        walk_yang_construct(visitor, yang, ch)


def walk_yang_construct[
    V: YangConstructVisitor
](
    mut visitor: V, read yang: YangModule, read node: Arc[YangConstruct]
) raises -> None:
    var kw = node[].spec
    if kw == `leaf`:
        visitor.visit_leaf(yang, node)
    elif kw == `leaf-list`:
        visitor.visit_leaf_list(yang, node)
    elif kw == `container`:
        visitor.visit_container(yang, node)
    elif kw == `list`:
        visitor.visit_list(yang, node)
    elif kw == `choice`:
        visitor.visit_choice(yang, node)
    elif kw == `case`:
        visitor.visit_case(yang, node)
    elif kw == `uses`:
        visitor.visit_uses(yang, node)
    elif kw == `grouping`:
        visitor.visit_grouping(yang, node)
    elif kw == `typedef`:
        visitor.visit_typedef(yang, node)
    elif kw == `module`:
        visitor.visit_yang_module(yang, node)
    else:
        visitor.visit_other(yang, node)


## -----------------------------------------------------------------------------
## Example visitor: expand `uses` by walking grouping bodies (no AST clone).
## -----------------------------------------------------------------------------


@fieldwise_init
struct UsesExpandVisitor(YangConstructVisitor):
    ## Tracks `uses` expansion stack to reject cycles.

    var stack: List[String]

    def __init__(out self):
        self.stack = List[String]()

    def visit_uses(
        mut self, read yang: YangModule, read node: Arc[YangConstruct]
    ) raises -> None:
        if not node[].has_argument():
            return
        var gname = node[].argument_text()
        if _stack_includes(self.stack, gname):
            raise Error(
                "uses expansion cycle involving grouping `" + gname + "`"
            )
        var g = yang.find_grouping(gname)
        if not g:
            raise Error("uses expansion: unknown grouping `" + gname + "`")
        self.stack.append(gname)
        for gc in g.value()[].children:
            walk_yang_construct(self, yang, gc)
        ## Pop one grouping name (supports nested `uses` in groupings).
        var prev = List[String]()
        for i in range(len(self.stack) - 1):
            prev.append(self.stack[i])
        self.stack = prev^


## -----------------------------------------------------------------------------
## Deep copy + splice `uses` (tree materialisation, not the visitor walk).
## -----------------------------------------------------------------------------


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
            var gname = c.argument_text()
            if _stack_includes(stack, gname):
                raise Error(
                    "uses expansion cycle involving grouping `" + gname + "`"
                )
            var g = module.find_grouping(gname)
            if not g:
                raise Error("uses expansion: unknown grouping `" + gname + "`")
            var stack2 = _stack_with_name(stack, gname)
            for gc in g.value()[].children:
                out.append(Arc[YangConstruct](_expand_arc(module, gc, stack2)))
        else:
            out.append(Arc[YangConstruct](_expand_arc(module, ch, stack)))
    return out^
