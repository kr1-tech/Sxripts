--!strict
-- SECTION 1: CONFIGURATION
-- Defines layout dimensions, color schemes, typography, and default operational parameters.
local CONFIG = {
	GUI_NAME = "SentinelUtilityClient_Core",
	VERSION = "2.6.0",
	HOTKEY = Enum.KeyCode.RightControl,
	DIMENSIONS = {
		WINDOW_SIZE = UDim2.new(0, 580, 0, 420),
		MINIMIZED_SIZE = UDim2.new(0, 180, 0, 36),
		MOBILE_BTN_SIZE = UDim2.new(0, 46, 0, 46),
		MIN_SCALE = 0.55,
		MAX_SCALE = 1.25,
		DEFAULT_SCALE = 1.0,
	},
	THEME = {
		BACKGROUND = Color3.fromRGB(18, 20, 26),
		SURFACE = Color3.fromRGB(25, 28, 36),
		SURFACE_ALT = Color3.fromRGB(32, 36, 47),
		INPUT_BG = Color3.fromRGB(14, 16, 21),
		BORDER = Color3.fromRGB(44, 49, 63),
		BORDER_LIGHT = Color3.fromRGB(60, 66, 84),
		TEXT_PRIMARY = Color3.fromRGB(240, 243, 248),
		TEXT_SECONDARY = Color3.fromRGB(152, 158, 175),
		TEXT_MUTED = Color3.fromRGB(102, 108, 124),
		SUCCESS = Color3.fromRGB(52, 211, 153),
		WARNING = Color3.fromRGB(251, 191, 36),
		ERROR = Color3.fromRGB(244, 63, 94),
		DEFAULT_ACCENT = Color3.fromRGB(56, 189, 248),
	},
	ACCENTS = {
		Cyan = Color3.fromRGB(56, 189, 248),
		Emerald = Color3.fromRGB(52, 211, 153),
		Violet = Color3.fromRGB(168, 85, 247),
		Amber = Color3.fromRGB(251, 191, 36),
		Rose = Color3.fromRGB(244, 63, 94),
		Slate = Color3.fromRGB(148, 163, 184),
	},
	FONTS = {
		TITLE = Enum.Font.GothamBold,
		HEADER = Enum.Font.GothamMedium,
		BODY = Enum.Font.Gotham,
		MONO = Enum.Font.Code,
	},
	AVAILABILITY = {
		LOCAL = "Client Local",
		EXPERIENCE = "Experience Dependent",
		RESTRICTED = "Restricted / FE",
		COLLISION = "FE Collision",
	},
}

-- SECTION 2: SERVICES
-- Resolves engine services and acquires player references with graceful fallbacks.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end

local detectedExecutor = "Unknown"
pcall(function()
	local anyG = _G :: any
	if typeof(anyG.identifyexecutor) == "function" then
		detectedExecutor = anyG.identifyexecutor()
	elseif typeof(identifyexecutor) == "function" then
		detectedExecutor = identifyexecutor()
	elseif typeof(getexecutorname) == "function" then
		detectedExecutor = getexecutorname()
	end
end)

local isMobileDevice = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Camera getter - dynamic to handle respawns and camera swaps
local function getCamera(): Camera
	local cam = Workspace.CurrentCamera
	if cam then
		return cam
	end
	repeat
		task.wait()
		cam = Workspace.CurrentCamera
	until cam
	return cam :: Camera
end

local function getViewportSize(): Vector2
	local cam = Workspace.CurrentCamera
	if cam and cam.ViewportSize.X > 50 and cam.ViewportSize.Y > 50 then
		return cam.ViewportSize
	end
	return Vector2.new(1280, 720)
end

-- Executor-aware protected GUI parent resolver (hardened for Delta Mobile and PC)
local function getProtectedParent(): Instance
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui and typeof(hui) == "Instance" then
			-- On mobile executors like Delta, gethui() can return a ScreenGui.
			-- Roblox engine ignores child ScreenGuis parented to an existing ScreenGui/LayerCollector!
			if not hui:IsA("ScreenGui") and not hui:IsA("LayerCollector") then
				return hui
			end
			if hui.Parent and not hui.Parent:IsA("LayerCollector") then
				return hui.Parent
			end
		end
	end

	local ok, cg = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and cg then
		local testOk = pcall(function()
			local testFolder = Instance.new("Folder")
			testFolder.Name = "SentinelTestFolder"
			testFolder.Parent = cg
			testFolder:Destroy()
		end)
		if testOk then
			return cg
		end
	end

	local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pgui then
		return pgui
	end
	return LocalPlayer:WaitForChild("PlayerGui", 5) or LocalPlayer
end

local TargetParent = getProtectedParent()

local function purgeOldGui(container: Instance?)
	if not container then return end
	local old = container:FindFirstChild(CONFIG.GUI_NAME)
	if old then
		pcall(function() old:Destroy() end)
	end
	local oldErr = container:FindFirstChild("Sentinel_Error")
	if oldErr then
		pcall(function() oldErr:Destroy() end)
	end
end

purgeOldGui(TargetParent)
pcall(function()
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then purgeOldGui(hui) end
	end
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then purgeOldGui(cg) end
	local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if pgui then purgeOldGui(pgui) end
end)

local sharedTable = _G :: any
local oldCleanup = sharedTable.SentinelUtilityCleanup
if typeof(oldCleanup) == "function" then
	pcall(oldCleanup)
	sharedTable.SentinelUtilityCleanup = nil
end

-- SECTION 3: STATE MANAGEMENT
-- Central repository for runtime variables, feature toggles, and resource tracking.
local state = {
	selectedPlayer = nil :: Player?,
	selectedPlayerName = "None",
	teleportDistance = 5,
	teleportOffset = "Behind",
	previousPosition = nil :: CFrame?,
	isFollowing = false,
	followDistance = 6,
	walkSpeed = 16,
	defaultWalkSpeed = 16,
	jumpPower = 50,
	defaultJumpPower = 50,
	jumpHeight = 7.2,
	defaultJumpHeight = 7.2,
	isFlying = false,
	flySpeed = 50,
	isNoclipping = false,
	isCharacterTransparent = false,
	characterTransparency = 0.5,
	originalTransparencies = {} :: { [Instance]: number },
	isHighlightActive = false,
	highlightInstance = nil :: Highlight?,
	currentFov = 70,
	defaultFov = 70,
	isScreenEffectActive = false,
	screenEffectInstance = nil :: ColorCorrectionEffect?,
	sandboxObject = nil :: Part?,
	sandboxImpulse = 35,
	flingPower = 15000,
	flingDuration = 1.5,
	isFlinging = false,
	isTouchFling = false,
	isOrbiting = false,
	orbitRadius = 6,
	orbitSpeed = 3,
	isHeadSitting = false,
	accentColor = CONFIG.THEME.DEFAULT_ACCENT,
	activeTab = "PlayerTools",
	guiScale = CONFIG.DIMENSIONS.DEFAULT_SCALE,
	windowOpacity = 0,
	animationsEnabled = true,
	rememberSession = true,
	isMinimized = false,
	isMobile = isMobileDevice,
	showMobileButton = UserInputService.TouchEnabled,
	manualScaleOverride = false,
	statusMessage = "System initialized and ready.",
	statusType = "Normal",
}

task.spawn(function()
	local cam = getCamera()
	state.currentFov = cam.FieldOfView
	state.defaultFov = cam.FieldOfView
end)

-- Resource tracking tables for deterministic cleanup.
local trackedConnections: { RBXScriptConnection } = {}
local trackedInstances: { Instance } = {}
local registeredAccentElements: { { instance: any, prop: string } } = {}

local function trackConnection(conn: RBXScriptConnection): RBXScriptConnection
	table.insert(trackedConnections, conn)
	return conn
end

local function trackInstance<T>(inst: T): T
	table.insert(trackedInstances, inst :: any)
	return inst
end

