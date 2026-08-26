using CGMESParser
using CGMESParser: SBASE, get_base_voltage, get_voltage_pu, get_injected_power_pu,
                   get_connecting_terminal, is_angle_ref, in_service, injector_type,
                   PVType, PQYType, SlackType, Injector, combine, get_current_sum_pu
using Test
include("testdata.jl")

@testset "accessors work on every dataset" begin
    for dir in all_dataset_dirs()
        d = CIMDataset(dir)
        tpns = d("TopologicalNode")
        @test !isempty(tpns)
        for tpn in tpns
            @test get_base_voltage(tpn) > 0
            u = get_voltage_pu(tpn)
            @test isfinite(u)
            @test 0.5 < abs(u) < 1.5
            @test is_angle_ref(tpn) isa Bool
        end
        # each island has exactly one angle reference
        @test count(is_angle_ref, tpns) == length(d("TopologicalIsland"))
    end
end

ds = CIMDataset(datapath("testdata1"))

@testset "base voltage" begin
    tpn = first(ds("TopologicalNode"))
    @test get_base_voltage(tpn) == 380
    # terminals inherit the base voltage of the node they sit on
    term = first(ds("Terminal"))
    @test get_base_voltage(term) == get_base_voltage(term["TopologicalNode"])
end

@testset "voltage in per unit" begin
    for tpn in ds("TopologicalNode")
        u = get_voltage_pu(tpn)
        @test u isa Complex
        @test 0.8 < abs(u) < 1.2
    end
    # exactly one node is the angle reference
    @test count(is_angle_ref, ds("TopologicalNode")) == 1
end

@testset "injected power uses injector convention and SBASE" begin
    load = first(ds("ConformLoad"))
    S = get_injected_power_pu(get_connecting_terminal(load))
    @test real(S) < 0            # a load draws power

    old = SBASE[]
    try
        SBASE[] = 2 * old
        S2 = get_injected_power_pu(get_connecting_terminal(load))
        @test S2 ≈ S / 2
    finally
        SBASE[] = old
    end
end

@testset "in_service" begin
    @test all(in_service, ds("SynchronousMachine"))
end

@testset "injector classification" begin
    gen = first(ds("SynchronousMachine"))
    @test injector_type(gen) isa PVType
    load = first(ds("ConformLoad"))
    @test injector_type(load) isa PQYType
end

@testset "injectors combine" begin
    a = PQYType(1.0, 2.0, 0.0, 0.0, CIMObject[])
    b = PQYType(3.0, 4.0, 0.5, 0.5, CIMObject[])
    c = combine(a, b)
    @test c isa PQYType
    @test c.P == 4.0 && c.Q == 6.0 && c.G == 0.5 && c.B == 0.5

    # a slack absorbs anything attached to the same node
    s = SlackType(1.0, CIMObject[])
    @test combine(s, a) isa SlackType
    @test combine(a, s) isa SlackType
    # a PV bus keeps its voltage but picks up the extra power
    pv = PVType(1.0, 1.05, CIMObject[])
    @test combine(pv, a) isa PVType
    @test combine(pv, a).V == 1.05
end

@testset "kirchhoff at a bus" begin
    # current implied by the stored powerflow must be finite and well defined
    nodes, _ = CGMESParser.split_topologically(ds; warn=false)
    for n in nodes
        @test isfinite(get_current_sum_pu(n))
    end
end
