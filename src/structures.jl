using DataStructures
using TimeZones

"""
    mutable struct Temporals
        t::Vector{String}
        dtf::Float64
        is_variable_dt::Bool
        variable_dt::Vector{Tuple{String, Float64}}
        ts_format::String
    end

Struct used for storing information about the timesteps in the model.
#Fields
- `t::Vector{String}`: Vector containing the timesteps. 
- `dtf::Float64`: The length between timesteps compared to one hour, if the length of the timesteps don't vary. dt = (t2-t1)/(1 hour)
- `is_variable_dt::Bool`: FLag indicating whether the timesteps vary in length. Default false. 
- `variable_dt::Vector{Tuple{String, Float64}}`: Vector containing the length between timesteps compared to one hour. The first element is the length between t_1 and t_2.
"""

mutable struct Temporals
    t::Vector{String}
    dtf::Float64
    is_variable_dt::Bool
    variable_dt::Vector{Tuple{String, Float64}}
    ts_format::String
end


"""
    function Temporals(ts::Vector{String})

Constructor for the Temporals struct.
"""
function Temporals(ts::Vector{String}, ts_format="yyyy-mm-ddTHH:MM:SSzzzz")
    dts = []
    zdt_ts = map(x -> ZonedDateTime(x, ts_format), ts)
    for i in 1:(length(zdt_ts)-1)
        push!(dts, (ts[i], Dates.Minute(zdt_ts[i+1] - zdt_ts[i])/Dates.Minute(60)))
    end
    if length(unique(map(t -> t[2], dts))) == 1
        return Temporals(ts, dts[1][2], false, [], ts_format)
    elseif length(unique(map(t -> t[2], dts))) > 1
        return Temporals(ts, 0.0, true, dts, ts_format)
    end
end

"""
    function (t::Temporals)(ts::ZonedDateTime)

Returns the length of the timesteps between t and t+1 as a measure how many can fit into 60 minutes.
"""
function (t::Temporals)(ts::ZonedDateTime)
    if t.is_variable_dt
        return filter(x -> x[1] == string(ts), t.variable_dt)[1][2]
    else
        return t.dtf
    end
end


"""
    function (t::Temporals)(ts::String).

Returns the length of the timesteps between t and t+1 as a measure how many can fit into 60 minutes.
"""
function (t::Temporals)(ts::String)
    if t.is_variable_dt
        return filter(x -> x[1] == ts, t.variable_dt)[1][2]
    else
        return t.dtf
    end
end


"""
    get_previous_t(t::Temporals)

Function to get the previous timestep
"""
function get_previous_t(temporals::Temporals)
    previous_ts = OrderedDict()
    for (i, x) in enumerate(temporals.t)
        if i > 1
            previous_ts[x] = temporals.t[i-1]
        end
    end
    return previous_ts
end


"""
    mutable struct State
        in_max::Float64
        out_max::Float64
        state_loss_proportional::Float64
        state_max::Float64
        state_min::Float64
        initial_state::Float64
        is_temp::Bool
        T_E_conversion::Float64
        residual_value::Float64
        function State(in_max, out_max, state_loss_proportional, state_max, state_min=0, initial_state=0, is_temp=0, T_E_conversion=1, residual_value=0)
            return new(in_max, out_max, state_loss_proportional, state_max, state_min, initial_state, is_temp, T_E_conversion, residual_value)
        end
    end

A struct for node states (storage), holds information on the parameters of the state.
# Fields
- `in_max::Float64`: Value for maximum increase of state variable value between timesteps. 
- `out_max::Float64`: Value for maximum decrease of state variable value between timesteps. 
- `state_loss_proportional`: Losses over time in the state, as a proportion of the value of the state.
- `state_max::Float64`: Maximum value for state variable. 
- `state_min::Float64`: Minimum value for state variable. 
- `initial_state::Float64`: Initial value of the state variable at t = 0.
- `is_temp::Bool`: Indicates if the value of the state is temperature (true) or energy (false).
- `T_E_conversion::Float64`: Conversion coefficient between temperature and energy. (E = T_E_conversion * T)
- `residual_value::Float64`: Value of the product remaining in the state after time horizon. 

"""
mutable struct State
    in_max::Float64
    out_max::Float64
    state_loss_proportional::Float64
    state_max::Float64
    state_min::Float64
    initial_state::Float64
    is_temp::Bool
    T_E_conversion::Float64
    residual_value::Float64
    function State(in_max, out_max, state_loss_proportional, state_max, state_min=0, initial_state=0, is_temp=0, T_E_conversion=1, residual_value=0)
        return new(in_max, out_max, state_loss_proportional, state_max, state_min, initial_state, is_temp, T_E_conversion, residual_value)
    end
end


# --- TimeSeries ---
"""
    struct TimeSeries
        scenario::AbstractString
        series::Vector{Tuple{AbstractString, Number}}
        function TimeSeries(scenario="", series=0)
            if series != 0
                return new(scenario, series)
            else
                return new(scenario, [])
            end
        end
    end

A struct for time series. Includes linked scenario and a vector containing tuples of time and value.
"""
struct TimeSeries
    scenario::AbstractString
    series::Vector{Tuple{AbstractString, Number}}
    function TimeSeries(scenario="", series=0)
        if series != 0
            return new(scenario, series)
        else
            return new(scenario, [])
        end
    end
end


"""
    function Base.:length(ts::TimeSeries)

Extends the Base.length() function for the TimeSeries struct. Returns the length of the TimeSeries.series. 
"""
function Base.:length(ts::TimeSeries)
    return length(ts.series)
end


