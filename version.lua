-- Villageworks Version Information
local Version = {
    major = 0,
    minor = 1,
    patch = 4,
    releaseDate = "2025-03-24"
}

-- Get a formatted version string
function Version.getVersionString()
    return string.format("current version: v%d.%d.%d", Version.major, Version.minor, Version.patch)
end

-- Get a full version string with date
function Version.getFullVersionString()
    return Version.getVersionString() .. " (" .. Version.releaseDate .. ")"
end

return Version 