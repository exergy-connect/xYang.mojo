## Document validation: `choice` and `case` (mandatory, exclusivity, defaults, `when`, lists).

from std.testing import assert_equal, assert_false, assert_true, TestSuite
from emberjson import parse as parse_json, Value
from xyang.ast import YangModule
from xyang import parse_yang_string
from xyang.validator import YangValidator


def _err_contains(msg: String, part: String) raises:
    """Fail if part does not appear in msg."""
    _ = assert_true(msg.find(part) >= 0)


# --- Schemas: explicit `case` (named cases) vs shorthand leaves-as-cases. ---

def _module_non_mandatory_two_cases() raises -> YangModule:
    """`transport`: two cases, each with one leaf. Not mandatory; no default."""
    return parse_yang_string(
        """
        module test-ch-nonmand {
          yang-version 1.1;
          namespace "urn:test:ch-nonmand";
          prefix t;

          container c {
            choice transport {
              case a-case {
                leaf a-leaf { type string; }
              }
              case b-case {
                leaf b-leaf { type string; }
              }
            }
          }
        }
        """
    )


def _module_mandatory_no_default() raises -> YangModule:
    return parse_yang_string(
        """
        module test-ch-mand-nodf {
          yang-version 1.1;
          namespace "urn:test:ch-mand-nodf";
          prefix t;

          container c {
            choice must-pick {
              mandatory true;
              case x-case {
                leaf x-leaf { type string; }
              }
              case y-case {
                leaf y-leaf { type string; }
              }
            }
          }
        }
        """
    )


def _module_shorthand_leaves() raises -> YangModule:
    """Implicit cases: two leaf children of `choice` (per parser shorthand)."""
    return parse_yang_string(
        """
        module test-ch-shorthand {
          yang-version 1.1;
          namespace "urn:test:ch-sh";
          prefix t;

          container c {
            choice fmt {
              leaf alpha { type string; }
              leaf beta { type string; }
            }
          }
        }
        """
    )


def _module_case_with_container() raises -> YangModule:
    return parse_yang_string(
        """
        module test-ch-cont {
          yang-version 1.1;
          namespace "urn:test:ch-cont";
          prefix t;

          container c {
            choice outer {
              case in-cont {
                container sub {
                  leaf v { type string; mandatory true; }
                }
              }
              case in-leaf {
                leaf w { type uint8; }
              }
            }
          }
        }
        """
    )


def _module_case_when() raises -> YangModule:
    return parse_yang_string(
        """
        module test-ch-case-when {
          yang-version 1.1;
          namespace "urn:test:ch-cwhen";
          prefix t;

          container c {
            leaf gating { type boolean; default true; }
            choice gated {
              case on-case {
                when "../gating = true()";
                leaf v-on { type string; }
              }
              case off-case {
                when "../gating = false()";
                leaf v-off { type string; }
              }
            }
          }
        }
        """
    )


def _module_choice_when() raises -> YangModule:
    return parse_yang_string(
        """
        module test-ch-choice-when {
          yang-version 1.1;
          namespace "urn:test:ch-qwhen";
          prefix t;

          container c {
            leaf en { type boolean; default true; }
            choice opt {
              when "../en = true()";
              leaf a { type string; }
              leaf b { type string; }
            }
          }
        }
        """
    )


def _module_list_with_choice() raises -> YangModule:
    return parse_yang_string(
        """
        module test-ch-list {
          yang-version 1.1;
          namespace "urn:test:ch-list";
          prefix t;

          container c {
            list item {
              key "name";
              leaf name { type string; }
              choice mode {
                case u {
                  leaf u-bit { type uint8; }
                }
                case v {
                  leaf v-bit { type uint8; }
                }
              }
            }
          }
        }
        """
    )


def _module_two_sibling_choices() raises -> YangModule:
    return parse_yang_string(
        """
        module test-ch-twoch {
          yang-version 1.1;
          namespace "urn:test:ch-twoch";
          prefix t;

          container c {
            choice c1 {
              case c1a { leaf a1 { type string; } }
              case c1b { leaf b1 { type string; } }
            }
            choice c2 {
              case c2a { leaf a2 { type string; } }
              case c2b { leaf b2 { type string; } }
            }
          }
        }
        """
    )


# --- Tests ---

def test_non_mandatory_empty_is_valid() raises:
    var module = _module_non_mandatory_two_cases()
    var data: Value = parse_json('{"c": {}}')
    var validator = YangValidator()
    _ = assert_true(validator.validate(data, module).is_valid)


def test_non_mandatory_one_case_valid() raises:
    var module = _module_non_mandatory_two_cases()
    var data: Value = parse_json('{"c": {"a-leaf": "ok"}}')
    var validator = YangValidator()
    _ = assert_true(validator.validate(data, module).is_valid)


