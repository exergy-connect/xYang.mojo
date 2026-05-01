from xyang.validator.document import validate_yang_document


comptime YANG_PATH = "examples/basic_yang/basic-device.yang"
comptime DATA_PATH = "examples/basic_yang/basic-device.json"


def read_text(path: String) raises -> String:
    var text: String
    with open(path, "r") as f:
        text = f.read()
    return text^


def test_basic_yang_files_validate() raises:
    validate_yang_document(
        read_text(YANG_PATH),
        read_text(DATA_PATH),
        YANG_PATH,
        DATA_PATH,
    )


def main() raises:
    test_basic_yang_files_validate()
