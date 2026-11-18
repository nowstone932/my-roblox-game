-- 숲 속 표지판·물건에 적힌 글씨 번역
--
-- 표지판 글씨는 서버가 한국어로 만들어 둡니다 (Build.text, ItemModels 등).
-- 이 모듈은 내 화면에서만 그 글씨를 지금 언어로 바꿔 보여줍니다.
-- 영어 문장은 src/shared/LangEn.luau 의 "숲 속 표지판" 칸에 있어요. 사전에 없는 글씨는 그대로 둡니다.
--
-- 대기실 천막 안내판(이름이 "Board")은 Hud 가 따로 채우므로 건드리지 않습니다.
--
-- 아래 도구 칸(1~9)에 보이는 도구 이름도 여기서 바꿉니다. 서버의 도구 이름은 한국어 그대로이고
-- (서버는 이름 대신 ItemId 속성으로 도구를 찾음), 내 화면에서만 이름을 바꿔 보여줍니다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Items = require(ReplicatedStorage.Shared.Items)
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

-- 도구 이름 (예: "조명탄 총" → "Flare gun", "섬광탄 x2" → "Flashbang x2")
local tools: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function toolName(tool: Tool): string?
	local def = Items.defs[tool:GetAttribute("ItemId") :: any]
	if not def then
		return nil
	end
	local name = Lang.t(def.name)
	local count = tool:GetAttribute("Count")
	if def.stack and typeof(count) == "number" then
		name = ("%s x%d"):format(name, count)
	end
	return name
end

local function applyTool(tool: Tool)
	local name = toolName(tool)
	if name and tool.Name ~= name then
		tool.Name = name
	end
	local def = Items.defs[tool:GetAttribute("ItemId") :: any]
	if def and def.desc then
		local tip = Lang.t(def.desc)
		if tool.ToolTip ~= tip then
			tool.ToolTip = tip
		end
	end
end

local function trackTool(tool: Tool)
	if tools[tool] then
		return
	end
	tools[tool] = true
	applyTool(tool)
	-- 서버가 개수를 바꾸면 이름이 한국어로 돌아오므로 다시 바꿈
	tool:GetPropertyChangedSignal("Name"):Connect(function()
		applyTool(tool)
	end)
	tool:GetAttributeChangedSignal("Count"):Connect(function()
		applyTool(tool)
	end)
end

local function track(label: Instance)
	if label:IsA("Tool") then
		trackTool(label)
		return
	end
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
	-- 가방(Backpack) 안의 도구
	local player = Players.LocalPlayer
	for _, child in player:GetDescendants() do
		track(child)
	end
	player.DescendantAdded:Connect(track)
	Lang.onChanged(function()
		for label, entry in entries do
			apply(label, entry)
		end
		for tool in tools do
			applyTool(tool)
		end
	end)
end

return WorldText
