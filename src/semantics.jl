#=
Semantic layer on top of the raw CIM graph.

The parser proper only knows objects and references; this file knows what those objects
*mean* for a power system: which terminals carry injections, what the per-unit voltage at
a node is, and which power-flow node type an injector amounts to. All of it is plain graph
traversal plus arithmetic, so it stays free of any simulation framework.
=#

"""
    SBASE[]

System base power in MVA used to convert the MW/MVAr values in the CGMES files to
per-unit. CGMES itself carries no system base, so this is a convention of this package —
set it before reading powers if your dataset assumes a different one.
"""
const SBASE = Ref(100.0)

# ---- Edge subgraph classification ----------------------------------------------

abstract type AbstractEdgeSubgraph end
abstract type SingleBranchSubgraph <: AbstractEdgeSubgraph end
struct ACLineSegment <: SingleBranchSubgraph end
struct PowerTransformer <: SingleBranchSubgraph end
struct Breaker <: SingleBranchSubgraph end
struct MultiBranchSubgraph <: AbstractEdgeSubgraph end

function is_abstract_edge_subgraph(c::CIMCollection)
    length(c("TopologicalNode")) == 2
end

function is_single_branch_subgraph(c::AbstractCIMCollection)
    length(c(BRANCH_CLASSES)) == 1 && length(c("Terminal")) == 2
end

function is_multi_branch_subgraph(c::AbstractCIMCollection)
    haskey(c.metadata, :branches) || return false
    branches = c.metadata[:branches]
    all(is_single_branch_subgraph, branches) || return false
end

function get_tpn_nodes(c::AbstractCIMCollection)
    endnodes = c("TopologicalNode")
    @assert length(endnodes)==2 "Expected a edge subgraph (two Topolocial nodes)!"
    src_node = endnodes[findfirst(n -> getname(n) == c.metadata[:src_name], endnodes)]
    dst_node = endnodes[findfirst(n -> getname(n) == c.metadata[:dst_name], endnodes)]
    (; src_node, dst_node)
end
function get_tpn_node(c::CIMCollection)
    only(c("TopologicalNode"))
end

function get_branch_name(c)
    el = only(c(BRANCH_CLASSES))
    getname(el)
end

"""
    classify_branch_subgraph(c) -> AbstractEdgeSubgraph or nothing

What kind of branch a two-bus subgraph describes: an `ACLineSegment`, a `PowerTransformer`,
a `Breaker`, or a `MultiBranchSubgraph` when several elements sit in series. Returns
`nothing` for anything else.
"""
function classify_branch_subgraph(c::AbstractCIMCollection)
    @assert is_abstract_edge_subgraph(c) "Expected a edge subgraph (two Topolocial nodes)!"

    if is_single_branch_subgraph(c)
        segment = only(c(BRANCH_CLASSES))
        is_class(segment, "ACLineSegment") && return ACLineSegment()
        is_class(segment, "PowerTransformer") && return PowerTransformer()
        is_class(segment, "Breaker") && return Breaker()
    end
    if is_multi_branch_subgraph(c)
        return MultiBranchSubgraph()
    end

    return nothing
end

# ---- Injector classification ---------------------------------------------------
"""
    Injector

What a piece of equipment does to the bus it hangs on, in powerflow terms: [`SlackType`](@ref),
[`PVType`](@ref) or [`PQYType`](@ref). Several injectors on the same bus reduce to one with
`combine`, which is where the usual precedence applies — a slack absorbs everything, a PV
bus keeps its voltage and picks up the extra power.
"""
abstract type Injector end
"""
    SlackType(V, objs)

A bus that holds both voltage magnitude and angle. `V` is `NaN` when the node is only the
angle reference and nothing fixes its magnitude.
"""
struct SlackType <: Injector
    V::Float64
    objs::Vector{CIMObject}
end
"""
    PVType(P, V, objs)

A bus holding active power and voltage magnitude, in per unit.
"""
struct PVType <: Injector
    P::Float64
    V::Float64
    objs::Vector{CIMObject}
end
"""
    PQYType(P, Q, G, B, objs)

A bus with a fixed power injection plus a shunt admittance, all in per unit. Plain loads and
generators leave `G` and `B` at zero; a pure shunt compensator leaves `P` and `Q` at zero.
"""
struct PQYType <: Injector
    P::Float64
    Q::Float64
    G::Float64  # Shunt conductance in pu
    B::Float64  # Shunt susceptance in pu
    objs::Vector{CIMObject}
