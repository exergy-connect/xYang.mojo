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

    ## YANG_TYPE_* keywords
    comptime LEAFREF: Self.Type = 11
    comptime ENUMERATION: Self.Type = 12
    comptime BINARY: Self.Type = 13
    comptime BITS: Self.Type = 14
    comptime BOOLEAN_KW: Self.Type = 15
    comptime DECIMAL64: Self.Type = 16
    comptime EMPTY: Self.Type = 17
    comptime IDENTITYREF: Self.Type = 18
    comptime INSTANCE_IDENTIFIER: Self.Type = 19
    comptime INT8_KW: Self.Type = 20
    comptime INT16_KW: Self.Type = 21
    comptime INT32_KW: Self.Type = 22
    comptime INT64_KW: Self.Type = 23
    comptime STRING_KW: Self.Type = 24
    comptime UINT8_KW: Self.Type = 25
    comptime UINT16_KW: Self.Type = 26
    comptime UINT32_KW: Self.Type = 27
    comptime UINT64_KW: Self.Type = 28

    ## YANG_BOOL_* keywords
    comptime TRUE: Self.Type = 29
    comptime FALSE: Self.Type = 30

    ## YANG_STMT_* keywords
    comptime MODULE: Self.Type = 31
    comptime NAMESPACE: Self.Type = 32
    comptime PREFIX: Self.Type = 33
    comptime DESCRIPTION: Self.Type = 34
    comptime REVISION: Self.Type = 35
    comptime ORGANIZATION: Self.Type = 36
    comptime CONTACT: Self.Type = 37
    comptime CONTAINER: Self.Type = 38
    comptime GROUPING: Self.Type = 39
    comptime USES: Self.Type = 40
    comptime REFINE: Self.Type = 41
    comptime IF_FEATURE: Self.Type = 42
    comptime AUGMENT: Self.Type = 43
    comptime LIST: Self.Type = 44
    comptime KEY: Self.Type = 45
    comptime LEAF: Self.Type = 46
    comptime LEAF_LIST: Self.Type = 47
    comptime ANYDATA: Self.Type = 48
    comptime ANYXML: Self.Type = 49
    comptime CHOICE: Self.Type = 50
    comptime CASE: Self.Type = 51
    comptime TYPE: Self.Type = 52
    comptime UNION: Self.Type = 53
    comptime ENUM: Self.Type = 54
    comptime MANDATORY: Self.Type = 55
    comptime DEFAULT: Self.Type = 56
    comptime MUST: Self.Type = 57
    comptime WHEN: Self.Type = 58
    comptime RANGE: Self.Type = 59
    comptime PATH: Self.Type = 60
    comptime FRACTION_DIGITS: Self.Type = 61
    comptime BIT: Self.Type = 62
    comptime BASE: Self.Type = 63
    comptime POSITION: Self.Type = 64
    comptime REQUIRE_INSTANCE: Self.Type = 65
    comptime ERROR_MESSAGE: Self.Type = 66
    comptime MIN_ELEMENTS: Self.Type = 67
    comptime MAX_ELEMENTS: Self.Type = 68
    comptime ORDERED_BY: Self.Type = 69
    comptime UNIQUE: Self.Type = 70

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
