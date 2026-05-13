## Shopping cart demo: **YANG-shaped JSON Schema** (`x-yang`) with field-annotated Mojo
## structs for the cart, **compile-time** parse + reflection checks, **runtime**
## `validate_data` (strict) vs **prune mode** (drop unknown / `when`-inactive leaves),
## and a tiny **REST** server over TCP using Python’s `socket` (Mojo std has no HTTP).
##
##   pixi run package
##   export MODULAR_MOJO_IMPORT_PATH="$PWD/.pixi/envs/default/lib/mojo"
##   pixi run mojo -I build -I "$MODULAR_MOJO_IMPORT_PATH" examples/shopping_cart.mojo
##
##   curl -s http://127.0.0.1:18080/cart
##   curl -s -X POST http://127.0.0.1:18080/purchase -d \
##     '{"purchase_request":{"item":[{"sku":"a","quantity":1,"unit_price_cents":100},{"sku":"b","quantity":1,"unit_price_cents":200},{"sku":"c","quantity":1,"unit_price_cents":50}],"discount_percent":10}}'
##   # Schema `when`: `count(../item) >= 3` — with 3+ line items the discount leaf is kept;
##   # prune mode strips `discount_percent` (and any non-schema keys) when the condition is false.

from std.collections import Dict, List
from std.memory import ArcPointer
from std.python import Python
from std.reflection import reflect

from xyang.json import parse_json, parse_yang_json_module
from xyang.json.parser import JsonValue, json_get, make_json
from xyang.validator.document import validate_data
import xyang.validator.schema_walk as schema_walk
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule
from xyang.yang.spec import `container`, `leaf`, `leaf-list`, `list`, `when`

comptime Arc = ArcPointer
comptime ArcJson = ArcPointer[JsonValue]


## --- Optional string length caps (same pattern as `comptime_yang_validation.mojo`) ---


trait StringLengthCap:
    @staticmethod
    def model_max_string_length() -> Int:
        ...


@fieldwise_init
struct NoStringConstraints(
    Copyable,
    Defaultable,
    ImplicitlyDestructible,
    Movable,
    StringLengthCap,
    Writable,
):
    @staticmethod
    def model_max_string_length() -> Int:
        return -1


@fieldwise_init
struct MaxStringLength[
    n: Int,
](
    Copyable,
    Defaultable,
    ImplicitlyDestructible,
    Movable,
    StringLengthCap,
    Writable,
):
    @staticmethod
    def model_max_string_length() -> Int:
        return Self.n


trait YangBuiltinDescriptor:
    comptime Value: Writable & Copyable & Movable & ImplicitlyDestructible & Defaultable

    @staticmethod
    def yang_type_keyword() -> String:
        ...


@fieldwise_init
struct YangBuiltinString(
    Copyable,
    Defaultable,
    ImplicitlyDestructible,
    Movable,
    Writable,
    YangBuiltinDescriptor,
):
    comptime Value = String

    @staticmethod
    def yang_type_keyword() -> String:
        return "string"


trait LeafModelSpec:
    @staticmethod
    def yang_type_str() -> String:
        ...

    @staticmethod
    def model_max_string_length() -> Int:
        ...


trait Yang:
    @staticmethod
    def yang_container_name() -> String:
        ...

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        _validate_yang_subtree[Self](module)


@fieldwise_init
struct YangLeaf[
    Builtin: YangBuiltinDescriptor,
    Constraints: StringLengthCap,
](ImplicitlyDestructible, LeafModelSpec, Movable):
    var value: Self.Builtin.Value

    @staticmethod
    def yang_type_str() -> String:
        return Self.Builtin.yang_type_keyword()

    @staticmethod
    def model_max_string_length() -> Int:
        return Self.Constraints.model_max_string_length()


@fieldwise_init
struct YangContainer[
    Child: Movable & ImplicitlyDestructible & Yang,
](ImplicitlyDestructible, Movable):
    var body: Self.Child

    @staticmethod
    def yang_name() -> String:
        return Self.Child.yang_container_name()


