local awful    = require("awful")
local wibox    = require("wibox")
local gears    = require("gears")
local beautiful = require("beautiful")
local dpi      = beautiful.xresources.apply_dpi

local M = {}

-- ── Config ───────────────────────────────────────────────────────────────────
local env_path = (os.getenv("XDG_CONFIG_HOME") or os.getenv("HOME") .. "/.config")
    .. "/somewm/calendars.env"
local LIST_H      = dpi(200)
local ROW_H       = dpi(20)
local HDR_H       = dpi(24)
local SCROLL_STEP = dpi(30)

-- Change this to accomodate your local timezone. I live in UTC+2
local UTC_GAP     = 2

-- ── Events store ─────────────────────────────────────────────────────────────
local events = {}

local function load_urls()
    local urls = {}
    local f = io.open(env_path, "r")
    if not f then return urls end
    for line in f:lines() do
        line = line:match("^(.-)%s*#.*$") or line:match("^(.-)%s*$") or line
        local key, val = line:match("^([%w_]+)=(.+)$")
        if key and key:match("_ICS_URL$") and val and val ~= "" then
            table.insert(urls, val)
        end
    end
    f:close()
    return urls
end

local function parse_dtstart(s)
    -- Returns day_key (YYYY-MM-DD) and time string (HH:MM) or nil for all-day.
    -- Handles: VALUE=DATE (all-day), plain datetime, and UTC (Z suffix).
    local date, time, utc = s:match("^(%d%d%d%d%d%d%d%d)T?(%d*)(Z?)$")
    if not date then return nil, nil end
    local y = tonumber(date:sub(1,4))
    local m = tonumber(date:sub(5,6))
    local d = tonumber(date:sub(7,8))
    if time and #time >= 4 then
        local h, min = tonumber(time:sub(1,2)), tonumber(time:sub(3,4))
        if utc == "Z" then
            local lt = os.date("*t", os.time({year=y,month=m,day=d,hour=h,min=min,sec=0}))
            return ("%04d-%02d-%02d"):format(lt.year, lt.month, lt.day),
                   ("%02d:%02d"):format(lt.hour + UTC_GAP, lt.min)
        end
        return ("%04d-%02d-%02d"):format(y, m, d), ("%02d:%02d"):format(h, min)
    end
    return ("%04d-%02d-%02d"):format(y, m, d), nil
end

local function parse_ics(text)
    local unfolded = text:gsub("\r\n[ \t]", ""):gsub("\n[ \t]", "")
    local in_vevent, dtstart, dtend, summary = false, nil, nil, nil
    for line in unfolded:gmatch("[^\r\n]+") do
        if line == "BEGIN:VEVENT" then
            in_vevent = true; dtstart, dtend, summary = nil, nil, nil
        elseif line == "END:VEVENT" then
            in_vevent = false
            if dtstart then
                local key, time_str = parse_dtstart(dtstart)
                if key then
                    local end_time = nil
                    if dtend then
                        local _, et = parse_dtstart(dtend)
                        end_time = et
                    end
                    if not events[key] then events[key] = {} end
                    table.insert(events[key], {summary = summary or "", time = time_str, end_time = end_time})
                end
            end
        elseif in_vevent then
            dtstart = line:match("^DTSTART[^:]*:([%dTZ]+)") or dtstart
            dtend   = line:match("^DTEND[^:]*:([%dTZ]+)")   or dtend
            summary = line:match("^SUMMARY:(.+)$")           or summary
        end
    end
end

local function refresh()
    for k in pairs(events) do events[k] = nil end
    for _, url in ipairs(load_urls()) do
        awful.spawn.easy_async({"curl", "-fsSL", "--max-time", "15", url},
            function(stdout, _, _, code)
                if code == 0 and stdout ~= "" then parse_ics(stdout) end
            end)
    end
end

-- ── Date helpers ──────────────────────────────────────────────────────────────
local function day_key(t)
    return ("%04d-%02d-%02d"):format(t.year, t.month, t.day)
end

local function week_monday(t)
    local ts   = os.time({year=t.year, month=t.month, day=t.day, hour=12, min=0, sec=0})
    local wday = os.date("*t", ts).wday  -- 1=Sun
    return ts - ((wday - 2) % 7) * 86400
