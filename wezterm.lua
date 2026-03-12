local wezterm = require("wezterm")
local config = wezterm.config_builder()

----------------------------------------------------
-- General
----------------------------------------------------
config.automatically_reload_config = true
config.use_ime = true
-- IME未確定文字をWezterm側で描画（安定性向上）
config.ime_preedit_rendering = "Builtin"
-- macOSでIMEにCtrl/Altを転送しない（誤動作防止）
config.macos_forward_to_ime_modifier_mask = "SHIFT"

----------------------------------------------------
-- Font
----------------------------------------------------
config.font = wezterm.font_with_fallback({
	{ family = "JetBrains Mono", weight = "Medium" },
	{ family = "Noto Sans JP", weight = "Medium" },
})
config.font_size = 11.0

----------------------------------------------------
-- Color Scheme (Kanagawa)
----------------------------------------------------
config.color_scheme = "Kanagawa (Gogh)"

----------------------------------------------------
-- Window
----------------------------------------------------
config.window_background_opacity = 0.80
config.macos_window_background_blur = 20

-- フォーカス時は透明度を下げる（より不透明に）
wezterm.on("window-focus-changed", function(window, pane)
	local overrides = window:get_config_overrides() or {}
	if window:is_focused() then
		overrides.window_background_opacity = 0.95
	else
		overrides.window_background_opacity = 0.80
	end
	window:set_config_overrides(overrides)
end)

----------------------------------------------------
-- Pane (フォーカスしていないペインを暗くする)
----------------------------------------------------
config.inactive_pane_hsb = {
	saturation = 0.7,
	brightness = 0.5,
}

----------------------------------------------------
-- Tab
----------------------------------------------------
-- タイトルバーを非表示
config.window_decorations = "RESIZE"
-- タブバーの表示
config.show_tabs_in_tab_bar = true
-- ステータスバーとして常時表示（CPU/MEM 等を表示するため）
config.hide_tab_bar_if_only_one_tab = false
-- retro tab bar（色を完全にコントロール可能）
config.use_fancy_tab_bar = false
-- タブバーを画面下部に配置（tmux スタイル）
config.tab_bar_at_bottom = true
-- タブの高さ
config.tab_max_width = 32

-- タブバーを背景色に合わせる (Kanagawa background)
config.window_background_gradient = {
	colors = { "#1F1F28" }, -- sumiInk1 (Kanagawa background)
}

-- タブの追加ボタンを非表示
config.show_new_tab_button_in_tab_bar = false
-- nightlyのみ使用可能
-- タブの閉じるボタンを非表示
config.show_close_tab_button_in_tabs = false

-- タブ同士の境界線を非表示 & Kanagawa colors
config.colors = {
	tab_bar = {
		inactive_tab_edge = "none",
		background = "#1F1F28", -- sumiInk1
	},
}

-- タブの形をカスタマイズ
-- タブの左側の装飾
local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_lower_right_triangle
-- タブの右側の装飾
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_upper_left_triangle

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	-- Kanagawa colors
	local background = "#54546D" -- sumiInk4
	local foreground = "#DCD7BA" -- fujiWhite
	local edge_background = "none"
	if tab.is_active then
		background = "#FF9E3B" -- roninYellow (Kanagawa accent)
		foreground = "#1F1F28" -- sumiInk1
	end
	local edge_foreground = background
	local title = "   " .. wezterm.truncate_right(tab.active_pane.title, max_width - 1) .. "   "
	return {
		{ Background = { Color = edge_background } },
		{ Foreground = { Color = edge_foreground } },
		{ Text = SOLID_LEFT_ARROW },
		{ Background = { Color = background } },
		{ Foreground = { Color = foreground } },
		{ Text = title },
		{ Background = { Color = edge_background } },
		{ Foreground = { Color = edge_foreground } },
		{ Text = SOLID_RIGHT_ARROW },
	}
end)

