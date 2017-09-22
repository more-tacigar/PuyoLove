---------------------------------------------------------------------
-- puyolove
-- Copyright (C) 2017 tacigar
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
---------------------------------------------------------------------

local suit = require "suit"

math.randomseed(os.time())

local puyoImgs = {}
local width = 6
local height = 13
local type = { blue = 1, green = 2, purple = 3, red = 4, yellow = 5 }

local numTypeSlider = { value = 3, min = 1, max = 5 }
local fallIntervalSlider = { value = 1.0, min = 0.1, max = 5.0 }
local field = {}
local puyo = {} -- falling puyo
local nextPuyos = {}
local playtime = 0
local prevFalltime = 0
local decideDeleteTime = 0
local decideCheckTime = 0
local prevKeyMoveTime = 0
local prevKeyRotateTime = 0
local stop = false
local state = "control"
local joystick
local maxChain
local curChain

local function newPuyo()
	puyo = nextPuyos[1]
	puyo[1].x, puyo[1].y = 3, 13
	puyo[2].x, puyo[2].y = 3, 14
	table.remove(nextPuyos, 1)
	table.insert(nextPuyos, {
		{ x = 3, y = 13, type = math.random(math.floor(numTypeSlider.value))},
		{ x = 3, y = 14, type = math.random(math.floor(numTypeSlider.value))},
	})
end

local function resetGame()
	field = {}
	for i = 1, height do
		field[i] = {}
		for j = 1, width do
			field[i][j] = nil
		end
	end
	for i = 1, 2 do
		table.insert(nextPuyos, {
			{ type = math.random(math.floor(numTypeSlider.value))},
			{ type = math.random(math.floor(numTypeSlider.value))},
		})
	end
	newPuyo()
	playtime = 0
	prevFalltime = 0
	decideDeleteTime = 0
	decideCheckTime = 0
	prevKeyMoveTime = 0
	prevKeyRotateTime = 0
	maxChain = 0
	curChain = 0
	stop = false
	state = "control"
end

function love.load()
	love.window.setTitle("puyolove")
	love.graphics.setDefaultFilter("nearest", "nearest")
	love.graphics.setNewFont(12)
	love.graphics.setColor(255, 255, 255)
	love.graphics.setBackgroundColor(50, 50, 50)
	joystick = love.joystick.getJoysticks()[1]
	resetGame()
end

local function movePuyo(dir)
	for _, p in ipairs(puyo) do
		local tx = p.x + dir.x
		local ty = p.y + dir.y
		if tx > 6 or tx < 1 or ty < 1 or ty > 13 or field[ty][tx] then
			return
		end
	end
	for _, p in ipairs(puyo) do
		p.x = p.x + dir.x
		p.y = p.y + dir.y
	end
end

local function rotatePuyo(dir)
	local ref = {
		{ x = 0, y = 1 },
		{ x = 1, y = 0 },
		{ x = 0, y = -1 },
		[0] = { x = -1, y = 0 },
	}
	local diff = { x = puyo[2].x - puyo[1].x, y = puyo[2].y - puyo[1].y }
	for i, d in pairs(ref) do
		if d.x == diff.x and d.y == diff.y then
			for j = 0, 2 do
				local p2diff = ref[(i + dir * j + dir + 4) % 4]
				local tx = puyo[1].x + p2diff.x
				local ty = puyo[1].y + p2diff.y
				if ty >= 1 and ty <= 13 and tx >= 1 and tx <= 6 and field[ty][tx] == nil then
					puyo[2].x = tx
					puyo[2].y = ty
					return
				end

				-- zurashi
				tx = puyo[1].x - p2diff.x
				ty = puyo[1].y - p2diff.y
				if ty >= 1 and ty <= 13 and tx >= 1 and tx <= 6 and field[ty][tx] == nil then
					puyo[2].x = puyo[1].x
					puyo[2].y = puyo[1].y
					puyo[1].x = tx
					puyo[1].y = ty
					return
				end
			end
		end
	end
end

