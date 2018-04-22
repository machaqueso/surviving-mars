GlobalObj("AutoCargoManagerInstance", "AutoCargoManager")
local MinResourceThreshold = 4 -- TODO make configurable through modconfig
-- local storable_resources = {"Concrete", "Metals", "Polymers", "Food", "Electronics", "MachineParts", "PreciousMetals", "Fuel", "MysteryResource", "BlackCube"}

DefineClass.AutoCargoManager = {
	__parents = {"InitDone"},
	city = false,
	transport_queues = false,
	supply_queue = false,
	demand_queue = false
}

function AutoCargoManager:Init()
	self.transport_queues = {}
	self.supply_queue = {}
	self.demand_queue = {}
end

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

function AutoCargoManager:GetTransportTask()
	self.supply_queue = {}
	self.demand_queue = {}

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
						AddDemandDepot(depot)
					end
				end
				if request:IsAnyFlagSet(const.rfSupply) then
					AddSupplyDepot(depot)
				end
			end
		end
	}

	-- approach: move resources until all depots have same amount
	-- sort demand tasks ascending
	-- TODO: this sort will be by priority scoring in the future
	table.sort(
		self.demand_queue,
		function(a, b)
			return a:GetActualAmount() > b:GetActualAmount()
		end
	)
	-- sort supply tasks by descending amount of stored resource
	table.sort(
		self.supply_queue,
		function(a, b)
			return a:GetActualAmount() < b:GetActualAmount()
		end
	)

	-- loop through demand tasks until we find a supply depot with resources to satisface it
	for _, demand in ipairs(self.demand_queue) do
		local resource = demand.resource
		local amount = demand.GetTargetAmount()

		local average = ResourceOverviewObj:GetAvailable(resource) / numDepots
		for _, supply in ipairs(self.supply_queue) do
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
