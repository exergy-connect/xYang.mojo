from emberjson import deserialize, JsonDeserializable


@fieldwise_init
struct SchemaWrapper(Movable, JsonDeserializable):
    var name: String


def main():
    # Minimal JSON object that includes a `$schema` field which is NOT present
    # in the SchemaWrapper struct. Reflection deserialization will treat this
    # as an unexpected field and crash with an error like:
    #
    #   Unexpected field: $schema
    #
    # This file serves as an executable repro for the issue documented in
    # `issues/reflection-deserialization-$schema.md`. Running:
    #
    #   pixi run mojo 'issues/reflection-deserialization-$schema.mojo'
    #
    # currently produces:
    #
    #   Unhandled exception caught during execution: Unexpected field: $schema
    #
    # which demonstrates that EmberJson's reflection cannot ignore or alias
    # unknown fields like `$schema` that have no corresponding struct fields.
    var json = """
    {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "name": "example"
    }
    """

    # This call is expected to fail at runtime with the error above.
    var wrapper = deserialize[SchemaWrapper](json)
    print(wrapper.name)

