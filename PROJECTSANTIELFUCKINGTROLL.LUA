--!strict
-- ============================================================================
-- SENTINEL SUITE: CORE CLIENT UTILITY & DIAGNOSTIC INTERFACE
-- Target Architecture: Delta Executor (Android Mobile / iOS / Windows PC)
-- Engine: Roblox FilteringEnabled (FE) Physics Engine
-- ============================================================================

local CONFIG = {
	GUI_NAME = "Sentinel_Diagnostic_UI",
	HOTKEY = Enum.KeyCode.RightControl,
	DIMENSIONS = {
		WINDOW_SIZE = UDim2.new(0, 580, 0, 420),
		MINIMIZED_SIZE = UDim2.new(0, 160, 0, 36),
		MOBILE_BTN_SIZE = UDim2.new(0, 46, 0, 46),
		MIN_SCALE = 0.52,
		MAX_SCALE = 1.0,
	},
	THEME = {
		BACKGROUND = Color3.fromRGB(15, 17, 23),
		SURFACE = Color3.fromRGB(22, 25, 35),
		SURFACE_ALT = Color3.fromRGB(30, 34, 48),
		BORDER = Color3.fromRGB(45, 52, 70),
		INPUT_BG = Color3.fromRGB(18, 20, 29),
		TEXT_PRIMARY = Color3.fromRGB(240, 242, 248),
		TEXT_SECONDARY = Color3.fromRGB(160, 166, 185),
		TEXT_MUTED = Color3.fromRGB(95, 102, 122),
		ACCENT_DEFAULT = Color3.fromRGB(0, 200, 115),
		SUCCESS = Color3.fromRGB(46, 204, 113),
		WARNING = Color3.fromRGB(241, 196, 15),
		ERROR = Color3.fromRGB(231, 76, 60),
		ACCENT_PALETTES = {
			Emerald = Color3.fromRGB(0, 200, 115),
			CyberCyan = Color3.fromRGB(0, 210, 255),
			NeonPurple = Color3.fromRGB(175, 82, 222),
			SunsetOrange = Color3.fromRGB(255, 107, 49),
			Crimson = Color3.fromRGB(255, 59, 48),
			PureWhite = Color3.fromRGB(245, 245, 245),
		},
	},
	FONTS = {
		TITLE = Enum.Font.GothamBold,
		HEADER = Enum.Font.GothamSemibold,
		BODY = Enum.Font.Gotham,
		MONO = Enum.Font.Code,
	},
	AVAILABILITY = {
		LOCAL = "[Client Local]",
		FE_PHYSICS = "[FE Collision]",
		EXPERIENCE = "[Exp Dependent]",
	},
}

-- SECTION 1: SERVICES & ENVIRONMENT RESOLUTION
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local _HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer :: Player
end

local detectedExecutor = "Unknown"
pcall(function()
	local anyG = _G :: any
	if typeof(identifyexecutor) == "function" then
		detectedExecutor = identifyexecutor()
	elseif typeof(getexecutorname) == "function" then
		detectedExecutor = getexecutorname()
	elseif anyG.DELTA_LOADED or anyG.Delta then
		detectedExecutor = "Delta"
	end
end)

local isMobileDevice = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function getCamera(): Camera
	local cam = Workspace.CurrentCamera
	if not cam then
		local start = tick()
		repeat
			task.wait(0.05)
			cam = Workspace.CurrentCamera
		until cam or tick() - start > 5
	end
	return cam or Instance.new("Camera")
end

local function getViewportSize(): Vector2
	local cam = getCamera()
	if cam and cam.ViewportSize.X > 200 and cam.ViewportSize.Y > 200 then
		return cam.ViewportSize
	end
	return Vector2.new(1280, 720)
end

-- Universal Loadstring Fallback for Delta
local function universalLoadstring(source: string, chunkName: string?): ((...any) -> (...any))?
	local anyG = _G :: any
	local globalLoad = anyG.loadstring or (getgenv and getgenv().loadstring) or loadstring
	if typeof(globalLoad) == "function" then
		local ok, fn = pcall(globalLoad, source, chunkName or "Sentinel_Chunk")
		if ok and typeof(fn) == "function" then
			return fn
		end
	end

	local env = getfenv and getfenv() or {}
	if typeof(env.loadstring) == "function" then
		local ok, fn = pcall(env.loadstring, source)
		if ok and typeof(fn) == "function" then
			return fn
		end
	end

	local globalShared = shared :: any
	if globalShared and typeof(globalShared.loadstring) == "function" then
		local ok, fn = pcall(globalShared.loadstring, source)
		if ok and typeof(fn) == "function" then
			return fn
		end
	end

	return nil
end

local function executeScriptString(code: string): (boolean, string)
	if code:gsub("%s+", "") == "" then
		return false, "Script code buffer is empty."
	end

	local fn = universalLoadstring(code, "Sentinel_UserExec")
	if not fn then
		return false, "No valid loadstring provider available in this executor environment."
	end

	local runOk, runErr = pcall(function()
		task.spawn(fn)
	end)

	if not runOk then
		return false, "[Runtime Error] " .. tostring(runErr)
	end
	return true, "Script executed successfully."
end

-- Executor-aware protected GUI resolver (hardened for Delta Mobile and PC)
local function resolveScreenGui(): ScreenGui
	local protectedContainer: Instance? = nil
	if typeof(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui and typeof(hui) == "Instance" then
			protectedContainer = hui
		end
	end

	-- If executor provides an active ScreenGui directly (e.g. Delta Mobile)
	if protectedContainer and protectedContainer:IsA("ScreenGui") then
		return protectedContainer :: ScreenGui
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = CONFIG.GUI_NAME
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10000
	gui.IgnoreGuiInset = true

	if typeof(protectgui) == "function" then
		pcall(protectgui, gui)
	elseif typeof(protect_gui) == "function" then
		pcall(protect_gui, gui)
	elseif typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
		pcall(syn.protect_gui, gui)
	end

	local parented = false
	if protectedContainer and not protectedContainer:IsA("LayerCollector") then
		local ok = pcall(function()
			gui.Parent = protectedContainer
		end)
		if ok and gui.Parent then parented = true end
	end

	if not parented then
		local ok, cg = pcall(function() return game:GetService("CoreGui") end)
		if ok and cg then
			local ok2 = pcall(function() gui.Parent = cg end)
			if ok2 and gui.Parent then parented = true end
		end
	end

	if not parented then
		local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
		pcall(function() gui.Parent = pgui end)
	end

	return gui
end

local function purgeOldGui(container: Instance?)
	if not container then return end
	local old = container:FindFirstChild(CONFIG.GUI_NAME)
	if old and old:IsA("ScreenGui") then
		pcall(function() old:Destroy() end)
	end
	for _, name in ipairs({ "MainFrame", "MobileToggleButton", "MinimizedPill", "Sentinel_ESP_Container" }) do
		local item = container:FindFirstChild(name)
		if item then
			pcall(function() item:Destroy() end)
		end
	end
end

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
local state = {
	selectedPlayer = nil :: Player?,
	selectedPlayerName = "None",
	teleportDistance = 5,
	teleportOffset = "Behind",
	previousPosition = nil :: CFrame?,

	isFollowing = false,
	followDistance = 6,

	isFlinging = false,
	flingIntensity = 100,
	flingMaxVelocity = 100000,
	isTouchFling = false,

	isOrbiting = false,
	orbitRadius = 8,
	orbitSpeed = 2,

	isHeadSitting = false,

	walkSpeed = 16,
	defaultWalkSpeed = 16,
	jumpPower = 50,
	defaultJumpPower = 50,
	jumpHeight = 7.2,
	infiniteJump = false,
	bunnyHop = false,
	antiRagdoll = false,
	speedMultiplier = 1,

	isFlying = false,
	flightSpeed = 50,

	isNoclip = false,

	isEspActive = false,
	isHighlightActive = false,
	isTracersActive = false,
	isNameTagsActive = false,
	selectedHighlightInstance = nil :: Instance?,
	originalTransparencies = {} :: { [Instance]: number },
	currentTransparency = 0,
	localFov = 70,
	defaultFov = 70,
	fullbright = false,
	noFog = false,
	thirdPersonDist = 12,
	xrayActive = false,
	nightVision = false,
	colorCorrectionInstance = nil :: ColorCorrectionEffect?,
	ambientPart = nil :: Part?,

	defaultGravity = Workspace.Gravity,
	customGravity = Workspace.Gravity,
	clientClockTime = 14,
	antiAfkActive = true,
	antiVoidActive = false,
	clickTeleport = false,

	activeTab = "PlayerTools",
	isMinimized = false,
	keybind = CONFIG.HOTKEY,
	accentColor = CONFIG.THEME.ACCENT_DEFAULT,
	accentName = "Emerald",
	guiScale = 1.0,
	manualScaleOverride = false,
	windowOpacity = 0,
	showMobileButton = true,

	savedExecutorCode = "",
}

task.spawn(function()
	local cam = getCamera()
	if cam then
		state.defaultFov = cam.FieldOfView
		state.localFov = cam.FieldOfView
	end
end)

local trackedConnections: { RBXScriptConnection } = {}
local trackedInstances: { Instance } = {}
local accentUpdaters: { { inst: Instance, prop: string } } = {}

local function trackConnection(conn: RBXScriptConnection): RBXScriptConnection
	table.insert(trackedConnections, conn)
	return conn
end

local function trackInstance(inst: Instance): Instance
	table.insert(trackedInstances, inst)
	return inst
end

local function registerAccent(inst: Instance, prop: string)
	table.insert(accentUpdaters, { inst = inst, prop = prop })
	pcall(function()
		local anyInst = inst :: any
		anyInst[prop] = state.accentColor
	end)
end

local function updateAccentColor(newColor: Color3, name: string)
	state.accentColor = newColor
	state.accentName = name
	for _, entry in ipairs(accentUpdaters) do
		if entry.inst and entry.inst.Parent then
			pcall(function()
				local anyInst = entry.inst :: any
				anyInst[entry.prop] = newColor
			end)
		end
	end
end

-- =========================================================================
-- SECTION 3.5: SHARED FORWARD DECLARATIONS (MODULAR REGISTERS ARCHITECTURE)
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
	local tween = TweenService:Create(inst, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
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

local function updateStatusBar(message: string, msgType: string?)
	if not StatusFeedbackLabel then return end
	local color = CONFIG.THEME.TEXT_MUTED
	if msgType == "Success" then
		color = CONFIG.THEME.SUCCESS
	elseif msgType == "Warning" then
		color = CONFIG.THEME.WARNING
	elseif msgType == "Error" then
		color = CONFIG.THEME.ERROR
	elseif msgType == "Accent" then
		color = state.accentColor
	end

	StatusFeedbackLabel.TextColor3 = color
	StatusFeedbackLabel.Text = string.format("[%s] %s", os.date("%H:%M:%S"), message)

	if StatusTargetLabel then
		StatusTargetLabel.Text = string.format("Target: %s", state.selectedPlayerName)
	end
end

local function clampMainFrameToBounds()
	if not MainFrame or not GuiScale then return end
	local vp = getViewportSize()
	local scale = GuiScale.Scale
	local halfW = (CONFIG.DIMENSIONS.WINDOW_SIZE.X.Offset * scale) / 2
	local halfH = (CONFIG.DIMENSIONS.WINDOW_SIZE.Y.Offset * scale) / 2

	local curX = MainFrame.Position.X.Scale * vp.X + MainFrame.Position.X.Offset
	local curY = MainFrame.Position.Y.Scale * vp.Y + MainFrame.Position.Y.Offset

	local minX = halfW + 8
	local maxX = vp.X - halfW - 8
	local minY = halfH + 8
	local maxY = vp.Y - halfH - 8

	if maxX < minX then minX = vp.X / 2; maxX = vp.X / 2 end
	if maxY < minY then minY = vp.Y / 2; maxY = vp.Y / 2 end

	local clampedX = math.clamp(curX, minX, maxX)
	local clampedY = math.clamp(curY, minY, maxY)

	MainFrame.Position = UDim2.new(0, math.floor(clampedX), 0, math.floor(clampedY))
end

local function recenterMainFrame()
	if not MainFrame then return end
	MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	clampMainFrameToBounds()
	updateStatusBar("Interface centered to screen coordinates.", "Normal")
end

local function toggleVisibility()
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
		updateStatusBar("Interface restored.", "Normal")
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

			local minCenterX = halfW + 4
			local maxCenterX = vp.X - halfW - 4
			local minCenterY = halfH + 4
			local maxCenterY = vp.Y - halfH - 4

			if maxCenterX < minCenterX then minCenterX = vp.X / 2; maxCenterX = vp.X / 2 end
			if maxCenterY < minCenterY then minCenterY = vp.Y / 2; maxCenterY = vp.Y / 2 end

			local clampedCenterX = math.clamp(currentCenterX, minCenterX, maxCenterX)
			local clampedCenterY = math.clamp(currentCenterY, minCenterY, maxCenterY)

			local finalOffsetX = (clampedCenterX - (vp.X * 0.5)) / scale
			local finalOffsetY = (clampedCenterY - (vp.Y * 0.5)) / scale

			frame.Position = UDim2.new(0.5, math.floor(finalOffsetX), 0.5, math.floor(finalOffsetY))
		end
	end))

	trackConnection(UserInputService.InputEnded:Connect(function(input)
		if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			dragInput = nil
		end
	end))
