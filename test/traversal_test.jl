using CGMESParser
using CGMESParser: is_class, get_connecting_terminal
using Test
include("testdata.jl")

ds = CIMDataset(datapath("testdata1"))

@testset "descend / ascend single match" begin
    term = first(ds("Terminal"))
    @test descend(term, byclass("TopologicalNode")) isa CIMObject
    # descend errors unless there is exactly one match
    @test_throws ErrorException descend(term, byclass("DoesNotExist"))
end

@testset "descendants / ascendants are plural and total" begin
    tpn = first(ds("TopologicalNode"))
    terms = ascendants(tpn, byclass("Terminal", via="TopologicalNode"))
    @test terms isa Vector{CIMObject}
    @test all(t -> is_class(t, "Terminal"), terms)
    @test isempty(descendants(tpn, byclass("DoesNotExist")))
end

@testset "byprop matches on the property name" begin
    gen = first(ds("SynchronousMachine"))
    term = get_connecting_terminal(gen)
    @test is_class(term, "Terminal")
    @test !isempty(ascendants(gen, byprop("ConductingEquipment")))
end

@testset "curried forms compose" begin
    tpn = first(ds("TopologicalNode"))
    @test (tpn |> ascendants(byclass("Terminal"))) == ascendants(tpn, byclass("Terminal"))
end

@testset "getindex by string and regex" begin
    term = first(ds("Terminal"))
    @test term["TopologicalNode"] isa CIMObject
    @test_throws KeyError term[r"NoSuchPropertyAnywhere"]
end

@testset "is_class accepts strings, regex and lists" begin
    term = first(ds("Terminal"))
    @test is_class(term, "Terminal")
    @test is_class(term, r"Term")
    @test is_class(term, ["Terminal", "TopologicalNode"])
    @test !is_class(term, "ACLineSegment")
end
