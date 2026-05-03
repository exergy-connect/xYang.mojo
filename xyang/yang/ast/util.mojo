# ----------------------------------------------------------------------
# ASCII bitset (0..127)
# ----------------------------------------------------------------------

from std.sys.intrinsics import unlikely
from std.sys.info import size_of


@always_inline
def to_byte[s: StaticString]() -> Byte:
    comptime assert s.byte_length() == 1, "expected one character string"
    comptime byte = s.as_bytes()[0]
    return byte


@always_inline
def token_table[*tokens: Byte]() -> InlineArray[Bool, 256]:
    var t = InlineArray[Bool, 256](fill=False)
    comptime for i in range(len(tokens)):
        t[tokens[i]] = True
    return t^

@fieldwise_init
struct BitSet(Copyable, ImplicitlyCopyable):
    comptime Type = UInt128 # TODO: Could be generalized to any integer type
    comptime bit_width = UInt8(size_of[Self.Type]() * 8)

    var mask: Self.Type

    @always_inline
    def __init__(out self):
        self.mask = 0

    @always_inline
    def __or__(self, other: Self) -> Self:
        return Self(self.mask | other.mask)

    @always_inline
    @staticmethod
    def chars[*items: Byte]() -> Self:
        var result = Self()
        comptime for i in range(len(items)):
            comptime assert items[i] < Self.bit_width, "BitSet byte out of bit width range"
            result.mask |= Self.Type(1) << UInt128(items[i])
        return result

    @always_inline
    @staticmethod
    def range[start: Byte, end: Byte]() -> Self:
        comptime assert start <= end, "invalid BitSet range"
        comptime assert end < Self.bit_width, "BitSet range out of bit width range"

        var result = Self()
        comptime for b in range(Int(start), Int(end) + 1):
            result.mask |= Self.Type(1) << UInt128(b)
        return result

    @always_inline
    def __contains__(self, ch: Byte) -> Bool:
        if unlikely(ch >= Self.bit_width):
            return False
        return (self.mask & (Self.Type(1) << UInt128(ch))) != 0

comptime ASCIISet[*chars: Byte] = BitSet.chars[*chars]
