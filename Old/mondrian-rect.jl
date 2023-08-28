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

function mondrian(n::Int64, m::Int64, r::Int64, force::Int64)
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
    for i in 1 : length(candidates)
        if i != force && i != length(candidates) - force + 1
            push!(rects, Pair(candidates[i], trunc(Int, area/candidates[i])))
        end
    end

    rect = Pair(candidates[force], trunc(Int, area/candidates[force]))

    # 2) Test with backtracking using top-left-heuristic and rectangles sorted by width

    printstyled("Solving (n = " * string(n) * ", m = " * string(m) * ", r = " * string(r) * ", l = " * string(length(candidates)) * ", rects = "  * string(rects) * ", rect = " * string([rect]) * ")\n"; color = :green)
    result = solveForceRect(n, m, r, rects, rect, true)
        
    if result
        println("AAAAAAAAALLLLLLLAAAAAAAARRRRRRMMMMMM")
        printstyled("\nSolved "* ARGS[1] *" \n"; color = :red)
    else
        printstyled("\nSolved "* ARGS[1] *" \n"; color = :yellow)
    end
end

function mondrian(n::Int64, m::Int64, r::Int64, forceA::Int64, forceB::Int64)
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
    for i in 1 : length(candidates)
        if i != forceA && i != length(candidates) - forceA + 1 && i != forceB && i != length(candidates) - forceB + 1
            push!(rects, Pair(candidates[i], trunc(Int, area/candidates[i])))
        end
    end

    rectA = Pair(candidates[forceA], trunc(Int, area/candidates[forceA]))
    rectB = Pair(candidates[forceB], trunc(Int, area/candidates[forceB]))

    # 2) Test with backtracking using top-left-heuristic and rectangles sorted by width

    printstyled("Solving (n = " * string(n) * ", m = " * string(m) * ", r = " * string(r) * ", l = " * string(length(candidates)) * ", rects = "  * string(rects) * ", rectA = " * string([rectA]) * ", rectB = " * string([rectB]) * ")\n"; color = :green)
    result = solveForceRect(n, m, r, rects, rectA, rectB, true)
        
    if result
        println("AAAAAAAAALLLLLLLAAAAAAAARRRRRRMMMMMM")
        printstyled("\nSolved "* ARGS[1] * ", " * ARGS[2] * " \n"; color = :red)
    else
        printstyled("\nSolved "* ARGS[1] * ", " * ARGS[2] * " \n"; color = :yellow)
    end
end

function mondrianParallel(n::Int64, m::Int64, r::Int64)
    area = trunc(Int, (n*m)/r)
    divsArea = divisors(area)
    candidates = divsArea[divsArea .<= n .&& area./divsArea .<= n]
    if ceil(length(candidates)/2) < r  # there must be at least r viable rectangles
        return false
    end

    combs = Vector{Pair{Int64, Int64}}()
    for i in 1 : ceil(length(candidates)/2)
        for j in 1 : ceil(length(candidates)/2)
            if i != j
                push!(combs, Pair(i, j))
            end
        end
    end

    Threads.@threads for c in combs
        mondrian(n, m, r, c[1], c[2])
    end
end


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
            if used[k] == 0 && (i + rects[k][1] - 1 <= n && j + rects[k][2] <= m)  # piece not used and fits
                done = true

                # check perimiter of rectangle for collisions with other rectangles

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

function solve2(n::Int64, m::Int64, r::Int64, rects::Vector{Pair{Int64, Int64}}, showProg::Bool)
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
        
        while (k <= ceil(s/2) || (k <= s && count > 0)) && !done
            if used[k] == 0  # piece has not been used yet
                if i + rects[k][1] - 1 <= n  # piece fits horizontally
                    if j + rects[k][2] <= m
                        indexFirst = findfirst(used .== 1)
                        if isnothing(indexFirst)
                            indexFirst = 0
                        end

                        if (i + rects[k][1] != n ||  # piece does not reach horizontal end
                        height[n] != 0 || # piece reaches horizontal end but not at bottom of square
                        indexFirst == 0 || # piece is at bottom right but it's thr first piece
                        (k > indexFirst && k < s+1-indexFirst))  # piece is at bottom right and not the first one but its index is symmetry-breaking
                            done = true

                            for l = 1 : rects[k][1] - 1
                                if height[i+l] > height[i]
                                    done = false
                                    break
                                end
                            end

                            if !done
                                k = s+1  # piece did not fit and neither will the next ones
                            end
                        else
                            k += 1
                        end
                    else
                        k += 1
                    end
                else
                    k = s+1  # piece cannot fit horizontally, so next ones won't either
                end
            else
                k += 1
            end
        end

        #println(string(k) * " " * string(i) * " " * string(j) * " " * string(done))
        #println(height)

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

