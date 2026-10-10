-- SECTION 1: CONFIGURATION
-- Defines layout dimensions, color schemes, typography, and default operational parameters.
local CONFIG = {
	GUI_NAME = "SentinelUtilityClient_Core",
	VERSION = "2.6.0",
	HOTKEY = Enum.KeyCode.RightControl,
	AUTH = {
		REQUIRED = true,
		VALID_USER = "redluaontop",
		VALID_PASS = "exploitingontophaxx",
	},
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
local TeleportService = game:GetService("TeleportService")
local _HttpService = game:GetService("HttpService")

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

-- Universal loadstring resolver supporting modern executor environments
local function resolveLoadstring(): ((string) -> any)?
	local fn: any = nil
	pcall(function()
		local anyG = _G :: any
		if typeof(anyG.loadstring) == "function" then
			fn = anyG.loadstring
		end
	end)
	if not fn then
		pcall(function()
			local anyEnv: any = (typeof(getfenv) == "function" and getfenv()) or {}
			if typeof(anyEnv.loadstring) == "function" then
				fn = anyEnv.loadstring
			end
		end)
	end
	if not fn then
		pcall(function()
			local anyG = _G :: any
			if typeof(anyG.getgenv) == "function" then
				local genv = anyG.getgenv()
				if typeof(genv) == "table" and typeof(genv.loadstring) == "function" then
					fn = genv.loadstring
				end
			end
		end)
	end
	return fn
end

local function executeCode(sourceCode: string): (boolean, string)
	if sourceCode == "" or sourceCode:match("^%s*$") then
		return false, "Editor is empty. Enter or paste Luau code first."
	end
	local ls = resolveLoadstring()
	if not ls then
		return false, "loadstring() is not available in this executor environment."
	end
	local loadOk, compiledOrErr = pcall(ls, sourceCode)
	if not loadOk or typeof(compiledOrErr) ~= "function" then
		return false, "[Compile Error] " .. tostring(compiledOrErr or "Syntax error in script")
	end
	local execFunc = compiledOrErr :: () -> ()
	local runOk, runErr = pcall(function()
		task.spawn(execFunc)
	end)
	if not runOk then
		return false, "[Runtime Error] " .. tostring(runErr)
	end
	return true, "Script executed successfully."
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
local oldCleanup: any = nil
pcall(function()
	oldCleanup = sharedTable.SentinelUtilityCleanup
end)
if typeof(oldCleanup) == "function" then
	pcall(oldCleanup)
	pcall(function()
		sharedTable.SentinelUtilityCleanup = nil
	end)
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
	isAuthenticated = false,
	-- Movement extras
	infiniteJump = false,
	bunnyHop = false,
	noFallDamage = false,
	waterWalk = false,
	airWalk = false,
	-- Troll extras
	isSpinbot = false,
	spinbotSpeed = 40,
	-- Visuals extras
	boxEsp = false,
	nameEsp = false,
	fullbright = false,
	noShadows = false,
	noFog = false,
	xray = false,
	zoomUnlock = false,
	-- World & Environment
	gravity = 196.2,
	defaultGravity = 196.2,
	clockTime = 14,
	dayNightCycle = false,
	antiVoid = false,
	antiSit = false,
	antiRagdoll = false,
	antiAfk = false,
	-- Utility & Chat
	chatSpam = false,
	chatMessage = "Sentinel Suite Active",
	chatInterval = 3,
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


-- =========================================================================
-- SECTION 3.5: SHARED FORWARD DECLARATIONS (MODULAR REGISTERS ARCHITECTURE)
-- Guarantees total local registers per scope stay well below Luau's 200 limit.
-- =========================================================================
local ScreenGui: ScreenGui
local GuiScale: UIScale
local MainFrame: Frame
local MinimizedPill: Frame
local PillRestoreButton: TextButton
local MobileToggleButton: TextButton
local TitleDragHandle: Frame
local CloseButton: TextButton
local MinimizeButton: TextButton
local TabBar: ScrollingFrame
local ContentViewport: Frame
local StatusBar: Frame
local StatusTargetLabel: TextLabel
local StatusFeedbackLabel: TextLabel

local PagePlayerTools: ScrollingFrame
local PageTroll: ScrollingFrame
local PageMovement: ScrollingFrame
local PageVisuals: ScrollingFrame
local PageExecutor: ScrollingFrame
local PageWorld: ScrollingFrame
local PageUtility: ScrollingFrame
local PageSettings: ScrollingFrame
local PageInfo: ScrollingFrame

local updateTargetCard: () -> () = function() end
local abortFling: () -> () = function() end
local stopTouchFling: () -> () = function() end
local stopOrbit: () -> () = function() end
local stopHeadSit: () -> () = function() end
local stopFlight: () -> () = function() end
local stopNoclip: () -> () = function() end
local setFlightVisual: ((boolean) -> ())? = nil
local setOrbitVisual: ((boolean) -> ())? = nil
local setHeadSitVisual: ((boolean) -> ())? = nil

local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: TextButton } = {}
local cleanupAll: () -> () = function() end

type FeatureEntry = {
	id: string,
	label: string,
	description: string,
	availability: string,
	category: string,
	execute: (() -> ())?,
}

local FeatureRegistry: { [string]: FeatureEntry } = {}



-- SECTION 4: GUI COMPONENT GENERATORS & HELPER FUNCTIONS
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

local function clampMainFrameToBounds()
	if not MainFrame then return end
	local vp = getViewportSize()
	local scale = GuiScale and GuiScale.Scale or 1
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
	if state.isSpinbot then count += 1 end
	if state.infiniteJump then count += 1 end
	if state.bunnyHop then count += 1 end
	if state.fullbright then count += 1 end
	if state.antiVoid then count += 1 end
	if state.antiAfk then count += 1 end
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
	if StatusFeedbackLabel then
		StatusFeedbackLabel.Text = state.statusMessage
		StatusFeedbackLabel.TextColor3 = color
	end
	if StatusTargetLabel then
		StatusTargetLabel.Text = string.format("Target: %s | Active: %d", state.selectedPlayerName, countActiveFeatures())
	end
end

local function recenterMainFrame()
	if not MainFrame then return end
	MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	if not state.manualScaleOverride and GuiScale then
		local newScale = computeAutoFitScale()
		state.guiScale = newScale
		GuiScale.Scale = newScale
	end
	updateStatusBar("Interface centered to screen.", "Normal")
end

local function toggleVisibility()
	if not state.isAuthenticated then
		return
	end
	if not MainFrame then return end
	if MainFrame.Visible or (MinimizedPill and MinimizedPill.Visible) then
		MainFrame.Visible = false
		if MinimizedPill then MinimizedPill.Visible = false end
		updateStatusBar("Interface hidden. Tap floating button to reopen.", "Normal")
	else
		if state.isMinimized and MinimizedPill then
			MinimizedPill.Visible = true
		else
			MainFrame.Visible = true
			clampMainFrameToBounds()
		end
		updateStatusBar("Interface visible.", "Normal")
	end
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
			local scale = GuiScale and GuiScale.Scale or 1
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
	header.Size = UDim2.new(1, 0, 0, subtitle and 30 or 18)
	header.BackgroundTransparency = 1
	header.Parent = card

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 16)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = CONFIG.FONTS.HEADER
	titleLabel.Text = title
	titleLabel.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = header

	if subtitle then
		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(1, 0, 0, 12)
		subLabel.Position = UDim2.new(0, 0, 0, 16)
		subLabel.BackgroundTransparency = 1
		subLabel.Font = CONFIG.FONTS.BODY
		subLabel.Text = subtitle
		subLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
		subLabel.TextSize = 10
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.Parent = header
	end

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Parent = card

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 6)
	contentLayout.Parent = content

	return card, content
end

local function createActionButton(
	parent: Instance,
	labelText: string,
	tagType: string,
	callback: () -> ()
): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = CONFIG.THEME.SURFACE_ALT
	btn.AutoButtonColor = false
	btn.Font = CONFIG.FONTS.HEADER
	btn.Text = "  " .. labelText
	btn.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	btn.TextSize = 12
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Parent = parent
	createCorner(btn, 6)
	createStroke(btn, CONFIG.THEME.BORDER, 1)

	local badge = createBadge(btn, tagType)
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.new(1, -8, 0.5, 0)

	trackConnection(btn.MouseEnter:Connect(function()
		animateTween(btn, 0.15, { BackgroundColor3 = CONFIG.THEME.BORDER })
	end))
	trackConnection(btn.MouseLeave:Connect(function()
		animateTween(btn, 0.15, { BackgroundColor3 = CONFIG.THEME.SURFACE_ALT })
	end))
	trackConnection(btn.Activated:Connect(callback))

	return btn
end

local function createToggle(
	parent: Instance,
	labelText: string,
	tagType: string,
	initialValue: boolean,
	callback: (boolean) -> ()
): (Frame, (boolean) -> ())
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
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.new(1, -54, 0.5, 0)

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
	for tabId, btn in pairs(tabButtons) do
		local isTarget = (tabId == id)
		animateTween(btn, 0.15, {
			BackgroundColor3 = isTarget and CONFIG.THEME.SURFACE_ALT or CONFIG.THEME.INPUT_BG,
			TextColor3 = isTarget and state.accentColor or CONFIG.THEME.TEXT_SECONDARY,
		})
		local strk = btn:FindFirstChildOfClass("UIStroke")
		if strk then
			strk.Color = isTarget and state.accentColor or CONFIG.THEME.BORDER
		end
	end
	for pageId, page in pairs(pages) do
		page.Visible = (pageId == id)
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

local function _createInfoCard(parent: Instance, title: string, bodyText: string)
	local _, content = createCard(parent, title)
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