-- Wrap Sections 4-8 in a pcall to guarantee visibility of any build errors
local BUILD_OK, BUILD_ERR = pcall(function()

-- SECTION 4: GUI CONSTRUCTION & COMPONENT HELPERS
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = CONFIG.GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 10000
ScreenGui.IgnoreGuiInset = true -- Critical for accurate screen centering and notch handling on mobile

if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
	pcall(syn.protect_gui, ScreenGui)
end

ScreenGui.Parent = TargetParent

local function computeAutoFitScale(): number
	local vp = getViewportSize()
	local maxW = vp.X - 24
	local maxH = vp.Y - 28
	local baseW = 580
	local baseH = 420

	local scaleX = maxW / baseW
	local scaleY = maxH / baseH
	local fitScale = math.min(scaleX, scaleY)

	if fitScale < 1.0 or isMobileDevice or vp.Y < 500 or vp.X < 650 then
		return math.clamp(fitScale * 0.95, 0.52, 1.0)
	end
	return 1.0
end

local initialScale = computeAutoFitScale()
state.guiScale = initialScale

local GuiScale = Instance.new("UIScale")
GuiScale.Scale = state.guiScale
GuiScale.Parent = ScreenGui

local function animateTween(inst: Instance, duration: number, props: { [string]: any })
	if state.animationsEnabled then
		local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(inst, info, props):Play()
	else
		for k, v in pairs(props) do
			(inst :: any)[k] = v
		end
	end
end

local function createCorner(parent: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function createStroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local function registerAccent(inst: any, propName: string)
	table.insert(registeredAccentElements, { instance = inst, prop = propName })
	inst[propName] = state.accentColor
end

local function updateAccentColor(newColor: Color3)
	state.accentColor = newColor
	for _, entry in ipairs(registeredAccentElements) do
		if entry.instance and entry.instance.Parent then
			entry.instance[entry.prop] = newColor
		end
	end
	if state.highlightInstance then
		state.highlightInstance.FillColor = newColor
	end
	if state.sandboxObject then
		state.sandboxObject.Color = newColor
	end
end

-- Construct Primary Containers
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = CONFIG.DIMENSIONS.WINDOW_SIZE
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = CONFIG.THEME.BACKGROUND
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = false
MainFrame.Active = true -- Blocks touch fallthrough to game world
MainFrame.Parent = ScreenGui
createCorner(MainFrame, 10)
createStroke(MainFrame, CONFIG.THEME.BORDER, 1)

local MinimizedPill = Instance.new("Frame")
MinimizedPill.Name = "MinimizedPill"
MinimizedPill.Size = CONFIG.DIMENSIONS.MINIMIZED_SIZE
MinimizedPill.Position = UDim2.new(0.5, 0, 0.08, 0)
MinimizedPill.AnchorPoint = Vector2.new(0.5, 0)
MinimizedPill.BackgroundColor3 = CONFIG.THEME.SURFACE
MinimizedPill.BorderSizePixel = 0
MinimizedPill.Active = true
MinimizedPill.Visible = false
MinimizedPill.Parent = ScreenGui
createCorner(MinimizedPill, 18)
local pillStroke = createStroke(MinimizedPill, CONFIG.THEME.BORDER, 1)
registerAccent(pillStroke, "Color")

local PillRestoreButton = Instance.new("TextButton")
PillRestoreButton.Size = UDim2.new(1, 0, 1, 0)
PillRestoreButton.BackgroundTransparency = 1
PillRestoreButton.Font = CONFIG.FONTS.HEADER
PillRestoreButton.Text = "Sentinel | Restore"
PillRestoreButton.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
PillRestoreButton.TextSize = 13
PillRestoreButton.Parent = MinimizedPill

local MobileToggleButton = Instance.new("TextButton")
MobileToggleButton.Name = "MobileToggleButton"
MobileToggleButton.Size = CONFIG.DIMENSIONS.MOBILE_BTN_SIZE
MobileToggleButton.Position = UDim2.new(0, 16, 0.45, 0)
MobileToggleButton.AnchorPoint = Vector2.new(0, 0.5)
MobileToggleButton.BackgroundColor3 = CONFIG.THEME.SURFACE
MobileToggleButton.BorderSizePixel = 0
MobileToggleButton.Font = CONFIG.FONTS.TITLE
MobileToggleButton.Text = "S"
MobileToggleButton.TextColor3 = state.accentColor
MobileToggleButton.TextSize = 22
MobileToggleButton.AutoButtonColor = false
MobileToggleButton.Active = true
MobileToggleButton.ZIndex = 250
MobileToggleButton.Visible = state.showMobileButton
MobileToggleButton.Parent = ScreenGui
createCorner(MobileToggleButton, 23)
local mobileStroke = createStroke(MobileToggleButton, state.accentColor, 1.5)
registerAccent(mobileStroke, "Color")
registerAccent(MobileToggleButton, "TextColor3")

local function clampMainFrameToBounds()
	local vp = getViewportSize()
	local scale = GuiScale.Scale
	if scale <= 0.1 then scale = 1 end

	local halfW = (MainFrame.AbsoluteSize.X / 2)
	local halfH = (MainFrame.AbsoluteSize.Y / 2)

	local currentCenterX = (vp.X * 0.5) + (MainFrame.Position.X.Offset * scale)
	local currentCenterY = (vp.Y * 0.5) + (MainFrame.Position.Y.Offset * scale)

	local minX = halfW + 4
	local maxX = math.max(vp.X - halfW - 4, minX)
	local minY = halfH + 4
	local maxY = math.max(vp.Y - halfH - 4, minY)

	local clampedCenterX = math.clamp(currentCenterX, minX, maxX)
	local clampedCenterY = math.clamp(currentCenterY, minY, maxY)

	local clampedOffsetX = (clampedCenterX - (vp.X * 0.5)) / scale
	local clampedOffsetY = (clampedCenterY - (vp.Y * 0.5)) / scale

	MainFrame.Position = UDim2.new(0.5, clampedOffsetX, 0.5, clampedOffsetY)
end

local function recenterMainFrame()
	MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	if not state.manualScaleOverride then
		local newScale = computeAutoFitScale()
		state.guiScale = newScale
		GuiScale.Scale = newScale
	end
	updateStatusBar("Interface centered to screen.", "Normal")
end

-- Title Bar Construction
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 38)
TitleBar.BackgroundColor3 = CONFIG.THEME.INPUT_BG
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
createCorner(TitleBar, 10)

local TitleBarCover = Instance.new("Frame")
TitleBarCover.Size = UDim2.new(1, 0, 0, 8)
TitleBarCover.Position = UDim2.new(0, 0, 1, -8)
TitleBarCover.BackgroundColor3 = CONFIG.THEME.INPUT_BG
TitleBarCover.BorderSizePixel = 0
TitleBarCover.Parent = TitleBar

local AccentBar = Instance.new("Frame")
AccentBar.Name = "AccentBar"
AccentBar.Size = UDim2.new(1, 0, 0, 2)
AccentBar.Position = UDim2.new(0, 0, 1, -2)
AccentBar.BorderSizePixel = 0
AccentBar.Parent = TitleBar
registerAccent(AccentBar, "BackgroundColor3")

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Text = "SENTINEL"
TitleLabel.Font = CONFIG.FONTS.TITLE
TitleLabel.TextSize = 15
TitleLabel.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.BackgroundTransparency = 1
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.Size = UDim2.new(0, 80, 1, 0)
TitleLabel.Parent = TitleBar

local TagLabel = Instance.new("TextLabel")
TagLabel.Text = string.format("CLIENT UTILITY [FE] | %s", detectedExecutor ~= "Unknown" and detectedExecutor or (isMobileDevice and "Mobile" or "Desktop"))
TagLabel.Font = CONFIG.FONTS.MONO
TagLabel.TextSize = 10
TagLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
TagLabel.TextXAlignment = Enum.TextXAlignment.Left
TagLabel.BackgroundTransparency = 1
TagLabel.Position = UDim2.new(0, 96, 0, 0)
TagLabel.Size = UDim2.new(0, 160, 1, 0)
TagLabel.Parent = TitleBar

local TitleDragHandle = Instance.new("Frame")
TitleDragHandle.Name = "DragHandle"
TitleDragHandle.Size = UDim2.new(1, -76, 1, 0)
TitleDragHandle.Position = UDim2.new(0, 0, 0, 0)
TitleDragHandle.BackgroundTransparency = 1
TitleDragHandle.Parent = TitleBar

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Size = UDim2.new(0, 28, 0, 26)
MinimizeButton.Position = UDim2.new(1, -64, 0, 6)
MinimizeButton.BackgroundColor3 = CONFIG.THEME.SURFACE
MinimizeButton.Font = CONFIG.FONTS.HEADER
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
MinimizeButton.TextSize = 14
MinimizeButton.Parent = TitleBar
createCorner(MinimizeButton, 6)
createStroke(MinimizeButton, CONFIG.THEME.BORDER, 1)

local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 28, 0, 26)
CloseButton.Position = UDim2.new(1, -34, 0, 6)
CloseButton.BackgroundColor3 = CONFIG.THEME.SURFACE
CloseButton.Font = CONFIG.FONTS.HEADER
CloseButton.Text = "X"
CloseButton.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
CloseButton.TextSize = 12
CloseButton.Parent = TitleBar
createCorner(CloseButton, 6)
createStroke(CloseButton, CONFIG.THEME.BORDER, 1)

-- Tab Bar Construction (ScrollingFrame for mobile screens)
local TabBar = Instance.new("ScrollingFrame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, -24, 0, 32)
TabBar.Position = UDim2.new(0, 12, 0, 46)
TabBar.BackgroundColor3 = CONFIG.THEME.INPUT_BG
TabBar.BorderSizePixel = 0
TabBar.ScrollBarThickness = 0
TabBar.ScrollingDirection = Enum.ScrollingDirection.X
TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
TabBar.Parent = MainFrame
createCorner(TabBar, 6)
createStroke(TabBar, CONFIG.THEME.BORDER, 1)

local TabBarLayout = Instance.new("UIListLayout")
TabBarLayout.FillDirection = Enum.FillDirection.Horizontal
TabBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
TabBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabBarLayout.Padding = UDim.new(0, 4)
TabBarLayout.Parent = TabBar

local TabBarPadding = Instance.new("UIPadding")
TabBarPadding.PaddingLeft = UDim.new(0, 4)
TabBarPadding.PaddingRight = UDim.new(0, 4)
TabBarPadding.Parent = TabBar

-- Content Viewport
local ContentViewport = Instance.new("Frame")
ContentViewport.Name = "ContentViewport"
ContentViewport.Size = UDim2.new(1, -24, 1, -118)
ContentViewport.Position = UDim2.new(0, 12, 0, 84)
ContentViewport.BackgroundTransparency = 1
ContentViewport.Parent = MainFrame

-- Status Bar Construction
local StatusBar = Instance.new("Frame")
StatusBar.Name = "StatusBar"
StatusBar.Size = UDim2.new(1, 0, 0, 28)
StatusBar.Position = UDim2.new(0, 0, 1, -28)
StatusBar.BackgroundColor3 = CONFIG.THEME.INPUT_BG
StatusBar.BorderSizePixel = 0
StatusBar.Parent = MainFrame
createCorner(StatusBar, 10)

local StatusBarCover = Instance.new("Frame")
StatusBarCover.Size = UDim2.new(1, 0, 0, 8)
StatusBarCover.Position = UDim2.new(0, 0, 0, 0)
StatusBarCover.BackgroundColor3 = CONFIG.THEME.INPUT_BG
StatusBarCover.BorderSizePixel = 0
StatusBarCover.Parent = StatusBar

local StatusSeparator = Instance.new("Frame")
StatusSeparator.Size = UDim2.new(1, 0, 0, 1)
StatusSeparator.Position = UDim2.new(0, 0, 0, 0)
StatusSeparator.BackgroundColor3 = CONFIG.THEME.BORDER
StatusSeparator.BorderSizePixel = 0
StatusSeparator.Parent = StatusBar

local StatusTargetLabel = Instance.new("TextLabel")
StatusTargetLabel.Name = "StatusTarget"
StatusTargetLabel.Size = UDim2.new(0, 260, 1, 0)
StatusTargetLabel.Position = UDim2.new(0, 12, 0, 0)
StatusTargetLabel.BackgroundTransparency = 1
StatusTargetLabel.Font = CONFIG.FONTS.MONO
StatusTargetLabel.Text = "Target: None | Active Features: 0"
StatusTargetLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
StatusTargetLabel.TextSize = 11
StatusTargetLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusTargetLabel.Parent = StatusBar

local StatusFeedbackLabel = Instance.new("TextLabel")
StatusFeedbackLabel.Name = "StatusFeedback"
StatusFeedbackLabel.Size = UDim2.new(1, -280, 1, 0)
StatusFeedbackLabel.Position = UDim2.new(0, 270, 0, 0)
StatusFeedbackLabel.BackgroundTransparency = 1
StatusFeedbackLabel.Font = CONFIG.FONTS.BODY
StatusFeedbackLabel.Text = state.statusMessage
StatusFeedbackLabel.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
StatusFeedbackLabel.TextSize = 11
StatusFeedbackLabel.TextXAlignment = Enum.TextXAlignment.Right
StatusFeedbackLabel.Parent = StatusBar

local function countActiveFeatures(): number
	local count = 0
	if state.isFollowing then count += 1 end
	if state.isFlying then count += 1 end
	if state.isNoclipping then count += 1 end
	if state.isCharacterTransparent then count += 1 end
	if state.isHighlightActive then count += 1 end
	if state.isScreenEffectActive then count += 1 end
	if state.isFlinging then count += 1 end
	if state.isTouchFling then count += 1 end
	if state.isOrbiting then count += 1 end
	if state.isHeadSitting then count += 1 end
	if state.currentFov ~= state.defaultFov then count += 1 end
	if state.walkSpeed ~= state.defaultWalkSpeed then count += 1 end
	return count
end

local function updateStatusBar(msg: string?, statusType: string?)
	if msg then
		state.statusMessage = msg
		state.statusType = statusType or "Normal"
	end
	local color = CONFIG.THEME.TEXT_SECONDARY
	if state.statusType == "Success" then
		color = CONFIG.THEME.SUCCESS
	elseif state.statusType == "Warning" then
		color = CONFIG.THEME.WARNING
	elseif state.statusType == "Error" then
		color = CONFIG.THEME.ERROR
	end
	StatusFeedbackLabel.Text = state.statusMessage
	StatusFeedbackLabel.TextColor3 = color
	StatusTargetLabel.Text = string.format("Target: %s | Active: %d", state.selectedPlayerName, countActiveFeatures())
end

local function enableDragging(frame: GuiObject, handle: GuiObject)
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart = Vector2.zero
	local startPos = frame.Position

	trackConnection(handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragInput = input
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPos = frame.Position

			local endedConn: RBXScriptConnection
			endedConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					dragInput = nil
					endedConn:Disconnect()
				end
			end)
		end
	end))

	trackConnection(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			local scale = GuiScale.Scale
			if scale <= 0.1 then scale = 1 end

			local newOffsetX = startPos.X.Offset + (delta.X / scale)
			local newOffsetY = startPos.Y.Offset + (delta.Y / scale)

			local vp = getViewportSize()
			local halfW = (frame.AbsoluteSize.X / 2)
			local halfH = (frame.AbsoluteSize.Y / 2)

			local currentCenterX = (vp.X * 0.5) + (newOffsetX * scale)
			local currentCenterY = (vp.Y * 0.5) + (newOffsetY * scale)

			local minX = halfW + 4
			local maxX = math.max(vp.X - halfW - 4, minX)
			local minY = halfH + 4
			local maxY = math.max(vp.Y - halfH - 4, minY)

			local clampedCenterX = math.clamp(currentCenterX, minX, maxX)
			local clampedCenterY = math.clamp(currentCenterY, minY, maxY)

			local clampedOffsetX = (clampedCenterX - (vp.X * 0.5)) / scale
			local clampedOffsetY = (clampedCenterY - (vp.Y * 0.5)) / scale

			frame.Position = UDim2.new(startPos.X.Scale, clampedOffsetX, startPos.Y.Scale, clampedOffsetY)
		end
	end))

	trackConnection(UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = false
			dragInput = nil
		end
	end))
