-- I shamesly lifted this part from Arkamod's AutoGatherTransport Mod

-- Mod's global
BetterLogisticsTransport = { }
-- Base ID for translatable text
BetterLogisticsTransport.StringIdBase = 20180406

-- Setup UI

function OnMsg.ClassesBuilt()
    BetterLogisticsAddInfoSection()
end

function BetterLogisticsAddInfoSection()

    if not table.find(XTemplates.ipRover[1],"UniqueId","c71b64b6-3ccc-11e8-a681-63b2fbe75a75") then

        table.insert(XTemplates.ipRover[1], 
            PlaceObj("XTemplateTemplate", {
                "__context_of_kind", "RCTransport",
                "__template", "InfopanelActiveSection",
                "Icon", "UI/Icons/Upgrades/service_bots_01.tga",
                "Title", T{BetterLogisticsTransport.StringIdBase + 11, "Auto Transport"},
                "RolloverText", T{BetterLogisticsTransport.StringIdBase + 12, "Enable/Disable this rover from automatic transport of resources between depots.<newline><newline>(Better Logistics mod)"},
                "RolloverTitle", T{BetterLogisticsTransport.StringIdBase + 13, "Auto Transport"},
                "RolloverHint",  T{BetterLogisticsTransport.StringIdBase + 14, "<left_click> Toggle setting"},
                "OnContextUpdate",
                    function(self, context)
                        if context.auto_transport then
                            self:SetTitle(T{BetterLogisticsTransport.StringIdBase + 15, "Auto Transport (ON)"})
                            self:SetIcon("UI/Icons/Upgrades/service_bots_02.tga")
                        else
                            self:SetTitle(T{BetterLogisticsTransport.StringIdBase + 16, "Auto Transport (OFF)"})
                            self:SetIcon("UI/Icons/Upgrades/service_bots_01.tga")
                        end
                    end,
                "UniqueId", "c71b64b6-3ccc-11e8-a681-63b2fbe75a75"
            }, {
                PlaceObj("XTemplateFunc", {
                    "name", "OnActivate(self, context)", 
                    "parent", function(parent, context)
                            return parent.parent
                        end,
                    "func", function(self, context)
                            context.auto_transport = not context.auto_transport
                            ObjModified(context)
                        end
                })
            })
        )
    
    end
end

-- Setup ModConfig UI

-- See if ModConfig is installed and that notifications are enabled
function BetterLogisticsConfigShowNotification()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("BetterLogisticsTransport", "Notifications")
    end
    return "all"
end

-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()

    ModConfig:RegisterMod("BetterLogisticsTransport", -- ID
        T{BetterLogisticsTransport.StringIdBase + 17, "BetterLogisticsTransport"}, -- Optional display name, defaults to ID
        T{BetterLogisticsTransport.StringIdBase + 18, "Transports automatically move resources between depots based on priority, keep themselves charged"} -- Optional description
    ) 

    ModConfig:RegisterOption("BetterLogisticsTransport", "Notifications", {
        name = T{BetterLogisticsTransport.StringIdBase + 19, "Notifications"},
        desc = T{BetterLogisticsTransport.StringIdBase + 20, "Enable/Disable notifications of the rovers in Auto mode."},
        type = "enum",
        values = {
            {value = "all", label = T{BetterLogisticsTransport.StringIdBase + 21, "All"}},
            {value = "problems", label = T{BetterLogisticsTransport.StringIdBase + 22, "Problems only"}},
            {value = "off", label = T{BetterLogisticsTransport.StringIdBase + 23, "Off"}}
        },
        default = "all" 
    })
    
end

--function OnMsg.GameTimeStart()
--    BetterLogisticsInstallThread()
--end

--function OnMsg.LoadGame()
--    BetterLogisticsInstallThread()
--end

--function BetterLogisticsInstallThread()
--    CreateGameTimeThread(function()
--        while true do
--            Sleep(5000)
--            --BetterLogisticsHandleTransports() 
--        end
--    end)
--end

function OnMsg.NewHour()
  BetterLogisticsTransport:DoTasks()
end

function BetterLogisticsTransport:DoTasks()
    ForEach { class = "RCTransport", exec = function(rover)
        if rover.auto_transport and rover.command == "Idle" then
          if rover.transport_task then
            if not rover.in_transport_task then
              BetterLogisticsTransport:Pickup(rover)
            else
              BetterLogisticsTransport:Deliver(rover)
            end
          else
            local task = BetterLogisticsTransport:FindTransportTask(rover)
            if(task) then
              rover.transport_task = task
              rover.in_transport_task = false
              lcPrint("Transport task assigned")
              
              BetterLogisticsTransport:Pickup(rover)
            end
          end
        end
    end }
end
    