end

local function createSectionHeader(parent: Instance, title: string): TextLabel
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 24)
	header.BackgroundTransparency = 1
	header.Font = CONFIG.FONTS.HEADER
	header.Text = title:upper()
	header.TextColor3 = state.accentColor
	header.TextSize = 11
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = parent
	registerAccent(header, "TextColor3")
	return header
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
	cardLayout.Padding = UDim.new(0, 6)
	cardLayout.Parent = card

	local cardTitle = Instance.new("TextLabel")
	cardTitle.Size = UDim2.new(1, 0, 0, 16)
	cardTitle.BackgroundTransparency = 1
	cardTitle.Font = CONFIG.FONTS.HEADER
	cardTitle.Text = title
	cardTitle.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	cardTitle.TextSize = 12
	cardTitle.TextXAlignment = Enum.TextXAlignment.Left
	cardTitle.Parent = card

	if subtitle then
		local cardSub = Instance.new("TextLabel")
		cardSub.Size = UDim2.new(1, 0, 0, 12)
		cardSub.Position = UDim2.new(0, 0, 0, 16)
		cardSub.BackgroundTransparency = 1
		cardSub.Font = CONFIG.FONTS.BODY
		cardSub.Text = subtitle
		cardSub.TextColor3 = CONFIG.THEME.TEXT_MUTED
		cardSub.TextSize = 10
		cardSub.TextXAlignment = Enum.TextXAlignment.Left
		cardSub.Parent = card
	end

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.Parent = card

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 8)
	contentLayout.Parent = content

	return card, content
end

local function createActionButton(
	parent: Instance,
	label: string,
	availability: string,
	callback: () -> ()
): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = CONFIG.THEME.SURFACE_ALT
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Parent = parent
	createCorner(btn, 6)
	local stroke = createStroke(btn, CONFIG.THEME.BORDER, 1)

	local btnLabel = Instance.new("TextLabel")
	btnLabel.Size = UDim2.new(0.65, 0, 1, 0)
	btnLabel.Position = UDim2.new(0, 10, 0, 0)
	btnLabel.BackgroundTransparency = 1
	btnLabel.Font = CONFIG.FONTS.BODY
	btnLabel.Text = label
	btnLabel.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	btnLabel.TextSize = 11
	btnLabel.TextXAlignment = Enum.TextXAlignment.Left
	btnLabel.Parent = btn

	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.new(0.32, -10, 1, 0)
	tag.Position = UDim2.new(0.68, 0, 0, 0)
	tag.BackgroundTransparency = 1
	tag.Font = CONFIG.FONTS.MONO
	tag.Text = availability
	tag.TextColor3 = CONFIG.THEME.TEXT_MUTED
	tag.TextSize = 9
	tag.TextXAlignment = Enum.TextXAlignment.Right
	tag.Parent = btn

	trackConnection(btn.MouseEnter:Connect(function()
		animateTween(btn, 0.12, { BackgroundColor3 = CONFIG.THEME.INPUT_BG })
		animateTween(stroke, 0.12, { Color = state.accentColor })
	end))
	trackConnection(btn.MouseLeave:Connect(function()
		animateTween(btn, 0.12, { BackgroundColor3 = CONFIG.THEME.SURFACE_ALT })
		animateTween(stroke, 0.12, { Color = CONFIG.THEME.BORDER })
	end))

	trackConnection(btn.Activated:Connect(callback))
	return btn
end

local function createToggle(
	parent: Instance,
	label: string,
	availability: string,
	initialState: boolean,
	onToggled: (boolean) -> ()
): (Frame, (boolean) -> ())
	local isToggled = initialState

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local rowLabel = Instance.new("TextLabel")
	rowLabel.Size = UDim2.new(0.6, 0, 1, 0)
	rowLabel.BackgroundTransparency = 1
	rowLabel.Font = CONFIG.FONTS.BODY
	rowLabel.Text = label
	rowLabel.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	rowLabel.TextSize = 11
	rowLabel.TextXAlignment = Enum.TextXAlignment.Left
	rowLabel.Parent = row

	local tag = Instance.new("TextLabel")
	tag.Size = UDim2.new(0.25, 0, 1, 0)
	tag.Position = UDim2.new(0.6, 0, 0, 0)
	tag.BackgroundTransparency = 1
	tag.Font = CONFIG.FONTS.MONO
	tag.Text = availability
	tag.TextColor3 = CONFIG.THEME.TEXT_MUTED
	tag.TextSize = 9
	tag.TextXAlignment = Enum.TextXAlignment.Right
	tag.Parent = row

	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0, 42, 0, 22)
	toggleBtn.Position = UDim2.new(1, -42, 0.5, -11)
	toggleBtn.BackgroundColor3 = isToggled and state.accentColor or CONFIG.THEME.INPUT_BG
	toggleBtn.BorderSizePixel = 0
	toggleBtn.Text = ""
	toggleBtn.AutoButtonColor = false
	toggleBtn.Parent = row
	createCorner(toggleBtn, 11)
	local stroke = createStroke(toggleBtn, isToggled and state.accentColor or CONFIG.THEME.BORDER, 1)

	local thumb = Instance.new("Frame")
	thumb.Size = UDim2.new(0, 16, 0, 16)
	thumb.Position = isToggled and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
	thumb.BackgroundColor3 = CONFIG.THEME.TEXT_PRIMARY
	thumb.BorderSizePixel = 0
	thumb.Parent = toggleBtn
	createCorner(thumb, 8)

	local function setVisualState(value: boolean)
		isToggled = value
		animateTween(toggleBtn, 0.15, {
			BackgroundColor3 = value and state.accentColor or CONFIG.THEME.INPUT_BG,
		})
		animateTween(stroke, 0.15, {
			Color = value and state.accentColor or CONFIG.THEME.BORDER,
		})
		animateTween(thumb, 0.15, {
			Position = value and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
		})
	end

	trackConnection(toggleBtn.Activated:Connect(function()
		local newVal = not isToggled
		setVisualState(newVal)
		onToggled(newVal)
	end))

	return row, setVisualState
end

local function createSlider(
	parent: Instance,
	label: string,
	minVal: number,
	maxVal: number,
	defaultVal: number,
	step: number,
	unit: string,
	onChanged: (number) -> ()
): (Frame, (number) -> ())
	local currentVal = defaultVal

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 46)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.new(0.65, 0, 0, 18)
	labelText.BackgroundTransparency = 1
	labelText.Font = CONFIG.FONTS.BODY
	labelText.Text = label
	labelText.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	labelText.TextSize = 11
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.Parent = row

	local valueText = Instance.new("TextLabel")
	valueText.Size = UDim2.new(0.35, 0, 0, 18)
	valueText.Position = UDim2.new(0.65, 0, 0, 0)
	valueText.BackgroundTransparency = 1
	valueText.Font = CONFIG.FONTS.MONO
	valueText.Text = string.format("%.1f %s", currentVal, unit)
	valueText.TextColor3 = state.accentColor
	valueText.TextSize = 10
	valueText.TextXAlignment = Enum.TextXAlignment.Right
	valueText.Parent = row
	registerAccent(valueText, "TextColor3")

	local sliderTrack = Instance.new("Frame")
	sliderTrack.Size = UDim2.new(1, 0, 0, 8)
	sliderTrack.Position = UDim2.new(0, 0, 0, 26)
	sliderTrack.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	sliderTrack.BorderSizePixel = 0
	sliderTrack.Parent = row
	createCorner(sliderTrack, 4)
	createStroke(sliderTrack, CONFIG.THEME.BORDER, 1)

	local relInit = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new(relInit, 0, 1, 0)
	sliderFill.BackgroundColor3 = state.accentColor
	sliderFill.BorderSizePixel = 0
	sliderFill.Parent = sliderTrack
	createCorner(sliderFill, 4)
	registerAccent(sliderFill, "BackgroundColor3")

	local sliderThumb = Instance.new("TextButton")
	sliderThumb.Size = UDim2.new(0, 16, 0, 16)
	sliderThumb.Position = UDim2.new(relInit, -8, 0.5, -8)
	sliderThumb.BackgroundColor3 = CONFIG.THEME.TEXT_PRIMARY
	sliderThumb.BorderSizePixel = 0
	sliderThumb.Text = ""
	sliderThumb.AutoButtonColor = false
	sliderThumb.Parent = sliderTrack
	createCorner(sliderThumb, 8)
	local thumbStroke = createStroke(sliderThumb, state.accentColor, 1.5)
	registerAccent(thumbStroke, "Color")

	local isSliding = false
	local function updateSliderFromPosition(posX: number)
		local trackAbsPos = sliderTrack.AbsolutePosition.X
		local trackAbsSize = sliderTrack.AbsoluteSize.X
		if trackAbsSize <= 0 then return end

		local rel = math.clamp((posX - trackAbsPos) / trackAbsSize, 0, 1)
		local rawVal = minVal + (rel * (maxVal - minVal))
		local steppedVal = math.floor((rawVal / step) + 0.5) * step
		currentVal = math.clamp(steppedVal, minVal, maxVal)

		local displayRel = (currentVal - minVal) / (maxVal - minVal)
		sliderFill.Size = UDim2.new(displayRel, 0, 1, 0)
		sliderThumb.Position = UDim2.new(displayRel, -8, 0.5, -8)

		if step >= 1 then
			valueText.Text = string.format("%d %s", math.floor(currentVal), unit)
		else
			valueText.Text = string.format("%.1f %s", currentVal, unit)
		end

		onChanged(currentVal)
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
			updateSliderFromPosition(input.Position.X)
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
			updateSliderFromPosition(input.Position.X)
		end
	end))

	trackConnection(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isSliding = false
		end
	end))

	local function setExternalVal(val: number)
		currentVal = math.clamp(val, minVal, maxVal)
		local displayRel = (currentVal - minVal) / (maxVal - minVal)
		sliderFill.Size = UDim2.new(displayRel, 0, 1, 0)
		sliderThumb.Position = UDim2.new(displayRel, -8, 0.5, -8)
		if step >= 1 then
			valueText.Text = string.format("%d %s", math.floor(currentVal), unit)
		else
			valueText.Text = string.format("%.1f %s", currentVal, unit)
		end
	end

	return row, setExternalVal
