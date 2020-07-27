@testset "Basic tests" begin
    optimizer = POI.ParametricOptimizer(GLPK.Optimizer())

    MOI.set(optimizer, MOI.Silent(), true)

    x = MOI.add_variables(optimizer,2)
    y, cy = MOI.add_constrained_variable(optimizer, POI.Parameter(0))
    z = MOI.VariableIndex(4)
    cz = MOI.ConstraintIndex{MOI.SingleVariable, POI.Parameter}(4)

    for x_i in x
        MOI.add_constraint(optimizer, MOI.SingleVariable(x_i), MOI.GreaterThan(0.0))
    end

    @test_throws ErrorException("Cannot constrain a parameter") MOI.add_constraint(optimizer, MOI.SingleVariable(y), MOI.EqualTo(0.0))

    @test_throws ErrorException("Variable not in the model") MOI.add_constraint(optimizer, MOI.SingleVariable(z), MOI.GreaterThan(0.0))

    cons1 = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0, 1.0], [x[1], y]), 0.0)
    
    MOI.add_constraint(optimizer, cons1, MOI.EqualTo(2.0))

    obj_func = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0, 1.0], [x[1], y]), 0.0)
    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), obj_func)
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)

    MOI.optimize!(optimizer)

    @test MOI.get(optimizer, MOI.ObjectiveValue()) == 2

    @test MOI.get(optimizer, MOI.VariablePrimal(), x[1]) == 2

    @test_throws ErrorException("Variable not in the model") MOI.get(optimizer, MOI.VariablePrimal(), z)

    MOI.set(optimizer, MOI.ConstraintSet(), cy, POI.Parameter(1.0))

    @test_throws ErrorException("Parameter not in the model") MOI.set(optimizer, MOI.ConstraintSet(), cz, POI.Parameter(1.0))

    MOI.optimize!(optimizer)

    @test MOI.get(optimizer, MOI.ObjectiveValue()) == 2

    @test MOI.get(optimizer, MOI.VariablePrimal(), x[1]) == 1


    new_obj_func = MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0, 1.0], [x[1], x[2]]), 0.0)
    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(), new_obj_func)
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)

    MOI.optimize!(optimizer)

    @test MOI.get(optimizer, MOI.ObjectiveValue()) == 1

end

@testset "Quadratic parameter x parameter" begin
    ipopt = Ipopt.Optimizer()
    MOI.set(ipopt, MOI.RawParameter("print_level"), 0)
    opt_in = MOIU.CachingOptimizer(MOIU.Model{Float64}(), ipopt)
    optimizer = POI.ParametricOptimizer(opt_in)

    A = [0.0 1.0; 1.0 0.0]
    a = [1.0, 1.0]

    x = MOI.add_variables(optimizer, 2)

    for x_i in x
        MOI.add_constraint(optimizer, MOI.SingleVariable(x_i), MOI.GreaterThan(0.0))
    end

    y, cy = MOI.add_constrained_variable(optimizer, POI.Parameter(1))
    z, cz = MOI.add_constrained_variable(optimizer, POI.Parameter(1))

    quad_terms = MOI.ScalarQuadraticTerm{Float64}[]
    push!(quad_terms, MOI.ScalarQuadraticTerm(A[1,2], y, z))

    objective_function = MOI.ScalarQuadraticFunction(
                            MOI.ScalarAffineTerm.(a, x),
                            quad_terms,
                            0.0
                        )

    MOI.set(optimizer, MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}(), objective_function)
    MOI.set(optimizer, MOI.ObjectiveSense(), MOI.MIN_SENSE)

    MOI.optimize!(optimizer)

    @test isapprox(MOI.get(optimizer, MOI.ObjectiveValue()), 1.0, atol = ATOL)
    @test MOI.get(optimizer, MOI.VariablePrimal(), x[1]) == 0

    MOI.set(optimizer, MOI.ConstraintSet(), cy, POI.Parameter(2.0))
    MOI.optimize!(optimizer)
    @test isapprox(MOI.get(optimizer, MOI.ObjectiveValue()), 2.0, atol = ATOL)

    MOI.set(optimizer, MOI.ConstraintSet(), cz, POI.Parameter(3.0))
    MOI.optimize!(optimizer)
    @test isapprox(MOI.get(optimizer, MOI.ObjectiveValue()), 6.0, atol = ATOL)

    MOI.set(optimizer, MOI.ConstraintSet(), cy, POI.Parameter(5.0))
    MOI.set(optimizer, MOI.ConstraintSet(), cz, POI.Parameter(5.0))
    MOI.optimize!(optimizer)
    @test isapprox(MOI.get(optimizer, MOI.ObjectiveValue()), 25.0, atol = ATOL)

end