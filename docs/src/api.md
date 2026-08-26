```@meta
CurrentModule = CGMESParser
```

# API Reference

## Reading

```@docs
CGMESParser
CIMDataset
CIMFile
CIMCollection
CIMObject
CIMExtension
CIMRef
CIMBackref
resolve_references!
merge_collection
```

## Accessing and traversing

```@docs
objects
extensions
properties
getname
hasname
follow_ref
base_object
is_class
descend
descendants
ascend
ascendants
byclass
byprop
symbolify
rdf_node
Relation
@hover
```

## Topology

```@docs
split_topologically
reduce_complexity
delete_unconnected
to_digraph
discover_subgraph
is_terminal
```

## Semantics

```@docs
SBASE
get_base_voltage
get_voltage_pu
get_injected_power_pu
get_connecting_terminal
is_angle_ref
in_service
injector_type
Injector
SlackType
PVType
PQYType
classify_branch_subgraph
```

## Transformations

```@docs
filter_loopback_breakers
merge_tpn_on_breakers
reattach_regulating_control
rename_dangling_tpn
```

## Comparing

```@docs
CIMCollectionComparison
compare_objects
```

## Inspection

```@docs
inspect_collection
inspect_node
inspect_comparison
html_hover_map
```
