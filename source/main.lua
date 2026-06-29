import "CoreLibs/graphics"
import "CoreLibs/ui"

local pd  <const> = playdate
local gfx <const> = pd.graphics

-- ---- Playing field ------------------------------------------------------
local SCREEN_W, SCREEN_H = 400, 240
local CENTER_X, CENTER_Y = 200, 120
local ORBIT_R    = 80     -- size of the circle the fairy flies around
local CATCH_DIST = 22     -- how close counts as a "catch" (bigger = easier)

local score = 0
local state = "title"     -- "title" or "play"
local frame = 0           -- counts up forever, used for gentle animation

-- ---- Artwork (each drawn once into a small image) -----------------------

-- A little star fairy: translucent wings, a smiling face, antennae with
-- sparkle tips, and a star-topped wand.
local function makeFairy()
    local W, H = 40, 42
    local cx = 20
    local img = gfx.image.new(W, H)
    gfx.pushContext(img)
        -- wings (outlines only, so they read as see-through)
        gfx.setLineWidth(1)
        gfx.drawEllipseInRect(1,  3, 17, 19)     -- upper left
        gfx.drawEllipseInRect(22, 3, 17, 19)     -- upper right
        gfx.drawEllipseInRect(4, 21, 14, 16)     -- lower left
        gfx.drawEllipseInRect(22,21, 14, 16)     -- lower right

        -- dress / body
        gfx.fillTriangle(cx, 16, cx - 7, 34, cx + 7, 34)   -- skirt
        gfx.fillRect(cx - 2, 13, 4, 5)                      -- bodice
        gfx.drawLine(cx - 2, 34, cx - 3, 39)               -- legs
        gfx.drawLine(cx + 2, 34, cx + 3, 39)
        -- white sparkles on the skirt
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(cx,     27, 1)
        gfx.fillCircleAtPoint(cx - 3, 31, 1)
        gfx.fillCircleAtPoint(cx + 3, 31, 1)
        gfx.setColor(gfx.kColorBlack)

        -- head with a friendly face
        gfx.fillCircleAtPoint(cx, 9, 5)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillCircleAtPoint(cx - 2, 9, 1)      -- eyes
        gfx.fillCircleAtPoint(cx + 2, 9, 1)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(cx - 1, 11, cx + 1, 11)     -- smile

        -- antennae with sparkle tips
        gfx.drawLine(cx - 2, 5, cx - 5, 1)
        gfx.drawLine(cx + 2, 5, cx + 5, 1)
        gfx.fillCircleAtPoint(cx - 5, 1, 1)
        gfx.fillCircleAtPoint(cx + 5, 1, 1)

        -- a star-topped wand in her hand
        gfx.drawLine(cx + 5, 19, cx + 11, 12)
        gfx.fillCircleAtPoint(cx + 12, 11, 2)
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

local fairyImg = makeFairy()
local starImg  = makeStar()
local rockImg  = makeRock()

-- ---- Background starfield (fixed twinkle dots) --------------------------
local bgStars = {}
for i = 1, 40 do
    bgStars[i] = { x = math.random(0, SCREEN_W), y = math.random(0, SCREEN_H) }
end

-- ---- Drifting items -----------------------------------------------------
-- Items sail in from just outside the screen, cross the play area near the
-- fairy's orbit, and drift off the far side. New ones keep arriving.
local items = {}
local MAX_ITEMS   = 5
local SPAWN_EVERY = 32      -- frames between spawn attempts
local spawnTimer  = 0

local function spawnItem()
    local kind = (math.random() < 0.62) and "star" or "rock"

    -- start just off a random edge
    local margin = 30
    local edge = math.random(1, 4)
    local x, y
    if     edge == 1 then x = -margin;                  y = math.random(0, SCREEN_H)
    elseif edge == 2 then x = SCREEN_W + margin;        y = math.random(0, SCREEN_H)
    elseif edge == 3 then x = math.random(0, SCREEN_W); y = -margin
    else                  x = math.random(0, SCREEN_W); y = SCREEN_H + margin end

    -- aim toward a point near the orbit so it passes the catchable zone
    local tx = CENTER_X + (math.random() - 0.5) * 2 * ORBIT_R
    local ty = CENTER_Y + (math.random() - 0.5) * 2 * ORBIT_R
    local dx, dy = tx - x, ty - y
    local d = math.sqrt(dx * dx + dy * dy)
    local speed = 1.1 + math.random() * 1.2

    items[#items + 1] = {
        kind = kind, x = x, y = y,
        vx = dx / d * speed,
        vy = dy / d * speed,
        spin  = math.random() * 360,
        dspin = (math.random() - 0.5) * 8,   -- gentle tumble
    }
