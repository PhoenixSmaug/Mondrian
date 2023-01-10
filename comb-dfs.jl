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