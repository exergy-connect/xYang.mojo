## Minimal YANG AST model in Mojo for xYang.mojo.

from std.collections import Dict
from std.memory import ArcPointer, UnsafePointer
from std.utils import Variant
from emberjson import JsonDeserializable
from xyang.xpath import Expr

comptime Arc = ArcPointer


fn _typedef_ref_local_name(n: String) -> String:
    var parts = n.split(":")
    if len(parts) == 0:
        return n
    return String(String(parts[len(parts) - 1]).strip())


## --- YANG `type` statement: lexical name + constraint payload (mutually exclusive shapes). ---

@fieldwise_init
## When non-null, `resolved` points at the module `typedef` for this `type` reference (external lifetime; not owned here).
struct YangTypeTypedef(Movable):
    var resolved: UnsafePointer[YangTypedefStmt, MutExternalOrigin]

@fieldwise_init
struct YangTypeIntegerRange(Movable):
    var has_range: Bool
    var range_min: Int64
    var range_max: Int64


@fieldwise_init
struct YangTypeDecimal64(Movable):
    ## 1..18 when set from YANG; 0 when absent.
    var fraction_digits: Int
    var has_decimal64_range: Bool
    var decimal64_range_min: Float64
    var decimal64_range_max: Float64


@fieldwise_init
struct YangTypeEnumeration(Movable):
    var enum_values: List[String]


@fieldwise_init
struct YangTypeLeafref(Movable):
    var leafref_path: String
    var leafref_require_instance: Bool


@fieldwise_init
struct YangTypeBits(Movable):
    var bits_names: List[String]


@fieldwise_init
struct YangTypeIdentityref(Movable):
    var identityref_base: String


@fieldwise_init
## One `pattern` substatement under `type string` (RFC 7950 Sec. 9.4.5), including
## optional `modifier invert-match` in the pattern's substatement block.
struct YangStringPatternSpec(Movable, Copyable):
    var pattern: String
    var invert_match: Bool


@fieldwise_init
## Built-in `string` (YANG) constraints. `patterns` preserves RFC AND order.
## `length_min` / `length_max` are JSON Schema `minLength` / `maxLength`; `-1` = unset.
struct YangTypeString(Movable):
    var patterns: List[YangStringPatternSpec]
    var length_min: Int
    var length_max: Int


@fieldwise_init
## Built-in YANG types with no substatements: `boolean`, `empty`.
struct YangTypeBasic(Movable):
    comptime Kind = Int
    comptime boolean: Self.Kind = 0
    comptime empty: Self.Kind = 1
    var kind: Self.Kind


@fieldwise_init
struct YangTypeUnion(Movable):
    var union_members: List[Arc[YangType]]


