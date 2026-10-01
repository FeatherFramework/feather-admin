-- Server counterpart of the client Core-backed adapter (Inventory convention).
Feather = Feather or {}
Feather.Locale = {
    register = function(locale, translations)
        return exports['feather-core']:RegisterLocale(locale, translations)
    end,
    translate = function(source, key, ...)
        local result = exports['feather-core']:TranslateLocale(source, key, ...)
        return type(result) == 'table' and result.ok and result.value or nil
    end
}
function AdminServerTranslate(key)
    local ok, text = pcall(Feather.Locale.translate, 0, key)
    if not ok or type(text) ~= 'string' or text == ''
        or text:match('^Translation %[') or text:match('^Locale %[') then
        return AdminEnglishTranslations[key] or key
    end
    return text
end
