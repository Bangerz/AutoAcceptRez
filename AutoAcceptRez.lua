--[[
  AutoAccept Rez — Retail / Midnight (12.x)

  On RESURRECT_REQUEST, waits 5 seconds then calls AcceptResurrect() only if:
  - C_InstanceEncounter / IsEncounterInProgress: no encounter in progress
  - The offerer (from ResurrectGetOfferer) maps to a party/raid unit that is not in combat

  Limitation: if the resurrecting player is not in your group, their combat state cannot be read;
  the addon will not auto-accept in that case.
]]

local DELAY_SEC = 5

local EncounterInProgress = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress or IsEncounterInProgress

local pendingTimer
local storedInviter
local countdownEnd

-- On-screen countdown above the usual resurrect dialog position
local feedback = CreateFrame("Frame", "AutoAcceptRezCountdown", UIParent, "BackdropTemplate")
feedback:SetSize(520, 36)
feedback:SetPoint("CENTER", UIParent, "CENTER", 0, -132)
feedback:SetFrameStrata("FULLSCREEN_DIALOG")
feedback:SetFrameLevel(5000)
feedback:EnableMouse(false)
feedback:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8",
	tile = false,
	tileSize = 0,
	edgeSize = 1,
	insets = { left = 0, right = 0, top = 0, bottom = 0 },
})
feedback:SetBackdropColor(0, 0, 0, 0.55)
feedback:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.9)
local feedbackText = feedback:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
feedbackText:SetPoint("CENTER")
feedbackText:SetText("")
feedback:Hide()

local function HideCountdown()
	feedback:Hide()
	feedback:SetScript("OnUpdate", nil)
	countdownEnd = nil
	feedbackText:SetText("")
end

local function ShowCountdown()
	countdownEnd = GetTime() + DELAY_SEC
	feedback:Show()
	feedback:SetScript("OnUpdate", function()
		if not countdownEnd then
			HideCountdown()
			return
		end
		local left = countdownEnd - GetTime()
		if left <= 0 then
			feedbackText:SetText("")
			return
		end
		local sec = math.ceil(left)
		feedbackText:SetFormattedText("Auto Accept Rez: accepting in %d...", sec)
	end)
end

local function CancelPending()
	HideCountdown()
	if pendingTimer then
		pendingTimer:Cancel()
		pendingTimer = nil
	end
	storedInviter = nil
end

local function NormalizePlayerName(name)
	if not name or name == "" then
		return nil
	end
	return Ambiguate(name, "none")
end

local function NamesMatch(a, b)
	local na, nb = NormalizePlayerName(a), NormalizePlayerName(b)
	return na and nb and na == nb
end

local function UnitMatchesInviter(unit, want)
	if not UnitExists(unit) or not want then
		return false
	end
	if NamesMatch(UnitName(unit), want) then
		return true
	end
	if UnitFullName then
		local full = UnitFullName(unit)
		if full and NamesMatch(full, want) then
			return true
		end
	end
	return false
end

--- Resolve a player name to partyN or raidN so UnitAffectingCombat works.
local function UnitForPlayerName(name)
	local want = NormalizePlayerName(name)
	if not want then
		return nil
	end
	if not IsInGroup() then
		return nil
	end
	local n = GetNumGroupMembers()
	if n <= 0 then
		return nil
	end
	if IsInRaid() then
		for i = 1, n do
			local unit = "raid" .. i
			if UnitMatchesInviter(unit, want) then
				return unit
			end
		end
	else
		for i = 1, n do
			local unit = "party" .. i
			if UnitMatchesInviter(unit, want) then
				return unit
			end
		end
	end
	return nil
end

local function TryAccept()
	HideCountdown()
	pendingTimer = nil
	local inviter = storedInviter
	storedInviter = nil

	if not UnitIsDeadOrGhost("player") then
		return
	end

	if EncounterInProgress and EncounterInProgress() then
		return
	end

	local offerer = ResurrectGetOfferer and ResurrectGetOfferer() or nil
	if not offerer or offerer == "" then
		return
	end
	if inviter and not NamesMatch(offerer, inviter) then
		return
	end

	local casterUnit = UnitForPlayerName(offerer)
	if not casterUnit then
		return
	end
	if UnitAffectingCombat(casterUnit) then
		return
	end

	AcceptResurrect()
	if StaticPopup_Hide then
		StaticPopup_Hide("RESURRECT_NO_TIMER")
		StaticPopup_Hide("RESURRECT_NO_SICKNESS")
		StaticPopup_Hide("RESURRECT")
	end
end

local frame = CreateFrame("Frame", "AutoAcceptRezFrame")
frame:RegisterEvent("RESURRECT_REQUEST")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:SetScript("OnEvent", function(_, event, inviter)
	if event == "RESURRECT_REQUEST" then
		CancelPending()
		storedInviter = inviter
		ShowCountdown()
		pendingTimer = C_Timer.NewTimer(DELAY_SEC, TryAccept)
	elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
		CancelPending()
	end
end)
