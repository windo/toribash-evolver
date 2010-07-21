local P = {}

--[[
Simulation-related functions
]]--

-- size of one move (20 joints + 2 grip)
local moveLength = 22
local minfitness = -10000000
local datapath = "evolve/data/"

-- holds "global" variables updated during simulation
local Simulation = {}

-- During simulation, make moves and advance the turn
local function simulation_next_turn()
  local s = Simulation
  local state = get_world_state()
  local move_interval = math.floor(s.rules.matchframes / s.indiv:get_movecount())
  -- time to move?
  local move = math.floor(state.match_frame / move_interval) + 1
  if move > s.move then
     s.move = s.move + 1
     P.debug("Making move "..s.move.."/"..s.indiv:get_movecount().." @ frame "..state.match_frame.."/"..s.rules.matchframes)
     P.make_move(s.indiv.jVals, move)
  end

  -- continue simulation
  step_game()
end

-- Trigger a simulation
function P.play_indiv(indiv, mod)
   -- select right mod
   if mod == nil then mod = "classic" end
   -- TODO: can't do here, triggers new game
   -- run_cmd("loadmod "..mod)
   
   -- setup simulation
   local s = Simulation
   s.rules = get_game_rules()
   s.indiv = indiv
   s.move  = 0
   add_hook("enter_freeze", "evolib", simulation_next_turn)
   -- make the first turn
   simulation_next_turn()
end

