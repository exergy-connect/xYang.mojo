from std.memory import ArcPointer, UnsafePointer
import xyang.ast as ast
from xyang.xpath import parse_xpath
from xyang.yang.parser.yang_token import YANG_TYPE_LEAFREF

comptime Arc = ArcPointer
comptime YangContainer = ast.YangContainer
comptime YangList = ast.YangList
comptime YangChoice = ast.YangChoice
comptime YangChoiceCase = ast.YangChoiceCase
comptime YangLeaf = ast.YangLeaf
comptime YangLeafList = ast.YangLeafList
comptime YangAnydata = ast.YangAnydata
comptime YangAnyxml = ast.YangAnyxml
comptime YangType = ast.YangType
comptime YangTypeTypedef = ast.YangTypeTypedef
comptime YangTypeIntegerRange = ast.YangTypeIntegerRange
comptime YangTypeDecimal64 = ast.YangTypeDecimal64
comptime YangTypeEnumeration = ast.YangTypeEnumeration
comptime YangTypeLeafref = ast.YangTypeLeafref
comptime YangTypeBits = ast.YangTypeBits
comptime YangTypeIdentityref = ast.YangTypeIdentityref
comptime YangTypeUnion = ast.YangTypeUnion
comptime YangTypeString = ast.YangTypeString
comptime YangTypeBoolean = ast.YangTypeBoolean
comptime YangMust = ast.YangMust
comptime YangMustStatements = ast.YangMustStatements
comptime YangWhen = ast.YangWhen


def ident_local_name_impl(ident: String) -> String:
    var parts = ident.split(":")
    if len(parts) == 0:
        return ident
    return String(String(parts[len(parts) - 1]).strip())


def split_schema_path_impl(path: String) -> List[String]:
    var out = List[String]()
    var trimmed = path.strip()
    var parts = trimmed.split("/")
    for i in range(len(parts)):
        var raw = String(String(parts[i]).strip())
        if len(raw) == 0 or raw == ".":
            continue
        out.append(ident_local_name_impl(raw))
    return out^


def clone_must_impl(read src: YangMust) raises -> YangMust:
    var xpath_ast = parse_xpath(src.expression)
    return YangMust(
        expression = src.expression,
        error_message = src.error_message,
        description = src.description,
        xpath_ast = xpath_ast,
    )


def clone_when_impl(read src: YangWhen) raises -> YangWhen:
    var xpath_ast = parse_xpath(src.expression)
    return YangWhen(
        expression = src.expression,
        description = src.description,
        xpath_ast = xpath_ast,
    )


def clone_yang_type_impl(read src: YangType) -> YangType:
    var union_members = List[Arc[YangType]]()
    for i in range(src.union_members_len()):
        union_members.append(Arc[YangType](clone_yang_type_impl(src.union_member_arc(i)[])))

    if src.name == "enumeration":
        var enum_values = List[String]()
        for i in range(src.enum_values_len()):
            enum_values.append(src.enum_value_at(i))
        return YangType(
            name = src.name,
            constraints = YangTypeEnumeration(enum_values^),
        )

    if src.name == "decimal64":
        return YangType(
            name = src.name,
            constraints = YangTypeDecimal64(
                src.fraction_digits(),
                src.has_decimal64_range(),
                src.decimal64_range_min(),
                src.decimal64_range_max(),
            ),
        )

    if src.name == YANG_TYPE_LEAFREF:
        return YangType(
            name = src.name,
            constraints = YangTypeLeafref(
                src.leafref_path(),
                src.leafref_require_instance(),
            ),
        )

    if src.name == "bits":
        var names = List[String]()
        for i in range(src.bits_names_len()):
            names.append(src.bits_name_at(i))
        return YangType(
            name = src.name,
            constraints = YangTypeBits(names^),
        )

    if src.name == "identityref":
        return YangType(
            name = src.name,
            constraints = YangTypeIdentityref(src.identityref_base()),
        )

    if src.name == "union":
        return YangType(
            name = src.name,
            constraints = YangTypeUnion(union_members = union_members^),
        )

    if (
        src.name == "integer"
        or src.name == "int8"
        or src.name == "int16"
        or src.name == "int32"
        or src.name == "int64"
        or src.name == "uint8"
        or src.name == "uint16"
        or src.name == "uint32"
        or src.name == "uint64"
        or src.name == "number"
    ):
        return YangType(
            name = src.name,
            constraints = YangTypeIntegerRange(
                src.has_range(),
                src.range_min(),
                src.range_max(),
            ),
        )

    if src.name == "string" and src.constraints.isa[YangTypeString]():
        return YangType(
            name = "string",
            constraints = YangTypeString(src.string_pattern()),
        )

    if src.name == "boolean" and src.constraints.isa[YangTypeBoolean]():
        return YangType(
            name = src.name,
            constraints = YangTypeBoolean(
                dummy = src.constraints[YangTypeBoolean].dummy,
            ),
        )

    if src.constraints.isa[YangTypeTypedef]():
        return YangType(
            name = src.name,
            constraints = YangTypeTypedef(
                resolved=src.constraints[YangTypeTypedef].resolved,
            ),
        )

    return YangType(
        name = src.name,
        constraints = YangTypeTypedef(
            resolved = UnsafePointer[ast.YangTypedefStmt, MutExternalOrigin](),
        ),
    )


