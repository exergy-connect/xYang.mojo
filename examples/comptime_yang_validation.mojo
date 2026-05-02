## Toy “thermostat service” with **type-level YANG hints** on fields and a matching
## **JSON Schema + `x-yang` tree** that is parsed through `parse_yang_json_module`
## at **compile time**. If the JSON shape drifts from what the validator accepts,
## this file fails to compile.
##
## The Mojo structs are only documentation + ergonomics for app code; the
## authoritative schema lives in the embedded JSON (same idea as generating
## bindings from YANG/JSON Schema in larger systems).
##
##   pixi run package
##   export MODULAR_MOJO_IMPORT_PATH="$PWD/.pixi/envs/default/lib/mojo"
##   pixi run mojo -I build -I "$MODULAR_MOJO_IMPORT_PATH" examples/comptime_yang_validation.mojo

from xyang.json import parse_yang_json_module


## --- Type-level YANG metadata (toy “annotations” on data members) ------------


@fieldwise_init
struct YangLeaf[
    leaf_name: StringLiteral,
    yang_builtin_type: StringLiteral,
    Value: Writable & Copyable & Movable & ImplicitlyDestructible & Defaultable,
](ImplicitlyDestructible, Movable):
    var value: Self.Value

    @staticmethod
    def yang_name() -> String:
        return String(Self.leaf_name)

    @staticmethod
    def yang_type() -> String:
        return String(Self.yang_builtin_type)


@fieldwise_init
struct YangContainer[
    container_name: StringLiteral,
    Child: Movable & ImplicitlyDestructible,
](ImplicitlyDestructible, Movable):
    var body: Self.Child

    @staticmethod
    def yang_name() -> String:
        return String(Self.container_name)


## --- Application data model (mirrors JSON `properties` / `x-yang` tree) -----


@fieldwise_init
struct ThermostatSystem(ImplicitlyDestructible, Movable):
    ## `leaf hostname { type string; … }`
    var hostname: YangLeaf["hostname", "string", String]
    ## `leaf enabled { type boolean; … }`
    var enabled: YangLeaf["enabled", "boolean", Bool]


@fieldwise_init
struct ThermostatApp(ImplicitlyDestructible, Movable):
    ## `container system { … }`
    var system: YangContainer["system", ThermostatSystem]


## Embedded program/schema as JSON (container + leaves with `x-yang`).

comptime APP_SCHEMA_JSON = """{
  "x-yang": {
    "module": "thermostat-app",
    "yang-version": "1.1",
    "namespace": "urn:example:thermostat-app",
    "prefix": "ta"
  },
  "description": "Toy thermostat configuration surface",
  "type": "object",
  "properties": {
    "system": {
      "type": "object",
      "description": "Device system settings",
      "x-yang": {"type": "container"},
      "properties": {
        "hostname": {
          "type": "string",
          "maxLength": 253,
          "description": "DNS hostname",
          "x-yang": {"type": "leaf"}
        },
        "enabled": {
          "type": "boolean",
          "description": "Telemetry enabled",
          "x-yang": {"type": "leaf"}
        }
      }
    }
  }
}"""


## Lock: embedded JSON is parsed + validated while compiling this module.
## `comptime` cannot call `raises` functions directly; the wrapper swallows
## errors and `comptime assert` turns a bad schema into a compile failure.
def _embedded_schema_parse_ok() -> Bool:
    try:
        _ = parse_yang_json_module(
            String(APP_SCHEMA_JSON), "thermostat-app.json"
        )
        return True
    except:
        return False


comptime _THERMOSTAT_SCHEMA_OK: Bool = _embedded_schema_parse_ok()


def main() raises:
    comptime assert _THERMOSTAT_SCHEMA_OK, (
        "examples/comptime_yang_validation.mojo: embedded APP_SCHEMA_JSON"
        " failed JSON parse or YANG construct validation"
    )
    var module = parse_yang_json_module(
        String(APP_SCHEMA_JSON), "thermostat-app.json"
    )
    print("Comptime-checked JSON schema module: " + module.get_name())
    print(
        "Mojo model hints: container `"
        + YangContainer["system", ThermostatSystem].yang_name()
        + "` holds leaves `"
        + YangLeaf["hostname", "string", String].yang_name()
        + "` ("
        + YangLeaf["hostname", "string", String].yang_type()
        + ") and `"
        + YangLeaf["enabled", "boolean", Bool].yang_name()
        + "` ("
        + YangLeaf["enabled", "boolean", Bool].yang_type()
        + ")."
    )
