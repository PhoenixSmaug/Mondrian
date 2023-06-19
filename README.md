# Mondrian Art Problem Solver

### Authors
* Natalia García-Colín (garciacolin.natalia@gmail.com)
* Dimitri Leemans (leemans.dimitri@ulb.be)
* Christoph Müßig (info@cmuessig.de)
* Érika Roldán (erika.roldan@ma.tum.de) https://www.erikaroldan.net/
* Peter Voran (p-voran@t-online.de)

---

## Overview

### Zero Defect

* `mondrian.jl`: Backtracking with top-left-heuristic to check if a defect of 0 for a given `n` is possible. Single- and Multi-threaded functions are available.
* `Old/mondrian-ideas.jl`: Alternative approaches using Integer Programming and Knuth's Dancing Links algorithm which tend to be slower in practise.

### Minimal Defect
* `mondrian-defect.jl`: Parallelized search for the minimal defect of a given `n` using Integer Programming and Backtracking
* `Old/mondrian-defect/mondrian.jl`: Alternative approaches which tend to be slower in practise.

---

### License
This project is licensed under the MIT License - see LICENSE file for details. If you use this code for academic purposes, please cite the paper: 
