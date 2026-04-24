## Minimal YANG AST model in Mojo for xYang.mojo.

from std.memory import ArcPointer
from std.utils import Variant
from emberjson import JsonDeserializable
from xyang.xpath import Expr

comptime Arc = ArcPointer


## --- YANG `type` statement: lexical name + constraint payload (mutually exclusive shapes). ---


@fieldwise_init
struct YangTypePlain(Movable):
    var _pad: UInt8


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
    var has_leafref_path: Bool
    var leafref_path: String
    var leafref_require_instance: Bool
    var leafref_xpath_ast: Expr.ExprPointer
    var leafref_path_parsed: Bool

    fn __del__(deinit self):
        if self.leafref_xpath_ast:
            self.leafref_xpath_ast[].free_tree()
            self.leafref_xpath_ast.destroy_pointee()
            self.leafref_xpath_ast.free()


@fieldwise_init
struct YangTypeBits(Movable):
    var bits_names: List[String]


@fieldwise_init
struct YangTypeIdentityref(Movable):
    var identityref_base: String


@fieldwise_init
struct YangType(Movable):
    comptime Constraints = Variant[
        YangTypePlain,
        YangTypeIntegerRange,
        YangTypeDecimal64,
        YangTypeEnumeration,
        YangTypeLeafref,
        YangTypeBits,
        YangTypeIdentityref,
    ]
    var name: String
    var constraints: Self.Constraints
    ## Populated only for `name == "union"`; otherwise empty.
    var union_members: List[Arc[YangType]]

    fn __del__(deinit self):
        # Ensure leafref XPath storage is freed when this arm is active (`take` runs `YangTypeLeafref.__del__`).
        if self.constraints.isa[YangTypeLeafref]():
            _ = self.constraints.take[YangTypeLeafref]()

    def __str__(self) -> String:
        if self.constraints.isa[YangTypeLeafref]():
            ref lr = self.constraints[YangTypeLeafref]
            if lr.has_leafref_path:
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
            return (
                "YangType("
                + self.name
                + ", types="
                + String(len(self.union_members))
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
        return len(self.union_members)

    def union_member_arc(read self, i: Int) -> Arc[YangType]:
        return self.union_members[i]

    # --- leafref ---

    def has_leafref_path(read self) -> Bool:
        if self.constraints.isa[YangTypeLeafref]():
            return self.constraints[YangTypeLeafref].has_leafref_path
        return False

    def leafref_path(read self) -> String:
        if self.constraints.isa[YangTypeLeafref]():
            return self.constraints[YangTypeLeafref].leafref_path
        return ""

    def leafref_require_instance(read self) -> Bool:
        if self.constraints.isa[YangTypeLeafref]():
            return self.constraints[YangTypeLeafref].leafref_require_instance
        return True

    def leafref_path_parsed(read self) -> Bool:
        if self.constraints.isa[YangTypeLeafref]():
            return self.constraints[YangTypeLeafref].leafref_path_parsed
        return False

    def leafref_xpath_ast(read self) -> Expr.ExprPointer:
        if self.constraints.isa[YangTypeLeafref]():
            return self.constraints[YangTypeLeafref].leafref_xpath_ast
        return Expr.ExprPointer()

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


@fieldwise_init
struct YangMust(Movable):
    ## Represents a YANG `must` expression attached to a leaf.
    ## - expression: raw XPath string from the schema (x-yang.must[].must)
    ## - xpath_ast: parsed XPath AST root when parsed=True; do not dereference when parsed=False.
    ## - parsed: True when parse_xpath succeeded; validator only evaluates when parsed.
    var expression: String
    var error_message: String
    var description: String
    var xpath_ast: Expr.ExprPointer
    var parsed: Bool

    fn __del__(deinit self):
        if self.xpath_ast:
            self.xpath_ast[].free_tree()
            self.xpath_ast.destroy_pointee()
            self.xpath_ast.free()


@fieldwise_init
struct YangWhen(Movable):
    ## Represents a YANG `when` expression attached to a statement.
    var expression: String
    var description: String
    var xpath_ast: Expr.ExprPointer
    var parsed: Bool

    fn __del__(deinit self):
        if self.xpath_ast:
            self.xpath_ast[].free_tree()
            self.xpath_ast.destroy_pointee()
            self.xpath_ast.free()


trait YangHasMustStatements:
    ## Shared access to a (possibly empty) list of `must` constraints.
    def must_count(self) -> Int:
        ...

    def set_must_statements(mut self, var stmts: List[Arc[YangMust]]):
        ...


trait YangHasWhen:
    ## Shared access to an optional `when` constraint.
    def has_when(self) -> Bool:
        ...

    def set_when(mut self, var value: Optional[YangWhen]):
        ...


@fieldwise_init
struct YangLeaf(Movable, JsonDeserializable, YangHasMustStatements, YangHasWhen):
    var name: String
    var type: YangType
    var mandatory: Bool
    var has_default: Bool
    var default_value: String
    ## True when the YANG `default` argument was a quoted string, or JSON Schema default is a string on a union type.
    ## Used so JSON `default` keeps the user’s type (e.g. string `"42"` vs integer `42`) for `oneOf` unions.
    var default_argument_was_quoted: Bool
    var must_statements: List[Arc[YangMust]]
    var when: Optional[YangWhen]

    def must_count(self) -> Int:
        return len(self.must_statements)

    def set_must_statements(mut self, var stmts: List[Arc[YangMust]]):
        self.must_statements = stmts^

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
            + String(len(self.must_statements))
            + ", has_when="
            + ("true" if self.has_when() else "false")
            + ")"
        )


