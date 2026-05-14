## Compile-time YANG type descriptors: traits and parametric structs that let
## Mojo structs declare their YANG node kind, leaf types, constraints, list keys,
## and conditional `when` expressions.

from xyang.yang.ast.module import YangModule
from xyang.validator.pattern_match import yang_string_matches_xsd_subset


trait StringLengthCap:
    @staticmethod
    def model_max_string_length() -> Int:
        ...


trait StringPatternConstraint:
    @staticmethod
    def yang_pattern_text[i: Int]() -> String:
        ...

    @staticmethod
    def yang_pattern_invert[i: Int]() -> Bool:
        ...

    @staticmethod
    def yang_pattern_count() -> Int:
        ...

    @staticmethod
    def has_yang_pattern() -> Bool:
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


@fieldwise_init
struct NoStringPatternConstraints(
    StdTraits,
    StringPatternConstraint,
):
    @staticmethod
    def yang_pattern_text[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_pattern_invert[i: Int]() -> Bool:
        return False

    @staticmethod
    def yang_pattern_count() -> Int:
        return 0

    @staticmethod
    def has_yang_pattern() -> Bool:
        return False


@fieldwise_init
struct YangPattern[
    *patterns: StaticString,
](
    StdTraits,
    StringPatternConstraint,
):
    @staticmethod
    def yang_pattern_text[i: Int]() -> String:
        return String(Self.patterns[i])

    @staticmethod
    def yang_pattern_invert[i: Int]() -> Bool:
        return False

    @staticmethod
    def yang_pattern_count() -> Int:
        return len(Self.patterns)

    @staticmethod
    def has_yang_pattern() -> Bool:
        return len(Self.patterns) > 0

    @staticmethod
    def comptime_matches[value: StaticString]() -> Bool:
        try:
            var ok = True
            comptime for i in range(len(Self.patterns)):
                var matched = yang_string_matches_xsd_subset(
                    String(Self.patterns[i]), String(value)
                )
                ok = ok and matched
            return ok
        except:
            return False


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

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        ...

    @staticmethod
    def yang_enum_count() -> Int:
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

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_enum_count() -> Int:
        return 0


@fieldwise_init
struct YangEnum[
    *values: StaticString,
](
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = String

    @staticmethod
    def yang_type_keyword() -> String:
        return "enumeration"

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String(Self.values[i])

    @staticmethod
    def yang_enum_count() -> Int:
        return len(Self.values)


@fieldwise_init
struct YangBuiltinBool(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Bool

    @staticmethod
    def yang_type_keyword() -> String:
        return "boolean"

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_enum_count() -> Int:
        return 0


@fieldwise_init
struct YangBuiltinInt8(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int

    @staticmethod
    def yang_type_keyword() -> String:
        return "int8"

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_enum_count() -> Int:
        return 0


@fieldwise_init
struct YangBuiltinInt16(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int

    @staticmethod
    def yang_type_keyword() -> String:
        return "int16"

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_enum_count() -> Int:
        return 0


@fieldwise_init
struct YangBuiltinInt32(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int

    @staticmethod
    def yang_type_keyword() -> String:
        return "int32"

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_enum_count() -> Int:
        return 0


@fieldwise_init
struct YangBuiltinInt64(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int64

    @staticmethod
    def yang_type_keyword() -> String:
        return "int64"

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_enum_count() -> Int:
        return 0


@fieldwise_init
struct YangBuiltinUInt8(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int

    @staticmethod
    def yang_type_keyword() -> String:
        return "uint8"

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_enum_count() -> Int:
        return 0


@fieldwise_init
struct YangBuiltinUInt16(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int

    @staticmethod
    def yang_type_keyword() -> String:
        return "uint16"

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_enum_count() -> Int:
        return 0


@fieldwise_init
struct YangBuiltinUInt32(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int64

    @staticmethod
    def yang_type_keyword() -> String:
        return "uint32"

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_enum_count() -> Int:
        return 0


@fieldwise_init
struct YangBuiltinUInt64(
    StdTraits,
    YangBuiltinDescriptor,
):
    comptime Value = Int64

    @staticmethod
    def yang_type_keyword() -> String:
        return "uint64"

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_enum_count() -> Int:
        return 0


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


trait YangListItem:
    comptime LIST_KEY: StaticString


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


comptime LeafModelSpec = StringLengthCap & StringPatternConstraint & NumericRangeConstraint & NodeModelSpec


trait YangModeled:
    @staticmethod
    def yang_container_name() -> String:
        ...

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        ...


@fieldwise_init
struct NoYangModel(ImplicitlyDestructible, Movable, YangListItem, YangModeled):
    comptime LIST_KEY = ""

    @staticmethod
    def yang_container_name() -> String:
        return ""

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass


trait YangDataNodeSpec:
    comptime ChildType: YangModeled
    comptime EntryType: YangModeled & YangListItem

    @staticmethod
    def yang_node_kind() -> String:
        ...

    @staticmethod
    def yang_type_str() -> String:
        ...

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        ...

    @staticmethod
    def yang_enum_count() -> Int:
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
    Pattern: StringPatternConstraint = NoStringPatternConstraints,
    When: YangWhenPredicate = NoYangWhen,
    Must: YangMustConstraints = NoYangMust,
](LeafModelSpec):

    @staticmethod
    def model_max_string_length() -> Int:
        return Self.Constraints.model_max_string_length()

    @staticmethod
    def yang_pattern_text[i: Int]() -> String:
        return Self.Pattern.yang_pattern_text[i]()

    @staticmethod
    def yang_pattern_invert[i: Int]() -> Bool:
        return Self.Pattern.yang_pattern_invert[i]()

    @staticmethod
    def yang_pattern_count() -> Int:
        return Self.Pattern.yang_pattern_count()

    @staticmethod
    def has_yang_pattern() -> Bool:
        return Self.Pattern.has_yang_pattern()

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

struct YangLeaf[
    Builtin: YangBuiltinDescriptor,
    C: LeafModelSpec = YangConstraints[],
](
    ImplicitlyDestructible,
    LeafModelSpec,
    Movable,
    Defaultable,
    YangDataNodeSpec,
):
    comptime BuiltinType = Self.Builtin
    comptime ConstraintType = Self.C
    comptime ChildType = NoYangModel
    comptime EntryType = NoYangModel

    var value: Self.Builtin.Value

    def __init__(out self):
        self.value = Self.Builtin.Value()

    @staticmethod
    def yang_node_kind() -> String:
        return "leaf"

    @staticmethod
    def yang_type_str() -> String:
        return Self.Builtin.yang_type_keyword()

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return Self.Builtin.yang_enum_value[i]()

    @staticmethod
    def yang_enum_count() -> Int:
        return Self.Builtin.yang_enum_count()

    @staticmethod
    def model_max_string_length() -> Int:
        return Self.C.model_max_string_length()

    @staticmethod
    def yang_pattern_text[i: Int]() -> String:
        return Self.C.yang_pattern_text[i]()

    @staticmethod
    def yang_pattern_invert[i: Int]() -> Bool:
        return Self.C.yang_pattern_invert[i]()

    @staticmethod
    def yang_pattern_count() -> Int:
        return Self.C.yang_pattern_count()

    @staticmethod
    def has_yang_pattern() -> Bool:
        return Self.C.has_yang_pattern()

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


struct YangLeafList[
    Builtin: YangBuiltinDescriptor,
    C: LeafModelSpec = YangConstraints[],
](
    ImplicitlyDestructible,
    LeafModelSpec,
    Movable,
    Defaultable,
    YangDataNodeSpec,
):
    comptime BuiltinType = Self.Builtin
    comptime ConstraintType = Self.C
    comptime ChildType = NoYangModel
    comptime EntryType = NoYangModel

    var values: List[Self.Builtin.Value]

    def __init__(out self):
        self.values = List[Self.Builtin.Value]()

    @staticmethod
    def yang_node_kind() -> String:
        return "leaf-list"

    @staticmethod
    def yang_type_str() -> String:
        return Self.Builtin.yang_type_keyword()

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return Self.Builtin.yang_enum_value[i]()

    @staticmethod
    def yang_enum_count() -> Int:
        return Self.Builtin.yang_enum_count()

    @staticmethod
    def model_max_string_length() -> Int:
        return Self.C.model_max_string_length()

    @staticmethod
    def yang_pattern_text[i: Int]() -> String:
        return Self.C.yang_pattern_text[i]()

    @staticmethod
    def yang_pattern_invert[i: Int]() -> Bool:
        return Self.C.yang_pattern_invert[i]()

    @staticmethod
    def yang_pattern_count() -> Int:
        return Self.C.yang_pattern_count()

    @staticmethod
    def has_yang_pattern() -> Bool:
        return Self.C.has_yang_pattern()

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
](
    ImplicitlyDestructible,
    LeafModelSpec,
    Movable,
    NodeModelSpec,
    YangDataNodeSpec,
):
    comptime ChildType = Self.Child
    comptime EntryType = NoYangModel
    comptime ConstraintType = Self.C

    var body: Self.Child

    @staticmethod
    def yang_node_kind() -> String:
        return "container"

    @staticmethod
    def yang_type_str() -> String:
        return String()

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_enum_count() -> Int:
        return 0

    @staticmethod
    def yang_name() -> String:
        return Self.Child.yang_container_name()

    @staticmethod
    def model_max_string_length() -> Int:
        return -1

    @staticmethod
    def yang_pattern_text[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_pattern_invert[i: Int]() -> Bool:
        return False

    @staticmethod
    def yang_pattern_count() -> Int:
        return 0

    @staticmethod
    def has_yang_pattern() -> Bool:
        return False

    @staticmethod
    def model_range_min() -> Int64:
        return 0

    @staticmethod
    def model_range_max() -> Int64:
        return 0

    @staticmethod
    def has_model_range() -> Bool:
        return False

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


struct YangList[
    Entry: Movable & ImplicitlyDestructible & YangListItem & YangModeled,
    C: NodeModelSpec = NodeConstraints[],
](
    ImplicitlyDestructible,
    LeafModelSpec,
    Movable,
    Defaultable,
    NodeModelSpec,
    YangDataNodeSpec,
):
    comptime ChildType = NoYangModel
    comptime EntryType = Self.Entry
    comptime ConstraintType = Self.C

    def __init__(out self):
        pass

    @staticmethod
    def yang_node_kind() -> String:
        return "list"

    @staticmethod
    def yang_type_str() -> String:
        return String()

    @staticmethod
    def yang_enum_value[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_enum_count() -> Int:
        return 0

    @staticmethod
    def yang_name() -> String:
        return Self.Entry.yang_container_name()

    @staticmethod
    def model_max_string_length() -> Int:
        return -1

    @staticmethod
    def yang_pattern_text[i: Int]() -> String:
        return String()

    @staticmethod
    def yang_pattern_invert[i: Int]() -> Bool:
        return False

    @staticmethod
    def yang_pattern_count() -> Int:
        return 0

    @staticmethod
    def has_yang_pattern() -> Bool:
        return False

    @staticmethod
    def model_range_min() -> Int64:
        return 0

    @staticmethod
    def model_range_max() -> Int64:
        return 0

    @staticmethod
    def has_model_range() -> Bool:
        return False

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
