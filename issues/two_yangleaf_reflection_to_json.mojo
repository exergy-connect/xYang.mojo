## Standalone: `YangModeled` struct with two `YangLeaf` fields → `YangConstruct` via reflection.
##
## Run (after `pixi run package`):
##   pixi run mojo -I build -I . issues/two_yangleaf_reflection_to_json.mojo
##
## Uses ``xyang.api.reflection`` (not ``YangModel`` schema packs).

from xyang.api.model import validate_yang_subtree, yang_module_from_model
from xyang.api.reflection import (
    YangBuiltinString,
    YangBuiltinUInt16,
    YangConstraints,
    YangLeaf,
    YangModeled,
    reflection_append_model_fields,
    reflection_instance_to_construct,
)
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.module import YangModule


@fieldwise_init
struct CatalogLine(Defaultable, ImplicitlyDestructible, Movable, YangModeled):
    var title: YangLeaf[YangBuiltinString, YangConstraints[]]
    var units: YangLeaf[YangBuiltinUInt16, YangConstraints[]]

    def __init__(out self):
        self.title = YangLeaf[YangBuiltinString, YangConstraints[]]()
        self.units = YangLeaf[YangBuiltinUInt16, YangConstraints[]]()
        self.title.value = String()
        self.units.value = 0

    @staticmethod
    def yang_container_name() -> String:
        return "catalog_line"

    @staticmethod
    def comptime_validate(read module: YangModule) raises:
        validate_yang_subtree[Self](module)

    @staticmethod
    def append_model_fields(mut parent: YangConstruct) raises:
        reflection_append_model_fields[Self](parent)


def main() raises:
    var m = yang_module_from_model[CatalogLine](
        "two-leaf-demo",
        "urn:example:two-leaf-demo",
        "tld",
    )
    CatalogLine.comptime_validate(m)
    var row = CatalogLine()
    row.title.value = "mug"
    row.units.value = 3
    print(reflection_instance_to_construct[CatalogLine](row).format(0))
