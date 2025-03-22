local MainMenu = {}

-- Initialize main menu
function MainMenu.init(UI)
    MainMenu.UI = UI
    
    -- Main menu state
    MainMenu.hoveredButton = nil
    
    -- Main menu options
    MainMenu.options = {
        "New Game",
        "Load Game",
        "Docs",
        "Exit"
    }
    
    -- Documentation submenu options
    MainMenu.docsOptions = {
        "How to Play",
        "About",
        "Changelog"
    }
end

-- Draw the main menu
function MainMenu.draw()
    local UI = MainMenu.UI
    
    -- Load and draw background image
    if not UI.backgroundImage then
        UI.backgroundImage = love.graphics.newImage("data/background.png")
    end
    
    -- Draw the background image scaled to fill the screen
    love.graphics.setColor(1, 1, 1, 1)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local imgWidth = UI.backgroundImage:getWidth()
    local imgHeight = UI.backgroundImage:getHeight()
    
    -- Calculate scale to ensure image covers the entire screen
    local scaleX = screenWidth / imgWidth
    local scaleY = screenHeight / imgHeight
    local scale = math.max(scaleX, scaleY)
    
    -- Calculate centered position
    local scaledWidth = imgWidth * scale
    local scaledHeight = imgHeight * scale
    local x = (screenWidth - scaledWidth) / 2
    local y = (screenHeight - scaledHeight) / 2
    
    love.graphics.draw(UI.backgroundImage, x, y, 0, scale, scale)
    
    -- Add a dark overlay for better text visibility (darkened at the top and bottom, lighter in the middle)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight / 3) -- Darker at top
    
    -- Center gradient section
    for i = 1, 10 do
        local alpha = 0.7 - (i / 15) -- Gradient from 0.7 to 0.03
        love.graphics.setColor(0, 0, 0, alpha)
        local height = screenHeight / 3 / 10
        love.graphics.rectangle("fill", 0, screenHeight / 3 + (i-1) * height, screenWidth, height)
    end
    
    -- Bottom section
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", 0, screenHeight * 2/3, screenWidth, screenHeight/3)
    
    -- Draw title with a dramatic glow effect
    love.graphics.setFont(UI.titleFont)
    local title = "Villageworks"
    local titleWidth = UI.titleFont:getWidth(title)
    
    -- Draw shadow for depth
    love.graphics.setColor(0.1, 0.2, 0.3, 0.8)
    love.graphics.print(title, (screenWidth - titleWidth) / 2 + 4, 78)
    
    -- Draw outer glow
    local glowColor = {0.4, 0.7, 1.0}
    local pulseIntensity = math.abs(math.sin(love.timer.getTime() * 0.5)) * 0.5
    
    for i = 5, 1, -1 do
        local alpha = (pulseIntensity / i) * 0.3
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], alpha)
        love.graphics.print(title, (screenWidth - titleWidth) / 2 - i, 80 - i)
        love.graphics.print(title, (screenWidth - titleWidth) / 2 + i, 80 - i)
        love.graphics.print(title, (screenWidth - titleWidth) / 2 - i, 80 + i)
        love.graphics.print(title, (screenWidth - titleWidth) / 2 + i, 80 + i)
    end
    
    -- Draw main title with a subtle gradient effect
    local r, g, b = 1, 1, 1
    love.graphics.setColor(r, g, b, 1)
    love.graphics.print(title, (screenWidth - titleWidth) / 2, 80)
    
    -- Draw tagline
    love.graphics.setFont(UI.bigFont)  -- Larger font for tagline
    local tagline = "Create and manage a network of thriving settlements."
    local taglineWidth = UI.bigFont:getWidth(tagline)
    love.graphics.setColor(0.9, 0.9, 0.9, 0.9)
    love.graphics.print(tagline, (screenWidth - taglineWidth) / 2, 140)
    
    -- Draw menu options
    local menuWidth = 300
    local buttonHeight = 60  -- Increased button height
    local buttonSpacing = 20
    local menuX = (screenWidth - menuWidth) / 2
    local startY = screenHeight / 2 - 50
    local cornerRadius = 10  -- Radius for rounded corners
    
    -- Use the fun font for menu buttons
    love.graphics.setFont(UI.menuFont)
    
    for i, option in ipairs(MainMenu.options) do
        local buttonY = startY + (i-1) * (buttonHeight + buttonSpacing)
        
        -- Special case for docs row
        if option == "Docs" then
            -- Draw three side-by-side buttons for documentation
            local smallButtonWidth = (menuWidth - 20) / 3
            
            for j, docOption in ipairs(MainMenu.docsOptions) do
                local docButtonX = menuX + (j-1) * (smallButtonWidth + 10)
                local isHovered = MainMenu.hoveredButton == "doc_" .. j
                
                -- Draw button background with hover effect
                if j == 1 then
                    -- How to Play
                    love.graphics.setColor(0.2, 0.4, 0.5)
                    if isHovered then love.graphics.setColor(0.3, 0.5, 0.7) end
                elseif j == 2 then
                    -- About
                    love.graphics.setColor(0.3, 0.3, 0.5)
                    if isHovered then love.graphics.setColor(0.4, 0.4, 0.7) end
                else
                    -- Changelog
                    love.graphics.setColor(0.4, 0.3, 0.4)
                    if isHovered then love.graphics.setColor(0.6, 0.4, 0.6) end
                end
                
                -- Draw rounded rectangle for button
                love.graphics.rectangle("fill", docButtonX, buttonY, smallButtonWidth, buttonHeight, cornerRadius, cornerRadius)
                
                -- Add a subtle glow on hover
                if isHovered then
                    -- Draw glow effect
                    love.graphics.setColor(0.6, 0.8, 1, 0.3)
                    love.graphics.rectangle("fill", docButtonX, buttonY, smallButtonWidth, buttonHeight, cornerRadius, cornerRadius)
                end
                
                -- Draw button border
                love.graphics.setColor(0.5, 0.7, 0.9)
                love.graphics.rectangle("line", docButtonX, buttonY, smallButtonWidth, buttonHeight, cornerRadius, cornerRadius)
                
                -- Draw button text
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(UI.font) -- Use smaller font for doc buttons
                local textWidth = UI.font:getWidth(docOption)
                
                -- Button text animation on hover
                local textY = buttonY + 20  -- Adjusted y position
                if isHovered then
                    textY = buttonY + 20 + math.sin(love.timer.getTime() * 5) * 2
                end
                
                love.graphics.print(docOption, docButtonX + (smallButtonWidth - textWidth) / 2, textY)
            end
            
            -- Reset font size for other buttons
            love.graphics.setFont(UI.menuFont)
        else
            -- Check if this button is hovered
            local isHovered = MainMenu.hoveredButton == option
            
            -- Draw regular button background with hover effects
            love.graphics.setColor(0.2, 0.3, 0.4)
            
            -- Change color on hover
            if isHovered then
                love.graphics.setColor(0.3, 0.4, 0.6)
            end
            
            -- Draw the button with rounded corners
            love.graphics.rectangle("fill", menuX, buttonY, menuWidth, buttonHeight, cornerRadius, cornerRadius)
            
            -- Add a subtle glow on hover
            if isHovered then
                -- Draw glow effect
                love.graphics.setColor(0.6, 0.8, 1, 0.3)
                love.graphics.rectangle("fill", menuX, buttonY, menuWidth, buttonHeight, cornerRadius, cornerRadius)
            end
            
            -- Draw button border with animation if hovered
            if isHovered then
                love.graphics.setColor(0.7, 0.9, 1)
                love.graphics.setLineWidth(2)
            else
                love.graphics.setColor(0.5, 0.7, 0.9)
                love.graphics.setLineWidth(1)
            end
            
            love.graphics.rectangle("line", menuX, buttonY, menuWidth, buttonHeight, cornerRadius, cornerRadius)
            love.graphics.setLineWidth(1)
            
            -- Draw button text
            love.graphics.setColor(1, 1, 1)
            local textWidth = UI.menuFont:getWidth(option)
            
            -- Button text animation on hover
            local textX = menuX + (menuWidth - textWidth) / 2
            local textY = buttonY + 15  -- Adjusted y position
            
            if isHovered then
                textY = buttonY + 15 + math.sin(love.timer.getTime() * 5) * 2
            end
            
            love.graphics.print(option, textX, textY)
        end
    end
    
    -- Draw version information at the bottom of the screen
    local Version = require("version")
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(UI.smallFont)
    local versionString = Version.getFullVersionString()
    love.graphics.print(versionString, 10, screenHeight - 20)
