## Top-level validation: YANG module shape + JSON instance document.

from xyang.json.parser import JsonValue, parse_json
from xyang.yang.ast.module import YangModule
from xyang.yang.ast.lexer import AstLexer
from xyang.validator.leafref import LeafrefCache, check_leafrefs_in_object
from xyang.validator.tree import validate_object_against_construct


def validate_data(
    read data: JsonValue, read module: YangModule, json_path: String = ""
) raises:
    if data.kind != JsonValue.OBJECT:
        var pfx = String()
        if json_path.byte_length() > 0:
            pfx += json_path + " "
        if data.source_line > 0:
            pfx += "line " + String(data.source_line) + ": "
        raise Error(pfx + "/: expected top-level JSON object")
    var leafref_cache = LeafrefCache()
    for i in range(len(data.object_keys)):
        var key = data.object_keys[i]
        ref slot = data.object_values[i][]
        var container = module.top_container(key)
        if not container:
            var pfx2 = String()
            if json_path.byte_length() > 0:
                pfx2 += json_path + " "
            if slot.source_line > 0:
                pfx2 += "line " + String(slot.source_line) + ": "
            raise Error(pfx2 + "/: unknown top-level field `" + key + "`")
        validate_object_against_construct(
            slot,
            container.value()[],
            module,
            "/" + key,
            json_path,
            "/" + key,
        )
        check_leafrefs_in_object(
            slot,
            container.value()[],
            module,
            data,
            "/" + key,
            json_path,
            leafref_cache,
        )


def validate_yang_document(
    yang_text: String,
    json_text: String,
    yang_path: String = "",
    json_path: String = "",
) raises:
    var lexer = AstLexer(yang_text.as_bytes())
    var yang_module = YangModule()
    yang_module.parse(lexer)

    var data = parse_json(json_text, json_path)
    validate_data(data, yang_module, json_path)
