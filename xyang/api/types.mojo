## Compile-time YANG type descriptors: traits and parametric structs that let
## Mojo structs declare their YANG node kind, leaf types, constraints, list keys,
## and conditional `when` expressions.

from std.memory import ArcPointer

from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule
from xyang.validator.pattern_match import yang_string_matches_xsd_subset

from .reflection_traits import (
    YangInstanceConstructEmitter,
    YangSchemaFieldEmitter,
)

comptime Arc = ArcPointer


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
    NumericRangeConstraint,
    StdTraits,
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
    NumericRangeConstraint,
    StdTraits,
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


trait YangModeled:
    @staticmethod
    def yang_container_name() -> String:
        ...

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        ...

    @staticmethod
    def field_count() -> Int:
        return 0

    @staticmethod
    def field_name[i: Int]() -> String:
        return String()

    @staticmethod
    def append_model_fields(mut parent: YangConstruct) raises:
        ...


trait YangListItem(YangModeled):
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


trait YangDataNodeSpec:
    comptime ChildType: YangModeled
    comptime EntryType: YangListItem

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


trait YangNamedDataNode:
    comptime NodeType: YangDataNodeSpec & LeafModelSpec

    @staticmethod
    def field_name() -> String:
        ...


@fieldwise_init
struct NoYangModel(ImplicitlyDestructible, Movable, YangListItem):
    comptime LIST_KEY = ""

    @staticmethod
    def yang_container_name() -> String:
        return ""

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    @staticmethod
    def append_model_fields(mut parent: YangConstruct) raises:
        pass


trait YangLeafValueReadable:
    def yang_leaf_string_value(read self) -> String:
        ...

    def yang_leaf_bool_value(read self) -> Bool:
        ...

    def yang_leaf_int64_value(read self) -> Int64:
        ...


struct YangField[
    name: StaticString,
    Node: YangDataNodeSpec & LeafModelSpec,
](YangNamedDataNode):
    comptime NodeType = Self.Node

    @staticmethod
    def field_name() -> String:
        return String(Self.name)


struct YangModel[
    name: StaticString,
    *Fields: YangNamedDataNode,
](
    Defaultable,
    ImplicitlyDestructible,
    Movable,
    YangModeled,
):
    def __init__(out self):
        pass

    @staticmethod
    def yang_container_name() -> String:
        return String(Self.name)

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    @staticmethod
    def field_count() -> Int:
        return len(Self.Fields)

    @staticmethod
    def field_name[i: Int]() -> String:
        return Self.Fields[i].field_name()

    @staticmethod
    def append_model_fields(mut parent: YangConstruct) raises:
        _append_explicit_model_fields[*Self.Fields](parent)


struct YangListModel[
    name: StaticString,
    key: StaticString,
    *Fields: YangNamedDataNode,
](
    Defaultable,
    ImplicitlyDestructible,
    Movable,
    YangListItem,
):
    comptime LIST_KEY = Self.key

    def __init__(out self):
        pass

    @staticmethod
    def yang_container_name() -> String:
        return String(Self.name)

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    @staticmethod
    def field_count() -> Int:
        return len(Self.Fields)

    @staticmethod
    def field_name[i: Int]() -> String:
        return Self.Fields[i].field_name()

    @staticmethod
    def append_model_fields(mut parent: YangConstruct) raises:
        _append_explicit_model_fields[*Self.Fields](parent)


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
    Defaultable,
    ImplicitlyDestructible,
    LeafModelSpec,
    Movable,
    YangDataNodeSpec,
    YangInstanceConstructEmitter,
    YangLeafValueReadable,
    YangSchemaFieldEmitter,
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

    def yang_leaf_string_value(read self) -> String:
        return String(self.value)

    def yang_leaf_bool_value(read self) -> Bool:
        return rebind[Bool](self.value)

    def yang_leaf_int64_value(read self) -> Int64:
        comptime keyword = Self.Builtin.yang_type_keyword()
        comptime if (
            keyword == "int64"
            or keyword == "uint32"
            or keyword == "uint64"
        ):
            return rebind[Int64](self.value)
        return Int64(rebind[Int](self.value))

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

    def append_schema_field(
        read self, read name: String, mut parent: YangConstruct
    ) raises:
        _ = self
        var child = _explicit_leaf_construct[Self](name)
        _model_append_stmt(parent, child^)

    def append_instance_field(
        read self, read name: String, mut parent: YangConstruct
    ) raises:
        comptime yt = Self.yang_type_str()
        comptime if yt == "string" or yt == "enumeration":
            _model_append_stmt(
                parent,
                _leaf_instance_construct[Self](name, self.yang_leaf_string_value())^,
            )
        comptime if yt == "boolean":
            var text = "true" if self.yang_leaf_bool_value() else "false"
            _model_append_stmt(
                parent, _leaf_instance_construct[Self](name, text)^
            )
        comptime if (
            yt != "string"
            and yt != "enumeration"
            and yt != "boolean"
        ):
            _model_append_stmt(
                parent,
                _leaf_instance_construct[Self](
                    name, String(self.yang_leaf_int64_value())
                )^,
            )