end

-- Update menu state
function MainMenu.update(dt)
    local UI = MainMenu.UI
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Reset hover state
    MainMenu.hoveredButton = nil
    
    local menuWidth = 300
    local buttonHeight = 60  -- Match the actual button height in draw
    local buttonSpacing = 20
    local menuX = (love.graphics.getWidth() - menuWidth) / 2
    local startY = love.graphics.getHeight() / 2 - 50  -- Match position in draw
    
    for i, option in ipairs(MainMenu.options) do
        local buttonY = startY + (i-1) * (buttonHeight + buttonSpacing)
        
        -- Special case for docs row
        if option == "Docs" then
            -- Check hover for documentation buttons
            local smallButtonWidth = (menuWidth - 20) / 3
            
            for j, docOption in ipairs(MainMenu.docsOptions) do
                local docButtonX = menuX + (j-1) * (smallButtonWidth + 10)
                
                if mouseX >= docButtonX and mouseX <= docButtonX + smallButtonWidth and
                   mouseY >= buttonY and mouseY <= buttonY + buttonHeight then
                    MainMenu.hoveredButton = "doc_" .. j
                    break
                end
            end
        elseif mouseX >= menuX and mouseX <= menuX + menuWidth and
               mouseY >= buttonY and mouseY <= buttonY + buttonHeight then
            MainMenu.hoveredButton = option
            break
        end
    end