## --- Cart model (reflection-checked against embedded schema) -------------------


@fieldwise_init
struct CartContainer(ImplicitlyDestructible, Movable, Yang):
    @staticmethod
    def yang_container_name() -> String:
        return "cart"

    var customer_id: YangLeaf[YangBuiltinString, MaxStringLength[128]]
    var currency: YangLeaf[YangBuiltinString, MaxStringLength[3]]


## --- Embedded JSON Schema + YANG (purchase_request: list `item`, conditional discount) ---

comptime APP_SCHEMA_JSON = """{
  "x-yang": {
    "module": "shopping-cart-app",
    "yang-version": "1.1",
    "namespace": "urn:example:shopping-cart",
    "prefix": "sc"
  },
  "description": "Shopping cart and purchase API model",
  "type": "object",
  "properties": {
    "cart": {
      "type": "object",
      "description": "Active cart",
      "x-yang": {"type": "container"},
      "properties": {
        "customer_id": {
          "type": "string",
          "maxLength": 128,
          "description": "Customer id",
          "x-yang": {"type": "leaf"}
        },
        "currency": {
          "type": "string",
          "maxLength": 3,
          "description": "ISO 4217 alphabetic code",
          "x-yang": {"type": "leaf"}
        }
      }
    },
    "purchase_request": {
      "type": "object",
      "description": "Checkout payload",
      "x-yang": {"type": "container"},
      "properties": {
        "item": {
          "type": "array",
          "description": "Line items",
          "x-yang": {"type": "list", "key": "sku"},
          "items": {
            "type": "object",
            "properties": {
              "sku": {
                "type": "string",
                "maxLength": 64,
                "description": "Product sku",
                "x-yang": {"type": "leaf"}
              },
              "quantity": {
                "type": "integer",
                "minimum": 0,
                "maximum": 65535,
                "description": "Units",
                "x-yang": {"type": "leaf"}
              },
              "unit_price_cents": {
                "type": "integer",
                "minimum": 0,
                "maximum": 65535,
                "description": "Pre-tax unit price in minor units",
                "x-yang": {"type": "leaf"}
              }
            }
          }
        },
        "discount_percent": {
          "type": "integer",
          "minimum": 0,
          "maximum": 100,
          "description": "Bulk discount; only when 3+ distinct line items",
          "x-yang": {
            "type": "leaf",
            "when": {"condition": "count(../item) >= 3"}
          }
        }
      }
    }
  }
}"""


def _schema_string_max_length(
    read module: YangModule, read parent: String, read leaf: String
) raises -> Int:
    var c = module.top_container(parent)
    if not c:
        raise Error("reflection: no top container `" + parent + "`")
    var lf = module.find_effective_leaf(c.value()[], leaf)
    if not lf:
        raise Error(
            "reflection: no leaf `"
            + leaf
            + "` under container `"
            + parent
            + "`"
        )
    var segs = module.leaf_length_segments(lf.value()[])
    if len(segs) == 0:
        return -1
    var hi: Int64 = -1
    for i in range(len(segs)):
        if segs[i].hi > hi:
            hi = segs[i].hi
    comptime _BIG: Int64 = 9223372036854775807
    if hi >= _BIG:
        return -1
    return Int(hi)


def _effective_leaf_names_under(
    read module: YangModule, read parent: YangConstruct
) raises -> List[String]:
    var out = List[String]()
    var seen = Dict[String, Bool]()
    for child in parent.children:
        if child[].spec == `leaf` and child[].has_argument():
            var name = child[].argument_text()
            if name not in seen:
                seen[name] = True
                out.append(name)
    for child in parent.children:
        if child[].keyword != "uses" or not child[].has_argument():
            continue
        var grouping = module.find_grouping(child[].argument_text())
        if not grouping:
            continue
        var inner = _effective_leaf_names_under(module, grouping.value()[])
        for i in range(len(inner)):
            var n = inner[i]
            if n not in seen:
                seen[n] = True
                out.append(n)
    return out^


