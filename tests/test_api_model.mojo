from std.testing import assert_equal

from xyang.api import (
    MaxStringLength,
    YangBuiltinBool,
    YangBuiltinUInt16,
    YangConstraints,
    YangKey,
    YangLeafList,
    YangList,
    YangModeled,
    YangMust,
    YangBuiltinString,
    YangLeaf,
    YangRange,
    YangWhen,
    parse_and_validate_json_against_model,
    validate_yang_subtree,
    yang_module_from_model,
)
from xyang.yang.ast.lexer import AstLexer
from xyang.yang.ast.module import YangModule
from xyang.yang.ast.parser import parse_module


@fieldwise_init
struct ApiCart(ImplicitlyDestructible, Movable, YangModeled):
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
    var quantity: YangLeaf[
        YangBuiltinUInt16,
        YangConstraints[Range=YangRange[0, 65535]],
    ]


@fieldwise_init
struct ApiServer(ImplicitlyDestructible, Movable, YangModeled):
    @staticmethod
    def yang_container_name() -> String:
        return "server"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    var name: YangLeaf[
        YangBuiltinString,
        YangConstraints[
            MaxStringLength[64],
            Must=YangMust["string-length(.) > 0"],
        ],
    ]
    var enabled: YangLeaf[
        YangBuiltinBool,
        YangConstraints[When=YangWhen["../name = 'primary'"]],
    ]


@fieldwise_init
struct ApiConfig(ImplicitlyDestructible, Movable, YangModeled):
    @staticmethod
    def yang_container_name() -> String:
        return "config"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    var server: YangList[ApiServer, YangKey["name"]]
    var tag: YangLeafList[
        YangBuiltinString, YangConstraints[MaxStringLength[16]]
    ]


def _generated_model_ok() -> Bool:
    try:
        var module = yang_module_from_model[ApiCart](
            "api-cart", "urn:test:api-cart", "ac"
        )
        ApiCart.comptime_validate(module)
        _ = parse_and_validate_json_against_model[ApiCart](
            '{"cart":{"customer_id":"guest","currency":"USD"}}',
            "api-cart",
            "urn:test:api-cart",
            "ac",
            "api-cart.json",
        )
        return True
    except:
        return False


comptime _MODEL_OK = _generated_model_ok()


comptime API_CONFIG_YANG = """
module api-config {
  yang-version 1.1;
  namespace "urn:test:api-config";
  prefix ac;
  container config {
    list server {
      key "name";
      leaf name {
        type string {
          length "0..64";
        }
        must "string-length(.) > 0";
      }
      leaf enabled {
        type boolean;
        when "../name = 'primary'";
      }
    }
    leaf-list tag {
      type string {
        length "0..16";
      }
    }
  }
}
"""


def _model_constructs_match_parsed_yang_ast() -> Bool:
    try:
        var lexer = AstLexer(String(API_CONFIG_YANG).as_bytes())
        var parsed_tree = parse_module(lexer)
        var generated_module = yang_module_from_model[ApiConfig](
            "api-config", "urn:test:api-config", "ac"
        )
        var generated_tree = generated_module.root_construct()
        return generated_tree[].format(0) == parsed_tree.format(0)
    except:
        return False


comptime _API_CONFIG_AST_PARITY_OK = _model_constructs_match_parsed_yang_ast()


def test_generated_module_from_model() raises:
    comptime assert _MODEL_OK, "generated model failed at compile time"
    var module = yang_module_from_model[ApiCart](
        "api-cart", "urn:test:api-cart", "ac"
    )
    assert_equal(module.get_name(), "api-cart")
    assert_equal(module.get_namespace(), "urn:test:api-cart")
    assert_equal(module.get_prefix(), "ac")
    ApiCart.comptime_validate(module)


def test_generated_module_rejects_bad_json() raises:
    try:
        _ = parse_and_validate_json_against_model[ApiCart](
            '{"cart":{"customer_id":"guest","currency":"USDX","quantity":1}}',
            "api-cart",
            "urn:test:api-cart",
            "ac",
            "bad-cart.json",
        )
    except e:
        if String(e).find("length") >= 0:
            return
    raise Error("expected generated model validation to reject long currency")


def test_generated_module_rejects_bad_range() raises:
    try:
        _ = parse_and_validate_json_against_model[ApiCart](
            '{"cart":{"customer_id":"guest","currency":"USD","quantity":65536}}',
            "api-cart",
            "urn:test:api-cart",
            "ac",
            "bad-range.json",
        )
    except e:
        if (
            String(e).find("range") >= 0
            or String(e).find("expected uint16") >= 0
        ):
            return
    raise Error("expected generated model validation to reject bad quantity")


def test_model_constructs_match_parsed_yang_ast() raises:
    comptime assert _API_CONFIG_AST_PARITY_OK, (
        "generated ApiConfig AST did not match parsed YANG AST at compile time"
    )
    var yang_text = String(API_CONFIG_YANG)
    var lexer = AstLexer(yang_text.as_bytes())
    var parsed_tree = parse_module(lexer)
    var generated_module = yang_module_from_model[ApiConfig](
        "api-config", "urn:test:api-config", "ac"
    )
    var generated_tree = generated_module.root_construct()
    assert_equal(generated_tree[].format(0), parsed_tree.format(0))


def main() raises:
    test_generated_module_from_model()
    test_generated_module_rejects_bad_json()
    test_generated_module_rejects_bad_range()
    test_model_constructs_match_parsed_yang_ast()
