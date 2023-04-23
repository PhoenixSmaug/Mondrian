using DataStructures
using ProgressMeter

include("comb-dfs.jl")
include("comb-ilp.jl")
include("cover-ilp.jl")
include("cover-dance.jl")
include("cover-dfs.jl")

"""
Solve the Mondrian Art problem
1) Collect all rectangles up to size nxn in a Priority Queue with descending area
2) Find all subsets of rectangle with area == n^2 and defect <= d
    A) Convert to Integer Programming Problem and Solve with Gurobi
    B) Simple Backtracking with Depth First Search
3) Parallel search starting with solutions of smallest defect
    A) Convert to Exact Cover Problem and Solve with Knuths Dancing Link Algorithm
    B) Convert to Integer Programming Problem and Solve with Gurobi/HiGHS
"""

function mondrian(n::Int64, d::Int64; milp = false, dfs = false, dmin = 0, backtrack = true)
    # 1) Collect all rectangles up to size nxn in a Priority Queue with descending area

    pq = PriorityQueue{Pair{Int64, Int64}, Int64}(Base.Order.Reverse);
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
    coll = PriorityQueue{Vector{Int64}, Int64}()

    if !dfs
        combinationsILP!(coll, areas, n, d)
    else
        combinationsDFS!(coll, fill(-1, length(pq)), areas, n, d)
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

    # 3) Parallel search starting with solutions of smallest defect

    collVec = Vector{Vector{Int64}}()  # convert Priority Queue to Vector for thread access
    for i in coll
        push!(collVec, i[1])
    end

    if (milp)
        @showprogress "Integer Programming" for j in 1 : length(collVec)
            # convert to list of rectangles
            rects = Vector{Pair{Int64, Int64}}()
            for i in 1 : length(collVec[j])
                if collVec[j][i] == 1
                    push!(rects, pairs[i])
                end
            end

            # solve exact cover problem
            success, result = solveILP(n, rects)

            if (success)
                display(result)
                return coll[collVec[j]], result
            end
        end

        return Inf, fill(0, 0, 0)
    else
        done = Threads.Atomic{Bool}(false)  # thread output values
        result = fill(fill(0, 0, 0), Threads.nthreads())
        defect = fill(typemax(Int64), Threads.nthreads())

        p = Progress(length(coll), "Dancing Links using " * string(Threads.nthreads()) * " threads.")  # progress bar
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
            
            success = false
            if backtrack
                for i in length(collVec[j]) : -1 : 1
                    if collVec[j][i] == 1
                        push!(rects, Pair(pairs[i][2], pairs[i][1]))
                    end
                end

                success, result[Threads.threadid()] = solveBacktrack(n, trunc(Int, length(rects)/2), rects)  # using backtracking
            else
                success, result[Threads.threadid()] = solveDancingLinks(n, rects)  # using dancing links
            end

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
end