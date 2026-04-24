from std.collections import Dict
from xyang.ast import YangChoice
from xyang.yang.tokens import YANG_BOOL_TRUE, YANG_BOOL_FALSE
from xyang.yang.parser.parser_contract import ParserContract


def parse_non_negative_int_impl[ParserT: ParserContract](mut parser: ParserT, label: String) raises -> Int:
    var raw = parser._consume_argument_value().strip()
    try:
        var n = atol(raw)
        if n < 0:
            parser._error(label + " must be non-negative, got '" + raw + "'")
        return Int(n)
    except:
        parser._error("Invalid integer for " + label + ": '" + raw + "'")
        return 0


def parse_ordered_by_argument_impl[ParserT: ParserContract](mut parser: ParserT) raises -> String:
    var v = parser._consume_argument_value()
    if v != "user" and v != "system":
        parser._error("ordered-by must be 'user' or 'system', got '" + v + "'")
    return v


def unique_components_from_argument_impl(arg: String) -> List[String]:
    var parts = arg.strip().split()
    var out = List[String]()
    for i in range(len(parts)):
        var seg = String(String(parts[i]).strip())
        if len(seg) > 0:
            out.append(seg^)
    return out^


def validate_choice_unique_node_names_impl[ParserT: ParserContract](
    mut parser: ParserT,
    read choice: YangChoice,
) raises:
    var seen = Dict[String, String]()
    for i in range(len(choice.cases)):
        ref c = choice.cases[i][]
        for j in range(len(c.node_names)):
            var nm = c.node_names[j]
            if nm in seen:
                parser._error(
                    "Choice '"
                    + choice.name
                    + "': node '"
                    + nm
                    + "' appears in case '"
                    + seen[nm]
                    + "' and case '"
                    + c.name
                    + "' (RFC 7950 §7.9)",
                )
            seen[nm] = c.name


def parse_boolean_value_impl[ParserT: ParserContract](mut parser: ParserT) raises -> Bool:
    var value = parser._consume_value()
    if value == YANG_BOOL_TRUE:
        return True
    if value == YANG_BOOL_FALSE:
        return False
    parser._error("Expected boolean value 'true' or 'false', got '" + value + "'")
    return False
