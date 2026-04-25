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


def test_list_element_must_valid() raises:
    # /system/interface[*]/name has must "string-length(.) > 0".
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
    var module = parse_yang_module(
        """
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:test:list-element-must",
  "x-yang": {
    "module": "list-element-must",
    "yang-version": "1.1",
    "namespace": "urn:test:list-element-must",
    "prefix": "lem"
  },
  "type": "object",
  "properties": {
    "system": {
      "type": "object",
      "x-yang": { "type": "container" },
      "properties": {
        "hostname": { "type": "string", "x-yang": { "type": "leaf" } },
        "enabled": { "type": "boolean", "x-yang": { "type": "leaf" } },
        "management-interface": { "type": "string", "x-yang": { "type": "leaf" } },
        "interface": {
          "type": "array",
          "x-yang": { "type": "list", "key": "name" },
          "items": {
            "type": "object",
            "properties": {
              "name": {
                "type": "string",
                "x-yang": {
                  "type": "leaf",
                  "must": [{"must": "string-length(.) > 0"}]
                }
              },
              "mtu": { "type": "integer", "x-yang": { "type": "leaf" } },
              "admin-up": { "type": "boolean", "x-yang": { "type": "leaf" } }
            },
            "additionalProperties": false
          }
        }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}
""",
    )
    var validator = YangValidator()
    var result = validator.validate(data, module)
    assert_true(result.is_valid)


def test_list_element_must_invalid() raises:
    # Empty interface name violates list-element must.
    var data: Value = parse_json(
        """
        {
          "system": {
            "hostname": "edge-router-1",
            "enabled": true,
            "management-interface": "eth0",
            "interface": [
              {"name": "", "mtu": 1500, "admin-up": true}
            ]
          }
        }
        """
    )
    var module = parse_yang_module(
        """
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:test:list-element-must",
  "x-yang": {
    "module": "list-element-must",
    "yang-version": "1.1",
    "namespace": "urn:test:list-element-must",
    "prefix": "lem"
  },
  "type": "object",
  "properties": {
    "system": {
      "type": "object",
      "x-yang": { "type": "container" },
      "properties": {
        "hostname": { "type": "string", "x-yang": { "type": "leaf" } },
        "enabled": { "type": "boolean", "x-yang": { "type": "leaf" } },
        "management-interface": { "type": "string", "x-yang": { "type": "leaf" } },
        "interface": {
          "type": "array",
          "x-yang": { "type": "list", "key": "name" },
          "items": {
            "type": "object",
            "properties": {
              "name": {
                "type": "string",
                "x-yang": {
                  "type": "leaf",
                  "must": [{"must": "string-length(.) > 0"}]
                }
              },
              "mtu": { "type": "integer", "x-yang": { "type": "leaf" } },
              "admin-up": { "type": "boolean", "x-yang": { "type": "leaf" } }
            },
            "additionalProperties": false
          }
        }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}
""",
    )
    var validator = YangValidator()
    var result = validator.validate(data, module)
    assert_false(result.is_valid)


def test_must_unparsed_expression_is_validation_error() raises:
    # XPath parse failure must surface as a validation error, not be skipped.
    var schema = """
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "$id": "urn:test:badmust",
      "x-yang": {
        "module": "badmust",
        "yang-version": "1.1",
        "namespace": "urn:test:badmust",
        "prefix": "b"
      },
      "type": "object",
      "properties": {
        "data-model": {
          "type": "object",
          "x-yang": { "type": "container" },
          "properties": {
            "name": {
              "type": "string",
              "x-yang": {
                "type": "leaf",
                "must": [{"must": "('a','b')"}]
              }
            }
          }
        }
      }
    }
    """
    var mod = parse_yang_module(schema)
    var data: Value = parse_json('{"data-model": {"name": "x"}}')
    var validator = YangValidator()
    var result = validator.validate(data, mod)
    assert_false(result.is_valid)


def test_container_and_list_must_validation() raises:
    var container_module = parse_yang_module(
        """
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:test:container-must",
  "x-yang": {
    "module": "container-must",
    "yang-version": "1.1",
    "namespace": "urn:test:container-must",
    "prefix": "cm"
  },
  "type": "object",
  "properties": {
    "root": {
      "type": "object",
      "x-yang": {
        "type": "container",
        "must": [
          {
            "must": "false()",
            "error-message": "container must failed"
          }
        ]
      },
      "properties": {
        "name": {
          "type": "string",
          "x-yang": { "type": "leaf" }
        }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}
""",
    )
    var list_module = parse_yang_module(
        """
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "urn:test:list-must",
  "x-yang": {
    "module": "list-must",
    "yang-version": "1.1",
    "namespace": "urn:test:list-must",
    "prefix": "lm"
  },
  "type": "object",
  "properties": {
    "root": {
      "type": "object",
      "x-yang": { "type": "container" },
      "properties": {
        "item": {
          "type": "array",
          "x-yang": {
            "type": "list",
            "key": "id",
            "must": [
              {
                "must": "false()",
                "error-message": "list must failed"
              }
            ]
          },
          "items": {
            "type": "object",
            "properties": {
              "id": {
                "type": "string",
                "x-yang": { "type": "leaf" }
              }
            },
            "additionalProperties": false
          }
        }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}
""",
    )
    var validator = YangValidator()

    var container_data: Value = parse_json(
        """
{
  "root": {
    "name": "ok"
  }
}
"""
    )
    var invalid_container_result = validator.validate(container_data, container_module)
    assert_false(invalid_container_result.is_valid)

    var list_data: Value = parse_json(
        """
{
  "root": {
    "item": [{"id": "x"}]
  }
}
"""
    )
    var invalid_list_result = validator.validate(list_data, list_module)
    assert_false(invalid_list_result.is_valid)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
