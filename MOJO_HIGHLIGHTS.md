# Mojo highlights in xYang.mojo

This note calls out **Mojo-specific** language and library choices in this port, especially where they differ from the Python xYang codebase (garbage-collected references, uniform `dict`/`Any` trees, and implicit sharing).

---

## 1. Ownership and the transfer operator (`^`)

Mojo distinguishes **borrowed** values from **moved** (transferred) ones. Many APIs take `var` parameters or return owned values; transferring uses `^` on the last use of a value so the callee **owns** it and the caller must not use it again.

Examples in this repo:

- **CLI**: `_argv_list()` ends with `return lst^` — the `List[String]` is moved out to the caller (`xyang/cli.mojo`).
- **JSON generator**: building `Object` / `Array` values often ends with `return o^` or passes `arr^` into `Value(...)` so nested JSON owns its children (`xyang/json/generator.mojo`).
- **YANG parser**: appending to the AST uses `Arc[T](node^)` so the `Arc` constructor receives **ownership** of the freshly built node (`xyang/yang/parser.mojo`).

In Python, lists and dicts are always handles; “moving” is not part of the type system. Here, forgetting `^` or copying when a move was required shows up as **compile errors** (e.g. non-`ImplicitlyCopyable` types), not silent aliasing bugs.

---

## 2. `Arc` for shared, immutable-shaped trees

Python shares substructures by reference naturally (every object is a pointer under the hood). In Mojo, **`ArcPointer`** (aliased as `Arc` in several modules) wraps refcounted sharing for things like **nested containers, lists, leaves, and `must` statements**:

```7:7:xyang/ast.mojo
comptime Arc = ArcPointer
```

`List[Arc[YangLeaf]]`, `List[Arc[YangMust]]`, and recursive `List[Arc[YangType]]` on `union_types` model the same logical tree as Python’s object graph, but **sharing and lifetime** are explicit at the type level.

---

## 3. Destructors and manual XPath lifetime

Python relies on the cycle collector / refcount for tree-shaped ASTs. Mojo uses deterministic teardown: types that hold **heap-allocated XPath ASTs** implement `__del__` and free in a fixed order:

```24:28:xyang/ast.mojo
    fn __del__(deinit self):
        if self.leafref_xpath_ast:
            self.leafref_xpath_ast[].free_tree()
            self.leafref_xpath_ast.destroy_pointee()
            self.leafref_xpath_ast.free()
```

The same pattern appears on **`YangMust`** and **`YangWhen`** (free the parse tree, then the pointer). That matches the idea of “owning” an `ExprPointer` produced by `parse_xpath`, whereas Python would drop references and let the GC reclaim.

---

## 4. `raises`, `try` / `except`, and CLI exit codes

Functions that parse, validate, or perform I/O are marked **`raises`** where failure is modeled as errors (e.g. `parse_yang_file`, `parse_json_schema`, EmberJson `parse`). The top-level CLI wraps work in **`try` / `except`**, prints a message, and returns a **process exit code** via `std.sys.exit(run_cli())` in `main.mojo` — analogous to Python’s `sys.exit(main())`, but **return types** (`-> Int`) and **`raises`** are checked by the compiler.

---

## 5. Argument conventions: `read`, `ref`, `mut`, `var`

Mojo encodes mutability and borrowing in signatures:

- **`read x: T`**: immutable borrow (common for traversals: `read leaf: YangLeaf` in the JSON generator).
- **`ref`**: interior references into structs or JSON `Value` views — e.g. `ref pair in props_obj.items()` in `xyang/json/parser.mojo` to walk EmberJson objects without copying the whole tree.
- **`mut self`** on validators / builders where internal state changes.

Python has no equivalent split; “const correctness” is only by convention.

---

## 6. `Optional` vs Python `None`

Optional fields use **`Optional[YangWhen]`** with `.value()` / `.has_when()`-style accessors in the AST traits, instead of `when: Optional[...] = None` with arbitrary `None` checks. Unwrapping is **typed**; missing `Optional` handling tends to fail at compile time rather than at `AttributeError` time.

---

## 7. `comptime` constants and aliases

Shared spellings (e.g. `Arc = ArcPointer`, JSON / `x-yang` key strings in `xyang/json/schema_keys.mojo`, CLI version in `xyang/cli.mojo`) use **`comptime`** so they are resolved at compile time with zero runtime cost — similar in spirit to module-level constants in Python, but integrated into the **parametric** compilation model.

---

## 8. `@fieldwise_init` structs vs Python `@dataclass`

AST nodes are **`@fieldwise_init` structs** (`YangModule`, `YangLeaf`, …) with generated memberwise constructors. They are **`Movable`** and often **`JsonDeserializable`** for EmberJson reflection, not open-ended classes with `__dict__`. That trades flexibility for **predictable layout** and **clear ownership** of every field.

---

## 9. EmberJson `Value` / `Object` vs Python `dict[str, Any]`

The JSON path uses **typed JSON values** (`Value`, `Object`, `Array`) from EmberJson instead of plain Python dicts. Navigation uses **`.object()`, `.string()`, `.is_array()`**, etc. (`xyang/json/parser.mojo`). Building schema output constructs **`Object`** trees explicitly (`xyang/json/generator.mojo`). This is closer to “typed document API” than Python’s uniform `dict` + `json.loads`, and interacts with Mojo’s **move / copy** rules when stuffing values into maps and arrays.

---

## 10. CLI: `argv()` and `StaticString`

`std.sys.argv()` yields a **`Span` of `StaticString`** (program arguments tied to static storage). The CLI copies them into owned **`String`** values for parsing (`String(sp[i])` in `xyang/cli.mojo`). Python’s `sys.argv` is already a list of distinct `str` objects; here the extra step makes **ownership and lifetime** of the argument list obvious.

---

## 11. Name clashes with the language

Identifiers that are natural in Python may be **reserved in Mojo** (e.g. `module`). The CLI uses names like **`yang_module`** where Python would say `module` (`xyang/cli.mojo`).

---

## 12. Traits for cross-cutting AST behavior

**Traits** such as `YangHasMustStatements` / `YangHasWhen` (`xyang/ast.mojo`) group leaves and leaf-lists that carry `must` / `when` metadata. Python would typically use a shared base class or structural typing; Mojo requires **explicit trait conformance** on structs that participate.

---

### Summary table

| Topic | Python xYang (typical) | xYang.mojo |
|--------|-------------------------|------------|
| Tree ownership | Reference cycles + GC | `Arc`, `^` transfer, explicit `__del__` for XPath |
| JSON tree | `dict` / `Any` | EmberJson `Value` / `Object` / `Array` |
| Optional data | `None` | `Optional[T]` |
| Failure modes | Exceptions (unchecked by types) | `raises` + `try` / `except` where declared |
| Shared subtrees | Implicit aliasing | `Arc[T]` + move into `Arc` |
| CLI args | `sys.argv: list[str]` | `argv()` → copy to `List[String]` |

This project leans on those Mojo features to keep **memory and sharing visible in types**, at the cost of more ceremony than the Python reference implementation.
