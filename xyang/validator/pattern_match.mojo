## Subset XSD-style matching for YANG `pattern` (RFC 7950 §9.4.5).
##
## Matches the **entire** string (XSD `xs:pattern` semantics). Supports `.`,
## `[` character classes `]` (with `^` negation and `a-z` ranges), `*`, `+`,
## `?`, `\` escapes for the next byte, and concatenation. Leading `^` and
## trailing `$` are stripped when present.
##
## Pattern bytes: callers pass a single ``String.as_bytes()`` view for the
## (already anchor-stripped) pattern; helpers index that span only.

from std.memory import Span

from xyang.yang.arguments import _strip_spaces


comptime PatBytes = Span[Byte, _]


@always_inline
def _pat_byte(read b: PatBytes, i: Int) -> Int:
    return Int(b[i])


def _strip_pattern_anchors(read pat: String) -> String:
    ## Strip at most one leading ``^`` and one trailing ``$`` using one UTF-8 scan.
    var b = pat.as_bytes()
    var n = len(b)
    var lo = 0
    var hi = n
    if n >= 1 and _pat_byte(b, 0) == ord("^"):
        lo = 1
    if hi > lo and _pat_byte(b, hi - 1) == ord("$"):
        hi -= 1
    if lo == 0 and hi == n:
        return pat.copy()
    return String(StringSlice(unsafe_from_utf8=b[lo:hi]))


def _utf8_decode_scalar(
    read s: String, byte_i: Int
) raises -> Tuple[Int32, Int]:
    var b = s.as_bytes()
    var n = len(b)
    if byte_i >= n:
        raise Error("pattern_match: UTF-8 decode past end")
    var c0 = Int(b[byte_i])
    if c0 < 0x80:
        return (Int32(c0), 1)
    if (c0 & 0xE0) == 0xC0 and byte_i + 1 < n:
        var c1 = Int(b[byte_i + 1])
        if (c1 & 0xC0) != 0x80:
            raise Error("pattern_match: invalid UTF-8 continuation")
        return (Int32((c0 & 0x1F) << 6 | (c1 & 0x3F)), 2)
    if (c0 & 0xF0) == 0xE0 and byte_i + 2 < n:
        var c1 = Int(b[byte_i + 1])
        var c2 = Int(b[byte_i + 2])
        if (c1 & 0xC0) != 0x80 or (c2 & 0xC0) != 0x80:
            raise Error("pattern_match: invalid UTF-8 continuation")
        return (
            Int32((c0 & 0x0F) << 12 | (c1 & 0x3F) << 6 | (c2 & 0x3F)),
            3,
        )
    if (c0 & 0xF8) == 0xF0 and byte_i + 3 < n:
        var c1 = Int(b[byte_i + 1])
        var c2 = Int(b[byte_i + 2])
        var c3 = Int(b[byte_i + 3])
        if (c1 & 0xC0) != 0x80 or (c2 & 0xC0) != 0x80 or (c3 & 0xC0) != 0x80:
            raise Error("pattern_match: invalid UTF-8 continuation")
        return (
            Int32(
                (c0 & 0x07) << 18
                | (c1 & 0x3F) << 12
                | (c2 & 0x3F) << 6
                | (c3 & 0x3F)
            ),
            4,
        )
    raise Error("pattern_match: invalid UTF-8 lead byte")


def _class_end(
    read pb: PatBytes, pat_len: Int, start_bracket: Int
) raises -> Int:
    var i = start_bracket + 1
    if i < pat_len and _pat_byte(pb, i) == ord("]"):
        i += 1
    while i < pat_len:
        if _pat_byte(pb, i) == ord("\\") and i + 1 < pat_len:
            i += 2
            continue
        if _pat_byte(pb, i) == ord("]"):
            return i
        i += 1
    raise Error("pattern_match: unterminated `[` in pattern")


def _scalar_in_class(
    read pb: PatBytes, class_start: Int, class_end: Int, cp: Int32
) -> Bool:
    var i = class_start + 1
    var neg = False
    if i <= class_end and _pat_byte(pb, i) == ord("^"):
        neg = True
        i += 1
    if i <= class_end and _pat_byte(pb, i) == ord("]"):
        i += 1
    var matched = False
    while i < class_end:
        if i + 2 < class_end and _pat_byte(pb, i + 1) == ord("-"):
            var lo = _pat_byte(pb, i)
            var hi = _pat_byte(pb, i + 2)
            if Int32(lo) <= cp and cp <= Int32(hi):
                matched = True
            i += 3
            continue
        if Int32(_pat_byte(pb, i)) == cp:
            matched = True
        i += 1
    return matched if not neg else not matched


