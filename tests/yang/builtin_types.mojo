## Comprehensive tests for all RFC 7950 built-in YANG types with constraints.
## Covers: int8/16/32/64, uint8/16/32/64, decimal64, string, boolean,
## enumeration, bits, binary, empty, leafref, identityref, union,
## instance-identifier — with range, length, pattern, and type-specific
## restrictions.

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
# YANG module with every built-in type and constraints
# ---------------------------------------------------------------------------

comptime YANG_ALL_TYPES = """
module all-types {
  yang-version 1.1;
  namespace "urn:test:all-types";
  prefix at;

  identity transport;
  identity tcp {
    base transport;
  }
  identity udp {
    base transport;
  }
  identity quic {
    base udp;
  }

  typedef percentage {
    type uint8 {
      range "0..100";
    }
  }

  container config {

    leaf i8 {
      type int8;
    }

    leaf i8-ranged {
      type int8 {
        range "-10..10";
      }
    }

    leaf i16 {
      type int16;
    }

    leaf i16-ranged {
      type int16 {
        range "-1000..1000";
      }
    }

    leaf i32 {
      type int32;
    }

    leaf i32-ranged {
      type int32 {
        range "0..1000000";
      }
    }

    leaf i64 {
      type int64;
    }

    leaf u8 {
      type uint8;
    }

    leaf u8-ranged {
      type uint8 {
        range "1..200";
      }
    }

    leaf u16 {
      type uint16;
    }

    leaf u16-ranged {
      type uint16 {
        range "100..5000";
      }
    }

    leaf u32 {
      type uint32;
    }

    leaf u32-ranged {
      type uint32 {
        range "0..999999";
      }
    }

    leaf u64 {
      type uint64;
    }

    leaf pct {
      type percentage;
    }

    leaf dec {
      type decimal64 {
        fraction-digits 2;
      }
    }

    leaf dec-ranged {
      type decimal64 {
        fraction-digits 3;
        range "0.0..100.0";
      }
    }

    leaf str {
      type string;
    }

    leaf str-len {
      type string {
        length "1..8";
      }
    }

    leaf str-pattern {
      type string {
        pattern "[a-z][a-z0-9]*";
      }
    }

    leaf flag {
      type boolean;
    }

    leaf color {
      type enumeration {
        enum red;
        enum green;
        enum blue;
      }
    }

    leaf permissions {
      type bits {
        bit read {
          position 0;
        }
        bit write {
          position 1;
        }
        bit execute {
          position 2;
        }
      }
    }

    leaf blob {
      type binary;
    }

    leaf blob-len {
      type binary {
        length "1..4";
      }
    }

    leaf marker {
      type empty;
    }

    leaf protocol {
      type identityref {
        base transport;
      }
    }

    leaf flexible {
      type union {
        type uint16;
        type string;
      }
    }

    leaf inst-id {
      type instance-identifier;
    }

    list port {
      key "id";
      leaf id {
        type string;
        must "string-length(.) > 0" {
          error-message "id required";
        }
      }
      leaf speed {
        type uint32;
      }
    }

    leaf mgmt-port {
      type leafref {
        path "/config/port/id";
      }
    }

    leaf-list tags {
      type string {
        length "1..20";
      }
    }

    leaf-list scores {
      type uint16 {
        range "0..1000";
      }
    }
  }
}
"""


# ===================================================================
# Positive tests
# ===================================================================


def test_int8_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i8": -128}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i8": 0}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i8": 127}}')


def test_int8_range_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i8-ranged": -10}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i8-ranged": 0}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i8-ranged": 10}}')


def test_int16_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i16": -32768}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i16": 32767}}')


def test_int16_range_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i16-ranged": -1000}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i16-ranged": 1000}}')


def test_int32_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i32": -2147483648}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i32": 2147483647}}')


def test_int32_range_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i32-ranged": 0}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i32-ranged": 1000000}}')


