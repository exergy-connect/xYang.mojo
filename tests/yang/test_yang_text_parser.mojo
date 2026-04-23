from std.testing import assert_equal, assert_true, TestSuite
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
    assert_equal(system.leaves[mgmt_if_idx][].type.name, "leafref")
    assert_equal(system.leaves[mgmt_if_index_idx][].type.name, "leafref")

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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
