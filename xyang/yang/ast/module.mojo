## Parsed YANG module: root tree plus header fields and indexes.

from std.collections import Dict, List
from std.iter import Iterable, Iterator
from std.memory import ArcPointer

from .construct import YangConstruct
from .lexer import AstLexer
from .parser import parse_module
from .util import _strip_spaces
from ..arguments import (
    LengthSegment,
    RangeBounds,
    YangPatternSpec,
    length_allows_scalar_count,
    try_parse_length_segments,
    try_parse_range_segments,
)
from ..keyword import Keyword
from ..xpath.pratt_parser import (
    XPathBinaryOp,
    XPathCall,
    XPathExpr,
    XPathPath,
    XPathStep,
)
from ..xpath.api import parse_xpath_expression, xpath_slash_expr_to_path
from ..xpath.token import Token


comptime Arc = ArcPointer
comptime ConstructMap = Dict[String, Arc[YangConstruct]]
comptime ModuleFieldMap = Dict[Keyword, Arc[YangConstruct]]


@always_inline
def _insert_unique(
    mut table: ConstructMap,
    read name: String,
    read child: Arc[YangConstruct],
) raises:
    table[name] = child.copy()


def _slice_string(read text: String, start: Int, end: Int) -> String:
    return String(StringSlice(unsafe_from_utf8=text.as_bytes()[start:end]))


def _is_if_feature_name_byte(c: UInt8) -> Bool:
    var v = Int(c)
    return (
        (v >= ord("a") and v <= ord("z"))
        or (v >= ord("A") and v <= ord("Z"))
        or (v >= ord("0") and v <= ord("9"))
        or v == ord("_")
        or v == ord("-")
        or v == ord(".")
        or v == ord(":")
    )


def _local_feature_name(read name: String) -> String:
    var sep = name.find(":")
    if sep < 0:
        return name.copy()
    return _slice_string(name, sep + 1, name.byte_length())


def _local_name(read name: String) -> String:
    """Strip optional ``prefix:`` qualifier, returning the local part."""
    var sep = name.find(":")
    if sep < 0:
        return name.copy()
    return _slice_string(name, sep + 1, name.byte_length())


@fieldwise_init
struct IfFeatureExprParser(Movable):
    var text: String
    var pos: Int

    def __init__(out self, read text: String):
        self.text = text.copy()
        self.pos = 0

    def at_end(read self) -> Bool:
        return self.pos >= self.text.byte_length()

    def remaining(read self) -> String:
        return _slice_string(self.text, self.pos, self.text.byte_length())

    def skip_ws(mut self):
        var b = self.text.as_bytes()
        while self.pos < len(b):
            var c = b[self.pos]
            if (
                c == UInt8(ord(" "))
                or c == UInt8(ord("\n"))
                or c == UInt8(ord("\r"))
                or c == UInt8(ord("\t"))
            ):
                self.pos += 1
            else:
                return

    def consume_keyword(mut self, read keyword: String) -> Bool:
        self.skip_ws()
        var n = keyword.byte_length()
        if self.pos + n > self.text.byte_length():
            return False
        if _slice_string(self.text, self.pos, self.pos + n) != keyword:
            return False
        if self.pos + n < self.text.byte_length():
            var next = self.text.as_bytes()[self.pos + n]
            if _is_if_feature_name_byte(next):
                return False
        self.pos += n
        return True

    def consume_byte(mut self, c: UInt8) -> Bool:
        self.skip_ws()
        if self.pos >= self.text.byte_length():
            return False
        if self.text.as_bytes()[self.pos] != c:
            return False
        self.pos += 1
        return True

    def parse_name(mut self) raises -> String:
        self.skip_ws()
        var start = self.pos
        var b = self.text.as_bytes()
        while self.pos < len(b) and _is_if_feature_name_byte(b[self.pos]):
            self.pos += 1
        if self.pos == start:
            raise Error(
                "expected feature name in if-feature expression near `"
                + self.remaining()
                + "`"
            )
        return _slice_string(self.text, start, self.pos)

