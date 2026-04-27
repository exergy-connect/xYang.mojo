from std.testing import assert_equal, assert_true, TestSuite
from std.memory import ArcPointer
from xyang.yang.parser.yang_token import YANG_TYPE_LEAFREF
from xyang import parse_yang_file, parse_yang_string
from xyang.yang.parser.clone_utils import clone_yang_type_impl
from xyang.ast import (
    YangModule,
    YangType,
    YangTypedefStmt,
    YangUsesStmt,
    YangRefineStmt,
    YangAugmentStmt,
    decompose_yang_list_children,
)


def _typedef_type_by_name(read m: YangModule, name: String) raises -> YangType:
    for ref pair in m.typedefs.items():
        if pair.key == name:
            return clone_yang_type_impl(pair.value[].type_stmt)
    raise Error("typedef not found: " + name)


def _find_leaf_index_by_name_in_container(name: String, path: String) raises -> Int:
    var module = parse_yang_file(path)
    ref system = module.top_level_containers[0][]
    for i in range(len(system.leaves)):
        if system.leaves[i][].name == name:
            return i
    return -1


def _find_leaf_index_in_list(list_name: String, leaf_name: String, path: String) raises -> Int:
    var module = parse_yang_file(path)
    ref system = module.top_level_containers[0][]
    for i in range(len(system.lists)):
        if system.lists[i][].name == list_name:
            ref lst = system.lists[i][]
            var b = decompose_yang_list_children(lst.children)
            for j in range(len(b.leaves)):
                if b.leaves[j][].name == leaf_name:
                    return j
    return -1


def test_parse_basic_yang_file() raises:
    var path = "examples/basic_yang/basic-device.yang"
    var module = parse_yang_file(path)

    assert_equal(module.name, "basic-device")
    assert_equal(module.namespace, "urn:example:basic-device")
    assert_equal(module.prefix, "bd")

    assert_equal(module.get_name(), "basic-device")
    assert_equal(module.get_namespace(), "urn:example:basic-device")
    assert_equal(module.get_prefix(), "bd")
    assert_equal(
        module.get_description(),
        "A minimal YANG module used as a basic example.",
    )
    assert_true(len(module.get_revisions()) == 1)
    assert_equal(module.get_revisions()[0], "2026-04-23")
    assert_equal(module.get_organization(), "Example")
    assert_equal(module.get_contact(), "example@example.com")

    assert_true(len(module.get_top_level_containers()) == 1)
    assert_true(len(module.top_level_containers) == 1)
    ref system = module.top_level_containers[0][]
    assert_equal(system.name, "system")

    assert_true(len(system.leaves) == 4)
    var hostname_idx = _find_leaf_index_by_name_in_container("hostname", path)
    var enabled_idx = _find_leaf_index_by_name_in_container("enabled", path)
    var mgmt_if_idx = _find_leaf_index_by_name_in_container("management-interface", path)
    var mgmt_if_index_idx = _find_leaf_index_by_name_in_container("management-interface-index", path)
    assert_true(hostname_idx >= 0)
    assert_true(enabled_idx >= 0)
    assert_true(mgmt_if_idx >= 0)
    assert_true(mgmt_if_index_idx >= 0)
    assert_equal(system.leaves[hostname_idx][].type.name, "string")
    assert_equal(system.leaves[enabled_idx][].type.name, "boolean")
    assert_equal(system.leaves[mgmt_if_idx][].type.name, YANG_TYPE_LEAFREF)
    assert_equal(system.leaves[mgmt_if_idx][].type.leafref_path(), "/system/interface/name")
    assert_equal(system.leaves[mgmt_if_index_idx][].type.name, YANG_TYPE_LEAFREF)
    assert_equal(system.leaves[mgmt_if_index_idx][].type.leafref_path(), "/system/interface/if-index")

    assert_true(len(system.lists) == 1)
    ref interface_list = system.lists[0][]
    assert_equal(interface_list.name, "interface")
    assert_equal(interface_list.key, "name")

    var mtu_idx = _find_leaf_index_in_list("interface", "mtu", path)
    assert_true(mtu_idx >= 0)
    var ib0 = decompose_yang_list_children(interface_list.children)
    assert_equal(ib0.leaves[mtu_idx][].type.name, "uint16")
    assert_true(ib0.leaves[mtu_idx][].type.has_range())
    assert_equal(ib0.leaves[mtu_idx][].type.range_min(), 576)
    assert_equal(ib0.leaves[mtu_idx][].type.range_max(), 9216)

    var descr_idx = _find_leaf_index_in_list("interface", "description", path)
    var hold_time_idx = _find_leaf_index_in_list("interface", "hold-time", path)
    assert_true(descr_idx >= 0)
    assert_true(hold_time_idx >= 0)
    assert_equal(ib0.leaves[descr_idx][].type.name, "string")
    assert_equal(ib0.leaves[hold_time_idx][].type.name, "uint16")
    assert_true(ib0.leaves[hold_time_idx][].type.has_range())
    assert_equal(ib0.leaves[hold_time_idx][].type.range_min(), 0)
    assert_equal(ib0.leaves[hold_time_idx][].type.range_max(), 300)


