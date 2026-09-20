--[[
	NEXUSPLAY HUB UI LIBRARY
	-------------------
	A standalone Roblox UI library. Drop this file on GitHub and load it with:

		local NexusPlayHub = loadstring(game:HttpGet(
			"https://raw.githubusercontent.com/soseb928/nexus-hub/refs/heads/main/NexusPlay_UI_Library.lua?v=" .. tostring(tick()),
			true
		))()

		local ui = NexusPlayHub:CreateWindow({
			welcome  = "WELCOME BACK",
			subtitle = "Thank you for using our services.",
			folder   = "NexusPlayHub",
			toggleKey = "RightShift",
			autoload = true,
		})

	This file contains the library ONLY - no example tabs are built, nothing is
	shown until you call CreateWindow. The library contains only the UI implementation; the hub core supplies the tabs and controls.

	STRUCTURE RULE:
		WINDOW  holds TABS
		TAB     holds SECTIONS
		SECTION holds CONTROLS (button, toggle, slider, dropdown, ...)

	Running the library twice never duplicates the UI - the old screen is
	removed automatically.
]]


local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

--=====================================================
--  1) IMAGE IDS - REPLACE THESE WITH YOUR OWN
--=====================================================
local IMAGES = {
	Background  = "2151741365", -- fills the entire panel behind everything
	Logo        = "116677845668287", -- "NEXUSPLAY" logo, top-left
	Banner      = "132582095265277", -- big PREMIUM+ / V4.0 artwork on the Home page
	Discord     = "16171891828",     -- social button 1 (Discord)
	YouTube     = "16171897995",      -- social button 2 (YouTube)
	Card1Icon   = "87628150067132", -- Home card 1
	Card2Icon   = "87628150067132", -- Home card 2
	Card3Icon   = "87628150067132", -- Home card 3
	TabIcon     = "87628150067132", -- default icon for a tab with no image set
	SearchIcon  = "118685771787843", -- the magnifier icon inside the search bar
	BackIcon    = "72257591594286",  -- the GO BACK button on the right of the search bar
	MiniIcon    = "134473690393403", -- the round HIDE / OPEN icon floating on the left of the screen
	CloseIcon   = "",               -- X button of the info popup. leave empty to use a text X
	NotifyIcon  = "",               -- leave empty -> every notification uses the LOGO above
}

-- SOCIAL ICON SIZE
-- every social icon is forced into the EXACT same square, so the size of the
-- uploaded image (big, small, wide, tall) makes no difference at all.
local SOCIAL_ICON_SCALE = 1      -- 1 = fills the whole square, lower = padding

-- how the artwork is placed inside that square:
--   "fill" -> stretched to fill it. every icon ends up EXACTLY the same size
--   "crop" -> zoomed in and cropped. same size, keeps the shape, cuts edges
--   "fit"  -> shrunk to fit. keeps the shape, wide logos look smaller
local SOCIAL_ICON_MODE = "fill"

-- per icon fine tuning, only if one artwork has extra empty space baked in
local SOCIAL_ICON_TWEAK = {
	Discord = 1,
	YouTube = 1,
}

-- SOCIAL LOGOS WITHOUT AN IMAGE ID
-- true  -> the icon is DRAWN with code (no upload, cannot get banned)
-- false -> the icon uses the image id from the IMAGES table (default now)
local YOUTUBE_DRAWN = true   -- youtube is DRAWN with code, no image id used
local YOUTUBE_COLOR = Color3.fromRGB(255, 0, 0)

local DISCORD_DRAWN = false  -- discord uses IMAGES.Discord
local DISCORD_COLOR = Color3.fromRGB(88, 101, 242)   -- discord blurple
local DISCORD_FACE  = Color3.fromRGB(255, 255, 255)  -- the two eyes

-- RED EFFECT ON TOP OF AN ICON
-- SOCIAL_TINT_COLOR   = paints the image itself in this color
-- SOCIAL_TINT_OVERLAY = 0 no red layer on top, 1 fully red layer on top
local SOCIAL_TINT_COLOR = {
	Discord = nil,  -- no red effect, the discord image keeps its own colors
	YouTube = nil,
}
local SOCIAL_TINT_OVERLAY = {
	Discord = 0,    -- 0 = no red layer on top
	YouTube = 0,
}

-- CREDITS PAGE PROFILE
local CREDITS = {
	Avatar    = "127399664303671", -- the logo shown inside the circle
	Name      = "NexusPlay",
	NameFont  = Enum.Font.Michroma, -- stylish font. try SciFi, Bangers, LuckiestGuy, Orbitron
	NameSize  = 40,
	Role      = "OWNER  •  DEVELOPER  •  DESIGNER",
	AvatarBox = 148,  -- size of the round profile picture
	LaserSpeed = 2.2, -- seconds for one full spin. lower = faster laser
	Lines = {
		"Founder and lead developer of NexusPlay Hub.",
		"Every line of this UI was written from scratch.",
		"",
		"Thanks to everyone testing, reporting bugs",
		"and keeping this project alive every day.",
		"",
		"Join the Discord for updates, support",
		"and early access to new features.",
	},
}

-- 0 = background image fully visible, 1 = fully hidden.
local BACKGROUND_TRANSPARENCY = 0

-- set to true to bring the live size tuner window back
local SHOW_TUNER = false

-- polished / silver / laser look on every outline. false = flat accent colour.
local LASER_OUTLINE = true

-- how much every soft outline fades out (erases) at its ends.
-- 0 = a solid line all the way round, 1 = almost gone at the ends.
local OUTLINE_ERASE = 0.5

-- buttons / switches / sliders use a FLAT outline with no shine at all.
-- some of them fade away a little at the TOP RIGHT corner only.
-- these three numbers are live-editable with the FADE TUNER on the right.
local STROKE_FADE = {
	Amount   = 0.70, -- how transparent the corner gets (0 = solid, 1 = gone)
	Position = 1.00, -- where the fade sits along the outline (0 - 1)
	Size     = 1.00, -- how long the fade runs before it reaches Amount
}

-- the tuner panel is off now that the numbers above are baked in.
-- set it back to true if you ever want to try new numbers live.
local SHOW_STROKE_TUNER = false

-- your tuned colours are baked in now, so the panel is off.
-- set it back to true if you ever want to try new colours live.
local SHOW_COLOR_TUNER = false

-- your box numbers are baked in now, so the panel is off.
-- set it back to true if you ever want to resize the box live again.
local SHOW_BOX_TUNER = false

-- social icons: true = plain icons only (no box), like the reference image
-- THE 2 SOCIAL LINKS ON THE FRONT PAGE. change them to your own any time.
local SOCIAL_LINKS = {
	Discord = "",
	YouTube = "",
}

-- how big the icon pops when your mouse is over it, and how fast
local SOCIAL_HOVER_SCALE = 1.45
local SOCIAL_HOVER_TIME  = 0.22

local SOCIAL_PLAIN = true
-- true = paint the social icons in the theme colour, false = keep the raw image
local SOCIAL_TINT  = false

-- tab hover / click highlight
local HOVER_ENABLED  = true
local HOVER_SPEED    = 0.25 -- seconds of the smooth fade
local HOVER_STRENGTH = 0.88 -- 1 = invisible, 0.80 = stronger glow
local CLICK_SPEED    = 0.45 -- seconds of the click ripple

-- how many tabs the FRONT PAGE can hold. the reference design fits 3
local MAX_HOME_TABS = 3

-- true = the go back button is always on screen (easier to find).
-- false = it only appears once you are inside a tab's sections.
local BACK_ALWAYS_VISIBLE = true

-- text drawn on the go back button when IMAGES.BackIcon is empty
local BACK_FALLBACK_TEXT = "<"

--=====================================================
--  DEVICE SCALING (PC / phone / iPad / Android)
--=====================================================
local UI_SIZE     = 0.72 -- overall size. 1 = original, lower = smaller everywhere
local SCREEN_FILL = 0.80 -- most of the screen the panel may take up
local MIN_SCALE   = 0.40
local MAX_SCALE   = 1.00

--=====================================================
--  2) TEXT - EDIT EVERY WORD HERE
--=====================================================
local TEXT = {
	Welcome  = 'Welcome back to <font color="rgb(255,0,0)">NEXUSPLAY HUB</font>',
	-- keep each line SHORT so it never wraps. 5 lines fits this box perfectly.
	Subtitle = table.concat({
		"Fast, clean and always up to date.",
		"Tabs hold sections, sections hold controls.",
		"Save configs and autoload your favourite.",
		"Works on PC, phone and every executor.",
		"Press RightShift to hide the panel.",
	}, "\n"),

	Nav = { "Home", "Pages", "Credits" }, -- order shown left to right
	ActiveNav = 1,                        -- page shown when the UI opens

	ArrowCount = 5,
	Arrow = ">>",

	Cards = {
		{ title = "Settings", desc = "Configure the script before starting your hands-free journey." },
		{ title = "Misc",     desc = "Cool features such as ESP or Teleport." },
		{ title = "Settings", desc = "Personalize your favourite script hub however you like." },
	},

	Credits = "NEXUSPLAY HUB\n\nPut your credits here.",
}

--=====================================================
--  3) THEME - EDIT EVERY COLOUR HERE
--=====================================================
local THEME = {
	Panel       = Color3.fromRGB(0, 0, 0),       -- PURE BLACK
	Card        = Color3.fromRGB(0, 0, 0),       -- PURE BLACK
	TabCard     = Color3.fromRGB(0, 0, 0),       -- PURE BLACK
	Accent      = Color3.fromRGB(255, 0, 0),     -- PURE RED. change this one for a new theme colour
	AccentDark  = Color3.fromRGB(120, 0, 0),
	Text        = Color3.fromRGB(245, 245, 248),
	SubText     = Color3.fromRGB(178, 178, 188),
	NavIdle     = Color3.fromRGB(150, 150, 160),
	Stroke      = Color3.fromRGB(74, 36, 36),
	SocialBox   = Color3.fromRGB(0, 0, 0),       -- PURE BLACK
	TunerBg     = Color3.fromRGB(0, 0, 0),       -- PURE BLACK
	TunerField  = Color3.fromRGB(0, 0, 0),       -- PURE BLACK
	SearchBar   = Color3.fromRGB(0, 0, 0),       -- PURE BLACK search bar fill
	DescPill    = Color3.fromRGB(24, 24, 24),    -- soft black behind a tab description, so the pill is visible
	LaserShine  = Color3.fromRGB(255, 228, 228), -- bright silver shine in an outline
	ControlAccent = Color3.fromRGB(228, 44, 44),  -- outline on buttons / switches / sliders
	ControlText = Color3.fromRGB(228, 10, 10),    -- button text, switch tick, slider bar. your tuned match
	LaserSoft   = Color3.fromRGB(150, 18, 18),   -- dim, NO shine. used on the control outlines
	LaserEdge   = Color3.fromRGB(140, 0, 0),     -- deep end of an outline
}

--=====================================================
--  4) LAYOUT - EDIT EVERY SIZE HERE
--=====================================================
local LAYOUT = {
	GAP            = 18,

	PanelWidth     = 1010, -- panel height is calculated, not set
	PanelPadding   = 26,
	PanelPaddingX  = 38,

	HeaderHeight   = 62,
	LogoWidth      = 210,
	LogoHeight     = 86,

	ArrowSize      = 36,  -- size of one >> arrow box
	ArrowText      = 26,  -- font size of the >> arrows
	ArrowGap       = 14,  -- space between the arrows
	ArrowOffsetX   = 70,  -- push the whole arrow row to the right

	HeroHeight     = 330,
	HeroLeftWidth  = 0.40,
	BannerWidth    = 0.60,
	BannerHeight   = 344,
	BannerOffsetY  = -16,

	-- SOCIAL ICON SIZE: this is the ONE number to change.
	-- 34 = tiny, 42 = small, 56 = medium, 68 = big, 80 = very big
	SocialBox      = 62,
	SocialGap      = 28,  -- space between the two icons
	SocialOffsetY  = 56,  -- push the 3 social icons down

	CardsHeight    = 134,
	CardGap        = 18,
	CardPad        = 16,
	CardIcon       = 98,

	-- Pages page (the tab list)
	TabColumns     = 2,   -- tabs per row  ->  Tab | Tab
	TabHeight      = 144, -- height of one tab card
	TabGap         = 16,  -- space between tab cards
	TabPad         = 16,  -- inner padding of a tab card
	TabIcon        = 108, -- tab image size
	TabTitle       = 38,  -- height of the big tab title
	TabDescHeight  = 42,  -- height of the description background pill
	TabDivider     = 0,   -- line between the columns. 0 = no line, 2 = thin line
	TabScrollPad   = 10,  -- space kept on the right for the scrollbar

	SearchHeight   = 52,  -- height of the search bar
	SearchIcon     = 28,  -- size of the search icon
	SearchGap      = 14,  -- extra space between the search bar and the first tab row
	BackButton     = 58,  -- width of the go back button, right of the search bar
	BackGap        = 12,  -- space between the search bar and the go back button

	-- SWITCHES / BUTTONS / SLIDERS (they live in a rounded box)
	ControlColumns = 2,   -- button | button
	ControlHeight  = 50,  -- height of a button and of a switch
	SliderHeight   = 70,  -- sliders need more room for the bar
	ControlGap     = 12,  -- space between two controls
	ControlBoxPad  = 30,  -- padding inside the rounded box
	ControlBoxHeight = 430, -- base height of the box
	ControlBoxScale = 0.85, -- size multiplier for the box. bigger number = bigger box
	PanelExtraHeight = 0, -- extra height added to the WHOLE panel, so the box can grow further DOWN
	ToggleBox      = 26,  -- the little square of a switch

	-- COMBO BUTTONS (many small buttons packed in a grid)
	ComboColumns   = 3,   -- how many small buttons fit on one line
	ComboHeight    = 32,  -- height of one small button
	ComboGap       = 7,   -- space between the small buttons
	ComboText      = 15,  -- biggest text size on a small button (long names shrink)
	ComboTitle     = 26,  -- height of the title above the grid

	-- ROUND HIDE / OPEN ICON (floats on the screen, not inside the panel)
	MiniSize       = 62,  -- diameter of the round icon
	MiniStroke     = 1.8,   -- thickness of its red outline
	MiniPosX       = 0.06, -- 0 = far left edge, 1 = far right edge
	MiniPosY       = 0.38, -- 0.5 = middle of the screen, lower number = higher up

	-- NOTIFICATIONS (they stack in the bottom right corner)
	NotifyWidth    = 330, -- width of one notification
	NotifyHeight   = 66,  -- height of one notification
	NotifyIcon     = 44,  -- size of the image box inside a notification
	NotifyIconZoom = 0.72, -- zoom of the image. lower = more zoomed OUT / smaller
	NotifyPad      = 12,  -- padding inside a notification
	NotifyGap      = 10,  -- space between two stacked notifications
	NotifyTime     = 4,   -- seconds a notification stays on screen
	NotifyText     = 15,  -- text size inside a notification
	NotifyFade     = 0.20, -- 0 = solid black, 1 = invisible. background see through
	NotifyStroke   = 1.2,  -- thickness of the red outline

	-- INFO POPUP (the black window with the red outline)
	InfoWidth      = 540, -- width of the popup
	InfoHeight     = 400, -- height of the popup
	InfoPad        = 20,  -- padding inside the popup
	InfoTitle      = 22,  -- title text size
	InfoText       = 16,  -- normal text size
	InfoBigText    = 24,  -- size used for **big words**
	InfoClose      = 34,  -- size of the X close button
}

local function img(id)
	if id == nil or id == false or id == "" then return "" end
	if type(id) == "number" then return "rbxassetid://" .. tostring(math.floor(id)) end
	id = tostring(id)
	if id:match("^%d+$") then return "rbxassetid://" .. id end
	return id
end

-- ICON PICKER: every card (tab, section, home card) accepts the icon under
-- any of these names ->  image / icon / imageId / iconId / imageID / iconID
-- pass "" or false to hide the icon, pass nothing to use the default one.
local function pickIcon(info, fallback)
	info = info or {}
	local id = info.image
	if id == nil then id = info.icon end
	if id == nil then id = info.imageId end
	if id == nil then id = info.iconId end
	if id == nil then id = info.imageID end
	if id == nil then id = info.iconID end
	if id == nil then return fallback end
	return id
end

--=====================================================
--  HELPERS
--=====================================================
local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color, thickness, transparency)
	local s = new("UIStroke", {
		Color = color or THEME.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	-- POLISHED / SILVER / LASER EFFECT on every purple outline
	if LASER_OUTLINE and (color == nil or color == THEME.Accent) then
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, THEME.LaserEdge),
				ColorSequenceKeypoint.new(0.18, THEME.Accent),
				ColorSequenceKeypoint.new(0.35, THEME.LaserShine),
				ColorSequenceKeypoint.new(0.50, THEME.Accent),
				ColorSequenceKeypoint.new(0.65, THEME.LaserShine),
				ColorSequenceKeypoint.new(0.82, THEME.Accent),
				ColorSequenceKeypoint.new(1.00, THEME.LaserEdge),
			}),
			Rotation = 35,
			Parent = s,
		})
	end

	return s
end

-- a calmer outline: same laser colours but much less shiny, plus a soft
-- "erased" fade so the line quietly disappears at both ends.
-- used on the control box and on every button / switch / slider.
local function softStroke(color, thickness, transparency, erase)
	local s = stroke(color, thickness, transparency)
	erase = erase or OUTLINE_ERASE

	local g = s:FindFirstChildOfClass("UIGradient")
	if not g then
		g = new("UIGradient", { Rotation = 35, Parent = s })
	end

	-- NO shine at all here: just a dim, even line that darkens at the ends
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, THEME.LaserEdge),
		ColorSequenceKeypoint.new(0.50, THEME.LaserSoft),
		ColorSequenceKeypoint.new(1.00, THEME.LaserEdge),
	})

	-- the erase effect: the outline fades out near the ends
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, erase),
		NumberSequenceKeypoint.new(0.20, 0),
		NumberSequenceKeypoint.new(0.80, 0),
		NumberSequenceKeypoint.new(1.00, erase),
	})

	return s
end

-- the outline used by BUTTONS, SWITCHES and SLIDERS.
-- absolutely no shine, one flat colour, and the line simply fades
-- away at the TOP RIGHT corner. tabs keep their own polished look.
local FADED_STROKES = {}

-- every control outline and every coloured control part is remembered here,
-- so the COLOR TUNER can recolour all of them live.
local CONTROL_STROKES = {}
local CONTROL_PARTS = {}

local function controlPart(inst, prop)
	table.insert(CONTROL_PARTS, { inst = inst, prop = prop })
	return inst
end

local function refreshControlColors()
	for _, e in ipairs(CONTROL_STROKES) do
		if e.stroke and e.stroke.Parent then
			e.stroke.Color = THEME.ControlAccent
			if e.grad then
				e.grad.Color = ColorSequence.new(THEME.ControlAccent)
			end
		end
	end
	for _, e in ipairs(CONTROL_PARTS) do
		if e.inst and e.inst.Parent then
			e.inst[e.prop] = THEME.ControlText
		end
	end
end