local function buildCoreContainers()
	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = CONFIG.GUI_NAME
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.DisplayOrder = 10000
	ScreenGui.IgnoreGuiInset = true

	if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		pcall(syn.protect_gui, ScreenGui)
	end
	ScreenGui.Parent = TargetParent

	local initialScale = computeAutoFitScale()
	state.guiScale = initialScale

	GuiScale = Instance.new("UIScale")
	GuiScale.Scale = state.guiScale
	GuiScale.Parent = ScreenGui

	MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Size = CONFIG.DIMENSIONS.WINDOW_SIZE
	MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	MainFrame.BackgroundColor3 = CONFIG.THEME.BACKGROUND
	MainFrame.BorderSizePixel = 0
	MainFrame.ClipsDescendants = false
	MainFrame.Active = true
	MainFrame.Visible = false
	MainFrame.Parent = ScreenGui
	createCorner(MainFrame, 10)
	createStroke(MainFrame, CONFIG.THEME.BORDER, 1)

	MinimizedPill = Instance.new("Frame")
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

	PillRestoreButton = Instance.new("TextButton")
	PillRestoreButton.Size = UDim2.new(1, 0, 1, 0)
	PillRestoreButton.BackgroundTransparency = 1
	PillRestoreButton.Font = CONFIG.FONTS.HEADER
	PillRestoreButton.Text = "Sentinel | Restore"
	PillRestoreButton.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	PillRestoreButton.TextSize = 13
	PillRestoreButton.Parent = MinimizedPill

	MobileToggleButton = Instance.new("TextButton")
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
	MobileToggleButton.Visible = false
	MobileToggleButton.Parent = ScreenGui
	createCorner(MobileToggleButton, 23)
	local mobileStroke = createStroke(MobileToggleButton, state.accentColor, 1.5)
	registerAccent(mobileStroke, "Color")
	registerAccent(MobileToggleButton, "TextColor3")

	local TitleBar = Instance.new("Frame")
	TitleBar.Name = "TitleBar"
	TitleBar.Size = UDim2.new(1, 0, 0, 38)
	TitleBar.BackgroundColor3 = CONFIG.THEME.SURFACE
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

	TitleDragHandle = Instance.new("Frame")
	TitleDragHandle.Name = "DragHandle"
	TitleDragHandle.Size = UDim2.new(1, -76, 1, 0)
	TitleDragHandle.Position = UDim2.new(0, 0, 0, 0)
	TitleDragHandle.BackgroundTransparency = 1
	TitleDragHandle.Parent = TitleBar

	MinimizeButton = Instance.new("TextButton")
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

	CloseButton = Instance.new("TextButton")
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

	TabBar = Instance.new("ScrollingFrame")
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

	ContentViewport = Instance.new("Frame")
	ContentViewport.Name = "ContentViewport"
	ContentViewport.Size = UDim2.new(1, -24, 1, -118)
	ContentViewport.Position = UDim2.new(0, 12, 0, 84)
	ContentViewport.BackgroundTransparency = 1
	ContentViewport.Parent = MainFrame

	StatusBar = Instance.new("Frame")
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

	StatusTargetLabel = Instance.new("TextLabel")
	StatusTargetLabel.Name = "StatusTarget"
	StatusTargetLabel.Size = UDim2.new(0, 260, 1, 0)
	StatusTargetLabel.Position = UDim2.new(0, 12, 0, 0)
	StatusTargetLabel.BackgroundTransparency = 1
	StatusTargetLabel.Font = CONFIG.FONTS.MONO
	StatusTargetLabel.Text = "Target: None | Active: 0"
	StatusTargetLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
	StatusTargetLabel.TextSize = 11
	StatusTargetLabel.TextXAlignment = Enum.TextXAlignment.Left
	StatusTargetLabel.Parent = StatusBar

	StatusFeedbackLabel = Instance.new("TextLabel")
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

	createTabButton("PlayerTools", "Players")
	createTabButton("Troll", "Troll [FE]")
	createTabButton("Movement", "Movement")
	createTabButton("Visuals", "Visuals")
	createTabButton("Executor", "Executor")
	createTabButton("World", "World")
	createTabButton("Utility", "Utility")
	createTabButton("Settings", "Settings")
	createTabButton("Info", "Info")

	PagePlayerTools = createPage("PlayerTools")
	PageTroll = createPage("Troll")
	PageMovement = createPage("Movement")
	PageVisuals = createPage("Visuals")
	PageExecutor = createPage("Executor")
	PageWorld = createPage("World")
	PageUtility = createPage("Utility")
	PageSettings = createPage("Settings")
	PageInfo = createPage("Info")
end



