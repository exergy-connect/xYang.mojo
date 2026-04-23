## Standalone test for a simple YANG `must` expression.
## JSON/YANG schema is parsed with xyang.json.parser; validator evaluates must via xyang.xpath.

from std.testing import assert_true, assert_false, TestSuite
from emberjson import parse as parse_json, Value
from xyang.ast import YangModule
from xyang.json.parser import parse_yang_module
from xyang.validator import YangValidator


def _schema_json() -> String:
    """Minimal JSON/YANG schema for:
       container data-model {
         leaf name {
           type string;
           must "string-length(.) > 0";
         }
       }
    """
    return """
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "urn:test:mustrule",
      "x-yang": {
        "module": "test",
        "yang-version": "1.1",
        "namespace": "urn:test:mustrule",
        "prefix": "t"
      },
      "type": "object",
      "properties": {
        "data-model": {
          "type": "object",
          "description": "Root container for data model definition",
          "x-yang": {
            "type": "container"
          },
          "properties": {
            "name": {
              "type": "string",
              "x-yang": {
                "type": "leaf",
                "must": [
                  {
                    "must": "string-length(.) > 0",
                    "error-message": "name must be non-empty"
                  }
                ]
              }
            }
          }
        }
      }
    }
    """


def _build_module() raises -> YangModule:
    """Parse the inline schema JSON into a YangModule via the real parser."""
    var text = _schema_json()
    return parse_yang_module(text)


def test_must_expression_valid() raises:
    # /data-model/name is a non-empty string -> must holds.
    var json_str = """
    {
      "data-model": {
        "name": "ok"
      }
    }
    """
    var data: Value = parse_json(json_str)

    # Structural + type + must validation.
    var module = _build_module()
    var validator = YangValidator()
    var result = validator.validate(data, module)
    assert_true(result.is_valid)


def test_must_expression_invalid() raises:
    # /data-model/name is empty -> must "string-length(.) > 0" fails.
    var json_str = """
    {
      "data-model": {
        "name": ""
      }
    }
    """
    var data: Value = parse_json(json_str)

    var module = _build_module()
    var validator = YangValidator()
    var result = validator.validate(data, module)
    assert_false(result.is_valid)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()

