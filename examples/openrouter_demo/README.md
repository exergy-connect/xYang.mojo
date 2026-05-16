# OpenRouter Tool-Calling Demo

This demo calls an OpenRouter-hosted free model with an OpenAI-style function
tool from Mojo. Product names are compile-time data, so the function parameter
schema exposes exactly the product names in the current catalog.

## Run

```bash
pixi run package
OPENROUTER_API_KEY=... pixi run openrouter-demo
```

By default the demo uses OpenRouter's free router:

```text
OPENROUTER_MODEL=openrouter/free
```

Override it with any OpenRouter model that supports tool calls:

```bash
OPENROUTER_MODEL='some/provider-model:free' pixi run openrouter-demo
```

## What It Shows

- `demo.mojo` owns the compile-time product catalog.
- `QuoteRequest.product_name` is a `YangEnum[...]` specialized from that catalog.
- `_tool_parameters_json()` projects the tool parameter schema from the modeled
  descriptors, including the product-name enum and quantity range.
- The returned OpenRouter `tool_calls` envelope is modeled with
  `OpenRouterToolCalls`, `OpenRouterToolCall`, and `OpenRouterToolFunction`.
- Callback arguments are wrapped as `{"quote_request": ...}` and validated with
  xYang before the local quote function runs.

If validation fails, the callback does not execute. For example, an unknown
product name or a quantity outside `1..20` is rejected before catalog logic.