@fieldwise_init
struct TopContainerIterator(Iterator):
    comptime Element = Arc[YangConstruct]

    var root: Optional[Arc[YangConstruct]]
    var index: Int

    def __init__(out self, root: Optional[Arc[YangConstruct]]):
        self.root = root.copy()
        self.index = 0

    def __next__(mut self) raises StopIteration -> Self.Element:
        from ..spec import `container`

        if not self.root:
            raise StopIteration()
        ref root = self.root.value()[]
        while self.index < len(root.children):
            var i = self.index
            self.index += 1
            var child = root.children[i]
            if child[].spec == `container`:
                return child.copy()
        raise StopIteration()


@fieldwise_init
struct YangModule(Movable & Iterable):
    comptime IteratorType[
        iterable_mut: Bool, //, iterable_origin: Origin[mut=iterable_mut]
    ]: Iterator = TopContainerIterator

    var root: Optional[Arc[YangConstruct]]
    var fields: ModuleFieldMap
    var revisions: List[String]
    var groupings: ConstructMap
    var typedefs: ConstructMap
    var identities: ConstructMap
    var features: ConstructMap
    var feature_names: List[String]
    var feature_enabled: Dict[String, Bool]
    var top_containers: ConstructMap

    def __init__(out self):
        self.root = Optional[Arc[YangConstruct]]()
        self.fields = ModuleFieldMap()
        self.revisions = List[String]()
        self.groupings = ConstructMap()
        self.typedefs = ConstructMap()
        self.identities = ConstructMap()
        self.features = ConstructMap()
        self.feature_names = List[String]()
        self.feature_enabled = Dict[String, Bool]()
        self.top_containers = ConstructMap()

    def parse[
        origin: ImmutOrigin
    ](mut self, mut lexer: AstLexer[origin]) raises:
        var tree = parse_module(lexer)
        self.ingest_construct_tree(tree^)

    def ingest_construct_tree(mut self, var tree: YangConstruct) raises:
        """Validate a module `YangConstruct` root, index it, and take ownership as `root`.

        Used by the text parser and by JSON (`parse_yang_json_module`) so both
        front ends share one path: spec validation, `_populate_from_validated_tree`,
        and `root` assignment.
        """
        from ..spec import `module`, build_spec_table

        var specs = build_spec_table()
        specs[Int(`module`)].validate(tree, specs)
        self.root = Optional[Arc[YangConstruct]](Arc[YangConstruct](tree^))
        self._populate_from_validated_root()
        self._validate_semantics()

    def _populate_from_validated_root(mut self) raises:
        from ..spec import (
            `container`,
            `feature`,
            `grouping`,
            `identity`,
            `if-feature`,
            `revision`,
            `typedef`,
        )

        ref root_arc = self.root.value()
        for child in root_arc[].children:
            ref node = child[]
            var arg = node.argument_text()
            var kw = node.spec
            if kw == `revision`:
                self.revisions.append(arg)
            elif kw == `feature`:
                _insert_unique(self.features, arg, child)
                self.feature_names.append(arg)
                self.feature_enabled[arg] = False
            elif kw == `grouping`:
                _insert_unique(self.groupings, arg, child)
            elif kw == `typedef`:
                _insert_unique(self.typedefs, arg, child)
            elif kw == `identity`:
                _insert_unique(self.identities, arg, child)
            elif kw == `container`:
                _insert_unique(self.top_containers, arg, child)
            else:
                self.fields[kw] = child.copy()
        self._resolve_feature_enablement()

    def _resolve_feature_enablement(mut self) raises:
        from ..spec import `if-feature`

        comptime MAX_FEATURE_PASSES = 128
        for _ in range(MAX_FEATURE_PASSES):
            var changed = False
            for name in self.feature_names:
                ref stmt = self.features[name][]
                var enabled = True
                for child in stmt.children:
                    if child[].spec == `if-feature` and child[].has_argument():
                        if not self.if_feature_expr_enabled(
                            child[].argument_text()
                        ):
                            enabled = False
                            break
                if self.feature_enabled[name] != enabled:
                    self.feature_enabled[name] = enabled
                    changed = True
            if not changed:
                return
        raise Error("feature dependency chain too deep or cyclic")

    def is_feature_enabled(read self, read name: String) raises -> Bool:
        var local = _local_feature_name(name)
        if local not in self.feature_enabled:
            return False
        return self.feature_enabled[local]

    def if_feature_expr_enabled(
        read self, read expression: String
    ) raises -> Bool:
        var parser = IfFeatureExprParser(expression)
        var result = _parse_if_feature_or(parser, self)
        parser.skip_ws()
        if not parser.at_end():
            raise Error(
                "invalid if-feature expression near `"
                + parser.remaining()
                + "`"
            )
        return result

    def construct_if_features_enabled(
        read self, read node: YangConstruct
    ) raises -> Bool:
        from ..spec import `if-feature`

        for child in node.children:
            if child[].spec == `if-feature` and child[].has_argument():
                if not self.if_feature_expr_enabled(child[].argument_text()):
                    return False
        return True

    def is_construct_active(read self, read node: YangConstruct) raises -> Bool:
        return self.construct_if_features_enabled(node)

    def root_construct(read self) raises -> Arc[YangConstruct]:
        if not self.root:
            raise Error("YANG module has no parsed root construct")
        return self.root.value().copy()

    def field(read self, kw: Keyword) raises -> Optional[Arc[YangConstruct]]:
        if kw not in self.fields:
            return Optional[Arc[YangConstruct]]()
        return Optional[Arc[YangConstruct]](self.fields[kw].copy())

    @always_inline
    def _field_argument_text_optional(
        read self, kw: Keyword
    ) raises -> Optional[String]:
        var stmt = self.field(kw)
        if not stmt:
            return Optional[String]()
        ref n = stmt.value()[]
        if not n.has_argument():
            return Optional[String]()
        return Optional[String](n.argument_text())

    @always_inline
    def _field_argument_text_required(read self, kw: Keyword) raises -> String:
        ref n = self.fields[kw][]
        if n.has_argument():
            return n.argument_text()
        return ""

    def get_name(read self) raises -> String:
        if not self.root:
            return ""
        ref root_node = self.root.value()[]
        if root_node.has_argument():
            return root_node.argument_text()
        return ""

    def get_yang_version(read self) raises -> Optional[String]:
        from ..spec import `yang-version`

        return self._field_argument_text_optional(`yang-version`)

    def get_namespace(read self) raises -> String:
        from ..spec import `namespace`

        return self._field_argument_text_required(`namespace`)

    def get_prefix(read self) raises -> String:
        from ..spec import `prefix`

        return self._field_argument_text_required(`prefix`)

    def get_organization(read self) raises -> Optional[String]:
        from ..spec import `organization`

        return self._field_argument_text_optional(`organization`)

    def get_contact(read self) raises -> Optional[String]:
        from ..spec import `contact`

        return self._field_argument_text_optional(`contact`)

    def get_description(read self) raises -> Optional[String]:
        from ..spec import `description`

        return self._field_argument_text_optional(`description`)

    def get_revisions(read self) -> List[String]:
        return self.revisions.copy()

    def get_top_level_containers(
        ref self,
    ) -> ref[self.top_containers] ConstructMap:
        return self.top_containers

    def __iter__(ref self) -> Self.IteratorType[origin_of(self)]:
        return TopContainerIterator(self.root)

    def grouping(
        ref self, read name: String
    ) raises -> Optional[Arc[YangConstruct]]:
        if name not in self.groupings:
            return Optional[Arc[YangConstruct]]()
        return Optional[Arc[YangConstruct]](self.groupings[name].copy())

    def typedef(
        ref self, read name: String
    ) raises -> Optional[Arc[YangConstruct]]:
        if name not in self.typedefs:
            return Optional[Arc[YangConstruct]]()
        return Optional[Arc[YangConstruct]](self.typedefs[name].copy())

    def top_container(
        ref self, read name: String
    ) raises -> Optional[Arc[YangConstruct]]:
        if name not in self.top_containers:
            return Optional[Arc[YangConstruct]]()
        return Optional[Arc[YangConstruct]](self.top_containers[name].copy())

    def find_child(
        read self, read node: YangConstruct, keyword: Keyword
    ) -> Optional[Arc[YangConstruct]]:
        for child in node.children:
            if child[].spec == keyword:
                return Optional[Arc[YangConstruct]](child.copy())
        return Optional[Arc[YangConstruct]]()

    def find_grouping(
        read self, read name: String
    ) raises -> Optional[Arc[YangConstruct]]:
        if name not in self.groupings:
            return Optional[Arc[YangConstruct]]()
        return Optional[Arc[YangConstruct]](self.groupings[name].copy())

    def is_leaf_name_in_uses(
        read self, read parent: YangConstruct, name: String
    ) raises -> Bool:
        from ..spec import `leaf`, `uses`

        for child in parent.children:
            if child[].spec != `uses` or not child[].has_argument():
                continue
            var grouping = self.find_grouping(child[].argument_text())
            if not grouping:
                continue
            for gchild in grouping.value()[].children:
                if (
                    gchild[].spec == `leaf`
                    and gchild[].has_argument()
                    and gchild[].argument_text() == name
                ):
                    return True
        return False

    def find_effective_leaf(
        read self, read parent: YangConstruct, name: String
    ) raises -> Optional[Arc[YangConstruct]]:
        from ..spec import `leaf`, `uses`

        for child in parent.children:
            if (
                child[].spec == `leaf`
                and child[].has_argument()
                and child[].argument_text() == name
            ):
                return Optional[Arc[YangConstruct]](child.copy())
        for child in parent.children:
            if child[].spec != `uses` or not child[].has_argument():
                continue
            var grouping = self.find_grouping(child[].argument_text())
            if not grouping:
                continue
            var leaf = self.find_effective_leaf(grouping.value()[], name)
            if leaf:
                return leaf^
        return Optional[Arc[YangConstruct]]()

    def find_effective_child(
        read self,
        read parent: YangConstruct,
        keyword: Keyword,
        name: String,
    ) -> Optional[Arc[YangConstruct]]:
        for child in parent.children:
            if (
                child[].spec == keyword
                and child[].has_argument()
                and child[].argument_text() == name
            ):
                return Optional[Arc[YangConstruct]](child.copy())
        return Optional[Arc[YangConstruct]]()

    def leaf_effective_type_stmt(
        read self, read leaf: YangConstruct
    ) raises -> Optional[Arc[YangConstruct]]:
        from ..spec import `type`

        var cur_ty = self.find_child(leaf, `type`)
        if not cur_ty:
            return Optional[Arc[YangConstruct]]()
        comptime _MAX_TYPEDEF_STEPS = 128
        for _ in range(_MAX_TYPEDEF_STEPS):
            ref cur = cur_ty.value()[]
            if not cur.has_argument():
                return cur_ty.copy()
            var nm = cur.argument_text()
            var td = self.typedef(nm)
            if not td:
                return cur_ty.copy()
            var inner_ty = self.find_child(td.value()[], `type`)
            if not inner_ty:
                return cur_ty.copy()
            cur_ty = inner_ty.copy()
        raise Error("typedef chain too deep or cyclic")

    def leaf_type(read self, read leaf: YangConstruct) raises -> String:
        var eff = self.leaf_effective_type_stmt(leaf)
        if not eff:
            return ""
        if eff.value()[].has_argument():
            return eff.value()[].argument_text()
        return ""

    def leaf_range(read self, read leaf: YangConstruct) raises -> String:
        from ..spec import `range-stmt`

        var ty = self.leaf_effective_type_stmt(leaf)
        if not ty:
            return ""
        var range_stmt = self.find_child(ty.value()[], `range-stmt`)
        if range_stmt and range_stmt.value()[].has_argument():
            return range_stmt.value()[].argument_text()
        return ""

    def leaf_range_segments(
        read self, read leaf: YangConstruct
    ) raises -> List[RangeBounds]:
        var text = self.leaf_range(leaf)
        if text.byte_length() == 0:
            return List[RangeBounds]()
        return try_parse_range_segments(text, 0)

    def leaf_length_argument(
        read self, read leaf: YangConstruct
    ) raises -> String:
        from ..spec import `length`

        var ty = self.leaf_effective_type_stmt(leaf)
        if not ty:
            return ""
        var ln = self.find_child(ty.value()[], `length`)
        if not ln or not ln.value()[].has_argument():
            return ""
        return ln.value()[].argument_text()

    def leaf_length_segments(
        read self, read leaf: YangConstruct
    ) raises -> List[LengthSegment]:
        var text = self.leaf_length_argument(leaf)
        if text.byte_length() == 0:
            return List[LengthSegment]()
        return try_parse_length_segments(text, 0)

    def leaf_pattern_specs(
        read self, read leaf: YangConstruct
    ) raises -> List[YangPatternSpec]:
        from ..spec import `modifier`, `pattern`

        var out = List[YangPatternSpec]()
        var ty = self.leaf_effective_type_stmt(leaf)
        if not ty:
            return out^
        for ch in ty.value()[].children:
            if ch[].spec != `pattern` or not ch[].has_argument():
                continue
            var inv = False
            for sub in ch[].children:
                if sub[].spec == `modifier` and sub[].has_argument():
                    if _strip_spaces(sub[].argument_text()) == "invert-match":
                        inv = True
                    break
            out.append(YangPatternSpec(ch[].argument_text(), inv))
        return out^

    def identity_derives_from(
        read self, read name: String, read base: String
    ) raises -> Bool:
        """Return True when `name` equals `base` or transitively derives from it.

        Strips any module prefix (e.g. ``mod:foo`` → ``foo``) before lookup so
        both qualified and unqualified forms work for the single-module case.
        """
        from ..spec import `base` as `base-kw`

        var local_name = _local_name(name)
        var local_base = _local_name(base)
        if local_name == local_base:
            return True
        if local_name not in self.identities:
            return False
        comptime _MAX_DEPTH = 128
        var stack = List[String]()
        stack.append(local_name)
        for _ in range(_MAX_DEPTH):
            if len(stack) == 0:
                return False
            var cur = stack.pop()
            if cur not in self.identities:
                continue
            ref ident = self.identities[cur][]
            for child in ident.children:
                if child[].spec == `base-kw` and child[].has_argument():
                    var parent = _local_name(child[].argument_text())
                    if parent == local_base:
                        return True
                    stack.append(parent)
        return False

    def leaf_identityref_bases(
        read self, read leaf: YangConstruct
    ) raises -> List[String]:
        """Collect the `base` identity names from a leaf's effective identityref type."""
        from ..spec import `base` as `base-kw`

        var out = List[String]()
        var ty = self.leaf_effective_type_stmt(leaf)
        if not ty:
            return out^
        for ch in ty.value()[].children:
            if ch[].spec == `base-kw` and ch[].has_argument():
                out.append(_local_name(ch[].argument_text()))
        return out^

    def identity_valid_for_bases(
        read self, read value: String, read bases: List[String]
    ) raises -> Bool:
        """Return True when `value` is (or derives from) at least one of `bases`."""
        var local_val = _local_name(value)
        for i in range(len(bases)):
            if self.identity_derives_from(local_val, bases[i]):
                return True
        return False

    def leafref_path(read self, read leaf: YangConstruct) -> String:
        from ..spec import `path`, `type`

        var ty = self.find_child(leaf, `type`)
        if not ty:
            return ""
        var path_stmt = self.find_child(ty.value()[], `path`)
        if path_stmt and path_stmt.value()[].has_argument():
            return path_stmt.value()[].argument_text()
        return ""

    def _validate_semantics(ref self) raises:
        if not self.root:
            return
        from xyang.yang.visitor.uses_expand_visitor import (
            expand_uses_throughout_module,
        )
        var expanded_tree = expand_uses_throughout_module(self)
        var expanded_root = Arc[YangConstruct](expanded_tree^)
        var ancestry = List[Arc[YangConstruct]]()
        _validate_semantics_in_subtree(self, expanded_root, ancestry^)


