import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local pd <const> = playdate
local gfx <const> = pd.graphics

local princess
local angle = 0
local centerX = 200
local centerY = 120
local radius = 80
local crankPosition = 0

function pd.update()
    pd.timer.updateTimers()
    
    -- Get crank input
    local crankChange, acceleratedChange = pd.getCrankChange()
    if crankChange ~= 0 then
        crankPosition += crankChange
    end
    
    -- Update angle based on crank position
    angle = math.rad(crankPosition)
    
    -- Calculate princess position in circle
    local x = centerX + math.cos(angle) * radius
    local y = centerY + math.sin(angle) * radius
    
    -- Update princess position
    princess:moveTo(x, y)
    
    -- Update sprites
    gfx.sprite.update()
    
    -- Draw background
    gfx.clear()
    
    -- Draw circle path (optional visual guide)
    gfx.drawCircleAtPoint(centerX, centerY, radius)
end

-- Princess sprite class
class('Princess').extends(gfx.sprite)

function Princess:init()
    -- Create a simple princess graphic (crown and dress shape)
    local princessImage = gfx.image.new(20, 20)
    gfx.pushContext(princessImage)
        -- Draw princess (simple representation)
        -- Crown
        gfx.fillRect(5, 2, 10, 3)
        gfx.fillTriangle(3, 5, 8, 2, 8, 5)
        gfx.fillTriangle(12, 2, 17, 5, 12, 5)
        
        -- Face
        gfx.fillCircleAtPoint(10, 10, 4)
        
        -- Dress
        gfx.fillRect(7, 14, 6, 6)
    gfx.popContext()
    
    self:setImage(princessImage)
    self:setCenter(0.5, 0.5)
    self:add()
end

-- Initialize the game
function pd.gameWillStart()
    -- Create princess sprite
    princess = Princess()
    
    -- Set initial position
    local x = centerX + math.cos(angle) * radius
    local y = centerY + math.sin(angle) * radius
    princess:moveTo(x, y)
end