end

enableDragging(MainFrame, TitleDragHandle)
enableDragging(MinimizedPill, MinimizedPill)

local mobileBtnDragging = false
local mobileBtnStartPos = Vector2.zero
local mobileBtnStartGuiPos = UDim2.new()
local mobileBtnDragInput: InputObject? = nil
local mobileBtnMoved = false

trackConnection(MobileToggleButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		mobileBtnDragging = true
		mobileBtnMoved = false
		mobileBtnDragInput = input
		mobileBtnStartPos = Vector2.new(input.Position.X, input.Position.Y)
		mobileBtnStartGuiPos = MobileToggleButton.Position

		local endedConn: RBXScriptConnection
		endedConn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				mobileBtnDragging = false
				mobileBtnDragInput = nil
				endedConn:Disconnect()
			end
		end)
	end
end))

trackConnection(UserInputService.InputChanged:Connect(function(input)
	if mobileBtnDragging and (input == mobileBtnDragInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
		local cur = Vector2.new(input.Position.X, input.Position.Y)
		local delta = cur - mobileBtnStartPos
		if delta.Magnitude > 6 then
			mobileBtnMoved = true
		end
		local vp = getViewportSize()
		local newX = math.clamp(mobileBtnStartGuiPos.X.Offset + delta.X, 4, vp.X - 52)
		local newY = math.clamp(mobileBtnStartGuiPos.Y.Offset + delta.Y, 4, vp.Y - 52)
		MobileToggleButton.Position = UDim2.new(mobileBtnStartGuiPos.X.Scale, newX, mobileBtnStartGuiPos.Y.Scale, newY)
	end
end))

trackConnection(UserInputService.InputEnded:Connect(function(input)
	if mobileBtnDragging and (input == mobileBtnDragInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
		mobileBtnDragging = false
		mobileBtnDragInput = nil
		if not mobileBtnMoved then
			toggleVisibility()
		end
	end
end))

local lastTitleTapTime = 0
trackConnection(TitleDragHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local now = os.clock()
		if now - lastTitleTapTime < 0.35 then
			recenterMainFrame()
		end
		lastTitleTapTime = now
	end
end))

local function createBadge(parent: Instance, tagType: string): TextLabel
	local badge = Instance.new("TextLabel")
	badge.Size = UDim2.new(0, 105, 0, 18)
	badge.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	badge.Font = CONFIG.FONTS.MONO
	badge.TextSize = 9
	badge.Parent = parent
	createCorner(badge, 4)

	local stroke = createStroke(badge, CONFIG.THEME.BORDER, 1)
	if tagType == CONFIG.AVAILABILITY.LOCAL then
		badge.Text = "[Client Local]"
		badge.TextColor3 = CONFIG.THEME.SUCCESS
		stroke.Color = CONFIG.THEME.SUCCESS
	elseif tagType == CONFIG.AVAILABILITY.EXPERIENCE then
		badge.Text = "[Exp Dependent]"
		badge.TextColor3 = CONFIG.THEME.WARNING
		stroke.Color = CONFIG.THEME.WARNING
	elseif tagType == CONFIG.AVAILABILITY.COLLISION then
		badge.Text = "[FE Collision]"
		badge.TextColor3 = state.accentColor
		stroke.Color = state.accentColor
	else
		badge.Text = "[Restricted]"
		badge.TextColor3 = CONFIG.THEME.ERROR
		stroke.Color = CONFIG.THEME.ERROR
	end
	return badge
end

local function createCard(parent: Instance, title: string, subtitle: string?): (Frame, Frame)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = CONFIG.THEME.SURFACE
	card.BorderSizePixel = 0
	card.Parent = parent
	createCorner(card, 8)
	createStroke(card, CONFIG.THEME.BORDER, 1)

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0, 10)
	cardPadding.PaddingBottom = UDim.new(0, 10)
	cardPadding.PaddingLeft = UDim.new(0, 12)
	cardPadding.PaddingRight = UDim.new(0, 12)
	cardPadding.Parent = card

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Padding = UDim.new(0, 8)
	cardLayout.Parent = card

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 20)
	header.BackgroundTransparency = 1
	header.LayoutOrder = 1
	header.Parent = card

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = CONFIG.FONTS.HEADER
	titleLabel.Text = title
	titleLabel.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = header

	if subtitle then
		titleLabel.Size = UDim2.new(1, 0, 0, 14)
		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(1, 0, 0, 12)
		subLabel.Position = UDim2.new(0, 0, 0, 14)
		subLabel.BackgroundTransparency = 1
		subLabel.Font = CONFIG.FONTS.BODY
		subLabel.Text = subtitle
		subLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
		subLabel.TextSize = 10
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.Parent = header
		header.Size = UDim2.new(1, 0, 0, 28)
	end

	local content = Instance.new("Frame")
	content.Name = "CardContent"
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.LayoutOrder = 2
	content.Parent = card

	local innerLayout = Instance.new("UIListLayout")
	innerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	innerLayout.Padding = UDim.new(0, 6)
	innerLayout.Parent = content

	return card, content
end

local function createActionButton(parent: Instance, labelText: string, tagType: string, callback: () -> ()): TextButton
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 32)
	container.BackgroundTransparency = 1
	container.Parent = parent

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -112, 1, 0)
	btn.BackgroundColor3 = CONFIG.THEME.SURFACE_ALT
	btn.Font = CONFIG.FONTS.HEADER
	btn.Text = labelText
	btn.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	btn.TextSize = 12
	btn.Parent = container
	createCorner(btn, 6)
	createStroke(btn, CONFIG.THEME.BORDER, 1)

	local badge = createBadge(container, tagType)
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.new(1, 0, 0.5, 0)

	trackConnection(btn.MouseEnter:Connect(function()
		animateTween(btn, 0.15, { BackgroundColor3 = CONFIG.THEME.BORDER })
	end))
	trackConnection(btn.MouseLeave:Connect(function()
		animateTween(btn, 0.15, { BackgroundColor3 = CONFIG.THEME.SURFACE_ALT })
	end))
	trackConnection(btn.Activated:Connect(callback))

	return btn
end

local function createToggle(parent: Instance, labelText: string, tagType: string, initialValue: boolean, callback: (boolean) -> ()): (Frame, (boolean) -> ())
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 32)
	container.BackgroundTransparency = 1
	container.Parent = parent

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -170, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = CONFIG.FONTS.BODY
	title.Text = labelText
	title.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = container

	local badge = createBadge(container, tagType)
	badge.Position = UDim2.new(1, -160, 0.5, -9)

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0, 44, 0, 22)
	toggleBtn.AnchorPoint = Vector2.new(1, 0.5)
	toggleBtn.Position = UDim2.new(1, 0, 0.5, 0)
	toggleBtn.BackgroundColor3 = initialValue and state.accentColor or CONFIG.THEME.INPUT_BG
	toggleBtn.Text = ""
	toggleBtn.Parent = container
	createCorner(toggleBtn, 11)
	createStroke(toggleBtn, CONFIG.THEME.BORDER, 1)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Position = initialValue and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.Parent = toggleBtn
	createCorner(knob, 8)

	local isEnabled = initialValue

	local function setVisualState(value: boolean)
		isEnabled = value
		local targetColor = isEnabled and state.accentColor or CONFIG.THEME.INPUT_BG
		local targetPos = isEnabled and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		animateTween(toggleBtn, 0.15, { BackgroundColor3 = targetColor })
		animateTween(knob, 0.15, { Position = targetPos })
	end

	trackConnection(toggleBtn.Activated:Connect(function()
		local nextState = not isEnabled
		setVisualState(nextState)
		callback(nextState)
	end))

	return container, setVisualState
end

local function createSlider(
	parent: Instance,
	labelText: string,
	min: number,
	max: number,
	initialValue: number,
	step: number,
	unit: string,
	callback: (number) -> ()
): (Frame, (number) -> ())
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 48)
	container.BackgroundTransparency = 1
	container.Parent = parent

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 18)
	header.BackgroundTransparency = 1
	header.Parent = container

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0.7, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = CONFIG.FONTS.BODY
	title.Text = labelText
	title.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.3, 0, 1, 0)
	valueLabel.Position = UDim2.new(0.7, 0, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Font = CONFIG.FONTS.MONO
	valueLabel.Text = string.format("%.1f %s", initialValue, unit)
	valueLabel.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
	valueLabel.TextSize = 11
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Parent = header

	local sliderTrack = Instance.new("Frame")
	sliderTrack.Size = UDim2.new(1, 0, 0, 8)
	sliderTrack.Position = UDim2.new(0, 0, 0, 26)
	sliderTrack.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	sliderTrack.BorderSizePixel = 0
	sliderTrack.Parent = container
	createCorner(sliderTrack, 4)
	createStroke(sliderTrack, CONFIG.THEME.BORDER, 1)

	local sliderFill = Instance.new("Frame")
	local ratio = math.clamp((initialValue - min) / (max - min), 0, 1)
	sliderFill.Size = UDim2.new(ratio, 0, 1, 0)
	sliderFill.BackgroundColor3 = state.accentColor
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderTrack
	createCorner(sliderFill, 4)
	registerAccent(sliderFill, "BackgroundColor3")

	local sliderThumb = Instance.new("TextButton")
	sliderThumb.Size = UDim2.new(0, 16, 0, 16)
	sliderThumb.AnchorPoint = Vector2.new(0.5, 0.5)
	sliderThumb.Position = UDim2.new(ratio, 0, 0.5, 0)
	sliderThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sliderThumb.Text = ""
	sliderThumb.Parent = sliderTrack
	createCorner(sliderThumb, 8)
	createStroke(sliderThumb, CONFIG.THEME.BORDER, 1)

	local isSliding = false
	local currentValue = initialValue

	local function updateFromPosition(inputX: number)
		local trackAbsPos = sliderTrack.AbsolutePosition.X
		local trackAbsSize = sliderTrack.AbsoluteSize.X
		local newRatio = math.clamp((inputX - trackAbsPos) / trackAbsSize, 0, 1)
		local rawValue = min + (max - min) * newRatio
		local steppedValue = math.floor(rawValue / step + 0.5) * step
		currentValue = math.clamp(steppedValue, min, max)

		local displayRatio = (currentValue - min) / (max - min)
		sliderFill.Size = UDim2.new(displayRatio, 0, 1, 0)
		sliderThumb.Position = UDim2.new(displayRatio, 0, 0.5, 0)
		valueLabel.Text = string.format("%.1f %s", currentValue, unit)
		callback(currentValue)
	end

	local function setValue(val: number)
		currentValue = math.clamp(val, min, max)
		local displayRatio = (currentValue - min) / (max - min)
		sliderFill.Size = UDim2.new(displayRatio, 0, 1, 0)
		sliderThumb.Position = UDim2.new(displayRatio, 0, 0.5, 0)
		valueLabel.Text = string.format("%.1f %s", currentValue, unit)
	end

	trackConnection(sliderThumb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isSliding = true
			local conn: RBXScriptConnection
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					isSliding = false
					conn:Disconnect()
				end
			end)
		end
	end))

	trackConnection(sliderTrack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isSliding = true
			updateFromPosition(input.Position.X)
			local conn: RBXScriptConnection
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					isSliding = false
					conn:Disconnect()
				end
			end)
		end
	end))

	trackConnection(UserInputService.InputChanged:Connect(function(input)
		if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromPosition(input.Position.X)
		end
	end))

	return container, setValue