def test_parse_mixed_single_double_quoted_string() raises:
    var module = parse_yang_string(
        """
module quote-test {
  namespace "urn:example:quote-test";
  prefix qt;

  container system {
    leaf mixed {
      type string;
      default '"' + "'";
    }
  }
}
""",
    )

    ref system = module.top_level_containers[0][]
    ref mixed = system.leaves[0][]
    assert_true(mixed.has_default)
    assert_equal(mixed.default_value, "\"'")


def test_parse_utf8_description_text() raises:
    var module = parse_yang_string(
        """
module utf8-text {
  namespace "urn:example:utf8-text";
  prefix ut;
  description "Unicode punctuation — and ± should parse.";
}
""",
    )
    assert_equal(
        module.get_description(),
        "Unicode punctuation — and ± should parse.",
    )


def test_parse_forward_grouping_uses_resolution() raises:
    var module = parse_yang_string(
        """
module forward-grouping {
  namespace "urn:example:forward-grouping";
  prefix fg;

  grouping field-a {
    uses field-b;
    leaf a {
      type string;
    }
  }

  grouping field-b {
    leaf b {
      type string;
    }
  }

  container root {
    uses field-a;
  }
}
""",
    )

    ref root = module.top_level_containers[0][]
    var saw_a = False
    var saw_b = False
    for i in range(len(root.leaves)):
        if root.leaves[i][].name == "a":
            saw_a = True
        if root.leaves[i][].name == "b":
            saw_b = True
    assert_true(saw_a)
    assert_true(saw_b)


def test_refine_leaf_description_in_uses() raises:
    var module = parse_yang_string(
        """
module refine-leaf-description {
  namespace "urn:example:refine-leaf-description";
  prefix rd;

  grouping entity-reference {
    leaf entity {
      type string;
      mandatory true;
    }
  }

  container root {
    uses entity-reference {
      refine entity {
        mandatory false;
      }
    }
  }
}
""",
    )

    ref root = module.top_level_containers[0][]
    assert_equal(root.leaves[0][].name, "entity")
    assert_true(not root.leaves[0][].mandatory)


def test_parse_single_quoted_regex_with_backslashes() raises:
    var module = parse_yang_string(
        """
module regex-escapes {
  namespace "urn:example:regex-escapes";
  prefix re;

  typedef date {
    type string {
      pattern '\\d{4}-\\d{2}-\\d{2}';
    }
  }

  container root {
    leaf value {
      type date;
    }
  }
}
""",
    )
    assert_equal(module.name, "regex-escapes")
    assert_true(len(module.top_level_containers) == 1)
    assert_equal(module.top_level_containers[0][].name, "root")
    assert_true(len(module.typedefs) == 1)


