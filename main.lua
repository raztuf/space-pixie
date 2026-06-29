-- Star Princess
-- A gentle, crank-only game made for a 4-year-old.
-- Turn the crank to fly the princess around her orbit:
--   * catch the spiky STARS  (+1)
--   * dodge the round ROCKS   (-1, but never below zero)
-- No timer, no "game over" -- just happy endless play.

import "CoreLibs/graphics"
import "CoreLibs/ui"

local pd  <const> = playdate
local gfx <const> = pd.graphics

-- ---- Playing field ------------------------------------------------------
local SCREEN_W, SCREEN_H = 400, 240
local CENTER_X, CENTER_Y = 200, 120
local ORBIT_R    = 80     -- size of the circle the princess flies around
local CATCH_DIST = 24     -- how close counts as a "catch" (bigger = easier)

local score = 0

-- ---- Artwork (each drawn once into a small image) -----------------------

local function makePrincess()
    local img = gfx.image.new(26, 26)
    gfx.pushContext(img)
        -- crown (three little points)
        gfx.fillTriangle(7, 8,  9, 3, 11, 8)
        gfx.fillTriangle(10, 8, 13, 2, 16, 8)
        gfx.fillTriangle(15, 8, 17, 3, 19, 8)
        gfx.fillRect(7, 7, 12, 2)            -- crown band
        gfx.fillCircleAtPoint(13, 12, 4)     -- head
        gfx.fillTriangle(13, 14, 5, 25, 21, 25) -- dress
    gfx.popContext()
    return img
end

local function makeStar()
    local size = 18
    local cx, cy = size / 2, size / 2
    local outer, inner = size / 2 - 1, (size / 2 - 1) * 0.45
    local pts = {}
    for i = 0, 9 do
        local r = (i % 2 == 0) and outer or inner
        local a = math.rad(-90 + i * 36)
        pts[#pts + 1] = cx + math.cos(a) * r
        pts[#pts + 1] = cy + math.sin(a) * r
    end
    local img = gfx.image.new(size, size)
    gfx.pushContext(img)
        gfx.fillPolygon(table.unpack(pts))
    gfx.popContext()
    return img
end

local function makeRock()
    local img = gfx.image.new(18, 18)
    gfx.pushContext(img)
        gfx.fillCircleAtPoint(9, 9, 8)
        gfx.setColor(gfx.kColorWhite)        -- two little craters
        gfx.fillCircleAtPoint(6, 7, 1)
        gfx.fillCircleAtPoint(11, 10, 1)
        gfx.setColor(gfx.kColorBlack)
    gfx.popContext()
    return img
end

local princessImg = makePrincess()
local starImg     = makeStar()
local rockImg     = makeRock()

-- ---- Background starfield (fixed twinkle dots) --------------------------
local bgStars = {}
for i = 1, 40 do
    bgStars[i] = { x = math.random(0, SCREEN_W), y = math.random(0, SCREEN_H) }
end

-- ---- Items living on the orbit ------------------------------------------
-- Each item just sits at an angle on the circle. When the princess touches
-- one, it teleports to a fresh spot, so the field never empties out.
local items = {
    { kind = "star", angle = 30  },
    { kind = "star", angle = 150 },
    { kind = "star", angle = 270 },
    { kind = "rock", angle = 90  },
    { kind = "rock", angle = 210 },
}

local function pointOnOrbit(angleDeg)
    local a = math.rad(angleDeg)
    return CENTER_X + math.cos(a) * ORBIT_R,
           CENTER_Y + math.sin(a) * ORBIT_R
end

local function angleGap(a, b)
    local d = math.abs((a - b) % 360)
    if d > 180 then d = 360 - d end
    return d
end

-- Send an item to a new angle, away from the princess and other items.
local function relocate(item, princessAngle)
    for _ = 1, 30 do
        local a = math.random() * 360
        local ok = angleGap(a, princessAngle) > 55
        if ok then
            for _, other in ipairs(items) do
                if other ~= item and angleGap(a, other.angle) < 28 then
                    ok = false
                    break
                end
            end
        end
        if ok then item.angle = a; return end
    end
    item.angle = math.random() * 360 -- fallback if no clear spot found
end

-- ---- Sound --------------------------------------------------------------
local catchSynth = pd.sound.synth.new(pd.sound.kWaveSine)
local bonkSynth  = pd.sound.synth.new(pd.sound.kWaveSquare)
local function playCatch() catchSynth:playNote("E6", 0.5, 0.10) end
local function playBonk()  bonkSynth:playNote("A2", 0.4, 0.18) end

-- Version-safe nudge to pull the crank out, if needed.
if pd.ui.crankIndicator.start then pd.ui.crankIndicator:start() end

-- ---- Main loop ----------------------------------------------------------
function pd.update()
    local princessAngle = pd.getCrankPosition()  -- 0-360, follows the crank
    local px, py = pointOnOrbit(princessAngle)

    -- Did the princess touch anything?
    for _, item in ipairs(items) do
        local ix, iy = pointOnOrbit(item.angle)
        local dx, dy = px - ix, py - iy
        if dx * dx + dy * dy < CATCH_DIST * CATCH_DIST then
            if item.kind == "star" then
                score += 1
                playCatch()
            else
                if score > 0 then score -= 1 end
                playBonk()
            end
            relocate(item, princessAngle)
        end
    end

    -- Draw the whole scene fresh each frame.
    gfx.clear(gfx.kColorWhite)

    for _, s in ipairs(bgStars) do
        gfx.fillCircleAtPoint(s.x, s.y, 1)
    end

    gfx.setLineWidth(1)
    gfx.drawCircleAtPoint(CENTER_X, CENTER_Y, ORBIT_R)   -- the orbit path

    for _, item in ipairs(items) do
        local ix, iy = pointOnOrbit(item.angle)
        local img = (item.kind == "star") and starImg or rockImg
        img:drawAnchored(ix, iy, 0.5, 0.5)
    end

    princessImg:drawAnchored(px, py, 0.5, 0.5)

    -- Score: a star icon and the number, top-left.
    starImg:draw(6, 6)
    gfx.drawText("" .. score, 30, 10)

    -- Show the "turn the crank" hint while it's docked.
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:update()
    end
end
