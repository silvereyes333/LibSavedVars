--[[
     LibSavedVars table with defaults fallback class.
     
     LSV_DefaultsTable:New()
  ]]--

local LIBNAME      = "LibSavedVars"
local CLASSNAME    = "DefaultsTable"
local CLASSVERSION = 1.0

-- If a newer version of this class is already loaded, exit
local class, protected = LibSavedVars:NewClass(CLASSNAME, CLASSVERSION)
if not class then return end

LSV_DefaultsTable = class

local debugMode = false
local rawnext = LibLua52 and LibLua52.rawnext or next
local rawipairs = LibLua52 and LibLua52.rawipairs or ipairs
---------------------------------------
--
--       Public Methods
-- 
---------------------------------------

function LSV_DefaultsTable:New(data, defaults, parent, parentKey)
    defaults = defaults or {}
    local instance = setmetatable({}, self)
    LSV_DefaultsTable.Initialize(instance, data, defaults, parent, parentKey)    
    return instance
end

function LSV_DefaultsTable:AttachChild(key, childDefaultsTable)
    protected.Debug("LSV_DefaultsTable:AttachChild(<<1>>, <<2>>)", debugMode, key, tostring(childDefaultsTable))
    local children, data, defaults, _, _, _, injectForNonDefaults = LSV_DefaultsTable.GetDataSources(self)
    children[key] = childDefaultsTable
    
    if LSV_DefaultsTable.ContainsNonDefaultValues(childDefaultsTable) then
        local rawChildData = rawget(childDefaultsTable, "__data")
        if not data then
            data = {[key] = rawChildData}
            rawset(self, "__data", data)
        else
            data[key] = rawChildData
        end
        if injectForNonDefaults then
            for injectKey, injectValue in pairs(injectForNonDefaults) do
                data[injectKey] = injectValue
            end
        end
        
    elseif data then
        self[key] = nil
    end
end

function LSV_DefaultsTable:ContainsNonDefaultValues()
    protected.Debug("LSV_DefaultsTable:ContainsNonDefaultValues()", debugMode)
    local children, data, defaults, _, _, _, injectForNonDefaults = LSV_DefaultsTable.GetDataSources(self)
    if data then
        local key
        repeat key = next(data, key)
        until not injectForNonDefaults or injectForNonDefaults[key] == nil
        if key ~= nil then
            return true
        end
    end
    for _, child in pairs(children) do
        if LSV_DefaultsTable.ContainsNonDefaultValues(child) then
            return true
        end
    end
end

function LSV_DefaultsTable:Except(keys)
    protected.Debug("LSV_DefaultsTable:Except(<<1>>)", debugMode, tostring(keys))
    local filtered = {}
    local dataSources = {LSV_DefaultsTable.GetDataSources(self)}
    for _, ds in ipairs(dataSources) do
        for key, value in pairs(ds) do
            if filtered[key] == nil and keys[key] == nil then
                filtered[key] = ds[key]
            end
        end
    end
    return filtered
end
function LSV_DefaultsTable:Initialize(data, defaults, parent, parentKey)
    protected.Debug("LSV_DefaultsTable:Initialize(<<1>>, <<2>>, <<3>>)", debugMode, tostring(data), tostring(parent), parentKey)
    local children = {}
    local parentIsDefaultsTable = getmetatable(parent) == LSV_DefaultsTable
    rawset(self, "__children", children)
    rawset(self, "__data", data)
    if defaults then
        rawset(self, "__defaults", defaults)
    else
        defaults = rawget(self, "__defaults")
    end
    rawset(self, "__parent", parent)
    rawset(self, "__parentKey", parentKey)
    rawset(self, "__parentIsDefaultsTable", parentIsDefaultsTable)
    if data then
        for key, value in pairs(data) do
            if type(value) == 'table' then
                LSV_DefaultsTable:New(value, defaults[key] or {}, self, key)
            
            -- Automatically trim default data
            elseif defaults[key] == value then
                data[key] = nil
            end
        end
    end
    if defaults then
        for key, value in pairs(defaults) do
            if type(value) == 'table' and children[key] == nil then
                LSV_DefaultsTable:New(nil, value, self, key)
            end
        end
    end
    
    if parentIsDefaultsTable then
        LSV_DefaultsTable.AttachChild(parent, parentKey, self)
    end
    if not LSV_DefaultsTable.ContainsNonDefaultValues(self) then
        rawset(self, "__data", nil)
        if parent and not parentIsDefaultsTable then
            parent[parentKey] = nil
        end
    end
end

function LSV_DefaultsTable:Filter(keys)
    protected.Debug("LSV_DefaultsTable:Filter(<<1>>)", debugMode, tostring(keys))
    local filtered = {}
    local dataSources = {LSV_DefaultsTable.GetDataSources(self)}
    local keyCount = NonContiguousCount(keys)
    local filteredKeyCount = 0
    for key, _ in pairs(keys) do
        for _, ds in ipairs(dataSources) do
            if filtered[key] == nil and ds[key] ~= nil then
                filtered[key] = ds[key]
                filteredKeyCount = filteredKeyCount + 1
                if filteredKeyCount == keyCount then
                    return filtered
                end
            end
        end
    end
    return filtered
end

function LSV_DefaultsTable:GetDataSources()
    return rawget(self, "__children"), rawget(self, "__data"), rawget(self, "__defaults"), rawget(self, "__parent"), 
           rawget(self, "__parentKey"), rawget(self, "__parentIsDefaultsTable"), rawget(self, "__injectForNonDefaults")
