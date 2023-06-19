using Primes

function solveBacktrack(n::Int64, r::Int64, rects::Vector{Pair{Int64, Int64}})
    s = length(rects)
    center = ceil(s/2)

    tiles = fill(0, n, n)
    used = fill(0, s)
    coords = Vector{Pair{Int64, Int64}}()
    count = 0; i = j = kStart = 1
    steps = 1

    while count < r && count >= 0
        # try to place next piece on (i, j)

        done = false
        k = kStart
        
        while (k <= center || (k <= s && count > 0)) && !done
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

        if done  # another piece can be placed
            push!(coords, Pair(i, j))

            for l = 0 : rects[k][1] - 1  # fill tiles with selected square
                tiles[i + l, j] = k
                tiles[i + l, j + rects[k][2] - 1] = k

                for m = 0 : rects[k][2] - 1
                    tiles[i + l, j + m] = k
                end
            end

            count += 1
            used[s - k + 1] = -1  # different rotation can't be used anymore
            used[k] = count
            kStart = 1
        else
            # find last piece placed by count number
            k = argmax(used)

            if !isempty(coords)
                last = pop!(coords)  # remove from coords

                for l = 0 : rects[k][1] - 1  # remove from tiles
                    for m = 0 : rects[k][2] - 1
                        tiles[last[1] + l, last[2] + m] = 0
                    end
                end
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

        steps += 1
    end

    if count == r
        return true, tiles
    else
        return false, tiles
    end
end

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