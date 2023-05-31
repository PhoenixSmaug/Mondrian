using ProgressMeter

"""
Perfect Mondrian Art Problem Solver
- Focus on the case defect = 0
- Paper proves defect = 0 can't be done with less than 9 pieces

1) Find possibilities with trivial number theory
2) Test with backtracking using top-left-heuristic and rectangles sorted by width
"""

function mondrian(n::Int64; minPieces = 9)
    # 1) Find possibilities with trivial number theory

    combinations = Vector{Pair{Int64, Vector{Pair{Int64, Int64}}}}()  # (r, rects)
    divs = divisors(n^2)

    for r in divs  # number of pieces must divide number of tiles
        if r >= minPieces

            area = trunc(Int, n^2/r)
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

    println("Combinations possible (n = " * string(n) * "): " * string(length(combinations)))

    # 2) Test with backtracking using top-left-heuristic and rectangles sorted by width

    for j in 1 : length(combinations)
        printstyled("Solving (" * string(j) * "/" * string(length(combinations)) * "): n = " * string(n) * ", r = " * string(combinations[j][1]) * ", rects = "  * string(combinations[j][2]) * "\n"; color = :green)

        success = solve(n, combinations[j][1], combinations[j][2])  # solve exact cover problem

        if success
            return true
        end
    end

    return false
end

"""
Perfect Mondrian Art Problem Solver
- Specify number of rectangles r
"""
function mondrian(n::Int64, r::Int64)
    # 1) Create vector of combinations 

    area = trunc(Int, n^2/r)
    divsArea = divisors(area)
    candidates = divsArea[divsArea .<= n .&& area./divsArea .<= n]  # remove all rectangles with a bigger side than the square
    
    if ceil(length(candidates)/2) < r  # there must be at least r viable rectangles
        return
    end

    rects = Vector{Pair{Int64, Int64}}()
    for i in candidates
        push!(rects, Pair(i, trunc(Int, area/i)))
    end

    # 2) Test with backtracking using top-left-heuristic and rectangles sorted by width

    printstyled("Solving (n = " * string(n) * ", r = " * string(r) * ", m = " * string(length(candidates)) * ", rects = "  * string(rects) * ")\n"; color = :green)

    return solve(n, r, rects, true)
end

function mondrianParallel(n::Int64, r::Int64)
    # 1) Create vector of combinations 

    area = trunc(Int, n^2/r)
    divsArea = divisors(area)
    candidates = divsArea[divsArea .<= n .&& area./divsArea .<= n]  # remove all rectangles with a bigger side than the square
    
    if ceil(length(candidates)/2) < r  # there must be at least r viable rectangles
        return
    end

    rects = Vector{Pair{Int64, Int64}}()
    for i in candidates
        push!(rects, Pair(i, trunc(Int, area/i)))
    end

    # 2) Test in parallel with backtracking using top-left-heuristic and random permutations based on sorted by width (BLD* Section 3, https://merl.com/publications/docs/TR2003-05.pdf)

    orders = Vector{Vector{Pair{Int64, Int64}}}()  # go through list sorted by widht and accept each element with p = 0.5, repeat until all rectangles are choosen
    push!(orders, rects)

    for i in 1 : Threads.nthreads() - 1
        order = Vector{Pair{Int64, Int64}}()

        while length(order) != length(rects)
            remaining = setdiff(rects, order)

            for j in remaining
                if rand() <= 0.5
                    push!(order, j)
                end
            end
        end

        push!(orders, order)
    end

    result = fill(false, Threads.nthreads())

    Threads.@threads for i = 1 : Threads.nthreads()
        printstyled("Solving in Thread " * string(Threads.threadid()) * "/" * string(Threads.nthreads()) * " (n = " * string(n) * ", r = " * string(r) * ", m = " * string(length(candidates)) * ", rects = "  * string(orders[Threads.threadid()]) * ")\n"; color = :green)

        result[Threads.threadid()] = solve(n, r, orders[Threads.threadid()], Threads.threadid() == 1)  # only show progress of first thread

        if !result[Threads.threadid()]
            println("Thread " * string(Threads.threadid()) * " finished with result = " * string(result[Threads.threadid()]))
            
            exit()  # ugly solution since Julia does not allow program termination without leaving REPL
        end
    end
end


function solve(n::Int64, r::Int64, rects::Vector{Pair{Int64, Int64}}, showProg::Bool)
    prog = ProgressUnknown("Backtracking search:"; enabled = showProg)
    s = length(rects)

    tiles = fill(0, n, n)  # current state of square
    used = fill(0, s)  # rectangles used
    coords = Vector{Pair{Int64, Int64}}()  # remember coordinates
    count = 0  # number of rectangles used
    i = j = kStart = steps = 1

    while count < r && count >= 0
        ProgressMeter.update!(prog, steps)

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

        # next = findfirst(isequal(0), t'); i = next[2]; j = next[1]

        steps += 1
    end

    if count == r  # print solution
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