@fieldwise_init
struct YangLeafList(Movable, JsonDeserializable, YangHasMustStatements, YangHasWhen):
    var name: String
    var type: YangType
    var default_values: List[String]
    var must_statements: List[Arc[YangMust]]
    var when: Optional[YangWhen]
    ## RFC 7950: unset when `min_elements` / `max_elements` are `-1`.
    var min_elements: Int
    var max_elements: Int
    ## RFC 7950 §7.7.1: `user` or `system`; empty if not specified in the model source.
    var ordered_by: String

    def must_count(self) -> Int:
        return len(self.must_statements)

    def set_must_statements(mut self, var stmts: List[Arc[YangMust]]):
        self.must_statements = stmts^

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
            + String(len(self.must_statements))
            + ", has_when="
            + ("true" if self.has_when() else "false")
            + ")"
        )


@fieldwise_init
struct YangChoiceCase(Movable, JsonDeserializable, YangHasWhen):
    var name: String
    var node_names: List[String]
    var when: Optional[YangWhen]

    def has_when(self) -> Bool:
        return Bool(self.when)

    def set_when(mut self, var value: Optional[YangWhen]):
        self.when = value^


@fieldwise_init
struct YangChoice(Movable, JsonDeserializable, YangHasWhen):
    var name: String
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
    var leaves: List[Arc[YangLeaf]]
    var leaf_lists: List[Arc[YangLeafList]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]

    def __str__(self) -> String:
        var nleaf = len(self.leaves)
        var nleaflist = len(self.leaf_lists)
        var ncont = len(self.containers)
        var nlist = len(self.lists)
        var nchoice = len(self.choices)
        return "YangContainer(" + self.name + ", leaves=" + String(nleaf) + ", leaf-lists=" + String(nleaflist) + ", containers=" + String(ncont) + ", lists=" + String(nlist) + ", choices=" + String(nchoice) + ")"


@fieldwise_init
struct YangList(Movable, JsonDeserializable):
    var name: String
    var key: String
    var description: String
    var leaves: List[Arc[YangLeaf]]
    var leaf_lists: List[Arc[YangLeafList]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]
    ## RFC 7950: unset when `min_elements` / `max_elements` are `-1`.
    var min_elements: Int
    var max_elements: Int
    var ordered_by: String
    ## Each inner list is one `unique` statement: descendant leaf names (same list entry).
    var unique_specs: List[List[String]]

    def __str__(self) -> String:
        var nleaf = len(self.leaves)
        var nleaflist = len(self.leaf_lists)
        var ncont = len(self.containers)
        var nlist = len(self.lists)
        var nchoice = len(self.choices)
        return "YangList(" + self.name + ", key=" + self.key + ", leaves=" + String(nleaf) + ", leaf-lists=" + String(nleaflist) + ", containers=" + String(ncont) + ", lists=" + String(nlist) + ", choices=" + String(nchoice) + ")"


@fieldwise_init
struct YangModule(Movable, JsonDeserializable):
    ## Minimal YANG module representation for JSON/YANG parsing.
    var name: String
    var namespace: String
    var prefix: String
    ## Module-level `description` (RFC 7950); empty if absent in source.
    var description: String
    ## `revision` date strings in module source order (RFC 7950 allows multiple). Substatements inside each revision block are not modeled.
    var revisions: List[String]
    var organization: String
    var contact: String
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

    def __str__(self) -> String:
        return "YangModule(" + self.name + ", namespace=" + self.namespace + ", prefix=" + self.prefix + ", containers=" + String(len(self.top_level_containers)) + ")"