local function fadeSequence()
	local amount = math.clamp(tonumber(STROKE_FADE.Amount) or 0, 0, 1)
	local pos    = math.clamp(tonumber(STROKE_FADE.Position) or 0.8, 0.05, 0.99)
	local size   = math.clamp(tonumber(STROKE_FADE.Size) or 0.2, 0.01, 0.9)
	local startAt = math.clamp(pos - size, 0.01, pos - 0.01)

	return NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0),
		NumberSequenceKeypoint.new(startAt, 0),
		NumberSequenceKeypoint.new(pos, amount),
		NumberSequenceKeypoint.new(1.00, amount),
	})
end

local function refreshStrokeFade()
	local seq = fadeSequence()
	for _, g in ipairs(FADED_STROKES) do
		if g and g.Parent then
			g.Transparency = seq
		end
	end
end

-- fade = false  ->  a solid line all the way round, no transparency at all
-- fade = true   ->  the line fades a little into the TOP RIGHT corner
local function plainStroke(color, thickness, transparency, fade)
	local c = color or THEME.ControlAccent

	local s = new("UIStroke", {
		Color = c,
		Thickness = thickness or 1.4,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})

	local g = new("UIGradient", {
		Color = ColorSequence.new(c), -- flat: no silver, no laser, no glint
		Rotation = -45, -- the fade runs into the TOP RIGHT corner
		Parent = s,
	})

	if fade == false then
		g.Transparency = NumberSequence.new(0)
	else
		table.insert(FADED_STROKES, g)
		g.Transparency = fadeSequence()
	end

	table.insert(CONTROL_STROKES, { stroke = s, grad = g })

	return s
end

local function gradient(c1, c2, rot)
	return new("UIGradient", {
		Color = ColorSequence.new(c1, c2),
		Rotation = rot or 0,
	})
end

local function padding(t, r, b, l)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or 0),
		PaddingBottom = UDim.new(0, b or 0),
		PaddingLeft = UDim.new(0, l or 0),
	})
end

--=====================================================
--  SLIDE ANIMATION
--  going INSIDE  -> the new view slides in from the RIGHT  ->
--  going BACK    -> the new view slides in from the LEFT   <-
--=====================================================
local SLIDE_TIME = 0.22 -- seconds. bigger = slower slide
local SLIDE_PUSH = 0.30 -- how far it starts off screen. bigger = longer travel

--=====================================================
--  OPEN / HIDE ANIMATION (the round mini icon)
--  open  = small  ->  big
--  hide  = shrink ->  vanish
--=====================================================
local OPEN_TIME  = 0.45 -- how long the grow / shrink takes (seconds)
local OPEN_START = 0.02 -- opens from the size of a dot and grows to full size
local HIDE_END   = 0.02 -- shrinks all the way down to a dot before it vanishes

-- SMOOTH FEEL
local DRAG_SMOOTH   = 0.09 -- how much the panel lags behind your finger while dragging
                           -- 0 = glued to the cursor, bigger = softer / floatier
local TOGGLE_SMOOTH = 0.22 -- how slow and soft a switch turns on / off

local function slideIn(frame, forward)
	if not frame then return end

	-- remember where the frame is supposed to rest
	local home = frame:GetAttribute("SlideHome")
	if typeof(home) ~= "UDim2" then
		home = frame.Position
		frame:SetAttribute("SlideHome", home)
	end

	frame.Position = home
	frame.Visible = true

	if SLIDE_TIME <= 0 then return end

	local dir = (forward == false) and -1 or 1
	frame.Position = home + UDim2.fromScale(SLIDE_PUSH * dir, 0)
	TweenService:Create(
		frame,
		TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = home }
	):Play()
end

local function vlist(gap, align)
	return new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap or 0),
	})
end

local function hlist(gap, align)
	return new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, gap or 0),
	})
end

local function clampText(maxSize)
	return new("UITextSizeConstraint", {
		MaxTextSize = maxSize,
		MinTextSize = 8,
	})
end

-- soft blend between two positions (used by the smooth drag)
local function lerpUDim2(a, b, t)
	return UDim2.new(
		a.X.Scale + (b.X.Scale - a.X.Scale) * t,
		a.X.Offset + (b.X.Offset - a.X.Offset) * t,
		a.Y.Scale + (b.Y.Scale - a.Y.Scale) * t,
		a.Y.Offset + (b.Y.Offset - a.Y.Offset) * t
	)
end

-- DRAGGING WITH A SMOOTH DELAY.
-- your finger sets a target, and the panel glides towards it every frame
-- instead of snapping, so the movement feels soft and expensive.
local function makeDraggable(frame, handle)
	local dragging, dragStart, startPos
	local target = frame.Position
	local loop = nil
	handle = handle or frame

	local function stopLoop()
		if loop then
			loop:Disconnect()
			loop = nil
		end
	end

	local function startLoop()
		if loop then return end
		loop = RunService.RenderStepped:Connect(function(dt)
			if not frame.Parent then
				stopLoop()
				return
			end

			local smooth = math.max(DRAG_SMOOTH, 0.0001)
			local alpha = 1 - math.exp(-dt / smooth)
			frame.Position = lerpUDim2(frame.Position, target, alpha)

			-- once it has caught up and the finger is gone, stop the loop
			if not dragging then
				local dx = math.abs(frame.Position.X.Offset - target.X.Offset)
				local dy = math.abs(frame.Position.Y.Offset - target.Y.Offset)
				if dx < 1 and dy < 1 then
					frame.Position = target
					stopLoop()
				end
			end
		end)
	end

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			target = frame.Position
			startLoop()
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - dragStart
			target = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
			startLoop()
		end
	end)
end

--=====================================================
--  LIBRARY
--=====================================================
local Library = {}
Library.__index = Library

function Library.new()
	local self = setmetatable({}, Library)

	-- RUN IT TWICE AND YOU STILL GET ONE UI:
	-- any old NexusPlayHub screen is deleted before the new one is built
	local function wipeOld(holder)
		if not holder then return end
		for _, old in ipairs(holder:GetChildren()) do
			if old:IsA("ScreenGui") and old.Name == "NexusPlayHub" then
				old:Destroy()
			end
		end
	end
	pcall(function() wipeOld(Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")) end)
	pcall(function() wipeOld(game:GetService("CoreGui")) end)
	pcall(function() if gethui then wipeOld(gethui()) end end)

	self.IconSlots   = {}
	self.TextCols    = {}
	self.SocialBoxes = {}
	self.Tabs        = {} -- every tab you add lands here
	self.PageFrames  = {}
	self.NavButtons  = {}

	self.Gui = new("ScreenGui", {
		Name = "NexusPlayHub",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
		Parent = (Players.LocalPlayer and Players.LocalPlayer:WaitForChild("PlayerGui")),
	})

	self.Main = new("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(LAYOUT.PanelWidth, 575),
		BackgroundColor3 = THEME.Panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Active = true,
		Parent = self.Gui,
	}, {
		corner(26),
		stroke(THEME.Accent, 2.5, 0.1),
		new("UIScale", { Name = "Scale" }),
	})

	self.Background = new("ImageLabel", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = img(IMAGES.Background),
		ImageTransparency = BACKGROUND_TRANSPARENCY,
		ScaleType = Enum.ScaleType.Crop,
		Parent = self.Main,
	}, { corner(26) })

	self.Body = new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.Main,
	}, {
		padding(LAYOUT.PanelPadding, LAYOUT.PanelPaddingX, LAYOUT.PanelPadding, LAYOUT.PanelPaddingX),
	})

	-- everything below the header lives in here, one frame per page
	self.Content = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(0, LAYOUT.HeaderHeight + LAYOUT.GAP),
		Size = UDim2.new(1, 0, 1, -(LAYOUT.HeaderHeight + LAYOUT.GAP)),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self.Body,
	})

	self:_buildHeader()
	self:_buildHomePage()
	self:_buildTabsPage()
	self:_buildCreditsPage()
	self:_applyLayout()
	self:SelectPage(TEXT.Nav[TEXT.ActiveNav] or "Home")
	makeDraggable(self.Main)

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:_fitToScreen()
		end)
	end

	if SHOW_TUNER then
		self:_buildTuner()
	end

	if SHOW_STROKE_TUNER then
		self:_buildStrokeTuner()
	end

	if SHOW_COLOR_TUNER then
		self:_buildColorTuner()
	end

	if SHOW_BOX_TUNER then
		self:_buildBoxTuner()
	end

	-- the round HIDE / OPEN icon on the left of the screen
	self:_buildMiniIcon()

	return self
end

--=====================================================
--  ROUND HIDE / OPEN ICON
--  it lives on the ScreenGui, NOT inside the panel, so it stays
--  on screen while the panel is hidden.
--  position, size and image all come from LAYOUT / IMAGES.
--=====================================================
function Library:_buildMiniIcon()
	local size = LAYOUT.MiniSize

	local shell = new("Frame", {
		Name = "MiniIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(LAYOUT.MiniPosX, LAYOUT.MiniPosY),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 50,
		Parent = self.Gui,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }), -- perfect circle
		new("UIStroke", {
			Color = THEME.Accent,
			Thickness = LAYOUT.MiniStroke,
			Transparency = 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})

	-- RULE: the image is never tinted, and it fills the whole circle
	local icon = new("ImageLabel", {
		Name = "Icon",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = img(IMAGES.MiniIcon),
		ScaleType = Enum.ScaleType.Crop,
		ZIndex = 51,
		Parent = shell,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	-- if no image id is set yet you still see a clear round button
	local fallback = new("TextLabel", {
		Name = "Fallback",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "H",
		TextSize = math.floor(size * 0.45),
		TextColor3 = THEME.Accent,
		Visible = (icon.Image == ""),
		ZIndex = 52,
		Parent = shell,
	})

	local hit = new("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 55,
		Parent = shell,
	})

	hit.MouseButton1Click:Connect(function()
		self:Toggle()
	end)

	-- LASER / SHINE on the round outline: a bright band keeps sweeping
	-- around the ring so the little button never looks flat
	local ring = shell:FindFirstChildOfClass("UIStroke")
	if ring then
		local shine = new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, THEME.AccentDark),
				ColorSequenceKeypoint.new(0.35, THEME.Accent),
				ColorSequenceKeypoint.new(0.50, THEME.LaserShine),
				ColorSequenceKeypoint.new(0.65, THEME.Accent),
				ColorSequenceKeypoint.new(1.00, THEME.AccentDark),
			}),
			Rotation = 0,
			Parent = ring,
		})

		task.spawn(function()
			while shine.Parent do
				TweenService:Create(
					shine,
					TweenInfo.new(2.4, Enum.EasingStyle.Linear),
					{ Rotation = 360 }
				):Play()
				task.wait(2.4)
				if not shine.Parent then break end
				shine.Rotation = 0
			end
		end)
	end

	-- you can drag the icon anywhere you like
	makeDraggable(shell, hit)

	self.MiniIcon = shell
	self.MiniImage = icon
	self.MiniFallback = fallback
	return shell
end

-- hide / show the whole panel WITH the pop animation.
-- pass true as the second argument if you ever want it to snap instantly.
function Library:SetVisible(state, instant)
	if not self.Main then return end
	state = state and true or false
	self.Shown = state

	local scaleObj = self.Main:FindFirstChild("Scale")
	local base = self.BaseScale or (scaleObj and scaleObj.Scale) or 1

	if (not scaleObj) or instant then
		self.Main.Visible = state
		if scaleObj then scaleObj.Scale = base end
		self.Animating = false
		return
	end

	-- EVERY animation gets its own ticket number. cancelling a tween still
	-- fires its Completed event, and the old finisher used to slam the scale
	-- back to full size - that is why the open animation looked like it did
	-- nothing at all. now an old ticket simply gets ignored.
	self.AnimToken = (self.AnimToken or 0) + 1
	local token = self.AnimToken

	if self.OpenTween then
		pcall(function() self.OpenTween:Cancel() end)
		self.OpenTween = nil
	end

	self.Animating = true

	if state then
		-- OPEN: from the size of a dot, grow out to full size
		self.Main.Visible = true
		scaleObj.Scale = base * OPEN_START

		local tween = TweenService:Create(
			scaleObj,
			TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Scale = base }
		)
		self.OpenTween = tween
		tween.Completed:Connect(function()
			if token ~= self.AnimToken then return end
			self.Animating = false
			scaleObj.Scale = self.BaseScale or base
			-- the heavy measuring was frozen during the animation, catch up now
			self:_refreshControlBoxes()
		end)
		tween:Play()
	else
		-- HIDE: shrink down to a dot, then vanish
		local tween = TweenService:Create(
			scaleObj,
			TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
			{ Scale = base * HIDE_END }
		)
		self.OpenTween = tween
		tween.Completed:Connect(function()
			if token ~= self.AnimToken then return end
			self.Main.Visible = false
			scaleObj.Scale = self.BaseScale or base
			self.Animating = false
		end)
		tween:Play()
	end
end

function Library:Show() self:SetVisible(true) end
function Library:Hide() self:SetVisible(false) end

function Library:Toggle()
	if not self.Main then return end
	if self.Shown == nil then self.Shown = self.Main.Visible end
	self:SetVisible(not self.Shown)
end

-- change the round icon image at any time:  ui:SetMiniIcon("123456789")
function Library:SetMiniIcon(id)
	IMAGES.MiniIcon = id
	if self.MiniImage then
		self.MiniImage.Image = img(id)
		if self.MiniFallback then
			self.MiniFallback.Visible = (self.MiniImage.Image == "")
		end
	end
end

--=====================================================
--  NOTIFICATIONS
--  ui:Notify({ text = "Saved", image = "87628150067132", time = 4 })
--  with an image  ->  image | text
--  without one    ->  text only, using the whole width
--=====================================================
function Library:_notifyHolder()
	if self.NotifyHolder and self.NotifyHolder.Parent then
		return self.NotifyHolder
	end

	local holder = new("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.new(0, LAYOUT.NotifyWidth, 0.9, 0),
		BackgroundTransparency = 1,
		ZIndex = 80,
		Parent = self.Gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0, LAYOUT.NotifyGap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	self.NotifyHolder = holder
	return holder
end

function Library:Notify(info)
	if type(info) == "string" then info = { text = info } end
	info = info or {}

	local holder = self:_notifyHolder()
	local life = info.time or info.duration or LAYOUT.NotifyTime
	local pad = LAYOUT.NotifyPad

	-- NOTIFICATION IMAGE
	--   ui:Notify({ text = "hi", image = "1234567890" })  -> your own image id
	--   ui:Notify({ text = "hi" })                        -> falls back to the LOGO
	--   ui:Notify({ text = "hi", image = false })         -> text only, no image
	local image = pickIcon(info, nil)
	if image == nil then
		image = IMAGES.NotifyIcon
		if image == nil or image == "" then image = IMAGES.Logo end
	end
	if image == false or image == "" then image = nil end

	local card = new("Frame", {
		Name = "Notification",
		Size = UDim2.new(1, 0, 0, LAYOUT.NotifyHeight),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 81,
		Parent = holder,
	}, { corner(12) })

	local line = new("UIStroke", {
		Color = THEME.Accent,
		Thickness = LAYOUT.NotifyStroke,
		Transparency = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = card,
	})

	local icon
	local textLeft = pad

	if image then
		-- RULE 1: the image and the text never touch, there is always a gap
		-- ZOOMED OUT: Fit keeps the whole logo visible instead of cropping into
		-- it, and NotifyIconZoom shrinks it a bit inside its box.
		local zoom = LAYOUT.NotifyIconZoom or 0.72
		local iconSize = math.floor(LAYOUT.NotifyIcon * zoom)
		icon = new("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, pad + math.floor((LAYOUT.NotifyIcon - iconSize) / 2), 0.5, 0),
			Size = UDim2.fromOffset(iconSize, iconSize),
			BackgroundTransparency = 1,
			Image = img(image),
			ImageTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 82,
			Parent = card,
		}, { corner(10) })

		textLeft = pad + LAYOUT.NotifyIcon + pad
	end

	-- RULE 3: the text stays inside the card and wraps instead of spilling
	local label = new("TextLabel", {
		Name = "Text",
		Position = UDim2.fromOffset(textLeft, pad),
		Size = UDim2.new(1, -(textLeft + pad), 1, -(pad * 2)),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		RichText = true,
		Text = info.text or "",
		TextSize = LAYOUT.NotifyText,
		TextColor3 = THEME.Text,
		TextTransparency = 1,
		TextWrapped = true,
		TextXAlignment = image and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 82,
		Parent = card,
	})

	-- fade in
	local fadeIn = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(card, fadeIn, { BackgroundTransparency = LAYOUT.NotifyFade }):Play()
	TweenService:Create(line, fadeIn, { Transparency = 0 }):Play()
	TweenService:Create(label, fadeIn, { TextTransparency = 0 }):Play()
	if icon then
		TweenService:Create(icon, fadeIn, { ImageTransparency = 0 }):Play()
	end

	-- fade out and clean itself up
	task.delay(life, function()
		if not card.Parent then return end
		local out = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(card, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(line, out, { Transparency = 1 }):Play()
		TweenService:Create(label, out, { TextTransparency = 1 }):Play()
		if icon then
			TweenService:Create(icon, out, { ImageTransparency = 1 }):Play()
		end
		task.wait(0.35)
		if card then card:Destroy() end
	end)

	return card
end

--=====================================================
--  INFO POPUP
--  black window, red outline, close button.
--  **words between two stars** come out BIG, so you can
--  mark the important parts of a how to use text.
--=====================================================
local function toRichText(raw)
	raw = tostring(raw or "")

	-- rich text needs these escaped first, otherwise it breaks
	raw = raw:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")

	-- **big words**  ->  bold and bigger
	raw = raw:gsub("%*%*(.-)%*%*", function(inner)
		return string.format(
			'<b><font size="%d" color="#%s">%s</font></b>',
			LAYOUT.InfoBigText,
			string.format("%02X%02X%02X",
				math.floor(THEME.Accent.R * 255),
				math.floor(THEME.Accent.G * 255),
				math.floor(THEME.Accent.B * 255)),
			inner
		)
	end)

	return raw
end

function Library:ShowInfo(info)
	if type(info) == "string" then info = { text = info } end
	info = info or {}

	self:CloseInfo()

	-- dark sheet behind the window so the popup reads clearly
	local overlay = new("Frame", {
		Name = "InfoOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 90,
		Parent = self.Gui,
	})

	local window = new("Frame", {
		Name = "InfoWindow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(LAYOUT.InfoWidth, LAYOUT.InfoHeight),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 91,
		Parent = overlay,
	}, {
		corner(18),
		new("UIStroke", {
			Color = THEME.Accent,
			Thickness = 2.5,
			Transparency = 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})

	local pad = LAYOUT.InfoPad
	local closeSize = LAYOUT.InfoClose

	-- RULE 1 + 3: the title stops before the X, it never runs under it
	new("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(pad, pad),
		Size = UDim2.new(1, -(pad * 2 + closeSize + 12), 0, closeSize),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = info.title or "HOW TO USE",
		TextSize = LAYOUT.InfoTitle,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 92,
		Parent = window,
	})

	local close = new("ImageButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -pad, 0, pad),
		Size = UDim2.fromOffset(closeSize, closeSize),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Image = img(IMAGES.CloseIcon),
		ScaleType = Enum.ScaleType.Crop,
		AutoButtonColor = false,
		ZIndex = 93,
		Parent = window,
	}, {
		corner(10),
		new("UIStroke", {
			Color = THEME.Accent,
			Thickness = 2,
			Transparency = 0,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})

	-- if no close image id is set you still get a clear red X
	new("TextLabel", {
		Name = "X",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "X",
		TextSize = math.floor(closeSize * 0.5),
		TextColor3 = THEME.Accent,
		Visible = (close.Image == ""),
		ZIndex = 94,
		Parent = close,
	})

	local bodyTop = pad + closeSize + 14

	local scroll = new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(pad, bodyTop),
		Size = UDim2.new(1, -(pad * 2), 1, -(bodyTop + pad)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = THEME.Accent,
		ClipsDescendants = true,
		ZIndex = 92,
		Parent = window,
	})

	new("TextLabel", {
		Name = "Text",
		Size = UDim2.new(1, -10, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		RichText = true,
		Text = toRichText(info.text or info.info or ""),
		TextSize = LAYOUT.InfoText,
		TextColor3 = THEME.SubText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 93,
		Parent = scroll,
	})

	close.MouseButton1Click:Connect(function()
		self:CloseInfo()
	end)

	makeDraggable(window)

	self.InfoPopup = overlay
	return overlay
end

function Library:CloseInfo()
	if self.InfoPopup then
		self.InfoPopup:Destroy()
		self.InfoPopup = nil
	end
end

--=====================================================
--  HEADER (nav labels are clickable)
--=====================================================
function Library:_buildHeader()
	self.Header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, LAYOUT.HeaderHeight),
		BackgroundTransparency = 1,
		Parent = self.Body,
	})

	self.LeftGroup = new("Frame", {
		Name = "LeftGroup",
		Size = UDim2.new(0.60, 0, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self.Header,
	}, { hlist(LAYOUT.GAP * 2) })

	self.Logo = new("ImageLabel", {
		Name = "Logo",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(LAYOUT.LogoWidth, LAYOUT.LogoHeight),
		BackgroundTransparency = 1,
		Image = img(IMAGES.Logo),
		ScaleType = Enum.ScaleType.Stretch,
		Parent = self.LeftGroup,
	})

	local arrows = new("Frame", {
		Name = "Arrows",
		LayoutOrder = 2,
		Size = UDim2.fromOffset(
			LAYOUT.ArrowOffsetX + TEXT.ArrowCount * (LAYOUT.ArrowSize + LAYOUT.ArrowGap),
			LAYOUT.ArrowSize
		),
		BackgroundTransparency = 1,
		Parent = self.LeftGroup,
	}, {
		padding(0, 0, 0, LAYOUT.ArrowOffsetX),
		hlist(LAYOUT.ArrowGap),
	})

	for i = 1, TEXT.ArrowCount do
		new("TextLabel", {
			Name = "Arrow" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(LAYOUT.ArrowSize, LAYOUT.ArrowSize),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = TEXT.Arrow,
			TextSize = LAYOUT.ArrowText,
			TextColor3 = (i % 2 == 0) and THEME.Accent or THEME.Text,
			Parent = arrows,
		})
	end

	local nav = new("Frame", {
		Name = "Nav",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0.38, 0, 0, 32),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self.Header,
	}, { hlist(40, Enum.HorizontalAlignment.Right) })

	for i, label in ipairs(TEXT.Nav) do
		local btn = new("TextButton", {
			Name = label,
			LayoutOrder = i,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 30),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Font = Enum.Font.GothamMedium,
			Text = label,
			TextSize = 21,
			TextColor3 = THEME.NavIdle,
			Parent = nav,
		})
		btn.MouseButton1Click:Connect(function()
			self:SelectPage(label)
		end)
		self.NavButtons[label] = btn
	end
