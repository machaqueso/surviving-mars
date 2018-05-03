-- Inspired by akarnokd's excelent AutoGatherTransport: mod (https://github.com/akarnokd/surviving-mars-mods)
-- Parts of this code are based on that mod, specially the game thread, menu and modconfig sections

-- Globals
AutoCargo = {}
-- Base ID for translatable text
AutoCargo.StringIdBase = 20180406
-- global queue of transport tasks
AutoCargo.transport_tasks = {}

function OnMsg.GameTimeStart()
    AutoCargoInstallThread()
end

function OnMsg.LoadGame()
    AutoCargoInstallThread()
end

function AutoCargoInstallThread()
    CreateGameTimeThread(
        function()
            while true do
                --lcPrint("Ping")
                AutoCargo:DoTasks()
                local period = AutoCargo:ConfigUpdatePeriod()
                Sleep(tonumber(period))
            end
        end
    )
end

function OnMsg.NewHour()
    --lcPrint("NewHour")
    AutoCargo:DoTasks()
end

-- Setup UI
function OnMsg.ClassesBuilt()
    AutoCargoAddInfoSection()
    --AutoCargoManager:Init()
end

function AutoCargoAddInfoSection()
    if not table.find(XTemplates.ipRover[1], "UniqueId", "c71b64b6-3ccc-11e8-a681-63b2fbe75a75") then
        table.insert(
            XTemplates.ipRover[1],
            PlaceObj(
                "XTemplateTemplate",
                {
                    "__context_of_kind",
                    "RCTransport",
                    "__template",
                    "InfopanelActiveSection",
                    "Icon",
                    "UI/Icons/Upgrades/service_bots_01.tga",
                    "Title",
                    T {AutoCargo.StringIdBase + 11, "Auto Cargo"},
                    "RolloverText",
                    T {
                        AutoCargo.StringIdBase + 12,
                        "Enable/Disable transport rover from automatic resource transfer between storage depots.<newline><newline>(Auto Cargo Mod)"
                    },
                    "RolloverTitle",
                    T {AutoCargo.StringIdBase + 13, "Auto Cargo"},
                    "RolloverHint",
                    T {AutoCargo.StringIdBase + 14, "<left_click> Toggle setting"},
                    "OnContextUpdate",
                    function(self, context)
                        if context.auto_cargo then
                            self:SetTitle(T {AutoCargo.StringIdBase + 15, "Auto Cargo (ON)"})
                            self:SetIcon("UI/Icons/Upgrades/service_bots_02.tga")
                        else
                            self:SetTitle(T {AutoCargo.StringIdBase + 16, "Auto Cargo (OFF)"})
                            self:SetIcon("UI/Icons/Upgrades/service_bots_01.tga")
                        end
                    end,
                    "UniqueId",
                    "c71b64b6-3ccc-11e8-a681-63b2fbe75a75"
                },
                {
                    PlaceObj(
                        "XTemplateFunc",
                        {
                            "name",
                            "OnActivate(self, context)",
                            "parent",
                            function(parent, context)
                                return parent.parent
                            end,
                            "func",
                            function(self, context)
                                context.auto_cargo = not context.auto_cargo
                                ObjModified(context)
                            end
                        }
                    )
                }
            )
        )
    end
end

-- Setup ModConfig UI

-- See if ModConfig is installed and that notifications are enabled
function AutoCargo:ConfigShowNotification()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoCargo", "Notifications")
    end
    return "all"
end

function AutoCargo:ConfigUpdatePeriod()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoCargo", "UpdatePeriod")
    end
    return "5000"
end

-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()
    ModConfig:RegisterMod(
        "AutoCargo", -- ID
        T {AutoCargo.StringIdBase + 17, "AutoCargo"}, -- Optional display name, defaults to ID
        T {
            AutoCargo.StringIdBase + 18,
            "Transports automatically move resources between depots based on priority, keep themselves charged"
        } -- Optional description
    )

    ModConfig:RegisterOption(
        "AutoCargo",
        "Notifications",
        {
            name = T {AutoCargo.StringIdBase + 19, "Notifications"},
            desc = T {AutoCargo.StringIdBase + 20, "Enable/Disable notifications of the rovers in Auto mode."},
            type = "enum",
            values = {
                {value = "all", label = T {AutoCargo.StringIdBase + 21, "All"}},
                {value = "problems", label = T {AutoCargo.StringIdBase + 22, "Problems only"}},
                {value = "off", label = T {AutoCargo.StringIdBase + 23, "Off"}}
            },
            default = "problems"
        }
    )

    ModConfig:RegisterOption(
        "AutoCargo",
        "UpdatePeriod",
        {
            name = T {AutoCargo.StringIdBase + 24, "Update period"},
            desc = T {
                AutoCargo.StringIdBase + 25,
                "Time transport stays idle before picking a task.<newline>Pick a larger value if your colony has become large and you get lag."
            },
            type = "enum",
            values = {
                {value = "1000", label = T {"1 s"}},
                {value = "2000", label = T {"2 s"}},
                {value = "3000", label = T {"3 s"}},
                {value = "4000", label = T {"4 s"}},
                {value = "5000", label = T {"5 s"}},
                {value = "10000", label = T {"10 s"}}
            },
            default = "5000"
        }
    )