@fieldwise_init
struct YangType(Movable):
    comptime Constraints = Variant[
        YangTypeTypedef,
        YangTypeIntegerRange,
        YangTypeDecimal64,
        YangTypeEnumeration,
        YangTypeLeafref,
        YangTypeBits,
        YangTypeIdentityref,
        YangTypeString,
        YangTypeBasic,
        YangTypeUnion,
    ]
    var name: String
    var constraints: Self.Constraints

    def __str__(self) -> String:
        if self.constraints.isa[YangTypeLeafref]():
            ref lr = self.constraints[YangTypeLeafref]
            return (
                "YangType("
                + self.name
                + ", path="
                + lr.leafref_path
                + ", require-instance="
                + ("true" if lr.leafref_require_instance else "false")
                + ")"
            )
        if self.constraints.isa[YangTypeIntegerRange]():
            ref ir = self.constraints[YangTypeIntegerRange]
            if ir.has_range:
                return (
                    "YangType("
                    + self.name
                    + ", range="
                    + String(ir.range_min)
                    + ".."
                    + String(ir.range_max)
                    + ")"
                )
        if self.name == "enumeration" and self.constraints.isa[YangTypeEnumeration]():
            return (
                "YangType("
                + self.name
                + ", enums="
                + String(len(self.constraints[YangTypeEnumeration].enum_values))
                + ")"
            )
        if self.name == "union":
            var member_count = 0
            if self.constraints.isa[YangTypeUnion]():
                member_count = len(self.constraints[YangTypeUnion].union_members)
            return (
                "YangType("
                + self.name
                + ", types="
                + String(member_count)
                + ")"
            )
        if self.constraints.isa[YangTypeTypedef]():
            ref tdef = self.constraints[YangTypeTypedef]
            if tdef.resolved:
                return (
                    "YangType("
                    + self.name
                    + ", typedef="
                    + tdef.resolved[].name
                    + ")"
                )
        return "YangType(" + self.name + ")"

    # --- Integer / numeric range (integer types, `integer`, `number` with optional range) ---

    def has_range(read self) -> Bool:
        if self.constraints.isa[YangTypeIntegerRange]():
            return self.constraints[YangTypeIntegerRange].has_range
        return False

    def range_min(read self) -> Int64:
        if self.constraints.isa[YangTypeIntegerRange]():
            return self.constraints[YangTypeIntegerRange].range_min
        return 0

    def range_max(read self) -> Int64:
        if self.constraints.isa[YangTypeIntegerRange]():
            return self.constraints[YangTypeIntegerRange].range_max
        return 0

    # --- decimal64 ---

    def fraction_digits(read self) -> Int:
        if self.constraints.isa[YangTypeDecimal64]():
            return self.constraints[YangTypeDecimal64].fraction_digits
        return 0

    def has_decimal64_range(read self) -> Bool:
        if self.constraints.isa[YangTypeDecimal64]():
            return self.constraints[YangTypeDecimal64].has_decimal64_range
        return False

    def decimal64_range_min(read self) -> Float64:
        if self.constraints.isa[YangTypeDecimal64]():
            return self.constraints[YangTypeDecimal64].decimal64_range_min
        return Float64(0.0)

    def decimal64_range_max(read self) -> Float64:
        if self.constraints.isa[YangTypeDecimal64]():
            return self.constraints[YangTypeDecimal64].decimal64_range_max
        return Float64(0.0)

    # --- enumeration ---

    def enum_values_len(read self) -> Int:
        if self.constraints.isa[YangTypeEnumeration]():
            return len(self.constraints[YangTypeEnumeration].enum_values)
        return 0

    def enum_value_at(read self, i: Int) -> String:
        return self.constraints[YangTypeEnumeration].enum_values[i]

    # --- union member types ---

    def union_members_len(read self) -> Int:
        if self.constraints.isa[YangTypeUnion]():
            return len(self.constraints[YangTypeUnion].union_members)
        return 0

    def union_member_arc(read self, i: Int) -> Arc[YangType]:
        return self.constraints[YangTypeUnion].union_members[i]

    # --- leafref ---

    def leafref_path(read self) -> String:
        if self.constraints.isa[YangTypeLeafref]():
            return self.constraints[YangTypeLeafref].leafref_path
        return ""

    def leafref_require_instance(read self) -> Bool:
        if self.constraints.isa[YangTypeLeafref]():
            return self.constraints[YangTypeLeafref].leafref_require_instance
        return True

    # --- bits ---

    def bits_names_len(read self) -> Int:
        if self.constraints.isa[YangTypeBits]():
            return len(self.constraints[YangTypeBits].bits_names)
        return 0

    def bits_name_at(read self, i: Int) -> String:
        return self.constraints[YangTypeBits].bits_names[i]


    # --- identityref ---

    def identityref_base(read self) -> String:
        if self.constraints.isa[YangTypeIdentityref]():
            return self.constraints[YangTypeIdentityref].identityref_base
        return ""

    # --- string (YANG) pattern ---

    def has_string_pattern(read self) -> Bool:
        if self.name != "string":
            return False
        if self.constraints.isa[YangTypeString]():
            return len(self.constraints[YangTypeString].patterns) > 0
        return False

    def string_patterns_len(read self) -> Int:
        if self.name == "string" and self.constraints.isa[YangTypeString]():
            return len(self.constraints[YangTypeString].patterns)
        return 0

    def string_pattern_regex_at(read self, i: Int) -> String:
        if self.name == "string" and self.constraints.isa[YangTypeString]():
            ref ps = self.constraints[YangTypeString].patterns
            if i >= 0 and i < len(ps):
                return ps[i].pattern
        return ""

    def string_pattern_invert_at(read self, i: Int) -> Bool:
        if self.name == "string" and self.constraints.isa[YangTypeString]():
            ref ps = self.constraints[YangTypeString].patterns
            if i >= 0 and i < len(ps):
                return ps[i].invert_match
        return False

    def string_pattern(read self) -> String:
        ## First pattern regex (backward compatible); empty if none.
        return self.string_pattern_regex_at(0)

    def has_string_length_min(read self) -> Bool:
        if self.name != "string":
            return False
        if not self.constraints.isa[YangTypeString]():
            return False
        return self.constraints[YangTypeString].length_min >= 0

    def has_string_length_max(read self) -> Bool:
        if self.name != "string":
            return False
        if not self.constraints.isa[YangTypeString]():
            return False
        return self.constraints[YangTypeString].length_max >= 0

    def string_length_min(read self) -> Int:
        if self.name == "string" and self.constraints.isa[YangTypeString]():
            return self.constraints[YangTypeString].length_min
        return -1

    def string_length_max(read self) -> Int:
        if self.name == "string" and self.constraints.isa[YangTypeString]():
            return self.constraints[YangTypeString].length_max
        return -1

    # --- optional resolved `typedef` (see `YangTypeTypedef`) ---

    def typedef_reference(read self) -> String:
        if self.constraints.isa[YangTypeTypedef]():
            ref tdef = self.constraints[YangTypeTypedef]
            if tdef.resolved:
                return tdef.resolved[].name
            return self.name
        return ""

    ## Set only `YangTypeTypedef.resolved` (recurse into `union` member `Arc[YangType]`). No `YangType` cloning.
    def link_typedef_resolved(mut self, read typedefs: Dict[String, Arc[YangTypedefStmt]]) raises:
        if self.name == "union" and self.constraints.isa[YangTypeUnion]():
            for i in range(self.union_members_len()):
                var m = self.union_member_arc(i)
                ref mty = m[]
                mty.link_typedef_resolved(typedefs)
            return
        if not self.constraints.isa[YangTypeTypedef]():
            return
        if self.constraints[YangTypeTypedef].resolved:
            return
        var key = _typedef_ref_local_name(self.name)
        var found = typedefs.get(key)
        if not found:
            raise Error("Unknown typedef '" + self.name + "'")
        ref tds = found.value()[]
        self.constraints[YangTypeTypedef].resolved = (
            UnsafePointer(to=tds).unsafe_origin_cast[MutExternalOrigin]()
        )