end

--=====================================================
--  PAGE SWITCHING
--=====================================================
function Library:SelectPage(name, back)
	-- work out which way the page should slide.
	-- moving forward in the nav (Home -> Pages -> Credits) slides in from the RIGHT,
	-- moving backwards slides in from the LEFT.
	local order = {}
	for i, navName in ipairs(TEXT.Nav) do order[navName] = i end

	local forward = true
	if back ~= nil then
		forward = not back
	elseif self.CurrentPage and order[name] and order[self.CurrentPage] then
		forward = order[name] >= order[self.CurrentPage]
	end

	for pageName, frame in pairs(self.PageFrames) do
		if pageName == name then
			slideIn(frame, forward)
		else
			frame.Visible = false
		end
	end
	for label, btn in pairs(self.NavButtons) do
		btn.TextColor3 = (label == name) and THEME.Accent or THEME.NavIdle
	end
	self.CurrentPage = name
end

--=====================================================
--  HOME PAGE (hero + 3 cards)
--=====================================================
function Library:_buildHomePage()
	local page = new("Frame", {
		Name = "HomePage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self.Content,
	})
	self.PageFrames[TEXT.Nav[1] or "Home"] = page

	self.Hero = new("Frame", {
		Name = "Hero",
		Size = UDim2.new(1, 0, 0, LAYOUT.HeroHeight),
		BackgroundTransparency = 1,
		Parent = page,
	})

	-- RULE 1: the -GAP keeps the text away from the banner
	self.Left = new("Frame", {
		Name = "Left",
		Size = UDim2.new(LAYOUT.HeroLeftWidth, -LAYOUT.GAP, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = self.Hero,
	}, { vlist(16) })

	new("TextLabel", {
		Name = "Welcome",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		RichText = true,
		Font = Enum.Font.GothamBold,
		Text = TEXT.Welcome,
		TextSize = 30,
		TextColor3 = THEME.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.15,
		Parent = self.Left,
	})

	new("TextLabel", {
		Name = "Subtitle",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = TEXT.Subtitle,
		TextSize = 16,
		TextColor3 = THEME.SubText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.25,
		Parent = self.Left,
	})

	self.Socials = new("Frame", {
		Name = "Socials",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, LAYOUT.SocialBox + LAYOUT.SocialOffsetY),
		BackgroundTransparency = 1,
		Parent = self.Left,
	}, {
		padding(LAYOUT.SocialOffsetY, 0, 0, 0),
		hlist(LAYOUT.SocialGap),
	})

	-- YOUTUBE LOGO DRAWN BY CODE (no image id needed, nothing to upload,
	-- nothing that can get moderated). It is a red rounded box with a white
	-- play triangle built out of small frames.
	local function drawYouTubeLogo(parent)
		-- fills the WHOLE square, exactly like an image icon does, so the drawn
		-- youtube logo ends up the exact same size as the discord image
		local body = new("Frame", {
			Name = "YTBody",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = YOUTUBE_COLOR,
			BorderSizePixel = 0,
			Parent = parent,
		}, {
			new("UICorner", { CornerRadius = UDim.new(0.24, 0) }),
		})

		-- the white play triangle, drawn row by row
		local holder = new("Frame", {
			Name = "YTPlay",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.55, 0.5),
			Size = UDim2.fromScale(0.26, 0.40),
			BackgroundTransparency = 1,
			Parent = body,
		})

		local ROWS = 28
		for r = 1, ROWS do
			local t = (r - 0.5) / ROWS                 -- 0 at the top, 1 at the bottom
			local w = 1 - math.abs(t - 0.5) * 2        -- widest in the middle
			new("Frame", {
				Name = "Row" .. r,
				Position = UDim2.fromScale(0, (r - 1) / ROWS),
				Size = UDim2.new(w, 0, 1 / ROWS, 1),   -- +1px so there are no gaps
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderSizePixel = 0,
				Parent = holder,
			})
		end

		return body
	end

	-- DISCORD LOGO DRAWN BY CODE (no image id needed either).
	-- Real clyde shape: wide rounded head on top, a flared skirt under it, two
	-- pointed horns at the bottom corners, and two white oval eyes.
	local function drawDiscordLogo(parent)
		-- everything is built inside this box so the whole logo scales together
		local body = new("Frame", {
			Name = "DCBody",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.80),
			BackgroundTransparency = 1,
			Parent = parent,
		})

		local function shape(name, x, y, w, h, radius, rot, z)
			return new("Frame", {
				Name = name,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(x, y),
				Size = UDim2.fromScale(w, h),
				Rotation = rot or 0,
				BackgroundColor3 = DISCORD_COLOR,
				BorderSizePixel = 0,
				ZIndex = z or 2,
				Parent = body,
			}, {
				new("UICorner", { CornerRadius = UDim.new(radius, 0) }),
			})
		end

		-- 1) the two pointed horns at the bottom left and bottom right
		shape("HornLeft",  0.135, 0.760, 0.30, 0.42, 0.34, -28, 2)
		shape("HornRight", 0.865, 0.760, 0.30, 0.42, 0.34,  28, 2)

		-- 2) the flared skirt that joins the horns to the head
		shape("Skirt", 0.5, 0.660, 0.80, 0.40, 0.30, 0, 3)

		-- 3) the wide rounded head on top
		shape("Head", 0.5, 0.420, 0.90, 0.66, 0.50, 0, 4)

		-- 4) fills the small dip between the head and the skirt
		shape("Neck", 0.5, 0.560, 0.86, 0.30, 0.18, 0, 5)

		-- 5) the two white oval eyes, always on top
		for _, side in ipairs({ -1, 1 }) do
			new("Frame", {
				Name = side < 0 and "EyeLeft" or "EyeRight",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5 + side * 0.175, 0.470),
				Size = UDim2.fromScale(0.145, 0.235),
				BackgroundColor3 = DISCORD_FACE,
				BorderSizePixel = 0,
				ZIndex = 9,
				Parent = body,
			}, {
				new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			})
		end

		return body
	end

	-- ONLY 2 SOCIAL BUTTONS NOW: DISCORD AND YOUTUBE.
	-- click = the link is copied to your clipboard AND opened for you.
	-- draw = built with code instead of an image id.
	local socialItems = {
		{ name = "Discord", id = IMAGES.Discord, link = SOCIAL_LINKS.Discord,
		  draw = DISCORD_DRAWN and drawDiscordLogo or nil },
		{ name = "YouTube", id = IMAGES.YouTube, link = SOCIAL_LINKS.YouTube,
		  draw = YOUTUBE_DRAWN and drawYouTubeLogo or nil },
	}

	for i, data in ipairs(socialItems) do
		-- SOCIAL_PLAIN = true -> just the icon, no box behind it (like the image)
		local box = new("TextButton", {
			Name = data.name,
			LayoutOrder = i,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(LAYOUT.SocialBox, LAYOUT.SocialBox),
			BackgroundColor3 = THEME.SocialBox,
			BackgroundTransparency = SOCIAL_PLAIN and 1 or 0,
			BorderSizePixel = 0,
			ClipsDescendants = not SOCIAL_PLAIN,
			Parent = self.Socials,
		}, {
			corner(12),
			new("UIScale", { Name = "Pop", Scale = 1 }),
			new("ImageLabel", {
				Name = "Icon",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				-- EXACT SAME SIZE FOR EVERY SOCIAL ICON. the square below never
				-- changes, so the resolution of the uploaded image does nothing.
				Size = UDim2.fromScale(
					SOCIAL_ICON_SCALE * (SOCIAL_ICON_TWEAK[data.name] or 1),
					SOCIAL_ICON_SCALE * (SOCIAL_ICON_TWEAK[data.name] or 1)
				),
				BackgroundTransparency = 1,
				Image = img(data.id),
				ImageColor3 = SOCIAL_TINT_COLOR[data.name]
					or (SOCIAL_TINT and THEME.Accent)
					or Color3.fromRGB(255, 255, 255),
				ScaleType = (SOCIAL_ICON_MODE == "fit" and Enum.ScaleType.Fit)
					or (SOCIAL_ICON_MODE == "crop" and Enum.ScaleType.Crop)
					or Enum.ScaleType.Stretch,
			}, { corner(12), new("UIAspectRatioConstraint", { AspectRatio = 1 }) }),
		})

		-- if this social is drawn by code, blank the image and build the shapes
		if data.draw then
			local slot = box:FindFirstChild("Icon")
			if slot then
				slot.Image = ""
				data.draw(slot)
			end
		else
			-- RED EFFECT: a second copy of the same image, painted red, laid on
			-- top of the first one. Exact same size, so nothing shifts.
			local strength = SOCIAL_TINT_OVERLAY[data.name] or 0
			local slot = box:FindFirstChild("Icon")
			if slot and strength > 0 then
				new("ImageLabel", {
					Name = "RedGlow",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Image = slot.Image,
					ImageColor3 = Color3.fromRGB(255, 0, 0),
					ImageTransparency = 1 - strength,
					ScaleType = slot.ScaleType,
					ZIndex = (slot.ZIndex or 1) + 1,
					Parent = slot,
				})
			end
		end

		if not SOCIAL_PLAIN then
			stroke(THEME.Stroke, 1, 0.3).Parent = box
		end

		-- HOVER POP:  small dot  ->  big dot
		local pop = box:FindFirstChild("Pop")
		local function popTo(target, time)
			if not pop then return end
			TweenService:Create(pop, TweenInfo.new(time, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = target,
			}):Play()
		end

		box.MouseEnter:Connect(function() popTo(SOCIAL_HOVER_SCALE, SOCIAL_HOVER_TIME) end)
		box.MouseLeave:Connect(function() popTo(1, SOCIAL_HOVER_TIME) end)

		box.MouseButton1Click:Connect(function()
			-- a tiny squeeze so you can feel the click
			popTo(SOCIAL_HOVER_SCALE * 0.82, 0.08)
			task.delay(0.08, function() popTo(SOCIAL_HOVER_SCALE, SOCIAL_HOVER_TIME) end)

			self:OpenLink(data.link, data.name)
		end)

		table.insert(self.SocialBoxes, box)
	end

	self.Banner = new("ImageLabel", {
		Name = "Banner",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, LAYOUT.BannerOffsetY),
		Size = UDim2.new(LAYOUT.BannerWidth, 0, 0, LAYOUT.BannerHeight),
		BackgroundTransparency = 1,
		Image = img(IMAGES.Banner),
		ScaleType = Enum.ScaleType.Stretch,
		Parent = self.Hero,
	}, { corner(14) })

	-- the three bottom cards
	self.CardRow = new("Frame", {
		Name = "Cards",
		AnchorPoint = Vector2.new(0, 1),
		-- inset by 3px on every side so the card outlines are never clipped
		Position = UDim2.new(0, 3, 1, -3),
		Size = UDim2.new(1, -6, 0, LAYOUT.CardsHeight),
		BackgroundTransparency = 1,
		Parent = page,
	}, { hlist(LAYOUT.CardGap, Enum.HorizontalAlignment.Center) })

	-- the front page starts EMPTY. you fill it yourself with:
	--   ui:AddHomeTab({ title = "...", desc = "...", image = "...", callback = fn })
	self.Cards = {}
	self.HomeTabs = {}
	self.HomeLinks = {}
end

