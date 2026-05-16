## Minimal repro for the former JsonValue.to_string latency issue.
##
## Run:
##   pixi run package
##   pixi run bash -lc 'timeout 20s mojo -I build -I "$PWD/.pixi/envs/default/lib/mojo" issues/json_value_to_string_compile_time_repro.mojo'
##
## Before removing the scalar function-pointer dispatch table in
## `xyang/json/value.mojo`, this timed out after 20s even for a scalar value.

from xyang.json.parser import parse_json


def main() raises:
    var value = parse_json('"ok"', "json-value-to-string-repro.json")
    print(value.to_string())