def _line_prefix(line: UInt) -> String:
    if line > 0:
        return "line " + String(line) + ": "
    return ""


def _schema_data_node(read node: YangConstruct) -> Bool:
    from ..spec import `anydata`, `anyxml`, `container`, `leaf`, `leaf-list`, `list`

    return (
        node.spec == `anydata`
        or node.spec == `anyxml`
        or node.spec == `container`
        or node.spec == `leaf`
        or node.spec == `leaf-list`
        or node.spec == `list`
    )


def _schema_child_by_name(
    read module: YangModule, read parent: YangConstruct, read name: String
) raises -> Optional[Arc[YangConstruct]]:
    from ..spec import `case`, `choice`, `uses`

    for child in parent.children:
        if (
            _schema_data_node(child[])
            and child[].has_argument()
            and _local_name(child[].argument_text()) == _local_name(name)
        ):
            return Optional[Arc[YangConstruct]](child.copy())
    for child in parent.children:
        if child[].spec != `uses` or not child[].has_argument():
            continue
        var grouping = module.find_grouping(child[].argument_text())
        if not grouping:
            continue
        var found = _schema_child_by_name(module, grouping.value()[], name)
        if found:
            return found^
    for child in parent.children:
        if child[].spec != `choice`:
            continue
        for ch in child[].children:
            if ch[].spec != `case`:
                continue
            var found = _schema_child_by_name(module, ch[], name)
            if found:
                return found^
    return Optional[Arc[YangConstruct]]()


