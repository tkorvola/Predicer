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
    """return mc, input_data"""
    return mc
end

function solve_hertta(input_data::InputData)

    #print_inputdata(input_data)

    mc = generate_model(input_data)

    solve_model(mc)

    df = get_result_df(mc, input_data, "v_flow", "electricheater", "s1")

    return df

    #convert_df_to_vector(df)

    #get_process_data(mc, input_data, "v_state", "electricheater", "s1")

end

function get_result_df(mc::OrderedDict, input_data::Predicer.InputData, type::String, process::String, scenario::String)

    df = get_result_dataframe(mc, input_data, type, process, scenario)
    return df

end

function extract_column_as_vector(df::DataFrame, column_name::String)
    if hasproperty(df, column_name)
        return df[!, column_name]
    else
        throw(ArgumentError("Column '$(column_name)' not found in DataFrame"))
    end
end

function convert_df_to_vector(df::DataFrame)
    num_rows = size(df, 1)
    tuples_vector = [(df[i, 1], df[i, 2]) for i in 1:num_rows]
    return tuples_vector
end

function get_vec_length(vec::Vector{Tuple{String, Float64}})

    vector_length = length(vec)
    return vector_length

end

function print_type(x)
    println("The type of x is: ", typeof(x))
end

function get_first_tuple_value(vec::Vector{Tuple{String, Float64}})
    # Check if the vector is not empty
    if length(vec) > 0
        println(vec[1][1])
        return vec[1][1]
    else
        error("The vector is empty.")
    end
end

function get_value(vec::Vector{Tuple{String, Float64}}, i::Integer, j::Integer)

    if 1 <= i <= length(vec)
        return vec[i][j]
    else
        throw(ArgumentError("Index i is out of bounds for the given vector."))
    end

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