-- Villageworks Version Information
local Version = {
    major = 0,
    minor = 1,
    patch = 1,
    releaseDate = "2023-06-04"
}

-- Get a formatted version string
function Version.getVersionString()
    return string.format("v%d.%d.%d", Version.major, Version.minor, Version.patch)
end

-- Get a full version string with date
function Version.getFullVersionString()
    return Version.getVersionString() .. " (" .. Version.releaseDate .. ")"
end

return Version 