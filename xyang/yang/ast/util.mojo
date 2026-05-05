# ----------------------------------------------------------------------
# ASCII bitset (0..127)
# ----------------------------------------------------------------------

from std.sys.info import size_of
from std.math import ceildiv, max
from std.sys import simd_width_of, bit_width_of
from std.collections.bitset import _check_index_bounds, _word_index, _bit_mask

from std.algorithm import vectorize

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
struct BitSet[size: Int](Copyable, ImplicitlyCopyable, Defaultable):
    """
    Modeled after https://docs.modular.com/mojo/std/collections/bitset/BitSet/.
    """
    comptime WordType = Int64
    comptime _WORD_BITS = Int(size_of[Self.WordType]() * 8)

    comptime _words_size = max(1, ceildiv(Self.size, Self._WORD_BITS))
    var _words: InlineArray[Self.WordType, Self._words_size]  # Payload storage.

    def __init__(out self):
        self._words = type_of(self._words)(fill=0)


    @staticmethod
    @always_inline
    def charset[*chars: Byte]() -> Self:
    # def __init__[*chars: Byte](out self):
       var result = Self()
       comptime for ch in range(len(chars)):
          result.set(Int(chars[ch]))
       return result^

    @staticmethod
    @always_inline
    def range[start: Byte, end: Byte]() -> Self:
    # def __init__[start: Byte, end: Byte](out self):
        """Initializes a bitset with the range of bytes from `start` to `end`, inclusive.

        Parameters:
            start: The starting byte of the range.
            end: The ending byte of the range.
        """
        var result = Self()
        comptime for ch in range(start, end+1):
            result.set(Int(ch))
        return result^

    @always_inline
    def set(mut self, idx: Int):
        """Sets the bit at the specified index `idx` to 1.

        Args:
            idx: The non-negative index of the bit to set (must be < `size`).
        """
        _check_index_bounds["set"](idx, Self.size)
        var w = _word_index(idx)
        self._words.unsafe_get(w) |= Int64(_bit_mask(idx))


    @always_inline
    @staticmethod
    def _vectorize_apply[
        func: def[simd_width: Int](
            SIMD[DType.int64, simd_width],
            SIMD[DType.int64, simd_width],
        ) capturing -> SIMD[DType.int64, simd_width],
    ](left: Self, right: Self) -> Self:
        """Applies a vectorized binary operation between two bitsets.

        This internal utility function optimizes set operations by processing
        multiple words in parallel using SIMD instructions when possible. It
        applies the provided function to corresponding words from both bitsets
        and returns a new bitset with the results.

        The vectorized operation is applied to each word in the bitsets but only
        if the number of words in the bitsets is greater than or equal to the
        SIMD width.

        Parameters:
            func: A function that takes two SIMD vectors of UInt64 values and
                returns a SIMD vector with the result of the operation. The
                function should implement the desired set operation (e.g.,
                union, intersection).

        Args:
            left: The first bitset operand.
            right: The second bitset operand.

        Returns:
            A new bitset containing the result of applying the function to each
            corresponding pair of words from the input bitsets.
        """
        comptime simd_width = simd_width_of[Self.WordType]()
        var res = Self()

        # Define a vectorized operation that processes multiple words at once
        @always_inline
        def _intersect[
            simd_width: Int
        ](offset: Int) {mut res, read left, read right}:
            # Initialize SIMD vectors to hold multiple words from each bitset
            var left_vec = SIMD[DType.int64, simd_width]()
            var right_vec = SIMD[DType.int64, simd_width]()

            # Load a batch of words from both bitsets into SIMD vectors
            comptime for i in range(simd_width):
                left_vec[i] = left._words.unsafe_get(offset + i)
                right_vec[i] = right._words.unsafe_get(offset + i)

            # Apply the provided operation (union, intersection, etc.) to the
            # vectors
            var result_vec = func(left_vec, right_vec)

            # Store the results back into the result bitset
            comptime for i in range(simd_width):
                res._words.unsafe_get(offset + i) = result_vec[i]

        # Choose between vectorized or scalar implementation based on word count
        comptime if Self._words_size >= simd_width:
            # If we have enough words, use SIMD vectorization for better
            # performance
            vectorize[simd_width](Self._words_size, _intersect)
        else:
            # For small bitsets, use a simple scalar implementation
            comptime for i in range(Self._words_size):
                res._words.unsafe_get(i) = func(
                    left._words.unsafe_get(i),
                    right._words.unsafe_get(i),
                )

        return res^

    @always_inline
    def __or__(self, other: Self) -> Self:
        @parameter
        @always_inline
        def _union[
            simd_width: Int
        ](
            left: SIMD[DType.int64, simd_width],
            right: SIMD[DType.int64, simd_width],
        ) -> SIMD[DType.int64, simd_width]:
            return left | right

        return Self._vectorize_apply[_union](self, other)


    @always_inline
    def __contains__[T: Intable](self, idx: T) -> Bool:
        _check_index_bounds["__contains__"](Int(idx), Self.size)
        var w = _word_index(Int(idx))
        return (self._words.unsafe_get(w) & Int64(_bit_mask(Int(idx)))) != 0

comptime ASCIISet[*chars: Byte] = BitSet[size=128].charset[*chars]
comptime ASCIIRange[start: Byte, end: Byte] = BitSet[size=128].range[start, end]


## Collapse ASCII spaces inside composite argument fragments (`length`, `range`,
## JSON-derived XPath, pattern normalization). Single-token lexer arguments should
## not need this.
def _strip_spaces(read s: String) -> String:
    var parts = s.split(" ")
    var out = String()
    for i in range(len(parts)):
        var p = String(parts[i])
        if p.byte_length() > 0:
            out += p
    return out^