def _validate_yang_subtree[T: Yang](read module: YangModule) raises:
    comptime info = reflect[T]()
    comptime _nfc = info.field_count()
    var want = T.yang_container_name()
    var c = module.top_container(want)
    if not c:
        raise Error(
            "reflection: Yang subtree missing top container `" + want + "`"
        )
    var schema_leaves = _effective_leaf_names_under(module, c.value()[])
    if len(schema_leaves) != _nfc:
        raise Error(
            "reflection: container `"
            + want
            + "` has "
            + String(len(schema_leaves))
            + " effective leaf(es) vs "
            + String(_nfc)
            + " model field(s)"
        )
    for i in range(len(schema_leaves)):
        var ln = schema_leaves[i]
        var in_model = False
        for j in range(_nfc):
            if info.field_names()[j] == ln:
                in_model = True
                break
        if not in_model:
            raise Error(
                "reflection: schema leaf `"
                + want
                + "/"
                + ln
                + "` has no matching Mojo field"
            )
    comptime for j in range(_nfc):
        var fname = String(info.field_names()[j])
        var in_schema = False
        for i in range(len(schema_leaves)):
            if schema_leaves[i] == fname:
                in_schema = True
                break
        if not in_schema:
            raise Error(
                "reflection: Mojo field `"
                + fname
                + "` missing under YANG `"
                + want
                + "`"
            )
        _validate_leaf_field_type_vs_module[info.field_types()[j]](
            module, want, fname
        )


def _validate_leaf_field_type_vs_module[
    FT: AnyType,
](read module: YangModule, read parent: String, read leaf: String) raises:
    _validate_leaf_model_vs_module[FT](module, parent, leaf)


def _validate_leaf_model_vs_module[
    FT: AnyType
](read module: YangModule, read parent: String, read leaf: String) raises:
    var reflected_ty = reflect[FT]().name()
    var string_marker = reflect[YangBuiltinString]().name()
    var yt = "string"
    if string_marker in reflected_ty:
        pass
    else:
        raise Error(
            "reflection: field `"
            + parent
            + "/"
            + leaf
            + "` is not a recognized YangLeaf builtin: "
            + reflected_ty
        )
    var c = module.top_container(parent)
    if not c:
        raise Error("reflection: missing container `" + parent + "`")
    var lf = module.find_effective_leaf(c.value()[], leaf)
    if not lf:
        raise Error("reflection: missing leaf `" + parent + "/" + leaf + "`")
    var schema_ty = module.leaf_type(lf.value()[])
    if schema_ty != yt:
        raise Error(
            "reflection: leaf `"
            + parent
            + "/"
            + leaf
            + "` model type `"
            + yt
            + "` != schema `"
            + schema_ty
            + "`"
        )
    var schema_max = _schema_string_max_length(module, parent, leaf)
    var want_constraint = "MaxStringLength[" + String(schema_max) + "]"
    if schema_max == -1:
        want_constraint = reflect[NoStringConstraints]().name()
    if want_constraint not in reflected_ty:
        raise Error(
            "reflection: leaf `"
            + parent
            + "/"
            + leaf
            + "` model constraints `"
            + reflected_ty
            + "` do not match schema length upper bound "
            + String(schema_max)
        )


def _validate_mojo_cart_vs_yang(read module: YangModule) raises:
    CartContainer.comptime_validate(module)


def _embedded_schema_parse_ok() -> Bool:
    try:
        _ = parse_yang_json_module(
            String(APP_SCHEMA_JSON), "shopping-cart-app.json"
        )
        return True
    except:
        return False


comptime _SCHEMA_PARSE_OK: Bool = _embedded_schema_parse_ok()


def _reflection_cart_ok() -> Bool:
    try:
        var m = parse_yang_json_module(
            String(APP_SCHEMA_JSON), "shopping-cart-app.json"
        )
        _validate_mojo_cart_vs_yang(m)
        return True
    except:
        return False


