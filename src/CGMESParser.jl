"""
    CGMESParser

Reader and inspection tools for CGMES (Common Grid Model Exchange Standard) datasets.

A [`CIMDataset`](@ref) is a faithful in-memory image of a directory of CGMES profile files:
objects keep the class names and property names from the XML, and the references between
them are resolved in both directions so the model can be walked as a graph. On top of that
sit three optional layers — cleanup transformations, the topological split into buses and
branches, and a semantic layer that reads per-unit voltages and injections.

Plotting lives in a package extension; load GraphMakie together with a Makie backend to get
[`inspect_collection`](@ref) and friends.
"""
module CGMESParser

using XML: XML, Node, nodetype, attributes, children, tag,
           is_simple, simple_value
using OrderedCollections: OrderedDict
using Graphs

# core data model and graph traversal
export CIMObject, CIMRef, CIMBackref, CIMExtension, CIMCollection, CIMFile, CIMDataset
export rdf_node, plain_name, is_reference, is_object, is_extension, parse_metadata
export resolve_references!, merge_collection
export objects, extensions, hasname, getname, properties, follow_ref, base_object, is_class
export descend, ascend, descendants, ascendants, byprop, byclass
export symbolify

# comparing two datasets
export CIMCollectionComparison, compare_objects

# inspection (implemented in the GraphMakie extension)
export inspect_collection, inspect_node, inspect_comparison, html_hover_map

include("util.jl")
include("types.jl")
include("parsing.jl")
include("semantics.jl")
include("subgraph.jl")
include("transformations.jl")
include("compare.jl")
include("show.jl")
include("inspect.jl")

"""
    @hover expr

No-op in normal use. The documentation build rewrites it to append an HTML hover map after
the plot produced by `expr`, so that tooltips survive into the static docs.
"""
macro hover(expr)
    esc(expr)
end
export @hover

end # module