"""
    function Base.:getindex(ts::TimeSeries, i::Int64)

Extends the Base.getindex() function for the TimeSeries struct. Returns the value of the TimeSeries.series at the index. 
"""
function Base.:getindex(ts::TimeSeries, i::Int64)
    return getindex(ts.series, i)
end


"""
    function (ts::TimeSeries)(t::ZonedDateTime)

Returns the value of the TimeSeries at the given timestep. If the exact timestep is not defined, retrieve the value corresponding to the closest previous timestep, or alternatively the first timestep. 
"""
function (ts::TimeSeries)(t::ZonedDateTime)
    st = string(t)
    if st in map(x -> x[1], ts.series)
        return filter(x -> x[1] == st, ts.series)[1][2]
    else
        i = 1
        low = 0
        high = length(ts.series)
        while high - low > 1
            i = Int(ceil((high-low)/2) + low)
            if ts.series[i][1] < st
                low = i
            elseif ts.series[i][1] > st
                high = i
            end
        end
        return ts.series[low][2]
    end
end


"""
    function (ts::TimeSeries)(t::String)

Returns the value of the TimeSeries at the given timestep. If the exact timestep is not defined, retrieve the value corresponding to the closest previous timestep, or alternatively the first timestep. 
"""
function (ts::TimeSeries)(t::String)
    if t in map(x -> x[1], ts.series)
        return filter(x -> x[1] == t, ts.series)[1][2]
    else
        i = 1
        low = 0
        high = length(ts.series)
        while high - low > 1
            i = Int(ceil((high-low)/2) + low)
            if ts.series[i][1] < t
                low = i
            elseif ts.series[i][1] > t
                high = i
            end
        end
        return ts.series[low][2]
    end
end


"""
    struct TimeSeriesData
        ts_data::Vector{TimeSeries}
        function TimeSeriesData()
            return new([])
        end
    end

A struct for storing TimeSeries for different scenarios. 
"""
struct TimeSeriesData
    ts_data::Vector{TimeSeries}
    function TimeSeriesData()
        return new([])
    end
end


"""
    function (tsd::TimeSeriesData)(s::String, t::String)

Returns the value of the TimeSeries for scenario s and timestep t.
"""
function (tsd::TimeSeriesData)(s::String, t::String)
    return tsd(s)(t)
end


"""
    function (tsd::TimeSeriesData)(s::String, t::TimeZones.ZonedDateTime)

Returns the value of the TimeSeries for scenario s and timestep t.
"""
function (tsd::TimeSeriesData)(s::String, t::TimeZones.ZonedDateTime)
    return tsd(s)(t)
end


"""
    function (tsd::TimeSeriesData)(s::String)

Returns the TimeSeries for scenario s. If the scenario is not found, return TimeSeries for the first scenario
"""
function (tsd::TimeSeriesData)(s::String)
    if s in map(x -> x.scenario, tsd.ts_data)
        return filter(ts -> ts.scenario == s, tsd.ts_data)[1]
    end
end


"""
    function Base.:isempty(tsd::TimeSeriesData)

Extends the Base.isempty() function for the TimeSeriesData struct. Returns true if the TimeSeriesData is empty, and false otherwise. 
"""
function Base.:isempty(tsd::TimeSeriesData)
    return isempty(tsd.ts_data)
end

""" 
    struct Group
        name::String
        type::String
        members::Vector{String}
    end

A struct for defining groups of processes or nodes in the model
# Fields
- `name::String`: Name of the group
- `type::String`: Type of the group. Either process or Node
- `members::Vector{String}`: Names of the members in the group. 
"""
struct Group
    name::String
    type::String
    members::Vector{String}
    function Group(name::String, type::String, members::Vector{String}=[])
        return new(name, type, members)
    end
end

"""
    function NodeGroup(name::String, members::Vector{String}=[])

Function to generate a new group of the type 'Node'.
"""
function NodeGroup(name::String, members::Vector{String})
    return Group(name, "node", members)
end


"""
    function NodeGroup(name::String, member::String=[])

Function to generate a new group of the type 'Node'.
"""
function NodeGroup(name::String, member::String)
    return Group(name, "node", [member])
end


"""
    function NodeGroup(name::String)

Function to generate a new group of the type 'Node'.
"""
function NodeGroup(name::String)
    return Group(name, "node", [])
end

"""
    function ProcessGroup(name::String, members::Vector{String}=[])

Function to generate a new group of the type 'Process'.
"""
function ProcessGroup(name::String, members::Vector{String})
    return Group(name, "process", members)
end

"""
    function ProcessGroup(name::String, members::Vector{String}=[])

Function to generate a new group of the type 'Process'.
"""
function ProcessGroup(name::String, member::String)
    return Group(name, "process", [member])
end

"""
    function ProcessGroup(name::String, members::Vector{String}=[])

Function to generate a new group of the type 'Process'.
"""
function ProcessGroup(name::String)
    return Group(name, "process", [])
end

"""
    function add_group_members(group::Group, members::Vector{String})

Function to add names of members to a group.
"""
function add_group_members(group::Group, members::Vector{String})
    for member in members
        push!(group.members, member)
    end
end

"""
    function add_group_members(group::Group, members::String)

Function to add name of member to a group.
"""
function add_group_members(group::Group, member::String)
    push!(group.members, member)
end


