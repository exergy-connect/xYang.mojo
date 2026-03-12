## Top-level YANG validator: validates data (JSON Value) against a YangModule.
## Returns (is_valid, errors, warnings) as in the Python xYang validator.

from emberjson import Value
from xyang.ast import YangModule
from xyang.validator.document_validator import DocumentValidator
from xyang.validator.validation_error import ValidationError, Severity


@fieldwise_init
struct ValidationResult:
    var is_valid: Bool
    var errors: List[String]
    var warnings: List[String]


struct YangValidator:
    var _doc_validator: DocumentValidator

    def __init__(out self):
        self._doc_validator = DocumentValidator()

    def validate(mut self, data: Value, module: YangModule) -> ValidationResult:
        var doc_errors = self._doc_validator.validate(module, data)
        var errors = List[String]()
        var warnings = List[String]()
        for i in range(len(doc_errors)):
            ref e = doc_errors[i]
            var msg = _format_error(e)
            if e.severity.value == "error":
                errors.append(msg)
            else:
                warnings.append(msg)
        return ValidationResult(
            is_valid=len(errors) == 0,
            errors=errors^,
            warnings=warnings^,
        )


def _format_error(e: ValidationError) -> String:
    if len(e.expression) > 0:
        return e.path + ": " + e.message + " (expression: " + e.expression + ")"
    return e.path + ": " + e.message
