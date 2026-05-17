## JSON value type with Variant payload and serialization.

from std.memory import ArcPointer
from std.utils import Variant

comptime Arc = ArcPointer


## --- Variant member types ----------------------------------------------------


@fieldwise_init
struct JsonObject(Movable):
    var keys: List[String]
    var values: List[Arc[JsonValue]]


@fieldwise_init
struct JsonArray(Movable):
    var values: List[Arc[JsonValue]]


@fieldwise_init
struct JsonString(Movable):
    var value: String


@fieldwise_init
struct JsonInt(Movable):
    var value: Int64
    var text: String


@fieldwise_init
struct JsonReal(Movable):
    var text: String


@fieldwise_init
struct JsonBool(Movable):
    var value: Bool


struct JsonNull(Movable):
    def __init__(out self):
        pass

    def __init__(out self, *, deinit take: Self):
        pass


comptime JsonPayload = Variant[
    JsonObject, JsonArray, JsonString, JsonInt,
    JsonReal, JsonBool, JsonNull,
]


## --- JsonValue ---------------------------------------------------------------


struct JsonValue(ImplicitlyDestructible, Movable):
    comptime Kind = UInt8
    comptime OBJECT: Self.Kind = 0
    comptime ARRAY: Self.Kind = 1
    comptime STRING: Self.Kind = 2
    comptime INT: Self.Kind = 3
    comptime REAL: Self.Kind = 4
    comptime BOOL: Self.Kind = 5
    comptime NULL: Self.Kind = 6

    var kind: Self.Kind
    var payload: JsonPayload
    var source_line: Int

    def __init__(out self, kind: Self.Kind, var payload: JsonPayload, source_line: Int = 0):
        self.kind = kind
        self.payload = payload^
        self.source_line = source_line

    def __init__(out self, *, deinit take: Self):
        self.kind = take.kind
        self.payload = take.payload^
        self.source_line = take.source_line

    def to_string(read self) raises -> String:
        if self.kind == Self.OBJECT:
            ref obj = self.payload[JsonObject]
            var s = String("{")
            for i in range(len(obj.keys)):
                if i > 0:
                    s += ","
                s += '"' + json_escape(obj.keys[i]) + '":'
                s += obj.values[i][].to_string()
            s += "}"
            return s^
        if self.kind == Self.ARRAY:
            ref arr = self.payload[JsonArray]
            var s = String("[")
            for i in range(len(arr.values)):
                if i > 0:
                    s += ","
                s += arr.values[i][].to_string()
            s += "]"
            return s^
        # Keep scalar serialization as direct branches. A previous version used
        # a comptime InlineArray of thin function pointers here; with this
        # recursive Variant-backed type, that caused severe compile/runtime
        # latency. See issues/standalone_recursive_fn_table_compile_repro.mojo.
        if self.kind == Self.STRING:
            return '"' + json_escape(self.payload[JsonString].value) + '"'
        if self.kind == Self.INT:
            return self.payload[JsonInt].text
        if self.kind == Self.REAL:
            return self.payload[JsonReal].text
        if self.kind == Self.BOOL:
            if self.payload[JsonBool].value:
                return "true"
            return "false"
        return "null"


## --- Helpers -----------------------------------------------------------------


def json_escape(read s: String) -> String:
    return (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def json_get(read obj: JsonValue, key: String) -> Optional[Arc[JsonValue]]:
    ref o = obj.payload[JsonObject]
    for i in range(len(o.keys)):
        if o.keys[i] == key:
            return Optional[Arc[JsonValue]](o.values[i].copy())
    return Optional[Arc[JsonValue]]()


def json_scalar_text(read value: JsonValue) -> String:
    if value.kind == JsonValue.STRING:
        return value.payload[JsonString].value
    if value.kind == JsonValue.INT:
        return value.payload[JsonInt].text
    if value.kind == JsonValue.REAL:
        return value.payload[JsonReal].text
    if value.kind == JsonValue.BOOL:
        return "true" if value.payload[JsonBool].value else "false"
    return "<non-scalar>"