# --- Node ---
"""
    mutable struct Node
        name::String
        groups::Vector{String}
        is_commodity::Bool
        is_market::Bool
        is_state::Bool
        is_res::Bool
        is_inflow::Bool
        state::Union{State, Nothing}
        cost::TimeSeriesData
        inflow::TimeSeriesData
    end

A struct for nodes.
# Fields
- `name::String`: Name of the node. 
- `groups::Vector{String}`: Name of the groups this node is a member in.
- `is_commodity::Bool`: Flag indicating of the node is a commodity.
- `is_market::Bool`: Flag indicating of the node is a market node.
- `is_state::Bool`:  Flag indicating of the node has a state (storage).
- `is_res::Bool`: Flag indicating of the node participates as a reserve.
- `is_inflow::Bool`: Flag indicating of the node has a inflow.
- `state::Union{State, Nothing}`: The state of the node.
- `cost::TimeSeriesData`: Vector containing TimeSeries with the costs for each scenario.
- `inflow::TimeSeriesData`: Vector contining TimeSeries with the inflows for each scenario.
"""
mutable struct Node
    name::String
    groups::Vector{String}
    is_commodity::Bool
    is_market::Bool
    is_state::Bool
    is_res::Bool
    is_inflow::Bool
    state::Union{State, Nothing}
    cost::TimeSeriesData
    inflow::TimeSeriesData
end


"""
    function Node(name::String, is_commodity::Bool, is_market::Bool)

Constructor for the Node struct.

# Examples
```julia-repl
julia> n = Node("testNode")
Node("testNode", false, false, false, false, false, nothing, TimeSeries[], TimeSeries[])
```

```julia-repl
julia> n = Node("CommodityNode", true)
Node("CommodityNode", true, false, false, false, false, nothing, TimeSeries[], TimeSeries[])
```

```julia-repl
julia> n = Node("MarketNode", false, true)
Node("MarketNode", false, true, false, false, false, nothing, TimeSeries[], TimeSeries[])
```
"""
function Node(name::String, is_commodity::Bool=false, is_market::Bool=false)
    if is_commodity == true && is_market == true
        error("A Node cannot be a commodity and a market at the same time!")
    else
        return Node(name, [], is_commodity, is_market, false, false, false, nothing, TimeSeriesData(), TimeSeriesData())
    end
end

"""
    function add_group(n::Node, g::Group)

Add a group to the node.
"""
function add_group(n::Node, g::String)
    push!(n.groups, g)
end


"""
    function add_inflow(n::Node, ts::TimeSeries)

Add a inflow timeseries to the Node. A positive inflow adds to the Node, while a negative inflow removes from the Node, and can thus seen as a demand.
"""
function add_inflow(n::Node, ts::TimeSeries)
    if n.is_commodity == true 
        error("A commodity Node cannot have an inflow.")
    elseif n.is_market == true
        error("A market Node cannot have an inflow.")
    else
        n.is_inflow = true
        push!(n.inflow.ts_data, ts)
    end
end


"""
    function add_state(n::Node, s::State)

Adds a State (storage) to the Node. 
"""
function add_state(n::Node, s::State)
    if n.is_commodity == true 
        error("A commodity Node cannot have a state.")
    elseif n.is_market == true
        error("A market Node cannot have a state.")
    else
        n.is_state = true
        n.state = s
    end
end


"""
    function add_to_reserve(n::Node)

Sets a flag which shows that the Node is a reserve node. 
"""
function add_node_to_reserve(n::Node)
    if n.is_commodity == true 
        error("A commodity Node cannot have a reserve.")
    elseif n.is_market == true
        error("A market Node cannot have a reserve.")
    else
        n.is_res = true
    end
end


"""
    function convert_to_commodity(n::Node)

Makes a Node into a commodity Node. 
"""
function convert_to_commodity(n::Node)
    if n.is_res
        error("Cannot convert a Node with reserves into a commodity Node.")
    elseif n.is_state
        error("Cannot convert a Node with a state into a commodity Node.")
    elseif n.is_inflow
        error("Cannot convert a Node with an inflow into a commodity Node.")
    elseif !n.is_market
        n.is_commodity = true
    else
        error("Cannot change a market Node into a commodity Node.")
    end
end


"""
    function convert_to_market(n::Node)

Makes a Node into a market Node. 
"""
function convert_to_market(n::Node)
    if n.is_res
        error("Cannot convert a Node with reserves into a market Node.")
    elseif n.is_state
        error("Cannot convert a Node with a state into a market Node.")
    elseif n.is_inflow
        error("Cannot convert a Node with an inflow into a market Node.")
    elseif !n.is_commodity
        n.is_market = true
    else
        error("Cannot change a commodity Node into a market Node.")
    end
end


"""
    add_cost(n::Node, ts::TimeSeries)

Adds a cost TimeSeries to a Node with is_commodity==true. Returns an error if is_commodity==false
"""
function add_cost(n::Node, ts::TimeSeries)
    if n.is_commodity
        push!(n.cost.ts_data, ts)
    else
        error("Can only add a cost TimeSeries to a commodity Node!")
    end
end


# --- Topology ---
"""
    mutable struct Topology
        source::String
        sink::String
        capacity::Float64
        VOM_cost::Float64
        ramp_up::Float64
        ramp_down::Float64
        cap_ts::TimeSeriesData
        function Topology(source::String, sink::String, capacity::Float64, VOM_cost::Float64, ramp_up::Float64, ramp_down::Float64)
            return new(source, sink, capacity, VOM_cost, ramp_up, ramp_down, TimeSeriesData())
        end
    end

A struct for a process topology, signifying the connection between flows in a process. 
# Fields
- `source::String`: Name of the source of the topology.
- `sink::String`: Name of the sink of the topology.
- `capacity::Float64`: Upper limit of the flow variable for the topology. 
- `VOM_cost::Float64`: VOM cost of using this connection. 
- `ramp_up::Float64`: Maximum allowed increase of the linked flow variable value between timesteps. Min 0.0 max 1.0. 
- `ramp_down::Float64`: Minimum allowed increase of the linked flow variable value between timesteps. Min 0.0 max 1.0.
- `cap_ts::TimeSeriesData`: TimeSeriesStruct
"""
mutable struct Topology
    source::String
    sink::String
    capacity::Float64
    VOM_cost::Float64
    ramp_up::Float64
    ramp_down::Float64
    cap_ts::TimeSeriesData