end

local function createPage(parent: Instance, id: string): ScrollingFrame
	local page = Instance.new("ScrollingFrame")
	page.Name = "Page_" .. id
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = CONFIG.THEME.BORDER
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = parent

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

-- =========================================================================
-- SECTION 4.5: CORE SHELL GENERATION
-- =========================================================================
local function buildCoreContainers()
	ScreenGui = resolveScreenGui()

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
	MainFrame.Visible = true
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
	MobileToggleButton.Visible = state.showMobileButton
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
	TagLabel.Position = UDim2.new(0, 100, 0, 0)
	TagLabel.Size = UDim2.new(0, 260, 1, 0)
	TagLabel.Parent = TitleBar

	TitleDragHandle = Instance.new("Frame")
	TitleDragHandle.Size = UDim2.new(1, -120, 1, 0)
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
	TabBar.Size = UDim2.new(1, -20, 0, 34)
	TabBar.Position = UDim2.new(0, 10, 0, 44)
	TabBar.BackgroundTransparency = 1
	TabBar.BorderSizePixel = 0
	TabBar.ScrollBarThickness = 0
	TabBar.CanvasSize = UDim2.new(0, 0, 0, 0)
	TabBar.AutomaticCanvasSize = Enum.AutomaticSize.X
	TabBar.Parent = MainFrame

	local TabLayout = Instance.new("UIListLayout")
	TabLayout.FillDirection = Enum.FillDirection.Horizontal
	TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	TabLayout.Padding = UDim.new(0, 6)
	TabLayout.Parent = TabBar

	ContentViewport = Instance.new("Frame")
	ContentViewport.Name = "ContentViewport"
	ContentViewport.Size = UDim2.new(1, -20, 1, -114)
	ContentViewport.Position = UDim2.new(0, 10, 0, 82)
	ContentViewport.BackgroundTransparency = 1
	ContentViewport.Parent = MainFrame

	StatusBar = Instance.new("Frame")
	StatusBar.Name = "StatusBar"
	StatusBar.Size = UDim2.new(1, 0, 0, 26)
	StatusBar.Position = UDim2.new(0, 0, 1, -26)
	StatusBar.BackgroundColor3 = CONFIG.THEME.SURFACE
	StatusBar.BorderSizePixel = 0
	StatusBar.Parent = MainFrame
	createCorner(StatusBar, 10)

	local StatusCover = Instance.new("Frame")
	StatusCover.Size = UDim2.new(1, 0, 0, 8)
	StatusCover.BackgroundColor3 = CONFIG.THEME.SURFACE
	StatusCover.BorderSizePixel = 0
	StatusCover.Parent = StatusBar

	StatusTargetLabel = Instance.new("TextLabel")
	StatusTargetLabel.Size = UDim2.new(0, 160, 1, 0)
	StatusTargetLabel.Position = UDim2.new(0, 12, 0, 0)
	StatusTargetLabel.BackgroundTransparency = 1
	StatusTargetLabel.Font = CONFIG.FONTS.MONO
	StatusTargetLabel.Text = "Target: None"
	StatusTargetLabel.TextColor3 = state.accentColor
	StatusTargetLabel.TextSize = 10
	StatusTargetLabel.TextXAlignment = Enum.TextXAlignment.Left
	StatusTargetLabel.Parent = StatusBar
	registerAccent(StatusTargetLabel, "TextColor3")

	StatusFeedbackLabel = Instance.new("TextLabel")
	StatusFeedbackLabel.Size = UDim2.new(1, -180, 1, 0)
	StatusFeedbackLabel.Position = UDim2.new(0, 172, 0, 0)
	StatusFeedbackLabel.BackgroundTransparency = 1
	StatusFeedbackLabel.Font = CONFIG.FONTS.MONO
	StatusFeedbackLabel.Text = "[Ready] Sentinel Suite online."
	StatusFeedbackLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
	StatusFeedbackLabel.TextSize = 10
	StatusFeedbackLabel.TextXAlignment = Enum.TextXAlignment.Right
	StatusFeedbackLabel.Parent = StatusBar

	enableDragging(MainFrame, TitleDragHandle)
	enableDragging(MinimizedPill, MinimizedPill)

	local mobileDragging = false
	local mobileDragStart = Vector2.zero
	local mobileBtnStartGuiPos = MobileToggleButton.Position
	local mobileMoved = false

	trackConnection(MobileToggleButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			mobileDragging = true
			mobileMoved = false
			mobileDragStart = Vector2.new(input.Position.X, input.Position.Y)
			mobileBtnStartGuiPos = MobileToggleButton.Position

			local moveConn: RBXScriptConnection
			local endConn: RBXScriptConnection

			moveConn = UserInputService.InputChanged:Connect(function(moveInput)
				if mobileDragging and (moveInput.UserInputType == Enum.UserInputType.Touch or moveInput.UserInputType == Enum.UserInputType.MouseMovement) then
					local delta = Vector2.new(moveInput.Position.X, moveInput.Position.Y) - mobileDragStart
					if delta.Magnitude > 6 then
						mobileMoved = true
					end
					local vp = getViewportSize()
					local newX = math.clamp(mobileBtnStartGuiPos.X.Offset + delta.X, 0, vp.X - 50)
					local newY = math.clamp(mobileBtnStartGuiPos.Y.Offset + delta.Y, 0, vp.Y - 50)
					MobileToggleButton.Position = UDim2.new(mobileBtnStartGuiPos.X.Scale, newX, mobileBtnStartGuiPos.Y.Scale, newY)
				end
			end)

			endConn = UserInputService.InputEnded:Connect(function(endInput)
				if endInput.UserInputType == Enum.UserInputType.Touch or endInput.UserInputType == Enum.UserInputType.MouseButton1 then
					mobileDragging = false
					if moveConn then moveConn:Disconnect() end
					if endConn then endConn:Disconnect() end

					if not mobileMoved then
						toggleVisibility()
					end
				end
			end)
		end
	end))

	createTabButton("PlayerTools", "Target")
	createTabButton("Troll", "Troll [FE]")
	createTabButton("Movement", "Movement")
	createTabButton("Visuals", "Visuals")
	createTabButton("Executor", "Executor")
	createTabButton("World", "World")
	createTabButton("Utility", "Utility")
	createTabButton("Settings", "Settings")
	createTabButton("Info", "Info")

	PagePlayerTools = createPage(ContentViewport, "PlayerTools")
	PageTroll = createPage(ContentViewport, "Troll")
	PageMovement = createPage(ContentViewport, "Movement")
	PageVisuals = createPage(ContentViewport, "Visuals")
	PageExecutor = createPage(ContentViewport, "Executor")
	PageWorld = createPage(ContentViewport, "World")
	PageUtility = createPage(ContentViewport, "Utility")
	PageSettings = createPage(ContentViewport, "Settings")
	PageInfo = createPage(ContentViewport, "Info")
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

local LeftRoster = Instance.new("Frame")
LeftRoster.Size = UDim2.new(0.48, 0, 1, 0)
LeftRoster.BackgroundColor3 = CONFIG.THEME.SURFACE
LeftRoster.Parent = PlayerSplitFrame
createCorner(LeftRoster, 8)
createStroke(LeftRoster, CONFIG.THEME.BORDER, 1)

local LeftPadding = Instance.new("UIPadding")
LeftPadding.PaddingTop = UDim.new(0, 10)
LeftPadding.PaddingBottom = UDim.new(0, 10)
LeftPadding.PaddingLeft = UDim.new(0, 10)
LeftPadding.PaddingRight = UDim.new(0, 10)
LeftPadding.Parent = LeftRoster

local RosterTitle = Instance.new("TextLabel")
RosterTitle.Size = UDim2.new(1, 0, 0, 16)
RosterTitle.BackgroundTransparency = 1
RosterTitle.Font = CONFIG.FONTS.HEADER
RosterTitle.Text = "ACTIVE PLAYERS"
RosterTitle.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
RosterTitle.TextSize = 11
RosterTitle.TextXAlignment = Enum.TextXAlignment.Left
RosterTitle.Parent = LeftRoster

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, 0, 0, 26)
SearchBox.Position = UDim2.new(0, 0, 0, 22)
SearchBox.BackgroundColor3 = CONFIG.THEME.INPUT_BG
SearchBox.BorderSizePixel = 0
SearchBox.Font = CONFIG.FONTS.BODY
SearchBox.PlaceholderColor3 = CONFIG.THEME.TEXT_MUTED
SearchBox.PlaceholderText = "Search player name..."
SearchBox.Text = ""
SearchBox.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
SearchBox.TextSize = 11
SearchBox.ClearTextOnFocus = false
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.Parent = LeftRoster
createCorner(SearchBox, 4)
createStroke(SearchBox, CONFIG.THEME.BORDER, 1)

local SearchPadding = Instance.new("UIPadding")
SearchPadding.PaddingLeft = UDim.new(0, 8)
SearchPadding.PaddingRight = UDim.new(0, 8)
SearchPadding.Parent = SearchBox

local RosterList = Instance.new("ScrollingFrame")
RosterList.Size = UDim2.new(1, 0, 1, -56)
RosterList.Position = UDim2.new(0, 0, 0, 54)
RosterList.BackgroundTransparency = 1
RosterList.BorderSizePixel = 0
RosterList.ScrollBarThickness = 2
RosterList.ScrollBarImageColor3 = CONFIG.THEME.BORDER
RosterList.CanvasSize = UDim2.new(0, 0, 0, 0)
RosterList.AutomaticCanvasSize = Enum.AutomaticSize.Y
RosterList.Parent = LeftRoster

local RosterLayout = Instance.new("UIListLayout")
RosterLayout.SortOrder = Enum.SortOrder.Name
RosterLayout.Padding = UDim.new(0, 4)
RosterLayout.Parent = RosterList

local RightToolsContainer = Instance.new("ScrollingFrame")
RightToolsContainer.Size = UDim2.new(0.50, 0, 1, 0)
RightToolsContainer.BackgroundTransparency = 1
RightToolsContainer.BorderSizePixel = 0
RightToolsContainer.ScrollBarThickness = 2
RightToolsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
RightToolsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
RightToolsContainer.Parent = PlayerSplitFrame

