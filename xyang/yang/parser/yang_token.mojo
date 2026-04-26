from std.collections import Dict

## YANG parser/validator string constants.
## Moved here so parser token definitions own their keyword lexemes.

comptime YANG_TYPE_LEAFREF = "leafref"
comptime YANG_TYPE_UNKNOWN = "unknown"
comptime YANG_TYPE_ENUMERATION = "enumeration"
comptime YANG_TYPE_BINARY = "binary"
comptime YANG_TYPE_BITS = "bits"
comptime YANG_TYPE_BOOLEAN = "boolean"
comptime YANG_TYPE_DECIMAL64 = "decimal64"
comptime YANG_TYPE_EMPTY = "empty"
comptime YANG_TYPE_IDENTITYREF = "identityref"
comptime YANG_TYPE_INSTANCE_IDENTIFIER = "instance-identifier"
comptime YANG_TYPE_INT8 = "int8"
comptime YANG_TYPE_INT16 = "int16"
comptime YANG_TYPE_INT32 = "int32"
comptime YANG_TYPE_INT64 = "int64"
comptime YANG_TYPE_STRING = "string"
comptime YANG_TYPE_UINT8 = "uint8"
comptime YANG_TYPE_UINT16 = "uint16"
comptime YANG_TYPE_UINT32 = "uint32"
comptime YANG_TYPE_UINT64 = "uint64"

comptime YANG_BOOL_TRUE = "true"
comptime YANG_BOOL_FALSE = "false"

comptime YANG_STMT_MODULE = "module"
comptime YANG_STMT_NAMESPACE = "namespace"
comptime YANG_STMT_PREFIX = "prefix"
comptime YANG_STMT_DESCRIPTION = "description"
comptime YANG_STMT_REVISION = "revision"
comptime YANG_STMT_ORGANIZATION = "organization"
comptime YANG_STMT_CONTACT = "contact"
comptime YANG_STMT_CONTAINER = "container"
comptime YANG_STMT_GROUPING = "grouping"
comptime YANG_STMT_USES = "uses"
comptime YANG_STMT_REFINE = "refine"
comptime YANG_STMT_IF_FEATURE = "if-feature"
comptime YANG_STMT_AUGMENT = "augment"
comptime YANG_STMT_LIST = "list"
comptime YANG_STMT_KEY = "key"
comptime YANG_STMT_LEAF = "leaf"
comptime YANG_STMT_LEAF_LIST = "leaf-list"
comptime YANG_STMT_ANYDATA = "anydata"
comptime YANG_STMT_ANYXML = "anyxml"
comptime YANG_STMT_CHOICE = "choice"
comptime YANG_STMT_CASE = "case"
comptime YANG_STMT_TYPE = "type"
comptime YANG_STMT_UNION = "union"
comptime YANG_STMT_ENUM = "enum"
comptime YANG_STMT_MANDATORY = "mandatory"
comptime YANG_STMT_DEFAULT = "default"
comptime YANG_STMT_MUST = "must"
comptime YANG_STMT_WHEN = "when"
comptime YANG_STMT_RANGE = "range"
comptime YANG_STMT_PATH = "path"
comptime YANG_STMT_FRACTION_DIGITS = "fraction-digits"
comptime YANG_STMT_BIT = "bit"
comptime YANG_STMT_BASE = "base"
comptime YANG_STMT_POSITION = "position"
comptime YANG_STMT_REQUIRE_INSTANCE = "require-instance"
comptime YANG_STMT_ERROR_MESSAGE = "error-message"
comptime YANG_STMT_MIN_ELEMENTS = "min-elements"
comptime YANG_STMT_MAX_ELEMENTS = "max-elements"
comptime YANG_STMT_ORDERED_BY = "ordered-by"
comptime YANG_STMT_UNIQUE = "unique"
comptime YANG_STMT_TYPEDEF = "typedef"
comptime YANG_STMT_IDENTITY = "identity"
comptime YANG_STMT_PATTERN = "pattern"


