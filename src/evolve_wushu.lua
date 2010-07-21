dofile("evolve/evolib.lua")
dofile("evolve/GA.lua")
conf = dofile("evolve/GA_default.lua")
conf.moves = 10
conf.popFile = "wushu.txt"
conf.bestFile = "wushu-best.txt"
conf.mod = "wushu.tbm"
conf.get_fitness = evolib.get_fitness.wushu
run_GA(conf)