def test_parse_tree_statements_capture_uses_refine_augment() raises:
    var module = parse_yang_string(
        """
module parse-tree-stmts {
  namespace "urn:example:parse-tree-stmts";
  prefix pts;

  grouping g {
    leaf a { type string; }
  }

  typedef local-string {
    type string {
      length "1..16";
      pattern '[a-z]+';
    }
  }

  container root {
    uses g {
      refine a {
        mandatory true;
      }
    }
    leaf enabled { type boolean; }
  }

  augment /root {
    leaf extra {
      type string;
    }
  }
}
""",
    )
    var saw_typedef = False
    var saw_uses = False
    var saw_refine = False
    var saw_augment = False
    for i in range(len(module.statements)):
        var stmt = module.statements[i]
        if stmt.isa[ArcPointer[YangTypedefStmt]]():
            saw_typedef = True
        elif stmt.isa[ArcPointer[YangUsesStmt]]():
            saw_uses = True
        elif stmt.isa[ArcPointer[YangRefineStmt]]():
            saw_refine = True
        elif stmt.isa[ArcPointer[YangAugmentStmt]]():
            saw_augment = True
    assert_true(saw_typedef)
    assert_true(saw_uses)
    assert_true(saw_refine)
    assert_true(saw_augment)


def test_rfc7950_string_type_length_and_pattern() raises:
    ## RFC 7950 Sec. 9.4 / 9.4.4 / 9.4.5: the built-in `string` type allows `length` and
    ## `pattern` in its substatements. Forms covered here:
    ##   - `length` as a single positive integer (exact length)
    ##   - `length` as a closed range (low..high)
    ##   - `length` with the `min` and `max` length keywords (unbounded on one side)
    ##   - `pattern` alone and together with `length`
    ## Multiple `pattern` / `modifier invert-match` are covered in
    ## `test_parse_string_pattern_modifier_and_multi_pattern`.
    var m = parse_yang_string(
        """
module rfc7950-string-constraints {
  yang-version 1.1;
  namespace "urn:example:rfc7950-string-constraints";
  prefix r7;

  typedef exact-len-5 {
    type string { length "5"; }
  }
  typedef range-closed {
    type string { length "10..20"; }
  }
  typedef range-to-max {
    type string { length "3..max"; }
  }
  typedef range-from-min {
    type string { length "min..64"; }
  }
  typedef range-open-both-ends { type string { length "0..max"; } }
  typedef pattern-and-length {
    type string {
      length "1..32";
      pattern "[a-zA-Z0-9_-]+";
    }
  }
  typedef pattern-only { type string { pattern "[0-9]+"; } }
}
""",
    )

    # --- length: exact (single value in YANG) ---
    var t0 = _typedef_type_by_name(m, "exact-len-5")
    assert_equal(t0.name, "string")
    assert_true(t0.has_string_length_min())
    assert_true(t0.has_string_length_max())
    assert_equal(t0.string_length_min(), 5)
    assert_equal(t0.string_length_max(), 5)
    assert_true(not t0.has_string_pattern())

    # --- length: two-sided closed range ---
    var t1 = _typedef_type_by_name(m, "range-closed")
    assert_equal(t1.string_length_min(), 10)
    assert_equal(t1.string_length_max(), 20)

    # --- length: lower bound only (upper unbounded) ---
    var t2 = _typedef_type_by_name(m, "range-to-max")
    assert_equal(t2.string_length_min(), 3)
    assert_true(t2.has_string_length_min())
    assert_true(not t2.has_string_length_max())
    assert_equal(t2.string_length_max(), -1)

    # --- length: upper bound only (lower unbounded) ---
    var t3 = _typedef_type_by_name(m, "range-from-min")
    assert_true(not t3.has_string_length_min())
    assert_equal(t3.string_length_min(), -1)
    assert_true(t3.has_string_length_max())
    assert_equal(t3.string_length_max(), 64)

    # --- length: 0 to max (RFC allows 0) ---
    var t4 = _typedef_type_by_name(m, "range-open-both-ends")
    assert_equal(t4.string_length_min(), 0)
    assert_true(t4.has_string_length_min())
    assert_true(not t4.has_string_length_max())

    # --- pattern + length (same type body) ---
    var t5 = _typedef_type_by_name(m, "pattern-and-length")
    assert_equal(t5.string_length_min(), 1)
    assert_equal(t5.string_length_max(), 32)
    assert_true(t5.has_string_pattern())
    assert_equal(t5.string_pattern(), "[a-zA-Z0-9_-]+")

    # --- pattern only ---
    var t6 = _typedef_type_by_name(m, "pattern-only")
    assert_true(t6.has_string_pattern())
    assert_equal(t6.string_pattern(), "[0-9]+")
    assert_true(not t6.has_string_length_min())
    assert_true(not t6.has_string_length_max())