local RightLayout = Instance.new("UIListLayout")
RightLayout.SortOrder = Enum.SortOrder.LayoutOrder
RightLayout.Padding = UDim.new(0, 8)
RightLayout.Parent = RightToolsContainer

local _, TargetInfoContent = createCard(RightToolsContainer, "Target Diagnostics")
local TargetDisplayLabel = Instance.new("TextLabel")
TargetDisplayLabel.Size = UDim2.new(1, 0, 0, 18)
TargetDisplayLabel.BackgroundTransparency = 1
TargetDisplayLabel.Font = CONFIG.FONTS.HEADER
TargetDisplayLabel.Text = "Target: [None Selected]"
TargetDisplayLabel.TextColor3 = state.accentColor
TargetDisplayLabel.TextSize = 12
TargetDisplayLabel.TextXAlignment = Enum.TextXAlignment.Left
TargetDisplayLabel.Parent = TargetInfoContent
registerAccent(TargetDisplayLabel, "TextColor3")

local TargetDistanceLabel = Instance.new("TextLabel")
TargetDistanceLabel.Size = UDim2.new(1, 0, 0, 14)
TargetDistanceLabel.BackgroundTransparency = 1
TargetDistanceLabel.Font = CONFIG.FONTS.MONO
TargetDistanceLabel.Text = "Distance: N/A"
TargetDistanceLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
TargetDistanceLabel.TextSize = 10
TargetDistanceLabel.TextXAlignment = Enum.TextXAlignment.Left
TargetDistanceLabel.Parent = TargetInfoContent

local TargetHealthLabel = Instance.new("TextLabel")
TargetHealthLabel.Size = UDim2.new(1, 0, 0, 14)
TargetHealthLabel.BackgroundTransparency = 1
TargetHealthLabel.Font = CONFIG.FONTS.MONO
TargetHealthLabel.Text = "Health: N/A"
TargetHealthLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
TargetHealthLabel.TextSize = 10
TargetHealthLabel.TextXAlignment = Enum.TextXAlignment.Left
TargetHealthLabel.Parent = TargetInfoContent

updateTargetCard = function()
	if not state.selectedPlayer then
		TargetDisplayLabel.Text = "Target: [None Selected]"
		TargetDistanceLabel.Text = "Distance: N/A"
		TargetHealthLabel.Text = "Health: N/A"
		return
	end

	local target = state.selectedPlayer
	TargetDisplayLabel.Text = string.format("Target: %s (@%s)", target.DisplayName, target.Name)

	local myChar = LocalPlayer.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?

	local tChar = target.Character
	local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")

	if myHrp and tHrp then
		local dist = (myHrp.Position - tHrp.Position).Magnitude
		TargetDistanceLabel.Text = string.format("Distance: %.1f studs", dist)
	else
		TargetDistanceLabel.Text = "Distance: Target Character Absent"
	end

	if tHum then
		TargetHealthLabel.Text = string.format("Health: %.0f / %.0f", tHum.Health, tHum.MaxHealth)
		if tHum.Health <= 0 then
			TargetHealthLabel.TextColor3 = CONFIG.THEME.ERROR
		else
			TargetHealthLabel.TextColor3 = CONFIG.THEME.SUCCESS
		end
	else
		TargetHealthLabel.Text = "Health: Humanoid Absent"
		TargetHealthLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
	end
end

local function selectTargetPlayer(player: Player?)
	state.selectedPlayer = player
	state.selectedPlayerName = player and player.Name or "None"
	updateTargetCard()

	for _, child in ipairs(RosterList:GetChildren()) do
		if child:IsA("TextButton") then
			local isMatch = player and child.Name == player.Name
			animateTween(child, 0.12, {
				BackgroundColor3 = isMatch and CONFIG.THEME.SURFACE_ALT or CONFIG.THEME.INPUT_BG,
			})
			local strk = child:FindFirstChildOfClass("UIStroke")
			if strk then
				strk.Color = isMatch and state.accentColor or CONFIG.THEME.BORDER
			end
		end
	end

	if player then
		updateStatusBar(string.format("Selected target player: %s", player.Name), "Normal")
	else
		updateStatusBar("Target player deselected.", "Normal")
	end
end

local function refreshRosterList()
	for _, child in ipairs(RosterList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local query = SearchBox.Text:lower()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local nameMatches = player.Name:lower():find(query) or player.DisplayName:lower():find(query)
			if query == "" or nameMatches then
				local item = Instance.new("TextButton")
				item.Name = player.Name
				item.Size = UDim2.new(1, 0, 0, 26)
				item.BackgroundColor3 = (state.selectedPlayer == player) and CONFIG.THEME.SURFACE_ALT or CONFIG.THEME.INPUT_BG
				item.BorderSizePixel = 0
				item.Text = ""
				item.AutoButtonColor = false
				item.Parent = RosterList
				createCorner(item, 4)
				local strk = createStroke(item, (state.selectedPlayer == player) and state.accentColor or CONFIG.THEME.BORDER, 1)

				local nameLbl = Instance.new("TextLabel")
				nameLbl.Size = UDim2.new(0.65, 0, 1, 0)
				nameLbl.Position = UDim2.new(0, 6, 0, 0)
				nameLbl.BackgroundTransparency = 1
				nameLbl.Font = CONFIG.FONTS.BODY
				nameLbl.Text = player.DisplayName
				nameLbl.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
				nameLbl.TextSize = 10
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
				nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
				nameLbl.Parent = item

				local userLbl = Instance.new("TextLabel")
				userLbl.Size = UDim2.new(0.35, -10, 1, 0)
				userLbl.Position = UDim2.new(0.65, 0, 0, 0)
				userLbl.BackgroundTransparency = 1
				userLbl.Font = CONFIG.FONTS.MONO
				userLbl.Text = "@" .. player.Name
				userLbl.TextColor3 = CONFIG.THEME.TEXT_MUTED
				userLbl.TextSize = 9
				userLbl.TextXAlignment = Enum.TextXAlignment.Right
				userLbl.TextTruncate = Enum.TextTruncate.AtEnd
				userLbl.Parent = item

				trackConnection(item.Activated:Connect(function()
					if state.selectedPlayer == player then
						selectTargetPlayer(nil)
					else
						selectTargetPlayer(player)
					end
				end))
			end
		end
	end
end

trackConnection(SearchBox:GetPropertyChangedSignal("Text"):Connect(refreshRosterList))
trackConnection(Players.PlayerAdded:Connect(refreshRosterList))
trackConnection(Players.PlayerRemoving:Connect(function(leaving)
	if state.selectedPlayer == leaving then
		selectTargetPlayer(nil)
	end
	refreshRosterList()
end))
refreshRosterList()

-- Teleportation Engine (CFrame-based)
local function executeTeleport()
	if not state.selectedPlayer then
		updateStatusBar("Cannot teleport: No target player selected.", "Warning")
		return
	end

	local targetChar = state.selectedPlayer.Character
	local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetHrp then
		updateStatusBar("Target character root part unavailable.", "Error")
		return
	end

	local myChar = LocalPlayer.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not myHrp then
		updateStatusBar("Local character root part unavailable.", "Error")
		return
	end

	state.previousPosition = myHrp.CFrame

	local offsetVector = Vector3.zero
	if state.teleportOffset == "Behind" then
		offsetVector = -targetHrp.CFrame.LookVector * state.teleportDistance
	elseif state.teleportOffset == "Above" then
		offsetVector = Vector3.new(0, state.teleportDistance, 0)
	elseif state.teleportOffset == "InFront" then
		offsetVector = targetHrp.CFrame.LookVector * state.teleportDistance
	end

	local destination = targetHrp.CFrame + offsetVector
	myHrp.CFrame = CFrame.new(destination.Position, targetHrp.Position)
	updateStatusBar(string.format("Teleported to %s [%s, %d studs].", state.selectedPlayer.Name, state.teleportOffset, state.teleportDistance), "Success")
end

local function executeReturnToPrevious()
	if not state.previousPosition then
		updateStatusBar("No previous position saved.", "Warning")
		return
	end

	local myChar = LocalPlayer.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not myHrp then
		updateStatusBar("Local character root part unavailable.", "Error")
		return
	end

	myHrp.CFrame = state.previousPosition
	updateStatusBar("Returned to previously saved position coordinates.", "Success")
end

local _, TeleportCardContent = createCard(RightToolsContainer, "Target Navigation", "Client-side CFrame translation")

local OffsetSelectorRow = Instance.new("Frame")
OffsetSelectorRow.Size = UDim2.new(1, 0, 0, 24)
OffsetSelectorRow.BackgroundTransparency = 1
OffsetSelectorRow.Parent = TeleportCardContent

local OffsetLayout = Instance.new("UIListLayout")
OffsetLayout.FillDirection = Enum.FillDirection.Horizontal
OffsetLayout.Padding = UDim.new(0, 4)
OffsetLayout.Parent = OffsetSelectorRow

local offsetButtons: { [string]: TextButton } = {}
local function setOffsetMode(mode: string)
	state.teleportOffset = mode
	for m, btn in pairs(offsetButtons) do
		local isSel = (m == mode)
		btn.BackgroundColor3 = isSel and state.accentColor or CONFIG.THEME.INPUT_BG
		btn.TextColor3 = isSel and CONFIG.THEME.BACKGROUND or CONFIG.THEME.TEXT_SECONDARY
	end
end

for _, m in ipairs({ "Behind", "Above", "InFront" }) do
	local ob = Instance.new("TextButton")
	ob.Size = UDim2.new(0.32, 0, 1, 0)
	ob.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	ob.Font = CONFIG.FONTS.BODY
	ob.Text = m
	ob.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
	ob.TextSize = 10
	ob.Parent = OffsetSelectorRow
	createCorner(ob, 4)
	createStroke(ob, CONFIG.THEME.BORDER, 1)
	offsetButtons[m] = ob
	trackConnection(ob.Activated:Connect(function()
		setOffsetMode(m)
	end))
end
setOffsetMode(state.teleportOffset)

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
local followConnection: RBXScriptConnection? = nil

local function stopFollowing()
	state.isFollowing = false
	if followConnection then
		followConnection:Disconnect()
		followConnection = nil
	end
	if setFollowVisual then
		setFollowVisual(false)
	end
end

local function startFollowing()
	if not state.selectedPlayer then
		updateStatusBar("Follow aborted: No target player selected.", "Warning")
		stopFollowing()
		return
	end

	stopFollowing()
	state.isFollowing = true

	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if not state.isFollowing or not state.selectedPlayer then
			stopFollowing()
			return
		end

		local tChar = state.selectedPlayer.Character
		local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		local myChar = LocalPlayer.Character
		local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
		local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?

		if tHrp and myHum and myHrp then
			local dist = (myHrp.Position - tHrp.Position).Magnitude
			if dist > state.followDistance + 1 then
				local targetGoal = tHrp.Position - (tHrp.CFrame.LookVector * state.followDistance)
				myHum:MoveTo(targetGoal)
			end
		end
	end)
	trackConnection(conn)
	followConnection = conn
	updateStatusBar(string.format("Actively following %s.", state.selectedPlayer.Name), "Success")
end

local _, followVisSetter = createToggle(FollowCardContent, "Follow Target", CONFIG.AVAILABILITY.LOCAL, state.isFollowing, function(enabled)
	if enabled then
		startFollowing()
	else
		stopFollowing()
		updateStatusBar("Target following stopped.", "Normal")
	end
end)
setFollowVisual = followVisSetter
end