@fieldwise_init
struct YangMust(Movable):
    ## Represents a YANG `must` expression attached to a leaf.
    ## - expression: raw XPath string from the schema (x-yang.must[].must)
    ## - xpath_ast: parsed XPath AST from `parse_xpath(expression)`; construction implies parse succeeded.
    var expression: String
    var error_message: String
    var description: String
    var xpath_ast: Expr.ExprPointer

    fn __del__(deinit self):
        if self.xpath_ast:
            self.xpath_ast[].free_tree()
            self.xpath_ast.destroy_pointee()
            self.xpath_ast.free()


@fieldwise_init
struct YangWhen(Movable):
    ## Represents a YANG `when` expression attached to a statement.
    ## - xpath_ast: from `parse_xpath(expression)`; construction implies parse succeeded.
    var expression: String
    var description: String
    var xpath_ast: Expr.ExprPointer

    fn __del__(deinit self):
        if self.xpath_ast:
            self.xpath_ast[].free_tree()
            self.xpath_ast.destroy_pointee()
            self.xpath_ast.free()


@fieldwise_init
struct YangMustStatements(Movable, JsonDeserializable):
    ## Owns the (possibly empty) list of `must` constraints for a schema node.
    var must_statements: List[Arc[YangMust]]

    def must_count(self) -> Int:
        return len(self.must_statements)

    def set_must_statements(mut self, var stmts: List[Arc[YangMust]]):
        self.must_statements = stmts^


