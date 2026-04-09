## Cross-module SIGSEGV repro (exit 139). Do not bulk-replace from xyang.
##
##   pixi run mojo -I tests/crash tests/crash/repro_cross_module/main.mojo

from std.memory import ArcPointer

from repro_cross_module.evaluator import Expr, Token, XPathEvaluator, XPathNode

def main() raises:
    var root = ArcPointer[XPathNode](XPathNode("/"))
    var ex = "'hello'"
    var tok = Token(type=Token.STRING, start=0, length=7, line=1)
    var ptr = Expr.string(tok)
    var ev = XPathEvaluator()
    _ = ev.eval(ptr, root, ex)
