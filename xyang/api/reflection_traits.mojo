## Traits used by the reflection-based ``YangModeled`` field walk.

from xyang.yang.ast.construct import YangConstruct


trait YangSchemaFieldEmitter:
    """Append one schema-only ``leaf`` / ``container`` / ``list`` child to ``parent``."""

    def append_schema_field(
        read self, read name: String, mut parent: YangConstruct
    ) raises:
        ...


trait YangInstanceConstructEmitter:
    """Append one instance field (``leaf`` with ``value``, nested ``container``, …)."""

    def append_instance_field(
        read self, read name: String, mut parent: YangConstruct
    ) raises:
        ...
