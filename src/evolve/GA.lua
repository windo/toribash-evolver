-- include conf and lib functions
dofile("evolve/evolib.lua")

--[[
GA global variables - updated/read throughout the simulation
]]--
local round = 0   -- nr of round for this run
local pop = nil   -- all individuals
local idx   = 1   -- nr of individual in population
local bestfit = 0 -- best fitness seen during this run so far
local cache = evolib.new_lookaside(500) -- lookaside cache for known individuals
local conf = nil  -- configuration options
local visible = 1 -- start with things visible (or not?!?)
local set_options = { fixedframerate = 0,
                      antialiasing = 0,
                      blood = 0,
                      trails = 0,
                      hud = visible,
                      tori = visible,
                      uke = visible
                    }

--[[
toribash hooks
]]--

-- toggle visibility of tori and uke
local function key_down(key)
   if key == string.byte("v") then
      local v = get_option("tori")
      v = (v + 1) % 2
      set_option("tori", v)
      set_option("uke", v)
      set_option("hud", v)
   end
end

local function end_round()
   -- take next individual
   idx = idx + 1
   -- is it the end of pass?
   if(idx > #pop) then
      -- sort by fitness
      evolib.sort_pop(pop)

      -- update best individual list
      local best_indiv = pop[1]
      if best_indiv.fitness ~= nil and best_indiv.fitness > bestfit then
         evolib.info("New best individual: "..best_indiv.fitness.." > "..bestfit)
         evolib.append_file(conf.bestFile, best_indiv:format())
         bestfit = best_indiv.fitness
      end

      -- save some population statistics
      max, p90, p75, p50, p25, avg = evolib.pop_stats(pop)
      evolib.append_file(conf.statFile, string.format("%.2f, %.2f, %.2f, %.2f, %.2f, %.2f", max, p90, p75, p50, p25, avg))

      -- GA steps
      -- kill some individuals
      evolib.trunc_pop(pop, conf)
      -- replace them
      evolib.grow_pop(pop, conf)

      -- save the population
      evolib.save_pop(pop, conf.popFile)

      if conf.forever then
         -- start from first one again
         idx = 1
      else
         -- finish after one population
         remove_hooks("GA")
         return false
      end
   end

   return true
end

-- Executed at the end of round, stores fitness, triggers new round
local function finish_game(winType)
   local indiv = pop[idx]
   indiv.fitness = conf.get_fitness(winType)
   cache:save(indiv)
   evolib.info("Finished round (simulation), fitness: "..indiv.fitness)
   if end_round() then
      -- trigger new round -> start_game()
      start_new_game()
   end
end

-- Triggered at the start of a new round
local function start_game()
   local fitness_found = true
   local keep_going    = true
   while keep_going and fitness_found do
      round = round + 1
      local indiv = pop[idx]
      assert(indiv ~= nil)
      evolib.info("Starting round #"..round.." individual #"..idx)

      local fitness = cache:get(indiv)
      if fitness ~= nil then
         indiv.fitness = fitness
         evolib.info("Finished round (lookaside), fitness: "..fitness)
         keep_going = end_round()
      else
         -- will need to run the simulation
         evolib.play_indiv(indiv)
         fitness_found = false
      end
   end
end

--Startup
function run_GA(configuration)
   -- stored in local variable
   conf = configuration
   evolib.info("Starting GA")
   
   if conf.loadPrev == true then
      evolib.info("Loading population from file")
      pop = evolib.load_pop(conf.popFile)
   end
   if pop == nil then
      evolib.info("Creating new random population")
      pop = evolib.rand_pop(conf.popSize, conf.moves)
   elseif #pop ~= conf.popSize then
      evolib.info("Loaded population not the configured size, regenerating new one")
      pop = evolib.rand_pop(conf.popSize, conf.moves)
   end
   
   evolib.debug("Setting toribash options for increased FPS")
   for opt, val in pairs(set_options) do
      set_option(opt, val)
   end
   
   evolib.debug("Adding hooks")
   add_hook("end_game", "GA", finish_game)
   add_hook("new_game", "GA", start_game)
   add_hook("key_down", "GA", key_down)
   
   evolib.info("Press v to hide/show GUI elements. Minimize window for maximum performance.")
   run_cmd("loadmod "..conf.mod)
end
