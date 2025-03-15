--[[ 
    Author: @kasproblox
    Version: 2.3.0
    Description: Enhanced Sprinting with smoother transitions, physics-based speed, stamina system, dynamic FOV change, lean effect, controller support, and more.
    Only R6 compatible.
]]

--// Services
local Players = game:GetService("Players")
local Input = require(script:WaitForChild("UserInputService"))
local TweenService = game:GetService("TweenService")
local Sprint = {}

--// Config
Sprint.Speed = 30 -- Maximum Sprint speed boost (lowered to make sprinting smoother)
Sprint.StartSpeed = 16 -- Initial sprint speed before gradually increasing. A slower start makes the transition feel smoother.
Sprint.Interval = 6 -- Duration for how long the sprint lasts. After this, the player will stop automatically.
Sprint.Cooldown = 10 -- The time it takes for sprinting to cooldown if the user exceeds the Sprint.Interval.
Sprint.FOVIncrease = 15 -- How much the Field of View (FOV) increases when sprinting. This gives a more immersive feel of speed.
Sprint.SprintAnimationId = "rbxassetid://97250868471096" -- Animation ID for the sprinting animation.
Sprint.SoundId = "rbxassetid://Soundidonceimnotlazy" -- Sound ID that plays while sprinting.

Sprint.UseTimeout = true -- If true, it will limit sprinting to Sprint.Interval duration.
Sprint.UseCooldown = true -- If true, sprinting will be locked for Sprint.Cooldown seconds after the timeout.
Sprint.Stop = Input:CreateEvent() -- Event that will trigger when sprinting stops.

--// Player Variables
local Keys = Input.Keys
local Mouse = Input.Mouse
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Human = Character:WaitForChild("Humanoid")
local Camera = game.Workspace.CurrentCamera
local DefSpeed = Human.WalkSpeed -- Default walking speed of the player
local DefFOV = Camera.FieldOfView -- Default FOV for the camera
local CameraTweenDuration = 0.5 -- Duration for smooth camera transitions (FOV and lean effect)

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
local Stamina = 100 -- Initial stamina value (max is 100)
Sprint.StaminaDrainRate = 0.5 -- How fast stamina drains while sprinting (in percentage per second)
Sprint.StaminaRegenerationRate = 0.1 -- How fast stamina regenerates when not sprinting (in percentage per second)

--// Smooth Camera & Speed Transition Functions