def _choice_case_name(read case_node: YangConstruct) -> String:
    if case_node.has_argument():
        return case_node.argument_text()
    return "<unnamed>"


def _collect_choice_case_keys(read case_node: YangConstruct, mut keys: Dict[String, Bool]):
    from ..spec import `case`, `choice`

    for child in case_node.children:
        ref c = child[]
        if _schema_data_node(c) and c.has_argument():
            keys[_local_name(c.argument_text())] = True
            continue
        if c.spec == `choice`:
            for ch in c.children:
                if ch[].spec == `case`:
                    _collect_choice_case_keys(ch[], keys)


def _validate_choice_cases_distinguishable(read choice_node: YangConstruct) raises:
    from ..spec import `case`

    var seen = Dict[String, String]()
    for ch in choice_node.children:
        if ch[].spec != `case`:
            continue
        var keys = Dict[String, Bool]()
        _collect_choice_case_keys(ch[], keys)
        var case_name = _choice_case_name(ch[])
        for key in keys.keys():
            if key in seen:
                raise Error(
                    _line_prefix(ch[].line)
                    + "YANG `choice` cases must be uniquely distinguishable; key `"
                    + key
                    + "` appears in both case `"
                    + seen[key]
                    + "` and case `"
                    + case_name
                    + "`"
                )
            seen[key] = case_name


