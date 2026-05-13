## Leafref validation tests: absolute paths, relative paths, list predicates,
## and negative cases (non-existing targets, broken paths).

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


# ---------------------------------------------------------------------------
# YANG modules embedded as string literals
# ---------------------------------------------------------------------------

comptime YANG_SIMPLE = """
module lr-simple {
  yang-version 1.1;
  namespace "urn:test:lr-simple";
  prefix lr;

  container config {
    list interface {
      key "name";
      leaf name {
        type string;
        must "string-length(.) > 0" {
          error-message "name must be non-empty";
        }
      }
      leaf if-index {
        type uint16;
      }
    }

    leaf mgmt-interface {
      type leafref {
        path "/config/interface/name";
      }
    }

    leaf mgmt-index {
      type leafref {
        path "/config/interface/if-index";
      }
    }
  }
}
"""

comptime YANG_RELATIVE = """
module lr-relative {
  yang-version 1.1;
  namespace "urn:test:lr-relative";
  prefix lr;

  container config {
    list interface {
      key "name";
      leaf name {
        type string;
        must "string-length(.) > 0" {
          error-message "name must be non-empty";
        }
      }
    }

    container mgmt {
      leaf active-interface {
        type leafref {
          path "../../interface/name";
        }
      }
    }
  }
}
"""

comptime YANG_PREDICATE = """
module lr-pred {
  yang-version 1.1;
  namespace "urn:test:lr-pred";
  prefix lr;

  container config {
    list vrf {
      key "name";
      leaf name {
        type string;
        must "string-length(.) > 0" {
          error-message "vrf name must be non-empty";
        }
      }

      list interface {
        key "name";
        leaf name {
          type string;
          must "string-length(.) > 0" {
            error-message "interface name must be non-empty";
          }
        }
      }
    }

    container binding {
      leaf vrf-name {
        type string;
      }
      leaf bound-interface {
        type leafref {
          path "/config/vrf[name = current()/../vrf-name]/interface/name";
        }
      }
    }
  }
}
"""

comptime YANG_MULTI_LEAFREF = """
module lr-multi {
  yang-version 1.1;
  namespace "urn:test:lr-multi";
  prefix lr;

  container config {
    list port {
      key "id";
      leaf id {
        type string;
        must "string-length(.) > 0" {
          error-message "port id must be non-empty";
        }
      }
    }

    leaf primary-port {
      type leafref {
        path "/config/port/id";
      }
    }

    leaf backup-port {
      type leafref {
        path "/config/port/id";
      }
    }
  }
}
"""

# ---------------------------------------------------------------------------
# Positive tests
# ---------------------------------------------------------------------------


def test_absolute_string_leafref_resolves() raises:
    _expect_ok(
        YANG_SIMPLE,
        """
        {
          "config": {
            "interface": [
              {"name": "eth0", "if-index": 1},
              {"name": "eth1", "if-index": 2}
            ],
            "mgmt-interface": "eth0"
          }
        }
        """,
    )


def test_absolute_integer_leafref_resolves() raises:
    _expect_ok(
        YANG_SIMPLE,
        """
        {
          "config": {
            "interface": [
              {"name": "eth0", "if-index": 1},
              {"name": "eth1", "if-index": 2}
            ],
            "mgmt-index": 2
          }
        }
        """,
    )


def test_relative_leafref_resolves() raises:
    _expect_ok(
        YANG_RELATIVE,
        """
        {
          "config": {
            "interface": [
              {"name": "lo0"},
              {"name": "eth0"}
            ],
            "mgmt": {
              "active-interface": "lo0"
            }
          }
        }
        """,
    )


def test_predicate_leafref_resolves() raises:
    _expect_ok(
        YANG_PREDICATE,
        """
        {
          "config": {
            "vrf": [
              {
                "name": "default",
                "interface": [{"name": "eth0"}, {"name": "eth1"}]
              },
              {
                "name": "mgmt",
                "interface": [{"name": "mgmt0"}]
              }
            ],
            "binding": {
              "vrf-name": "mgmt",
              "bound-interface": "mgmt0"
            }
          }
        }
        """,
    )


def test_multiple_leafrefs_resolve() raises:
    _expect_ok(
        YANG_MULTI_LEAFREF,
        """
        {
          "config": {
            "port": [
              {"id": "p1"},
              {"id": "p2"},
              {"id": "p3"}
            ],
            "primary-port": "p1",
            "backup-port": "p3"
          }
        }
        """,
    )


def test_leafref_to_last_list_entry() raises:
    _expect_ok(
        YANG_SIMPLE,
        """
        {
          "config": {
            "interface": [
              {"name": "eth0", "if-index": 10},
              {"name": "eth1", "if-index": 20},
              {"name": "eth2", "if-index": 30}
            ],
            "mgmt-interface": "eth2"
          }
        }
        """,
    )


# ---------------------------------------------------------------------------
# Negative tests
# ---------------------------------------------------------------------------


def test_nonexistent_string_leafref_fails() raises:
    _expect_error(
        YANG_SIMPLE,
        """
        {
          "config": {
            "interface": [
              {"name": "eth0", "if-index": 1}
            ],
            "mgmt-interface": "eth99"
          }
        }
        """,
        "does not resolve",
    )


def test_nonexistent_integer_leafref_fails() raises:
    _expect_error(
        YANG_SIMPLE,
        """
        {
          "config": {
            "interface": [
              {"name": "eth0", "if-index": 1}
            ],
            "mgmt-index": 999
          }
        }
        """,
        "does not resolve",
    )


def test_relative_leafref_nonexistent_fails() raises:
    _expect_error(
        YANG_RELATIVE,
        """
        {
          "config": {
            "interface": [
              {"name": "eth0"}
            ],
            "mgmt": {
              "active-interface": "missing-intf"
            }
          }
        }
        """,
        "does not resolve",
    )


def test_predicate_leafref_wrong_vrf_fails() raises:
    _expect_error(
        YANG_PREDICATE,
        """
        {
          "config": {
            "vrf": [
              {
                "name": "default",
                "interface": [{"name": "eth0"}]
              },
              {
                "name": "mgmt",
                "interface": [{"name": "mgmt0"}]
              }
            ],
            "binding": {
              "vrf-name": "mgmt",
              "bound-interface": "eth0"
            }
          }
        }
        """,
        "does not resolve",
    )


def test_predicate_leafref_nonexistent_vrf_fails() raises:
    _expect_error(
        YANG_PREDICATE,
        """
        {
          "config": {
            "vrf": [
              {
                "name": "default",
                "interface": [{"name": "eth0"}]
              }
            ],
            "binding": {
              "vrf-name": "no-such-vrf",
              "bound-interface": "eth0"
            }
          }
        }
        """,
        "does not resolve",
    )


def test_leafref_empty_list_fails() raises:
    _expect_error(
        YANG_SIMPLE,
        """
        {
          "config": {
            "interface": [],
            "mgmt-interface": "eth0"
          }
        }
        """,
        "does not resolve",
    )


def test_multiple_leafrefs_one_bad_fails() raises:
    _expect_error(
        YANG_MULTI_LEAFREF,
        """
        {
          "config": {
            "port": [
              {"id": "p1"},
              {"id": "p2"}
            ],
            "primary-port": "p1",
            "backup-port": "p99"
          }
        }
        """,
        "does not resolve",
    )


# ---------------------------------------------------------------------------


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
