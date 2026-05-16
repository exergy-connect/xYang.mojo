## Minimal compile/runtime latency repro for YangModule ingestion.
##
## Run:
##   pixi run package
##   pixi run bash -lc 'timeout 20s mojo -I build -I "$PWD/.pixi/envs/default/lib/mojo" issues/build_spec_table_compile_time_repro.mojo'
##
## Observed on Mojo 1.0.0b2.dev2026051506:
## - Importing `build_spec_table` is fast.
## - Constructing one RuntimeConstructSpec row is fast.
## - Filling a small RuntimeConstructSpec.Table is fast.
## - Calling `build_spec_table()` does not finish within 20s.
##
## This is the small trigger behind slow examples that call:
## - YangModule.parse(...)
## - YangModule.ingest_construct_tree(...)
## - yang_module_from_model(...)

from xyang.yang.spec import build_spec_table


def main() raises:
    var specs = build_spec_table()
    print(len(specs))
