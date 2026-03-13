from emberjson import deserialize, JsonDeserializable, Value


@fieldwise_init
struct ValueWrapper(Movable, JsonDeserializable):
    var properties: Value


def main():
    # Minimal JSON object that matches ValueWrapper's single field.
    # On Mojo 0.26.1 with EmberJson reflection, this call triggers a
    # compile-time error like:
    #
    #   cannot reference parametric function
    #
    # inside emberjson/_deserialize/reflection.mojo when instantiating
    # deserialize[ValueWrapper], because the struct contains a Value field.
    #
    # This file is an executable repro for the
    # \"cannot reference parametric function\" reflection bug when a
    # JsonDeserializable struct has a Value-typed field.
    var json = "{\"properties\": {}}"
    var wrapper = deserialize[ValueWrapper](json)
    print(wrapper.properties.is_object())

