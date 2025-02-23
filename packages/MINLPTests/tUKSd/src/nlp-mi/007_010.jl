function nlp_mi_007_010(optimizer, objective_tol, primal_tol, dual_tol)
    # Test Goals:
    # - infeasible model
    
    m = Model(solver = optimizer)
    
    @variable(m, x, Int)
    @variable(m, y, Int)
    
    @NLconstraint(m, y == exp(x))
    @constraint(m, x == y^2)
    
    status = solve(m)
    
    check_status(status, target=:Infeasible)
    
end