--=====================================================
--  FRONT PAGE TABS - ui:AddHomeTab({ ... })
--  same behaviour as a normal tab, only the design differs.
--  maximum of MAX_HOME_TABS (3) cards.
--=====================================================
function Library:_resizeHomeTabs()
	local count = math.max(1, #self.HomeTabs)
	local cardW = 1 / count
	local cardOffset = -math.floor((LAYOUT.CardGap * (count - 1)) / count)
	for i, tab in ipairs(self.HomeTabs) do
		tab.Frame.LayoutOrder = i
		tab.Frame.Size = UDim2.new(cardW, cardOffset, 1, 0)
	end
end

function Library:AddHomeTab(info)
	info = info or {}

	if #self.HomeTabs >= MAX_HOME_TABS then
		warn("[NEXUSPLAY HUB] the front page holds " .. MAX_HOME_TABS .. " tabs only")
		return nil
	end

	local index = #self.HomeTabs + 1
	local pad = LAYOUT.CardPad

	local card = new("Frame", {
		Name = "HomeTab" .. index,
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 1, 0), -- corrected by _resizeHomeTabs
		BackgroundColor3 = THEME.Card,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = self.CardRow,
	}, {
		corner(16),
		stroke(THEME.Accent, 1.4, 0.45),
		padding(pad, pad, pad, pad),
	})

	gradient(THEME.AccentDark, THEME.Card, 205).Parent = card

	-- hover + click highlight, behind the text and the image
	local glow = new("Frame", {
		Name = "Hover",
		Position = UDim2.fromOffset(-pad, -pad),
		Size = UDim2.new(1, pad * 2, 1, pad * 2),
		BackgroundColor3 = THEME.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = card,
	}, { corner(16) })

	local ripple = new("Frame", {
		Name = "Ripple",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = THEME.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 0,
		Parent = card,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	if HOVER_ENABLED then
		local fade = TweenInfo.new(HOVER_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local hit = new("TextButton", {
			Name = "Hit",
			Position = UDim2.fromOffset(-pad, -pad),
			Size = UDim2.new(1, pad * 2, 1, pad * 2),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 5,
			Parent = card,
		})

		hit.MouseEnter:Connect(function()
			TweenService:Create(glow, fade, { BackgroundTransparency = HOVER_STRENGTH }):Play()
		end)

		hit.MouseLeave:Connect(function()
			TweenService:Create(glow, fade, { BackgroundTransparency = 1 }):Play()
		end)

		hit.MouseButton1Down:Connect(function()
			local mouse = UserInputService:GetMouseLocation()
			local origin = Vector2.new(mouse.X, mouse.Y) - card.AbsolutePosition
			local w, h = card.AbsoluteSize.X, card.AbsoluteSize.Y
			local reach = math.sqrt(w * w + h * h) * 2

			ripple.Position = UDim2.fromOffset(origin.X - pad, origin.Y - pad)
			ripple.Size = UDim2.fromOffset(0, 0)
			ripple.BackgroundTransparency = HOVER_STRENGTH - 0.08
			ripple.Visible = true

			local grow = TweenService:Create(
				ripple,
				TweenInfo.new(CLICK_SPEED, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(reach, reach), BackgroundTransparency = 1 }
			)
			grow:Play()
			grow.Completed:Once(function() ripple.Visible = false end)
		end)

		if info.callback then
			hit.MouseButton1Click:Connect(function()
				task.spawn(info.callback)
			end)
		end
	end

	-- RULE 1: the text column reserves the icon width plus a GAP
	local textCol = new("Frame", {
		Name = "Text",
		Size = UDim2.new(1, -(LAYOUT.CardIcon + LAYOUT.GAP), 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = card,
	}, { vlist(6) })
	table.insert(self.TextCols, textCol)

	local title = new("TextLabel", {
		Name = "Title",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = info.title or ("Tab " .. index),
		TextScaled = true,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = textCol,
	}, { clampText(26) })

	local desc = new("TextLabel", {
		Name = "Desc",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 1, -38),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = info.desc or "",
		TextScaled = true,
		TextColor3 = THEME.SubText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = textCol,
	}, { clampText(14) })

	local slot = new("Frame", {
		Name = "IconSlot",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(LAYOUT.CardIcon, LAYOUT.CardIcon),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = card,
	}, {
		corner(12),
		new("ImageLabel", {
			Name = "Icon",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = img(pickIcon(info, IMAGES["Card" .. math.min(index, 3) .. "Icon"] or IMAGES.Card1Icon)),
			ScaleType = Enum.ScaleType.Crop,
		}, { corner(12) }),
	})
	table.insert(self.IconSlots, slot)

	slot.Visible = (slot.Icon.Image ~= "")

	local tab = {
		Frame = card,
		Title = title,
		Desc  = desc,
		Icon  = slot.Icon,
		IconSlot = slot,
		Glow  = glow,
		Library = self,
	}

	function tab:SetTitle(v) self.Title.Text = v end
	function tab:SetDesc(v)  self.Desc.Text = v end
	function tab:SetImage(v)
		self.Icon.Image = img(v)
		if self.IconSlot then self.IconSlot.Visible = (self.Icon.Image ~= "") end
		return self
	end
	tab.SetIcon    = tab.SetImage
	tab.SetImageId = tab.SetImage
	function tab:Remove()
		local lib = self.Library
		for i, t in ipairs(lib.HomeTabs) do
			if t == self then table.remove(lib.HomeTabs, i) break end
		end
		self.Frame:Destroy()
		lib:_resizeHomeTabs()
	end

	self.HomeTabs[index] = tab
	self.Cards[index] = card
	self:_resizeHomeTabs()
	return tab
end

--=====================================================
--  FRONT PAGE TAB = a shortcut to one of your PAGES tabs
--    ui:SetFrontPageTab(1, "AUTO FARM LEVEL")
--  clicking it jumps to the Pages tab and opens that tab.
--=====================================================
function Library:FindTab(name)
	if not name then return nil end
	local want = tostring(name):lower()
	for _, t in ipairs(self.Tabs or {}) do
		if t.Title and tostring(t.Title.Text):lower() == want then return t end
	end
	return nil
end

function Library:SetFrontPageTab(slot, tabName, override)
	override = override or {}
	self.HomeLinks = self.HomeLinks or {}

	local target = self:FindTab(tabName)
	if not target then
		warn("[NEXUSPLAY HUB] there is no tab called '" .. tostring(tabName) .. "' in Pages")
		return nil
	end

	slot = math.floor(tonumber(slot) or (#self.HomeTabs + 1))
	slot = math.clamp(slot, 1, math.min(MAX_HOME_TABS, #self.HomeTabs + 1))
	self.HomeLinks[slot] = target

	local title = override.title or target.Title.Text
	local desc  = override.desc  or target.Desc.Text

	local card = self.HomeTabs[slot]
	if card then
		card:SetTitle(title)
		card:SetDesc(desc)
		if override.image then card:SetImage(override.image) end
		return card
	end

	return self:AddHomeTab({
		title = title,
		desc  = desc,
		image = override.image or IMAGES.Card1Icon,
		callback = function()
			local linked = self.HomeLinks[slot]
			if not linked then return end
			self:ResetTabView()
			self:SelectPage(TEXT.Nav[2] or "Pages")
			self:OpenSection(linked)
		end,
	})
end

--=====================================================
--  PAGES PAGE (the tab list - no search bar)
--=====================================================
function Library:_buildTabsPage()
	local page = new("Frame", {
		Name = "TabsPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ClipsDescendants = true,
		Parent = self.Content,
	})
	self.PageFrames[TEXT.Nav[2] or "Pages"] = page

	-- SEARCH BAR: icon + field only. No extra button next to it.
	self.SearchBar = new("Frame", {
		Name = "SearchBar",
		-- inset by 3px so the outline is never clipped by the panel edge
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -(LAYOUT.TabScrollPad + 6 + LAYOUT.BackButton + LAYOUT.BackGap), 0, LAYOUT.SearchHeight),
		BackgroundColor3 = THEME.SearchBar,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = page,
	}, {
		corner(16),
		stroke(THEME.Accent, 2, 0.15),
		padding(0, 18, 0, 18),
		new("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.fromOffset(LAYOUT.SearchIcon, LAYOUT.SearchIcon),
			BackgroundTransparency = 1,
			Image = img(IMAGES.SearchIcon),
			ScaleType = Enum.ScaleType.Fit,
		}),
		new("TextBox", {
			Name = "Field",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(1, -(LAYOUT.SearchIcon + 12), 1, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Font = Enum.Font.GothamMedium,
			PlaceholderText = TEXT.SearchPlaceholder or "SEARCH ...",
			PlaceholderColor3 = THEME.SubText,
			Text = "",
			TextSize = 20,
			TextColor3 = THEME.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
		}),
	})

	-- GO BACK BUTTON, on the right of the search bar.
	-- put your own image id in IMAGES.BackIcon.
	self.BackButton = new("ImageButton", {
		Name = "BackButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -(LAYOUT.TabScrollPad + 3), 0, 3),
		Size = UDim2.fromOffset(LAYOUT.BackButton, LAYOUT.SearchHeight),
		BackgroundColor3 = THEME.SearchBar,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Image = "",
		AutoButtonColor = false,
		Visible = BACK_ALWAYS_VISIBLE,
		ZIndex = 3,
		Parent = page,
	}, {
		corner(16),
		stroke(THEME.Accent, 2, 0.15),
		gradient(THEME.AccentDark, THEME.SearchBar, 205),
		-- the arrow you see until you put your own image id in IMAGES.BackIcon
		new("TextLabel", {
			Name = "Fallback",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = BACK_FALLBACK_TEXT,
			TextSize = 26,
			TextColor3 = THEME.Text,
			Visible = img(IMAGES.BackIcon) == "",
			ZIndex = 4,
		}),
		new("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -18, 1, -18),
			BackgroundTransparency = 1,
			Image = img(IMAGES.BackIcon),
			ScaleType = Enum.ScaleType.Fit,
			Visible = img(IMAGES.BackIcon) ~= "",
			ZIndex = 4,
		}),
	})

	-- same smooth highlight the tabs use, so the button feels alive
	if HOVER_ENABLED then
		local fade = TweenInfo.new(HOVER_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		self.BackButton.MouseEnter:Connect(function()
			TweenService:Create(self.BackButton, fade, { BackgroundTransparency = 0.55 }):Play()
		end)
		self.BackButton.MouseLeave:Connect(function()
			TweenService:Create(self.BackButton, fade, { BackgroundTransparency = 0.15 }):Play()
		end)
	end

	self.BackButton.MouseButton1Click:Connect(function()
		self:CloseSection()
	end)

	-- THE SEARCH BAR NOW ACTUALLY WORKS.
	-- it filters the level you are on, nothing else.
	local field = self.SearchBar:FindFirstChild("Field")
	if field then
		field:GetPropertyChangedSignal("Text"):Connect(function()
			if self.SearchIgnore then return end
			self:_searchLevel(field.Text)
		end)
	end

	-- RULE 2: the tab list starts below the search bar, never on top of it
	local gridTop = LAYOUT.SearchHeight + LAYOUT.GAP + LAYOUT.SearchGap

	local area = new("Frame", {
		Name = "GridArea",
		Position = UDim2.fromOffset(0, gridTop),
		Size = UDim2.new(1, 0, 1, -gridTop),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = page,
	})
	self.TabArea = area

	-- The tab list is built ROW BY ROW so every card lines up perfectly
	self.TabRows = {}
	self.TabLines = {}

	self.TabList = new("ScrollingFrame", {
		Name = "TabList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = THEME.Accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = area,
	}, {
		-- a few pixels on every side so no card outline gets clipped
		padding(3, LAYOUT.TabScrollPad, LAYOUT.TabGap, 3),
		vlist(LAYOUT.TabGap),
	})

	-- the root list and every section list share the exact same layout code
	self.Tabs = self.Tabs or {}
	self.RootList = {
		List  = self.TabList,
		Rows  = self.TabRows,
		Lines = self.TabLines,
		Items = self.Tabs,
	}
	self.CurrentSection = nil
	self.ViewStack = {}

	self.EmptyHint = new("TextLabel", {
		Name = "EmptyHint",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "No tabs yet. Add them with ui:AddTab({ ... })",
		TextSize = 16,
		TextColor3 = THEME.SubText,
		Parent = area,
	})
end

--=====================================================
--  ONE ROW OF TABS  ->  Tab | Tab
--=====================================================
function Library:_rowIn(ctx, rowIndex)
	if ctx.Rows[rowIndex] then return ctx.Rows[rowIndex] end

	local cols = math.max(1, LAYOUT.TabColumns)

	local row = new("Frame", {
		Name = "Row" .. rowIndex,
		LayoutOrder = rowIndex,
		Size = UDim2.new(1, 0, 0, LAYOUT.TabHeight),
		BackgroundTransparency = 1,
		Parent = ctx.List,
	})

	-- optional divider line, only drawn when LAYOUT.TabDivider is above 0
	local lines = {}
	for i = 1, (LAYOUT.TabDivider > 0 and cols - 1 or 0) do
		lines[i] = new("Frame", {
			Name = "Line" .. i,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(i / cols, (i * LAYOUT.TabGap / cols) - (LAYOUT.TabGap / 2), 0, 0),
			Size = UDim2.new(0, LAYOUT.TabDivider, 1, 0),
			BackgroundColor3 = THEME.Accent,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = row,
		})
	end
	ctx.Lines[rowIndex] = lines

	local above = ctx.Lines[rowIndex - 1]
	if above then
		for _, line in ipairs(above) do
			line.Size = UDim2.new(0, LAYOUT.TabDivider, 1, LAYOUT.TabGap)
		end
	end

	ctx.Rows[rowIndex] = row
	return row
end

--=====================================================
--  ADD A TAB - call this as many times as you like
--=====================================================
-- ui:AddTab({ title = "AUTO FARM", desc = "what it does", image = "87628150067132" })
function Library:AddTab(info)
	return self:_addCard(self.RootList, info, false)
end

-- shared builder. a tab and a section use the SAME card design.
function Library:_addCard(ctx, info, isSection)
	info = info or {}
	local index = #ctx.Items + 1
	local cardHandle

	local cols = math.max(1, LAYOUT.TabColumns)
	local col  = ((index - 1) % cols) + 1
	local row  = self:_rowIn(ctx, math.floor((index - 1) / cols) + 1)

	-- RULE 2: columns + gaps fill the row exactly, so every tab is the same
	-- width and they can never overlap
	local card = new("Frame", {
		Name = (isSection and "Section" or "Tab") .. index,
		Position = UDim2.new((col - 1) / cols, (col - 1) * LAYOUT.TabGap / cols, 0, 0),
		Size = UDim2.new(1 / cols, -LAYOUT.TabGap * (cols - 1) / cols, 1, 0),
		BackgroundColor3 = THEME.TabCard,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = row,
	}, {
		corner(18),
		stroke(THEME.Accent, 1.6, 0.3),
		padding(LAYOUT.TabPad, LAYOUT.TabPad, LAYOUT.TabPad, LAYOUT.TabPad),
	})

	-- HOVER + CLICK HIGHLIGHT
	-- both layers sit BEHIND the text and the image, and inside the card, so the
	-- glow never covers the title, the description or the game icon
	local pad = LAYOUT.TabPad

	local glow = new("Frame", {
		Name = "Hover",
		Position = UDim2.fromOffset(-pad, -pad),
		Size = UDim2.new(1, pad * 2, 1, pad * 2),
		BackgroundColor3 = THEME.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = card,
	}, { corner(18) })

	local ripple = new("Frame", {
		Name = "Ripple",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = THEME.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 0,
		Parent = card,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	if HOVER_ENABLED then
		local fade = TweenInfo.new(HOVER_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		local hit = new("TextButton", {
			Name = "Hit",
			Position = UDim2.fromOffset(-pad, -pad),
			Size = UDim2.new(1, pad * 2, 1, pad * 2),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 5,
			Parent = card,
		})

		hit.MouseEnter:Connect(function()
			TweenService:Create(glow, fade, { BackgroundTransparency = HOVER_STRENGTH }):Play()
		end)

		hit.MouseLeave:Connect(function()
			TweenService:Create(glow, fade, { BackgroundTransparency = 1 }):Play()
		end)

		hit.MouseButton1Down:Connect(function()
			-- the ripple starts exactly where the mouse is and grows over the whole tab
			local mouse = UserInputService:GetMouseLocation()
			local origin = Vector2.new(mouse.X, mouse.Y) - card.AbsolutePosition
			local w, h = card.AbsoluteSize.X, card.AbsoluteSize.Y
			local reach = math.sqrt(w * w + h * h) * 2

			ripple.Position = UDim2.fromOffset(origin.X - pad, origin.Y - pad)
			ripple.Size = UDim2.fromOffset(0, 0)
			ripple.BackgroundTransparency = HOVER_STRENGTH - 0.08
			ripple.Visible = true

			local grow = TweenService:Create(
				ripple,
				TweenInfo.new(CLICK_SPEED, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(reach, reach), BackgroundTransparency = 1 }
			)
			grow:Play()
			grow.Completed:Once(function() ripple.Visible = false end)
		end)

		hit.MouseButton1Click:Connect(function()
			-- clicking a tab always goes INSIDE it and shows its sections
			-- a tab always opens. a section opens only when it holds
			-- something inside (its own sections or controls).
			if cardHandle and (not isSection or cardHandle.SectionCtx) then
				self:OpenSection(cardHandle)
			end
			if info.callback then task.spawn(info.callback) end
		end)
	end

	-- RULE 1: the text column reserves the icon width plus a GAP
	local textCol = new("Frame", {
		Name = "Text",
		Size = UDim2.new(1, -(LAYOUT.TabIcon + LAYOUT.GAP), 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = card,
	}, { vlist(8) })

	local title = new("TextLabel", {
		Name = "Title",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, LAYOUT.TabTitle),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = info.title or ("TAB " .. index),
		TextScaled = true,
		TextWrapped = true,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = textCol,
	}, { clampText(28) })

	-- the description sits on its own rounded background pill
	local pill = new("Frame", {
		Name = "DescPill",
		LayoutOrder = 2, -- rounded pill behind the description
		Size = UDim2.new(1, 0, 0, LAYOUT.TabDescHeight),
		BackgroundColor3 = THEME.DescPill,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = textCol,
	}, {
		corner(12),
		padding(4, 12, 4, 12),
	})

	local desc = new("TextLabel", {
		Name = "Desc",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = info.desc or "",
		TextScaled = true,
		TextColor3 = THEME.SubText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = pill,
	}, { clampText(14) })

	local slot = new("Frame", {
		Name = "IconSlot",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(LAYOUT.TabIcon, LAYOUT.TabIcon),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = card,
	}, {
		corner(12),
		new("ImageLabel", {
			Name = "Icon",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			-- ICON: works exactly the same on a TAB and on a SECTION.
			-- image / icon / imageId / iconId are all accepted.
			Image = img(pickIcon(info, IMAGES.TabIcon)),
			ScaleType = Enum.ScaleType.Crop,
		}, { corner(12) }),
	})

	-- image = "" or image = false hides the icon completely
	slot.Visible = (slot.Icon.Image ~= "")

	local tab = {
		Frame     = card,
		Title     = title,
		Desc      = desc,
		Pill      = pill,
		Icon      = slot.Icon,
		IconSlot  = slot,
		Glow      = glow,
		Library   = self,
		IsSection = isSection or false,
		Sections  = {},
	}

	function tab:SetTitle(v) self.Title.Text = v end
	function tab:SetDesc(v)  self.Desc.Text = v end

	-- CHANGE THE ICON AT ANY TIME (tab or section, same command):
	--   myTab:SetImage("87628150067132")
	--   mySection:SetIcon("rbxassetid://87628150067132")
	--   mySection:SetIcon("")   -- hides the icon
	function tab:SetImage(v)
		self.Icon.Image = img(v)
		if self.IconSlot then self.IconSlot.Visible = (self.Icon.Image ~= "") end
		return self
	end
	tab.SetIcon    = tab.SetImage
	tab.SetImageId = tab.SetImage
	function tab:GetImage() return self.Icon.Image end

	function tab:Remove()    self.Frame:Destroy() end

	--=====================================================
	--  STRUCTURE BLOCKER  (this is the rule of the whole UI)
	--    Pages page      ->  TABS only
	--    inside a TAB    ->  SECTIONS only
	--    inside a SECTION->  CONTROLS only (button / slider / toggle ...)
	--  anything placed in the wrong level is refused with a warning,
	--  it is never drawn, and a harmless dummy handle is returned so
	--  your script keeps running instead of erroring.
	--=====================================================
	local deadMeta
	deadMeta = {
		__index = function()
			return function() return setmetatable({}, deadMeta) end
		end,
	}

	local function refuse(what, why)
		warn("[NEXUSPLAY HUB] " .. what .. " was BLOCKED. " .. why)
		return setmetatable({}, deadMeta)
	end

	-- wraps every control so it only works inside a SECTION
	local function controlOnly(name, fn)
		return function(self, o, ...)
			if not self.IsSection then
				return refuse(name,
					"controls live INSIDE a section. Do:  local s = tab:AddSection({ title = \"...\" })  then  s:" .. name .. "({ ... })")
			end
			return fn(self, o, ...)
		end
	end

	-- a SECTION may only be added inside a TAB, never inside another section
	function tab:AddSection(sectionInfo)
		if self.IsSection then
			return refuse("AddSection",
				"a section cannot hold another section. Put your controls in this section instead.")
		end
		local lib = self.Library
		return lib:_addCard(lib:_sectionList(self), sectionInfo, true)
	end

	function tab:Open() self.Library:OpenSection(self) end
	function tab:Back() self.Library:CloseSection() end

	-- REAL CONTROLS. section only. they land in the rounded box you see
	-- after you click the section.
	tab.AddButton      = controlOnly("AddButton",      function(self, o) return self.Library:_addButton(self, o) end)
	tab.AddToggle      = controlOnly("AddToggle",      function(self, o) return self.Library:_addToggle(self, o) end)
	tab.AddSwitch      = controlOnly("AddSwitch",      function(self, o) return self.Library:_addToggle(self, o) end)
	tab.AddSlider      = controlOnly("AddSlider",      function(self, o) return self.Library:_addSlider(self, o) end)
	tab.AddComboButton = controlOnly("AddComboButton", function(self, o) return self.Library:_addCombo(self, o) end)
	tab.AddComboButtons= controlOnly("AddComboButtons",function(self, o) return self.Library:_addCombo(self, o) end)

	-- EXTRA CONTROLS. section only as well.
	tab.AddLabel       = controlOnly("AddLabel",       function(self, o) return self.Library:_addLabel(self, o) end)
	tab.AddParagraph   = controlOnly("AddParagraph",   function(self, o) return self.Library:_addParagraph(self, o) end)
	tab.AddDivider     = controlOnly("AddDivider",     function(self)    return self.Library:_addDivider(self) end)
	tab.AddInput       = controlOnly("AddInput",       function(self, o) return self.Library:_addInput(self, o) end)
	tab.AddTextbox     = controlOnly("AddTextbox",     function(self, o) return self.Library:_addInput(self, o) end)
	tab.AddKeybind     = controlOnly("AddKeybind",     function(self, o) return self.Library:_addKeybind(self, o) end)
	tab.AddDropdown    = controlOnly("AddDropdown",    function(self, o) return self.Library:_addDropdown(self, o) end)
	tab.AddMultiDropdown = controlOnly("AddMultiDropdown", function(self, o)
		o = o or {}
		o.multi = true
		return self.Library:_addDropdown(self, o)
	end)
	tab.AddColorPicker = controlOnly("AddColorPicker", function(self, o) return self.Library:_addColorPicker(self, o) end)

	-- INFO BUTTON: a normal button that opens the black popup. section only.
	tab.AddInfoButton = controlOnly("AddInfoButton", function(self, o)
		o = o or {}
		local lib = self.Library
		return lib:_addButton(self, {
			text = o.text or "HOW TO USE",
			callback = function()
				lib:ShowInfo({ title = o.title or o.text or "HOW TO USE", text = o.info or o.body or "" })
			end,
		})
	end)


	cardHandle = tab
	ctx.Items[index] = tab
	if self.EmptyHint then self.EmptyHint.Visible = false end
	return tab
end

--=====================================================
--  SECTIONS
--  clicking a tab opens its own list, built with the very
--  same code, so a section looks identical to a tab.
--=====================================================
function Library:_sectionList(tab)
	if tab.SectionCtx then return tab.SectionCtx end

	local list = new("ScrollingFrame", {
		Name = "SectionList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = THEME.Accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 2,
		Parent = self.TabArea,
	}, {
		padding(3, LAYOUT.TabScrollPad, LAYOUT.TabGap, 3),
		vlist(LAYOUT.TabGap),
	})

	tab.SectionCtx = {
		List  = list,
		Rows  = {},
		Lines = {},
		Items = tab.Sections,
	}
	return tab.SectionCtx
end

--=====================================================
--  SEARCH BAR
--  it only ever searches the level you are standing on:
--  on the tab list  -> tabs only
--  inside a tab     -> that tab's sections only
--  inside a section -> that section's own things only
--=====================================================
function Library:_currentCtx()
	if self.CurrentSection and self.CurrentSection.SectionCtx then
		return self.CurrentSection.SectionCtx
	end
	return self.RootList
end

-- after hiding cards, pack the visible ones back together so there are no holes
function Library:_repackLevel(ctx)
	if not ctx then return 0 end
	local cols = math.max(1, LAYOUT.TabColumns)
	local shown = 0

	for _, item in ipairs(ctx.Items) do
		local card = item.Frame
		if card and card.Visible then
			shown = shown + 1
			local col = ((shown - 1) % cols) + 1
			local rowIndex = math.floor((shown - 1) / cols) + 1
			local row = ctx.Rows[rowIndex]
			if row then
				card.Parent = row
				card.Position = UDim2.new((col - 1) / cols, (col - 1) * LAYOUT.TabGap / cols, 0, 0)
			end
		end
	end

	local usedRows = math.ceil(shown / cols)
	for i, row in ipairs(ctx.Rows) do
		row.Visible = (i <= usedRows)
	end

	return shown
end

-- hide the controls of the open card when their name does not match
function Library:_filterControls(card, query)
	if not card or not card.ControlRows then return end
	for _, row in ipairs(card.ControlRows) do
		local frame = row.Frame
		if frame then
			local match = (query == "")
			if not match then
				for _, thing in ipairs(frame:GetDescendants()) do
					if thing:IsA("TextLabel") or thing:IsA("TextButton") then
						if string.find(string.lower(thing.Text), query, 1, true) then
							match = true
							break
						end
					end
				end
			end
			frame.Visible = match
		end
	end
end

function Library:_searchLevel(text)
	local query = string.lower(text or "")
	local ctx = self:_currentCtx()
	if not ctx then return end

	for _, item in ipairs(ctx.Items) do
		local name = string.lower(item.Title and item.Title.Text or "")
		local desc = string.lower(item.Desc and item.Desc.Text or "")
		local match = (query == "")
			or string.find(name, query, 1, true) ~= nil
			or string.find(desc, query, 1, true) ~= nil
		if item.Frame then item.Frame.Visible = match end
	end

	self:_repackLevel(ctx)
	self:_filterControls(self.CurrentSection, query)
end

-- empty the search box and show everything again (used every time you change level)
function Library:_clearSearch()
	if self.SearchBar then
		local field = self.SearchBar:FindFirstChild("Field")
		if field and field.Text ~= "" then
			self.SearchIgnore = true
			field.Text = ""
			self.SearchIgnore = false
		end
	end

	for _, ctx in ipairs({ self.RootList, self.CurrentSection and self.CurrentSection.SectionCtx }) do
		if ctx then
			for _, item in ipairs(ctx.Items) do
				if item.Frame then item.Frame.Visible = true end
			end
			self:_repackLevel(ctx)
		end
	end

	self:_filterControls(self.CurrentSection, "")
end

-- show one level: a card's inside view, or nil for the plain tab list
function Library:_showLevel(card, forward)
	self:_clearSearch()
	if card then
		local ctx = self:_sectionList(card)
		slideIn(ctx.List, forward)
		ctx.List.CanvasPosition = Vector2.new(0, 0)
		self.CurrentSection = card
		if self.EmptyHint then
			-- level aware hint: a tab can only hold sections, a section can only hold controls
			if card.IsSection then
				self.EmptyHint.Text = "This section is empty. Add controls with section:AddButton / AddToggle / AddSlider"
			else
				self.EmptyHint.Text = "This tab is empty. Add sections with tab:AddSection({ title = \"...\" })"
			end
			self.EmptyHint.Visible = (#card.Sections == 0 and card.ControlBox == nil)
		end
	else
		if self.TabList then slideIn(self.TabList, forward) end
		self.CurrentSection = nil
		if self.EmptyHint then
			self.EmptyHint.Text = "No tabs yet. Add them with ui:AddTab({ ... })"
			self.EmptyHint.Visible = (#self.Tabs == 0)
		end
	end
end

-- go inside a tab or a section
function Library:OpenSection(card)
	if not card then return end
	self:_sectionList(card)

	-- hide the level we are standing on right now
	if self.CurrentSection and self.CurrentSection.SectionCtx then
		self.CurrentSection.SectionCtx.List.Visible = false
	elseif self.TabList then
		self.TabList.Visible = false
	end

	self.ViewStack = self.ViewStack or {}
	table.insert(self.ViewStack, card)
	-- going inside: slide in from the RIGHT
	self:_showLevel(card, true)
	if self.BackButton then self.BackButton.Visible = true end
end

-- one step back. when you are already on the plain tab list,
-- the back button takes you out to the HOME page.
function Library:CloseSection()
	self.ViewStack = self.ViewStack or {}

	if #self.ViewStack > 0 then
		local leaving = table.remove(self.ViewStack)
		if leaving.SectionCtx then leaving.SectionCtx.List.Visible = false end
		-- going back: slide in from the LEFT
		self:_showLevel(self.ViewStack[#self.ViewStack], false)
		if self.BackButton then
			self.BackButton.Visible = (#self.ViewStack > 0) or BACK_ALWAYS_VISIBLE
		end
		return
	end

	self:SelectPage(TEXT.Nav[1] or "Home", true)
end

-- jump straight back to the plain tab list, no matter how deep you are
function Library:ResetTabView()
	self.ViewStack = self.ViewStack or {}
	while #self.ViewStack > 0 do
		local leaving = table.remove(self.ViewStack)
		if leaving.SectionCtx then leaving.SectionCtx.List.Visible = false end
	end
	self:_showLevel(nil, false)
	if self.BackButton then self.BackButton.Visible = BACK_ALWAYS_VISIBLE end
end

--=====================================================
--  THE ROUNDED BOX THAT HOLDS SWITCHES / BUTTONS / SLIDERS
--  it sits under the section cards, inside the card you opened
--=====================================================
function Library:_controlBox(card)
	if card.ControlBox then return card.ControlBox end

	local ctx = self:_sectionList(card)

	-- the box itself NEVER scrolls and never moves. it is pinned to the
	-- visible area, and the controls scroll INSIDE it.
	local box = new("Frame", {
		Name = "ControlBox",
		LayoutOrder = 9999, -- always the last thing in the list
		Size = UDim2.new(1, 0, 0, LAYOUT.ControlBoxHeight),
		BackgroundColor3 = THEME.Card,
		-- SOLID: nothing behind it shows through anymore
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = ctx.List,
	}, {
		corner(18),
		softStroke(THEME.Accent, 1.3, 0.55, 0.45),
	})

	-- the scrolling part lives INSIDE the box, so the rounded frame and
	-- its outline stay perfectly still while the controls move
	local inner = new("ScrollingFrame", {
		Name = "Inner",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = THEME.ControlAccent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = box,
	}, {
		padding(LAYOUT.ControlBoxPad, LAYOUT.ControlBoxPad, LAYOUT.ControlBoxPad, LAYOUT.ControlBoxPad),
		vlist(LAYOUT.ControlGap),
	})

	-- breathing room at the very bottom. automatic canvas size ignores the
	-- bottom padding, which is what made the last buttons feel stuck.
	new("Frame", {
		Name = "BottomSpace",
		LayoutOrder = 999999,
		Size = UDim2.new(1, 0, 0, LAYOUT.ControlBoxPad),
		BackgroundTransparency = 1,
		Parent = inner,
	})

	card.ControlBox = box
	card.ControlInner = inner
	card.ControlRows = {}

	-- remember every box so the BOX TUNER can resize them live
	self.ControlBoxes = self.ControlBoxes or {}
	table.insert(self.ControlBoxes, { Box = box, Inner = inner, Card = card })

	self:_fitControlBox(box)
	if self.TabArea then
		self.TabArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:_fitControlBox(box)
		end)
	end

	return box
end

-- keep the box inside the visible area so it never needs the outer
-- page scroll. anything taller simply scrolls inside the box.
function Library:_fitControlBox(box)
	if not box or not box.Parent then return end

	-- THE STUTTER FIX: while the panel is growing or shrinking, its size
	-- changes every single frame. re-measuring the boxes on every one of
	-- those frames is what made the animation feel stuck. skip it, and the
	-- animation finisher re-measures once at the end instead.
	if self.Animating then return end

	-- ONE simple rule: height x scale. bigger number = bigger box, always.
	local room = LAYOUT.ControlBoxHeight * (LAYOUT.ControlBoxScale or 1)

	-- THE BUG THAT MADE THE BOX STOP EARLY:
	-- AbsoluteSize is measured AFTER the UIScale shrink, but the box size
	-- is written in design pixels. comparing the two chopped the box down
	-- to about 70% of the real room. divide the scale back out first.
	if self.TabArea then
		-- always measure against the RESTING scale, never a mid animation one
		local scaleObj = self.Main and self.Main:FindFirstChild("Scale")
		local live = (scaleObj and scaleObj.Scale > 0) and scaleObj.Scale or 1
		local s = self.BaseScale or live
		if s <= 0 then s = 1 end

		local avail = (self.TabArea.AbsoluteSize.Y / s) - (LAYOUT.TabGap * 2)
		if avail > 60 then
			room = math.min(room, avail)
		end
	end

	box.Size = UDim2.new(1, 0, 0, room)
end

-- re-apply every box / padding / gap / row height number after the
-- BOX TUNER changes something
function Library:_refreshControlBoxes()
	-- the panel itself may need to get taller first, otherwise the box
	-- simply has no room to grow downwards
	if self.Main then
		self:_applyLayout()
	end

	for _, entry in ipairs(self.ControlBoxes or {}) do
		self:_fitControlBox(entry.Box)

		local pad = entry.Inner:FindFirstChildOfClass("UIPadding")
		if pad then
			local p = UDim.new(0, LAYOUT.ControlBoxPad)
			pad.PaddingTop, pad.PaddingBottom = p, p
			pad.PaddingLeft, pad.PaddingRight = p, p
		end

		local list = entry.Inner:FindFirstChildOfClass("UIListLayout")
		if list then
			list.Padding = UDim.new(0, LAYOUT.ControlGap)
		end

		for _, row in ipairs(entry.Card.ControlRows or {}) do
			-- combo rows own their height (it depends on how many buttons
			-- are inside), so they are never resized to a control height
			local h = row.Full and row.Height
				or (row.Slider and LAYOUT.SliderHeight or LAYOUT.ControlHeight)
			row.Height = h
			if row.Frame and row.Frame.Parent then
				row.Frame.Size = UDim2.new(1, 0, 0, h)
			end
		end
	end
end

-- RULE 2: two columns + the gap fill the row exactly, so controls
-- can never overlap  ->  button | button
function Library:_controlSlot(card, height)
	local box = self:_controlBox(card)
	local holder = card.ControlInner or box
	local cols = math.max(1, LAYOUT.ControlColumns)
	local rows = card.ControlRows
	local row = rows[#rows]

	if (not row) or row.Used >= cols then
		local frame = new("Frame", {
			Name = "ControlRow" .. (#rows + 1),
			LayoutOrder = #rows + 1,
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			ZIndex = 2,
			Parent = holder,
		})
		row = { Frame = frame, Used = 0, Height = height, Slider = (height >= LAYOUT.SliderHeight) }
		rows[#rows + 1] = row
	end

	if height > row.Height then
		row.Height = height
		row.Slider = (height >= LAYOUT.SliderHeight)
		row.Frame.Size = UDim2.new(1, 0, 0, height)
	end

	local col = row.Used
	row.Used = col + 1

	local gap = LAYOUT.ControlGap
	return new("Frame", {
		Name = "Slot" .. row.Used,
		Position = UDim2.new(col / cols, col * gap / cols, 0, 0),
		Size = UDim2.new(1 / cols, -gap * (cols - 1) / cols, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = row.Frame,
	})
end

-- a row that takes the FULL width of the box (no button | button split).
-- combo grids use this so the small buttons can spread edge to edge.
function Library:_comboRow(card, height)
	local box = self:_controlBox(card)
	local holder = card.ControlInner or box
	local rows = card.ControlRows

	local frame = new("Frame", {
		Name = "ComboRow" .. (#rows + 1),
		LayoutOrder = #rows + 1,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = holder,
	})

	-- Used is filled up on purpose: the next control starts a brand new row
	local entry = {
		Frame = frame,
		Used = math.max(1, LAYOUT.ControlColumns),
		Height = height,
		Slider = false,
		Full = true,
	}
	rows[#rows + 1] = entry

	return frame, entry
end

-- one small pill button inside a combo grid
function Library:_comboButton(parent, opt)
	opt = opt or {}

	local shell = new("Frame", {
		Name = "ComboButton",
		BackgroundColor3 = THEME.TabCard,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = parent,
	}, {
		corner(10),
		plainStroke(THEME.ControlAccent, 1.6, 0, false),
	})

	local glow = new("Frame", {
		Name = "Hover",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.ControlAccent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = shell,
	}, { corner(10) })

	local ripple = new("Frame", {
		Name = "Ripple",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = THEME.ControlAccent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
		Parent = shell,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	-- RULE 1 + 3: the name keeps a margin and never leaves the pill.
	-- TextScaled + the constraint = a long name simply shrinks itself
	-- instead of getting cut off, exactly like the reference image.
	local label = new("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -12, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = opt.text or "BUTTON",
		TextScaled = true,
		TextColor3 = THEME.ControlText,
		ZIndex = 3,
		Parent = shell,
	}, {
		clampText(LAYOUT.ComboText),
	})
	controlPart(label, "TextColor3")

	local hit = new("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
		Parent = shell,
	})

	if HOVER_ENABLED then
		local fade = TweenInfo.new(HOVER_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		hit.MouseEnter:Connect(function()
			TweenService:Create(glow, fade, { BackgroundTransparency = HOVER_STRENGTH }):Play()
		end)

		hit.MouseLeave:Connect(function()
			TweenService:Create(glow, fade, { BackgroundTransparency = 1 }):Play()
		end)

		hit.MouseButton1Down:Connect(function()
			local mouse = UserInputService:GetMouseLocation()
			local origin = Vector2.new(mouse.X, mouse.Y) - shell.AbsolutePosition
			local w, h = shell.AbsoluteSize.X, shell.AbsoluteSize.Y
			local reach = math.sqrt(w * w + h * h) * 2

			ripple.Position = UDim2.fromOffset(origin.X, origin.Y)
			ripple.Size = UDim2.fromOffset(0, 0)
			ripple.BackgroundTransparency = HOVER_STRENGTH - 0.08
			ripple.Visible = true

			local grow = TweenService:Create(
				ripple,
				TweenInfo.new(CLICK_SPEED, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(reach, reach), BackgroundTransparency = 1 }
			)
			grow:Play()
			grow.Completed:Once(function() ripple.Visible = false end)
		end)
	end

	hit.MouseButton1Click:Connect(function()
		if opt.callback then task.spawn(opt.callback) end
	end)

	local handle = { Frame = shell, Label = label }
	function handle:SetText(v) self.Label.Text = v end
	return handle
end

--=====================================================
--  COMBO BUTTONS - many small buttons in a neat grid
--  tab:AddComboButton({ text = "Mod Skin Aura", columns = 3,
--      buttons = { { text = "Bright Yellow", callback = function() end }, ... } })
--=====================================================
function Library:_addCombo(card, info)
	info = info or {}

	local items = info.buttons or info.items or {}
	local cols  = math.max(1, info.columns or LAYOUT.ComboColumns)
	local gap   = info.gap or LAYOUT.ComboGap
	local btnH  = info.height or LAYOUT.ComboHeight

	local hasTitle = (info.text ~= nil and info.text ~= "")
	local titleH = hasTitle and LAYOUT.ComboTitle or 0

	local count = math.max(#items, 1)
	local lines = math.ceil(count / cols)
	local total = titleH + (lines * btnH) + ((lines - 1) * gap)

	local frame, rowEntry = self:_comboRow(card, total)

	if hasTitle then
		new("TextLabel", {
			Name = "ComboTitle",
			Position = UDim2.fromOffset(2, 0),
			Size = UDim2.new(1, -4, 0, titleH),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = info.text,
			TextSize = 17,
			TextColor3 = THEME.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
			Parent = frame,
		})
	end

	-- RULE 2: the grid divides the row exactly, so the pills never overlap
	local grid = new("Frame", {
		Name = "ComboGrid",
		Position = UDim2.fromOffset(0, titleH),
		Size = UDim2.new(1, 0, 1, -titleH),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = frame,
	}, {
		new("UIGridLayout", {
			-- the extra -1 pixel stops rounding from pushing the last pill
			-- onto a new line (that is why 3 columns showed up as 2)
			CellSize = UDim2.new(1 / cols, -(gap * (cols - 1) / cols) - 1, 0, btnH),
			CellPadding = UDim2.new(0, gap, 0, gap),
			FillDirectionMaxCells = cols,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	-- THE SCROLL FIX: never trust the row-count maths. the grid reports how
	-- tall it really is and the row grows to match, so the canvas is always
	-- long enough and the last line of buttons can be scrolled to.
	local gridLayout = grid:FindFirstChildOfClass("UIGridLayout")
	local function refitCombo()
		if not gridLayout or not frame.Parent then return end
		if self.Animating then return end -- never measure mid animation
		local scaleObj = self.Main and self.Main:FindFirstChild("Scale")
		local live = (scaleObj and scaleObj.Scale > 0) and scaleObj.Scale or 1
		local s = self.BaseScale or live
		if s <= 0 then s = 1 end
		local h = titleH + math.ceil(gridLayout.AbsoluteContentSize.Y / s)
		if h > 0 and math.abs(h - frame.Size.Y.Offset) > 1 then
			frame.Size = UDim2.new(1, 0, 0, h)
			if rowEntry then rowEntry.Height = h end
		end
	end
	if gridLayout then
		gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refitCombo)
		task.defer(refitCombo)
	end

	local made = {}
	for i, opt in ipairs(items) do
		if type(opt) == "string" then opt = { text = opt } end
		local btn = self:_comboButton(grid, opt)
		btn.Frame.LayoutOrder = i
		made[i] = btn
	end

	local handle = { Frame = frame, Grid = grid, Buttons = made }
	function handle:Get(i) return self.Buttons[i] end
	return handle
end

--=====================================================
--  BUTTON
--=====================================================
function Library:_addButton(card, info)
	info = info or {}
	local slot = self:_controlSlot(card, LAYOUT.ControlHeight)

	local shell = new("Frame", {
		Name = "Button",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.TabCard,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = slot,
	}, {
		corner(12),
		plainStroke(THEME.ControlAccent, 1.6, 0, false), -- button: solid outline, no fade
	})

	-- HOVER + CLICK HIGHLIGHT, exactly like a tab card.
	-- both layers sit BEHIND the text, so the label always stays readable
	local glow = new("Frame", {
		Name = "Hover",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.ControlAccent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = shell,
	}, { corner(12) })

	local ripple = new("Frame", {
		Name = "Ripple",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = THEME.ControlAccent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 2,
		Parent = shell,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	-- RULE 1 + 3: the label keeps a margin and never leaves the button
	local label = new("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = info.text or "BUTTON",
		TextSize = 18,
		TextColor3 = THEME.ControlText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = shell,
	})
	controlPart(label, "TextColor3")

	local hit = new("TextButton", {
		Name = "Hit",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
		Parent = shell,
	})

	if HOVER_ENABLED then
		local fade = TweenInfo.new(HOVER_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		hit.MouseEnter:Connect(function()
			TweenService:Create(glow, fade, { BackgroundTransparency = HOVER_STRENGTH }):Play()
		end)

		hit.MouseLeave:Connect(function()
			TweenService:Create(glow, fade, { BackgroundTransparency = 1 }):Play()
		end)

		hit.MouseButton1Down:Connect(function()
			local mouse = UserInputService:GetMouseLocation()
			local origin = Vector2.new(mouse.X, mouse.Y) - shell.AbsolutePosition
			local w, h = shell.AbsoluteSize.X, shell.AbsoluteSize.Y
			local reach = math.sqrt(w * w + h * h) * 2

			ripple.Position = UDim2.fromOffset(origin.X, origin.Y)
			ripple.Size = UDim2.fromOffset(0, 0)
			ripple.BackgroundTransparency = HOVER_STRENGTH - 0.08
			ripple.Visible = true

			local grow = TweenService:Create(
				ripple,
				TweenInfo.new(CLICK_SPEED, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(reach, reach), BackgroundTransparency = 1 }
			)
			grow:Play()
			grow.Completed:Once(function() ripple.Visible = false end)
		end)
	end

	hit.MouseButton1Click:Connect(function()
		if info.callback then task.spawn(info.callback) end
	end)

	local handle = { Frame = shell, Label = label, IgnoreConfig = true }
	function handle:SetText(v) self.Label.Text = v end
	return self:_flag(info.flag, handle, "Button")
end

--=====================================================
--  SWITCH (toggle) - label on the left, square on the right
--=====================================================
function Library:_addToggle(card, info)
	info = info or {}
	local slot = self:_controlSlot(card, LAYOUT.ControlHeight)

	local shell = new("Frame", {
		Name = "Switch",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.TabCard,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = slot,
	}, {
		corner(12),
		plainStroke(THEME.ControlAccent, 1.6, 0),
		padding(0, 14, 0, 14),
	})

	-- RULE 1: the label stops before the square, they never touch
	local label = new("TextLabel", {
		Name = "Label",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, -(LAYOUT.ToggleBox + 12), 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = info.text or "SWITCH",
		TextSize = 17,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = shell,
	})

	local square = new("Frame", {
		Name = "Box",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(LAYOUT.ToggleBox, LAYOUT.ToggleBox),
		BackgroundColor3 = THEME.ControlText,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = shell,
	}, {
		corner(7),
		plainStroke(THEME.ControlAccent, 1.8, 0),
	})
	controlPart(square, "BackgroundColor3")

	local hit = new("TextButton", {
		Name = "Hit",
		Size = UDim2.new(1, 28, 1, 0),
		Position = UDim2.fromOffset(-14, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
		Parent = shell,
	})

	-- SMOOTH SWITCH: soft easing plus a tiny pop, so a click feels gentle
	local fade = TweenInfo.new(TOGGLE_SMOOTH, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local state = info.default and true or false

	local function apply(v, fire, animate)
		state = v and true or false

		if animate == false then
			square.BackgroundTransparency = state and 0.05 or 1
		else
			TweenService:Create(square, fade, { BackgroundTransparency = state and 0.05 or 1 }):Play()

			-- the tick grows in when it turns on, and eases back when it turns off
			local box = LAYOUT.ToggleBox
			local from = state and 0.70 or 1.14
			square.Size = UDim2.fromOffset(math.floor(box * from), math.floor(box * from))
			TweenService:Create(square, fade, { Size = UDim2.fromOffset(box, box) }):Play()
		end

		if fire and info.callback then task.spawn(info.callback, state) end
	end

	apply(state, false, false)
	hit.MouseButton1Click:Connect(function() apply(not state, true) end)

	local handle = { Frame = shell, Label = label, Box = square }
	function handle:Set(v) apply(v, true) end
	function handle:Get() return state end
	function handle:SetText(v) self.Label.Text = v end
	return self:_flag(info.flag, handle, "Toggle")
end

--=====================================================
--  SLIDER
--=====================================================
function Library:_addSlider(card, info)
	info = info or {}
	local slot = self:_controlSlot(card, LAYOUT.SliderHeight)

	local minV = info.min or 0
	local maxV = info.max or 100
	if maxV <= minV then maxV = minV + 1 end
	local value = math.clamp(info.default or minV, minV, maxV)

	local shell = new("Frame", {
		Name = "Slider",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.TabCard,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = slot,
	}, {
		corner(12),
		plainStroke(THEME.ControlAccent, 1.6, 0),
		padding(10, 14, 12, 14),
	})

	local label = new("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, -70, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = info.text or "SLIDER",
		TextSize = 17,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = shell,
	})

	local readout = new("TextLabel", {
		Name = "Value",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(64, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "0",
		TextSize = 16,
		TextColor3 = THEME.ControlText,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = shell,
	})
	controlPart(readout, "TextColor3")

	local track = new("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = THEME.SearchBar,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = shell,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		plainStroke(THEME.ControlAccent, 1.6, 0, false), -- slider track: solid, never faded
	})

	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = THEME.ControlText,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = track,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	controlPart(fill, "BackgroundColor3")

	local knob = new("Frame", {
		Name = "Knob",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = THEME.ControlText,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = track,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	controlPart(knob, "BackgroundColor3")

	local hit = new("TextButton", {
		Name = "Hit",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 10),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 6,
		Parent = shell,
	})

	local function round(v)
		if info.step and info.step > 0 then
			v = math.floor(v / info.step + 0.5) * info.step
		end
		if info.decimals and info.decimals > 0 then
			local m = 10 ^ info.decimals
			return math.floor(v * m + 0.5) / m
		end
		return math.floor(v + 0.5)
	end

	local function apply(v, fire)
		value = math.clamp(round(v), minV, maxV)
		local pct = (value - minV) / (maxV - minV)
		fill.Size = UDim2.fromScale(pct, 1)
		knob.Position = UDim2.new(pct, 0, 0.5, 0)
		readout.Text = tostring(value) .. (info.suffix or "")
		if fire and info.callback then task.spawn(info.callback, value) end
	end

	local dragging = false

	local function setFromX(x)
		local left = track.AbsolutePosition.X
		local width = math.max(1, track.AbsoluteSize.X)
		local pct = math.clamp((x - left) / width, 0, 1)
		apply(minV + (maxV - minV) * pct, true)
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)

	hit.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			setFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	apply(value, false)

	local handle = { Frame = shell, Label = label, Value = readout }
	function handle:Set(v) apply(v, true) end
	function handle:Get() return value end
	function handle:SetText(v) self.Label.Text = v end
	return self:_flag(info.flag, handle, "Slider")
end

--=====================================================
--  EXTRA CONTROLS  (my own design, nothing copied)
--  label / paragraph / divider / input / keybind /
--  dropdown / multi dropdown / color picker
--=====================================================
local EXTRA = {
	LabelHeight    = 34,  -- plain text line
	ParagraphMin   = 64,  -- title + wrapped text (grows on its own)
	DividerHeight  = 16,  -- thin separator line
	InputHeight    = 62,  -- text box with a title above it
	DropdownHeight = 58,  -- closed height of a dropdown
	DropdownRow    = 34,  -- height of one option inside it
	DropdownShow   = 4,   -- how many options fit before it scrolls
	ColorHeight    = 58,  -- closed height of a color picker
	ColorBar       = 16,  -- height of one R / G / B bar
}

-- FLAGS: every control that is given a flag is remembered here, and
-- that list is exactly what the save system writes into a file.
function Library:_flag(flag, handle, class)
	handle.Class = class or handle.Class
	handle.Library = self
	if handle.Destroy == nil then
		function handle:Destroy()
			if self.Frame then self.Frame:Destroy() end
			if self.Flag and self.Library and self.Library.Flags then
				self.Library.Flags[self.Flag] = nil
			end
		end
	end
	if flag == nil then return handle end
	self.Flags = self.Flags or {}
	handle.Flag = flag
	self.Flags[flag] = handle
	return handle
end

function Library:GetFlag(flag)
	local h = self.Flags and self.Flags[flag]
	if h and h.Get then return h:Get() end
	return nil
end

function Library:SetFlag(flag, value)
	local h = self.Flags and self.Flags[flag]
	if h and h.Set then h:Set(value) end
end

--  LABEL  ---------------------------------------------------------
function Library:_addLabel(card, info)
	info = info or {}
	local frame = self:_comboRow(card, EXTRA.LabelHeight)

	local label = new("TextLabel", {
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = info.text or "LABEL",
		TextSize = 17,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = frame,
	})

	local handle = { Frame = frame, Label = label, IgnoreConfig = true }
	function handle:Set(v) self.Label.Text = tostring(v) end
	function handle:Get() return self.Label.Text end
	function handle:SetText(v) self.Label.Text = tostring(v) end
	return self:_flag(info.flag, handle, "Label")
end

--  PARAGRAPH  -----------------------------------------------------
function Library:_addParagraph(card, info)
	info = info or {}
	local frame, rowEntry = self:_comboRow(card, EXTRA.ParagraphMin)

	local shell = new("Frame", {
		Name = "Paragraph",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.TabCard,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = frame,
	}, {
		corner(12),
		plainStroke(THEME.ControlAccent, 1.4, 0),
		padding(10, 14, 10, 14),
	})

	local title = new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = info.title or "INFO",
		TextSize = 16,
		TextColor3 = THEME.ControlText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = shell,
	})
	controlPart(title, "TextColor3")

	local body = new("TextLabel", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = info.text or "",
		TextSize = 15,
		TextColor3 = THEME.SubText,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = shell,
	})

	-- RULE 3: it grows to fit its own text, so words can never spill out
	local function refit()
		local h = math.max(18, math.ceil(body.TextBounds.Y))
		body.Size = UDim2.new(1, 0, 0, h)
		local total = h + 24 + 20
		frame.Size = UDim2.new(1, 0, 0, total)
		if rowEntry then rowEntry.Height = total end
	end
	body:GetPropertyChangedSignal("TextBounds"):Connect(refit)
	task.defer(refit)

	local handle = { Frame = frame, Title = title, Body = body, IgnoreConfig = true }
	function handle:Set(v) body.Text = tostring(v) refit() end
	function handle:Get() return body.Text end
	function handle:SetTitle(v) title.Text = tostring(v) end
	return self:_flag(info.flag, handle, "Paragraph")
end

--  DIVIDER  -------------------------------------------------------
function Library:_addDivider(card)
	local frame = self:_comboRow(card, EXTRA.DividerHeight)

	local line = new("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = THEME.ControlAccent,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = frame,
	})
	controlPart(line, "BackgroundColor3")

	return self:_flag(nil, { Frame = frame, Line = line, IgnoreConfig = true }, "Divider")
end

--  INPUT (text box)  ----------------------------------------------
function Library:_addInput(card, info)
	info = info or {}
	local frame = self:_comboRow(card, EXTRA.InputHeight)

	local shell = new("Frame", {
		Name = "Input",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.TabCard,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = frame,
	}, {
		corner(12),
		plainStroke(THEME.ControlAccent, 1.6, 0),
		padding(8, 14, 10, 14),
	})

	local label = new("TextLabel", {
		Name = "Label",
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = info.text or "INPUT",
		TextSize = 16,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = shell,
	})

	local field = new("TextBox", {
		Name = "Field",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = THEME.SearchBar,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Text = info.default and tostring(info.default) or "",
		PlaceholderText = info.placeholder or "Type here ...",
		PlaceholderColor3 = THEME.SubText,
		TextSize = 15,
		TextColor3 = THEME.ControlText,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 3,
		Parent = shell,
	}, {
		corner(8),
		plainStroke(THEME.ControlAccent, 1.2, 0, false),
		padding(0, 10, 0, 10),
	})
	controlPart(field, "TextColor3")

	field.FocusLost:Connect(function(enter)
		if info.callback then task.spawn(info.callback, field.Text, enter) end
		if info.clearOnEnter and enter then field.Text = "" end
	end)

	local handle = { Frame = frame, Label = label, Field = field }
	function handle:Get() return field.Text end
	function handle:Set(v) field.Text = tostring(v or "") end
	function handle:SetText(v) label.Text = tostring(v) end
	return self:_flag(info.flag, handle, "Input")
end

--  KEYBIND  -------------------------------------------------------
function Library:_addKeybind(card, info)
	info = info or {}
	local slot = self:_controlSlot(card, LAYOUT.ControlHeight)

	local shell = new("Frame", {
		Name = "Keybind",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.TabCard,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = slot,
	}, {
		corner(12),
		plainStroke(THEME.ControlAccent, 1.6, 0),
		padding(0, 12, 0, 14),
	})

	local label = new("TextLabel", {
		Name = "Label",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, -96, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = info.text or "KEYBIND",
		TextSize = 17,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = shell,
	})

	local current = info.default and tostring(info.default) or "None"
	local listening = false

	local keyBtn = new("TextButton", {
		Name = "Key",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(84, 28),
		BackgroundColor3 = THEME.SearchBar,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = Enum.Font.GothamBold,
		Text = current,
		TextSize = 15,
		TextColor3 = THEME.ControlText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 4,
		Parent = shell,
	}, {
		corner(8),
		plainStroke(THEME.ControlAccent, 1.2, 0, false),
	})
	controlPart(keyBtn, "TextColor3")

	keyBtn.MouseButton1Click:Connect(function()
		listening = true
		keyBtn.Text = "..."
	end)

	UserInputService.InputBegan:Connect(function(input, typing)
		if typing then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

		if listening then
			listening = false
			current = input.KeyCode.Name
			keyBtn.Text = current
			if info.onChange then task.spawn(info.onChange, current) end
			return
		end

		if current ~= "None" and input.KeyCode.Name == current then
			if info.callback then task.spawn(info.callback, current) end
		end
	end)

	local handle = { Frame = shell, Label = label, Key = keyBtn }
	function handle:Get() return current end
	function handle:Set(v)
		current = tostring(v or "None")
		keyBtn.Text = current
	end
	function handle:SetText(v) label.Text = tostring(v) end
	return self:_flag(info.flag, handle, "Keybind")
end

--  DROPDOWN (single choice, or multi choice)  ---------------------
function Library:_addDropdown(card, info)
	info = info or {}
	local multi = info.multi and true or false
	local rowH = EXTRA.DropdownHeight
	local frame, rowEntry = self:_comboRow(card, rowH)

	local opts = {}
	for i, v in ipairs(info.options or {}) do opts[i] = tostring(v) end

	local shell = new("Frame", {
		Name = "Dropdown",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.TabCard,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = frame,
	}, {
		corner(12),
		plainStroke(THEME.ControlAccent, 1.6, 0),
	})

	local label = new("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -50, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = info.text or "DROPDOWN",
		TextSize = 16,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = shell,
	})

	local valueLabel = new("TextLabel", {
		Name = "Value",
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.new(1, -50, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "None",
		TextSize = 15,
		TextColor3 = THEME.ControlText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = shell,
	})
	controlPart(valueLabel, "TextColor3")

	local arrow = new("TextLabel", {
		Name = "Arrow",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 18),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "v",
		TextSize = 16,
		TextColor3 = THEME.ControlText,
		ZIndex = 3,
		Parent = shell,
	})
	controlPart(arrow, "TextColor3")

	local list = new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(14, rowH - 4),
		Size = UDim2.new(1, -28, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = THEME.ControlAccent,
		Visible = false,
		ZIndex = 3,
		Parent = shell,
	})

	local selected
	if multi then
		selected = {}
		if type(info.default) == "table" then
			for _, v in ipairs(info.default) do selected[tostring(v)] = true end
		end
	else
		selected = info.default and tostring(info.default) or (opts[1] or "")
	end

	local open = false
	local buttons = {}

	local function getValue()
		if not multi then return selected end
		local out = {}
		for _, n in ipairs(opts) do
			if selected[n] then out[#out + 1] = n end
		end
		return out
	end

	local function textOf()
		if not multi then
			return (selected ~= "" and selected) or "None"
		end
		local picked = getValue()
		if #picked == 0 then return "None" end
		return table.concat(picked, ", ")
	end

	local function refreshMarks()
		for name, btn in pairs(buttons) do
			local on
			if multi then on = (selected[name] == true) else on = (selected == name) end
			btn.BackgroundTransparency = on and 0.2 or 0.8
		end
		valueLabel.Text = textOf()
	end

	local function resize()
		local step = EXTRA.DropdownRow + 4
		local rows = math.min(#opts, EXTRA.DropdownShow)
		local h = open and (rows * step + 4) or 0
		list.Visible = open
		list.Size = UDim2.new(1, -28, 0, h)
		list.CanvasSize = UDim2.new(0, 0, 0, #opts * step)
		local total = rowH + h + (open and 8 or 0)
		frame.Size = UDim2.new(1, 0, 0, total)
		if rowEntry then rowEntry.Height = total end
		arrow.Text = open and "^" or "v"
	end

	local function choose(name)
		if multi then
			if selected[name] then selected[name] = nil else selected[name] = true end
		else
			selected = name
			open = false
			resize()
		end
		refreshMarks()
		if info.callback then task.spawn(info.callback, getValue()) end
	end

	local function rebuild()
		for _, b in pairs(buttons) do b:Destroy() end
		buttons = {}
		local step = EXTRA.DropdownRow + 4
		for i, name in ipairs(opts) do
			local btn = new("TextButton", {
				Name = "Opt" .. i,
				Position = UDim2.fromOffset(0, (i - 1) * step),
				Size = UDim2.new(1, -6, 0, EXTRA.DropdownRow),
				BackgroundColor3 = THEME.ControlAccent,
				BackgroundTransparency = 0.8,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = Enum.Font.GothamMedium,
				Text = name,
				TextSize = 15,
				TextColor3 = THEME.Text,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 4,
				Parent = list,
			}, { corner(8) })
			controlPart(btn, "BackgroundColor3")
			buttons[name] = btn
			btn.MouseButton1Click:Connect(function() choose(name) end)
		end
		refreshMarks()
		resize()
	end

	local hit = new("TextButton", {
		Name = "Hit",
		Size = UDim2.new(1, 0, 0, rowH),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
		Parent = shell,
	})
	hit.MouseButton1Click:Connect(function()
		open = not open
		resize()
	end)

	rebuild()

	local handle = { Frame = frame, Shell = shell, Label = label }
	function handle:Get() return getValue() end
	function handle:Set(v)
		if multi then
			selected = {}
			if type(v) == "table" then
				for _, n in ipairs(v) do selected[tostring(n)] = true end
			end
		else
			selected = tostring(v or "")
		end
		refreshMarks()
	end
	function handle:SetOptions(newOpts)
		opts = {}
		for i, v in ipairs(newOpts or {}) do opts[i] = tostring(v) end
		if (not multi) and (not table.find(opts, selected)) then
			selected = opts[1] or ""
		end
		rebuild()
	end
	function handle:GetOptions() return opts end
	function handle:SetText(v) label.Text = tostring(v) end
	return self:_flag(info.flag, handle, "Dropdown")
end

--  COLOR PICKER (three simple R / G / B bars)  --------------------
function Library:_addColorPicker(card, info)
	info = info or {}
	local rowH = EXTRA.ColorHeight
	local frame, rowEntry = self:_comboRow(card, rowH)
	local colorValue = info.default or Color3.fromRGB(228, 44, 44)

	local shell = new("Frame", {
		Name = "ColorPicker",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = THEME.TabCard,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = frame,
	}, {
		corner(12),
		plainStroke(THEME.ControlAccent, 1.6, 0),
	})

	local label = new("TextLabel", {
		Name = "Label",
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -80, 0, rowH),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = info.text or "COLOR",
		TextSize = 17,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = shell,
	})

	local swatch = new("Frame", {
		Name = "Swatch",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, math.floor((rowH - 26) / 2)),
		Size = UDim2.fromOffset(44, 26),
		BackgroundColor3 = colorValue,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = shell,
	}, {
		corner(8),
		plainStroke(THEME.ControlAccent, 1.2, 0, false),
	})

	local open = false
	local setters = {}

	local function fire()
		swatch.BackgroundColor3 = colorValue
		if info.callback then task.spawn(info.callback, colorValue) end
	end

	local function makeBar(index, channel, tint)
		local y = rowH + (index - 1) * (EXTRA.ColorBar + 8)

		local track = new("Frame", {
			Name = channel,
			Position = UDim2.fromOffset(14, y),
			Size = UDim2.new(1, -28, 0, EXTRA.ColorBar),
			BackgroundColor3 = THEME.SearchBar,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 3,
			Parent = shell,
		}, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			plainStroke(THEME.ControlAccent, 1.2, 0, false),
		})

		local fill = new("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = tint,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = track,
		}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

		local hit = new("TextButton", {
			Name = "Hit",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 5,
			Parent = track,
		})

		local dragging = false
		local function setFrom(x)
			local left = track.AbsolutePosition.X
			local w = math.max(1, track.AbsoluteSize.X)
			local pct = math.clamp((x - left) / w, 0, 1)
			fill.Size = UDim2.fromScale(pct, 1)

			local r, g, b = colorValue.R, colorValue.G, colorValue.B
			if channel == "R" then
				r = pct
			elseif channel == "G" then
				g = pct
			else
				b = pct
			end
			colorValue = Color3.new(r, g, b)
			fire()
		end

		hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFrom(input.Position.X)
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch then
				setFrom(input.Position.X)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)

		setters[index] = function(pct, show)
			fill.Size = UDim2.fromScale(pct, 1)
			if show ~= nil then track.Visible = show end
		end
	end

	makeBar(1, "R", Color3.fromRGB(255, 70, 70))
	makeBar(2, "G", Color3.fromRGB(70, 255, 120))
	makeBar(3, "B", Color3.fromRGB(80, 140, 255))

	local function paint(show)
		setters[1](colorValue.R, show)
		setters[2](colorValue.G, show)
		setters[3](colorValue.B, show)
	end

	local function resize()
		local total = rowH
		if open then total = rowH + 3 * (EXTRA.ColorBar + 8) + 6 end
		frame.Size = UDim2.new(1, 0, 0, total)
		if rowEntry then rowEntry.Height = total end
		paint(open)
	end

	local hit = new("TextButton", {
		Name = "Hit",
		Size = UDim2.new(1, 0, 0, rowH),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 5,
		Parent = shell,
	})
	hit.MouseButton1Click:Connect(function()
		open = not open
		resize()
	end)

	resize()

	local handle = { Frame = frame, Label = label, Swatch = swatch }
	function handle:Get() return colorValue end
	function handle:Set(v)
		if typeof(v) == "Color3" then
			colorValue = v
			swatch.BackgroundColor3 = v
			paint(nil)
		end
	end
	function handle:SetText(v) label.Text = tostring(v) end
	return self:_flag(info.flag, handle, "ColorPicker")
end

--=====================================================
--  SAVE / LOAD SCRIPT SETTINGS  (config system)
--  works on any executor that has file functions.
--  in Roblox Studio it is skipped safely.
--=====================================================
local FS = {
	write      = writefile,
	read       = readfile,
	isFile     = isfile,
	isFolder   = isfolder,
	makeFolder = makefolder,
	list       = listfiles,
	del        = delfile,
}

local function fsReady()
	return type(FS.write) == "function"
		and type(FS.read) == "function"
		and type(FS.isFile) == "function"
end

-- JSON cannot hold a Color3, so values get packed into plain data first
local function packValue(v)
	if typeof(v) == "Color3" then
		return {
			__type = "Color3",
			r = math.floor(v.R * 255 + 0.5),
			g = math.floor(v.G * 255 + 0.5),
			b = math.floor(v.B * 255 + 0.5),
		}
	end
	if typeof(v) == "EnumItem" then
		return { __type = "Enum", name = v.Name }
	end
	if type(v) == "table" then
		local out = {}
		for i, item in ipairs(v) do out[i] = packValue(item) end
		return { __type = "List", data = out }
	end
	return v
end

local function unpackValue(v)
	if type(v) == "table" then
		if v.__type == "Color3" then return Color3.fromRGB(v.r or 0, v.g or 0, v.b or 0) end
		if v.__type == "Enum" then return v.name end
		if v.__type == "List" then
			local out = {}
			for i, item in ipairs(v.data or {}) do out[i] = unpackValue(item) end
			return out
		end
	end
	return v
end

-- change where the files live:  ui:SetFolder("MyHub")
function Library:SetFolder(name)
	self.Folder = name or "NexusPlayHub"
	self:_ensureFolders()
	return self.Folder
end

function Library:_ensureFolders()
	if not fsReady() then return false end
	local root = self.Folder or "NexusPlayHub"
	if type(FS.isFolder) == "function" and type(FS.makeFolder) == "function" then
		if not FS.isFolder(root) then FS.makeFolder(root) end
		if not FS.isFolder(root .. "/configs") then FS.makeFolder(root .. "/configs") end
	end
	return true
end

function Library:_configPath(name)
	return (self.Folder or "NexusPlayHub") .. "/configs/" .. tostring(name) .. ".json"
end

function Library:_autoloadPath()
	return (self.Folder or "NexusPlayHub") .. "/autoload.txt"
end

-- ui:SaveConfig("my setup")
function Library:SaveConfig(name)
	if not fsReady() then return false, "This executor cannot save files" end
	name = name or self.ConfigName or "default"
	if name == "" then return false, "Give the config a name first" end
	self:_ensureFolders()

	local data = { version = 1, values = {} }
	for flag, h in pairs(self.Flags or {}) do
		if (not h.IgnoreConfig) and h.Get then
			local ok, value = pcall(function() return h:Get() end)
			if ok then
				data.values[flag] = { class = h.Class or "Value", value = packValue(value) }
			end
		end
	end

	local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
	if not ok then return false, "Could not turn the settings into JSON" end

	local written = pcall(function() FS.write(self:_configPath(name), encoded) end)
	if not written then return false, "Could not write the file" end

	self.ConfigName = name
	return true
end

-- ui:LoadConfig("my setup")
function Library:LoadConfig(name)
	if not fsReady() then return false, "This executor cannot read files" end
	name = name or self.ConfigName
	if (not name) or name == "" then return false, "Pick a config first" end

	local path = self:_configPath(name)
	if not FS.isFile(path) then return false, "That config does not exist" end

	local ok, decoded = pcall(function() return HttpService:JSONDecode(FS.read(path)) end)
	if (not ok) or type(decoded) ~= "table" then return false, "That config file is damaged" end

	for flag, entry in pairs(decoded.values or {}) do
		local h = self.Flags and self.Flags[flag]
		if h and h.Set then
			local value = unpackValue(entry.value)
			task.spawn(function() pcall(function() h:Set(value) end) end)
		end
	end

	self.ConfigName = name
	return true
end

function Library:DeleteConfig(name)
	if (not fsReady()) or type(FS.del) ~= "function" then return false, "Not supported here" end
	if (not name) or name == "" then return false, "Pick a config first" end
	local path = self:_configPath(name)
	if not FS.isFile(path) then return false, "That config does not exist" end
	pcall(function() FS.del(path) end)
	return true
end

-- returns a plain list of every saved config name
function Library:ListConfigs()
	local out = {}
	if (not fsReady()) or type(FS.list) ~= "function" then return out end
	self:_ensureFolders()

	local ok, files = pcall(function()
		return FS.list((self.Folder or "NexusPlayHub") .. "/configs")
	end)
	if (not ok) or type(files) ~= "table" then return out end

	for _, path in ipairs(files) do
		if type(path) == "string" and path:sub(-5) == ".json" then
			local name = path:match("([^/\\]+)%.json$")
			if name then out[#out + 1] = name end
		end
	end
	table.sort(out)
	return out
end

-- AUTOLOAD: the chosen config is applied by itself on the next execute
function Library:SetAutoload(name)
	if not fsReady() then return false end
	self:_ensureFolders()
	pcall(function() FS.write(self:_autoloadPath(), tostring(name)) end)
	return true
end

function Library:GetAutoload()
	if not fsReady() then return nil end
	local path = self:_autoloadPath()
	if not FS.isFile(path) then return nil end
	local ok, name = pcall(function() return FS.read(path) end)
	if ok and name and name ~= "" then return name end
	return nil
end

function Library:ClearAutoload()
	if (not fsReady()) or type(FS.del) ~= "function" then return false end
	local path = self:_autoloadPath()
	if FS.isFile(path) then pcall(function() FS.del(path) end) end
	return true
end

function Library:LoadAutoload(quiet)
	local name = self:GetAutoload()
	if not name then return false end
	local ok, err = self:LoadConfig(name)
	if not quiet then
		if ok then
			self:Notify({ text = "Loaded your saved settings: " .. name })
		else
			self:Notify({ text = "Autoload failed: " .. tostring(err) })
		end
	end
	return ok
end

-- AUTO SAVE: keeps writing your current settings in the background
function Library:AutoSave(on, name, every)
	self.AutoSaveOn = on and true or false
	if name then self.ConfigName = name end
	self.AutoSaveEvery = every or 5

	if not self.AutoSaveOn then return end
	if self.AutoSaveRunning then return end
	self.AutoSaveRunning = true

	task.spawn(function()
		while self.AutoSaveOn and not self.Destroyed do
			task.wait(self.AutoSaveEvery)
			if self.AutoSaveOn and self.ConfigName then
				pcall(function() self:SaveConfig(self.ConfigName) end)
			end
		end
		self.AutoSaveRunning = false
	end)
end

--=====================================================
--  KEY TO OPEN / CLOSE, THEME COLOR, CLEAN EXIT
--=====================================================

-- ui:SetToggleKey("RightShift")
function Library:SetToggleKey(key)
	self.ToggleKey = key or "RightShift"
	if self._toggleConn then pcall(function() self._toggleConn:Disconnect() end) end

	self._toggleConn = UserInputService.InputBegan:Connect(function(input, typing)
		if typing or self.Destroyed then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode.Name == self.ToggleKey then self:Toggle() end
	end)

	return self.ToggleKey
end

-- ui:SetAccent(Color3.fromRGB(228, 44, 44))
function Library:SetAccent(color)
	if typeof(color) ~= "Color3" then return end
	THEME.Accent = color
	THEME.ControlAccent = color
	THEME.ControlText = color

	for _, item in ipairs(CONTROL_STROKES) do
		pcall(function()
			item.stroke.Color = color
			if item.grad then item.grad.Color = ColorSequence.new(color) end
		end)
	end
	pcall(function() refreshControlColors() end)
end

-- ui:Destroy()  - removes everything and stops every loop
function Library:Destroy()
	self.Destroyed = true
	self.AutoSaveOn = false
	if self._toggleConn then pcall(function() self._toggleConn:Disconnect() end) end
	if self.Gui then pcall(function() self.Gui:Destroy() end) end
end

--=====================================================
--  CREDITS PAGE
--=====================================================
function Library:_buildCreditsPage()
	local page = new("Frame", {
		Name = "CreditsPage",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ClipsDescendants = true,
		Parent = self.Content,
	})
	self.PageFrames[TEXT.Nav[3] or "Credits"] = page

	-- everything is stacked in the middle of the page
	local holder = new("Frame", {
		Name = "CreditsHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = page,
	}, {
		padding(28, 0, 0, 0),
		vlist(10, Enum.HorizontalAlignment.Center),
	})

	--------------------------------------------------
	-- 1) ROUND PROFILE PICTURE WITH A SPINNING LASER RING
	--------------------------------------------------
	local box = CREDITS.AvatarBox

	local avatarWrap = new("Frame", {
		Name = "Avatar",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(box, box),
		BackgroundTransparency = 1,
		Parent = holder,
	})

	-- the laser colours that sweep around the circle
	local laserColors = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, THEME.Accent),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.50, THEME.Accent),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(120, 0, 0)),
		ColorSequenceKeypoint.new(1.00, THEME.Accent),
	})

	-- makes one glowing ring and spins its gradient forever
	local function laserRing(name, inset, thickness, speed, backwards)
		local ringGradient = new("UIGradient", {
			Color = laserColors,
			Rotation = 0,
		})

		local ringStroke = new("UIStroke", {
			Thickness = thickness,
			Color = Color3.fromRGB(255, 255, 255),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, { ringGradient })

		local ring = new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -inset, 1, -inset),
			BackgroundTransparency = 1,
			Parent = avatarWrap,
		}, {
			new("UICorner", { CornerRadius = UDim.new(1, 0) }),
			ringStroke,
		})

		-- spin the laser
		ringGradient.Rotation = backwards and 360 or 0
		TweenService:Create(
			ringGradient,
			TweenInfo.new(speed, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Rotation = backwards and 0 or 360 }
		):Play()

		return ring
	end

	laserRing("RingOuter", 0, 3, CREDITS.LaserSpeed, false)
	laserRing("RingInner", 14, 2, CREDITS.LaserSpeed * 1.6, true)

	-- the logo itself, clipped into a perfect circle
	self.CreditsAvatar = new("ImageLabel", {
		Name = "Photo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -26, 1, -26),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Image = img(CREDITS.Avatar),
		ScaleType = Enum.ScaleType.Crop,
		ClipsDescendants = true,
		Parent = avatarWrap,
	}, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})

	--------------------------------------------------
	-- 2) THE NAME, IN A STYLISH FONT WITH A RED GRADIENT
	--------------------------------------------------
	self.CreditsName = new("TextLabel", {
		Name = "Name",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, CREDITS.NameSize + 14),
		BackgroundTransparency = 1,
		Font = CREDITS.NameFont,
		Text = CREDITS.Name,
		TextSize = CREDITS.NameSize,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Parent = holder,
	}, {
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, THEME.Accent),
			}),
			Rotation = 90,
		}),
		new("UIStroke", {
			Color = THEME.Accent,
			Thickness = 1.4,
			Transparency = 0.35,
		}),
	})

	-- small line under the name
	self.CreditsRole = new("TextLabel", {
		Name = "Role",
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = CREDITS.Role,
		TextSize = 13,
		TextColor3 = THEME.Accent,
		Parent = holder,
	})

	--------------------------------------------------
	-- 3) THE DESCRIPTION UNDER THE NAME
	--------------------------------------------------
	self.CreditsLabel = new("TextLabel", {
		Name = "Credits",
		LayoutOrder = 4,
		Size = UDim2.new(0.86, 0, 0, 150),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = table.concat(CREDITS.Lines, "\n"),
		TextSize = 15,
		TextColor3 = THEME.Text,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.25,
		Parent = holder,
	})
end

--=====================================================
--  FIT TO SCREEN - same look everywhere, only bigger or smaller
--=====================================================
function Library:_fitToScreen()
	local scaleObj = self.Main:FindFirstChild("Scale")
	if not scaleObj then return end

	local camera = workspace.CurrentCamera
	local viewport = (camera and camera.ViewportSize) or Vector2.new(1280, 720)

	local designW = LAYOUT.PanelWidth
	local designH = self.PanelHeight or 575

	local fit = math.min(
		(viewport.X * SCREEN_FILL) / designW,
		(viewport.Y * SCREEN_FILL) / designH
	)

	-- BaseScale is the real resting size. the open / hide animation borrows
	-- this same UIScale, so we never overwrite it mid animation.
	self.BaseScale = math.clamp(fit, MIN_SCALE, MAX_SCALE) * UI_SIZE
	if not self.Animating then
		scaleObj.Scale = self.BaseScale
	end

	self.Main.AnchorPoint = Vector2.new(0.5, 0.5)
	self.Main.Position = UDim2.fromScale(0.5, 0.5)
end

--=====================================================
--  APPLY LAYOUT - call this after changing any LAYOUT number
--=====================================================
function Library:_applyLayout()
	-- RULE 2: sections grow to fit their images, so they can never collide
	local headerH = math.max(LAYOUT.HeaderHeight, LAYOUT.LogoHeight)
	local heroH   = math.max(LAYOUT.HeroHeight, LAYOUT.BannerHeight + math.abs(LAYOUT.BannerOffsetY) * 2)

	local panelH = (LAYOUT.PanelPadding * 2)
		+ headerH + LAYOUT.GAP
		+ heroH + LAYOUT.GAP
		+ LAYOUT.CardsHeight
		+ (LAYOUT.PanelExtraHeight or 0) -- makes the panel taller, so the control box has room to grow down

	self.PanelHeight = panelH
	self.Main.Size = UDim2.fromOffset(LAYOUT.PanelWidth, panelH)
	self:_fitToScreen()

	self.Header.Size = UDim2.new(1, 0, 0, headerH)
	self.Logo.Size   = UDim2.fromOffset(LAYOUT.LogoWidth, LAYOUT.LogoHeight)

	self.Content.Position = UDim2.fromOffset(0, headerH + LAYOUT.GAP)
	self.Content.Size     = UDim2.new(1, 0, 1, -(headerH + LAYOUT.GAP))

	self.Hero.Size = UDim2.new(1, 0, 0, heroH)

	-- RULE 1: the -GAP keeps the text away from the banner
	self.Left.Size   = UDim2.new(LAYOUT.HeroLeftWidth, -LAYOUT.GAP, 1, 0)
	self.Banner.Size = UDim2.new(LAYOUT.BannerWidth, 0, 0, LAYOUT.BannerHeight)
	self.Banner.Position = UDim2.new(1, 0, 0.5, LAYOUT.BannerOffsetY)

	self.Socials.Size = UDim2.new(1, 0, 0, LAYOUT.SocialBox + LAYOUT.SocialOffsetY)
	for _, box in ipairs(self.SocialBoxes) do
		box.Size = UDim2.fromOffset(LAYOUT.SocialBox, LAYOUT.SocialBox)
	end

	self.CardRow.Size = UDim2.new(1, -6, 0, LAYOUT.CardsHeight)
	self.CardRow.Position = UDim2.new(0, 3, 1, -3)
	for _, slot in ipairs(self.IconSlots) do
		slot.Size = UDim2.fromOffset(LAYOUT.CardIcon, LAYOUT.CardIcon)
	end
	for _, col in ipairs(self.TextCols) do
		col.Size = UDim2.new(1, -(LAYOUT.CardIcon + LAYOUT.GAP), 1, 0)
	end

	if self.Warning then
		local total = LAYOUT.HeroLeftWidth + LAYOUT.BannerWidth
		if total > 1 then
			self.Warning.Text = string.format("WARNING: text + banner = %.2f. Keep it at 1.00 or less.", total)
			self.Warning.TextColor3 = Color3.fromRGB(255, 120, 120)
		else
			self.Warning.Text = string.format("OK: text + banner = %.2f | panel height %d", total, panelH)
			self.Warning.TextColor3 = Color3.fromRGB(120, 220, 150)
		end
	end

	if self.Summary then
		self.Summary.Text = string.format(
			"BannerWidth=%.2f  BannerHeight=%d  LogoWidth=%d  LogoHeight=%d  CardIcon=%d  SocialBox=%d  TextColumn=%.2f  Gap=%d  HeroHeight=%d",
			LAYOUT.BannerWidth, LAYOUT.BannerHeight,
			LAYOUT.LogoWidth, LAYOUT.LogoHeight,
			LAYOUT.CardIcon, LAYOUT.SocialBox,
			LAYOUT.HeroLeftWidth, LAYOUT.GAP, LAYOUT.HeroHeight
		)
	end
end

--=====================================================
--  TEMPORARY COLOR TUNER (right side of the screen)
--  OUTLINE = the line around a button / switch / slider
--  FILL    = button text, switch tick, slider bar and knob
--=====================================================
function Library:_buildColorTuner()
	local tuner = new("Frame", {
		Name = "ColorTuner",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 90),
		Size = UDim2.fromOffset(276, 330),
		BackgroundColor3 = THEME.TunerBg,
		BorderSizePixel = 0,
		Active = true,
		Parent = self.Gui,
	}, {
		corner(14),
		stroke(THEME.ControlAccent, 2, 0.15),
		padding(12, 12, 12, 12),
	})

	local title = new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "COLOR TUNER  (drag me)",
		TextSize = 15,
		TextColor3 = THEME.ControlAccent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tuner,
	})
	makeDraggable(tuner, title)

	new("TextLabel", {
		Name = "Hint",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "0 - 255, press Enter after each box.",
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tuner,
	})

	local rows = new("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		Parent = tuner,
	}, { vlist(6) })

	local order = 0

	local function addHeading(text)
		order = order + 1
		new("TextLabel", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Text = text,
			TextSize = 13,
			TextColor3 = THEME.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = rows,
		})
	end

	local function addRow(labelText, themeKey, channel)
		order = order + 1
		local row = new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Parent = rows,
		}, { hlist(8) })

		new("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(0.56, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = labelText,
			TextSize = 13,
			TextColor3 = THEME.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		local function channelValue()
			local c = THEME[themeKey]
			local v = (channel == "R" and c.R) or (channel == "G" and c.G) or c.B
			return math.floor(v * 255 + 0.5)
		end

		local box = new("TextBox", {
			Name = channel,
			LayoutOrder = 2,
			Size = UDim2.new(0.40, 0, 1, 0),
			BackgroundColor3 = THEME.TunerField,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			Text = tostring(channelValue()),
			TextSize = 13,
			TextColor3 = THEME.Text,
			ClearTextOnFocus = false,
			Parent = row,
		}, { corner(6), stroke(THEME.Stroke, 1, 0.3) })

		box.FocusLost:Connect(function()
			local n = tonumber(box.Text)
			if n then
				n = math.clamp(math.floor(n), 0, 255) / 255
				local c = THEME[themeKey]
				if channel == "R" then
					THEME[themeKey] = Color3.new(n, c.G, c.B)
				elseif channel == "G" then
					THEME[themeKey] = Color3.new(c.R, n, c.B)
				else
					THEME[themeKey] = Color3.new(c.R, c.G, n)
				end
				refreshControlColors()
			end
			box.Text = tostring(channelValue())
		end)
	end

	addHeading("OUTLINE")
	addRow("Red", "ControlAccent", "R")
	addRow("Green", "ControlAccent", "G")
	addRow("Blue", "ControlAccent", "B")

	addHeading("TEXT / TICK / SLIDER BAR")
	addRow("Red", "ControlText", "R")
	addRow("Green", "ControlText", "G")
	addRow("Blue", "ControlText", "B")

	self.ColorTuner = tuner
end

--=====================================================
--  TEMPORARY BOX TUNER (right side of the screen)
--  change the numbers, tell me the ones you like,
--  and I will bake them in and delete this panel.
--=====================================================
function Library:_buildBoxTuner()
	local tuner = new("Frame", {
		Name = "BoxTuner",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 90),
		Size = UDim2.fromOffset(286, 346),
		BackgroundColor3 = THEME.TunerBg,
		BorderSizePixel = 0,
		Active = true,
		Parent = self.Gui,
	}, {
		corner(14),
		stroke(THEME.ControlAccent, 2, 0.15),
		padding(12, 12, 12, 12),
	})

	local title = new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "BOX TUNER  (drag me)",
		TextSize = 15,
		TextColor3 = THEME.ControlAccent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tuner,
	})
	makeDraggable(tuner, title)

	new("TextLabel", {
		Name = "Hint",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Type a number, press Enter. Open a tab first.",
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tuner,
	})

	local rows = new("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		Parent = tuner,
	}, { vlist(6) })

	local order = 0

	local function addRow(labelText, layoutKey, low, high)
		order = order + 1
		local row = new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Parent = rows,
		}, { hlist(8) })

		new("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(0.60, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = labelText,
			TextSize = 13,
			TextColor3 = THEME.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		local box = new("TextBox", {
			Name = layoutKey,
			LayoutOrder = 2,
			Size = UDim2.new(0.36, 0, 1, 0),
			BackgroundColor3 = THEME.TunerField,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			Text = tostring(LAYOUT[layoutKey]),
			TextSize = 13,
			TextColor3 = THEME.Text,
			ClearTextOnFocus = false,
			Parent = row,
		}, { corner(6), stroke(THEME.Stroke, 1, 0.3) })

		box.FocusLost:Connect(function()
			local n = tonumber(box.Text)
			if n then
				-- decimals are allowed: 0.1, 0.5, 320.5 all work.
				-- kept to 2 decimal places so the field stays readable.
				n = math.clamp(n, low, high)
				LAYOUT[layoutKey] = math.floor(n * 100 + 0.5) / 100
				self:_refreshControlBoxes()
			end
			box.Text = tostring(LAYOUT[layoutKey])
		end)
	end

	-- a real drag slider, because typing numbers for this one was confusing
	local function addSlider(labelText, layoutKey, low, high)
		order = order + 1
		local row = new("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundTransparency = 1,
			Parent = rows,
		})

		local label = new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = labelText .. "   " .. string.format("%.2f", LAYOUT[layoutKey] or 1),
			TextSize = 13,
			TextColor3 = THEME.SubText,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		local track = new("Frame", {
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, 0, 0, 10),
			BackgroundColor3 = THEME.TunerField,
			BorderSizePixel = 0,
			Parent = row,
		}, { corner(5), stroke(THEME.Stroke, 1, 0.3) })

		local start = math.clamp(((LAYOUT[layoutKey] or 1) - low) / (high - low), 0, 1)

		local fill = new("Frame", {
			Size = UDim2.fromScale(start, 1),
			BackgroundColor3 = THEME.ControlText,
			BorderSizePixel = 0,
			Parent = track,
		}, { corner(5) })

		local knob = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(start, 0, 0.5, 0),
			Size = UDim2.fromOffset(15, 15),
			BackgroundColor3 = THEME.ControlText,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = track,
		}, { corner(8) })

		local hit = new("TextButton", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 4,
			Parent = track,
		})

		local function setFromX(x)
			local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
			local value = low + (high - low) * rel
			value = math.floor(value * 100 + 0.5) / 100

			LAYOUT[layoutKey] = value
			fill.Size = UDim2.fromScale(rel, 1)
			knob.Position = UDim2.new(rel, 0, 0.5, 0)
			label.Text = labelText .. "   " .. string.format("%.2f", value)
			self:_refreshControlBoxes()
		end

		local dragging = false

		hit.MouseButton1Down:Connect(function(x)
			dragging = true
			setFromX(x)
		end)

		UserInputService.InputChanged:Connect(function(input)
			if not dragging then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch then
				setFromX(input.Position.X)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	end

	-- drag this one: 0.10 = smallest, 3.00 = triple size
	addSlider("Box size", "ControlBoxScale", 0.1, 3)

	addRow("Box height", "ControlBoxHeight", 0, 2000)
	addRow("Panel extra height", "PanelExtraHeight", 0, 1200)
	addRow("Inside padding", "ControlBoxPad", 0, 60)
	addRow("Gap between rows", "ControlGap", 0, 60)
	addRow("Button / switch height", "ControlHeight", 10, 300)
	addRow("Slider height", "SliderHeight", 10, 300)

	self.BoxTuner = tuner
end

--=====================================================
--  TEMPORARY FADE TUNER (right side of the screen)
--  change the three numbers, tell me the ones you like,
--  and I will bake them in and delete this panel.
--=====================================================
function Library:_buildStrokeTuner()
	local tuner = new("Frame", {
		Name = "FadeTuner",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 90),
		Size = UDim2.fromOffset(268, 178),
		BackgroundColor3 = THEME.TunerBg,
		BorderSizePixel = 0,
		Active = true,
		Parent = self.Gui,
	}, {
		corner(14),
		stroke(THEME.ControlAccent, 2, 0.15),
		padding(12, 12, 12, 12),
	})

	local title = new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "FADE TUNER  (drag me)",
		TextSize = 15,
		TextColor3 = THEME.ControlAccent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tuner,
	})
	makeDraggable(tuner, title)

	new("TextLabel", {
		Name = "Hint",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Type a number, press Enter.",
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tuner,
	})

	local rows = new("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		Parent = tuner,
	}, { vlist(8) })

	local order = 0
	local function addRow(labelText, key)
		order = order + 1
		local row = new("Frame", {
			Name = key,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Parent = rows,
		}, { hlist(8) })

		new("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(0.56, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = labelText,
			TextSize = 13,
			TextColor3 = THEME.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})

		local box = new("TextBox", {
			Name = "Input",
			LayoutOrder = 2,
			Size = UDim2.new(0.40, 0, 1, 0),
			BackgroundColor3 = THEME.TunerField,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			Text = string.format("%.2f", STROKE_FADE[key]),
			TextSize = 13,
			TextColor3 = THEME.Text,
			ClearTextOnFocus = false,
			Parent = row,
		}, { corner(6), stroke(THEME.Stroke, 1, 0.3) })

		box.FocusLost:Connect(function()
			local n = tonumber(box.Text)
			if n then
				STROKE_FADE[key] = math.clamp(n, 0, 1)
				refreshStrokeFade()
			end
			box.Text = string.format("%.2f", STROKE_FADE[key])
		end)
	end

	addRow("Fade transparency", "Amount")
	addRow("Fade position", "Position")
	addRow("Fade size", "Size")

	self.FadeTuner = tuner
