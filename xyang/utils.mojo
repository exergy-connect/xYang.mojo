## YANG AST utilities (e.g. tree printing).

from xyang.ast import YangModule, YangContainer, YangList, YangChoice


def _print_list(list_node: YangList, indent: String):
    """Print a list node and its children recursively."""
    print(indent + "list " + list_node.name + ((" key " + list_node.key) if len(list_node.key) > 0 else ""))
    var inner = indent + "  "
    for i in range(len(list_node.leaves)):
        ref leaf = list_node.leaves[i][]
        print(inner + "leaf " + leaf.name + " : " + leaf.type.name + (" (mandatory)" if leaf.mandatory else ""))
    for i in range(len(list_node.anydatas)):
        ref ad = list_node.anydatas[i][]
        print(inner + "anydata " + ad.name + (" (mandatory)" if ad.mandatory else ""))
    for i in range(len(list_node.anyxmls)):
        ref ax = list_node.anyxmls[i][]
        print(inner + "anyxml " + ax.name + (" (mandatory)" if ax.mandatory else ""))
    for i in range(len(list_node.containers)):
        _print_container(list_node.containers[i][], inner)
    for i in range(len(list_node.lists)):
        _print_list(list_node.lists[i][], inner)
    for i in range(len(list_node.choices)):
        ref ch = list_node.choices[i][]
        print(inner + "choice " + ch.name + (" (mandatory)" if ch.mandatory else "") + " cases=" + String(len(ch.case_names)))


def _print_container(container: YangContainer, indent: String):
    """Print a container and its children recursively."""
    print(indent + "container " + container.name)
    var inner = indent + "  "
    for i in range(len(container.leaves)):
        ref leaf = container.leaves[i][]
        print(inner + "leaf " + leaf.name + " : " + leaf.type.name + (" (mandatory)" if leaf.mandatory else ""))
    for i in range(len(container.anydatas)):
        ref ad = container.anydatas[i][]
        print(inner + "anydata " + ad.name + (" (mandatory)" if ad.mandatory else ""))
    for i in range(len(container.anyxmls)):
        ref ax = container.anyxmls[i][]
        print(inner + "anyxml " + ax.name + (" (mandatory)" if ax.mandatory else ""))
    if len(container.containers) > 0:
        for c in container.containers:
            _print_container(c[], inner)
    for i in range(len(container.lists)):
        _print_list(container.lists[i][], inner)
    for i in range(len(container.choices)):
        ref ch = container.choices[i][]
        print(inner + "choice " + ch.name + (" (mandatory)" if ch.mandatory else "") + " cases=" + String(len(ch.case_names)))


def print_module_tree(module: YangModule):
    """Print the full AST tree of a YANG module."""
    print("module " + module.name + " { namespace \"" + module.namespace + "\"; prefix " + module.prefix + ";")
    for i in range(len(module.top_level_containers)):
        _print_container(module.top_level_containers[i][], "  ")
    print("}")
