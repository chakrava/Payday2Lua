ChallengeManager = ChallengeManager or class()
ChallengeManager.PATH = "gamedata/challenges"
ChallengeManager.FILE_EXTENSION = "timeline"
function ChallengeManager:init()
	self:_setup()
end
function ChallengeManager:init_finalize()
end
function ChallengeManager:_setup()
	self._default = {}
	if not Global.challenge_manager then
		Global.challenge_manager = {}
		Global.challenge_manager.challenges = {}
		Global.challenge_manager.active_challenges = {}
		Global.challenge_manager.visited_crimenet = false
		Global.challenge_manager.retrieving = false
		Global.challenge_manager.validated = false
		self:_load_challenges_from_xml()
		managers.savefile:add_load_sequence_done_callback_handler(callback(self, self, "_load_done"))
	end
	self._global = Global.challenge_manager
end
function ChallengeManager:visited_crimenet()
	return self._global.visited_crimenet
end
function ChallengeManager:visit_crimenet()
	self._global.visited_crimenet = true
end
function ChallengeManager:get_timestamp()
	local year = tonumber(Application:date("%y"))
	local day = tonumber(Application:date("%j"))
	local hour = tonumber(Application:date("%H"))
	local all_days = year * 365 + year % 4 + 1 + day
	local timestamp = all_days * 24 + hour
	return timestamp
end
function ChallengeManager:clear_challenges()
	self._global.challenges = {}
end
function ChallengeManager:is_retrieving()
	return self._global.retrieving
end
function ChallengeManager:is_validated()
	return self._global.validated
end
function ChallengeManager:fetch_challenges()
	if self._load_done then
		self:_fetch_challenges()
	end
end
function ChallengeManager:_fetch_challenges()
	local done_clbk = callback(self, self, "_fetch_done_clbk")
	self._global.retrieving = true
	if SystemInfo:platform() == Idstring("WIN32") then
		Steam:http_request("http://media.overkillsoftware.com/stats/missions.json", done_clbk, Idstring("ChallengeManager:_fetch_challenges()"):key())
	else
	end
end
function ChallengeManager:_fetch_done_clbk(success, s)
	self._global.retrieving = false
	self._global.validated = false
	if success then
		local all_currently_active_challenges = {}
		local currently_active_challenges = {}
		for category, ids in string.gmatch(s, "\"([^,:\"]+)\":\"([^:\"]+)\"") do
			currently_active_challenges[category] = currently_active_challenges[category] or {}
			for active_id in string.gmatch(ids, "'([^,]+)'") do
				table.insert(currently_active_challenges[category], active_id)
				table.insert(all_currently_active_challenges, active_id)
			end
		end
		local inactive_challenges = {}
		local timestamp = self:get_timestamp()
		local is_active
		for key, challenge in pairs(self._global.active_challenges) do
			is_active = table.contains(all_currently_active_challenges, challenge.id)
			if not is_active and (challenge.completed and challenge.rewarded or timestamp > challenge.timestamp + challenge.interval) then
				print("[ChallengeManager] Active challenge is invalid", "Challenge id", challenge.id, "Challenge timestamp", challenge.timestamp, "Challenge interval", challenge.interval, "timestamp", timestamp)
				table.insert(inactive_challenges, key)
			end
		end
		for _, key in ipairs(inactive_challenges) do
			self._global.active_challenges[key] = nil
		end
		for category, ids in pairs(currently_active_challenges) do
			for _, id in ipairs(ids) do
				print("[ChallengeManager]", category, id, inspect(self._global.active_challenges[Idstring(id):key()]))
				self:activate_challenge(id, nil, category)
			end
		end
		self._global.validated = true
	end
