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

function Camera:worldToScreen(worldX, worldY)
    return worldX * self.scale - self.x, worldY * self.scale - self.y
end

function Camera:screenToWorld(screenX, screenY)
    return (screenX + self.x) / self.scale, (screenY + self.y) / self.scale
end

return Camera 