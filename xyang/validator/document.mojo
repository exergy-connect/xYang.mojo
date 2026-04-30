## Top-level validation: YANG module shape + JSON instance document.

from xyang.json.parser import JsonValue, parse_json
from xyang.yang.construct import YangConstruct, parse_module, validate_module
from xyang.yang.lexer import AstLexer
from xyang.yang.lookup import find_effective_child
from xyang.validator.leafref import check_leafrefs_in_object
from xyang.validator.tree import validate_object_against_construct


def validate_data(
    read data: JsonValue, read module: YangConstruct, json_path: String = ""
) raises:
    if data.kind != JsonValue.OBJECT:
        var pfx = String()
        if json_path.byte_length() > 0:
            pfx += json_path + " "
        if data.source_line > 0:
            pfx += "line " + String(data.source_line) + ": "
        raise Error(pfx + "/: expected top-level JSON object")
    for i in range(len(data.object_keys)):
        var key = data.object_keys[i]
        ref slot = data.object_values[i][]
        var container = find_effective_child(module, module, "container", key)
        if not container:
            var pfx2 = String()
            if json_path.byte_length() > 0:
                pfx2 += json_path + " "
            if slot.source_line > 0:
                pfx2 += "line " + String(slot.source_line) + ": "
            raise Error(pfx2 + "/: unknown top-level field `" + key + "`")
        validate_object_against_construct(
            slot, container.value()[], module, "/" + key, json_path
        )
        check_leafrefs_in_object(
            slot,
            container.value()[],
            module,
            data,
            "/" + key,
            json_path,
        )


def validate_yang_document(
    yang_text: String,
    json_text: String,
    yang_path: String = "",
    json_path: String = "",
) raises:
    var lexer = AstLexer(yang_text.as_bytes())
    var yang_module = parse_module(lexer)
    validate_module(yang_module)
    var data = parse_json(json_text, json_path)
    validate_data(data, yang_module, json_path)
