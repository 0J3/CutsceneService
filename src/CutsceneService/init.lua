--[[

Tutorial & Documentation: devforum.roblox.com/t/718571

Version of this module: 1.1.0

Created by Vaschex

Rojo Support added by 0J3_0

]]

local module = {}
local plr = game.Players.LocalPlayer
local char = plr.Character
local controls = require(plr.PlayerScripts.PlayerModule):GetControls()
local easingFunctions = require(script.EasingFunctions)
local rootPart = char:WaitForChild("HumanoidRootPart")
local runService = game:GetService("RunService")
local StarterGui = game.StarterGui
local camera = workspace.CurrentCamera
local clock = os.clock
local playing = false

local Signal = {}
Signal.__index = Signal
Signal.ClassName = "Signal"

function Signal.new()
	local self = setmetatable({}, Signal)

	self._bindableEvent = Instance.new("BindableEvent")
	self._argData = nil
	self._argCount = nil -- Prevent edge case of :Fire("A", nil) --> "A" instead of "A", nil

	return self
end

function Signal:Fire(...)
	self._argData = {...}
	self._argCount = select("#", ...)
	self._bindableEvent:Fire()
	self._argData = nil
	self._argCount = nil
end

function Signal:Connect(handler)
	if not (type(handler) == "function") then
		error(("connect(%s)"):format(typeof(handler)), 2)
	end

	return self._bindableEvent.Event:Connect(function()
		handler(unpack(self._argData, 1, self._argCount))
	end)
end

function Signal:Wait()
	self._bindableEvent.Event:Wait()
	assert(self._argData, "Missing arg data, likely due to :TweenSize/Position corrupting threadrefs.")
	return unpack(self._argData, 1, self._argCount)
end

function Signal:Destroy()
	if self._bindableEvent then
		self._bindableEvent:Destroy()
		self._bindableEvent = nil
	end

	self._argData = nil
	self._argCount = nil
end

local function getPoints(folder) --returns point cframes in order
	folder = folder:GetChildren()
	local points = {}
	
	table.sort(folder, function(a,b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)
	
	for _,v in pairs(folder) do
		table.insert(points, v.CFrame)
	end
	
	return points
end

--This function is taken from a script by DejaVu_Loop and was optimized in Luau
type CFrameArray = { [number] : CFrame }
local function getCF(pointsTB: CFrameArray, ratio: number) : CFrame
	repeat
		local ntb : CFrameArray = {}
		for k, v in ipairs(pointsTB) do
			if k ~= 1 then
				ntb[k-1] = pointsTB[k-1]:Lerp(v, ratio)
			end
		end
		pointsTB = ntb
	until #pointsTB == 1
	return pointsTB[1]
end

local function getCoreGuisEnabled()
	return {
		Backpack = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack),
		Chat = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat),
		EmotesMenu = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu),
		Health = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Health),
		PlayerList = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
	}
end

module.Functions = {
	DisableControls = "DisableControls",
	StartFromCurrentCamera = "StartFromCurrentCamera",
	EndWithCurrentCamera = "EndWithCurrentCamera",
	EndWithDefaultCamera = "EndWithDefaultCamera",
	YieldAfterCutscene = "YieldAfterCutscene",
	FreezeCharacter = "FreezeCharacter",
	CustomCamera = "CustomCamera",
}

