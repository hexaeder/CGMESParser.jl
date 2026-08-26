using CGMESParser
using CGMESParser: compare_objects
using Test
include("testdata.jl")

A = CIMCollection(CIMDataset(datapath("reexport", "1-EHVHV-mixed-all-2-sw-Ausschnitt")))
B = CIMCollection(CIMDataset(datapath("reexport", "1-EHVHV-mixed-all-2-sw-Ausschnitt_reexport")))

@testset "comparing a dataset to itself matches everything" begin
    self = CIMCollectionComparison(A, A)
    @test length(self.matches_a_to_b) == length(objects(A))
    # Objects are matched on content, not on UUID, so a handful of genuinely identical
    # twins (duplicate CurrentLimits, PositionPoints) may pair up with each other rather
    # than with themselves. Everything else maps to itself.
    @test count(((k, v),) -> k == v, self.matches_a_to_b) > 0.95 * length(objects(A))
end

@testset "comparing an export to its reexport" begin
    cmp = CIMCollectionComparison(A, B)
    @test cmp isa CIMCollectionComparison
    @test !isempty(cmp.matches_a_to_b)
    # the reexport is a subset, so not everything finds a partner
    @test length(cmp.matches_a_to_b) <= min(length(objects(A)), length(objects(B)))
    # every match points at an object that exists on the other side
    for (a, b) in cmp.matches_a_to_b
        @test haskey(A, a)
        @test haskey(B, b)
    end
    # the buses survive a reexport and must be found
    for tpn in A("TopologicalNode")
        @test haskey(cmp.matches_a_to_b, tpn.id)
    end
end

@testset "nameless objects do not break matching" begin
    # PositionPoint and friends carry no name; comparing collections containing them
    # must not throw
    @test !isempty(A("PositionPoint"))
    @test CIMCollectionComparison(A, B) isa CIMCollectionComparison
end

@testset "compare_objects reports on a pair" begin
    obj = first(A("TopologicalNode"))
    out = sprint(io -> compare_objects(obj, obj; io))
    @test out isa String
    @test !isempty(out)
end
