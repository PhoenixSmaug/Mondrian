using JuMP
using Gurobi

function mondrian(n::Int64, d::Int64, m::Int64)
    # 1) setup

    model = Model(Gurobi.Optimizer)

    set_optimizer_attribute(model, "NonConvex", 2)

    @variable(model, rx[1:m], Int)  # size x direction
    @variable(model, ry[1:m], Int)  # size y direction
    @variable(model, sx[1:m], Int)  # size x direction orientated
    @variable(model, sy[1:m], Int)  # size y direction orientated
    @variable(model, px[1:m], Int)  # x position
    @variable(model, py[1:m], Int)  # y position

    @variable(model, o[1:m], Bin)  # orientation of rectangle
    @variable(model, overlap[1:m, 1:m, 1:4], Bin)  # help variable for overlap
    @variable(model, area[1:m], Int)  # rectangle area
    @variable(model, y1[1:m], Int)  # help variables area
    @variable(model, y2[1:m], Int)

    # 2) constraints

    for i in 1 : m
        @constraint(model, rx[i] >= 1)  # positive side lengths
        @constraint(model, ry[i] >= 1)

        @constraint(model, px[i] >= 0)  # no negative positions
        @constraint(model, py[i] >= 0)

        @constraint(model, px[i] + sx[i] <= n)  # contained in square
        @constraint(model, py[i] + sy[i] <= n)

        @constraint(model, (1 - o[i]) * rx[i] + o[i] * ry[i] == sx[i])  # determine size from orientation
        @constraint(model, o[i] * rx[i] + (1 - o[i]) * ry[i] == sy[i])

        @constraint(model, y1[i] == 0.5 * rx[i] + 0.5 * ry[i])  # calculate area
        @constraint(model, y2[i] == 0.5 * rx[i] - 0.5 * ry[i])
        @constraint(model, area[i] == y1[i]^2 - y2[i]^2)
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