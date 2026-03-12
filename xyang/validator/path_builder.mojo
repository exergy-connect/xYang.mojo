## Path builder for YANG document validation.
## Maintains the current path string as the walker descends.
## List entries use key predicates: /data-model/entities[name='foo']

struct PathBuilder:
    var _segments: List[String]

    def __init__(out self):
        self._segments = List[String]()

    def push(mut self, name: String, key: String = "") -> None:
        if len(key) > 0:
            self._segments.append(name + "[" + key + "]")
        else:
            self._segments.append(name)

    def pop(mut self) -> None:
        _ = self._segments.pop()

    def current(self) -> String:
        if len(self._segments) == 0:
            return "/"
        var out = ""
        for i in range(len(self._segments)):
            if i > 0:
                out += "/"
            out += self._segments[i]
        return "/" + out

    def child(self, name: String, key: String = "") -> String:
        var base = self.current()
        if base == "/":
            if len(key) > 0:
                return "/" + name + "[" + key + "]"
            return "/" + name
        if len(key) > 0:
            return base + "/" + name + "[" + key + "]"
        return base + "/" + name