comptime _CART_REFLECTION_OK: Bool = _reflection_cart_ok()


## --- Prune: keep only schema-known children; drop `discount_percent` when `when` fails ---
## Note: `validate_data` does not evaluate YANG `when`; a client can still send
## `discount_percent` with fewer than three line items and pass strict validation.
## Prune mode applies the schema’s `when` for this leaf and removes it when the
## `count(../item) >= 3` condition is not met.


def _when_text_on_leaf(
    read module: YangModule, read leaf: YangConstruct
) -> String:
    var w = module.find_child(leaf, `when`)
    if not w:
        return String()
    ref wn = w.value()[]
    if not wn.has_argument():
        return String()
    return wn.argument_text()


def _purchase_discount_when_applies(
    read when_expr: String, read purchase_obj: JsonValue
) -> Bool:
    ## Interpret the schema’s `count(../item) >= 3` style condition for JSON data.
    if when_expr.byte_length() == 0:
        return True
    var t = when_expr
    if t.find("count(../item) >= 3") >= 0:
        var it = json_get(purchase_obj, "item")
        if not it or it.value()[].kind != JsonValue.ARRAY:
            return False
        return len(it.value()[].array_values.copy()) >= 3
    return True


def _byte_slice_str(read s: String, start: Int, end: Int) -> String:
    var b = s.as_bytes()
    return String(StringSlice(unsafe_from_utf8=b[start:end]))


def _prune_object_to_schema(
    read data: JsonValue,
    read schema: YangConstruct,
    read module: YangModule,
    read parent_for_when: JsonValue,
) raises -> JsonValue:
    if data.kind != JsonValue.OBJECT:
        return make_json(JsonValue.OBJECT)
    var out = make_json(JsonValue.OBJECT)
    for i in range(len(data.object_keys)):
        var key = data.object_keys[i]
        ref slot = data.object_values[i][]
        var ch_opt = schema_walk.find_schema_child_for_json_key(
            module,
            schema,
            key,
            data,
        )
        if not ch_opt:
            continue
        ref ch = ch_opt.value()[]
        var kw = ch.spec
        if kw == `leaf`:
            if not _leaf_allowed_by_when(module, ch, parent_for_when):
                continue
            out.object_keys.append(key)
            out.object_values.append(data.object_values[i].copy())
            continue
        if kw == `leaf-list`:
            out.object_keys.append(key)
            out.object_values.append(data.object_values[i].copy())
            continue
        if kw == `container`:
            var inner = _prune_object_to_schema(slot, ch, module, slot)
            out.object_keys.append(key)
            out.object_values.append(ArcJson(inner^))
            continue
        if kw == `list`:
            var arr = _prune_list_to_schema(slot, ch, module)
            out.object_keys.append(key)
            out.object_values.append(ArcJson(arr^))
            continue
    return out^


def _leaf_allowed_by_when(
    read module: YangModule,
    read leaf_schema: YangConstruct,
    read ctx: JsonValue,
) -> Bool:
    var wx = _when_text_on_leaf(module, leaf_schema)
    if wx.byte_length() == 0:
        return True
    return _purchase_discount_when_applies(wx, ctx)


def _prune_list_to_schema(
    read data: JsonValue,
    read list_schema: YangConstruct,
    read module: YangModule,
) raises -> JsonValue:
    if data.kind != JsonValue.ARRAY:
        return make_json(JsonValue.ARRAY)
    var out = make_json(JsonValue.ARRAY)
    for i in range(len(data.array_values)):
        ref el = data.array_values[i][]
        var pr = _prune_object_to_schema(el, list_schema, module, el)
        out.array_values.append(ArcJson(pr^))
    return out^