end


# --- Process ---
"""
    mutable struct Process
        name::String
        groups::Vector{String}
        conversion::Integer # change to string-based: unit_based, market_based, transfer_based
        is_cf::Bool
        is_cf_fix::Bool
        is_online::Bool
        is_res::Bool
        eff::Float64
        load_min::Float64
        load_max::Float64
        start_cost::Float64
        min_online::Int64
        min_offline::Int64
        max_online::Int64
        max_offline::Int64
        initial_state::Bool
        topos::Vector{Topology}
        cf::TimeSeriesData
        eff_ts::TimeSeriesData
        eff_ops::Vector{AbstractString}
        eff_fun::Vector{Tuple{Number, Number}}
    end

A struct for a process (unit).
# Fields
- `name::String`: Name of the process.
- `groups::Vector{String}`: names of the groups this process is a member of. 
- `conversion::String`: Process type; unit, market, or transport based. 
- `is_cf::Bool`: Flag indicating if the process is a cf (capacity factor) process, aka depends on a TimeSeries.
- `is_cf_fix::Bool`: Flag indicating if the cf TimeSeries is a upper limit (false) or a set value (true).
- `is_online::Bool`: Flag indicating if the process has an binary online variable.
- `is_res::Bool`: Flag indicating if the process can participate in a reserve.
- `eff::Float64`: Process conversion efficiency.
- `conversion::Integer`: 
- `load_min::Float64`: Minimum allowed load over the process, min 0, max 1.
- `load_max::Float64`: Maximum allowed load over the process, min 0, max 1.
- `start_cost::Float64`: Cost to start the process, if the 'is_online' flag is true.
- `min_online::Int64`: Minimum time the process has to be online after start.
- `min_offline::Int64`: Minimum time the process has to be offline after start.
- `max_online::Int64`: Maximum time the process can be online after start.
- `max_offline::Int64`: Maximum time the process can be offline after start.
- `initial_state::Bool`: Initial state (on/off) of the process at the start of simulation.
- `topos::Vector{Topology}`: Vector containing the topologies of the process.
- `cf::TimeSeriesData`: Vector containing TimeSeries limiting a cf process.
- `eff_ts::TimeSeriesData`: Vector of TimeSeries containing information on efficiency depending on time.
- `eff_ops::Vector{AbstractString}`: Vector containing operating points for a piecewise efficiency function.
- `eff_fun::Vector{Tuple{Number, Number}}`: Vector containing efficiencies for a piecewise efficiency function.
"""
mutable struct Process
    name::String
    groups::Vector{String}
    conversion::Integer # change to string-based: unit_based, market_based, transfer_based
    delay::Float64
    is_cf::Bool
    is_cf_fix::Bool
    is_online::Bool
    is_res::Bool
    eff::Float64
    load_min::Float64
    load_max::Float64
    start_cost::Float64
    min_online::Int64
    min_offline::Int64
    max_online::Int64
    max_offline::Int64
    initial_state::Bool
    topos::Vector{Topology}
    cf::TimeSeriesData
    eff_ts::TimeSeriesData
    eff_ops::Vector{AbstractString}
    eff_fun::Vector{Tuple{Number, Number}}
end


"""
    function Process(name::String, conversion::Int=1)

The constructor for the Process struct. 

# Arguments:
- `name::String`: The name of the process.
- `conversion::Int`: Used to differentiate between types of process. 1 = unit based, 2 = transfer process, 3 = market process.
"""
function Process(name::String, conversion::Int=1, delay::Float64=0.0)
    return Process(name, [], conversion, delay, false, false, false, false, -1.0, 0.0, 1.0, 0.0, 0, 0, 0, 0, true, [], TimeSeriesData(), TimeSeriesData(), [], [])
end


"""
    function MarketProcess(name::String)

Returns a market based process. 
"""
function MarketProcess(name::String)
    return Process(name, 3)
end


"""
    function TransferProcess(name::String)

Returns a transfer process. 
"""
function TransferProcess(name::String)
    return Process(name, 2)
end


"""
    function add_group(p::Process, g::String)

Add a group to the process.
"""
function add_group(p::Process, g::String)
    push!(p.groups, g)
end

"""
    function add_fixed_eff(p::Process, ts::TimeSeries)

Adds a time-dependent value for the efficiency of the process. 
"""
function add_fixed_eff(p::Process, ts::TimeSeries)
    push!(p.eff_ts.ts_data, ts)
end


"""
    function add_piecewise_eff(p::Process, ops::Vector{Float64}, effs::Vector{Tuple{Float64, Float64}})

Add piecewise efficiency functionality to the process.
"""
function add_piecewise_eff(p::Process, ops::Vector{Float64}, effs::Vector{Tuple{Float64, Float64}})
    if length(ops) == length(effs)
        p.eff_ops = ops
        p.eff_fun = effs
    else
        return error("The length of the operating points vector and efficiency vector must be the same.")
    end
end