trait YangHasWhen:
    ## Shared access to an optional `when` constraint.
    def has_when(self) -> Bool:
        ...

    def set_when(mut self, var value: Optional[YangWhen]):
        ...


@fieldwise_init
struct YangLeaf(Movable, JsonDeserializable, YangHasWhen):
    var name: String
    var description: String
    var type: YangType
    var mandatory: Bool
    var has_default: Bool
    var default_value: String
    var must: YangMustStatements
    var when: Optional[YangWhen]

    def has_when(self) -> Bool:
        return Bool(self.when)

    def set_when(mut self, var value: Optional[YangWhen]):
        self.when = value^

    def __str__(self) -> String:
        var m = "true" if self.mandatory else "false"
        return (
            "YangLeaf("
            + self.name
            + ", type="
            + self.type.__str__()
            + ", mandatory="
            + m
            + ", has_default="
            + ("true" if self.has_default else "false")
            + ", must="
            + String(len(self.must.must_statements))
            + ", has_when="
            + ("true" if self.has_when() else "false")
            + ")"
        )


@fieldwise_init
struct YangLeafList(Movable, JsonDeserializable, YangHasWhen):
    var name: String
    var description: String
    var type: YangType
    var default_values: List[String]
    var must: YangMustStatements
    var when: Optional[YangWhen]
    ## RFC 7950: unset when `min_elements` / `max_elements` are `-1`.
    var min_elements: Int
    var max_elements: Int
    ## RFC 7950 §7.7.1: `user` or `system`; empty if not specified in the model source.
    var ordered_by: String

    def has_when(self) -> Bool:
        return Bool(self.when)

    def set_when(mut self, var value: Optional[YangWhen]):
        self.when = value^

    def __str__(self) -> String:
        return (
            "YangLeafList("
            + self.name
            + ", type="
            + self.type.__str__()
            + ", defaults="
            + String(len(self.default_values))
            + ", must="
            + String(len(self.must.must_statements))
            + ", has_when="
            + ("true" if self.has_when() else "false")
            + ")"
        )


@fieldwise_init
struct YangAnydata(Movable, JsonDeserializable, YangHasWhen):
    ## RFC 7950 §7.12 — instance is any JSON-compatible value (not further constrained here).
    var name: String
    var description: String
    var mandatory: Bool
    var must: YangMustStatements
    var when: Optional[YangWhen]

    def has_when(self) -> Bool:
        return Bool(self.when)

    def set_when(mut self, var value: Optional[YangWhen]):
        self.when = value^


@fieldwise_init
struct YangAnyxml(Movable, JsonDeserializable, YangHasWhen):
    ## RFC 7950 §7.11 — same JSON treatment as anydata for encoding and validation.
    var name: String
    var description: String
    var mandatory: Bool
    var must: YangMustStatements
    var when: Optional[YangWhen]

    def has_when(self) -> Bool:
        return Bool(self.when)

    def set_when(mut self, var value: Optional[YangWhen]):
        self.when = value^


@fieldwise_init
struct YangChoiceCase(Movable, JsonDeserializable, YangHasWhen):
    var name: String
    var description: String
    var node_names: List[String]
    var when: Optional[YangWhen]

    def has_when(self) -> Bool:
        return Bool(self.when)

    def set_when(mut self, var value: Optional[YangWhen]):
        self.when = value^


