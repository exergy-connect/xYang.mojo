## Reflection-based xYang API: ``YangModeled`` structs with ``YangLeaf`` / container fields.
##
## Import this module **or** use the struct-based schema API from ``xyang.api``
## (``YangModel`` / ``YangField`` packs). Both paths share descriptor types from
## ``types.mojo``; pick one style per model.
##
##     struct Cart(Defaultable, ImplicitlyDestructible, Movable, YangModeled):
##         var sku: YangLeaf[YangBuiltinString, YangConstraints[]]
##         @staticmethod
##         def yang_container_name() -> String: return "cart"
##         @staticmethod
##         def append_model_fields(mut parent: YangConstruct) raises:
##             reflection_append_model_fields[Self](parent)
##
## Instance values → ``YangConstruct``: :func:`reflection_instance_to_construct`.

from std.reflection import reflect

from xyang.yang.ast.construct import YangConstruct

from .reflection_traits import (
    YangInstanceConstructEmitter,
    YangSchemaFieldEmitter,
)
from .types import (
    YangBuiltinBool,
    YangBuiltinDescriptor,
    YangBuiltinInt8,
    YangBuiltinInt16,
    YangBuiltinInt32,
    YangBuiltinInt64,
    YangBuiltinString,
    YangBuiltinUInt8,
    YangBuiltinUInt16,
    YangBuiltinUInt32,
    YangBuiltinUInt64,
    YangConstraints,
    YangContainer,
    YangEnum,
    YangLeaf,
    YangLeafList,
    YangLeafValueReadable,
    YangList,
    YangModeled,
    _model_stmt,
    _reflection_append_instance_fields,
)


def reflection_field_count[T: YangModeled]() -> Int:
    return reflect[T].field_count()


def reflection_field_name[T: YangModeled, i: Int]() -> String:
    return String(reflect[T].field_names()[i])


def reflection_append_model_fields[
    T: YangModeled & Defaultable & ImplicitlyDestructible,
](mut parent: YangConstruct) raises:
    """Append schema-only ``leaf`` / ``container`` / ``list`` children (no ``value``)."""

    var scratch = T()
    comptime ri = reflect[T]
    comptime for i in range(ri.field_count()):
        comptime nm = String(ri.field_names()[i])
        trait_downcast[YangSchemaFieldEmitter](
            ri.field_ref[i](scratch)
        ).append_schema_field(nm, parent)


def reflection_append_instance_fields[T: YangModeled](
    read instance: T, mut parent: YangConstruct
) raises:
    """Append instance children (``leaf`` with ``value``, nested ``container``, …)."""

    _reflection_append_instance_fields[T](instance, parent)


def reflection_instance_to_construct[T: YangModeled](
    read instance: T,
) raises -> YangConstruct:
    """Build a top-level ``container`` ``YangConstruct`` from a modeled instance."""

    var root = _model_stmt("container", T.yang_container_name())
    reflection_append_instance_fields[T](instance, root)
    return root^