"""
    function add_online(p::Process, start_cost::Float64=0, min_online::Float64=0, min_offline::Float64=0, max_online::Float64=0, max_offline::Float64=0, initial_state::Bool=true)

Add binary online functionality to the process.
"""
function add_online(p::Process, start_cost::Float64=0.0, min_online::Float64=0.0, min_offline::Float64=0.0, max_online::Float64=0.0, max_offline::Float64=0.0, initial_state::Bool=true)
    if !p.is_cf
        p.is_online = true
        p.min_online = min_online >= 0 ? min_online : error("Minimum time online cannot be less than 0.")
        p.min_offline = min_offline >= 0 ? min_offline : error("Minimum time offline cannot be less than 0.")
        p.max_online = max_online >= 0 ? max_online : error("Maximum time online cannot be less than 0.")
        p.max_offline = max_offline >= 0 ? max_offline : error("Maximum time offline cannot be less than 0.")
        p.start_cost = start_cost
        p.initial_state = initial_state
    else
        return error("A cf process cannot have online functionality.")
    end
end


"""
    function add_eff(p::Process, eff::Float64)

Add an efficiency to the process. 
"""
function add_eff(p::Process, eff::Float64)
    if eff >= 0.0
        p.eff = eff
    else 
        return error("The given efficiency must be larger than 0.0.")
    end
end

"""
    function add_cf(p::Process, ts::TimeSeries, is_cf_fix::Bool=false)

Adds a capacity factor functionality to a process. Can be called for each scenario to add the TimeSeries. 

# Arguments
- `p::Process`: Process struct.
- `is_cf_fix`: Boolean indicating whether the value of the process is bound (true) to the values given in the TimeSeries, or if the TimeSeries values act as an upper limit (false)
- `ts`: TimeSeries containing the values limiting the process. 
"""
function add_cf(p::Process, ts::TimeSeries, is_fixed::Bool=false)
    if !p.is_online
        p.is_cf = true
        p.is_cf_fix = is_fixed
        push!(p.cf.ts_data, ts)
    else
        return error("Cannot add cf functionality to a process with online functionality.")
    end
end


"""
    function add_to_reserve(p::Process)

Add reserve functionality to a process. 
"""
function add_process_to_reserve(p::Process)
    if !p.is_cf
        p.is_res = true
    else
        return error("A process with cf functionality cannot be a part of a reserve market.")
    end
end


"""
    function add_topology(p::Process, topo::Topology)

Add a new topology (connection) to the process.
"""
function add_topology(p::Process, topo::Topology)
    push!(p.topos, topo)
end


"""
    function add_load_limits(p::Process, min_load::Float64, max_load::Float64)

Add min and max load limitss to a process.
"""
function add_load_limits(p::Process, min_load::Float64, max_load::Float64)
    if min_load >= 0.0 && min_load <= 1.0
        if max_load >= 0.0 && max_load <= 1.0
            if max_load >= min_load
                p.load_min = min_load
                p.load_max = max_load
            else
                return error("The maximum load must be equal to or higher than the min load.")
            end
        else
            return error("The given max load must be between 0.0 and 1.0.")
        end
    else
        return error("The given min load must be between 0.0 and 1.0")
    end
end



# --- Market ---
"""
    struct Market
        name::String
        type::String
        node::AbstractString
        processgroup::AbstractString
        direction::String
        realisation::Dict{String, Float64}
        reserve_type::String
        is_bid::Bool
        price::TimeSeriesData
        up_price::TimeSeriesData
        down_price::TimeSeriesData
        fixed::Vector{Tuple{AbstractString, Number}}
        function Market(name, type, node, pgroup, direction, realisation, reserve_type, is_bid)
            return new(name, type, node, pgroup, direction, realisation, reserve_type, is_bid, [], [])
        end
    end

A struct for markets.
# Fields
- `name::String`: Name of the market. 
- `type::String`: Type of the market (energy/reserve).
- `node::AbstractString`: Name of the node this market is connected to.
- `processgroup::AbstractString`: Name of the group containing information which processes can participate in the market. 
- `direction::String`: Direction of the market (up/down/updown).
- `realisation::Dict{String, Float64}`: Realisation probability for each scenario.
- `reserve_type::String`: Type of the reserve market. 
- `is_bid::Bool`: Is the market biddable. 
- 'is_limited::Bool' : Is the reserve market limited
- 'min_bid::Float64' : Minimum bid for reserve
- 'max_bid::Float64' : Minimum bid for reserve
- 'fee::Float64' : Fee for reserve particiapation
- `price::TimeSeriesData`: Vector containing TimeSeries of the market price in different scenarios. 
- `fixed::Vector{Tuple{AbstractString, Number}}`: Vector containing information on the market being fixed. 
"""
mutable struct Market
    name::String
    type::String
    node::AbstractString
    processgroup::AbstractString
    direction::String
    realisation::Dict{String, Float64}
    reserve_type::String
    is_bid::Bool
    is_limited::Bool
    min_bid::Float64
    max_bid::Float64
    fee::Float64
    price::TimeSeriesData
    up_price::TimeSeriesData
    down_price::TimeSeriesData
    fixed::Vector{Tuple{AbstractString, Number}}
    """
    function Market(name, type, node, pgroup, direction, reserve_type, is_bid, is_limited, min_bid, max_bid, fee)
        return new(name, type, node, pgroup, direction, Dict(), reserve_type, is_bid,  is_limited, min_bid, max_bid, fee, TimeSeriesData(), TimeSeriesData(), TimeSeriesData(), [])
    end
    """
end