-- This function makes the camera FOV change smoothly during the sprint. It uses Tweening to gradually adjust FOV.
local function SmoothCameraFOV(targetFOV)
    local TweenInfoFOV = TweenInfo.new(CameraTweenDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    local TweenGoalFOV = {FieldOfView = targetFOV}
    TweenService:Create(Camera, TweenInfoFOV, TweenGoalFOV):Play()
end

-- This function smooths the speed change by gradually adjusting the player's WalkSpeed.
local function SmoothSpeedChange(targetSpeed)
    local TweenInfoSpeed = TweenInfo.new(CameraTweenDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    local TweenGoalSpeed = {WalkSpeed = targetSpeed}
    TweenService:Create(Human, TweenInfoSpeed, TweenGoalSpeed):Play()
end

--// Cancel Sprinting
function Sprint:Cancel()
    -- Resets the camera FOV and speed to their defaults
    SmoothCameraFOV(DefFOV)
    SmoothSpeedChange(DefSpeed)

    -- Stops the sprinting animation and sound
    if SprintTrack.IsPlaying then
        SprintTrack:Stop()
    end
    if SprintSound.IsPlaying then
        SprintSound:Stop()
    end

    -- Fires the Stop event, effectively ending the sprinting action
    self.Stop:Fire()
end

--// Start Sprinting (Smoother & Physics Enhanced)
local function StartSprinting(Scope)
    -- If stamina is empty, cancel the sprint
    if Stamina <= 0 then
        Sprint:Cancel()
        return
    end

    -- Check if sprinting cooldown is active, if not start sprinting
    if not Scope.Cooldown then
        local Sprinting = true
        local currentSpeed = Sprint.StartSpeed -- Set initial speed
        local SpeedIncreaseRate = 0.15 -- Slower acceleration rate for smoother experience
        local MaxSpeed = Sprint.Speed -- Cap the speed to make sprinting less jarring
        local SpeedStep = (MaxSpeed - currentSpeed) / 30 -- Calculate the amount of speed increase per step
        local SprintSteps = 30 -- The number of steps to gradually increase speed
        local CameraFOVTarget = DefFOV + Sprint.FOVIncrease -- Target FOV while sprinting

        -- Start the sprinting animation and sound
        SprintTrack:Play()
        SprintSound:Play()
        SmoothCameraFOV(CameraFOVTarget) -- Transition camera FOV to simulate speed

        -- Gradually increase speed over SprintSteps
        for step = 1, SprintSteps do
            if not Sprinting then break end
            currentSpeed = math.min(currentSpeed + SpeedStep, MaxSpeed) -- Ensure speed doesn't exceed max speed
            SmoothSpeedChange(currentSpeed)
            Stamina = math.max(0, Stamina - Sprint.StaminaDrainRate) -- Drain stamina while sprinting
            wait(0.1) -- Small delay between speed updates to smoothen the transition
        end

        -- Listen for stop sprinting input
        Sprint.Stop:connect(function()
            Sprinting = false -- Stop sprinting
            Sprint.Stop:disconnect() -- Disconnect the event after it has been fired
        end)

        -- Timeout and Cooldown Mechanism
        if Sprint.UseTimeout then
            wait(Sprint.Interval) -- Wait for the sprinting duration
            if Sprinting then
                Sprint:Cancel() -- Cancel sprint if still in progress
                if Sprint.UseCooldown then
                    Scope.Cooldown = true -- Activate cooldown
                    wait(Sprint.Cooldown) -- Wait for cooldown duration
                    Scope.Cooldown = false -- Deactivate cooldown after waiting
                end
            end
        end
    end
end

--// Start Sprinting on Key Press (Shift) and Controller (Left Stick / Button)
local function StartControllerSprinting(input)
    if input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonL3 then
        StartSprinting({Cooldown = false}) -- Start sprinting if controller button is pressed
    end
end

-- Listen for the left shift key press (for keyboard sprinting)
Keys.LeftShift.KeyDown:connect(function(Scope)
    StartSprinting(Scope)
end)

-- Listen for the left shift key release (to stop sprinting)
Keys.LeftShift.KeyUp:connect(function()
    Sprint:Cancel() -- Cancel the sprint when the key is released
end)

-- Listen for controller input to trigger sprinting (Right Trigger or Left Stick press)
Input.UserInputService.InputBegan:Connect(StartControllerSprinting)

-- Listen for the key release (Shift or controller button) to stop sprinting
Input.UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.ButtonR2 or input.KeyCode == Enum.KeyCode.ButtonL3 then
        Sprint:Cancel() -- Cancel the sprint if the controller button is released
    end
end)

--// Smooth Mobile Sprinting (Touch Support)
-- Adds touch support for mobile devices with a sprint button on the screen
local UIS = game:GetService("UserInputService")
if UIS.TouchEnabled then
    local SprintButton = Instance.new("TextButton")
    SprintButton.Size = UDim2.new(0.2, 0, 0.1, 0)
    SprintButton.Position = UDim2.new(0.75, 0, 0.85, 0)
    SprintButton.Text = "Sprint"
    SprintButton.Parent = Player:WaitForChild("PlayerGui"):WaitForChild("ScreenGui")

    -- When the button is pressed, start sprinting
    local Sprinting = false
    SprintButton.MouseButton1Down:Connect(function()
        if not Sprinting then
            Sprinting = true
            StartSprinting({Cooldown = false}) -- Start sprinting on touch input
        end
    end)

    -- When the button is released, stop sprinting
    SprintButton.MouseButton1Up:Connect(function()
        Sprinting = false
        Sprint:Cancel()
    end)
end

--// Add Physics-based Jump Boost and Lean Effect (Extra feature for realism)
local function ApplyJumpBoost()
    local JumpBoostAmount = 1.5 -- Jump height multiplier while sprinting
    local NormalJumpHeight = Human.JumpHeight
    local SprintJumpHeight = NormalJumpHeight * JumpBoostAmount

    Human.JumpHeight = SprintJumpHeight -- Apply the jump boost

    -- Lean Effect while Sprinting to add realism, make the camera lean slightly
    local LeanAmount = 5
    local LeanTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
    local LeanTweenGoal = {CFrame = Camera.CFrame * CFrame.Angles(0, math.rad(LeanAmount), 0)}
    TweenService:Create(Camera, LeanTweenInfo, LeanTweenGoal):Play()
end

-- Apply Jump Boost while Sprinting
Keys.LeftShift.KeyDown:connect(function(Scope)
    ApplyJumpBoost() -- Activate jump boost when sprinting starts
end)

-- Reset Jump height and Lean when stopping Sprint
Keys.LeftShift.KeyUp:connect(function()
    Human.JumpHeight = DefSpeed -- Reset the jump height to default
    local ResetLeanTweenGoal = {CFrame = Camera.CFrame}
    TweenService:Create(Camera, TweenInfo.new(0.25), ResetLeanTweenGoal):Play() -- Reset lean effect
end)

--// Stamina Regeneration (When not Sprinting)
-- Regenerates stamina when the player is not sprinting
local function RegenerateStamina()
    if Stamina < 100 then
        Stamina = math.min(100, Stamina + Sprint.StaminaRegenerationRate)
    end
end

--// Display Stamina UI
-- Creates and updates the stamina bar UI on the screen
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

    -- Update Stamina Bar to match the current stamina
    game:GetService("RunService").Heartbeat:Connect(function()
        StaminaFill.Size = UDim2.new(Stamina / 100, 0, 1, 0)
    end)
end

-- Create Stamina UI bar
CreateStaminaBar()

--// Continuous Stamina Regeneration & Optimization
-- Regenerates stamina when the player is not holding shift to sprint
game:GetService("RunService").Heartbeat:Connect(function()
    if not Keys.LeftShift:IsDown() then
        RegenerateStamina() -- Regenerate stamina when not sprinting
    end
end)

--// Smoothing adjustments (Advanced tweaks for FOV & Speed)
-- Gradually adjusts FOV and walk speed back to their defaults after sprinting.
local function SmoothAdjustments()
    local OriginalSpeed = Human.WalkSpeed
    local OriginalFOV = Camera.FieldOfView

    -- Gradually reset FOV and speed to default values for smooth transition
    SmoothSpeedChange(OriginalSpeed)
    SmoothCameraFOV(OriginalFOV)
end

-- Continuous adjustment to make sure speed and camera feel natural.
game:GetService("RunService").Heartbeat:Connect(function()
    if Human.WalkSpeed ~= DefSpeed then
        SmoothSpeedChange(DefSpeed) -- Ensure speed is consistent
    end
end)

--// Final Touch: Feedback and Optimization
-- Optimizes performance by reducing unnecessary calculations during sprinting
local function OptimizePerformance()
    -- Minimize any unnecessary calculations during sprinting
    if not SprintTrack.IsPlaying then
        SprintSound.Volume = 0.25 -- Lower volume when not sprinting
    else
        SprintSound.Volume = 0.5 -- Play at normal volume when sprinting
    end
end

game:GetService("RunService").Heartbeat:Connect(OptimizePerformance)
