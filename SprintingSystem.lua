--[[ 
    Author: @kasproblox
    Version: 2.3.0
    Description: Enhanced Sprinting with smoother transitions, physics-based speed, stamina system, dynamic FOV change, lean effect, controller support, and more.
    Only R6 compatible.
]]--

--// Services
local Players = game:GetService("Players")
local Input = require(script:WaitForChild("UserInputService"))
local TweenService = game:GetService("TweenService")
local Sprint = {}

--// Config
Sprint.Speed = 30 -- Maximum Sprint speed boost (lowered)
Sprint.StartSpeed = 16 -- Initial sprint speed before gradually increasing.
Sprint.Interval = 6 -- How long the sprint lasts.
Sprint.Cooldown = 10 -- Time it takes for sprinting to cooldown if user sprints longer than Sprint.Interval.
Sprint.FOVIncrease = 15 -- How much the FOV increases when sprinting.
Sprint.SprintAnimationId = "rbxassetid://97250868471096" -- Anim ID
Sprint.SoundId = "rbxassetid://Soundidonceimnotlazy" -- Sound ID

Sprint.UseTimeout = true -- If true, make it so the user can only sprint as long as Sprint.Interval is set.
Sprint.UseCooldown = true -- If true, make it so the user has to wait Sprint.Cooldown seconds before sprinting again, if user sprints longer than Sprint.Interval.
Sprint.Stop = Input:CreateEvent() -- Stop sprinting event, don't mess with.

--// Player Variables
local Keys = Input.Keys
local Mouse = Input.Mouse
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Human = Character:WaitForChild("Humanoid")
local Camera = game.Workspace.CurrentCamera
local DefSpeed = Human.WalkSpeed
local DefFOV = Camera.FieldOfView
local CameraTweenDuration = 0.5

--// Animation Setup
local Animator = Human:FindFirstChildOfClass("Animator") or Instance.new("Animator", Human)
local SprintAnimation = Instance.new("Animation")
SprintAnimation.AnimationId = Sprint.SprintAnimationId
local SprintTrack = Animator:LoadAnimation(SprintAnimation)

--// Sound Setup
local SprintSound = Instance.new("Sound", Character)
SprintSound.SoundId = Sprint.SoundId
SprintSound.Looped = true
SprintSound.Volume = 0.5

--// Stamina System
local Stamina = 100
Sprint.StaminaDrainRate = 0.5 -- Rate at which stamina drains while sprinting
Sprint.StaminaRegenerationRate = 0.1 -- Rate at which stamina regenerates when not sprinting

