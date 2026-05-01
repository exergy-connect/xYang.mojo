## anydata / anyxml: text parse, validate arbitrary JSON, JSON Schema round-trip.

from emberjson import parse, Value
from std.testing import assert_equal, assert_true, TestSuite
from xyang import parse_yang_string
from xyang.json.generator import generate_json_schema, schema_to_yang_json
from xyang.json.parser import parse_json_schema
from xyang.validator.document_validator import DocumentValidator

def _module_source() -> String:
    return (
        """
module adax {
  yang-version 1.1;
  namespace "urn:adax";
  prefix adax;
  container data-model {
    anydata payload { description "free-form"; }
    anyxml legacy { mandatory true; }
    leaf tag { type string; }
  }
}
"""
    )


def test_parse_anydata_anyxml_ast() raises:
    var module = parse_yang_string(_module_source())
    assert_equal(len(module.top_level_containers), 1)
    ref dm = module.top_level_containers[0][]
    assert_equal(dm.name, "data-model")
    assert_equal(len(dm.anydatas), 1)
    assert_equal(len(dm.anyxmls), 1)
    assert_equal(dm.anydatas[0][].name, "payload")
    assert_equal(dm.anyxmls[0][].name, "legacy")
    assert_true(dm.anyxmls[0][].mandatory)
    assert_equal(dm.anydatas[0][].description, "free-form")


def test_validate_accepts_arbitrary_json() raises:
    var module = parse_yang_string(_module_source())
    var v = DocumentValidator()
    var data: Value = parse(
        '{"data-model":{"payload":{"nested":[1,2,null],"ok":true},"legacy":"plain string","tag":"x"}}',
    )
    var errs = v.validate(module, data)
    assert_equal(len(errs), 0)


def test_validate_mandatory_anyxml_missing() raises:
    var module = parse_yang_string(_module_source())
    var v = DocumentValidator()
    var data: Value = parse('{"data-model":{"tag":"x"}}')
    var errs = v.validate(module, data)
    assert_equal(len(errs), 1)
    assert_true("anyxml" in errs[0].message.lower())
    assert_true("legacy" in errs[0].message)


def test_schema_roundtrip_kinds() raises:
    var module = parse_yang_string(_module_source())
    var json_text = schema_to_yang_json(module)
    var m2 = parse_json_schema(json_text)
    ref dm2 = m2.top_level_containers[0][]
    assert_equal(len(dm2.anydatas), 1)
    assert_equal(len(dm2.anyxmls), 1)
    assert_equal(dm2.anydatas[0][].name, "payload")
    assert_equal(dm2.anyxmls[0][].name, "legacy")
    assert_true(dm2.anyxmls[0][].mandatory)
    var root = generate_json_schema(module)
    ref dm_prop = root.object()["properties"]["data-model"].object()
    ref props = dm_prop["properties"].object()
    assert_equal(props["payload"]["x-yang"]["type"].string(), "anydata")
    assert_equal(props["legacy"]["x-yang"]["type"].string(), "anyxml")
    assert_true("type" in props["payload"].object())
    assert_true(props["payload"]["type"].is_array())


def test_extension_and_if_feature_in_anydata_body() raises:
    var src = (
        """
module extdemo {
  yang-version 1.1;
  namespace "urn:ext";
  prefix ex;
  container c {
    anydata p {
      if-feature feat;
      ex:ann { description "x"; }
      description "d";
    }
  }
}
"""
    )
    var m = parse_yang_string(src)
    assert_equal(len(m.top_level_containers[0][].anydatas), 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