# --- ConFactor ---
"""
    struct ConFactor
        var_type::String
        var_tuple::Union{Tuple{AbstractString, AbstractString}, String}
        data::TimeSeriesData
        function ConFactor(var_type, var_tuple)
            return new(var_type, var_tuple, TimeSeriesData())
        end
    end

Struct for general constraints factors.
# Fields
- `var_type::String`: Type of the variable (v_flow, v_state, v_online)
- `var_tuple::Tuple{AbstractString, AbstractString}`: Name/ID of the variable. (p, flow) for v_flow, (n, "") for v_state and (p, "") for v_online.
- `data::TimeSeriesData`: Timeseries containing the coefficients for the variable. 
"""
mutable struct ConFactor
    var_type::String
    var_tuple::Tuple{AbstractString, AbstractString}
    data::TimeSeriesData
    """
    function ConFactor(var_type, var_tuple)
        return new(var_type, var_tuple, TimeSeriesData())
    end
    """
end


"""
    function OnlineConFactor(var_tuple::Tuple{AbstractString, AbstractString})

Function to create a confactor for an online variable. 
"""
function OnlineConFactor(var_tuple)
    return ConFactor("online", var_tuple)
end


"""
    function StateConFactor(var_tuple::Tuple{AbstractString, AbstractString})

Function to create a confactor for a state variable. 
"""
function StateConFactor(var_tuple)
    return ConFactor("state", var_tuple)
end


"""
    function FlowConFactor(var_tuple::Tuple{AbstractString, AbstractString})

Function to create a confactor for a flow variable. 
"""
function FlowConFactor(var_tuple)
    return ConFactor("flow", var_tuple)
end


# --- GenConstraint ---
"""
    struct GenConstraint
        name::String
        type::String
        is_setpoint::Bool
        penalty::Float64
        factors::Vector{ConFactor}
        constant::TimeSeriesData
        function GenConstraint(name,type,is_setpoint=false, penalty=0.0)
            return new(name,type,is_setpoint, penalty, [], TimeSeriesData())
        end
    end

Struct for general constraints.
# Fields
- `name::String`: Name of the generic constraint. 
- `is_setpoint::Bool`: Indicates whether the constraint is a setpoint (=true) with possible deviation from the given value, or fixed (=false) 
- `penalty::Float64`: Name of the generic constraint. 
- `type::String`: Type of the generic constraint. 
- `factors::Vector{ConFactor}`: Vector of ConFactors. 
- `constant::TimeSeriesData`: TimeSeries?
"""
mutable struct GenConstraint
    name::String
    type::String
    is_setpoint::Bool
    penalty::Float64
    factors::Vector{ConFactor}
    constant::TimeSeriesData
end


"""
    struct InflowBlock
        name::String
        node::String
        data::TimeSeriesData
        function InflowBlock(name::String, node::String)
            return new(name, node, TimeSeriesData())
        end
    end
"""
struct InflowBlock
    name::String
    node::String
    data::TimeSeriesData
    function InflowBlock(name::String, node::String)
        return new(name, node, TimeSeriesData())
    end
end

"""
    struct NodeHistory
        node::AbstractString
        steps::Vector{Tuple{String, Float32}}
    end

Struct for defining values for nodes for timesteps before the balance is calculated. For example if there is a delay of 2 between nodes n1 and n2, 
the balance for n2 at the timesteps t1 and t2 (?) are defined using a NodeHistory struct.

# Fields
- `node::AbstractString`: Name of the node.
- `steps::OrderedDict{String, Float32}`: An OrderedDict of timestep-value pairs. 
"""
struct NodeHistory
    node::AbstractString
    steps::TimeSeriesData
    function NodeHistory(node::AbstractString)
        return new(node, TimeSeriesData())
    end
end