# force rect to be placed in upper left corner in given rotation
function solveForceRect(n::Int64, m::Int64, r::Int64, rects::Vector{Pair{Int64, Int64}}, rect::Pair{Int64, Int64}, showProg::Bool)
    prog = Progress(Int(ceil(length(rects)/2) * (length(rects)-2) * (length(rects)-4)); enabled=showProg)

    s = length(rects)

    height = fill(0, n)  # save height stored in each row
    height[1 : rect[1]] .+= rect[2]  # height from forced rectangle

    used = fill(0, s)  # rectangles used
    coords = Vector{Pair{Int64, Int64}}()  # remember coordinates
    count = 0  # number of rectangles used
    kStart = 1

    j = minimum(height)
    i = findfirst(height .== j)

    while count < r && count >= 0
        # 1) Try to place a rectangle on (i, j)

        done = false
        k = kStart
        
        while k <= s && !done
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

        tiles[1 : rect[1], 1: rect[2]] = fill(1, rect[1], rect[2])

        for l in 1 : length(used)
            if used[l] >= 1
                i = coords[used[l]][1]
                j = coords[used[l]][2] + 1  # since j is the minimal value of height, it is zero-indexed
    
                tiles[i : i + rects[l][1] - 1, j : j + rects[l][2] - 1] = fill(used[l] + 1, rects[l][1], rects[l][2])
            end
        end
        
        display(tiles)
        return true
    else
        return false
    end
end

function solveForceRect(n::Int64, m::Int64, r::Int64, rects::Vector{Pair{Int64, Int64}}, rectA::Pair{Int64, Int64}, rectB::Pair{Int64, Int64}, showProg::Bool)
    prog = Progress(Int(ceil(length(rects)/2) * (length(rects)-2) * (length(rects)-4)); enabled=showProg)

    s = length(rects)

    if rectA[1] + rectB[1] > n
        return false
    end

    height = fill(0, n)  # save height stored in each row
    height[1 : rectA[1]] .+= rectA[2]  # height from forced rectangle
    height[rectA[1] + 1 : rectA[1] + rectB[1]] .+= rectB[2]

    used = fill(0, s)  # rectangles used
    coords = Vector{Pair{Int64, Int64}}()  # remember coordinates
    count = 0  # number of rectangles used
    kStart = 1

    j = minimum(height)
    i = findfirst(height .== j)

    while count < r && count >= 0
        # 1) Try to place a rectangle on (i, j)

        done = false
        k = kStart
        
        while k <= s && !done
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

        tiles[1 : rectA[1], 1 : rectA[2]] = fill(1, rectA[1], rectA[2])
        tiles[rectA[1] + 1 : rectA[1] + rectB[1], 1 : rectB[2]] = fill(2, rectB[1], rectB[2])

        for l in 1 : length(used)
            if used[l] >= 1
                i = coords[used[l]][1]
                j = coords[used[l]][2] + 1  # since j is the minimal value of height, it is zero-indexed
    
                tiles[i : i + rects[l][1] - 1, j : j + rects[l][2] - 1] = fill(used[l] + 2, rects[l][1], rects[l][2])
            end
        end
        
        display(tiles)
        return true
    else
        return false
    end
end

function completeVec(rects::Vector{Pair{Int64, Int64}})
    rectsRot = Vector{Pair{Int64, Int64}}()

    for i in length(rects) : -1 : 1
        if i != length(rects) || rects[i][1] != rects[i][2]  # dont rotate the square in the last place``
            push!(rectsRot, Pair(rects[i][2], rects[i][1]))
        end
    end

    return vcat(rects, rectsRot)
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

mondrian(840, 840, 21, parse(Int64, ARGS[1]), parse(Int64, ARGS[2]))

#for x in ARGS
    #mondrian(280, 168, 14, parse(Int64, x))
    #mondrian(840, 840, 20, parse(Int64, x))  # 22
    #mondrian(840, 840, 21, parse(Int64, x))  # 21
#end