AutoCargo = { }
-- Base ID for translatable text
AutoCargo.StringIdBase = 20180406

-- Setup UI

function OnMsg.ClassesBuilt()
    AutoCargoAddInfoSection()
end

function AutoCargoAddInfoSection()

    if not table.find(XTemplates.ipRover[1],"UniqueId","c71b64b6-3ccc-11e8-a681-63b2fbe75a75") then

        table.insert(XTemplates.ipRover[1], 
            PlaceObj("XTemplateTemplate", {
                "__context_of_kind", "RCTransport",
                "__template", "InfopanelActiveSection",
                "Icon", "UI/Icons/Upgrades/service_bots_01.tga",
                "Title", T{AutoCargo.StringIdBase + 11, "Auto Cargo"},
                "RolloverText", T{AutoCargo.StringIdBase + 12, "Enable/Disable transport rover from automatic resource transfer between storage depots.<newline><newline>(Auto Cargo Mod)"},
                "RolloverTitle", T{AutoCargo.StringIdBase + 13, "Auto Cargo"},
                "RolloverHint",  T{AutoCargo.StringIdBase + 14, "<left_click> Toggle setting"},
                "OnContextUpdate",
                    function(self, context)
                        if context.auto_transport then
                            self:SetTitle(T{AutoCargo.StringIdBase + 15, "Auto Cargo (ON)"})
                            self:SetIcon("UI/Icons/Upgrades/service_bots_02.tga")
                        else
                            self:SetTitle(T{AutoCargo.StringIdBase + 16, "Auto Cargo (OFF)"})
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
function AutoCargoConfigShowNotification()
    if rawget(_G, "ModConfig") then
        return ModConfig:Get("AutoCargo", "Notifications")
    end
    return "all"
end

-- ModConfig signals "ModConfigReady" when it can be manipulated
function OnMsg.ModConfigReady()

    ModConfig:RegisterMod("AutoCargo", -- ID
        T{AutoCargo.StringIdBase + 17, "AutoCargo"}, -- Optional display name, defaults to ID
        T{AutoCargo.StringIdBase + 18, "Transports automatically move resources between depots based on priority, keep themselves charged"} -- Optional description
    ) 

    ModConfig:RegisterOption("AutoCargo", "Notifications", {
        name = T{AutoCargo.StringIdBase + 19, "Notifications"},
        desc = T{AutoCargo.StringIdBase + 20, "Enable/Disable notifications of the rovers in Auto mode."},
        type = "enum",
        values = {
            {value = "all", label = T{AutoCargo.StringIdBase + 21, "All"}},
            {value = "problems", label = T{AutoCargo.StringIdBase + 22, "Problems only"}},
            {value = "off", label = T{AutoCargo.StringIdBase + 23, "Off"}}
        },
        default = "all" 
    })
    
end