function BetterLogisticsTransport:Pickup(rover)
  lcPrint("Pickup")
	if not rover.transport_task then
		return 
	end
	local resource = rover.transport_task.resource
	local amount = rover.transport_task.amount
	
	if amount <= 0 then 
    rover.transport_task = false
    lcPrint("Pickup cancelled: zero resources requested")
    return
  end
  
  if not rover.transport_task.source then
    rover.transport_task = false
    lcPrint("Pickup cancelled: invalid source")
    return
  end
  
 	local source = rover.transport_task.source
  
  if source:GetStoredAmount(resource) <= 0 then
    rover.transport_task = false
    lcPrint("Pickup cancelled: no resources at source")
    return
  end
      
  lcPrint("Picking up "..resource.." from depot at "..print_format(source:GetPos()))
  SetUnitControlInteractionMode(rover, false)
  rover:SetCommand("TransferResources", source, "load", resource, amount)
  rover.in_transport_task = true
end


function BetterLogisticsTransport:Deliver(rover)
  lcPrint("Deliver")
	if not rover.transport_task then 
		return 
	end
	local resource = rover.transport_task.resource
	local amount = rover.transport_task.amount
 	local destination = rover.transport_task.destination
  
  if rover:GetStoredAmount() > 0 then
    lcPrint("Delivering "..amount.." "..resource.." to depot at "..print_format(destination:GetPos()))
    SetUnitControlInteractionMode(rover, false)
    rover:SetCommand("TransferAllResources", destination, "unload", rover.storable_resources)
  else
    lcPrint("Cargo delivered")
    rover.in_transport_task = false
    rover.transport_task = false
  end
end

local task = {}
local minimum_resource_amount_treshold = 4
local dist_threshold = 15000

local function GetDemandTask(depot, request)
    local demand_task = {}
    demand_task.destination = depot
    demand_task.resource = request:GetResource()
    demand_task.stored_amount = depot:GetStoredAmount(demand_task.resource)
    demand_task.amount = Min(demand_task.stored_amount - request:GetTargetAmount(), minimum_resource_amount_treshold or 0)
    return demand_task
end

local function CanPickupResourceFrom(o, resource)
	local res = o.resource
	return o:DoesHaveSupplyRequestForResource(resource) or false
end

local NearestSupplyQuery = {
    class = "StorageDepot",
    filter = function(o, rover, resource)
        -- no supply task for resource at this depot
        if not CanPickupResourceFrom(o, resource) then return false end
        -- no stock of resource at this depot
        if o:GetStoredAmount(resource) == 0 then return false end
        
        return true
    end
}

local function PrintTask(t)
  lcPrint(t.amount.." "..t.resource.." from "..print_format(t.source:GetPos()).." to "..print_format(t.destination:GetPos()))
end


function BetterLogisticsTransport:FindTransportTask(rover)
  
  ForEach { class = "StorageDepot", exec = function(depot)
      if not (depot.encyclopedia_id == "Rocket") then
          lcPrint(depot.encyclopedia_id)
        
          task = false
        
          for _, request in ipairs(depot.task_requests or empty_table) do
            
              if request:IsAnyFlagSet(const.rfDemand) then
                
                  local demand_task = GetDemandTask(depot, request)
                  
                  if demand_task.amount > 0 then
                  
                  local available = ResourceOverviewObj:GetAvailable(demand_task.resource)
                  
                  if available > 0 then
                      
                      lcPrint("Demand for "..demand_task.resource.." detected")
                      
                      local nearest_supply, distance = FindNearest({
                          class = "StorageDepot",
                          filter = function(o, rover, resource)
                              -- no supply task for resource at this depot
                              --if not o:DoesHaveSupplyRequestForResource(resource) or false then return false end
                              
                              -- no stock of resource at this depot
                              if o:GetStoredAmount(resource) == 0 then return false end
                              
                              return true
                          end
                      }, rover, demand_task.resource)
                  
                      if not nearest_supply then
                        lcPrint("Could not find "..demand_task.resource.." supply")
                      end
                      
                      --lcPrint("nearest_supply and distance > dist_threshold: "..print_format(nearest_supply and distance > dist_threshold))
                      
                      if nearest_supply and distance > dist_threshold then
                        demand_task.source = nearest_supply
                      
                        if not task then
                          task = demand_task
                        end
                        
                        lcPrint(demand_task.resource.." supply available")
                        PrintTask(task)
                        
                        lcPrint("Inventory: "..demand_task.stored_amount.."/"..demand_task.amount)
                        -- depots with no stock get priority
                        if demand_task.stored_amount == 0 then
                          task = demand_task
                          lcPrint("Priority for depot with no stock")
                          return task
                        end
                        
                        -- find depot requiring higher amount
                        if task.amount < demand_task.amount then
                          task = demand_task
                        end
                      
                      else
                        lcPrint("Supply is in drone range")
                      end
                      
                  end
                  end
                  
              end
          end
          PrintTask(task)
          return task
      end
  end }
end

--function BetterLogisticsTransport:FindTransportTask(rover)
  
--  task = BetterLogisticsTransport:FindDemand(rover)
  
----  lcPrint(print_format(task))
--  lcPrint(task.resource.." requested")
  
--  -- find nearest supply depot with resource available
--  --local nearest_supply, distance = FindNearest(NearestSupplyQuery, rover, task)

