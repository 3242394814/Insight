--[[
Copyright (C) 2020, 2021 penguin0616

This file is part of Insight.

The source code of this program is shared under the RECEX
SHARED SOURCE LICENSE (version 1.0).
The source code is shared for referrence and academic purposes
with the hope that people can read and learn from it. This is not
Free and Open Source software, and code is not redistributable
without permission of the author. Read the RECEX SHARED
SOURCE LICENSE for details
The source codes does not come with any warranty including
the implied warranty of merchandise.
You should have received a copy of the RECEX SHARED SOURCE
LICENSE in the form of a LICENSE file in the root of the source
directory. If not, please refer to
<https://raw.githubusercontent.com/Recex/Licenses/master/SharedSourceLicense/LICENSE.txt>
]]

-- beargerspawner.lua [Worldly]
local filename = debug.getinfo(1, "S").source:match("([%w_]+)%.lua$")

local BEARGER_TIMERNAME
local function GetBeargerData(self)
	if not self.inst.updatecomponents[self] then
		return {}
	end

	local save_data = self:OnSave()

	local time_to_attack
	if CurrentRelease.GreaterOrEqualTo("R15_QOL_WORLDSETTINGS") then
		if BEARGER_TIMERNAME == nil then
			BEARGER_TIMERNAME = assert(util.recursive_getupvalue(TheWorld.components[filename].GetDebugString, "BEARGER_TIMERNAME"), "Unable to find \"BEARGER_TIMERNAME\"") --"bearger_timetospawn"
		end

		time_to_attack = TheWorld.components.worldsettingstimer:GetTimeLeft(BEARGER_TIMERNAME)
	else
		time_to_attack = save_data.timetospawn
	end
	
	if not (time_to_attack and time_to_attack > 0) then
		return {}
	end

	local target, upvalue_exists = util.getupvalue(self.OnUpdate, "_targetplayer")

	if target then
		target = {
			name = target.name,
			userid = target.userid,
			prefab = target.prefab,
		}
	else
		if upvalue_exists == false then
			target_error_string = "???"
		end
	end

	return {
		time_to_attack = time_to_attack,
		target = target,
		warning = save_data.warning,
		target_error_string = target_error_string
	}
end

local function ProcessInformation(context, time_to_attack, target, target_error_string)
	local time_string = context.time:SimpleProcess(time_to_attack)
	local client_table = target and TheNet:GetClientTableForUser(target.userid)

	if not client_table then
		if target_error_string then
			return string.format(
				context.lstr.beargerspawner.incoming_bearger_targeted, 
				"#cc4444",
				target_error_string, 
				time_string
			)
		end

		return time_string
	else
		local target_string = string.format("%s - %s", EscapeRichText(target.name), target.prefab)
		return string.format(
			context.lstr.beargerspawner.incoming_bearger_targeted, 
			Color.ToHex(
				client_table.colour
			), 
			target_string, 
			time_string
		)
	end
end

local function RemoteDescribe(data, context)
	local description = nil

	--cprint('horse', data)
	if not data then
		return nil
	end

	if data.time_to_attack then
		description = ProcessInformation(context, data.time_to_attack, data.target, target_error_string)
	end

	local priority = Insight.descriptors.periodicthreat.CalculateThreatPriority(data.time_to_attack, { ignore_different_shard=true, shard_data=data.shard_data }) - 1
	--cprint(priority, data.shard_data)

	return {
		priority = priority,
		description = description,
		icon = {
			atlas = "images/Bearger.xml",
			tex = "Bearger.tex",
		},
		worldly = true,
		time_to_attack = data.time_to_attack,
		target_userid = data.target and data.target.userid or nil,
		warning = data.warning,
	}
end

local function StatusAnnouncementsDescribe(special_data, context)
	if not special_data.time_to_attack then
		return
	end

	local description = nil
	local target = special_data.target_userid and TheNet:GetClientTableForUser(special_data.target_userid)

	if target then
		-- Bearger is targetting someone
		description = ProcessRichTextPlainly(string.format(
			context.lstr.beargerspawner.announce_bearger_target,
			EscapeRichText(target.name),
			target.prefab,
			context.time:TryStatusAnnouncementsTime(special_data.time_to_attack)
		))
	else
		description = ProcessRichTextPlainly(string.format(
			context.lstr.beargerspawner.bearger_attack,
			context.time:TryStatusAnnouncementsTime(special_data.time_to_attack)
		))
	end

	return {
		description = description,
		append = true
	}
end


local function DangerAnnouncementDescribe(special_data, context)
	-- Funny enough, very similar to logic for status announcements and normal descriptor.
	-- Gets repetitive.
	if not special_data.time_to_attack then
		return
	end

	local description
	local client_table = special_data.target_userid and TheNet:GetClientTableForUser(special_data.target_userid)
	local time_string = context.time:SimpleProcess(special_data.time_to_attack, "realtime")

	if not client_table then
		description = string.format(context.lstr[filename].bearger_attack, time_string)
	else
		description = string.format(
			context.lstr[filename].announce_bearger_target, 
			EscapeRichText(client_table.name), 
			client_table.prefab, 
			time_string
		)
	end

	return description, "boss"
end


return {
	RemoteDescribe = RemoteDescribe,
	GetBeargerData = GetBeargerData,
	StatusAnnouncementsDescribe = StatusAnnouncementsDescribe,
	DangerAnnouncementDescribe = DangerAnnouncementDescribe,
}