end

-- Handle main menu clicks
function MainMenu.handleClick(game, x, y, Documentation, SaveLoad)
    -- Check if documentation popup is showing and handle its clicks first
    if Documentation.showPopup then
        return Documentation.handleClick(x, y)
    end
    
    -- Handle menu option clicks
    local menuWidth = 300
    local buttonHeight = 60
    local buttonSpacing = 20
    local menuX = (love.graphics.getWidth() - menuWidth) / 2
    local startY = love.graphics.getHeight() / 2 - 50
    
    for i, option in ipairs(MainMenu.options) do
        local buttonY = startY + (i-1) * (buttonHeight + buttonSpacing)
        
        -- Special case for docs buttons
        if option == "Docs" then
            -- Check clicks on the three documentation buttons
            local smallButtonWidth = (menuWidth - 20) / 3
            
            for j, docOption in ipairs(MainMenu.docsOptions) do
                local docButtonX = menuX + (j-1) * (smallButtonWidth + 10)
                
                if x >= docButtonX and x <= docButtonX + smallButtonWidth and
                   y >= buttonY and y <= buttonY + buttonHeight then
                    
                    -- Handle documentation option clicks
                    if docOption == "How to Play" then
                        Documentation.show("howToPlay")
                        return true
                    elseif docOption == "About" then
                        Documentation.show("about")
                        return true
                    elseif docOption == "Changelog" then
                        Documentation.show("changelog")
                        return true
                    end
                end
            end
        elseif x >= menuX and x <= menuX + menuWidth and
           y >= buttonY and y <= buttonY + buttonHeight then
            
            -- Handle option selection
            if option == "New Game" then
                MainMenu.UI.showMainMenu = false
                MainMenu.UI.gameRunning = true
                game:reset() -- Reset game state for a new game
                return true
            elseif option == "Load Game" then
                -- Show load dialog and refresh save slots
                SaveLoad.showLoadDialog = true
                SaveLoad.loadSaveFiles() -- Refresh list of saves
                SaveLoad.selectedSaveFile = nil
                SaveLoad.loadDialogScroll = 0 -- Reset scroll position
                return true
            elseif option == "Exit" then
                love.event.quit()
                return true
            end
        end
    end
    
    return true -- Capture all clicks in main menu
end

return MainMenu 