using ProgressMeter


"""
Perfect Mondrian Art Problem Square Solver
"""
function mondrian(n::Int64; perimeterCheck=false)
    return mondrian(n, n, perimeterCheck=perimeterCheck)
end


"""
Perfect Mondrian Art Problem Rectangle Solver
- Focus on the case defect = 0
- Paper proves defect = 0 can't be done with less than 7 pieces (Lemma 2.1)
- Assumed n >= m

1) Find possibilities with trivial number theory
2) Test with backtracking using top-left-heuristic and rectangles sorted by width
"""
function mondrian(n::Int64, m::Int64; minPieces = 7, perimeterCheck=false)
    if m > n
        println("It must be: n >= m")
        return
    end

    # 1) Find possibilities with trivial number theory

    combinations = Vector{Pair{Int64, Vector{Pair{Int64, Int64}}}}()  # (r, rects)
    divs = divisors(n * m)

    for r in divs  # number of pieces must divide number of tiles
        if r >= minPieces

            area = trunc(Int, (n*m)/r)
            divsArea = divisors(area)
            candidates = divsArea[divsArea .<= n .&& area./divsArea .<= m]  # remove all rectangles with a bigger side than the square
            
            if ceil(length(candidates)/2) < r  # there must be at least r viable rectangles
                continue
            end

            rects = Vector{Pair{Int64, Int64}}()
            for i in candidates
                push!(rects, Pair(i, trunc(Int, area/i)))
            end

            if !perimeterCheck || perimeter(rects, n, m, r)  # check if perimeter solutions exist
                push!(combinations, Pair(r, rects))
            end
        end
    end

    println("Combinations possible (n = " * string(n) * ", m = " * string(m) * "): " * string(length(combinations)))

    # 2) Test with backtracking using top-left-heuristic and rectangles sorted by width

    for j in 1 : length(combinations)
        printstyled("Solving (" * string(j) * "/" * string(length(combinations)) * "): n = " * string(n) * ", m = " * string(m) * ", r = " * string(combinations[j][1]) * ", rects = "  * string(combinations[j][2]) * "\n"; color = :green)

        success = solve(n, m, combinations[j][1], combinations[j][2], true)  # solve exact cover problem

        if success
            printstyled("Solution found (" * string(j) * "/" * string(length(combinations)) * "): n = " * string(n) * ", m = " * string(m) * ", r = " * string(combinations[j][1]) * ", rects = "  * string(combinations[j][2]) * "\n"; color = :red)
            return true
        else
            printstyled("\nNo Solution (" * string(j) * "/" * string(length(combinations)) * "): n = " * string(n) * ", m = " * string(m) * ", r = " * string(combinations[j][1]) * ", rects = "  * string(combinations[j][2]) * "\n"; color = :yellow)
        end
    end

    return false
end


"""
Perfect Mondrian Art Problem Solver
- Specify number of rectangles r
"""
function mondrian(n::Int64, m::Int64, r::Int64; perimeterCheck=true)
    if m > n
        println("n must be bigger than m")
        return
    end

    # 1) Create vector of combinations 

    area = trunc(Int, (n*m)/r)
    divsArea = divisors(area)
    candidates = divsArea[divsArea .<= n .&& area./divsArea .<= n]  # remove all rectangles with a bigger side than the square
    
    if ceil(length(candidates)/2) < r  # there must be at least r viable rectangles
        return false
    end

    rects = Vector{Pair{Int64, Int64}}()
    for i in candidates
        push!(rects, Pair(i, trunc(Int, area/i)))
    end

    if perimeterCheck && !perimeter(rects, n, m, r)  # check if perimeter solutions exist
        return false
    end

    # 2) Test with backtracking using top-left-heuristic and rectangles sorted by width

    printstyled("Solving (n = " * string(n) * ", m = " * string(m) * ", r = " * string(r) * ", l = " * string(length(candidates)) * ", rects = "  * string(rects) * ")\n"; color = :green)

    return solve(n, m, r, rects, true)
end


"""
Solve rectangle packing with backtracking using top-left-heuristic and rectangles sorted by width
"""
function solve(n::Int64, m::Int64, r::Int64, rects::Vector{Pair{Int64, Int64}}, showProg::Bool)
    prog = Progress(Int(ceil(length(rects)/2) * (length(rects)-2) * (length(rects)-4)); enabled=showProg)

    s = length(rects)

    height = fill(0, n)  # save height stored in each row
    used = fill(0, s)  # rectangles used
    coords = Vector{Pair{Int64, Int64}}()  # remember coordinates
    count = 0  # number of rectangles used
    i = kStart = 1
    j = 0

    while count < r && count >= 0
        # 1) Try to place a rectangle on (i, j)

        done = false
        k = kStart
        
        while k <= s && !done
            if n == m && count == 0 && k > ceil(s/2)  # if bounding box is a square we can use symmetry and restrict ourself to not rotating the first rectangle
                break
            end

            if used[k] == 0 && (i + rects[k][1] - 1 <= n && j + rects[k][2] <= m)  # piece not used and fits
                done = true

                # check perimeter of rectangle for collisions with other rectangles

                for l = 1 : rects[k][1] - 1
                    if height[i+l] > height[i]
                        done = false
                        break
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
            push!(coords, Pair(i, height[i]))
            height[i : i + rects[k][1] - 1] .+= rects[k][2]

            if count == 2
		        ProgressMeter.next!(prog)
            end

            count += 1
            used[s - k + 1] = -1  # different rotation can't be used anymore
            used[k] = count
            kStart = 1
        else  # no rectangle can be placed anymore, backtrack
            k = argmax(used)  # find which piece was last piece

            if !isempty(coords)
                last = pop!(coords)  # find coordinates of last piece
                height[last[1] : last[1] + rects[k][1] - 1] .-= rects[k][2]  # remove from tiles
            end

            count -= 1
            used[k] = 0
            used[s - k + 1] = 0
            kStart = k + 1
        end
        
        j = minimum(height)
        i = findfirst(height .== j)  # can't use argmin, since i needs to be minimal such that height[i] = j
    end

    if count == r  # print solution
        tiles = fill(0, n, m)  # output square

        for l in eachindex(used)
            if used[l] >= 1
                i = coords[used[l]][1]
                j = coords[used[l]][2] + 1  # since j is the minimal value of height, it is zero-indexed
    
                tiles[i : i + rects[l][1] - 1, j : j + rects[l][2] - 1] = fill(used[l], rects[l][1], rects[l][2])
            end
        end
        
        display(tiles)
        return true
    else
        return false
    end
