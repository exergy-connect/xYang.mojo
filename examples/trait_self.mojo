## `ReflectsSelf.describe_self` enumerates every field of a conforming struct via
## **`reflect[Self]()`**: for each index `i` it prints **`field_names()[i]`** and
## **`reflect[field_type]().name()`** where **`field_type = field_types()[i]`**.
##
## The sample structs below include builtins, custom structs, parametric custom
## structs, type-level literals, std containers, and nested combinations.
##
## String-ish type params are deliberately shown three ways:
## - `StringLiteral` reflects as `<unprintable>` in this Mojo build.
## - `String` reflects as its internal storage tuple, not just the text.
## - a label marker type gives the cleanest reflected type name.

from std.reflection import reflect


trait ReflectsSelf:
    @staticmethod
    def describe_self():
        comptime self_info = reflect[Self]()

        print("Self type: " + self_info.name())
        print("field count: " + String(self_info.field_count()))

        comptime for i in range(self_info.field_count()):
            comptime field_name = self_info.field_names()[i]
            comptime field_type = self_info.field_types()[i]
            print("  " + field_name + ": " + reflect[field_type]().name())


@fieldwise_init
struct EmptyModel(ReflectsSelf):
    pass


@fieldwise_init
struct DeviceModel(ReflectsSelf):
    var hostname: String
    var enabled: Bool
    var mtu: Int


comptime FieldValue = Copyable & Movable & ImplicitlyDestructible


@fieldwise_init
struct Location(Copyable, ImplicitlyDestructible, Movable):
    var rack: String
    var slot: Int


@fieldwise_init
struct InterfaceId(Copyable, ImplicitlyDestructible, Movable):
    var name: String
    var unit: Int


@fieldwise_init
struct Box[T: FieldValue](Copyable, ImplicitlyDestructible, Movable):
    var value: Self.T


@fieldwise_init
struct PairBox[First: FieldValue, Second: FieldValue](
    Copyable, ImplicitlyDestructible, Movable
):
    var first: Self.First
    var second: Self.Second


@fieldwise_init
struct SizedBox[n: Int, T: FieldValue](
    Copyable, ImplicitlyDestructible, Movable
):
    var value: Self.T

    @staticmethod
    def size() -> Int:
        return Self.n


@fieldwise_init
struct NamedValue[name: StringLiteral, T: FieldValue](
    Copyable, ImplicitlyDestructible, Movable
):
    var value: Self.T

    @staticmethod
    def field_name() -> String:
        return String(Self.name)


@fieldwise_init
struct NamedValueByString[name: String, T: FieldValue](
    Copyable, ImplicitlyDestructible, Movable
):
    var value: Self.T

    @staticmethod
    def field_name() -> String:
        return Self.name


@fieldwise_init
struct NamedValueById[id: Int, T: FieldValue](
    Copyable, ImplicitlyDestructible, Movable
):
    var value: Self.T

    @staticmethod
    def field_name() -> String:
        if Self.id == 1:
            return "hostname"
        if Self.id == 2:
            return "location"
        return "<unknown>"


trait FieldLabel:
    @staticmethod
    def label() -> String:
        ...


@fieldwise_init
struct HostnameLabel(Copyable, ImplicitlyDestructible, Movable, FieldLabel):
    @staticmethod
    def label() -> String:
        return "hostname"


@fieldwise_init
struct LocationLabel(Copyable, ImplicitlyDestructible, Movable, FieldLabel):
    @staticmethod
    def label() -> String:
        return "location"


@fieldwise_init
struct NamedValueByLabel[Label: FieldLabel, T: FieldValue](
    Copyable, ImplicitlyDestructible, Movable
):
    var value: Self.T

    @staticmethod
    def field_name() -> String:
        return Self.Label.label()


@fieldwise_init
struct ModelWithCustomFields(ReflectsSelf):
    var location: Location
    var interface_id: InterfaceId
    var boxed_int: Box[Int]
    var boxed_location: Box[Location]
    var pair_builtin_custom: PairBox[String, Location]
    var sized_bool: SizedBox[4, Bool]
    var named_hostname: NamedValue["hostname", String]
    var named_hostname_by_string: NamedValueByString[String("hostname"), String]
    var named_hostname_by_id: NamedValueById[1, String]
    var named_hostname_by_label: NamedValueByLabel[HostnameLabel, String]


@fieldwise_init
struct ModelWithStdContainers(ReflectsSelf):
    var optional_int: Optional[Int]
    var optional_custom: Optional[Location]
    var list_string: List[String]
    var dict_string_int: Dict[String, Int]
    var list_boxed_int: List[Box[Int]]
    var optional_list_string: Optional[List[String]]
    var dict_string_boxed_int: Dict[String, Box[Int]]


@fieldwise_init
struct ModelWithNestedCustomFields(ReflectsSelf):
    var box_of_box: Box[Box[Int]]
    var box_of_pair: Box[PairBox[String, Location]]
    var pair_of_boxes: PairBox[Box[Int], Box[String]]
    var named_boxed_custom: NamedValue["location", Box[Location]]
    var named_boxed_custom_by_string: NamedValueByString[
        String("location"), Box[Location]
    ]
    var named_boxed_custom_by_id: NamedValueById[2, Box[Location]]
    var named_boxed_custom_by_label: NamedValueByLabel[
        LocationLabel, Box[Location]
    ]
    var sized_pair: SizedBox[2, PairBox[InterfaceId, Location]]


def describe_named_value_variants():
    print("NamedValue variant labels")
    print("  " + reflect[NamedValue["hostname", String]]().name())
    print("    field_name(): " + NamedValue["hostname", String].field_name())
    print(
        "  "
        + reflect[NamedValueByString[String("hostname"), String]]().name()
    )
    print(
        "    field_name(): "
        + NamedValueByString[String("hostname"), String].field_name()
    )
    print("  " + reflect[NamedValueById[1, String]]().name())
    print("    field_name(): " + NamedValueById[1, String].field_name())
    print("  " + reflect[NamedValueByLabel[HostnameLabel, String]]().name())
    print(
        "    field_name(): "
        + NamedValueByLabel[HostnameLabel, String].field_name()
    )
    print("")


def describe[T: ReflectsSelf]():
    print(reflect[T]().name() + ".describe_self()")
    T.describe_self()
    print("")


def main():
    describe[EmptyModel]()
    describe[DeviceModel]()
    describe[ModelWithCustomFields]()
    describe[ModelWithStdContainers]()
    describe[ModelWithNestedCustomFields]()
    describe_named_value_variants()
