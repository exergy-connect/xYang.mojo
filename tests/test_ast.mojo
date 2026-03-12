from std.testing import assert_equal, assert_true, TestSuite
from emberjson import deserialize
from xyang.ast import YangModule


def test_deserialize_yang_module():
    # Minimal JSON representing a YangModule with one container and one leaf.
    var json_str = """
    {
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
                "containers": []
            }
        ]
    }
    """

    # NOTE: This succeeds only because the JSON is a hand-crafted, minimal
    # example that exactly matches the YangModule shape. Real meta-model
    # files like examples/meta-model.yang.json contain extra fields such as
    # "$schema" and "x-yang" that cannot be represented as Mojo struct fields
    # (invalid identifiers) and will cause EmberJson reflection to crash with
    # "Unexpected field" errors when using deserialize[YangModule](...).
    var module = deserialize[YangModule](json_str)

    assert_equal(module.name, "meta-model")
    assert_equal(module.namespace, "urn:xframe:meta-model")
    assert_equal(module.prefix, "mm")

    assert_true(len(module.top_level_containers) == 1)

    ref c = module.top_level_containers[0]
    assert_equal(c.name, "data-model")
    assert_true(len(c.leaves) == 1)


def main():
    TestSuite.discover_tests[__functions_in_module()]().run()

