## Type-level sketch aligned with **RFC 7950** `type-stmt`, `enum-stmt`,
## `union-specification`, `leafref-specification`, `string-restrictions`,
## `bits-specification`, and related `type-body-stmts` (see Appendix A).
## Also see `/home/jeroen/Projects/xYang/meta-model-grammar.ebnf` for the
## xYang meta-model subset.
##
## **Recursion (intentional limit):** a `typedef` body uses full `YangType`,
## which may include `union-specification` (`YangUnion`). Each union member is
## `YangUnionMemberType` — the same substatement set as `YangType` **except**
## union is disallowed, so a union cannot nest another union at the grammar
## level modeled here.
##
## This file uses the small grammar-building structures from
## `examples/structure.mojo`: `FieldDefinition`, `RepeatedField`, and
## `CompositeFieldDefinition`.  The aliases map RFC productions to comptime types.
##
##   pixi run mojo -I . -I examples examples/yang_ebnf.mojo

from structure import (
    CompositeFieldDefinition,
    FieldTraits,
    FieldDefinition,
    RepeatedField,
    YangBool,
    YangInt,
    YangString,
)
from ast import AstLexer, parse_module


## Shared scalar statements.
comptime YangVersion = FieldDefinition["yang-version", YangString]
comptime YangNamespace = FieldDefinition["namespace", YangString]
comptime YangPrefix = FieldDefinition["prefix", YangString]
comptime YangOrganization = FieldDefinition["organization", YangString]
comptime YangContact = FieldDefinition["contact", YangString]
comptime YangDescription = FieldDefinition["description", YangString]
comptime YangErrorMessage = FieldDefinition["error-message", YangString]
comptime YangPresence = FieldDefinition["presence", YangString]
comptime YangKey = FieldDefinition["key", YangString]
comptime YangMinElements = FieldDefinition["min-elements", YangInt]
comptime YangMaxElements = FieldDefinition["max-elements", YangInt]
comptime YangMandatory = FieldDefinition["mandatory", YangBool]
comptime YangDefault = FieldDefinition["default", YangString]
comptime YangPath = FieldDefinition["path", YangString]
comptime YangRequireInstance = FieldDefinition["require-instance", YangBool]
comptime YangPattern = FieldDefinition["pattern", YangString]
comptime YangPatternList = RepeatedField[YangPattern]
comptime YangLength = FieldDefinition["length", YangString]
comptime YangRange = FieldDefinition["range", YangString]
comptime YangFractionDigits = FieldDefinition["fraction-digits", YangInt]
comptime YangPosition = FieldDefinition["position", YangInt]
comptime YangValue = FieldDefinition["value", YangInt]
comptime YangReference = FieldDefinition["reference", YangString]
comptime YangStatus = FieldDefinition["status", YangString]


## Meta statements.
comptime YangRevision = CompositeFieldDefinition[
    "revision", True, YangDescription
]
comptime YangRevisionList = RepeatedField[YangRevision]


## Type statements (RFC 7950 `type-stmt` + `type-body-stmts`).
##
## `YangType`: `identifier-ref-arg-str` is the composite argument; `{ ... }`
## holds one branch’s substatements (keyword dispatch). `union-specification`
## is `1*type-stmt`; here each member is `YangUnionMemberType` (no nested union).
##
## Omitted from this sketch: `identityref-specification`, `instance-identifier-`
## `specification`, `binary-specification`, `if-feature-stmt`, `modifier-stmt`,
## `error-app-tag-stmt`, and block-only refinements on `range` / `length` /
## `pattern` (only leaf forms are modeled).
##
comptime YangEnum = CompositeFieldDefinition[
    "enum",
    True,
    YangValue,
    YangStatus,
    YangDescription,
    YangReference,
]
comptime YangEnumList = RepeatedField[YangEnum]

comptime YangBit = CompositeFieldDefinition[
    "bit",
    True,
    YangPosition,
    YangStatus,
    YangDescription,
    YangReference,
]
comptime YangBitList = RepeatedField[YangBit]

