## Validation error and severity for YANG document validation.

@fieldwise_init
struct Severity(Copyable, Movable):
    var value: String

    def __str__(self) -> String:
        return self.value


@fieldwise_init
struct ValidationError(Copyable, Movable):
    """
    A single validation failure.
    path: XPath-like location, e.g. /data-model/entities[name='foo']/name
    message: human-readable description
    expression: failing XPath or constraint expression, if any (empty = none)
    severity: error or warning
    """
    var path: String
    var message: String
    var expression: String
    var severity: Severity

    def __str__(self) -> String:
        var out = self.path + ": " + self.message
        if len(self.expression) > 0:
            out += " (expression: " + self.expression + ")"
        if self.severity.value != "error":
            out += " (severity: " + self.severity.value + ")"
        return out
