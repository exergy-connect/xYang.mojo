from std.testing import assert_equal, assert_true, TestSuite
from xyang.xpath.path_parser import parse_path, parse_qname


def test_parse_qname_with_prefix() raises:
    var qn = parse_qname("if:interface")
    assert_true(qn.has_prefix())
    assert_equal(qn.prefix, "if")
    assert_equal(qn.local_name, "interface")
    assert_equal(qn.text(), "if:interface")


def test_parse_qname_without_prefix() raises:
    var qn = parse_qname("interface")
    assert_true(not qn.has_prefix())
    assert_equal(qn.prefix, "")
    assert_equal(qn.local_name, "interface")
    assert_equal(qn.text(), "interface")


def test_parse_relative_path_qname_segments() raises:
    var path = parse_path("if:interfaces/if:interface")
    assert_true(not path.absolute)
    assert_equal(len(path.segments), 2)
    assert_equal(path.segments[0].prefix, "if")
    assert_equal(path.segments[0].local_name, "interfaces")
    assert_equal(path.segments[1].prefix, "if")
    assert_equal(path.segments[1].local_name, "interface")
    assert_equal(path.text(), "if:interfaces/if:interface")


def test_parse_absolute_path_qname_segments() raises:
    var path = parse_path("/if:interfaces/if:interface")
    assert_true(path.absolute)
    assert_equal(len(path.segments), 2)
    assert_equal(path.segments[0].text(), "if:interfaces")
    assert_equal(path.segments[1].text(), "if:interface")
    assert_equal(path.text(), "/if:interfaces/if:interface")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