end

--=====================================================
--  OPTIONAL SIZE TUNER (SHOW_TUNER = true to use it)
--=====================================================
function Library:_buildTuner()
	local tuner = new("Frame", {
		Name = "SizeTuner",
		Position = UDim2.fromOffset(24, 90),
		Size = UDim2.fromOffset(320, 430),
		BackgroundColor3 = THEME.TunerBg,
		BorderSizePixel = 0,
		Active = true,
		Parent = self.Gui,
	}, {
		corner(14),
		stroke(THEME.Accent, 2, 0.15),
		padding(12, 12, 12, 12),
	})

	local title = new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = "SIZE TUNER  (drag me)",
		TextSize = 15,
		TextColor3 = THEME.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tuner,
	})
	makeDraggable(tuner, title)

	new("TextLabel", {
		Name = "Hint",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Text = "Type a number, press Enter.",
		TextSize = 12,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tuner,
	})

	local rows = new("Frame", {
		Name = "Rows",
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -140),
		BackgroundTransparency = 1,
		Parent = tuner,
	}, { vlist(6) })

	local order = 0
	local function addRow(labelText, key, isScale)
		order = order + 1
		local row = new("Frame", {
			Name = key,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundTransparency = 1,
			Parent = rows,
		}, { hlist(8) })

		new("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(0.58, 0, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Text = labelText,
			TextSize = 13,
			TextColor3 = THEME.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})

		local box = new("TextBox", {
			Name = "Input",
			LayoutOrder = 2,
			Size = UDim2.new(0.38, 0, 1, 0),
			BackgroundColor3 = THEME.TunerField,
			BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium,
			Text = isScale and string.format("%.2f", LAYOUT[key]) or tostring(LAYOUT[key]),
			TextSize = 13,
			TextColor3 = THEME.Text,
			ClearTextOnFocus = false,
			Parent = row,
		}, { corner(6), stroke(THEME.Stroke, 1, 0.3) })

		box.FocusLost:Connect(function()
			local n = tonumber(box.Text)
			if n then
				if isScale then
					n = math.clamp(n, 0.05, 1)
					LAYOUT[key] = n
					box.Text = string.format("%.2f", n)
				else
					n = math.floor(math.clamp(n, -400, 2000))
					LAYOUT[key] = n
					box.Text = tostring(n)
				end
				self:_applyLayout()
			else
				box.Text = isScale and string.format("%.2f", LAYOUT[key]) or tostring(LAYOUT[key])
			end
		end)
	end

	addRow("Banner width (0-1)",  "BannerWidth",   true)
	addRow("Banner height (px)",  "BannerHeight",  false)
	addRow("Banner up/down (px)", "BannerOffsetY", false)
	addRow("Logo width (px)",     "LogoWidth",     false)
	addRow("Logo height (px)",    "LogoHeight",    false)
	addRow("Card icon (px)",      "CardIcon",      false)
	addRow("Social icon (px)",    "SocialBox",     false)
	addRow("Text column (0-1)",   "HeroLeftWidth", true)
	addRow("Gap (px)",            "GAP",           false)
	addRow("Hero height (px)",    "HeroHeight",    false)

	self.Warning = new("TextLabel", {
		Name = "Warning",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -58),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "",
		TextSize = 11,
		TextColor3 = THEME.SubText,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = tuner,
	})

	self.Summary = new("TextBox", {
		Name = "Summary",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = THEME.TunerField,
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		Text = "",
		TextSize = 10,
		TextColor3 = THEME.Text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ClearTextOnFocus = false,
		TextEditable = false,
		Parent = tuner,
	}, { corner(6), padding(6, 6, 6, 6) })

	self:_applyLayout()
