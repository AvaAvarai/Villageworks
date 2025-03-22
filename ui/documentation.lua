local Documentation = {}

-- Helper function to load markdown documents
local function loadDocumentFile(path, defaultMessage)
    local success, content = pcall(function()
        local file = io.open(path, "r")
        if file then
            local content = file:read("*all")
            file:close()
            return content
        end
        return defaultMessage
    end)
    
    if success then
        return content
    else
        return "Error loading document: " .. content
    end
end

-- Initialize documentation system
function Documentation.init(UI)
    Documentation.UI = UI -- Store reference to main UI module
    Documentation.showPopup = false
    Documentation.popupType = nil
    Documentation.popupScroll = 0
    
    -- Load documentation content
    Documentation.docs = {
        howToPlay = loadDocumentFile("docs/GAME_GUIDE.md", "Game guide not found."),
        about = loadDocumentFile("docs/ABOUT.md", "About document not found."),
        changelog = loadDocumentFile("docs/CHANGELOG.md", "Changelog not found.")
    }
end

-- Show documentation popup
function Documentation.show(popupType)
    Documentation.showPopup = true
    Documentation.popupType = popupType
    Documentation.popupScroll = 0
end

-- Draw the documentation popup
function Documentation.drawPopup()
    local UI = Documentation.UI
    local width = love.graphics.getWidth() * 0.8
    local height = love.graphics.getHeight() * 0.8
    local x = (love.graphics.getWidth() - width) / 2
    local y = (love.graphics.getHeight() - height) / 2
    local cornerRadius = 10  -- Radius for rounded corners
    
    -- Draw popup background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", x, y, width, height, cornerRadius, cornerRadius)
    love.graphics.setColor(0.5, 0.5, 0.7, 1)
    love.graphics.rectangle("line", x, y, width, height, cornerRadius, cornerRadius)
    
    -- Draw title based on popup type
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.titleFont)
    
    local title = ""
    local content = ""
    
    if Documentation.popupType == "howToPlay" then
        title = "How to Play"
        content = Documentation.docs.howToPlay
    elseif Documentation.popupType == "about" then
        title = "About"
        content = Documentation.docs.about
    elseif Documentation.popupType == "changelog" then
        title = "Changelog"
        content = Documentation.docs.changelog
    end
    
    love.graphics.print(title, x + 20, y + 20)
    
    -- Draw close button
    love.graphics.setColor(0.7, 0.3, 0.3)
    love.graphics.rectangle("fill", x + width - 40, y + 20, 25, 25, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.font)
    love.graphics.print("X", x + width - 33, y + 25)
    
    -- Create a stencil for content area
    local contentX = x + 20
    local contentY = y + 70
    local contentWidth = width - 40
    local contentHeight = height - 100
    
    -- Draw scrollable content
    love.graphics.stencil(function()
        love.graphics.rectangle("fill", contentX, contentY, contentWidth, contentHeight)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(UI.font)
    
    -- Parse and render Markdown-like content
    local lineHeight = 20
    local textY = contentY - Documentation.popupScroll
    local lines = {}
    
    -- Split the content into lines
    for line in string.gmatch(content, "[^\r\n]+") do
        table.insert(lines, line)
    end
    
    -- Calculate content height for accurate scrolling
    local totalHeight = 0
    for i, line in ipairs(lines) do
        if line:match("^#%s+") then
            totalHeight = totalHeight + 30
        elseif line:match("^##%s+") then
            totalHeight = totalHeight + 25
        elseif line:match("^###%s+") then
            totalHeight = totalHeight + 20
        elseif line ~= "" then
            totalHeight = totalHeight + lineHeight
        else
            totalHeight = totalHeight + 10 -- Empty line spacing
        end
    end
    
    -- Render the visible content
    for i, line in ipairs(lines) do
        -- Only render if the line would be visible
        if textY + 30 >= contentY and textY <= contentY + contentHeight then
            -- Handle headers
            if line:match("^#%s+") then
                love.graphics.setFont(UI.bigFont)
                love.graphics.setColor(0.8, 0.8, 1)
                love.graphics.print(line:gsub("^#%s+", ""), contentX, textY)
                textY = textY + 30
            elseif line:match("^##%s+") then
                love.graphics.setFont(UI.bigFont)
                love.graphics.setColor(0.7, 0.9, 1)
                love.graphics.print(line:gsub("^##%s+", ""), contentX + 10, textY)
                textY = textY + 25
            elseif line:match("^###%s+") then
                love.graphics.setFont(UI.font)
                love.graphics.setColor(0.8, 1, 0.8)
                love.graphics.print(line:gsub("^###%s+", ""), contentX + 20, textY)
                textY = textY + 20
            -- Handle bullet points
            elseif line:match("^%-%s+") or line:match("^%*%s+") then
                love.graphics.setFont(UI.font)
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.print("• " .. line:gsub("^[%-%*]%s+", ""), contentX + 20, textY)
                textY = textY + lineHeight
            -- Handle numbered lists
            elseif line:match("^%d+%.%s+") then
                love.graphics.setFont(UI.font)
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.print(line, contentX + 20, textY)
                textY = textY + lineHeight
            -- Regular text
            elseif line ~= "" then
                love.graphics.setFont(UI.font)
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.print(line, contentX, textY)
                textY = textY + lineHeight
            else
                textY = textY + 10 -- Empty line spacing
            end
        else
            -- Skip rendering but update textY appropriately
            if line:match("^#%s+") then
                textY = textY + 30
            elseif line:match("^##%s+") then
                textY = textY + 25
            elseif line:match("^###%s+") then
                textY = textY + 20
            elseif line ~= "" then
                textY = textY + lineHeight
            else
                textY = textY + 10 -- Empty line spacing
            end
        end
    end
    
    -- Reset stencil
    love.graphics.setStencilTest()
    
    -- Draw scroll indicators if needed
    local maxScroll = math.max(0, totalHeight - contentHeight)
    if totalHeight > contentHeight then
        -- Calculate scroll bar parameters
        local scrollBarWidth = 10
        local scrollBarHeight = math.max(30, contentHeight * (contentHeight / totalHeight))
        local scrollBarX = x + width - 15
        local scrollBarY = contentY
        
        if maxScroll > 0 then
            scrollBarY = contentY + (Documentation.popupScroll / maxScroll) * (contentHeight - scrollBarHeight)
        end
        
        -- Draw scroll bar background
        love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
        love.graphics.rectangle("fill", scrollBarX, contentY, scrollBarWidth, contentHeight)
        
        -- Draw scroll bar handle
        love.graphics.setColor(0.6, 0.6, 0.6, 1)
        love.graphics.rectangle("fill", scrollBarX, scrollBarY, scrollBarWidth, scrollBarHeight)
        
        -- Draw scroll indicators with clearer highlighting
        if Documentation.popupScroll > 0 then
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.rectangle("fill", scrollBarX - 20, contentY, 15, 20)
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.print("▲", scrollBarX - 18, contentY)
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
            love.graphics.print("▲", scrollBarX - 18, contentY)
        end
        
        if Documentation.popupScroll < maxScroll then
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.rectangle("fill", scrollBarX - 20, contentY + contentHeight - 20, 15, 20)
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.print("▼", scrollBarX - 18, contentY + contentHeight - 20)
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
            love.graphics.print("▼", scrollBarX - 18, contentY + contentHeight - 20)
        end
        
        -- Draw scroll help text
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.setFont(UI.smallFont)
        love.graphics.print("Use mouse wheel or up/down keys to scroll", x + width / 2 - 100, y + height - 30)
    end
end

-- Handle mouse press events for the documentation popup
function Documentation.handleClick(x, y)
    if not Documentation.showPopup then
        return false
    end
    
    local width = love.graphics.getWidth() * 0.8
    local height = love.graphics.getHeight() * 0.8
    local popupX = (love.graphics.getWidth() - width) / 2
    local popupY = (love.graphics.getHeight() - height) / 2
    
    -- Check if clicking close button
    if x >= popupX + width - 40 and x <= popupX + width - 15 and
       y >= popupY + 20 and y <= popupY + 45 then
        Documentation.showPopup = false
        Documentation.popupType = nil
        return true
    end
    
    -- Check if clicking scroll up button
    local contentY = popupY + 70
    if x >= popupX + width - 25 and x <= popupX + width - 15 and
       y >= contentY and y <= contentY + 20 then
        Documentation.scroll(-30) -- Scroll up
        return true
    end
    
    -- Check if clicking scroll down button
    local contentHeight = height - 100
    if x >= popupX + width - 25 and x <= popupX + width - 15 and
       y >= contentY + contentHeight - 20 and y <= contentY + contentHeight then
        Documentation.scroll(30) -- Scroll down
        return true
    end
    
    -- Check if clicking inside the content area (for future interactions)
    if x >= popupX and x <= popupX + width and
       y >= popupY and y <= popupY + height then
        return true -- Capture the click
    end
    
    return false
end

-- Handle mouse wheel events for scrolling
function Documentation.wheelmoved(x, y)
    if Documentation.showPopup then
        -- Scroll amount based on wheel movement (y is positive for up, negative for down)
        Documentation.scroll(-y * 30) -- Multiply by a factor for smoother scrolling
        return true
    end
    return false
end

-- Handle keypresses for scrolling
function Documentation.keypressed(key)
    if not Documentation.showPopup then
        return false
    end
    
    if key == "up" or key == "pageup" then
        Documentation.scroll(-30) -- Scroll up (or larger amount for page up)
        return true
    elseif key == "down" or key == "pagedown" then
        Documentation.scroll(30) -- Scroll down (or larger amount for page down)
        return true
    elseif key == "home" then
        -- Scroll to the top
        Documentation.popupScroll = 0
        return true
    elseif key == "end" then
        -- Scroll to the bottom (will be capped in the scroll function)
        Documentation.scroll(10000) -- Use a large value that will be capped
        return true
    elseif key == "escape" then
        Documentation.showPopup = false
        Documentation.popupType = nil
        return true
    end
    
    return false
end

-- Helper function to scroll with bounds checking
function Documentation.scroll(amount)
    -- Get content to measure its height
    local content = ""
    if Documentation.popupType == "howToPlay" then
        content = Documentation.docs.howToPlay
    elseif Documentation.popupType == "about" then
        content = Documentation.docs.about
    elseif Documentation.popupType == "changelog" then
        content = Documentation.docs.changelog
    end
    
    -- Calculate content height
    local lineHeight = 20
    local totalHeight = 0
    
    for line in string.gmatch(content, "[^\r\n]+") do
        if line:match("^#%s+") then
            totalHeight = totalHeight + 30
        elseif line:match("^##%s+") then
            totalHeight = totalHeight + 25
        elseif line:match("^###%s+") then
            totalHeight = totalHeight + 20
        elseif line ~= "" then
            totalHeight = totalHeight + lineHeight
        else
            totalHeight = totalHeight + 10 -- Empty line spacing
        end
    end
    
    -- Calculate max scroll based on content and container size
    local width = love.graphics.getWidth() * 0.8
    local height = love.graphics.getHeight() * 0.8
    local contentHeight = height - 100
    local maxScroll = math.max(0, totalHeight - contentHeight)
    
    -- Update scroll with bounds checking
    Documentation.popupScroll = math.max(0, math.min(maxScroll, Documentation.popupScroll + amount))
    
    return true -- Indicate the scroll event was handled
end

return Documentation 