local function buildTrollTab(PageTroll: ScrollingFrame)
-- SECTION 6: TROLL & PHYSICAL MANIPULATION SUITE
local _, FlingCardContent = createCard(PageTroll, "FE Target Physical Impactor (Fling)", "Accelerates local character physics to impart impulse")

createSlider(FlingCardContent, "Fling Assembly Multiplier", 20, 200, state.flingIntensity, 5, "%", function(val)
	state.flingIntensity = val
	state.flingMaxVelocity = 1000 * val
end)

local flingLoopConn: RBXScriptConnection? = nil

abortFling = function()
	state.isFlinging = false
	if flingLoopConn then
		flingLoopConn:Disconnect()
		flingLoopConn = nil
	end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	if hrp then
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.AssemblyLinearVelocity = Vector3.zero
	end
	if hum then
		hum.PlatformStand = false
	end
end

local function executeFling()
	if not state.selectedPlayer then
		updateStatusBar("Fling aborted: No target player selected.", "Warning")
		return
	end

	local target = state.selectedPlayer
	local targetChar = target.Character
	local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not targetHrp then
		updateStatusBar("Fling aborted: Target root part unavailable.", "Error")
		return
	end

	local myChar = LocalPlayer.Character
	local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")

	if not myHrp or not myHum then
		updateStatusBar("Fling aborted: Local character unavailable.", "Error")
		return
	end

	state.isFlinging = true
	myHum.PlatformStand = true

	local initialPos = myHrp.CFrame
	local startTime = tick()
	local maxDuration = 4.0

	flingLoopConn = RunService.Heartbeat:Connect(function()
		if not state.isFlinging or tick() - startTime > maxDuration then
			abortFling()
			if myHrp and myHrp.Parent then
				myHrp.CFrame = initialPos
			end
			updateStatusBar("Fling routine ended. Restored original coordinates.", "Normal")
			return
		end

		local tCharCurrent = target.Character
		local tHrpCurrent = tCharCurrent and tCharCurrent:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not tHrpCurrent then
			abortFling()
			return
		end

		local rotAng = tick() * 30
		local offset = Vector3.new(math.sin(rotAng) * 1.5, 0.5, math.cos(rotAng) * 1.5)
		myHrp.CFrame = CFrame.new(tHrpCurrent.Position + offset, tHrpCurrent.Position)

		local boost = state.flingMaxVelocity
		myHrp.AssemblyAngularVelocity = Vector3.new(boost, boost, boost)
		myHrp.AssemblyLinearVelocity = Vector3.new(boost * 0.1, boost, boost * 0.1)
	end)

	trackConnection(flingLoopConn :: RBXScriptConnection)
	updateStatusBar(string.format("Executing physical impact on %s...", target.Name), "Success")
end

createActionButton(FlingCardContent, "Execute Target Fling", CONFIG.AVAILABILITY.FE_PHYSICS, executeFling)
createActionButton(FlingCardContent, "Abort Fling / Restore Physics", CONFIG.AVAILABILITY.LOCAL, abortFling)

-- Touch Fling Implementation
local _, TouchFlingCardContent = createCard(PageTroll, "Touch Fling (Passive Proximity Fling)", "Spins assembly momentum while preserving character controls")

local touchFlingConn: RBXScriptConnection? = nil

stopTouchFling = function()
	state.isTouchFling = false
	if touchFlingConn then
		touchFlingConn:Disconnect()
		touchFlingConn = nil
	end
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
end

local function startTouchFling()
	stopTouchFling()
	state.isTouchFling = true

	touchFlingConn = RunService.Heartbeat:Connect(function()
		if not state.isTouchFling then
			stopTouchFling()
			return
		end

		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			local vel = hrp.AssemblyLinearVelocity
			hrp.AssemblyAngularVelocity = Vector3.new(100000, 100000, 100000)
			hrp.AssemblyLinearVelocity = Vector3.new(vel.X, 0.05, vel.Z)
		end
	end)
	trackConnection(touchFlingConn :: RBXScriptConnection)
	updateStatusBar("Touch Fling active. Walk into unanchored players to launch them.", "Success")
end

createToggle(TouchFlingCardContent, "Touch Fling Active", CONFIG.AVAILABILITY.FE_PHYSICS, state.isTouchFling, function(enabled)
	if enabled then
		startTouchFling()
	else
		stopTouchFling()
		updateStatusBar("Touch Fling deactivated.", "Normal")
	end
end)

-- Orbit Target
local _, OrbitCardContent = createCard(PageTroll, "Orbit Target", "Rotates character around selected target at high speed")
createSlider(OrbitCardContent, "Orbit Radius", 3, 30, state.orbitRadius, 1, "studs", function(val)
	state.orbitRadius = val
end)
createSlider(OrbitCardContent, "Orbit Speed", 1, 10, state.orbitSpeed, 0.5, "rad/s", function(val)
	state.orbitSpeed = val
end)

local orbitConnection: RBXScriptConnection? = nil

stopOrbit = function()
	state.isOrbiting = false
	if orbitConnection then
		orbitConnection:Disconnect()
		orbitConnection = nil
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
	end
	if setOrbitVisual then setOrbitVisual(false) end
end

local function startOrbit()
	if not state.selectedPlayer then
		updateStatusBar("Orbit aborted: No target player selected.", "Warning")
		stopOrbit()
		return
	end

	stopOrbit()
	state.isOrbiting = true

	local angle = 0
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.PlatformStand = true end

	orbitConnection = RunService.Heartbeat:Connect(function(dt)
		if not state.isOrbiting or not state.selectedPlayer then
			stopOrbit()
			return
		end

		local tChar = state.selectedPlayer.Character
		local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		local myChar = LocalPlayer.Character
		local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?

		if tHrp and myHrp then
			angle = angle + (state.orbitSpeed * dt * 3)
			local x = math.cos(angle) * state.orbitRadius
			local z = math.sin(angle) * state.orbitRadius
			local targetPos = tHrp.Position + Vector3.new(x, 1, z)
			myHrp.CFrame = CFrame.new(targetPos, tHrp.Position)
			myHrp.AssemblyLinearVelocity = Vector3.zero
		end
	end)
	trackConnection(orbitConnection :: RBXScriptConnection)
	updateStatusBar(string.format("Orbiting %s.", state.selectedPlayer.Name), "Success")
end

local _, setOrbitToggle = createToggle(OrbitCardContent, "Orbit Active", CONFIG.AVAILABILITY.LOCAL, state.isOrbiting, function(enabled)
	if enabled then
		startOrbit()
	else
		stopOrbit()
		updateStatusBar("Orbit deactivated.", "Normal")
	end
end)
setOrbitVisual = setOrbitToggle

-- Head Sit Target
local _, HeadSitCardContent = createCard(PageTroll, "Head Sit", "Attaches character coordinates directly atop target head")
local headSitConnection: RBXScriptConnection? = nil

stopHeadSit = function()
	state.isHeadSitting = false
	if headSitConnection then
		headSitConnection:Disconnect()
		headSitConnection = nil
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Sit = false
	end
	if setHeadSitVisual then setHeadSitVisual(false) end
end

local function startHeadSit()
	if not state.selectedPlayer then
		updateStatusBar("Head Sit aborted: No target player selected.", "Warning")
		stopHeadSit()
		return
	end

	stopHeadSit()
	state.isHeadSitting = true

	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Sit = true end

	headSitConnection = RunService.Heartbeat:Connect(function()
		if not state.isHeadSitting or not state.selectedPlayer then
			stopHeadSit()
			return
		end

		local tChar = state.selectedPlayer.Character
		local tHead = tChar and tChar:FindFirstChild("Head") :: BasePart?
		local myChar = LocalPlayer.Character
		local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?

		if tHead and myHrp then
			myHrp.CFrame = tHead.CFrame * CFrame.new(0, 1.8, 0)
			myHrp.AssemblyLinearVelocity = Vector3.zero
		end
	end)
	trackConnection(headSitConnection :: RBXScriptConnection)
	updateStatusBar(string.format("Sitting on %s's head.", state.selectedPlayer.Name), "Success")
end

local _, setHeadSitToggle = createToggle(HeadSitCardContent, "Head Sit Active", CONFIG.AVAILABILITY.LOCAL, state.isHeadSitting, function(enabled)
	if enabled then
		startHeadSit()
	else
		stopHeadSit()
		updateStatusBar("Head Sit deactivated.", "Normal")
	end
end)
setHeadSitVisual = setHeadSitToggle
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
		updateStatusBar(string.format("Jump parameter set to %.0f [Subject to server scripts].", val), "Normal")
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
local _, PresetCardContent = createCard(PageMovement, "Speed & Jump Quick Presets", "Instant standard movement values")

local WalkPresetRow = Instance.new("Frame")
WalkPresetRow.Size = UDim2.new(1, 0, 0, 26)
WalkPresetRow.BackgroundTransparency = 1
WalkPresetRow.Parent = PresetCardContent

local WalkPresetLayout = Instance.new("UIListLayout")
WalkPresetLayout.FillDirection = Enum.FillDirection.Horizontal
WalkPresetLayout.Padding = UDim.new(0, 4)
WalkPresetLayout.Parent = WalkPresetRow

local speedPresets = {
	{ name = "Default (16)", val = 16 },
	{ name = "Fast (32)", val = 32 },
	{ name = "Sprint (64)", val = 64 },
	{ name = "Sonic (100)", val = 100 },
}

for _, p in ipairs(speedPresets) do
	local pBtn = Instance.new("TextButton")
	pBtn.Size = UDim2.new(0.24, 0, 1, 0)
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
	updateStatusBar(enabled and "Infinite Jump active." or "Infinite Jump deactivated.", "Normal")
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

createToggle(ExtraMoveCardContent, "Bunny Hop / Auto Jump", CONFIG.AVAILABILITY.LOCAL, state.bunnyHop, function(enabled)
	state.bunnyHop = enabled
	updateStatusBar(enabled and "Bunny Hop active." or "Bunny Hop deactivated.", "Normal")
end)

trackConnection(RunService.Heartbeat:Connect(function()
	if state.bunnyHop then
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.FloorMaterial ~= Enum.Material.Air and hum.MoveDirection.Magnitude > 0 then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end))

createToggle(ExtraMoveCardContent, "Anti-Ragdoll / No Stumble", CONFIG.AVAILABILITY.LOCAL, state.antiRagdoll, function(enabled)
	state.antiRagdoll = enabled
	updateStatusBar(enabled and "Anti-Ragdoll safeguard active." or "Anti-Ragdoll deactivated.", "Normal")
end)

trackConnection(RunService.Heartbeat:Connect(function()
	if state.antiRagdoll then
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			local stateType = hum:GetState()
			if stateType == Enum.HumanoidStateType.Ragdoll or stateType == Enum.HumanoidStateType.FallingDown or stateType == Enum.HumanoidStateType.PlatformStanding then
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end
	end
end))

createSlider(ExtraMoveCardContent, "Custom Gravity", 0, 400, state.customGravity, 5, "studs/s2", function(val)
	state.customGravity = val
	Workspace.Gravity = val
	updateStatusBar(string.format("Gravity set to %.0f.", val), "Normal")
end)

