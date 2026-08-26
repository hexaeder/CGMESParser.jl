using CGMESParser
using CGMESParser: is_external_ref
using Test
include("testdata.jl")

@testset "every bundled dataset parses" begin
    dirs = all_dataset_dirs()
    @test !isempty(dirs)
    for dir in dirs
        ds = @test_nowarn CIMDataset(dir)
        @test ds isa CIMDataset
        @test !isempty(objects(ds))
    end
end

@testset "graph invariants hold on every dataset" begin
    for dir in all_dataset_dirs()
        ds = CIMDataset(dir)
        objs = objects(ds)
        for o in values(objs)
            # every resolved internal reference points at an object of this dataset, and
            # the object on the other end knows about it
            for (prop, v) in properties(o)
                v isa Union{CIMRef, Vector{CIMRef}} || continue
                for ref in v
                    (ref.resolved && !is_external_ref(ref)) || continue
                    target = follow_ref(ref)
                    isnothing(target) && continue
                    @test haskey(objs, target.id)
                    @test any(b -> base_object(b) === o && b.prop == prop, target.backrefs)
                end
            end
        end
    end
end

@testset "show methods work on every dataset" begin
    for dir in all_dataset_dirs()
        ds = CIMDataset(dir)
        @test !isempty(sprint(show, MIME"text/plain"(), ds))
        for o in Iterators.take(values(objects(ds)), 20)
            @test !isempty(sprint(show, MIME"text/plain"(), o))
            @test !isempty(sprint(show, o))
        end
    end
end

@testset "profiles and structure" begin
    ds = CIMDataset(datapath("testdata1"))
    @test haskey(ds, :Topology)
    @test haskey(ds, :StateVariables)
    @test ds[:Topology] isa CIMFile
    @test length(objects(ds)) == 122

    # objects carry their originating profile and their raw CIM class name
    tpns = ds("TopologicalNode")
    @test length(tpns) == 3
    @test all(o -> o.profile === :Topology, tpns)
    @test all(o -> o.class_name == "TopologicalNode", tpns)
end

@testset "references resolve in both directions" begin
    ds = CIMDataset(datapath("testdata1"))
    term = first(ds("Terminal"))
    tpn = term["TopologicalNode"]
    @test tpn isa CIMObject
    # the terminal must show up again among the objects pointing at that node
    @test term in ascendants(tpn, byclass("Terminal", via="TopologicalNode"))
end

@testset "regex and vector class lookup" begin
    ds = CIMDataset(datapath("testdata1"))
    @test !isempty(ds(r"Terminal"))
    combined = ds(["Terminal", "TopologicalNode"])
    @test length(combined) == length(ds("Terminal")) + length(ds("TopologicalNode"))
end

@testset "extensions merge into properties" begin
    # SSH files re-state Equipment objects; those become extensions of the EQ object
    ds = CIMDataset(datapath("testdata1"))
    withext = filter(o -> !isempty(o.extension), collect(values(objects(ds))))
    @test !isempty(withext)
    o = first(withext)
    # properties() sees the extension, the raw field does not
    @test length(properties(o)) >= length(o.properties)
end

@testset "copy is deep and stays resolved" begin
    ds = CIMDataset(datapath("testdata1"))
    c = copy(CIMCollection(ds))
    @test length(objects(c)) == length(objects(ds))
    term = first(c("Terminal"))
    @test term["TopologicalNode"] isa CIMObject
    # mutating the copy must not touch the original
    term.properties["name"] = "changed"
    @test getname(first(ds("Terminal"))) != "changed"
end
