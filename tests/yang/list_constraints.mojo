## List `unique` validation and `ordered-by` acceptance.

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


comptime YANG_LIST_CONSTRAINTS = """
module list-constraints {
  yang-version 1.1;
  namespace "urn:test:list-constraints";
  prefix lc;

  container config {
    list user {
      key "name";
      ordered-by user;
      unique "email address/city";

      leaf name {
        type string;
      }
      leaf email {
        type string;
      }
      container address {
        leaf city {
          type string;
        }
      }
    }

    leaf-list tag {
      type string;
      ordered-by user;
    }
  }
}
"""


def test_unique_accepts_distinct_tuples_and_ordered_by_user() raises:
    _expect_ok(
        YANG_LIST_CONSTRAINTS,
        """
        {
          "config": {
            "user": [
              {"name": "a", "email": "a@example.com", "address": {"city": "NYC"}},
              {"name": "b", "email": "a@example.com", "address": {"city": "SFO"}},
              {"name": "c", "email": "c@example.com", "address": {"city": "NYC"}}
            ],
            "tag": ["first", "second"]
          }
        }
        """,
    )


def test_unique_rejects_duplicate_complete_tuple() raises:
    _expect_error(
        YANG_LIST_CONSTRAINTS,
        """
        {
          "config": {
            "user": [
              {"name": "a", "email": "a@example.com", "address": {"city": "NYC"}},
              {"name": "b", "email": "a@example.com", "address": {"city": "NYC"}}
            ]
          }
        }
        """,
        "duplicate values for `unique` `email address/city`",
    )


def test_unique_ignores_entries_with_missing_referenced_leaf() raises:
    _expect_ok(
        YANG_LIST_CONSTRAINTS,
        """
        {
          "config": {
            "user": [
              {"name": "a", "email": "a@example.com"},
              {"name": "b", "email": "a@example.com"},
              {"name": "c", "address": {"city": "NYC"}},
              {"name": "d", "address": {"city": "NYC"}}
            ]
          }
        }
        """,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
