dofile("evolve/evolib.lua")

-- Configuration options
local c = {}

-- population parameters
c.popSize = 30    -- population size
c.moves = 3       -- number of moves
c.mod = "classic"

c.get_fitness = evolib.get_fitness.dismember

-- all sizes can be either absolute (integer) or relative (fraction of total)

-- the genetic operations
c.eliteSize = 0.1  -- % that are not mutated
c.mutaSize = 6     -- number of codons that are maximally mutated
c.randSize = 0.0   -- % that is randomly spawned (the rest are children)
c.blockStep = 0.25 -- max change of joint mutation block per mutation (0 ... 1)
c.selfsex = false  -- can both parents of crossover be the same individual - effectively cloning

-- selection parameters
c.truncSize = 0 -- % that survive the round, 0 or 1 to disable
c.maxAge = 10   -- max age of an individual, 0 to disable
c.tourCount = 5 -- number of tournaments to hold, 0 to disable
c.tourSize  = 2 -- individuals per tournament (2 is common)
c.tourProb  = 1 -- probability that the best one is selected (usually 1, non-deterministic otherways)

-- execution settings
c.loadPrev = true -- continue evolving the previously saved population
c.forever  = true -- continue evolving, stop after one population if false (for automation)
c.bestFile = "best.txt"      -- stores the best of the current run
c.popFile = "population.txt" -- stores the current population
c.statFile = "stats.txt"     -- stores statistics about the population

return c