def test_int64_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i64": 0}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i64": -999999999}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"i64": 999999999}}')


def test_uint8_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u8": 0}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u8": 255}}')


def test_uint8_range_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u8-ranged": 1}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u8-ranged": 200}}')


def test_uint16_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u16": 0}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u16": 65535}}')


def test_uint16_range_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u16-ranged": 100}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u16-ranged": 5000}}')


def test_uint32_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u32": 0}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u32": 4294967295}}')


def test_uint32_range_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u32-ranged": 0}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u32-ranged": 999999}}')


def test_uint64_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u64": 0}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"u64": 1000000000000}}')


def test_typedef_uint8_range() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"pct": 0}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"pct": 50}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"pct": 100}}')


def test_decimal64_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"dec": 3.14}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"dec": -99.99}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"dec": 0}}')


def test_decimal64_range_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"dec-ranged": 0.0}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"dec-ranged": 50.5}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"dec-ranged": 100.0}}')


def test_string_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"str": "hello"}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"str": ""}}')


def test_string_length_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"str-len": "a"}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"str-len": "abcdefgh"}}')


def test_string_pattern_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"str-pattern": "abc123"}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"str-pattern": "x"}}')


def test_boolean_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"flag": true}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"flag": false}}')


def test_enumeration_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"color": "red"}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"color": "green"}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"color": "blue"}}')


def test_bits_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"permissions": "read"}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"permissions": "read write"}}')
    _expect_ok(
        YANG_ALL_TYPES,
        '{"config": {"permissions": "read write execute"}}',
    )
    _expect_ok(YANG_ALL_TYPES, '{"config": {"permissions": ""}}')


def test_binary_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"blob": "SGVsbG8="}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"blob": ""}}')


def test_binary_length_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"blob-len": "AQ=="}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"blob-len": "AQID"}}')


def test_empty_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"marker": [null]}}')


def test_identityref_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"protocol": "tcp"}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"protocol": "udp"}}')


def test_identityref_base_itself_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"protocol": "transport"}}')


def test_identityref_transitive_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"protocol": "quic"}}')


def test_identityref_unknown_value() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"protocol": "sctp"}}',
        "does not match any declared identity",
    )


def test_union_valid() raises:
    _expect_ok(YANG_ALL_TYPES, '{"config": {"flexible": 42}}')
    _expect_ok(YANG_ALL_TYPES, '{"config": {"flexible": "auto"}}')


def test_instance_identifier_valid() raises:
    _expect_ok(
        YANG_ALL_TYPES,
        '{"config": {"inst-id": "/config/port[id=\\"p1\\"]/speed"}}',
    )


def test_leafref_valid() raises:
    _expect_ok(
        YANG_ALL_TYPES,
        """
        {
          "config": {
            "port": [{"id": "mgmt", "speed": 1000}],
            "mgmt-port": "mgmt"
          }
        }
        """,
    )


def test_leaf_list_string_valid() raises:
    _expect_ok(
        YANG_ALL_TYPES,
        '{"config": {"tags": ["prod", "us-east"]}}',
    )


def test_leaf_list_uint16_valid() raises:
    _expect_ok(
        YANG_ALL_TYPES,
        '{"config": {"scores": [100, 500, 1000]}}',
    )


def test_many_types_together() raises:
    _expect_ok(
        YANG_ALL_TYPES,
        """
        {
          "config": {
            "i8": -1,
            "u16": 8080,
            "u32": 100000,
            "dec": 2.71,
            "str": "ok",
            "flag": true,
            "color": "blue",
            "permissions": "read execute",
            "blob": "AQID",
            "marker": [null],
            "protocol": "tcp",
            "port": [{"id": "eth0", "speed": 10000}],
            "mgmt-port": "eth0",
            "tags": ["a", "b"],
            "scores": [42]
          }
        }
        """,
    )


# ===================================================================
# Negative tests
# ===================================================================