def prune_instance_to_model(
    read root: JsonValue, read module: YangModule
) raises -> JsonValue:
    if root.kind != JsonValue.OBJECT:
        return make_json(JsonValue.OBJECT)
    var out = make_json(JsonValue.OBJECT)
    for i in range(len(root.object_keys)):
        var key = root.object_keys[i]
        ref slot = root.object_values[i][]
        var tc = module.top_container(key)
        if not tc:
            continue
        var pruned = _prune_object_to_schema(slot, tc.value()[], module, slot)
        out.object_keys.append(key)
        out.object_values.append(ArcJson(pruned^))
    return out^


## --- Pricing -------------------------------------------------------------------


def _line_total_cents(read line: JsonValue) raises -> Int:
    var q = json_get(line, "quantity")
    var p = json_get(line, "unit_price_cents")
    if not q or q.value()[].kind != JsonValue.INT:
        return 0
    if not p or p.value()[].kind != JsonValue.INT:
        return 0
    return Int(q.value()[].int_value * p.value()[].int_value)


def purchase_subtotal_cents(read purchase: JsonValue) raises -> Int:
    var items = json_get(purchase, "item")
    if not items or items.value()[].kind != JsonValue.ARRAY:
        return 0
    var sum: Int = 0
    var arr = items.value()[].array_values.copy()
    for i in range(len(arr)):
        sum += _line_total_cents(arr[i][])
    return sum


def purchase_total_cents(read purchase: JsonValue) raises -> Int:
    var sub = purchase_subtotal_cents(purchase)
    var d = json_get(purchase, "discount_percent")
    if not d or d.value()[].kind != JsonValue.INT:
        return sub
    var pct = Int(d.value()[].int_value)
    if pct <= 0:
        return sub
    if pct > 100:
        pct = 100
    return sub - (sub * pct) // 100


## --- HTTP (Python `socket`) ----------------------------------------------------


def _http_ok_json(body: String) -> String:
    var bl = body.byte_length()
    return (
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection:"
        " close\r\nContent-Length: "
        + String(bl)
        + "\r\n\r\n"
        + body
    )


def _http_err(status: Int, message: String) -> String:
    var body = (
        '{"error":"'
        + _json_escape(message)
        + '","status":'
        + String(status)
        + "}"
    )
    var bl = body.byte_length()
    return (
        "HTTP/1.1 "
        + String(status)
        + " Error\r\nContent-Type: application/json\r\nConnection:"
        " close\r\nContent-Length: "
        + String(bl)
        + "\r\n\r\n"
        + body
    )


def _json_escape(read s: String) -> String:
    return s.replace('"', '\\"')


@always_inline
def _ascii_byte[s: StaticString]() -> Byte:
    comptime assert s.byte_length() == 1, "expected one character string"
    comptime byte = s.as_bytes()[0]
    return byte


def _http_first_line(read header: String) -> String:
    var b = header.as_bytes()
    var n = len(b)
    var nl = _ascii_byte["\n"]()
    var cr = _ascii_byte["\r"]()
    var i = 0
    while i < n and b[i] != nl:
        i += 1
    var line = _byte_slice_str(header, 0, i)
    if line.byte_length() > 0 and line.as_bytes()[line.byte_length() - 1] == cr:
        line = _byte_slice_str(line, 0, line.byte_length() - 1)
    return line^


def _parse_request_path(read header: String) raises -> Tuple[String, String]:
    var line = _http_first_line(header)
    var parts = line.split(" ")
    if len(parts) < 2:
        return ("", "")
    return (String(parts[0]), String(parts[1]))


def _header_value(read header: String, read name: String) raises -> String:
    var needle = name + ":"
    for line_raw in header.split("\r\n"):
        var line = String(line_raw)
        if line.byte_length() >= needle.byte_length():
            var pref = _byte_slice_str(line, 0, needle.byte_length())
            if pref == needle:
                var rest = _byte_slice_str(
                    line, needle.byte_length(), line.byte_length()
                )
                var rb = rest.as_bytes()
                var j = 0
                comptime sp = _ascii_byte[" "]()
                comptime tab = _ascii_byte["\t"]()
                while j < len(rb) and (rb[j] == sp or rb[j] == tab):
                    j += 1
                return _byte_slice_str(rest, j, rest.byte_length())
    return String()


