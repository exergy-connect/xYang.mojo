## Type-level key/value pairs for building dense handler dispatch tables.
##
## This variant bounds recursive dispatch by using two different handler tables:
## `dispatch_a` uses `HANDLERS_A`, and recursive calls made by handlers use
## `dispatch_b` with `HANDLERS_B`. `dispatch_b` passes `dispatch_stop` onward,
## so the compiler does not see an unbounded parameter-domain recursion cycle.
##
##   pixi run mojo examples/handlers.mojo

comptime Kw = UInt8
comptime `<INVALID>`: Kw = 0
comptime `leaf`: Kw = 1
comptime `container`: Kw = 2
comptime `list`: Kw = 3
comptime KEYWORD_COUNT: Int = 4

comptime Dispatcher = def(keyword: Kw, name: String) raises thin -> None
comptime Handler = def(dispatcher: Dispatcher, name: String) raises thin -> None


@no_inline
def validate_unknown(dispatcher: Dispatcher, name: String) raises -> None:
    print("unknown:", name)


@no_inline
def validate_leaf(dispatcher: Dispatcher, name: String) raises -> None:
    print("leaf:", name)


@no_inline
def validate_container(dispatcher: Dispatcher, name: String) raises -> None:
    print("container:", name)
    dispatcher(`leaf`, name + "/child")


@no_inline
def validate_list(dispatcher: Dispatcher, name: String) raises -> None:
    print("list:", name)


trait HandlerMapping:
    comptime kw: Kw
    comptime callback: Handler


struct HandlerKV[key: Kw, handler: Handler](HandlerMapping):
    comptime kw = Self.key
    comptime callback = Self.handler


@always_inline
def handler_dispatch_table[
    *mappings: HandlerMapping
](default_handler: Handler) -> InlineArray[Handler, KEYWORD_COUNT]:
    var table = InlineArray[Handler, KEYWORD_COUNT](fill=default_handler)
    comptime for i in range(len(mappings)):
        table[mappings[i].kw] = mappings[i].callback
    return table^


comptime HANDLERS_A = handler_dispatch_table[
    HandlerKV[`leaf`, validate_leaf],
    HandlerKV[`container`, validate_container],
    HandlerKV[`list`, validate_list],
](validate_unknown)

comptime HANDLERS_B = handler_dispatch_table[
    HandlerKV[`leaf`, validate_leaf],
    HandlerKV[`container`, validate_unknown],
    HandlerKV[`list`, validate_list],
](validate_unknown)


@no_inline
def dispatch_a(keyword: Kw, name: String) raises -> None:
    HANDLERS_A[keyword](dispatch_b, name)


@no_inline
def dispatch_b(keyword: Kw, name: String) raises -> None:
    HANDLERS_B[keyword](dispatch_stop, name)


@no_inline
def dispatch_stop(keyword: Kw, name: String) raises -> None:
    print("stop:", name)


def main() raises:
    dispatch_a(`container`, "interfaces")
