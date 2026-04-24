## Round-trip: text YANG → AST → JSON Schema → parse_json_schema.

from std.testing import assert_equal, assert_true, TestSuite
from xyang.yang import parse_yang_file, parse_yang_string
from xyang.json.generator import generate_json_schema, schema_to_yang_json
from xyang.json.parser import parse_json_schema
from xyang.yang.parser.yang_token import YANG_TYPE_LEAFREF


def test_schema_roundtrip_basic_device() raises:
    var path = "examples/basic_yang/basic-device.yang"
    var module = parse_yang_file(path)
    var json_text = schema_to_yang_json(module)
    assert_true(len(json_text) > 100)
    var roundtrip = parse_json_schema(json_text)

    assert_equal(roundtrip.name, module.name)
    assert_equal(roundtrip.namespace, module.namespace)
    assert_equal(roundtrip.prefix, module.prefix)
    assert_equal(len(roundtrip.top_level_containers), len(module.top_level_containers))
    ref sys0 = module.top_level_containers[0][]
    ref sys1 = roundtrip.top_level_containers[0][]
    assert_equal(sys0.name, sys1.name)
    assert_equal(len(sys0.leaves), len(sys1.leaves))
    assert_equal(len(sys0.lists), len(sys1.lists))

    var found_leafref = False
    for i in range(len(sys1.leaves)):
        ref lf = sys1.leaves[i][]
        if lf.type.name == YANG_TYPE_LEAFREF:
            found_leafref = True
            assert_true(lf.type.has_leafref_path())
    assert_true(found_leafref)


def test_generate_json_schema_has_draft_and_properties() raises:
    var path = "examples/basic_yang/basic-device.yang"
    var module = parse_yang_file(path)
    var root = generate_json_schema(module)
    ref obj = root.object()
    assert_true("$schema" in obj)
    assert_true("properties" in obj)
    assert_true("x-yang" in obj)
    assert_equal(
        obj["$schema"].string(),
        "https://json-schema.org/draft/2020-12/schema",
    )


def test_generate_and_roundtrip_enum_and_union() raises:
    var module = parse_yang_string(
        """
        module test-json-enum-union {
          yang-version 1.1;
          namespace "urn:test:json-enum-union";
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
              default "42";
            }
          }
        }
        """
    )

    var root = generate_json_schema(module)
    ref root_obj = root.object()
    ref cfg_prop = root_obj["properties"]["cfg"].object()
    ref cfg_props = cfg_prop["properties"].object()
    ref mode_prop = cfg_props["mode"].object()
    ref id_or_name_prop = cfg_props["id-or-name"].object()

    assert_true("enum" in mode_prop)
    assert_true(mode_prop["enum"].is_array())
    assert_true(len(mode_prop["enum"].array()) == 2)
    assert_equal(mode_prop["enum"].array()[0].string(), "auto")
    assert_equal(mode_prop["enum"].array()[1].string(), "manual")

    assert_true("oneOf" in id_or_name_prop)
    assert_true(id_or_name_prop["oneOf"].is_array())
    assert_true(len(id_or_name_prop["oneOf"].array()) == 2)
    assert_true("default" in id_or_name_prop)
    assert_true(id_or_name_prop["default"].is_int())
    assert_equal(id_or_name_prop["default"].int(), 42)

    var json_text = schema_to_yang_json(module)
    var roundtrip = parse_json_schema(json_text)
    ref cfg = roundtrip.top_level_containers[0][]
    var mode_idx = -1
    var id_or_name_idx = -1
    for i in range(len(cfg.leaves)):
        if cfg.leaves[i][].name == "mode":
            mode_idx = i
        elif cfg.leaves[i][].name == "id-or-name":
            id_or_name_idx = i
    assert_true(mode_idx >= 0)
    assert_true(id_or_name_idx >= 0)
    assert_equal(cfg.leaves[mode_idx][].type.name, "enumeration")
    assert_equal(cfg.leaves[mode_idx][].type.enum_values_len(), 2)
    assert_equal(cfg.leaves[id_or_name_idx][].type.name, "union")
    assert_equal(cfg.leaves[id_or_name_idx][].type.union_members_len(), 2)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