@fieldwise_init
struct YangToken(Copyable):
    comptime Type = Int

    ## Punctuation
    comptime LBRACE: Self.Type = 0
    comptime RBRACE: Self.Type = 1
    comptime SEMICOLON: Self.Type = 2
    comptime COLON: Self.Type = 3
    comptime EQUALS: Self.Type = 4
    comptime PLUS: Self.Type = 5
    comptime SLASH: Self.Type = 6

    ## Literals / generic
    comptime STRING: Self.Type = 7
    comptime IDENTIFIER: Self.Type = 8
    comptime INTEGER: Self.Type = 9
    comptime DOTTED_NUMBER: Self.Type = 10
    comptime UNKNOWN: Self.Type = 11

    ## YANG_TYPE_* keywords
    comptime LEAFREF: Self.Type = 12
    comptime ENUMERATION: Self.Type = 13
    comptime BINARY: Self.Type = 14
    comptime BITS: Self.Type = 15
    comptime BOOLEAN_KW: Self.Type = 16
    comptime DECIMAL64: Self.Type = 17
    comptime EMPTY: Self.Type = 18
    comptime IDENTITYREF: Self.Type = 19
    comptime INSTANCE_IDENTIFIER: Self.Type = 20
    comptime INT8_KW: Self.Type = 21
    comptime INT16_KW: Self.Type = 22
    comptime INT32_KW: Self.Type = 23
    comptime INT64_KW: Self.Type = 24
    comptime STRING_KW: Self.Type = 25
    comptime UINT8_KW: Self.Type = 26
    comptime UINT16_KW: Self.Type = 27
    comptime UINT32_KW: Self.Type = 28
    comptime UINT64_KW: Self.Type = 29

    ## YANG_BOOL_* keywords
    comptime TRUE: Self.Type = 30
    comptime FALSE: Self.Type = 31

    ## YANG_STMT_* keywords
    comptime MODULE: Self.Type = 32
    comptime NAMESPACE: Self.Type = 33
    comptime PREFIX: Self.Type = 34
    comptime DESCRIPTION: Self.Type = 35
    comptime REVISION: Self.Type = 36
    comptime ORGANIZATION: Self.Type = 37
    comptime CONTACT: Self.Type = 38
    comptime CONTAINER: Self.Type = 39
    comptime GROUPING: Self.Type = 40
    comptime USES: Self.Type = 41
    comptime REFINE: Self.Type = 42
    comptime IF_FEATURE: Self.Type = 43
    comptime AUGMENT: Self.Type = 44
    comptime LIST: Self.Type = 45
    comptime KEY: Self.Type = 46
    comptime LEAF: Self.Type = 47
    comptime LEAF_LIST: Self.Type = 48
    comptime ANYDATA: Self.Type = 49
    comptime ANYXML: Self.Type = 50
    comptime CHOICE: Self.Type = 51
    comptime CASE: Self.Type = 52
    comptime TYPE: Self.Type = 53
    comptime UNION: Self.Type = 54
    comptime ENUM: Self.Type = 55
    comptime MANDATORY: Self.Type = 56
    comptime DEFAULT: Self.Type = 57
    comptime MUST: Self.Type = 58
    comptime WHEN: Self.Type = 59
    comptime RANGE: Self.Type = 60
    comptime PATH: Self.Type = 61
    comptime FRACTION_DIGITS: Self.Type = 62
    comptime BIT: Self.Type = 63
    comptime BASE: Self.Type = 64
    comptime POSITION: Self.Type = 65
    comptime REQUIRE_INSTANCE: Self.Type = 66
    comptime ERROR_MESSAGE: Self.Type = 67
    comptime MIN_ELEMENTS: Self.Type = 68
    comptime MAX_ELEMENTS: Self.Type = 69
    comptime ORDERED_BY: Self.Type = 70
    comptime UNIQUE: Self.Type = 71
    comptime TYPEDEF: Self.Type = 72
    comptime IDENTITY: Self.Type = 73
    comptime PATTERN: Self.Type = 74

    var type: Self.Type
    var start: Int
    var length: Int
    var line: Int

    def text(self, source: String, strip_quotes: Bool = False) -> String:
        if strip_quotes and self.type == Self.STRING and self.length >= 2:
            return String(
                source[byte=self.start + 1 : self.start + self.length - 1]
            )
        return String(source[byte=self.start : self.start + self.length])


