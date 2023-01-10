using JuMP
using Gurobi
using Suppressor

function combinationsILP!(coll::PriorityQueue{Vector{Int64}, Int64}, areas::Vector{Int64}, n::Int64, d::Int64)
    @suppress begin  # Gurobi license message

    m = length(areas)

    model = Model(Gurobi.Optimizer)
    set_optimizer_attribute(model, "PoolSearchMode", 2)
    set_optimizer_attribute(model, "PoolSolutions", 10e7)

    @variable(model, x[1:m], Bin)  # x[i] <=> i-th rectangle is contained in subset

    # 2) constraints

    @constraint(model, sum(x .* areas) == n^2)  # sum equals n^2

    # defect smaller or equal dmax
    for i in 1 : m
        for j in i + 1 : m
            # defect condition only necessary if rectangle i and j are selected, so x[i] + x[j] = 2 and the left side simplifies to areas[i] - areas[j]
            # otherwise left side is negative andr the inequality is trivially fulfilled
            @constraint(model, (2 * x[i] + 2 * x[j] - 3) * (areas[i] - areas[j]) <= d)
        end
    end

    optimize!(model)

    for i in 1 : result_count(model)
        resAreas = areas[BitArray(Int.(round.(value.(x; result = i))))]
        coll[Int.(round.(value.(x; result = i)))] = maximum(resAreas) - minimum(resAreas)
    end

    end  # suppress
end