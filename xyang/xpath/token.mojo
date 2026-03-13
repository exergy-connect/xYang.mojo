## Span-based XPath token: references the source expression by position instead of owning lexeme text.
## Tokens are lightweight (type, start, length, line); use .text(source) to get the lexeme string
## from the original expression. The tokenizer/parser hold the expression; tokens do not contain it.

@fieldwise_init
struct Token(Copyable):

    comptime Type = UInt8

    comptime IDENTIFIER: Self.Type    = 0
    comptime NUMBER: Self.Type        = 1
    comptime STRING: Self.Type        = 2
    comptime OPERATOR: Self.Type      = 3
    comptime PAREN_OPEN: Self.Type    = 4
    comptime PAREN_CLOSE: Self.Type   = 5
    comptime BRACKET_OPEN: Self.Type  = 6
    comptime BRACKET_CLOSE: Self.Type = 7
    comptime DOT: Self.Type           = 8
    comptime DOTDOT: Self.Type        = 9
    comptime SLASH: Self.Type         = 10
    comptime COMMA: Self.Type         = 11
    comptime EOF: Self.Type           = 12

    var type: Self.Type
    var start: Int
    var length: Int
    var line: Int

    ## Return the lexeme string for this token from the original expression (span [start, start+length)).
    ## If strip_quotes is True and this is a STRING token, returns the inner value (without surrounding quotes).
    def text(self, source: String, strip_quotes: Bool = False) -> String:
        if strip_quotes and self.type == Self.STRING:
            return String(source[self.start + 1:self.start + self.length - 1])
        return String(source[self.start:self.start + self.length])

    ## Return the type name string for the given type constant (e.g. "IDENTIFIER", "EOF").
    @staticmethod
    def type_name(type_value: Self.Type) -> String:
        if type_value == Self.IDENTIFIER:
            return "IDENTIFIER"
        if type_value == Self.NUMBER:
            return "NUMBER"
        if type_value == Self.STRING:
            return "STRING"
        if type_value == Self.OPERATOR:
            return "OPERATOR"
        if type_value == Self.PAREN_OPEN:
            return "PAREN_OPEN"
        if type_value == Self.PAREN_CLOSE:
            return "PAREN_CLOSE"
        if type_value == Self.BRACKET_OPEN:
            return "BRACKET_OPEN"
        if type_value == Self.BRACKET_CLOSE:
            return "BRACKET_CLOSE"
        if type_value == Self.DOT:
            return "DOT"
        if type_value == Self.DOTDOT:
            return "DOTDOT"
        if type_value == Self.SLASH:
            return "SLASH"
        if type_value == Self.COMMA:
            return "COMMA"
        if type_value == Self.EOF:
            return "EOF"
        return "UNKNOWN"