def make_keyword_type_map() -> Dict[String, YangToken.Type]:
    var d = Dict[String, YangToken.Type]()

    ## YANG_TYPE_* keywords
    d[YANG_TYPE_LEAFREF] = YangToken.LEAFREF
    d[YANG_TYPE_UNKNOWN] = YangToken.IDENTIFIER
    d[YANG_TYPE_ENUMERATION] = YangToken.ENUMERATION
    d[YANG_TYPE_BINARY] = YangToken.BINARY
    d[YANG_TYPE_BITS] = YangToken.BITS
    d[YANG_TYPE_BOOLEAN] = YangToken.BOOLEAN_KW
    d[YANG_TYPE_DECIMAL64] = YangToken.DECIMAL64
    d[YANG_TYPE_EMPTY] = YangToken.EMPTY
    d[YANG_TYPE_IDENTITYREF] = YangToken.IDENTITYREF
    d[YANG_TYPE_INSTANCE_IDENTIFIER] = YangToken.INSTANCE_IDENTIFIER
    d[YANG_TYPE_INT8] = YangToken.INT8_KW
    d[YANG_TYPE_INT16] = YangToken.INT16_KW
    d[YANG_TYPE_INT32] = YangToken.INT32_KW
    d[YANG_TYPE_INT64] = YangToken.INT64_KW
    d[YANG_TYPE_STRING] = YangToken.STRING_KW
    d[YANG_TYPE_UINT8] = YangToken.UINT8_KW
    d[YANG_TYPE_UINT16] = YangToken.UINT16_KW
    d[YANG_TYPE_UINT32] = YangToken.UINT32_KW
    d[YANG_TYPE_UINT64] = YangToken.UINT64_KW

    ## YANG_BOOL_* keywords
    d[YANG_BOOL_TRUE] = YangToken.TRUE
    d[YANG_BOOL_FALSE] = YangToken.FALSE

    ## YANG_STMT_* keywords
    d[YANG_STMT_MODULE] = YangToken.MODULE
    d[YANG_STMT_NAMESPACE] = YangToken.NAMESPACE
    d[YANG_STMT_PREFIX] = YangToken.PREFIX
    d[YANG_STMT_DESCRIPTION] = YangToken.DESCRIPTION
    d[YANG_STMT_REVISION] = YangToken.REVISION
    d[YANG_STMT_ORGANIZATION] = YangToken.ORGANIZATION
    d[YANG_STMT_CONTACT] = YangToken.CONTACT
    d[YANG_STMT_CONTAINER] = YangToken.CONTAINER
    d[YANG_STMT_GROUPING] = YangToken.GROUPING
    d[YANG_STMT_USES] = YangToken.USES
    d[YANG_STMT_REFINE] = YangToken.REFINE
    d[YANG_STMT_IF_FEATURE] = YangToken.IF_FEATURE
    d[YANG_STMT_AUGMENT] = YangToken.AUGMENT
    d[YANG_STMT_LIST] = YangToken.LIST
    d[YANG_STMT_KEY] = YangToken.KEY
    d[YANG_STMT_LEAF] = YangToken.LEAF
    d[YANG_STMT_LEAF_LIST] = YangToken.LEAF_LIST
    d[YANG_STMT_ANYDATA] = YangToken.ANYDATA
    d[YANG_STMT_ANYXML] = YangToken.ANYXML
    d[YANG_STMT_CHOICE] = YangToken.CHOICE
    d[YANG_STMT_CASE] = YangToken.CASE
    d[YANG_STMT_TYPE] = YangToken.TYPE
    d[YANG_STMT_UNION] = YangToken.UNION
    d[YANG_STMT_ENUM] = YangToken.ENUM
    d[YANG_STMT_MANDATORY] = YangToken.MANDATORY
    d[YANG_STMT_DEFAULT] = YangToken.DEFAULT
    d[YANG_STMT_MUST] = YangToken.MUST
    d[YANG_STMT_WHEN] = YangToken.WHEN
    d[YANG_STMT_RANGE] = YangToken.RANGE
    d[YANG_STMT_PATH] = YangToken.PATH
    d[YANG_STMT_FRACTION_DIGITS] = YangToken.FRACTION_DIGITS
    d[YANG_STMT_BIT] = YangToken.BIT
    d[YANG_STMT_BASE] = YangToken.BASE
    d[YANG_STMT_POSITION] = YangToken.POSITION
    d[YANG_STMT_REQUIRE_INSTANCE] = YangToken.REQUIRE_INSTANCE
    d[YANG_STMT_ERROR_MESSAGE] = YangToken.ERROR_MESSAGE
    d[YANG_STMT_MIN_ELEMENTS] = YangToken.MIN_ELEMENTS
    d[YANG_STMT_MAX_ELEMENTS] = YangToken.MAX_ELEMENTS
    d[YANG_STMT_ORDERED_BY] = YangToken.ORDERED_BY
    d[YANG_STMT_UNIQUE] = YangToken.UNIQUE
    d[YANG_STMT_TYPEDEF] = YangToken.TYPEDEF
    d[YANG_STMT_IDENTITY] = YangToken.IDENTITY
    d[YANG_STMT_PATTERN] = YangToken.PATTERN

    return d^
