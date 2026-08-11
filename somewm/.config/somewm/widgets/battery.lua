local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local naughty = require("naughty")
local beautiful = require("beautiful")

local battery_text = wibox.widget {
    widget = wibox.widget.textbox,
}

local battery_widget = wibox.widget {
    battery_text,
    layout = wibox.layout.fixed.horizontal,
}

local last_warning = nil

local function update_battery()
    awful.spawn.easy_async_with_shell(
        "cat /sys/class/power_supply/BAT0/capacity; cat /sys/class/power_supply/BAT0/status",
        function(stdout)
            local lines = {}
            for line in stdout:gmatch("[^\n]+") do
                table.insert(lines, line)
            end

            local capacity = tonumber(lines[1]) or 0
            local status = lines[2] or "Unknown"
            local charging = status == "Charging"

            local color
            if charging then
                color = beautiful.fg_normal
            elseif capacity > 50 then
                color = beautiful.fg_normal
            elseif capacity > 20 then
                color = "#f0a500"
            else
                color = "#cc241d"
            end

            local label = charging and "⚡ " or "🔋 "
            battery_text:set_markup(
                string.format('<span color="%s">%s%d%%</span>', color, label, capacity)
            )

            if not charging then
                if capacity <= 10 and last_warning ~= 10 then
                    naughty.notification {
                        urgency = "critical",
                        title   = "Battery Critical",
                        message = "Battery at " .. capacity .. "%",
                    }
                    last_warning = 10
                elseif capacity <= 20 and last_warning ~= 20 then
                    naughty.notification {
                        urgency = "normal",
                        title   = "Battery Low",
                        message = "Battery at " .. capacity .. "%",
                    }
                    last_warning = 20
                end
            else
                last_warning = nil
            end
        end
    )
end

gears.timer {
    timeout   = 30,
    autostart = true,
    call_now  = true,
    callback  = update_battery,
}

return battery_widget
