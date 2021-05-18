local module = require(game:GetService("ReplicatedStorage").Common.CutsceneService)
local func = module.Functions
local buttons = script.Parent:WaitForChild("Buttons")
local char = game:GetService("Players").LocalPlayer.Character

local cutscene1 = module:Create(workspace.Cutscene1, 10,
	Enum.EasingStyle.Quart, Enum.EasingDirection.InOut, func.StartFromCurrentCamera, func.EndWithDefaultCamera, func.DisableControls)

local cutscene2 = module:Create(workspace.Cutscene2, 5,
	Enum.EasingStyle.Sine, Enum.EasingDirection.Out, func.DisableControls, func.EndWithCurrentCamera)

local cutscene3 = module:Create(workspace.Cutscene3, 5, "OutSine")

buttons.Play1.MouseButton1Click:Connect(function()
	cutscene1:Play()
end)

buttons.Play2.MouseButton1Click:Connect(function()
	cutscene2:Play()
end)

buttons.Play3.MouseButton1Click:Connect(function()
	cutscene3:Play()
end)

buttons.Play4.MouseButton1Click:Connect(function()
	local p1 = CFrame.lookAt(char.HumanoidRootPart.Position + Vector3.new(0, 100, 0), char.HumanoidRootPart.Position)
	local p2 = CFrame.lookAt(char.HumanoidRootPart.Position + Vector3.new(0, 10, 0), char.HumanoidRootPart.Position)
	module:Create({p1, p2}, 7, "InOutSine", func.StartFromCurrentCamera, func.DisableControls):Play()
end)

buttons.Play5.MouseButton1Click:Connect(function() -- "rubberband"
	local p1 = CFrame.lookAt(char.HumanoidRootPart.Position + Vector3.new(0, 200, 0), char.HumanoidRootPart.Position)
	local p2 = CFrame.lookAt(char.HumanoidRootPart.Position + Vector3.new(0, 10, 0), char.HumanoidRootPart.Position)
	module:Create({p1, p2}, 6, "InElastic", func.DisableControls):Play()
end)