@fieldwise_init
struct YangChoice(Movable, JsonDeserializable, YangHasWhen):
    var name: String
    var description: String
    var mandatory: Bool
    var default_case: String
    var case_names: List[String]
    var cases: List[Arc[YangChoiceCase]]
    var when: Optional[YangWhen]

    def has_when(self) -> Bool:
        return Bool(self.when)

    def set_when(mut self, var value: Optional[YangWhen]):
        self.when = value^

    def __str__(self) -> String:
        var m = "true" if self.mandatory else "false"
        var has_default = "true" if len(self.default_case) > 0 else "false"
        return (
            "YangChoice("
            + self.name
            + ", mandatory="
            + m
            + ", default-case="
            + has_default
            + ", cases="
            + String(len(self.case_names))
            + ")"
        )


@fieldwise_init
struct YangContainer(Movable, JsonDeserializable):
    var name: String
    var description: String
    var must: YangMustStatements
    var leaves: List[Arc[YangLeaf]]
    var leaf_lists: List[Arc[YangLeafList]]
    var anydatas: List[Arc[YangAnydata]]
    var anyxmls: List[Arc[YangAnyxml]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]

    def __str__(self) -> String:
        var nleaf = len(self.leaves)
        var nleaflist = len(self.leaf_lists)
        var na = len(self.anydatas)
        var nx = len(self.anyxmls)
        var ncont = len(self.containers)
        var nlist = len(self.lists)
        var nchoice = len(self.choices)
        return (
            "YangContainer("
            + self.name
            + ", must="
            + String(len(self.must.must_statements))
            + ", leaves="
            + String(nleaf)
            + ", leaf-lists="
            + String(nleaflist)
            + ", anydata="
            + String(na)
            + ", anyxml="
            + String(nx)
            + ", containers="
            + String(ncont)
            + ", lists="
            + String(nlist)
            + ", choices="
            + String(nchoice)
            + ")"
        )


@fieldwise_init
struct YangList(Movable, JsonDeserializable):
    ## Same arms as `YangGrouping.ChildStatement` / module body data nodes: Arc at variant arm.
    comptime ChildStatement = Variant[
        Arc[YangLeaf],
        Arc[YangLeafList],
        Arc[YangAnydata],
        Arc[YangAnyxml],
        Arc[YangContainer],
        Arc[YangList],
        Arc[YangChoice],
    ]
    var name: String
    var key: String
    var description: String
    var must: YangMustStatements
    var children: List[Self.ChildStatement]
    ## RFC 7950: unset when `min_elements` / `max_elements` are `-1`.
    var min_elements: Int
    var max_elements: Int
    var ordered_by: String
    ## Each inner list is one `unique` statement: descendant leaf names (same list entry).
    var unique_specs: List[List[String]]

    def __str__(self) -> String:
        return (
            "YangList("
            + self.name
            + ", key="
            + self.key
            + ", must="
            + String(len(self.must.must_statements))
            + ", children="
            + String(len(self.children))
            + ")"
        )


## Typed buckets for the seven allowed child node kinds; same merge order as `YangGrouping` packing.
@fieldwise_init
struct YangListChildBuckets:
    var leaves: List[Arc[YangLeaf]]
    var leaf_lists: List[Arc[YangLeafList]]
    var anydatas: List[Arc[YangAnydata]]
    var anyxmls: List[Arc[YangAnyxml]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]


def decompose_yang_list_children(
    read children: List[YangList.ChildStatement],
) -> YangListChildBuckets:
    var leaves = List[Arc[YangLeaf]]()
    var leaf_lists = List[Arc[YangLeafList]]()
    var anydatas = List[Arc[YangAnydata]]()
    var anyxmls = List[Arc[YangAnyxml]]()
    var containers = List[Arc[YangContainer]]()
    var lists = List[Arc[YangList]]()
    var choices = List[Arc[YangChoice]]()
    for i in range(len(children)):
        var ch = children[i]
        if ch.isa[Arc[YangLeaf]]():
            leaves.append(ch[Arc[YangLeaf]])
        elif ch.isa[Arc[YangLeafList]]():
            leaf_lists.append(ch[Arc[YangLeafList]])
        elif ch.isa[Arc[YangAnydata]]():
            anydatas.append(ch[Arc[YangAnydata]])
        elif ch.isa[Arc[YangAnyxml]]():
            anyxmls.append(ch[Arc[YangAnyxml]])
        elif ch.isa[Arc[YangContainer]]():
            containers.append(ch[Arc[YangContainer]])
        elif ch.isa[Arc[YangList]]():
            lists.append(ch[Arc[YangList]])
        elif ch.isa[Arc[YangChoice]]():
            choices.append(ch[Arc[YangChoice]])
    return YangListChildBuckets(
        leaves = leaves^,
        leaf_lists = leaf_lists^,
        anydatas = anydatas^,
        anyxmls = anyxmls^,
        containers = containers^,
        lists = lists^,
        choices = choices^,
    )


