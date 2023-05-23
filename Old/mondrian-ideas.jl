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
        printstyled("Solving (" * string(j) * "/" * string(length(combinations)) * "): n = " * string(n) * ", r = " * string(combinations[j][1]) * ", rects = "  * string(combinations[j][2]) * "\n"; color = :green)

        success = solveILP(n, combinations[j][1], combinations[j][2])  # solve exact cover problem

        if (success)
            return true
        end
    end

    return false
end

function solveILP(n::Int64, r::Int64, rects::Vector{Pair{Int64, Int64}})
    #@suppress begin  # Gurobi license message

    m = length(rects)  # (width, height)

    model = Model(Gurobi.Optimizer)
    set_optimizer_attribute(model, "TimeLimit", 3600)

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

function solveDancingLinks(n::Int64, rects::Vector{Pair{Int64, Int64}})
    # 1) Translation into Exact Cover Problem

    m = length(rects)

    table = fill(false, n^2 + m)'  # filler row
    lookup = Dict{Int64, NTuple{5, Int64}}()  # (table row) -> (px, py, sx, sy), allow reconstruction of rectangles from row number

    # generate table
    for i in 1 : m
        for rot in [true, false]
            sx = rot ? rects[i][1] : rects[i][2]
            sy = rot ? rects[i][2] : rects[i][1]

            for px in 0 : n - sx
                for py in 0 : n - sy
                    rectUsed = fill(false, m)'
                    rectUsed[i] = true

                    tileCovered = fill(false, n^2)'

                    for x in px + 1 : px + sx 
                        for y in py + 1 : py + sy
                            tileCovered[x + (y - 1) * n] = true
                        end
                    end

                    lookup[size(table, 1)] = (i, px, py, sx, sy)

                    table = vcat(table, hcat(tileCovered, rectUsed))
                end
            end
        end

        row = fill(false, n^2 + m)'
        row[n^2 + i] = true
        table = vcat(table, row)
    end
    table = table[2 : size(table, 1), :]  # remove filler row

    # construction of dictionaries
    dictX = Dict{Int64, Set{Int64}}()
    dictY = Dict{Int64, Vector{Int64}}()

    for i in 1 : size(table, 1)
        dictY[i] = Vector{Int64}()
    end
    for i in 1 : size(table, 2)
        dictX[i] = Set{Int64}()
    end

    for i in 1 : size(table, 1)
        for j in 1 : size(table, 2)
            if table[i, j]
                push!(dictY[i], j)
                push!(dictX[j], i)
            end
        end
    end

    # 2) Knuths Dancing Link Algorithm

    solution = Stack{Int64}()
    dancingLink!(dictX, dictY, solution)

    # 3) Output

    if !(isempty(solution))  # if solution was found
        output = fill(0, n, n)

        for i in solution
            rect, px, py, sx, sy = lookup[i]

            for x in px + 1 : px + sx 
                for y in py + 1 : py + sy
                    output[y, x] = rect
                end
            end
        end

        return true, output
    end

    return false, fill(0, 0, 0)
end

function dancingLink!(dictX::Dict{Int64, Set{Int64}}, dictY::Dict{Int64, Vector{Int64}}, solution::Stack{Int64})
    # 1) Heuristically choose constraint with least number of variables

    if isempty(dictX)  # no constraints left
        return true
    end

    c = valMin = typemax(Int64)
    for (key, value) in dictX
        if length(value) < valMin
            valMin = length(value)
            c = key
        end
    end

    # 2) backtracking step

    for i in dictX[c]
        push!(solution, i)
        cols = select!(dictX, dictY, i)  # cover rows

        if dancingLink!(dictX, dictY, solution)
            return true
        end

        deselect!(dictX, dictY, i, cols)  # uncover rows
        pop!(solution)
    end

    return false
end

@inline function select!(dictX::Dict{Int64, Set{Int64}}, dictY::Dict{Int64, Vector{Int64}}, r::Int64)
    cols = Stack{Set{Int64}}()
    for j in dictY[r]
        for i in dictX[j]
            for k in dictY[i]
                if k != j
                    delete!(dictX[k], i)
                end
            end
        end

        push!(cols, pop!(dictX, j))  # remember all rows removed while covering
    end

    return cols
end

@inline function deselect!(dictX::Dict{Int64, Set{Int64}}, dictY::Dict{Int64, Vector{Int64}}, r::Int64, cols::Stack{Set{Int64}})
    for j in reverse(dictY[r])
        dictX[j] = pop!(cols)
        for i in dictX[j]
            for k in dictY[i]
                if k != j
                    push!(dictX[k], i)
                end
            end
        end
    end
end