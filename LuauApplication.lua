Luau Scripter Application.
Submission by ftwcash

Local Script:


--// Services
local Players = game:GetService("Players")
local Marketplace = game:GetService("MarketplaceService")
local Replicated = game:GetService("ReplicatedStorage")
local Input = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

--// Player + UI References
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("ScreenGui")
local frame = gui:WaitForChild("TeleportFrame")
local button = frame:WaitForChild("Teleport")
local label = button:WaitForChild("TimeLeft")

--// Config
local cfg = Replicated:WaitForChild("TPSettings")
local toggle = Replicated:WaitForChild("TPButtonToggle")

local productId = tonumber(cfg:WaitForChild("ProductID").Value)
local visibleTime = tonumber(cfg:WaitForChild("VisibleTime").Value)

--// Tweening
local tweenIn = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local tweenOut = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

local offset = 60
local originalPos = frame.Position

--// State
local id = 0
local active = false
local animate = nil

--// Init
frame.Visible = false
label.Text = ""

--// UI Animations
local function slideIn()
 	if animate then animate:Cancel() end
 	frame.Position = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale, originalPos.Y.Offset + offset)
 	frame.Visible = true
 	animate = TweenService:Create(frame, tweenIn, { Position = originalPos })
 	animate:Play()
end

local function slideOut()
 	if animate then animate:Cancel() end
 	animate = TweenService:Create(frame, tweenOut, {
 		Position = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, originalPos.Y.Scale, originalPos.Y.Offset + offset)
 	})
 	animate:Play()
 	animate.Completed:Wait()
 	frame.Visible = false
 	animate = nil
end

--// Countdown
local function countdown(tag, duration)
 	active = true
 	local timeLeft = duration
 	local lastTick = tick()

 	while tag == id and timeLeft > 0 do
 		local now = tick()
 		timeLeft -= now - lastTick
 		lastTick = now

 		if timeLeft < 0 then timeLeft = 0 end
 		label.Text = string.format("%.1f", timeLeft)

 		task.wait(0.05)
 	end

 	if tag == id then
 		slideOut()
 		label.Text = ""
 	end

 	active = false
end

--// Remote Listener
toggle.OnClientEvent:Connect(function(mode)
 	if mode == "show" then
 		if active then return end
 		id += 1
 		slideIn()
 		task.spawn(countdown, id, visibleTime)

 	elseif mode == "hide" then
 		id += 1
 		active = false
 		label.Text = ""
 		task.spawn(slideOut)
 	end
end)

--// Purchase Handling
local function purchase()
 	if frame.Visible then
 		Marketplace:PromptProductPurchase(player, productId)
 	end
end

button.MouseButton1Click:Connect(purchase)

Input.InputBegan:Connect(function(input, processed)
 	if not processed and input.KeyCode == Enum.KeyCode.Y then
 		purchase()
 	end
end)



Script (Server):



--// Services
local Players = game:GetService("Players")
local Marketplace = game:GetService("MarketplaceService")
local Replicated = game:GetService("ReplicatedStorage")

--// Config
local cfg = Replicated:WaitForChild("TPSettings")
local toggle = Replicated:WaitForChild("TPButtonToggle")

local productId = tonumber(cfg:WaitForChild("ProductID").Value)
local fallThreshold = tonumber(cfg:WaitForChild("TriggerHeight").Value)

--// State Tables
local lastTouched = {}
local lastPos = {}
local safePart = {}
local safePos = {}
local fallStart = {}
local fell = {}
local froze = {}

--// Player Handling
Players.PlayerAdded:Connect(function(player)
 	player.CharacterAdded:Connect(function(character)
 		local hrp = character:WaitForChild("HumanoidRootPart")
 		local humanoid = character:WaitForChild("Humanoid")

 		-- Track touches
 		for _, part in ipairs(character:GetChildren()) do
 			if part:IsA("BasePart") then
 				part.Touched:Connect(function(hit)
 					if hit:IsA("BasePart") and hit.CanCollide then
 						lastTouched[player.UserId] = hit
 						lastPos[player.UserId] = hrp.CFrame

 						if not froze[player.UserId] then
 							safePart[player.UserId] = hit
 							safePos[player.UserId] = hrp.CFrame
 						end

 						if fell[player.UserId] then
 							toggle:FireClient(player, "show")
 							fell[player.UserId] = false
 						end
 					end
 				end)
 			end
 		end

 		-- Track fall distance
 		humanoid.StateChanged:Connect(function(_, newState)
 			if newState == Enum.HumanoidStateType.Freefall then
 				fallStart[player.UserId] = hrp.Position.Y

 				if lastTouched[player.UserId] and not froze[player.UserId] then
 					safePart[player.UserId] = lastTouched[player.UserId]
 					safePos[player.UserId] = lastPos[player.UserId]
 				end
 			end
 		end)

 		-- Monitor fall distance
 		while character.Parent do
 			task.wait(0.2)
 			if not hrp.Parent then break end

 			local startY = fallStart[player.UserId]
 			if startY then
 				local distance = startY - hrp.Position.Y
 				if distance >= fallThreshold then
 					fell[player.UserId] = true
 					froze[player.UserId] = true
 					fallStart[player.UserId] = nil
 				end
 			end
 		end
 	end)
end)

--// Purchase Handling
Marketplace.ProcessReceipt = function(info)
 	local player = Players:GetPlayerByUserId(info.PlayerId)

 	if player and info.ProductId == productId then
 		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 		if hrp then
 			if safePart[player.UserId] then
 				local part = safePart[player.UserId]
 				local yPos = part.Position.Y + part.Size.Y / 2
 				hrp.CFrame = CFrame.new(part.Position.X, yPos + 3, part.Position.Z)
 			elseif safePos[player.UserId] then
 				hrp.CFrame = safePos[player.UserId] + Vector3.new(0, 3, 0)
 			end
 		end

 		toggle:FireClient(player, "hide")
 		froze[player.UserId] = false
 	end

 	return Enum.ProductPurchaseDecision.PurchaseGranted
end
