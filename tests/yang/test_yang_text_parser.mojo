from std.testing import assert_equal, assert_true, TestSuite
from xyang.yang.tokens import YANG_TYPE_LEAFREF
from xyang.yang import parse_yang_file


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
            for j in range(len(lst.leaves)):
                if lst.leaves[j][].name == leaf_name:
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
    assert_true(system.leaves[mgmt_if_idx][].type.has_leafref_path)
    assert_equal(system.leaves[mgmt_if_idx][].type.leafref_path, "/system/interface/name")
    assert_equal(system.leaves[mgmt_if_index_idx][].type.name, YANG_TYPE_LEAFREF)
    assert_true(system.leaves[mgmt_if_index_idx][].type.has_leafref_path)
    assert_equal(system.leaves[mgmt_if_index_idx][].type.leafref_path, "/system/interface/if-index")

    assert_true(len(system.lists) == 1)
    ref interface_list = system.lists[0][]
    assert_equal(interface_list.name, "interface")
    assert_equal(interface_list.key, "name")

    var mtu_idx = _find_leaf_index_in_list("interface", "mtu", path)
    assert_true(mtu_idx >= 0)
    assert_equal(interface_list.leaves[mtu_idx][].type.name, "uint16")
    assert_true(interface_list.leaves[mtu_idx][].type.has_range)
    assert_equal(interface_list.leaves[mtu_idx][].type.range_min, 576)
    assert_equal(interface_list.leaves[mtu_idx][].type.range_max, 9216)

    var descr_idx = _find_leaf_index_in_list("interface", "description", path)
    var hold_time_idx = _find_leaf_index_in_list("interface", "hold-time", path)
    assert_true(descr_idx >= 0)
    assert_true(hold_time_idx >= 0)
    assert_equal(interface_list.leaves[descr_idx][].type.name, "string")
    assert_equal(interface_list.leaves[hold_time_idx][].type.name, "uint16")
    assert_true(interface_list.leaves[hold_time_idx][].type.has_range)
    assert_equal(interface_list.leaves[hold_time_idx][].type.range_min, 0)
    assert_equal(interface_list.leaves[hold_time_idx][].type.range_max, 300)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
