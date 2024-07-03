# SDDP support

using DocStringExtensions

using DataStructures
using Accessors
using SDDP

"""
$(TYPEDSIGNATURES)

Add bid curve state variables.  The markets, bid slots and times are obtained
from `inp.bid_slots` and must be identical for all stages, which all must call
this function with `mc["model"]` set to the stage subproblem.  Replaces
`create_v_bid_volume` for SDDP.
"""
function sddp_create_bid_state(mc::OrderedDict, inp::InputData)
    @variable(mc["model"],
              v_bid_volume[(m, s, t) = bid_slot_tuples(inp)]
              ≥ bid_lower_bound(inp.markets[m]),
              SDDP.State, initial_value=0)
end

"""
$(TYPEDSIGNATURES)

Return transition matrices suitable `for SDDP.Markovian[Policy]Graph`.
`inputs[i]` defines the scenarios for stage `i + 1`.  The root node of the
graph is a dummy and defines no subproblem.  It transitions with probability 1
to a single first stage node, then branches by the first set of scenarios to
the second stage.  Typically the first stage bids on markets, which are
cleared at the start of the second stage.  The node indices correspond to the
ordering of `InputData.scenarios`

If you want a multistage (> 2) graph where the transition probabilities also
depend on the scenario transitioned from, build the matrices by other means.
`InputData` cannot represent that.
"""
function sddp_markov_mats(
        inputs::AbstractVector{InputData}) :: Vector{Matrix{Float64}}
    #^ SDDP currently requires a vector of Matrix; AbstractMatrix will not do.
    @assert all(inp.setup.common_timesteps == 0 for inp in inputs)
    p(i) = [values(inputs[i].scenarios)...]'
    [[1.]', (repeat(p(i), i == 1 ? 1 : length(inputs[i - 1].scenarios))
             for i in 1 : length(inputs))...]
end

function sddp_policy_graph(inputs::AbstractVector{InputData}; kws...)
    @assert allequal(inp.bid_slots for inp in inputs)
    SDDP.MarkovianPolicyGraph(
        transition_matrices=sddp_markov_mats(inputs); kws...
    ) do sp, node
        st, sc = node
        if st == 1
            inp = inputs[1]
            scen = ""
            @reset inp.scenarios = OrderedDict()
        else
            inp = inputs[st - 1]
            scen = [keys(inp.scenarios)...][sc]
            @reset inp.scenarios = OrderedDict(scen => 1.)
        end
        mc = build_model_contents_dict(inp)
        mc["model"] = sp
        sddp_create_bid_state(mc, inp)
        if st == 1
            setup_bidding_volume_constraints(mc, inp, sddp=true)
        else
            create_variables(mc, inp, sddp=true)
            create_constraints(mc, inp, sddp=true)
            @stageobjective(sp, mc["expression"]["total_costs"][scen])
        end
    end
end

sddp_risk_measure(inp::InputData) = (
    inp.setup.contains_risk
    ? SDDP.EAVaR(beta = 1 - inp.risk["alfa"], lambda = 1 - inp.risk["beta"])
    : SDDP.Expectation()
)