"""
    mutable struct InputData
        temporals::Temporals
        contains_reserves::Bool
        contains_online::Bool
        contains_states::Bool
        contains_piecewise_eff::Bool
        contains_risk::Bool
        contains_diffusion::Bool
        contains_delay::Bool
        processes::OrderedDict{String, Process}
        nodes::OrderedDict{String, Node}
        node_diffusion::Vector{Tuple{AbstractString, AbstractString, Number}}
        node_delay::Vector{Tuple{AbstractString, AbstractString, Number, Number, Number}}
        node_histories::OrderedDict{String, NodeHistory}
        markets::OrderedDict{String, Market}
        groups::OrderedDict{String, Group}
        scenarios::OrderedDict{String, Float64}
        reserve_type::OrderedDict{String, Float64}
        risk::OrderedDict{String, Float64}
        inflow_blocks::OrderedDict{String, InflowBlock}
        gen_constraints::OrderedDict{String, GenConstraint}
    end

Struct containing the imported input data, based on which the Predicer is built.
# Fields
- `temporals::Temporals`: The timesteps in the model as a Temporals struct.
- `contains_reserves`: Boolean indicating whether the model (input_data) requires reserve functionality structures. 
- `contains_online::Bool`: Boolean indicating whether the model (input_data) requires online functionality structures. 
- `contains_states::Bool`: Boolean indicating whether the model (input_data) requires state functionality structures. 
- `contains_piecewise_eff::Bool`: Boolean indicating whether the model (input_data) requires piecewise efficiency functionality structures. 
- `contains_risk::Bool`: Boolean indicating whether the model (input_data) requires risk functionality structures. 
- `contains_diffusion::Bool`: Boolean indicating whether the model (input_data) requires diffusion functionality structures. 
- `contains_delay::Bool`: Boolean indicating whether the model (input_data) requires delay functionality structures. 
- `processes::OrderedDict{String, Process}`: A dict containing the data relevant for processes.
- `nodes::OrderedDict{String, Node}`: A dict containing the data relevant for nodes.
- `node_diffusion::Vector{Tuple{AbstractString, AbstractString, Number}}`: Vector containing node diffusion connection details. 
- `node_delay::Vector{Tuple{AbstractString, AbstractString, Number, Number, Number}}`: Vector containing connection details for node delay connections. 
- `node_histories::OrderedDict{String, NodeHistory}`: OrderedDict containing node histories, used in delay functionalities. 
- `markets::OrderedDict{String, Market}`: A dict containing the data relevant for markets.
- `groups::OrderedDict{String, Group}`: A dict containing the data relevant for groups
- `scenarios::OrderedDict{String, Float64}`:  A dict containing the data relevant for scenarios, with scenario name as key and probability as value.
- `reserve_type::OrderedDict{String, Float64}`:  A dict containing the reserve types, with reserve name as key and ramp rate(speed) as value: 1 = 1 hour reaction time, 4 = 15 minutes reaction time, etc. 
- `risk::OrderedDict{String, Float64}`:  A dict containing the data on risk for the cvar calculations, with the risk parameter as key and risk value as value. 
- `gen_constraints::OrderedDict{String, GenConstraint}`:  A dict containing the genconstraints.
"""
mutable struct InputData
    temporals::Temporals
    contains_reserves::Bool
    contains_online::Bool
    contains_states::Bool
    contains_piecewise_eff::Bool
    contains_risk::Bool
    contains_diffusion::Bool
    contains_delay::Bool
    processes::OrderedDict{String, Process}
    nodes::OrderedDict{String, Node}
    node_diffusion::Vector{Tuple{AbstractString, AbstractString, Number}}
    node_delay::Vector{Tuple{AbstractString, AbstractString, Number, Number, Number}}
    node_histories::OrderedDict{String, NodeHistory}
    markets::OrderedDict{String, Market}
    groups::OrderedDict{String, Group}
    scenarios::OrderedDict{String, Float64}
    reserve_type::OrderedDict{String, Float64}
    risk::OrderedDict{String, Float64}
    inflow_blocks::OrderedDict{String, InflowBlock}
    gen_constraints::OrderedDict{String, GenConstraint}
    """
    function InputData(temporals, contains_reserves, contains_online, contains_states, contains_piecewise_eff, contains_risk, contains_diffusion, contains_delay, processes, nodes, node_diffusion, node_delay, node_histories,  markets, groups, scenarios, reserve_type, risk, inflow__blocks, gen_constraints)
        return new(temporals, contains_reserves, contains_online, contains_states, contains_piecewise_eff, contains_risk, contains_diffusion, contains_delay, processes, nodes, node_diffusion, node_delay, node_histories, markets, groups, scenarios, reserve_type, risk, inflow__blocks, gen_constraints)
    end
    """
end


"""Esyn lisäämät"""

global processes_h = OrderedDict{String, Process}()
global nodes_h = OrderedDict{String, Node}()
global markets_h = OrderedDict{String, Market}()
global groups_h = OrderedDict{String, Group}()
global time_series = Vector{TimeSeries}()
global inflowblocks_h = OrderedDict{String, InflowBlock}()
global genconstraints_h = OrderedDict{String, GenConstraint}()
global node_diffusion_tuples_h = Vector{Tuple{String, String, Float64}}()
global node_delay_tuples_h = Vector{Tuple{String, String, Float64, Float64, Float64}}()
global node_histories_h = OrderedDict{String, NodeHistory}()

function print_message(d1::Int, d2::Int, d3::Int, d4::Int)

    println(d1)
    println(d2)
    println(d3)
    println(d4)

end

function print_ordered_dict(ordered_dict::OrderedDict)
    for (key, value) in ordered_dict
        println("Key: $key, Value: $value")
    end
end

"""adding the timeseries should be in this same funcgion? what is that nothing-part?"""

function create_node(name::String, is_commodity::Bool=false, is_market::Bool=false, is_inflow::Bool=false, is_state::Bool=false)
    if is_commodity == true && is_market == true
        error("A Node cannot be a commodity and a market at the same time!")
    else
        return Node(name, [], is_commodity, is_market, is_state, false, is_inflow, nothing, TimeSeriesData(), TimeSeriesData())
    end
end

function add_to_nodes(node::Node)

    push!(nodes_h, node.name => node)

end

function return_nodes()

    return nodes_h

end



function create_topology(source::String, sink::String, capacity::Float64, VOM_cost::Float64, ramp_up::Float64, ramp_down::Float64)

    return Topology(source, sink, capacity, VOM_cost, ramp_up, ramp_down, TimeSeriesData())

end


function create_process(name::String, conversion::Int=1, delay::Float64=0.0)
    return Process(name, [], conversion, delay, false, false, false, false, 1.0, 0.0, 1.0, 0.0, 0, 0, 0, 0, true, [], TimeSeriesData(), TimeSeriesData(), AbstractString[], Tuple{Number, Number}[])
end

function add_group_to_process(p::Process, group::String)

    push!(p.groups, group)

end

function print_process_nodes(processes::OrderedDict{String, Process})
    for (key, value) in processes
        # Print the cost data for each Node
        println("Key: $(key)")
        println("Value: $(value)")
    end
end

function add_to_processes(process::Process)

    push!(processes_h, process.name => process)

end

function return_processes()

    return processes_h

end

function topo_test(p::Process)

    println(length(p.topos))

end

