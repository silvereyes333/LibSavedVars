--[[ LibSavedVars and its files © silvereyes
     Distributed under MIT license (see LICENSE.txt) ]]

-- copy language strings locally, then destroy
local libSavedVarsStrings = LIBSAVEDVARS_STRINGS
LIBSAVEDVARS_STRINGS = nil

--Register LibSavedVars with LibStub
local MAJOR, MINOR = "LibSavedVars", 1
local libSavedVars, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not libSavedVars then return end --the same or newer version of this lib is already loaded into memory

-- Server/world name registry
local WORLDS = {
    ["live"] = {
        ["EU Megaserver"] = true,
        ["NA Megaserver"] = true,
    },
    ["pts"] = {
        ["PTS"] = true
    },
}
local DO_NOT_OVERWRITE = true

-- Create localized strings
for stringId, value in pairs(libSavedVarsStrings) do
    ZO_CreateStringId(stringId, value)
end

-- Clears all settings from the given 
function libSavedVars:ClearSavedVars(savedVars)
    for key, value in pairs(getmetatable(savedVars).__index) do
        if key ~= "version" and type(value) ~= "function" then
            savedVars[key] = nil
        end
    end
end

local function deepSavedVarsCopy(source, dest, doNotOverwrite)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(dest[key]) ~= "table" then
                dest[key] = {}
            end
            deepSavedVarsCopy(value, dest[key], doNotOverwrite)
        elseif key ~= "version" and type(value) ~= "function" then
            if not doNotOverwrite or dest[key] == nil then
                dest[key] = value
            end
        end
    end
end

function libSavedVars:DeepSavedVarsCopy(source, dest, doNotOverwrite)
    deepSavedVarsCopy(getmetatable(source).__index, getmetatable(dest).__index)
end

function libSavedVars:Get(addon, key)
    if addon.characterSettings.useAccountSettings then
        return addon.accountSettings[key]
    else
        return addon.characterSettings[key]
    end 
end

function libSavedVars:GetLibAddonMenuSetting(addon, default)
    -- Account-wide settings
    return {
        type    = "checkbox",
        name    = GetString(SI_LSV_ACCOUNT_WIDE),
        tooltip = GetString(SI_LSV_ACCOUNT_WIDE_TT),
        getFunc = function() return addon.characterSettings.useAccountSettings end,
        setFunc = function(value)
            addon.characterSettings.useAccountSettings = value
            -- When account-wide settings are the default and character-specific settings are chosen, 
            -- copy any account-wide settings that are not defined on the character to the character-specific settings.
            if default and not value then
                self:DeepSavedVarsCopy(addon.accountSettings, addon.characterSettings, DO_NOT_OVERWRITE)
            end
        end,
        default = default,
    }
end

function libSavedVars:Init(addon, accountWideSavedVarsName, characterSavedVarsName, 
                           defaults, useAccountSettingsDefault, 
                           legacySavedVars, legacyIsAccountWide, legacyMigrationCallback)
    
    local accountWideDefaults = ZO_ShallowTableCopy(defaults)
    accountWideDefaults["useAccountSettings"] = nil
    useAccountSettingsDefault = useAccountSettingsDefault or defaults["useAccountSettings"]
    
    if useAccountSettingsDefault then
        defaults = { ["useAccountSettings"] = true }
    else
        defaults["useAccountSettings"] = false
    end
    
    local worldName = GetWorldName()
    addon.accountSettings = ZO_SavedVars:NewAccountWide(accountWideSavedVarsName, 1, nil, accountWideDefaults, worldName)
    addon.characterSettings = ZO_SavedVars:NewCharacterIdSettings(characterSavedVarsName, 1, nil, defaults, worldName)
    
    if not legacySavedVars or legacySavedVars.libSavedVarsMigrated then
        return
    end
    
    -- Migrate old settings to new world-specific settings
    
    if legacyMigrationCallback and type(legacyMigrationCallback) == "function" then
        legacyMigrationCallback(addon, legacySavedVars)
    end
    local worlds = WORLDS["live"][worldName] and WORLDS["live"] or WORLDS["pts"]
    
    for copyToWorldName, _ in pairs(worlds) do
        local settings
        if copyToWorldName == worldName then
            settings = legacyIsAccountWide and addon.accountSettings or addon.characterSettings
        elseif legacyIsAccountWide then
            settings = ZO_SavedVars:NewAccountWide(accountWideSavedVarsName, 1, nil, accountWideDefaults, copyToWorldName)
        end
        if settings then
            self:DeepSavedVarsCopy(legacySavedVars, settings)
        end
    end
    self:ClearSavedVars(legacySavedVars)
    legacySavedVars.libSavedVarsMigrated = true
end

function libSavedVars:Set(addon, key, value)
    if addon.characterSettings.useAccountSettings then
        addon.accountSettings[key] = value
    else
        addon.characterSettings[key] = value
    end 
end