def _split_header_body(read text: String) raises -> Tuple[String, String]:
    var sep = "\r\n\r\n"
    var idx = text.find(sep)
    if idx < 0:
        return (
            _byte_slice_str(text, 0, text.byte_length()),
            String(),
        )
    return (
        _byte_slice_str(text, 0, idx),
        _byte_slice_str(text, idx + sep.byte_length(), text.byte_length()),
    )


def serve_rest(read module: YangModule, port: Int) raises:
    var sock_mod = Python.import_module("socket")
    var s = sock_mod.socket(sock_mod.AF_INET, sock_mod.SOCK_STREAM)
    s.setsockopt(sock_mod.SOL_SOCKET, sock_mod.SO_REUSEADDR, 1)
    var addr = Python().evaluate("('127.0.0.1', " + String(port) + ")")
    s.bind(addr)
    s.listen(8)
    print(
        "REST shopping cart on http://127.0.0.1:"
        + String(port)
        + "  (GET /cart, POST /cart, POST /purchase strict|prune)"
    )
    var g_cart = parse_json(
        '{"cart":{"customer_id":"guest","currency":"USD"}}', "cart.json"
    )
    while True:
        var pair = s.accept()
        var conn = pair[0]
        var buf = conn.recv(65536)
        var builtins = Python.import_module("builtins")
        var req_text = builtins.str(buf, encoding="utf-8")
        var text = String(req_text)
        var hb = _split_header_body(text)
        var hdr = hb[0]
        var body = hb[1]
        var cl = _header_value(hdr, "Content-Length")
        var want_body: Int = 0
        if cl.byte_length() > 0:
            want_body = atol(cl)
        while body.byte_length() < want_body and want_body > 0:
            var more = conn.recv(65536)
            var more_text = String(builtins.str(more, encoding="utf-8"))
            if more_text.byte_length() == 0:
                break
            body += more_text
        var mp = _parse_request_path(hdr)
        var method = mp[0]
        var path = mp[1]
        var qm = path.find("?")
        if qm >= 0:
            path = _byte_slice_str(path, 0, qm)
        var response: String
        if method == "GET" and path == "/cart":
            response = _http_ok_json(_json_cart_view(g_cart))
        elif method == "POST" and path == "/cart":
            try:
                var doc = parse_json(body, "body.json")
                var merged = _merge_cart(g_cart, doc)
                validate_data(merged, module, "strict-cart")
                g_cart = merged^
                response = _http_ok_json(_json_cart_view(g_cart))
            except e:
                response = _http_err(400, String(e))
        elif method == "POST" and path == "/purchase":
            try:
                var doc = parse_json(body, "body.json")
                validate_data(doc, module, "strict-purchase")
                var purchase = _purchase_from_doc(doc)
                var total_cents_strict = purchase_total_cents(purchase)
                var pruned_root = prune_instance_to_model(doc, module)
                var pr_p = _purchase_from_doc(pruned_root)
                var total_cents_pruned = purchase_total_cents(pr_p)
                response = _http_ok_json(
                    '{"totals":{"strict_validation_cents":'
                    + String(total_cents_strict)
                    + ',"pruned_model_cents":'
                    + String(total_cents_pruned)
                    + '},"purchase_strict":'
                    + _json_purchase_summary(purchase)
                    + ',"purchase_pruned":'
                    + _json_purchase_summary(pr_p)
                    + "}"
                )
            except e:
                response = _http_err(400, String(e))
        elif method == "GET" and path == "/health":
            response = _http_ok_json('{"ok":true}')
        else:
            response = _http_err(404, "not found")
        var py_resp = builtins.str(response)
        conn.sendall(py_resp.encode("utf-8"))
        conn.close()