def pack_yang_list_child_buckets(read buckets: YangListChildBuckets) -> List[YangList.ChildStatement]:
    var children = List[YangList.ChildStatement]()
    for i in range(len(buckets.leaves)):
        children.append(YangList.ChildStatement(buckets.leaves[i].copy()))
    for i in range(len(buckets.leaf_lists)):
        children.append(YangList.ChildStatement(buckets.leaf_lists[i].copy()))
    for i in range(len(buckets.anydatas)):
        children.append(YangList.ChildStatement(buckets.anydatas[i].copy()))
    for i in range(len(buckets.anyxmls)):
        children.append(YangList.ChildStatement(buckets.anyxmls[i].copy()))
    for i in range(len(buckets.containers)):
        children.append(YangList.ChildStatement(buckets.containers[i].copy()))
    for i in range(len(buckets.lists)):
        children.append(YangList.ChildStatement(buckets.lists[i].copy()))
    for i in range(len(buckets.choices)):
        children.append(YangList.ChildStatement(buckets.choices[i].copy()))
    return children^


@fieldwise_init
struct YangGrouping(Movable):
    ## Keep Arc at the Variant arm level: YANG AST nodes are not ImplicitlyCopyable.
    ## Wrapping nodes in Arc lets grouping entries be stored/reused without move-only copy errors.
    comptime ChildStatement = Variant[
        Arc[YangLeaf],
        Arc[YangLeafList],
        Arc[YangAnydata],
        Arc[YangAnyxml],
        Arc[YangContainer],
        Arc[YangList],
        Arc[YangChoice],
    ]
    var name: String
    var children: List[Self.ChildStatement]


@fieldwise_init
struct YangTypedefStmt(Movable):
    var name: String
    var type_stmt: YangType
    var description: String


@fieldwise_init
struct YangIdentityStmt(Movable):
    var name: String
    var bases: List[String]
    var if_features: List[String]
    var description: String


@fieldwise_init
struct YangExtensionStmt(Movable):
    var name: String
    var argument_name: String
    var argument_yin_element: Bool
    var has_argument_yin_element: Bool
    var description: String


@fieldwise_init
struct YangExtensionInvocationStmt(Movable):
    var prefix: String
    var name: String
    var argument: String
    var has_argument: Bool
    var description: String


@fieldwise_init
struct YangUsesStmt(Movable):
    var grouping_name: String
    var if_features: List[String]
    var has_when: Bool
    var when: Optional[YangWhen]


@fieldwise_init
struct YangRefineStmt(Movable, YangHasWhen):
    # The target descendant-schema-nodeid
    var target_path: String

    # Validation & Constraints
    var mandatory: Optional[Bool]
    var min_elements: Optional[Int]
    var max_elements: Optional[Int]

    # Configuration & Presence
    # var config: Optional[Bool]
    var presence: Optional[String]

    # Values
    var default_values: List[String]  ## Can be multiple for leaf-lists

    # Documentation & Features
    var description: Optional[String]
    # var reference: Optional[String]
    var if_features: List[String]
    ## `must` substatements under this refine (parse tree); schema targets also receive clones via refine.
    var must: YangMustStatements
    var when: Optional[YangWhen]

    def has_when(self) -> Bool:
        return Bool(self.when)

    def set_when(mut self, var value: Optional[YangWhen]):
        self.when = value^


