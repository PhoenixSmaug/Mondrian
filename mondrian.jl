using JuMP
using Gurobi
using Primes
using DataStructures
using Suppressor

# https://stackoverflow.com/questions/73988976/optimize-a-divisors-algorithm-in-julia

_tensorprod(A,B) = Iterators.map(x->(x[2],x[1]),Iterators.product(A,B))
tensorprod(A,B) = Iterators.map(x->tuple(Iterators.flatten(x)...),_tensorprod(B,A))

function divisors(n::Int64)
    if (n == 1)
        return [1]
    end

    f = factor(n)
    _f = map(x -> [x[1]^i for i=0:x[2]], sort(collect(f); rev=true))
    return vec(map(prod,foldl(tensorprod, _f)))
end

function mondrian(n::Int64; minPieces = 9)
    # find all rectangle combinations

    combinations = Vector{Pair{Int64, Vector{Pair{Int64, Int64}}}}()
    d = divisors(n^2)

    for r in d
        if r >= minPieces
            area = trunc(Int, n^2/r)  # area of rectangles
            dA = divisors(area)
            s = dA[dA .<= n .&& area./dA .<= n] # filter rectangles bigger than square
            
            if ceil(length(s)/2) < r  # less than r pieces
                continue
            end

            rects = Vector{Pair{Int64, Int64}}()
            for i in 1 : trunc(Int, ceil(length(s)/2))  # either s has even length of complements or odd with square in the center
                push!(rects, Pair(s[i], trunc(Int, area/s[i])))
            end

            push!(combinations, Pair(r, rects))
        end
    end

    println("Combinations possible (n = " * string(n) * "): " * string(length(combinations)))

    for j in 1 : length(combinations)
        printstyled("Solving (" * string(j) * "/" * string(length(combinations)) * "): r = " * string(combinations[j][1]) * ", rects = "  * string(combinations[j][2]) * "\n"; color = :green)

        success = solveILP(n, combinations[j][1], combinations[j][2])  # solve exact cover problem

        if (success)
            return true
        end
    end

    return false
end

# M. Berger, M. Schröder, K.-H. Küfer, "A constraint programming approach for the two-dimensional rectangular packing problem with orthogonal orientations", Berichte des Fraunhofer ITWM, Nr. 147 (2008).

function solveILP(n::Int64, r::Int64, rects::Vector{Pair{Int64, Int64}})
    #@suppress begin  # Gurobi license message

    m = length(rects)  # (width, height)

    model = Model(Gurobi.Optimizer)

    @variable(model, sx[1:m], Int)  # size in x direction
    @variable(model, sy[1:m], Int)  # size in y direction
    @variable(model, px[1:m], Int)  # x position
    @variable(model, py[1:m], Int)  # y position
    @variable(model, o[1:m], Bin)  # orientation of rectangle
    @variable(model, u[1:m], Bin)  # rectangle used in solution
    @variable(model, z[1:m, 1:m, 1:4], Bin)  # help variable for overlap

    @constraint(model, sum(u) == r)  # use r rectangles

    for i in 1 : m
        @constraint(model, px[i] >= 0)  # no non-negative positions (un-unused rectangles are allowed to have negative positions)
        @constraint(model, py[i] >= 0)

        @constraint(model, px[i] + sx[i] <= n)  # contained in square
        @constraint(model, py[i] + sy[i] <= n)

        @constraint(model, (1 - o[i]) * rects[i][1] + o[i] * rects[i][2] == sx[i])  # determine size from orientation
        @constraint(model, o[i] * rects[i][1] + (1 - o[i]) * rects[i][2] == sy[i])
    end

    for i in 1 : m
        for j in i + 1 : m
            # only if u[i] and u[j] are true the condition is relevant
            @constraint(model, px[i] - px[j] + sx[i] <= n * (1 - z[i, j, 1] + (1 - u[i]) + (1 - u[j])))  # left
            @constraint(model, px[j] - px[i] + sx[j] <= n * (1 - z[i, j, 2] + (1 - u[i]) + (1 - u[j])))  # right
            @constraint(model, py[i] - py[j] + sy[i] <= n * (1 - z[i, j, 3] + (1 - u[i]) + (1 - u[j])))  # below
            @constraint(model, py[j] - py[i] + sy[j] <= n * (1 - z[i, j, 4] + (1 - u[i]) + (1 - u[j])))  # above

            @constraint(model, z[i, j, 1] + z[i, j, 2] <= 1)  # can't be on the left and on the right of another rectangle
            @constraint(model, z[i, j, 4] + z[i, j, 3] <= 1)
            @constraint(model, sum(z[i, j, :]) >= 1)  # one of the cases must be true, rectangles don't overlap
        end
    end

    optimize!(model)

    debug = false
    if has_values(model) && debug  # debug output
        output = fill(0, n, n)

        for i in 1 : m
            if Bool(round(value(u[i])))
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
        end
    end

    return has_values(model)

    #end  # suppress
end