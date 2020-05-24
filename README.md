# LibSavedVars

A library to manage and migrate to addon settings that support scopes per server, per account and per character, and to allow toggling between scopes on-the-fly.

[TOC]

## Should I Use LibSavedVars?

LibSavedVars provides several capabilities that the built-in ZO_SavedVars functionality does not:

- Toggling between server-wide and character-specific saved variables at runtime, without reloading
- Versioning / upgrading saved vars structure without resetting all existing data.
- Not storing all default values to disk, making the files in your SavedVariables folder much easier to read and manage with a text editor.



## How Easy Is LibSavedVars to Use?

LibSavedVars is just as easy to use as ZO_SavedVars, just with some additional functionality.

It will be easiest to implement for the following kinds of addons:

- Addons that don't yet have any saved vars
- Addons that only have a single saved var table for player settings
- Addons that have a single saved var for character settings and a single saved var for account-wide settings, and the state for which one is active for a player is stored within the character settings table.

If your addon falls into one of those two categories, migrating to LibSavedVars should only take a few lines of code beyond including the library.



## What LibSavedVars Is NOT For

- Server-Agnostic Saved Vars

  If you don't need to separate out data between NA and EU because the data you are tracking doesn't change (e.g. furniture lists, item links, coordinate positions, etc), then LibSavedVars isn't going to really provide you with much advantage over the normal "Default" account wide ZO_SavedVars functionality.

- Addons with complex custom logic for managing saved variable scope between servers

  You are certainly free to rework your addon to use LibSavedVars instead, but it's most likely not going to do everything your custom implementation does.

- Addons with a saved var for character settings and one for account settings, but the state for which one is active is stored within the account settings table.

  I'll probably add a function in the future to enable account-wide settings on all characters with a simple function call, but it will always retain the ability to disable account-wide settings for an individual character while having them enabled for others.

  LibSavedVars is designed with the idea that account-wide settings represent a player's global default preferences, and character-specific settings act as overrides to those defaults.

  Forcing a player to choose between whether they want global defaults -OR- per-character customization runs counter to the purpose of LibSavedVars.



## Planned Features

- 
  Adding a function and a LibAddonMenu-2.0 button to enable account-wide settings on all characters
- Utilities and LibAddonMenu-2.0 controls for copying settings between characters, accounts and servers.



## Installation

