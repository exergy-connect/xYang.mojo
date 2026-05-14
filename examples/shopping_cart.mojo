## Shopping cart demo: **YANG-shaped JSON Schema** (`x-yang`) with field-annotated Mojo
## structs for the cart, **compile-time** parse + reflection checks, **runtime**
## `validate_data` (strict), catalog-owned pricing, itemized checkout response,
## and a tiny **REST** server over TCP using Python’s `socket` (Mojo std has no HTTP).
##
##   pixi run package
##   export MODULAR_MOJO_IMPORT_PATH="$PWD/.pixi/envs/default/lib/mojo"
##   pixi run mojo -I build -I "$MODULAR_MOJO_IMPORT_PATH" examples/shopping_cart.mojo
##
##   curl -s http://127.0.0.1:18080/cart
##   curl -s http://127.0.0.1:18080/catalog
##   curl -s -X POST http://127.0.0.1:18080/purchase -d \
##     '{"purchase_request":{"item":[{"sku":"tea","quantity":2},{"sku":"mug","quantity":1},{"sku":"beans","quantity":1}]}}'
##   # Prices come from the server-side catalog. A 10% bulk discount is applied
##   # when the request contains 3+ distinct line items.

from std.memory import ArcPointer
from std.python import Python

from xyang.api import (
    MaxStringLength,
    YangBuiltinInt32,
    YangBuiltinUInt16,
    YangConstraints,
    YangKey,
    YangList,
    YangModeled,
    YangMust,
    YangRange,
    YangBuiltinString,
    YangLeaf,
    YangWhen,
    validate_yang_subtree,
    yang_module_from_model,
)
from xyang.json import parse_json, parse_yang_json_module
from xyang.json.parser import JsonValue, json_get, make_json
from xyang.validator.document import validate_data
from xyang.yang.ast.module import YangModule

comptime Arc = ArcPointer
comptime ArcJson = ArcPointer[JsonValue]


## --- Cart model (reflection-checked against embedded schema) -------------------


@fieldwise_init
struct CartContainer(ImplicitlyDestructible, Movable, YangModeled):
    @staticmethod
    def yang_container_name() -> String:
        return "cart"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        validate_yang_subtree[Self](module)

    var customer_id: YangLeaf[
        YangBuiltinString, YangConstraints[MaxStringLength[128]]
    ]
    var currency: YangLeaf[
        YangBuiltinString, YangConstraints[MaxStringLength[3]]
    ]


@fieldwise_init
struct PurchaseItem(ImplicitlyDestructible, Movable, YangModeled):
    @staticmethod
    def yang_container_name() -> String:
        return "item"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    var sku: YangLeaf[
        YangBuiltinString,
        YangConstraints[
            MaxStringLength[64],
            Must=YangMust["/catalog/item[sku = current()]"],
        ],
    ]
    var quantity: YangLeaf[
        YangBuiltinUInt16,
        YangConstraints[Range=YangRange[0, 65535]],
    ]


@fieldwise_init
struct PurchaseRequestContainer(ImplicitlyDestructible, Movable, YangModeled):
    @staticmethod
    def yang_container_name() -> String:
        return "purchase_request"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    var item: YangList[PurchaseItem, YangKey["sku"]]


@fieldwise_init
struct PurchaseResponseItem(ImplicitlyDestructible, Movable, YangModeled):
    @staticmethod
    def yang_container_name() -> String:
        return "item"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    var sku: YangLeaf[YangBuiltinString, YangConstraints[MaxStringLength[64]]]
    var name: YangLeaf[YangBuiltinString, YangConstraints[MaxStringLength[128]]]
    var quantity: YangLeaf[
        YangBuiltinUInt16,
        YangConstraints[Range=YangRange[0, 65535]],
    ]
    var unit_price_cents: YangLeaf[
        YangBuiltinUInt16,
        YangConstraints[Range=YangRange[0, 65535]],
    ]
    var line_total_cents: YangLeaf[
        YangBuiltinInt32,
        YangConstraints[Range=YangRange[0, 2147483647]],
    ]


@fieldwise_init
struct PurchaseResponseContainer(ImplicitlyDestructible, Movable, YangModeled):
    @staticmethod
    def yang_container_name() -> String:
        return "purchase_response"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    var item: YangList[PurchaseResponseItem, YangKey["sku"]]
    var subtotal_cents: YangLeaf[
        YangBuiltinInt32,
        YangConstraints[Range=YangRange[0, 2147483647]],
    ]
    var discount_percent: YangLeaf[
        YangBuiltinUInt16,
        YangConstraints[
            Range=YangRange[0, 100],
            When=YangWhen["count(../item) >= 3"],
        ],
    ]
    var discount_cents: YangLeaf[
        YangBuiltinInt32,
        YangConstraints[
            Range=YangRange[0, 2147483647],
            When=YangWhen["count(../item) >= 3"],
        ],
    ]
    var total_cents: YangLeaf[
        YangBuiltinInt32,
        YangConstraints[Range=YangRange[0, 2147483647]],
    ]
    var currency: YangLeaf[
        YangBuiltinString, YangConstraints[MaxStringLength[3]]
    ]


