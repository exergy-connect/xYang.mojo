## Parsed YANG module: root tree plus header fields and indexes.

from std.collections import Dict
from std.iter import Iterable, Iterator
from std.memory import ArcPointer

from .construct import YangConstruct
from .lexer import AstLexer
from .parser import parse_module
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
            if child[].spec.value() == `container`:
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
        self.fields[tree.spec.value()] = tree.argument.value()
        for child in tree.children:
            ref node = child[]
            var arg = node.argument.value()
            var kw = node.spec.value()
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
        ref self
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