def _xpath_step_name(read step: XPathExpr, read source: String) -> String:
    return _local_name(step.value.text(source.as_bytes()))


def _xpath_parent_for_relative_step(
    read ancestry: List[Arc[YangConstruct]], read current: YangConstruct
) raises -> Arc[YangConstruct]:
    if len(ancestry) < 2:
        raise Error("XPath parent step has no schema parent")
    return ancestry[len(ancestry) - 2].copy()


def _xpath_resolve_path(
    read module: YangModule,
    read context: Arc[YangConstruct],
    read ancestry: List[Arc[YangConstruct]],
    read path: XPathExpr,
    read source: String,
    line: UInt,
    allow_missing: Bool = False,
) raises -> Optional[Arc[YangConstruct]]:
    if path.kind() != XPathExpr.PATH:
        return Optional[Arc[YangConstruct]]()

    ref p = path.payload[XPathPath]
    if len(p.steps) == 0:
        return Optional[Arc[YangConstruct]]()

    var parents = ancestry.copy()
    var first_name = _xpath_step_name(p.steps[0][], source)
    var i: Int
    var current: Optional[Arc[YangConstruct]]

    if first_name == ".":
        current = Optional[Arc[YangConstruct]](context.copy())
        i = 1
    elif first_name == "..":
        current = Optional[Arc[YangConstruct]](
            _xpath_parent_for_relative_step(ancestry, context[])
        )
        if len(parents) > 0:
            _ = parents.pop()
        if len(parents) > 0:
            _ = parents.pop()
        i = 1
    else:
        var top = module.top_container(first_name)
        if not top:
            raise Error(
                _line_prefix(line)
                + "XPath references unknown top-level node `"
                + first_name
                + "` in `"
                + source
                + "`"
            )
        current = top.copy()
        parents = List[Arc[YangConstruct]]()
        i = 1

    while i < len(p.steps):
        var step_name = _xpath_step_name(p.steps[i][], source)
        if step_name == ".":
            i += 1
            continue
        if step_name == "..":
            if len(parents) == 0:
                raise Error(
                    _line_prefix(line)
                    + "XPath parent step has no schema parent in `"
                    + source
                    + "`"
                )
            current = Optional[Arc[YangConstruct]](parents.pop())
            i += 1
            continue
        if not current:
            return Optional[Arc[YangConstruct]]()
        var child = _schema_child_by_name(module, current.value()[], step_name)
        if not child:
            if allow_missing:
                return Optional[Arc[YangConstruct]]()
            raise Error(
                _line_prefix(line)
                + "XPath references unknown schema node `"
                + step_name
                + "` in `"
                + source
                + "`"
            )
        parents.append(current.value().copy())
        current = child.copy()
        i += 1

    return current^


