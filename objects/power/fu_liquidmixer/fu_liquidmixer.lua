require "/scripts/fu_storageutils.lua"
require "/scripts/kheAA/transferUtil.lua"
require '/scripts/fupower.lua'

function init()
	power.init()
	storage.timer = storage.timer or config.getParameter("craftingSpeed")
	storage.crafting = storage.crafting or false
	object.setOutputNodeLevel(0,storage.crafting)
	storage.output = storage.output or {}
	self.recipeTable = getRecipes()
	self.powerCost=config.getParameter('isn_requiredPower')
	self.speed=config.getParameter("craftingSpeed")
end

function getInputContents()
	local id = entity.id()

	local contents = {}
	for i=0,1 do
		local stack = world.containerItemAt(id, i)
		if stack ~=nil then
			if contents[stack.name] ~= nil then
				contents[stack.name] = contents[stack.name] + stack.count
			else
				contents[stack.name] = stack.count
			end
		end
	end

	return contents
end

function map(l,f)
	local res = {}
	for k,v in pairs(l) do
		res[k] = f(v)
	end
	return res
end

function filter(l,f)
	return map(l, function(e) return f(e) and e or nil end)
end

function getValidRecipes(query)
	local function subset(t1,t2)
		if next(t2) == nil then
			return false
		end
		if t1 == t2 then
			return true
		end
			for k,_ in pairs(t1) do
				if not t2[k] or t1[k] > t2[k] then
					return false
				end
			end
		return true
	end
	return filter(self.recipeTable, function(l) return subset(l.inputs, query) end)
end


function getOutSlotsFor(something)
	local empty = {} -- empty slots in the outputs
	local slots = {} -- slots with a stack of "something"

	for i = 2, 2 do -- iterate all output slots
		local stack = world.containerItemAt(entity.id(), i) -- get the stack on i
		if stack ~= nil then -- not empty
			if stack.name == something then -- its "something"
				table.insert(slots,i) -- possible drop slot
			end
		else -- empty
			table.insert(empty, i)
		end
	end

	for _,e in pairs(empty) do -- add empty slots to the end
		table.insert(slots,e)
	end
	return slots
end


function update(dt)
	if not transferUtilDeltaTime or (transferUtilDeltaTime > 1) then
		transferUtilDeltaTime=0
		transferUtil.loadSelfContainer()
	else
		transferUtilDeltaTime=transferUtilDeltaTime+dt
	end
	storage.timer = storage.timer - dt
	if storage.timer <= 0 then
		if storage.crafting then
			if power.consume(self.powerCost) then
				for k,v in pairs(storage.output) do
					local leftover = {name = k, count = v}
					local slots = getOutSlotsFor(k)
					for _,i in pairs(slots) do
						leftover = world.containerPutItemsAt(entity.id(), leftover, i)
						if leftover == nil then
							break
						end
					end

					if leftover ~= nil then
						world.spawnItem(leftover.name, entity.position(), leftover.count)
					end
				end
				storage.crafting = false
				object.setOutputNodeLevel(0,storage.crafting)
				storage.output = {}
				storage.timer = self.speed
			else
				animator.setAnimationState("centrifuge", "idle")
			end
		end

		if not storage.crafting and storage.timer <= 0 then --make sure we didn't just finish crafting
			if not startCrafting(getValidRecipes(getInputContents())) then
				storage.timer = self.speed
				animator.setAnimationState("centrifuge", "idle")
			end --set timeout if there were no recipes
		end
	end
	power.update(dt)
end



function startCrafting(result)
	if power.getTotalEnergy() >= self.powerCost then
		if next(result) == nil then
			return false
		else
			_,result = next(result)

			for k,v in pairs(result.inputs) do
				if not world.containerConsume(entity.id(), {item = k , count = v}) then return false end
			end

			storage.crafting = true
			object.setOutputNodeLevel(0,storage.crafting)
			storage.timer = self.speed
			storage.output = result.outputs
			animator.setAnimationState("centrifuge", "working")
			return true
		end
	end
end

function getRecipes()
	return root.assetJson('/objects/power/fu_liquidmixer/fu_liquidmixer_recipes.config')
end