end

-- Tab navigation and content visibility logic:
local pages: { [string]: Frame } = {}
local tabButtons: { [string]: TextButton } = {}

local function createPage(id: string): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.Name = "Page_" .. id
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 4
	page.ScrollBarImageColor3 = CONFIG.THEME.BORDER
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = ContentViewport

	local pageLayout = Instance.new("UIListLayout")
	pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pageLayout.Padding = UDim.new(0, 10)
	pageLayout.Parent = page

	local pagePadding = Instance.new("UIPadding")
	pagePadding.PaddingRight = UDim.new(0, 6)
	pagePadding.Parent = page

	pages[id] = page :: any
	return page
end

local function switchTab(id: string)
	state.activeTab = id
	for pageId, pageFrame in pairs(pages) do
		pageFrame.Visible = (pageId == id)
	end
	for tabId, btn in pairs(tabButtons) do
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if tabId == id then
			btn.BackgroundColor3 = CONFIG.THEME.SURFACE
			btn.TextColor3 = state.accentColor
			if stroke then stroke.Color = state.accentColor end
		else
			btn.BackgroundColor3 = CONFIG.THEME.INPUT_BG
			btn.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
			if stroke then stroke.Color = CONFIG.THEME.BORDER end
		end
	end
end

local function createTabButton(id: string, label: string)
	local btn = Instance.new("TextButton")
	btn.Name = "Tab_" .. id
	btn.Size = UDim2.new(0, 84, 1, -8)
	btn.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	btn.Font = CONFIG.FONTS.HEADER
	btn.Text = label
	btn.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
	btn.TextSize = 11
	btn.Parent = TabBar
	createCorner(btn, 4)
	createStroke(btn, CONFIG.THEME.BORDER, 1)

	tabButtons[id] = btn
	trackConnection(btn.Activated:Connect(function()
		switchTab(id)
	end))
end

createTabButton("PlayerTools", "Players")
createTabButton("Troll", "Troll [FE]")
createTabButton("Movement", "Movement")
createTabButton("Visuals", "Visuals")
createTabButton("Settings", "Settings")
createTabButton("Info", "Info")

local PagePlayerTools = createPage("PlayerTools")
local PageTroll = createPage("Troll")
local PageMovement = createPage("Movement")
local PageVisuals = createPage("Visuals")
local PageSettings = createPage("Settings")
local PageInfo = createPage("Info")

-- SECTION 5: PLAYER SELECTION & INSPECTION LOGIC
local PlayerSplitFrame = Instance.new("Frame")
PlayerSplitFrame.Size = UDim2.new(1, 0, 0, 310)
PlayerSplitFrame.BackgroundTransparency = 1
PlayerSplitFrame.Parent = PagePlayerTools

local SplitLayout = Instance.new("UIListLayout")
SplitLayout.FillDirection = Enum.FillDirection.Horizontal
SplitLayout.Padding = UDim.new(0, 10)
SplitLayout.Parent = PlayerSplitFrame

local LeftListContainer = Instance.new("Frame")
LeftListContainer.Size = UDim2.new(0, 200, 1, 0)
LeftListContainer.BackgroundColor3 = CONFIG.THEME.SURFACE
LeftListContainer.BorderSizePixel = 0
LeftListContainer.Parent = PlayerSplitFrame
createCorner(LeftListContainer, 8)
createStroke(LeftListContainer, CONFIG.THEME.BORDER, 1)

local LeftPadding = Instance.new("UIPadding")
LeftPadding.PaddingTop = UDim.new(0, 8)
LeftPadding.PaddingBottom = UDim.new(0, 8)
LeftPadding.PaddingLeft = UDim.new(0, 8)
LeftPadding.PaddingRight = UDim.new(0, 8)
LeftPadding.Parent = LeftListContainer

local LeftLayout = Instance.new("UIListLayout")
LeftLayout.SortOrder = Enum.SortOrder.LayoutOrder
LeftLayout.Padding = UDim.new(0, 6)
LeftLayout.Parent = LeftListContainer

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, 0, 0, 26)
SearchBox.BackgroundColor3 = CONFIG.THEME.INPUT_BG
SearchBox.Font = CONFIG.FONTS.BODY
SearchBox.PlaceholderColor3 = CONFIG.THEME.TEXT_MUTED
SearchBox.PlaceholderText = "Search player..."
SearchBox.Text = ""
SearchBox.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
SearchBox.TextSize = 11
SearchBox.ClearTextOnFocus = false
SearchBox.LayoutOrder = 1
SearchBox.Parent = LeftListContainer
createCorner(SearchBox, 4)
createStroke(SearchBox, CONFIG.THEME.BORDER, 1)

local PlayerScroll = Instance.new("ScrollingFrame")
PlayerScroll.Size = UDim2.new(1, 0, 1, -34)
PlayerScroll.BackgroundTransparency = 1
PlayerScroll.BorderSizePixel = 0
PlayerScroll.ScrollBarThickness = 3
PlayerScroll.ScrollBarImageColor3 = CONFIG.THEME.BORDER
PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
PlayerScroll.LayoutOrder = 2
PlayerScroll.Parent = LeftListContainer

local PlayerListLayout = Instance.new("UIListLayout")
PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
PlayerListLayout.Padding = UDim.new(0, 4)
PlayerListLayout.Parent = PlayerScroll

local RightToolsContainer = Instance.new("Frame")
RightToolsContainer.Size = UDim2.new(1, -210, 1, 0)
RightToolsContainer.BackgroundTransparency = 1
RightToolsContainer.Parent = PlayerSplitFrame

local RightLayout = Instance.new("UIListLayout")
RightLayout.SortOrder = Enum.SortOrder.LayoutOrder
RightLayout.Padding = UDim.new(0, 8)
RightLayout.Parent = RightToolsContainer

local _, TargetCardContent = createCard(RightToolsContainer, "Target Profile", "Replicated inspection details")

local TargetNameRow = Instance.new("TextLabel")
TargetNameRow.Size = UDim2.new(1, 0, 0, 16)
TargetNameRow.BackgroundTransparency = 1
TargetNameRow.Font = CONFIG.FONTS.HEADER
TargetNameRow.Text = "Target: None Selected"
TargetNameRow.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
TargetNameRow.TextSize = 12
TargetNameRow.TextXAlignment = Enum.TextXAlignment.Left
TargetNameRow.Parent = TargetCardContent

local TargetStatusRow = Instance.new("TextLabel")
TargetStatusRow.Size = UDim2.new(1, 0, 0, 14)
TargetStatusRow.BackgroundTransparency = 1
TargetStatusRow.Font = CONFIG.FONTS.MONO
TargetStatusRow.Text = "Status: Standby | Distance: N/A"
TargetStatusRow.TextColor3 = CONFIG.THEME.TEXT_MUTED
TargetStatusRow.TextSize = 10
TargetStatusRow.TextXAlignment = Enum.TextXAlignment.Left
TargetStatusRow.Parent = TargetCardContent

local TargetHealthRow = Instance.new("TextLabel")
TargetHealthRow.Size = UDim2.new(1, 0, 0, 14)
TargetHealthRow.BackgroundTransparency = 1
TargetHealthRow.Font = CONFIG.FONTS.MONO
TargetHealthRow.Text = "Health: Unavailable"
TargetHealthRow.TextColor3 = CONFIG.THEME.TEXT_MUTED
TargetHealthRow.TextSize = 10
TargetHealthRow.TextXAlignment = Enum.TextXAlignment.Left
TargetHealthRow.Parent = TargetCardContent

local playerRowButtons: { [Player]: TextButton } = {}

local function updateTargetCard()
	if not state.selectedPlayer or not state.selectedPlayer.Parent then
		state.selectedPlayer = nil
		state.selectedPlayerName = "None"
		TargetNameRow.Text = "Target: None Selected"
		TargetStatusRow.Text = "Status: Standby | Distance: N/A"
		TargetHealthRow.Text = "Health: Unavailable"
		updateStatusBar(nil, nil)
		return
	end

	local p = state.selectedPlayer
	local pDisp = tostring(p.DisplayName or p.Name or "Player")
	local pNm = tostring(p.Name or "Player")
	TargetNameRow.Text = string.format("%s (@%s)", pDisp, pNm)

	local char = p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local localHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

	local distanceStr = "N/A"
	if hrp and localHrp and hrp:IsA("BasePart") and localHrp:IsA("BasePart") then
		local dist = (localHrp.Position - hrp.Position).Magnitude
		distanceStr = string.format("%.1f studs", dist)
	end

	local statusStr = "Missing Character"
	if char and hrp and hum then
		if hum.Health > 0 then
			statusStr = "Alive & Present"
		else
			statusStr = "Dead / Respawning"
		end
	elseif char and not hrp then
		statusStr = "Missing RootPart"
	end

	TargetStatusRow.Text = string.format("Status: %s | Dist: %s", statusStr, distanceStr)

	if hum and hum.Health > 0 then
		TargetHealthRow.Text = string.format("Health: %.0f / %.0f HP", hum.Health, hum.MaxHealth)
	elseif hum and hum.Health <= 0 then
		TargetHealthRow.Text = "Health: 0 HP (Dead)"
	else
		TargetHealthRow.Text = "Health: Non-Replicated"
	end

	updateStatusBar(nil, nil)
end

local function selectPlayer(p: Player?)
	state.selectedPlayer = p
	state.selectedPlayerName = p and tostring(p.Name) or "None"

	for otherPlayer, btn in pairs(playerRowButtons) do
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		if otherPlayer == p then
			btn.BackgroundColor3 = CONFIG.THEME.SURFACE_ALT
			btn.TextColor3 = state.accentColor
			if stroke then stroke.Color = state.accentColor end
		else
			btn.BackgroundColor3 = CONFIG.THEME.INPUT_BG
			btn.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
			if stroke then stroke.Color = CONFIG.THEME.BORDER end
		end
	end

	updateTargetCard()
end

