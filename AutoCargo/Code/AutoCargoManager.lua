-- GlobalObj("AutoCargoManagerInstance", "AutoCargoManager")
-- local storable_resources = {"Concrete", "Metals", "Polymers", "Food", "Electronics", "MachineParts", "PreciousMetals", "Fuel", "MysteryResource", "BlackCube"}

-- AutoCargoManager = {
-- 	transport_queues = false,
-- 	supply_queue = false,
-- 	demand_queue = false
-- }


function AutoCargoManager:FindTransportTask()
	lcPrint("FindTransportTask")
	local MinResourceThreshold = 4 -- TODO make configurable through modconfig
	local supply_queue = {}
	local demand_queue = {}
	
	local function AddSupplyDepot(task)
		local resource = task:GetResource()
		if task:GetActualAmount() > MinResourceThreshold then
			table.insert(supply_queue, task)
		end
	end
	
	local function AddDemandDepot(task)
		-- for initial simplicity, we only include depots with no resource
		if task:GetActualAmount() == 0 then
			table.insert(demand_queue, task)
		end
	end
	
	local numDepots = 0
	-- Get all supply and demand tasks
	ForEach {
		class = "StorageDepot",
		exec = function(depot)
			numDepots = numDepots + 1
			for _, request in ipairs(depot.task_requests or empty_table) do
				if request:IsAnyFlagSet(const.rfDemand) then
					-- RCTransports cannot deliver to rockets
					-- TODO: Should probably exclude space elevator as well
					if not (depot.encyclopedia_id == "Rocket") then
						AddDemandDepot(request)
					end
				end
				if request:IsAnyFlagSet(const.rfSupply) then
					AddSupplyDepot(request)
				end
			end
		end
	}
	lcPrint("found "..numDepots.." depots")

	-- approach: move resources until all depots have same amount
	-- sort demand tasks ascending
	-- TODO: this sort will be by priority scoring in the future
	table.sort(
		demand_queue,
		function(a, b)
			return a:GetActualAmount() > b:GetActualAmount()
		end
	)
	-- sort supply tasks by descending amount of stored resource
	table.sort(
		supply_queue,
		function(a, b)
			return a:GetActualAmount() < b:GetActualAmount()
		end
	)

	-- loop through demand tasks until we find a supply depot with resources to satisface it
	for _, demand in ipairs(demand_queue) do
		local resource = demand.resource
		local amount = demand.GetTargetAmount()
		lcPrint(resource)
		local average = ResourceOverviewObj:GetAvailable(resource) or 0 / numDepots
		for _, supply in ipairs(supply_queue) do
			if (supply:GetResource() == resource) and (supply:GetActualAmount() > average) then
				local transport_task = {}
				transport_task.source = supply.depot
				transport_task.destination = demand.depot
				transport_task.resource = resource
				transport_task.amount = average
				return transport_task
			end
		end
	end
end
