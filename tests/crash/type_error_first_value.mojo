## Standalone latent type_error repro for `_first_value`.
##
## Run:
##   pixi run mojo -I . tests/crash/type_error_first_value.mojo
##
## Behavior:
##   This file compiles because `_first_value` is never instantiated from a
##   call site. The invalid conversion remains latent in function body.

from std.collections import List
from std.utils import Variant

comptime EvalResult = Variant[List[Int]]

def _first_value(result: EvalResult) -> EvalResult:    
    var r = result
    ref nodes = r[List[Int]]
    if len(nodes) > 0:
        return EvalResult(nodes[0]) # This is a type error
    return result

def main() raises:
    # Intentionally do not call `_first_value`; keeps the type error latent.
    pass
