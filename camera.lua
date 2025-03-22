local Camera = {}
Camera.__index = Camera

function Camera.new()
    local camera = setmetatable({
        x = 0,
        y = 0,
        scale = 1,
        targetX = 0,
        targetY = 0,
        targetScale = 1,
        smoothing = 0.1
    }, Camera)
    
    return camera
end

function Camera:update(dt)
    -- Smooth camera movement
    self.x = self.x + (self.targetX - self.x) * self.smoothing
    self.y = self.y + (self.targetY - self.y) * self.smoothing
    self.scale = self.scale + (self.targetScale - self.scale) * self.smoothing
    
    -- Hard constrain the camera to prevent going beyond the map boundaries
    local Config = require("config")
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    
    -- Calculate max camera position based on world size and screen size
    -- Adjust by one tile size to prevent seeing beyond the edge
    local tileSize = Config.TILE_SIZE * self.scale
    local maxX = math.max(0, Config.WORLD_WIDTH * self.scale - screenWidth - tileSize)
    local maxY = math.max(0, Config.WORLD_HEIGHT * self.scale - screenHeight - tileSize)
    
    -- Apply constraints to actual position (not target)
    self.x = math.max(0, math.min(self.x, maxX))
    self.y = math.max(0, math.min(self.y, maxY))
    
    -- Also constrain targets to prevent continuous movement towards invalid positions
    self.targetX = math.max(0, math.min(self.targetX, maxX))
    self.targetY = math.max(0, math.min(self.targetY, maxY))
end

function Camera:move(dx, dy)
    self.targetX = self.targetX + dx
    self.targetY = self.targetY + dy
end

function Camera:setTarget(x, y)
    self.targetX = x
    self.targetY = y
end

function Camera:zoom(factor)
    self.targetScale = math.max(0.5, math.min(2.0, self.targetScale * factor))
end

function Camera:beginDraw()
    love.graphics.push()
    love.graphics.translate(-self.x, -self.y)
    love.graphics.scale(self.scale)
end

function Camera:endDraw()
    love.graphics.pop()
end

function Camera:screenToWorld(screenX, screenY)
    return (screenX + self.x) / self.scale, (screenY + self.y) / self.scale
end

function Camera:worldToScreen(worldX, worldY)
    return worldX * self.scale - self.x, worldY * self.scale - self.y
end

return Camera 