def clone_leaf_arc_impl(read src: Arc[YangLeaf]) raises -> Arc[YangLeaf]:
    var musts = List[Arc[YangMust]]()
    for i in range(len(src[].must.must_statements)):
        musts.append(Arc[YangMust](clone_must_impl(src[].must.must_statements[i][])))

    var when = Optional[YangWhen]()
    if Bool(src[].when):
        when = Optional(clone_when_impl(src[].when.value()))

    return Arc[YangLeaf](
        YangLeaf(
            name = src[].name,
            description = src[].description,
            type = clone_yang_type_impl(src[].type),
            mandatory = src[].mandatory,
            has_default = src[].has_default,
            default_value = src[].default_value,
            must = YangMustStatements(must_statements = musts^),
            when = when^,
        ),
    )


def clone_leaf_list_arc_impl(read src: Arc[YangLeafList]) raises -> Arc[YangLeafList]:
    var musts = List[Arc[YangMust]]()
    for i in range(len(src[].must.must_statements)):
        musts.append(Arc[YangMust](clone_must_impl(src[].must.must_statements[i][])))

    var when = Optional[YangWhen]()
    if Bool(src[].when):
        when = Optional(clone_when_impl(src[].when.value()))

    return Arc[YangLeafList](
        YangLeafList(
            name = src[].name,
            description = src[].description,
            type = clone_yang_type_impl(src[].type),
            default_values = src[].default_values.copy(),
            must = YangMustStatements(must_statements = musts^),
            when = when^,
            min_elements = src[].min_elements,
            max_elements = src[].max_elements,
            ordered_by = src[].ordered_by,
        ),
    )


def clone_choice_arc_impl(read src: Arc[YangChoice]) raises -> Arc[YangChoice]:
    var cases = List[Arc[YangChoiceCase]]()
    for i in range(len(src[].cases)):
        var case_when = Optional[YangWhen]()
        if Bool(src[].cases[i][].when):
            case_when = Optional(clone_when_impl(src[].cases[i][].when.value()))
        cases.append(Arc[YangChoiceCase](
            YangChoiceCase(
                name = src[].cases[i][].name,
                description = src[].cases[i][].description,
                node_names = src[].cases[i][].node_names.copy(),
                when = case_when^,
            ),
        ))

    var choice_when = Optional[YangWhen]()
    if Bool(src[].when):
        choice_when = Optional(clone_when_impl(src[].when.value()))

    return Arc[YangChoice](
        YangChoice(
            name = src[].name,
            description = src[].description,
            mandatory = src[].mandatory,
            default_case = src[].default_case,
            case_names = src[].case_names.copy(),
            cases = cases^,
            when = choice_when^,
        ),
    )


def clone_anydata_arc_impl(read src: Arc[YangAnydata]) raises -> Arc[YangAnydata]:
    var musts = List[Arc[YangMust]]()
    for i in range(len(src[].must.must_statements)):
        musts.append(Arc[YangMust](clone_must_impl(src[].must.must_statements[i][])))
    var when = Optional[YangWhen]()
    if src[].has_when():
        when = Optional(clone_when_impl(src[].when.value()))
    return Arc[YangAnydata](
        YangAnydata(
            name = src[].name,
            description = src[].description,
            mandatory = src[].mandatory,
            must = YangMustStatements(must_statements = musts^),
            when = when^,
        ),
    )


def clone_anyxml_arc_impl(read src: Arc[YangAnyxml]) raises -> Arc[YangAnyxml]:
    var musts = List[Arc[YangMust]]()
    for i in range(len(src[].must.must_statements)):
        musts.append(Arc[YangMust](clone_must_impl(src[].must.must_statements[i][])))
    var when = Optional[YangWhen]()
    if src[].has_when():
        when = Optional(clone_when_impl(src[].when.value()))
    return Arc[YangAnyxml](
        YangAnyxml(
            name = src[].name,
            description = src[].description,
            mandatory = src[].mandatory,
            must = YangMustStatements(must_statements = musts^),
            when = when^,
        ),
    )


