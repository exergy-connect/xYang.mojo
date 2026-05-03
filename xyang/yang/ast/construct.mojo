## Recursive YANG construct tree.
##

from std.memory import ArcPointer

from xyang.yang.path import YangPath
from xyang.yang.arguments import (
    BoolArgument,
    FractionDigitsArgument,
    IdentifierArgument,
    LengthArgument,
    ModifierArgument,
    NoArgument,
    PathArgument,
    PatternArgument,
    QNameArgument,
    RangeArgument,
    RevisionDateArgument,
    StringArgument,
    TypeNameArgument,
    XPathExpressionArgument,
    YangArgumentHost,
    YangArgumentValue,
)
from xyang.yang.keyword import Keyword, `<INVALID>`

comptime Arc = ArcPointer


@fieldwise_init
struct YangConstruct(
    ImplicitlyDestructible, Movable, Writable, YangArgumentHost
):
    comptime StatementList = List[Arc[YangConstruct]]

    var keyword: String
    var argument: YangArgumentValue
    var children: Self.StatementList
    var line: UInt
    # Keyword id of the YangConstructSpec that validated this node.
    var spec: Keyword

    def __init__(out self, keyword: String, line: UInt = 0):
        self.keyword = keyword
        self.argument = YangArgumentValue()
        self.children = Self.StatementList()
        self.line = line
        self.spec = `<INVALID>`

    def has_argument(read self) -> Bool:
        ## Raw lexer text uses `NoArgument` payload with non-empty `argument.text`;
        ## validated nodes use a typed payload (and usually non-empty text).
        return (
            self.argument.text.byte_length() > 0
            or not self.argument.isa[NoArgument]()
        )

    def argument_text(read self) -> String:
        return self.argument.text.copy()

    def argument_keyword(read self) -> String:
        return self.keyword.copy()

    def argument_line(read self) -> UInt:
        return self.line

    def set_argument(mut self, var argument: YangArgumentValue):
        self.argument = argument^

    def set_raw_argument(mut self, var text: String):
        self.set_argument(YangArgumentValue(text^))

    def __str__(ref self) -> String:
        return self.format(0)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.format(0))

    def format(ref self, indent: Int) -> String:
        var result = String()
        for _ in range(indent):
            result += "  "
        result += self.keyword
        if self.has_argument():
            result += " "
            result += repr(self.argument_text())
        if len(self.children) == 0:
            result += ";\n"
            return result

        result += " {\n"
        for child in self.children:
            result += child[].format(indent + 1)
        for _ in range(indent):
            result += "  "
        result += "}\n"
        return result
