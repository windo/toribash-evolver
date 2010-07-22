-- include lib functions
dofile("evolve/evolib.lua")

-- some local variables
local pop = nil -- array storing individuals
local idx = 1   -- currently playing individual index

-- start the simulation
local function start_game()
   local indiv = pop[idx]
   evolib.info("Playing move #"..idx.." of "..#pop.." (fitness "..indiv.fitness..")")
   evolib.play_indiv(indiv)
end

-- control which individual to show
local function key_down(key)
   local change = false
   if key == string.byte("x") then
      idx = idx + 1
      change = true
   end
   if key == string.byte("z") then
      idx = idx - 1
      change = true
   end
   if change then
      -- peculiar arithmetic - arrays start from 1
      idx = ((idx - 1) % #pop) + 1
      start_new_game()
   end
end

-- start population viewer
function show_population(fileName, mod)
   mod = mod or "classic"
   evolib.info("Starting population viewer")
   -- initialize
   evolib.info("Loading population from: "..fileName)
   pop = evolib.load_pop(fileName)
   if not pop then
      evolib.info("Population file not present, fail...")
      return
   end
   evolib.info("Loaded "..#pop.." individuals")
   
   evolib.debug("Adding hooks")
   add_hook("new_game", "evolve", start_game)
   add_hook("key_down", "evolve", key_down)
   
   evolib.info("Press z for previous, x for next individual.")
   run_cmd("loadmod "..mod)
end
