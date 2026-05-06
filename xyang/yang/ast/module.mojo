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
    var top_containers: ConstructMap

    def __init__(out self):
        self.root = Optional[Arc[YangConstruct]]()
        self.fields = ModuleFieldMap()
        self.revisions = List[String]()
        self.groupings = ConstructMap()
        self.typedefs = ConstructMap()
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

    def _populate_from_validated_root(mut self) raises:
        from ..spec import `container`, `grouping`, `revision`, `typedef`

        ref root_arc = self.root.value()
        for child in root_arc[].children:
            ref node = child[]
            var arg = node.argument_text()
            var kw = node.spec
            if kw == `revision`:
                self.revisions.append(arg)
            elif kw == `grouping`:
                _insert_unique(self.groupings, arg, child)
            elif kw == `typedef`:
                _insert_unique(self.typedefs, arg, child)
            elif kw == `container`:
                _insert_unique(self.top_containers, arg, child)
            else:
                self.fields[kw] = child.copy()

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
        from ..spec import `module`

        return self._field_argument_text_required(`module`)

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

    def leafref_path(read self, read leaf: YangConstruct) -> String:
        from ..spec import `path`, `type`

        var ty = self.find_child(leaf, `type`)
        if not ty:
            return ""
        var path_stmt = self.find_child(ty.value()[], `path`)
        if path_stmt and path_stmt.value()[].has_argument():
            return path_stmt.value()[].argument_text()
        return ""
