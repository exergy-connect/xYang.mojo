from std.reflection import (
    get_type_name,
    struct_field_count,
    struct_field_names,
    struct_field_types,
    struct_field_index_by_name,
)

comptime Cardinality = UInt8
comptime `0`: Cardinality = 0
comptime `1`: Cardinality = 1
comptime `0..1`: Cardinality = 2
comptime `0..n`: Cardinality = 3
comptime `1..n`: Cardinality = 4

comptime Kw = UInt8

trait HasCardinality:
    @staticmethod
    def get_cardinality(ref self) -> Cardinality:
        ...

@fieldwise_init
struct YangString[cardinality: Cardinality](Movable, HasCardinality):
    var text: String

    def __init__(out self):
        self.text = String()
    
    @staticmethod
    def get_cardinality(ref self) -> Cardinality:
        return Self.cardinality

struct YangKeywords:
    var description: YangString[`0..1`]
    var `yang-version`: YangString[`0..1`]
    var namespace: YangString[`1`]
    var prefix: YangString[`1`]
    var organization: YangString[`0..1`]
    var contact: YangString[`0..1`]

comptime KEYWORD_COUNT: Int = struct_field_count[YangKeywords]()
comptime RuleTable = InlineArray[Cardinality, KEYWORD_COUNT]

@fieldwise_init
struct YangModule(Movable):
    var module_name: YangString[`1`]
    var `yang-version`: YangString[`0..1`]
    var namespace: YangString[`1`]
    var prefix: YangString[`1`]
    var organization: YangString[`0..1`]
    var contact: YangString[`0..1`]
    var description: YangString[`0..1`]


def table[T: AnyType]() -> RuleTable:
    var result = RuleTable(fill=`0`)
    comptime types = struct_field_types[T]()
    comptime for i in range(struct_field_count[T]()):
        comptime _name = struct_field_names[T]()[i]
        comptime for kw in range(struct_field_count[YangKeywords]()):
            comptime if struct_field_names[YangKeywords]()[kw] == _name:
                comptime field_type = struct_field_types[T]()[i]
                comptime type_name = get_type_name[field_type]()
                result[kw] = `0..1` if String(`0..1`) in type_name else `1`
                
                # comptime if conforms_to(field_type,HasCardinality):
                #     result[kw] = trait_downcast[HasCardinality](field_type).get_cardinality()
                print(_name + " " + type_name)

    return result^


def main() raises:
    print("YangModule field count: " + String(struct_field_count[YangModule]()))
    var rules = table[YangModule]()
    print(rules)
