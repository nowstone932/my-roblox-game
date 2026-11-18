-- 언어 바꾸기 (English / 한국어 / Español / Português)
--
-- 게임 안의 글은 전부 한국어로 쓰여 있고, 화면에 보여주기 직전에 이 모듈이 번역합니다.
--   Lang.t("가방이 비었다")          -- 정해진 글 한 줄 번역 (영어 사전에 없으면 한국어 그대로)
--   Lang.message("고철 +1")          -- 서버가 보낸 안내 글 번역 (이름·숫자가 들어간 글도 알아봄)
--   Lang.set("en") / Lang.get()      -- 언어 바꾸기 / 지금 언어
--   Lang.onChanged(function() ... end)
--
-- 영어 문장은 src/shared/LangEn.luau 에 있어요. 새 글을 추가했으면 거기에 번역을 한 줄 넣으세요.
-- (안 넣어도 오류는 안 나고, 그 글만 한국어로 보입니다)
-- 스페인어·포르투갈어는 영어 문장을 한 번 더 번역합니다 (LangEs.luau, LangPt.luau).
-- 거기 없는 글은 영어로 보여요.
-- 처음 들어온 사람은 영어로 시작합니다 (client/Settings.luau 에서 정함).

local En = require(script.Parent.LangEn)

-- 영어 다음 단계 번역 (영어 문장 → 그 나라 말)
local FromEnglish: { [string]: { [string]: string } } = {
	es = require(script.Parent.LangEs),
	pt = require(script.Parent.LangPt),
}

local Lang = {}

-- 설정 창 버튼 순서
Lang.Languages = {
	{ code = "en", name = "English" },
	{ code = "ko", name = "한국어" },
	{ code = "es", name = "Español" },
	{ code = "pt", name = "Português" },
}

Lang.Default = "en"

local current = Lang.Default
local listeners: { () -> () } = {}

function Lang.get(): string
	return current
end

-- 이 게임이 아는 언어 코드인지
function Lang.isSupported(code: any): boolean
	if typeof(code) ~= "string" then
		return false
	end
	for _, info in Lang.Languages do
		if info.code == code then
			return true
		end
	end
	return false
end

function Lang.set(code: string)
	if not Lang.isSupported(code) then
		return
	end
	if code == current then
		return
	end
	current = code
	for _, fn in listeners do
		task.spawn(fn)
	end
end

function Lang.onChanged(fn: () -> ())
	table.insert(listeners, fn)
end

-- 영어 문장을 지금 언어로 (영어면 그대로)
local function fromEnglish(english: string): string
	local dict = FromEnglish[current]
	return dict and dict[english] or english
end

-- 정해진 글 번역
function Lang.t(text: string): string
	if current == "ko" then
		return text
	end
	local english = En[text]
	if not english then
		return text
	end
	return fromEnglish(english)
end

---------------------------------------------------------------------------
-- 이름·숫자가 끼어 있는 글 ("%s이(가) 쓰러졌다! %d초 …") 알아보기
---------------------------------------------------------------------------
type Rule = { pattern: string, en: string, length: number }
local rules: { Rule }? = nil

local MAGIC = "[%^%$%(%)%%%.%[%]%*%+%-%?]"

local function buildRules(): { Rule }
	local list: { Rule } = {}
	for ko, en in En do
		if ko:find("%%[ds]") then
			-- %d, %s 자리를 잠깐 다른 글자로 바꿔 두고 나머지 특수 문자를 무력화한 다음 되돌림
			local p = ko:gsub("%%d", "\1"):gsub("%%s", "\2")
			p = p:gsub(MAGIC, "%%%0")
			p = p:gsub("\1", "(%%-?%%d+)"):gsub("\2", "(.-)")
			table.insert(list, { pattern = "^" .. p .. "$", en = en, length = #ko })
		end
	end
	-- 긴(자세한) 글부터 맞춰 봄
	table.sort(list, function(a, b)
		return a.length > b.length
	end)
	return list
end

-- 서버가 보낸 안내 글 번역
function Lang.message(text: string): string
	if current == "ko" then
		return text
	end
	local exact = En[text]
	if exact then
		return fromEnglish(exact)
	end
	if not rules then
		rules = buildRules()
	end
	for _, rule in rules :: { Rule } do
		local captures = { text:match(rule.pattern) }
		if #captures > 0 then
			local args = {}
			for i, capture in captures do
				local english = En[capture]
				args[i] = tonumber(capture) or (if english then fromEnglish(english) else capture)
			end
			local ok, result = pcall(string.format, fromEnglish(rule.en), table.unpack(args))
			if ok then
				return result
			end
		end
	end
	return text
end

return Lang
