## Reflection sanity test: verify that emberjson.deserialize[T] correctly
## materializes the YANG AST structs when the input JSON is a hand-crafted,
## minimal example that EXACTLY matches the struct shapes (including `$schema`
## and `$id`). This does NOT test the full JSON Schema meta-model; that still
## uses the manual Value-based parser in xyang/json/parser.mojo.

from std.testing import assert_equal, assert_true, TestSuite
from std.memory import ArcPointer
from emberjson import deserialize, JsonDeserializable

comptime Arc = ArcPointer


@fieldwise_init
struct YangType(Defaultable, Movable, JsonDeserializable):
    var name: String

    def __init__(out self):
        self.name = ""


@fieldwise_init
struct YangLeaf(Defaultable, Movable, JsonDeserializable):
    var name: String
    var type: YangType
    var mandatory: Bool

    def __init__(out self):
        self.name = ""
        self.type = YangType()
        self.mandatory = False


@fieldwise_init
struct YangChoice(Defaultable, Movable, JsonDeserializable):
    var name: String
    var mandatory: Bool
    var case_names: List[String]

    def __init__(out self):
        self.name = ""
        self.mandatory = False
        self.case_names = []


@fieldwise_init
struct YangContainer(Defaultable, Movable, JsonDeserializable):
    var name: String
    var description: String
    var leaves: List[Arc[YangLeaf]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]

    def __init__(out self):
        self.name = ""
        self.description = ""
        self.leaves = []
        self.containers = []
        self.lists = []
        self.choices = []


@fieldwise_init
struct YangList(Defaultable, Movable, JsonDeserializable):
    var name: String
    var key: String
    var description: String
    var leaves: List[Arc[YangLeaf]]
    var containers: List[Arc[YangContainer]]
    var lists: List[Arc[YangList]]
    var choices: List[Arc[YangChoice]]

    def __init__(out self):
        self.name = ""
        self.key = ""
        self.description = ""
        self.leaves = []
        self.containers = []
        self.lists = []
        self.choices = []


@fieldwise_init
struct YangModule(Defaultable, Movable, JsonDeserializable):
    var `$schema`: String
    var `$id`: String
    var name: String
    var namespace: String
    var prefix: String
    var top_level_containers: List[Arc[YangContainer]]

    def __init__(out self):
        self.`$schema` = ""
        self.`$id` = ""
        self.name = ""
        self.namespace = ""
        self.prefix = ""
        self.top_level_containers = []


def test_deserialize_yang_module() raises:
    # Minimal JSON representing a YangModule with one container and one leaf.
    var json_str = """
    {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "urn:xframe:meta-model",
        "name": "meta-model",
        "namespace": "urn:xframe:meta-model",
        "prefix": "mm",
        "top_level_containers": [
            {
                "name": "data-model",
                "description": "Root container for data model definition",
                "leaves": [
                    {
                        "name": "name",
                        "type": { "name": \"string\" },
                        "mandatory": true
                    }
                ],
                "containers": [],
                "lists": [],
                "choices": []
            }
        ]
    }
    """

    var module = deserialize[YangModule](json_str)

    assert_equal(module.`$schema`, "https://json-schema.org/draft/2020-12/schema")
    assert_equal(module.`$id`, "urn:xframe:meta-model")
    assert_equal(module.name, "meta-model")
    assert_equal(module.namespace, "urn:xframe:meta-model")
    assert_equal(module.prefix, "mm")

    assert_true(len(module.top_level_containers) == 1)

    ref c = module.top_level_containers[0]
    assert_equal(c[].name, "data-model")
    assert_true(len(c[].leaves) == 1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
