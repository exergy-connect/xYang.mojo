## Recursive YANG construct tree.
##

from std.memory import ArcPointer

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
    RawArgument,
    RevisionDateArgument,
    StringArgument,
    TypeNameArgument,
    XPathExpressionArgument,
    YangArgument,
)
from xyang.yang.keyword import Keyword, `<INVALID>`

comptime Arc = ArcPointer


@fieldwise_init
struct YangConstruct(ImplicitlyDestructible, Movable, Writable):
    comptime StatementList = List[Arc[YangConstruct]]

    var keyword: String
    var argument: YangArgument
    var children: Self.StatementList
    var line: Int
    # Keyword id of the YangConstructSpec that validated this node.
    var spec: Keyword

    def __init__(out self, keyword: String, line: Int = 0):
        self.keyword = keyword
        self.argument = YangArgument(NoArgument())
        self.children = Self.StatementList()
        self.line = line
        self.spec = `<INVALID>`

    def has_argument(read self) -> Bool:
        return not self.argument.isa[NoArgument]()

    def argument_text(read self) -> String:
        if self.argument.isa[RawArgument]():
            return self.argument[RawArgument].text.copy()
        if self.argument.isa[StringArgument]():
            return self.argument[StringArgument].text.copy()
        if self.argument.isa[IdentifierArgument]():
            return self.argument[IdentifierArgument].text.copy()
        if self.argument.isa[QNameArgument]():
            return self.argument[QNameArgument].text.copy()
        if self.argument.isa[PathArgument]():
            return self.argument[PathArgument].text.copy()
        if self.argument.isa[XPathExpressionArgument]():
            return self.argument[XPathExpressionArgument].text.copy()
        if self.argument.isa[RevisionDateArgument]():
            return self.argument[RevisionDateArgument].text.copy()
        if self.argument.isa[RangeArgument]():
            return self.argument[RangeArgument].text.copy()
        if self.argument.isa[LengthArgument]():
            return self.argument[LengthArgument].text.copy()
        if self.argument.isa[PatternArgument]():
            return self.argument[PatternArgument].text.copy()
        if self.argument.isa[ModifierArgument]():
            return self.argument[ModifierArgument].text.copy()
        if self.argument.isa[FractionDigitsArgument]():
            return String(self.argument[FractionDigitsArgument].value)
        if self.argument.isa[TypeNameArgument]():
            return self.argument[TypeNameArgument].text.copy()
        if self.argument.isa[BoolArgument]():
            return "true" if self.argument[BoolArgument].value else "false"
        return ""

    def set_raw_argument(mut self, var text: String):
        self.argument = YangArgument(RawArgument(text^))

    def set_string_argument(mut self, var text: String):
        self.argument = YangArgument(StringArgument(text^))

    def set_identifier_argument(mut self, var text: String):
        self.argument = YangArgument(IdentifierArgument(text^))

    def set_qname_argument(mut self, var text: String):
        var parts = text.split(":")
        if len(parts) == 2:
            self.argument = YangArgument(
                QNameArgument(
                    text^,
                    Optional[String](String(parts[0])),
                    String(parts[1]),
                )
            )
        else:
            self.argument = YangArgument(
                QNameArgument(text^, Optional[String](), String(parts[0]))
            )

    def set_path_argument(mut self, var text: String):
        self.argument = YangArgument(PathArgument(text^))

    def set_xpath_expression_argument(mut self, var text: String):
        self.argument = YangArgument(XPathExpressionArgument(text^))

    def set_revision_date_argument(mut self, var text: String):
        self.argument = YangArgument(RevisionDateArgument(text^))

    def set_range_argument(mut self, var text: String):
        self.argument = YangArgument(RangeArgument(text^))

    def set_length_argument(mut self, var text: String):
        self.argument = YangArgument(LengthArgument(text^))

    def set_pattern_argument(mut self, var text: String):
        self.argument = YangArgument(PatternArgument(text^))

    def set_modifier_argument(mut self, var text: String):
        self.argument = YangArgument(ModifierArgument(text^))

    def set_fraction_digits_argument(mut self, value: Int):
        self.argument = YangArgument(FractionDigitsArgument(value))

    def set_type_name_argument(mut self, var text: String):
        self.argument = YangArgument(TypeNameArgument(text^))

    def set_bool_argument(mut self, value: Bool):
        self.argument = YangArgument(BoolArgument(value))

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