local function rebuildPlayerList()
	for _, child in ipairs(PlayerScroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	table.clear(playerRowButtons)

	local searchPattern = string.lower(SearchBox.Text)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local pName = tostring(p.Name or "Player")
			local pDisplay = tostring(p.DisplayName or pName)
			local matchName = string.find(string.lower(pName), searchPattern, 1, true)
			local matchDisplay = string.find(string.lower(pDisplay), searchPattern, 1, true)
			if searchPattern == "" or matchName or matchDisplay then
				local row = Instance.new("TextButton")
				row.Size = UDim2.new(1, 0, 0, 26)
				row.BackgroundColor3 = (p == state.selectedPlayer) and CONFIG.THEME.SURFACE_ALT or CONFIG.THEME.INPUT_BG
				row.Font = CONFIG.FONTS.BODY
				row.Text = string.format(" %s (@%s)", pDisplay, pName)
				row.TextColor3 = (p == state.selectedPlayer) and state.accentColor or CONFIG.THEME.TEXT_PRIMARY
				row.TextSize = 11
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.TextTruncate = Enum.TextTruncate.AtEnd
				row.Parent = PlayerScroll
				createCorner(row, 4)
				createStroke(row, (p == state.selectedPlayer) and state.accentColor or CONFIG.THEME.BORDER, 1)

				playerRowButtons[p] = row
				trackConnection(row.Activated:Connect(function()
					selectPlayer(p)
				end))
			end
		end
	end
end

trackConnection(SearchBox:GetPropertyChangedSignal("Text"):Connect(rebuildPlayerList))

trackConnection(Players.PlayerAdded:Connect(function()
	rebuildPlayerList()
end))

trackConnection(Players.PlayerRemoving:Connect(function(leavingPlayer)
	if state.selectedPlayer == leavingPlayer then
		if state.isFollowing then
			state.isFollowing = false
			updateStatusBar("Follow terminated: Target left server.", "Warning")
		end
		selectPlayer(nil)
		updateStatusBar("Selected target disconnected.", "Warning")
	end
	rebuildPlayerList()
end))

rebuildPlayerList()

-- SECTION 6: FEATURE LOGIC & REGISTRY
local function executeTeleport()
	if not state.selectedPlayer or not state.selectedPlayer.Parent then
		updateStatusBar("Teleport failed: No target selected.", "Error")
		return
	end

	local targetChar = state.selectedPlayer.Character
	local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
	if not targetHrp or not targetHrp:IsA("BasePart") then
		updateStatusBar("Teleport failed: Target character root part unavailable.", "Error")
		return
	end

	local localChar = LocalPlayer.Character
	local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
	if not localHrp or not localHrp:IsA("BasePart") then
		updateStatusBar("Teleport failed: Local character root part unavailable.", "Error")
		return
	end

	state.previousPosition = localHrp.CFrame

	local dist = state.teleportDistance
	local destination = targetHrp.CFrame
	if state.teleportOffset == "Behind" then
		destination = targetHrp.CFrame * CFrame.new(0, 0, dist)
	elseif state.teleportOffset == "Front" then
		destination = targetHrp.CFrame * CFrame.new(0, 0, -dist)
	elseif state.teleportOffset == "Above" then
		destination = targetHrp.CFrame * CFrame.new(0, dist + 2, 0)
	elseif state.teleportOffset == "Left" then
		destination = targetHrp.CFrame * CFrame.new(-dist, 0, 0)
	elseif state.teleportOffset == "Right" then
		destination = targetHrp.CFrame * CFrame.new(dist, 0, 0)
	end

	localHrp.CFrame = destination

	task.delay(0.2, function()
		if localHrp and localHrp.Parent then
			local actualDist = (localHrp.Position - destination.Position).Magnitude
			if actualDist < 8 then
				updateStatusBar(string.format("Teleported to %s [Local].", state.selectedPlayerName), "Success")
			else
				updateStatusBar("Teleport rejected or corrected by server authority.", "Warning")
			end
		end
	end)
end

local function executeReturnToPrevious()
	if not state.previousPosition then
		updateStatusBar("Return failed: No prior position recorded.", "Warning")
		return
	end

	local localChar = LocalPlayer.Character
	local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
	if not localHrp or not localHrp:IsA("BasePart") then
		updateStatusBar("Return failed: Local root part unavailable.", "Error")
		return
	end

	local targetCFrame = state.previousPosition
	localHrp.CFrame = targetCFrame
	updateStatusBar("Restored to saved coordinates [Local].", "Success")
end

-- Teleport Card Wiring
local _, TeleportCardContent = createCard(RightToolsContainer, "Local Teleportation", "Safe client-authoritative offset movement")

local OffsetSelectorRow = Instance.new("Frame")
OffsetSelectorRow.Size = UDim2.new(1, 0, 0, 24)
OffsetSelectorRow.BackgroundTransparency = 1
OffsetSelectorRow.Parent = TeleportCardContent

local OffsetLayout = Instance.new("UIListLayout")
OffsetLayout.FillDirection = Enum.FillDirection.Horizontal
OffsetLayout.Padding = UDim.new(0, 4)
OffsetLayout.Parent = OffsetSelectorRow

local offsetButtons: { [string]: TextButton } = {}
local offsets = { "Behind", "Front", "Above", "Left", "Right" }
for _, off in ipairs(offsets) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 48, 1, 0)
	btn.BackgroundColor3 = (off == state.teleportOffset) and CONFIG.THEME.SURFACE_ALT or CONFIG.THEME.INPUT_BG
	btn.Font = CONFIG.FONTS.MONO
	btn.Text = off
	btn.TextColor3 = (off == state.teleportOffset) and state.accentColor or CONFIG.THEME.TEXT_MUTED
	btn.TextSize = 10
	btn.Parent = OffsetSelectorRow
	createCorner(btn, 4)
	createStroke(btn, (off == state.teleportOffset) and state.accentColor or CONFIG.THEME.BORDER, 1)

	offsetButtons[off] = btn
	trackConnection(btn.MouseButton1Click:Connect(function()
		state.teleportOffset = off
		for oName, oBtn in pairs(offsetButtons) do
			local oStroke = oBtn:FindFirstChildOfClass("UIStroke")
			if oName == off then
				oBtn.BackgroundColor3 = CONFIG.THEME.SURFACE_ALT
				oBtn.TextColor3 = state.accentColor
				if oStroke then oStroke.Color = state.accentColor end
			else
				oBtn.BackgroundColor3 = CONFIG.THEME.INPUT_BG
				oBtn.TextColor3 = CONFIG.THEME.TEXT_MUTED
				if oStroke then oStroke.Color = CONFIG.THEME.BORDER end
			end
		end
	end))
end

createSlider(TeleportCardContent, "Distance Offset", 2, 25, state.teleportDistance, 1, "studs", function(val)
	state.teleportDistance = val
end)

type FeatureEntry = {
	id: string,
	label: string,
	description: string,
	availability: string,
	category: string,
	execute: (() -> ())?,
}

local FeatureRegistry: { [string]: FeatureEntry } = {
	TeleportTarget = {
		id = "teleport_target",
		label = "Teleport to Target",
		description = "Translates local character CFrame to selected player position with offset.",
		availability = CONFIG.AVAILABILITY.EXPERIENCE,
		category = "PlayerTools",
		execute = executeTeleport,
	},
	ReturnPrevious = {
		id = "return_previous",
		label = "Return to Previous Position",
		description = "Restores character CFrame to coordinates saved prior to teleport.",
		availability = CONFIG.AVAILABILITY.EXPERIENCE,
		category = "PlayerTools",
		execute = executeReturnToPrevious,
	},
}

createActionButton(TeleportCardContent, FeatureRegistry.TeleportTarget.label, FeatureRegistry.TeleportTarget.availability, executeTeleport)
createActionButton(TeleportCardContent, FeatureRegistry.ReturnPrevious.label, FeatureRegistry.ReturnPrevious.availability, executeReturnToPrevious)

-- Follow Loop Implementation
local _, FollowCardContent = createCard(RightToolsContainer, "Target Tracking", "Non-intrusive local character following")

createSlider(FollowCardContent, "Follow Distance", 3, 20, state.followDistance, 1, "studs", function(val)
	state.followDistance = val
end)

local setFollowVisual: ((boolean) -> ())? = nil
local _, setVisualToggle = createToggle(FollowCardContent, "Local Follow Target", CONFIG.AVAILABILITY.EXPERIENCE, state.isFollowing, function(enabled)
	state.isFollowing = enabled
	if enabled then
		if not state.selectedPlayer or not state.selectedPlayer.Parent then
			state.isFollowing = false
			if setFollowVisual then setFollowVisual(false) end
			updateStatusBar("Follow failed: Select an active player first.", "Error")
			return
		end
		updateStatusBar(string.format("Following %s [Modest rate].", state.selectedPlayerName), "Success")
		task.spawn(function()
			while state.isFollowing do
				task.wait(0.15)
				if not state.isFollowing then break end

				if not state.selectedPlayer or not state.selectedPlayer.Parent then
					state.isFollowing = false
					if setFollowVisual then setFollowVisual(false) end
					updateStatusBar("Follow halted: Target player left.", "Warning")
					break
				end

				local targetChar = state.selectedPlayer.Character
				local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
				local localChar = LocalPlayer.Character
				local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
				local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")

				if not targetHrp or not targetHrp:IsA("BasePart") or not localHum or not localHrp or not localHrp:IsA("BasePart") then
					state.isFollowing = false
					if setFollowVisual then setFollowVisual(false) end
					updateStatusBar("Follow halted: Character parts unavailable.", "Warning")
					break
				end

				local targetPart = targetHrp :: BasePart
				local localPart = localHrp :: BasePart
				local dist = (localPart.Position - targetPart.Position).Magnitude
				if dist > state.followDistance then
					localHum:MoveTo(targetPart.Position)
				end
			end
		end)
	else
		updateStatusBar("Follow deactivated.", "Normal")
	end
end)
setFollowVisual = setVisualToggle

-- TROLL TAB (FE COMPATIBLE COLLISION & HARASSMENT MECHANICS)
local _, FlingCardContent = createCard(PageTroll, "Target Collision Fling [FE]", "Launches target via networked physics collision impulse")

local FlingNotice = Instance.new("TextLabel")
FlingNotice.Size = UDim2.new(1, 0, 0, 32)
FlingNotice.BackgroundTransparency = 1
FlingNotice.Font = CONFIG.FONTS.BODY
FlingNotice.Text = "Strikes the target's collision hull with extreme assembly momentum. The physics collision resolution replicates across the server to all players. Requires player collision enabled in the game."
FlingNotice.TextColor3 = CONFIG.THEME.TEXT_MUTED
FlingNotice.TextSize = 10
FlingNotice.TextWrapped = true
FlingNotice.TextXAlignment = Enum.TextXAlignment.Left
FlingNotice.Parent = FlingCardContent

createSlider(FlingCardContent, "Impulse Momentum", 5000, 40000, state.flingPower, 2500, "units", function(val)
	state.flingPower = val
end)

createSlider(FlingCardContent, "Fling Duration", 0.5, 4.0, state.flingDuration, 0.25, "sec", function(val)
	state.flingDuration = val
end)

local flingHeartbeatConn: RBXScriptConnection? = nil

