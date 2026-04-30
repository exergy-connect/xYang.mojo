## Identifier and simple literal checks for YANG text arguments.

comptime `0b` = _to_byte["0"]()
comptime `9b` = _to_byte["9"]()
comptime `-` = _to_byte["-"]()


@always_inline
def _to_byte[s: StaticString]() -> Byte:
    comptime assert s.byte_length() == 1, "expected one character string"
    comptime byte = s.as_bytes()[0]
    return byte


def is_digit(ch: Byte) -> Bool:
    return ch >= `0b` and ch <= `9b`


def is_alpha(ch: Byte) -> Bool:
    return (ch >= _to_byte["a"]() and ch <= _to_byte["z"]()) or (
        ch >= _to_byte["A"]() and ch <= _to_byte["Z"]()
    )


def is_identifier_char(ch: Byte) -> Bool:
    return is_alpha(ch) or is_digit(ch) or ch == `-` or ch == _to_byte["_"]()


def is_identifier(text: StringSlice) -> Bool:
    var bytes = text.as_bytes()
    if len(bytes) == 0:
        return False
    if not is_alpha(bytes[0]) and bytes[0] != _to_byte["_"]():
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
