-- Главные программы и пути
local home = os.getenv("HOME")
local hypr = home .. "/.config/hypr"
local terminal = "kitty"
local launcher = "rofi -show drun -show-icons"
local filemanager = "nautilus"
local wallpaper = home .. "/Pictures/Wallpapers/wallpaper.jpg"

hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'pgrep -x waybar >/dev/null || waybar'")
    hl.exec_cmd("pgrep -x swaync >/dev/null || swaync")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd(home .. "/.local/bin/start-visualizer.sh")
    hl.exec_cmd("pgrep -x hypridle >/dev/null || hypridle >/dev/null 2>&1 &")
    hl.exec_cmd([[pgrep -x awww-daemon >/dev/null || awww-daemon >/dev/null 2>&1 &]])
    hl.exec_cmd("awww img " .. wallpaper .. " --transition-type fade --transition-duration 1")
    hl.exec_cmd(hypr .. "/scripts/start-hyprswitch.sh")
end)

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 12,
        border_size = 2,
        layout = "dwindle",
    },

    decoration = {
        rounding = 12,
        active_opacity = 0.88,
        inactive_opacity = 0.65,
        fullscreen_opacity = 1.0,

        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            ignore_opacity = true,
            new_optimizations = true,
        },

        shadow = {
            enabled = true,
        },
    },

    input = {
        kb_layout = "us,ru",
        kb_options = "grp:alt_shift_toggle",
        follow_mouse = 1,
        repeat_rate = 40,
        repeat_delay = 250,

        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
        },
    },

    animations = {
        enabled = true,
    },
})

-- Кривые анимаций
hl.curve("smoothOut", {
    type = "bezier",
    points = { { 0.36, 0 }, { 0.66, -0.56 } },
})

hl.curve("smoothIn", {
    type = "bezier",
    points = { { 0.25, 1 }, { 0.5, 1 } },
})

hl.curve("overshot", {
    type = "bezier",
    points = { { 0.05, 0.9 }, { 0.1, 1.05 } },
})

-- Анимации
hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 5,
    bezier = "overshot",
})

hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 5,
    bezier = "smoothOut",
    style = "popin 80%",
})

hl.animation({
    leaf = "border",
    enabled = true,
    speed = 10,
    bezier = "default",
})

hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 5,
    bezier = "default",
})

hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 5,
    bezier = "overshot",
    style = "slide",
})

hl.animation({
    leaf = "workspacesIn",
    enabled = true,
    speed = 5,
    bezier = "overshot",
    style = "slide",
})

hl.animation({
    leaf = "workspacesOut",
    enabled = true,
    speed = 5,
    bezier = "smoothOut",
    style = "slide",
})

local function refresh_waybar_workspaces()
    hl.exec_cmd("pkill -RTMIN+8 waybar")
end

local function focus_workspace(workspace)
    hl.dispatch(hl.dsp.focus({ workspace = workspace }))
    refresh_waybar_workspaces()
end

local function move_window_to_workspace(workspace)
    hl.dispatch(hl.dsp.window.move({ workspace = workspace, follow = false }))
    refresh_waybar_workspaces()
end

-- Горячие клавиши
hl.bind("SUPER + Q", hl.dsp.exec_cmd(terminal))
hl.bind("ALT + Tab", hl.dsp.exec_cmd("hyprswitch gui --mod-key alt --key tab"))
hl.bind("SUPER + M", hl.dsp.exec_cmd(hypr .. "/scripts/dashboard.sh"))
hl.bind("SUPER + R", hl.dsp.exec_cmd(launcher))
hl.bind("SUPER + E", hl.dsp.exec_cmd(filemanager))
hl.bind("SUPER + X", hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
hl.bind("SUPER + SHIFT + X", hl.dsp.workspace.toggle_special("minimized"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))

hl.bind("SUPER + L", hl.dsp.exec_cmd("hyprlock"))

hl.bind("SUPER + D", function()
    hl.exec_cmd(hypr .. "/show-desktop.sh")
end)

hl.bind("Print", function()
    hl.exec_cmd(hypr .. "/scripts/screenshot-area.sh")
end)

hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grim - | wl-copy"))

-- Окна
hl.bind("SUPER + C", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + Tab", hl.dsp.window.cycle_next({ next = true }))

-- Фокус окон стрелками
hl.bind("SUPER + Left", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + Right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + Up", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + Down", hl.dsp.focus({ direction = "down" }))

-- Перемещение окон стрелками
hl.bind("SUPER + SHIFT + Left", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + SHIFT + Up", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + Down", hl.dsp.window.move({ direction = "down" }))

-- Рабочие столы
for i = 1, 5 do
    local workspace = tostring(i)

    hl.bind("SUPER + " .. workspace, function()
        focus_workspace(workspace)
    end)

    hl.bind("SUPER + SHIFT + " .. workspace, function()
        move_window_to_workspace(workspace)
    end)
end

-- Диспетчер задач
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty --class btop-g -e btop"))

-- Управление звуком
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))