def _validate_xpath_expr_schema_refs(
    read module: YangModule,
    read context: Arc[YangConstruct],
    read ancestry: List[Arc[YangConstruct]],
    read expr: XPathExpr,
    read source: String,
    line: UInt,
    allow_missing_paths: Bool = False,
) raises:
    if expr.kind() == XPathExpr.PATH:
        ref path = expr.payload[XPathPath]
        _ = _xpath_resolve_path(
            module, context, ancestry, expr, source, line, allow_missing_paths
        )
        for i in range(len(path.steps)):
            ref st = path.steps[i][].payload[XPathStep]
            for j in range(len(st.predicates)):
                _validate_xpath_expr_schema_refs(
                    module,
                    context,
                    ancestry,
                    st.predicates[j][],
                    source,
                    line,
                    allow_missing_paths,
                )
        return
    if expr.kind() == XPathExpr.STEP:
        ref st = expr.payload[XPathStep]
        for i in range(len(st.predicates)):
            _validate_xpath_expr_schema_refs(
                module,
                context,
                ancestry,
                st.predicates[i][],
                source,
                line,
                allow_missing_paths,
            )
        return
    if expr.kind() == XPathExpr.BINARY:
        ref bin = expr.payload[XPathBinaryOp]
        if expr.value.type == Token.SLASH:
            var path = xpath_slash_expr_to_path(expr)
            if path:
                _ = _xpath_resolve_path(
                    module,
                    context,
                    ancestry,
                    path.value()[],
                    source,
                    line,
                    allow_missing_paths,
                )
            _validate_xpath_expr_schema_refs(
                module,
                context,
                ancestry,
                bin.left[],
                source,
                line,
                allow_missing_paths,
            )
            _validate_xpath_expr_schema_refs(
                module,
                context,
                ancestry,
                bin.right[],
                source,
                line,
                allow_missing_paths,
            )
            return
        _validate_xpath_expr_schema_refs(
            module,
            context,
            ancestry,
            bin.left[],
            source,
            line,
            allow_missing_paths,
        )
        _validate_xpath_expr_schema_refs(
            module,
            context,
            ancestry,
            bin.right[],
            source,
            line,
            allow_missing_paths,
        )
        return
    if expr.kind() == XPathExpr.CALL:
        ref call = expr.payload[XPathCall]
        var call_name = _local_name(expr.value.text(source.as_bytes()))
        var probe_allows_missing = (
            call_name == "boolean" or call_name == "count" or call_name == "not"
        )
        for i in range(len(call.args)):
            _validate_xpath_expr_schema_refs(
                module,
                context,
                ancestry,
                call.args[i][],
                source,
                line,
                allow_missing_paths or probe_allows_missing,
            )


