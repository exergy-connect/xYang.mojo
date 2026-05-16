## Standalone Mojo compiler latency repro.
##
## This file intentionally does not import xYang. It reduces the former
## `JsonValue.to_string()` timeout to:
##
## - a recursive JSON-like value type (`Obj` / `Arr` hold `Arc[Value]`),
## - a `Variant` payload,
## - a recursive `to_string()` method for object/array cases,
## - and a `comptime InlineArray` of thin function pointers for scalar cases.
##
## On Mojo 1.0.0b2.dev2026051506 this does not finish within 20s:
##
##   pixi run bash -lc 'timeout 20s mojo issues/standalone_recursive_fn_table_compile_repro.mojo'
##
## Removing the scalar function-pointer table and replacing it with direct
## `kind` branches makes the equivalent code compile/run in a few seconds.

from std.memory import ArcPointer
from std.utils import Variant

comptime Arc = ArcPointer


@fieldwise_init
struct Obj(Movable):
    var keys: List[String]
    var values: List[Arc[Value]]


@fieldwise_init
struct Arr(Movable):
    var values: List[Arc[Value]]


@fieldwise_init
struct Str(Movable):
    var value: String


@fieldwise_init
struct IntVal(Movable):
    var value: Int


struct Null(Movable):
    def __init__(out self):
        pass

    def __init__(out self, *, deinit take: Self):
        pass


comptime Payload = Variant[Obj, Arr, Str, IntVal, Null]


struct Value(ImplicitlyDestructible, Movable):
    comptime Kind = UInt8
    comptime OBJECT: Self.Kind = 0
    comptime ARRAY: Self.Kind = 1
    comptime STRING: Self.Kind = 2
    comptime INT: Self.Kind = 3
    comptime NULL: Self.Kind = 4

    var kind: Self.Kind
    var payload: Payload

    def __init__(out self, kind: Self.Kind, var payload: Payload):
        self.kind = kind
        self.payload = payload^

    def __init__(out self, *, deinit take: Self):
        self.kind = take.kind
        self.payload = take.payload^

    def to_string(read self) raises -> String:
        if self.kind == Self.OBJECT:
            ref obj = self.payload[Obj]
            var s = String("{")
            for i in range(len(obj.keys)):
                if i > 0:
                    s += ","
                s += '"' + obj.keys[i] + '":'
                s += obj.values[i][].to_string()
            s += "}"
            return s^
        if self.kind == Self.ARRAY:
            ref arr = self.payload[Arr]
            var s = String("[")
            for i in range(len(arr.values)):
                if i > 0:
                    s += ","
                s += arr.values[i][].to_string()
            s += "]"
            return s^
        return SERIALIZERS[self.kind](self)


comptime Serializer = def(read Value) raises thin -> String


@always_inline
def string_to_json(read v: Value) raises -> String:
    return '"' + v.payload[Str].value + '"'


@always_inline
def int_to_json(read v: Value) raises -> String:
    return String(v.payload[IntVal].value)


@always_inline
def null_to_json(read v: Value) raises -> String:
    return "null"


@always_inline
def serializer_table() -> InlineArray[Serializer, 5]:
    var table = InlineArray[Serializer, 5](fill=null_to_json)
    table[Value.STRING] = string_to_json
    table[Value.INT] = int_to_json
    return table^


comptime SERIALIZERS = serializer_table()


def main() raises:
    var value = Value(Value.STRING, Payload(Str("ok")))
    print(value.to_string())