end
# Backward compatibility constructor
PQType(P, Q, objs) = PQYType(P, Q, 0.0, 0.0, objs)
# S + S
combine(sA::SlackType, sB::SlackType) = SlackType(compatible_voltage(sA, sB), vcat(sA.objs, sB.objs))
# S + PV
combine(s::SlackType, pv::PVType) = SlackType(compatible_voltage(s, pv), vcat(s.objs, pv.objs))
combine(pv::PVType, s::SlackType) = combine(s, pv)
# S + PQY (Y component absorbed by fixed voltage)
combine(s::SlackType, pqy::PQYType) = SlackType(s.V, vcat(s.objs, pqy.objs))
combine(pqy::PQYType, s::SlackType) = combine(s, pqy)

# PV + PV
combine(pvA::PVType, pvB::PVType) = PVType(pvA.P + pvB.P, compatible_voltage(pvA, pvB), vcat(pvA.objs, pvB.objs))
# PV + PQY (Y component absorbed by fixed voltage)
combine(pv::PVType, pqy::PQYType) = PVType(pqy.P + pv.P, pv.V, vcat(pqy.objs, pv.objs))
combine(pqy::PQYType, pv::PVType) = combine(pv, pqy)

compatible_voltage(v1::Injector, v2::Injector) = compatible_voltage(v1.V, v2.V)
function compatible_voltage(v1, v2)
    isnan(v1) && !isnan(v2) && return v2
    !isnan(v1) && isnan(v2) && return v1
    isapprox(v1, v2; rtol=1e-5, atol=1e-8) && return v1
    error("Incompatible voltage setpoints: $(str_significant(v1)) vs $(str_significant(v2))!")
end

# PQY + PQY
combine(pqA::PQYType, pqB::PQYType) = PQYType(pqA.P + pqB.P, pqA.Q + pqB.Q, pqA.G + pqB.G, pqA.B + pqB.B, vcat(pqA.objs, pqB.objs))

"""
    injector_type(o::CIMObject) -> Injector

Read what a piece of equipment does to the bus it hangs on, as one of [`SlackType`](@ref),
[`PVType`](@ref) or [`PQYType`](@ref). Powers come out in per unit and in injector
convention, so a load is negative.

Dispatches on the CIM class; generators, loads, power electronics and shunt compensators are
handled. Several injectors on one bus can be reduced with `combine`.
"""
injector_type(o::CIMObject) = injector_type(Val(Symbol(o.class_name)), o)
function injector_type(::Val{:SynchronousMachine}, o::CIMObject)
    props = properties(o)

    # get p and q from SSH
    P = -props["RotatingMachine.p"]/SBASE[]
    Q = -props["RotatingMachine.q"]/SBASE[]

    if haskey(props, "RegulatingCondEq.RegulatingControl")
        baseV = get_base_voltage(get_connecting_terminal(o))
        controller = follow_ref(props["RegulatingCondEq.RegulatingControl"])
        is_class(controller, "RegulatingControl") || error("Expected RegulatingControl, got $(controller.class_name)")
        V = controller["targetValue"]/baseV

        return PVType(P, V, [o])
    else
        return PQType(P, Q, [o])
    end
end
function injector_type(::Val{:ConformLoad}, o::CIMObject)
    props = properties(o)
    P = -props["EnergyConsumer.p"]/SBASE[]
    Q = -props["EnergyConsumer.q"]/SBASE[]
    return PQType(P, Q, [o])
end

function injector_type(::Val{:PowerElectronicsConnection}, o::CIMObject)
    props = properties(o)

    # Get p and q from SSH (similar to SynchronousMachine but different property names)
    P = -props["p"]/SBASE[]
    Q = -props["q"]/SBASE[]

    if haskey(props, "RegulatingCondEq.RegulatingControl")
        baseV = get_base_voltage(get_connecting_terminal(o))
        controller = follow_ref(props["RegulatingCondEq.RegulatingControl"])
        is_class(controller, "RegulatingControl") || error("Expected RegulatingControl, got $(controller.class_name)")
        V = controller["targetValue"]/baseV
        return PVType(P, V, [o])
    else
        return PQType(P, Q, [o])
    end
end

