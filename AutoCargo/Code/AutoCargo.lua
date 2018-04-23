AutoCargo = {}
-- Base ID for translatable text
AutoCargo.StringIdBase = 20180406

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
function AutoCargoConfigShowNotification()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoCargo", "Notifications")
    end
    return "all"
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
            default = "all"
        }
    )
end

function OnMsg.NewHour()
    AutoCargo:DoTasks()
end

function AutoCargo:DoTasks()
    ForEach {
        class = "RCTransport",
        exec = function(rover)
            --lcPrint(rover.command)
            if rover.auto_cargo and rover.command == "Idle" then
                if not rover.auto_cargo_task then
                    --lcPrint("getting task")
                    local task = AutoCargo:FindTransportTask(rover)
                    if (task) then
                        --lcPrint("got task")
                        rover.auto_cargo_task = task
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

function AutoCargo:Pickup(rover)
    --lcPrint("Pickup")
    if not rover.auto_cargo_task then
        return
    end
    local resource = rover.auto_cargo_task.resource
    local amount = rover.auto_cargo_task.amount

    if amount <= 0 then
        rover.auto_cargo_task = false
        --lcPrint("Pickup cancelled: zero resources requested")
        return
    end

    if not rover.auto_cargo_task.source then
        rover.auto_cargo_task = false
        --lcPrint("Pickup cancelled: invalid source")
        return
    end

    local source = rover.auto_cargo_task.source

    if source:GetStoredAmount(resource) <= 0 then
        rover.auto_cargo_task = false
        --lcPrint("Pickup cancelled: no resources at source")
        return
    end

    --lcPrint("Picking up " .. resource .. " from depot at " .. print_format(source:GetPos()))
    SetUnitControlInteractionMode(rover, false)
    rover:SetCommand("TransferResources", source, "load", resource, amount)
end

function AutoCargo:Deliver(rover)
    --lcPrint("Deliver")
    if not rover.auto_cargo_task then
        return
    end
    local resource = rover.auto_cargo_task.resource
    local amount = rover.auto_cargo_task.amount
    local destination = rover.auto_cargo_task.destination

    if rover:GetStoredAmount() > 0 then
        --lcPrint("Delivering " .. amount .. " " .. resource .. " to depot at " .. print_format(destination:GetPos()))
        SetUnitControlInteractionMode(rover, false)
        rover:SetCommand("TransferAllResources", destination, "unload", rover.storable_resources)
    else
        --lcPrint("Cargo delivered")
        rover.auto_cargo_task = false
    end
end

function AutoCargo:FindTransportTask()
    --lcPrint("FindTransportTask")
    local MinResourceThreshold = 4 -- TODO make configurable through modconfig
    local supply_queue = {}
    local demand_queue = {}

    local function PrintTask(type, task)
        if task then
            --lcPrint(type .. ", " .. task.resource .. ", " .. task.amount)
        end
    end

    local function QueueSupply(depot, task)
        local resource = task:GetResource()
        local amount = task:GetActualAmount()
        if amount > MinResourceThreshold then
            local supply_task = {}
            supply_task.depot = depot
            supply_task.resource = resource
            supply_task.amount = amount
            table.insert(supply_queue, supply_task)
        end
    end

    local function QueueDemand(depot, task)
        local resource = task:GetResource()
        local amount = task:GetTargetAmount()
        -- for initial simplicity, we only include depots with no resource
        if task:GetActualAmount() == 0 then
            --PrintTask("demand", task)
            local demand_task = {}
            demand_task.depot = depot
            demand_task.resource = resource
            demand_task.amount = amount
            table.insert(demand_queue, demand_task)
        end
    end

    local storable_resources = {
        "Concrete",
        "Metals",
        "Polymers",
        "Food",
        "Electronics",
        "MachineParts",
        "PreciousMetals",
        "Fuel",
        "MysteryResource",
        "BlackCube"
    }
    local depots = {}

    for _, resource in ipairs(storable_resources) do
        depots[resource] = 0
    end

    -- Get all supply and demand tasks
    ForEach {
        class = "StorageDepot",
        exec = function(depot)
            -- count depots with stock for average
            for k, v in pairs(depot.stockpiled_amount) do
                if v > 0 then
                    depots[k] = depots[k] + 1
                end
            end

            for _, request in ipairs(depot.task_requests or empty_table) do
                if request:IsAnyFlagSet(const.rfDemand) then
                    -- RCTransports cannot deliver to rockets
                    -- TODO: Should probably exclude space elevator as well
                    if not (depot.encyclopedia_id == "Rocket") then
                        QueueDemand(depot, request)
                    end
                end
                if request:IsAnyFlagSet(const.rfSupply) then
                    QueueSupply(depot, request)
                end
            end
        end
    }
    ----lcPrint("found " .. numDepots .. " depots")

    -- approach: move resources until all depots have same amount
    -- sort demand tasks ascending
    -- TODO: this sort will be by priority scoring in the future
    table.sort(
        demand_queue,
        function(a, b)
            return a.amount > b.amount
        end
    )
    --PrintTask("demand", demand_queue[1])
    -- sort supply tasks by descending amount of stored resource
    table.sort(
        supply_queue,
        function(a, b)
            return a.amount < b.amount
        end
    )
    --PrintTask("supply", supply_queue[1])

    -- loop through demand tasks until we find a supply depot with resources to satisface it
    for _, demand in ipairs(demand_queue) do
        local resource = demand.resource
        local amount = demand.amount
        --lcPrint(resource .. " demand: "..amount)
        local available = ResourceOverviewObj:GetAvailable(resource) or 0
        --lcPrint("total "..resource.." available: "..available.." in "..depots[resource].." depots")
        local average = available / depots[resource]
        --lcPrint(resource .. " average: " .. average)
        for _, supply in ipairs(supply_queue) do
            if (supply.resource == resource) and (supply.amount > average) then
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
