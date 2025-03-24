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
    
    -- World size selection state
    MainMenu.showWorldSizeMenu = false
    MainMenu.selectedWorldSize = "medium"  -- Default selection
    MainMenu.worldSizeScroll = 0  -- Scroll offset for size selection
    MainMenu.maxWorldSizeScroll = 0  -- Will be calculated dynamically
    
    -- World size options
    MainMenu.worldSizes = {
        small = {
            name = "Small World",
            width = 2000,
            height = 2000,
            description = "Smaller, more intimate world with villages closer together."
        },
        medium = {
            name = "Medium World",
            width = 3000,
            height = 3000,
            description = "Balanced world size with moderate distances between features."
        },
        large = {
            name = "Large World",
            width = 4500,
            height = 4500,
            description = "Expansive world with greater distances and more exploration."
        },
        huge = {
            name = "Huge World",
            width = 6000,
            height = 6000,
            description = "Vast terrain with long distances between settlements."
        }
    }
    
    -- Create ordered list of world sizes for easier iteration
    MainMenu.worldSizeOrder = {"small", "medium", "large", "huge"}
end

-- Draw the main menu
function MainMenu.draw()
    -- Draw the main background and menu
    MainMenu.drawBackground()
    
    -- If world size menu is showing, draw it on top
    if MainMenu.showWorldSizeMenu then
        MainMenu.drawWorldSizeMenu()
    else
        -- Draw the regular main menu options
        MainMenu.drawMainMenuOptions()
    end
end

-- Draw the background common to all menu screens
function MainMenu.drawBackground()
    local UI = MainMenu.UI
    
    -- Load and draw background image
    if not UI.backgroundImage then
        UI.backgroundImage = love.graphics.newImage("data/background.png")
    end
    
    -- Draw the background image scaled to fill the screen
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
    
    -- Draw tagline with glow effect
    love.graphics.setFont(UI.bigFont)  -- Larger font for tagline
    local tagline = "Create and manage a network of thriving settlements."
    local taglineWidth = UI.bigFont:getWidth(tagline)
    
    -- Draw outer glow
    local glowColor = {0.4, 0.7, 1.0}
    local pulseIntensity = math.abs(math.sin(love.timer.getTime() * 0.5)) * 0.3
    
    for i = 3, 1, -1 do
        local alpha = (pulseIntensity / i) * 0.2
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], alpha)
        love.graphics.print(tagline, (screenWidth - taglineWidth) / 2 - i, 140 - i)
        love.graphics.print(tagline, (screenWidth - taglineWidth) / 2 + i, 140 - i)
        love.graphics.print(tagline, (screenWidth - taglineWidth) / 2 - i, 140 + i)
        love.graphics.print(tagline, (screenWidth - taglineWidth) / 2 + i, 140 + i)
    end
    
    -- Draw main tagline text
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    love.graphics.print(tagline, (screenWidth - taglineWidth) / 2, 140)
    
    -- Draw version information at the bottom of the screen
    local Version = require("version")
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(UI.smallFont)
    local versionString = Version.getFullVersionString()
    love.graphics.print(versionString, 10, screenHeight - 20)
end

-- Draw just the main menu buttons
function MainMenu.drawMainMenuOptions()
    local UI = MainMenu.UI
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
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
end

