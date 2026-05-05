## Standalone validation for `__init__` with comptime parameters.

from std.collections.bitset import _check_index_bounds, _word_index, _bit_mask
from std.math import ceildiv, max
from std.sys.info import size_of
from std.testing import assert_equal, assert_true, TestSuite


@always_inline
def to_byte[s: StaticString]() -> Byte:
    comptime assert s.byte_length() == 1, "expected one character string"
    comptime byte = s.as_bytes()[0]
    return byte


struct TrackedBitSet[size: Int](Copyable, ImplicitlyCopyable, Defaultable):
    comptime WordType = Int64
    comptime _WORD_BITS = Int(size_of[Self.WordType]() * 8)
    comptime _words_size = max(1, ceildiv(Self.size, Self._WORD_BITS))

    # Source bits:
    # - bit 0 => built via range-style builder
    # - bit 1 => built via char-list-style builder
    var source_mask: UInt8
    var _words: InlineArray[Self.WordType, Self._words_size]

    def __init__(out self):
        self.source_mask = 0
        self._words = type_of(self._words)(fill=0)

    @always_inline
    def __init__[start: Byte, end: Byte](out self):
        self.source_mask = 1
        self._words = type_of(self._words)(fill=0)
        comptime for ch in range(start, end+1):
            self.set(Int(ch))

    @always_inline
    def set(mut self, idx: Int):
        _check_index_bounds["set"](idx, Self.size)
        var w = _word_index(idx)
        self._words.unsafe_get(w) |= Int64(_bit_mask(idx))

    @always_inline
    def __contains__[T: Intable](self, idx: T) -> Bool:
        _check_index_bounds["__contains__"](Int(idx), Self.size)
        var w = _word_index(Int(idx))
        return (self._words.unsafe_get(w) & Int64(_bit_mask(Int(idx)))) != 0

    @always_inline
    def __or__(self, other: Self) -> Self:
        var out = Self()
        out.source_mask = self.source_mask | other.source_mask
        comptime for i in range(Self._words_size):
            out._words.unsafe_get(i) = (
                self._words.unsafe_get(i) | other._words.unsafe_get(i)
            )
        return out^

    @staticmethod
    @always_inline
    def charset[*chars: Byte]() -> Self:
        var out = Self()
        out.source_mask = 2
        comptime for i in range(len(chars)):
            out.set(Int(chars[i]))
        return out^

comptime `-` = to_byte["-"]()
comptime `_` = to_byte["_"]()
comptime `.` = to_byte["."]()

@always_inline
def from_range[start: Byte, end: Byte]() -> TrackedBitSet[size=128]:
    return TrackedBitSet[size=128].__init__[start, end]()


@always_inline
def from_chars[*chars: Byte]() -> TrackedBitSet[size=128]:
    var out = TrackedBitSet[size=128].charset[*chars]()
    out.source_mask = 2
    return out^

comptime ALPHA = (
    from_range[to_byte["a"](), to_byte["z"]()]()
    | from_range[to_byte["A"](), to_byte["Z"]()]()
)

comptime DIGIT = from_range[to_byte["0"](), to_byte["9"]()]()

comptime IDENTIFIER_CHAR = (
    ALPHA | DIGIT | from_chars[`_`, `-`, `.`]()
)


def test_alpha_uses_range_initializer() raises:
    # ALPHA is built from two range constructors only.
    assert_equal(ALPHA.source_mask, 1)
    assert_true(Int(to_byte["a"]()) in ALPHA)
    assert_true(Int(to_byte["M"]()) in ALPHA)
    assert_true(not (Int(to_byte["0"]()) in ALPHA))


def test_identifier_char_uses_both_initializers() raises:
    # IDENTIFIER_CHAR includes ALPHA/DIGIT ranges + explicit charset symbols.
    assert_equal(IDENTIFIER_CHAR.source_mask, 3)
    assert_true(Int(to_byte["a"]()) in IDENTIFIER_CHAR)
    assert_true(Int(to_byte["7"]()) in IDENTIFIER_CHAR)
    assert_true(Int(`_`) in IDENTIFIER_CHAR)
    assert_true(Int(`-`) in IDENTIFIER_CHAR)
    assert_true(Int(`.`) in IDENTIFIER_CHAR)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
