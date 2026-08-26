using CGMESParser
using Test
include("testdata.jl")

ds = CIMDataset(datapath("testdata1"))

# Loading GraphMakie brings in the extension; before that the stubs must explain themselves.
# runtests.jl loads this file last so the earlier testsets run without any Makie present.
@testset "stubs error before the extension loads" begin
    if isnothing(Base.get_extension(CGMESParser, :CGMESParserGraphMakieExt))
        @test_throws ErrorException inspect_collection(ds)
        @test_throws ErrorException inspect_node(first(ds("Terminal")))
    end
end

using CairoMakie
using GraphMakie

@testset "extension loads" begin
    @test !isnothing(Base.get_extension(CGMESParser, :CGMESParserGraphMakieExt))
end

@testset "inspect_collection" begin
    fig = inspect_collection(ds; size=(600, 600))
    @test fig isa Makie.Figure
    # filtering shrinks the picture but still draws one
    fig2 = inspect_collection(ds; filter_out=["Diagram", "Position", "Location"], size=(600, 600))
    @test fig2 isa Makie.Figure
end

@testset "inspect_node" begin
    fig = inspect_node(first(ds("Terminal")); max_depth=2, size=(600, 600))
    @test fig isa Makie.Figure
end

@testset "inspect_comparison" begin
    A = CIMCollection(CIMDataset(datapath("reexport", "1-EHVHV-mixed-all-2-sw-Ausschnitt")))
    B = CIMCollection(CIMDataset(datapath("reexport", "1-EHVHV-mixed-all-2-sw-Ausschnitt_reexport")))
    fig = inspect_comparison(CIMCollectionComparison(A, B); size=(800, 400))
    @test fig isa Makie.Figure
end

@testset "html_hover_map" begin
    inspect_collection(ds; size=(600, 600))
    @test html_hover_map() isa HTML
end