end

function AutoCargo:DoTasks()
    if not mapdata.GameLogic then
        return
    end

    ForEach {
        class = "RCTransport",
        exec = function(rover)
            --lcPrint(rover.command)

            if rover.auto_cargo and rover.command == "Idle" then
                if not rover.hauler_task then
                    --lcPrint("getting task")
                    local task = AutoCargo:FindTransportTask(rover)
                    if (task) then
                        --lcPrint("got task")
                        rover.hauler_task = task
                        AutoCargo:Pickup(rover)
                    end
                else
                    -- if idle and have a task means it's done picking up cargo
                    AutoCargo:Deliver(rover)
                end
            end
        end
    }
end

function AutoCargo:FindTransportTask(rover)
    local transport_task = LRManagerInstance:FindHaulerTask(rover)
    if transport_task then
        local supply_request = transport_task[2]
        local demand_request = transport_task[3]
        local resource = transport_task[4]
        local amount = Min(supply_request:GetTargetAmount(), demand_request:GetTargetAmount())

        local hauler_task = {}
        hauler_task.source = supply_request:GetBuilding()
        hauler_task.destination = demand_request:GetBuilding()
        hauler_task.resource = resource
        hauler_task.amount = amount
        lcPrint(
            amount ..
                " " .. resource .. " from " .. hauler_task.source.handle .. " to " .. hauler_task.destination.handle
        )

        return hauler_task
    end
end

function AutoCargo:Pickup(rover)
    local showNotifications = AutoCargo:ConfigShowNotification()

    if not rover.hauler_task then
        return
    end

    local resource = rover.hauler_task.resource
    local amount = rover.hauler_task.amount

    if amount <= 0 then
        rover.hauler_task = false
        --lcPrint("Pickup cancelled: zero resources requested")
        return
    end

    if not rover.hauler_task.source then
        rover.hauler_task = false
        --lcPrint("Pickup cancelled: invalid source")
        return
    end

    local source = rover.hauler_task.source

    if source:GetStoredAmount(resource) <= 0 then
        rover.hauler_task = false
        --lcPrint("Pickup cancelled: no resources at source")
        return
    end

    AutoCargo:Notify(rover, "all", "AutoCargoPickup", 26, "AutoCargo picking up " .. resource)

    SetUnitControlInteractionMode(rover, false)
    rover:SetCommand("TransferResources", source, "load", resource, amount)
end

function AutoCargo:Deliver(rover)
    local showNotifications = AutoCargo:ConfigShowNotification()

    --lcPrint("Deliver")
    if not rover.hauler_task then
        return
    end
    local resource = rover.hauler_task.resource
    local amount = rover.hauler_task.amount
    local destination = rover.hauler_task.destination

    if rover:GetStoredAmount() > 0 then
        AutoCargo:Notify(rover, "all", "AutoCargoDeliver", 27, "AutoCargo delivering " .. resource)
        SetUnitControlInteractionMode(rover, false)

        -- Hack to ensure unloading cargo (rover just stops if depot full)
        -- Couldn't figure out a way to find if depot is full
        if not rover.hauler_task.shouldDump then
            rover:SetCommand("TransferAllResources", destination, "unload", rover.storable_resources)
            rover.hauler_task.shouldDump = true
        else
            AutoCargo:Notify(rover, "problem", "AutoCargoDepotFull", 28, "Depot full, dumping " .. resource)
            rover:SetCommand("DumpCargo", destination:GetPos(), "all")
        end
    else
        --lcPrint("Cargo delivered")
        rover.hauler_task = false
    end
end

function AutoCargo:Notify(rover, level, title, messageId, message)
    local showNotifications = AutoCargo:ConfigShowNotification()

    if showNotifications == level then
        AddCustomOnScreenNotification(
            title,
            T {rover.name},
            T {AutoCargo.StringIdBase + messageId, message},
            "UI/Icons/Upgrades/service_bots_02.tga",
            false,
            {
                expiration = 5000
            }
        )
    end
