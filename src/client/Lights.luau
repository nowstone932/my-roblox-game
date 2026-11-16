-- 맵의 등불(랜턴, 촛불 등)을 살아있는 것처럼 깜빡이게 합니다.
--   - 평소: 불꽃처럼 일렁임
--   - 숲지기가 가까이 오면: 꺼질 듯 깜빡이다 꺼짐 (괴물이 근처에 있다는 유일한 "눈에 보이는" 신호)
--   - 정전(Blackout): 숲 전체의 불이 한동안 꺼짐
--   - LampOut: 내 근처의 등불 하나가 치직거리다 꺼짐
-- 서버(Build.light)가 Flicker 속성을 붙여 둔 불빛만 다룹니다.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Lights = {}

type Lamp = {
	light: PointLight,
	part: BasePart,
	base: number, -- 원래 밝기
	color: Color3,
	material: Enum.Material,
	lit: boolean,
	deadUntil: number,
}

local lamps: { [PointLight]: Lamp } = {}
local blackoutUntil = 0
local monsterRoot: () -> BasePart? = function()
	return nil
end

local DARK = Color3.fromRGB(28, 24, 20)

-- 불이 꺼지면 전구/불꽃 파트도 어두워지게 (네온이 계속 빛나면 어색하니까)
local function setLit(lamp: Lamp, lit: boolean)
	if lamp.lit == lit then
		return
	end
	lamp.lit = lit
	if lamp.material == Enum.Material.Neon then
		lamp.part.Material = if lit then lamp.material else Enum.Material.SmoothPlastic
		lamp.part.Color = if lit then lamp.color else DARK
	end
end

local function register(inst: Instance)
	if not (inst:IsA("BasePart") and inst:GetAttribute("Flicker")) then
		return
	end
	local light = inst:FindFirstChildOfClass("PointLight") or inst:WaitForChild("PointLight", 2)
	if light and light:IsA("PointLight") and not lamps[light] then
		lamps[light] = {
			light = light,
			part = inst,
			base = light.Brightness,
			color = inst.Color,
			material = inst.Material,
			lit = true,
			deadUntil = 0,
		}
	end
end

local t0 = os.clock()
local function update()
	local now = os.clock()
	local t = now - t0
	local mRoot = monsterRoot()
	local blackout = now < blackoutUntil
	for light, lamp in lamps do
		if not lamp.part.Parent then
			lamps[light] = nil
			continue
		end
		local brightness: number
		if blackout then
			brightness = if math.random() < 0.015 then lamp.base * 0.4 else 0
		elseif now < lamp.deadUntil then
			-- 치직거리다 꺼짐
			local left = lamp.deadUntil - now
			brightness = if left > 11.2 and math.random() < 0.5 then lamp.base * 0.7 else 0
		else
			local n = math.noise(t * 3, lamp.base * 7.3 + lamp.part.Position.X)
			brightness = if math.random() < 0.008 then 0 else lamp.base * (0.75 + n * 0.6)
			if mRoot then
				local d = (lamp.part.Position - mRoot.Position).Magnitude
				if d < 38 then
					-- 괴물이 가까울수록 더 자주 꺼짐
					brightness = if math.random() < (1 - d / 38) * 0.9 then 0 else brightness * (d / 38)
				end
			end
		end
		light.Brightness = brightness
		setLit(lamp, brightness > 0.01)
	end
end

-- getMonsterRoot: 괴물 몸통을 돌려주는 함수 (쓰러졌거나 없으면 nil)
function Lights.start(getMonsterRoot: () -> BasePart?)
	monsterRoot = getMonsterRoot
	task.spawn(function()
		local forest = Workspace:WaitForChild("BlackpineForest")
		for _, d in forest:GetDescendants() do
			task.spawn(register, d)
		end
		forest.DescendantAdded:Connect(function(d)
			task.defer(register, d)
		end)
	end)
	RunService.Heartbeat:Connect(update)
end

function Lights.blackout(seconds: number)
	blackoutUntil = os.clock() + seconds
end

function Lights.isBlackout(): boolean
	return os.clock() < blackoutUntil
end

-- pos 근처(45스터드 안)의 켜진 등불 하나를 한동안 꺼뜨림. 꺼뜨린 등불의 위치를 돌려줌 (없으면 nil)
function Lights.killNearest(pos: Vector3): Vector3?
	local now = os.clock()
	local best: Lamp? = nil
	local bestDist = 45
	for _, lamp in lamps do
		if lamp.part.Parent and now >= lamp.deadUntil then
			local d = (lamp.part.Position - pos).Magnitude
			if d < bestDist then
				best, bestDist = lamp, d
			end
		end
	end
	if best then
		best.deadUntil = now + 12
		return best.part.Position
	end
	return nil
end

return Lights