end

-- ── Event list ────────────────────────────────────────────────────────────────
local highlighted_key = nil
local highlight_timer = nil

-- Create overflow layout imperatively to avoid declarative-syntax edge cases
local event_layout = wibox.layout.overflow.vertical()
event_layout.scrollbar_enabled = false
event_layout.step = SCROLL_STEP

local function update_event_list(focus_key)
    event_layout:reset()

    local ref_t = os.date("*t")
    if focus_key then
        local y, m, d = focus_key:match("^(%d+)-(%d+)-(%d+)$")
        if y then ref_t = {year=tonumber(y), month=tonumber(m), day=tonumber(d)} end
    end

    local mon_ts  = week_monday(ref_t)
    local total_h = 0
    local focus_y = nil

    for i = 0, 6 do
        local ts         = mon_ts + i * 86400
        local dt         = os.date("*t", ts)
        local key        = day_key(dt)
        local day_events = events[key] or {}
        local is_focus   = (key == focus_key)

        if is_focus and not focus_y then focus_y = total_h end

        local hdr_bg = is_focus and (beautiful.bg_focus  or "#4c566a") or (beautiful.bg_normal or "#2e3440")
        local hdr_fg = is_focus and (beautiful.fg_focus  or beautiful.fg_normal) or beautiful.fg_normal
        local ev_bg  = is_focus and (beautiful.bg_focus  or "#4c566a") or (beautiful.bg_normal or "#2e3440")

        -- Day header
        local hdr_text = wibox.widget.textbox()
        hdr_text:set_markup("<b>" .. os.date("%a %d", ts) .. "</b>")
        hdr_text.align = "left"

        local hdr_margin = wibox.container.margin(hdr_text, dpi(8), dpi(8), dpi(2), dpi(2))

        local hdr = wibox.container.background(hdr_margin)
        hdr.forced_height = HDR_H
        hdr.fg = hdr_fg
        hdr.bg = hdr_bg
        event_layout:add(hdr)
        total_h = total_h + HDR_H

        -- Events (or empty-day placeholder)
        if #day_events == 0 then
            local row_text = wibox.widget.textbox()
            row_text.text = "  —"
            local row = wibox.container.background(
                wibox.container.margin(row_text, dpi(8), 0, 0, 0))
            row.forced_height = ROW_H
            row.bg = ev_bg
            row.fg = beautiful.fg_minimize or "#616e88"
            event_layout:add(row)
            total_h = total_h + ROW_H
        else
            table.sort(day_events, function(a, b)
                if not a.time then return false end
                if not b.time then return true end
                return a.time < b.time
            end)
            for _, ev in ipairs(day_events) do
                local span = ev.time
                    and (ev.end_time and (ev.time .. " - " .. ev.end_time) or (ev.time))
                    or "All day"
                local label = span .. " · " .. ev.summary
                local row_text = wibox.widget.textbox()
                row_text.text = "  · " .. label
                local row = wibox.container.background(
                    wibox.container.margin(row_text, dpi(8), 0, 0, 0))
                row.forced_height = ROW_H
                row.bg = ev_bg
                event_layout:add(row)
                total_h = total_h + ROW_H
            end
        end
    end

    if event_layout._private.used_in_dir then
        if focus_y then
            local scrollable = math.max(0, total_h - LIST_H)
            event_layout:set_scroll_factor(scrollable > 0 and math.min(1, focus_y / scrollable) or 0)
        else
            event_layout:set_scroll_factor(0)
        end
    end
end

local function select_day(date)
    highlighted_key = day_key(date)
    if highlight_timer then highlight_timer:stop(); highlight_timer = nil end
    update_event_list(highlighted_key)
    highlight_timer = gears.timer.start_new(2, function()
        highlighted_key = nil
        highlight_timer = nil
        update_event_list(nil)
        return false
    end)
end

-- ── Calendar popup ────────────────────────────────────────────────────────────
local popup = awful.widget.calendar_popup.month()
local cal   = popup:get_widget()

local original_embed = cal._private.fn_embed

