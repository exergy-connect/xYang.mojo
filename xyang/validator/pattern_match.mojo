## Subset XSD-style matching for YANG `pattern` (RFC 7950 §9.4.5).
##
## Matches the **entire** string (XSD `xs:pattern` semantics). Supports `.`,
## `[` character classes `]` (with `^` negation and `a-z` ranges), `*`, `+`,
## `?`, `\` escapes for the next byte, and concatenation. Leading `^` and
## trailing `$` are stripped when present.

from xyang.yang.arguments import _strip_spaces


def _bytes_at(read s: String, i: Int) -> Int:
    return Int(s.as_bytes()[i])


def _strip_pattern_anchors(read pat: String) -> String:
    var p = pat
    if p.byte_length() >= 1 and _bytes_at(p, 0) == ord("^"):
        p = String(
            StringSlice(unsafe_from_utf8=p.as_bytes()[1 : p.byte_length()])
        )
    if p.byte_length() >= 1 and _bytes_at(p, p.byte_length() - 1) == ord("$"):
        p = String(
            StringSlice(unsafe_from_utf8=p.as_bytes()[0 : p.byte_length() - 1])
        )
    return p^


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


def _class_end(read pat: String, start_bracket: Int) raises -> Int:
    var i = start_bracket + 1
    var n = pat.byte_length()
    if i < n and _bytes_at(pat, i) == ord("]"):
        i += 1
    while i < n:
        if _bytes_at(pat, i) == ord("\\") and i + 1 < n:
            i += 2
            continue
        if _bytes_at(pat, i) == ord("]"):
            return i
        i += 1
    raise Error("pattern_match: unterminated `[` in pattern")


def _scalar_in_class(
    read pat: String, class_start: Int, class_end: Int, cp: Int32
) -> Bool:
    var i = class_start + 1
    var neg = False
    if i <= class_end and _bytes_at(pat, i) == ord("^"):
        neg = True
        i += 1
    if i <= class_end and _bytes_at(pat, i) == ord("]"):
        i += 1
    var matched = False
    while i < class_end:
        if i + 2 < class_end and _bytes_at(pat, i + 1) == ord("-"):
            var lo = _bytes_at(pat, i)
            var hi = _bytes_at(pat, i + 2)
            if Int32(lo) <= cp and cp <= Int32(hi):
                matched = True
            i += 3
            continue
        if Int32(_bytes_at(pat, i)) == cp:
            matched = True
        i += 1
    return matched if not neg else not matched


def _atom_end_no_quant(read pat: String, pi: Int) raises -> Int:
    var pch = _bytes_at(pat, pi)
    if pch == ord("["):
        return _class_end(pat, pi) + 1
    if pch == ord(".") or pch == ord("*") or pch == ord("+") or pch == ord("?"):
        raise Error("pattern_match: misplaced metacharacter")
    if pch == ord("\\") and pi + 1 < pat.byte_length():
        return pi + 2
    return pi + 1


def _quant_next_pi(read pat: String, atom_end: Int) -> Int:
    if atom_end >= pat.byte_length():
        return atom_end
    var q = _bytes_at(pat, atom_end)
    if q == ord("*") or q == ord("+") or q == ord("?"):
        return atom_end + 1
    return atom_end


def _quant_kind(read pat: String, atom_end: Int) -> Int:
    if atom_end >= pat.byte_length():
        return 0
    var q = _bytes_at(pat, atom_end)
    if q == ord("*"):
        return 1
    if q == ord("+"):
        return 2
    if q == ord("?"):
        return 3
    return 0


def _class_matches(
    read pat: String, class_start: Int, read val: String, vi: Int
) raises -> Bool:
    if vi >= val.byte_length():
        return False
    var dec = _utf8_decode_scalar(val, vi)
    var ce = _class_end(pat, class_start)
    return _scalar_in_class(pat, class_start, ce, dec[0])


def _dot_matches(read val: String, vi: Int) -> Bool:
    return vi < val.byte_length()


def _literal_matches(
    read pat: String, pi: Int, read val: String, vi: Int
) raises -> Bool:
    if vi >= val.byte_length():
        return False
    var pch = _bytes_at(pat, pi)
    if pch == ord("\\") and pi + 1 < pat.byte_length():
        pch = _bytes_at(pat, pi + 1)
    var dec = _utf8_decode_scalar(val, vi)
    return Int32(pch) == dec[0]