----------------------------------------------------
-- Status Bar (Powerline)
----------------------------------------------------
-- Kanagawa palette
local K = {
	bg = "#1F1F28", -- sumiInk1
	fg = "#DCD7BA", -- fujiWhite
	dark = "#16161D", -- sumiInk0
	gray = "#54546D", -- sumiInk4
	yellow = "#FF9E3B", -- roninYellow
	blue = "#7E9CD8", -- crystalBlue
	green = "#98BB6C", -- springGreen
	red = "#C34043", -- autumnRed
	magenta = "#957FB8", -- oniViolet
	orange = "#FFA066", -- surimiOrange
}

local SEP_L = wezterm.nerdfonts.pl_left_hard_divider
local SEP_R = wezterm.nerdfonts.pl_right_hard_divider

-- Navigation hints toggle (Leader+n で切り替え)
if wezterm.GLOBAL.show_nav_hints == nil then
	wezterm.GLOBAL.show_nav_hints = true
end

-- System specs (起動時に1回だけ取得)
local specs = { cores = 0, mem_gb = 0 }
do
	local ok, out = wezterm.run_child_process({ "sysctl", "-n", "hw.ncpu" })
	if ok then
		specs.cores = tonumber(out:match("%d+")) or 0
	end
	ok, out = wezterm.run_child_process({ "sysctl", "-n", "hw.memsize" })
	if ok then
		specs.mem_gb = math.floor((tonumber(out:match("%d+")) or 0) / 1073741824)
	end
end

-- System metrics cache (10秒間隔で更新)
local sys = { mem = "", cpu = "", ts = 0 }

local function refresh_sys()
	local now = os.time()
	if now - sys.ts < 10 then
		return
	end
	sys.ts = now
	local ok, out = wezterm.run_child_process({
		"bash",
		"-c",
		"ps -caxm -orss= | awk '{s+=$1}END{printf \"%.1f\",s/1048576}'",
	})
	if ok then
		sys.mem = out:gsub("%s+$", "")
	end
	ok, out = wezterm.run_child_process({ "sysctl", "-n", "vm.loadavg" })
	if ok then
		local l = out:match("{%s+([%d%.]+)")
		if l then
			sys.cpu = l
		end
	end
end

-- Powerline builder (右側: ◀ seg1 ◀ seg2 ...)
local function powerline_right(segs)
	local el = {}
	for i, s in ipairs(segs) do
		local prev = i > 1 and segs[i - 1].bg or K.bg
		table.insert(el, { Background = { Color = prev } })
		table.insert(el, { Foreground = { Color = s.bg } })
		table.insert(el, { Text = SEP_L })
		table.insert(el, { Background = { Color = s.bg } })
		table.insert(el, { Foreground = { Color = s.fg } })
		table.insert(el, { Text = s.text })
	end
	return el
end

