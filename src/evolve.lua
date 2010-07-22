dofile("evolve/GA.lua")
conf = dofile("evolve/GA_default.lua")
conf.moves = 4
conf.popFile = "4-moves.txt"
run_GA(conf)
