# CGMESParser.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://hexaeder.github.io/CGMESParser.jl/dev/)
[![Build Status](https://github.com/hexaeder/CGMESParser.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/hexaeder/CGMESParser.jl/actions/workflows/CI.yml?query=branch%3Amain)

Reading, exploring and visualizing CGMES (Common Grid Model Exchange Standard) datasets in
Julia.

CGMES models are distributed as a directory of XML files, one per profile (Equipment,
Topology, StateVariables, …), that reference each other by UUID. `CGMESParser` reads such a
directory into an object graph you can walk in both directions, and adds the pieces you
normally end up writing yourself: cleanup passes for the quirks real exports contain, a
split of the model into buses and branches, and per-unit accessors for the stored powerflow.

The package deliberately knows nothing about any simulation framework. It gives you the
grid as data; what you build from it is up to you.

```julia
using CGMESParser

dataset = CIMDataset("path/to/cgmes/directory")

# walk the object graph
terminal = first(dataset("Terminal"))
node     = terminal["TopologicalNode"]
attached = ascendants(node, byclass("Terminal", via="TopologicalNode"))

# read the powerflow stored in the SV profile
using CGMESParser: get_voltage_pu, get_injected_power_pu
get_voltage_pu(node)

# collapse the switching detail into buses and branches
buses, branches = split_topologically(dataset)
```

## Inspecting a dataset

The most useful thing when meeting an unfamiliar export is to look at it. Load GraphMakie
and a Makie backend to enable the plotting extension:

```julia
using GraphMakie, CairoMakie
inspect_collection(reduce_complexity(CIMCollection(dataset)); node_labels=:short)
```

Plotting is a package extension, so the dependency is only paid by those who ask for it.

## Status

Early days, and shaped by the datasets it has been used on. `Terminal`, `TopologicalNode`,
`ACLineSegment`, `PowerTransformer`, `Breaker`, `SynchronousMachine`, `ConformLoad`,
`PowerElectronicsConnection` and `LinearShuntCompensator` are handled; other classes parse
fine but are not yet interpreted by the semantic layer. Issues and PRs welcome.
