## YANG substatement cardinality (RFC-style) and rule helpers.

comptime Cardinality = UInt8
comptime `0`: Cardinality = 0
comptime `1`: Cardinality = 1
comptime `0..1`: Cardinality = 2
comptime `0..n`: Cardinality = 3
comptime `1..n`: Cardinality = 4


def check_cardinality(
    name: String, card: Cardinality, count: Int, line: UInt = 0
) raises:
    if card == `0` and count != 0:
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` must not appear, found "
            + String(count)
        )
    if card == `1` and count != 1:
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` must appear exactly once, found "
            + String(count)
        )
    if card == `0..1` and count > 1:
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` may appear at most once, found "
            + String(count)
        )
    if card == `1..n` and count < 1:
        raise Error(
            ("line " + String(line) + ": " if line > 0 else "")
            + "`"
            + name
            + "` must appear at least once"
        )


@fieldwise_init
struct FieldRule(Copyable, ImplicitlyCopyable, Movable):
    var cardinality: Cardinality
