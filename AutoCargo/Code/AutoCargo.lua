AutoCargo = {}
-- Base ID for translatable text
AutoCargo.StringIdBase = 20180406

-- Setup UI

function OnMsg.ClassesBuilt()
    AutoCargoAddInfoSection()
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
            if rover.auto_cargo and rover.command == "Idle" then
                if not rover.auto_cargo_task then
                    local task = AutoCargoManagerInstance:FindTransportTask(rover)
                    if (task) then
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
    lcPrint("Pickup")
    if not rover.auto_cargo_task then
        return
    end
    local resource = rover.auto_cargo_task.resource
    local amount = rover.auto_cargo_task.amount

    if amount <= 0 then
        rover.auto_cargo_task = false
        lcPrint("Pickup cancelled: zero resources requested")
        return
    end

    if not rover.auto_cargo_task.source then
        rover.auto_cargo_task = false
        lcPrint("Pickup cancelled: invalid source")
        return
    end

    local source = rover.auto_cargo_task.source

    if source:GetStoredAmount(resource) <= 0 then
        rover.auto_cargo_task = false
        lcPrint("Pickup cancelled: no resources at source")
        return
    end

    lcPrint("Picking up " .. resource .. " from depot at " .. print_format(source:GetPos()))
    SetUnitControlInteractionMode(rover, false)
    rover:SetCommand("TransferResources", source, "load", resource, amount)
end

function AutoCargo:Deliver(rover)
    lcPrint("Deliver")
    if not rover.auto_cargo_task then
        return
    end
    local resource = rover.auto_cargo_task.resource
    local amount = rover.auto_cargo_task.amount
    local destination = rover.auto_cargo_task.destination

    if rover:GetStoredAmount() > 0 then
        lcPrint("Delivering " .. amount .. " " .. resource .. " to depot at " .. print_format(destination:GetPos()))
        SetUnitControlInteractionMode(rover, false)
        rover:SetCommand("TransferAllResources", destination, "unload", rover.storable_resources)
    else
        lcPrint("Cargo delivered")
        rover.auto_cargo_task = false
    end
end
