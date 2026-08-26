```@meta
CurrentModule = CGMESParser
```

# CGMESParser

Reading, exploring and visualizing [CGMES](https://www.entsoe.eu/data/cim/cim-for-grid-models-exchange/)
(Common Grid Model Exchange Standard) datasets in Julia.

A CGMES model is a directory of XML files, one per profile, whose objects reference each
other by UUID. `CGMESParser` reads such a directory into an object graph you can walk in
both directions, and adds the layers you would otherwise write yourself: cleanup passes for
the quirks real exports contain, a split into buses and branches, and per-unit accessors for
the powerflow stored in the StateVariables profile.

The package knows nothing about any simulation framework. It gives you the grid as data.

## Reading a dataset

[`CIMDataset`](@ref) reads a whole directory and resolves the references between all
profiles. It is a faithful image of what the files say — nothing is cleaned up or
interpreted at this stage.

```julia
using CGMESParser
dataset = CIMDataset("path/to/cgmes/directory")
```

From there, three optional layers sit on top:

- **[Walking the Object Graph](@ref)** — finding objects and following references.
- **[Inspecting a Dataset](@ref)** — plotting the object graph, and splitting the model into
  buses and branches.
- **Cleanup** — [`filter_loopback_breakers`](@ref), [`merge_tpn_on_breakers`](@ref),
  [`reattach_regulating_control`](@ref) and [`rename_dangling_tpn`](@ref) each take a
  collection and return a corrected copy. They are deliberately not applied automatically:
  they change what the file said, and which of them you want depends on the export.

## Plotting

Visualization lives in a package extension so that the parser itself has no plotting
dependency. Load GraphMakie together with a Makie backend to enable it:

```julia
using GraphMakie, CairoMakie
inspect_collection(dataset)
```

## What is interpreted

Every class parses, but only some are given electrical meaning by the semantic layer:
`Terminal`, `TopologicalNode`, `ACLineSegment`, `PowerTransformer`, `Breaker`,
`SynchronousMachine`, `ConformLoad`, `PowerElectronicsConnection` and
`LinearShuntCompensator`. Everything else is readable as data but will not be classified by
[`split_topologically`](@ref) or the injector accessors.