-- Перезагрузка конфига
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

hl.window_rule({
    name = "btop-floating",

    match = {
        class = "btop-g",
    },

    float = true,
    pin = true,
    opacity = "0.70 0.70",
    border_size = 0,
    no_shadow = true,
})



hl.monitor({
 output = "DP-3",
 mode = "2560x1440@144",
 position = "0x0",
 scale = 1,
})

hl.monitor({
 output = "HDMI-A-1",
 mode = "1920x1080@74.97",
 position = "2560x-6",
 scale = 1,
})

hl.layer_rule({
    name = "rofi-popin",
    match = { namespace = "rofi" },
    animation = "popin 80%",
    blur = true,
    ignore_alpha = 0.4,
})

hl.layer_rule({
    name = "dashboard-blur",
    match = { namespace = "quickshell" },
    blur = true,
    ignore_alpha = 0.2,
})

-- BEGIN keyboard layout switch
-- Switch keyboard layout by ALT + SHIFT
hl.config({
 input = {
  kb_layout = "us,ru",
  kb_options = "grp:alt_shift_toggle",
 }
})
-- END keyboard layout switch

-- BEGIN dual monitor workspace binds
-- Main monitor DP-3:
-- SUPER + 1..5 -> focus workspaces 1..5
-- SUPER + SHIFT + 1..5 -> move active window to workspaces 1..5
--
-- Second monitor HDMI-A-1:
-- ALT + 1..5 -> focus workspaces 6..10
-- SUPER + ALT + 1..5 -> move active window to workspaces 6..10

-- Workspace placement
hl.workspace_rule({ workspace = "1", monitor = "DP-3", persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-3", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-3", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "DP-3", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "DP-3", persistent = true })

hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "9", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-1", persistent = true })

-- Main monitor navigation
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = 5 }))

-- Main monitor move window
hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = 1, follow = true }))
hl.bind("SUPER + SHIFT + 2", hl.dsp.window.move({ workspace = 2, follow = true }))
hl.bind("SUPER + SHIFT + 3", hl.dsp.window.move({ workspace = 3, follow = true }))
hl.bind("SUPER + SHIFT + 4", hl.dsp.window.move({ workspace = 4, follow = true }))
hl.bind("SUPER + SHIFT + 5", hl.dsp.window.move({ workspace = 5, follow = true }))

-- Second monitor navigation
hl.bind("ALT + 1", hl.dsp.focus({ workspace = 6 }))
hl.bind("ALT + 2", hl.dsp.focus({ workspace = 7 }))
hl.bind("ALT + 3", hl.dsp.focus({ workspace = 8 }))
hl.bind("ALT + 4", hl.dsp.focus({ workspace = 9 }))
hl.bind("ALT + 5", hl.dsp.focus({ workspace = 10 }))

-- Second monitor move window
hl.bind("SUPER + ALT + 1", hl.dsp.window.move({ workspace = 6, follow = true }))
hl.bind("SUPER + ALT + 2", hl.dsp.window.move({ workspace = 7, follow = true }))
hl.bind("SUPER + ALT + 3", hl.dsp.window.move({ workspace = 8, follow = true }))
hl.bind("SUPER + ALT + 4", hl.dsp.window.move({ workspace = 9, follow = true }))
hl.bind("SUPER + ALT + 5", hl.dsp.window.move({ workspace = 10, follow = true }))
-- END dual monitor workspace binds