cal.fn_embed = function(widget, flag, date)
    local styled = original_embed(widget, flag, date)
    if flag ~= "normal" and flag ~= "focus" then return styled end

    styled:buttons({ awful.button({}, 1, function() select_day(date) end) })

    local key = day_key(date)
    if not events[key] or #events[key] == 0 then return styled end

    return wibox.widget {
        styled,
        {
            {
                forced_height = dpi(4),
                forced_width  = dpi(4),
                shape = gears.shape.circle,
                bg    = beautiful.fg_urgent or "#ff6c6b",
                widget = wibox.container.background,
            },
            valign = "bottom",
            halign = "center",
            widget = wibox.container.place,
        },
        layout = wibox.layout.stack,
    }
end

-- Build combined layout: calendar / separator / event list
local separator = wibox.widget.separator()
separator.color         = beautiful.border_color_normal or beautiful.fg_normal
separator.forced_height = 1

local constraint = wibox.container.constraint(event_layout, "exact", nil, LIST_H)

local combined = wibox.layout.fixed.vertical()
combined:add(cal)
combined:add(separator)
combined:add(constraint)

-- Use set_widget (same method calendar_popup itself uses) instead of setup
popup:set_widget(combined)

-- Override the popup's wibox-level scroll buttons with position-aware handlers.
-- When the cursor is in the event list area (bottom LIST_H px), scroll the
-- event list; otherwise let it navigate months as normal.
popup.buttons = {
    awful.button({}, 1, function() popup.visible = false; popup._calendar_clicked_on = false end),
    awful.button({}, 3, function() popup.visible = false; popup._calendar_clicked_on = false end),
    awful.button({}, 4, function()
        local geo = popup:geometry()
        if mouse.coords().y > geo.y + geo.height - LIST_H then
            event_layout:scroll(-1)
        else
            popup:call_calendar(-1)
        end
    end),
    awful.button({}, 5, function()
        local geo = popup:geometry()
        if mouse.coords().y > geo.y + geo.height - LIST_H then
            event_layout:scroll(1)
        else
            popup:call_calendar(1)
        end
    end),
}

-- Geometry: measured from saved `cal` ref since get_widget() now returns `combined`
local function popup_geometry(position, screen)
    local pos = position or popup.position or "tc"
    local s   = screen   or popup.screen  or awful.screen.focused()
    local wa  = s.workarea
    local cal_w, cal_h = cal:fit({screen=s, dpi=s.dpi}, wa.width, wa.height)
    local w, h = cal_w, cal_h + 1 + LIST_H

    local x = pos:sub(2,2) == "l" and wa.x
           or pos:sub(2,2) == "r" and wa.x + wa.width - w
           or wa.x + math.floor((wa.width - w) / 2)
    local y = pos:sub(1,1) == "t" and wa.y
           or pos:sub(1,1) == "b" and wa.y + wa.height - h
           or wa.y + math.floor((wa.height - h) / 2)

    return {x=x, y=y, width=w, height=h}
end

popup.call_calendar = function(self, offset_delta, position, screen)
    local s = screen or self.screen or awful.screen.focused()
    self.position = position or self.position
    self.offset   = (offset_delta or 0) ~= 0 and self.offset + (offset_delta or 0) or 0

    local raw  = os.date("*t")
    local date = {day=raw.day, month=raw.month, year=raw.year}
    if self.offset ~= 0 then
        date = {
            month = (raw.month + self.offset - 1) % 12 + 1,
            year  = raw.year + math.floor((raw.month + self.offset - 1) / 12),
        }
    end

    cal:set_date(date)
    self:geometry(popup_geometry(self.position, s))
    update_event_list(highlighted_key)
    return self
end

popup:connect_signal("property::visible", function(self)
    if not self.visible then
        if highlight_timer then highlight_timer:stop(); highlight_timer = nil end
        highlighted_key = nil
        self.offset = 0
    end
end)

-- ── Startup ───────────────────────────────────────────────────────────────────
refresh()
gears.timer { timeout = 3600, autostart = true, callback = refresh }
update_event_list(nil)

M.popup   = popup
M.refresh = refresh

return M
