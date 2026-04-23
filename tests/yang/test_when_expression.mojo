## Validation test for YANG `when` expressions on leaf presence.

from std.testing import assert_false, assert_true, TestSuite
from emberjson import parse as parse_json, Value
from xyang.ast import YangModule
from xyang.yang import parse_yang_file
from xyang.validator import YangValidator


def _module() raises -> YangModule:
    return parse_yang_file("examples/basic_yang/basic-device.yang")


def test_when_expression_valid() raises:
    # shutdown-reason allowed when admin-up is false.
    var data: Value = parse_json(
        """
        {
          "system": {
            "hostname": "edge-router-1",
            "enabled": true,
            "interface": [
              {
                "name": "eth1",
                "mtu": 1500,
                "admin-up": false,
                "shutdown-reason": "maintenance-window"
              }
            ]
          }
        }
        """
    )
    var validator = YangValidator()
    var result = validator.validate(data, _module())
    assert_true(result.is_valid)


def test_when_expression_invalid() raises:
    # shutdown-reason must be absent when admin-up is true.
    var data: Value = parse_json(
        """
        {
          "system": {
            "hostname": "edge-router-1",
            "enabled": true,
            "interface": [
              {
                "name": "eth2",
                "mtu": 1500,
                "admin-up": true,
                "shutdown-reason": "should-not-be-set-when-up"
              }
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
