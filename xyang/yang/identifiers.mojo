## Identifier and simple literal checks for YANG text arguments.

import xyang.yang.ast.util as ast_util

comptime `-` = ast_util.to_byte["-"]()
comptime `_` = ast_util.to_byte["_"]()
comptime `.` = ast_util.to_byte["."]()

comptime ALPHA = (
    ast_util.ASCIIRange[ast_util.to_byte["a"](), ast_util.to_byte["z"]()]()
    | ast_util.ASCIIRange[ast_util.to_byte["A"](), ast_util.to_byte["Z"]()]()
)

comptime IDENTIFIER_START_CHAR = ALPHA | ast_util.ASCIISet[`_`]()

comptime DIGIT = ast_util.ASCIIRange[
    ast_util.to_byte["0"](),
    ast_util.to_byte["9"](),
]()


@always_inline
def is_digit(ch: Byte) -> Bool:
    return ch in DIGIT


@always_inline
def is_alpha(ch: Byte) -> Bool:
    return ch in ALPHA

@always_inline
def is_identifier_start_char(ch: Byte) -> Bool:
    return ch in IDENTIFIER_START_CHAR


@always_inline
def is_identifier_char(ch: Byte) -> Bool:
    # identifier = (ALPHA / "_") *(ALPHA / DIGIT / "_" / "-" / ".")
    comptime IDENTIFIER_CHAR = (
        ALPHA | DIGIT | ast_util.ASCIISet[`_`, `-`, `.`]()
    )
    return Int(ch) in IDENTIFIER_CHAR

def is_identifier(text: StringSlice) -> Bool:
    var bytes = text.as_bytes()
    if len(bytes) == 0:
        return False
    if not is_identifier_start_char(bytes[0]):
        return False
    for i in range(1, len(bytes)):
        if not is_identifier_char(bytes[i]):
            return False
    return True


def is_qname(text: String) -> Bool:
    var parts = text.split(":")
    if len(parts) == 1:
        return is_identifier(parts[0])
    if len(parts) == 2:
        return is_identifier(parts[0]) and is_identifier(parts[1])
    return False


def is_revision_date(text: String) -> Bool:
    var bytes = text.as_bytes()
    if len(bytes) != 10:
        return False
    for i in range(len(bytes)):
        if i == 4 or i == 7:
            if bytes[i] != `-`:
                return False
        elif not is_digit(bytes[i]):
            return False
    return True