end
function ChallengeManager:_load_challenges_from_xml()
	local list = PackageManager:script_data(self.FILE_EXTENSION:id(), self.PATH:id())
	local objectives, rewards
	for _, challenge in ipairs(list) do
		if challenge._meta == "challenge" and challenge.id then
			objectives = {}
			rewards = {}
			for _, data in ipairs(challenge) do
				if data._meta == "objective" then
					table.insert(objectives, {
						achievement_id = data.achievement_id,
						name_id = data.name_id,
						name_s = data.name_s,
						desc_id = data.desc_id,
						desc_s = data.desc_s,
						completed = false
					})
				elseif data._meta == "reward" then
					table.insert(rewards, {
						name_id = data.name_id,
						name_s = data.name_s,
						desc_id = data.desc_id,
						desc_s = data.desc_s,
						type_items = data.type_items,
						item_entry = data.item_entry,
						amount = data.amount,
						global_value = data.global_value or false,
						choose_weapon_reward = data.choose_weapon_reward,
						rewarded = false
					})
				elseif data._meta == "rewards" then
					local reward_data = {rewarded = false}
					for _, reward in ipairs(data) do
						table.insert(reward_data, {
							name_id = reward.name_id,
							name_s = reward.name_s,
							desc_id = reward.desc_id,
							desc_s = reward.desc_s,
							type_items = reward.type_items,
							item_entry = reward.item_entry,
							amount = reward.amount,
							global_value = reward.global_value or false,
							choose_weapon_reward = reward.choose_weapon_reward
						})
					end
					table.insert(rewards, reward_data)
				end
			end
			Global.challenge_manager.challenges[Idstring(challenge.id):key()] = {
				id = challenge.id,
				name_id = challenge.name_id,
				name_s = challenge.name_s,
				desc_id = challenge.desc_id,
				desc_s = challenge.desc_s,
				objective_id = challenge.objective_id,
				objective_s = challenge.objective_s,
				reward_id = challenge.reward_id,
				reward_s = challenge.reward_s,
				interval = challenge.interval or false,
				objectives = objectives,
				rewards = rewards
			}
		else
			Application:debug("[ChallengeManager:_load_challenges_from_xml] Unrecognized entry in xml", "meta", challenge._meta, "id", challenge.id)
		end
	end
end
function ChallengeManager:get_all_active_challenges()
	return self._global.active_challenges
end
function ChallengeManager:get_challenge(id, key)
	return self._global.challenges[key or Idstring(id):key()]
end
function ChallengeManager:get_active_challenge(id, key)
	return self._global.active_challenges[key or Idstring(id):key()]
end
function ChallengeManager:has_challenge(id, key)
	return not not self._global.challenges[key or Idstring(id):key()]
end
function ChallengeManager:has_active_challenges(id, key)
	return not not self._global.active_challenges[key or Idstring(id):key()]
end
function ChallengeManager:activate_challenge(id, key, category)
	if self:has_active_challenges(id, key) then
		local active_challenge = self:get_active_challenge(id, key)
		active_challenge.category = category
		return false, "active"
	end
	local challenge = self:get_challenge(id, key)
	if challenge then
		challenge = deep_clone(challenge)
		challenge.timestamp = self:get_timestamp()
		challenge.completed = false
		challenge.rewarded = false
		challenge.category = category
		self._global.active_challenges[key or Idstring(id):key()] = challenge
		return true
	end
	Application:error("[ChallengeManager:activate_challenge] Trying to activate non-existing challenge", id, key)
	return false, "not_found"
end
function ChallengeManager:remove_active_challenge(id, key)
	local active_challenge = self:get_active_challenge(id, key)
	if not active_challenge then
		return false, "not_active"
	end
	self._global.active_challenges[key or Idstring(id):key()] = nil
end
function ChallengeManager:_check_challenge_completed(id, key)
	local active_challenge = self:get_active_challenge(id, key)
	if active_challenge and not active_challenge.completed then
		local completed = true
		for _, objective in pairs(active_challenge.objectives) do
			if not objective.completed then
				completed = false
			else
			end
		end
		if completed then
			self._any_challenge_completed = true
			active_challenge.completed = true
			if managers.hud then
				managers.hud:post_event("Achievement_challenge")
			end
			return true
		end
	end
	return false
end
function ChallengeManager:on_achievement_awarded(id)
	if not self._global.validated then
		return
	end
	for key, active_challenge in pairs(self._global.active_challenges) do
		for _, objective in ipairs(active_challenge.objectives) do
			if not objective.completed and objective.achievement_id == id then
				objective.completed = true
				self:_check_challenge_completed(objective.id, key)
			else
			end
		end
	end