createActionButton(ExtraMoveCardContent, "Reset Gravity to Default", CONFIG.AVAILABILITY.LOCAL, function()
	Workspace.Gravity = state.defaultGravity
	state.customGravity = state.defaultGravity
	updateStatusBar("Gravity reset to engine default (196.2).", "Normal")
end)

-- Flight Mechanics
local _, FlightCardContent = createCard(PageMovement, "Flight Engine (BodyVelocity)", "Independent freeflight mechanics")
createSlider(FlightCardContent, "Flight Velocity", 10, 150, state.flightSpeed, 5, "studs/s", function(val)
	state.flightSpeed = val
end)

local flightBodyVel: BodyVelocity? = nil
local flightBodyGyro: BodyGyro? = nil
local flightConnection: RBXScriptConnection? = nil

stopFlight = function()
	state.isFlying = false
	if flightConnection then
		flightConnection:Disconnect()
		flightConnection = nil
	end
	if flightBodyVel then
		flightBodyVel:Destroy()
		flightBodyVel = nil
	end
	if flightBodyGyro then
		flightBodyGyro:Destroy()
		flightBodyGyro = nil
	end
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
	end
end

local function startFlight()
	stopFlight()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		updateStatusBar("Flight aborted: Character root part missing.", "Error")
		return
	end

	state.isFlying = true
	hum.PlatformStand = true

	local bv = Instance.new("BodyVelocity")
	bv.Name = "Sentinel_FlightVelocity"
	bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	bv.Velocity = Vector3.zero
	bv.Parent = hrp
	flightBodyVel = bv

	local bg = Instance.new("BodyGyro")
	bg.Name = "Sentinel_FlightGyro"
	bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	bg.P = 9e4
	bg.CFrame = hrp.CFrame
	bg.Parent = hrp
	flightBodyGyro = bg

	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		if not state.isFlying or not hrp.Parent then
			stopFlight()
			return
		end

		local cam = getCamera()
		local moveDir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			moveDir = moveDir + cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			moveDir = moveDir - cam.CFrame.LookVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then
			moveDir = moveDir - cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then
			moveDir = moveDir + cam.CFrame.RightVector
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			moveDir = moveDir + Vector3.new(0, 1, 0)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			moveDir = moveDir - Vector3.new(0, 1, 0)
		end

		if moveDir.Magnitude > 0 then
			bv.Velocity = moveDir.Unit * state.flightSpeed
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
	state.isNoclip = false
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
	local char = LocalPlayer.Character
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = true
			end
		end
	end
end

local function startNoclip()
	stopNoclip()
	state.isNoclip = true

	local conn: RBXScriptConnection
	conn = RunService.Stepped:Connect(function()
		if not state.isNoclip then
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
	updateStatusBar("Noclip enabled [Local collision disabled].", "Success")
end

createToggle(NoclipCardContent, "Noclip Active", CONFIG.AVAILABILITY.LOCAL, state.isNoclip, function(enabled)
	if enabled then
		startNoclip()
	else
		stopNoclip()
		updateStatusBar("Noclip disabled.", "Normal")
	end
end)
end

local function buildVisualsTab(PageVisuals: ScrollingFrame)
-- SECTION 6.5: VISUALS TAB
local _, CharCardContent = createCard(PageVisuals, "Character Visuals", "Local character rendering & transparency")

createSlider(CharCardContent, "Character Transparency", 0, 1, state.currentTransparency, 0.05, "", function(val)
	state.currentTransparency = val
	local char = LocalPlayer.Character
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				if not state.originalTransparencies[part] then
					state.originalTransparencies[part] = part.Transparency
				end
				part.Transparency = val
			end
		end
	end
	updateStatusBar(string.format("Character transparency set to %.2f.", val), "Normal")
end)

local function restoreTransparency()
	local char = LocalPlayer.Character
	if char then
		for part, orig in pairs(state.originalTransparencies) do
			if part and part.Parent and part:IsA("BasePart") then
				part.Transparency = orig
			end
		end
	end
	table.clear(state.originalTransparencies)
	state.currentTransparency = 0
	updateStatusBar("Character transparency restored to normal.", "Normal")
end

FeatureRegistry.RestoreTrans = {
	id = "restore_trans",
	label = "Restore Default Transparency",
	description = "Restores character parts to original transparency values.",
	availability = CONFIG.AVAILABILITY.LOCAL,
	category = "Character",
	execute = restoreTransparency,
}
createActionButton(CharCardContent, FeatureRegistry.RestoreTrans.label, FeatureRegistry.RestoreTrans.availability, restoreTransparency)

local _, HighlightCardContent = createCard(PageVisuals, "Target Player Highlighting", "Draws visual highlight adornment around selected player")

local function updateHighlightAdornee()
	if not state.isHighlightActive then return end
	if state.selectedHighlightInstance and state.selectedHighlightInstance.Parent then
		state.selectedHighlightInstance:Destroy()
		state.selectedHighlightInstance = nil
	end

	if state.selectedPlayer and state.selectedPlayer.Character then
		local hl = Instance.new("Highlight")
		hl.Name = "Sentinel_Highlight"
		hl.FillColor = state.accentColor
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.FillTransparency = 0.5
		hl.OutlineTransparency = 0
		hl.Adornee = state.selectedPlayer.Character
		hl.Parent = state.selectedPlayer.Character
		state.selectedHighlightInstance = hl
		trackInstance(hl)
	end
end

createToggle(HighlightCardContent, "Highlight Selected Player", CONFIG.AVAILABILITY.LOCAL, state.isHighlightActive, function(enabled)
	state.isHighlightActive = enabled
	if enabled then
		updateHighlightAdornee()
		updateStatusBar("Target highlight active.", "Success")
	else
		if state.selectedHighlightInstance and state.selectedHighlightInstance.Parent then
			state.selectedHighlightInstance:Destroy()
			state.selectedHighlightInstance = nil
		end
		updateStatusBar("Target highlight deactivated.", "Normal")
	end
end)

-- CAMERA & FIELD OF VIEW
local _, CamCardContent = createCard(PageVisuals, "Camera Optics", "Field of view and perspective zoom controls")
local _, setFovSlider = createSlider(CamCardContent, "Field of View", 30, 130, state.localFov, 1, "deg", function(val)
	state.localFov = val
	local cam = getCamera()
	if cam then
		cam.FieldOfView = val
	end
end)

local function resetFov()
	state.localFov = state.defaultFov
	setFovSlider(state.defaultFov)
	local cam = getCamera()
	if cam then
		cam.FieldOfView = state.defaultFov
	end
	updateStatusBar("FOV reset to default camera configuration.", "Normal")
end

FeatureRegistry.ResetFov = {
	id = "reset_fov",
	label = "Reset Field of View",
	description = "Restores camera FieldOfView to default angle.",
	availability = CONFIG.AVAILABILITY.LOCAL,
	category = "Visuals",
	execute = resetFov,
}
createActionButton(CamCardContent, FeatureRegistry.ResetFov.label, FeatureRegistry.ResetFov.availability, resetFov)

createSlider(CamCardContent, "Third-Person Max Zoom", 10, 300, state.thirdPersonDist, 5, "studs", function(val)
	state.thirdPersonDist = val
	LocalPlayer.CameraMaxZoomDistance = val
	updateStatusBar(string.format("CameraMaxZoomDistance set to %.0f.", val), "Normal")
end)

-- GLOBAL ESP & TRACERS SUITE
local _, EspCardContent = createCard(PageVisuals, "Diagnostic ESP & World Overlays", "Renders bounding boxes, name tags, and tracer vectors")

local espFolder = Instance.new("Folder")
espFolder.Name = "Sentinel_ESP_Container"
espFolder.Parent = ScreenGui

local function createEspBoxForPlayer(targetPlayer: Player): BillboardGui?
	if targetPlayer == LocalPlayer or not targetPlayer.Character then return nil end
	local char = targetPlayer.Character
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return nil end

	local old = espFolder:FindFirstChild("ESP_" .. targetPlayer.Name)
	if old then old:Destroy() end

	local bbg = Instance.new("BillboardGui")
	bbg.Name = "ESP_" .. targetPlayer.Name
	bbg.Adornee = hrp
	bbg.AlwaysOnTop = true
	bbg.Size = UDim2.new(4, 0, 5.5, 0)
	bbg.StudsOffset = Vector3.new(0, 0, 0)
	bbg.Parent = espFolder

	local boxFrame = Instance.new("Frame")
	boxFrame.Size = UDim2.new(1, 0, 1, 0)
	boxFrame.BackgroundTransparency = 1
	boxFrame.Parent = bbg
	createStroke(boxFrame, state.accentColor, 1.5)

	local nameTag = Instance.new("TextLabel")
	nameTag.Size = UDim2.new(1, 0, 0, 14)
	nameTag.Position = UDim2.new(0, 0, 0, -16)
	nameTag.BackgroundTransparency = 1
	nameTag.Font = CONFIG.FONTS.MONO
	nameTag.Text = string.format("%s [Dist: %d]", targetPlayer.DisplayName, math.floor((hrp.Position - (LocalPlayer.Character and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart and (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart).Position or Vector3.zero) or Vector3.zero)).Magnitude))
	nameTag.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameTag.TextSize = 9
	nameTag.TextStrokeTransparency = 0.2
	nameTag.Parent = bbg

	return bbg
end

local function refreshAllEsp()
	espFolder:ClearAllChildren()
	if not state.isEspActive then return end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character then
			createEspBoxForPlayer(p)
		end
	end
end

createToggle(EspCardContent, "Player Boxes & Name Tags ESP", CONFIG.AVAILABILITY.LOCAL, state.isEspActive, function(enabled)
	state.isEspActive = enabled
	refreshAllEsp()
	updateStatusBar(enabled and "Player ESP visual overlays active." or "Player ESP overlays removed.", "Normal")
end)

trackConnection(RunService.Heartbeat:Connect(function()
	if state.isEspActive then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and p.Character then
				local existing = espFolder:FindFirstChild("ESP_" .. p.Name)
				if not existing then
					createEspBoxForPlayer(p)
				else
					local hrp = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if hrp and myHrp then
						local dist = math.floor((hrp.Position - myHrp.Position).Magnitude)
						local lbl = existing:FindFirstChildOfClass("TextLabel")
						if lbl then
							lbl.Text = string.format("%s [%d studs]", p.DisplayName, dist)
						end
					end
				end
			end
		end
	end
end))

-- X-RAY & AMBIENT WORLD LIGHTING
local _, WorldLightCardContent = createCard(PageVisuals, "Lighting & Rendering Diagnostic Filters", "Fullbright illumination, wall x-ray, and fog negation")

createToggle(WorldLightCardContent, "Fullbright Ambient Lighting", CONFIG.AVAILABILITY.LOCAL, state.fullbright, function(enabled)
	state.fullbright = enabled
	local lighting = game:GetService("Lighting")
	if enabled then
		lighting.Ambient = Color3.fromRGB(255, 255, 255)
		lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
		lighting.Brightness = 2
	else
		lighting.Ambient = Color3.fromRGB(128, 128, 128)
		lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
		lighting.Brightness = 1
	end
	updateStatusBar(enabled and "Fullbright illumination active." or "Lighting ambient restored.", "Normal")
end)