function module:Create(pointsTemplate, duration, ...)
	assert(pointsTemplate, "Argument 1 (points) missing or nil")
	assert(duration, "Argument 2 (duration) missing or nil")
	local cutscene = {}
	local args = {...}
	local pausedPassedTime = 0 --stores progress of cutscene when paused
	local passedTime, start, previousCameraType, customCameraEnabled, points, previousCoreGuis

	cutscene.Completed = Signal.new()
	cutscene.PlaybackState = Enum.PlaybackState.Begin
	cutscene.Progress = 0
	
	if typeof(pointsTemplate) == "Instance" then
		assert(typeof(pointsTemplate) ~= "table", "Argument 1 (points) not a table or instance")
		pointsTemplate = getPoints(pointsTemplate)
	end

	local specialFunctionsTable = {
		Start = { --this is an array so you can iterate in order
			{"CustomCamera", function(customCamera)
				assert(customCamera, "CustomCamera Argument 1 missing or nil")
				camera = customCamera
				customCameraEnabled = true
			end},
			{"DisableControls", function()
				controls:Disable()
			end},
			{"FreezeCharacter", function(stopAnimations)
				if stopAnimations == nil or stopAnimations == true then
					for _, v in pairs(char.Humanoid.Animator:GetPlayingAnimationTracks()) do
						v:Stop()
					end
				end
				rootPart.Anchored = true
			end},
			{"StartFromCurrentCamera", function()
				table.insert(points, 1, camera.CFrame)
			end},
			{"EndWithCurrentCamera", function()				
				table.insert(points, camera.CFrame)
			end},
			{"EndWithDefaultCamera", function(useCurrentZoomDistance)
				local zoomDistance = 12.5
				useCurrentZoomDistance = useCurrentZoomDistance or true
				if useCurrentZoomDistance then
					zoomDistance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
				else
					--pls help me: https://devforum.roblox.com/t/1209043
					--set camera zoomDistance to default for smooth transition when changing type to custom
					local oldMin = plr.CameraMinZoomDistance
					local oldMax = plr.CameraMaxZoomDistance
					plr.CameraMaxZoomDistance = zoomDistance
					plr.CameraMinZoomDistance = zoomDistance
					wait()
					plr.CameraMaxZoomDistance = oldMax
					plr.CameraMinZoomDistance = oldMin
				end
				local cameraOffset = CFrame.new(0, zoomDistance/2.6397830596715992, zoomDistance/1.0352760971197642)
				--Vector3.new(0, 4.7352376, 12.0740738)
				local lookAt = rootPart.CFrame.Position + Vector3.new(0, rootPart.Size.Y/2 + 0.5, 0)
				local at = (rootPart.CFrame * cameraOffset).Position

				table.insert(points,  CFrame.lookAt(at, lookAt))
			end},
		},
		End = {
			{"YieldAfterCutscene", function(waitTime)
				assert(waitTime, "YieldAfterCutscene Argument 1 missing or nil")
				wait(waitTime)
			end},
			{"DisableControls", function()
				controls:Enable(true)
			end},
			{"FreezeCharacter", function()
				rootPart.Anchored = false
			end},
			{"CustomCamera", function()
				camera.CameraType = previousCameraType
				camera = workspace.CurrentCamera
			end},
		}
	}

	local easingFunction = easingFunctions.Linear
	local arg = args[1]
	if arg and easingFunctions[arg] then
		easingFunction = easingFunctions[arg]
	elseif arg and typeof(arg) == "EnumItem" then
		local dir, style = "In", nil
		if arg.EnumType == Enum.EasingDirection then
			dir = arg.Name
		elseif arg.EnumType == Enum.EasingStyle then
			style = arg.Name
		end

		if args[2] and typeof(args[2]) == "EnumItem" then
			arg = args[2]
			if arg.EnumType == Enum.EasingDirection then
				dir = arg.Name
			elseif arg.EnumType == Enum.EasingStyle then
				style = arg.Name
			end
		end

		if style then
			assert(easingFunctions[dir..style], "EasingFunction "..dir..style.." not found")
			
			easingFunction = easingFunctions[dir..style]
		end
	end

	local function callSpecialFunctions(Type)
		for i, v in ipairs(specialFunctionsTable[Type]) do
			local idx = table.find(args, v[1])
			if idx then
				local Next = args[idx+1]
				if Next and typeof(Next) ~= "string" then --check if it is argument for the function
					if typeof(Next) == "table" then --check for multiple args in table
						v[2](unpack(Next))
					else
						v[2](Next)
					end
				else
					v[2]()
				end
			end
		end
	end

	function cutscene:Play()
		if playing == false then
			playing = true

			customCameraEnabled = false
			points = {unpack(pointsTemplate)}

			previousCoreGuis = getCoreGuisEnabled()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

			callSpecialFunctions("Start")
			
			assert(#points > 1, "More than one point is required")
			pausedPassedTime = 0
			cutscene.PlaybackState = Enum.PlaybackState.Playing
			previousCameraType = camera.CameraType
			camera.CameraType = Enum.CameraType.Scriptable
			start = clock()

			runService:BindToRenderStep("Cutscene", Enum.RenderPriority.Camera.Value, function()
				passedTime = clock() - start

				if passedTime <= duration then
					camera.CFrame = getCF(points, easingFunction(passedTime, 0, 1, duration))

					cutscene.Progress = passedTime / duration
				else
					runService:UnbindFromRenderStep("Cutscene")
					cutscene.Progress = 1

					callSpecialFunctions("End")

					playing = false
					cutscene.PlaybackState = Enum.PlaybackState.Completed
					cutscene.Completed:Fire()
					if not customCameraEnabled then
						camera.CameraType = previousCameraType
					end

					for k, v in pairs(previousCoreGuis) do --reactive previous enabled coreguis
						if v == true then
							StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[k], true)
						end
					end				
				end
			end)

		else
			warn("Error while calling :Play() - A cutscene was already playing, you can only play one at a time")
		end
	end

	function cutscene:Pause(waitTime)
		if playing then		
			runService:UnbindFromRenderStep("Cutscene")
			playing = false
			pausedPassedTime = passedTime
			cutscene.PlaybackState = Enum.PlaybackState.Paused

			if waitTime then
				wait(waitTime)
				self:Resume()
			end
		else
			warn("Error while calling :Pause() - There was no cutscene playing")
		end
	end

	function cutscene:Resume()
		if playing == false then
			if pausedPassedTime ~= 0 then
				playing = true

				cutscene.PlaybackState = Enum.PlaybackState.Playing
				camera.CameraType = Enum.CameraType.Scriptable
				start = clock() - pausedPassedTime

				runService:BindToRenderStep("Cutscene", Enum.RenderPriority.Camera.Value, function()
					passedTime = clock() - start

					if passedTime <= duration then
						camera.CFrame = getCF(points, easingFunction(passedTime, 0, 1, duration))

						cutscene.Progress = passedTime / duration
					else
						runService:UnbindFromRenderStep("Cutscene")
						cutscene.Progress = 1

						callSpecialFunctions("End")

						playing = false
						cutscene.PlaybackState = Enum.PlaybackState.Completed
						cutscene.Completed:Fire()
						if not customCameraEnabled then
							camera.CameraType = previousCameraType
						end

						for k, v in pairs(previousCoreGuis) do --reactive previous enabled coreguis
							if v == true then
								StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[k], true)
							end
						end				
					end
				end)

			else
				warn("Error while calling :Resume() - The cutscene isn't paused, use :Play() if you want to start it")
			end
		else
			warn("Error while calling :Resume() - The cutscene was already playing")
		end
	end

	function cutscene:Cancel()
		if playing then
			runService:UnbindFromRenderStep("Cutscene")
			playing = false
			camera.CameraType = previousCameraType
			cutscene.PlaybackState = Enum.PlaybackState.Cancelled
		else
			warn("Error while calling :Cancel() - There was no cutscene playing")
		end
	end

	return cutscene
end


return module