def _atom_end_no_quant(read pb: PatBytes, pat_len: Int, pi: Int) raises -> Int:
    var pch = _pat_byte(pb, pi)
    if pch == ord("["):
        return _class_end(pb, pat_len, pi) + 1
    if pch == ord(".") or pch == ord("*") or pch == ord("+") or pch == ord("?"):
        raise Error("pattern_match: misplaced metacharacter")
    if pch == ord("\\") and pi + 1 < pat_len:
        return pi + 2
    return pi + 1


def _parse_brace_exact(
    read pb: PatBytes, pat_len: Int, brace_pi: Int
) raises -> Tuple[Int, Int]:
    ## `{n}` only: returns `(n, index_after_brace)` or `(0, brace_pi)` if invalid.
    if brace_pi >= pat_len or _pat_byte(pb, brace_pi) != ord("{"):
        return (0, brace_pi)
    var i = brace_pi + 1
    var n = 0
    var seen = False
    while i < pat_len:
        var b = _pat_byte(pb, i)
        if b >= ord("0") and b <= ord("9"):
            seen = True
            n = n * 10 + Int(b - ord("0"))
            i += 1
            continue
        if b == ord("}"):
            if not seen or n < 1:
                return (0, brace_pi)
            return (n, i + 1)
        return (0, brace_pi)
    return (0, brace_pi)


def _quant_next_pi(
    read pb: PatBytes, pat_len: Int, atom_end: Int
) raises -> Int:
    if atom_end >= pat_len:
        return atom_end
    var q = _pat_byte(pb, atom_end)
    if q == ord("*") or q == ord("+") or q == ord("?"):
        return atom_end + 1
    if q == ord("{"):
        var br = _parse_brace_exact(pb, pat_len, atom_end)
        if br[0] > 0:
            return br[1]
    return atom_end


def _quant_kind(read pb: PatBytes, pat_len: Int, atom_end: Int) raises -> Int:
    if atom_end >= pat_len:
        return 0
    var q = _pat_byte(pb, atom_end)
    if q == ord("*"):
        return 1
    if q == ord("+"):
        return 2
    if q == ord("?"):
        return 3
    if q == ord("{"):
        var br = _parse_brace_exact(pb, pat_len, atom_end)
        if br[0] > 0:
            return 4
    return 0


def _class_matches(
    read pb: PatBytes, pat_len: Int, class_start: Int, read val: String, vi: Int
) raises -> Bool:
    if vi >= val.byte_length():
        return False
    var dec = _utf8_decode_scalar(val, vi)
    var ce = _class_end(pb, pat_len, class_start)
    return _scalar_in_class(pb, class_start, ce, dec[0])


def _dot_matches(read val: String, vi: Int) -> Bool:
    return vi < val.byte_length()


def _literal_matches(
    read pb: PatBytes, pat_len: Int, pi: Int, read val: String, vi: Int
) raises -> Bool:
    if vi >= val.byte_length():
        return False
    var pch = _pat_byte(pb, pi)
    if pch == ord("\\") and pi + 1 < pat_len:
        var esc = _pat_byte(pb, pi + 1)
        var dec = _utf8_decode_scalar(val, vi)
        var cp = dec[0]
        if esc == ord("d"):
            return cp >= Int32(ord("0")) and cp <= Int32(ord("9"))
        pch = esc
    var dec2 = _utf8_decode_scalar(val, vi)
    return Int32(pch) == dec2[0]


def _literal_advance(read pb: PatBytes, pat_len: Int, pi: Int) -> Int:
    if _pat_byte(pb, pi) == ord("\\") and pi + 1 < pat_len:
        return pi + 2
    return pi + 1


