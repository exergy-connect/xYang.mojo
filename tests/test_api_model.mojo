from std.testing import assert_equal

from xyang.api import (
    MaxStringLength,
    NoStringConstraints,
    YangBuiltinUInt16,
    YangModeled,
    YangBuiltinString,
    YangLeaf,
    YangRange,
    parse_and_validate_json_against_model,
    validate_yang_subtree,
    yang_module_from_model,
)
from xyang.yang.ast.module import YangModule


@fieldwise_init
struct ApiCart(ImplicitlyDestructible, Movable, YangModeled):
    @staticmethod
    def yang_container_name() -> String:
        return "cart"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        validate_yang_subtree[Self](module)

    var customer_id: YangLeaf[YangBuiltinString, MaxStringLength[128]]
    var currency: YangLeaf[YangBuiltinString, MaxStringLength[3]]
    var quantity: YangLeaf[
        YangBuiltinUInt16, NoStringConstraints, YangRange[0, 65535]
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
        if String(e).find("range") >= 0 or String(e).find("expected uint16") >= 0:
            return
    raise Error("expected generated model validation to reject bad quantity")


def main() raises:
    test_generated_module_from_model()
    test_generated_module_rejects_bad_json()
    test_generated_module_rejects_bad_range()
