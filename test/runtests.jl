#= In the project root directory:
    ]activate .
    ]test
=#

using Predicer
using Test
using JuMP
using DataStructures
using SDDP

using HiGHS: Optimizer
#using Cbc: Optimizer
#using CPLEX: Optimizer

# Model definition files and objective values.  obj = NaN to disable
# comparison.
cases = OrderedDict(
    "input_data.xlsx" => -10985.034456374564,
    "input_data_complete.xlsx" => -7139.999025659914,
    "input_data_bidcurve.xlsx" => -4371.579033779262,
    "input_data_bidcurve_e.xlsx" => -4501.509824681449,
    "demo_model.xlsx" => -1095.5118308122817,
    "example_model.xlsx" => -11014.1278942231,
    "input_data_common_start.xlsx" => -1574.9410327933133,
    "input_data_delays.xlsx" => 62.22222222222222,
    "input_data_temps.xlsx" => 65388.35282275837,
    "simple_building_model.xlsx" => 563.7841038762567,
    "simple_dh_model.xlsx" => 7195.372539092246,
    #"simple_hydropower_river_system.xlsx" => NaN,
    "two_stage_dh_model.xlsx" => 9508.652488524222,
)

# SDDP test cases with lower bounds.
# I think these have to be for the best scenario, at least for multicut.
# A bound for the expected cost may do for single cut.
sddp_cases = OrderedDict(
    "input_data_bidcurve.xlsx" => -12000,
    "input_data_bidcurve_e.xlsx" => -12000,
)

inputs = Dict{String, Predicer.InputData}()

get_input(bn) = get!(inputs, bn) do
    inp = Predicer.get_data(joinpath("..", "input_data", bn))
    Predicer.tweak_input!(inp)
end

include("../make-graph.jl")

function obj_rtol(m)
    rgap = relative_gap(m)
    # Apparently infinite for LP
    if rgap < 1e-8 || !isfinite(rgap)
        return 1e-8
    else
        return rgap
    end
end

@testset "make-graph on $bn" for (bn, _) in cases
    of = joinpath("..", "input_data",
                  replace(bn, r"[.][^.]*$" => "") * ".dot")
    println("$bn |-> $of")
    @test (write_graph(of, get_input(bn)); true)
end

@testset "Predicer on $bn" for (bn, obj) in cases
    m = Model(Optimizer)
    #set_silent(m)
    mc = Predicer.generate_model(m, get_input(bn))
    @test m == mc["model"]
    Predicer.solve_model(mc)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test objective_value(m) ≈ obj rtol=obj_rtol(m) skip=isnan(obj)
    @show objective_value(m) obj relative_gap(m)
end

@testset "Scenarios on $bn" for (bn, spobj) in cases
    inp = get_input(bn)
    mcs = [Predicer.generate_model(Model(Optimizer),
                                   Predicer.scen_subproblem(inp, sc))
           for sc in keys(inp.scenarios)]
    ms = getindex.(mcs, "model")
    set_silent.(ms)
    Predicer.solve_model.(mcs)
    @test all(JuMP.termination_status.(ms) .== MOI.OPTIMAL)
    min_obj, max_obj = extrema(objective_value.(ms))
    lower_bound = get(sddp_cases, bn, -Inf)
    @test min_obj ≥ lower_bound
    @test min_obj ≤ spobj skip=isnan(spobj)
    @show lower_bound min_obj spobj max_obj
end

@testset "SDDP on $bn" for (bn, lower_bound) in sddp_cases
    obj = cases[bn]
    @assert lower_bound ≤ obj
    inp = get_input(bn)
    pg = Predicer.sddp_policy_graph(
        [inp]; lower_bound, optimizer=Optimizer)
    dem = SDDP.deterministic_equivalent(pg, Optimizer)
    optimize!(dem)
    @test JuMP.termination_status(dem) == MOI.OPTIMAL
    @test(objective_value(dem) ≈ obj, rtol=obj_rtol(dem),
          skip=isnan(obj) || inp.setup.contains_risk)
    @test objective_value(dem) ≥ lower_bound
    @show(inp.setup.contains_risk, objective_value(dem), obj,
          relative_gap(dem), lower_bound)
    risk_measure = Predicer.sddp_risk_measure(inp)
    SDDP.train(pg; risk_measure,
               cut_type=SDDP.MULTI_CUT,
               #iteration_limit=100,
               )
    obj_bound = SDDP.calculate_bound(pg; risk_measure)
    @test obj - obj_bound ≥ -1e-4
    @show obj_bound
end
