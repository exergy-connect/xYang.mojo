## Recursive YANG construct tree.
##

from std.memory import ArcPointer

comptime Arc = ArcPointer

@fieldwise_init
struct YangConstruct(ImplicitlyDestructible, Movable, Writable):
    comptime StatementList = List[Arc[YangConstruct]]

    var keyword: String
    var argument: Optional[String]
    var children: Self.StatementList
    var line: Int

    def __init__(out self, keyword: String, line: Int = 0):
        self.keyword = keyword
        self.argument = Optional[String]()
        self.children = Self.StatementList()
        self.line = line

    def __str__(ref self) -> String:
        return self.format(0)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.format(0))

    def format(ref self, indent: Int) -> String:
        var result = String()
        for _ in range(indent):
            result += "  "
        result += self.keyword
        if self.argument:
            result += " "
            result += repr(self.argument.value())
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
