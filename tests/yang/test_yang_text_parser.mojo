from std.testing import assert_equal, assert_true, TestSuite
from std.memory import ArcPointer
from xyang.yang.parser.yang_token import YANG_TYPE_LEAFREF
from xyang import parse_yang_file, parse_yang_string
from xyang.ast import (
    YangTypedefStmt,
    YangUsesStmt,
    YangRefineStmt,
    YangAugmentStmt,
    decompose_yang_list_children,
)


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
    assert_equal(len(root.must_statements), 1)
    assert_equal(root.must_statements[0][].expression, "string-length(name) > 0")
    assert_equal(len(root.lists), 1)
    ref item = root.lists[0][]
    assert_equal(len(item.must_statements), 1)
    assert_equal(item.must_statements[0][].expression, "string-length(id) > 0")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