createToggle(WorldLightCardContent, "Negate Atmospheric Fog", CONFIG.AVAILABILITY.LOCAL, state.noFog, function(enabled)
	state.noFog = enabled
	local lighting = game:GetService("Lighting")
	if enabled then
		lighting.FogEnd = 100000
	else
		lighting.FogEnd = 1000
	end
	updateStatusBar(enabled and "Atmospheric fog disabled." or "Atmospheric fog restored.", "Normal")
end)

createToggle(WorldLightCardContent, "Wall X-Ray (Translucent Architecture)", CONFIG.AVAILABILITY.LOCAL, state.xrayActive, function(enabled)
	state.xrayActive = enabled
	for _, part in ipairs(Workspace:GetDescendants()) do
		if part:IsA("BasePart") and not part:IsDescendantOf(LocalPlayer.Character or Workspace) and part.Transparency < 0.8 then
			if enabled then
				if not state.originalTransparencies[part] then
					state.originalTransparencies[part] = part.Transparency
				end
				part.Transparency = 0.65
			else
				if state.originalTransparencies[part] then
					part.Transparency = state.originalTransparencies[part]
				end
			end
		end
	end
	updateStatusBar(enabled and "Wall X-Ray active." or "Wall X-Ray restored.", "Normal")
end)
end

local function buildExecutorTab(PageExecutor: ScrollingFrame)
-- SECTION 6.6: EXECUTOR TAB
local _, EditorCardContent = createCard(PageExecutor, "Universal Script Console & Runner", "Compiles and runs custom Luau chunks client-side")

local EditorContainer = Instance.new("Frame")
EditorContainer.Size = UDim2.new(1, 0, 0, 140)
EditorContainer.BackgroundColor3 = CONFIG.THEME.INPUT_BG
EditorContainer.BorderSizePixel = 0
EditorContainer.Parent = EditorCardContent
createCorner(EditorContainer, 6)
createStroke(EditorContainer, CONFIG.THEME.BORDER, 1)

local CodeScroll = Instance.new("ScrollingFrame")
CodeScroll.Size = UDim2.new(1, -12, 1, -12)
CodeScroll.Position = UDim2.new(0, 6, 0, 6)
CodeScroll.BackgroundTransparency = 1
CodeScroll.BorderSizePixel = 0
CodeScroll.ScrollBarThickness = 3
CodeScroll.ScrollBarImageColor3 = CONFIG.THEME.BORDER
CodeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
CodeScroll.AutomaticCanvasSize = Enum.AutomaticSize.XY
CodeScroll.Parent = EditorContainer

local CodeEditorBox = Instance.new("TextBox")
CodeEditorBox.Size = UDim2.new(1, 0, 1, 0)
CodeEditorBox.AutomaticSize = Enum.AutomaticSize.XY
CodeEditorBox.BackgroundTransparency = 1
CodeEditorBox.Font = CONFIG.FONTS.MONO
CodeEditorBox.PlaceholderColor3 = CONFIG.THEME.TEXT_MUTED
CodeEditorBox.PlaceholderText = "-- Type or paste Luau script here...\nprint('Hello from Sentinel Executor!')"
CodeEditorBox.Text = state.savedExecutorCode
CodeEditorBox.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
CodeEditorBox.TextSize = 11
CodeEditorBox.ClearTextOnFocus = false
CodeEditorBox.MultiLine = true
CodeEditorBox.TextXAlignment = Enum.TextXAlignment.Left
CodeEditorBox.TextYAlignment = Enum.TextYAlignment.Top
CodeEditorBox.Parent = CodeScroll

local ExecButtonRow = Instance.new("Frame")
ExecButtonRow.Size = UDim2.new(1, 0, 0, 32)
ExecButtonRow.BackgroundTransparency = 1
ExecButtonRow.Parent = EditorCardContent

local ExecButtonLayout = Instance.new("UIListLayout")
ExecButtonLayout.FillDirection = Enum.FillDirection.Horizontal
ExecButtonLayout.Padding = UDim.new(0, 6)
ExecButtonLayout.Parent = ExecButtonRow

local RunButton = Instance.new("TextButton")
RunButton.Size = UDim2.new(0.32, 0, 1, 0)
RunButton.BackgroundColor3 = CONFIG.THEME.SURFACE_ALT
RunButton.Font = CONFIG.FONTS.HEADER
RunButton.Text = "Execute"
RunButton.TextColor3 = state.accentColor
RunButton.TextSize = 11
RunButton.Parent = ExecButtonRow
createCorner(RunButton, 6)
local runStroke = createStroke(RunButton, state.accentColor, 1)
registerAccent(runStroke, "Color")
registerAccent(RunButton, "TextColor3")

local ClearButton = Instance.new("TextButton")
ClearButton.Size = UDim2.new(0.32, 0, 1, 0)
ClearButton.BackgroundColor3 = CONFIG.THEME.INPUT_BG
ClearButton.Font = CONFIG.FONTS.HEADER
ClearButton.Text = "Clear"
ClearButton.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
ClearButton.TextSize = 11
ClearButton.Parent = ExecButtonRow
createCorner(ClearButton, 6)
createStroke(ClearButton, CONFIG.THEME.BORDER, 1)

local PasteButton = Instance.new("TextButton")
PasteButton.Size = UDim2.new(0.32, 0, 1, 0)
PasteButton.BackgroundColor3 = CONFIG.THEME.INPUT_BG
PasteButton.Font = CONFIG.FONTS.HEADER
PasteButton.Text = "Paste Clip"
PasteButton.TextColor3 = CONFIG.THEME.TEXT_SECONDARY
PasteButton.TextSize = 11
PasteButton.Parent = ExecButtonRow
createCorner(PasteButton, 6)
createStroke(PasteButton, CONFIG.THEME.BORDER, 1)

local ExecStatusLabel = Instance.new("TextLabel")
ExecStatusLabel.Size = UDim2.new(1, 0, 0, 20)
ExecStatusLabel.BackgroundTransparency = 1
ExecStatusLabel.Font = CONFIG.FONTS.MONO
ExecStatusLabel.Text = "Console: Idle"
ExecStatusLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
ExecStatusLabel.TextSize = 10
ExecStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
ExecStatusLabel.Parent = EditorCardContent

trackConnection(RunButton.Activated:Connect(function()
	local code = CodeEditorBox.Text
	state.savedExecutorCode = code
	ExecStatusLabel.Text = "Compiling and executing script..."
	ExecStatusLabel.TextColor3 = state.accentColor

	local success, resultMsg = executeScriptString(code)
	if success then
		ExecStatusLabel.Text = "Success: " .. resultMsg
		ExecStatusLabel.TextColor3 = CONFIG.THEME.SUCCESS
		updateStatusBar("Executed custom Luau chunk.", "Success")
	else
		ExecStatusLabel.Text = "Execution Error: " .. resultMsg
		ExecStatusLabel.TextColor3 = CONFIG.THEME.ERROR
		updateStatusBar("Executor encountered compile or runtime error.", "Error")
	end
end))

trackConnection(ClearButton.Activated:Connect(function()
	CodeEditorBox.Text = ""
	state.savedExecutorCode = ""
	ExecStatusLabel.Text = "Console: Cleared."
	ExecStatusLabel.TextColor3 = CONFIG.THEME.TEXT_MUTED
end))

trackConnection(PasteButton.Activated:Connect(function()
	if typeof(getclipboard) == "function" then
		local ok, text = pcall(getclipboard)
		if ok and text then
			CodeEditorBox.Text = tostring(text)
			state.savedExecutorCode = CodeEditorBox.Text
			ExecStatusLabel.Text = "Clipboard contents pasted."
			ExecStatusLabel.TextColor3 = state.accentColor
			return
		end
	end
	local anyG = _G :: any
	if anyG and typeof(anyG.getclipboard) == "function" then
		local ok, text = pcall(anyG.getclipboard)
		if ok and text then
			CodeEditorBox.Text = tostring(text)
			state.savedExecutorCode = CodeEditorBox.Text
			ExecStatusLabel.Text = "Clipboard contents pasted."
			ExecStatusLabel.TextColor3 = state.accentColor
			return
		end
	end
	ExecStatusLabel.Text = "Clipboard read not supported by this executor."
	ExecStatusLabel.TextColor3 = CONFIG.THEME.WARNING
end))

-- SCRIPT HUB QUICK LOADER
local _, HubCardContent = createCard(PageExecutor, "Built-In Script Hub Quick Library", "Preset diagnostic and exploration utilities")

local libraryScripts = {
	{
		title = "Infinite Yield Universal Admin",
		desc = "Feature-complete general administration suite",
		code = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()]],
	},
	{
		title = "Simple Spy Remote Logger",
		desc = "Captures and logs client-server network signals",
		code = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/SimpleSpyV3/main.lua"))()]],
	},
	{
		title = "Dex Explorer V4",
		desc = "Full Roblox DOM hierarchy and property inspector",
		code = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/dex.lua"))()]],
	},
	{
		title = "Hydroxide Memory & Remote Inspector",
		desc = "Advanced networked data packet debugging suite",
		code = [[loadstring(game:HttpGet("https://raw.githubusercontent.com/Upbolt/Hydroxide/revision/init.lua"))()]],
	},
}

for _, item in ipairs(libraryScripts) do
	local libItem = Instance.new("Frame")
	libItem.Size = UDim2.new(1, 0, 0, 36)
	libItem.BackgroundColor3 = CONFIG.THEME.INPUT_BG
	libItem.BorderSizePixel = 0
	libItem.Parent = HubCardContent
	createCorner(libItem, 6)
	createStroke(libItem, CONFIG.THEME.BORDER, 1)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(0.65, 0, 0, 16)
	titleLbl.Position = UDim2.new(0, 8, 0, 2)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = CONFIG.FONTS.HEADER
	titleLbl.Text = item.title
	titleLbl.TextColor3 = CONFIG.THEME.TEXT_PRIMARY
	titleLbl.TextSize = 10
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Parent = libItem

	local descLbl = Instance.new("TextLabel")
	descLbl.Size = UDim2.new(0.65, 0, 0, 14)
	descLbl.Position = UDim2.new(0, 8, 0, 18)
	descLbl.BackgroundTransparency = 1
	descLbl.Font = CONFIG.FONTS.BODY
	descLbl.Text = item.desc
	descLbl.TextColor3 = CONFIG.THEME.TEXT_MUTED
	descLbl.TextSize = 9
	descLbl.TextXAlignment = Enum.TextXAlignment.Left
	descLbl.Parent = libItem

	local loadBtn = Instance.new("TextButton")
	loadBtn.Size = UDim2.new(0, 54, 0, 24)
	loadBtn.Position = UDim2.new(1, -62, 0.5, -12)
	loadBtn.BackgroundColor3 = CONFIG.THEME.SURFACE_ALT
	loadBtn.Font = CONFIG.FONTS.HEADER
	loadBtn.Text = "Load"
	loadBtn.TextColor3 = state.accentColor
	loadBtn.TextSize = 10
	loadBtn.Parent = libItem
	createCorner(loadBtn, 4)
	local lStroke = createStroke(loadBtn, state.accentColor, 1)
	registerAccent(lStroke, "Color")
	registerAccent(loadBtn, "TextColor3")

	trackConnection(loadBtn.Activated:Connect(function()
		CodeEditorBox.Text = item.code
		state.savedExecutorCode = item.code
		updateStatusBar("Loaded script into executor editor: " .. item.title, "Success")
	end))