end

--=====================================================
--  LINKS: copy to clipboard + open it for the player
--=====================================================
function Library:OpenLink(link, name)
	if not link or link == "" then return false end
	name = name or "Link"

	-- 1) copy to the clipboard (executor function, different name on each one)
	local copied = false
	local setter = (setclipboard or toclipboard or set_clipboard
		or (syn and syn.write_clipboard) or (Clipboard and Clipboard.set))
	if setter then
		copied = pcall(setter, link)
	end

	-- 2) OPEN IT FOR REAL.
	local opened = false

	-- the executor http function, whatever it is called on your executor
	local req = (syn and syn.request) or (http and http.request) or http_request or request

	-- DISCORD: talk to the Discord app on this pc and make it open the invite
	local code = string.match(link, "discord%.gg/([%w%-]+)")
	if code and req then
		pcall(function()
			req({
				Url = "http://127.0.0.1:6463/rpc?v=1",
				Method = "POST",
				Headers = { ["Content-Type"] = "application/json", Origin = "https://discord.com" },
				Body = HttpService:JSONEncode({
					cmd = "INVITE_BROWSER",
					nonce = HttpService:GenerateGUID(false),
					args = { code = code },
				}),
			})
			opened = true
		end)
	end

	-- ANY LINK (youtube too): open the browser
	if not opened then
		local browser = rawget(getfenv(), "openbrowser") or rawget(getfenv(), "OpenBrowser")
		if browser then
			opened = pcall(browser, link)
		end
	end

	if not opened then
		opened = pcall(function()
			game:GetService("GuiService"):OpenBrowserWindow(link)
		end)
	end

	-- last try: the Roblox prompt (works inside the game window)
	if not opened then
		pcall(function()
			game:GetService("GuiService"):OpenBrowserWindow(link)
			opened = true
		end)
	end

	self:Notify({
		text = copied and (name .. " link copied to your clipboard")
			or (name .. " link: " .. link),
		time = 4,
	})

	return copied or opened