-- Draw the world size selection menu
function MainMenu.drawWorldSizeMenu()
    local UI = MainMenu.UI
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Draw a semi-transparent overlay for the entire screen
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Menu dimensions - adjusted for smaller screens
    local menuWidth = math.min(500, screenWidth - 40)
    local menuHeight = math.min(400, screenHeight - 80)
    local menuX = (screenWidth - menuWidth) / 2
    local menuY = (screenHeight - menuHeight) / 2
    local cornerRadius = 10
    
    -- Draw menu background
    love.graphics.setColor(0.1, 0.15, 0.2, 0.95)
    love.graphics.rectangle("fill", menuX, menuY, menuWidth, menuHeight, cornerRadius, cornerRadius)
    
    -- Draw border
    love.graphics.setColor(0.5, 0.7, 0.9, 0.8)
    love.graphics.rectangle("line", menuX, menuY, menuWidth, menuHeight, cornerRadius, cornerRadius)
    
    -- Draw menu title
    love.graphics.setFont(UI.bigFont)
    love.graphics.setColor(1, 1, 1)
    local titleText = "Select World Size"
    local titleWidth = UI.bigFont:getWidth(titleText)
    love.graphics.print(titleText, menuX + (menuWidth - titleWidth) / 2, menuY + 15)
    
    -- Draw close button
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.rectangle("fill", menuX + menuWidth - 30, menuY + 10, 20, 20, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("×", menuX + menuWidth - 25, menuY + 8)
    
    -- Size option buttons
    local buttonHeight = 80
    local buttonSpacing = 10
    local buttonWidth = menuWidth - 40
    local contentHeight = #MainMenu.worldSizeOrder * (buttonHeight + buttonSpacing) - buttonSpacing
    
    -- Calculate the scroll area boundaries
    local scrollAreaY = menuY + 60
    local scrollAreaHeight = menuHeight - 120 -- Space for title and bottom button
    
    -- Adjust max scroll based on content height
    MainMenu.maxWorldSizeScroll = math.max(0, contentHeight - scrollAreaHeight)
    
    -- Ensure scroll is within bounds
    MainMenu.worldSizeScroll = math.max(0, math.min(MainMenu.worldSizeScroll, MainMenu.maxWorldSizeScroll))
    
    -- Create a stencil to mask content outside the scroll area
    love.graphics.stencil(function()
        love.graphics.rectangle("fill", menuX, scrollAreaY, menuWidth, scrollAreaHeight)
    end, "replace", 1)
    
    love.graphics.setStencilTest("greater", 0)
    
    -- Draw the size options with scrolling
    for i, sizeKey in ipairs(MainMenu.worldSizeOrder) do
        local sizeInfo = MainMenu.worldSizes[sizeKey]
        local buttonY = scrollAreaY + (i-1) * (buttonHeight + buttonSpacing) - MainMenu.worldSizeScroll
        
        -- Only draw if button would be visible in the scroll area
        if buttonY + buttonHeight >= scrollAreaY and buttonY <= scrollAreaY + scrollAreaHeight then
            local isSelected = MainMenu.selectedWorldSize == sizeKey
            local isHovered = MainMenu.hoveredButton == "size_" .. sizeKey
            
            -- Button background
            if isSelected then
                love.graphics.setColor(0.3, 0.5, 0.7, 0.8)
            elseif isHovered then
                love.graphics.setColor(0.25, 0.35, 0.45, 0.8)
            else
                love.graphics.setColor(0.2, 0.3, 0.4, 0.7)
            end
            love.graphics.rectangle("fill", menuX + 20, buttonY, buttonWidth, buttonHeight, 6, 6)
            
            -- Button border
            if isSelected then
                love.graphics.setColor(0.6, 0.8, 1)
                love.graphics.setLineWidth(2)
            else
                love.graphics.setColor(0.4, 0.6, 0.8)
                love.graphics.setLineWidth(1)
            end
            love.graphics.rectangle("line", menuX + 20, buttonY, buttonWidth, buttonHeight, 6, 6)
            love.graphics.setLineWidth(1)
            
            -- Size name
            love.graphics.setFont(UI.font)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(sizeInfo.name, menuX + 35, buttonY + 10)
            
            -- Size dimensions
            love.graphics.setFont(UI.smallFont)
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print(sizeInfo.width .. "x" .. sizeInfo.height .. " pixels", menuX + 35, buttonY + 32)
            
            -- Size description
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print(sizeInfo.description, menuX + 35, buttonY + 48)
            
            -- Selection indicator
            if isSelected then
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle("fill", menuX + 30, buttonY + 17, 4)
            end
        end
    end
    
    -- Disable stencil test after drawing scrollable content
    love.graphics.setStencilTest()
    
    -- Draw scroll indicators if needed
    if MainMenu.maxWorldSizeScroll > 0 then
        -- Draw scroll indicator at top if not at beginning
        if MainMenu.worldSizeScroll > 0 then
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.polygon("fill", 
                menuX + menuWidth / 2 - 10, scrollAreaY + 15,
                menuX + menuWidth / 2 + 10, scrollAreaY + 15,
                menuX + menuWidth / 2, scrollAreaY + 5
            )
        end
        
        -- Draw scroll indicator at bottom if not at end
        if MainMenu.worldSizeScroll < MainMenu.maxWorldSizeScroll then
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.polygon("fill", 
                menuX + menuWidth / 2 - 10, scrollAreaY + scrollAreaHeight - 15,
                menuX + menuWidth / 2 + 10, scrollAreaY + scrollAreaHeight - 15,
                menuX + menuWidth / 2, scrollAreaY + scrollAreaHeight - 5
            )
        end
        
        -- Draw scrollbar on the right
        local scrollbarHeight = (scrollAreaHeight / contentHeight) * scrollAreaHeight
        local scrollbarY = scrollAreaY + (MainMenu.worldSizeScroll / MainMenu.maxWorldSizeScroll) * (scrollAreaHeight - scrollbarHeight)
        
        love.graphics.setColor(0.3, 0.4, 0.5, 0.5)
        love.graphics.rectangle("fill", menuX + menuWidth - 10, scrollAreaY, 5, scrollAreaHeight, 2, 2)
        
        love.graphics.setColor(0.5, 0.7, 0.9, 0.8)
        love.graphics.rectangle("fill", menuX + menuWidth - 10, scrollbarY, 5, scrollbarHeight, 2, 2)
    end
    
    -- Main start button at bottom
    local startButtonY = menuY + menuHeight - 50
    local isStartHovered = MainMenu.hoveredButton == "start_game"
    
    if isStartHovered then
        love.graphics.setColor(0.3, 0.7, 0.4, 0.9)
    else
        love.graphics.setColor(0.2, 0.6, 0.3, 0.8)
    end
    love.graphics.rectangle("fill", menuX + 150, startButtonY, menuWidth - 300, 40, 8, 8)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.bigFont)
    local startText = "Start Game"
    local startWidth = UI.bigFont:getWidth(startText)
    love.graphics.print(startText, menuX + (menuWidth - startWidth) / 2, startButtonY + 8)
