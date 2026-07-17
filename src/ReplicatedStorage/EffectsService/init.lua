--[[ EFFECTS SERVICE
		Exposes events to trigger both sound and visual effects.
		This replicates to all the players in the game.
]]

-- Requires and Services
local SoundService = game:GetService("SoundService")

-- References
local musics: SoundGroup = SoundService:FindFirstChild("Music")
local sfxs: SoundGroup = SoundService:FindFirstChild("Effects")

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

local EffectsService = {}

-- ----------------------------- ----------- SOUNDS BEHAVIOURS ----------- -----------------------------

-- Start music wheel automatically, only if this is the module used.
if game:GetService("Players").LocalPlayer then
	EffectsService.IsMusicPlaying = true
	task.spawn(function()
		while EffectsService.IsMusicPlaying do
			for _, music in ipairs(musics:GetChildren()) do
				if not music:IsA("Sound") then continue end
				if not EffectsService.IsMusicPlaying then break end
			
				music:Play()
				music.Stopped:Wait()
			end
		end
	end)
end

function EffectsService.PlaySFX(name: string, position: Vector3?)
	local SFXPrefab = sfxs:FindFirstChild(name) :: Sound
	if not SFXPrefab then warn("Sound effect missing: " .. name); return end
	
	local sfx: Sound = SFXPrefab:Clone()
	if position then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = workspace.Terrain
		
		sfx.Parent = attachment
		sfx:Play()
		
		return function() attachment:Destroy() end
	else
		sfx.Parent = SoundService
		sfx:Play()
		
		return function() sfx:Destroy() end
	end
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return EffectsService
