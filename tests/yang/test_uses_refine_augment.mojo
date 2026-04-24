from std.testing import assert_equal, assert_true, TestSuite
from xyang.yang import parse_yang_string


def test_parse_uses_refine_if_feature_and_augment() raises:
    var yang = """
module refine-augment-test {
  namespace "urn:example:refine-augment-test";
  prefix rat;

  grouping g {
    leaf a {
      type string;
    }
    container c {
      leaf d {
        type string;
      }
    }
  }

  container root {
    uses g {
      if-feature "feature-a";
      refine a {
        mandatory true;
        default "x";
      }
      refine c {
        description "refined-container";
      }
      augment c {
        leaf e {
          type string;
        }
      }
    }
  }

  container root2 {
    uses g;
  }

  augment "/root" {
    leaf top-added {
      type string;
    }
  }

  augment "/root2/c" {
    leaf f {
      type string;
    }
  }
}
"""

    var module = parse_yang_string(yang)
    assert_equal(module.name, "refine-augment-test")
    assert_true(len(module.top_level_containers) == 2)

    ref root = module.top_level_containers[0][]
    ref root2 = module.top_level_containers[1][]
    assert_equal(root.name, "root")
    assert_equal(root2.name, "root2")

    assert_true(len(root.leaves) == 2)
    assert_equal(root.leaves[0][].name, "a")
    assert_true(root.leaves[0][].mandatory)
    assert_true(root.leaves[0][].has_default)
    assert_equal(root.leaves[0][].default_value, "x")
    assert_equal(root.leaves[1][].name, "top-added")

    assert_true(len(root.containers) == 1)
    ref root_c = root.containers[0][]
    assert_equal(root_c.name, "c")
    assert_equal(root_c.description, "refined-container")
    assert_true(len(root_c.leaves) == 2)
    assert_equal(root_c.leaves[0][].name, "d")
    assert_equal(root_c.leaves[1][].name, "e")

    # Verify refined values are isolated to this uses-site (deep clone behavior).
    assert_true(len(root2.leaves) == 1)
    assert_equal(root2.leaves[0][].name, "a")
    assert_true(not root2.leaves[0][].mandatory)
    assert_true(not root2.leaves[0][].has_default)

    assert_true(len(root2.containers) == 1)
    ref root2_c = root2.containers[0][]
    assert_equal(root2_c.name, "c")
    assert_true(len(root2_c.leaves) == 2)
    assert_equal(root2_c.leaves[0][].name, "d")
    assert_equal(root2_c.leaves[1][].name, "f")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
