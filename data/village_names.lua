-- List of historical village and settlement names from various cultures
local VillageNames = {
    -- European medieval villages
    "Ashford", "Blackwood", "Bridgewater", "Cresthill", "Dalebrook", 
    "Elmsworth", "Fairhaven", "Greenfield", "Highgarden", "Ironforge",
    "Kingsport", "Lakeshire", "Millfield", "Northshire", "Oakvale",
    "Pinewatch", "Queensbury", "Ravenhill", "Silverbrook", "Thornhill",
    
    -- Ancient settlements
    "Antioch", "Byzantium", "Carthage", "Delphi", "Ephesus",
    "Thebes", "Memphis", "Nineveh", "Persepolis", "Tyre",
    "Ur", "Varanasi", "Alexandria", "Jericho", "Troy",
    
    -- Asian villages
    "Edo", "Heian", "Kyoto", "Nara", "Osaka",
    "Beijing", "Chang'an", "Kunlun", "Luoyang", "Wuxi",
    "Anyang", "Busan", "Hanseong", "Gyeongju", "Suwon",
    
    -- Middle Eastern settlements
    "Aden", "Basra", "Damascus", "Esfahan", "Fez",
    "Giza", "Hama", "Isfahan", "Jerusalem", "Kashan",
    "Luxor", "Marrakesh", "Nicosia", "Petra", "Qom",
    
    -- Native American settlements
    "Cahokia", "Hawikuh", "Oraibi", "Taos", "Tenochtitlan",
    "Tikal", "Tula", "Copan", "Chichen Itza", "Cuzco",
    
    -- Norse settlements
    "Birka", "Hedeby", "Kaupang", "Nidaros", "Roskilde",
    "Sigtuna", "Uppsala", "Jorvik", "Trondheim", "Visby",
    
    -- African settlements
    "Aksum", "Benin", "Cyrene", "Djenne", "Elmina",
    "Gao", "Harar", "Ife", "Jenne", "Kano",
    "Lalibela", "Meroe", "Niani", "Oyo", "Pemba",
    
    -- Celtic settlements
    "Alesia", "Bibracte", "Camulodunum", "Dumnonia", "Eburacum",
    "Gaul", "Hibernia", "Iceni", "Londinium", "Noviodonum"
}

-- Function to get a random village name
function VillageNames.getRandomName()
    return VillageNames[math.random(#VillageNames)]
end

-- Function to get a unique village name that hasn't been used yet
function VillageNames.getUniqueName(usedNames)
    usedNames = usedNames or {}
    
    -- If all names are used, start adding suffixes
    if #usedNames >= #VillageNames then
        local baseName = VillageNames[math.random(#VillageNames)]
        local suffix = math.random(100)
        return baseName .. " " .. suffix
    end
    
    -- Try to find an unused name
    local attempts = 0
    local name
    repeat
        name = VillageNames[math.random(#VillageNames)]
        attempts = attempts + 1
        
        -- If we've tried too many times, generate with suffix
        if attempts > 20 then
            name = name .. " " .. math.random(100)
            break
        end
    until not usedNames[name]
    
    return name
end

return VillageNames 