function love.update(dt)
	suit.layout:reset(425, 200, 20, 20)
	if suit.Button("STOP", suit.layout:row(100, 20)).hit then
		stop = true
	end
	if suit.Button("RESUME", suit.layout:row(100, 20)).hit then
		stop = false
	end
	if suit.Button("RESET", suit.layout:row(100, 20)).hit then
		resetGame()
	end
	suit.layout:push(suit.layout:row())
		suit.Slider(numTypeSlider, suit.layout:row(100, 20))
		suit.Label(("%d"):format(numTypeSlider.value), suit.layout:col(30))
		suit.layout:pop()

	suit.layout:push(suit.layout:row())
		suit.Slider(fallIntervalSlider, suit.layout:row(100, 20))
		suit.Label(("%.01f"):format(fallIntervalSlider.value), suit.layout:col(30))
		suit.layout:pop()

	if not stop then
		playtime = playtime + dt
		if state == "control" then
			if playtime > prevFalltime + fallIntervalSlider.value then
				prevFalltime = playtime
				-- check under
				for _, p in ipairs(puyo) do
					if p.y == 1 or field[p.y - 1][p.x] then
						for _, p2 in ipairs(puyo) do
							if p2.y <= 13 then
								field[p2.y][p2.x] = p2.type
							end
						end
						for _, p2 in ipairs(puyo) do -- fall
							if p2.y <= 13 then
								field[p2.y][p2.x] = nil
								while p2.y > 1 and not field[p2.y - 1][p2.x] do
									p2.y = p2.y - 1
								end
								field[p2.y][p2.x] = p2.type
							end
						end
						state = "check"
						curChain = 0
						decideCheckTime = playtime
						return
					end
				end
				-- fall
				for _, p in ipairs(puyo) do
					p.y = p.y - 1
				end
			end

			if playtime > prevKeyMoveTime + 0.075 then
				prevKeyMoveTime = playtime
				-- key
				if love.keyboard.isDown('d') or joystick:isDown(15) then
					movePuyo{ x = 1, y = 0 }
				end
				if love.keyboard.isDown('a') or joystick:isDown(14) then
					movePuyo{ x = -1, y = 0 }
				end
				if love.keyboard.isDown('s') or joystick:isDown(13) then
					movePuyo{ x = 0, y = -1 }
				end
			end
			if playtime > prevKeyRotateTime + 0.15 then
				prevKeyRotateTime = playtime
				if love.keyboard.isDown('j') or joystick:isDown(1) then
					rotatePuyo(-1)
				end
				if love.keyboard.isDown('l') or joystick:isDown(2) then
					rotatePuyo(1)
				end
			end

		elseif state == "check" then
			if playtime > decideCheckTime + 0.5 then
				local deleteField = {}
				for i = 1, 13 do
					deleteField[i] = {}
				end
				local deletePoss = {}
				local checkedField = {}
				for i = 1, 13 do
					checkedField[i] = {}
				end

				local function check(tp, x, y, cf)
					if field[y] == nil or field[y][x] == nil or cf[y][x] or field[y][x] ~= tp or deleteField[y][x] then
						return 0, nil
					end

					cf[y][x] = true
					local cnt = 1
					local poss = { { x = x, y = y } }
					for _, diff in ipairs {
						{ x =  1, y =  0 },
						{ x = -1, y =  0 },
						{ x =  0, y =  1 },
						{ x =  0, y = -1 },
					} do
						local tcnt, tposs = check(tp, x + diff.x, y + diff.y, cf)
						if tcnt > 0 then
							cnt = cnt + tcnt
							for _, pos in ipairs(tposs) do
								table.insert(poss, pos)
							end
						end
					end
					return cnt, poss
				end
				for i = 1, 13 do
					for j = 1, 6 do
						if field[i][j] ~= nil and not deleteField[i][j] and not checkedField[i][j] then
							local checkField = {}
							for i = 1, 13 do
								checkField[i] = {}
							end
							local cnt, poss = check(field[i][j], j, i, checkField)
								if cnt >= 4 then
								for _, pos in ipairs(poss) do
									deleteField[pos.y][pos.x] = true
									table.insert(deletePoss, pos)
								end
							elseif cnt >= 1 then
								for _, pos in ipairs(poss) do
									checkedField[pos.y][pos.x] = true
								end
							end
						end
					end
				end

				if #deletePoss == 0 then -- check gameover
					if field[13][3] ~= nil then
						resetGame()
						return
					else
						if maxChain < curChain then maxChain = curChain end
						curChain = 0
						state = "control"
						newPuyo()
						return
					end
				end

				for _, pos in ipairs(deletePoss) do
					field[pos.y][pos.x] = nil
				end
				curChain = curChain + 1
				state = "delete"
				decideDeleteTime = playtime
				return
			end

		elseif state == "delete" then
			if playtime > decideDeleteTime + 1.0 then
				for j = 1, 6 do
					for i = 13, 1, -1 do
						if field[i][j] == nil then
							for k = i, 12 do
								field[k][j] = field[k + 1][j]
							end
						end
					end
				end
				state = "check"
				decideCheckTime = playtime
				return
			end
		end
	end
end

local function drawPuyo(tpv, x, y)
	if not tpv then return end
	if tpv == type.blue then love.graphics.setColor(0, 0, 255)
	elseif tpv == type.green then love.graphics.setColor(0, 255, 0)
	elseif tpv == type.purple then love.graphics.setColor(255, 0, 255)
	elseif tpv == type.red then love.graphics.setColor(255, 0, 0)
	elseif tpv == type.yellow then love.graphics.setColor(255, 255, 0)
	end
	love.graphics.circle("fill", (x - 1) * 50 + 75, (12 - y) * 50 + 75, 25)
end

function love.draw()
	suit.draw()

	love.graphics.setColor(255, 255, 255)
	local f = love.graphics.newFont(18)
	love.graphics.draw(love.graphics.newText(f, string.format("MAX CHAIN: %d", maxChain)), 425, 400)
	love.graphics.draw(love.graphics.newText(f, string.format("CUR CHAIN: %d", curChain)), 425, 425)

	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", 50, 50, 300, 600)

	if state == "control" then
		for _, p in ipairs(puyo) do
			if p.y < 13 then
				drawPuyo(p.type, p.x, p.y)
			end
		end
	end
	for i = 1, 12 do
		for j = 1, 6 do
			drawPuyo(field[i][j], j, i)
		end
	end

	love.graphics.setColor(0, 0, 0)
	love.graphics.rectangle("fill", 8.25 * 50 - 7.5, 42.5, 65, 115)
	love.graphics.rectangle("fill", 9.75 * 50 - 7.5, 42.5, 65, 115)
	drawPuyo(nextPuyos[1][1].type, 8.25, 11)
	drawPuyo(nextPuyos[1][2].type, 8.25, 12)
	drawPuyo(nextPuyos[2][1].type, 9.75, 11)
	drawPuyo(nextPuyos[2][2].type, 9.75, 12)
end
