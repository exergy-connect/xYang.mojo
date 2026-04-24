from std.testing import assert_equal, assert_false, assert_true, TestSuite
from emberjson import parse as parse_json, Value
from xyang.ast import YangModule
from xyang.yang import parse_yang_string
from xyang.validator import YangValidator


def _module_enum_union() raises -> YangModule:
    return parse_yang_string(
        """
        module test-enum-union {
          yang-version 1.1;
          namespace "urn:test:enum-union";
          prefix teu;

          container cfg {
            leaf mode {
              type enumeration {
                enum auto;
                enum manual;
              }
            }
            leaf id-or-name {
              type union {
                type uint16;
                type string;
              }
            }
          }
        }
        """
    )


def test_parse_enum_and_union_type_info() raises:
    var module = _module_enum_union()
    ref cfg = module.top_level_containers[0][]
    assert_equal(len(cfg.leaves), 2)

    var mode_idx = -1
    var id_or_name_idx = -1
    for i in range(len(cfg.leaves)):
        if cfg.leaves[i][].name == "mode":
            mode_idx = i
        elif cfg.leaves[i][].name == "id-or-name":
            id_or_name_idx = i

    assert_true(mode_idx >= 0)
    assert_true(id_or_name_idx >= 0)
    ref mode = cfg.leaves[mode_idx][]
    ref id_or_name = cfg.leaves[id_or_name_idx][]

    assert_equal(mode.type.name, "enumeration")
    assert_equal(mode.type.enum_values_len(), 2)
    assert_equal(mode.type.enum_value_at(0), "auto")
    assert_equal(mode.type.enum_value_at(1), "manual")

    assert_equal(id_or_name.type.name, "union")
    assert_equal(id_or_name.type.union_members_len(), 2)
    assert_equal(id_or_name.type.union_member_arc(0)[].name, "uint16")
    assert_equal(id_or_name.type.union_member_arc(1)[].name, "string")


def test_validator_enforces_enum_and_union() raises:
    var module = _module_enum_union()
    var validator = YangValidator()

    var ok_int: Value = parse_json(
        """
        {"cfg":{"mode":"auto","id-or-name":42}}
        """
    )
    var ok_int_result = validator.validate(ok_int, module)
    assert_true(ok_int_result.is_valid)

    var ok_string: Value = parse_json(
        """
        {"cfg":{"mode":"manual","id-or-name":"eth0"}}
        """
    )
    var ok_string_result = validator.validate(ok_string, module)
    assert_true(ok_string_result.is_valid)

    var bad_enum: Value = parse_json(
        """
        {"cfg":{"mode":"invalid","id-or-name":"eth0"}}
        """
    )
    var bad_enum_result = validator.validate(bad_enum, module)
    assert_false(bad_enum_result.is_valid)

    var bad_union: Value = parse_json(
        """
        {"cfg":{"mode":"auto","id-or-name":[1,2]}}
        """
    )
    var bad_union_result = validator.validate(bad_union, module)
    assert_false(bad_union_result.is_valid)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