def test_parse_string_pattern_modifier_and_multi_pattern() raises:
    ## RFC 7950 Sec. 9.4.5: `pattern` substatement block may contain `modifier invert-match`.
    ## Multiple `pattern` statements are ANDed in YANG.
    var m = parse_yang_string(
        """
module string-pattern-mod {
  yang-version 1.1;
  namespace "urn:example:string-pattern-mod";
  prefix spm;

  typedef inverted {
    type string {
      pattern 'abc' {
        modifier invert-match;
      }
    }
  }
  typedef dual {
    type string {
      pattern '[a-z]+';
      pattern '[0-9]{3}' {
          modifier invert-match;
        }
    }
  }
  typedef plain-brace {
    type string {
      pattern '[x]+' { }
    }
  }
}
""",
    )
    var ti = _typedef_type_by_name(m, "inverted")
    assert_equal(ti.string_patterns_len(), 1)
    assert_true(ti.string_pattern_invert_at(0))
    assert_equal(ti.string_pattern_regex_at(0), "abc")

    var td = _typedef_type_by_name(m, "dual")
    assert_equal(td.string_patterns_len(), 2)
    assert_true(not td.string_pattern_invert_at(0))
    assert_equal(td.string_pattern_regex_at(0), "[a-z]+")
    assert_true(td.string_pattern_invert_at(1))
    assert_equal(td.string_pattern_regex_at(1), "[0-9]{3}")

    var tp = _typedef_type_by_name(m, "plain-brace")
    assert_equal(tp.string_patterns_len(), 1)
    assert_true(not tp.string_pattern_invert_at(0))
    assert_equal(tp.string_pattern_regex_at(0), "[x]+")


def test_parse_leaf_description_after_typedef_ref_type() raises:
    ## Regression: `type <typedef-name>;` leaves `;` unconsumed (built-in types consume it in
    ## their parsers). A bare `;` must not use `_skip_statement()` or the next `description`
    ## keyword is swallowed and the leaf description stays empty.
    var m_typedef = parse_yang_string(
        """
module typedef-desc-after-type {
  namespace "urn:example:tdat"; prefix tda;
  typedef my-custom-type { type string; description "td"; }
  container c {
    leaf x { type my-custom-type; description "leaf desc"; }
  }
}
""",
    )
    ref c_typedef = m_typedef.top_level_containers[0][]
    assert_equal(c_typedef.leaves[0][].description, "leaf desc")
    assert_equal(c_typedef.leaves[0][].type.name, "my-custom-type")

    var m_builtin = parse_yang_string(
        """
module builtin-desc-after-type {
  namespace "urn:example:bdat"; prefix bda;
  container c {
    leaf x { type string; description "leaf desc"; }
  }
}
""",
    )
    ref c_builtin = m_builtin.top_level_containers[0][]
    assert_equal(c_builtin.leaves[0][].description, "leaf desc")


def test_parse_must_on_container_and_list() raises:
    var module = parse_yang_string(
        """
module must-on-structural-nodes {
  namespace "urn:example:must-on-structural-nodes";
  prefix msn;

  container root {
    must "string-length(name) > 0";
    leaf name {
      type string;
    }
    list item {
      key "id";
      must "string-length(id) > 0";
      leaf id {
        type string;
      }
    }
  }
}
""",
    )
    ref root = module.top_level_containers[0][]
    assert_equal(len(root.must.must_statements), 1)
    assert_equal(root.must.must_statements[0][].expression, "string-length(name) > 0")
    assert_equal(len(root.lists), 1)
    ref item = root.lists[0][]
    assert_equal(len(item.must.must_statements), 1)
    assert_equal(item.must.must_statements[0][].expression, "string-length(id) > 0")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
