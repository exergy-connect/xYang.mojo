## Compile-time YANG type descriptors: traits and parametric structs that let
## Mojo structs declare their YANG node kind, leaf types, constraints, list keys,
## and conditional `when` expressions.

from xyang.yang.ast.module import YangModule


trait StringLengthCap:
    @staticmethod
    def model_max_string_length() -> Int:
        ...

comptime StdTraits = Copyable & Defaultable & ImplicitlyDestructible & Movable & Writable

@fieldwise_init
struct NoStringConstraints(
    StdTraits,
    StringLengthCap,
):
    @staticmethod
    def model_max_string_length() -> Int:
        return -1


@fieldwise_init
struct MaxStringLength[
    n: Int,
](
    StdTraits,
    StringLengthCap,
):
    @staticmethod
    def model_max_string_length() -> Int:
        return Self.n


trait NumericRangeConstraint:
    @staticmethod
    def model_range_min() -> Int64:
        ...

    @staticmethod
    def model_range_max() -> Int64:
        ...

    @staticmethod
    def has_model_range() -> Bool:
        ...


@fieldwise_init
struct NoNumericRange(
    StdTraits,
    NumericRangeConstraint,
):
    @staticmethod
    def model_range_min() -> Int64:
        return 0

    @staticmethod
    def model_range_max() -> Int64:
        return 0

    @staticmethod
    def has_model_range() -> Bool:
        return False


@fieldwise_init
struct YangRange[
    min: Int64,
    max: Int64,
](
    StdTraits,
    NumericRangeConstraint,
):
    @staticmethod
    def model_range_min() -> Int64:
        return Self.min

    @staticmethod
    def model_range_max() -> Int64:
        return Self.max

    @staticmethod
    def has_model_range() -> Bool:
        return True


trait YangBuiltinDescriptor:
    comptime Value: StdTraits

    @staticmethod
    def yang_type_keyword() -> String:
        ...


