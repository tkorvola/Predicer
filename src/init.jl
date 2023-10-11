using JuMP
using HiGHS
using DataFrames
using TimeZones
using Dates
using DataStructures
using XLSX


function get_data(fpath::String, t_horizon::Vector{ZonedDateTime}=ZonedDateTime[])
    return import_input_data(fpath, t_horizon)
end

function build_model_contents_dict(input_data::Predicer.InputData)
    model_contents = OrderedDict()
    model_contents["constraint"] = OrderedDict() #constraints
    model_contents["expression"] = OrderedDict() #expressions?
    model_contents["variable"] = OrderedDict() #variables?
    model_contents["gen_constraint"] = OrderedDict() #GenericConstraints
    model_contents["gen_expression"] = OrderedDict() #GenericConstraints
    input_data_dirs = unique(map(m -> m.direction, collect(values(input_data.markets))))
    res_dir = []
    for d in input_data_dirs
        if d == "up" || d == "res_up"
            push!(res_dir, "res_up")
        elseif d == "dw" || d == "res_dw" || d == "dn" || d == "res_dn" || d == "down" || d == "res_down"
            push!(res_dir, "res_down")
        elseif d == "up/down" || d == "up/dw" || d == "up/dn" ||d == "up_down" || d == "up_dw" || d == "up_dn"
            push!(res_dir, "res_up")
            push!(res_dir, "res_down")
        elseif d != "none"
            msg = "Invalid reserve direction given: " * d
            throw(ErrorException(msg))
        end
    end
    model_contents["res_dir"] = unique(res_dir)
    return model_contents
end

function setup_optimizer(solver::Any)
    m = JuMP.Model(solver)
    set_optimizer_attribute(m, "presolve", "on")
    return m
end

function build_model(model_contents::OrderedDict, input_data::Predicer.InputData)
    create_variables(model_contents, input_data)
    create_constraints(model_contents, input_data)
end

function generate_model(input_data::InputData)
    # get input_data
    #input_data = Predicer.get_data(fpath, t_horizon)
    # Check input_data
    validation_result = Predicer.validate_data(input_data)
    if !validation_result["is_valid"]
        return validation_result["errors"]
    end
    # Resolve potential delays
    if input_data.contains_delay
        input_data = Predicer.resolve_delays(input_data)
    end
    # Build market structures
    input_data = Predicer.resolve_market_nodes(input_data)
    # create mc
    mc = build_model_contents_dict(input_data)
    mc["model"] = setup_optimizer(HiGHS.Optimizer)
    # build model
    build_model(mc, input_data)
    return mc, input_data
end

function solve_hertta(input_data::InputData)

    mc, inputdata = generate_model(input_data)

    solve_model(mc)

end

function print_inputdata(input_data::InputData)

    println("ALKU----------------------------------------------------contains_reserves")
    println(input_data.contains_reserves)
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------contains_online")
    println(input_data.contains_online)
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------contains_states")
    println(input_data.contains_states)
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------contains_piecewise_eff")
    println(input_data.contains_piecewise_eff)
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------contains_risk")
    println(input_data.contains_risk)
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------contains_delay")
    println(input_data.contains_delay)
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------contains_diffusion")
    println(input_data.contains_diffusion)
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------processes")
    for (key, value) in input_data.processes
        println("Key: $key, Value: $value")
        println("-------------")
    end
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------nodes")
    for (key, value) in input_data.nodes
        println("Key: $key, Value: $value")
        println("Value: $value.cost.data")
        println("-------------")
    end
    println("LOPPU----------------------------------------------------")

    
    println("ALKU----------------------------------------------------node_diffusion_tuples")

    for tup in input_data.node_diffusion
        println(tup)
    end
    
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------node_delays")

    for tup in input_data.node_delay
        println(tup)
    end
    
    println("LOPPU----------------------------------------------------")
    

    println("ALKU----------------------------------------------------markets")
    for (key, value) in input_data.markets
        println("Key: $key, Value: $value")
        println("-------------")
    end
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------groups")
    for (key, value) in input_data.groups
        println("Key: $key, Value: $value")
        println("-------------")
    end
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------gen constraints")
    for (key, value) in input_data.gen_constraints
        println("Key: $key, Value: $value")
        println("-------------")
    end
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------scenarios")
    for (key, value) in input_data.scenarios
        println("Key: $key, Value: $value")
        println("-------------")
    end
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------reserve_type")
    for (key, value) in input_data.reserve_type
        println("Key: $key, Value: $value")
        println("-------------")
    end
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------risk")
    for (key, value) in input_data.risk
        println("Key: $key, Value: $value")
        println("-------------")
    end
    println("LOPPU----------------------------------------------------")

    println("ALKU----------------------------------------------------inflow_blocks")
    for (key, value) in input_data.inflow_blocks
        println("Key: $key, Value: $value")
        println("-------------")
    end
    println("LOPPU----------------------------------------------------")

end

"""
function generate_model(fpath::String, t_horizon::Vector{ZonedDateTime}=ZonedDateTime[])
    # get input_data
    input_data = Predicer.get_data(fpath, t_horizon)
    # Check input_data
    validation_result = Predicer.validate_data(input_data)
    if !validation_result["is_valid"]
        return validation_result["errors"]
    end
    # Build market structures
    input_data = Predicer.resolve_market_nodes(input_data)
    # create model_contents
    model_contents = build_model_contents_dict(input_data)
    model_contents["model"] = setup_optimizer(HiGHS.Optimizer)
    # build model
    build_model(model_contents, input_data)
    return model_contents, input_data
end
"""

function solve_model(model_contents::OrderedDict)
    optimize!(model_contents["model"])
end