--  --lcPrint(print_format(nearest_supply))
--  --task.source = nearest_supply
--  return task

--end



--function BetterLogisticsHandleTransports()
--    ForEach { class = "RCTransport", exec = function(rover)
--        -- Enabled via the InfoPanel UI section "Auto Transport"
--        lcPrint(rover.name.." "..print_format(rover.auto_transport))
--        if rover.auto_transport then
--            local largestDemand = BetterLogisticsFindDemand()
--            lcPrint("Largest demand: "..largestDemand.deficit.." "..largestDemand.resource)

--            local available = ResourceOverviewObj:GetAvailable(largestDemand.resource)
--            lcPrint(largestDemand.resource.." available: "..FormatScale(available,const.ResourceScale))
            
--            local nearest_supply, distance = FindNearest({ 
--                class = "StorageDepot",
--                filter = function(o, rover)
                    
--                    if o.handle == largestDemand.depot.handle then
--                        return false
--                    end
--                    if o:GetStoredAmount(largestDemand.resource) == 0 then
--                        return false
--                    end
                
--		            local rover_resources = rover.transport_resource
--		            if type(rover_resources) == "table" then
--			            local found
--			            for _, resource in ipairs(rover_resources) do
--				            if BetterLogisticsCanPickupResourceFrom(o, largestDemand.resource) then
--					            found = true
--					            break
--				            end
--			            end
--			            if not found then
--				            return false
--			            end
--		            elseif not BetterLogisticsCanPickupResourceFrom(o, rover_resources) then
--			            return false
--		            end

--		            local stored_amount = 0
--		            if type(rover_resources) == "table" then
--			            for _, resource in ipairs(rover_resources) do
--				            if BetterLogisticsCanPickupResourceFrom(o, resource) then
--					            stored_amount = stored_amount + o:GetStoredAmount(resource)
--				            end
--			            end
--		            elseif BetterLogisticsCanPickupResourceFrom(o, rover_resources) then
--			            stored_amount = o:GetStoredAmount(rover_resources)
--		            end

--		            return stored_amount >= const.ResourceScale		            
--                end
--            }, rover, roverZone)
            
--            local pos = nearest_supply:GetPos()
    
--            lcPrint("Found "..nearest_supply.encyclopedia_id.." with "..nearest_supply:GetStoredAmount(largestDemand.resource).." "..largestDemand.resource.." at "..print_format(pos)..", distance: "..distance)
            
--            SetUnitControlInteractionMode(rover, false)
--            --TransferResources(next_source, "load", self.transport_resource)
            
--            lcPrint("Picking up "..largestDemand.resource.." from depot at "..print_format(pos))
--            rover:SetCommand("TransferResources", nearest_supply, "load", largestDemand.resource)
            
--            -- Putting this function here might be an ugly practice, let me know
--            function OnMsg.NewHour()
--              if rover.command == "Idle" and not (rover:GetStoredAmount() == 0) then
--                lcPrint("Droping "..largestDemand.resource.." to depot at "..print_format(largestDemand.depot:GetPos()))
--                rover:SetCommand("TransferAllResources", largestDemand.depot, "unload", rover.storable_resources)
--              end
--            end

----            AddCustomOnScreenNotification(
----                "BetterLogisticsAutoTransportDemand", 
----                T{rover.name}, 
----                T{BetterLogisticsTransport.StringIdBase, "Largest demand: "..largestDemand.deficit.." "..largestDemand.resource.."/"..available.." on "..largestDemand.depot.encyclopedia_id}, 
----                "UI/Icons/Sections/storage.tga",
----                false,
----                {
----                    expiration = 2000
----                }
----            )

--        end
--    end 
--    }
--end

--function BetterLogisticsFindDemand()
--    local largestDemand = {}
--    largestDemand.deficit = 0
        
--    ForEach { class = "StorageDepot", exec = function(depot)
--        if (not (depot.encyclopedia_id == "Rocket")) and depot.has_demand_request then
            
--            depotDemand = BetterLogisticsGetLargestDemand(depot)
--            if depotDemand.deficit > largestDemand.deficit then
--                largestDemand.deficit = depotDemand.deficit
--                largestDemand.resource = depotDemand.resource
--                largestDemand.depot = depot
--            end
--        end
--    end
--    }
    
--    return largestDemand

--end

--function BetterLogisticsGetLargestDemand(depot)
--    local demand = {}
--    demand.deficit = 0
    
--    for _, request in ipairs(depot.task_requests or empty_table) do
--        if request:IsAnyFlagSet(const.rfDemand) then
--            local resource = request:GetResource()
--            local stored = depot:GetStoredAmount()
--            local target = request:GetTargetAmount()
--            if target - stored > demand.deficit then
--                demand.resource = resource
--                demand.deficit = target - stored
--            end
--        end
--    end
--    return demand
--end

---- Copied from RCTransport.Lua, removed anything not specific to StorageDepots

--function BetterLogisticsCanPickupResourceFrom(o, resource)
--	local res = o.resource
--	return o:DoesHaveSupplyRequestForResource(resource) or false
--end


