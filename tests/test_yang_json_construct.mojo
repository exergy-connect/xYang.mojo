from std.testing import assert_equal

from xyang.json import parse_yang_json, parse_yang_json_module
from xyang.yang.ast.lexer import AstLexer
from xyang.yang.ast.parser import parse_module


def test_yang_json_raw_construct_matches_yang_text() raises:
    var yang_text = """
module demo {
  yang-version 1.1;
  namespace "urn:demo";
  prefix d;
  description "Demo module";
  container cfg {
    description "Config root";
    leaf name {
      type string {
        length "1..64";
        pattern "[a-z]+";
      }
      mandatory true;
      description "Name";
    }
    list item {
      key id;
      min-elements 1;
      description "Items";
      leaf id {
        type uint8;
        description "Identifier";
      }
    }
  }
}
"""
    var json_text = """
{
  "description": "Demo module",
  "x-yang": {
    "module": "demo",
    "yang-version": "1.1",
    "namespace": "urn:demo",
    "prefix": "d"
  },
  "type": "object",
  "properties": {
    "cfg": {
      "type": "object",
      "description": "Config root",
      "x-yang": {"type": "container"},
      "properties": {
        "name": {
          "type": "string",
          "minLength": 1,
          "maxLength": 64,
          "pattern": "^[a-z]+$",
          "description": "Name",
          "x-yang": {"type": "leaf", "mandatory": true}
        },
        "item": {
          "type": "array",
          "minItems": 1,
          "description": "Items",
          "x-yang": {"type": "list", "key": "id"},
          "items": {
            "type": "object",
            "properties": {
              "id": {
                "type": "integer",
                "minimum": 0,
                "maximum": 255,
                "description": "Identifier",
                "x-yang": {"type": "leaf"}
              }
            }
          }
        }
      }
    }
  }
}
"""
    var lexer = AstLexer(yang_text.as_bytes())
    var yang_tree = parse_module(lexer)
    var json_tree = parse_yang_json(json_text)
    assert_equal(json_tree.format(0), yang_tree.format(0))


def test_yang_json_module_indexes_supported_subset() raises:
    var json_text = """
{
  "x-yang": {
    "module": "demo",
    "yang-version": "1.1",
    "namespace": "urn:demo",
    "prefix": "d"
  },
  "type": "object",
  "properties": {
    "cfg": {
      "type": "object",
      "x-yang": {"type": "container"},
      "properties": {
        "enabled": {
          "type": "boolean",
          "description": "Enabled flag",
          "x-yang": {"type": "leaf"}
        }
      }
    }
  }
}
"""
    var module = parse_yang_json_module(json_text)
    assert_equal(module.get_name(), "demo")
    assert_equal(module.get_namespace(), "urn:demo")
    var cfg = module.top_container("cfg")
    assert_equal(cfg != None, True)


def main() raises:
    test_yang_json_raw_construct_matches_yang_text()
    test_yang_json_module_indexes_supported_subset()
