from std.testing import assert_equal, assert_true

from xyang.validator.document import validate_yang_document
from xyang.json import JsonValue, parse_json


comptime YANG_PATH = "examples/basic_yang/basic-device.yang"
comptime DATA_PATH = "examples/basic_yang/basic-device.json"


def read_text(path: String) raises -> String:
    var text: String
    with open(path, "r") as f:
        text = f.read()
    return text^


def test_basic_yang_files_validate() raises:
    validate_yang_document(
        read_text(YANG_PATH),
        read_text(DATA_PATH),
        YANG_PATH,
        DATA_PATH,
    )


def test_json_parser_distinguishes_int_and_real_numbers() raises:
    var data = parse_json("[1, 1.0, 1e2, 2E+3]")
    assert_equal(data.array_values[0][].kind, JsonValue.INT)
    assert_equal(data.array_values[1][].kind, JsonValue.REAL)
    assert_equal(data.array_values[2][].kind, JsonValue.REAL)
    assert_equal(data.array_values[3][].kind, JsonValue.REAL)


def test_integer_leaf_rejects_json_real() raises:
    var yang_text = """
module numeric-demo {
  yang-version 1.1;
  namespace "urn:numeric-demo";
  prefix n;

  container cfg {
    leaf count {
      type int32;
    }
  }
}
"""
    var json_text = """{"cfg": {"count": 1.0}}"""
    var failed = False
    try:
        validate_yang_document(yang_text, json_text)
    except:
        failed = True
    assert_equal(failed, True)


def test_decimal64_leaf_accepts_json_real() raises:
    var yang_text = """
module numeric-demo {
  yang-version 1.1;
  namespace "urn:numeric-demo";
  prefix n;

  container cfg {
    leaf ratio {
      type decimal64 {
        fraction-digits 2;
      }
    }
  }
}
"""
    validate_yang_document(yang_text, """{"cfg": {"ratio": 1.25}}""")


def _expect_validation_error(
    yang_text: String, json_text: String, fragment: String
) raises:
    try:
        validate_yang_document(yang_text, json_text)
        raise Error("expected validation error containing: " + fragment)
    except e:
        var msg = String(e)
        assert_true(
            fragment in msg,
            "expected `" + fragment + "` in error: " + msg,
        )


def test_if_feature_disables_nested_leaf() raises:
    var yang_text = """
module feature-demo {
  yang-version 1.1;
  namespace "urn:feature-demo";
  prefix f;

  container cfg {
    leaf always {
      type string;
    }
    leaf gated {
      if-feature missing-feature;
      type string;
    }
  }
}
"""
    validate_yang_document(yang_text, """{"cfg": {"always": "ok"}}""")
    _expect_validation_error(
        yang_text,
        """{"cfg": {"gated": "nope"}}""",
        "unknown field `gated`",
    )


def test_if_feature_feature_dependency_enables_leaf() raises:
    var yang_text = """
module feature-demo {
  yang-version 1.1;
  namespace "urn:feature-demo";
  prefix f;

  feature base;
  feature dependent {
    if-feature base;
  }

  container cfg {
    leaf gated {
      if-feature dependent;
      type string;
    }
  }
}
"""
    validate_yang_document(yang_text, """{"cfg": {"gated": "ok"}}""")


def test_if_feature_boolean_expression_disables_top_container() raises:
    var yang_text = """
module feature-demo {
  yang-version 1.1;
  namespace "urn:feature-demo";
  prefix f;

  feature base;

  container cfg {
    if-feature "base and not missing";
    leaf name {
      type string;
    }
  }

  container hidden {
    if-feature "base and missing";
    leaf name {
      type string;
    }
  }
}
"""
    validate_yang_document(yang_text, """{"cfg": {"name": "ok"}}""")
    _expect_validation_error(
        yang_text,
        """{"hidden": {"name": "nope"}}""",
        "unknown top-level field `hidden`",
    )


def main() raises:
    test_basic_yang_files_validate()
    test_json_parser_distinguishes_int_and_real_numbers()
    test_integer_leaf_rejects_json_real()
    test_decimal64_leaf_accepts_json_real()
    test_if_feature_disables_nested_leaf()
    test_if_feature_feature_dependency_enables_leaf()
    test_if_feature_boolean_expression_disables_top_container()
