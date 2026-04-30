from std.collections import List
from std.collections.string import Codepoint, StringSlice


@fieldwise_init
struct QName(Copyable):
    """Qualified name segment in a schema path (prefix:local-name or local-name)."""

    var prefix: String
    var local_name: String

    def has_prefix(self) -> Bool:
        return len(self.prefix) > 0

    def text(self) -> String:
        if self.has_prefix():
            return self.prefix + ":" + self.local_name
        return self.local_name


struct Path(Copyable):
    """Schema path made of QName segments."""

    var absolute: Bool
    var segments: List[QName]

    def __init__(out self, absolute: Bool = False, var segments: List[QName] = List[QName]()):
        self.absolute = absolute
        self.segments = segments^

    def text(self) -> String:
        var out = String("")
        var first = not self.absolute
        for seg in self.segments:
            if not first:
                out += "/"
            out += seg.text()
            first = False
        return out^


def _qname_from_path_segment(segment: String) raises -> QName:
    """One path segment as RFC 7950 ``node-identifier`` (``[prefix ':'] identifier``)."""
    var colon_at = segment.find(":")
    if colon_at < 0:
        return QName(prefix="", local_name=segment)

    if segment.find(":", colon_at + 1) >= 0:
        raise Error("Invalid path: at most one ':' per segment")

    var prefix = String(segment[byte=0:colon_at].strip())
    var local_name = String(segment[byte=colon_at + 1 : len(segment)].strip())
    if len(prefix) == 0:
        raise Error("Invalid path: empty prefix before ':'")
    if len(local_name) == 0:
        raise Error("Invalid path: empty local name after ':'")
    return QName(prefix=prefix, local_name=local_name)


def _qname_for_slashed_path_token(read part: String) raises -> QName:
    """One slash-separated path step (outer per-step trim only)."""
    var segment = String(part.strip())
    if len(segment) == 0:
        raise Error("Invalid path: empty segment (adjacent '/' or trailing '/')")
    if segment == ".":
        raise Error("Invalid path: '.' is not a valid segment")
    return _qname_from_path_segment(segment)


def local_names_from_slashed_path_parts(read parts: List[String]) raises -> List[String]:
    """``node-identifier`` local name per step from tokenizer-split segments (no re-split of a full path)."""
    var out = List[String]()
    for i in range(len(parts)):
        out.append(_qname_for_slashed_path_token(parts[i]).local_name)
    return out^


def _qnames_from_slashed_path_parts(read parts: List[String]) raises -> List[QName]:
    var out = List[QName]()
    for i in range(len(parts)):
        out.append(_qname_for_slashed_path_token(parts[i]))
    return out^


def parse_path(expression: StringSlice) raises -> Path:
    var absolute = False
    var trimmed = expression.strip()
    if trimmed.startswith("/"):
        absolute = True
        trimmed = trimmed[byte=1:len(trimmed)]
    var parts = List[String]()
    for p in trimmed.split("/"):
        parts.append(String(p))
    return Path(absolute=absolute, segments=_qnames_from_slashed_path_parts(parts))