end

-- Adapted from ShuttleHub.Lua
function AutoCargo:OnTaskAssigned(rover)
    assert(not rover.assigned_to_s_req and not rover.assigned_to_d_req)
    rover.is_colonist_transport_task = false
    local supply_request = rover.transport_task[2]
    local demand_request = rover.transport_task[3]
    local resource = rover.transport_task[4]
    local amount =
        Min(
        rover.max_shared_storage,
        supply_request and supply_request:GetTargetAmount() or max_int,
        demand_request:GetTargetAmount()
    )

    --assign early so cc's updating their deficit will see us
    if amount <= 0 or (supply_request and not supply_request:AssignUnit(amount)) then
        return false
    end

    if not demand_request:AssignUnit(amount) then
        if supply_request then
            supply_request:UnassignUnit(amount, false)
        end
        return false
    end

    rover.assigned_to_s_req = supply_request and {supply_request, amount} or false
    rover.assigned_to_d_req = {demand_request, amount}
    demand_request:GetBuilding():ChangeDeficit(resource, amount)

    return true
end

--[[
    CODE BELOW BASED ON LRTransport.Lua
]]
local minimum_resource_amount_treshold = const.TransportMinResAmountTreshold
local dist_threshold = const.TransportDistThreshold

local function t_to_prio(t)
    local as_dist = t / 10 --1s ~ 1guim
    return as_dist
end

local function d_to_prio(d)
    return d * -1
end

local function CalcDemandPrio(req, bld, requestor)
    local d = bld:GetDist2D(requestor)
    --time since serviced, dist (closer is better), if any resource set to import + 100000 + needed amount
    return t_to_prio(now() - req:GetLastServiced()) + req:GetTargetAmount() + d_to_prio(d)
end

local function CalcSupplyPrio(s_req, s_bld, d_req, d_bld, requestor, demand_score)
    local d = s_bld:GetDist2D(d_bld)
    local d2 = s_bld:GetDist2D(requestor)
    return s_req:GetTargetAmount() + d_to_prio(d) + d_to_prio(d2) + demand_score
end

local function CheckMinDist(bld1, bld2)
    if bld1:IsCloser2D(bld2, dist_threshold) then
        local did_reach, len = pf.PathLen(bld1:GetPos(), 0, bld2:GetPos()) --cant cache :(
        return not did_reach or len > dist_threshold
    end
    return true
end

-- Stripped down version of LRManagerInstance:FindTransportTask()
function LRManagerInstance:FindHaulerTask(requestor)
    --lcPrint("FindHaulerTask")
    local resources = StorableResourcesForSession
    local demand_queues = self.demand_queues
    local supply_queues = self.supply_queues

    local res_prio, res_s_req, res_d_req, res_resource = min_int, false, false, false
    for k = 1, #resources do
        local resource = resources[k]
        local d_queue = demand_queues[resource]
        local s_queue = supply_queues[resource] or empty_table
        for i = 1, #d_queue do
            local d_req = d_queue[i]

            local d_bld = d_req:GetBuilding()

            local d_prio = CalcDemandPrio(d_req, d_bld, requestor)
            for j = 1, #s_queue do
                local s_req = s_queue[j]
                local s_bld = s_req:GetBuilding()
                if
                    s_bld ~= d_bld and s_req:GetTargetAmount() > minimum_resource_amount_treshold and
                        CheckMinDist(s_bld, d_bld)
                 then
                    local s_prio = CalcSupplyPrio(s_req, s_bld, d_req, d_bld, requestor, d_prio)
                    if res_prio < s_prio then
                        res_prio, res_s_req, res_d_req, res_resource = s_prio, s_req, d_req, resource
                    end
                end
            end
        end
    end

    -- local hystory = self.req_hystory or {}
    -- self.req_hystory = hystory
    -- local last_entry = hystory[#hystory]
    -- local time = GameTime()
    -- local count = req_count
    -- local next_idx = last_entry and last_entry:x() == time and #hystory or #hystory + 1
    -- hystory[next_idx] = point(time, count)
    -- while #hystory > 10 and time - hystory[1]:x() >= hystory_time do
    --     table.remove(hystory, 1)
    -- end

    local best_task = res_prio and {res_prio, res_s_req, res_d_req, res_resource}
    -- if (best_task) then
    --     lcPrint(best_task)
    -- else
    --     lcPrint("no task assigned :(")
    -- end
    return best_task
end
