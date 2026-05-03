from std.testing import assert_equal, assert_true

from xyang.json import parse_yang_json, parse_yang_json_module
from xyang.yang.arguments import PathArgument
from xyang.yang.ast.lexer import AstLexer
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.parser import parse_module
from xyang.yang.path import parse_yang_path


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


def test_overlapping_length_in_xyang_rejected() raises:
    ## RFC 7950 §9.4.4: `length` segments must be disjoint (only in `x-yang.length`
    ## when JSON Schema cannot express the constraint).
    var json_text = """
{
  "x-yang": {
    "module": "badlen",
    "yang-version": "1.1",
    "namespace": "urn:badlen",
    "prefix": "b"
  },
  "type": "object",
  "properties": {
    "x": {
      "type": "string",
      "x-yang": {"type": "leaf", "length": "1..4|2..5"}
    }
  }
}
"""
    try:
        _ = parse_yang_json_module(json_text)
        raise Error("expected overlapping length to fail validation")
    except:
        pass


def test_pattern_invert_from_json_emits_modifier() raises:
    var json_text = """
{
  "x-yang": {
    "module": "invpat",
    "yang-version": "1.1",
    "namespace": "urn:invpat",
    "prefix": "i"
  },
  "type": "object",
  "properties": {
    "x": {
      "type": "string",
      "x-yang": {"type": "leaf", "pattern": "[0-9]+", "patternInvert": true}
    }
  }
}
"""
    var tree = parse_yang_json(json_text)
    var formatted = tree.format(0)
    if "invert-match" not in formatted:
        raise Error("expected modifier invert-match in emitted YANG tree")


def test_parse_yang_path_with_leafref_predicate() raises:
    var path = parse_yang_path(
        "/data-model/entities[name = current()/../entity]/fields/name"
    )
    assert_true(path.absolute)
    assert_equal(len(path.segments), 4)
    assert_equal(path.segments[1].node.local_name, "entities")
    assert_equal(len(path.segments[1].predicates), 1)
    assert_equal(path.segments[1].predicates[0].key.local_name, "name")
    assert_equal(path.segments[1].predicates[0].target.parent_steps, 1)
    assert_equal(
        path.segments[1].predicates[0].target.segments[0].local_name, "entity"
    )


def test_path_argument_stores_validated_yang_path() raises:
    var node = YangConstruct("path", 7)
    node.set_raw_argument("../fields/name")
    PathArgument.validate(node)
    assert_true(node.argument.isa[PathArgument]())
    ref arg = node.argument.get[PathArgument]()
    assert_equal(node.argument.text, "../fields/name")
    assert_equal(arg.path.parent_steps, 1)
    assert_equal(len(arg.path.segments), 2)
    assert_equal(arg.path.segments[0].node.local_name, "fields")


def test_invalid_yang_path_rejected() raises:
    var node = YangConstruct("path", 11)
    node.set_raw_argument("/data-model/")
    var failed = False
    try:
        PathArgument.validate(node)
    except:
        failed = True
    assert_true(failed)


def main() raises:
    test_yang_json_raw_construct_matches_yang_text()
    test_yang_json_module_indexes_supported_subset()
    test_overlapping_length_in_xyang_rejected()
    test_pattern_invert_from_json_emits_modifier()
    test_parse_yang_path_with_leafref_predicate()
    test_path_argument_stores_validated_yang_path()
    test_invalid_yang_path_rejected()
