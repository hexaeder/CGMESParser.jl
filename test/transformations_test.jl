using CGMESParser
using CGMESParser: filter_loopback_breakers, merge_tpn_on_breakers, reattach_regulating_control,
                   rename_dangling_tpn, delete_object!, split_topologically, is_external_ref
using Test
include("testdata.jl")

@testset "transformations leave the input untouched" begin
    for sub in ("testdata1", "1-EHVHV-mixed-all-2-sw-minimal-komplex")
        orig = CIMCollection(CIMDataset(datapath(sub)))
        n_before = length(objects(orig))
        for f in (filter_loopback_breakers, reattach_regulating_control,
                  rename_dangling_tpn, merge_tpn_on_breakers)
            out = f(orig)
            @test out isa CIMCollection
            @test length(objects(orig)) == n_before   # input not mutated
            # the result is a usable collection: every internal reference is resolved
            # again (external CIM schema enum URIs are never resolved by design)
            @test all(values(objects(out))) do o
                all(properties(o)) do (_, v)
                    !(v isa CIMRef) || is_external_ref(v) || v.resolved
                end
            end
        end
    end
end

@testset "transformations chain" begin
    c = copy(CIMCollection(CIMDataset(datapath("1-EHVHV-mixed-all-2-sw-minimal-komplex"))))
    c = filter_loopback_breakers(c)
    c = merge_tpn_on_breakers(c)
    c = reattach_regulating_control(c)
    nodes, edges = split_topologically(c; warn=false)
    @test !isempty(nodes) && !isempty(edges)
end

@testset "no-op transformations are identity in size" begin
    # testdata1 has no loopback breakers and no misplaced regulating controls
    c = CIMCollection(CIMDataset(datapath("testdata1")))
    @test length(objects(filter_loopback_breakers(c))) == length(objects(c))
    @test length(objects(reattach_regulating_control(c))) == length(objects(c))
end

@testset "delete_object! detaches an object from the graph" begin
    c = copy(CIMCollection(CIMDataset(datapath("testdata1"))))
    victim = first(c("DiagramObject"))
    id = victim.id
    n_before = length(objects(c))

    delete_object!(c, victim)
    @test !haskey(c, id)
    @test length(objects(c)) == n_before - 1
    # nothing points at the deleted object any more
    @test all(values(objects(c))) do o
        all(properties(o)) do (_, v)
            !(v isa CIMRef) || v.id != id
        end
    end

    # delete_object! leaves the backref bookkeeping to a following resolve; after that
    # the collection is consistent again
    resolve_references!(c; warn=false)
    @test all(values(objects(c))) do o
        all(b -> b.source !== victim, o.backrefs)
    end
end
