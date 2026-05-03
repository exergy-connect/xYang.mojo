## Identifier and simple literal checks for YANG text arguments.

import xyang.yang.ast.util as ast_util

comptime `0b` = ast_util.to_byte["0"]()
comptime `9b` = ast_util.to_byte["9"]()
comptime `-` = ast_util.to_byte["-"]()

comptime a_b = ast_util.to_byte["a"]()
comptime z_b = ast_util.to_byte["z"]()
comptime A_b = ast_util.to_byte["A"]()
comptime Z_b = ast_util.to_byte["Z"]()

comptime ALPHA = (
    ast_util.BitSet.range[a_b, z_b]() | ast_util.BitSet.range[A_b, Z_b]()
)


def is_digit(ch: Byte) -> Bool:
    return ch >= `0b` and ch <= `9b`


@always_inline
def is_alpha(ch: Byte) -> Bool:
    return ch in ALPHA


def is_identifier_char(ch: Byte) -> Bool:
    return (
        is_alpha(ch)
        or is_digit(ch)
        or ch == `-`
        or ch == ast_util.to_byte["_"]()
    )


def is_identifier(text: StringSlice) -> Bool:
    var bytes = text.as_bytes()
    if len(bytes) == 0:
        return False
    if not is_alpha(bytes[0]) and bytes[0] != ast_util.to_byte["_"]():
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


def is_supported_type_name(text: String) -> Bool:
    return (
        text == "string"
        or text == "boolean"
        or text == "uint16"
        or text == "leafref"
        or is_qname(text)
    )
