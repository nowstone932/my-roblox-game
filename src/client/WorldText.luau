-- 숲 속 표지판·물건에 적힌 글씨 번역
--
-- 표지판 글씨는 서버가 한국어로 만들어 둡니다 (Build.text, ItemModels 등).
-- 이 모듈은 내 화면에서만 그 글씨를 지금 언어로 바꿔 보여줍니다.
-- 영어 문장은 src/shared/LangEn.luau 의 "숲 속 표지판" 칸에 있어요. 사전에 없는 글씨는 그대로 둡니다.
--
-- 대기실 천막 안내판(이름이 "Board")은 Hud 가 따로 채우므로 건드리지 않습니다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Lang = require(ReplicatedStorage.Shared.Lang)

local WorldText = {}

type Entry = { original: string, shown: string }
local entries: { [TextLabel]: Entry } = setmetatable({}, { __mode = "k" }) :: any

local function apply(label: TextLabel, entry: Entry)
	entry.shown = Lang.t(entry.original)
	if label.Text ~= entry.shown then
		label.Text = entry.shown
	end
end

local function track(label: Instance)
	if not label:IsA("TextLabel") or entries[label] then
		return
	end
	local gui = label.Parent
	if not gui or not (gui:IsA("SurfaceGui") or gui:IsA("BillboardGui")) or gui.Name == "Board" then
		return
	end
	local entry = { original = label.Text, shown = label.Text }
	entries[label] = entry
	apply(label, entry)
	-- 서버가 글씨를 바꾸면 그 글씨를 새 원문으로 삼음
	label:GetPropertyChangedSignal("Text"):Connect(function()
		if label.Text ~= entry.shown then
			entry.original = label.Text
			apply(label, entry)
		end
	end)
end

function WorldText.start()
	for _, child in Workspace:GetDescendants() do
		track(child)
	end
	Workspace.DescendantAdded:Connect(track)
	Lang.onChanged(function()
		for label, entry in entries do
			apply(label, entry)
		end
	end)
end

return WorldText
