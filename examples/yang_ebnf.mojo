## Type-level sketch of the YANG subset described by
## `/home/jeroen/Projects/xYang/meta-model-grammar.ebnf`.
##
## This file intentionally uses the small grammar-building structures from
## `examples/structure.mojo`: `FieldDefinition`, `RepeatedField`, and
## `CompositeFieldDefinition`.  The aliases below map EBNF productions to
## comptime Mojo types.
##
##   pixi run mojo examples/yang_ebnf.mojo

from structure import (
    CompositeFieldDefinition,
    FieldTraits,
    FieldDefinition,
    RepeatedField,
    YangBool,
    YangInt,
    YangString,
)
from must_tokenizer import Lexer


@fieldwise_init
struct SkippedStatement[
    field_name: StringLiteral,
    has_argument: Bool,
](FieldTraits):
    var argument: Optional[String]

    def __init__(out self):
        self.argument = Optional[String]()

    @staticmethod
    def name() -> String:
        return Self.field_name

    def __str__(ref self) -> String:
        if self.argument:
            return Self.field_name + "(" + self.argument.value() + ")\n"
        return Self.field_name + "\n"

    @staticmethod
    def from_lexer(mut lexer: Lexer) raises -> Self:
        var statement = Self()
        statement.parse(lexer)
        return statement^

    def parse(mut self, mut lexer: Lexer) raises:
        if Self.has_argument:
            self.argument = Optional[String](lexer.expect_arg())
        lexer.skip_statement_tail()


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
comptime YangLength = FieldDefinition["length", YangString]
comptime YangRange = FieldDefinition["range", YangString]
comptime YangFractionDigits = FieldDefinition["fraction-digits", YangInt]
comptime YangPosition = FieldDefinition["position", YangInt]


## Meta statements.
comptime YangRevision = CompositeFieldDefinition["revision", True, YangDescription]
comptime YangRevisionList = RepeatedField[YangRevision]


## Type statements.
##
## `YangType` models the common scalar form:
##
##   type string;
##   type entity-name;
##
## `YangTypeBlock` models constrained and aggregate forms:
##
##   type string { pattern "..."; }
##   type union { type string; type int32; }
##
comptime YangType = FieldDefinition["type", YangString]

comptime YangEnum = CompositeFieldDefinition["enum", True, YangDescription]
comptime YangEnumList = RepeatedField[YangEnum]

comptime YangBit = CompositeFieldDefinition["bit", True, YangPosition, YangDescription]
comptime YangBitList = RepeatedField[YangBit]

comptime YangTypeBlock = CompositeFieldDefinition[
    "type", True,
    YangType,
    YangPath,
    YangRequireInstance,
    YangEnumList,
    YangBitList,
    YangPattern,
    YangLength,
    YangRange,
    YangFractionDigits,
    YangDescription,
]


## Typedef.
comptime YangTypedef = CompositeFieldDefinition[
    "typedef", True,
    YangType,
    YangTypeBlock,
    YangDescription,
]
comptime YangTypedefList = RepeatedField[YangTypedef]


## Must / when / uses / refine.
comptime YangMust = CompositeFieldDefinition[
    "must", True,
    YangErrorMessage,
    YangDescription,
]
comptime YangMustList = RepeatedField[YangMust]

comptime YangWhen = CompositeFieldDefinition[
    "when", True,
    YangDescription,
]

comptime YangRefine = CompositeFieldDefinition[
    "refine", True,
    YangType,
    YangTypeBlock,
    YangMustList,
    YangDescription,
]
comptime YangRefineList = RepeatedField[YangRefine]

comptime YangUses = CompositeFieldDefinition[
    "uses", True,
    YangRefineList,
    YangWhen,
]
comptime YangUsesList = RepeatedField[YangUses]


## Data definition statements.
comptime YangLeaf = CompositeFieldDefinition[
    "leaf", True,
    YangType,
    YangTypeBlock,
    YangMandatory,
    YangDefault,
    YangWhen,
    YangDescription,
    YangMustList,
]
comptime YangLeafList = RepeatedField[YangLeaf]

comptime YangLeafListStatement = CompositeFieldDefinition[
    "leaf-list", True,
    YangType,
    YangTypeBlock,
    YangMinElements,
    YangMaxElements,
    YangWhen,
    YangDescription,
    YangMustList,
]
comptime YangLeafListStatements = RepeatedField[YangLeafListStatement]

comptime YangContainer = CompositeFieldDefinition[
    "container", True,
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
    "list", True,
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
    "case", True,
    YangDescription,
    YangLeafList,
    YangLeafListStatements,
    YangContainerList,
    YangListList,
    YangUsesList,
]
comptime YangCaseList = RepeatedField[YangCase]

comptime YangChoice = CompositeFieldDefinition[
    "choice", True,
    YangMandatory,
    YangDescription,
    YangCaseList,
]
comptime YangChoiceList = RepeatedField[YangChoice]


## Grouping and module.
comptime YangGrouping = CompositeFieldDefinition[
    "grouping", True,
    YangDescription,
    YangLeafList,
    YangLeafListStatements,
    YangContainerList,
    YangListList,
    YangChoiceList,
    YangUsesList,
]
comptime YangGroupingList = RepeatedField[YangGrouping]

comptime YangSkippedTypedef = SkippedStatement["typedef", True]
comptime YangSkippedTypedefList = RepeatedField[YangSkippedTypedef]
comptime YangSkippedGrouping = SkippedStatement["grouping", True]
comptime YangSkippedGroupingList = RepeatedField[YangSkippedGrouping]
comptime YangSkippedContainer = SkippedStatement["container", True]
comptime YangSkippedContainerList = RepeatedField[YangSkippedContainer]
comptime YangSkippedList = SkippedStatement["list", True]
comptime YangSkippedListList = RepeatedField[YangSkippedList]
comptime YangSkippedLeaf = SkippedStatement["leaf", True]
comptime YangSkippedLeafList = RepeatedField[YangSkippedLeaf]
comptime YangSkippedLeafListStatement = SkippedStatement["leaf-list", True]
comptime YangSkippedLeafListStatements = RepeatedField[YangSkippedLeafListStatement]
comptime YangSkippedChoice = SkippedStatement["choice", True]
comptime YangSkippedChoiceList = RepeatedField[YangSkippedChoice]

comptime YangModule = CompositeFieldDefinition[
    "module", True,
    YangVersion,
    YangNamespace,
    YangPrefix,
    YangOrganization,
    YangContact,
    YangDescription,
    YangRevisionList,
    YangSkippedTypedefList,
    YangSkippedGroupingList,
    YangSkippedContainerList,
    YangSkippedListList,
    YangSkippedLeafList,
    YangSkippedLeafListStatements,
    YangSkippedChoiceList,
]


def main() raises:
    var lexer = Lexer(file_path="examples/meta-model.yang")
    var stmt_name = lexer.expect_ident()
    if stmt_name != "module":
        raise Error("Expected module statement")

    var module = YangModule()
    module.parse(lexer)
    print(module.__str__())