def _purchase_from_doc(read doc: JsonValue) raises -> JsonValue:
    var pr = json_get(doc, "purchase_request")
    if not pr:
        raise Error("POST /purchase: expected top-level purchase_request")
    return _json_clone(pr.value()[])


def _merge_cart(
    read base: JsonValue, read patch: JsonValue
) raises -> JsonValue:
    ## Shallow merge: patch.cart overrides keys in base.cart.
    var pc = json_get(patch, "cart")
    if not pc or pc.value()[].kind != JsonValue.OBJECT:
        return _json_clone(base)
    var out = _json_clone(base)
    var oc = json_get(out, "cart")
    if not oc or oc.value()[].kind != JsonValue.OBJECT:
        out.object_keys.append("cart")
        out.object_values.append(ArcJson(_json_clone(pc.value()[])))
        return out^
    var inner = make_json(JsonValue.OBJECT)
    ref bobj = oc.value()[]
    for i in range(len(bobj.object_keys)):
        inner.object_keys.append(bobj.object_keys[i])
        inner.object_values.append(bobj.object_values[i].copy())
    ref pobj = pc.value()[]
    for i in range(len(pobj.object_keys)):
        var k = pobj.object_keys[i]
        var replaced = False
        for j in range(len(inner.object_keys)):
            if inner.object_keys[j] == k:
                inner.object_values[j] = pobj.object_values[i].copy()
                replaced = True
                break
        if not replaced:
            inner.object_keys.append(k)
            inner.object_values.append(pobj.object_values[i].copy())
    for i in range(len(out.object_keys)):
        if out.object_keys[i] == "cart":
            out.object_values[i] = ArcJson(inner^)
            break
    return out^


def _json_cart_view(read doc: JsonValue) raises -> String:
    var c = json_get(doc, "cart")
    if not c:
        return "{}"
    return _json_value_to_string(c.value()[])


def _json_purchase_summary(read p: JsonValue) raises -> String:
    var disc = "false"
    if json_get(p, "discount_percent") != None:
        disc = "true"
    return (
        '{"subtotal_cents":'
        + String(purchase_subtotal_cents(p))
        + ',"total_cents":'
        + String(purchase_total_cents(p))
        + ',"discount_percent_present":'
        + disc
        + "}"
    )


def _json_value_to_string(read v: JsonValue) raises -> String:
    if v.kind == JsonValue.STRING:
        return '"' + _json_escape(v.text) + '"'
    if v.kind == JsonValue.INT:
        return String(v.int_value)
    if v.kind == JsonValue.REAL:
        return v.text
    if v.kind == JsonValue.BOOL:
        if v.bool_value:
            return "true"
        return "false"
    if v.kind == JsonValue.NULL:
        return "null"
    if v.kind == JsonValue.ARRAY:
        var s = String("[")
        for i in range(len(v.array_values)):
            if i > 0:
                s += ","
            s += _json_value_to_string(v.array_values[i][])
        s += "]"
        return s^
    if v.kind == JsonValue.OBJECT:
        var s = String("{")
        for i in range(len(v.object_keys)):
            if i > 0:
                s += ","
            s += '"' + _json_escape(v.object_keys[i]) + '":'
            s += _json_value_to_string(v.object_values[i][])
        s += "}"
        return s^
    return "null"


def _json_clone(read v: JsonValue) raises -> JsonValue:
    return parse_json(_json_value_to_string(v), "clone.json")


## --- main ----------------------------------------------------------------------


def main() raises:
    comptime assert (
        _SCHEMA_PARSE_OK
    ), "examples/shopping_cart.mojo: embedded APP_SCHEMA_JSON failed parse"
    comptime assert (
        _CART_REFLECTION_OK
    ), "examples/shopping_cart.mojo: CartContainer fields do not match schema"
    var module = parse_yang_json_module(
        String(APP_SCHEMA_JSON), "shopping-cart-app.json"
    )
    _validate_mojo_cart_vs_yang(module)
    var port: Int = 18080
    serve_rest(module, port)
