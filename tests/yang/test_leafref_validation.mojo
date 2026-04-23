## Validation tests for leafref-shaped fields in the basic YANG example.

from std.testing import assert_false, assert_true, TestSuite
from emberjson import parse as parse_json, Value
from xyang.ast import YangModule
from xyang.yang import parse_yang_file
from xyang.validator import YangValidator


def _module() raises -> YangModule:
    return parse_yang_file("examples/basic_yang/basic-device.yang")


def test_leafref_value_valid_string() raises:
    # management-interface is typed as leafref -> string is accepted by current checker.
    var data: Value = parse_json(
        """
        {
          "system": {
            "hostname": "edge-router-1",
            "enabled": true,
            "management-interface": "eth0",
            "interface": [
              {"name": "eth0", "mtu": 1500, "admin-up": true}
            ]
          }
        }
        """
    )
    var validator = YangValidator()
    var result = validator.validate(data, _module())
    assert_true(result.is_valid)


def test_leafref_value_valid_integer_leaf() raises:
    # Integer leafref target/value should be accepted.
    var data: Value = parse_json(
        """
        {
          "system": {
            "hostname": "edge-router-1",
            "enabled": true,
            "management-interface-index": 2,
            "interface": [
              {"name": "eth0", "if-index": 1, "mtu": 1500, "admin-up": true},
              {"name": "eth1", "if-index": 2, "mtu": 1500, "admin-up": true}
            ]
          }
        }
        """
    )
    var validator = YangValidator()
    var result = validator.validate(data, _module())
    assert_true(result.is_valid)


def test_leafref_value_invalid_non_scalar() raises:
    # leafref must be a scalar, not an object.
    var data: Value = parse_json(
        """
        {
          "system": {
            "hostname": "edge-router-1",
            "enabled": true,
            "management-interface": {"name": "eth0"},
            "interface": [
              {"name": "eth0", "if-index": 1, "mtu": 1500, "admin-up": true}
            ]
          }
        }
        """
    )
    var validator = YangValidator()
    var result = validator.validate(data, _module())
    assert_false(result.is_valid)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
