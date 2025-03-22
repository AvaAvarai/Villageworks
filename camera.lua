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
        smoothing = 0.1,
        screenWidth = love.graphics.getWidth(),
        screenHeight = love.graphics.getHeight(),
        maxX = 0,
        maxY = 0
    }, Camera)
    
    -- Calculate initial bounds
    camera:recalculateBounds()
    
    return camera
end

function Camera:recalculateBounds()
    local Config = require("config")
    self.screenWidth = love.graphics.getWidth()
    self.screenHeight = love.graphics.getHeight()
    
    -- Calculate max camera position based on world size and current screen size
    -- Adjust by one tile size to prevent seeing beyond the edge
    local tileSize = Config.TILE_SIZE * self.scale
    self.maxX = math.max(0, Config.WORLD_WIDTH * self.scale - self.screenWidth - tileSize)
    self.maxY = math.max(0, Config.WORLD_HEIGHT * self.scale - self.screenHeight - tileSize)
    
    -- Re-apply constraints after recalculating
    self:applyConstraints()
end

function Camera:applyConstraints()
    -- Apply constraints to actual position
    self.x = math.max(0, math.min(self.x, self.maxX))
    self.y = math.max(0, math.min(self.y, self.maxY))
    
    -- Also constrain targets to prevent continuous movement towards invalid positions
    self.targetX = math.max(0, math.min(self.targetX, self.maxX))
    self.targetY = math.max(0, math.min(self.targetY, self.maxY))
end

function Camera:update(dt)
    -- Smooth camera movement
    self.x = self.x + (self.targetX - self.x) * self.smoothing
    self.y = self.y + (self.targetY - self.y) * self.smoothing
    self.scale = self.scale + (self.targetScale - self.scale) * self.smoothing
    
    -- Recalculate bounds if the scale has changed
    local Config = require("config")
    local tileSize = Config.TILE_SIZE * self.scale
    self.maxX = math.max(0, Config.WORLD_WIDTH * self.scale - self.screenWidth - tileSize)
    self.maxY = math.max(0, Config.WORLD_HEIGHT * self.scale - self.screenHeight - tileSize)
    
    -- Apply constraints
    self:applyConstraints()
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