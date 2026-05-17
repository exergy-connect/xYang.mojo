from std.testing import assert_equal, assert_true

from xyang.api.reflection import (
    YangBuiltinUInt16,
    YangBuiltinString,
    YangConstraints,
    YangLeaf,
    YangModeled,
    reflection_append_model_fields,
    reflection_instance_to_construct,
)
from xyang.api.model import yang_module_from_model
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule


@fieldwise_init
struct TwoLeafRow(Defaultable, ImplicitlyDestructible, Movable, YangModeled):
    var title: YangLeaf[YangBuiltinString, YangConstraints[]]
    var units: YangLeaf[YangBuiltinUInt16, YangConstraints[]]

    def __init__(out self):
        self.title = YangLeaf[YangBuiltinString, YangConstraints[]]()
        self.units = YangLeaf[YangBuiltinUInt16, YangConstraints[]]()
        self.title.value = String()
        self.units.value = 0

    @staticmethod
    def yang_container_name() -> String:
        return "two_leaf"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        pass

    @staticmethod
    def append_model_fields(mut parent: YangConstruct) raises:
        reflection_append_model_fields[Self](parent)


def test_reflection_instance_construct() raises:
    var row = TwoLeafRow()
    row.title.value = "mug"
    row.units.value = 3
    var ir = reflection_instance_to_construct[TwoLeafRow](row).format(0)
    assert_true(ir.find("title") >= 0)
    assert_true(ir.find("mug") >= 0)
    assert_true(ir.find("units") >= 0)
    assert_true(ir.find("value") >= 0 and ir.find("3") >= 0)


def test_reflection_schema_fields() raises:
    var m = yang_module_from_model[TwoLeafRow](
        "two-leaf-test", "urn:example:two-leaf-test", "t"
    )
    var opt = m.top_container("two_leaf")
    if not opt:
        raise Error("missing top container two_leaf")
    var leaves = 0
    for ch in opt.value()[].children:
        if ch[].keyword == "leaf":
            leaves += 1
    assert_equal(leaves, 2)


def main() raises:
    test_reflection_instance_construct()
    test_reflection_schema_fields()
    print("test_api_reflection: ok")
