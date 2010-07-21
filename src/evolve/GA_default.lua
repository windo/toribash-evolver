dofile("evolve/evolib.lua")

-- Configuration options
local c = {}

c.popSize = 30    -- population size
c.eliteSize = 0.1 -- % that are not mutated
c.truncSize = 0.5 -- % that survive the round
c.randSize = 0.0  -- % that is randomly spawned (the rest are children)
c.mutaSize = 6    -- number of codons that are maximally mutated
c.moves = 3       -- number of moves

c.loadPrev = true -- continue evolving the previously saved population
c.forever  = true -- continue evolving, stop after one population if false

c.bestFile = "best.txt"      --stores the best of the current run
c.popFile = "population.txt" --stores the current population
c.get_fitness = evolib.get_fitness.dismember
c.mod = "classic"

return c
