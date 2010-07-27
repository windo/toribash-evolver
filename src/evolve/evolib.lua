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
function P.play_indiv(indiv)
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
   if jVals[offset + moveLength - 1] ~= 0 then
      set_grip_info(0, BODYPARTS.L_HAND, jVals[offset + moveLength - 1] % 3)
   end
   if jVals[offset + moveLength] ~= 0 then
      set_grip_info(0, BODYPARTS.R_HAND, jVals[offset + moveLength] % 3)
   end
end


--[[
Individual
]]--

local _indiv = {}
-- constructor for an individual
function P.new_indiv(jVals, bVals, fitness)
   local _i = {}
   if fitness == nil then fitness = minfitness end
   -- data
   _i.fitness = fitness
   _i.jVals  = jVals
   _i.bVals  = bVals
   _i.age    = 1
   -- methods
   _i.get_movecount = _indiv.get_movecount
   _i.file_format = _indiv.file_format
   _i.print_format = _indiv.print_format
   return _i
end

-- calculate the number of moves done
function _indiv.get_movecount(self)
   return #self.jVals / moveLength
end

-- format an individual to be written to file
function _indiv.file_format(self)
   return self.fitness..":"..table.concat(self.jVals, ",")..":"..table.concat(self.bVals, ",")
end
-- as text
function _indiv.print_format(self)
   return "Indiv fitness="..self.fitness..", age="..self.age..", jVals="..table.concat(self.jVals, ", ")..", bVals="..table.concat(self.bVals, ", ")
end

-- generate random individual
function P.rand_indiv(moves)
   local jVals = {}
   local bVals = {}
   for i = 1, moveLength * moves do
      table.insert(jVals, math.random(0, 4))
      table.insert(bVals, math.random(0, 10) / 4)
   end
   return P.new_indiv(jVals, bVals)
end

-- build an individual from string
function P.indiv_from_string(str)
   jStart = string.find(str, ":") + 1
   bStart = string.find(str, ":", jStart) + 1
   jString = string.sub(str, jStart, bStart - 2)
   bString = string.sub(str, bStart)

   -- using +0 to force to a number
   fitVal = string.sub(str, 1, jointStart - 2) + 0
   jVals = {}
   bVals = {}
   for val in jString:gmatch("%w+") do
      table.insert(jVals, val + 0)
   end
   for val in bString:gmatch("%w+") do
      table.insert(bVals, val + 0)
   end
   return P.new_indiv(jVals, bVals, fitVal)
end

function P.copy_indiv(indiv)
   local jVals = {}
   local bVals = {}
   for i = 1, #indiv.jVals do
      table.insert(jVals, indiv.jVals[i])
      table.insert(bVals, indiv.bVals[i])
   end
   return P.new_indiv(jVals, bVals, indiv.fitness)
end

--[[
Misc
]]--

-- append one record to a file
function P.append_file(filename, string)
   if filename == nil then return nil end
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

-- prints a population
function P.print_pop(pop)
   for i, indiv in ipairs(pop) do 
      P.debug(i.." fitness "..indiv.fitness, "value: "..table.concat(indiv.jVals, ",")) 
   end
end

-- saves a population to a file
function P.save_pop(pop, filename)
   if filename == nil then return nil end
   filename = datapath..filename
   P.debug("Saving population to "..filename)
   local f, res = io.open(filename, "w")
   if f == nil then
     P.debug("Can't save population, opening file failed: "..res)
     return
   end

   for i, indiv in ipairs(pop) do
      f:write(indiv:file_format().."\n")
   end
   f:close()
end

-- sorts a population by fitness
local function sorter(a, b) return a.fitness > b.fitness end
function P.sort_pop(pop)
   table.sort(pop, sorter)
end

--creates a random population
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
   if filename == nil then return nil end
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