def test_int8_overflow() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"i8": 128}}',
        "out of range",
    )
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"i8": -129}}',
        "out of range",
    )


def test_int8_range_violation() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"i8-ranged": 11}}',
        "range",
    )
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"i8-ranged": -11}}',
        "range",
    )


def test_int8_wrong_json_type() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"i8": "five"}}',
        "expected int8",
    )


def test_int16_overflow() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"i16": 32768}}',
        "out of range",
    )


def test_int16_range_violation() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"i16-ranged": 1001}}',
        "range",
    )


def test_int32_overflow() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"i32": 2147483648}}',
        "out of range",
    )


def test_int32_range_violation() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"i32-ranged": -1}}',
        "range",
    )


def test_uint8_negative() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"u8": -1}}',
        "out of range",
    )


def test_uint8_overflow() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"u8": 256}}',
        "out of range",
    )


def test_uint8_range_violation() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"u8-ranged": 0}}',
        "range",
    )


def test_uint16_overflow() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"u16": 65536}}',
        "out of range",
    )


def test_uint16_range_violation() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"u16-ranged": 99}}',
        "range",
    )


def test_uint32_negative() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"u32": -1}}',
        "out of range",
    )


def test_uint32_range_violation() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"u32-ranged": 1000000}}',
        "range",
    )


def test_uint64_negative() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"u64": -1}}',
        "out of range",
    )


def test_typedef_range_violation() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"pct": 101}}',
        "range",
    )


def test_decimal64_range_violation() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"dec-ranged": 100.1}}',
        "range",
    )


def test_decimal64_wrong_json_type() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"dec": "3.14"}}',
        "expected decimal64",
    )


def test_string_length_too_short() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"str-len": ""}}',
        "length",
    )


def test_string_length_too_long() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"str-len": "123456789"}}',
        "length",
    )


def test_string_pattern_violation() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"str-pattern": "123abc"}}',
        "pattern",
    )


def test_string_wrong_json_type() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"str": 42}}',
        "expected string",
    )


def test_boolean_wrong_json_type() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"flag": "true"}}',
        "expected boolean",
    )


def test_enumeration_invalid_value() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"color": "yellow"}}',
        "not allowed",
    )


def test_enumeration_wrong_json_type() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"color": 1}}',
        "expected string",
    )


def test_bits_unknown_bit() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"permissions": "read admin"}}',
        "unknown bit",
    )


def test_bits_wrong_json_type() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"permissions": 7}}',
        "expected string for bits",
    )


def test_binary_wrong_json_type() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"blob": 12345}}',
        "expected string for binary",
    )


def test_binary_length_violation() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"blob-len": "AQIDBAU="}}',
        "binary length",
    )


def test_empty_wrong_encoding() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"marker": null}}',
        "expected [null]",
    )
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"marker": true}}',
        "expected [null]",
    )


def test_identityref_wrong_json_type() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"protocol": 1}}',
        "expected string for identityref",
    )


def test_union_wrong_json_type() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"flexible": [1, 2]}}',
        "expected scalar for union",
    )


def test_instance_id_wrong_json_type() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"inst-id": 42}}',
        "expected string for instance-identifier",
    )


def test_leafref_not_found() raises:
    _expect_error(
        YANG_ALL_TYPES,
        """
        {
          "config": {
            "port": [{"id": "eth0"}],
            "mgmt-port": "missing"
          }
        }
        """,
        "does not resolve",
    )


def test_leaf_list_wrong_element_type() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"scores": [100, "bad"]}}',
        "expected uint16",
    )


def test_leaf_list_element_range() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"scores": [100, 1001]}}',
        "range",
    )


def test_leaf_list_string_length() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"tags": ["ok", ""]}}',
        "length",
    )


def test_unknown_field_rejected() raises:
    _expect_error(
        YANG_ALL_TYPES,
        '{"config": {"nonexistent": 1}}',
        "unknown field",
    )


# ---------------------------------------------------------------------------


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
