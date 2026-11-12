-- 서버와 클라이언트가 주고받는 신호(RemoteEvent)를 한 곳에서 관리합니다.
-- 서버가 먼저 만들고, 클라이언트는 만들어질 때까지 기다립니다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Craft", -- 클라 -> 서버: 제작 요청 (recipeId)
	"Fire", -- 클라 -> 서버: 총 발사 (origin, direction)
	"UseItem", -- 클라 -> 서버: 아이템 사용 ("Flashbang" | "Medkit")
	"Notify", -- 서버 -> 클라: 화면에 메시지 표시 (text)
	"Effect", -- 서버 -> 클라: 시각 효과 (kind, ...)
}

local folder: Instance
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

local Remotes = {}

function Remotes.get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