def test_non_mandatory_two_active_cases_invalid() raises:
    var module = _module_non_mandatory_two_cases()
    var data: Value = parse_json('{"c": {"a-leaf": "x", "b-leaf": "y"}}')
    var validator = YangValidator()
    var r = validator.validate(data, module)
    _ = assert_false(r.is_valid)
    _ = assert_equal(len(r.errors), 1)
    _ = _err_contains(
        r.errors[0],
        "Choice 'transport' allows only one case; data matches multiple cases",
    )
    _ = _err_contains(r.errors[0], "a-case")
    _ = _err_contains(r.errors[0], "b-case")


def test_shorthand_multi_branch_invalid() raises:
    var module = _module_shorthand_leaves()
    var validator = YangValidator()
    var r = validator.validate(
        parse_json('{"c": {"alpha": "p", "beta": "q"}}'),
        module,
    )
    _ = assert_false(r.is_valid)
    _ = _err_contains(r.errors[0], "Choice 'fmt' allows only one case")


def test_mandatory_no_data_invalid() raises:
    var module = _module_mandatory_no_default()
    var validator = YangValidator()
    var r = validator.validate(parse_json('{"c": {}}'), module)
    _ = assert_false(r.is_valid)
    _ = assert_equal(len(r.errors), 1)
    _ = _err_contains(r.errors[0], "Mandatory choice 'must-pick' has no active case")


def test_mandatory_one_branch_valid() raises:
    var module = _module_mandatory_no_default()
    var validator = YangValidator()
    _ = assert_true(
        validator.validate(parse_json('{"c": {"x-leaf": "ok"}}'), module).is_valid
    )


def test_container_case_node_valid() raises:
    var module = _module_case_with_container()
    var validator = YangValidator()
    var r = validator.validate(
        parse_json('{"c": {"sub": {"v": "hi"}}}'),
        module,
    )
    _ = assert_true(r.is_valid)


def test_container_case_sibling_leaves_invalid() raises:
    var module = _module_case_with_container()
    var validator = YangValidator()
    var r = validator.validate(
        parse_json('{"c": {"sub": {"v": "a"}, "w": 1}}'),
        module,
    )
    _ = assert_false(r.is_valid)
    _ = _err_contains(r.errors[0], "multiple cases")


def test_case_when_mismatch_data_invalid() raises:
    var module = _module_case_when()
    var validator = YangValidator()
    var r = validator.validate(
        parse_json('{"c": {"gating": false, "v-on": "bad"}}'),
        module,
    )
    _ = assert_false(r.is_valid)
    _ = _err_contains(
        r.errors[0],
        "Case 'on-case' of choice 'gated' has data but its 'when' condition is false",
    )


def test_case_when_consistent_valid() raises:
    var module = _module_case_when()
    var v1 = YangValidator()
    _ = assert_true(
        v1.validate(
            parse_json('{"c": {"gating": true, "v-on": "ok"}}'),
            module,
        ).is_valid,
    )
    var v2 = YangValidator()
    _ = assert_true(
        v2.validate(
            parse_json('{"c": {"gating": false, "v-off": "ok"}}'),
            module,
        ).is_valid,
    )


def test_choice_when_inactive_with_no_data_valid() raises:
    var module = _module_choice_when()
    var validator = YangValidator()
    _ = assert_true(
        validator.validate(
            parse_json('{"c": {"en": false}}'),
            module,
        ).is_valid,
    )


def test_choice_when_inactive_with_branch_data_invalid() raises:
    var module = _module_choice_when()
    var validator = YangValidator()
    var r = validator.validate(
        parse_json('{"c": {"en": false, "a": "x"}}'),
        module,
    )
    _ = assert_false(r.is_valid)
    _ = _err_contains(
        r.errors[0],
        "Choice 'opt' has data but its 'when' condition is false",
    )


def test_list_entry_one_choice_branch_valid() raises:
    var module = _module_list_with_choice()
    var validator = YangValidator()
    var r = validator.validate(
        parse_json('{"c": {"item": [{"name": "n1", "u-bit": 1}]}}'),
        module,
    )
    _ = assert_true(r.is_valid)


def test_list_entry_both_branches_invalid() raises:
    var module = _module_list_with_choice()
    var validator = YangValidator()
    var r = validator.validate(
        parse_json('{"c": {"item": [{"name": "n1", "u-bit": 1, "v-bit": 2}]}}'),
        module,
    )
    _ = assert_false(r.is_valid)
    _ = _err_contains(
        r.errors[0],
        "Choice 'mode' allows only one case; data matches multiple cases",
    )


def test_two_choices_independent() raises:
    var module = _module_two_sibling_choices()
    var v_ok = YangValidator()
    _ = assert_true(
        v_ok.validate(
            parse_json('{"c": {"a1": "a", "a2": "b"}}'),
            module,
        ).is_valid,
    )
    var v_bad = YangValidator()
    _ = assert_false(
        v_bad.validate(
            parse_json('{"c": {"a1": "a", "b1": "b"}}'),
            module,
        ).is_valid,
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
