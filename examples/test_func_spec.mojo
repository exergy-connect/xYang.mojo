comptime Cardinality = UInt8
comptime `0`   : Cardinality = 0
comptime `1`   : Cardinality = 1
comptime `0..1`: Cardinality = 2
comptime `0..n`: Cardinality = 3
comptime `1..n`: Cardinality = 4

comptime Kw = UInt8
comptime `description` : Kw = 0
comptime `error-message` : Kw = 1
comptime KEYWORD_COUNT: Int = 2
comptime RuleTable = InlineArray[Cardinality, KEYWORD_COUNT]

comptime FIELD = Tuple[Kw, Cardinality]

def fields[n: Int](*fieldlist: FIELD) -> RuleTable:
    var table = InlineArray[Cardinality, KEYWORD_COUNT](fill=`0`)
    comptime for i in range(n):
        table[Int(fieldlist[i][0])] = fieldlist[i][1]
    return table

comptime MUST_FIELDS = fields[2]((`description`, `0..1`), (`error-message`, `1`))

def main() raises:
    print(MUST_FIELDS)