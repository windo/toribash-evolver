dofile("evolve/evolib.lua")
dofile("evolve/GA.lua")
conf = dofile("evolve/GA_default.lua")
conf.moves = 15
conf.popSize = 10
conf.get_fitness = evolib.get_fitness.lazy
conf.popFile = nil
conf.bestFile = nil
conf.statFile = "test-stat.txt"
conf.mod = "judo.tbm"
run_GA(conf)
