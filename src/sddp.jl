# SDDP support

using SDDP

function create_state(model_contents::OrderedDict, input_data::InputData)
    @variable(model_contents["model"],
              v_bid_volume[(m, s, t) = bid_slot_tuples(input_data)]
              ≥ bid_lower_bound(input_data.markets[m]),
              SDDP.State, initial_value=0)
    model_contents["variable"]["v_bid_volume"] = v_bid_volume
end
