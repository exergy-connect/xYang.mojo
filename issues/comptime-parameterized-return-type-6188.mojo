## Minimal repro: comptime-parameterized return types
## https://github.com/modularml/mojo/issues/6188
##
## Intended spelling (see issue + maintainer comment): return type may depend on
## comptime parameters, e.g. `-> T1 if cond else T2`, with both arms sharing a
## trait bound.
##
## Mojo 0.26.2: plain `return a` / `return b` still fails against `-> T1 if … else T2`.
## Explicit cast: `comptime R = T1 if want_int else T2` then `rebind[R](…).copy()` so
## the return value is a `Copyable` value of the conditional type.

from std.testing import assert_equal, TestSuite


def pick[
    want_int: Bool,
    T1: Writable & Copyable,
    T2: Writable & Copyable,
](a: T1, b: T2) -> T1 if want_int else T2:
    comptime R = T1 if want_int else T2
    comptime if want_int:
        return rebind[R](a.copy()).copy()
    else:
        return rebind[R](b.copy()).copy()


def test_pick() raises:
    var got_int = pick[True](7, "seven")
    var got_str = pick[False](7, "seven")
    assert_equal(got_int, 7)
    assert_equal(got_str, "seven")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
