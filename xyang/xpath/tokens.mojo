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