function create_market(name::String, type::String, node::String, pgroup::String, direction::String, reserve_type::String, is_bid::Bool, is_limited::Bool, min_bid::Float64, max_bid::Float64, fee::Float64)
    return Market(name, type, node, pgroup, direction, Dict(), reserve_type, is_bid,  is_limited, min_bid, max_bid, fee, TimeSeriesData(), TimeSeriesData(), TimeSeriesData(), [])
end

function create_vartuple(s1::String, s2::String)

    return (s1, s2)

end

function create_confactor(vartype::String, vartuple::Tuple{String, String})

    return ConFactor(vartype, vartuple, TimeSeriesData())

end

function add_ts_to_confactor(confactor::ConFactor, timeseriesdata::TimeSeriesData)

    confactor.data = timeseriesdata

end

function add_market_prices(market::Market, price::TimeSeriesData)

    market.price = price

end

function add_confactor_to_gc(confactor::ConFactor, gen_constraint::GenConstraint)

    push!(gen_constraint.factors, confactor)


end

function add_market_up_prices(market::Market, price::TimeSeriesData)

    market.up_price = price

end

function add_market_down_prices(market::Market, price::TimeSeriesData)

    market.down_price = price

end

function add_gc_constants(genconstraint::GenConstraint, constants::TimeSeriesData)

    genconstraint.constant = constants

end

function add_to_markets(market::Market)

    push!(markets_h, market.name => market)

end

function return_markets()

    return markets_h

end

function create_group(name::String, type::String, member::String)

    return Group(name, type, [member])

end

function add_to_groups(group::Group)

    push!(groups_h, group.name => group)

end

function return_groups()

    return groups_h

end

function create_genconstraint(name::String,type::String,is_setpoint=false, penalty=0.0)

    return GenConstraint(name,type,is_setpoint, penalty, [], TimeSeriesData())

end


function add_to_genconstraints(genconstraint::GenConstraint)

    push!(genconstraints_h, genconstraint.name => genconstraint)

end

function return_genconstraints()

    return genconstraints_h

end

function return_inflowblocks()

    return inflowblocks_h

end

function create_nodehistory(node::AbstractString)
    return NodeHistory(node, TimeSeriesData())
end

function make_time_point(time_stamp::String, value::Number)

    return (time_stamp, value)

end

function create_timeseries(scenario::String)

    return TimeSeries(scenario, Vector{Tuple{AbstractString, Number}}[])

end

function push_time_point(time_series::TimeSeries, time_point::Tuple{AbstractString, Number})

    push!(time_series.series, time_point)

end

function create_timeseriesdata()

    return TimeSeriesData()

end

function push_timeseries(timeseriesdata::TimeSeriesData, timeseries::TimeSeries)

    push!(timeseriesdata.ts_data, timeseries)

end

function add_inflow_to_node(node::Node, timeseriesdata::TimeSeriesData)

    node.inflow = timeseriesdata

end

function create_temporals()

    temps = 
    ["2022-04-20T00:00:00+00:00",
    "2022-04-20T01:00:00+00:00",
    "2022-04-20T02:00:00+00:00",
    "2022-04-20T03:00:00+00:00",
    "2022-04-20T04:00:00+00:00",
    "2022-04-20T05:00:00+00:00",
    "2022-04-20T06:00:00+00:00",
    "2022-04-20T07:00:00+00:00",
    "2022-04-20T08:00:00+00:00",
    "2022-04-20T09:00:00+00:00"]

    return temps

end

function create_state(in_max, out_max, state_loss_proportional, state_max, state_min=0, initial_state=0, is_temp=0, T_E_conversion=1, residual_value=0)

    return State(in_max, out_max, state_loss_proportional, state_max, state_min, initial_state, is_temp, T_E_conversion, residual_value)

end

function create_node_diffusion_tuple(node1::String, node2::String, diff_coeff::Float64)

    tup = (node1, node2, diff_coeff)
    push!(node_diffusion_tuples_h, tup)

end

function return_node_diffusion_tuples()

    return node_diffusion_tuples_h

end

function create_node_delay_tuple(node1::String, node2::String, delay_t::Float64, min_flow::Float64, max_flow::Float64)

    tup = (node1, node2, delay_t, min_flow, max_flow)
    push!(node_delay_tuples_h, tup)

end

function return_node_delay_tuples()

    return node_delay_tuples_h

end

function return_node_histories()

    return node_histories_h

end

function create_inputdata2(
    
    processes::OrderedDict{String, Process}, 
    nodes::OrderedDict{String, Node}, 
    node_diffusion::Vector{Tuple{String, String, Float64}}, 
    node_delay::Vector{Tuple{String, String, Float64, Float64, Float64}}, 
    node_histories::OrderedDict{String, NodeHistory},  
    markets::OrderedDict{String, Market}, 
    groups::OrderedDict{String, Group},
    gen_constraints::OrderedDict{String, GenConstraint}, 
    scenarios::OrderedDict{String, Float64}, 
    reserve_type::OrderedDict{String, Float64}, 
    risk::OrderedDict{String, Float64}, 
    inflow__blocks::OrderedDict{String, InflowBlock}, 
    contains_reserves::Bool, 
    contains_online::Bool, 
    contains_states::Bool, 
    contains_piecewise_eff::Bool, 
    contains_risk::Bool,
    contains_delay::Bool,  
    contains_diffusion::Bool)

    return InputData(Predicer.Temporals(unique(sort(create_temporals()))), contains_reserves, contains_online, contains_states, contains_piecewise_eff, contains_risk, contains_diffusion, contains_delay, processes, nodes, node_diffusion, node_delay, node_histories, markets, groups, scenarios, reserve_type, risk, inflow__blocks, gen_constraints)

end