@fieldwise_init
struct YangBuiltinString(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = String

    @staticmethod
    def yang_type_keyword() -> String:
        return "string"


@fieldwise_init
struct YangBuiltinBool(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Bool

    @staticmethod
    def yang_type_keyword() -> String:
        return "boolean"


@fieldwise_init
struct YangBuiltinInt8(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int

    @staticmethod
    def yang_type_keyword() -> String:
        return "int8"


@fieldwise_init
struct YangBuiltinInt16(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int

    @staticmethod
    def yang_type_keyword() -> String:
        return "int16"


@fieldwise_init
struct YangBuiltinInt32(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int

    @staticmethod
    def yang_type_keyword() -> String:
        return "int32"


@fieldwise_init
struct YangBuiltinInt64(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int64

    @staticmethod
    def yang_type_keyword() -> String:
        return "int64"


@fieldwise_init
struct YangBuiltinUInt8(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int

    @staticmethod
    def yang_type_keyword() -> String:
        return "uint8"


@fieldwise_init
struct YangBuiltinUInt16(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int

    @staticmethod
    def yang_type_keyword() -> String:
        return "uint16"


@fieldwise_init
struct YangBuiltinUInt32(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int64

    @staticmethod
    def yang_type_keyword() -> String:
        return "uint32"


@fieldwise_init
struct YangBuiltinUInt64(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int64

    @staticmethod
    def yang_type_keyword() -> String:
        return "uint64"


trait YangWhenPredicate:
    @staticmethod
    def yang_when_condition() -> String:
        ...

    @staticmethod
    def has_yang_when() -> Bool:
        ...


@fieldwise_init
struct NoYangWhen(
    StdTraits,
    YangWhenPredicate,
):
    @staticmethod
    def yang_when_condition() -> String:
        return String()

    @staticmethod
    def has_yang_when() -> Bool:
        return False


@fieldwise_init
struct YangWhen[
    condition: StringLiteral,
](
    StdTraits,
    YangWhenPredicate,
):
    @staticmethod
    def yang_when_condition() -> String:
        return String(Self.condition)

    @staticmethod
    def has_yang_when() -> Bool:
        return True


trait YangMustConstraints:
    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        ...

    @staticmethod
    def yang_must_count() -> Int:
        ...

    @staticmethod
    def has_yang_must() -> Bool:
        ...


@fieldwise_init
struct NoYangMust(
    StdTraits,
    YangMustConstraints,
):
    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        return ""

    @staticmethod
    def yang_must_count() -> Int:
        return 0

    @staticmethod
    def has_yang_must() -> Bool:
        return False


@fieldwise_init
struct YangMust[
    *conditions: StaticString,
](
    StdTraits,
    YangMustConstraints,
):
    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        return String(Self.conditions[i])

    @staticmethod
    def yang_must_count() -> Int:
        return len(Self.conditions)

    @staticmethod
    def has_yang_must() -> Bool:
        return len(Self.conditions) > 0


trait YangListKey:
    @staticmethod
    def yang_key_text() -> String:
        ...

    @staticmethod
    def has_yang_key() -> Bool:
        ...


@fieldwise_init
struct NoYangKey(
    StdTraits,
    YangListKey,
):
    @staticmethod
    def yang_key_text() -> String:
        return String()

    @staticmethod
    def has_yang_key() -> Bool:
        return False


@fieldwise_init
struct YangKey[
    name: StringLiteral,
](
    StdTraits,
    YangListKey,
):
    @staticmethod
    def yang_key_text() -> String:
        return String(Self.name)

    @staticmethod
    def has_yang_key() -> Bool:
        return True


trait YangDataNodeSpec:
    @staticmethod
    def yang_node_kind() -> String:
        ...


trait NodeModelSpec:
    @staticmethod
    def yang_when_condition() -> String:
        ...

    @staticmethod
    def has_yang_when() -> Bool:
        ...

    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        ...

    @staticmethod
    def yang_must_count() -> Int:
        ...

    @staticmethod
    def has_yang_must() -> Bool:
        ...


trait LeafModelSpec:
    @staticmethod
    def model_max_string_length() -> Int:
        ...

    @staticmethod
    def model_range_min() -> Int64:
        ...

    @staticmethod
    def model_range_max() -> Int64:
        ...

    @staticmethod
    def has_model_range() -> Bool:
        ...

    @staticmethod
    def yang_when_condition() -> String:
        ...

    @staticmethod
    def has_yang_when() -> Bool:
        ...

    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        ...

    @staticmethod
    def yang_must_count() -> Int:
        ...

    @staticmethod
    def has_yang_must() -> Bool:
        ...


trait YangModeled:
    @staticmethod
    def yang_container_name() -> String:
        ...

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        ...


struct NodeConstraints[
    When: YangWhenPredicate = NoYangWhen,
    Must: YangMustConstraints = NoYangMust,
](NodeModelSpec):

    @staticmethod
    def yang_when_condition() -> String:
        return Self.When.yang_when_condition()

    @staticmethod
    def has_yang_when() -> Bool:
        return Self.When.has_yang_when()

    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        return Self.Must.yang_must_condition[i]()

    @staticmethod
    def yang_must_count() -> Int:
        return Self.Must.yang_must_count()

    @staticmethod
    def has_yang_must() -> Bool:
        return Self.Must.has_yang_must()


struct YangConstraints[
    Constraints: StringLengthCap = NoStringConstraints,
    Range: NumericRangeConstraint = NoNumericRange,
    When: YangWhenPredicate = NoYangWhen,
    Must: YangMustConstraints = NoYangMust,
](LeafModelSpec):

    @staticmethod
    def model_max_string_length() -> Int:
        return Self.Constraints.model_max_string_length()

    @staticmethod
    def model_range_min() -> Int64:
        return Self.Range.model_range_min()

    @staticmethod
    def model_range_max() -> Int64:
        return Self.Range.model_range_max()

    @staticmethod
    def has_model_range() -> Bool:
        return Self.Range.has_model_range()

    @staticmethod
    def yang_when_condition() -> String:
        return Self.When.yang_when_condition()

    @staticmethod
    def has_yang_when() -> Bool:
        return Self.When.has_yang_when()

    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        return Self.Must.yang_must_condition[i]()

    @staticmethod
    def yang_must_count() -> Int:
        return Self.Must.yang_must_count()

    @staticmethod
    def has_yang_must() -> Bool:
        return Self.Must.has_yang_must()

@fieldwise_init
struct YangLeaf[
    Builtin: YangBuiltinDescriptor,
    C: LeafModelSpec = YangConstraints[],
](ImplicitlyDestructible, LeafModelSpec, Movable, YangDataNodeSpec):
    var value: Self.Builtin.Value

    @staticmethod
    def yang_node_kind() -> String:
        return "leaf"

    @staticmethod
    def yang_type_str() -> String:
        return Self.Builtin.yang_type_keyword()

    @staticmethod
    def model_max_string_length() -> Int:
        return Self.C.model_max_string_length()

    @staticmethod
    def model_range_min() -> Int64:
        return Self.C.model_range_min()

    @staticmethod
    def model_range_max() -> Int64:
        return Self.C.model_range_max()

    @staticmethod
    def has_model_range() -> Bool:
        return Self.C.has_model_range()

    @staticmethod
    def yang_when_condition() -> String:
        return Self.C.yang_when_condition()

    @staticmethod
    def has_yang_when() -> Bool:
        return Self.C.has_yang_when()

    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        return Self.C.yang_must_condition[i]()

    @staticmethod
    def yang_must_count() -> Int:
        return Self.C.yang_must_count()

    @staticmethod
    def has_yang_must() -> Bool:
        return Self.C.has_yang_must()


@fieldwise_init
struct YangLeafList[
    Builtin: YangBuiltinDescriptor,
    C: LeafModelSpec = YangConstraints[],
](ImplicitlyDestructible, LeafModelSpec, Movable, YangDataNodeSpec):
    var values: List[Self.Builtin.Value]

    @staticmethod
    def yang_node_kind() -> String:
        return "leaf-list"

    @staticmethod
    def yang_type_str() -> String:
        return Self.Builtin.yang_type_keyword()

    @staticmethod
    def model_max_string_length() -> Int:
        return Self.C.model_max_string_length()

    @staticmethod
    def model_range_min() -> Int64:
        return Self.C.model_range_min()

    @staticmethod
    def model_range_max() -> Int64:
        return Self.C.model_range_max()

    @staticmethod
    def has_model_range() -> Bool:
        return Self.C.has_model_range()

    @staticmethod
    def yang_when_condition() -> String:
        return Self.C.yang_when_condition()

    @staticmethod
    def has_yang_when() -> Bool:
        return Self.C.has_yang_when()

    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        return Self.C.yang_must_condition[i]()

    @staticmethod
    def yang_must_count() -> Int:
        return Self.C.yang_must_count()

    @staticmethod
    def has_yang_must() -> Bool:
        return Self.C.has_yang_must()


@fieldwise_init
struct YangContainer[
    Child: Movable & ImplicitlyDestructible & YangModeled,
    C: NodeModelSpec = NodeConstraints[],
](ImplicitlyDestructible, Movable, NodeModelSpec, YangDataNodeSpec):
    var body: Self.Child

    @staticmethod
    def yang_node_kind() -> String:
        return "container"

    @staticmethod
    def yang_name() -> String:
        return Self.Child.yang_container_name()

    @staticmethod
    def yang_when_condition() -> String:
        return Self.C.yang_when_condition()

    @staticmethod
    def has_yang_when() -> Bool:
        return Self.C.has_yang_when()

    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        return Self.C.yang_must_condition[i]()

    @staticmethod
    def yang_must_count() -> Int:
        return Self.C.yang_must_count()

    @staticmethod
    def has_yang_must() -> Bool:
        return Self.C.has_yang_must()


@fieldwise_init
struct YangList[
    Entry: Movable & ImplicitlyDestructible & YangModeled,
    Key: YangListKey = NoYangKey,
    C: NodeModelSpec = NodeConstraints[],
](ImplicitlyDestructible, Movable, NodeModelSpec, YangDataNodeSpec):
    @staticmethod
    def yang_node_kind() -> String:
        return "list"

    @staticmethod
    def yang_name() -> String:
        return Self.Entry.yang_container_name()

    @staticmethod
    def yang_key_text() -> String:
        return Self.Key.yang_key_text()

    @staticmethod
    def has_yang_key() -> Bool:
        return Self.Key.has_yang_key()

    @staticmethod
    def yang_when_condition() -> String:
        return Self.C.yang_when_condition()

    @staticmethod
    def has_yang_when() -> Bool:
        return Self.C.has_yang_when()

    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        return Self.C.yang_must_condition[i]()

    @staticmethod
    def yang_must_count() -> Int:
        return Self.C.yang_must_count()

    @staticmethod
    def has_yang_must() -> Bool:
        return Self.C.has_yang_must()