def _match_from(
    read pb: PatBytes, pat_len: Int, pi: Int, read val: String, vi: Int
) raises -> Bool:
    if pi >= pat_len:
        return vi >= val.byte_length()
    var a_end = _atom_end_no_quant(pb, pat_len, pi)
    var next_pi = _quant_next_pi(pb, pat_len, a_end)
    var qk = _quant_kind(pb, pat_len, a_end)

    if _pat_byte(pb, pi) == ord("["):
        if qk == 4:
            var n_times = _parse_brace_exact(pb, pat_len, a_end)[0]
            var j4 = vi
            for _ in range(n_times):
                if j4 >= val.byte_length() or not _class_matches(
                    pb, pat_len, pi, val, j4
                ):
                    return False
                j4 += _utf8_decode_scalar(val, j4)[1]
            return _match_from(pb, pat_len, next_pi, val, j4)
        if qk == 1:
            var j = vi
            while True:
                if _match_from(pb, pat_len, next_pi, val, j):
                    return True
                if j >= val.byte_length():
                    return False
                if not _class_matches(pb, pat_len, pi, val, j):
                    return False
                j += _utf8_decode_scalar(val, j)[1]
        elif qk == 2:
            if vi >= val.byte_length() or not _class_matches(
                pb, pat_len, pi, val, vi
            ):
                return False
            var j2 = vi + _utf8_decode_scalar(val, vi)[1]
            while True:
                if _match_from(pb, pat_len, next_pi, val, j2):
                    return True
                if j2 >= val.byte_length():
                    return False
                if not _class_matches(pb, pat_len, pi, val, j2):
                    return False
                j2 += _utf8_decode_scalar(val, j2)[1]
        elif qk == 3:
            if _class_matches(pb, pat_len, pi, val, vi):
                return _match_from(
                    pb,
                    pat_len,
                    next_pi,
                    val,
                    vi + _utf8_decode_scalar(val, vi)[1],
                )
            return _match_from(pb, pat_len, next_pi, val, vi)
        else:
            if not _class_matches(pb, pat_len, pi, val, vi):
                return False
            return _match_from(
                pb,
                pat_len,
                next_pi,
                val,
                vi + _utf8_decode_scalar(val, vi)[1],
            )

    if _pat_byte(pb, pi) == ord("."):
        if qk == 4:
            var n_dot = _parse_brace_exact(pb, pat_len, a_end)[0]
            var jfd4 = vi
            for _ in range(n_dot):
                if not _dot_matches(val, jfd4):
                    return False
                jfd4 += _utf8_decode_scalar(val, jfd4)[1]
            return _match_from(pb, pat_len, next_pi, val, jfd4)
        if qk == 1:
            var jd = vi
            while True:
                if _match_from(pb, pat_len, next_pi, val, jd):
                    return True
                if jd >= val.byte_length():
                    return False
                jd += _utf8_decode_scalar(val, jd)[1]
        elif qk == 2:
            if not _dot_matches(val, vi):
                return False
            var jdp = vi + _utf8_decode_scalar(val, vi)[1]
            while True:
                if _match_from(pb, pat_len, next_pi, val, jdp):
                    return True
                if jdp >= val.byte_length():
                    return False
                jdp += _utf8_decode_scalar(val, jdp)[1]
        elif qk == 3:
            if _dot_matches(val, vi):
                return _match_from(
                    pb,
                    pat_len,
                    next_pi,
                    val,
                    vi + _utf8_decode_scalar(val, vi)[1],
                )
            return _match_from(pb, pat_len, next_pi, val, vi)
        else:
            if not _dot_matches(val, vi):
                return False
            return _match_from(
                pb,
                pat_len,
                next_pi,
                val,
                vi + _utf8_decode_scalar(val, vi)[1],
            )

    if qk == 4:
        var n_lit = _parse_brace_exact(pb, pat_len, a_end)[0]
        var jn = vi
        for _ in range(n_lit):
            if not _literal_matches(pb, pat_len, pi, val, jn):
                return False
            jn += _utf8_decode_scalar(val, jn)[1]
        return _match_from(pb, pat_len, next_pi, val, jn)

    if not _literal_matches(pb, pat_len, pi, val, vi):
        return False
    var vadv = _utf8_decode_scalar(val, vi)[1]
    if qk == 1:
        var jl = vi
        while True:
            if _match_from(pb, pat_len, next_pi, val, jl):
                return True
            if jl >= val.byte_length():
                return False
            if not _literal_matches(pb, pat_len, pi, val, jl):
                return False
            jl += _utf8_decode_scalar(val, jl)[1]
    elif qk == 2:
        var jlp = vi + vadv
        while True:
            if _match_from(pb, pat_len, next_pi, val, jlp):
                return True
            if jlp >= val.byte_length():
                return False
            if not _literal_matches(pb, pat_len, pi, val, jlp):
                return False
            jlp += _utf8_decode_scalar(val, jlp)[1]
    elif qk == 3:
        if _literal_matches(pb, pat_len, pi, val, vi):
            return _match_from(pb, pat_len, next_pi, val, vi + vadv)
        return _match_from(pb, pat_len, next_pi, val, vi)
    else:
        return _match_from(pb, pat_len, next_pi, val, vi + vadv)


def yang_string_matches_xsd_subset(
    read pattern: String, read value: String
) raises -> Bool:
    var p = _strip_pattern_anchors(_strip_spaces(pattern))
    var pb = p.as_bytes()
    var pn = len(pb)
    if pn == 0:
        return value.byte_length() == 0
    return _match_from(pb, pn, 0, value, 0)


def unicode_scalar_count(read s: String) raises -> Int:
    ## Count of Unicode scalar values (decoded UTF-8 code points), RFC 7950 §9.4.4.
    var i = 0
    var n = 0
    while i < s.byte_length():
        i += _utf8_decode_scalar(s, i)[1]
        n += 1
    return n