def clone_container_arc_impl(read src: Arc[YangContainer]) raises -> Arc[YangContainer]:
    var musts = List[Arc[YangMust]]()
    var leaves = List[Arc[YangLeaf]]()
    var leaf_lists = List[Arc[YangLeafList]]()
    var anydatas = List[Arc[YangAnydata]]()
    var anyxmls = List[Arc[YangAnyxml]]()
    var containers = List[Arc[YangContainer]]()
    var lists = List[Arc[YangList]]()
    var choices = List[Arc[YangChoice]]()

    for i in range(len(src[].must.must_statements)):
        musts.append(Arc[YangMust](clone_must_impl(src[].must.must_statements[i][])))
    for i in range(len(src[].leaves)):
        leaves.append(clone_leaf_arc_impl(src[].leaves[i]))
    for i in range(len(src[].leaf_lists)):
        leaf_lists.append(clone_leaf_list_arc_impl(src[].leaf_lists[i]))
    for i in range(len(src[].anydatas)):
        anydatas.append(clone_anydata_arc_impl(src[].anydatas[i]))
    for i in range(len(src[].anyxmls)):
        anyxmls.append(clone_anyxml_arc_impl(src[].anyxmls[i]))
    for i in range(len(src[].containers)):
        containers.append(clone_container_arc_impl(src[].containers[i]))
    for i in range(len(src[].lists)):
        lists.append(clone_list_arc_impl(src[].lists[i]))
    for i in range(len(src[].choices)):
        choices.append(clone_choice_arc_impl(src[].choices[i]))

    return Arc[YangContainer](
        YangContainer(
            name = src[].name,
            description = src[].description,
            must = YangMustStatements(must_statements = musts^),
            leaves = leaves^,
            leaf_lists = leaf_lists^,
            anydatas = anydatas^,
            anyxmls = anyxmls^,
            containers = containers^,
            lists = lists^,
            choices = choices^,
        ),
    )


def clone_list_arc_impl(read src: Arc[YangList]) raises -> Arc[YangList]:
    var musts = List[Arc[YangMust]]()
    var ch = List[YangList.ChildStatement]()
    var unique_specs = List[List[String]]()

    for i in range(len(src[].must.must_statements)):
        musts.append(Arc[YangMust](clone_must_impl(src[].must.must_statements[i][])))
    for i in range(len(src[].children)):
        var stmt = src[].children[i]
        if stmt.isa[Arc[YangLeaf]]():
            ch.append(YangList.ChildStatement(clone_leaf_arc_impl(stmt[Arc[YangLeaf]])))
        elif stmt.isa[Arc[YangLeafList]]():
            ch.append(
                YangList.ChildStatement(
                    clone_leaf_list_arc_impl(stmt[Arc[YangLeafList]]),
                ),
            )
        elif stmt.isa[Arc[YangAnydata]]():
            ch.append(
                YangList.ChildStatement(
                    clone_anydata_arc_impl(stmt[Arc[YangAnydata]]),
                ),
            )
        elif stmt.isa[Arc[YangAnyxml]]():
            ch.append(
                YangList.ChildStatement(
                    clone_anyxml_arc_impl(stmt[Arc[YangAnyxml]]),
                ),
            )
        elif stmt.isa[Arc[YangContainer]]():
            ch.append(
                YangList.ChildStatement(
                    clone_container_arc_impl(stmt[Arc[YangContainer]]),
                ),
            )
        elif stmt.isa[Arc[YangList]]():
            ch.append(
                YangList.ChildStatement(
                    clone_list_arc_impl(stmt[Arc[YangList]]),
                ),
            )
        elif stmt.isa[Arc[YangChoice]]():
            ch.append(
                YangList.ChildStatement(
                    clone_choice_arc_impl(stmt[Arc[YangChoice]]),
                ),
            )
    for i in range(len(src[].unique_specs)):
        unique_specs.append(src[].unique_specs[i].copy())

    return Arc[YangList](
        YangList(
            name = src[].name,
            key = src[].key,
            description = src[].description,
            must = YangMustStatements(must_statements = musts^),
            children = ch^,
            min_elements = src[].min_elements,
            max_elements = src[].max_elements,
            ordered_by = src[].ordered_by,
            unique_specs = unique_specs^,
        ),
    )
