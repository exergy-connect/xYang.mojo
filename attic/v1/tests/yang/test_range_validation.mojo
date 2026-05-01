from std.testing import assert_false, assert_true, TestSuite
from emberjson import parse as parse_json, Value
from xyang import parse_yang_file
from xyang.validator import YangValidator


def test_mtu_range_valid() raises:
    var module = parse_yang_file("examples/basic_yang/basic-device.yang")
    var validator = YangValidator()
    var data: Value = parse_json("""
    {
      "system": {
        "hostname": "edge-router-1",
        "enabled": true,
        "interface": [
          {"name": "eth0", "mtu": 1500, "admin-up": true}
        ]
      }
    }
    """)
    var result = validator.validate(data, module)
    assert_true(result.is_valid)


def test_mtu_range_invalid() raises:
    var module = parse_yang_file("examples/basic_yang/basic-device.yang")
    var validator = YangValidator()
    var data: Value = parse_json("""
    {
      "system": {
        "hostname": "edge-router-1",
        "enabled": true,
        "interface": [
          {"name": "eth0", "mtu": 9300, "admin-up": true}
        ]
      }
    }
    """)
    var result = validator.validate(data, module)
    assert_false(result.is_valid)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
