## After YANG text parse, only fill `YangTypeTypedef.resolved` (see `YangType.link_typedef_resolved`).

from std.collections import Dict
from std.memory import ArcPointer
import xyang.ast as ast

comptime Arc = ArcPointer

def _resolve_container_in_arc(
    mut c: Arc[ast.YangContainer], read typedefs: Dict[String, Arc[ast.YangTypedefStmt]]
) raises:
    ref b = c[]
    for i in range(len(b.leaves)):
        b.leaves[i][].type.link_typedef_resolved(typedefs)
    for i in range(len(b.leaf_lists)):
        b.leaf_lists[i][].type.link_typedef_resolved(typedefs)
    for j in range(len(b.containers)):
        _resolve_container_in_arc(b.containers[j], typedefs)
    for j in range(len(b.lists)):
        var a = b.lists[j]
        _resolve_list_in_arc(a, typedefs)
        b.lists[j] = a^
    for j in range(len(b.choices)):
        _ = b.choices[j]


def _resolve_list_in_arc(
    mut a: Arc[ast.YangList], read typedefs: Dict[String, Arc[ast.YangTypedefStmt]]
) raises:
    ref l = a[]
    for i in range(len(l.children)):
        var ch = l.children[i]
        if ch.isa[Arc[ast.YangLeaf]]():
            ref yl = ch[Arc[ast.YangLeaf]][]
            yl.type.link_typedef_resolved(typedefs)
        elif ch.isa[Arc[ast.YangLeafList]]():
            ref yll = ch[Arc[ast.YangLeafList]][]
            yll.type.link_typedef_resolved(typedefs)
        elif ch.isa[Arc[ast.YangContainer]]():
            _resolve_container_in_arc(ch[Arc[ast.YangContainer]], typedefs)
        elif ch.isa[Arc[ast.YangList]]():
            _resolve_list_in_arc(ch[Arc[ast.YangList]], typedefs)


def _resolve_grouping_in_arc(
    mut g: Arc[ast.YangGrouping], read typedefs: Dict[String, Arc[ast.YangTypedefStmt]]
) raises:
    ref ug = g[]
    for idx in range(len(ug.children)):
        var ch = ug.children[idx]
        if ch.isa[Arc[ast.YangLeaf]]():
            ref yl = ch[Arc[ast.YangLeaf]][]
            yl.type.link_typedef_resolved(typedefs)
        elif ch.isa[Arc[ast.YangLeafList]]():
            ref yll = ch[Arc[ast.YangLeafList]][]
            yll.type.link_typedef_resolved(typedefs)
        elif ch.isa[Arc[ast.YangContainer]]():
            _resolve_container_in_arc(ch[Arc[ast.YangContainer]], typedefs)
        elif ch.isa[Arc[ast.YangList]]():
            _resolve_list_in_arc(ch[Arc[ast.YangList]], typedefs)


def resolve_typedef_refs_in_module(mut m: ast.YangModule) raises:
    for i in range(len(m.statements)):
        var s = m.statements[i]
        if s.isa[Arc[ast.YangTypedefStmt]]():
            var arc_td = s[Arc[ast.YangTypedefStmt]]
            ref td = arc_td[]
            td.type_stmt.link_typedef_resolved(m.typedefs)
        elif s.isa[Arc[ast.YangGrouping]]():
            _resolve_grouping_in_arc(s[Arc[ast.YangGrouping]], m.typedefs)
    for j in range(len(m.top_level_containers)):
        _resolve_container_in_arc(m.top_level_containers[j], m.typedefs)
