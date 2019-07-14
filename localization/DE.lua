local strings = {
    ["SI_LSV_ACCOUNT_WIDE"]    = "Accountweite Einstellungen",
    ["SI_LSV_ACCOUNT_WIDE_TT"] = "Alle Einstellungen sind für alle deine Charaktere identisch.",
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    LIBSAVEDVARS_STRINGS[stringId] = value
end