-- Главные программы
local terminal = "kitty"
local launcher = "rofi -show drun -show-icons"
local filemanager = "nautilus"


hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'pgrep -x waybar >/dev/null || waybar'")
    hl.exec_cmd("swaync")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("/home/abooser/.local/bin/start-visualizer.sh")
    hl.exec_cmd("pgrep -x hypridle >/dev/null || hypridle >/dev/null 2>&1 &")
    hl.exec_cmd([[pgrep -x awww-daemon >/dev/null || awww-daemon >/dev/null 2>&1 &]])
    hl.exec_cmd([[awww img /home/abooser/Pictures/Wallpapers/wallpaper.jpg --transition-type fade --transition-duration 1]])
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
        blur = {
            enabled = true,
            size = 4,
            passes = 2,
        },
        shadow = {
            enabled = true,
        },
    },

    input = {
        kb_layout = "us,ru",
        kb_options = "grp:alt_shift_toggle",
        follow_mouse = 1,

        touchpad = {
            natural_scroll = true,
        },
    },

    animations = {
        enabled = true,
    },
})


-- Кривые анимаций
hl.curve("smoothOut", {
    type = "bezier",
    points = { {0.36, 0}, {0.66, -0.56} },
})

hl.curve("smoothIn", {
    type = "bezier",
    points = { {0.25, 1}, {0.5, 1} },
})

hl.curve("overshot", {
    type = "bezier",
    points = { {0.05, 0.9}, {0.1, 1.05} },
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

-- Горячие клавиши
hl.bind("SUPER + Q", hl.dsp.exec_cmd(terminal))
hl.bind("SUPER + R", hl.dsp.exec_cmd(launcher))
hl.bind("SUPER + E", hl.dsp.exec_cmd(filemanager))
hl.bind("SUPER + X", hl.dsp.window.move({ workspace = "special:minimized" }))
hl.bind("SUPER + SHIFT + X", hl.dsp.workspace.toggle_special("minimized"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))

hl.bind("SUPER + L", hl.dsp.exec_cmd("hyprlock"))

hl.bind("SUPER + D", function()
    hl.exec_cmd("/home/abooser/.config/hypr/show-desktop.sh")
end)

hl.bind("Print", function()
    hl.exec_cmd("/home/abooser/.config/hypr/scripts/screenshot-area.sh")
end)

-- Закрыть окно
hl.bind("SUPER + C", hl.dsp.window.close())

-- Полный экран
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- Плавающий режим окна
hl.bind("SUPER + Space", hl.dsp.window.float({ action = "toggle" }))


-- Переключение рабочих столов
hl.bind("SUPER + 1", hl.dsp.focus({ workspace = "1" }))
hl.bind("SUPER + 2", hl.dsp.focus({ workspace = "2" }))
hl.bind("SUPER + 3", hl.dsp.focus({ workspace = "3" }))
hl.bind("SUPER + 4", hl.dsp.focus({ workspace = "4" }))
hl.bind("SUPER + 5", hl.dsp.focus({ workspace = "5" }))

-- Переместить окно на другой рабочий стол
hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({ workspace = "1" }))
hl.bind("SUPER + SHIFT + 2", hl.dsp.window.move({ workspace = "2" }))
hl.bind("SUPER + SHIFT + 3", hl.dsp.window.move({ workspace = "3" }))
hl.bind("SUPER + SHIFT + 4", hl.dsp.window.move({ workspace = "4" }))
hl.bind("SUPER + SHIFT + 5", hl.dsp.window.move({ workspace = "5" }))

hl.bind("SUPER + Tab", hl.dsp.window.cycle_next({ next = true }))

-- Диспетчер задач
hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("kitty -e btop"))

-- Управление звуком
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))

-- Перезагрузка конфига
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- Прозрачность + блюр для всех окон
hl.config({
    decoration = {
        active_opacity = 0.80,
        inactive_opacity = 0.30,
        fullscreen_opacity = 1.0,

        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            ignore_opacity = true,
            new_optimizations = true,
        },
    },
})

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
  output = "HDMI-A-1",
  mode = "highrr",
  position = "0x0",
  scale = 1,
})

hl.layer_rule({
    name = "rofi-popin",
    match = { namespace = "rofi" },
    animation = "popin 80%",
    blur = true,
    ignore_alpha = 0.4,
})