def _validate_when_semantics(
    read module: YangModule,
    read node: YangConstruct,
    read ancestry: List[Arc[YangConstruct]],
) raises:
    if len(ancestry) == 0:
        return
    var context = ancestry[len(ancestry) - 1].copy()
    var root = parse_xpath_expression(node.argument_text(), node.line)
    _validate_xpath_expr_schema_refs(
        module,
        context,
        ancestry,
        root[],
        node.argument_text(),
        node.line,
    )


def _validate_semantics_for_node(
    read module: YangModule,
    read node: YangConstruct,
    read ancestry: List[Arc[YangConstruct]],
) raises:
    from ..spec import `choice`, `when`

    if node.spec == `choice`:
        _validate_choice_cases_distinguishable(node)
    if node.spec == `when`:
        _validate_when_semantics(module, node, ancestry)


def _validate_semantics_in_subtree(
    read module: YangModule,
    read node: Arc[YangConstruct],
    read ancestry: List[Arc[YangConstruct]],
) raises:
    from ..spec import `grouping`

    if node[].spec == `grouping`:
        return
    _validate_semantics_for_node(module, node[], ancestry)
    var child_ancestry = ancestry.copy()
    child_ancestry.append(node.copy())
    for child in node[].children:
        _validate_semantics_in_subtree(module, child.copy(), child_ancestry)


