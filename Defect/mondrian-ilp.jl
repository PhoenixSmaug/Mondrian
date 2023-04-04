"""
Solve the Mondrian Art problem
- Translation to Non-Convex Optimization Problem
- Solve with commercial software Gurobi
"""

using JuMP
using Gurobi

function mondrian(n::Int64, d::Int64, m::Int64)
    # 1) setup

    model = Model(Gurobi.Optimizer)

    set_optimizer_attribute(model, "NonConvex", 2)

    @variable(model, sx[1:m], Int)  # size x direction
    @variable(model, sy[1:m], Int)  # size y direction
    @variable(model, px[1:m], Int)  # x position
    @variable(model, py[1:m], Int)  # y position

    @variable(model, overlap[1:m, 1:m, 1:4], Bin)  # help variable for overlap
    @variable(model, congruent1[1:m, 1:m, 1:4], Bin)  # help variable for non-congruent
    @variable(model, congruent2[1:m, 1:m, 1:4], Bin)
    @variable(model, area[1:m], Int)  # rectangle area

    # 2) constraints

    for i in 1 : m
        @constraint(model, sx[i] >= 1)  # positive side lengths
        @constraint(model, sy[i] >= 1)

        @constraint(model, px[i] >= 0)  # no negative positions
        @constraint(model, py[i] >= 0)

        @constraint(model, px[i] + sx[i] <= n)  # contained in square
        @constraint(model, py[i] + sy[i] <= n)

        @constraint(model, area[i] == sx[i] * sy[i])  # calculate area
    end

    for i in 1 : m
        for j in i + 1 : m
            @constraint(model, px[i] - px[j] + sx[i] <= n * (1 - overlap[i, j, 1]))  # left
            @constraint(model, px[j] - px[i] + sx[j] <= n * (1 - overlap[i, j, 2]))  # right
            @constraint(model, py[i] - py[j] + sy[i] <= n * (1 - overlap[i, j, 3]))  # below
            @constraint(model, py[j] - py[i] + sy[j] <= n * (1 - overlap[i, j, 4]))  # above

            @constraint(model, sum(overlap[i, j, :]) >= 1)  # one of the cases must be true, rectangles don't overlap

            @constraint(model, sx[i] - sx[j] + 1 <= n * (1 - congruent1[i, j, 1]))  # non-congruence
            @constraint(model, sx[j] - sx[i] + 1 <= n * (1 - congruent1[i, j, 2]))
            @constraint(model, sy[i] - sy[j] + 1 <= n * (1 - congruent1[i, j, 3]))
            @constraint(model, sy[j] - sy[i] + 1 <= n * (1 - congruent1[i, j, 4]))

            @constraint(model, sum(congruent1[i, j, :]) >= 1)

            @constraint(model, sx[i] - sy[j] + 1 <= n * (1 - congruent2[i, j, 1]))
            @constraint(model, sy[j] - sx[i] + 1 <= n * (1 - congruent2[i, j, 2]))
            @constraint(model, sy[i] - sx[j] + 1 <= n * (1 - congruent2[i, j, 3]))
            @constraint(model, sx[j] - sy[i] + 1 <= n * (1 - congruent2[i, j, 4]))

            @constraint(model, sum(congruent2[i, j, :]) >= 1)
        end
    end

    for i in 1 : m
        for j in 1 : m
            if (i != j)
                @constraint(model, area[i] - area[j] <= d)  # defect limit
            end  
        end
    end

    @constraint(model, sum(area) == n^2)  # total area n^2

    # 3) optimization and output

    optimize!(model)

    if (has_values(model))  # if solution was found
        output = fill(0, n, n)

        for i in 1 : m
            iPX = Int(round(value(px[i])))
            iPY = Int(round(value(py[i])))
            iSX = Int(round(value(sx[i])))
            iSY = Int(round(value(sy[i])))

            for x in iPX + 1 : iPX + iSX 
                for y in iPY + 1 : iPY + iSY
                    output[y, x] = i
                end
            end
        end

        display(output)
    end
end