-- calculate some stats about the population
function P.pop_stats(pop)
   -- assume the stats are sorted
   local max = pop[1].fitness
   local p90 = pop[math.floor(0.1 * #pop)].fitness
   local p75 = pop[math.floor(0.25 * #pop)].fitness
   local p50 = pop[math.floor(0.5 * #pop)].fitness
   local p25 = pop[math.floor(0.75 * #pop)].fitness
   local avg = 0
   -- find average
   for i, indiv in ipairs(pop) do
      avg = avg + indiv.fitness
   end
   avg = avg / #pop
   return max, p90, p75, p50, p25, avg
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
Fitness functions - different variants
]]--

P.get_fitness = {}
-- Possibly the simplest fitness function - difference of score (from original code)
function P.get_fitness.plain(indiv, wt)
   local uke_score = math.floor(get_player_info(0).injury)
   local tori_score = math.floor(get_player_info(1).injury)
   return tori_score - uke_score
end

-- A fitness function that values factures and dismembers (from forum)
local dismember_value = 10000 -- Dismembered points value
local fracture_value = 7000 -- Fracture points value
function P.get_fitness.dismember(indiv, wt)
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
function P.get_fitness.requirewin(indiv, wt)
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
function P.get_fitness.wushu(indiv, wt)
   local uke_score = math.floor(get_player_info(0).injury)
   local tori_score = math.floor(get_player_info(1).injury)
   if uke_score ~= 0 then
      local s = get_world_state()
      return -5000 * (1 - (s.match_frame / s.game_frame)) + (tori_score - uke_score)
   else
      return tori_score - uke_score
   end
end

local move_effort = 1
local hold_effort = 1
local relax_effort = 1
local nop_effort = 0
-- lazy fitness - favour less movement
function P.get_fitness.lazy(indiv, wt)
   local effort = 0
   for i = 1, #indiv.jVals do
      local jVal = indiv.jVals[i]
      if jVal == 1 or jVal == 2 then effort = effort + move_effort
      elseif jVal == 3 then effort = effort + hold_effort
      elseif jVal == 4 then effort = effort + relax_effort
      elseif jVal == 0 then effort = effort + nop_effort
      end
   end
   return P.get_fitness.plain(indiv, wt) / (effort ^ 0.5)
end

--[[
GA updating functions
]]--

-- select relative or absolute size based on integer/float
local function rel_size(total, size)
   if math.floor(size) == size then
      -- absolute
      return size
   else
      -- proportional
      return math.floor(total * size)
   end
end

-- Mutate the individual by randomly chosing a new int with probability p_mut. Works per codon.
function P.intflip_mutation(indiv, conf)
   local mutations = math.random() * rel_size(#indiv.jVals, conf.mutaSize)
   for i = 1, mutations do
       pos = math.floor(math.random() * #indiv.jVals) + 1
       -- check if the mutation passes the block
       if math.random() > indiv.bVals[pos] then
          indiv.jVals[pos] = math.random(0, 4)
       end
       -- update block randomly
       indiv.bVals[pos] = indiv.bVals[pos] + (math.random(0, 2) - 1) * conf.blockStep
       if indiv.bVals[pos] < 0 then indiv.bVals[pos] = 0 end
       if indiv.bVals[pos] > 1 then indiv.bVals[pos] = 1 end
   end
end

-- Given two individuals, create a child using N-point crossover
function P.n_point_crossover(p, q, n)
   assert(#p.jVals == #q.jVals)
   -- generate crossover points
   local points
   for i = 1, n do
      table.insert(points, math.random(1, #p.jVals))
   end
   points:sort()
   -- empty lists
   local jVals = {}
   local bVals = {}
   -- fill the lists
   local j = 1
   local parent = p
   for i = 1, #p.jVals do
      -- switch parents if we pass a point
      while i > points[j] and j <= n do
         j = j + 1
         if parent == p then
            parent = q
         else
            parent = p
         end
      end
      -- insert a codon
      table.insert(jVals, parent.jVals[i])
      table.insert(bVals, parent.bVals[i])
   end
   return P.new_indiv(jVals, bVals)
end

-- create a child using uniform crossover (randomly select parent for each codon)
function P.uniform_crossover(p, q)
   assert(#p.jVals == #q.jVals)
   local jVals = {}
   local bVals = {}
   local parent = p
   for i = 1, #p.jVals do
      if math.random() < 0.5 then
         parent = p
      else
         parent = q
      end
      table.insert(jVals, parent.jVals[i])
      table.insert(bVals, parent.bVals[i])
   end
   return P.new_indiv(jVals, bVals)
end

-- Tournament selection algorithm
function P.tournament(pop, conf)
   if conf.tourCount == 0 then return end
   local tourCount = rel_size(#pop, conf.tourCount)
   local tourSize  = rel_size(#pop, conf.tourSize)
   P.debug("Running "..tourCount.." tournaments of "..tourSize.." with "..conf.tourProb.." randomness to select survivors")
   local popsize = #pop
   local newpop = {}
   for t = 1, tourCount do
      -- assemble tournament
      local tour = {}
      while #tour < tourSize and #pop > 0 do
         table.insert(tour, table.remove(pop, math.random(1, #pop)))
         if next(pop) ~= nil then table.insert(pop, table.remove(pop)) end
      end
      P.debug("Assembled tournament of "..#tour..", "..#pop.." left in population")

      -- draw the winner
      P.sort_pop(tour)
      for i, v in ipairs(tour) do
         -- select based on probability or last one with 100% probability
         if math.random() < conf.tourProb or next(tour, i) == nil then
            table.insert(newpop, table.remove(tour, i))
            break
         end
      end

      -- end tournament, put contestants back
      for i, v in ipairs(tour) do
         table.insert(pop, tour[i])
      end
   end
   -- clean population
   for i = 1, #pop do
      table.remove(pop)
   end
   -- replace
   for i = 1, #newpop do
      table.insert(pop, newpop[i])
   end
   P.debug("Tournament reduced population from "..popsize.." to "..#pop)
end

-- Kill individuals who have been around for too long (to kill elitists)
function P.kill_old(pop, conf)
   -- increase age
   for i = 1, #pop do
      pop[i].age = pop[i].age + 1
   end

   if conf.maxAge == 0 then return end

   -- kill
   P.debug("Killing all individuals older than "..conf.maxAge)
   local i = 1
   local popsize = #pop
   while i < #pop do
      if pop[i].age > conf.maxAge then
         P.debug("Killing indiv #"..i.." because of old age")
         table.remove(pop, i)
         -- fill the hole
         table.insert(pop, table.remove(pop))
      else
         i = i + 1
      end
   end

   P.debug("Killed "..(popsize - #pop).." individuals because of old age")
end

-- Truncate population to set size
function P.trunc_pop(pop, conf)
   if conf.truncSize == 0 or conf.truncSize == 1 then return end
   local survive = rel_size(#pop, conf.truncSize)
   P.debug("Truncating population from "..#pop.." to "..survive.." individuals")
   for i = survive + 1, #pop do
      table.remove(pop, survive + 1)
   end
end

-- Clear room in population
function P.shrink_pop(pop, conf)
   P.kill_old(pop, conf)
   P.tournament(pop, conf)
   P.trunc_pop(pop, conf)
end

-- Generate a new generation (based on old one)
function P.grow_pop(pop, conf)
   P.debug("Filling population from "..#pop.." to "..conf.popSize.." individuals")
   local survivors = #pop

   -- add random newcomers
   local randoms = rel_size(conf.popSize, conf.randSize)
   P.debug("Adding "..randoms.." random individuals")
   for i = 1, conf.randSize * conf.popSize do
      table.insert(pop, P.rand_indiv(conf.moves))
   end

   -- generate the rest with crossover
   local needed = conf.popSize - #pop
   P.debug("Adding "..needed.." individuals as crossover children of survivors and randoms")
   for i = 1, needed do
         -- avoid both parents being the same individual
         if conf.selfsex then
     	      ind1, ind2 = math.random(1, survivors + randoms), math.random(1, survivors + randoms)
         else
     	      ind1, ind2 = math.random(1, survivors + randoms), math.random(1, survivors + randoms - 1)
            if ind2 >= ind1 then ind2 = ind2 + 1 end
         end
         -- generate child
     	   local indiv = P.uniform_crossover(pop[ind1], pop[ind2])
     	   table.insert(pop, indiv)
   end

   -- mutate non-elite individuales
   local elite = rel_size(#pop, conf.eliteSize)
   P.debug("Mutating "..#pop-elite.." individuals (sparing "..elite.." elites)")
   for i = elite + 1, #pop do
       P.intflip_mutation(pop[i], conf)
       pop[i].fitness = minfitness
   end
end

evolib = P
return evolib
