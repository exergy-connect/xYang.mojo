## Experiment: YANG `must` constraints with a variable number of compile-time
## string parameters.
##
## Run with:
##
##   pixi run mojo examples/variadic_must.mojo
##
## Callers can write `YangMust["expr 1", "expr 2"]` directly instead of first
## packing the strings into an `InlineArray`.

trait YangMustConstraints:
    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        ...

    @staticmethod
    def yang_must_count() -> Int:
        ...

    @staticmethod
    def has_yang_must() -> Bool:
        ...


@fieldwise_init
struct YangMust[
    *conditions: StaticString,
](YangMustConstraints):
    @staticmethod
    def yang_must_condition[i: Int]() -> String:
        return String(Self.conditions[i])

    @staticmethod
    def yang_must_count() -> Int:
        return len(Self.conditions)

    @staticmethod
    def has_yang_must() -> Bool:
        return len(Self.conditions) > 0


def dump_must[T: YangMustConstraints]():
    print("count:", T.yang_must_count())
    comptime for i in range(T.yang_must_count()):
        print("  must", i, "=", T.yang_must_condition[i]())
    print("  has_yang_must:", T.has_yang_must())


def main():
    print("Empty variadic style")
    dump_must[YangMust[]]()

    print("")
    print("Single variadic style")
    dump_must[YangMust["../enabled = 'true'"]]()

    print("")
    print("Multiple variadic style")
    dump_must[
        YangMust[
            "../enabled = 'true'",
            "count(../item) > 0",
        ]
    ]()