end

-- Update menu state
function MainMenu.update(dt)
    local UI = MainMenu.UI
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Reset hover state
    MainMenu.hoveredButton = nil
    
    -- If world size menu is showing, handle its hover states
    if MainMenu.showWorldSizeMenu then
        return MainMenu.updateWorldSizeMenu(mouseX, mouseY)
    end
    
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

-- Update world size menu hover states
function MainMenu.updateWorldSizeMenu(mouseX, mouseY)
    local UI = MainMenu.UI
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Menu dimensions - adjusted for smaller screens
    local menuWidth = math.min(500, screenWidth - 40)
    local menuHeight = math.min(400, screenHeight - 80)
    local menuX = (screenWidth - menuWidth) / 2
    local menuY = (screenHeight - menuHeight) / 2
    
    -- Scroll area boundaries
    local scrollAreaY = menuY + 60
    local scrollAreaHeight = menuHeight - 120
    
    -- Check for mouse wheel scrolling
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        
        -- Check if mouse is inside scroll area
        if mx >= menuX and mx <= menuX + menuWidth and
           my >= scrollAreaY and my <= scrollAreaY + scrollAreaHeight then
            
            -- Check if mouse is over the scrollbar
            if mx >= menuX + menuWidth - 15 and mx <= menuX + menuWidth - 5 then
                -- Calculate scroll position based on mouse position
                local scrollRatio = (my - scrollAreaY) / scrollAreaHeight
                MainMenu.worldSizeScroll = math.max(0, math.min(MainMenu.maxWorldSizeScroll, 
                                                    scrollRatio * MainMenu.maxWorldSizeScroll))
            end
        end
    end
    
    -- Size option buttons
    local buttonHeight = 80
    local buttonSpacing = 10
    local buttonWidth = menuWidth - 40
    
    -- Check for hover over size buttons in the scroll area
    for i, sizeKey in ipairs(MainMenu.worldSizeOrder) do
        local buttonY = scrollAreaY + (i-1) * (buttonHeight + buttonSpacing) - MainMenu.worldSizeScroll
        
        -- Only check if button would be visible in the scroll area
        if buttonY + buttonHeight >= scrollAreaY and buttonY <= scrollAreaY + scrollAreaHeight then
            if mouseX >= menuX + 20 and mouseX <= menuX + 20 + buttonWidth and
               mouseY >= buttonY and mouseY <= buttonY + buttonHeight and
               mouseY >= scrollAreaY and mouseY <= scrollAreaY + scrollAreaHeight then
                -- Hover over size option
                MainMenu.hoveredButton = "size_" .. sizeKey
                return
            end
        end
    end
    
    -- Check for main start button hover
    local startButtonY = menuY + menuHeight - 50
    if mouseX >= menuX + 150 and mouseX <= menuX + menuWidth - 150 and
       mouseY >= startButtonY and mouseY <= startButtonY + 40 then
        MainMenu.hoveredButton = "start_game"
        return
    end
    
    -- Check for close button hover
    if mouseX >= menuX + menuWidth - 30 and mouseX <= menuX + menuWidth - 10 and
       mouseY >= menuY + 10 and mouseY <= menuY + 30 then
        MainMenu.hoveredButton = "close"
        return
    end
    
    MainMenu.hoveredButton = nil