def _literal_advance(read pat: String, pi: Int) -> Int:
    if _bytes_at(pat, pi) == ord("\\") and pi + 1 < pat.byte_length():
        return pi + 2
    return pi + 1


def _match_from(
    read pat: String, pi: Int, read val: String, vi: Int
) raises -> Bool:
    var pl = pat.byte_length()
    if pi >= pl:
        return vi >= val.byte_length()
    var a_end = _atom_end_no_quant(pat, pi)
    var next_pi = _quant_next_pi(pat, a_end)
    var qk = _quant_kind(pat, a_end)

    if _bytes_at(pat, pi) == ord("["):
        if qk == 1:
            var j = vi
            while True:
                if _match_from(pat, next_pi, val, j):
                    return True
                if j >= val.byte_length():
                    return False
                if not _class_matches(pat, pi, val, j):
                    return False
                j += _utf8_decode_scalar(val, j)[1]
        elif qk == 2:
            if vi >= val.byte_length() or not _class_matches(pat, pi, val, vi):
                return False
            var j2 = vi + _utf8_decode_scalar(val, vi)[1]
            while True:
                if _match_from(pat, next_pi, val, j2):
                    return True
                if j2 >= val.byte_length():
                    return False
                if not _class_matches(pat, pi, val, j2):
                    return False
                j2 += _utf8_decode_scalar(val, j2)[1]
        elif qk == 3:
            if _class_matches(pat, pi, val, vi):
                return _match_from(
                    pat, next_pi, val, vi + _utf8_decode_scalar(val, vi)[1]
                )
            return _match_from(pat, next_pi, val, vi)
        else:
            if not _class_matches(pat, pi, val, vi):
                return False
            return _match_from(
                pat, next_pi, val, vi + _utf8_decode_scalar(val, vi)[1]
            )

    if _bytes_at(pat, pi) == ord("."):
        if qk == 1:
            var jd = vi
            while True:
                if _match_from(pat, next_pi, val, jd):
                    return True
                if jd >= val.byte_length():
                    return False
                jd += _utf8_decode_scalar(val, jd)[1]
        elif qk == 2:
            if not _dot_matches(val, vi):
                return False
            var jdp = vi + _utf8_decode_scalar(val, vi)[1]
            while True:
                if _match_from(pat, next_pi, val, jdp):
                    return True
                if jdp >= val.byte_length():
                    return False
                jdp += _utf8_decode_scalar(val, jdp)[1]
        elif qk == 3:
            if _dot_matches(val, vi):
                return _match_from(
                    pat, next_pi, val, vi + _utf8_decode_scalar(val, vi)[1]
                )
            return _match_from(pat, next_pi, val, vi)
        else:
            if not _dot_matches(val, vi):
                return False
            return _match_from(
                pat, next_pi, val, vi + _utf8_decode_scalar(val, vi)[1]
            )

    if not _literal_matches(pat, pi, val, vi):
        return False
    var vadv = _utf8_decode_scalar(val, vi)[1]
    if qk == 1:
        var jl = vi
        while True:
            if _match_from(pat, next_pi, val, jl):
                return True
            if jl >= val.byte_length():
                return False
            if not _literal_matches(pat, pi, val, jl):
                return False
            jl += _utf8_decode_scalar(val, jl)[1]
    elif qk == 2:
        var jlp = vi + vadv
        while True:
            if _match_from(pat, next_pi, val, jlp):
                return True
            if jlp >= val.byte_length():
                return False
            if not _literal_matches(pat, pi, val, jlp):
                return False
            jlp += _utf8_decode_scalar(val, jlp)[1]
    elif qk == 3:
        if _literal_matches(pat, pi, val, vi):
            return _match_from(pat, next_pi, val, vi + vadv)
        return _match_from(pat, next_pi, val, vi)
    else:
        return _match_from(pat, next_pi, val, vi + vadv)


def yang_string_matches_xsd_subset(
    read pattern: String, read value: String
) raises -> Bool:
    var p = _strip_pattern_anchors(_strip_spaces(pattern))
    if p.byte_length() == 0:
        return value.byte_length() == 0
    return _match_from(p, 0, value, 0)


def unicode_scalar_count(read s: String) raises -> Int:
    ## Count of Unicode scalar values (decoded UTF-8 code points), RFC 7950 §9.4.4.
    var i = 0
    var n = 0
    while i < s.byte_length():
        i += _utf8_decode_scalar(s, i)[1]
        n += 1
    return n
