using JuMP
using Gurobi
using Primes
using ProgressMeter
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

    collVec = Vector{Vector{Pair{Int64, Int64}}}()
    d = divisors(n^2)

    for r in d
        if r >= minPieces
            alpha = trunc(Int, n^2/r)  # area of rectangles
            if ceil(alpha/2) >= r  # no effect?
                #println("Work to do for r = " * string(r))
            else
                continue
            end

            dA = divisors(alpha)
            s = dA[dA .<= n .&& alpha./dA .<= n] # filter rectangles bigger than square
            
            if ceil(length(s)/2) < r  # less than r pieces
                continue
            end

            rects = Vector{Pair{Int64, Int64}}()
            for i in 1 : trunc(Int, ceil(length(s)/2))  # either s has even length of complements or odd with square in the center
                push!(rects, Pair(s[i], trunc(Int, alpha/s[i])))
            end

            push!(collVec, rects)
        end
    end

    println("Combinations possible: " * string(length(collVec)))

    @showprogress "Integer Programming" for j in 1 : length(collVec)
        success = solveILP(n, collVec[j])  # solve exact cover problem

        if (success)
            return true
        end
    end

    return false
end

# M. Berger, M. Schröder, K.-H. Küfer, "A constraint programming approach for the two-dimensional rectangular packing problem with orthogonal orientations", Berichte des Fraunhofer ITWM, Nr. 147 (2008).

function solveILP(n::Int64, rects::Vector{Pair{Int64, Int64}})
    @suppress begin  # Gurobi license message

    m = length(rects)  # (width, height)

    model = Model(Gurobi.Optimizer)

    @variable(model, sx[1:m], Int)  # size in x direction
    @variable(model, sy[1:m], Int)  # size in y direction
    @variable(model, px[1:m], Int)  # x position
    @variable(model, py[1:m], Int)  # y position
    @variable(model, o[1:m], Bin)  # orientation of rectangle
    @variable(model, z[1:m, 1:m, 1:4], Bin)  # help variable for overlap

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
            @constraint(model, px[i] - px[j] + sx[i] <= n * (1 - z[i, j, 1]))  # left
            @constraint(model, px[j] - px[i] + sx[j] <= n * (1 - z[i, j, 2]))  # right
            @constraint(model, py[i] - py[j] + sy[i] <= n * (1 - z[i, j, 3]))  # below
            @constraint(model, py[j] - py[i] + sy[j] <= n * (1 - z[i, j, 4]))  # above

            @constraint(model, z[i, j, 1] + z[i, j, 2] <= 1)  # can't be on the left and on the right of another rectangle
            @constraint(model, z[i, j, 4] + z[i, j, 3] <= 1)
            @constraint(model, sum(z[i, j, :]) >= 1)  # one of the cases must be true, rectangles don't overlap
        end
    end

    optimize!(model)

    return has_values(model)

    end  # suppress
end