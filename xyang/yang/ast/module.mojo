## Parsed YANG module: header fields plus indexes (no full tree root).

from std.collections import Dict
from std.memory import ArcPointer

from .construct import YangConstruct
from .lexer import AstLexer
from .parser import parse_module


comptime Arc = ArcPointer


@always_inline
def _set_once(
    mut slot: Optional[String],
    read value: String,
    field: String,
    line: Int,
) raises:
    if slot:
        raise Error(
            "line "
            + String(line)
            + ": duplicate `"
            + field
            + "` at module level"
        )
    slot = Optional[String](value)


@always_inline
def _insert_unique(
    mut table: Dict[String, Arc[YangConstruct]],
    read name: String,
    read child: Arc[YangConstruct],
    stmt_kind: String,
    line: Int,
) raises:
    if name in table:
        raise Error(
            "line "
            + String(line)
            + ": duplicate "
            + stmt_kind
            + " `"
            + name
            + "`"
        )
    table[name] = child.copy()


@fieldwise_init
struct YangModule(Movable):
    var module_name: String
    var yang_version: Optional[String]
    var namespace: Optional[String]
    var prefix: Optional[String]
    var organization: Optional[String]
    var contact: Optional[String]
    var description: Optional[String]
    var revisions: List[String]
    var groupings: Dict[String, Arc[YangConstruct]]
    var typedefs: Dict[String, Arc[YangConstruct]]
    var top_containers: Dict[String, Arc[YangConstruct]]

    def __init__(out self):
        self.module_name = ""
        self.yang_version = Optional[String]()
        self.namespace = Optional[String]()
        self.prefix = Optional[String]()
        self.organization = Optional[String]()
        self.contact = Optional[String]()
        self.description = Optional[String]()
        self.revisions = List[String]()
        self.groupings = Dict[String, Arc[YangConstruct]]()
        self.typedefs = Dict[String, Arc[YangConstruct]]()
        self.top_containers = Dict[String, Arc[YangConstruct]]()

    def parse[
        origin: ImmutOrigin
    ](mut self, mut lexer: AstLexer[origin]) raises:
        var tree = parse_module(lexer)
        if not tree.argument:
            raise Error(
                "line "
                + String(tree.line)
                + ": expected `module` statement to have a name argument"
            )
        self.module_name = tree.argument.value()

        from ..spec import MODULE_SPEC, build_spec_table, validate_construct
        var specs = build_spec_table()
        validate_construct(MODULE_SPEC, tree, specs)

        for child in tree.children:
            ref node = child[]
            if node.keyword == "revision":
                if not node.argument:
                    raise Error(
                        "line "
                        + String(node.line)
                        + ": expected `revision` to have an argument"
                    )
                self.revisions.append(node.argument.value())
                continue
            if not node.argument:
                continue
            var arg = node.argument.value()
            if node.keyword == "yang-version":
                _set_once(self.yang_version, arg, "yang-version", node.line)
            elif node.keyword == "namespace":
                _set_once(self.namespace, arg, "namespace", node.line)
            elif node.keyword == "prefix":
                _set_once(self.prefix, arg, "prefix", node.line)
            elif node.keyword == "organization":
                _set_once(self.organization, arg, "organization", node.line)
            elif node.keyword == "contact":
                _set_once(self.contact, arg, "contact", node.line)
            elif node.keyword == "description":
                _set_once(self.description, arg, "description", node.line)
            elif node.keyword == "grouping":
                _insert_unique(
                    self.groupings, arg, child, "grouping", node.line
                )
            elif node.keyword == "typedef":
                _insert_unique(self.typedefs, arg, child, "typedef", node.line)
            elif node.keyword == "container":
                _insert_unique(
                    self.top_containers, arg, child, "container", node.line
                )

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