--// Smooth Camera & Speed Transition
local function SmoothCameraFOV(targetFOV)
	local TweenInfoFOV = TweenInfo.new(CameraTweenDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local TweenGoalFOV = {FieldOfView = targetFOV}
	TweenService:Create(Camera, TweenInfoFOV, TweenGoalFOV):Play()
end

local function SmoothSpeedChange(targetSpeed)
	local TweenInfoSpeed = TweenInfo.new(CameraTweenDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local TweenGoalSpeed = {WalkSpeed = targetSpeed}
	TweenService:Create(Human, TweenInfoSpeed, TweenGoalSpeed):Play()
end

--// Cancel Sprinting
function Sprint:Cancel()
	SmoothCameraFOV(DefFOV)
	SmoothSpeedChange(DefSpeed)

	if SprintTrack.IsPlaying then
		SprintTrack:Stop()
	end
	if SprintSound.IsPlaying then
		SprintSound:Stop()
	end
	self.Stop:Fire()
end

--// Start Sprinting (Smoother & Physics Enhanced)
local function StartSprinting(Scope)
	if Stamina <= 0 then
		Sprint:Cancel()
		return
	end

	if not Scope.Cooldown then
		local Sprinting = true
		local currentSpeed = Sprint.StartSpeed
		local SpeedIncreaseRate = 0.15 -- Slower acceleration rate for smoother experience
		local MaxSpeed = Sprint.Speed -- Capped maximum speed for smoother sprinting
		local SpeedStep = (MaxSpeed - currentSpeed) / 30
		local SprintSteps = 30
		local CameraFOVTarget = DefFOV + Sprint.FOVIncrease

		SprintTrack:Play()
		SprintSound:Play()
		SmoothCameraFOV(CameraFOVTarget)

		-- Gradually increase speed
		for step = 1, SprintSteps do
			if not Sprinting then break end
			currentSpeed = math.min(currentSpeed + SpeedStep, MaxSpeed) -- Cap the speed
			SmoothSpeedChange(currentSpeed)
			Stamina = math.max(0, Stamina - Sprint.StaminaDrainRate)
			wait(0.1)
		end

		-- Listen for Stop Sprinting
		Sprint.Stop:connect(function()
			Sprinting = false
			Sprint.Stop:disconnect()
		end)

		-- Timeout and Cooldown Mechanism
		if Sprint.UseTimeout then
			wait(Sprint.Interval)
			if Sprinting then
				Sprint:Cancel()
				if Sprint.UseCooldown then
					Scope.Cooldown = true
					wait(Sprint.Cooldown)
					Scope.Cooldown = false
				end
			end
		end
	end
end

--// Start Sprinting on Key Press (Shift) and Controller (Left Stick / Button)
local function StartControllerSprinting(input)
	if input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonL3 then
		StartSprinting({Cooldown = false})
	end
end

Keys.LeftShift.KeyDown:connect(function(Scope)
	StartSprinting(Scope)
end)

Keys.LeftShift.KeyUp:connect(function()
	Sprint:Cancel()
end)

--// Controller Input (Right Trigger or Left Stick press)
Input.UserInputService.InputBegan:Connect(StartControllerSprinting)

--// Stop Sprinting on Key Release (Shift and Controller)
Keys.LeftShift.KeyUp:connect(function()
	Sprint:Cancel()
end)

Input.UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonL3 then
		Sprint:Cancel()
	end
end)

--// Smooth Mobile Sprinting (Touch Support)
local UIS = game:GetService("UserInputService")
if UIS.TouchEnabled then
	local SprintButton = Instance.new("TextButton")
	SprintButton.Size = UDim2.new(0.2, 0, 0.1, 0)
	SprintButton.Position = UDim2.new(0.75, 0, 0.85, 0)
	SprintButton.Text = "Sprint"
	SprintButton.Parent = Player:WaitForChild("PlayerGui"):WaitForChild("ScreenGui")

	local Sprinting = false
	SprintButton.MouseButton1Down:Connect(function()
		if not Sprinting then
			Sprinting = true
			StartSprinting({Cooldown = false})
		end
	end)

	SprintButton.MouseButton1Up:Connect(function()
		Sprinting = false
		Sprint:Cancel()
	end)
end

--// Add Physics-based Jump Boost and Lean Effect (Extra feature for realism)
local function ApplyJumpBoost()
	local JumpBoostAmount = 1.5
	local NormalJumpHeight = Human.JumpHeight
	local SprintJumpHeight = NormalJumpHeight * JumpBoostAmount

	Human.JumpHeight = SprintJumpHeight

	-- Lean Effect while Sprinting
	local LeanAmount = 5
	local LeanTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local LeanTweenGoal = {CFrame = Camera.CFrame * CFrame.Angles(0, math.rad(LeanAmount), 0)}
	TweenService:Create(Camera, LeanTweenInfo, LeanTweenGoal):Play()
end

-- Apply Jump Boost while Sprinting
Keys.LeftShift.KeyDown:connect(function(Scope)
	ApplyJumpBoost()
end)

-- Reset Jump height and Lean when stopping Sprint
Keys.LeftShift.KeyUp:connect(function()
	Human.JumpHeight = DefSpeed
	local ResetLeanTweenGoal = {CFrame = Camera.CFrame}
	TweenService:Create(Camera, TweenInfo.new(0.25), ResetLeanTweenGoal):Play()
end)

--// Stamina Regeneration (When not Sprinting)
local function RegenerateStamina()
	if Stamina < 100 then
		Stamina = math.min(100, Stamina + Sprint.StaminaRegenerationRate)
	end
end

--// Display Stamina UI
local function CreateStaminaBar()
	local StaminaBar = Instance.new("Frame")
	StaminaBar.Size = UDim2.new(0.2, 0, 0.02, 0)
	StaminaBar.Position = UDim2.new(0.4, 0, 0.9, 0)
	StaminaBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	StaminaBar.Parent = Player:WaitForChild("PlayerGui"):WaitForChild("ScreenGui")

	local StaminaFill = Instance.new("Frame")
	StaminaFill.Size = UDim2.new(Stamina / 100, 0, 1, 0)
	StaminaFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	StaminaFill.Parent = StaminaBar

	-- Update Stamina Bar
	game:GetService("RunService").Heartbeat:Connect(function()
		StaminaFill.Size = UDim2.new(Stamina / 100, 0, 1, 0)
	end)
end

-- Create Stamina UI bar
CreateStaminaBar()

--// Continuous Stamina Regeneration & Optimization
game:GetService("RunService").Heartbeat:Connect(function()
	if not Keys.LeftShift:IsDown() then
		RegenerateStamina()
	end
end)

--// Smoothing adjustments (Advanced tweaks for FOV & Speed)
local function SmoothAdjustments()
	local OriginalSpeed = Human.WalkSpeed
	local OriginalFOV = Camera.FieldOfView

	-- Gradually reset FOV and speed
	SmoothSpeedChange(OriginalSpeed)
	SmoothCameraFOV(OriginalFOV)
end

-- Continuous adjustment to make sure speed and camera feel natural.
game:GetService("RunService").Heartbeat:Connect(function()
	if Human.WalkSpeed ~= DefSpeed then
		SmoothSpeedChange(DefSpeed)
	end
end)

--// Final Touch: Feedback and Optimization
local function OptimizePerformance()
	-- Minimize any unnecessary calculations during sprinting
	if not SprintTrack.IsPlaying then
		SprintSound.Volume = 0.25
	else
		SprintSound.Volume = 0.5
	end
end

game:GetService("RunService").Heartbeat:Connect(OptimizePerformance)
