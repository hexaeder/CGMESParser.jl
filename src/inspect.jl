#=
Interactive inspection of the CIM object graph. The implementation lives in the GraphMakie
extension so that the parser itself carries no plotting dependency — these are the stubs
that hold the docstrings and give a useful error when the backend is missing.
=#

function _no_graphmakie(f)
    error("$f requires GraphMakie. Run `using GraphMakie` (plus a Makie backend such as \
           CairoMakie or WGLMakie) to load the inspection extension.")
end

"""
    inspect_collection(collection; filter_out=String[], size=(2000,1500), hl1=[], hl2=[],
                       seed=1, edge_labels=true, node_labels=:long)

Plot every object in `collection` as a node and every resolved reference as an edge, with
nodes colored by the profile they came from. `filter_out` drops classes whose name contains
any of the given strings, which is how you get a readable picture out of a full dataset.

Requires GraphMakie and a Makie backend to be loaded.
"""
inspect_collection(collection; kwargs...) = _no_graphmakie("inspect_collection")

"""
    inspect_node(node::CIMObject; stop_classes=String[], filter_out=String[], max_depth=100, ...)

Plot the neighbourhood of a single object, walking references outwards until hitting a class
in `stop_classes` or `max_depth`. Useful for asking "what is attached to this Terminal".

Requires GraphMakie and a Makie backend to be loaded.
"""
inspect_node(node; kwargs...) = _no_graphmakie("inspect_node")

"""
    inspect_comparison(comparison::CIMCollectionComparison; size=(2000,1000), ...)

Plot two collections side by side, graying out the objects that matched and pinning them to
the same positions, so that whatever differs stands out.

Requires GraphMakie and a Makie backend to be loaded.
"""
inspect_comparison(comparison; kwargs...) = _no_graphmakie("inspect_comparison")

"""
    html_hover_map(fig=Makie.current_figure())

Wrap `fig` in an HTML image map carrying the per-node tooltips, so hovering works in a
static documentation build where no live Makie backend is running.

Requires GraphMakie and a Makie backend to be loaded.
"""
html_hover_map(args...) = _no_graphmakie("html_hover_map")