local function abortFling()
	state.isFlinging = false
	if flingHeartbeatConn then
		flingHeartbeatConn:Disconnect()
		flingHeartbeatConn = nil
	end
	local localChar = LocalPlayer.Character
	local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
	local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
	if localHrp and localHrp:IsA("BasePart") then
		localHrp.AssemblyLinearVelocity = Vector3.zero
		localHrp.AssemblyAngularVelocity = Vector3.zero
		if state.previousPosition then
			localHrp.CFrame = state.previousPosition
		end
	end
	if localHum then
		localHum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		localHum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		localHum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function executeTargetFling()
	if state.isFlinging then
		updateStatusBar("Fling already active.", "Warning")
		return
	end

	if not state.selectedPlayer or not state.selectedPlayer.Parent then
		updateStatusBar("Fling failed: Select a target player first.", "Error")
		return
	end

	local targetChar = state.selectedPlayer.Character
	local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
	local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")
	local localChar = LocalPlayer.Character
	local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
	local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")

	if not targetHrp or not targetHrp:IsA("BasePart") or not targetHum or targetHum.Health <= 0 then
		updateStatusBar("Fling failed: Target character unavailable or dead.", "Error")
		return
	end

	if not localHrp or not localHrp:IsA("BasePart") or not localHum then
		updateStatusBar("Fling failed: Local character unavailable.", "Error")
		return
	end

	state.previousPosition = localHrp.CFrame
	state.isFlinging = true
	updateStatusBar(string.format("Executing FE collision strike on %s...", state.selectedPlayerName), "Normal")

	localHum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	localHum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	local power = state.flingPower
	local deadline = tick() + state.flingDuration

	flingHeartbeatConn = RunService.Heartbeat:Connect(function()
		if not state.isFlinging or tick() >= deadline then
			abortFling()
			updateStatusBar("FE collision strike completed. Position restored.", "Success")
			return
		end

		if not targetHrp or not targetHrp.Parent or not localHrp or not localHrp.Parent or targetHum.Health <= 0 then
			abortFling()
			updateStatusBar("Target lost or eliminated during fling strike.", "Warning")
			return
		end

		local jitter = Vector3.new(
			math.random(-15, 15) / 100,
			math.random(-10, 10) / 100,
			math.random(-15, 15) / 100
		)
		localHrp.CFrame = CFrame.new(targetHrp.Position + jitter)
		localHrp.AssemblyAngularVelocity = Vector3.new(power, power * 1.5, power)
		localHrp.AssemblyLinearVelocity = Vector3.new(0, power * 0.8, 0)
	end)
	trackConnection(flingHeartbeatConn :: RBXScriptConnection)
end

createActionButton(FlingCardContent, "Fling Target [FE Strike]", CONFIG.AVAILABILITY.COLLISION, executeTargetFling)
createActionButton(FlingCardContent, "Emergency Stop / Reset Velocity", CONFIG.AVAILABILITY.LOCAL, function()
	abortFling()
	updateStatusBar("Fling aborted. Character physics normalized.", "Normal")
end)

-- Touch Fling Aura Card
local _, AuraCardContent = createCard(PageTroll, "Touch Fling Aura [FE]", "Infuses character with continuous collision repulsion")
local touchFlingConn: RBXScriptConnection? = nil

local function stopTouchFling()
	state.isTouchFling = false
	if touchFlingConn then
		touchFlingConn:Disconnect()
		touchFlingConn = nil
	end
	local localChar = LocalPlayer.Character
	local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
	if localHrp and localHrp:IsA("BasePart") then
		localHrp.AssemblyAngularVelocity = Vector3.zero
	end
end

local function startTouchFling()
	stopTouchFling()
	state.isTouchFling = true
	local conn = RunService.Heartbeat:Connect(function()
		if not state.isTouchFling then
			stopTouchFling()
			return
		end
		local localChar = LocalPlayer.Character
		local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
		if localHrp and localHrp:IsA("BasePart") then
			local p = state.flingPower
			localHrp.AssemblyAngularVelocity = Vector3.new(0, p, 0)
		end
	end)
	trackConnection(conn)
	touchFlingConn = conn
	updateStatusBar("Touch Fling Aura active: Walk into players to fling them.", "Success")
end

createToggle(AuraCardContent, "Toggle Touch Fling Aura", CONFIG.AVAILABILITY.COLLISION, state.isTouchFling, function(enabled)
	if enabled then
		startTouchFling()
	else
		stopTouchFling()
		updateStatusBar("Touch Fling Aura disabled.", "Normal")
	end
end)

-- Kinematic Harassment & Tracking Card
local _, KinematicCardContent = createCard(PageTroll, "Kinematic Tracking & Annoyance [FE]", "Replicated client-authoritative movement harassment")

createSlider(KinematicCardContent, "Orbit Radius", 3, 15, state.orbitRadius, 1, "studs", function(val)
	state.orbitRadius = val
end)

createSlider(KinematicCardContent, "Orbit Speed", 1, 10, state.orbitSpeed, 1, "", function(val)
	state.orbitSpeed = val
end)

local orbitConn: RBXScriptConnection? = nil
local orbitAngle = 0

local function stopOrbit()
	state.isOrbiting = false
	if orbitConn then
		orbitConn:Disconnect()
		orbitConn = nil
	end
end

local function startOrbit()
	if not state.selectedPlayer or not state.selectedPlayer.Parent then
		updateStatusBar("Orbit failed: No target selected.", "Error")
		return
	end
	stopOrbit()
	state.isOrbiting = true
	local conn = RunService.Heartbeat:Connect(function(dt)
		if not state.isOrbiting then
			stopOrbit()
			return
		end
		local targetChar = state.selectedPlayer and state.selectedPlayer.Character
		local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
		local localChar = LocalPlayer.Character
		local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
		if not targetHrp or not targetHrp:IsA("BasePart") or not localHrp or not localHrp:IsA("BasePart") then
			stopOrbit()
			updateStatusBar("Orbit stopped: Target or local parts unavailable.", "Warning")
			return
		end

		orbitAngle = (orbitAngle + dt * state.orbitSpeed * 3) % (math.pi * 2)
		local radius = state.orbitRadius
		local offsetX = math.cos(orbitAngle) * radius
		local offsetZ = math.sin(orbitAngle) * radius
		local goalPos = targetHrp.Position + Vector3.new(offsetX, 1, offsetZ)

		localHrp.CFrame = CFrame.lookAt(goalPos, targetHrp.Position)
	end)
	trackConnection(conn)
	orbitConn = conn
	updateStatusBar(string.format("Orbiting target %s [Replicated movement].", state.selectedPlayerName), "Success")
end

local setOrbitVisual: ((boolean) -> ())? = nil
local _, setOrbitToggle = createToggle(KinematicCardContent, "Orbit Selected Player", CONFIG.AVAILABILITY.EXPERIENCE, state.isOrbiting, function(enabled)
	if enabled then
		if not state.selectedPlayer or not state.selectedPlayer.Parent then
			if setOrbitVisual then setOrbitVisual(false) end
			updateStatusBar("Orbit failed: Select an active target first.", "Error")
			return
		end
		startOrbit()
	else
		stopOrbit()
		updateStatusBar("Orbit deactivated.", "Normal")
	end
end)
setOrbitVisual = setOrbitToggle

local headSitConn: RBXScriptConnection? = nil

local function stopHeadSit()
	state.isHeadSitting = false
	if headSitConn then
		headSitConn:Disconnect()
		headSitConn = nil
	end
	local localChar = LocalPlayer.Character
	local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
	if localHum then
		localHum.PlatformStand = false
	end
end

local function startHeadSit()
	if not state.selectedPlayer or not state.selectedPlayer.Parent then
		updateStatusBar("Head Sit failed: No target selected.", "Error")
		return
	end
	stopHeadSit()
	state.isHeadSitting = true
	local conn = RunService.Heartbeat:Connect(function()
		if not state.isHeadSitting then
			stopHeadSit()
			return
		end
		local targetChar = state.selectedPlayer and state.selectedPlayer.Character
		local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
		local localChar = LocalPlayer.Character
		local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
		local localHum = localChar and localChar:FindFirstChildOfClass("Humanoid")
		if not targetHrp or not targetHrp:IsA("BasePart") or not localHrp or not localHrp:IsA("BasePart") or not localHum then
			stopHeadSit()
			updateStatusBar("Head Sit halted: Target unavailable.", "Warning")
			return
		end

		localHum.Sit = true
		localHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 3.2, 0)
		localHrp.AssemblyLinearVelocity = Vector3.zero
	end)
	trackConnection(conn)
	headSitConn = conn
	updateStatusBar(string.format("Head Sit active on %s [Replicated movement].", state.selectedPlayerName), "Success")
end

local setHeadSitVisual: ((boolean) -> ())? = nil
local _, setHeadSitToggle = createToggle(KinematicCardContent, "Head Sit / Attach", CONFIG.AVAILABILITY.EXPERIENCE, state.isHeadSitting, function(enabled)
	if enabled then
		if not state.selectedPlayer or not state.selectedPlayer.Parent then
			if setHeadSitVisual then setHeadSitVisual(false) end
			updateStatusBar("Head Sit failed: Select an active target first.", "Error")
			return
		end
		startHeadSit()
	else
		stopHeadSit()
		updateStatusBar("Head Sit deactivated.", "Normal")
	end
end)
setHeadSitVisual = setHeadSitToggle

-- MOVEMENT TAB
local _, WalkCardContent = createCard(PageMovement, "Walk Speed Adjustment", "Local Humanoid walk speed modification")
local _, setWalkSlider = createSlider(WalkCardContent, "Walk Speed", 0, 120, state.walkSpeed, 1, "studs/s", function(val)
	state.walkSpeed = val
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = val
		updateStatusBar(string.format("WalkSpeed set to %.0f [Subject to server scripts].", val), "Normal")
	end
end)

local function resetWalkSpeed()
	state.walkSpeed = state.defaultWalkSpeed
	setWalkSlider(state.defaultWalkSpeed)
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = state.defaultWalkSpeed
	end
	updateStatusBar("WalkSpeed reset to default (16).", "Normal")
end

FeatureRegistry.ResetWalkSpeed = {
	id = "reset_walkspeed",
	label = "Reset Walk Speed",
	description = "Restores local Humanoid.WalkSpeed to 16.",
	availability = CONFIG.AVAILABILITY.LOCAL,
	category = "Movement",
	execute = resetWalkSpeed,
}
createActionButton(WalkCardContent, FeatureRegistry.ResetWalkSpeed.label, FeatureRegistry.ResetWalkSpeed.availability, resetWalkSpeed)

local _, JumpCardContent = createCard(PageMovement, "Jump Power / Height", "Local Humanoid jump parameter adjustment")
local _, setJumpSlider = createSlider(JumpCardContent, "Jump Setting", 0, 150, state.jumpPower, 1, "units", function(val)
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		if hum.UseJumpPower then
			state.jumpPower = val
			hum.JumpPower = val
		else
			state.jumpHeight = val * 0.144
			hum.JumpHeight = state.jumpHeight
		end
		updateStatusBar("Jump parameter updated locally.", "Normal")
	end
end)

local function resetJumpParameter()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.UseJumpPower = true
		hum.JumpPower = state.defaultJumpPower
		state.jumpPower = state.defaultJumpPower
		setJumpSlider(state.defaultJumpPower)
	end
	updateStatusBar("Jump parameter reset to default.", "Normal")
end

FeatureRegistry.ResetJump = {
	id = "reset_jump",
	label = "Reset Jump Parameter",
	description = "Restores local Humanoid jump configuration to default.",
	availability = CONFIG.AVAILABILITY.LOCAL,
	category = "Movement",
	execute = resetJumpParameter,
}
createActionButton(JumpCardContent, FeatureRegistry.ResetJump.label, FeatureRegistry.ResetJump.availability, resetJumpParameter)

local _, FlightCardContent = createCard(PageMovement, "Local Flight Demonstration", "Directional flight simulation using client velocity")
createSlider(FlightCardContent, "Flight Speed", 10, 150, state.flySpeed, 5, "studs/s", function(val)
	state.flySpeed = val
end)

local flightVelocity: BodyVelocity? = nil
local flightGyro: BodyGyro? = nil
local flightConnection: RBXScriptConnection? = nil