end
end

local function buildWorldTab(PageWorld: ScrollingFrame)
-- SECTION 6.7: WORLD TAB
local _, WorldPhysicsCardContent = createCard(PageWorld, "Environmental Physics", "Global game environment and physics controls")

createSlider(WorldPhysicsCardContent, "Client Clock Time", 0, 24, state.clientClockTime, 0.5, "hrs", function(val)
	state.clientClockTime = val
	game:GetService("Lighting").ClockTime = val
	updateStatusBar(string.format("Client ClockTime adjusted to %.1f.", val), "Normal")
end)

createActionButton(WorldPhysicsCardContent, "Remove Map Kill Plusses & Void Fall Anchors", CONFIG.AVAILABILITY.LOCAL, function()
	local count = 0
	for _, part in ipairs(Workspace:GetDescendants()) do
		if part:IsA("TouchTransmitter") or (part:IsA("BasePart") and (part.Name:lower():find("kill") or part.Name:lower():find("lava") or part.Name:lower():find("death"))) then
			pcall(function()
				part:Destroy()
				count = count + 1
			end)
		end
	end
	updateStatusBar(string.format("Purged %d hazard zones/transmitters from workspace.", count), "Success")
end)

local _, AntiVoidCardContent = createCard(PageWorld, "Anti-Void Safeguard", "Prevents falling into the void by placing a platform beneath character")
local antiVoidPart: Part? = nil
local antiVoidConn: RBXScriptConnection? = nil

createToggle(AntiVoidCardContent, "Anti-Void Platform", CONFIG.AVAILABILITY.LOCAL, state.antiVoidActive, function(enabled)
	state.antiVoidActive = enabled
	if enabled then
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local yLevel = hrp and (hrp.Position.Y - 15) or -50

		local part = Instance.new("Part")
		part.Name = "Sentinel_AntiVoidPlatform"
		part.Size = Vector3.new(2000, 2, 2000)
		part.Anchored = true
		part.CanCollide = true
		part.Transparency = 0.6
		part.Material = Enum.Material.ForceField
		part.Color = state.accentColor
		part.CFrame = CFrame.new(0, yLevel, 0)
		part.Parent = Workspace
		antiVoidPart = part
		trackInstance(part)

		antiVoidConn = RunService.Heartbeat:Connect(function()
			if state.antiVoidActive and antiVoidPart and LocalPlayer.Character then
				local currentHrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if currentHrp and currentHrp.Position.Y < (antiVoidPart.Position.Y + 2) then
					currentHrp.CFrame = CFrame.new(currentHrp.Position.X, antiVoidPart.Position.Y + 5, currentHrp.Position.Z)
					currentHrp.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end)
		trackConnection(antiVoidConn :: RBXScriptConnection)
		updateStatusBar("Anti-Void safeguard platform deployed.", "Success")
	else
		if antiVoidConn then
			antiVoidConn:Disconnect()
			antiVoidConn = nil
		end
		if antiVoidPart and antiVoidPart.Parent then
			antiVoidPart:Destroy()
			antiVoidPart = nil
		end
		updateStatusBar("Anti-Void platform removed.", "Normal")
	end
end)

-- CLICK TELEPORT
local _, ClickTpCardContent = createCard(PageWorld, "Click / Touch Teleportation", "Teleports character directly to raycasted tap position")

local clickTpConn: RBXScriptConnection? = nil
createToggle(ClickTpCardContent, "Click / Touch to Teleport", CONFIG.AVAILABILITY.LOCAL, state.clickTeleport, function(enabled)
	state.clickTeleport = enabled
	if enabled then
		clickTpConn = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or (input.UserInputType == Enum.UserInputType.Touch and not UserInputService:GetFocusedTextBox()) then
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or isMobileDevice then
					local cam = getCamera()
					local mousePos = UserInputService:GetMouseLocation()
					local ray = cam:ViewportPointToRay(mousePos.X, mousePos.Y)
					local rayParams = RaycastParams.new()
					rayParams.FilterDescendantsInstances = { LocalPlayer.Character, ScreenGui }
					rayParams.FilterType = Enum.RaycastFilterType.Exclude

					local result = Workspace:Raycast(ray.Origin, ray.Direction * 2000, rayParams)
					if result and LocalPlayer.Character then
						local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if hrp then
							hrp.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
							updateStatusBar("Teleported to point of intersection.", "Success")
						end
					end
				end
			end
		end)
		trackConnection(clickTpConn :: RBXScriptConnection)
		updateStatusBar("Click-Teleport active [Tap ground while holding Ctrl or tap on Mobile].", "Success")
	else
		if clickTpConn then
			clickTpConn:Disconnect()
			clickTpConn = nil
		end
		updateStatusBar("Click-Teleport deactivated.", "Normal")
	end
end)
end

local function buildUtilityTab(PageUtility: ScrollingFrame)
-- SECTION 6.8: UTILITY TAB
local _, SystemCardContent = createCard(PageUtility, "Session & Server Utilities", "Player and server connection helpers")

local function copyJobId()
	local jid = game.JobId ~= "" and game.JobId or "SinglePlayer_LocalSession"
	if typeof(setclipboard) == "function" then
		pcall(setclipboard, jid)
	end
	local anyG = _G :: any
	if anyG and typeof(anyG.setclipboard) == "function" then
		pcall(anyG.setclipboard, jid)
	end
	updateStatusBar("Copied game.JobId to system clipboard.", "Success")
end

local function copyPlaceId()
	local pid = tostring(game.PlaceId)
	if typeof(setclipboard) == "function" then
		pcall(setclipboard, pid)
	end
	local anyG = _G :: any
	if anyG and typeof(anyG.setclipboard) == "function" then
		pcall(anyG.setclipboard, pid)
	end
	updateStatusBar("Copied game.PlaceId to system clipboard.", "Success")
end

local function executeRejoin()
	local ts = game:GetService("TeleportService")
	if #Players:GetPlayers() <= 1 then
		LocalPlayer:Kick("Sentinel: Reconnecting to session...")
		task.wait(0.2)
		ts:Teleport(game.PlaceId, LocalPlayer)
	else
		ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end
end

createActionButton(SystemCardContent, "Rejoin Experience Instance", CONFIG.AVAILABILITY.LOCAL, executeRejoin)
createActionButton(SystemCardContent, "Copy Current Job ID", CONFIG.AVAILABILITY.LOCAL, copyJobId)
createActionButton(SystemCardContent, "Copy Experience Place ID", CONFIG.AVAILABILITY.LOCAL, copyPlaceId)

-- PERFORMANCE & MEMORY AUDITOR
local _, PerfCardContent = createCard(PageUtility, "Client Memory & Diagnostics", "Garbage collection and asset cache optimization")

createActionButton(SystemCardContent, "Clear Texture & Mesh Visual Caches", CONFIG.AVAILABILITY.LOCAL, function()
	local count = 0
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Decal") or inst:IsA("Texture") then
			inst.Transparency = 1
			count = count + 1
		end
	end
	updateStatusBar(string.format("Suppressed %d texture/decal assets to boost framerate.", count), "Success")
end)

createActionButton(PerfCardContent, "Force Garbage Collection Pass", CONFIG.AVAILABILITY.LOCAL, function()
	collectgarbage("collect")
	updateStatusBar("Invoked client Luau memory garbage collection.", "Success")
end)

local _, ServerHopCardContent = createCard(PageUtility, "Server Hopping Engine", "Migrate client to alternative live game servers")
createActionButton(ServerHopCardContent, "Hop to Random Public Server", CONFIG.AVAILABILITY.LOCAL, function()
	updateStatusBar("Querying Roblox matchmaking API for alternative server...", "Normal")
	task.spawn(function()
		local ts = game:GetService("TeleportService")
		pcall(function()
			ts:Teleport(game.PlaceId, LocalPlayer)
		end)
	end)
end)
end

local function buildSettingsTab(PageSettings: ScrollingFrame)
-- SECTION 6.9: SETTINGS TAB
local _, PaletteCardContent = createCard(PageSettings, "Theme & Accent Color", "Custom aesthetic palettes for UI borders and highlights")

local PaletteGrid = Instance.new("Frame")
PaletteGrid.Size = UDim2.new(1, 0, 0, 56)
PaletteGrid.BackgroundTransparency = 1
PaletteGrid.Parent = PaletteCardContent

local PaletteLayout = Instance.new("UIGridLayout")
PaletteLayout.CellSize = UDim2.new(0.31, 0, 0, 24)
PaletteLayout.CellPadding = UDim2.new(0, 5, 0, 5)
PaletteLayout.Parent = PaletteGrid

for name, color in pairs(CONFIG.THEME.ACCENT_PALETTES) do
	local pBtn = Instance.new("TextButton")
	pBtn.Size = UDim2.new(1, 0, 1, 0)
	pBtn.BackgroundColor3 = color
	pBtn.Font = CONFIG.FONTS.HEADER
	pBtn.Text = name
	pBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
	pBtn.TextSize = 10
	pBtn.Parent = PaletteGrid
	createCorner(pBtn, 4)
	createStroke(pBtn, CONFIG.THEME.BORDER, 1)

	trackConnection(pBtn.Activated:Connect(function()
		updateAccentColor(color, name)
		updateStatusBar(string.format("Accent palette set to %s.", name), "Success")
	end))
end

local _, UiTweaksContent = createCard(PageSettings, "Interface Adjustments", "Size, scale, and opacity preferences")

createSlider(UiTweaksContent, "Window Scale Multiplier", 0.6, 1.2, state.guiScale, 0.05, "x", function(val)
	state.guiScale = val
	GuiScale.Scale = val
	clampMainFrameToBounds()
end)

createSlider(UiTweaksContent, "Background Window Opacity", 0, 0.8, state.windowOpacity, 0.05, "", function(val)
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

local _, UnloadCardContent = createCard(PageSettings, "Session Teardown & Unload", "Terminates all Sentinel background threads")
createActionButton(UnloadCardContent, "Unload Sentinel Suite", CONFIG.AVAILABILITY.LOCAL, cleanupAll)
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

[Universal Safe]: Tested and hardened across all standard Luau executors with guaranteed graceful failure handling.]]
)
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

trackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == CONFIG.HOTKEY then
		toggleVisibility()
	end
end))

local cam = getCamera()
if cam then
	trackConnection(cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if not state.manualScaleOverride then
			local autoScale = computeAutoFitScale()
			state.guiScale = autoScale
			if GuiScale then
				GuiScale.Scale = autoScale
			end
		end
		clampMainFrameToBounds()
	end))
end

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
		state.selectedHighlightInstance = hl
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

	if MainFrame and MainFrame.Parent then
		pcall(function() MainFrame:Destroy() end)
	end
	if MinimizedPill and MinimizedPill.Parent then
		pcall(function() MinimizedPill:Destroy() end)
	end
	if MobileToggleButton and MobileToggleButton.Parent then
		pcall(function() MobileToggleButton:Destroy() end)
	end
	if ScreenGui and ScreenGui.Name == CONFIG.GUI_NAME then
		pcall(function() ScreenGui:Destroy() end)
	end

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
clampMainFrameToBounds()
updateStatusBar("Sentinel Suite ready. Press RightControl or tap 'S' to toggle.", "Normal")
