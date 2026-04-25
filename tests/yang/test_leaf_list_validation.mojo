## Validation tests for YANG leaf-list behavior.

from std.testing import assert_false, assert_true, TestSuite
from emberjson import parse as parse_json, Value
from xyang.ast import YangModule
from xyang import parse_yang_string
from xyang.validator import YangValidator


def _leaf_list_module() raises -> YangModule:
    return parse_yang_string(
        """
        module test-leaf-list {
          yang-version 1.1;
          namespace "urn:test:leaf-list";
          prefix t;

          container data {
            leaf-list tags {
              type string;
              must "string-length(.) > 0" {
                error-message "tag must be non-empty";
              }
            }
          }
        }
        """
    )


def test_leaf_list_valid() raises:
    var module = _leaf_list_module()
    ref data_container = module.top_level_containers[0][]
    assert_true(len(data_container.leaf_lists) == 1)
    assert_true(data_container.leaf_lists[0][].name == "tags")

    var data: Value = parse_json(
        """
        {
          "data": {
            "tags": ["prod", "edge"]
          }
        }
        """
    )
    var validator = YangValidator()
    var result = validator.validate(data, _leaf_list_module())
    assert_true(result.is_valid)


def test_leaf_list_invalid_non_array() raises:
    var data: Value = parse_json(
        """
        {
          "data": {
            "tags": "prod"
          }
        }
        """
    )
    var validator = YangValidator()
    var result = validator.validate(data, _leaf_list_module())
    assert_false(result.is_valid)


def test_leaf_list_invalid_must_item() raises:
    var data: Value = parse_json(
        """
        {
          "data": {
            "tags": ["prod", ""]
          }
        }
        """
    )
    var validator = YangValidator()
    var result = validator.validate(data, _leaf_list_module())
    assert_false(result.is_valid)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