function P.make_move(jVals, move)
   move = move or 1
   local offset = (move - 1) * moveLength
   local i = 1
   for jName, jID in pairs(JOINTS) do
      --P.debug(move.." using "..(offset+i).." of "..#jVals)
      local val = jVals[offset + i]
      --P.debug("Setting joint "..jName.." to "..val)
      if val ~= 0 then
         set_joint_state(0, jID, val)
      end
      i = i + 1
   end
   set_grip_info(0, BODYPARTS.L_HAND, jVals[offset + moveLength - 1] % 3)
   set_grip_info(0, BODYPARTS.R_HAND, jVals[offset + moveLength] % 3)
end


--[[
Individual
]]--

local _indiv = {}
-- constructor for an individual
function P.new_indiv(fitness, jVals)
   local _i = {}
   if fitness == nil then fitness = minfitness end
   _i.fitness = fitness
   _i.jVals = jVals
   _i.get_movecount = _indiv.get_movecount
   _i.format = _indiv.format
   return _i
end

-- calculate the number of moves done
function _indiv.get_movecount(self)
   return #self.jVals / moveLength
end

-- format an individual to be written to file
function _indiv.format(self)
   return self.fitness..":"..table.concat(self.jVals, ",")
end

-- generate random individual
function P.rand_indiv(moves)
   jVals = {}
   for i = 1, moveLength * moves do
      table.insert(jVals, math.random(0, 4))
   end
   return P.new_indiv(nil, jVals)
end

-- build an individual from string
function P.indiv_from_string(str)
   jointStart = string.find(str, ":") + 1
   jointString = string.sub(str, jointStart)

   fitVal = string.sub(str, 1, jointStart - 2)
   jVals = {}
   for val in jointString:gmatch("%w+") do
      -- + 0 to force str -> int conversion
      table.insert(jVals, val + 0)
   end
   return P.new_indiv(fitVal, jVals)
end

function P.copy_indiv(indiv)
   local jVals = {}
   for i = 1, #indiv.jVals do
      table.insert(jVals, indiv.jVals[i])
   end
   return P.new_indiv(indiv.fitness, jVals)
end

-- append one record to a file
function P.append_file(filename, string)
   filename = datapath..filename
   -- Get old data if any
   local f, res = io.open(filename, "r")
   local lines = {}
   if f ~= nil then
      while f:read(0) ~= nil do
         line = f:read("*l")
         table.insert(lines, line)
      end
      f:close()
   else
      P.debug("Could not read file: "..res)
   end
   -- Append string
   table.insert(lines, string)
  
   -- Write new file
   local f, res = io.open(filename, "w")
   if f == nil then
      P.debug("Can't append to "..filename..", opening for writing failed: "..res)
      return
   end
   for i, line in ipairs(lines) do
      f:write(line.."\n")
   end
   f:close()
end

-- print debugging/info messages
function P.debug(msg)
   print("GA-debug: "..msg)
end

function P.info(msg)
   print("GA-info: "..msg)
   echo("GA: "..msg)
end

--[[
Population management
]]--
function P.print_pop(pop)
   for i, indiv in ipairs(pop) do 
      P.debug(i.." fitness "..indiv.fitness, "value: "..table.concat(indiv.jVals, ",")) 
   end
end

function P.save_pop(pop, filename)
   filename = datapath..filename
   P.debug("Saving population to "..filename)
   local f, res = io.open(filename, "w")
   if f == nil then
     P.debug("Can't save population, opening file failed: "..res)
     return
   end

   for i, indiv in ipairs(pop) do
      f:write(indiv:format().."\n")
   end
   f:close()
end

local function sorter(a, b) return a.fitness > b.fitness end
function P.sort_pop(pop)
   table.sort(pop, sorter)
end

--[[
creates a population of popsize, initialising 
them to 0 fitness and random jVals
--]]
function P.rand_pop(size, moves)
   P.debug("Creating random population of "..size)
   pop = {}
   for i = 1, size do 
      table.insert(pop, P.rand_indiv(moves))
   end
   return pop
end

-- load population from file
function P.load_pop(filename) 
   filename = datapath..filename

   P.debug("Loading population from "..filename)
   local pop = {}
   local f, res = io.open(filename, "r")
   if f == nil then
      P.debug("Failed to open population: "..res)
      return nil
   end

   while f:read(0) ~= nil do
      local indivStr = f:read("*l")
      local indiv = P.indiv_from_string(indivStr)
      table.insert(pop, indiv)
   end

   f:close()
   P.debug("Got "..#pop.." individuals")
   return pop
end

--[[
 Lookaside cache implementation
After simulation each individual (with fitness) is stored in this cache.
Later on - if the individual has not been evicted - simulation can be
skipped.
This is useful if you tend to get the same individual repeatedly -
for example the elite and children of two identical elites.
]]--

local _lookaside = {}
-- constructor for a lookaside cache
function P.new_lookaside(size)
   local la = {}
   la.cache = {}
   la.max_size = size
   la.save = _lookaside.save
   la.get = _lookaside.get
   la.find = _lookaside.find
   return la
end

-- find if a matching jVals is in the lookaside buffer
function _lookaside.find(self, f_indiv)
   for idx, indiv in ipairs(self.cache) do
      assert(#indiv.jVals == #f_indiv.jVals)
      local match = true
      for i = 1, #f_indiv.jVals do
         if f_indiv.jVals[i] ~= indiv.jVals[i] then
            match = false
            break
         end
      end
      if match then return idx end
   end
   return nil
end

-- return individual fitness or nil if not found
function _lookaside.get(self, indiv)
   idx = self:find(indiv)
   if idx == nil then return nil end
   P.debug("Found from lookaside at #"..idx)
   -- Bring to the front of lookaside
   local l_indiv = self.cache[idx]
   table.remove(self.cache, idx)
   table.insert(self.cache, 1, l_indiv)
   return l_indiv.fitness
end

-- update lookaside buffer (indiv must contain valid fitness)
function _lookaside.save(self, indiv)
   idx = self:find(indiv)
   if idx == nil then
      P.debug("Adding individual to lookaside")
      -- Not in yet, make a copy (in case it gets mutated) and add
      local c_indiv = P.copy_indiv(indiv)
      table.insert(self.cache, 1, c_indiv)
      -- Remove last item if table is full
      if #self.cache > self.max_size then
         table.remove(self.cache, #self.cache)
      end
   end
end

--[[
Fitness functions

Listed below are a couple of fitness functions.
]]--

P.get_fitness = {}
-- Possibly the simplest fitness function - difference of score (from original code)
function P.get_fitness.plain(wt)
   local uke_score = math.floor(get_player_info(0).injury)
   local tori_score = math.floor(get_player_info(1).injury)
   return tori_score - uke_score
end

-- A fitness function that values factures and dismembers (from forum)
local dismember_value = 10000 -- Dismembered points value
local fracture_value = 7000 -- Fracture points value
function P.get_fitness.dismember(wt)
   local uke_score = math.floor(get_player_info(0).injury)
   local tori_score = math.floor(get_player_info(1).injury)
   for i = 0, 19 do
        if (get_joint_dismember(0, i)) then
            uke_score = uke_score + dismember_value
        elseif (get_joint_fracture(0, i)) then
            uke_score = uke_score + fracture_value
        end
        if (get_joint_dismember(1, i)) then
            tori_score = tori_score + dismember_value
        elseif (get_joint_fracture(1, i)) then
            tori_score = tori_score + fracture_value
        end
   end
   return tori_score - uke_score
end

-- sadly not working on linux version (3.5)
-- plain fitness, but always 0 when losing (squeakus' second release)
function P.get_fitness.requirewin(wt)
   local uke_score = math.floor(get_player_info(0).injury)
   local tori_score = math.floor(get_player_info(1).injury)
   -- this awards a fitness of zero if tori is disqualified
   if wt == 2 then
      local win = get_world_state().winner
      if win~=-1 then
         local winner = get_player_info(win).name
         if winner == 'uke' then return 0 end
      end
   end

   return tori_score - uke_score
end

-- fitness function for wushu
-- favouring those who dance around longer (disqualification check is a hack - if uke has points)
function P.get_fitness.wushu(wt)
   local uke_score = math.floor(get_player_info(0).injury)
   local tori_score = math.floor(get_player_info(1).injury)
   if uke_score ~= 0 then
      local s = get_world_state()
      return -5000 * (1 - (s.match_frame / s.game_frame)) + (tori_score - uke_score)
   else
      return tori_score - uke_score
   end
end

--[[
GA updating functions
]]--

--Mutate the individual by randomly chosing a new int with probability p_mut. Works per codon.
function P.intflip_mutation(jVals, mutaSize)
   local mutations = math.random() * mutaSize
   for i = 1, mutations do
       jVals[math.floor(math.random() * #jVals) + 1] = math.random(0, 4)
   end
end

-- Given two individuals, create a child using one-point crossover.
function P.onepoint_crossover(p, q)
   assert(#p == #q)
   point = math.random(1, #p)
   c = {}
   for i = 1, point do
      table.insert(c, p[i])
   end
   for i = point + 1, #q do
	    table.insert(c, q[i])
   end
   return c
end

-- Kill unsuccessful individuals
function P.trunc_pop(pop, conf)
   local survive = math.floor(table.getn(pop) * conf.truncSize)
   P.debug("Truncating population from "..#pop.." to "..survive.." individuals")
   for i = survive + 1, #pop do
      table.remove(pop, survive + 1)
   end
end

-- Generate a new generation (based on old one)
function P.grow_pop(pop, conf)
   P.debug("Filling population from "..#pop.." to "..conf.popSize.." individuals")
   local survivors = #pop
   local selfsex = true

   -- add random newcomers
   local randoms = conf.randSize * conf.popSize
   P.debug("Adding "..randoms.." random individuals")
   for i = 1, conf.randSize * conf.popSize do
      table.insert(pop, P.rand_indiv(conf.moves))
   end

   -- generate the rest with crossover
   local needed = conf.popSize - #pop
   P.debug("Adding "..needed.." individuals as crossover children of survivors and randoms")
   for i = 1, needed do
         -- avoid both parents being the same individual
         if selfsex then
     	      ind1, ind2 = math.random(1, survivors + randoms), math.random(1, survivors + randoms)
         else
     	      ind1, ind2 = math.random(1, survivors + randoms), math.random(1, survivors + randoms - 1)
            if ind2 >= ind1 then ind2 = ind2 + 1 end
         end
         -- generate child
     	   jVals = P.onepoint_crossover(pop[ind1].jVals, pop[ind2].jVals)
     	   table.insert(pop, P.new_indiv(nil, jVals))
   end

   -- mutate non-elite individuales
   local elite = conf.eliteSize * conf.popSize
   P.debug("Mutating "..#pop-elite.." individuales (sparing "..elite.." elites)")
   for i = elite + 1, #pop do
       P.intflip_mutation(pop[i].jVals, conf.mutaSize)
       pop[i].fitness = minfitness
   end
end

evolib = P
return evolib