end
function ChallengeManager:can_give_reward(id, key)
	local active_challenge = self:get_active_challenge(id, key)
	return self._global.validated and active_challenge and active_challenge.completed and not active_challenge.rewarded and true or false
end
function ChallengeManager:is_challenge_rewarded(id, key)
	local active_challenge = self:get_active_challenge(id, key)
	return active_challenge and active_challenge.rewarded and true or false
end
function ChallengeManager:is_challenge_completed(id, key)
	local active_challenge = self:get_active_challenge(id, key)
	return active_challenge and active_challenge.completed and true or false
end
function ChallengeManager:any_challenge_completed()
	if self._any_challenge_completed then
		self._any_challenge_completed = nil
		return true
	end
end
function ChallengeManager:any_challenge_rewarded()
	if self._any_challenge_rewarded then
		self._any_challenge_rewarded = nil
		return true
	end
end
function ChallengeManager:on_give_reward(id, key, reward_index)
	if not self._global.validated then
		return
	end
	local active_challenge = self:get_active_challenge(id, key)
	if active_challenge and active_challenge.completed and not active_challenge.rewarded then
		local reward = active_challenge.rewards[reward_index]
		if reward and not reward.rewarded then
			reward = self:_give_reward(reward)
			local all_rewarded = true
			for _, reward in ipairs(active_challenge.rewards) do
				if not reward.rewarded then
					all_rewarded = false
				else
				end
			end
			active_challenge.rewarded = all_rewarded
			if all_rewarded then
				self._any_challenge_rewarded = true
			end
			return reward
		end
	end
end
function ChallengeManager:on_give_all_rewards(id, key)
	if not self._global.validated then
		return
	end
	local active_challenge = self:get_active_challenge(id, key)
	if active_challenge and active_challenge.completed and not active_challenge.rewarded then
		local rewards = {}
		for _, reward in ipairs(active_challenge.rewards) do
			table.insert(rewards, self:_give_reward(reward))
		end
		active_challenge.rewarded = true
		self._any_challenge_rewarded = true
		return rewards
	end
end
function ChallengeManager:_give_reward(reward)
	reward.rewarded = true
	local reward = #reward > 0 and loot_drop[math.random(#reward)] or reward
	if reward.choose_weapon_reward then
	else
		local entry = tweak_data:get_raw_value("blackmarket", reward.type_items, reward.item_entry)
		if entry then
			for i = 1, reward.amount or 1 do
				local global_value = reward.global_value or entry.infamous and "infamous" or entry.global_value or entry.dlc or entry.dlcs and entry.dlcs[math.random(#entry.dlcs)] or "normal"
				cat_print("jansve", "[ChallengeManager:_give_rewards]", i .. "  give", reward.type_items, reward.item_entry, global_value)
				managers.blackmarket:add_to_inventory(global_value, reward.type_items, reward.item_entry)
			end
		end
	end
	return reward
end
function ChallengeManager:save(data)
	Application:debug("[ChallengeManager:save]")
	local save_data = {}
	save_data.active_challenges = deep_clone(self._global.active_challenges)
	save_data.visited_crimenet = self._global.visited_crimenet
	data.ChallengeManager = save_data
end
function ChallengeManager:load(data, version)
	Application:debug("[ChallengeManager:load]")
	local state = data.ChallengeManager
	if state then
		self._global.visited_crimenet = state.visited_crimenet
		for key, challenge in pairs(state.active_challenges or {}) do
			if self._global.challenges[key] then
				self._global.active_challenges[key] = self._global.challenges[key]
				self._global.active_challenges[key].timestamp = challenge.timestamp
				self._global.active_challenges[key].completed = challenge.completed
				self._global.active_challenges[key].rewarded = challenge.rewarded
				self._global.active_challenges[key].objectives = challenge.objectives or self._global.active_challenges[key].objectives
				self._global.active_challenges[key].rewards = challenge.rewards or self._global.active_challenges[key].rewards
			end
		end
		self._global.validated = false
	end
end
function ChallengeManager:_load_done()
	self._load_done = true
	self:fetch_challenges()
end