local function stopFlight()
	state.isFlying = false
	if flightConnection then
		flightConnection:Disconnect()
		flightConnection = nil
	end
	if flightVelocity then
		flightVelocity:Destroy()
		flightVelocity = nil
	end
	if flightGyro then
		flightGyro:Destroy()
		flightGyro = nil
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
	end
end

local function startFlight()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hrp:IsA("BasePart") or not hum then
		updateStatusBar("Flight failed: Character parts unavailable.", "Error")
		return
	end

	stopFlight()
	state.isFlying = true

	local bv = Instance.new("BodyVelocity")
	bv.Name = "Sentinel_FlightVelocity"
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.Velocity = Vector3.zero
	bv.Parent = hrp
	flightVelocity = bv
	trackInstance(bv)

	local bg = Instance.new("BodyGyro")
	bg.Name = "Sentinel_FlightGyro"
	bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	bg.CFrame = getCamera().CFrame
	bg.Parent = hrp
	flightGyro = bg
	trackInstance(bg)

	local conn = RunService.RenderStepped:Connect(function()
		if not state.isFlying or not hrp or not hrp.Parent then
			stopFlight()
			return
		end

		local cam = getCamera()
		local moveVector = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			moveVector += cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			moveVector -= cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			moveVector -= cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			moveVector += cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			moveVector += Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			moveVector -= Vector3.new(0, 1, 0)
		end

		if hum and hum.MoveDirection.Magnitude > 0 and moveVector.Magnitude == 0 then
			local worldDir = cam.CFrame:VectorToWorldSpace(hum.MoveDirection)
			moveVector += worldDir
		end

		if moveVector.Magnitude > 0 then
			bv.Velocity = moveVector.Unit * state.flySpeed
		else
			bv.Velocity = Vector3.zero
		end
		bg.CFrame = cam.CFrame
	end)
	trackConnection(conn)
	flightConnection = conn
	updateStatusBar("Flight demonstration active [WASD/Space/Shift].", "Success")
end

local _, setFlightVisual = createToggle(FlightCardContent, "Toggle Flight", CONFIG.AVAILABILITY.LOCAL, state.isFlying, function(enabled)
	if enabled then
		startFlight()
	else
		stopFlight()
		updateStatusBar("Flight demonstration halted.", "Normal")
	end
end)

local _, NoclipCardContent = createCard(PageMovement, "Local Noclip Testing", "Client collision bypass for map diagnostics")
local noclipConnection: RBXScriptConnection? = nil

local function stopNoclip()
	state.isNoclipping = false
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
	local char = LocalPlayer.Character
	if char then
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and (p.Name == "HumanoidRootPart" or string.find(p.Name, "Torso") or p.Name == "Head") then
				p.CanCollide = true
			end
		end
	end
end

local function startNoclip()
	stopNoclip()
	state.isNoclipping = true
	local conn = RunService.Stepped:Connect(function()
		if not state.isNoclipping then
			stopNoclip()
			return
		end
		local char = LocalPlayer.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end
	end)
	trackConnection(conn)
	noclipConnection = conn
	updateStatusBar("Noclip testing active [Local collision bypassed].", "Success")
end

createToggle(NoclipCardContent, "Toggle Noclip", CONFIG.AVAILABILITY.LOCAL, state.isNoclipping, function(enabled)
	if enabled then
		startNoclip()
	else
		stopNoclip()
		updateStatusBar("Noclip deactivated. Collisions restored.", "Normal")
	end
end)

local _, ResetCardContent = createCard(PageMovement, "Character Reset", "Triggers standard client respawn mechanism")

local function executeCharacterReset()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Dead)
		hum.Health = 0
		updateStatusBar("Character reset invoked.", "Warning")
	else
		updateStatusBar("Reset failed: Humanoid not found.", "Error")
	end
end

FeatureRegistry.CharacterReset = {
	id = "character_reset",
	label = "Execute Character Reset",
	description = "Triggers standard client humanoid respawn via ChangeState(Dead).",
	availability = CONFIG.AVAILABILITY.LOCAL,
	category = "Movement",
	execute = executeCharacterReset,
}
createActionButton(ResetCardContent, FeatureRegistry.CharacterReset.label, FeatureRegistry.CharacterReset.availability, executeCharacterReset)

-- VISUALS TAB
local _, TransCardContent = createCard(PageVisuals, "Character Ghosting / Transparency", "Local client character mesh visibility test")
local _, setTransSlider = createSlider(TransCardContent, "Transparency", 0, 1, state.characterTransparency, 0.05, "", function(val)
	state.characterTransparency = val
	state.isCharacterTransparent = (val > 0)
	local char = LocalPlayer.Character
	if char then
		for _, desc in ipairs(char:GetDescendants()) do
			if desc:IsA("BasePart") then
				if state.originalTransparencies[desc] == nil then
					state.originalTransparencies[desc] = desc.Transparency
				end
				desc.Transparency = val
			elseif desc:IsA("Decal") then
				if state.originalTransparencies[desc] == nil then
					state.originalTransparencies[desc] = desc.Transparency
				end
				desc.Transparency = val
			end
		end
	end
	updateStatusBar(string.format("Local transparency set to %.2f.", val), "Normal")
end)

local function restoreTransparency()
	state.isCharacterTransparent = false
	setTransSlider(0)
	for inst, origTrans in pairs(state.originalTransparencies) do
		if inst and inst.Parent then
			local bInst = inst :: any
			bInst.Transparency = origTrans
		end
	end
	table.clear(state.originalTransparencies)
	updateStatusBar("Character transparency restored.", "Normal")
end

FeatureRegistry.RestoreTrans = {
	id = "restore_trans",
	label = "Restore Original Transparency",
	description = "Reverts all character BasePart and Decal transparency values.",
	availability = CONFIG.AVAILABILITY.LOCAL,
	category = "Visuals",
	execute = restoreTransparency,
}
createActionButton(TransCardContent, FeatureRegistry.RestoreTrans.label, FeatureRegistry.RestoreTrans.availability, restoreTransparency)

local _, HighlightCardContent = createCard(PageVisuals, "Local Character Highlight", "Renders client-side outline/fill Highlight instance")
createToggle(HighlightCardContent, "Toggle Highlight", CONFIG.AVAILABILITY.LOCAL, state.isHighlightActive, function(enabled)
	state.isHighlightActive = enabled
	if enabled then
		local char = LocalPlayer.Character
		if char then
			if state.highlightInstance then state.highlightInstance:Destroy() end
			local hl = Instance.new("Highlight")
			hl.Name = "Sentinel_Highlight"
			hl.FillColor = state.accentColor
			hl.OutlineColor = Color3.fromRGB(255, 255, 255)
			hl.FillTransparency = 0.5
			hl.OutlineTransparency = 0
			hl.Adornee = char
			hl.Parent = char
			state.highlightInstance = hl
			trackInstance(hl)
			updateStatusBar("Character highlight enabled.", "Success")
		end
	else
		if state.highlightInstance then
			state.highlightInstance:Destroy()
			state.highlightInstance = nil
		end
		updateStatusBar("Character highlight disabled.", "Normal")
	end
end)

local _, FovCardContent = createCard(PageVisuals, "Camera Field of View", "Local viewport angle adjustment")
local _, setFovSlider = createSlider(FovCardContent, "Field of View", 40, 120, state.currentFov, 1, "deg", function(val)
	state.currentFov = val
	getCamera().FieldOfView = val
	updateStatusBar(string.format("Camera FOV set to %.0f degrees.", val), "Normal")
end)

local function resetFov()
	state.currentFov = state.defaultFov
	getCamera().FieldOfView = state.defaultFov
	setFovSlider(state.defaultFov)
	updateStatusBar("Camera FOV restored to default (70).", "Normal")
end

FeatureRegistry.ResetFov = {
	id = "reset_fov",
	label = "Reset Field of View",
	description = "Restores Camera.FieldOfView to default angle.",
	availability = CONFIG.AVAILABILITY.LOCAL,
	category = "Visuals",
	execute = resetFov,
}
createActionButton(FovCardContent, FeatureRegistry.ResetFov.label, FeatureRegistry.ResetFov.availability, resetFov)

local _, EffectCardContent = createCard(PageVisuals, "Screen Color Enhancement", "Harmless client-side post-processing color correction")
createToggle(EffectCardContent, "Toggle Screen Effect", CONFIG.AVAILABILITY.LOCAL, state.isScreenEffectActive, function(enabled)
	state.isScreenEffectActive = enabled
	if enabled then
		if state.screenEffectInstance then state.screenEffectInstance:Destroy() end
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "Sentinel_ColorCorrection"
		cc.Brightness = 0.04
		cc.Contrast = 0.16
		cc.Saturation = 0.25
		cc.Parent = Lighting
		state.screenEffectInstance = cc
		trackInstance(cc)
		updateStatusBar("Screen color enhancement active.", "Success")
	else
		if state.screenEffectInstance then
			state.screenEffectInstance:Destroy()
			state.screenEffectInstance = nil
		end
		updateStatusBar("Screen effect deactivated.", "Normal")
	end
end)

-- SETTINGS TAB
local _, ScaleCardContent = createCard(PageSettings, "Interface Scale", "Adjust viewport scale factor")
createSlider(ScaleCardContent, "Scale Factor", 0.8, 1.25, state.guiScale, 0.05, "x", function(val)
	state.guiScale = val
	GuiScale.Scale = val
end)

local _, AccentCardContent = createCard(PageSettings, "Theme Accent Color", "Pick an interface highlight shade")
local PaletteRow = Instance.new("Frame")
PaletteRow.Size = UDim2.new(1, 0, 0, 26)
PaletteRow.BackgroundTransparency = 1
PaletteRow.Parent = AccentCardContent

local PaletteLayout = Instance.new("UIListLayout")
PaletteLayout.FillDirection = Enum.FillDirection.Horizontal
PaletteLayout.Padding = UDim.new(0, 6)
PaletteLayout.Parent = PaletteRow

for name, color in pairs(CONFIG.ACCENTS) do
	local swatch = Instance.new("TextButton")
	swatch.Size = UDim2.new(0, 36, 1, 0)
	swatch.BackgroundColor3 = color
	swatch.Text = ""
	swatch.Parent = PaletteRow
	createCorner(swatch, 4)
	createStroke(swatch, CONFIG.THEME.BORDER, 1)

	trackConnection(swatch.Activated:Connect(function()
		updateAccentColor(color)
		updateStatusBar(string.format("Accent color updated to %s.", name), "Normal")
	end))
end

local _, OpacityCardContent = createCard(PageSettings, "Window Background Opacity", "Configure panel surface transparency")
createSlider(OpacityCardContent, "Surface Transparency", 0, 0.4, state.windowOpacity, 0.05, "", function(val)
	state.windowOpacity = val
	MainFrame.BackgroundTransparency = val
end)

local _, MobileCardContent = createCard(PageSettings, "Mobile & Display Preferences", "Touch UI and screen fit options")
createToggle(MobileCardContent, "Show Mobile Floating Toggle", CONFIG.AVAILABILITY.LOCAL, state.showMobileButton, function(enabled)
	state.showMobileButton = enabled
	MobileToggleButton.Visible = enabled
end)
createActionButton(MobileCardContent, "Recenter Interface to Screen", CONFIG.AVAILABILITY.LOCAL, recenterMainFrame)
createToggle(MobileCardContent, "Auto-Fit Scale (Mobile Displays)", CONFIG.AVAILABILITY.LOCAL, not state.manualScaleOverride, function(enabled)
	state.manualScaleOverride = not enabled
	if enabled then
		local autoScale = computeAutoFitScale()
		state.guiScale = autoScale
		GuiScale.Scale = autoScale
		clampMainFrameToBounds()
	end
end)

