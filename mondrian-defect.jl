using DataStructures
using ProgressMeter
using JuMP, Gurobi, Suppressor

"""
Defect Mondrian Art Problem Solver
- Find minimal defect for given n
- Currently known up to 65 (https://oeis.org/A276523)

Solve the Mondrian Art problem
1) Collect all rectangles up to size nxn in a Priority Queue with descending area
2) Find all subsets of rectangle with area == n^2 and defect <= d
    A) Convert to Integer Programming Problem and Solve with Gurobi
    B) Simple Backtracking with Depth First Search
3) Parallel search starting with solutions of smallest defect by backtracking
"""

function mondrian(n::Int64, d::Int64; milp = true, dmin = 0)
    # 1) Collect all rectangles up to size nxn in a Priority Queue with descending area

    pq = PriorityQueue{Pair{Int64, Int64}, Int64}(Base.Order.Reverse)
    for i in 1 : n
        for j in i : n
            if !(i == j == n)
                pq[Pair(i, j)] = i * j
            end
        end
    end

    # 2) Find all subsets of rectangle with area == n^2 and defect <= d

    areas = Vector{Int64}()
    pairs = Vector{Pair{Int64, Int64}}()
    for i in pq
        push!(pairs, i[1])
        push!(areas, i[2])
    end

    coll = PriorityQueue{Vector{Int64}, Int64}()  # (rects, defect)
    if milp
        combinationsILP!(coll, areas, n, d)  # solve with integer programming
    else
        combinationsDFS!(coll, fill(-1, length(pq)), areas, n, d)  # solve with backtracking
    end

    if isempty(coll)
        println("No combinations possible.")
        return Inf, fill(0, 0, 0)
    end

    # filter defects bigger than dmin
    while peek(coll)[2] < dmin
        dequeue!(coll)
    end

    println("Combinations possible: " * string(length(coll)))

    # 3) Parallel search starting with solutions of smallest defect by backtracking

    collVec = Vector{Vector{Int64}}()  # convert Priority Queue to Vector for thread access
    for i in coll
        push!(collVec, i[1])
    end

    done = Threads.Atomic{Bool}(false)  # thread output values
    result = fill(fill(0, 0, 0), Threads.nthreads())
    defect = fill(typemax(Int64), Threads.nthreads())

    p = Progress(length(coll), "Backtracking using " * string(Threads.nthreads()) * " threads.")  # progress bar
    ProgressMeter.update!(p, 0)
    t = Threads.Atomic{Int64}(0)
    l = Threads.SpinLock()

    Threads.@threads for j in 1 : length(collVec)  # Parallel search
        if done[]  # one thread found a solution
            continue
        end

        # convert to list of rectangles
        rects = Vector{Pair{Int64, Int64}}()
        for i in 1 : length(collVec[j])
            if collVec[j][i] == 1
                push!(rects, pairs[i])
            end
        end

        sort!(rects, rev=true, by = x -> x[2])  # heuristic sort by biggest width

        rectsRot = rects  # rotation by 90 degrees
        for i in length(rects) : -1 : 1
            push!(rectsRot, reverse(rects[i]))
        end

        success, result[Threads.threadid()] = solve(n, rects)  # using backtracking

        Threads.atomic_add!(t, 1)  # progress bar update
        Threads.lock(l)
        ProgressMeter.update!(p, t[])
        Threads.unlock(l)

        if success  # if current thread found solution
            done[] = true
            defect[Threads.threadid()] = coll[collVec[j]]
        end
    end

    if !done[]  # no thread found any solution
        return Inf, fill(0, 0, 0)
    else
        # from all threads with a solution use solution with minimal defect
        best = argmin(defect)
        display(result[best])
        return defect[best], result[best]
    end
end

"""
Combinations via Integer Programming
- Translate into ILP and get all solutions via Gurobi
- Faster than Depth first search
"""

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
            # otherwise left side is negative and the inequality is trivially fulfilled
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

"""
Depth first search
- Backtracking with collection of solutions in Priority Queue
- dfs Vector contains which rectangle are included (1), which are excluded (0) and on which no decision has been made yet (-1)

+------------+---+---+---+----+-----+----+
| Rectangles | 1 | 2 | 3 | 4  | ... | m  |
+------------+---+---+---+----+-----+----+
| dfs Vector | 1 | 0 | 1 | -1 | ... | -1 |
+------------+---+---+---+----+-----+----+
"""