end

function LSV_DefaultsTable:GetIterator()
    protected.Debug("LSV_DefaultsTable:GetIterator()", debugMode)
    if not self then return rawnext, nil end
    local children, data, defaults = LSV_DefaultsTable.GetDataSources(self)
    
    local subTables = { data or {}, defaults }
    local subTableIndex, subTable = 1, subTables[1]
    -- TODO: Remove this before publish
    local maxIterations = 100 --temporary failsafe
    local iterations = 0
    return
        function(_, key)
            if key == nil then
                subTableIndex, subTable = 1, subTables[1]
            end
            local value
            repeat
                protected.Debug("subtableIndex: <<1>>, subTable: <<2>>, key: <<3>>", debugMode, 
                                subTableIndex, tostring(subTable), key)
                key, value = rawnext(subTable, key)
                iterations = iterations + 1
                if key == nil then
                    subTableIndex, subTable = subTableIndex + 1, subTables[subTableIndex + 1]
                elseif type(value) == "table" then
                    value = children[value]
                -- TODO: remove this before publish
                elseif iterations >= maxIterations then
                    protected.Debug("max iterations for defaults table reached. exiting.", debugMode)
                end
            until key ~= nil or not subTable
            protected.Debug("key: <<1>>, value: <<2>>", debugMode, key, value)
            return key, value
        end, 
        self,
        nil
end

function LSV_DefaultsTable:GetLength()
    protected.Debug("LSV_DefaultsTable:GetLength()", debugMode)
    local children, data, defaults = LSV_DefaultsTable.GetDataSources(self)
    return math.max(#data, #defaults)
end

function LSV_DefaultsTable:GetNumericIterator()
    protected.Debug("LSV_DefaultsTable:GetNumericIterator()", debugMode)
    if not self then return rawipairs, nil end
    local children, data, defaults = LSV_DefaultsTable.GetDataSources(self)
    if not data then
        data = {}
    end
    
    local maxIndex = math.max(#data, #defaults)
    return
        function(_, index)
            if index == nil then
                index = 1
            else
                index = index + 1
            end
            if index > maxIndex then
                return
            end
            local value 
            if data and data[index] ~= nil then
                value = data[index]
            elseif defaults and defaults[index] ~= nil then
                value = defaults[index]
            end
            if type(value) == "table" and children then
                value = children[index]
            end
            return index, value
        end, 
        self,
        0
end

--[[ Used to inject standard ZO_SavedVars fields like version and $LastCharacterName, as well as the special LibSavedVars field ]]--
function LSV_DefaultsTable:InjectForNonDefaults(fieldsToInject)
    rawset(self, "__injectForNonDefaults", fieldsToInject)
    if LSV_DefaultsTable.ContainsNonDefaultValues(self) then
        for key, value in pairs(fieldsToInject) do
            LSV_DefaultsTable.__newindex(self, key, value)
        end
    else
        for key, value in pairs(fieldsToInject) do
            LSV_DefaultsTable.__newindex(self, key, nil)
        end
    end
end

function LSV_DefaultsTable:Unpack()
    local children, data, defaults = LSV_DefaultsTable.GetDataSources(self)
    local all = {}
    for _, value in LSV_DefaultsTable.GetNumericIterator(self) do
        table.insert(all, value)
    end
    return unpack(all)
end

---------------------------------------
--
--       Meta methods
-- 
---------------------------------------

function LSV_DefaultsTable.__index(defaultsTable, key)
    --protected.Debug("LSV_DefaultsTable:__index(<<1>>)", debugMode, key)
    if type(LSV_DefaultsTable[key]) == "function" then
        return LSV_DefaultsTable[key]
    end
    local children, data, defaults = LSV_DefaultsTable.GetDataSources(defaultsTable)
    if children[key] ~= nil then
        return children[key]
    end
    if data and data[key] ~= nil then
        return data[key]
    end
    return defaults[key]
end

function LSV_DefaultsTable.__newindex(defaultsTable, key, value)
    protected.Debug("LSV_DefaultsTable:__newindex(<<1>>, <<2>>)", debugMode, key, tostring(value))
    
    if not defaultsTable then return end
    
    local children, data, defaults, parent, parentKey, parentIsDefaultsTable = LSV_DefaultsTable.GetDataSources(defaultsTable)
            
    if type(value) == "table" then
        -- Automatically attaches itself to defaultsTable as needed. No need to alter children.
        if children[key] then
            LSV_DefaultsTable.Initialize(children[key], value, nil, defaultsTable, key)
        else
            LSV_DefaultsTable:New(value, defaults[key], defaultsTable, key)
        end
        return
    end
    
    if value == defaults[key] then
        if data then
            data[key] = nil
            if next(data) == nil then
                data = nil
                rawset(defaultsTable, "__data", nil)
            end
        end
        if parentIsDefaultsTable then
            LSV_DefaultsTable.AttachChild(parent, parentKey, defaultsTable)
        elseif parent and data == nil then
            parent[parentKey] = nil
        end
    else
        if not data then
            data = {[key] = value}
            rawset(defaultsTable, "__data", data)
            if parentIsDefaultsTable then
                LSV_DefaultsTable.AttachChild(parent, parentKey, defaultsTable)
            elseif parent then
                parent[parentKey] = data
            end
        else
            data[key] = value
        end
    end
end

LSV_DefaultsTable.__ipairs = LSV_DefaultsTable.GetNumericIterator
LSV_DefaultsTable.__pairs = LSV_DefaultsTable.GetIterator