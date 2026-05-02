## Argument validator callbacks for table-driven YANG construct validation.

from xyang.yang.arguments import (
    BoolArgument,
    FractionDigitsArgument,
    IdentifierArgument,
    LengthArgument,
    ModifierArgument,
    PathArgument,
    PatternArgument,
    QNameArgument,
    RangeArgument,
    RevisionDateArgument,
    StringArgument,
    TypeNameArgument,
    XPathExpressionArgument,
    YangArgumentValue,
)
from xyang.yang.ast.construct import YangConstruct


comptime ArgumentValidator = def(mut YangConstruct) raises thin -> None


def validate_yang_any(mut node: YangConstruct) raises -> None:
    return


def validate_yang_string(mut node: YangConstruct) raises -> None:
    StringArgument.validate(node)


def validate_yang_identifier(mut node: YangConstruct) raises -> None:
    IdentifierArgument.validate(node)


def validate_yang_qname(mut node: YangConstruct) raises -> None:
    QNameArgument.validate(node)


def validate_yang_version(mut node: YangConstruct) raises -> None:
    var argument = node.argument_text()
    if argument != "1" and argument != "1.1":
        raise Error(
            ("line " + String(node.line) + ": " if node.line > 0 else "")
            + "`"
            + node.keyword
            + "` expected YANG version 1 or 1.1"
        )
    node.set_argument(YangArgumentValue(StringArgument(argument^)))


def validate_yang_revision_date(mut node: YangConstruct) raises -> None:
    RevisionDateArgument.validate(node)


def validate_yang_range(mut node: YangConstruct) raises -> None:
    RangeArgument.validate(node)


def validate_yang_length(mut node: YangConstruct) raises -> None:
    LengthArgument.validate(node)


def validate_yang_pattern_arg(mut node: YangConstruct) raises -> None:
    PatternArgument.validate(node)


def validate_yang_modifier(mut node: YangConstruct) raises -> None:
    ModifierArgument.validate(node)


def validate_yang_fraction_digits(mut node: YangConstruct) raises -> None:
    FractionDigitsArgument.validate(node)


def validate_yang_path(mut node: YangConstruct) raises -> None:
    PathArgument.validate(node)


def validate_yang_type_name(mut node: YangConstruct) raises -> None:
    TypeNameArgument.validate(node)


def validate_yang_expression(mut node: YangConstruct) raises -> None:
    XPathExpressionArgument.validate(node)


def validate_yang_bool(mut node: YangConstruct) raises -> None:
    BoolArgument.validate(node)
