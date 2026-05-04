## Integration: `XPathExpressionArgument.validate` + `YangConstruct.argument_text` / AST root.

from std.testing import assert_equal, assert_true, TestSuite

from xyang.yang.arguments import XPathExpressionArgument
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.xpath.pratt_parser import XPathExpr


def test_xpath_expression_argument_validate_stores_text_and_ast() raises:
    var node = YangConstruct("when", line=12)
    node.set_raw_argument(String("1 + 2"))
    XPathExpressionArgument.validate(node)
    assert_equal(node.argument_text(), String("1 + 2"))
    assert_true(node.argument.isa[XPathExpressionArgument]())
    ref x = node.argument.get[XPathExpressionArgument]()
    assert_equal(x.root[].kind(), XPathExpr.BINARY)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