def _parse_if_feature_primary(
    mut parser: IfFeatureExprParser, read module: YangModule
) raises -> Bool:
    if parser.consume_byte(UInt8(ord("("))):
        var value = _parse_if_feature_or(parser, module)
        if not parser.consume_byte(UInt8(ord(")"))):
            raise Error(
                "expected `)` in if-feature expression near `"
                + parser.remaining()
                + "`"
            )
        return value
    var name = parser.parse_name()
    return module.is_feature_enabled(name)


def _parse_if_feature_not(
    mut parser: IfFeatureExprParser, read module: YangModule
) raises -> Bool:
    if parser.consume_keyword("not"):
        return not _parse_if_feature_not(parser, module)
    return _parse_if_feature_primary(parser, module)


def _parse_if_feature_and(
    mut parser: IfFeatureExprParser, read module: YangModule
) raises -> Bool:
    var value = _parse_if_feature_not(parser, module)
    while parser.consume_keyword("and"):
        var rhs = _parse_if_feature_not(parser, module)
        value = value and rhs
    return value


def _parse_if_feature_or(
    mut parser: IfFeatureExprParser, read module: YangModule
) raises -> Bool:
    var value = _parse_if_feature_and(parser, module)
    while parser.consume_keyword("or"):
        var rhs = _parse_if_feature_and(parser, module)
        value = value or rhs
    return value