function combinationsDFS!(coll::PriorityQueue{Vector{Int64}, Int64}, dfs::Vector{Int64}, areas::Vector{Int64}, n::Int64, d::Int64)
    # 1) find next rectangle to decide inclusion in subset

    next = findfirst(==(-1), dfs)

    # since all possibilities need to be found, only stop when dfs = [0, ... 0, 1 ... 1]
    firstOne = findfirst(==(1), dfs)
    lastZero = findlast(==(0), dfs)
    if !isnothing(firstOne) && !isnothing(lastZero) && isnothing(next)
        if (firstOne > lastZero)
            return true
        end
    end

    if isnothing(next)
        return false
    end

    # 2) backtracking step for A) include next rectangle in subset or (B) exclude

    # A) include rectangle
    dfs[next] = 1
    valid, area = check(dfs, areas, n, d)

    if (valid)
        if (area == n^2)
            first = findfirst(==(1), dfs)
            last = findlast(==(1), dfs)

            coll[copy(dfs)] = areas[first] - areas[last]  # add solution with defect to Priority Queue
        end

        if (combinationsDFS!(coll, dfs, areas, n, d))
            return true
        end
    end

    # B) exclude rectangle
    dfs[next] = 0
    if (combinationsDFS!(coll, dfs, areas, n, d))
        return true
    end

    dfs[next] = -1

    return false
end

@inline function check(dfs::Vector{Int64}, areas::Vector{Int64}, n::Int64, d::Int64)
    # 1) verify defect <= d

    first = findfirst(==(1), dfs)
    last = findlast(==(1), dfs)
    
    if isnothing(first)  # no square selected
        return true, 0
    end

    if (areas[first] - areas[last] > d)
        return false, 0
    end

    # 2) total area bigger than n^2
    
    area = sum(areas[Bool[dfs[i] == 1 for i = 1 : length(areas)]])

    return (area <= n^2), area
end

"""
Rectangle Packing via Backtracking
- Use top-left heuristic with rectangles sorted by descending height
"""

function solve(n::Int64, rects::Vector{Pair{Int64, Int64}})
    s = length(rects)

    tiles = fill(0, n, n)  # current state of square
    used = fill(0, s)  # rectangles used
    coords = Vector{Pair{Int64, Int64}}()  # remember coordinates
    count = 0  # number of rectangles used
    i = j = kStart = 1

    while count < s/2 && count >= 0
        # 1) Try to place a rectangle on (i, j)

        done = false
        k = kStart
        
        while (k <= ceil(s/2) || (k <= s && count > 0)) && !done
            if used[k] == 0 && (i + rects[k][1] - 1 <= n && j + rects[k][2] - 1 <= n)  # piece not used and fits
                done = true

                # check permiter of rectangle for collisions with other rectangles

                for l = 0 : rects[k][1] - 1
                    if tiles[i + l, j] != 0 || tiles[i + l, j + rects[k][2] - 1] != 0
                        done = false
                        break
                    end
                end

                if done
                    for l = 0 : rects[k][2] - 1
                        if tiles[i, j + l] != 0 || tiles[i + rects[k][1] - 1, j + l] != 0
                            done = false
                            break
                        end
                    end
                end

                if !done
                    k += 1
                end
            else
                k += 1  # try next piece
            end
        end

        if done  # rectangle k can be placed on (i, j)
            push!(coords, Pair(i, j))

            tiles[i : i + rects[k][1] - 1, j : j + rects[k][2] - 1] = fill(k, rects[k][1], rects[k][2])  # fill tiles with selected square

            count += 1
            used[s - k + 1] = -1  # different rotation can't be used anymore
            used[k] = count
            kStart = 1
        else  # no rectangle can be placed anymore, backtrack
            k = argmax(used)  # find which piece was last piece

            if !isempty(coords)
                last = pop!(coords)  # find coordinates of last piece
                tiles[last[1] : last[1] + rects[k][1] - 1, last[2] : last[2] + rects[k][2] - 1] = fill(0, rects[k][1], rects[k][2])  # remove from tiles
            end

            count -= 1
            used[k] = 0
            used[s - k + 1] = 0
            kStart = k + 1
        end

        # find first free tile top left for (i, j)
        i = j = 1
        while tiles[i, j] != 0 && (i < n || (i == n && j < n))
            if j < n
                j += 1
            else
                i += 1
                j = 1
            end
        end
    end

    if count == s/2
        return true, tiles
    else
        return false, fill(0, 0, 0)
    end
end