end


"""
Check if a perimeter solution exists
"""
function perimeter(rects::Vector{Pair{Int64, Int64}}, n::Int64, m::Int64, r::Int64)
    verticalPre = Vector{Vector{Pair{Int64, Int64}}}()
    horizontalPre = Vector{Vector{Pair{Int64, Int64}}}()

    # find all subsets with backtracking
    subsets!(verticalPre, fill(-1, length(rects)), rects, n, true)
    subsets!(horizontalPre, fill(-1, length(rects)), rects, m, false)

    # remove subsets which contain rectangles in both orientations
    vertical = Vector{Vector{Pair{Int64, Int64}}}()
    horizontal = Vector{Vector{Pair{Int64, Int64}}}()
    for s in verticalPre
        if length(s) == length(Set(Tuple(sort([pair[1], pair[2]])) for pair in s))
            push!(vertical, s)
        end
    end
    for s in horizontalPre
        if length(s) == length(Set(Tuple(sort([pair[1], pair[2]])) for pair in s))
            push!(horizontal, s)
        end
    end

    # find neighbours of subsets, meaning the side of the perimeter they fill could be neighboured
    neighbours = Dict{Vector{Pair{Int64, Int64}},Set{Vector{Pair{Int64, Int64}}}}()
    for s in union(vertical, horizontal)
        neighbours[s] = Set{Vector{Pair{Int64, Int64}}}()
    end
    for v in vertical
        for h in horizontal
            if length(intersect(Set(v), Set(h))) == 1 # v and h have exactly one element in common
                if length(union(Set(v), Set(h))) == length(Set(Tuple(sort([pair[1], pair[2]])) for pair in union(Set(v), Set(h))))  # v and h dont have one rectangle in both orientations
                    push!(neighbours[v], h)
                    push!(neighbours[h], v)
                end
            end
        end
    end

    # find solution for perimeter by checking if two neighbours of v share a neighbour w except v
    #solutions = Vector{Vector{Vector{Pair{Int64, Int64}}}}()
    for i in eachindex(vertical)
        v = vertical[i]
        for h1 in neighbours[v]
            for h2 in neighbours[v]
                if h1 != h2 && length(union(Set(h1), Set(h2))) == length(Set(Tuple(sort([pair[1], pair[2]])) for pair in union(Set(h1), Set(h2))))  # h1 and h2 dont have one rectangle in both orientations
                    sharedRectsHorizontal = intersect(Set(h1), Set(h2))
                    if all(x -> x[1] == n, sharedRectsHorizontal)  # h1 and h2 are disjoint or their common rectangle covers entire vertical side
                        for j in 1 : i-1
                            w = vertical[j]
                            if (w in neighbours[h1]) && (w in neighbours[h2])
                                sharedRectsVertical = intersect(Set(v), Set(w))
                                if all(x -> x[2] == m, sharedRectsVertical)  # v and w are disjoint or their common rectangle covers entire horizontal side
                                    if length(union(Set(v), Set(w))) == length(Set(Tuple(sort([pair[1], pair[2]])) for pair in union(Set(v), Set(w))))  # v and w dont have one rectangle in both orientations
                                        if length(union(h1, w, h2, v)) <= r   # perimeter uses at most r rectangles
                                            return true
                                            #push!(solutions, [h1, w, h2, v])
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    #return solutions
    return false
end


"""
Find all subsets of rects where the first column sums to n or where the second column sums to n if firstColumn is set to false
    
- dfs Vector contains which rectangle are included (1), which are excluded (0) and on which no decision has been made yet (-1)
+------------+---+---+---+----+-----+----+
| Rectangles | 1 | 2 | 3 | 4  | ... | m  |
+------------+---+---+---+----+-----+----+
| dfs Vector | 1 | 0 | 1 | -1 | ... | -1 |
+------------+---+---+---+----+-----+----+
"""
function subsets!(coll::Vector{Vector{Pair{Int64, Int64}}}, dfs::Vector{Int64}, rects::Vector{Pair{Int64, Int64}}, target::Int64, firstColumn)
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

    dfs[next] = 1  # include rectangle
    total = 0  # calculate sum
    if firstColumn
        total = sum(r[1] for (r, b) in zip(rects, dfs) if b == 1)
    else
        total = sum(r[2] for (r, b) in zip(rects, dfs) if b == 1)
    end

    if (total <= target)
        if (total == target)  # solution found
            push!(coll, [r for (r, b) in zip(rects, dfs) if b == 1])  # add solution to output list
        end

        if (subsets!(coll, dfs, rects, target, firstColumn))
            return true
        end
    end

    dfs[next] = 0  # exclude rectangle
    if (subsets!(coll, dfs, rects, target, firstColumn))
        return true
    end

    dfs[next] = -1

    return false
end


"""
Return divisors of n in ascending order
"""
function divisors(n::Int64)
    divs = Vector{Int64}()
    for i in 1 : n
        if n % i == 0
            push!(divs, i)
        end
    end

    return divs
end