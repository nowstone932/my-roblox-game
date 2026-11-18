-- 직접 만든 3D 모델(에셋)을 게임에 연결하는 곳
--
-- Studio의 ReplicatedStorage 안에 "Assets" 폴더를 만들고 아래 이름 그대로 모델을 넣으면,
-- 코드가 자동으로 파트 블록 대신 그 모델을 사용합니다. (없으면 기존 파트 모양을 씀)
--
--   ReplicatedStorage
--   └ Assets
--     ├ Items      Fuse, Battery, FuelCan, CarKey, Antenna, Rune, DogTag,
--     │            Scrap, Wood, Herb, Gunpowder, Cloth
--     ├ Tools      FlareGun, Axe, Flashbang, Trap, Medkit, SealStake
--     ├ Props      Pine(소나무), DeadTree(고목), Stump(그루터기), Bush(덤불)
--     │            → 넣으면 숲의 나무가 전부 그 모델로 바뀝니다 (실사 나무 모델 추천)
--     └ Monster    (괴물 모델 1개. 자세한 조건은 docs/에셋_요청서.md)
--
-- 크기는 자동으로 맞춰주므로 대충 넣어도 됩니다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = {}

local function find(category: string, name: string): Instance?
	local root = ReplicatedStorage:FindFirstChild("Assets")
	local folder = root and root:FindFirstChild(category)
	if category == "Monster" then
		return root and root:FindFirstChild("Monster")
	end
	return folder and folder:FindFirstChild(name)
end

function Assets.has(category: string, name: string): boolean
	return find(category, name) ~= nil
end

-- 에셋 복제본을 Model 형태로 돌려줌. 가장 긴 변이 maxSize가 되도록 크기 조절.
-- 없으면 nil
function Assets.clone(category: string, name: string, maxSize: number?): Model?
	local source = find(category, name)
	if not source then
		return nil
	end
	local copy = source:Clone()
	local model: Model
	if copy:IsA("Model") then
		model = copy
	elseif copy:IsA("BasePart") then
		model = Instance.new("Model")
		model.Name = name
		copy.Parent = model
		model.PrimaryPart = copy
	else
		copy:Destroy()
		return nil
	end
	-- 에셋 안에 스크립트가 섞여 있으면 제거 (무료 모델 해킹 스크립트 방지)
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then
			d:Destroy()
		end
	end
	-- 한 부품에 SurfaceAppearance(색 입히기)가 여러 개 붙으면 Roblox가 그중 하나만 쓰는데,
	-- 빈 것(그림 없음)이 뽑히면 모델이 하얗게 나옴. 애니메이션을 여러 번 가져올 때 이렇게 됨.
	-- 그림이 있는 것이 하나라도 있으면 빈 것은 지워서 항상 진짜 색이 보이게 함.
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local textured, empty = false, {}
			for _, c in d:GetChildren() do
				if c:IsA("SurfaceAppearance") then
					local ok, map = pcall(function()
						return c.ColorMap
					end)
					if ok and map ~= "" then
						textured = true
					elseif ok then
						table.insert(empty, c)
					end
				end
			end
			if textured then
				for _, c in empty do
					c:Destroy()
				end
			end
		end
	end
	if maxSize then
		local size = model:GetExtentsSize()
		local longest = math.max(size.X, size.Y, size.Z)
		if longest > 0 then
			model:ScaleTo(model:GetScale() * (maxSize / longest))
		end
	end
	return model
end

return Assets
