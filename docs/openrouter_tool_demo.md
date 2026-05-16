# OpenRouter Tool-Calling Demo

This Mojo demo calls OpenRouter's free model router with an OpenAI-style
function tool. Product names are part of a compile-time catalog, and the tool
parameter JSON Schema is projected from an xYang-modeled Mojo struct, so the
model only sees the currently valid product-name enum.

## Run

```bash
pixi run package
OPENROUTER_API_KEY=... pixi run openrouter-demo
```

By default the demo uses:

```text
OPENROUTER_MODEL=openrouter/free
```

You can override it with any OpenRouter model that supports tool calls:

```bash
OPENROUTER_MODEL='some/provider-model:free' pixi run openrouter-demo
```

## What It Shows

- `examples/openrouter_tool_demo.mojo` owns the compile-time product catalog,
  the `QuoteRequest` xYang model, response parsing, validation, and callback
  dispatch.
- `QuoteRequest.product_name` is a `YangEnum[...]` specialized from the
  compile-time product names.
- The OpenRouter function `parameters` object is extracted from
  `yang_module_from_model[QuoteRequest]` and `yang_module_to_json_schema`.
- The model returns a `tool_calls` assistant message.
- The callback wraps the raw arguments as `{"quote_request": ...}` and calls
  `validate_data` in-process against the embedded YANG contract.

If validation fails, the callback does not execute. For example, an unknown SKU
or a quantity outside `1..20` is rejected by xYang before catalog logic runs.