## RFC 7950: `union-specification = 1*type-stmt` where each member type-stmt
## must not recurse into another union (enforced by `YangUnionMemberType`).
comptime YangUnionMemberType = CompositeFieldDefinition[
    "type",
    True,
    YangPath,
    YangRequireInstance,
    YangEnumList,
    YangBitList,
    YangPatternList,
    YangLength,
    YangRange,
    YangFractionDigits,
    YangDescription,
]
comptime YangUnion = RepeatedField[YangUnionMemberType]

comptime YangType = CompositeFieldDefinition[
    "type",
    True,
    YangUnion,
    YangPath,
    YangRequireInstance,
    YangEnumList,
    YangBitList,
    YangPatternList,
    YangLength,
    YangRange,
    YangFractionDigits,
    YangDescription,
]


## Typedef.
comptime YangTypedef = CompositeFieldDefinition[
    "typedef",
    True,
    YangType,
    YangDescription,
]
comptime YangTypedefList = RepeatedField[YangTypedef]


## Must / when / uses / refine.
comptime YangMust = CompositeFieldDefinition[
    "must",
    True,
    YangErrorMessage,
    YangDescription,
]
comptime YangMustList = RepeatedField[YangMust]

comptime YangWhen = CompositeFieldDefinition[
    "when",
    True,
    YangDescription,
]

comptime YangRefine = CompositeFieldDefinition[
    "refine",
    True,
    YangType,
    YangMustList,
    YangDescription,
]
comptime YangRefineList = RepeatedField[YangRefine]

comptime YangUses = CompositeFieldDefinition[
    "uses",
    True,
    YangRefineList,
    YangWhen,
]
comptime YangUsesList = RepeatedField[YangUses]


## Data definition statements.
comptime YangLeaf = CompositeFieldDefinition[
    "leaf",
    True,
    YangType,
    YangMandatory,
    YangDefault,
    YangWhen,
    YangDescription,
    YangMustList,
]
comptime YangLeafList = RepeatedField[YangLeaf]

comptime YangLeafListStatement = CompositeFieldDefinition[
    "leaf-list",
    True,
    YangType,
    YangMinElements,
    YangMaxElements,
    YangWhen,
    YangDescription,
    YangMustList,
]
comptime YangLeafListStatements = RepeatedField[YangLeafListStatement]

comptime YangContainer = CompositeFieldDefinition[
    "container",
    True,
    YangPresence,
    YangWhen,
    YangDescription,
    YangMustList,
    YangLeafList,
    YangLeafListStatements,
    YangUsesList,
]
comptime YangContainerList = RepeatedField[YangContainer]

comptime YangList = CompositeFieldDefinition[
    "list",
    True,
    YangKey,
    YangMinElements,
    YangMaxElements,
    YangWhen,
    YangDescription,
    YangMustList,
    YangLeafList,
    YangLeafListStatements,
    YangContainerList,
    YangUsesList,
]
comptime YangListList = RepeatedField[YangList]

comptime YangCase = CompositeFieldDefinition[
    "case",
    True,
    YangDescription,
    YangLeafList,
    YangLeafListStatements,
    YangContainerList,
    YangListList,
    YangUsesList,
]
comptime YangCaseList = RepeatedField[YangCase]

comptime YangChoice = CompositeFieldDefinition[
    "choice",
    True,
    YangMandatory,
    YangDescription,
    YangCaseList,
]
comptime YangChoiceList = RepeatedField[YangChoice]


## Grouping and module.
comptime YangGrouping = CompositeFieldDefinition[
    "grouping",
    True,
    YangDescription,
    YangLeafList,
    YangLeafListStatements,
    YangContainerList,
    YangListList,
    YangChoiceList,
    YangUsesList,
]
comptime YangGroupingList = RepeatedField[YangGrouping]

comptime YangModule = CompositeFieldDefinition[
    "module",
    True,
    YangVersion,
    YangNamespace,
    YangPrefix,
    YangOrganization,
    YangContact,
    YangDescription,
    YangRevisionList,
    YangTypedefList,
    YangGroupingList,
    YangContainerList,
    YangListList,
    YangLeafList,
    YangLeafListStatements,
    YangChoiceList,
]


def main() raises:
    var source: String
    with open("examples/meta-model.yang", "r") as f:
        source = f.read()
    var lexer = AstLexer(source.as_bytes())
    var construct = parse_module(lexer)

    var module = YangModule()
    module.build(construct)
    print(module.__str__())