function injector_type(::Val{:LinearShuntCompensator}, o::CIMObject)
    props = properties(o)

    # Get susceptance and conductance per section
    bPerSection = props["bPerSection"]  # in Siemens
    gPerSection = props["gPerSection"]  # in Siemens

    # Get actual sections from StateVariables (SvShuntCompensatorSections)
    sv = ascend(o, byclass("SvShuntCompensatorSections", via="ShuntCompensator"))
    sections = properties(sv)["sections"]

    # Get base voltage to convert to pu
    baseV = get_base_voltage(get_connecting_terminal(o))  # kV
    Ybase = SBASE[] / (baseV^2)

    # Total admittance in pu
    G = (gPerSection * sections) / Ybase
    B = (bPerSection * sections) / Ybase

    # Shunt compensators inject no fixed P or Q (voltage-dependent)
    return PQYType(0.0, 0.0, G, B, [o])
end


# ---- Per-unit accessors --------------------------------------------------------
"""
    in_service(inj)

Whether a piece of equipment (or the terminal it hangs on) is switched in. Both the
Equipment profile and an SvStatus in the StateVariables profile can say, and this errors if
the two disagree.
"""
function in_service(inj)
    if is_class(inj, "Terminal")
        @assert is_injector_terminal(inj) "Expected injector Terminal, got $(inj.class_name)"
        inj = inj["ConductingEquipment"]
    end

    eqp_service = if haskey(inj, "Equipment.inService")
        inj["Equipment.inService"]
    else
        nothing
    end
    svcand = ascendants(inj, byclass("SvStatus", via="ConductingEquipment"))
    sv_service = if !isempty(svcand)
        svc = only(svcand)
        svc["inService"]
    else
        nothing
    end
    # error if both are defined and different
    if !isnothing(eqp_service) && !isnothing(sv_service)
        eqp_service == sv_service || error("Inconsistent inService status for $(getname(inj))!")
    end
    if isnothing(eqp_service) && isnothing(sv_service)
        return true
    elseif isnothing(eqp_service)
        return sv_service
    else
        return eqp_service
    end
end

"""
    is_angle_ref(o::CIMObject)

Whether a TopologicalNode is the angle reference of its island — the slack bus, in
powerflow terms.
"""
function is_angle_ref(o::CIMObject)
    @assert is_class(o, "TopologicalNode") "Expected TopologicalNode, got $(o.class_name)"

    refs = ascendants(o, byprop("AngleRefTopologicalNode"))

    if length(refs) == 0
        return false
    elseif length(refs) == 1
        return true
    else
        error("Multiple AngleRefTopologicalNode references found for TopologicalNode $(getname(o))!")
    end
end

"""
    get_base_voltage(ob::CIMObject) -> kV

Nominal voltage of the object, in kV. Terminals take the base voltage of the node they sit
on.
"""
function get_base_voltage(ob::CIMObject)
    if is_class(ob, ["TopologicalNode", "PowerTransformerEnd", "ACLineSegment"])
        return follow_ref(ob[r"BaseVoltage$"])["nominalVoltage"]
    elseif is_class(ob, "Terminal")
        return get_base_voltage(ob["TopologicalNode"])
    end
    error("Don't know how to get base voltage for object of class $(ob.class_name)!")
end

"""
    get_connecting_terminal(injector::CIMObject)

The Terminal through which a piece of equipment is attached to the grid. Errors unless
there is exactly one.
"""
function get_connecting_terminal(injector::CIMObject)
    ascend(injector, byclass("Terminal", via="ConductingEquipment"))
end

"""
    get_voltage_pu(o) -> Complex

Voltage at a node, terminal or bus subgraph, as a complex phasor in per unit of the node's
base voltage. Read from the SvVoltage in the StateVariables profile, so this is the
operating point the exporting tool computed, not something recomputed here.
"""
function get_voltage_pu(o::CIMObject)
    if is_class(o, "Terminal")
        o = descend(o, byclass("TopologicalNode", via="TopologicalNode"))
    end
    sv = ascend(o, byclass("SvVoltage"))
    θ = deg2rad(sv["angle"])
    V = sv["v"] / get_base_voltage(o)
    return V * exp(im * θ)
end
function get_voltage_pu(o::CIMCollection)
    tpn = only(o("TopologicalNode"))
    get_voltage_pu(tpn)
