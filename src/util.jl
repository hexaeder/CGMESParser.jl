"""
    symbolify(s::String)

Turn a CGMES object name into a Symbol usable as a component name, replacing whitespace
with underscores.
"""
function symbolify(s::String)
    s = replace(s, r"\s" => "_")
    Symbol(s)
end

# Compact number formatting for warnings and tables.
str_significant(x; sigdigits=5) = string(round(x; sigdigits))