struct YangLeafList[
    Builtin: YangBuiltinDescriptor,
    C: LeafModelSpec = YangConstraints[],
](
    Defaultable,
    ImplicitlyDestructible,
    LeafModelSpec,
    Movable,
    YangDataNodeSpec,
    YangInstanceConstructEmitter,
    YangSchemaFieldEmitter,
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

    def append_schema_field(
        read self, read name: String, mut parent: YangConstruct
    ) raises:
        _ = self
        var child = _explicit_leaf_list_construct[Self](name)
        _model_append_stmt(parent, child^)

    def append_instance_field(
        read self, read name: String, mut parent: YangConstruct
    ) raises:
        raise Error("leaf-list instance lowering is not implemented yet")


@fieldwise_init
struct YangContainer[
    Child: Movable & ImplicitlyDestructible & Defaultable & YangModeled,
    C: NodeModelSpec = NodeConstraints[],
](
    ImplicitlyDestructible,
    LeafModelSpec,
    Movable,
    NodeModelSpec,
    YangDataNodeSpec,
    YangInstanceConstructEmitter,
    YangSchemaFieldEmitter,
):
    comptime ChildType = Self.Child
    comptime EntryType = NoYangModel
    comptime ConstraintType = Self.C

    var body: Self.Child

    def __init__(out self):
        self.body = Self.Child()

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

    def append_schema_field(
        read self, read name: String, mut parent: YangConstruct
    ) raises:
        _ = self
        var child = _explicit_container_construct[Self](name)
        _model_append_stmt(parent, child^)

    def append_instance_field(
        read self, read name: String, mut parent: YangConstruct
    ) raises:
        var container = _model_stmt("container", name)
        _reflection_append_instance_fields[Self.Child](self.body, container)
        _model_append_stmt(parent, container^)


struct YangList[
    Entry: Movable & ImplicitlyDestructible & YangListItem,
    C: NodeModelSpec = NodeConstraints[],
](
    Defaultable,
    ImplicitlyDestructible,
    LeafModelSpec,
    Movable,
    NodeModelSpec,
    YangDataNodeSpec,
    YangInstanceConstructEmitter,
    YangSchemaFieldEmitter,
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

    def append_schema_field(
        read self, read name: String, mut parent: YangConstruct
    ) raises:
        _ = self
        var child = _explicit_list_construct[Self](name)
        _model_append_stmt(parent, child^)

    def append_instance_field(
        read self, read name: String, mut parent: YangConstruct
    ) raises:
        raise Error("list instance lowering is not implemented yet")


def _model_stmt(keyword: String, argument: String = "") -> YangConstruct:
    var node = YangConstruct(keyword, 0)
    if argument.byte_length() > 0:
        node.set_raw_argument(argument)
    return node^


def _model_append_stmt(mut parent: YangConstruct, var child: YangConstruct):
    parent.children.append(Arc[YangConstruct](child^))


def _model_append_arg(
    mut parent: YangConstruct, keyword: String, argument: String
):
    if argument.byte_length() == 0:
        return
    var child = _model_stmt(keyword, argument)
    _model_append_stmt(parent, child^)


def _append_explicit_leaf_constraints[FT: NodeModelSpec](
    mut node: YangConstruct
):
    if FT.has_yang_when():
        _model_append_stmt(node, _model_stmt("when", FT.yang_when_condition()))
    comptime for i in range(FT.yang_must_count()):
        _model_append_stmt(
            node, _model_stmt("must", FT.yang_must_condition[i]())
        )


def _append_explicit_type_constraints[
    FT: YangDataNodeSpec & LeafModelSpec
](
    mut type_node: YangConstruct, read yt: String
):
    if yt == "enumeration":
        comptime for i in range(FT.yang_enum_count()):
            _model_append_arg(type_node, "enum", FT.yang_enum_value[i]())
    elif yt == "string":
        var max_len = FT.model_max_string_length()
        if max_len >= 0:
            _model_append_arg(type_node, "length", "0.." + String(max_len))
        comptime for i in range(FT.yang_pattern_count()):
            _model_append_arg(type_node, "pattern", FT.yang_pattern_text[i]())
    else:
        if FT.has_model_range():
            _model_append_arg(
                type_node,
                "range",
                String(FT.model_range_min())
                + ".."
                + String(FT.model_range_max()),
            )


def _explicit_leaf_construct[
    FT: YangDataNodeSpec & LeafModelSpec
](read name: String) raises -> YangConstruct:
    var leaf_node = _model_stmt("leaf", name)
    var yt = FT.yang_type_str()
    var type_node = _model_stmt("type", yt)
    _append_explicit_type_constraints[FT](type_node, yt)
    _model_append_stmt(leaf_node, type_node^)
    _append_explicit_leaf_constraints[FT](leaf_node)
    return leaf_node^


def _explicit_leaf_list_construct[
    FT: YangDataNodeSpec & LeafModelSpec
](read name: String) raises -> YangConstruct:
    var node = _model_stmt("leaf-list", name)
    var yt = FT.yang_type_str()
    var type_node = _model_stmt("type", yt)
    _append_explicit_type_constraints[FT](type_node, yt)
    _model_append_stmt(node, type_node^)
    _append_explicit_leaf_constraints[FT](node)
    return node^


def _explicit_container_construct[
    FT: YangDataNodeSpec & LeafModelSpec
](read name: String) raises -> YangConstruct:
    var node = _model_stmt("container", name)
    _append_explicit_leaf_constraints[FT](node)
    FT.ChildType.append_model_fields(node)
    return node^


def _explicit_list_construct[
    FT: YangDataNodeSpec & LeafModelSpec
](read name: String) raises -> YangConstruct:
    var node = _model_stmt("list", name)
    var key = String(FT.EntryType.LIST_KEY)
    if key.byte_length() > 0:
        _model_append_arg(node, "key", key)
    _append_explicit_leaf_constraints[FT](node)
    FT.EntryType.append_model_fields(node)
    return node^


def _append_explicit_model_fields[*Fields: YangNamedDataNode](
    mut parent: YangConstruct
) raises:
    comptime for i in range(len(Fields)):
        comptime FieldType = Fields[i].NodeType
        comptime kind = FieldType.yang_node_kind()
        comptime if kind == "leaf":
            var child = _explicit_leaf_construct[FieldType](
                Fields[i].field_name()
            )
            _model_append_stmt(parent, child^)
        elif kind == "leaf-list":
            var child = _explicit_leaf_list_construct[FieldType](
                Fields[i].field_name()
            )
            _model_append_stmt(parent, child^)
        elif kind == "container":
            var child = _explicit_container_construct[FieldType](
                Fields[i].field_name()
            )
            _model_append_stmt(parent, child^)
        elif kind == "list":
            var child = _explicit_list_construct[FieldType](
                Fields[i].field_name()
            )
            _model_append_stmt(parent, child^)
        else:
            raise Error("unsupported model node kind `" + kind + "`")


def _leaf_instance_construct[
    FT: YangDataNodeSpec & LeafModelSpec,
](read name: String, read value_text: String) raises -> YangConstruct:
    var leaf_node = _model_stmt("leaf", name)
    var yt = FT.yang_type_str()
    var type_node = _model_stmt("type", yt)
    _model_append_stmt(leaf_node, type_node^)
    _model_append_stmt(leaf_node, _model_stmt("value", value_text)^)
    _append_explicit_leaf_constraints[FT](leaf_node)
    return leaf_node^


def _reflection_append_instance_fields[T: YangModeled](
    read instance: T, mut parent: YangConstruct
) raises:
    """Reflection instance walk; implemented here to avoid an import cycle with ``reflection.mojo``."""

    from std.reflection import reflect

    comptime ri = reflect[T]
    comptime for i in range(ri.field_count()):
        comptime nm = String(ri.field_names()[i])
        trait_downcast[YangInstanceConstructEmitter](
            ri.field_ref[i](instance)
        ).append_instance_field(nm, parent)
