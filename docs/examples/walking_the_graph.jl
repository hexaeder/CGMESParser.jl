#=
# Walking the Object Graph

A parsed dataset is an object graph: every `CIMObject` carries the properties from the XML,
and the UUID references between objects are resolved in both directions. This page covers
how to get from one object to another.
=#
using CGMESParser

DATA = joinpath(pkgdir(CGMESParser), "test", "data", "testdata1")
dataset = CIMDataset(DATA)

#=
## Finding objects by class

Calling a collection with a class name gives you every object of that class. A regex or a
vector of names works too.
=#
dataset("TopologicalNode")

#=
## Following a reference

Indexing an object with a property name follows the reference and returns the object on the
other end, so chains read the way the model does.
=#
terminal = first(dataset("Terminal"))
terminal["TopologicalNode"]

#=
Properties that are plain values come back as values. `properties(obj)` returns everything
including what extensions in other profiles added — the SSH profile, for instance, restates
Equipment objects to attach the operating point, and those show up here but not in the raw
`obj.properties` field.
=#
properties(terminal)

#=
## Going against the direction of a reference

References in CGMES point one way, but the interesting question is often the other way
round: not "which node does this terminal sit on" but "what is attached to this node".
That is what `ascendants` is for, with `descendants` being the forward equivalent.

Both take a matcher. `byclass` selects on the class of the object at the other end, with an
optional `via` to also pin down which property the reference lives in; `byprop` selects on
the property name alone.
=#
node = terminal["TopologicalNode"]
ascendants(node, byclass("Terminal", via="TopologicalNode"))

#=
`descend` and `ascend` are the singular forms: same matchers, but they return the object
itself and error unless there is exactly one match. Use them when the model guarantees a
single answer and you would rather find out immediately when it does not.
=#
descend(terminal, byclass("TopologicalNode"))

#=
## Reading the stored operating point

The SV profile carries the powerflow the exporting tool computed. The semantic accessors
read it in per unit, using [`CGMESParser.SBASE`](@ref) as the system base — CGMES itself
carries no system base, so this is a convention of this package.

Powers use the injector convention: a load comes out negative.
=#
using CGMESParser: get_voltage_pu, get_injected_power_pu, get_base_voltage, get_connecting_terminal

get_base_voltage(node), get_voltage_pu(node)

#-

load = first(dataset("ConformLoad"))
get_injected_power_pu(get_connecting_terminal(load))