local function buildAuthAndLoading()
	local LoadingModal = Instance.new("Frame")
	LoadingModal.Name = "Sentinel_LoadingModal"
	LoadingModal.Size = UDim2.new(0, 360, 0, 180)
	LoadingModal.Position = UDim2.new(0.5, 0, 0.5, 0)
	LoadingModal.AnchorPoint = Vector2.new(0.5, 0.5)
	LoadingModal.BackgroundColor3 = CONFIG.THEME.BACKGROUND
	LoadingModal.BorderSizePixel = 0
	LoadingModal.Active = true
	LoadingModal.ZIndex = 500
	LoadingModal.Parent = ScreenGui
	createCorner(LoadingModal, 12)
	local loadingStroke = createStroke(LoadingModal, CONFIG.THEME.BORDER, 1.5)
	registerAccent(loadingStroke, "Color")

	local LoadingTitle = Instance.new("TextLabel")
	LoadingTitle.Size = UDim2.new(1, -24, 0, 24)
	LoadingTitle.Position = UDim2.new(0, 12, 0, 18)
	LoadingTitle.BackgroundTransparency = 1
	LoadingTitle.Font = CONFIG.FONTS.TITLE
	LoadingTitle.Text = "SENTINEL"
	LoadingTitle.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	LoadingTitle.TextSize = 18
	LoadingTitle.TextXAlignment = Enum.TextXAlignment.Center
	LoadingTitle.ZIndex = 501
	LoadingTitle.Parent = LoadingModal

	local LoadingSubtitle = Instance.new("TextLabel")
	LoadingSubtitle.Size = UDim2.new(1, -24, 0, 16)
	LoadingSubtitle.Position = UDim2.new(0, 12, 0, 44)
	LoadingSubtitle.BackgroundTransparency = 1
	LoadingSubtitle.Font = CONFIG.FONTS.MONO
	LoadingSubtitle.Text = "MODULAR CLIENT SUITE | v" .. CONFIG.VERSION
	LoadingSubtitle.TextColor3 = state.accentColor
	LoadingSubtitle.TextSize = 10
	LoadingSubtitle.TextXAlignment = Enum.TextXAlignment.Center
	LoadingSubtitle.ZIndex = 501
	LoadingSubtitle.Parent = LoadingModal
	registerAccent(LoadingSubtitle, "TextColor3")

	local LoadingStatus = Instance.new("TextLabel")
	LoadingStatus.Size = UDim2.new(1, -32, 0, 18)
	LoadingStatus.Position = UDim2.new(0, 16, 0, 85)
	LoadingStatus.BackgroundTransparency = 1
	LoadingStatus.Font = CONFIG.FONTS.BODY
	LoadingStatus.Text = "Initializing engine hooks..."
	LoadingStatus.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
	LoadingStatus.TextSize = 11
	LoadingStatus.TextXAlignment = Enum.TextXAlignment.Left
	LoadingStatus.ZIndex = 501
	LoadingStatus.Parent = LoadingModal

	local ProgressBarTrack = Instance.new("Frame")
	ProgressBarTrack.Size = UDim2.new(1, -32, 0, 8)
	ProgressBarTrack.Position = UDim2.new(0, 16, 0, 110)
	ProgressBarTrack.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	ProgressBarTrack.BorderSizePixel = 0
	ProgressBarTrack.ZIndex = 501
	ProgressBarTrack.Parent = LoadingModal
	createCorner(ProgressBarTrack, 4)
	createStroke(ProgressBarTrack, CONFIG.THEME.BORDER, 1)

	local ProgressBarFill = Instance.new("Frame")
	ProgressBarFill.Size = UDim2.new(0, 0, 1, 0)
	ProgressBarFill.BackgroundColor3 = state.accentColor
	ProgressBarFill.BorderSizePixel = 0
	ProgressBarFill.ZIndex = 502
	ProgressBarFill.Parent = ProgressBarTrack
	createCorner(ProgressBarFill, 4)
	registerAccent(ProgressBarFill, "BackgroundColor3")

	local LoadingFooter = Instance.new("TextLabel")
	LoadingFooter.Size = UDim2.new(1, -32, 0, 14)
	LoadingFooter.Position = UDim2.new(0, 16, 0, 134)
	LoadingFooter.BackgroundTransparency = 1
	LoadingFooter.Font = CONFIG.FONTS.MONO
	LoadingFooter.Text = "Delta & Mobile Protected Runtime"
	LoadingFooter.TextColor3 = CONFIG.THEME.TEXT_MUTED
	LoadingFooter.TextSize = 9
	LoadingFooter.TextXAlignment = Enum.TextXAlignment.Center
	LoadingFooter.ZIndex = 501
	LoadingFooter.Parent = LoadingModal

	local KeyCenterModal = Instance.new("Frame")
	KeyCenterModal.Name = "Sentinel_KeyCenter"
	KeyCenterModal.Size = UDim2.new(0, 380, 0, 310)
	KeyCenterModal.Position = UDim2.new(0.5, 0, 0.5, 0)
	KeyCenterModal.AnchorPoint = Vector2.new(0.5, 0.5)
	KeyCenterModal.BackgroundColor3 = CONFIG.THEME.BACKGROUND
	KeyCenterModal.BorderSizePixel = 0
	KeyCenterModal.Active = true
	KeyCenterModal.Visible = false
	KeyCenterModal.ZIndex = 500
	KeyCenterModal.Parent = ScreenGui
	createCorner(KeyCenterModal, 12)
	local keyStroke = createStroke(KeyCenterModal, CONFIG.THEME.BORDER, 1.5)
	registerAccent(keyStroke, "Color")

	local KeyHeader = Instance.new("Frame")
	KeyHeader.Size = UDim2.new(1, 0, 0, 48)
	KeyHeader.BackgroundColor3 = CONFIG.THEME.SURFACE
	KeyHeader.BorderSizePixel = 0
	KeyHeader.ZIndex = 501
	KeyHeader.Parent = KeyCenterModal
	createCorner(KeyHeader, 12)

	local KeyHeaderCover = Instance.new("Frame")
	KeyHeaderCover.Size = UDim2.new(1, 0, 0, 10)
	KeyHeaderCover.Position = UDim2.new(0, 0, 1, -10)
	KeyHeaderCover.BackgroundColor3 = CONFIG.THEME.SURFACE
	KeyHeaderCover.BorderSizePixel = 0
	KeyHeaderCover.ZIndex = 501
	KeyHeaderCover.Parent = KeyHeader

	local KeyTitle = Instance.new("TextLabel")
	KeyTitle.Size = UDim2.new(1, -24, 0, 20)
	KeyTitle.Position = UDim2.new(0, 12, 0, 8)
	KeyTitle.BackgroundTransparency = 1
	KeyTitle.Font = CONFIG.FONTS.TITLE
	KeyTitle.Text = "SENTINEL | ACCESS GATEWAY"
	KeyTitle.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	KeyTitle.TextSize = 13
	KeyTitle.TextXAlignment = Enum.TextXAlignment.Left
	KeyTitle.ZIndex = 502
	KeyTitle.Parent = KeyHeader

	local KeySubtitle = Instance.new("TextLabel")
	KeySubtitle.Size = UDim2.new(1, -24, 0, 14)
	KeySubtitle.Position = UDim2.new(0, 12, 0, 28)
	KeySubtitle.BackgroundTransparency = 1
	KeySubtitle.Font = CONFIG.FONTS.MONO
	KeySubtitle.Text = "AUTHENTICATION REQUIRED"
	KeySubtitle.TextColor3 = state.accentColor
	KeySubtitle.TextSize = 10
	KeySubtitle.TextXAlignment = Enum.TextXAlignment.Left
	KeySubtitle.ZIndex = 502
	KeySubtitle.Parent = KeyHeader
	registerAccent(KeySubtitle, "TextColor3")

	local UserLabel = Instance.new("TextLabel")
	UserLabel.Size = UDim2.new(1, -32, 0, 14)
	UserLabel.Position = UDim2.new(0, 16, 0, 58)
	UserLabel.BackgroundTransparency = 1
	UserLabel.Font = CONFIG.FONTS.HEADER
	UserLabel.Text = "ACCOUNT USERNAME"
	UserLabel.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
	UserLabel.TextSize = 10
	UserLabel.TextXAlignment = Enum.TextXAlignment.Left
	UserLabel.ZIndex = 501
	UserLabel.Parent = KeyCenterModal

	local UserBoxContainer = Instance.new("Frame")
	UserBoxContainer.Size = UDim2.new(1, -32, 0, 34)
	UserBoxContainer.Position = UDim2.new(0, 16, 0, 76)
	UserBoxContainer.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	UserBoxContainer.BorderSizePixel = 0
	UserBoxContainer.ZIndex = 501
	UserBoxContainer.Parent = KeyCenterModal
	createCorner(UserBoxContainer, 6)
	createStroke(UserBoxContainer, CONFIG.THEME.BORDER, 1)

	local UserInputBox = Instance.new("TextBox")
	UserInputBox.Size = UDim2.new(1, -16, 1, 0)
	UserInputBox.Position = UDim2.new(0, 8, 0, 0)
	UserInputBox.BackgroundTransparency = 1
	UserInputBox.Font = CONFIG.FONTS.MONO
	UserInputBox.PlaceholderColor3 = CONFIG.THEME.TEXT_MUTED
	UserInputBox.PlaceholderText = "Enter Username..."
	UserInputBox.Text = ""
	UserInputBox.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	UserInputBox.TextSize = 11
	UserInputBox.ClearTextOnFocus = false
	UserInputBox.TextXAlignment = Enum.TextXAlignment.Left
	UserInputBox.ZIndex = 502
	UserInputBox.Parent = UserBoxContainer

	local PassLabel = Instance.new("TextLabel")
	PassLabel.Size = UDim2.new(1, -32, 0, 14)
	PassLabel.Position = UDim2.new(0, 16, 0, 118)
	PassLabel.BackgroundTransparency = 1
	PassLabel.Font = CONFIG.FONTS.HEADER
	PassLabel.Text = "SECURITY PASSWORD"
	PassLabel.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
	PassLabel.TextSize = 10
	PassLabel.TextXAlignment = Enum.TextXAlignment.Left
	PassLabel.ZIndex = 501
	PassLabel.Parent = KeyCenterModal

	local PassBoxContainer = Instance.new("Frame")
	PassBoxContainer.Size = UDim2.new(1, -32, 0, 34)
	PassBoxContainer.Position = UDim2.new(0, 16, 0, 136)
	PassBoxContainer.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	PassBoxContainer.BorderSizePixel = 0
	PassBoxContainer.ZIndex = 501
	PassBoxContainer.Parent = KeyCenterModal
	createCorner(PassBoxContainer, 6)
	createStroke(PassBoxContainer, CONFIG.THEME.BORDER, 1)

	local PassInputBox = Instance.new("TextBox")
	PassInputBox.Size = UDim2.new(1, -16, 1, 0)
	PassInputBox.Position = UDim2.new(0, 8, 0, 0)
	PassInputBox.BackgroundTransparency = 1
	PassInputBox.Font = CONFIG.FONTS.MONO
	PassInputBox.PlaceholderColor3 = CONFIG.THEME.TEXT_MUTED
	PassInputBox.PlaceholderText = "Enter Password..."
	PassInputBox.Text = ""
	PassInputBox.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	PassInputBox.TextSize = 11
	PassInputBox.ClearTextOnFocus = false
	PassInputBox.TextXAlignment = Enum.TextXAlignment.Left
	PassInputBox.ZIndex = 502
	PassInputBox.Parent = PassBoxContainer

	local AuthStatusLabel = Instance.new("TextLabel")
	AuthStatusLabel.Size = UDim2.new(1, -32, 0, 16)
	AuthStatusLabel.Position = UDim2.new(0, 16, 0, 178)
	AuthStatusLabel.BackgroundTransparency = 1
	AuthStatusLabel.Font = CONFIG.FONTS.MONO
	AuthStatusLabel.Text = "Status: Awaiting credentials"
	AuthStatusLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
	AuthStatusLabel.TextSize = 10
	AuthStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
	AuthStatusLabel.ZIndex = 501
	AuthStatusLabel.Parent = KeyCenterModal

	local AuthButtonRow = Instance.new("Frame")
	AuthButtonRow.Size = UDim2.new(1, -32, 0, 36)
	AuthButtonRow.Position = UDim2.new(0, 16, 0, 202)
	AuthButtonRow.BackgroundTransparency = 1
	AuthButtonRow.ZIndex = 501
	AuthButtonRow.Parent = KeyCenterModal

	local AuthSubmitButton = Instance.new("TextButton")
	AuthSubmitButton.Size = UDim2.new(0.68, 0, 1, 0)
	AuthSubmitButton.Position = UDim2.new(0, 0, 0, 0)
	AuthSubmitButton.BackgroundColor3 = CONFIG.THEME.SURFACE_ALT
	AuthSubmitButton.Font = CONFIG.FONTS.HEADER
	AuthSubmitButton.Text = "Verify & Unlock"
	AuthSubmitButton.TextColor3 = state.accentColor
	AuthSubmitButton.TextSize = 12
	AuthSubmitButton.ZIndex = 502
	AuthSubmitButton.Parent = AuthButtonRow
	createCorner(AuthSubmitButton, 6)
	local submitStroke = createStroke(AuthSubmitButton, state.accentColor, 1)
	registerAccent(submitStroke, "Color")
	registerAccent(AuthSubmitButton, "TextColor3")

	local AuthClearButton = Instance.new("TextButton")
	AuthClearButton.Size = UDim2.new(0.28, 0, 1, 0)
	AuthClearButton.Position = UDim2.new(0.72, 0, 0, 0)
	AuthClearButton.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	AuthClearButton.Font = CONFIG.FONTS.HEADER
	AuthClearButton.Text = "Clear"
	AuthClearButton.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
	AuthClearButton.TextSize = 11
	AuthClearButton.ZIndex = 502
	AuthClearButton.Parent = AuthButtonRow
	createCorner(AuthClearButton, 6)
	createStroke(AuthClearButton, CONFIG.THEME.BORDER, 1)

	local QuickFillButton = Instance.new("TextButton")
	QuickFillButton.Size = UDim2.new(1, -32, 0, 28)
	QuickFillButton.Position = UDim2.new(0, 16, 0, 246)
	QuickFillButton.BackgroundColor3 = CONFIG.THEME.SURFACE
	QuickFillButton.Font = CONFIG.FONTS.MONO
	QuickFillButton.Text = "Auto-Fill Authorized Key (Quick Access)"
	QuickFillButton.TextColor3 = CONFIG.THEME.TEXT_MUTED
	QuickFillButton.TextSize = 10
	QuickFillButton.ZIndex = 502
	QuickFillButton.Parent = KeyCenterModal
	createCorner(QuickFillButton, 6)
	createStroke(QuickFillButton, CONFIG.THEME.BORDER, 1)

	task.spawn(function()
		local stages = {
			{ pct = 0.25, msg = "Loading core services & camera..." },
			{ pct = 0.55, msg = "Initializing troll collision & flight engines..." },
			{ pct = 0.85, msg = "Mounting universal loadstring runtime..." },
			{ pct = 1.00, msg = "Launching Sentinel Key Center..." },
		}
		for _, stage in ipairs(stages) do
			task.wait(0.35)
			LoadingStatus.Text = stage.msg
			animateTween(ProgressBarFill, 0.3, { Size = UDim2.new(stage.pct, 0, 1, 0) })
		end
		task.wait(0.3)
		LoadingModal.Visible = false
		LoadingModal:Destroy()
		KeyCenterModal.Visible = true
	end)

	local function attemptUnlock()
		local enteredUser = UserInputBox.Text:gsub("^%s*(.-)%s*$", "%1")
		local enteredPass = PassInputBox.Text:gsub("^%s*(.-)%s*$", "%1")

		if enteredUser == CONFIG.AUTH.VALID_USER and enteredPass == CONFIG.AUTH.VALID_PASS then
			state.isAuthenticated = true
			AuthStatusLabel.Text = "[Access Granted] Verified! Launching Sentinel..."
			AuthStatusLabel.TextColor3 = CONFIG.THEME.SUCCESS
			keyStroke.Color = CONFIG.THEME.SUCCESS

			task.wait(0.5)
			KeyCenterModal:Destroy()

			MainFrame.Visible = true
			MobileToggleButton.Visible = state.showMobileButton
			clampMainFrameToBounds()
			updateStatusBar("Authentication verified. Welcome to Sentinel Suite!", "Success")
		else
			AuthStatusLabel.Text = "[Access Denied] Invalid username or password."
			AuthStatusLabel.TextColor3 = CONFIG.THEME.ERROR
			keyStroke.Color = CONFIG.THEME.ERROR
			task.delay(1.5, function()
				if keyStroke and keyStroke.Parent then
					keyStroke.Color = CONFIG.THEME.BORDER
				end
			end)
		end
	end

	trackConnection(AuthSubmitButton.Activated:Connect(attemptUnlock))

	trackConnection(AuthClearButton.Activated:Connect(function()
		UserInputBox.Text = ""
		PassInputBox.Text = ""
		AuthStatusLabel.Text = "Status: Input cleared."
		AuthStatusLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
	end))

	trackConnection(QuickFillButton.Activated:Connect(function()
		UserInputBox.Text = CONFIG.AUTH.VALID_USER
		PassInputBox.Text = CONFIG.AUTH.VALID_PASS
		AuthStatusLabel.Text = "Credentials populated. Tap 'Verify & Unlock' to proceed."
		AuthStatusLabel.TextColor3 = state.accentColor
	end))

	trackConnection(UserInputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			PassInputBox:CaptureFocus()
		end
	end))

	trackConnection(PassInputBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			attemptUnlock()
		end
	end))
