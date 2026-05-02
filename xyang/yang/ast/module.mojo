## Parsed YANG module: root tree plus header fields and indexes.

from std.collections import Dict, List
from std.iter import Iterable, Iterator
from std.memory import ArcPointer

from .construct import YangConstruct
from .lexer import AstLexer
from .parser import parse_module
from ..arguments import (
    LengthSegment,
    RangeBounds,
    YangPatternSpec,
    _strip_spaces,
    length_allows_scalar_count,
    try_parse_length_segments,
    try_parse_range_bounds,
)
from ..spec import Kw


comptime Arc = ArcPointer
comptime ConstructMap = Dict[String, Arc[YangConstruct]]


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
    var fields: Dict[Kw, String]
    var revisions: List[String]
    var groupings: ConstructMap
    var typedefs: ConstructMap
    var top_containers: ConstructMap

    def __init__(out self):
        self.root = Optional[Arc[YangConstruct]]()
        self.fields = Dict[Kw, String]()
        self.revisions = List[String]()
        self.groupings = ConstructMap()
        self.typedefs = ConstructMap()
        self.top_containers = ConstructMap()

    def parse[
        origin: ImmutOrigin
    ](mut self, mut lexer: AstLexer[origin]) raises:
        var tree = parse_module(lexer)
        from ..spec import MODULE_SPEC, build_spec_table, validate_construct

        var specs = build_spec_table()
        validate_construct(MODULE_SPEC, tree, specs)
        self._populate_from_validated_tree(tree)
        self.root = Optional[Arc[YangConstruct]](Arc[YangConstruct](tree^))

    def _populate_from_validated_tree(
        mut self, read tree: YangConstruct
    ) raises:
        from ..spec import `container`, `grouping`, `revision`

        self.fields[tree.spec] = tree.argument.value()
        for child in tree.children:
            ref node = child[]
            var arg = node.argument.value()
            var kw = node.spec
            if kw == `revision`:
                self.revisions.append(arg)
            elif kw == `grouping`:
                _insert_unique(self.groupings, arg, child)
            elif kw == `container`:
                _insert_unique(self.top_containers, arg, child)
            else:
                self.fields[kw] = arg

    def root_construct(read self) raises -> Arc[YangConstruct]:
        if not self.root:
            raise Error("YANG module has no parsed root construct")
        return self.root.value().copy()

    def field(read self, kw: Kw) raises -> Optional[String]:
        if kw not in self.fields:
            return Optional[String]()
        return Optional[String](self.fields[kw])

    def get_name(read self) raises -> String:
        from ..spec import `module`

        return self.fields[`module`]

    def get_yang_version(read self) raises -> Optional[String]:
        from ..spec import `yang-version`

        return self.field(`yang-version`)

    def get_namespace(read self) raises -> String:
        from ..spec import `namespace`

        return self.fields[`namespace`]

    def get_prefix(read self) raises -> String:
        from ..spec import `prefix`

        return self.fields[`prefix`]

    def get_organization(read self) raises -> Optional[String]:
        from ..spec import `organization`

        return self.field(`organization`)

    def get_contact(read self) raises -> Optional[String]:
        from ..spec import `contact`

        return self.field(`contact`)

    def get_description(read self) raises -> Optional[String]:
        from ..spec import `description`

        return self.field(`description`)

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
        read self, read node: YangConstruct, keyword: Kw
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
        for child in parent.children:
            if child[].keyword != "uses" or not child[].argument:
                continue
            var grouping = self.find_grouping(child[].argument.value())
            if not grouping:
                continue
            for gchild in grouping.value()[].children:
                if (
                    gchild[].keyword == "leaf"
                    and gchild[].argument
                    and gchild[].argument.value() == name
                ):
                    return True
        return False

    def find_effective_leaf(
        read self, read parent: YangConstruct, name: String
    ) raises -> Optional[Arc[YangConstruct]]:
        for child in parent.children:
            if (
                child[].keyword == "leaf"
                and child[].argument
                and child[].argument.value() == name
            ):
                return Optional[Arc[YangConstruct]](child.copy())
        for child in parent.children:
            if child[].keyword != "uses" or not child[].argument:
                continue
            var grouping = self.find_grouping(child[].argument.value())
            if not grouping:
                continue
            var leaf = self.find_effective_leaf(grouping.value()[], name)
            if leaf:
                return leaf^
        return Optional[Arc[YangConstruct]]()

    def find_effective_data_child(
        read self, read parent: YangConstruct, name: String
    ) raises -> Optional[Arc[YangConstruct]]:
        from ..spec import `container`, `leaf`, `list`

        for child in parent.children:
            var kw = child[].spec
            if (
                (kw == `leaf` or kw == `container` or kw == `list`)
                and child[].argument
                and child[].argument.value() == name
            ):
                return Optional[Arc[YangConstruct]](child.copy())
        for child in parent.children:
            if child[].keyword != "uses" or not child[].argument:
                continue
            var grouping = self.find_grouping(child[].argument.value())
            if not grouping:
                continue
            var data_child = self.find_effective_data_child(
                grouping.value()[], name
            )
            if data_child:
                return data_child^
        return Optional[Arc[YangConstruct]]()

    def effective_data_children(
        read self, read parent: YangConstruct
    ) raises -> ConstructMap:
        var out = ConstructMap()
        self._populate_effective_data_children(parent, out)
        return out^

    def _populate_effective_data_children(
        read self, read parent: YangConstruct, mut out: ConstructMap
    ) raises:
        from ..spec import `container`, `leaf`, `list`

        for child in parent.children:
            var kw = child[].spec
            if (
                not (kw == `leaf` or kw == `container` or kw == `list`)
                or not child[].argument
            ):
                continue
            var name = child[].argument.value()
            if name not in out:
                out[name] = child.copy()
        for child in parent.children:
            if child[].keyword != "uses" or not child[].argument:
                continue
            var grouping = self.find_grouping(child[].argument.value())
            if not grouping:
                continue
            self._populate_effective_data_children(grouping.value()[], out)

    def find_effective_child(
        read self,
        read parent: YangConstruct,
        keyword: Kw,
        name: String,
    ) -> Optional[Arc[YangConstruct]]:
        for child in parent.children:
            if (
                child[].spec == keyword
                and child[].argument
                and child[].argument.value() == name
            ):
                return Optional[Arc[YangConstruct]](child.copy())
        return Optional[Arc[YangConstruct]]()

    def leaf_type(read self, read leaf: YangConstruct) -> String:
        from ..spec import `type`

        var ty = self.find_child(leaf, `type`)
        if ty and ty.value()[].argument:
            return ty.value()[].argument.value()
        return ""

    def leaf_range(read self, read leaf: YangConstruct) -> String:
        from ..spec import `range-stmt`, `type`

        var ty = self.find_child(leaf, `type`)
        if not ty:
            return ""
        var range_stmt = self.find_child(ty.value()[], `range-stmt`)
        if range_stmt and range_stmt.value()[].argument:
            return range_stmt.value()[].argument.value()
        return ""

    def leaf_range_bounds(
        read self, read leaf: YangConstruct
    ) raises -> Optional[RangeBounds]:
        var text = self.leaf_range(leaf)
        if text.byte_length() == 0:
            return Optional[RangeBounds]()
        return try_parse_range_bounds(text)

    def leaf_length_argument(read self, read leaf: YangConstruct) -> String:
        from ..spec import `length`, `type`

        var ty = self.find_child(leaf, `type`)
        if not ty:
            return ""
        var ln = self.find_child(ty.value()[], `length`)
        if not ln or not ln.value()[].argument:
            return ""
        return ln.value()[].argument.value()

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
        from ..spec import `modifier`, `pattern`, `type`

        var out = List[YangPatternSpec]()
        var ty = self.find_child(leaf, `type`)
        if not ty:
            return out^
        for ch in ty.value()[].children:
            if ch[].spec != `pattern` or not ch[].argument:
                continue
            var inv = False
            for sub in ch[].children:
                if sub[].spec == `modifier` and sub[].argument:
                    if _strip_spaces(sub[].argument.value()) == "invert-match":
                        inv = True
                    break
            out.append(YangPatternSpec(ch[].argument.value(), inv))
        return out^

    def leafref_path(read self, read leaf: YangConstruct) -> String:
        from ..spec import `path`, `type`

        var ty = self.find_child(leaf, `type`)
        if not ty:
            return ""
        var path_stmt = self.find_child(ty.value()[], `path`)
        if path_stmt and path_stmt.value()[].argument:
            return path_stmt.value()[].argument.value()
        return ""