end
"""
ATTENTION: we go from load to injector convention
"""
function get_injected_power_pu(o::CIMObject)
    if is_class(o, INJECTOR_CLASSES)
        o = get_connecting_terminal(o)
    end
    sv = try
        ascend(o, byclass("SvPowerFlow"))
    catch e
        # check if it is deactivated
        if is_injector_terminal(o) && !in_service(o)
            return 0.0
        else
            rethrow(e)
        end
    end
    P = sv["p"] / SBASE[]
    Q = sv["q"] / SBASE[]
    return -P - im * Q
end

function get_src_voltage_pu(c::CIMCollection)
    src_node, dst_node = get_tpn_nodes(c)
    get_voltage_pu(src_node)
end
function get_dst_voltage_pu(c::CIMCollection)
    src_node, dst_node = get_tpn_nodes(c)
    get_voltage_pu(dst_node)
end
function get_src_power_pu(c::CIMCollection)
    src_node, dst_node = get_tpn_nodes(c)
    terminals = ascendants(src_node, byclass("Terminal", via="TopologicalNode"))
    Sref = sum(get_injected_power_pu.(terminals); init=0.0+0.0im)
end
function get_dst_power_pu(c::CIMCollection)
    src_node, dst_node = get_tpn_nodes(c)
    terminals = ascendants(src_node, byclass("Terminal", via="TopologicalNode"))
    Sref = sum(get_injected_power_pu.(terminals); init=0.0+0.0im)
end
function get_current_sum_pu(c::CIMCollection)
    tpn = only(c("TopologicalNode"))
    terminals = ascendants(tpn, byclass("Terminal", via="TopologicalNode"))
    @assert all(is_injector_terminal, terminals) "Expected only injector terminals"

    S = sum(get_injected_power_pu.(terminals); init=0.0+0.0im)
    V = get_voltage_pu(tpn)
    conj(S / V)
end

# ---- Consistency checks against the stored powerflow ---------------------------
function check_svv_consistency(pqy::PQYType)
    obj = only(pqy.objs)
    term = get_connecting_terminal(obj)
    S_ref = get_injected_power_pu(term)
    V_ref = get_voltage_pu(term)

    S_shunt = (pqy.G + im * pqy.B) * abs2(V_ref)
    S_pq = pqy.P + im * pqy.Q
    S_total = S_shunt + S_pq

    P_err = abs(real(S_total) - real(S_ref))
    Q_err = abs(imag(S_total) - imag(S_ref))

    if P_err > 1e-6 || Q_err > 1e-6
        name = getname(obj)
        if P_err > 1e-3 || Q_err > 1e-3
            printstyled("⚠ PQY inconsistency at $name: ", color=:yellow)
            printstyled("ΔP=$(str_significant(P_err; sigdigits=3)), ΔQ=$(str_significant(Q_err; sigdigits=3))\n", color=:yellow)
        end
    end
end

function check_svv_consistency(pv::PVType)
    obj = only(pv.objs)
    term = get_connecting_terminal(obj)
    P_ref = real(get_injected_power_pu(term))
    V_ref = abs(get_voltage_pu(term))

    P_err = abs(pv.P - P_ref)
    V_err = abs(pv.V - V_ref)

    if P_err > 1e-6 || V_err > 1e-6
        name = getname(obj)
        if P_err > 1e-3 || V_err > 1e-3
            printstyled("⚠ PV inconsistency at $name: ", color=:yellow)
            printstyled("ΔP=$(str_significant(P_err; sigdigits=3)), ΔV=$(str_significant(V_err; sigdigits=3))\n", color=:yellow)
        end
    end
end

function check_svv_consistency(s::SlackType)
    # Slack nodes should have consistent voltage magnitude
    # For angle reference nodes, we check if voltage from SV matches the setpoint
    if isnan(s.V)
        # NaN voltage means this is just an angle reference without voltage constraint
        return 0.0
    end

    obj = only(s.objs)
    # obj could be TopologicalNode (for angle ref) or a RegulatingControl
    if is_class(obj, "TopologicalNode")
        V_ref = abs(get_voltage_pu(obj))
    else
        term = get_connecting_terminal(obj)
        V_ref = abs(get_voltage_pu(term))
    end

    V_err = abs(s.V - V_ref)

    if V_err > 1e-6
        name = getname(obj)
        if V_err > 1e-3
            printstyled("⚠ Slack inconsistency at $name: ", color=:yellow)
            printstyled("ΔV=$(str_significant(V_err; sigdigits=3))\n", color=:yellow)
        end
    end

    return V_err
end
