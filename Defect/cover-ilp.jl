"""
Integer Programming Solver
- Translation into ILP according to M. Berger, M. Schröder, K.-H. Küfer, "A constraint programming approach for the two-dimensional rectangular packing problem with orthogonal orientations", Berichte des Fraunhofer ITWM, Nr. 147 (2008).
- Solving with commercial solver Gurobi (manual install necessary) or open source solver HiGHS
- For rectangle packing far slower than dancing links
"""

using JuMP
using Gurobi
using Suppressor

function solveILP(n::Int64, rects::Vector{Pair{Int64, Int64}})
    # 1) setup

    @suppress begin  # Gurobi license message

    m = length(rects)  # (width, height)

    model = Model(Gurobi.Optimizer)
    #model = Model(HiGHS.Optimizer)

    @variable(model, sx[1:m], Int)  # size in x direction
    @variable(model, sy[1:m], Int)  # size in y direction
    @variable(model, px[1:m], Int)  # x position
    @variable(model, py[1:m], Int)  # y position
    @variable(model, o[1:m], Bin)  # orientation of rectangle
    @variable(model, overlap[1:m, 1:m, 1:4], Bin)  # help variable for overlap

    # 2) constraints

    for i in 1 : m
        @constraint(model, px[i] >= 0)  # no non-negative positions
        @constraint(model, py[i] >= 0)

        @constraint(model, px[i] + sx[i] <= n)  # contained in square
        @constraint(model, py[i] + sy[i] <= n)

        @constraint(model, (1 - o[i]) * rects[i][1] + o[i] * rects[i][2] == sx[i])  # determine size from orientation
        @constraint(model, o[i] * rects[i][1] + (1 - o[i]) * rects[i][2] == sy[i])
    end

    for i in 1 : m
        for j in i + 1 : m
            @constraint(model, px[i] - px[j] + sx[i] <= n * (1 - overlap[i, j, 1]))  # left
            @constraint(model, px[j] - px[i] + sx[j] <= n * (1 - overlap[i, j, 2]))  # right
            @constraint(model, py[i] - py[j] + sy[i] <= n * (1 - overlap[i, j, 3]))  # below
            @constraint(model, py[j] - py[i] + sy[j] <= n * (1 - overlap[i, j, 4]))  # above

            @constraint(model, sum(overlap[i, j, :]) >= 1)  # one of the cases must be true, rectangles don't overlap
        end
    end

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

        return true, output
    end

    return false, fill(0, 0, 0)

    end  # suppress
end