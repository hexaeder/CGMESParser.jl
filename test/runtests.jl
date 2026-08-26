using CGMESParser
using Test

@testset "CGMESParser.jl" begin
    @testset "parsing" begin include("parsing_test.jl") end
    @testset "traversal" begin include("traversal_test.jl") end
    @testset "semantics" begin include("semantics_test.jl") end
    @testset "topology" begin include("topology_test.jl") end
    @testset "transformations" begin include("transformations_test.jl") end
    @testset "comparison" begin include("comparison_test.jl") end
    @testset "inspection extension" begin include("inspect_test.jl") end
end