end

--=====================================================
--  SMALL HELPERS YOU CAN CALL LATER
--=====================================================
function Library:SetText(which, value)
	if which == "Welcome" then
		self.Left.Welcome.Text = value
	elseif which == "Subtitle" then
		self.Left.Subtitle.Text = value
	elseif which == "Credits" then
		self.CreditsLabel.Text = value
	end
end

function Library:SetSize(key, value)
	if LAYOUT[key] == nil then return end
	LAYOUT[key] = value
	self:_applyLayout()
end

function Library:SetImage(which, id)
	if which == "Background" then
		self.Background.Image = img(id)
	elseif which == "Logo" then
		self.Logo.Image = img(id)
	elseif which == "Banner" then
		self.Banner.Image = img(id)
	end
end


--=====================================================
--  PUBLIC ENTRY POINT (this is what loadstring returns)
--=====================================================
local NexusPlayHub = {}
NexusPlayHub.Library = Library
NexusPlayHub.Version = "1.0.2"

-- NexusPlayHub:CreateWindow({ ... }) builds the window and hands you the ui object.
-- every option is optional.
function NexusPlayHub:CreateWindow(opts)
	opts = opts or {}
	local ui = Library.new()

	if opts.welcome  then pcall(function() ui:SetText("Welcome", opts.welcome) end) end
	if opts.subtitle then pcall(function() ui:SetText("Subtitle", opts.subtitle) end) end
	if opts.credits  then pcall(function() ui:SetText("Credits", opts.credits) end) end

	if opts.background then pcall(function() ui:SetImage("Background", opts.background) end) end
	if opts.logo       then pcall(function() ui:SetImage("Logo", opts.logo) end) end
	if opts.banner     then pcall(function() ui:SetImage("Banner", opts.banner) end) end

	if opts.folder then ui:SetFolder(opts.folder) end
	if opts.accent then ui:SetAccent(opts.accent) end

	ui:SetToggleKey(opts.toggleKey or "RightShift")

	if opts.autoload then
		task.defer(function() ui:LoadAutoload(true) end)
	end

	NexusPlayHub.Window = ui
	return ui
end

-- short alias: NexusPlayHub.new({ ... })
function NexusPlayHub.new(opts)
	return NexusPlayHub:CreateWindow(opts)
end

return NexusPlayHub
