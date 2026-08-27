# # Inspecting a Dataset
#
# Real CGMES exports are large and full of detail that has nothing to do with the electrical
# model. This page walks through meeting an unfamiliar dataset: read it, strip it down to
# something you can look at, and then split it into buses and branches.

using CGMESParser
using CairoMakie
using GraphMakie

DATA = joinpath(pkgdir(CGMESParser), "test", "data", "1-EHVHV-mixed-all-2-sw-Ausschnitt")
dataset = CIMCollection(CIMDataset(DATA))

# ## Getting a first picture
#
# Plotting the whole collection shows every object and every reference between them. Nodes are
# colored by the profile they came from.
#
# > **Tip**
# >
# > Hover the nodes to inspect their properties!
#
# `reduce_complexity` drops the classes that carry no electrical meaning — diagram layout,
# geographical position, operational limits — which is usually the difference between an
# unreadable hairball and a picture.

reduced_dataset = reduce_complexity(dataset)
inspect_collection(reduced_dataset; edge_labels=false, node_labels=:short, size=(1000,1000))

# ## Splitting into buses and branches
#
# Still too much to take in at once. `split_topologically` collapses the switching detail and
# hands back two lists of subgraphs: one per bus, one per branch. Each subgraph is a full
# `CIMCollection`, so everything you can do to a dataset you can also do to a single bus.

nodes, edges = split_topologically(dataset; warn=false)
length(nodes), length(edges)

# ## A single bus
#
# Three synchronous machines on one topological node:

inspect_collection(nodes[1]; size=(900,900))

# A load:

inspect_collection(nodes[3]; size=(900,900))

# ## A single branch
#
# A transformer. Both transformer ends carry `r`/`x` and `g`/`b`, so this can be read as a
# pi-line with two voltage bases:

inspect_collection(edges[1]; size=(900,900))

# And an ordinary AC line:

inspect_collection(edges[2]; size=(900,900))

# This file was generated using Literate.jl, https://github.com/fredrikekre/Literate.jl