end

-- Handle main menu clicks
function MainMenu.handleClick(game, x, y, Documentation, SaveLoad)
    local UI = MainMenu.UI
    
    -- If world size selection is showing, handle those clicks
    if MainMenu.showWorldSizeMenu then
        return MainMenu.handleWorldSizeClick(game, x, y)
    end
    
    -- Check if documentation popup is showing and handle its clicks first
    if Documentation.showPopup then
        return Documentation.handleClick(x, y)
    end
    
    -- Handle menu option clicks
    local menuWidth = 300
    local buttonHeight = 60  -- Updated to match the new button height
    local buttonSpacing = 20
    local menuX = (love.graphics.getWidth() - menuWidth) / 2
    local startY = love.graphics.getHeight() / 2 - 50  -- Updated to match drawMainMenu
    
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
                -- Show world size selection instead of immediately starting the game
                MainMenu.showWorldSizeMenu = true
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

-- Handle world size selection menu clicks
function MainMenu.handleWorldSizeClick(game, x, y)
    local UI = MainMenu.UI
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Menu dimensions - adjusted for smaller screens
    local menuWidth = math.min(500, screenWidth - 40)
    local menuHeight = math.min(400, screenHeight - 80)
    local menuX = (screenWidth - menuWidth) / 2
    local menuY = (screenHeight - menuHeight) / 2
    
    -- Check if clicking outside the menu (cancel)
    if x < menuX or x > menuX + menuWidth or y < menuY or y > menuY + menuHeight then
        MainMenu.showWorldSizeMenu = false
        return true
    end
    
    -- Check for close button click
    if x >= menuX + menuWidth - 30 and x <= menuX + menuWidth - 10 and
       y >= menuY + 10 and y <= menuY + 30 then
        MainMenu.showWorldSizeMenu = false
        return true
    end
    
    -- Scroll area boundaries
    local scrollAreaY = menuY + 60
    local scrollAreaHeight = menuHeight - 120
    
    -- Size option buttons
    local buttonHeight = 80
    local buttonSpacing = 10
    local buttonWidth = menuWidth - 40
    
    -- Handle scroll up/down arrows if clicked
    if x >= menuX + menuWidth - 15 and x <= menuX + menuWidth - 5 then
        -- Click on scrollbar area
        if y >= scrollAreaY and y <= scrollAreaY + scrollAreaHeight then
            local scrollRatio = (y - scrollAreaY) / scrollAreaHeight
            MainMenu.worldSizeScroll = math.max(0, math.min(MainMenu.maxWorldSizeScroll, 
                                             scrollRatio * MainMenu.maxWorldSizeScroll))
            return true
        end
    end
    
    -- Check clicks on the buttons within the scroll area
    for i, sizeKey in ipairs(MainMenu.worldSizeOrder) do
        local buttonY = scrollAreaY + (i-1) * (buttonHeight + buttonSpacing) - MainMenu.worldSizeScroll
        
        -- Only check if button would be visible in the scroll area
        if buttonY + buttonHeight >= scrollAreaY and buttonY <= scrollAreaY + scrollAreaHeight then
            if x >= menuX + 20 and x <= menuX + 20 + buttonWidth and
               y >= buttonY and y <= buttonY + buttonHeight and
               y >= scrollAreaY and y <= scrollAreaY + scrollAreaHeight then
                -- Select this world size
                MainMenu.selectedWorldSize = sizeKey
                
                -- Check if clicking the Start button (positioned at the bottom of each size button)
                if y >= buttonY + buttonHeight - 30 and y <= buttonY + buttonHeight - 5 and
                   x >= menuX + buttonWidth - 50 and x <= menuX + buttonWidth + 10 then
                    -- Start the game with selected world size
                    MainMenu.startGameWithSelectedSize(game)
                end
                
                return true
            end
        end
    end
    
    -- Check for main start button at bottom
    local startButtonY = menuY + menuHeight - 50
    if x >= menuX + 150 and x <= menuX + menuWidth - 150 and
       y >= startButtonY and y <= startButtonY + 40 then
        -- Start the game with selected world size
        MainMenu.startGameWithSelectedSize(game)
        return true
    end
    
    return true