end

local function offScreen(it)
    local m = 40
    return it.x < -m or it.x > SCREEN_W + m or it.y < -m or it.y > SCREEN_H + m
end

-- ---- Sound --------------------------------------------------------------
local catchSynth = pd.sound.synth.new(pd.sound.kWaveSine)
local bonkSynth  = pd.sound.synth.new(pd.sound.kWaveSquare)
local function playCatch() catchSynth:playNote("E6", 0.5, 0.10) end
local function playBonk()  bonkSynth:playNote("A2", 0.4, 0.18) end

-- White artwork on a black, starry-night background.
pd.display.setInverted(true)

local titleFont = gfx.getSystemFont(gfx.font.kVariantBold)

-- Version-safe nudge to pull the crank out, if needed.
if pd.ui.crankIndicator.start then pd.ui.crankIndicator:start() end

-- ---- Title screen -------------------------------------------------------
local function drawTitle()
    gfx.clear(gfx.kColorWhite)
    for _, s in ipairs(bgStars) do
        gfx.fillCircleAtPoint(s.x, s.y, 1)
    end

    local bob = math.sin(frame * 0.08) * 5
    fairyImg:drawAnchored(CENTER_X, 132 + bob, 0.5, 0.5)

    gfx.setFont(titleFont)
    gfx.drawTextAligned("Princesse",   CENTER_X, 40, kTextAlignment.center)
    gfx.drawTextAligned("des etoiles", CENTER_X, 64, kTextAlignment.center)
    gfx.setFont(gfx.getSystemFont())

    if (frame // 24) % 2 == 0 then     -- gentle blink
        gfx.drawTextAligned("Tourne la manivelle !", CENTER_X, 196, kTextAlignment.center)
    end
end

-- ---- Main loop ----------------------------------------------------------
function pd.update()
    frame += 1

    if state == "title" then
        if pd.buttonJustPressed(pd.kButtonA)
            or pd.buttonJustPressed(pd.kButtonB)
            or math.abs(pd.getCrankChange()) > 2 then
            state = "play"
        end
        drawTitle()
        if pd.isCrankDocked() then pd.ui.crankIndicator:update() end
        return
    end

    -- play state ----------------------------------------------------------
    local princessAngle = pd.getCrankPosition()  -- 0-360, follows the crank
    local a  = math.rad(princessAngle)
    local px = CENTER_X + math.cos(a) * ORBIT_R
    local py = CENTER_Y + math.sin(a) * ORBIT_R

    -- keep new items arriving
    spawnTimer += 1
    if spawnTimer >= SPAWN_EVERY and #items < MAX_ITEMS then
        spawnTimer = 0
        spawnItem()
    end

    -- move every item, catch it, or retire it when it leaves
    for i = #items, 1, -1 do
        local it = items[i]
        it.x = it.x + it.vx
        it.y = it.y + it.vy
        it.spin = it.spin + it.dspin

        local dx, dy = px - it.x, py - it.y
        if dx * dx + dy * dy < CATCH_DIST * CATCH_DIST then
            if it.kind == "star" then
                score += 1
                playCatch()
            else
                if score > 0 then score -= 1 end
                playBonk()
            end
            table.remove(items, i)
        elseif offScreen(it) then
            table.remove(items, i)
        end
    end

    -- Draw the whole scene fresh each frame.
    gfx.clear(gfx.kColorWhite)

    for _, s in ipairs(bgStars) do
        gfx.fillCircleAtPoint(s.x, s.y, 1)
    end

    gfx.setLineWidth(1)
    gfx.drawCircleAtPoint(CENTER_X, CENTER_Y, ORBIT_R)   -- the orbit path

    for _, it in ipairs(items) do
        local img = (it.kind == "star") and starImg or rockImg
        img:drawRotated(it.x, it.y, it.spin)
    end

    fairyImg:drawAnchored(px, py, 0.5, 0.5)

    -- Score: a star icon and the number, top-left.
    starImg:draw(6, 6)
    gfx.drawText("" .. score, 30, 10)

    -- Show the "turn the crank" hint while it's docked.
    if pd.isCrankDocked() then
        pd.ui.crankIndicator:update()
    end
end