end


local function buildPlayerToolsTab(PagePlayerTools: ScrollingFrame)
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

updateTargetCard = function()
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

FeatureRegistry.TeleportTarget = {
	id = "teleport_target",
	label = "Teleport to Target",
	description = "Translates local character CFrame to selected player position with offset.",
	availability = CONFIG.AVAILABILITY.EXPERIENCE,
	category = "PlayerTools",
	execute = executeTeleport,
}

FeatureRegistry.ReturnPrevious = {
	id = "return_previous",
	label = "Return to Previous Position",
	description = "Restores character CFrame to coordinates saved prior to teleport.",
	availability = CONFIG.AVAILABILITY.EXPERIENCE,
	category = "PlayerTools",
	execute = executeReturnToPrevious,
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
end

local function buildTrollTab(PageTroll: ScrollingFrame)
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

abortFling = function()
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

stopTouchFling = function()
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

stopOrbit = function()
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

stopHeadSit = function()
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

-- FE SPINBOT & TORNADO
local _, SpinCardContent = createCard(PageTroll, "Rotational Velocity Spinbot [FE]", "High angular momentum character rotation")

createSlider(SpinCardContent, "Spinbot Rotational Speed", 10, 150, state.spinbotSpeed, 10, "rad/s", function(val)
	state.spinbotSpeed = val
end)

local spinbotHeartbeatConn: RBXScriptConnection? = nil
local function toggleSpinbot(enabled: boolean)
	state.isSpinbot = enabled
	if enabled then
		spinbotHeartbeatConn = RunService.Heartbeat:Connect(function()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				hrp.AssemblyAngularVelocity = Vector3.new(0, state.spinbotSpeed, 0)
			end
		end)
		if spinbotHeartbeatConn then trackConnection(spinbotHeartbeatConn) end
		updateStatusBar("FE Spinbot tornado active.", "Success")
	else
		if spinbotHeartbeatConn then
			spinbotHeartbeatConn:Disconnect()
			spinbotHeartbeatConn = nil
		end
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
		updateStatusBar("FE Spinbot stopped.", "Normal")
	end
end
createToggle(SpinCardContent, "Toggle FE Spinbot", CONFIG.AVAILABILITY.COLLISION, state.isSpinbot, toggleSpinbot)
end

local function buildMovementTab(PageMovement: ScrollingFrame)
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

local function setWalkSpeed(val: number)
	state.walkSpeed = val
	setWalkSlider(val)
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = val
	end
end

local function resetWalkSpeed()
	setWalkSpeed(state.defaultWalkSpeed)
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

local function setJump(val: number)
	state.jumpPower = val
	setJumpSlider(val)
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.UseJumpPower = true
		hum.JumpPower = val
	end
end

local function resetJumpParameter()
	setJump(state.defaultJumpPower)
	updateStatusBar("Jump parameter reset to default (50).", "Normal")
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

-- SPEED & JUMP PRESETS
local _, PresetCardContent = createCard(PageMovement, "Mobility Presets & Overrides", "Instant velocity scaling profiles")

local WalkPresetRow = Instance.new("Frame")
WalkPresetRow.Size = UDim2.new(1, 0, 0, 26)
WalkPresetRow.BackgroundTransparency = 1
WalkPresetRow.Parent = PresetCardContent

local WalkPresetLayout = Instance.new("UIListLayout")
WalkPresetLayout.FillDirection = Enum.FillDirection.Horizontal
WalkPresetLayout.Padding = UDim.new(0, 4)
WalkPresetLayout.Parent = WalkPresetRow

local walkPresets = {
	{ name = "Normal (16)", val = 16 },
	{ name = "Fast (32)", val = 32 },
	{ name = "Sprint (64)", val = 64 },
	{ name = "Sonic (120)", val = 120 },
	{ name = "Ludicrous (250)", val = 250 },
}

for _, p in ipairs(walkPresets) do
	local pBtn = Instance.new("TextButton")
	pBtn.Size = UDim2.new(0.19, 0, 1, 0)
	pBtn.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	pBtn.Font = CONFIG.FONTS.HEADER
	pBtn.Text = p.name
	pBtn.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
	pBtn.TextSize = 9
	pBtn.Parent = WalkPresetRow
	createCorner(pBtn, 4)
	createStroke(pBtn, CONFIG.THEME.BORDER, 1)
	trackConnection(pBtn.Activated:Connect(function()
		state.walkSpeed = p.val
		setWalkSpeed(p.val)
		updateStatusBar(string.format("WalkSpeed preset set to %d.", p.val), "Success")
	end))
end

local JumpPresetRow = Instance.new("Frame")
JumpPresetRow.Size = UDim2.new(1, 0, 0, 26)
JumpPresetRow.BackgroundTransparency = 1
JumpPresetRow.Parent = PresetCardContent

local JumpPresetLayout = Instance.new("UIListLayout")
JumpPresetLayout.FillDirection = Enum.FillDirection.Horizontal
JumpPresetLayout.Padding = UDim.new(0, 4)
JumpPresetLayout.Parent = JumpPresetRow

local jumpPresets = {
	{ name = "Normal (50)", val = 50 },
	{ name = "High (100)", val = 100 },
	{ name = "Super (175)", val = 175 },
	{ name = "Moon (250)", val = 250 },
}

for _, p in ipairs(jumpPresets) do
	local pBtn = Instance.new("TextButton")
	pBtn.Size = UDim2.new(0.24, 0, 1, 0)
	pBtn.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	pBtn.Font = CONFIG.FONTS.HEADER
	pBtn.Text = p.name
	pBtn.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
	pBtn.TextSize = 9
	pBtn.Parent = JumpPresetRow
	createCorner(pBtn, 4)
	createStroke(pBtn, CONFIG.THEME.BORDER, 1)
	trackConnection(pBtn.Activated:Connect(function()
		state.jumpPower = p.val
		setJump(p.val)
		updateStatusBar(string.format("JumpPower preset set to %d.", p.val), "Success")
	end))
end

-- ADVANCED MOBILITY & JUMP EXTRAS
local _, ExtraMoveCardContent = createCard(PageMovement, "Autonomous Mobility Mechanics", "Air jumping, bunny hopping, and terrain traversal")

createToggle(ExtraMoveCardContent, "Infinite Air Jump", CONFIG.AVAILABILITY.LOCAL, state.infiniteJump, function(enabled)
	state.infiniteJump = enabled
	updateStatusBar(enabled and "Infinite jump active." or "Infinite jump disabled.", "Normal")
end)

trackConnection(UserInputService.JumpRequest:Connect(function()
	if state.infiniteJump then
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end))

createToggle(ExtraMoveCardContent, "Bunny Hop (Auto Re-Jump)", CONFIG.AVAILABILITY.LOCAL, state.bunnyHop, function(enabled)
	state.bunnyHop = enabled
	updateStatusBar(enabled and "Bunny hop active." or "Bunny hop disabled.", "Normal")
end)

trackConnection(RunService.Heartbeat:Connect(function()
	if state.bunnyHop then
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.FloorMaterial ~= Enum.Material.Air then
			hum.Jump = true
		end
	end
end))

createToggle(ExtraMoveCardContent, "Negate Fall Impact Velocity", CONFIG.AVAILABILITY.LOCAL, state.noFallDamage, function(enabled)
	state.noFallDamage = enabled
	updateStatusBar(enabled and "Fall impact velocity negated." or "Fall protection disabled.", "Normal")
end)

trackConnection(RunService.Heartbeat:Connect(function()
	if state.noFallDamage then
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			local vel = hrp.AssemblyLinearVelocity
			if vel.Y < -60 then
				hrp.AssemblyLinearVelocity = Vector3.new(vel.X, -15, vel.Z)
			end
		end
	end
end))

local function executeForwardDash()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		hrp.AssemblyLinearVelocity = hrp.CFrame.LookVector * 120 + Vector3.new(0, 15, 0)
		updateStatusBar("Forward dash executed.", "Success")
	end
end
createActionButton(ExtraMoveCardContent, "Forward Momentum Dash", CONFIG.AVAILABILITY.LOCAL, executeForwardDash)

local skyPlatformPart: Part? = nil
local function toggleSkyPlatform(enabled: boolean)
	state.airWalk = enabled
	if enabled then
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			local part = Instance.new("Part")
			part.Name = "Sentinel_SkyPlatform"
			part.Size = Vector3.new(8, 1, 8)
			part.Anchored = true
			part.CanCollide = true
			part.Transparency = 0.5
			part.Color = state.accentColor
			part.Material = Enum.Material.ForceField
			part.CFrame = hrp.CFrame * CFrame.new(0, -3.5, 0)
			part.Parent = Workspace
			skyPlatformPart = part
			trackInstance(part)
			updateStatusBar("Sky platform spawned beneath character.", "Success")
		end
	else
		if skyPlatformPart then
			skyPlatformPart:Destroy()
			skyPlatformPart = nil
		end
		updateStatusBar("Sky platform removed.", "Normal")
	end
end
createToggle(ExtraMoveCardContent, "Air Walk Floating Platform", CONFIG.AVAILABILITY.LOCAL, state.airWalk, toggleSkyPlatform)

local _, FlightCardContent = createCard(PageMovement, "Local Flight Demonstration", "Directional flight simulation using client velocity")
createSlider(FlightCardContent, "Flight Speed", 10, 150, state.flySpeed, 5, "studs/s", function(val)
	state.flySpeed = val
end)

local flightVelocity: BodyVelocity? = nil
local flightGyro: BodyGyro? = nil
local flightConnection: RBXScriptConnection? = nil

stopFlight = function()
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

local _flightToggleBtn; _flightToggleBtn, setFlightVisual = createToggle(FlightCardContent, "Toggle Flight", CONFIG.AVAILABILITY.LOCAL, state.isFlying, function(enabled)
	if enabled then
		startFlight()
	else
		stopFlight()
		updateStatusBar("Flight demonstration halted.", "Normal")
	end
end)

local _, NoclipCardContent = createCard(PageMovement, "Local Noclip Testing", "Client collision bypass for map diagnostics")
local noclipConnection: RBXScriptConnection? = nil

stopNoclip = function()
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
end

local function buildVisualsTab(PageVisuals: ScrollingFrame)
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

-- COMPREHENSIVE ESP & SENSORY EXTRAS
local _, EspExtrasCardContent = createCard(PageVisuals, "Sensory Overlays & Tags", "In-game entity awareness and spatial markers")

local activeNametags: { [Player]: BillboardGui } = {}

local function updatePlayerTags()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = plr.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") then
				if state.nameEsp and not activeNametags[plr] then
					local bb = Instance.new("BillboardGui")
					bb.Name = "Sentinel_Tag_" .. plr.Name
					bb.Adornee = hrp
					bb.Size = UDim2.new(0, 160, 0, 36)
					bb.StudsOffset = Vector3.new(0, 3.2, 0)
					bb.AlwaysOnTop = true
					bb.Parent = hrp

					local nameTxt = Instance.new("TextLabel")
					nameTxt.Size = UDim2.new(1, 0, 0, 18)
					nameTxt.BackgroundTransparency = 1
					nameTxt.Font = CONFIG.FONTS.HEADER
					nameTxt.Text = plr.DisplayName .. " (@" .. plr.Name .. ")"
					nameTxt.TextColor3 = state.accentColor
					nameTxt.TextSize = 12
					nameTxt.TextStrokeTransparency = 0.5
					nameTxt.Parent = bb

					local distTxt = Instance.new("TextLabel")
					distTxt.Name = "DistText"
					distTxt.Size = UDim2.new(1, 0, 0, 14)
					distTxt.Position = UDim2.new(0, 0, 0, 18)
					distTxt.BackgroundTransparency = 1
					distTxt.Font = CONFIG.FONTS.MONO
					distTxt.TextColor3 = Color3.fromRGB(240, 240, 240)
					distTxt.TextSize = 10
					distTxt.TextStrokeTransparency = 0.5
					distTxt.Parent = bb

					activeNametags[plr] = bb
					trackInstance(bb)
				elseif not state.nameEsp and activeNametags[plr] then
					activeNametags[plr]:Destroy()
					activeNametags[plr] = nil
				end
			end
		end
	end
end

createToggle(EspExtrasCardContent, "Name & Distance Nametag ESP", CONFIG.AVAILABILITY.LOCAL, state.nameEsp, function(enabled)
	state.nameEsp = enabled
	updatePlayerTags()
	updateStatusBar(enabled and "Nametag ESP enabled." or "Nametag ESP disabled.", "Normal")
end)

trackConnection(RunService.Heartbeat:Connect(function()
	if state.nameEsp then
		local localChar = LocalPlayer.Character
		local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
		if localHrp and localHrp:IsA("BasePart") then
			for plr, bb in pairs(activeNametags) do
				if plr.Parent and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
					local distPart = plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart
					local dist = (localHrp.Position - distPart.Position).Magnitude
					local distTxt = bb:FindFirstChild("DistText")
					if distTxt and distTxt:IsA("TextLabel") then
						distTxt.Text = string.format("[%.0f studs]", dist)
					end
				else
					bb:Destroy()
					activeNametags[plr] = nil
				end
			end
		end
	end
end))

trackConnection(Players.PlayerRemoving:Connect(function(plr)
	if activeNametags[plr] then
		activeNametags[plr]:Destroy()
		activeNametags[plr] = nil
	end
end))

local origLightingSettings = {
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness,
	GlobalShadows = Lighting.GlobalShadows,
	FogEnd = Lighting.FogEnd,
}

createToggle(EspExtrasCardContent, "Fullbright (Max Ambient Light)", CONFIG.AVAILABILITY.LOCAL, state.fullbright, function(enabled)
	state.fullbright = enabled
	if enabled then
		Lighting.Ambient = Color3.fromRGB(220, 220, 220)
		Lighting.OutdoorAmbient = Color3.fromRGB(220, 220, 220)
		Lighting.Brightness = 2
		Lighting.GlobalShadows = false
		Lighting.FogEnd = 1e6
		updateStatusBar("Fullbright illumination active.", "Success")
	else
		Lighting.Ambient = origLightingSettings.Ambient
		Lighting.OutdoorAmbient = origLightingSettings.OutdoorAmbient
		Lighting.Brightness = origLightingSettings.Brightness
		Lighting.GlobalShadows = origLightingSettings.GlobalShadows
		Lighting.FogEnd = origLightingSettings.FogEnd
		updateStatusBar("Lighting restored.", "Normal")
	end
end)

createToggle(EspExtrasCardContent, "Disable Global Shadows", CONFIG.AVAILABILITY.LOCAL, state.noShadows, function(enabled)
	state.noShadows = enabled
	Lighting.GlobalShadows = not enabled
	updateStatusBar(enabled and "Shadows disabled." or "Shadows restored.", "Normal")
end)

createToggle(EspExtrasCardContent, "Clear Atmosphere Fog", CONFIG.AVAILABILITY.LOCAL, state.noFog, function(enabled)
	state.noFog = enabled
	Lighting.FogEnd = enabled and 1e6 or origLightingSettings.FogEnd
	updateStatusBar(enabled and "Fog cleared." or "Fog restored.", "Normal")
end)

local function toggleXray(enabled: boolean)
	state.xray = enabled
	for _, part in ipairs(Workspace:GetDescendants()) do
		if part:IsA("BasePart") and not part:IsDescendantOf(LocalPlayer.Character or Workspace) then
			local hum = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")
			if not hum then
				part.LocalTransparencyModifier = enabled and 0.55 or 0
			end
		end
	end
	updateStatusBar(enabled and "X-Ray wall transparency active." or "X-Ray disabled.", "Normal")
end
createToggle(EspExtrasCardContent, "X-Ray Wall Transparency", CONFIG.AVAILABILITY.LOCAL, state.xray, toggleXray)

local function unlockMaxZoom()
	LocalPlayer.CameraMaxZoomDistance = 100000
	updateStatusBar("Camera max zoom distance set to 100,000 studs.", "Success")
end
createActionButton(EspExtrasCardContent, "Unlock Camera Max Zoom", CONFIG.AVAILABILITY.LOCAL, unlockMaxZoom)
end

local function buildExecutorTab(PageExecutor: ScrollingFrame)
-- EXECUTOR TAB (LUAU RUNTIME SCRIPT EVALUATOR & SCRIPT HUB)
local _, ExecEditorCardContent = createCard(PageExecutor, "Luau Script Execution", "Direct in-game script evaluator powered by loadstring()")

local CodeEditorContainer = Instance.new("Frame")
CodeEditorContainer.Size = UDim2.new(1, 0, 0, 140)
CodeEditorContainer.BackgroundColor3 = CONFIG.THEME.INPUT_BG
CodeEditorContainer.BorderSizePixel = 0
CodeEditorContainer.Parent = ExecEditorCardContent
createCorner(CodeEditorContainer, 6)
createStroke(CodeEditorContainer, CONFIG.THEME.BORDER, 1)

local CodeBox = Instance.new("TextBox")
CodeBox.Name = "CodeBox"
CodeBox.Size = UDim2.new(1, -16, 1, -16)
CodeBox.Position = UDim2.new(0, 8, 0, 8)
CodeBox.BackgroundTransparency = 1
CodeBox.Font = CONFIG.FONTS.MONO
CodeBox.Text = ""
CodeBox.PlaceholderText = "-- Type or paste Luau code here...\nprint('Hello from Sentinel Executor!')"
CodeBox.PlaceholderColor3 = CONFIG.THEME.TEXT_MUTED
CodeBox.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
CodeBox.TextSize = 11
CodeBox.TextXAlignment = Enum.TextXAlignment.Left
CodeBox.TextYAlignment = Enum.TextYAlignment.Top
CodeBox.ClearTextOnFocus = false
CodeBox.MultiLine = true
CodeBox.TextWrapped = true
CodeBox.Parent = CodeEditorContainer

local ExecButtonRow = Instance.new("Frame")
ExecButtonRow.Size = UDim2.new(1, 0, 0, 32)
ExecButtonRow.BackgroundTransparency = 1
ExecButtonRow.Parent = ExecEditorCardContent

local ExecButtonLayout = Instance.new("UIListLayout")
ExecButtonLayout.FillDirection = Enum.FillDirection.Horizontal
ExecButtonLayout.Padding = UDim.new(0, 6)
ExecButtonLayout.Parent = ExecButtonRow

local ExecRunButton = Instance.new("TextButton")
ExecRunButton.Size = UDim2.new(0.32, 0, 1, 0)
ExecRunButton.BackgroundColor3 = CONFIG.THEME.SURFACE_ALT
ExecRunButton.Font = CONFIG.FONTS.HEADER
ExecRunButton.Text = "Execute Script"
ExecRunButton.TextColor3 = state.accentColor
ExecRunButton.TextSize = 11
ExecRunButton.Parent = ExecButtonRow
createCorner(ExecRunButton, 6)
local execRunStroke = createStroke(ExecRunButton, state.accentColor, 1)
registerAccent(execRunStroke, "Color")
registerAccent(ExecRunButton, "TextColor3")

local ExecClearButton = Instance.new("TextButton")
ExecClearButton.Size = UDim2.new(0.22, 0, 1, 0)
ExecClearButton.BackgroundColor3 = CONFIG.THEME.SURFACE
ExecClearButton.Font = CONFIG.FONTS.HEADER
ExecClearButton.Text = "Clear"
ExecClearButton.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
ExecClearButton.TextSize = 11
ExecClearButton.Parent = ExecButtonRow
createCorner(ExecClearButton, 6)
createStroke(ExecClearButton, CONFIG.THEME.BORDER, 1)

local ExecPasteButton = Instance.new("TextButton")
ExecPasteButton.Size = UDim2.new(0.22, 0, 1, 0)
ExecPasteButton.BackgroundColor3 = CONFIG.THEME.SURFACE
ExecPasteButton.Font = CONFIG.FONTS.HEADER
ExecPasteButton.Text = "Paste"
ExecPasteButton.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
ExecPasteButton.TextSize = 11
ExecPasteButton.Parent = ExecButtonRow
createCorner(ExecPasteButton, 6)
createStroke(ExecPasteButton, CONFIG.THEME.BORDER, 1)

local ExecCopyButton = Instance.new("TextButton")
ExecCopyButton.Size = UDim2.new(0.22, 0, 1, 0)
ExecCopyButton.BackgroundColor3 = CONFIG.THEME.SURFACE
ExecCopyButton.Font = CONFIG.FONTS.HEADER
ExecCopyButton.Text = "Copy Code"
ExecCopyButton.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
ExecCopyButton.TextSize = 11
ExecCopyButton.Parent = ExecButtonRow
createCorner(ExecCopyButton, 6)
createStroke(ExecCopyButton, CONFIG.THEME.BORDER, 1)

local _, ExecLogCardContent = createCard(PageExecutor, "Execution Output & Traceback", "Real-time compiler and runtime status")

local OutputFrame = Instance.new("Frame")
OutputFrame.Size = UDim2.new(1, 0, 0, 64)
OutputFrame.BackgroundColor3 = CONFIG.THEME.INPUT_BG
OutputFrame.BorderSizePixel = 0
OutputFrame.Parent = ExecLogCardContent
createCorner(OutputFrame, 6)
createStroke(OutputFrame, CONFIG.THEME.BORDER, 1)

local OutputLabel = Instance.new("TextLabel")
OutputLabel.Size = UDim2.new(1, -16, 1, -12)
OutputLabel.Position = UDim2.new(0, 8, 0, 6)
OutputLabel.BackgroundTransparency = 1
OutputLabel.Font = CONFIG.FONTS.MONO
OutputLabel.Text = "[Ready] Standby for script execution."
OutputLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
OutputLabel.TextSize = 10
OutputLabel.TextWrapped = true
OutputLabel.TextXAlignment = Enum.TextXAlignment.Left
OutputLabel.TextYAlignment = Enum.TextYAlignment.Top
OutputLabel.Parent = OutputFrame

trackConnection(ExecRunButton.Activated:Connect(function()
	local codeText = CodeBox.Text
	local ok, msg = executeCode(codeText)
	if ok then
		OutputLabel.Text = string.format("[Execution Success - %s]\nZero syntax or runtime errors.", os.date("%H:%M:%S"))
		OutputLabel.TextColor3 = CONFIG.THEME.SUCCESS
		updateStatusBar("Script executed successfully.", "Success")
	else
		OutputLabel.Text = msg
		OutputLabel.TextColor3 = CONFIG.THEME.ERROR
		updateStatusBar("Script execution failed.", "Error")
	end
end))

trackConnection(ExecClearButton.Activated:Connect(function()
	CodeBox.Text = ""
	OutputLabel.Text = "[Cleared] Editor reset."
	OutputLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
	updateStatusBar("Code editor cleared.", "Normal")
end))

trackConnection(ExecPasteButton.Activated:Connect(function()
	local anyG = _G :: any
	local clipFn = anyG.getclipboard or (typeof(getclipboard) == "function" and getclipboard)
	if clipFn then
		local ok, text = pcall(clipFn)
		if ok and typeof(text) == "string" and text ~= "" then
			CodeBox.Text = text
			OutputLabel.Text = string.format("[Pasted] Loaded %d characters from clipboard.", #text)
			OutputLabel.TextColor3 = CONFIG.THEME.SUCCESS
			updateStatusBar("Pasted from clipboard.", "Success")
			return
		end
	end
	updateStatusBar("Clipboard function unavailable; long-press paste in editor.", "Warning")
end))

trackConnection(ExecCopyButton.Activated:Connect(function()
	local anyG = _G :: any
	local setClipFn = anyG.setclipboard or (typeof(setclipboard) == "function" and setclipboard)
	if setClipFn and CodeBox.Text ~= "" then
		pcall(setClipFn, CodeBox.Text)
		updateStatusBar("Script copied to clipboard.", "Success")
	else
		updateStatusBar("setclipboard() unavailable in environment.", "Warning")
	end
end))

-- SCRIPT HUB CATALOG (24+ LOADSTRING SCRIPTS & PRESETS)
local _, HubCardContent = createCard(PageExecutor, "Script Hub & Preset Catalog", "Instant one-click execution of curated Luau scripts")

local scriptCatalog = {
	{ name = "Infinite Yield", cat = "Admin", desc = "Universal FE admin commands suite", src = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source\"))()" },
	{ name = "Dark Dex V3", cat = "Explorer", desc = "Full game explorer and property inspector", src = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/infyiff/backup/main/dex.lua\"))()" },
	{ name = "SimpleSpy V3", cat = "Network", desc = "Inspect, log, and mock remote events", src = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/exxtremestuffs/SimpleSpy/master/source.lua\"))()" },
	{ name = "RemoteSpy", cat = "Network", desc = "Advanced remote event and function listener", src = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/yofriendfromschool1/Sky-Hub-Backup/main/RemoteSpy.lua\"))()" },
	{ name = "Hydroxide", cat = "Analysis", desc = "Dynamic runtime inspector and method hooker", src = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/Upbolt/Hydroxide/revision/init.lua\"))()" },
	{ name = "Turtle Spy", cat = "Network", desc = "Lightweight remote logger for low-end devices", src = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/Turtle-Brand/Turtle-Spy/main/source.lua\"))()" },
	{ name = "Fly GUI V3", cat = "Movement", desc = "Classic standalone touch/PC flight interface", src = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/XNEOFF/FlyGuiV3/main/FlyGuiV3.lua\"))()" },
	{ name = "Nameless Admin", cat = "Admin", desc = "Featherweight FE admin with chat commands", src = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/FilteringEnabled/NamelessAdmin/main/Source\"))()" },
	{ name = "Fates Admin", cat = "Admin", desc = "High-performance modular client command hub", src = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/fatesc/fates-admin/main/main.lua\"))()" },
	{ name = "Unnamed ESP", cat = "Visuals", desc = "Universal 2D box, bone, and tracer ESP", src = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/ic3w0lf22/Unnamed-ESP/master/UnnamedESP.lua\"))()" },
	{ name = "Touch Keyboard", cat = "Mobile", desc = "On-screen virtual keyboard for mobile Delta", src = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/advcomunicles/ROBLOX/main/keyboard.lua\"))()" },
	{ name = "Anti-AFK Standalone", cat = "Utility", desc = "Autonomous idle disconnect protector", src = "loadstring(game:HttpGet(\"https://raw.githubusercontent.com/KazeOnTop/Rice-Anti-Afk/main/Wind.lua\"))()" },
	{ name = "Fast Server Rejoin", cat = "Server", desc = "Instantly reconnect to this place instance", src = "game:GetService(\"TeleportService\"):TeleportToPlaceInstance(game.PlaceId, game.JobId, game:GetService(\"Players\").LocalPlayer)" },
	{ name = "Server Hop", cat = "Server", desc = "Teleport to an alternate public server", src = "game:GetService(\"TeleportService\"):Teleport(game.PlaceId, game:GetService(\"Players\").LocalPlayer)" },
	{ name = "Texture Stripper FPS", cat = "Performance", desc = "Remove decals & particles for max FPS", src = "for _,v in pairs(workspace:GetDescendants()) do if v:IsA(\"BasePart\") then v.Material = Enum.Material.SmoothPlastic elseif v:IsA(\"Decal\") or v:IsA(\"Texture\") then v:Destroy() elseif v:IsA(\"ParticleEmitter\") then v.Enabled = false end end" },
	{ name = "Click TP Tool", cat = "Movement", desc = "Adds click-to-teleport tool to Backpack", src = "local m = game:GetService(\"Players\").LocalPlayer:GetMouse(); local t = Instance.new(\"Tool\"); t.RequiresHandle = false; t.Name = \"Click TP\"; t.Activated:Connect(function() local c = game:GetService(\"Players\").LocalPlayer.Character; if c and m.Hit then c:MoveTo(m.Hit.Position) end end); t.Parent = game:GetService(\"Players\").LocalPlayer.Backpack" },
	{ name = "Spawn Client BTools", cat = "Utility", desc = "Adds Move, Clone, and Delete HopperBins", src = "local bp = game:GetService(\"Players\").LocalPlayer:WaitForChild(\"Backpack\"); for _,bt in ipairs({Enum.BinType.Grab, Enum.BinType.Clone, Enum.BinType.Hammer}) do local b = Instance.new(\"HopperBin\"); b.BinType = bt; b.Parent = bp end" },
	{ name = "Air Walk Sky Platform", cat = "Movement", desc = "Spawns invisible stepping platform under feet", src = "local p = Instance.new(\"Part\"); p.Size = Vector3.new(8, 1, 8); p.Anchored = true; p.Transparency = 0.5; local c = game:GetService(\"Players\").LocalPlayer.Character; if c and c:FindFirstChild(\"HumanoidRootPart\") then p.CFrame = c.HumanoidRootPart.CFrame * CFrame.new(0, -3.5, 0); p.Parent = workspace end" },
	{ name = "Anti-Void Safe Zone", cat = "Protection", desc = "Rescues character from infinite void falls", src = "task.spawn(function() while true do task.wait(0.5); local c = game:GetService(\"Players\").LocalPlayer.Character; local r = c and c:FindFirstChild(\"HumanoidRootPart\"); if r and r.Position.Y < -80 then r.CFrame = CFrame.new(r.Position.X, 60, r.Position.Z); r.AssemblyLinearVelocity = Vector3.zero end end end)" },
	{ name = "Copy Character CFrame", cat = "Utility", desc = "Copies exact player CFrame to clipboard", src = "local r = game:GetService(\"Players\").LocalPlayer.Character and game:GetService(\"Players\").LocalPlayer.Character:FindFirstChild(\"HumanoidRootPart\"); if r and setclipboard then setclipboard(string.format(\"CFrame.new(%.2f, %.2f, %.2f)\", r.Position.X, r.Position.Y, r.Position.Z)) end" },
	{ name = "Force Instant Respawn", cat = "Player", desc = "Cleanses humanoid and respawns character", src = "local c = game:GetService(\"Players\").LocalPlayer.Character; if c then c:BreakJoints() end" },
	{ name = "Force Shiftlock Enabler", cat = "Camera", desc = "Unlocks mouse shiftlock mode globally", src = "game:GetService(\"Players\").LocalPlayer.DevEnableMouseLock = true" },
}

for _, scriptItem in ipairs(scriptCatalog) do
	local itemFrame = Instance.new("Frame")
	itemFrame.Size = UDim2.new(1, 0, 0, 42)
	itemFrame.BackgroundColor3 = CONFIG.THEME.SURFACE
	itemFrame.BorderSizePixel = 0
	itemFrame.Parent = HubCardContent
	createCorner(itemFrame, 6)
	createStroke(itemFrame, CONFIG.THEME.BORDER, 1)

	local titleTxt = Instance.new("TextLabel")
	titleTxt.Size = UDim2.new(0.55, 0, 0, 18)
	titleTxt.Position = UDim2.new(0, 8, 0, 4)
	titleTxt.BackgroundTransparency = 1
	titleTxt.Font = CONFIG.FONTS.HEADER
	titleTxt.Text = scriptItem.name .. " [" .. scriptItem.cat .. "]"
	titleTxt.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	titleTxt.TextSize = 11
	titleTxt.TextXAlignment = Enum.TextXAlignment.Left
	titleTxt.Parent = itemFrame

	local descTxt = Instance.new("TextLabel")
	descTxt.Size = UDim2.new(0.55, 0, 0, 14)
	descTxt.Position = UDim2.new(0, 8, 0, 22)
	descTxt.BackgroundTransparency = 1
	descTxt.Font = CONFIG.FONTS.BODY
	descTxt.Text = scriptItem.desc
	descTxt.TextColor3 = CONFIG.THEME.TEXT_MUTED
	descTxt.TextSize = 9
	descTxt.TextXAlignment = Enum.TextXAlignment.Left
	descTxt.Parent = itemFrame

	local runBtn = Instance.new("TextButton")
	runBtn.Size = UDim2.new(0.2, 0, 0, 26)
	runBtn.Position = UDim2.new(1, -130, 0, 8)
	runBtn.BackgroundColor3 = CONFIG.THEME.SURFACE_ALT
	runBtn.Font = CONFIG.FONTS.HEADER
	runBtn.Text = "Run"
	runBtn.TextColor3 = state.accentColor
	runBtn.TextSize = 10
	runBtn.Parent = itemFrame
	createCorner(runBtn, 4)
	local rStroke = createStroke(runBtn, state.accentColor, 1)
	registerAccent(rStroke, "Color")
	registerAccent(runBtn, "TextColor3")

	local loadBtn = Instance.new("TextButton")
	loadBtn.Size = UDim2.new(0.18, 0, 0, 26)
	loadBtn.Position = UDim2.new(1, -60, 0, 8)
	loadBtn.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	loadBtn.Font = CONFIG.FONTS.HEADER
	loadBtn.Text = "Load"
	loadBtn.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
	loadBtn.TextSize = 10
	loadBtn.Parent = itemFrame
	createCorner(loadBtn, 4)
	createStroke(loadBtn, CONFIG.THEME.BORDER, 1)

	trackConnection(runBtn.Activated:Connect(function()
		local ok, msg = executeCode(scriptItem.src)
		if ok then
			OutputLabel.Text = string.format("[Hub Execute: %s]\nExecuted with zero errors.", scriptItem.name)
			OutputLabel.TextColor3 = CONFIG.THEME.SUCCESS
			updateStatusBar("Ran preset: " .. scriptItem.name, "Success")
		else
			OutputLabel.Text = msg
			OutputLabel.TextColor3 = CONFIG.THEME.ERROR
			updateStatusBar("Failed preset: " .. scriptItem.name, "Error")
		end
	end))

	trackConnection(loadBtn.Activated:Connect(function()
		CodeBox.Text = scriptItem.src
		OutputLabel.Text = string.format("[Loaded] \"%s\" loaded into editor.", scriptItem.name)
		OutputLabel.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
		updateStatusBar("Loaded to editor: " .. scriptItem.name, "Normal")
	end))
end
end

local function buildWorldTab(PageWorld: ScrollingFrame)
-- WORLD & ENVIRONMENT TAB
local _, GravityCardContent = createCard(PageWorld, "Workspace Gravity Mechanics", "Engine physics gravity acceleration modifier")

createSlider(GravityCardContent, "World Gravity", 0, 500, state.gravity, 5, "studs/s2", function(val)
	state.gravity = val
	Workspace.Gravity = val
	updateStatusBar(string.format("World gravity set to %.0f.", val), "Normal")
end)

local GravPresetRow = Instance.new("Frame")
GravPresetRow.Size = UDim2.new(1, 0, 0, 26)
GravPresetRow.BackgroundTransparency = 1
GravPresetRow.Parent = GravityCardContent

local GravPresetLayout = Instance.new("UIListLayout")
GravPresetLayout.FillDirection = Enum.FillDirection.Horizontal
GravPresetLayout.Padding = UDim.new(0, 4)
GravPresetLayout.Parent = GravPresetRow

local gravPresets = {
	{ name = "Zero G (0)", val = 0 },
	{ name = "Moon (50)", val = 50 },
	{ name = "Low (100)", val = 100 },
	{ name = "Earth (196.2)", val = 196.2 },
	{ name = "Heavy (350)", val = 350 },
}

for _, p in ipairs(gravPresets) do
	local pBtn = Instance.new("TextButton")
	pBtn.Size = UDim2.new(0.19, 0, 1, 0)
	pBtn.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	pBtn.Font = CONFIG.FONTS.HEADER
	pBtn.Text = p.name
	pBtn.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
	pBtn.TextSize = 9
	pBtn.Parent = GravPresetRow
	createCorner(pBtn, 4)
	createStroke(pBtn, CONFIG.THEME.BORDER, 1)
	trackConnection(pBtn.Activated:Connect(function()
		state.gravity = p.val
		Workspace.Gravity = p.val
		updateStatusBar(string.format("Gravity set to %.1f.", p.val), "Success")
	end))
end

local _, TimeCardContent = createCard(PageWorld, "Lighting Time & Sun Cycle", "ClockTime manipulation and automatic celestial rotation")

createSlider(TimeCardContent, "Time of Day", 0, 24, state.clockTime, 0.5, "hrs", function(val)
	state.clockTime = val
	Lighting.ClockTime = val
end)

local dayNightConn: RBXScriptConnection? = nil
createToggle(TimeCardContent, "Continuous Day/Night Cycle", CONFIG.AVAILABILITY.LOCAL, state.dayNightCycle, function(enabled)
	state.dayNightCycle = enabled
	if enabled then
		dayNightConn = RunService.Heartbeat:Connect(function(dt)
			Lighting.ClockTime = (Lighting.ClockTime + (dt * 0.5)) % 24
		end)
		if dayNightConn then trackConnection(dayNightConn) end
		updateStatusBar("Day/night cycle active.", "Normal")
	else
		if dayNightConn then
			dayNightConn:Disconnect()
			dayNightConn = nil
		end
		updateStatusBar("Day/night cycle stopped.", "Normal")
	end
end)

local _, WorldOptCardContent = createCard(PageWorld, "World Optimization & Protections", "Client performance enhancements and environmental safety")

local function runFpsBooster()
	local count = 0
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.Material = Enum.Material.SmoothPlastic
			inst.Reflectance = 0
			count += 1
		elseif inst:IsA("Decal") or inst:IsA("Texture") then
			inst.Transparency = 1
			count += 1
		elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then
			inst.Enabled = false
			count += 1
		end
	end
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 9e9
	updateStatusBar(string.format("FPS Booster: Optimized %d objects.", count), "Success")
end
createActionButton(WorldOptCardContent, "FPS Booster (Strip Textures & Particles)", CONFIG.AVAILABILITY.LOCAL, runFpsBooster)

createToggle(WorldOptCardContent, "Anti-Void Fall Watchdog", CONFIG.AVAILABILITY.LOCAL, state.antiVoid, function(enabled)
	state.antiVoid = enabled
	updateStatusBar(enabled and "Anti-Void watchdog active." or "Anti-Void disabled.", "Normal")
end)

trackConnection(RunService.Heartbeat:Connect(function()
	if state.antiVoid then
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") and hrp.Position.Y < -80 then
			hrp.CFrame = CFrame.new(hrp.Position.X, 60, hrp.Position.Z)
			hrp.AssemblyLinearVelocity = Vector3.zero
			updateStatusBar("Anti-Void rescued character from fall.", "Warning")
		end
	end
end))

createToggle(WorldOptCardContent, "Anti-Sit (Auto Seat Dismount)", CONFIG.AVAILABILITY.LOCAL, state.antiSit, function(enabled)
	state.antiSit = enabled
	updateStatusBar(enabled and "Anti-Sit active." or "Anti-Sit disabled.", "Normal")
end)

trackConnection(RunService.Heartbeat:Connect(function()
	if state.antiSit then
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Sit then
			hum.Sit = false
		end
	end
end))

local antiAfkConn: RBXScriptConnection? = nil
createToggle(WorldOptCardContent, "Anti-AFK Inactivity Bypass", CONFIG.AVAILABILITY.LOCAL, state.antiAfk, function(enabled)
	state.antiAfk = enabled
	if enabled then
		local anyG = _G :: any
		local vu = anyG.VirtualUser or game:GetService("VirtualUser")
		antiAfkConn = LocalPlayer.Idled:Connect(function()
			pcall(function()
				vu:Button2Down(Vector2.zero, Workspace.CurrentCamera.CFrame)
				task.wait(1)
				vu:Button2Up(Vector2.zero, Workspace.CurrentCamera.CFrame)
			end)
		end)
		if antiAfkConn then trackConnection(antiAfkConn) end
		updateStatusBar("Anti-AFK inactivity protection active.", "Success")
	else
		if antiAfkConn then
			antiAfkConn:Disconnect()
			antiAfkConn = nil
		end
		updateStatusBar("Anti-AFK disabled.", "Normal")
	end
end)

local function clearDebris()
	local cleaned = 0
	for _, inst in ipairs(Workspace:GetChildren()) do
		if inst:IsA("BasePart") and not inst.Anchored then
			inst:Destroy()
			cleaned += 1
		end
	end
	updateStatusBar(string.format("Cleaned %d loose unanchored parts.", cleaned), "Success")
end
createActionButton(WorldOptCardContent, "Clear Workspace Loose Debris", CONFIG.AVAILABILITY.LOCAL, clearDebris)
end

local function buildUtilityTab(PageUtility: ScrollingFrame)
-- UTILITY TAB (SERVER, TOOLS & DIAGNOSTICS)
local _, ServerCardContent = createCard(PageUtility, "Server Session Navigation", "Teleportation and instance management")

local function executeRejoin()
	updateStatusBar("Rejoining server instance...", "Normal")
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end)
end
createActionButton(ServerCardContent, "Rejoin Current Server", CONFIG.AVAILABILITY.EXPERIENCE, executeRejoin)

local function executeServerHop()
	updateStatusBar("Finding alternate server...", "Normal")
	pcall(function()
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	end)
end
createActionButton(ServerCardContent, "Server Hop to Alternate Server", CONFIG.AVAILABILITY.EXPERIENCE, executeServerHop)

local function copyJobId()
	local anyG = _G :: any
	local setClip = anyG.setclipboard or (typeof(setclipboard) == "function" and setclipboard)
	if setClip then
		pcall(setClip, tostring(game.JobId))
		updateStatusBar("Server JobId copied to clipboard.", "Success")
	end
end
createActionButton(ServerCardContent, "Copy Server JobId", CONFIG.AVAILABILITY.LOCAL, copyJobId)

local function copyPlaceId()
	local anyG = _G :: any
	local setClip = anyG.setclipboard or (typeof(setclipboard) == "function" and setclipboard)
	if setClip then
		pcall(setClip, tostring(game.PlaceId))
		updateStatusBar("Game PlaceId copied to clipboard.", "Success")
	end
end
createActionButton(ServerCardContent, "Copy Game PlaceId", CONFIG.AVAILABILITY.LOCAL, copyPlaceId)

local _, ToolSpawnerCardContent = createCard(PageUtility, "Client Tool Spawners", "Backpack tool injection and character coordinates")

local function spawnBTools()
	local bp = LocalPlayer:WaitForChild("Backpack")
	local tools = {
		{ name = "Move (Grab)", binType = Enum.BinType.Grab },
		{ name = "Clone", binType = Enum.BinType.Clone },
		{ name = "Delete (Hammer)", binType = Enum.BinType.Hammer },
	}
	for _, info in ipairs(tools) do
		local bin = Instance.new("HopperBin")
		bin.BinType = info.binType
		bin.Name = info.name
		bin.Parent = bp
		trackInstance(bin)
	end
	updateStatusBar("Client BTools added to Backpack.", "Success")
end
createActionButton(ToolSpawnerCardContent, "Spawn Client Building Tools (BTools)", CONFIG.AVAILABILITY.LOCAL, spawnBTools)

local function spawnClickTpTool()
	local mouse = LocalPlayer:GetMouse()
	local tool = Instance.new("Tool")
	tool.Name = "Click TP [Sentinel]"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	trackConnection(tool.Activated:Connect(function()
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and mouse.Hit then
			hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
			updateStatusBar("Teleported to clicked position.", "Success")
		end
	end))
	tool.Parent = LocalPlayer:WaitForChild("Backpack")
	trackInstance(tool)
	updateStatusBar("Click TP Tool added to Backpack.", "Success")
end
createActionButton(ToolSpawnerCardContent, "Equip Cursor Click TP Tool", CONFIG.AVAILABILITY.LOCAL, spawnClickTpTool)

local function copyPlayerCoordinates()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		local pos = hrp.Position
		local str = string.format("Vector3.new(%.2f, %.2f, %.2f)", pos.X, pos.Y, pos.Z)
		local anyG = _G :: any
		local setClip = anyG.setclipboard or (typeof(setclipboard) == "function" and setclipboard)
		if setClip then
			pcall(setClip, str)
			updateStatusBar("Coordinates copied: " .. str, "Success")
		else
			updateStatusBar(str, "Normal")
		end
	end
end
createActionButton(ToolSpawnerCardContent, "Copy Player Coordinates (XYZ)", CONFIG.AVAILABILITY.LOCAL, copyPlayerCoordinates)

local _, DiagnosticsCardContent = createCard(PageUtility, "Live Telemetry & Performance", "Real-time client and server metric readings")

local MetricsLabel = Instance.new("TextLabel")
MetricsLabel.Size = UDim2.new(1, 0, 0, 48)
MetricsLabel.BackgroundTransparency = 1
MetricsLabel.Font = CONFIG.FONTS.MONO
MetricsLabel.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
MetricsLabel.TextSize = 10
MetricsLabel.TextWrapped = true
MetricsLabel.TextXAlignment = Enum.TextXAlignment.Left
MetricsLabel.Text = "Telemetry initializing..."
MetricsLabel.Parent = DiagnosticsCardContent

local lastTime = os.clock()
local frameCount = 0
local currentFps = 60

trackConnection(RunService.RenderStepped:Connect(function()
	frameCount += 1
	local now = os.clock()
	if now - lastTime >= 1 then
		currentFps = frameCount
		frameCount = 0
		lastTime = now
		local ping = 0
		pcall(function()
			ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
		end)
		MetricsLabel.Text = string.format(
			"Render FPS: %d fps | Server Ping: %d ms\nActive Players: %d / %d\nPlace ID: %d",
			currentFps,
			ping,
			#Players:GetPlayers(),
			Players.MaxPlayers,
			game.PlaceId
		)
	end
end))
end

local function buildSettingsTab(PageSettings: ScrollingFrame)
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
end

local function buildInfoTab(PageInfo: ScrollingFrame)
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
end

local function bindEvents()
-- SECTION 7: EVENT CONNECTIONS & DRAGGING
trackConnection(CloseButton.Activated:Connect(function()
	MainFrame.Visible = false
	MinimizedPill.Visible = false
	updateStatusBar("Interface hidden. Tap floating button to reopen.", "Normal")
end))

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
	if not state.isAuthenticated then
		return
	end
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
		if setFlightVisual then setFlightVisual(false) end
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
end

-- SECTION 8: CLEANUP LIFECYCLE & ERROR HANDLING
cleanupAll = function()
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

	Workspace.Gravity = state.defaultGravity

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
	pcall(function()
		cleanupG.SentinelUtilityCleanup = nil
	end)
end

local sharedG = _G :: any
pcall(function()
	sharedG.SentinelUtilityCleanup = cleanupAll
end)
if typeof(shared) == "table" then
	pcall(function()
		(shared :: any).SentinelUtilityCleanup = cleanupAll
	end)
end


-- =========================================================================
-- SECTION 9: MODULAR ORCHESTRATION & SAFE EXECUTION
-- Runs each builder function in an isolated frame to enforce sub-70 register footprint.
-- =========================================================================
local function safeBuild(sectionName: string, builderFn: () -> ())
	local ok, err = pcall(builderFn)
	if not ok then
		warn(string.format("[Sentinel] Error initializing %s: %s", sectionName, tostring(err)))
	end
end

buildCoreContainers()
buildAuthAndLoading()

safeBuild("PlayerTools", function() buildPlayerToolsTab(PagePlayerTools) end)
safeBuild("Troll", function() buildTrollTab(PageTroll) end)
safeBuild("Movement", function() buildMovementTab(PageMovement) end)
safeBuild("Visuals", function() buildVisualsTab(PageVisuals) end)
safeBuild("Executor", function() buildExecutorTab(PageExecutor) end)
safeBuild("World", function() buildWorldTab(PageWorld) end)
safeBuild("Utility", function() buildUtilityTab(PageUtility) end)
safeBuild("Settings", function() buildSettingsTab(PageSettings) end)
safeBuild("Info", function() buildInfoTab(PageInfo) end)

bindEvents()
switchTab(state.activeTab)
updateStatusBar("Sentinel Suite ready. Press RightControl or tap 'S' to toggle.", "Normal")
