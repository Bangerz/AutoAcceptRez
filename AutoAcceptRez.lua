--[[
  Auto Accept Rez — Retail / Midnight (12.x)

  Arms a 5s accept timer when a resurrection is pending (RESURRECT_REQUEST and/or
  INCOMING_RESURRECT_CHANGED + UnitHasIncomingResurrection), then AcceptResurrect() only if:
  - No boss encounter in progress
  - ResurrectGetOfferer maps to a party/raid unit that is not in combat

  If the caster is not in your group, combat cannot be verified and the rez is skipped.
]]

local DELAY_SEC = 5

local EncounterInProgress = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress or IsEncounterInProgress

local pendingTimer
local storedInviter
local countdownEnd

-- TOOLTIP strata so death screen / rez StaticPopup does not paint over the countdown
local feedback = CreateFrame("Frame", "AutoAcceptRezCountdown", UIParent)
feedback:SetSize(640, 48)
feedback:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
feedback:SetFrameStrata("TOOLTIP")
feedback:SetFrameLevel(20000)
if feedback.SetFixedFrameStrata then
	feedback:SetFixedFrameStrata(true)
end
feedback:EnableMouse(false)
local feedbackText = feedback:CreateFontString(nil, "OVERLAY")
feedbackText:SetAllPoints()
feedbackText:SetJustifyH("CENTER")
feedbackText:SetJustifyV("MIDDLE")
local base = _G.GameFontNormalHuge or _G.Game18Font or _G.GameFontNormalLarge or _G.GameFontNormal
local fontFile, fontHeight = "Fonts\\FRIZQT__.TTF", 22
if base and base.GetFont then
	local f, h = base:GetFont()
	if f then
		fontFile, fontHeight = f, h
	end
end
feedbackText:SetFont(fontFile, (fontHeight or 18) + 8, "OUTLINE")
feedbackText:SetTextColor(0.25, 1, 0.35, 1)
feedbackText:SetShadowOffset(0, 0)
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

--- RESURRECT_REQUEST may pass party1/raid3, or "Name-Realm" when UnitExists(name) is false.
local function InviterKeyFromEvent(inviter)
	if not inviter or inviter == "" then
		return nil
	end
	if type(inviter) == "string" and UnitExists(inviter) and not UnitIsUnit(inviter, "player") then
		return UnitName(inviter)
	end
	if type(inviter) == "string" then
		local hy = string.find(inviter, "-", 1, true)
		if hy and hy > 1 then
			return string.sub(inviter, 1, hy - 1)
		end
	end
	return inviter
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

local function ArmTimer(inviterFromEvent)
	CancelPending()
	storedInviter = InviterKeyFromEvent(inviterFromEvent)
	ShowCountdown()
	pendingTimer = C_Timer.NewTimer(DELAY_SEC, TryAccept)
end

--- Second signal for a pending rez (some builds fire this without RESURRECT_REQUEST).
local function ArmTimerFromIncomingIfNeeded()
	if pendingTimer then
		return
	end
	if not UnitHasIncomingResurrection or not UnitHasIncomingResurrection("player") then
		return
	end
	CancelPending()
	ShowCountdown()
	pendingTimer = C_Timer.NewTimer(DELAY_SEC, TryAccept)
end

local frame = CreateFrame("Frame", "AutoAcceptRezFrame")
frame:RegisterEvent("RESURRECT_REQUEST")
frame:RegisterEvent("INCOMING_RESURRECT_CHANGED")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "RESURRECT_REQUEST" then
		ArmTimer(arg1)
	elseif event == "INCOMING_RESURRECT_CHANGED" then
		if type(arg1) ~= "string" or not UnitExists(arg1) or not UnitIsUnit(arg1, "player") then
			return
		end
		C_Timer.After(0, function()
			if UnitHasIncomingResurrection and UnitHasIncomingResurrection("player") then
				ArmTimerFromIncomingIfNeeded()
			else
				CancelPending()
			end
		end)
	elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
		CancelPending()
	end
end)