@fieldwise_init
struct YangAugmentStmt(Movable):
    ## Data nodes allowed under `augment` (RFC 7950); `uses` is expanded during parse.
    comptime ChildStatement = Variant[
        Arc[YangLeaf],
        Arc[YangLeafList],
        Arc[YangAnydata],
        Arc[YangAnyxml],
        Arc[YangContainer],
        Arc[YangList],
        Arc[YangChoice],
    ]
    var augment_path: String
    var if_features: List[String]
    var when: Optional[YangWhen]
    var statements: List[Self.ChildStatement]

    def has_when(self) -> Bool:
        return Bool(self.when)


@fieldwise_init
struct YangUnknownStatement(Movable):
    var keyword: String
    var argument: String
    var has_argument: Bool


@fieldwise_init
struct YangModuleImport(Movable):
    var local_prefix: String
    var module_name: String


@fieldwise_init
struct YangRevisionStmt(Movable):
    var date: String
    var description: String


@fieldwise_init
struct YangFeatureStmt(Movable):
    var name: String
    var if_features: List[String]
    var description: String


comptime YangModuleStatement = Variant[
    Arc[YangContainer],
    Arc[YangList],
    Arc[YangChoice],
    Arc[YangLeaf],
    Arc[YangLeafList],
    Arc[YangAnydata],
    Arc[YangAnyxml],
    Arc[YangGrouping],
    Arc[YangTypedefStmt],
    Arc[YangIdentityStmt],
    Arc[YangExtensionStmt],
    Arc[YangExtensionInvocationStmt],
    Arc[YangUsesStmt],
    Arc[YangRefineStmt],
    Arc[YangAugmentStmt],
    Arc[YangUnknownStatement],
]


@fieldwise_init
struct YangModule(Movable, JsonDeserializable):
    ## Minimal YANG module representation for JSON/YANG parsing.
    var name: String
    var namespace: String
    var prefix: String
    ## Module-level `description` (RFC 7950); empty if absent in source.
    var description: String
    var yang_version: String
    var belongs_to_module: String
    ## `revision` date strings in module source order (RFC 7950 allows multiple).
    var revisions: List[String]
    ## Parse-tree oriented revision entries with optional substatement data.
    var revision_statements: List[Arc[YangRevisionStmt]]
    var organization: String
    var contact: String
    var typedefs: Dict[String, Arc[YangTypedefStmt]]
    var identities: Dict[String, Arc[YangIdentityStmt]]
    var groupings: Dict[String, Arc[YangGrouping]]
    var features: List[Arc[YangFeatureStmt]]
    var feature_if_features: Dict[String, List[String]]
    var import_prefixes: Dict[String, Arc[YangModuleImport]]
    var extensions: Dict[String, Arc[YangExtensionStmt]]
    ## Parse-tree top-level body statements in source order.
    var statements: List[YangModuleStatement]
    var top_level_containers: List[Arc[YangContainer]]

    def get_name(self) -> String:
        return self.name

    def get_namespace(self) -> String:
        return self.namespace

    def get_prefix(self) -> String:
        return self.prefix

    def get_description(self) -> String:
        return self.description

    def get_revisions(self) -> List[String]:
        return self.revisions.copy()

    def get_organization(self) -> String:
        return self.organization

    def get_contact(self) -> String:
        return self.contact

    ## Returns a copy of the top-level container list; use the `top_level_containers` field when a borrow is enough.
    def get_top_level_containers(self) -> List[Arc[YangContainer]]:
        return self.top_level_containers.copy()

    ## Explicit materialization hook: parse tree -> schema tree currently returns the parser-produced schema list.
    def materialize_top_level_containers(self) -> List[Arc[YangContainer]]:
        return self.top_level_containers.copy()

    def __str__(self) -> String:
        return "YangModule(" + self.name + ", namespace=" + self.namespace + ", prefix=" + self.prefix + ", containers=" + String(len(self.top_level_containers)) + ")"