local _, PrefCardContent = createCard(PageSettings, "Runtime Preferences", "Client behavior settings")
createToggle(PrefCardContent, "Enable Smooth Transitions", CONFIG.AVAILABILITY.LOCAL, state.animationsEnabled, function(enabled)
	state.animationsEnabled = enabled
end)
createToggle(PrefCardContent, "Preserve Session State", CONFIG.AVAILABILITY.LOCAL, state.rememberSession, function(enabled)
	state.rememberSession = enabled
end)

local _, UnloadCardContent = createCard(PageSettings, "Unload & Terminate", "Completely remove Sentinel and reset all character states")
createActionButton(UnloadCardContent, "Unload Sentinel Suite", CONFIG.AVAILABILITY.LOCAL, cleanupAll)

local _, HotkeyCardContent = createCard(PageSettings, "Keybind Reference", "Global utility shortcuts")
local HotkeyLabel = Instance.new("TextLabel")
HotkeyLabel.Size = UDim2.new(1, 0, 0, 20)
HotkeyLabel.BackgroundTransparency = 1
HotkeyLabel.Font = CONFIG.FONTS.MONO
HotkeyLabel.Text = "Toggle Interface: [RightControl] | Minimized Floating Bar"
HotkeyLabel.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
HotkeyLabel.TextSize = 11
HotkeyLabel.TextXAlignment = Enum.TextXAlignment.Left
HotkeyLabel.Parent = HotkeyCardContent

-- INFORMATION TAB
local function createInfoCard(title: string, bodyText: string)
	local _, content = createCard(PageInfo, title)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = CONFIG.FONTS.BODY
	label.Text = bodyText
	label.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
	label.TextSize = 11
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = content
end

createInfoCard(
	"FilteringEnabled (FE) Architecture",
	[[Roblox enforces strict client-server separation via FilteringEnabled. Clients possess authoritative physics control only over their own character assemblies. Changes enacted on another player's character, coordinates, or velocities never replicate to the server or other connected clients without an authorized server-side remote handler.]]
)

createInfoCard(
	"How FE Collision Flinging Works",
	[[Under FilteringEnabled, you cannot directly assign velocity to an opponent's character. However, character-to-character physical collisions are calculated by Roblox's physics engine. When the local character's root assembly is infused with extreme angular or linear momentum and strikes an unanchored player, the collision solver resolves the interpenetration by imparting immense kinetic force to the target. This physical impulse replicates across the network to all connected players, provided player-to-player collision is enabled in the game.]]
)

createInfoCard(
	"Client vs Server Movement Authority",
	[[Modifying local HumanoidRootPart CFrame relocates the local character client-side. However, the game server continually validates character positions. If an experience implements server-side anti-cheat, position threshold checks, or physics boundaries, client teleportation will be rejected, resulting in immediate rollback or rubberbanding.]]
)

createInfoCard(
	"Feature Availability Classification Legend",
	[[[Client Local]: Executes entirely on your local machine with guaranteed functional behavior (Visuals, Highlights, Local FOV, Noclip).

[FE Collision]: Uses local physics momentum and physical collision to transfer networked impulses to unanchored players across the server.

[Exp Dependent]: Local actions that may be overridden, capped, or rubberbanded by game-specific server scripts (WalkSpeed, JumpPower, Local Teleportation).

[Restricted]: Server-authoritative mechanics that cannot legitimately be performed by a client script alone.]]
)

local _, sysDiagContent = createCard(PageInfo, "System & Platform Diagnostics", "Runtime environment analysis")
local sysLabel = Instance.new("TextLabel")
sysLabel.Size = UDim2.new(1, 0, 0, 0)
sysLabel.AutomaticSize = Enum.AutomaticSize.Y
sysLabel.BackgroundTransparency = 1
sysLabel.Font = CONFIG.FONTS.MONO
sysLabel.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
sysLabel.TextSize = 11
sysLabel.TextWrapped = true
sysLabel.TextXAlignment = Enum.TextXAlignment.Left
local curVp = getViewportSize()
sysLabel.Text = string.format("Detected Executor: %s\nPlatform Profile: %s\nTouch Input: %s\nProtected Container: %s\nDisplay Viewport: %d x %d\nEffective Scale: %.2f",
	detectedExecutor,
	isMobileDevice and "Mobile / Touch Device" or "Desktop / Laptop",
	UserInputService.TouchEnabled and "Supported" or "None",
	TargetParent.ClassName,
	curVp.X,
	curVp.Y,
	GuiScale.Scale
)
sysLabel.Parent = sysDiagContent

-- SECTION 7: EVENT CONNECTIONS & DRAGGING
trackConnection(MinimizeButton.Activated:Connect(function()
	state.isMinimized = true
	MainFrame.Visible = false
	MinimizedPill.Visible = true
	updateStatusBar("Interface minimized to floating pill.", "Normal")
end))

trackConnection(PillRestoreButton.Activated:Connect(function()
	state.isMinimized = false
	MinimizedPill.Visible = false
	MainFrame.Visible = true
	updateStatusBar("Interface restored.", "Normal")
end))

local function toggleVisibility()
	if MainFrame.Visible or MinimizedPill.Visible then
		MainFrame.Visible = false
		MinimizedPill.Visible = false
		updateStatusBar("Interface hidden. Tap floating button to reopen.", "Normal")
	else
		if state.isMinimized then
			MinimizedPill.Visible = true
		else
			MainFrame.Visible = true
			clampMainFrameToBounds()
		end
		updateStatusBar("Interface visible.", "Normal")
	end
end

trackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == CONFIG.HOTKEY then
		toggleVisibility()
	end
end))

local function onViewportChanged()
	if not state.manualScaleOverride then
		local newScale = computeAutoFitScale()
		state.guiScale = newScale
		GuiScale.Scale = newScale
	end
	clampMainFrameToBounds()
end

local activeCam = Workspace.CurrentCamera
if activeCam then
	trackConnection(activeCam:GetPropertyChangedSignal("ViewportSize"):Connect(onViewportChanged))
end
trackConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	local newCam = Workspace.CurrentCamera
	if newCam then
		trackConnection(newCam:GetPropertyChangedSignal("ViewportSize"):Connect(onViewportChanged))
	end
	onViewportChanged()
end))

trackConnection(LocalPlayer.CharacterAdded:Connect(function(newChar)
	task.wait(0.2)
	if state.walkSpeed ~= state.defaultWalkSpeed then
		local hum = newChar:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = state.walkSpeed end
	end
	if state.isFlying then
		stopFlight()
		setFlightVisual(false)
	end
	if state.isFlinging then
		abortFling()
	end
	if state.isTouchFling then
		stopTouchFling()
	end
	if state.isOrbiting then
		stopOrbit()
		if setOrbitVisual then setOrbitVisual(false) end
	end
	if state.isHeadSitting then
		stopHeadSit()
		if setHeadSitVisual then setHeadSitVisual(false) end
	end
	if state.isHighlightActive then
		local hl = Instance.new("Highlight")
		hl.Name = "Sentinel_Highlight"
		hl.FillColor = state.accentColor
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.FillTransparency = 0.5
		hl.OutlineTransparency = 0
		hl.Adornee = newChar
		hl.Parent = newChar
		state.highlightInstance = hl
		trackInstance(hl)
	end
	updateTargetCard()
end))

trackConnection(RunService.Heartbeat:Connect(function()
	if state.selectedPlayer and MainFrame.Visible and state.activeTab == "PlayerTools" then
		updateTargetCard()
	end
end))

-- SECTION 8: CLEANUP LIFECYCLE & ERROR HANDLING
local function cleanupAll()
	state.isFollowing = false
	abortFling()
	stopTouchFling()
	stopOrbit()
	stopHeadSit()
	stopFlight()
	stopNoclip()

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = state.defaultWalkSpeed
		hum.UseJumpPower = true
		hum.JumpPower = state.defaultJumpPower
		hum.PlatformStand = false
	end

	for inst, origTrans in pairs(state.originalTransparencies) do
		if inst and inst.Parent then
			local bInst = inst :: any
			bInst.Transparency = origTrans
		end
	end
	table.clear(state.originalTransparencies)

	getCamera().FieldOfView = state.defaultFov

	for _, conn in ipairs(trackedConnections) do
		if conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(trackedConnections)

	for _, inst in ipairs(trackedInstances) do
		if inst and inst.Parent then
			inst:Destroy()
		end
	end
	table.clear(trackedInstances)

	ScreenGui:Destroy()
	local cleanupG = _G :: any
	cleanupG.SentinelUtilityCleanup = nil
end

trackConnection(CloseButton.Activated:Connect(function()
	MainFrame.Visible = false
	MinimizedPill.Visible = false
	updateStatusBar("Interface hidden. Tap floating button to reopen.", "Normal")
end))
local sharedG = _G :: any
sharedG.SentinelUtilityCleanup = cleanupAll

switchTab(state.activeTab)
updateStatusBar("Sentinel Suite ready. Press RightControl to toggle visibility.", "Normal")

end)

-- If build fails, report and construct fallback on-screen error dialogue
if not BUILD_OK then
	warn("[Sentinel] BUILD FAILED: " .. tostring(BUILD_ERR))
	local errGui = Instance.new("ScreenGui")
	errGui.Name = "Sentinel_Error"
	errGui.ResetOnSpawn = false
	errGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	errGui.IgnoreGuiInset = true
	errGui.DisplayOrder = 20000

	if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		pcall(syn.protect_gui, errGui)
	end

	errGui.Parent = TargetParent

	local vp = getViewportSize()
	local errW = math.min(500, vp.X - 20)
	local errH = math.min(240, vp.Y - 20)

	local errFrame = Instance.new("Frame")
	errFrame.Size = UDim2.new(0, errW, 0, errH)
	errFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	errFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	errFrame.BackgroundColor3 = Color3.fromRGB(35, 12, 16)
	errFrame.BorderSizePixel = 0
	errFrame.Parent = errGui

	local errCorner = Instance.new("UICorner")
	errCorner.CornerRadius = UDim.new(0, 8)
	errCorner.Parent = errFrame

	local errStroke = Instance.new("UIStroke")
	errStroke.Color = Color3.fromRGB(244, 63, 94)
	errStroke.Thickness = 1
	errStroke.Parent = errFrame

	local errTitle = Instance.new("TextLabel")
	errTitle.Size = UDim2.new(1, -24, 0, 28)
	errTitle.Position = UDim2.new(0, 12, 0, 8)
	errTitle.BackgroundTransparency = 1
	errTitle.Font = CONFIG.FONTS.TITLE
	errTitle.Text = "SENTINEL SUITE - BUILD FAILURE"
	errTitle.TextColor3 = Color3.fromRGB(255, 100, 120)
	errTitle.TextSize = 13
	errTitle.TextXAlignment = Enum.TextXAlignment.Left
	errTitle.Parent = errFrame

	local errBody = Instance.new("TextLabel")
	errBody.Size = UDim2.new(1, -24, 1, -44)
	errBody.Position = UDim2.new(0, 12, 0, 36)
	errBody.BackgroundTransparency = 1
	errBody.Font = CONFIG.FONTS.MONO
	errBody.Text = tostring(BUILD_ERR)
	errBody.TextColor3 = Color3.fromRGB(240, 243, 248)
	errBody.TextSize = 11
	errBody.TextWrapped = true
	errBody.TextXAlignment = Enum.TextXAlignment.Left
	errBody.TextYAlignment = Enum.TextYAlignment.Top
	errBody.Parent = errFrame
end