wezterm.on("update-right-status", function(window, pane)
	refresh_sys()
	local segs = {}

	-- Key table (アクティブ時のみ)
	local kt = window:active_key_table()
	if kt then
		table.insert(segs, { text = " " .. kt .. " ", bg = K.red, fg = K.fg })
	end

	-- CPU load (値/コア数 — コア数を超えると過負荷)
	if sys.cpu ~= "" then
		local load = tonumber(sys.cpu) or 0
		local bg = load > specs.cores * 0.8 and K.red or K.gray
		table.insert(segs, { text = " CPU " .. sys.cpu .. "/" .. specs.cores .. " ", bg = bg, fg = K.fg })
	end

	-- Memory (使用量/総量)
	if sys.mem ~= "" then
		local used = tonumber(sys.mem) or 0
		local bg = used > specs.mem_gb * 0.8 and K.red or K.magenta
		table.insert(segs, { text = " MEM " .. sys.mem .. "/" .. specs.mem_gb .. "G ", bg = bg, fg = K.dark })
	end

	-- Battery
	local bat = wezterm.battery_info()
	if #bat > 0 then
		local pct = math.floor(bat[1].state_of_charge * 100)
		table.insert(segs, { text = " BAT " .. pct .. "% ", bg = K.blue, fg = K.dark })
	end

	-- Date & Time
	table.insert(segs, { text = " " .. wezterm.strftime("%m/%d %H:%M") .. " ", bg = K.yellow, fg = K.dark })

	window:set_right_status(wezterm.format(powerline_right(segs)))

	-- Left status: workspace name + navigation hints
	local ws = window:active_workspace()
	local left = {
		{ Background = { Color = K.green } },
		{ Foreground = { Color = K.dark } },
		{ Text = " " .. ws .. " " },
		{ Background = { Color = K.bg } },
		{ Foreground = { Color = K.green } },
		{ Text = SEP_R },
	}

	if wezterm.GLOBAL.show_nav_hints then
		local hints = " C-hjkl:Pane Move  Space+e:Files  Space+ff:Find  Space+fg:Grep  Space+gg:Git  Ldr+?:Help  Ldr+n:Hide "
		-- gray segment
		table.insert(left, { Background = { Color = K.bg } })
		table.insert(left, { Foreground = { Color = K.gray } })
		table.insert(left, { Text = SEP_R })
		table.insert(left, { Background = { Color = K.gray } })
		table.insert(left, { Foreground = { Color = K.fg } })
		table.insert(left, { Text = hints })
		table.insert(left, { Background = { Color = K.bg } })
		table.insert(left, { Foreground = { Color = K.gray } })
		table.insert(left, { Text = SEP_R })
	end

	window:set_left_status(wezterm.format(left))
end)

----------------------------------------------------
-- smart-splits (Neovim ↔ WezTerm pane navigation)
----------------------------------------------------
local function is_vim(pane)
	return pane:get_foreground_process_name():find("n?vim") ~= nil
end

local direction_keys = {
	h = "Left",
	j = "Down",
	k = "Up",
	l = "Right",
}

local function split_nav(resize_or_move, key)
	return {
		key = key,
		mods = resize_or_move == "resize" and "ALT" or "CTRL",
		action = wezterm.action_callback(function(win, pane)
			if is_vim(pane) then
				-- Neovim に渡す
				win:perform_action({
					SendKey = { key = key, mods = resize_or_move == "resize" and "ALT" or "CTRL" },
				}, pane)
			elseif #pane:tab():panes() > 1 then
				-- 複数ペイン時のみナビゲーション
				if resize_or_move == "resize" then
					win:perform_action({ AdjustPaneSize = { direction_keys[key], 3 } }, pane)
				else
					win:perform_action({ ActivatePaneDirection = direction_keys[key] }, pane)
				end
			else
				-- ペイン1つ → キーをそのままシェルに渡す (Ctrl+k 等が使える)
				win:perform_action({
					SendKey = { key = key, mods = resize_or_move == "resize" and "ALT" or "CTRL" },
				}, pane)
			end
		end),
	}
end

----------------------------------------------------
-- keybinds
----------------------------------------------------
config.disable_default_key_bindings = true

local keybinds = require("keybinds")
local keys = keybinds.keys

-- Navigation hints トグル (Leader+n)
table.insert(keys, {
	key = "n",
	mods = "LEADER",
	action = wezterm.action_callback(function(window, pane)
		wezterm.GLOBAL.show_nav_hints = not wezterm.GLOBAL.show_nav_hints
		wezterm.log_info("Nav hints: " .. tostring(wezterm.GLOBAL.show_nav_hints))
	end),
})

-- smart-splits キーを追加
for _, k in ipairs({ "h", "j", "k", "l" }) do
	table.insert(keys, split_nav("move", k))
	table.insert(keys, split_nav("resize", k))
end

config.keys = keys
config.key_tables = keybinds.key_tables
config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 2000 }

return config
