## Validation tests for default realization and effective default semantics.

from std.testing import assert_true, assert_false, assert_equal, TestSuite
from emberjson import parse as parse_json, Value
from xyang.ast import YangModule, decompose_yang_list_children
from xyang import parse_yang_string, parse_yang_file
from xyang.validator import YangValidator


def _module_when_uses_default() raises -> YangModule:
    return parse_yang_string(
        """
        module test-default-when {
          yang-version 1.1;
          namespace "urn:test:default-when";
          prefix t;

          container data {
            leaf enabled {
              type boolean;
              default true;
            }
            leaf note {
              when "../enabled = true()";
              type string;
            }
          }
        }
        """
    )


def _module_choice_default_case() raises -> YangModule:
    return parse_yang_string(
        """
        module test-choice-default {
          yang-version 1.1;
          namespace "urn:test:choice-default";
          prefix t;

          container data {
            choice transport {
              mandatory true;
              default tcp-case;
              case tcp-case {
                leaf tcp-port {
                  type uint16;
                  default 443;
                }
              }
              case udp-case {
                leaf udp-port {
                  type uint16;
                }
              }
            }
          }
        }
        """
    )


def _module_leaf_list_default() raises -> YangModule:
    return parse_yang_string(
        """
        module test-leaf-list-default {
          yang-version 1.1;
          namespace "urn:test:leaf-list-default";
          prefix t;

          container data {
            leaf-list tags {
              type string;
              default "prod";
              default "edge";
              must "string-length(.) > 0" {
                error-message "tag must be non-empty";
              }
            }
          }
        }
        """
    )


def _module_union_default() raises -> YangModule:
    return parse_yang_string(
        """
        module test-union-default {
          yang-version 1.1;
          namespace "urn:test:union-default";
          prefix t;

          container data {
            leaf id {
              type union {
                type uint16;
                type enumeration {
                  enum abc;
                }
              }
              default "42";
            }
          }
        }
        """
    )


def test_text_parser_extracts_leaf_defaults() raises:
    var module = parse_yang_file("examples/basic_yang/basic-device.yang")
    ref system = module.top_level_containers[0][]

    var enabled_idx = -1
    for i in range(len(system.leaves)):
        if system.leaves[i][].name == "enabled":
            enabled_idx = i
            break
    assert_true(enabled_idx >= 0)
    assert_true(system.leaves[enabled_idx][].has_default)
    assert_equal(system.leaves[enabled_idx][].default_value, "true")

    ref interface_list = system.lists[0][]
    var il = decompose_yang_list_children(interface_list.children)
    var admin_up_idx = -1
    for i in range(len(il.leaves)):
        if il.leaves[i][].name == "admin-up":
            admin_up_idx = i
            break
    assert_true(admin_up_idx >= 0)
    assert_true(il.leaves[admin_up_idx][].has_default)
    assert_equal(il.leaves[admin_up_idx][].default_value, "true")


def test_when_uses_effective_default_value() raises:
    var module = _module_when_uses_default()
    var data: Value = parse_json(
        """
        {
          "data": {
            "note": "allowed-by-default-enabled"
          }
        }
        """
    )
    var validator = YangValidator()
    var result = validator.validate(data, module)
    assert_true(result.is_valid)


def test_choice_default_case_satisfies_mandatory() raises:
    var module = _module_choice_default_case()
    var data: Value = parse_json(
        """
        {
          "data": {}
        }
        """
    )
    var validator = YangValidator()
    var result = validator.validate(data, module)
    assert_true(result.is_valid)


def test_choice_multiple_active_cases_invalid() raises:
    var module = _module_choice_default_case()
    var data: Value = parse_json(
        """
        {
          "data": {
            "tcp-port": 443,
            "udp-port": 53
          }
        }
        """
    )
    var validator = YangValidator()
    var result = validator.validate(data, module)
    assert_false(result.is_valid)


def test_leaf_list_defaults_realized() raises:
    var module = _module_leaf_list_default()
    var data: Value = parse_json(
        """
        {
          "data": {}
        }
        """
    )
    var validator = YangValidator()
    var result = validator.validate(data, module)
    assert_true(result.is_valid)


def test_union_default_realized_with_member_type() raises:
    var module = _module_union_default()
    var data: Value = parse_json(
        """
        {
          "data": {}
        }
        """
    )
    var validator = YangValidator()
    var result = validator.validate(data, module)
    assert_true(result.is_valid)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
