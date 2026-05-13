## List and leaf-list `min-elements` / `max-elements` validation.

from std.testing import TestSuite, assert_true

from xyang.validator.document import validate_yang_document


def _expect_ok(yang: String, json: String) raises:
    validate_yang_document(yang, json)


def _expect_error(yang: String, json: String, fragment: String) raises:
    try:
        validate_yang_document(yang, json)
        raise Error("expected validation to fail with: " + fragment)
    except e:
        var msg = String(e)
        assert_true(
            fragment in msg,
            "expected `" + fragment + "` in error: " + msg,
        )


comptime YANG_CARDINALITY = """
module cardinality {
  yang-version 1.1;
  namespace "urn:test:cardinality";
  prefix c;

  container config {
    list server {
      key "name";
      min-elements 1;
      max-elements 2;

      leaf name {
        type string;
      }
    }

    leaf-list dns {
      type string;
      min-elements 1;
      max-elements 3;
    }

    leaf-list tag {
      type string;
      max-elements unbounded;
    }
  }
}
"""


def test_list_cardinality_accepts_bounds() raises:
    _expect_ok(
        YANG_CARDINALITY,
        """
        {
          "config": {
            "server": [{"name": "a"}, {"name": "b"}],
            "dns": ["1.1.1.1", "8.8.8.8"]
          }
        }
        """,
    )


def test_list_min_elements_rejects_too_few() raises:
    _expect_error(
        YANG_CARDINALITY,
        """
        {
          "config": {
            "server": [],
            "dns": ["1.1.1.1"]
          }
        }
        """,
        "fewer entries than `min-elements` 1",
    )


def test_list_max_elements_rejects_too_many() raises:
    _expect_error(
        YANG_CARDINALITY,
        """
        {
          "config": {
            "server": [
              {"name": "a"},
              {"name": "b"},
              {"name": "c"}
            ],
            "dns": ["1.1.1.1"]
          }
        }
        """,
        "more entries than `max-elements` 2",
    )


def test_leaf_list_min_elements_rejects_too_few() raises:
    _expect_error(
        YANG_CARDINALITY,
        """
        {
          "config": {
            "server": [{"name": "a"}],
            "dns": []
          }
        }
        """,
        "fewer entries than `min-elements` 1",
    )


def test_leaf_list_max_elements_rejects_too_many() raises:
    _expect_error(
        YANG_CARDINALITY,
        """
        {
          "config": {
            "server": [{"name": "a"}],
            "dns": ["1.1.1.1", "8.8.8.8", "9.9.9.9", "4.4.4.4"]
          }
        }
        """,
        "more entries than `max-elements` 3",
    )


def test_max_elements_unbounded_accepts_many_values() raises:
    _expect_ok(
        YANG_CARDINALITY,
        """
        {
          "config": {
            "server": [{"name": "a"}],
            "dns": ["1.1.1.1"],
            "tag": ["a", "b", "c", "d", "e"]
          }
        }
        """,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
