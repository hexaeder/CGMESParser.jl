using CGMESParser
using CGMESParser: split_topologically, reduce_complexity, delete_unconnected, to_digraph,
                   classify_branch_subgraph, ACLineSegment, PowerTransformer, Breaker,
                   MultiBranchSubgraph, get_tpn_node, get_tpn_nodes, get_branch_name
using Graphs: nv, ne
using Test
include("testdata.jl")

# simbench_2bus is left out: it contains an EnergySource, a class the injector
# classification does not handle yet.
SPLITTABLE = ["testdata1", "1-EHVHV-mixed-all-2-sw-Ausschnitt",
              "1-EHVHV-mixed-all-2-sw-minimal-komplex"]

@testset "split into buses and branches" begin
    for sub in SPLITTABLE
        ds = CIMDataset(datapath(sub))
        nodes, edges = split_topologically(ds; warn=false)
        @test !isempty(nodes)
        @test !isempty(edges)
        # a bus subgraph holds exactly one topological node, a branch exactly two
        @test all(n -> length(n("TopologicalNode")) == 1, nodes)
        @test all(e -> length(e("TopologicalNode")) == 2, edges)
    end
end

@testset "subgraph metadata names the endpoints" begin
    ds = CIMDataset(datapath("testdata1"))
    nodes, edges = split_topologically(ds; warn=false)
    busnames = Set(getname(get_tpn_node(n)) for n in nodes)
    for e in edges
        @test haskey(e.metadata, :src_name)
        @test haskey(e.metadata, :dst_name)
        # branch endpoints must be buses that actually came out of the same split
        @test e.metadata[:src_name] in busnames
        @test e.metadata[:dst_name] in busnames
        src, dst = get_tpn_nodes(e)
        @test getname(src) == e.metadata[:src_name]
        @test getname(dst) == e.metadata[:dst_name]
    end
    for n in nodes
        @test haskey(n.metadata, :busidx)
    end
end

@testset "branch classification" begin
    ds = CIMDataset(datapath("testdata1"))
    _, edges = split_topologically(ds; warn=false)
    @test all(e -> classify_branch_subgraph(e) isa ACLineSegment, edges)
    @test all(e -> get_branch_name(e) isa AbstractString, edges)

    ds2 = CIMDataset(datapath("1-EHVHV-mixed-all-2-sw-minimal-komplex"))
    _, edges2 = split_topologically(ds2; warn=false)
    classes = unique(typeof.(classify_branch_subgraph.(edges2)))
    @test !isempty(classes)
    @test all(c -> c <: Union{ACLineSegment, PowerTransformer, Breaker, MultiBranchSubgraph}, classes)
end

@testset "to_digraph mirrors the references" begin
    c = CIMCollection(CIMDataset(datapath("testdata1")))
    nodes, g = to_digraph(c)
    @test length(nodes) == length(objects(c))
    @test nv(g) == length(nodes)
    @test ne(g) > 0
end

@testset "reduce_complexity drops the decorative classes" begin
    c = CIMCollection(CIMDataset(datapath("testdata1")))
    red = reduce_complexity(c)
    @test length(objects(red)) < length(objects(c))
    for class in ("DiagramObject", "CoordinateSystem", "BaseVoltage", "Substation", "Location")
        @test isempty(red(class))
    end
    # the electrically relevant objects survive
    @test length(red("TopologicalNode")) == length(c("TopologicalNode"))
    @test length(red("ACLineSegment")) == length(c("ACLineSegment"))
end

@testset "filter keeps the collection consistent" begin
    c = CIMCollection(CIMDataset(datapath("testdata1")))
    only_tpn = filter(o -> o.class_name in ("TopologicalNode", "Terminal"), c)
    @test all(o -> o.class_name in ("TopologicalNode", "Terminal"), values(objects(only_tpn)))
    # references that survived the filter are still resolved
    term = first(only_tpn("Terminal"))
    @test term["TopologicalNode"] isa CIMObject
end
