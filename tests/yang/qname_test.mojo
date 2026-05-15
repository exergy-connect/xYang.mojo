## One YANG module exercising every argument shape that allows a QName
## (`identifier-ref`, `node-identifier` lists, `descendant-schema-nodeid`,
## and schema paths with prefixed steps). Parsed with `YangModule::parse`.

from std.memory import ArcPointer
from std.testing import TestSuite, assert_true

from xyang.yang.arguments import (
    KeyArgument,
    PathArgument,
    QNameArgument,
    TypeArgument,
    UniqueArgument,
    XPathExpressionArgument,
)
from xyang.yang.ast.construct import YangConstruct
from xyang.yang.ast.lexer import AstLexer
from xyang.yang.ast.module import YangModule

comptime Arc = ArcPointer


def _find_first_keyword(
    read root: Arc[YangConstruct], read kw: String
) -> Optional[Arc[YangConstruct]]:
    ref node = root[]
    if node.keyword == kw:
        return Optional[Arc[YangConstruct]](root.copy())
    for i in range(len(node.children)):
        var inner = _find_first_keyword(node.children[i], kw)
        if inner:
            return inner
    return Optional[Arc[YangConstruct]]()


def _find_keyword_under(
    read root: Arc[YangConstruct], read kw: String, read arg: String
) -> Optional[Arc[YangConstruct]]:
    ## First descendant with `keyword` and argument text `arg`.
    ref node = root[]
    if node.keyword == kw and node.argument_text() == arg:
        return Optional[Arc[YangConstruct]](root.copy())
    for i in range(len(node.children)):
        var inner = _find_keyword_under(node.children[i], kw, arg)
        if inner:
            return inner
    return Optional[Arc[YangConstruct]]()


def test_qname_module_parses_and_payloads() raises:
    ## RFC 7950 §14: `base`, `type`, `uses` use `identifier-ref`; `key` uses
    ## `node-identifier` tokens; `unique` uses `descendant-schema-nodeid`
    ## tokens; `augment` / leafref `path` use schema paths with
    ## `node-identifier` steps.
    var yang_text = String(
        """
module ex-mod {
  yang-version 1.1;
  namespace "urn:ex";
  prefix ex;

  identity id-root;

  identity id-sub {
    base ex:id-root;
  }

  typedef ex-int {
    type uint32;
  }

  grouping ex-group {
    leaf g {
      type string;
    }
  }

  container top {
    leaf scalar {
      type ex:ex-int;
    }
    leaf owner-kind {
      type identityref {
        base ex:id-root;
      }
    }
    uses ex:ex-group {
      when "not(boolean(./scalar))";
      description "conditional grouping use";
      refine g {
        mandatory false;
        must "string-length(.) >= 0";
      }
    }

    list row {
      key "id ex:aux";
      unique "name ex:extra/nested";
      leaf id {
        type string;
      }
      leaf aux {
        type string;
      }
      leaf name {
        type string;
      }
      container extra {
        leaf nested {
          type string;
        }
      }
      leaf lr {
        type leafref {
          path "/ex:top/ex:scalar";
        }
      }
    }
  }

  augment "/ex:top/ex:row" {
    leaf aug-leaf {
      type string;
    }
  }
}
"""
    )
    var lexer = AstLexer(yang_text.as_bytes())
    var mod = YangModule()
    mod.parse(lexer)
    assert_true(mod.root)
    var root_arc = mod.root.value()

    var base = _find_first_keyword(root_arc, "base")
    assert_true(base)
    assert_true(base.value()[].argument.isa[QNameArgument]())

    var uses_top = _find_keyword_under(root_arc, "uses", "ex:ex-group")
    assert_true(uses_top)
    assert_true(uses_top.value()[].argument.isa[QNameArgument]())
    var uses_when = _find_keyword_under(
        uses_top.value(), "when", "not(boolean(./scalar))"
    )
    assert_true(uses_when)
    assert_true(uses_when.value()[].argument.isa[XPathExpressionArgument]())
    var refine_stmt = _find_keyword_under(uses_top.value(), "refine", "g")
    assert_true(refine_stmt)
    assert_true(refine_stmt.value()[].argument.isa[PathArgument]())

    var scalar_ty = _find_keyword_under(root_arc, "type", "ex:ex-int")
    assert_true(scalar_ty)
    assert_true(scalar_ty.value()[].argument.isa[TypeArgument]())
    ref scalar_type_arg = scalar_ty.value()[].argument.get[TypeArgument]()
    assert_true(scalar_type_arg.is_derived())
    assert_true(scalar_type_arg.prefix == "ex")
    assert_true(scalar_type_arg.local_name == "ex-int")

    var key_stmt = _find_first_keyword(root_arc, "key")
    assert_true(key_stmt)
    assert_true(key_stmt.value()[].argument.isa[KeyArgument]())

    var unique_stmt = _find_first_keyword(root_arc, "unique")
    assert_true(unique_stmt)
    assert_true(unique_stmt.value()[].argument.isa[UniqueArgument]())
    ref uarg = unique_stmt.value()[].argument.get[UniqueArgument]()
    assert_true(len(uarg.paths) == 2)
    assert_true(uarg.paths[0].text == "name")
    assert_true(len(uarg.paths[0].segments) == 1)
    assert_true(uarg.paths[1].text == "ex:extra/nested")
    assert_true(len(uarg.paths[1].segments) == 2)

    var aug = _find_first_keyword(root_arc, "augment")
    assert_true(aug)
    assert_true(aug.value()[].argument.isa[PathArgument]())
    var aug_leaf = _find_keyword_under(aug.value(), "leaf", "aug-leaf")
    assert_true(aug_leaf)

    var path_stmt = _find_first_keyword(root_arc, "path")
    assert_true(path_stmt)
    assert_true(path_stmt.value()[].argument.isa[PathArgument]())


def test_prefixed_uses_rejects_non_local_prefix() raises:
    var yang_text = String(
        """
module ex-mod {
  yang-version 1.1;
  namespace "urn:ex";
  prefix ex;

  grouping ex-group {
    leaf g {
      type string;
    }
  }

  container top {
    uses other:ex-group;
  }
}
"""
    )
    try:
        var lexer = AstLexer(yang_text.as_bytes())
        var mod = YangModule()
        mod.parse(lexer)
        raise Error("expected non-local uses prefix to fail")
    except e:
        var msg = String(e)
        assert_true(
            "external grouping reference" in msg,
            "expected external grouping reference error, got: " + msg,
        )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
