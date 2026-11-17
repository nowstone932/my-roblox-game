-- 언어 바꾸기 (한국어 / English)
--
-- 게임 안의 글은 전부 한국어로 쓰여 있고, 화면에 보여주기 직전에 이 모듈이 번역합니다.
--   Lang.t("가방이 비었다")          -- 정해진 글 한 줄 번역 (영어 사전에 없으면 한국어 그대로)
--   Lang.message("고철 +1")          -- 서버가 보낸 안내 글 번역 (이름·숫자가 들어간 글도 알아봄)
--   Lang.set("en") / Lang.get()      -- 언어 바꾸기 / 지금 언어
--   Lang.onChanged(function() ... end)
--
-- 영어 문장은 src/shared/LangEn.luau 에 있어요. 새 글을 추가했으면 거기에 번역을 한 줄 넣으세요.
-- (안 넣어도 오류는 안 나고, 그 글만 한국어로 보입니다)

local En = require(script.Parent.LangEn)

local Lang = {}

Lang.Languages = {
	{ code = "ko", name = "한국어" },
	{ code = "en", name = "English" },
}

local current = "ko"
local listeners: { () -> () } = {}

function Lang.get(): string
	return current
end

function Lang.set(code: string)
	if code ~= "ko" and code ~= "en" then
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

-- 정해진 글 번역
function Lang.t(text: string): string
	if current == "ko" then
		return text
	end
	return En[text] or text
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
		return exact
	end
	if not rules then
		rules = buildRules()
	end
	for _, rule in rules :: { Rule } do
		local captures = { text:match(rule.pattern) }
		if #captures > 0 then
			local args = {}
			for i, capture in captures do
				args[i] = tonumber(capture) or En[capture] or capture
			end
			local ok, result = pcall(string.format, rule.en, table.unpack(args))
			if ok then
				return result
			end
		end
	end
	return text
end

return Lang
