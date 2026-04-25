import xyang.ast as ast
from xyang.yang.parser.yang_token import (
    YANG_TYPE_ENUMERATION,
    YANG_TYPE_LEAFREF,
)

comptime YangType = ast.YangType
comptime YangTypePlain = ast.YangTypePlain
comptime YangTypeIntegerRange = ast.YangTypeIntegerRange
comptime YangTypeDecimal64 = ast.YangTypeDecimal64
comptime YangTypeEnumeration = ast.YangTypeEnumeration
comptime YangTypeLeafref = ast.YangTypeLeafref
comptime YangTypeBits = ast.YangTypeBits
comptime YangTypeIdentityref = ast.YangTypeIdentityref


def _yang_constraints_for_parsed_type(
    type_name: String,
    has_range: Bool,
    range_min: Int64,
    range_max: Int64,
    var enum_values: List[String],
    var leafref_path: String,
    leafref_require_instance: Bool,
    fraction_digits: Int,
    has_dec_range: Bool,
    dec_lo: Float64,
    dec_hi: Float64,
    var bits_names: List[String],
    var identityref_base: String,
) -> YangType.Constraints:
    if type_name == YANG_TYPE_ENUMERATION:
        return YangTypeEnumeration(enum_values^)
    if type_name == "decimal64":
        return YangTypeDecimal64(
            fraction_digits,
            has_dec_range,
            dec_lo,
            dec_hi,
        )
    if type_name == YANG_TYPE_LEAFREF:
        return YangTypeLeafref(
            leafref_path^,
            leafref_require_instance,
        )
    if type_name == "bits":
        return YangTypeBits(bits_names^)
    if type_name == "identityref":
        return YangTypeIdentityref(identityref_base^)
    if (
        type_name == "integer"
        or type_name == "int8"
        or type_name == "int16"
        or type_name == "int32"
        or type_name == "int64"
        or type_name == "uint8"
        or type_name == "uint16"
        or type_name == "uint32"
        or type_name == "uint64"
        or type_name == "number"
    ):
        return YangTypeIntegerRange(has_range, range_min, range_max)
    return YangTypePlain(_pad=0)
