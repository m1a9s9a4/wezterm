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
-- Tab
----------------------------------------------------
-- タイトルバーを非表示
config.window_decorations = "RESIZE"
-- タブバーの表示
config.show_tabs_in_tab_bar = true
-- タブが一つの時は非表示
config.hide_tab_bar_if_only_one_tab = true
-- falseにするとタブバーの透過が効かなくなる
-- config.use_fancy_tab_bar = false

-- タブバーの透過
config.window_frame = {
	inactive_titlebar_bg = "none",
	active_titlebar_bg = "none",
}

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
-- Right Status (Command Duration)
----------------------------------------------------
wezterm.on("update-right-status", function(window, pane)
	-- Kanagawa colors
	local yellow = "#FF9E3B" -- roninYellow
	local text = ""

	-- Get command duration
	local duration = window:active_pane():get_foreground_process_name()
	local cmd_duration = math.floor(pane:get_metadata().since_last_response_ms or 0)

	if cmd_duration > 0 then
		local seconds = cmd_duration / 1000
		if seconds < 60 then
			text = string.format("⏱️  %.1fs", seconds)
		elseif seconds < 3600 then
			text = string.format("⏱️  %.1fm", seconds / 60)
		else
			text = string.format("⏱️  %.1fh", seconds / 3600)
		end

		window:set_right_status(wezterm.format({
			{ Foreground = { Color = yellow } },
			{ Text = text .. " " },
		}))
	else
		window:set_right_status("")
	end
end)

----------------------------------------------------
-- keybinds
----------------------------------------------------
config.disable_default_key_bindings = true
config.keys = require("keybinds").keys
config.key_tables = require("keybinds").key_tables
config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 2000 }

return config