Add a [`## DependsOn: LibSavedVars`](https://wiki.esoui.com/Addon_manifest_(.txt)_format#DependsOn) clause to your addon manifest.  That's it.  You should no longer need to bundle libraries with your addons.



## Setup

- Create a SavedVariables entry in your addon manifest txt file.  If you have any existing `## SavedVariables` entry (e.g. `MyAddon_Data`) leave it in place.

  ###### MyAddon/MyAddon.txt (manifest file example)

  ```
  ## Title: My Cool Addon
  ## Author: silvereyes
  ## Description: Example of LibSavedVars usage.
  ## Version: 1.2.0
  ## APIVersion: 100030 100031
  ## DependsOn: LibSavedVars LibAddonMenu-2.0
  ## SavedVariables: MyAddon_Data
  ```

- Inside an [event handler](https://wiki.esoui.com/Events#Introduction) for [EVENT_ADD_ON_LOADED](https://wiki.esoui.com/Events#UI_Loading) in your addon lua code, do one of the following:

  If you want account-wide settings to be the default:

  ```lua
  MyAddon.settings = LibSavedVars
      :NewAccountWide( "MyAddon_Data", "Account", MyAddon.defaults )
      :AddCharacterSettingsToggle( "MyAddon_Data", "Characters" )
      # Optional, if you have existing data
      :MigrateFromAccountWide( { name = "MyAddon_Data" } )
      # Optional, if you want to not persist defaults to disk
      :EnableDefaultsTrimming()
  ```

  If you want character-specific settings to be the default.  Note, if you have an old saved var created with ZO_SavedVars:NewCharacterIdSettings(), then you will want to use `:MigrateFromCharacterId()` instead of `:MigrateFromCharacterName()`.

  ```lua
  MyAddon.settings = LibSavedVars
      :NewCharacterSettings( "MyAddon_Data", "Characters", MyAddon.defaults )
      :AddAccountWideToggle( "MyAddon_Data", "Account" )
      # Optional, if you have existing data.
      :MigrateFromCharacterName( { name = "MyAddon_Data" } ) 
      # Optional, if you want to not persist defaults to disk
      :EnableDefaultsTrimming()
  ```

  

## Versioning / Upgrading

You can chain the following methods after the `:New***Settings()`, `:Add***Toggle()` and `:MigrateFrom***()` method calls to add versioning.  Multiple methods can be called per version.

### :Version()

Upgrades all saved vars tracked by this data instance of a given scope to the given version number.  Has no effect on saved vars at or above the given version.

- *version* `number`: Settings are only upgraded on saved vars below this version number.
- *scope* `string` (optional): `LIBSAVEDVARS_SCOPE_CHARACTER`, `LIBSAVEDVARS_SCOPE_ACCOUNT` or `*`. Defaults to `*`.
- *onVersionUpdate* `function`: Upgrade script function with the signature function(rawDataTable) end to be run before updating saved vars version.  You can run any settings transforms in here.

```lua
local version2, version3
addon.settings = LibSavedVars:NewAccountWide("MyAddon_Data", "Account", MyAddon.defaults)
                             :Version(2, version2)
                             :Version(3, version3)

function version2(savedVarsTable)
    -- v2 transformation logic goes here
end

function version3(savedVarsTable)
    -- v3 transformation logic goes here
end
```

### :RemoveSettings()

Removes a list of settings from all saved vars tracked by this data instance of a given scope when upgrading to the given version number.  Has no effect on saved vars at or above the given version.

- *version* `number`: Settings are only upgraded on saved vars below this version number.
- *scope* `string` (optional): `LIBSAVEDVARS_SCOPE_CHARACTER`, `LIBSAVEDVARS_SCOPE_ACCOUNT` or `*`. Defaults to `*`.
- *settingsToRemove* `function`: Either a table containing a list of string setting names to remove, or a single string  setting name.  If a string is given, then additional strings can be provided as extra parameters.

```lua
addon.settings = LibSavedVars:NewAccountWide("MyAddon_Data", "Account", MyAddon.defaults)
                             :RemoveSettings(2, "key1", "key2", "key3")
```

### :RenameSettings()

Changes the names of a list of settings in all saved vars tracked by this data instance of a given scope when upgrading to the given version number.  Has no effect on saved vars at or above the given version.

- *version* `number`: Settings are only upgraded on saved vars below this version number.
- *scope* `string` (optional): `LIBSAVEDVARS_SCOPE_CHARACTER`, `LIBSAVEDVARS_SCOPE_ACCOUNT` or `*`. Defaults to `*`.
- *renameMap* `table`: A key-value table containing a mapping of old setting names (keys) to new setting names (values).
- *callback* `function` (optional): A function to be called on saved vars values right before they are renamed. Used by `:RenameSettingsAndInvert()`.

```lua
local beforeRenameV2, renamedSettingsV2

addon.settings = LibSavedVars:NewAccountWide("MyAddon_Data", "Account", MyAddon.defaults)
                             :RenameSettings(2, renamedSettingsV2, beforeRenameV2)

function beforeRenameV2(value)
    local newValue
    -- do something to transform value into newValue
    return newValue
end

renamedSettingsV2 = {
	["old1"] = "new1",
	["old2"] = "new2"
}
```

### :RenameSettingsAndInvert()

Changes the names of a list of boolean settings and inverts them in all saved vars tracked by this data instance of a given scope when upgrading to the given version number.  Has no effect on saved vars at or above the given version.

- *version* `number`: Settings are only upgraded on saved vars below this version number.
- *scope* `string` (optional): `LIBSAVEDVARS_SCOPE_CHARACTER`, `LIBSAVEDVARS_SCOPE_ACCOUNT` or `*`. Defaults to `*`.
- *renameMap* `table`: A key-value table containing a mapping of old setting names (keys) to new setting names (values).

```lua
local renamedSettingsV2

addon.settings = LibSavedVars:NewAccountWide("MyAddon_Data", "Account", MyAddon.defaults)
                             :RenameSettingsAndInvert(2, renamedSettingsV2)
renamedSettingsV2 = {
	["isNotSomething1"] = "isSomething1",
	["isNotSomething2"] = "isSomething2"
}
```



## Defaults Trimming

You can also chain the method `:EnableDefaultsTrimming()` with the saved vars constructor in order to remove all default values from the saved vars upon player logout, right before the data is saved to disk.

This can make the resulting file a lot smaller on disk, load and save faster, as well as become a lot more readable during manual edits, assuming users leave most settings at their default values.

Note, this feature uses a *copy* of the defaults values at the time they are passed to `LibSavedVars:NewAccountWide( "MyAddon_Data", "Account", MyAddon.defaults )` or `LibSavedVars:NewCharacterSettings( "MyAddon_Data", "Characters", MyAddon.defaults )`.  Programmatically altering the contents of the defaults table parameters after those calls will have no affect on the defaults trimming feature, since it will be using a separate defaults table copy.



## Saved Variable Reading and Writing

Reading and writing values should work just like normal `ZO_SavedVar` instances.  The following examples assume your saved vars data object is accessible via addon.settings.

### Reading a saved var value:

```lua
local setting1 = addon.settings.setting1
-- OR --
local setting1 = addon.settings["setting1"]
```

### Writing a saved var value:

```lua
addon.settings.setting1 = value
-- OR ---
addon.settings["setting1"] = value
```



## Saved Variable Looping

Just like normal `ZO_SavedVars` instance, `LibSavedVars` creates a proxy class (`LSV_Data`) that cannot be directly iterated with `pairs()`.

The following examples assume your saved vars data object is accessible via addon.settings...

### With pairs()

An additional key called `__dataSource` is included as the last key with pairs() and next() iterations.  This allows you to access the internal dataSource property in Zgoo, but it is something to keep in mind when looping.

```lua
for key, value in pairs(addon.settings) do
    if key ~= "__dataSource" then
        -- do something
        d("key: "..tostring(key)..", value: "..tostring(value))
    end
end
```

If you don't want to worry about `__dataSource`, you can loop the raw saved vars table directly:

```lua
local savedVars = addon.settings:GetActiveSavedVars()
local rawSavedVars = LibSavedVars:GetRawDataTable(savedVars)
for key, value in pairs(rawSavedVars) do
    -- do something
    d("key: "..tostring(key)..", value: "..tostring(value))
end
```

### With next()

```lua
local key, value = next(addon.settings, nil)
while key ~= "__dataSource" then
    -- do something
    d("key: "..tostring(key)..", value: "..tostring(value))
    key, value = next(addon.settings, key)
end
```

or

```lua
local savedVars = addon.settings:GetActiveSavedVars()
local rawSavedVars = LibSavedVars:GetRawDataTable(savedVars)
local key, value = next(rawSavedVars, nil)
repeat
    -- do something
    d("key: "..tostring(key)..", value: "..tostring(value))
    key, value = next(rawSavedVars, key)
until key == nil
```

### With ipairs()

Since the only additional keys that the `LSV_Data` and `ZO_SavedVars` proxies add to loops are non-numeric, so they don't affect `ipairs()` at all.

```lua
for index, value in ipairs(addon.settings) do
    -- do something
    d("index: "..tostring(index)..", value: "..tostring(value))
end
```

### With a numeric range

Note the use of `addon.settings:GetLength()` instead of `#addon.settings`.  The `#` operator is not supported, because it cannot be overloaded on tables in Lua 5.1, which is what ESO uses.

```lua
for index, 1, addon.settings:GetLength() do
    -- do something
    d("index: "..tostring(index)..", value: "..tostring(value))
end
```

or

```lua
local savedVars = addon.settings:GetActiveSavedVars()
local rawSavedVars = LibSavedVars:GetRawDataTable(savedVars)
for index, 1, #rawSavedVars do
    -- do something
    d("index: "..tostring(index)..", value: "..tostring(value))
end
```



## LibAddonMenu-2 Integration

LibSavedVars has a helper method to create the "Account-wide Settings" checkbox in your LibAddonMenu-2 panel, localized for English, French, German, Japanese and Russian.

The following example assumes your saved vars data object is accessible via `addon.settings`...

```lua
-- Setup options panel
local panelData = {
    type = "panel",
    name = addon.title,
    displayName = addon.title,
    author = addon.author,
    version = addon.version,
    slashCommand = "/myaddon",
    registerForRefresh = true,
    registerForDefaults = true,
}
LibAddonMenu2:RegisterAddonPanel(addon.name .. "Options", panelData)

local optionsTable = { 

    -- Account-wide settings
    addon.settings:GetLibAddonMenuAccountCheckbox(),
    
    -- other LAM2 setting options....
}

LibAddonMenu2:RegisterOptionControls(addon.name .. "Options", optionsTable)
```