end

-- Start the game with the currently selected world size
function MainMenu.startGameWithSelectedSize(game)
    local worldSize = MainMenu.worldSizes[MainMenu.selectedWorldSize]
    
    -- Update game config with selected world size
    local Config = require("config")
    Config.WORLD_WIDTH = worldSize.width
    Config.WORLD_HEIGHT = worldSize.height
    
    -- Hide menus and start the game
    MainMenu.showWorldSizeMenu = false
    MainMenu.UI.showMainMenu = false
    MainMenu.UI.gameRunning = true
    game:reset() -- Reset game state for a new game
end

-- Handle mouse wheel events for world size selection scrolling
function MainMenu.wheelmoved(x, y)
    if MainMenu.showWorldSizeMenu then
        -- Scroll amount depends on wheel movement
        local scrollAmount = y * 20  -- Adjust the multiplier for scroll speed
        MainMenu.worldSizeScroll = math.max(0, math.min(MainMenu.maxWorldSizeScroll, 
                                            MainMenu.worldSizeScroll - scrollAmount))
        return true
    end
    
    return false
end

-- Handle keyboard input for the main menu
function MainMenu.keypressed(key, SaveLoad)
    -- If world size menu is showing
    if MainMenu.showWorldSizeMenu then
        if key == "escape" then
            MainMenu.showWorldSizeMenu = false
            return true
        end
    end
    
    -- If load game dialog is showing
    if SaveLoad and SaveLoad.showLoadDialog then
        if key == "escape" then
            SaveLoad.showLoadDialog = false
            return true
        end
    end
    
    return false
end

return MainMenu 