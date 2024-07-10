@testset "Predicer on $bn" for (bn, known_obj) in cases
    m = Model(Optimizer)
    silent && set_silent(m)
    mc = Predicer.generate_model(m, get_input(bn))
    @test m == mc["model"]
    Predicer.solve_model(mc)
    @test JuMP.termination_status(m) == MOI.OPTIMAL
    @test objective_value(m) ≈ known_obj rtol=obj_rtol(m) skip=isnan(known_obj)
    @show objective_value(m) known_obj relative_gap(m)
end