## --- Embedded JSON Schema + YANG (catalog, purchase request, itemized response) ---

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
    "catalog": {
      "type": "object",
      "description": "Server-owned products for sale",
      "x-yang": {"type": "container"},
      "properties": {
        "item": {
          "type": "array",
          "description": "Catalog items and authoritative prices",
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
              "name": {
                "type": "string",
                "maxLength": 128,
                "description": "Display name",
                "x-yang": {"type": "leaf"}
              },
              "unit_price_cents": {
                "type": "integer",
                "minimum": 0,
                "maximum": 65535,
                "description": "Authoritative unit price in minor units",
                "x-yang": {"type": "leaf"}
              }
            }
          }
        }
      }
    },
    "purchase_request": {
      "type": "object",
      "description": "Checkout request: clients choose catalog SKUs and quantities only",
      "x-yang": {"type": "container"},
      "properties": {
        "item": {
          "type": "array",
          "description": "Requested line items",
          "x-yang": {"type": "list", "key": "sku"},
          "items": {
            "type": "object",
            "properties": {
              "sku": {
                "type": "string",
                "maxLength": 64,
                "description": "Product sku",
                "x-yang": {
                  "type": "leaf",
                  "must": [
                    {
                      "must": "/catalog/item[sku = current()]",
                      "error-message": "SKU must exist in catalog"
                    }
                  ]
                }
              },
              "quantity": {
                "type": "integer",
                "minimum": 0,
                "maximum": 65535,
                "description": "Units",
                "x-yang": {"type": "leaf"}
              }
            }
          }
        }
      }
    },
    "purchase_response": {
      "type": "object",
      "description": "Server-computed itemized bill",
      "x-yang": {"type": "container"},
      "properties": {
        "item": {
          "type": "array",
          "description": "Priced line items",
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
              "name": {
                "type": "string",
                "maxLength": 128,
                "description": "Display name",
                "x-yang": {"type": "leaf"}
              },
              "quantity": {
                "type": "integer",
                "minimum": 0,
                "maximum": 65535,
                "description": "Units purchased",
                "x-yang": {"type": "leaf"}
              },
              "unit_price_cents": {
                "type": "integer",
                "minimum": 0,
                "maximum": 65535,
                "description": "Catalog unit price used for this bill",
                "x-yang": {"type": "leaf"}
              },
              "line_total_cents": {
                "type": "integer",
                "minimum": 0,
                "maximum": 2147483647,
                "description": "Line total before discounts",
                "x-yang": {"type": "leaf"}
              }
            }
          }
        },
        "subtotal_cents": {
          "type": "integer",
          "minimum": 0,
          "maximum": 2147483647,
          "description": "Subtotal before discounts",
          "x-yang": {"type": "leaf"}
        },
        "discount_percent": {
          "type": "integer",
          "minimum": 0,
          "maximum": 100,
          "description": "Bulk discount percent; present when 3+ distinct line items",
          "x-yang": {
            "type": "leaf",
            "when": {"condition": "count(../item) >= 3"}
          }
        },
        "discount_cents": {
          "type": "integer",
          "minimum": 0,
          "maximum": 2147483647,
          "description": "Discount amount; present when discount_percent is active",
          "x-yang": {
            "type": "leaf",
            "when": {"condition": "count(../item) >= 3"}
          }
        },
        "total_cents": {
          "type": "integer",
          "minimum": 0,
          "maximum": 2147483647,
          "description": "Final total after discounts",
          "x-yang": {"type": "leaf"}
        },
        "currency": {
          "type": "string",
          "maxLength": 3,
          "description": "ISO 4217 alphabetic code",
          "x-yang": {"type": "leaf"}
        }
      }
    }
  }
}"""


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


def _generated_cart_module_ok() -> Bool:
    try:
        var m = yang_module_from_model[CartContainer](
            "shopping-cart-cart",
            "urn:example:shopping-cart",
            "sc",
        )
        _validate_mojo_cart_vs_yang(m)
        var data = parse_json(
            '{"cart":{"customer_id":"guest","currency":"USD"}}',
            "generated-cart.json",
        )
        validate_data(data, m, "generated-cart")
        return True
    except:
        return False


comptime _CART_GENERATED_MODULE_OK: Bool = _generated_cart_module_ok()


def _byte_slice_str(read s: String, start: Int, end: Int) -> String:
    var b = s.as_bytes()
    return String(StringSlice(unsafe_from_utf8=b[start:end]))


## --- Pricing -------------------------------------------------------------------


def _catalog_json() -> String:
    return (
        '{"catalog":{"item":['
        '{"sku":"tea","name":"Jasmine green tea","unit_price_cents":450},'
        '{"sku":"mug","name":"Stoneware mug","unit_price_cents":1200},'
        '{"sku":"beans","name":"House espresso beans","unit_price_cents":1600},'
        '{"sku":"filter","name":"Paper filter pack","unit_price_cents":650}'
        "]}}"
    )


def _catalog_item(read sku: String) raises -> Tuple[String, Int]:
    if sku == "tea":
        return ("Jasmine green tea", 450)
    if sku == "mug":
        return ("Stoneware mug", 1200)
    if sku == "beans":
        return ("House espresso beans", 1600)
    if sku == "filter":
        return ("Paper filter pack", 650)
    raise Error("unknown catalog sku `" + sku + "`")


def _line_sku(read line: JsonValue) raises -> String:
    var sku = json_get(line, "sku")
    if not sku or sku.value()[].kind != JsonValue.STRING:
        raise Error("purchase_request/item: expected sku")
    return sku.value()[].text


def _line_quantity(read line: JsonValue) raises -> Int:
    var q = json_get(line, "quantity")
    if not q or q.value()[].kind != JsonValue.INT:
        raise Error("purchase_request/item: expected quantity")
    return Int(q.value()[].int_value)


def _line_total_cents(read line: JsonValue) raises -> Int:
    var sku = _line_sku(line)
    var q = _line_quantity(line)
    return q * _catalog_item(sku)[1]


def purchase_line_count(read purchase: JsonValue) raises -> Int:
    var items = json_get(purchase, "item")
    if not items or items.value()[].kind != JsonValue.ARRAY:
        return 0
    return len(items.value()[].array_values)


def purchase_discount_percent(read purchase: JsonValue) raises -> Int:
    if purchase_line_count(purchase) >= 3:
        return 10
    return 0


def purchase_subtotal_cents(read purchase: JsonValue) raises -> Int:
    var items = json_get(purchase, "item")
    if not items or items.value()[].kind != JsonValue.ARRAY:
        return 0
    var sum: Int = 0
    ref arr = items.value()[].array_values
    for i in range(len(arr)):
        sum += _line_total_cents(arr[i][])
    return sum


def purchase_total_cents(read purchase: JsonValue) raises -> Int:
    var sub = purchase_subtotal_cents(purchase)
    var pct = purchase_discount_percent(purchase)
    return sub - (sub * pct) // 100


def _cart_currency(read doc: JsonValue) raises -> String:
    var c = json_get(doc, "cart")
    if not c:
        return "USD"
    var cur = json_get(c.value()[], "currency")
    if not cur or cur.value()[].kind != JsonValue.STRING:
        return "USD"
    return cur.value()[].text


def _json_purchase_response(
    read purchase: JsonValue, read currency: String
) raises -> String:
    var items = json_get(purchase, "item")
    if not items or items.value()[].kind != JsonValue.ARRAY:
        raise Error("purchase_request: expected item list")
    var subtotal = purchase_subtotal_cents(purchase)
    var pct = purchase_discount_percent(purchase)
    var discount = (subtotal * pct) // 100
    var total = subtotal - discount
    var s = String('{"purchase_response":{"item":[')
    ref arr = items.value()[].array_values
    for i in range(len(arr)):
        if i > 0:
            s += ","
        ref line = arr[i][]
        var sku = _line_sku(line)
        var q = _line_quantity(line)
        var catalog_item = _catalog_item(sku)
        var unit = catalog_item[1]
        var line_total = q * unit
        s += (
            '{"sku":"'
            + _json_escape(sku)
            + '","name":"'
            + _json_escape(catalog_item[0])
            + '","quantity":'
            + String(q)
            + ',"unit_price_cents":'
            + String(unit)
            + ',"line_total_cents":'
            + String(line_total)
            + "}"
        )
    s += '],"subtotal_cents":' + String(subtotal)
    if pct > 0:
        s += (
            ',"discount_percent":'
            + String(pct)
            + ',"discount_cents":'
            + String(discount)
        )
    s += (
        ',"total_cents":'
        + String(total)
        + ',"currency":"'
        + _json_escape(currency)
        + '"}}'
    )
    return s^


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
        + "  (GET /cart, GET /catalog, POST /cart, POST /purchase)"
    )
    var g_cart = parse_json(
        '{"cart":{"customer_id":"guest","currency":"USD"}}', "cart.json"
    )
    var catalog_doc = parse_json(_catalog_json(), "catalog.json")
    validate_data(catalog_doc, module, "catalog")
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
        elif method == "GET" and path == "/catalog":
            response = _http_ok_json(_catalog_json())
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
                var body_json = _json_purchase_response(
                    purchase, _cart_currency(g_cart)
                )
                validate_data(
                    parse_json(body_json, "purchase-response.json"),
                    module,
                    "purchase-response",
                )
                response = _http_ok_json(body_json)
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
    comptime assert (
        _CART_GENERATED_MODULE_OK
    ), "examples/shopping_cart.mojo: CartContainer generated YangModule failed"
    var module = parse_yang_json_module(
        String(APP_SCHEMA_JSON), "shopping-cart-app.json"
    )
    _validate_mojo_cart_vs_yang(module)
    var port: Int = 18080
    serve_rest(module, port)
