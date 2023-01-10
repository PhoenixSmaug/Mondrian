"""
Integer Programming Solver
- Knuths Dancing Link Algorithm (https://arxiv.org/abs/cs/0011047) using dictionaries https://www.cs.mcgill.ca/~aassaf9/python/algorithm_x.html
- For rectangle packing far faster than Integer programming
- Translation into Exact Cover Problem (https://en.wikipedia.org/wiki/Exact_cover)

+-----------------------------------------------+--------------------+---------------------+
|                       -                       | Tile covered (n^2) |  Rectangle used (m) |
+-----------------------------------------------+--------------------+---------------------+
| Rectangle 1 (1, 1)                            |                    |                     |
| ...                                           |                    |                     |
| Rectangle 1 (n - sizeX(1), n - sizeY(1))      |                    |                     |
| Rectangle 1 rot. (1, 1)                       |                    |                     |
| ...                                           |                    |                     |
| Rectangle 1 rot. (n - sizeY(1), n - sizeX(1)) |                    |                     |
| ....                                          |                    |                     |
| Rectangle m rot. (n - sizeY(m), n - sizeX(m)) |                    |                     |
+-----------------------------------------------+--------------------+---------------------+
"""

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