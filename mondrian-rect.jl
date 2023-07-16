using ProgressMeter

"""
Perfect Mondrian Art Problem Rectangle Solver
- Focus on the case defect = 0
- Paper proves defect = 0 can't be done with less than 9 pieces
- Assumed n >= m

1) Find possibilities with trivial number theory
2) Test with backtracking using top-left-heuristic and rectangles sorted by width
"""

function mondrian(n::Int64, m::Int64; minPieces = 8)
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
            candidates = divsArea[divsArea .<= n .&& area./divsArea .<= n]  # remove all rectangles with a bigger side than the square
            
            if ceil(length(candidates)/2) < r  # there must be at least r viable rectangles
                continue
            end

            rects = Vector{Pair{Int64, Int64}}()
            for i in candidates
                push!(rects, Pair(i, trunc(Int, area/i)))
            end
            push!(combinations, Pair(r, rects))
        end
    end

    println("Combinations possible (n = " * string(n) * ", m = " * string(m) * "): " * string(length(combinations)))

    # 2) Test with backtracking using top-left-heuristic and rectangles sorted by width

    for j in 1 : length(combinations)
        printstyled("Solving (" * string(j) * "/" * string(length(combinations)) * "): n = " * string(n) * ", m = " * string(m) * ", r = " * string(combinations[j][1]) * ", rects = "  * string(combinations[j][2]) * "\n"; color = :green)

        success = solve(n, m, combinations[j][1], combinations[j][2], true)  # solve exact cover problem

        if success
            printstyled("Solution found (" * string(j) * "/" * string(length(combinations)) * "): n = " * string(n) * ", m = " * string(m) * ", r = " * string(combinations[j][1]) * ", rects = "  * string(combinations[j][2]) * "\n"; color = :red)
            exit()
        end
    end

    return false
end

"""
Perfect Mondrian Art Problem Solver
- Specify number of rectangles r
"""
function mondrian(n::Int64, m::Int64, r::Int64)
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

    # 2) Test with backtracking using top-left-heuristic and rectangles sorted by width

    printstyled("Solving (n = " * string(n) * ", m = " * string(m) * ", r = " * string(r) * ", l = " * string(length(candidates)) * ", rects = "  * string(rects) * ")\n"; color = :green)

    return solve(n, m, r, rects, true)
end

function solve(n::Int64, m::Int64, r::Int64, rects::Vector{Pair{Int64, Int64}}, showProg::Bool)
    prog = Progress(Int(ceil(length(rects)/2)); enabled=showProg)

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
        
        while (k <= ceil(s/2) || (k <= s && count > 0)) && !done
            if used[k] == 0 && (i + rects[k][1] - 1 <= n && j + rects[k][2] <= m)  # piece not used and fits
                done = true

                # check permiter of rectangle for collisions with other rectangles

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

        #println(string(k) * " " * string(i) * " " * string(j) * " " * string(done))
        #println(height)

        if done  # rectangle k can be placed on (i, j)
            push!(coords, Pair(i, height[i]))
            height[i : i + rects[k][1] - 1] .+= rects[k][2]

            if count == 0
                ProgressMeter.update!(prog, k)
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

    #println(used)
    #println(coords)

    if count == r  # print solution
        tiles = fill(0, n, m)  # output square

        for l in 1 : length(used)
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

function divisors(n::Int64)
    divs = Vector{Int64}()
    for i in 1 : n
        if n % i == 0
            push!(divs, i)
        end
    end

    return divs
end