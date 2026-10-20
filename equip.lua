-- YunaEquip, as part of YunaUI: your equipment on screen in the YunaGearOpt style (a wheel of gear round your job,
-- HP / MP / TP and your current gear set). Loaded by yunaui.lua; its pictures and fonts are in yunaui/equip/.
YUI_EQ_VERSION = '1.0.4';

require('common');
local imgui    = require('imgui');
local settings = require('settings');
local chat     = require('chat');
local ffi      = require('ffi');
local d3d      = require('d3d8');

----------------------------------------------------------------------------------------------------
-- Settings (flat values only: saved tables come back as T{} and break plain table code)
----------------------------------------------------------------------------------------------------
local defaults = T{
    visible = true,
    locked  = false,
    scale   = 1.0,
    opacity = 0.0,     -- the wheel's background: none (fixed; the setting was removed)
    x       = 200,
    y       = 200,
    flash   = true,    -- the Shadow effect when a piece of gear changes
    icon    = 36,      -- icon size in px (before Size)
    mini    = false,   -- mini mode: 16 px icons, tight spacing
    layout  = '4x4',   -- how the 16 slots are arranged (see LAYOUTS)
    living  = true,    -- the border's colours follow idle / engaged / casting / resting
    state   = false,   -- the state's name on the top edge (Idle, Engaged, Casting, ...); off = cleaner
    state_v = 1,       -- 2 once the name has been switched off for everyone
    idle_color = 'purple',     -- the border / name colour when idle: purple, black or white
    size_v  = 1,       -- 2 once the old Size has been folded into Icon size
    mptimer = false,   -- while /resting: seconds until MP is full, on the bottom edge (off by default)
    mp_v    = 1,       -- 2 once the MP timer has been switched off for everyone
    ripple  = true,    -- when you engage: a wave pops through the items from the centre out
    style   = 'orbit',   -- card = the grid, orbit = weapon in the centre with the rest on a ring
    blm_art = 'blm',   -- Black Mage's picture: 'blm' (the wizard) or 'wak' (the warlock)
    bg      = 'ink',   -- the Orbit's background: 'ink' (charcoal and brushstrokes), 'glass', 'job', 'none', 'solid'
    bg_v    = 1,       -- 2 once everyone has been moved to the ink background
    disc    = 'black', -- the wheel's background colour (see JOBS.discs)
    bottom  = 'set',   -- under the wheel: 'set' (the gear set's name) or 'off'
    bottom_v = 1,
    set_font = 'bahn',  -- the set name's font (SET_FONTS)
    set_font_v = 1,
    set_color = 'gold',   -- and colour (SET_COLORS)
    middle  = 'icon',   -- the middle of the wheel: 'art' (the job's artwork), 'icon' (the job icon), 'set' (the gear set's name)
    middle_v = 1,
    centre_fx = 'veins', -- the effect between the job icon and the gear (JOBS.FX_LIST)
    art_alpha = 1.0,   -- how solid the artwork in the middle is (0.1 - 1)
    big_logo = false,  -- layout: the logo big in the middle, the HP / MP ring round it, the gear outside
    show_ring = false, -- the HP / MP ring round the gear (off = the gear floats on its own; the default look)
    mid_anim = true,   -- the animation of the icon / artwork in the middle (off = still, lighter)
    low_on  = true,    -- under 50% HP / MP: a soft breathing glow on that side of the ring and on its number
    bezel_fx = true,   -- the light gliding along the HP / MP ring and the pulsing level (off = they stand still)
    stat_size = 1.0,   -- the size of the HP / MP / TP text
    stat_mode = 'wheel', -- HP / MP / TP: 'wheel' (round the wheel) or 'bars' (three bars of their own, each draggable)
    sb_scale = 1.0, sb_len = 1.0, sb_tp = true, sb_mp = true, sb_fx = 'same',
    sb_thick = 1.0, sb_hp_size = 1.0, sb_mp_size = 1.0, sb_tp_size = 1.0, sb_hp_len = 1.0, sb_mp_len = 1.0, sb_tp_len = 1.0,
    hpbar_x = -1, hpbar_y = -1, mpbar_x = -1, mpbar_y = -1, tpbar_x = -1, tpbar_y = -1,
    sb_anchor = 0,           -- the dots by your HP number: 0 = each bar free, 1 = MP and TP stacked under HP, 2 = side by side
    theme   = 'sumi',    -- the Orbit's look: 'classic' (bars on the bezel), 'sumi' (ink brush ring), 'neon' (glowing ring)
};
local cfg = settings.load(defaults, 'equip');

local ui = {
    place    = true,   -- put the card at the saved spot on the next frame (load / reset / settings change)
    menu     = false,  -- the settings panel
    menu_pos = nil,    -- where to open it (next to the card)
};
settings.register('equip', 'ye_settings_update', function(s)
    if s ~= nil then cfg = s; end
    ui.place = true;
end);

local function msg(t) print(chat.header(addon.name):append(chat.message(t))); end
local function save() settings.save('equip'); end

----------------------------------------------------------------------------------------------------
-- Look: YunaGearOpt's palette (navy panels, periwinkle accent)
----------------------------------------------------------------------------------------------------
local C = {
    bg       = { 0.086, 0.098, 0.145, 1.00 },
    side     = { 0.067, 0.078, 0.118, 1.00 },
    card     = { 0.125, 0.145, 0.222, 1.00 },
    face     = { 0.045, 0.052, 0.085, 1.00 },   -- the equipment card
    frame    = { 0.176, 0.196, 0.271, 1.00 },
    frame_hi = { 0.220, 0.243, 0.333, 1.00 },
    border   = { 0.560, 0.620, 1.000, 0.12 },
    line     = { 0.700, 0.750, 1.000, 0.08 },
    rall     = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15,   -- round all corners (0 = none in this ImGui)
    gold     = { 0.74, 0.66, 0.95, 1.00 },      -- the accent (YGO called it "gold"): YunaUI's soft lavender now
    ice      = { 0.550, 0.880, 1.000, 1.00 },
    text     = { 0.910, 0.922, 0.957, 1.00 },
    muted    = { 0.545, 0.576, 0.667, 1.00 },
    aug      = { 0.720, 0.560, 1.000, 1.00 },
    red      = { 1.000, 0.450, 0.450, 1.00 },
};
local function u32(c) return imgui.GetColorU32(c); end
local function esc(t) return tostring(t); end                       -- (this ImGui prints text as it is: no %% doubling)

-- Equipmon's 4x4 order (slot ids)
local GRID = { 0x00, 0x01, 0x02, 0x03, 0x04, 0x09, 0x0B, 0x0C, 0x05, 0x06, 0x0D, 0x0E, 0x0F, 0x0A, 0x07, 0x08 };
-- The same 16 slots, in Equipmon's order, reflowed: { name (columns x rows), columns }
local LAYOUTS = { { '4x4', 4 }, { '8x2', 8 }, { '2x8', 2 }, { '16x1', 16 }, { '1x16', 1 } };
local ICON_SIZES = { 16, 20, 24, 28, 32, 36, 40, 48 };
-- Size is gone from the settings (Icon size does the same): fold an old Size into the icon size once
if (tonumber(cfg.size_v) or 1) < 2 then
    local px = (tonumber(cfg.icon) or 36) * (tonumber(cfg.scale) or 1);
    local best = 36;
    for _, v in ipairs(ICON_SIZES) do if math.abs(v - px) < math.abs(best - px) then best = v; end end
    cfg.icon, cfg.scale, cfg.size_v = best, 1.0, 2;
    settings.save('equip');
end


-- The set name's font is Bahnschrift by default now (the user's pick): switch to it once
if (tonumber(cfg.set_font_v) or 1) < 2 then cfg.set_font, cfg.set_font_v = 'bahn', 2; settings.save('equip'); end

-- The job icon in the middle and the gear set under the wheel is the default look: switch to it once
if (tonumber(cfg.middle_v) or 1) < 3 then cfg.middle, cfg.middle_v = 'icon', 3; settings.save('equip'); end
if cfg.middle ~= 'art' and cfg.middle ~= 'icon' then cfg.middle = 'icon'; settings.save('equip'); end

-- Only Black is left: everyone is on it
if cfg.disc ~= 'black' then cfg.disc = 'black'; settings.save('equip'); end

-- Under the wheel: just the gear set's name now (the weapon crest is gone): switch to it once
if (tonumber(cfg.bottom_v) or 1) < 3 then cfg.bottom, cfg.bottom_v = 'set', 3; settings.save('equip'); end

-- Classic is gone from the themes: anyone on it moves to Sumi-e
if cfg.theme ~= 'sumi' and cfg.theme ~= 'neon' then cfg.theme = 'sumi'; settings.save('equip'); end
-- (YunaUI) only the Orbit style, only the job icon in the middle (no artwork), no smoke on gear swaps
if cfg.style ~= 'orbit' or cfg.middle ~= 'icon' or cfg.flash ~= false then cfg.style, cfg.middle, cfg.flash = 'orbit', 'icon', false; settings.save('equip'); end
if cfg.show_icon == nil then cfg.show_icon = true; end
if cfg.mid_bars == nil then cfg.mid_bars = true; end

-- The ink background is the new look: switch to it once (the others stay in the settings)
if (tonumber(cfg.bg_v) or 1) < 2 then cfg.bg, cfg.bg_v = 'ink', 2; settings.save('equip'); end

-- The MP timer is off by default now too (the user didn't need it); it stays in the settings
if (tonumber(cfg.mp_v) or 1) < 2 then cfg.mptimer, cfg.mp_v = false, 2; settings.save('equip'); end
-- The state name on top is off by default now (looks cleaner); it stays in the settings
if (tonumber(cfg.state_v) or 1) < 2 then cfg.state, cfg.state_v = false, 2; settings.save('equip'); end

-- Fixed choices, no longer in the settings: idle is black, the living border and engage ripple are on,
-- the state name and the MP timer are off
cfg.idle_color, cfg.living, cfg.ripple, cfg.state, cfg.mptimer = 'black', false, true, false, false;

local function layout_cols()
    for _, l in ipairs(LAYOUTS) do if l[1] == cfg.layout then return l[2]; end end
    return 4;
end
-- Next / previous entry of a list, starting from the current value
local function step_list(list, cur, dir, key)
    local idx = 1;
    for i, v in ipairs(list) do if (key and v[key] or v) == cur then idx = i; end end
    local v = list[(idx - 1 + dir) % #list + 1];
    return key and v[key] or v;
end

----------------------------------------------------------------------------------------------------
-- Fonts: Segoe UI (YGO's text) and Bahnschrift (for the title), from Windows' own Fonts folder.
-- Loaded once when the addon loads; if they're missing the game's ImGui font is used.
----------------------------------------------------------------------------------------------------
local fonts = { main = nil, title = nil, semi = nil, serif = nil, labels = {}, set = {} };
-- The fonts the set's name can use (Windows' own): { key, name shown, file }
local SET_FONTS = {
    { 'georgia',   'Georgia',     'georgiab.ttf' },
    { 'palatino',  'Palatino',    'palab.ttf' },
    { 'cambria',   'Cambria',     'cambriab.ttf' },
    { 'constantia','Constantia',  'constanb.ttf' },
    { 'bahn',      'Bahnschrift', 'bahnschrift.ttf' },
    { 'segoe',     'Segoe UI',    'seguisb.ttf' },
    { 'trebuchet', 'Trebuchet',   'trebucbd.ttf' },
    { 'impact',    'Impact',      'impact.ttf' },
};
-- and its colours: { key, name shown, colour }
local SET_COLORS = {
    { 'gold',   'Gold',       { 1.00, 0.84, 0.50 } },
    { 'white',  'White',      { 1.00, 1.00, 1.00 } },
    { 'silver', 'Silver',     { 0.80, 0.83, 0.88 } },
    { 'peri',   'Periwinkle', { 0.58, 0.66, 1.00 } },
    { 'ice',    'Ice',        { 0.60, 0.90, 1.00 } },
    { 'red',    'Red',        { 1.00, 0.40, 0.42 } },
    { 'blue',   'Blue',       { 0.40, 0.64, 1.00 } },
    { 'green',  'Green',      { 0.55, 0.95, 0.55 } },
};
-- The fonts the state name can use: { name, file in this addon's fonts folder, size }
local NAME_FONTS = {
    { 'Shojumaru', 'Shojumaru-Regular.ttf', 17 },   -- Japanese-style brush caps (OFL)
};
local function load_fonts()
    fonts.yui = {};
    if YUI_OLDIMGUI then return; end                                 -- (plain Ashita: no fonts of our own, see YUI_OLDIMGUI in yunaui.lua)
    local dir = (os.getenv('WINDIR') or 'C:\\Windows') .. '\\Fonts\\';
    local function add(name, size)
        local f = io.open(dir .. name, 'rb');
        if f == nil then return nil; end
        f:close();
        local ok, font = pcall(imgui.AddFontFromFileTTF, dir .. name, size);
        return (ok and font) or nil;
    end
    fonts.main = add('segoeui.ttf', 17) or add('SegUIVar.ttf', 17);
    fonts.title = add('bahnschrift.ttf', 22);
    fonts.semi = add('seguisb.ttf', 20);             -- Segoe UI Semibold: HP / MP / TP
    fonts.serif = add('georgia.ttf', 18);            -- Georgia: the weapon crest's label
    -- YunaUI's font (AvantGarde style) for the separate HP / MP / TP bars, made at a few sizes
    fonts.yui = {};
    local yf = (YUI_EQ_PATH:gsub('[\\/]+$', '')) .. '\\fonts\\texgyreadventor-regular.otf';
    local yh = io.open(yf, 'rb');
    if yh then
        yh:close();
        for _, px in ipairs(YUI_OLDIMGUI and { 18, 32 } or { 13, 18, 24, 32, 44 }) do
            local ok, ft = pcall(imgui.AddFontFromFileTTF, yf, px);
            if ok and ft then fonts.yui[#fonts.yui + 1] = { ft, px }; end
        end
    end
    for _, sf in ipairs(SET_FONTS) do                                -- (plain Ashita: only the one in use, see YUI_OLDIMGUI)
        if not YUI_OLDIMGUI or sf[1] == (cfg.set_font or 'bahn') then fonts.set[sf[1]] = add(sf[3], 26); end
    end
    -- The state name's fonts: every one in NAME_FONTS that is there (missing ones are skipped)
    local mine = (YUI_EQ_PATH:gsub('[\\/]+$', '')) .. '\\fonts\\';
    for _, nf in ipairs(YUI_OLDIMGUI and {} or NAME_FONTS) do
        local font = nil;
        if nf[2] then
            local f = io.open(mine .. nf[2], 'rb');
            if f then
                f:close();
                local ok, ft = pcall(imgui.AddFontFromFileTTF, mine .. nf[2], nf[3]);
                if ok then font = ft; end
            end
        else
            font = add('bahnschrift.ttf', nf[3]);
        end
        if font then fonts.labels[nf[1]] = { font = font, size = nf[3] }; end
    end
end
local function push_font(f, size)
    if f == nil then return false; end
    if YUI_NEWFONT(f) then return (pcall(imgui.PushFont, f, size)); end   -- newer ImGui: any size
    return (pcall(imgui.PushFont, f));
end
-- Older ImGui can't size a pushed font, so the card scales it with the window font scale instead
local function font_scale(sc)
    if fonts.main and YUI_NEWFONT(fonts.main) then return 1; end
    return sc;
end
-- The name font (Shojumaru) and its size; nil = it didn't load, the card's font is used
local function label_font()
    local l = fonts.labels['Shojumaru'];
    if l == nil then return nil, 17; end
    return l.font, l.size;
end

----------------------------------------------------------------------------------------------------
-- Item icons from the game files, loaded once per item id. While loading, each icon gets YGO's colour lift and
-- its main colour is measured (weighted by how colourful each pixel is) for its glow.
----------------------------------------------------------------------------------------------------
local icons = {};
local function item_icon(id)
    if id == nil or id == 0 or id == 65535 then return nil; end
    if icons[id] ~= nil then return icons[id] or nil; end
    icons[id] = false;
    pcall(function()
        local item = AshitaCore:GetResourceManager():GetItemById(id);
        if item == nil or item.Bitmap == nil or (item.ImageSize or 0) == 0 then return; end
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        if ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), item.Bitmap, item.ImageSize, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
                ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, ptr) ~= ffi.C.S_OK then
            return;
        end
        local tex = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
        local sr, sg, sb, sw = 0, 0, 0, 0;
        local is_hq, final_px, fw, fh = false, nil, 32, 32;
        pcall(function()
            local w, h = 32, 32;
            local dres, desc = tex:GetLevelDesc(0);
            if dres == ffi.C.S_OK and desc ~= nil then w, h = tonumber(desc.Width), tonumber(desc.Height); end
            local res, rect = tex:LockRect(0, nil, 0);
            if res ~= ffi.C.S_OK or rect == nil then return; end
            local bits, pitch = ffi.cast('uint8_t*', rect.pBits), tonumber(rect.Pitch);
            -- HQ / +1 items sit in a bevelled grey square (a light outer band, a darker grey inside). The square is
            -- faded into a soft round halo: still a hint that the piece is HQ, but no corners or edges. Such icons have
            -- a fully solid edge (normal icons have see-through edges); every smooth, neutral grey area joined to the
            -- edge is the square, followed through gradual shade changes. (Tuned on real icons.)
            pcall(function()
                local function px_at(xx, yy) return bits + yy * pitch + xx * 4; end
                local function neutral(q)
                    if q[3] == 0 then return false; end
                    return math.max(q[0], q[1], q[2]) - math.min(q[0], q[1], q[2]) <= 3 and (q[0] + q[1] + q[2]) / 3 >= 95;   -- the box is pure grey
                end
                local edge = {};
                for xx = 0, w - 1 do edge[#edge + 1] = { xx, 0 }; edge[#edge + 1] = { xx, h - 1 }; end
                for yy = 1, h - 2 do edge[#edge + 1] = { 0, yy }; edge[#edge + 1] = { w - 1, yy }; end
                local queue = {};
                for _, e in ipairs(edge) do
                    local q = px_at(e[1], e[2]);
                    if q[3] < 255 then return; end                       -- see-through edge: a normal icon
                    if neutral(q) then queue[#queue + 1] = e; end
                end
                if #queue < #edge * 0.2 then return; end
                is_hq = true;                                        -- the grey square = an HQ / +1 item
                local seen = {};
                for _, e in ipairs(queue) do seen[e[2] * w + e[1]] = true; end
                local back, head = {}, 1;
                while head <= #queue do
                    local e = queue[head]; head = head + 1;
                    local q = px_at(e[1], e[2]);
                    back[#back + 1] = e;
                    for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                        local nx, ny = e[1] + o[1], e[2] + o[2];
                        local key = ny * w + nx;
                        if nx >= 0 and ny >= 0 and nx < w and ny < h and not seen[key] then
                            local nq = px_at(nx, ny);
                            -- the square is only a 4 px bevelled band round the edge: never follow grey further in
                            -- (light grey sleeves, trousers... joined to it were being cut away)
                            local band = math.min(nx, ny, w - 1 - nx, h - 1 - ny) <= 3;
                            if band and neutral(nq) and math.max(math.abs(nq[0] - q[0]), math.abs(nq[1] - q[1]), math.abs(nq[2] - q[2])) <= 24 then
                                seen[key] = true;
                                queue[#queue + 1] = { nx, ny };
                            end
                        end
                    end
                end
                -- the square goes see-through: the white ring round the item marks it as HQ instead. Then every light,
                -- grey pixel left near the edge (6 px) goes too (the bevel isn't always perfectly grey: it left thin lines)
                for _, e in ipairs(back) do px_at(e[1], e[2])[3] = 0; end
                for yy = 0, h - 1 do
                    for xx = 0, w - 1 do
                        if math.min(xx, yy, w - 1 - xx, h - 1 - yy) <= 5 then
                            local q = px_at(xx, yy);
                            local mx_, mn_ = math.max(q[0], q[1], q[2]), math.min(q[0], q[1], q[2]);
                            if q[3] > 0 and mx_ - mn_ <= 10 and (q[0] + q[1] + q[2]) / 3 >= 60 then q[3] = 0; end
                        end
                    end
                end
            end);
            for yy = 0, h - 1 do
                local row = bits + yy * pitch;
                for xx = 0, w - 1 do
                    local px = row + xx * 4;
                    if px[3] > 0 then
                        local bl, gr, rd = px[0], px[1], px[2];
                        local l = 0.114 * bl + 0.587 * gr + 0.299 * rd;
                        local wgt = (math.max(rd, gr, bl) - math.min(rd, gr, bl) + 8) * px[3] / 255;
                        sr, sg, sb, sw = sr + rd * wgt, sg + gr * wgt, sb + bl * wgt, sw + wgt;
                        for c, v in ipairs({ bl, gr, rd }) do
                            local o = (l + (v - l) * 1.35) * 1.12;
                            px[c - 1] = o < 0 and 0 or (o > 255 and 255 or math.floor(o + 0.5));
                        end
                    end
                end
            end
            -- the finished pixels, for the sharp enlarged copies (item_big)
            local rows = {};
            for yy = 0, h - 1 do rows[#rows + 1] = ffi.string(bits + yy * pitch, w * 4); end
            final_px, fw, fh = table.concat(rows), w, h;
            tex:UnlockRect(0);
        end);
        local glow = { 0.55, 0.62, 1.0 };
        if sw > 0 then
            local mx = math.max(sr, sg, sb, 1);
            glow = { sr / mx, sg / mx, sb / mx };                       -- full brightness, same hue
        end
        -- the HD copy (images\items\<id>.png: upscaled from this icon, already cleaned and lifted) is drawn instead
        -- when there is one; the game icon above still gives the glow colour and the HQ mark
        pcall(function()
            local f = io.open(YUI_EQ_PATH .. '\\..\\images\\items\\' .. id .. '.png', 'rb');
            if f == nil then return; end
            local data = f:read('*a');
            f:close();
            local hp = ffi.new('IDirect3DTexture8*[1]');
            if ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), data, #data, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
                    ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0, nil, nil, hp) == ffi.C.S_OK then
                tex = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', hp[0]));
                final_px = nil;                                         -- (no smoothed copies needed: it's already sharp)
            end
        end);
        icons[id] = { tex = tex, ptr = tonumber(ffi.cast('uint32_t', tex)), glow = glow, hq = is_hq, px = final_px, w = fw, h = fh };
    end);
    return icons[id] or nil;
end
YUI_EQ_ICON = item_icon;                                            -- (YunaUI's diamond ring uses these cleaned icons too)

-- Sharp enlarged icons: the game's icons are 32x32, and stretched by the GPU they go blocky / grainy. Each icon is
-- resized smoothly (Catmull-Rom bicubic, premultiplied alpha) to the exact size it's shown at, once per size, and
-- drawn 1:1. Made one per frame from a queue, so a full set of new icons never stutters.
local bigs, big_queue = {}, {};
local function resample(px, w, h, S)
    local n = w * h;
    local src = ffi.new('uint8_t[?]', #px);
    ffi.copy(src, px, #px);
    local ch = {};                                                  -- premultiplied b, g, r and alpha
    for c = 0, 3 do ch[c] = ffi.new('float[?]', n); end
    for i = 0, n - 1 do
        local a = src[i * 4 + 3] / 255;
        ch[0][i], ch[1][i], ch[2][i], ch[3][i] = src[i * 4] * a, src[i * 4 + 1] * a, src[i * 4 + 2] * a, a;
    end
    local function taps(N)                                          -- 4 source indices + weights per output pixel
        local idx, wt = ffi.new('int[?]', S * 4), ffi.new('float[?]', S * 4);
        for o = 0, S - 1 do
            local sp = (o + 0.5) * N / S - 0.5;
            local i0 = math.floor(sp);
            local t = sp - i0;
            local t2, t3 = t * t, t * t * t;
            local ws = { (-t3 + 2 * t2 - t) / 2, (3 * t3 - 5 * t2 + 2) / 2, (-3 * t3 + 4 * t2 + t) / 2, (t3 - t2) / 2 };
            for k = 0, 3 do
                idx[o * 4 + k] = math.min(N - 1, math.max(0, i0 - 1 + k));
                wt[o * 4 + k] = ws[k + 1];
            end
        end
        return idx, wt;
    end
    local xi, xw = taps(w);
    local yi, yw = taps(h);
    local tmp = {};                                                 -- horizontal pass: h rows of S
    for c = 0, 3 do
        local t, sch = ffi.new('float[?]', h * S), ch[c];
        for y = 0, h - 1 do
            for o = 0, S - 1 do
                local acc = 0;
                for k = 0, 3 do acc = acc + sch[y * w + xi[o * 4 + k]] * xw[o * 4 + k]; end
                t[y * S + o] = acc;
            end
        end
        tmp[c] = t;
    end
    local ok, tex = pcall(function()
        local hr, t = d3d.get_device():CreateTexture(S, S, 1, 0, ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED);
        if hr ~= ffi.C.S_OK or t == nil then return nil; end
        return d3d.gc_safe_release(t);
    end);
    if not ok or tex == nil then return nil; end
    local res, rect = tex:LockRect(0, nil, 0);
    if res ~= ffi.C.S_OK or rect == nil then return nil; end
    local bits, pitch = ffi.cast('uint8_t*', rect.pBits), tonumber(rect.Pitch);
    for oy = 0, S - 1 do                                            -- vertical pass, straight into the texture
        local row = bits + oy * pitch;
        for ox = 0, S - 1 do
            local v = { 0, 0, 0, 0 };
            for c = 0, 3 do
                local acc, t = 0, tmp[c];
                for k = 0, 3 do acc = acc + t[yi[oy * 4 + k] * S + ox] * yw[oy * 4 + k]; end
                v[c + 1] = acc;
            end
            local a = math.max(0, math.min(1, v[4]));
            local q = row + ox * 4;
            if a > 0.004 then
                for c = 0, 2 do q[c] = math.max(0, math.min(255, math.floor(v[c + 1] / a + 0.5))); end
            else
                q[0], q[1], q[2] = 0, 0, 0;
            end
            q[3] = math.floor(a * 255 + 0.5);
        end
    end
    tex:UnlockRect(0);
    return { tex = tex, ptr = tonumber(ffi.cast('uint32_t', tex)) };
end
-- The icon at exactly S px (nil until it's been made; the 32 px one is used meanwhile)
-- Plain Ashita runs DirectX 8: making new textures while playing can stall it, so there the game's own icons are
-- used as they are (no sharp enlarged copies). VanaCore (DirectX 12) gets them.
local IS_DX8 = nil;
local function item_big(id, ic, S)
    if IS_DX8 == nil then
        IS_DX8 = true;
        pcall(function() IS_DX8 = not AshitaCore:GetInstallPath():lower():find('vanacore', 1, true); end);
    end
    if IS_DX8 then return nil; end
    if ic == nil or ic.px == nil or S == ic.w then return nil; end
    local key = id .. ':' .. S;
    local b = bigs[key];
    if b == nil then
        bigs[key] = false;
        big_queue[#big_queue + 1] = { key = key, ic = ic, S = S };
        return nil;
    end
    return b or nil;
end
local function make_next_big()
    local job = table.remove(big_queue, 1);
    if job == nil then return; end
    local ok, b = pcall(resample, job.ic.px, job.ic.w, job.ic.h, job.S);
    bigs[job.key] = (ok and b) or nil;
end

-- The Yuna logo (images\logo.png) for the middle of the Orbit
local logos = {};
local function logo_texture(name)
    name = name or 'logo.png';
    if logos[name] ~= nil then return logos[name] or nil; end
    logos[name] = false;
    pcall(function()
        local f = io.open(YUI_EQ_PATH .. '/images/' .. name, 'rb');
        if f == nil then return; end
        local data = f:read('*a');
        f:close();
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        if ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), data, #data, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
                ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0, nil, nil, ptr) == ffi.C.S_OK then
            local tex = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
            logos[name] = { tex = tex, ptr = tonumber(ffi.cast('uint32_t', tex)) };
        end
    end);
    return logos[name] or nil;
end
-- Where the katana runs on the logo (fractions of the picture): the guard, and the tip
local BLADE_AXIS = { 0.273, 0.387, 0.984, 0.893 };

-- Blood dripping off the end of the logo's katana: drops swell on the blade's edge (the tip and two spots just
-- before it), fall and leave a tiny splash, each spot on its own rhythm. { x, y (fractions of the logo), phase, fall }
local LOGO_DRIPS = { { 0.985, 0.945, 0.0, 0.16 }, { 0.890, 0.855, 0.9, 0.22 }, { 0.825, 0.795, 1.8, 0.26 } };
local function logo_blood(dl, x, y, w)
    local t = os.clock();
    local function col(al) return imgui.GetColorU32({ 0.66, 0.05, 0.07, al }); end
    for _, d in ipairs(LOGO_DRIPS) do
        local tx, ty = x + d[1] * w, y + d[2] * w + w * 0.012;
        local land = ty + d[4] * w;
        local ph = (t + d[3]) % 2.7;
        if ph < 1.2 then                                            -- swelling on the edge
            local rr = w * (0.011 + 0.017 * ph / 1.2);
            dl:AddLine({ tx, ty - rr }, { tx, ty + rr }, col(0.9), rr * 0.9);
            dl:AddCircleFilled({ tx, ty + rr * 1.2 }, rr, col(0.92), 12);
        elseif ph < 1.65 then                                       -- falling, speeding up
            local u = (ph - 1.2) / 0.45;
            local fy = ty + w * 0.02 + (land - ty - w * 0.02) * u * u;
            dl:AddCircleFilled({ tx, fy }, w * 0.026, col(0.92), 12);
            dl:AddCircleFilled({ tx, fy - w * 0.026 }, w * 0.015, col(0.8), 10);
        elseif ph < 2.4 then                                        -- a tiny splash, fading
            local al = 1 - (ph - 1.65) / 0.75;
            dl:AddCircleFilled({ tx, land }, w * 0.024, col(0.85 * al), 12);
            for _, f in ipairs({ { -1.0, -0.5 }, { 1.1, -0.6 }, { -1.8, 0.1 }, { 1.7, 0.2 } }) do
                dl:AddCircleFilled({ tx + f[1] * w * 0.04, land + f[2] * w * 0.024 }, w * 0.011, col(0.75 * al), 8);
            end
        end
    end
end

-- While the figure in the middle is drawn, every picture is faded by the "Artwork opacity" setting
local ART = { on = false, a = 1 };
-- Troubleshooting: /ye debug <part> hides one part of the Orbit at a time ('icon' = whatever is in the middle,
-- the job icon or the artwork) (to find what a player's PC dislikes)
DBG = { ring = false, slots = false, icon = false, text = false, clamp = false };
local function draw_image(dl, tex, x1, y1, x2, y2, alpha, tint)
    if ART.on then
        local t = tint or { 1, 1, 1, alpha or 1 };
        tint = { t[1], t[2], t[3], (t[4] or 1) * ART.a };
    end
    local ok = pcall(function() dl:AddImage(tex.ptr, { x1, y1 }, { x2, y2 }, { 0, 0 }, { 1, 1 }, u32(tint or { 1, 1, 1, alpha or 1 })); end);
    if not ok and (tint == nil or tint[1] > 0.3) then dl:AddImage(tex.ptr, { x1, y1 }, { x2, y2 }); end
end

-- Every job but Samurai has its own figure (Blue Mage, Ranger and Ninja are the user's own pictures) in the middle of the Orbit (images\jobs): job_XXX.png is the figure,
-- job_XXX_fx.png its coloured energy. Samurai (and a job with no picture, like Ranger) keeps the Yuna samurai.
local JOBS = {
    art = { [1] = 'war', [2] = 'mnk', [3] = 'whm', [4] = 'blm', [5] = 'rdm', [6] = 'thf', [7] = 'pld', [8] = 'drk',
            [9] = 'bst', [10] = 'brd', [11] = 'rng', [13] = 'nin', [14] = 'drg', [15] = 'smn', [16] = 'blu', [17] = 'cor', [18] = 'pup',
            [19] = 'dnc', [20] = 'sch', [21] = 'geo', [22] = 'run' },
    color = { war = { 1.00, 0.50, 0.15 }, mnk = { 0.25, 0.55, 1.00 }, whm = { 0.95, 0.97, 1.00 }, blm = { 0.50, 0.38, 1.00 },
              rdm = { 1.00, 0.25, 0.25 }, thf = { 0.50, 0.92, 0.25 }, pld = { 0.92, 0.95, 1.00 }, drk = { 0.88, 0.12, 0.20 },
              bst = { 1.00, 0.75, 0.25 }, brd = { 0.30, 0.88, 0.88 }, nin = { 0.85, 0.22, 0.48 }, blu = { 0.30, 0.52, 1.00 }, rng = { 0.55, 0.85, 0.35 }, drg = { 0.62, 0.30, 1.00 },
              smn = { 0.78, 0.30, 0.95 }, wak = { 0.75, 0.35, 0.95 }, cor = { 0.25, 0.52, 1.00 }, pup = { 0.95, 0.22, 0.32 },
              dnc = { 1.00, 0.42, 0.72 }, sch = { 1.00, 0.80, 0.30 }, geo = { 0.35, 0.95, 0.70 }, run = { 0.30, 0.55, 1.00 } },
    -- melee jobs draw their weapon when they engage, like the samurai: { grip x, grip y, tip x, tip y } per weapon
    weapons = {
        war = { { 0.547, 0.531, 0.815, 0.329, 0.30 } },        -- (5th: extra room for the axe head)
        thf = { { 0.195, 0.383, 0.057, 0.687 }, { 0.809, 0.461, 0.910, 0.742 } },
        pld = { { 0.406, 0.379, -0.105, 0.792, 0.07, 1.5 } },   -- long golden sword, on a 1.5x picture (6th value)
        drk = { { 0.555, 0.449, 0.997, 0.814 } },
        drg = { { 0.578, 0.496, 0.991, 0.728 } },
        nin = { { 0.273, 0.250, 0.027, 0.410 }, { 0.750, 0.555, 0.988, 0.840 } },   -- the user's own ninja, two katanas
        cor = { { 0.273, 0.277, 0.020, 0.181 }, { 0.773, 0.594, 0.957, 0.831 } },
        run = { { 0.328, 0.500, 0.961, 0.832 } },
        bst = { { 0.258, 0.387, 0.031, 0.492 } },
        mnk = { { 0.346, 0.458, 0.204, 0.418, 0.12 }, { 0.606, 0.347, 0.723, 0.256, 0.12 } },   -- the user's gauntlets, glowing red
        blu = { { 0.344, 0.320, 0.164, 0.438, 0.16 }, { 0.648, 0.559, 0.906, 0.461, 0.16 } },   -- two books (the user's own picture)
        rng = { { 0.875, 0.379, 0.754, 0.055, 0.30 }, { 0.875, 0.387, 0.781, 0.648, 0.30 } },   -- the bow, both limbs out of the hand
    },
    on = 0, cast = 0, blade = 0,
};
-- Every clip rectangle goes through here: kept inside the screen, on whole pixels and at least 1 px in size.
-- (On plain Ashita / DirectX 8 a clip rectangle partly off the screen or with no size seems to leave a wrong
-- viewport behind, so every addon's window shakes.)
JOBS.dsp = { 1e5, 1e5 };
function JOBS.clip(dl, a, b, inter)
    local w, h = JOBS.dsp[1], JOBS.dsp[2];
    local x1 = math.floor(math.max(0, math.min(w - 1, a[1])));
    local y1 = math.floor(math.max(0, math.min(h - 1, a[2])));
    local x2 = math.ceil(math.max(x1 + 1, math.min(w, b[1])));
    local y2 = math.ceil(math.max(y1 + 1, math.min(h, b[2])));
    dl:PushClipRect({ x1, y1 }, { x2, y2 }, inter);
end
-- Out of combat the job's energy is dim and slowly breathing. Engaged or casting it flares up in the job's colour,
-- swells and drifts a little, and an aura of the job's colour pulses round the figure (faster while casting).
function JOBS.draw(dl, key, lx, ly, lw, engaged, casting, now, dt, bs, flash)
    local fig, fx = logo_texture('jobs/job_' .. key .. '.png'), logo_texture('jobs/job_' .. key .. '_fx.png');
    if fig == nil then return false; end
    -- a melee job with its weapon cut out: the figure and energy without it, the hilt, and each blade
    local wps, hilt, blades = JOBS.weapons[key], nil, {};
    if wps then
        local body, fxb = logo_texture('jobs/job_' .. key .. '_body.png'), logo_texture('jobs/job_' .. key .. '_fxb.png');
        hilt = logo_texture('jobs/job_' .. key .. '_hilt.png');
        for i = 1, #wps do blades[i] = logo_texture('jobs/job_' .. key .. '_w' .. i .. '.png'); end
        if body and fxb and hilt and #blades == #wps then fig, fx = body, fxb; else wps = nil; end
    end
    local jc = JOBS.color[key] or { 1, 1, 1 };
    JOBS.on = JOBS.on + (((engaged or casting) and 1 or 0) - JOBS.on) * math.min(1, dt * 3);
    JOBS.cast = JOBS.cast + ((casting and 1 or 0) - JOBS.cast) * math.min(1, dt * 3);
    local on, cast = JOBS.on, JOBS.cast;
    if cfg.mid_anim == false then on, cast = 0, 0; end            -- "Middle animation" off: a still figure
    -- the pulse: its own phase moves on a little every frame, a bit faster while casting. (Working it out from the
    -- clock divided by a changing speed made it jump many times a second as the speed changed: a blinking mess.)
    JOBS.ph = ((JOBS.ph or 0) + dt / (1.8 - 0.5 * cast)) % 1;
    local beat = 0.5 + 0.5 * math.sin(JOBS.ph * math.pi * 2);
    local breathe = 0.5 + 0.5 * math.sin(now / 4 * math.pi * 2);
    local dirs = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -0.7, -0.7 }, { 0.7, -0.7 }, { -0.7, 0.7 }, { 0.7, 0.7 } };
    -- the aura: copies of the figure in the job's colour, pushed out a little in every direction, behind it
    if on > 0.01 then
        local white = math.min(jc[1], jc[2], jc[3]) > 0.85;     -- White Mage / Paladin: a white aura on a white figure
        for ring = 1, 2 do                                       -- casting fades in a second, wider ring
            local wgt = (ring == 1) and 1 or cast;
            if wgt > 0.01 then
            local o = (1.0 + 0.5 * beat * (0.4 + 0.6 * cast)) * (ring == 1 and 1 or 2.6) * bs;
            local at = { jc[1], jc[2], jc[3], (0.045 + 0.025 * beat) * on * wgt * (white and 0.6 or 1) / (ring * 1.5 - 0.5) };
            for _, d in ipairs(dirs) do
                draw_image(dl, fig, lx + d[1] * o, ly + d[2] * o, lx + lw + d[1] * o, ly + lw + d[2] * o, nil, at);
            end
            end
        end
    end
    -- the energy: dim at rest; flaring, swelling and drifting when it's on
    if fx then
        local fa = math.min(1, 0.45 + 0.10 * breathe + (0.45 + 0.08 * beat) * on + (flash or 0));
        local sw = lw * (1 + 0.03 * on * (0.7 + 0.3 * beat)) / 2;
        local cx = lx + lw / 2 + math.sin(now * 0.9) * 1.4 * bs * on;
        local cy = ly + lw / 2 + math.cos(now * 0.7) * 1.4 * bs * on;
        if on > 0.01 then                                       -- a soft bloom of the energy itself
            local o = 1.5 * bs;
            for k = 1, 4 do
                local d = dirs[k + 4];
                draw_image(dl, fx, cx - sw + d[1] * o, cy - sw + d[2] * o, cx + sw + d[1] * o, cy + sw + d[2] * o, nil,
                    { jc[1], jc[2], jc[3], 0.18 * on * (0.85 + 0.15 * beat) });
            end
        end
        draw_image(dl, fx, cx - sw, cy - sw, cx + sw, cy + sw, nil, { 1, 1, 1, fa });
        if (key == 'whm' or key == 'pld') and cast > 0.01 then
            -- White Mage / Paladin casting: only the swirling streaks round them light up (white / gold), pulsing
            -- and softly blooming
            local lc = (key == 'pld') and { 1.00, 0.80, 0.32 } or { 1, 1, 1 };
            local k2 = cast * (0.75 + 0.25 * beat);
            local sw2 = sw * (1 + 0.02 * beat);
            for _, d in ipairs(dirs) do
                local o = (1.2 + 1.3 * beat) * bs;
                draw_image(dl, fx, cx - sw2 + d[1] * o, cy - sw2 + d[2] * o, cx + sw2 + d[1] * o, cy + sw2 + d[2] * o, nil, { lc[1], lc[2], lc[3], 0.22 * k2 });
            end
            draw_image(dl, fx, cx - sw2, cy - sw2, cx + sw2, cy + sw2, nil, { lc[1], lc[2], lc[3], k2 });
            draw_image(dl, fx, cx - sw2, cy - sw2, cx + sw2, cy + sw2, nil, { lc[1], lc[2], lc[3], 0.6 * k2 });
        end
    end
    -- the figure, taking on a little of the job's colour when it's on
    local m = 0.10 * on;
    local tint = { 1 - m + m * jc[1], 1 - m + m * jc[2], 1 - m + m * jc[3], 1 };
    local holy = 0;                                             -- (the old gold halo: replaced by the streaks lighting up)
    if holy > 0.01 then                                         -- White Mage / Paladin casting: a holy light behind them
        local hx_, hy_ = lx + lw / 2, ly + lw / 2;
        for k = 1, 10 do
            dl:AddCircleFilled({ hx_, hy_ }, lw * (0.52 - k * 0.04) * (1 + 0.04 * beat), u32({ 1, 0.92, 0.70, 0.045 * holy * (0.75 + 0.25 * beat) }), 48);
        end
        for _, d in ipairs(dirs) do                             -- and a bright outline of light round the figure
            local o = (2.2 + 1.2 * beat) * bs;
            draw_image(dl, fig, lx + d[1] * o, ly + d[2] * o, lx + lw + d[1] * o, ly + lw + d[2] * o, nil, { 1, 0.90, 0.62, 0.16 * holy });
        end
    end
    -- relief: a light edge up-left and a dark shadow down-right under the figure, so it looks embossed
    local ro = math.max(1, 1.4 * bs);
    draw_image(dl, fig, lx - ro, ly - ro, lx + lw - ro, ly + lw - ro, nil, { 1, 1, 1, 0.30 });
    draw_image(dl, fig, lx + ro * 1.4, ly + ro * 1.6, lx + lw + ro * 1.4, ly + lw + ro * 1.6, nil, { 0, 0, 0, 0.75 });
    draw_image(dl, fig, lx, ly, lx + lw, ly + lw, nil, tint);
    if holy > 0.01 then                                         -- the figure itself lights up
        draw_image(dl, fig, lx, ly, lx + lw, ly + lw, nil, { 1, 0.97, 0.85, 0.45 * holy * (0.7 + 0.3 * beat) });
    end
    -- drawing the weapon (engaged only): the hilt fades into the hand, then the blade slides out of it with a
    -- glint (0.4 s); putting it away goes the other way, slower (0.9 s)
    if wps then
        JOBS.blade = engaged and math.min(1, JOBS.blade + dt / 0.4) or math.max(0, JOBS.blade - dt / 0.9);
        local hilt_a = math.min(1, JOBS.blade / 0.25);
        local bo = math.max(0, math.min(1, (JOBS.blade - 0.2) / 0.8));
        local out = bo * bo * (3 - 2 * bo);
        if hilt_a > 0.01 then draw_image(dl, hilt, lx, ly, lx + lw, ly + lw, nil, { tint[1], tint[2], tint[3], tint[4] * hilt_a }); end
        if out > 0.001 then
            for i, wa in ipairs(wps) do
                local pad = (wa[5] or 0.07) * lw;
                local ex = (wa[6] or 1) * lw;                   -- a blade picture bigger than the figure's (longer blades)
                local bx1, by1 = lx + lw / 2 - ex / 2, ly + lw / 2 - ex / 2;
                local bx2, by2 = bx1 + ex, by1 + ex;
                local wtint = (key == 'pld') and { 1, 1, 1, 1 } or tint;   -- the golden sword keeps its gold
                local gx, gy = lx + wa[1] * lw, ly + wa[2] * lw;
                local hx, hy = gx + (wa[3] - wa[1]) * lw * out, gy + (wa[4] - wa[2]) * lw * out;
                if out > 0.98 then                                -- all the way out: the whole weapon
                    draw_image(dl, blades[i], bx1, by1, bx2, by2, nil, wtint);
                else
                    JOBS.clip(dl, { math.min(gx, hx) - pad, math.min(gy, hy) - pad }, { math.max(gx, hx) + pad, math.max(gy, hy) + pad }, true);
                    draw_image(dl, blades[i], bx1, by1, bx2, by2, nil, wtint);
                    dl:PopClipRect();
                end
                if key == 'mnk' and out > 0.02 then             -- the gauntlets' red glow breathes
                    local pr = 0.5 + 0.5 * math.sin(now * 2.4 + i);
                    for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
                        local o = (1.5 + 1.5 * pr) * bs;
                        draw_image(dl, blades[i], bx1 + d[1] * o, by1 + d[2] * o, bx2 + d[1] * o, by2 + d[2] * o, nil, { 1, 0.15, 0.18, 0.18 * pr * out });
                    end
                end
                if key == 'pld' and out > 0.98 then             -- light golden sparkles twinkling along the drawn sword
                    for q = 1, 6 do
                        local ph = (now * 0.8 + q * 0.37) % 1;
                        local tw = math.sin(ph * math.pi);
                        local f = 0.15 + 0.85 * ((q * 0.618) % 1);
                        local sx = gx + (wa[3] - wa[1]) * lw * f + math.sin(q * 7.1) * 2.5 * bs;
                        local sy = gy + (wa[4] - wa[2]) * lw * f + math.cos(q * 5.3) * 2.5 * bs;
                        local sr = (1.5 + 2.5 * tw) * bs;
                        dl:AddCircleFilled({ sx, sy }, sr * 1.8, u32({ 1, 0.82, 0.35, 0.18 * tw }), 12);
                        dl:AddLine({ sx - sr, sy }, { sx + sr, sy }, u32({ 1, 0.92, 0.6, 0.85 * tw }), 1 * bs);
                        dl:AddLine({ sx, sy - sr }, { sx, sy + sr }, u32({ 1, 0.92, 0.6, 0.85 * tw }), 1 * bs);
                        dl:AddCircleFilled({ sx, sy }, 0.8 * bs, u32({ 1, 1, 0.85, tw }), 8);
                    end
                end
                if JOBS.blade < 1 and engaged and key ~= 'mnk' then   -- the glint running along the edge (not on the gauntlets)
                    local gr = (2.0 + 2.0 * out) * bs;
                    dl:AddCircleFilled({ hx, hy }, gr * 2.2, u32({ jc[1], jc[2], jc[3], 0.22 }), 16);
                    dl:AddLine({ hx - gr * 2, hy }, { hx + gr * 2, hy }, u32({ 1, 1, 1, 0.9 }), 1.2 * bs);
                    dl:AddLine({ hx, hy - gr * 2 }, { hx, hy + gr * 2 }, u32({ 1, 1, 1, 0.9 }), 1.2 * bs);
                    dl:AddCircleFilled({ hx, hy }, gr * 0.6, u32({ 1, 1, 1, 1 }), 12);
                end
            end
        end
    end
    return true;
end

----------------------------------------------------------------------------------------------------
-- What you're wearing (checked 20 times a second, so swaps show straight away)
----------------------------------------------------------------------------------------------------
local ye = { slots = {}, sig = '', next_scan = 0, encumber = 0, flash = {}, cast_until = 0, ws_t = nil };

-- Augmented gear: the extdata says "augmented" and at least one augment id is set
local function is_augmented(item)
    local e = item.Extra;
    if e == nil then return false; end
    local function rd(i)
        if type(e) == 'string' then return e:byte(i + 1) or 0; end
        local ok, v = pcall(function() return e[i]; end);
        return (ok and tonumber(v)) or 0;
    end
    if bit.band(rd(0), 0x02) == 0 or bit.band(rd(1), 0x08 + 0x10 + 0x20 + 0x80) ~= 0 then return false; end
    for k = 0, 4 do
        if bit.band(rd(2 + k * 2) + rd(3 + k * 2) * 256, 0x7FF) ~= 0 then return true; end
    end
    return false;
end

local function scan_equipment()
    local inv = AshitaCore:GetMemoryManager():GetInventory();
    local res = AshitaCore:GetResourceManager();
    local found, parts = {}, {};
    for _, slot in ipairs(GRID) do
        local e = inv:GetEquippedItem(slot);
        local entry = nil;
        if e ~= nil and e.Index ~= 0 then
            local bag, idx = bit.rshift(bit.band(e.Index, 0xFF00), 8), bit.band(e.Index, 0xFF);
            local it = inv:GetContainerItem(bag, idx);
            if it ~= nil and it.Id ~= 0 and it.Id ~= 65535 then
                entry = { id = it.Id, count = it.Count or 1, bag = bag, idx = idx, item = it };
            end
        end
        found[slot] = entry;
        parts[#parts + 1] = entry and (entry.id .. ':' .. entry.bag .. ':' .. entry.idx) or '-';
    end
    local sig = table.concat(parts, ',');
    if sig == ye.sig then
        for slot, e in pairs(found) do                             -- only the ammo count moves
            if ye.slots[slot] and e then ye.slots[slot].count = e.count; end
        end
        return;
    end
    local first, old = (ye.sig == ''), ye.slots;
    ye.sig, ye.slots = sig, {};
    for slot, e in pairs(found) do
        local r = res:GetItemById(e.id);
        ye.slots[slot] = { id = e.id, count = e.count, stack = (r and r.StackSize or 1), augmented = is_augmented(e.item) };
    end
    -- the swap effect: every slot whose item changed (not on the first look after loading)
    if not first then
        for _, slot in ipairs(GRID) do
            local o, n = old[slot], ye.slots[slot];
            if (o and o.id) ~= (n and n.id) then ye.flash[slot] = os.clock(); end
        end
    end
end

local STATUS = { [0] = 'Idle', [1] = 'Engaged', [2] = 'Dead', [3] = 'Dead', [5] = 'Mounted', [33] = 'Resting',
                 [47] = 'Sitting', [85] = 'Mounted' };
local function player_status()
    local ok, idx, st = pcall(function()
        local i = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
        return i, AshitaCore:GetMemoryManager():GetEntity():GetStatus(i);
    end);
    if not ok or idx == nil or idx == 0 then return nil; end   -- zoning / not logged in
    return STATUS[st] or '';
end

----------------------------------------------------------------------------------------------------
-- Living border: two colours flowing round it (casting = the GEAROPT title's periwinkle / ice blue), changing with
-- what you're doing. { colour 1, colour 2, pulse amount, pulse seconds }
----------------------------------------------------------------------------------------------------
local MOODS = {
    idle    = { { 0.40, 0.28, 0.80 }, { 0.58, 0.42, 0.92 }, 0.15, 4.0 },   -- violet, deepened towards the card's navy
    engaged = { { 1.00, 0.16, 0.22 }, { 1.00, 0.55, 0.30 }, 0.45, 1.1 },
    casting = { { 0.49, 0.557, 1.00 }, { 0.55, 0.88, 1.00 }, 0.50, 0.6 },  -- the GEAROPT title's periwinkle / ice blue
    resting = { { 0.28, 0.90, 0.50 }, { 0.45, 1.00, 0.88 }, 0.35, 3.0 },
    dead    = { { 0.45, 0.45, 0.50 }, { 0.65, 0.65, 0.70 }, 0.00, 1.0 },
};
ye.glow, ye.glow2, ye.pulse = { 0.40, 0.28, 0.80 }, { 0.58, 0.42, 0.92 }, 0.15;

-- Idle's colour, picked in the settings. Black and white also recolour the name: white letters with a black outline
-- on black, black letters with a white outline on white.
local IDLE_COLORS = {
    purple = { { 0.40, 0.28, 0.80 }, { 0.58, 0.42, 0.92 } },
    black  = { { 0.07, 0.07, 0.09 }, { 0.30, 0.30, 0.34 }, text = { 0.97, 0.97, 0.99 }, outline = { 0, 0, 0 } },
    white  = { { 0.80, 0.83, 0.90 }, { 1.00, 1.00, 1.00 }, text = { 0.04, 0.04, 0.06 }, outline = { 1, 1, 1 } },
};
local IDLE_ORDER = { 'purple', 'black', 'white' };
local function idle_colors() return IDLE_COLORS[cfg.idle_color] or IDLE_COLORS.purple; end

local function mood_of(status)
    if status == 'Dead' then return 'dead'; end
    if os.clock() < ye.cast_until then return 'casting'; end
    if status == 'Engaged' then return 'engaged'; end
    if status == 'Resting' then return 'resting'; end
    return 'idle';
end

-- Once a frame: eases the colours towards the mood, returns the glow strength and both colours
local function update_glow(status)
    local now = os.clock();
    local dt = math.min(0.1, now - (ye.glow_t or now));
    ye.glow_t = now;
    local ic = idle_colors();
    MOODS.idle[1], MOODS.idle[2] = ic[1], ic[2];
    local m = MOODS[cfg.living and mood_of(status) or 'idle'];
    local k = math.min(1, dt * 5);
    for i = 1, 3 do
        ye.glow[i] = ye.glow[i] + (m[1][i] - ye.glow[i]) * k;
        ye.glow2[i] = ye.glow2[i] + (m[2][i] - ye.glow2[i]) * k;
    end
    ye.pulse = ye.pulse + (m[3] - ye.pulse) * k;
    local strength = 1 + ye.pulse * math.sin(now / m[4] * math.pi * 2);
    if ye.ws_t and cfg.living then                                 -- weapon skill: a short gold flare
        local age = now - ye.ws_t;
        if age > 0.6 then
            ye.ws_t = nil;
        else
            local f = 1 - age / 0.6;
            local function mix(c, g) return { c[1] + (g[1] - c[1]) * f, c[2] + (g[2] - c[2]) * f, c[3] + (g[3] - c[3]) * f }; end
            return strength + 1.4 * f, mix(ye.glow, { 1.0, 0.82, 0.35 }), mix(ye.glow2, { 1.0, 0.95, 0.70 });
        end
    end
    return strength, ye.glow, ye.glow2;
end

-- Points along a rounded rectangle, about every `step` px, clockwise from the top-left
local function rrect_points(x1, y1, x2, y2, r, step)
    local pts = {};
    local function line(ax, ay, bx, by)
        local n = math.max(1, math.floor(math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) / step));
        for i = 0, n - 1 do pts[#pts + 1] = { ax + (bx - ax) * i / n, ay + (by - ay) * i / n }; end
    end
    local function arc(cx, cy, a0, a1)
        local n = math.max(2, math.floor(r * math.pi / 2 / step));
        for i = 0, n - 1 do
            local ang = a0 + (a1 - a0) * i / n;
            pts[#pts + 1] = { cx + math.cos(ang) * r, cy + math.sin(ang) * r };
        end
    end
    local pi = math.pi;
    line(x1 + r, y1, x2 - r, y1);  arc(x2 - r, y1 + r, -pi / 2, 0);
    line(x2, y1 + r, x2, y2 - r);  arc(x2 - r, y2 - r, 0, pi / 2);
    line(x2 - r, y2, x1 + r, y2);  arc(x1 + r, y2 - r, pi / 2, pi);
    line(x1, y2 - r, x1, y1 + r);  arc(x1 + r, y1 + r, pi, pi * 1.5);
    return pts;
end

-- The border: a wide soft glow in the state's colours (outside and a little inside), then a thick line whose colour
-- flows between the two colours (three slow waves travelling round), and every 6 s a light that runs once around it
local function draw_border(dl, x1, y1, x2, y2, r, sc, gs, c1, c2)
    local now = os.clock();
    local mid = { (c1[1] + c2[1]) / 2, (c1[2] + c2[2]) / 2, (c1[3] + c2[3]) / 2 };
    local px = math.max(1, sc);
    for i = 1, 16 do                                               -- outer glow: 1 px rings, so it fades smoothly
        local o = i * px;
        local al = math.max(0, math.min(1, 0.30 * (1 - i / 17) ^ 1.6 * gs));
        dl:AddRect({ x1 - o, y1 - o }, { x2 + o, y2 + o }, u32({ mid[1], mid[2], mid[3], al }), r + o);
    end
    for i = 1, 6 do                                                -- inner glow
        local o = i * px;
        local al = math.max(0, math.min(1, 0.22 * (1 - i / 7) ^ 1.5 * gs));
        dl:AddRect({ x1 + o, y1 + o }, { x2 - o, y2 - o }, u32({ mid[1], mid[2], mid[3], al }), math.max(1, r - o));
    end
    local key = string.format('%.1f,%.1f,%.1f,%.1f,%.1f', x1, y1, x2, y2, sc);
    if ye.bkey ~= key then ye.bkey, ye.bpts = key, rrect_points(x1, y1, x2, y2, r, 3 * sc); end
    local pts, n = ye.bpts, #ye.bpts;
    local ph = now % 6;
    local sweep = ph < 1.8 and (ph / 1.8) or nil;
    for i = 1, n do
        local f = (i - 1) / n;
        local u = 0.5 + 0.5 * math.sin(now * 1.2 - f * math.pi * 6);
        local cr, cg, cb = c1[1] + (c2[1] - c1[1]) * u, c1[2] + (c2[2] - c1[2]) * u, c1[3] + (c2[3] - c1[3]) * u;
        local kk = 0;
        if sweep then
            local d = math.abs(f - sweep);
            kk = math.max(0, 1 - math.min(d, 1 - d) / 0.06);
        end
        local p, q = pts[i], pts[i % n + 1];
        dl:AddLine(p, q, u32({ cr, cg, cb, 0.35 }), 4.5 * sc);     -- a soft halo right on the line
        dl:AddLine(p, q, u32({ cr + (1 - cr) * kk, cg + (1 - cg) * kk, cb + (1 - cb) * kk, 1 }), 2.2 * sc);
    end
    if sweep then
        local hp = pts[math.floor(sweep * n) % n + 1];
        dl:AddCircleFilled(hp, 7 * sc, u32({ 1, 1, 1, 0.14 }), 16);
        dl:AddCircleFilled(hp, 2.8 * sc, u32({ 1, 1, 1, 0.9 }), 12);
    end
end

----------------------------------------------------------------------------------------------------
-- The Shadow (when a piece of gear changes): a billow of dark violet smoke swells in the slot (near-black at the
-- heart, lighter violet wisps at the edges), the new item emerges from inside it, then the cloud drifts apart and
-- fades. Everything stays inside the slot.
----------------------------------------------------------------------------------------------------
local FX_LIFE = 1.05;
local function zh(i, j) local v = math.sin(i * 12.9898 + j * 78.233) * 43758.5453; return v - math.floor(v); end
local function ease_out(u) return 1 - (1 - u) ^ 3; end
local S_CORE, S_DEEP, S_MID, S_EDGE = { 0.06, 0.00, 0.12 }, { 0.20, 0.03, 0.42 }, { 0.38, 0.10, 0.78 }, { 0.62, 0.42, 0.98 };

-- One soft puff of smoke: stacked circles, densest in the middle
-- The smoke's colours follow your job (WAR red, RNG green, WHM white, BLM black...): core, deep, mid, edge
local SMOKE_JOB = { war = { 0.85, 0.12, 0.10 }, mnk = { 1.00, 0.68, 0.20 }, whm = 'white', blm = 'black', rdm = { 0.90, 0.18, 0.25 },
    thf = { 0.45, 0.85, 0.25 }, pld = { 1.00, 0.78, 0.25 }, drk = { 0.55, 0.05, 0.12 }, bst = { 0.95, 0.60, 0.20 },
    brd = { 0.25, 0.85, 0.80 }, rng = { 0.20, 0.70, 0.25 }, sam = { 0.85, 0.15, 0.20 }, nin = { 0.30, 0.18, 0.42 },
    drg = { 0.20, 0.42, 1.00 }, smn = { 0.65, 0.30, 0.95 }, blu = { 0.15, 0.45, 0.95 }, cor = { 0.25, 0.45, 0.95 },
    pup = { 0.85, 0.40, 0.25 }, dnc = { 1.00, 0.45, 0.72 }, sch = { 0.95, 0.80, 0.45 }, geo = { 0.30, 0.85, 0.65 },
    run = { 0.40, 0.65, 1.00 } };
local SMOKE_PAL = { S_CORE, S_DEEP, S_MID, S_EDGE };
local function smoke_palette()
    local jab;
    pcall(function() jab = JOBS.abbr[AshitaCore:GetMemoryManager():GetPlayer():GetMainJob()]; end);
    local c = jab and SMOKE_JOB[jab:lower()];
    if c == 'white' then return { { 0.55, 0.55, 0.60 }, { 0.78, 0.78, 0.84 }, { 0.92, 0.92, 0.97 }, { 1, 1, 1 } }; end
    if c == 'black' then return { { 0.0, 0.0, 0.0 }, { 0.04, 0.03, 0.06 }, { 0.10, 0.09, 0.14 }, { 0.26, 0.24, 0.32 } }; end
    if type(c) ~= 'table' then return SMOKE_PAL; end
    local function mx(k, w) return { c[1] * k + w, c[2] * k + w, c[3] * k + w }; end
    return { mx(0.12, 0.0), mx(0.40, 0.0), mx(0.80, 0.0), { c[1] + (1 - c[1]) * 0.35, c[2] + (1 - c[2]) * 0.35, c[3] + (1 - c[3]) * 0.35 } };
end

local function puff(dl, x, y, r, c, al)
    if al <= 0.005 or r <= 0.5 then return; end
    dl:AddCircleFilled({ x, y }, r, u32({ c[1], c[2], c[3], al * 0.35 }), 20);
    dl:AddCircleFilled({ x, y }, r * 0.72, u32({ c[1], c[2], c[3], al * 0.45 }), 18);
    dl:AddCircleFilled({ x, y }, r * 0.45, u32({ c[1], c[2], c[3], al * 0.55 }), 14);
end

local function draw_fx(dl, mx, my, size, sc, ft, seed)
    local u = ft / FX_LIFE;
    local swell = ease_out(math.min(1, u / 0.22));                  -- billows out fast
    local fade = (u < 0.55) and 1 or (1 - (u - 0.55) / 0.45);       -- then thins and fades
    if fade <= 0.01 then return; end
    local spill = 4 * sc;                                           -- a little past the slot's edge
    JOBS.clip(dl, { mx - size / 2 - spill, my - size / 2 - spill }, { mx + size / 2 + spill, my + size / 2 + spill }, true);
    size = size * 1.3;                                              -- a bigger cloud
    local spread = 0.85 + 0.35 * u;                                 -- the cloud slowly drifts apart
    local swirl = ft * 0.9;
    local P = smoke_palette();
    local S_CORE, S_DEEP, S_MID, S_EDGE = P[1], P[2], P[3], P[4];
    -- outer wisps: light violet, thin, curling outwards
    for i = 0, 9 do
        local ang = zh(i, seed) * math.pi * 2 + swirl * ((i % 2 == 0) and 1 or -1);
        local d = size * (0.24 + 0.14 * zh(i, seed + 1)) * spread * swell;
        local r = size * (0.13 + 0.07 * zh(i, seed + 2)) * swell;
        puff(dl, mx + math.cos(ang) * d, my + math.sin(ang) * d * 0.85, r, S_EDGE, 0.55 * fade);
    end
    -- the body: rich violet puffs
    for i = 0, 8 do
        local ang = zh(i, seed + 3) * math.pi * 2 - swirl * 0.6;
        local d = size * (0.10 + 0.14 * zh(i, seed + 4)) * spread * swell;
        local r = size * (0.17 + 0.07 * zh(i, seed + 5)) * swell;
        puff(dl, mx + math.cos(ang) * d, my + math.sin(ang) * d * 0.85, r, (i % 3 == 0) and S_MID or S_DEEP, 0.85 * fade);
    end
    -- the dark heart
    for i = 0, 4 do
        local ang = zh(i, seed + 6) * math.pi * 2 + swirl * 0.4;
        local d = size * 0.07 * zh(i, seed + 7) * swell;
        puff(dl, mx + math.cos(ang) * d, my + math.sin(ang) * d, size * (0.20 + 0.05 * zh(i, seed + 8)) * swell, S_CORE, 0.9 * fade * (1 - u * 0.5));
    end
    -- a few specks of light caught in the smoke
    for i = 0, 3 do
        local tw = math.max(0, math.sin(ft * 7 + i * 1.7));
        local ang = zh(i, seed + 9) * math.pi * 2 + swirl;
        local d = size * 0.22 * zh(i, seed + 10);
        dl:AddCircleFilled({ mx + math.cos(ang) * d, my + math.sin(ang) * d }, 0.7 * sc, u32({ S_EDGE[1], S_EDGE[2], S_EDGE[3], 0.7 * tw * fade }), 6);
    end
    dl:PopClipRect();
end

-- How the new item comes in: hidden in the smoke at first, then it fades in from inside the cloud
local function fx_icon(ft)
    if ft < 0.25 then return 0.85, 0; end
    local u = math.min(1, (ft - 0.25) / 0.45);
    return 0.85 + 0.15 * ease_out(u), u;
end

-- The state's name: small, in Shojumaru (a brush font, fonts\Shojumaru-Regular.ttf), sitting in a notch on the card's
-- top edge so the glowing border passes behind it. Its letters flow between the border's two colours like YGO's
-- title. When the state changes, the old name fades out drifting up while the new one fades in from just below,
-- and the notch eases to the new width.
local STATE_NAMES = { idle = 'Idle', engaged = 'Engaged', casting = 'Casting', resting = 'Resting', dead = 'Dead' };
local LABEL_FADE = 0.4;
local function state_name(status)
    if ye.ws_label_until and os.clock() < ye.ws_label_until then return 'Weaponskill'; end
    return STATE_NAMES[mood_of(status)] or 'Idle';
end
local function name_letters(dl, text, cx, y, sc, c1, c2, al, tc, oc)
    if al <= 0.01 then return; end
    if tc then                                                       -- fixed colour with a crisp outline
        local x = cx - imgui.CalcTextSize(text) / 2;
        for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
            dl:AddText({ x + o[1] * sc, y + o[2] * sc }, u32({ oc[1], oc[2], oc[3], 0.95 * al }), text);
        end
        dl:AddText({ x, y }, u32({ tc[1], tc[2], tc[3], al }), text);
        return;
    end
    local now = os.clock();
    local x = cx - imgui.CalcTextSize(text) / 2;
    for i = 1, #text do
        local ch = text:sub(i, i);
        local u = 0.5 + 0.5 * math.sin(now * 1.2 - i * 0.45);
        local c = { c1[1] + (c2[1] - c1[1]) * u, c1[2] + (c2[2] - c1[2]) * u, c1[3] + (c2[3] - c1[3]) * u };
        for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do            -- soft glow
            dl:AddText({ x + o[1] * sc, y + o[2] * sc }, u32({ c[1], c[2], c[3], 0.18 * al }), ch);
        end
        dl:AddText({ x + 1 * sc, y + 1.2 * sc }, u32({ 0, 0, 0, 0.8 * al }), ch);       -- shadow
        dl:AddText({ x, y }, u32({ c[1] + (1 - c[1]) * 0.30, c[2] + (1 - c[2]) * 0.30, c[3] + (1 - c[3]) * 0.30, al }), ch);
        x = x + imgui.CalcTextSize(ch);
    end
end
-- The Idle name takes black / white letters when Idle's colour is black or white
local function name_style(text)
    local ic = idle_colors();
    if text == STATE_NAMES.idle and ic.text then return ic.text, ic.outline; end
    return nil, nil;
end
local function draw_state(dl, cx, ytop, sc, text, c1, c2, maxw)
    local now = os.clock();
    if ye.label ~= text then
        if ye.label then ye.label_prev, ye.label_prev_w = ye.label, ye.label_w; end
        ye.label, ye.label_t = text, now;
    end
    local f, fsz = label_font();
    local pushed = push_font(f, math.floor(fsz * sc + 0.5));
    imgui.SetWindowFontScale((pushed and YUI_NEWFONT(f)) and 1 or sc);
    local tw, th = imgui.CalcTextSize(text);
    if maxw and tw + 14 * sc > maxw then                             -- too wide for this card: leave it out
        if pushed then imgui.PopFont(); end
        imgui.SetWindowFontScale(font_scale(sc));
        return;
    end
    ye.label_w = tw;
    local k = math.min(1, (now - (ye.label_t or now)) / LABEL_FADE);
    local e = 1 - (1 - k) ^ 3;                                       -- ease out
    local fading = ye.label_prev ~= nil and k < 1;
    -- the notch: card-coloured, so the border seems to pass behind the name
    local pw = fading and ((ye.label_prev_w or tw) + (tw - (ye.label_prev_w or tw)) * e) or tw;
    local pad = 7 * sc;
    dl:AddRectFilled({ cx - pw / 2 - pad, ytop - th / 2 }, { cx + pw / 2 + pad, ytop + th / 2 }, u32(C.face), th / 2);
    dl:AddCircleFilled({ cx - pw / 2 - pad, ytop }, 1.6 * sc, u32({ c1[1], c1[2], c1[3], 0.9 }), 8);   -- where the
    dl:AddCircleFilled({ cx + pw / 2 + pad, ytop }, 1.6 * sc, u32({ c2[1], c2[2], c2[3], 0.9 }), 8);   -- border tucks in
    local y = ytop - th / 2;
    if fading then
        local ptc, poc = name_style(ye.label_prev);
        name_letters(dl, ye.label_prev, cx, y - 4 * sc * e, sc, c1, c2, 1 - e, ptc, poc);
    else
        ye.label_prev = nil;
    end
    local tc, oc = name_style(text);
    name_letters(dl, text, cx, y + 4 * sc * (1 - e), sc, c1, c2, e, tc, oc);
    if pushed then imgui.PopFont(); end
    imgui.SetWindowFontScale(font_scale(sc));
end

----------------------------------------------------------------------------------------------------
-- MP timer while /resting: seconds until MP is full, on the card's bottom edge in the same notch style.
-- The server's rule (LandSandBoat scripts/effects/healing.lua): no heal for the first 20 s, then a heal every
-- 10 s; heal number k (0, 1, 2, ...) gives  12 + MP-healing gear + k * (1 + Clear Mind)  MP.
-- Gear and Clear Mind are read off the heals; MP gained between heals (Refresh, Sublimation...) is measured as a
-- rate and added in. Until three heals have been seen (about 40 s) the time is a guess, shown with a "~".
----------------------------------------------------------------------------------------------------
-- Current MP, max MP and MP %. The max is checked against the % (what the game's own bar uses): if the
-- player max disagrees with it, the max worked out from the % is used.
local function mp_now()
    local ok, mp, mx, pct = pcall(function()
        local party = AshitaCore:GetMemoryManager():GetParty();
        local pmax = 0;
        pcall(function() pmax = AshitaCore:GetMemoryManager():GetPlayer():GetMPMax(); end);
        return party:GetMemberMP(0), pmax, party:GetMemberMPPercent(0);
    end);
    if not ok then return nil; end
    mp, mx, pct = tonumber(mp), tonumber(mx) or 0, tonumber(pct);
    if mp == nil then return nil; end
    if pct and pct >= 100 then return mp, mp, pct; end              -- the bar says full
    -- the player max is right when it gives the same whole % as the bar
    local trusted = mx >= mp and mx > 0 and pct ~= nil and math.abs(math.floor(mp * 100 / mx) - pct) <= 1;
    return mp, mx, pct, trusted;
end

-- Every frame while resting: sorts MP gains into heals (on the 20 s / 10 s rhythm) and everything else
local function track_rest(status)
    if status ~= 'Resting' then ye.rest = nil; return; end
    local mp, mx, pct, trusted = mp_now();
    if mp == nil then ye.rest = nil; return; end
    local now = os.clock();
    if ye.rest == nil then ye.rest = { t0 = now, last = mp, heals = {}, seen = {}, other = 0 }; end
    local r = ye.rest;
    if mp > r.last then
        local gain = mp - r.last;
        local since = now - r.t0;
        local n = math.floor((since - 20) / 10 + 0.5);               -- the nearest heal
        -- a heal is never under 12 MP; smaller gains are Refresh and friends even if they land near a heal
        if gain >= 10 and n >= 0 and math.abs(since - (20 + 10 * n)) <= 3 and not r.seen[n] then
            r.seen[n] = true;
            if not (pct and pct >= 100) then                         -- a heal cut short by full MP says nothing
                r.heals[#r.heals + 1] = { n = n, g = gain };
            end
            r.t0 = now - (20 + 10 * n);                              -- re-sync to the real tick
        else
            r.other = r.other + gain;                                -- Refresh and friends
        end
    end
    -- an untrusted max: narrow it down from every % reading (the real max lies in [mp*100/(pct+1), mp*100/pct])
    if not trusted and pct and pct > 0 and pct < 100 then
        r.lo = math.max(r.lo or 0, mp * 100 / (pct + 1));
        r.hi = math.min(r.hi or math.huge, mp * 100 / pct);
        if r.lo > r.hi then r.lo, r.hi = mp * 100 / (pct + 1), mp * 100 / pct; end   -- max changed (gear swap)
        mx = math.ceil((r.lo + r.hi) / 2);
    end
    if mx == nil or mx <= 0 then ye.rest = nil; return; end
    r.last, r.mp, r.mx, r.pct = mp, mp, mx, pct;
end

-- Seconds until full (0 = full), and whether it's still a guess
local function mp_full_in()
    local r = ye.rest;
    if r == nil then return nil; end
    if (r.pct and r.pct >= 100) or r.mp >= r.mx then return 0, false; end
    local now = os.clock();
    local h = r.heals;
    local first, step = 12, 1;                                       -- before any heal: no gear, no Clear Mind
    if #h >= 2 then
        -- a straight line through every heal; the step (1 + Clear Mind) is a whole number, and the base is the
        -- middle value, so a heal that shared its moment with a Refresh tick can't throw it off
        local sn, sg, snn, sng = 0, 0, 0, 0;
        for _, x in ipairs(h) do sn, sg, snn, sng = sn + x.n, sg + x.g, snn + x.n * x.n, sng + x.n * x.g; end
        local den = #h * snn - sn * sn;
        step = (den ~= 0) and math.max(1, math.floor((#h * sng - sn * sg) / den + 0.5)) or 1;
        local bases = {};
        for _, x in ipairs(h) do bases[#bases + 1] = x.g - step * x.n; end
        table.sort(bases);
        first = bases[math.floor((#bases + 1) / 2)];
    elseif #h == 1 then
        first = h[1].g - step * h[1].n;
    end
    local rate = r.other / math.max(10, now - r.t0);                 -- MP per second from everything else
    local m, t = r.mp, now;
    local n = math.max(0, math.floor((now - r.t0 - 20) / 10) + 1);  -- the next heal
    for _ = 1, 400 do
        local tt = r.t0 + 20 + 10 * n;
        if tt > t then
            if rate > 0 and m + rate * (tt - t) >= r.mx then return (t + (r.mx - m) / rate) - now, #h < 3; end
            m, t = m + rate * (tt - t), tt;
        end
        m = m + first + step * n;
        if m >= r.mx then return math.max(0, tt - now), #h < 3; end
        n = n + 1;
    end
    return nil;
end

local function draw_mp_timer(dl, cx, ybot, sc, c1, c2, maxw)
    local secs, guess = mp_full_in();
    if secs == nil then return; end
    local text, short;
    if secs <= 0 then
        text, short = 'MP full', 'MP full';
    else
        local s2 = math.ceil(secs);
        short = (guess and '~' or '') .. ((s2 >= 60) and string.format('%d:%02d', math.floor(s2 / 60), s2 % 60) or string.format('%ds', s2));
        text = 'MP full ' .. short;
    end
    local al = math.min(1, (os.clock() - ye.rest.t0) / 0.4);       -- fades in when you sit down
    local f, fsz = label_font();
    local pushed = push_font(f, math.floor(14 * sc + 0.5));
    imgui.SetWindowFontScale((pushed and YUI_NEWFONT(f)) and 1 or sc * 14 / 17);
    local tw, th = imgui.CalcTextSize(text);
    if maxw and tw + 14 * sc > maxw then                             -- narrow card: just the time
        text = short;
        tw, th = imgui.CalcTextSize(text);
    end
    if not (maxw and tw + 14 * sc > maxw) then
        local pad = 6 * sc;
        dl:AddRectFilled({ cx - tw / 2 - pad, ybot - th / 2 }, { cx + tw / 2 + pad, ybot + th / 2 }, u32({ C.face[1], C.face[2], C.face[3], al }), th / 2);
        dl:AddCircleFilled({ cx - tw / 2 - pad, ybot }, 1.4 * sc, u32({ c1[1], c1[2], c1[3], 0.9 * al }), 8);
        dl:AddCircleFilled({ cx + tw / 2 + pad, ybot }, 1.4 * sc, u32({ c2[1], c2[2], c2[3], 0.9 * al }), 8);
        name_letters(dl, text, cx, ybot - th / 2, sc, c1, c2, al);
    end
    if pushed then imgui.PopFont(); end
    imgui.SetWindowFontScale(font_scale(sc));
end

local function play_test()
    local now = os.clock();
    for i, slot in ipairs(GRID) do ye.flash[slot] = now + (i - 1) * 0.07; end   -- a quick wave over every slot
end

----------------------------------------------------------------------------------------------------
-- The equipment card
----------------------------------------------------------------------------------------------------
-- The Orbit's ring, grouped by side (clockwise from the top; degrees, 0 = right, 90 = bottom), 22.5 degrees apart.
-- Top: range, main, sub, ammo. Right: neck, earrings, rings. Bottom: back, waist. Left: feet up to head.
-- The Yuna logo sits in the middle.
local ORBIT = {
    { 0x02, -123.75 }, { 0x00, -101.25 }, { 0x01, -78.75 }, { 0x03, -56.25 },       -- range, main, sub, ammo (top)
    { 0x09, -33.75 }, { 0x0B, -11.25 }, { 0x0C, 11.25 }, { 0x0D, 33.75 }, { 0x0E, 56.25 },   -- neck, ears, rings (right)
    { 0x0F, 78.75 }, { 0x0A, 101.25 },                                              -- back, waist (bottom)
    { 0x08, 123.75 }, { 0x07, 146.25 }, { 0x06, 168.75 }, { 0x05, 191.25 }, { 0x04, 213.75 },  -- feet up to head (left)
};

-- One equipment slot at (tx, ty), T px square. k = this frame's shared values; rdelay = when the engage ripple
-- reaches this slot (seconds after it starts).
local function draw_slot(k, i, slot, tx, ty, T, rdelay, plain)
    local dl, bs, d, fs, gcol, now = k.dl, k.bs, k.d, k.fs, k.gcol, k.now;
    local tx2, ty2 = tx + T, ty + T;
    local mx, my = tx + T / 2, ty + T / 2;
    local e = ye.slots[slot];
    local ic = e and item_icon(e.id) or nil;
    local blocked = bit.band(ye.encumber, bit.lshift(1, slot)) ~= 0;
    imgui.SetCursorScreenPos({ tx, ty });
    imgui.InvisibleButton('##ye_t' .. i, { T, T });
    local hov = imgui.IsItemHovered();
    local seed = ye.flash[slot] or 0;
    local ft = cfg.flash and ye.flash[slot] and (now - ye.flash[slot]) or nil;
    if ft and ft > FX_LIFE then ye.flash[slot] = nil; ft = nil; end
    if ft and ft < 0 then ft = nil; end                         -- a test wave: not this slot's turn yet


    if hov then                                                 -- hover: a soft light in the border's colour
        dl:AddRectFilled({ tx, ty }, { tx2, ty2 }, u32({ 1, 1, 1, 0.05 }), 6 * bs);
        for j = 1, 4 do
            dl:AddCircleFilled({ mx, my }, T * (0.66 - j * 0.09), u32({ gcol[1], gcol[2], gcol[3], 0.07 * j }), 24);
        end
    end
    if k.socket then                                            -- a dark round socket with a thin grey rim
        dl:AddCircleFilled({ mx, my }, T * 0.56, u32({ 0.05, 0.05, 0.07, 0.88 }), 32);
        dl:AddCircle({ mx, my }, T * 0.56, u32({ 0.72, 0.72, 0.76, 0.55 }), 40, 1.3 * bs);
    end
    if ft then draw_fx(dl, mx, my, T, bs, ft, seed); end

    if e then
        local pad = math.floor(2 * bs);
        if ic then
            local scale, ia = 1, 1;
            if ft then scale, ia = fx_icon(ft); end
            if cfg.ripple and ye.ripple_t then                 -- engage ripple: a quick pop as the wave passes
                local ra = now - ye.ripple_t - rdelay;
                if ra > 0 and ra < 0.45 then scale = scale * (1 + 0.12 * math.sin(ra / 0.45 * math.pi)); end
            end
            if ia > 0 then
                if not plain and not k.round then               -- glow in the item's own colour (card only)
                    local g3 = ic.glow;
                    for j = 1, 5 do
                        dl:AddCircleFilled({ mx, my }, T * (0.54 - j * 0.07) * scale, u32({ g3[1], g3[2], g3[3], (0.04 + j * 0.012) * ia }), 24);
                    end
                end
                if hov and not ft and scale == 1 then scale = 1.06; end   -- the hovered item lifts a little
                -- sharp: the game's 32 px icon is drawn 1:1 when the slot is about that size (never shrunk, which
                -- blurs it), bigger slots get the smooth enlarged copy at their exact size; always on whole pixels
                local S = math.floor(T - 2 * pad + 0.5);
                if S < 36 then S = ic.w or 32; end
                ye.big_S = S;
                local tx_ = item_big(e.id, ic, S) or ic;
                local hw = S / 2 * scale;
                local x1, y1 = math.floor(mx - hw + 0.5), math.floor(my - hw + 0.5);
                local sz = math.floor(hw * 2 + 0.5);
                if not plain then
                    draw_image(dl, tx_, x1 + 1, y1 + 1, x1 + sz + 1, y1 + sz + 1, nil, { 0, 0, 0, 0.30 * ia });
                end
                draw_image(dl, tx_, x1, y1, x1 + sz, y1 + sz, ia);
            end
        end
        if e.stack > 1 and e.count then                         -- ammo count
            imgui.SetWindowFontScale(0.72 * fs * math.max(0.6, d));
            local ct = tostring(e.count);
            local cw, ch = imgui.CalcTextSize(ct);
            dl:AddText({ tx2 - cw + 1, ty2 - ch + 1 }, u32({ 0, 0, 0, 0.9 }), ct);
            dl:AddText({ tx2 - cw, ty2 - ch }, u32({ 1, 1, 1, 1 }), ct);
            imgui.SetWindowFontScale(fs);
        end
        if ic and ic.hq then                                    -- HQ / +1: a hand-drawn sketchy circle round the item
            if k.round then
                -- (no ring round HQ items any more)
            else
                dl:AddRect({ tx - 1, ty - 1 }, { tx2 + 1, ty2 + 1 }, u32({ 1, 1, 1, 0.85 }), 7 * bs);
            end
        end
        if e.augmented and k.round then                        -- augmented: no mark in the Orbit (the user removed the violet arc)
        elseif e.augmented then                                 -- a small violet diamond, top right
            local dx, dy = tx2 - 3 * bs, ty + 3 * bs;
            dl:AddTriangleFilled({ dx, dy - 3.6 * bs }, { dx + 3.0 * bs, dy }, { dx - 3.0 * bs, dy }, u32({ 0, 0, 0, 0.8 }));
            dl:AddTriangleFilled({ dx - 3.0 * bs, dy }, { dx + 3.0 * bs, dy }, { dx, dy + 3.6 * bs }, u32({ 0, 0, 0, 0.8 }));
            dl:AddTriangleFilled({ dx, dy - 2.7 * bs }, { dx + 2.1 * bs, dy }, { dx - 2.1 * bs, dy }, u32(C.aug));
            dl:AddTriangleFilled({ dx - 2.1 * bs, dy }, { dx + 2.1 * bs, dy }, { dx, dy + 2.7 * bs }, u32(C.aug));
        end
    elseif not ft and not k.round then                          -- empty: a barely-there outline (the Orbit just leaves a gap)
        dl:AddRect({ tx + 1, ty + 1 }, { tx2 - 1, ty2 - 1 }, u32({ 1, 1, 1, 0.07 }), 6 * bs);
    end
    if blocked then
        dl:AddRectFilled({ tx, ty }, { tx2, ty2 }, u32({ 0.85, 0.1, 0.12, 0.22 }), 6 * bs);
        dl:AddRect({ tx, ty }, { tx2, ty2 }, u32({ 0.95, 0.2, 0.2, 0.9 }), 6 * bs);
    end
end

-- The Orbit's living border: a circle instead of a rounded rectangle, same glow, colour wave and running light
local function draw_ring_border(dl, cx, cy, rad, bs, gs, c1, c2)
    local now = os.clock();
    local mid = { (c1[1] + c2[1]) / 2, (c1[2] + c2[2]) / 2, (c1[3] + c2[3]) / 2 };
    local px = math.max(1, bs);
    for i = 1, 16 do                                           -- outer glow
        local al = math.max(0, math.min(1, 0.30 * (1 - i / 17) ^ 1.6 * gs));
        dl:AddCircle({ cx, cy }, rad + i * px, u32({ mid[1], mid[2], mid[3], al }), 96, px * 1.1);
    end
    for i = 1, 6 do                                            -- inner glow
        local al = math.max(0, math.min(1, 0.22 * (1 - i / 7) ^ 1.5 * gs));
        dl:AddCircle({ cx, cy }, rad - i * px, u32({ mid[1], mid[2], mid[3], al }), 96, px * 1.1);
    end
    local n = 144;
    local ph = now % 6;
    local sweep = ph < 1.8 and (ph / 1.8) or nil;
    for i = 0, n - 1 do
        local f = i / n;
        local a1, a2 = -math.pi / 2 + f * math.pi * 2, -math.pi / 2 + (i + 1) / n * math.pi * 2;
        local u = 0.5 + 0.5 * math.sin(now * 1.2 - f * math.pi * 6);
        local cr, cg, cb = c1[1] + (c2[1] - c1[1]) * u, c1[2] + (c2[2] - c1[2]) * u, c1[3] + (c2[3] - c1[3]) * u;
        local kk = 0;
        if sweep then
            local dd = math.abs(f - sweep);
            kk = math.max(0, 1 - math.min(dd, 1 - dd) / 0.06);
        end
        local p, q = { cx + math.cos(a1) * rad, cy + math.sin(a1) * rad }, { cx + math.cos(a2) * rad, cy + math.sin(a2) * rad };
        dl:AddLine(p, q, u32({ cr, cg, cb, 0.35 }), 4.5 * bs);
        dl:AddLine(p, q, u32({ cr + (1 - cr) * kk, cg + (1 - cg) * kk, cb + (1 - cb) * kk, 1 }), 2.2 * bs);
    end
    if sweep then
        local a = -math.pi / 2 + sweep * math.pi * 2;
        local hp = { cx + math.cos(a) * rad, cy + math.sin(a) * rad };
        dl:AddCircleFilled(hp, 7 * bs, u32({ 1, 1, 1, 0.14 }), 16);
        dl:AddCircleFilled(hp, 2.8 * bs, u32({ 1, 1, 1, 0.9 }), 12);
    end
end

-- The Orbit's background. glass: smoked and see-through, lighter in the middle, with a bright rim. job: the same
-- glass with a faint shade of your job's colour. none: no disc, just a faint track under the ring. solid: the old one.
function JOBS.arc(dl, cx, cy, r, a1, a2, col, th)
    local n = math.max(4, math.floor(math.abs(a2 - a1) / 3));
    for i = 0, n - 1 do
        local p, q = math.rad(a1 + (a2 - a1) * i / n), math.rad(a1 + (a2 - a1) * (i + 1) / n);
        dl:AddLine({ cx + math.cos(p) * r, cy + math.sin(p) * r }, { cx + math.cos(q) * r, cy + math.sin(q) * r }, col, th);
    end
end
JOBS.abbr = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN',
              'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN' };
-- HP / MP / TP read once a frame and eased (shared by every look): returns hp, mp, tp, hp %, mp %
-- Low HP / MP warning (under 50%): 0 = fine, else a heartbeat pulse 0..1 that beats faster as it gets lower
function JOBS.low_beat(pct, now, seed)
    -- a slow, smooth breath (no flashing): about every 3 s at 50%, every 1.8 s when almost empty
    if pct == nil or pct >= 50 or pct <= 0 then return 0; end
    local k = 1 - pct / 50;
    JOBS.lb_ph = JOBS.lb_ph or {};
    local key = seed;
    local last = JOBS.lb_t or now;
    local ph = ((JOBS.lb_ph[key] or 0) + (now - (JOBS.lb_last and JOBS.lb_last[key] or now)) / (3.0 - 1.2 * k)) % 1;
    JOBS.lb_ph[key] = ph;
    JOBS.lb_last = JOBS.lb_last or {}; JOBS.lb_last[key] = now;
    local b = 0.5 - 0.5 * math.cos(ph * math.pi * 2);
    return b * (0.45 + 0.35 * k);
end

-- Low HP / MP (under 50%): the look is a setting ("Low HP / MP effect"). Each one does the ring side and the number.
function JOBS.low_ring(dl, cx, cy, r, bs, now)
    local fx = (cfg.low_on == false) and 'none' or 'breath';
    for side = 1, 2 do
        local L = JOBS.low_side and JOBS.low_side[side];
        if L and L.pct and L.pct < 50 and L.pct > 0 and fx ~= 'none' and fx ~= 'fade' and fx ~= 'tint' then
            local c, k = L.c, 1 - L.pct / 50;
            local function band(f0, f1, al, w)                       -- part of this side (0 = bottom, 1 = top)
                local a1 = (side == 1) and (90 + 180 * f0) or (90 - 180 * f0);
                local a2 = (side == 1) and (90 + 180 * f1) or (90 - 180 * f1);
                JOBS.arc(dl, cx, cy, r, math.min(a1, a2), math.max(a1, a2), u32({ c[1], c[2], c[3], al }), w * bs);
            end
            if fx == 'breath' or fx == 'glow' then
                local b = (fx == 'glow') and (0.7 + 0.3 * L.beat) or L.beat * 1.6;
                for q = 0, 23 do
                    local f = q / 24;
                    local al = (0.22 + 0.18 * k) * b * (1 - f) ^ 1.3;
                    band(f, f + 1 / 24, al * 0.45, 18);
                    band(f, f + 1 / 24, al, 9);
                end
            elseif fx == 'wave' then                                 -- a bright band rising up the side, again and again
                local ph = (now * (0.45 + 0.35 * k) + side * 0.5) % 1.2;
                for q = 0, 23 do
                    local f = q / 24;
                    local d = math.max(0, 1 - math.abs(f - ph) / 0.14);
                    if d > 0 then band(f, f + 1 / 24, 0.55 * d, 10); band(f, f + 1 / 24, 0.25 * d, 20); end
                end
            elseif fx == 'ember' then                                -- sparks drifting off the side
                for e = 1, 10 do
                    local t = (now * 0.35 + e * 0.173) % 1;
                    local f = (e * 0.618) % 0.9;
                    local a = math.rad((side == 1) and (90 + 180 * f) or (90 - 180 * f));
                    local rr = r + (6 + 26 * t) * bs;
                    local x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr - 10 * bs * t;
                    local al = (1 - t) * (0.5 + 0.4 * k);
                    dl:AddCircleFilled({ x, y }, (2.4 - 1.4 * t) * bs, u32({ c[1], c[2], c[3], al }), 10);
                    dl:AddCircleFilled({ x, y }, (5 - 2 * t) * bs, u32({ c[1], c[2], c[3], al * 0.25 }), 12);
                end
            end
        end
    end
end
-- the number's look when low: returns colour, extra glow alpha
function JOBS.low_text(beat, c, vcol)
    local fx = (cfg.low_on == false) and 'none' or 'breath';
    if beat <= 0 or fx == 'none' then return vcol, 0; end
    if fx == 'tint' then
        local m = math.min(1, beat * 1.5);
        return { 1 + (c[1] - 1) * m, 1 + (c[2] - 1) * m, 1 + (c[3] - 1) * m, vcol[4] }, 0.25 * m;
    elseif fx == 'fade' then
        return { vcol[1], vcol[2], vcol[3], 1 - 0.6 * math.min(1, beat * 1.5) }, 0;
    end
    return vcol, 0.45 * math.min(1, beat * 1.5);
end

function JOBS.stats()
    local b = JOBS.bars;
    local now = os.clock();
    local dt = math.min(0.1, now - (b.st or now));
    b.st = now;
    local hp, mp, tp, hpp, mpp = 0, 0, 0, 100, 100;
    pcall(function()
        local pt = AshitaCore:GetMemoryManager():GetParty();
        hp, mp, tp = pt:GetMemberHP(0), pt:GetMemberMP(0), pt:GetMemberTP(0);
        hpp, mpp = pt:GetMemberHPPercent(0), pt:GetMemberMPPercent(0);
    end);
    local first = (b.seen2 == nil);
    b.seen2 = true;
    for _, kv in ipairs({ { 'hp', hpp / 100 }, { 'mp', mpp / 100 }, { 'tp', math.min(3000, tp) / 3000 } }) do
        local key, v = kv[1], kv[2];
        local lag = key .. '_lag';
        if first then b[key] = v; if b[lag] then b[lag] = v; end
        else
            b[key] = b[key] + (v - b[key]) * math.min(1, dt * 8);
            if b[lag] then b[lag] = (v >= b[lag]) and v or math.max(v, b[lag] - dt * 0.35); end
        end
    end
    JOBS.hpp, JOBS.mpp = hpp, mpp;
    return hp, mp, tp, hpp, mpp;
end

-- A pill (round ends drawn by hand, so it's round on every ImGui version)
function JOBS.capsule(dl, x1, y1, x2, y2, fill, line, th)
    local rr = (y2 - y1) / 2;
    dl:AddRectFilled({ x1 + rr, y1 }, { x2 - rr, y2 }, fill);
    dl:AddCircleFilled({ x1 + rr, y1 + rr }, rr, fill, 24);
    dl:AddCircleFilled({ x2 - rr, y1 + rr }, rr, fill, 24);
    if line then
        dl:AddLine({ x1 + rr, y1 }, { x2 - rr, y1 }, line, th);
        dl:AddLine({ x1 + rr, y2 }, { x2 - rr, y2 }, line, th);
        JOBS.arc(dl, x1 + rr, y1 + rr, rr, 90, 270, line, th);
        JOBS.arc(dl, x2 - rr, y1 + rr, rr, -90, 90, line, th);
    end
end

-- Text with a dark outline. ax: -1 = ends at x, 0 = centred on x, 1 = starts at x. Returns its height.
function JOBS.text(dl, x, y, ax, str, c, scale, fs)
    imgui.SetWindowFontScale(fs * scale);
    local w, h = imgui.CalcTextSize(str);
    local x1 = (ax < 0) and (x - w) or ((ax > 0) and x or (x - w / 2));
    for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
        dl:AddText({ x1 + o[1], y + o[2] }, u32({ 0, 0, 0, 0.7 }), str);
    end
    dl:AddText({ x1, y }, u32(c), str);
    imgui.SetWindowFontScale(fs);
    return h;
end

-- HP / MP / TP, the user's own design: the stat's name in its colour, the
-- number beside it in white, and a line under the number in the stat's colour (filled as far as the stat is full).
-- In Segoe UI Semibold. ax: -1 = the group ends at x, 1 = starts at x, 0 = centred on x; y = its middle (its top
-- with ytop). Returns the group's width and height.
JOBS.badge = { HP = { 0.30, 0.10, 0.12 }, MP = { 0.12, 0.15, 0.32 }, TP = { 0.29, 0.22, 0.08 } };
JOBS.ink = { HP = { 1.00, 0.42, 0.72 }, MP = { 0.55, 0.55, 1.00 }, TP = { 1.00, 0.82, 0.42 } };
-- YunaUI's bar colours: HP pink to magenta, MP blue to violet
JOBS.UI = { hp = { 1.00, 0.36, 0.62 }, hp2 = { 0.86, 0.24, 0.86 }, mp = { 0.40, 0.55, 1.00 }, mp2 = { 0.62, 0.40, 1.00 } };
function JOBS.stat(dl, x, y, ax, label, value, c, fs, bs, ytop, frac, beat)
    local ss = math.max(0.6, math.min(2.0, tonumber(cfg.stat_size) or 1));
    bs = bs * ss;                                                    -- everything in the group grows with the text
    local pushed = push_font(fonts.semi, math.floor(20 * bs + 0.5));
    local new = fonts.semi and YUI_NEWFONT(fonts.semi);
    local base = pushed and (new and (20 * bs) or 20) or 17;
    local function scale(px) imgui.SetWindowFontScale((pushed and new) and (px / (20 * bs)) or (px / base)); end
    scale(14 * bs);
    local lw, lh = imgui.CalcTextSize(label);
    scale(21 * bs);
    local vw, vh = imgui.CalcTextSize(value);
    local bw, bh = lw + 2 * bs, math.max(lh + 10 * bs, 28 * bs);
    local gap = 9 * bs;
    local uw = math.max(vw, 44 * bs);                                -- the line under the number
    local w, h = bw + gap + uw, bh;
    local x1 = (ax < 0) and (x - w) or ((ax > 0) and x or (x - w / 2));
    local y1 = ytop and y or (y - h / 2);
    -- the badge: a dark rounded tile in the stat's colour (corners drawn by hand, so they're round everywhere)
    -- the name in the stat's colour (no tile behind it: the user didn't like it), with a dark edge
    local lc = JOBS.ink[label] or c;
    scale(14 * bs);
    local lx_, ly_ = x1 + (bw - lw) / 2, y1 + (bh - lh) / 2;
    for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
        dl:AddText({ lx_ + o[1], ly_ + o[2] }, u32({ 0, 0, 0, 0.7 }), label);
    end
    dl:AddText({ lx_, ly_ }, u32({ lc[1], lc[2], lc[3], 1 }), label);
    -- the number, white with a soft dark edge so it reads on light ground too
    scale(21 * bs);
    local vx, vy = x1 + bw + gap, y1 + (bh - vh) / 2 - 2 * bs;
    -- weapon skill ready (TP 1000+): the number pulses, swelling a little and glowing gold, once every 1.3 s
    local vcol, vs = { 1, 1, 1, 1 }, 1;
    if label == 'TP' and (tonumber(value) or 0) >= 1000 then
        local p = 0.5 - 0.5 * math.cos((os.clock() % 1.3) / 1.3 * math.pi * 2);
        vs = 1;                                                 -- (no size change: a text size that changes every frame
                                                                -- makes newer ImGui re-make its fonts each frame = stutter in every addon)
        vcol = { 1, 1 - 0.12 * p, 1 - 0.55 * p, 1 };
        local gx, gy = vx + vw / 2, vy + vh / 2;
        for k = 1, 5 do                                         -- a soft gold glow behind it, swelling with the pulse
            dl:AddCircleFilled({ gx, gy + 1 * bs }, vh * (0.80 - k * 0.1) * (1 + 0.35 * p), u32({ 1, 0.80, 0.30, 0.08 * p }), 24);
        end
    end
    scale(21 * bs * vs);
    local pw_, ph_ = imgui.CalcTextSize(value);
    local px_, py_ = vx + (vw - pw_) / 2, vy + (vh - ph_) / 2;  -- grows from its own middle
    for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 }, { 0, 2 } }) do
        dl:AddText({ px_ + o[1], py_ + o[2] }, u32({ 0, 0, 0, 0.6 }), value);
    end
    local gl;
    vcol, gl = JOBS.low_text(beat or 0, c, vcol);                     -- low HP / MP: the chosen effect
    if gl > 0 then
        for _, o in ipairs({ { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } }) do
            dl:AddText({ px_ + o[1] * bs, py_ + o[2] * bs }, u32({ c[1], c[2], c[3], gl }), value);
        end
    end
    dl:AddText({ px_, py_ }, u32(vcol), value);
    -- the line under it: dim, and bright as far as the stat is full
    local ly = y1 + bh - 1.5 * bs;
    local f = math.max(0, math.min(1, frac or 1));
    dl:AddLine({ vx, ly }, { vx + uw, ly }, u32({ c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 0.9 }), 2.5 * bs);
    if f > 0 then dl:AddLine({ vx, ly }, { vx + uw * f, ly }, u32({ c[1], c[2], c[3], 1 }), 2.5 * bs); end
    if pushed then imgui.PopFont(); end
    imgui.SetWindowFontScale(fs);
    return w, h;
end

-- The set plaque (images\set_plaque.png, 484 x 242): its wings are bent onto the ring, so the ring's HP / MP
-- bars stop at the frame's horns (JOBS.cut degrees either side of the bottom) and the wings carry them on.
-- In the picture (484 x 268): frame centre x 228, frame top y 98, ring radius 360 px; wing tips meet the ring.
function JOBS.plaque_geo(cx, cy, R) return nil; end              -- (the ornate plaque was removed: the ring is whole)
function JOBS.cut_deg() return 0; end
function JOBS.plaque_draw(dl, cx, cy, R)
    local tex, px, py, pw, ph = JOBS.plaque_geo(cx, cy, R);
    if tex then draw_image(dl, tex, px, py, px + pw, py + ph, 1); end
end

-- The wheel's background colours (the disc behind the gear): { key, name shown, colour }
JOBS.discs = {
    { 'black',    'Black',    { 0.030, 0.030, 0.040 } },
};
function JOBS.disc_col()
    for _, d in ipairs(JOBS.discs) do if d[1] == cfg.disc then return d[3]; end end
    return JOBS.discs[1][3];
end
-- How solid the background is: black almost solid, the colours more see-through; times the Opacity setting
function JOBS.disc_alpha()
    if cfg.disc == 'none' then return 0; end
    local base = ((cfg.disc or 'black') == 'black') and 0.93 or 0.72;
    return 0;                                                      -- no background behind the wheel (the user's choice)
end

-- Sumi-e: a black disc, red / blue ink splatters, and a big dry-brush ensō round it: its left half is HP (red),
-- its right half MP (blue). Each half fills from the bottom up; a light runs up through the ink and the level glows.
function JOBS.sumi(dl, cx, cy, R, bs, fs)
    local bg, rl, rr_ = logo_texture('bg_sumi_disc.png'), logo_texture('sumi_ring_l.png'), logo_texture('sumi_ring_r.png');
    local deco = logo_texture('bg_sumi_deco.png');
    if bg == nil or rl == nil or rr_ == nil then return false; end
    local K = 1.25;                                                     -- the pictures span 1.25 x the disc
    local x0, y0, x1, y1 = cx - K * R, cy - K * R, cx + K * R, cy + K * R;
    local dc = JOBS.disc_col();
    draw_image(dl, bg, x0, y0, x1, y1, nil, { dc[1] * 1.08, dc[2] * 1.08, dc[3] * 1.08, JOBS.disc_alpha() / 0.93 });   -- the disc, in the chosen colour
    if deco then draw_image(dl, deco, x0, y0, x1, y1, 1); end
    -- a thin black outline that follows the brush ring's own strokes: the ring's pictures in black, nudged a
    -- little in every direction, behind it
    for _, tex_ in ipairs({ rl, rr_ }) do
        for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -0.7, -0.7 }, { 0.7, 0.7 }, { -0.7, 0.7 }, { 0.7, -0.7 } }) do
            local o = 1.5 * bs;
            draw_image(dl, tex_, x0 + d[1] * o, y0 + d[2] * o, x1 + d[1] * o, y1 + d[2] * o, nil, { 0, 0, 0, 0.85 });
        end
    end
    local b = JOBS.bars;
    local now = os.clock();
    local top_, bot_ = cy - 1.08 * R, cy + 1.08 * R;                     -- how high the brush ring reaches
    local cutd = JOBS.cut_deg();
    local ycut = (cutd > 0) and (cy + 1.02 * R * math.cos(math.rad(cutd))) or (y1 + 1);   -- below this the plaque carries it
    if cutd > 0 then bot_ = ycut; end
    for side = 1, 2 do
        local tex = (side == 1) and rl or rr_;
        local v, lag = (side == 1) and b.hp or b.mp, (side == 1) and b.hp_lag or b.mp_lag;
        local c = (side == 1) and { 0.96, 0.32, 0.74 } or { 0.50, 0.50, 1.00 };      -- YunaUI's pink-magenta / blue-violet
        local beat = JOBS.low_beat((side == 1) and JOBS.hpp or JOBS.mpp, now, side * 0.37);
        JOBS.low_side = JOBS.low_side or {};
        JOBS.low_side[side] = { c = c, beat = beat, pct = (side == 1) and JOBS.hpp or JOBS.mpp };
        local sx0, sx1 = (side == 1) and x0 or cx, (side == 1) and cx or x1;
        JOBS.clip(dl, { x0, y0 }, { x1, ycut }, true);
        draw_image(dl, tex, x0, y0, x1, y1, nil, { 0.55, 0.55, 0.60, 0.28 });         -- the empty brush
        dl:PopClipRect();
        local lv = bot_ - (bot_ - top_) * math.min(1, v);
        if lag and lag > v + 0.002 then                                 -- what was just lost, draining
            JOBS.clip(dl, { sx0, bot_ - (bot_ - top_) * lag }, { sx1, lv }, true);
            draw_image(dl, tex, x0, y0, x1, y1, nil, { 1, 0.95, 0.9, 0.55 });
            dl:PopClipRect();
        end
        if v > 0.003 then
            -- the filled ink, in full colour (twice, so it really shines)
            JOBS.clip(dl, { sx0, lv }, { sx1, ycut }, true);
            draw_image(dl, tex, x0, y0, x1, y1, nil, { c[1], c[2], c[3], 1 });
            draw_image(dl, tex, x0, y0, x1, y1, nil, { math.min(1, c[1] + 0.25), math.min(1, c[2] + 0.25), math.min(1, c[3] + 0.25), 0.45 });
            dl:PopClipRect();
            -- the filled part as an angle along the ring: from the bottom (90) up its own side to the level
            local rg = 1.02 * R;
            local dy = math.max(-rg, math.min(rg, lv - cy));
            local asn = math.deg(math.asin(dy / rg));
            local a1, e = (side == 1) and (90 + cutd) or (90 - cutd), (side == 1) and (180 - asn) or asn;
            local dir = (side == 1) and 1 or -1;
            JOBS.ring_fx(dl, cx, cy, rg, a1, e, c, c, 6 * bs, side, false);   -- YunaUI's bar effect along the ink (no glow)
        end
    end
    JOBS.low_ring(dl, cx, cy, 1.02 * R, bs, now);
    return true;
end

-- The HP / MP ring's effect, the same as YunaUI's bars (EQUIP > Ring effect; 'same' follows YunaUI's Bar effect):
-- flow = the two colours flowing along it and a sheen gliding by, electric = thin crackling threads inside it,
-- pulse = it brightens softly and back, still = nothing. All of it stays on the ring itself (no glow round it).
-- recolor: redraw the colours (the Neon ring); the Sumi-e ink keeps its own and only gets the light on top.
function JOBS.ring_fx(dl, cx, cy, r, a1, e, c0, c, th, seed, recolor)
    local fx = cfg.ring_fx or 'same';
    if fx == 'same' then fx = (YUI_BAR_FX and YUI_BAR_FX()) or 'flow'; end
    if fx == 'still' or math.abs(e - a1) < 1 then return; end
    local now = os.clock();
    local n = math.max(6, math.floor(math.abs(e - a1) / 3));
    local function pt(a, rr) local q = math.rad(a); return { cx + math.cos(q) * (rr or r), cy + math.sin(q) * (rr or r) }; end
    if fx == 'flow' then
        if recolor then                                              -- the colours flowing along it
            local ph = now * 0.35 + seed * 0.21;
            for k = 0, n - 1 do
                local f1, f2 = k / n, (k + 1) / n;
                local u = 0.5 + 0.5 * math.sin((f1 * 1.6 - ph) * math.pi * 2);
                local col = u32({ c0[1] + (c[1] - c0[1]) * u, c0[2] + (c[2] - c0[2]) * u, c0[3] + (c[3] - c0[3]) * u, 1 });
                dl:AddLine(pt(a1 + (e - a1) * f1), pt(a1 + (e - a1) * f2), col, th * 0.8);
            end
        end
        local sp = (now * 0.32 + seed * 0.37) % 1;                   -- the sheen gliding along
        local mid = a1 + (e - a1) * sp;
        for k = -6, 5 do
            local fa, fb = mid + (e - a1) * k * 0.012, mid + (e - a1) * (k + 1) * 0.012;
            local lo, hi = math.min(a1, e), math.max(a1, e);
            if fa >= lo and fa <= hi and fb >= lo and fb <= hi then
                local al = 0.55 * (1 - math.abs(k + 0.5) / 6.5);
                dl:AddLine(pt(fa), pt(fb), u32({ 1, 1, 1, al }), th * 0.6);
            end
        end
    elseif fx == 'electric' then                                     -- crackling threads inside the ring
        local beat = math.max(0, math.sin(now * 2.6 + seed)) ^ 3;
        local a = 0.25 + 0.6 * beat;
        local tick = math.floor(now * 14);
        for pass = 1, 2 do
            local prev = nil;
            for k = 0, n do
                local rnd = (math.sin(tick * 31.7 + k * 12.9898 + seed * 7.1 + pass * 3.3) * 43758.5453) % 1;
                local p = pt(a1 + (e - a1) * k / n, r + (rnd - 0.5) * th * 0.7);
                if prev then dl:AddLine(prev, p, u32({ 0.95, 0.97, 1, a * ((pass == 1) and 1 or 0.45) }), (pass == 1) and 1.2 or 2); end
                prev = p;
            end
        end
    elseif fx == 'pulse' then                                        -- the whole lit part brightens softly and back
        local pb = 0.5 - 0.5 * math.cos(now * 2.2 + seed);
        for k = 0, n - 1 do dl:AddLine(pt(a1 + (e - a1) * k / n), pt(a1 + (e - a1) * (k + 1) / n), u32({ 1, 1, 1, 0.25 * pb }), th * 0.8); end
    end
end

-- HP and MP as two upright bars in the middle of the wheel (either side of the job icon, or together when it's off),
-- in YunaUI's look: a dark track, the two colours flowing up the fill, a sheen gliding up, a bright head, the lost part
-- draining; the effect follows EQUIP > Bar effect ('As YunaUI' = YunaUI's Bar effect); under 50% they breathe
function JOBS.vbar(dl, x, y, w, h, v, lag, c1, c2, seed, warn)
    v = math.max(0, math.min(1, v or 0));
    local now = os.clock();
    local fx = cfg.ring_fx or 'same';
    if fx == 'same' then fx = (YUI_BAR_FX and YUI_BAR_FX()) or 'flow'; end
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32({ 0.05, 0.04, 0.07, 0.75 }), w / 2);
    if lag and lag > v then dl:AddRectFilled({ x, y + h * (1 - lag) }, { x + w, y + h * (1 - v) }, u32({ 1, 0.92, 0.95, 0.40 }), w / 2); end
    if v <= 0 then return; end
    local fh = h * v;
    local top = y + h - fh;
    local pulse = 0.5 + 0.5 * math.sin(now * 2.2 + seed);
    local gl = 0.75 + 0.5 * pulse + warn * 2;
    for k = 1, 3 + math.floor(warn * 3) do
        dl:AddRectFilled({ x - k, top - k }, { x + w + k, y + h + k }, u32({ c2[1], c2[2], c2[3], math.max(0, 0.10 - k * 0.02) * gl }), w / 2 + k);
    end
    dl:AddRectFilled({ x - 1, top - 1 }, { x + w + 1, y + h + 1 }, u32({ c2[1], c2[2], c2[3], 0.85 }), w / 2 + 1);
    local segs = math.max(4, math.floor(h / 30));
    local ph = (fx == 'flow') and (now * 0.35 + seed * 0.21) or 0.3;
    local function col_at(f)
        local u = 0.5 + 0.5 * math.sin((f * 1.6 - ph) * math.pi * 2);
        return u32({ c1[1] + (c2[1] - c1[1]) * u, c1[2] + (c2[2] - c1[2]) * u, c1[3] + (c2[3] - c1[3]) * u, 1 });
    end
    for k = 0, segs - 1 do                                           -- f: 0 at the bottom, 1 at the top
        local f1, f2 = k / segs, (k + 1) / segs;
        local ya, yb = y + h - h * f1, math.max(top, y + h - h * f2);
        if ya > yb then
            local a, b = col_at(f1), col_at(yb == top and v or f2);
            dl:AddRectFilledMultiColor({ x, yb }, { x + w, ya }, b, b, a, a);
        end
    end
    if warn > 0.01 then dl:AddRectFilled({ x, top }, { x + w, y + h }, u32({ 1, 1, 1, 0.3 * warn }), w / 2); end
    if fx == 'flow' then                                             -- the sheen gliding up
        local sp = (now * 0.32 + seed * 0.137) % 1;
        local hy, hw = y + h + 30 - sp * (fh + 60), 30;
        local function band(y1, y2, a1, a2)
            local cy1, cy2 = math.max(top, y1), math.min(y + h, y2);
            if cy2 <= cy1 then return; end
            local f1, f2 = (cy1 - y1) / (y2 - y1), (cy2 - y1) / (y2 - y1);
            local b1, b2 = a1 + (a2 - a1) * f1, a1 + (a2 - a1) * f2;
            dl:AddRectFilledMultiColor({ x, cy1 }, { x + w, cy2 }, u32({ 1, 1, 1, b1 }), u32({ 1, 1, 1, b1 }), u32({ 1, 1, 1, b2 }), u32({ 1, 1, 1, b2 }));
        end
        band(hy - hw, hy, 0, 0.55);
        band(hy, hy + hw, 0.55, 0);
    elseif fx == 'electric' then                                     -- threads crackling up inside it
        local beat = math.max(0, math.sin(now * 2.6 + seed)) ^ 3;
        dl:PushClipRect({ x, top }, { x + w, y + h }, true);
        local tick = math.floor(now * 14);
        local py, px = y + h, x + w / 2;
        local k = 0;
        while py > top do
            k = k + 1;
            local r = (math.sin(tick * 31.7 + k * 12.9898 + seed * 7.1) * 43758.5453) % 1;
            local ny = math.max(top, py - math.max(4, w * 1.8) * (0.6 + 0.8 * ((r * 7.7) % 1)));
            local nx = x + w * (0.12 + 0.76 * r);
            dl:AddLine({ px, py }, { nx, ny }, u32({ 0.92, 0.97, 1, 0.2 + 0.55 * beat }), 1);
            px, py = nx, ny;
        end
        dl:PopClipRect();
    elseif fx == 'pulse' then
        local pb = 0.5 - 0.5 * math.cos(now * 2.2 + seed);
        dl:AddRectFilled({ x, top }, { x + w, y + h }, u32({ 1, 1, 1, 0.22 * pb }), w / 2);
    end
    dl:AddCircleFilled({ x + w / 2, top }, w * 1.1, u32({ 1, 1, 1, 0.18 + 0.1 * pulse }), 12);
    dl:AddCircleFilled({ x + w / 2, top }, w * 0.5, u32({ 1, 1, 1, 0.95 }), 10);
end
function JOBS.mid_bars(dl, cx, cy, inner, icon_half, bs)
    local b = JOBS.bars;
    local now = os.clock();
    local h = inner * 1.15;
    local w = math.max(3, math.floor(5 * bs));
    local gap = (icon_half > 0) and (icon_half + 10 * bs) or (8 * bs);
    local y = cy - h / 2;
    local hw = (cfg.low_on ~= false) and JOBS.low_beat(JOBS.hpp, now, 0.37) * 1.6 or 0;
    local mw = (cfg.low_on ~= false) and JOBS.low_beat(JOBS.mpp, now, 0.74) * 1.6 or 0;
    JOBS.vbar(dl, cx - gap - w, y, w, h, b.hp, b.hp_lag, JOBS.UI.hp, JOBS.UI.hp2, 0.4, hw);
    JOBS.vbar(dl, cx + gap, y, w, h, b.mp, b.mp_lag, JOBS.UI.mp, JOBS.UI.mp2, 2.1, mw);
end

-- Neon: a dark disc with a thin glowing ring, pink to magenta down the left (HP), blue to violet down the right (MP)
-- (YunaUI's bar colours), each filling from
-- the bottom up with the running light and a glowing tip; a thin grey ring inside it.
function JOBS.neon(dl, cx, cy, R, bs, fs)
    local b = JOBS.bars;
    local now = os.clock();
    local dc = JOBS.disc_col();
    dl:AddCircleFilled({ cx, cy }, R, u32({ dc[1], dc[2], dc[3], JOBS.disc_alpha() }), 96);
    for i = 1, (cfg.disc == 'none') and 0 or 6 do dl:AddCircle({ cx, cy }, R - i * 2.5 * bs, u32({ 0, 0, 0, 0.10 * (1 - i / 7) }), 96, 2.5 * bs); end
    local th = 5.5 * bs;                                            -- thick enough to read at a glance
    dl:AddCircle({ cx, cy }, R, u32({ 0, 0, 0, 0.95 }), 160, th + 3.5 * bs);   -- a black outline round the whole ring
    for side = 1, 2 do
        local v, lag = (side == 1) and b.hp or b.mp, (side == 1) and b.hp_lag or b.mp_lag;
        local c = (side == 1) and JOBS.UI.hp2 or JOBS.UI.mp2;           -- the glow and the far end
        local c0 = (side == 1) and JOBS.UI.hp or JOBS.UI.mp;           -- where it starts
        local beat = JOBS.low_beat((side == 1) and JOBS.hpp or JOBS.mpp, now, side * 0.37);
        JOBS.low_side = JOBS.low_side or {};
        JOBS.low_side[side] = { c = c, beat = beat, pct = (side == 1) and JOBS.hpp or JOBS.mpp };
        local cut = JOBS.cut_deg();
        local a1, a2 = (side == 1) and (90 + cut) or (90 - cut), (side == 1) and 270 or -90;   -- from the plaque up its own side
        local dir = (a2 > a1) and 1 or -1;
        JOBS.bar(dl, cx, cy, R, a1, a2, { c[1] * 0.35, c[2] * 0.35, c[3] * 0.35, 0.6 }, nil, th);   -- dim, unlit
        if lag and lag > v + 0.002 then
            JOBS.bar(dl, cx, cy, R, a1 + (a2 - a1) * v, a1 + (a2 - a1) * lag, { 1, 0.92, 0.85, 0.5 }, nil, th);
        end
        if v > 0.003 then
            local e = a1 + (a2 - a1) * math.min(1, v);
            JOBS.bar(dl, cx, cy, R, a1, e, { c0[1], c0[2], c0[3], 1 }, { c[1], c[2], c[3], 1 }, th);
            JOBS.ring_fx(dl, cx, cy, R, a1, e, c0, c, th, side, true);  -- YunaUI's bar effect along it (no glow)
        end
    end
    JOBS.low_ring(dl, cx, cy, R, bs, now);
    return true;
end

-- The job title on top of the ring: your main job / sub job and level, e.g. "DRG/WAR 75", in a rounded pill
-- ---------------------------------------------------------------------------------------------------
-- The gear set you're wearing, by name: your gear-swap profile's sets (LegacyAC XML, or else LuAshitacast) are
-- read, and the one that matches what's equipped is shown under the wheel. Reread when the job changes and
-- every 20 s (so edits to the profile show up).
-- ---------------------------------------------------------------------------------------------------
JOBS.SLOTKEY = { main = 0, sub = 1, range = 2, ammo = 3, head = 4, body = 5, hands = 6, legs = 7, feet = 8, neck = 9,
    waist = 10, ear1 = 11, lear = 11, ear2 = 12, rear = 12, ring1 = 13, lring = 13, ring2 = 14, rring = 14, back = 15 };
JOBS.PAIR = { [11] = 12, [12] = 11, [13] = 14, [14] = 13 };
function JOBS.readfile(path)
    local f = io.open(path, 'rb');
    if f == nil then return nil; end
    local d = f:read('*a');
    f:close();
    return d;
end
-- XML: <set name="X" baseset="Y"> <slot>Item</slot> ... </set>, basesets resolved
function JOBS.parse_xml(d)
    local raw, order = {}, {};
    for attrs, body in d:gmatch('<set%s+([^>]-)>(.-)</set>') do
        local name = attrs:match('name%s*=%s*"([^"]*)"');
        if name then
            local base = attrs:match('baseset%s*=%s*"([^"]*)"');
            local items = {};
            for tag, val in body:gmatch('<(%w+)[^>]*>([^<]*)</%w+>') do
                local k = JOBS.SLOTKEY[tag:lower()];
                val = val:gsub('^%s+', ''):gsub('%s+$', '');
                if k and val ~= '' then items[k] = val:lower(); end
            end
            raw[name] = { base = base, items = items };
            order[#order + 1] = name;
        end
    end
    local out = {};
    local function resolve(n, depth)
        local st = raw[n];
        if st == nil or depth > 10 then return {}; end
        local t = {};
        if st.base then for k, v in pairs(resolve(st.base, depth + 1)) do t[k] = v; end end
        for k, v in pairs(st.items) do t[k] = v; end
        return t;
    end
    for _, n in ipairs(order) do out[#out + 1] = { name = n, items = resolve(n, 0) }; end
    return out;
end
-- LuAshitacast: ["Name"] = { Slot = "Item", ... } (or Name = { ... }) inside the sets table
function JOBS.parse_lac(d)
    local out = {};
    -- the sets table: 'local sets = {...}' or 'profile.Sets = {...}' / 'Sets = {...}'; look inside it only
    local tbl = d:match('local%s+sets%s*=%s*(%b{})') or d:match('[%.%s]Sets%s*=%s*(%b{})') or d:match('sets%s*=%s*(%b{})');
    if tbl == nil then return out; end
    tbl = tbl:sub(2, -2);
    for name, body in tbl:gmatch('%[?"?([%w_%-]+)"?%]?%s*=%s*(%b{})') do
        local items, n = {}, 0;
        for key, val in body:gmatch('([%a][%w]*)%s*=%s*"([^"]*)"') do
            local k = JOBS.SLOTKEY[key:lower()];
            if k then items[k] = val:lower(); n = n + 1; end
        end
        for key, val in body:gmatch("([%a][%w]*)%s*=%s*'([^']*)'") do
            local k = JOBS.SLOTKEY[key:lower()];
            if k then items[k] = val:lower(); n = n + 1; end
        end
        if n > 0 then out[#out + 1] = { name = name, items = items }; end
    end
    return out;
end
function JOBS.load_sets()
    local pname, sid, job = '', 0, 0;
    pcall(function()
        local pt = AshitaCore:GetMemoryManager():GetParty();
        pname, sid = pt:GetMemberName(0), pt:GetMemberServerId(0);
        job = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob();
    end);
    local jab = JOBS.abbr[job];
    if pname == nil or pname == '' or jab == nil then return nil; end
    local root = AshitaCore:GetInstallPath():gsub('[\\/]+$', '');
    local xml = JOBS.readfile(root .. '/config/legacyac/' .. pname .. '_' .. jab .. '.xml');
    if xml then return JOBS.parse_xml(xml); end
    local lac = JOBS.readfile(root .. '/config/addons/luashitacast/' .. pname .. '_' .. tostring(sid) .. '/' .. jab .. '.lua');
    if lac then return JOBS.parse_lac(lac); end
    return nil;
end
-- Which set matches what you wear: every piece of the set must be on (rings / earrings either way round);
-- of those the biggest wins (a full set beats a small piece-set like Fastcast). None fully on: the closest.
function JOBS.current_set()
    local now = os.clock();
    local job = 0;
    pcall(function() job = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob(); end);
    if JOBS.sets_job ~= job or now > (JOBS.sets_t or 0) then
        JOBS.sets, JOBS.sets_job, JOBS.sets_t = JOBS.load_sets(), job, now + 60;
        JOBS.set_sig = nil;
    end
    if JOBS.sets == nil then return nil; end
    if JOBS.set_sig == ye.sig and JOBS.set_name ~= nil then return JOBS.set_name, JOBS.set_full; end
    local worn, res = {}, AshitaCore:GetResourceManager();
    for slot, e in pairs(ye.slots) do
        local it = res:GetItemById(e.id);
        if it then worn[slot] = (it.Name[1] or ''):lower(); end
    end
    local best, best_n, best_full, best_frac = nil, -1, false, -1;
    for _, st in ipairs(JOBS.sets) do
        local n, hit = 0, 0;
        for k, v in pairs(st.items) do
            n = n + 1;
            if v == 'displaced' or v == 'remove' or worn[k] == v or (JOBS.PAIR[k] and worn[JOBS.PAIR[k]] == v) then hit = hit + 1; end
        end
        if n > 0 then
            local full = (hit == n);
            local frac = hit / n;
            if (full and (not best_full or n > best_n)) or (not best_full and not full and (frac > best_frac or (frac == best_frac and hit > best_n))) then
                best, best_n, best_full, best_frac = st.name, full and n or hit, full, frac;
            end
        end
    end
    JOBS.set_sig, JOBS.set_name, JOBS.set_full = ye.sig, best or '', best_full;
    return JOBS.set_name, JOBS.set_full;
end

-- Under the wheel, part of the bezel (no box): the weapon crest. Your main weapon (red, left) and off-hand (blue,
-- right) as small glowing silhouettes, and under them a small header and a serif label, e.g. WEAPON SET /
-- KATANA / DAGGER. They flash when the weapons change or you weapon skill. Or, with "Gear set", the gear set's
-- name in the same style.
JOBS.SKILLS = { [1] = 'Hand-to-Hand', [2] = 'Dagger', [3] = 'Sword', [4] = 'Great Sword', [5] = 'Axe', [6] = 'Great Axe',
    [7] = 'Scythe', [8] = 'Polearm', [9] = 'Katana', [10] = 'Great Katana', [11] = 'Club', [12] = 'Staff',
    [25] = 'Archery', [26] = 'Marksmanship', [27] = 'Throwing', [41] = 'Instrument', [42] = 'Instrument',
    [45] = 'Handbell' };
function JOBS.weapon_kind(e)
    if e == nil then return nil; end
    local it = AshitaCore:GetResourceManager():GetItemById(e.id);
    if it == nil then return nil; end
    local sk = tonumber(it.Skill) or 0;
    if JOBS.SKILLS[sk] then return JOBS.SKILLS[sk]; end
    local nm = (it.Name[1] or ''):lower();
    if nm:find('grip') or nm:find('strap') then return 'Grip'; end
    if (tonumber(it.ShieldSize) or 0) > 0 or nm:find('shield') or nm:find('buckler') or nm:find('aspis') or nm:find('escutcheon') then return 'Shield'; end
    return it.Name[1];
end
-- Text in Georgia (or the card font), with a dark edge; ax 0 = centred. Returns width, height.
function JOBS.serif(dl, x, y, str, px, col, spacing)
    local pushed = push_font(fonts.serif, math.floor(px + 0.5));
    local new = pushed and YUI_NEWFONT(fonts.serif);
    imgui.SetWindowFontScale(pushed and (new and 1 or px / 18) or (px / 17));
    local sp = spacing or 0;
    local w, h = 0, 0;
    for ch in str:gmatch('.') do local cw, chh = imgui.CalcTextSize(ch); w = w + cw + sp; h = chh; end
    w = w - sp;
    local tx = x - w / 2;
    for ch in str:gmatch('.') do
        local cw = imgui.CalcTextSize(ch);
        for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
            dl:AddText({ tx + o[1], y + o[2] }, u32({ 0, 0, 0, 0.8 * col[4] }), ch);
        end
        dl:AddText({ tx, y }, u32(col), ch);
        tx = tx + cw + sp;
    end
    if pushed then imgui.PopFont(); end
    return w, h;
end
-- Text in Bahnschrift (YGO's title font), centred on x, with a dark edge. Returns width, height.
function JOBS.bahn(dl, x, y, str, px, col, spacing)
    local pushed = push_font(fonts.title, math.floor(px + 0.5));
    local new = pushed and YUI_NEWFONT(fonts.title);
    imgui.SetWindowFontScale(pushed and (new and 1 or px / 22) or (px / 17));
    local sp = spacing or 0;
    local w, h = 0, 0;
    for ch in str:gmatch('.') do local cw, chh = imgui.CalcTextSize(ch); w = w + cw + sp; h = chh; end
    w = w - sp;
    local tx = x - w / 2;
    for ch in str:gmatch('.') do
        local cw = imgui.CalcTextSize(ch);
        for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
            dl:AddText({ tx + o[1], y + o[2] }, u32({ 0, 0, 0, 0.75 * col[4] }), ch);
        end
        dl:AddText({ tx, y }, u32(col), ch);
        tx = tx + cw + sp;
    end
    if pushed then imgui.PopFont(); end
    return w, h;
end
-- What the gear set is FOR, in a word or two. Only the sets that matter are named: a weapon skill, the spell type
-- you're casting (from the spell's magic skill), precast, PDT / MDT; otherwise TP when engaged, resting, idle.
-- Raw profile names (TP_Hybrid_DT, Savage-Acc...) are never shown.
JOBS.SPELL_KIND = { [32] = 'DIVINE', [33] = 'HEALING', [34] = 'ENHANCING', [35] = 'ENFEEBLING', [36] = 'NUKE', [37] = 'DARK MAGIC',
    [38] = 'SUMMONING', [39] = 'NINJUTSU', [40] = 'SONG', [41] = 'SONG', [42] = 'SONG', [43] = 'BLUE MAGIC', [44] = 'GEOMANCY', [45] = 'GEOMANCY' };
function JOBS.set_label(status)
    local now = os.clock();
    local ok, name = pcall(JOBS.current_set);
    local n = ((ok and name) or ''):lower();
    if n:find('precast') or n:find('fastcast') or n:find('^fc') or n:find('preshot') or n:find('fast cast') then return 'PRECAST'; end
    if ye.ws_t and now - ye.ws_t < 2.0 then return 'WEAPON SKILL'; end
    if (now < (ye.cast_until or 0) or (ye.spell_t and now - ye.spell_t < 1.5)) and ye.spell then
        local kind;
        pcall(function()
            local sp = AshitaCore:GetResourceManager():GetSpellById(ye.spell);
            if sp then
                kind = JOBS.SPELL_KIND[tonumber(sp.Skill) or 0];
                local sn = ((sp.Name and sp.Name[1]) or ''):lower();
                if kind == 'HEALING' and (sn:find('cur') or sn:find('cura')) then kind = 'CURE'; end
                if kind == 'SONG' and ye.job_key == 'brd' then
                    if sn:find('requiem') or sn:find('lullaby') or sn:find('elegy') or sn:find('threnody') or sn:find('finale') or sn:find('nocturne') or sn:find('virelai') then kind = 'SONG DEBUFF'; else kind = 'SONG BUFF'; end
                end
            end
        end);
        if kind then return kind; end
    end
    if n:find('mdt') or n:find('magicdefense') then return 'MDT'; end
    if n:find('pdt') or n:find('physicaldefense') then return 'PDT'; end
    if status == 'Engaged' then return 'TP'; end
    if status == 'Resting' then return 'RESTING'; end
    if n == '' and JOBS.sets == nil then return 'NO GEAR PROFILE'; end
    return 'IDLE';
end

-- Veins from the job icon to each piece of gear: a slightly crooked line per slot (fixed shape) with two thin
-- side branches, a faint steady glow, and a bright pulse that runs out from the icon to the gear (each slot on
-- its own beat), so energy seems to flow from the job into the equipment
JOBS.VEIN = nil;
function JOBS.veins(dl, cx, cy, r0, r1, c, bs, now)
    if JOBS.VEIN == nil then
        JOBS.VEIN = {};
        for j, o in ipairs(ORBIT) do
            local pts, n = {}, 22;                                  -- a smooth, gently winding curve (like a vein)
            local amp = 5 + 4 * ((j * 0.618) % 1);
            local sd = j * 1.7;
            for q = 0, n do
                local t = q / n;
                pts[#pts + 1] = { t, amp * (math.sin(t * math.pi * 1.6 + sd) * 0.7 + math.sin(t * math.pi * 3.1 + sd * 2) * 0.3) };
            end
            local br = {};
            for b = 1, 2 do
                local t0 = 0.35 + 0.3 * ((j * 0.618 + b * 0.37) % 1);
                br[b] = { t0 = t0, side = (b == 1) and 1 or -1, len = 0.18 + 0.1 * ((j * 0.31 + b) % 1) };
            end
            JOBS.VEIN[j] = { a = math.rad(o[2]), pts = pts, br = br, ph = (j * 0.137) % 1 };
        end
    end
    local function at(v, t, off)
        local a = v.a + math.rad(off or 0);
        local r = r0 + (r1 - r0) * t;
        return { cx + math.cos(a) * r, cy + math.sin(a) * r };
    end
    for _, v in ipairs(JOBS.VEIN) do
        local ph = (now * 0.55 + v.ph) % 1;                         -- where the pulse is along this vein
        local prev = nil;
        for q, p in ipairs(v.pts) do
            local pt = at(v, p[1], p[2] * math.sin(p[1] * math.pi));   -- crooked in the middle, straight at both ends
            if prev then
                local tm = (p[1] + v.pts[q - 1][1]) / 2;
                local glow = math.max(0, 1 - math.abs(tm - ph) / 0.16);
                local base = 0.14 * (1 - tm * 0.4);
                dl:AddLine(prev, pt, u32({ c[1], c[2], c[3], (0.08 + 0.25 * glow) }), (3.5 + 3 * glow) * bs);
                dl:AddLine(prev, pt, u32({ c[1] + (1 - c[1]) * 0.5 * glow, c[2] + (1 - c[2]) * 0.5 * glow, c[3] + (1 - c[3]) * 0.5 * glow, base + 0.7 * glow }), (1.0 + 0.8 * glow) * bs);
            end
            prev = pt;
        end
        for _, b in ipairs(v.br) do                                 -- the side branches
            local s0 = at(v, b.t0, 0);
            local s1 = at(v, b.t0 + b.len, b.side * 9);
            local glow = math.max(0, 1 - math.abs(b.t0 - ph) / 0.2);
            dl:AddLine(s0, s1, u32({ c[1], c[2], c[3], 0.12 + 0.35 * glow }), (0.8 + 0.5 * glow) * bs);
        end
        local tip = at(v, 1, 0);                                    -- the pulse lands on the gear: a small flash
        local land = math.max(0, 1 - math.abs(ph - 0.97) / 0.06);
        if land > 0 then dl:AddCircleFilled(tip, (3 + 3 * land) * bs, u32({ c[1], c[2], c[3], 0.35 * land }), 16); end
    end
end

-- The effects between the job icon and the gear, all in the job's colour. Pick one in the settings ("Effect").
JOBS.FX_LIST = { { 'veins', 'Veins' }, { 'waves', 'Waves' }, { 'bolts', 'Thunderbolts' }, { 'sound', 'Sound wave' },
    { 'sparks', 'Orbiting sparks' }, { 'stars', 'Constellation' }, { 'runes', 'Rune circle' }, { 'none', 'None' } };
function JOBS.fx(name, dl, cx, cy, r0, r1, c, bs, now)
    local function slot(j) local a = math.rad(ORBIT[j][2]); return { cx + math.cos(a) * r1, cy + math.sin(a) * r1 }, a; end
    if name == 'veins' then return JOBS.veins(dl, cx, cy, r0, r1, c, bs, now); end
    if name == 'waves' then
        -- soft gradient rings rising out of the icon and spreading to the gear, fading as they go
        for k = 0, 3 do
            local t = ((now * 0.35) + k / 4) % 1;
            local rr = r0 + (r1 - r0) * t;
            local al = math.sin(t * math.pi) * 0.5;
            for q = 1, 4 do
                dl:AddCircle({ cx, cy }, rr - q * 2 * bs, u32({ c[1], c[2], c[3], al * (0.35 - q * 0.07) }), 96, 3 * bs);
            end
            dl:AddCircle({ cx, cy }, rr, u32({ c[1] + (1 - c[1]) * 0.4, c[2] + (1 - c[2]) * 0.4, c[3] + (1 - c[3]) * 0.4, al }), 96, 1.4 * bs);
        end
        return;
    end
    if name == 'bolts' then
        -- a lightning bolt jumps from one piece of gear to the next round the ring, every ~0.35 s
        local n = #ORBIT;
        local step = math.floor(now / 0.35);
        for back = 0, 2 do                                       -- the latest bolt and two fading ones
            local st = step - back;
            local j = (st * 5) % n + 1;                          -- hops around the ring (skipping a few)
            local k2 = (j + 1 + (st % 3)) % n + 1;
            local p1, p2 = slot(j), slot(k2);
            local age = (now / 0.35 - st);
            local al = math.max(0, 1 - (age + back) / 3);
            if al > 0.02 then
                local pts = { p1 };
                local seg = 8;
                for q = 1, seg - 1 do
                    local t = q / seg;
                    local x = p1[1] + (p2[1] - p1[1]) * t; local y = p1[2] + (p2[2] - p1[2]) * t;
                    local jit = (math.sin(st * 91.7 + q * 37.3 + math.floor(now * 20) * 1.3) * 0.5) * 22 * bs * math.sin(t * math.pi);
                    local nx, ny = -(p2[2] - p1[2]), p2[1] - p1[1];
                    local L = math.max(1, math.sqrt(nx * nx + ny * ny));
                    pts[#pts + 1] = { x + nx / L * jit, y + ny / L * jit };
                end
                pts[#pts + 1] = p2;
                for q = 1, #pts - 1 do
                    dl:AddLine(pts[q], pts[q + 1], u32({ c[1], c[2], c[3], 0.25 * al }), 6 * bs);
                    dl:AddLine(pts[q], pts[q + 1], u32({ 1, 1, 1, 0.9 * al }), 1.4 * bs);
                end
                dl:AddCircleFilled(p2, 7 * bs * al, u32({ c[1], c[2], c[3], 0.35 * al }), 16);
            end
        end
        return;
    end
    if name == 'sound' then
        -- an equaliser ring: bars round the icon that rise and fall like music, plus a wavy ring
        local N = 48;
        for q = 0, N - 1 do
            local a = q / N * math.pi * 2;
            local v = 0.5 + 0.25 * math.sin(now * 3.1 + q * 0.7) + 0.25 * math.sin(now * 5.3 + q * 1.9);
            local len = (r1 - r0) * (0.12 + 0.35 * v);
            local p1 = { cx + math.cos(a) * r0 * 1.05, cy + math.sin(a) * r0 * 1.05 };
            local p2 = { cx + math.cos(a) * (r0 * 1.05 + len), cy + math.sin(a) * (r0 * 1.05 + len) };
            dl:AddLine(p1, p2, u32({ c[1], c[2], c[3], 0.25 + 0.45 * v }), 2.2 * bs);
        end
        local prev;
        for q = 0, 96 do
            local a = q / 96 * math.pi * 2;
            local rr = r0 + (r1 - r0) * 0.72 + math.sin(a * 8 + now * 4) * 4 * bs * (0.6 + 0.4 * math.sin(now * 1.7));
            local pt = { cx + math.cos(a) * rr, cy + math.sin(a) * rr };
            if prev then dl:AddLine(prev, pt, u32({ c[1], c[2], c[3], 0.45 }), 1.3 * bs); end
            prev = pt;
        end
        return;
    end
    if name == 'sparks' then
        -- glowing sparks orbiting the icon at different speeds and distances, leaving short trails
        for k = 1, 18 do
            local rr = r0 + (r1 - r0) * (0.15 + 0.75 * ((k * 0.618) % 1));
            local sp = (0.25 + 0.5 * ((k * 0.377) % 1)) * ((k % 2 == 0) and 1 or -1);
            for tr = 0, 5 do
                local a = now * sp + k * 2.4 - tr * 0.05 * (sp > 0 and 1 or -1);
                local pt = { cx + math.cos(a) * rr, cy + math.sin(a) * rr };
                local al = (1 - tr / 6) * (0.6 + 0.4 * math.sin(now * 3 + k));
                dl:AddCircleFilled(pt, (2.2 - tr * 0.3) * bs, u32({ c[1], c[2], c[3], 0.8 * al }), 8);
            end
        end
        return;
    end
    if name == 'stars' then
        -- a constellation: thin lines linking the gear to the icon and to each other, twinkling star points on them
        local n = #ORBIT;
        for j = 1, n do
            local p1 = slot(j);
            local p2 = slot(j % n + 1);
            local mid = { cx + (p1[1] - cx) * 0.45, cy + (p1[2] - cy) * 0.45 };
            dl:AddLine(p1, p2, u32({ c[1], c[2], c[3], 0.22 }), 1 * bs);
            dl:AddLine(mid, p1, u32({ c[1], c[2], c[3], 0.15 }), 1 * bs);
            if j % 2 == 0 then dl:AddLine(mid, slot((j + 3) % n + 1), u32({ c[1], c[2], c[3], 0.12 }), 1 * bs); end
            local tw = 0.5 + 0.5 * math.sin(now * 2.3 + j * 1.7);
            dl:AddCircleFilled(mid, (1.5 + 1.5 * tw) * bs, u32({ 1, 1, 1, 0.5 + 0.5 * tw }), 8);
            dl:AddCircleFilled(mid, (4 + 3 * tw) * bs, u32({ c[1], c[2], c[3], 0.15 * tw }), 12);
        end
        return;
    end
    if name == 'runes' then
        -- a magic circle: two rings turning opposite ways with marks on them, and a star drawn between them
        local ra, rb = r0 + (r1 - r0) * 0.45, r0 + (r1 - r0) * 0.80;
        for _, rr in ipairs({ ra, rb }) do
            dl:AddCircle({ cx, cy }, rr, u32({ c[1], c[2], c[3], 0.45 }), 96, 1.3 * bs);
        end
        for q = 0, 23 do
            local a = q / 24 * math.pi * 2 + now * 0.2;
            local p1 = { cx + math.cos(a) * (rb - 4 * bs), cy + math.sin(a) * (rb - 4 * bs) };
            local p2 = { cx + math.cos(a) * (rb + 4 * bs), cy + math.sin(a) * (rb + 4 * bs) };
            dl:AddLine(p1, p2, u32({ c[1], c[2], c[3], (q % 3 == 0) and 0.8 or 0.35 }), 1.3 * bs);
        end
        local star = {};
        for q = 0, 5 do
            local a = q / 6 * math.pi * 2 - now * 0.3;
            star[#star + 1] = { cx + math.cos(a) * ra, cy + math.sin(a) * ra };
        end
        for q = 1, 6 do
            dl:AddLine(star[q], star[(q + 1) % 6 + 1], u32({ c[1], c[2], c[3], 0.35 + 0.15 * math.sin(now * 2 + q) }), 1.2 * bs);
        end
        return;
    end
end

-- The job icon's colours, per job: two shades it drifts between (and a white edge for the dark ones)
JOBS.ICON_COL = {
    mnk = { { 1.00, 0.82, 0.30 }, { 1.00, 0.93, 0.55 } },          -- yellowish
    whm = { { 0.62, 0.88, 1.00 }, { 0.85, 0.97, 1.00 } },          -- light azure
    nin = { { 0.06, 0.06, 0.08 }, { 0.20, 0.18, 0.24 }, true },    -- black, with a white edge
    drg = { { 0.20, 0.42, 1.00 }, { 0.40, 0.62, 1.00 } },          -- blue
    war = { { 0.55, 0.33, 0.16 }, { 0.75, 0.50, 0.28 } },          -- brown
    pld = { { 1.00, 0.78, 0.25 }, { 1.00, 0.92, 0.55 } },          -- gold
    blm = { { 0.32, 0.12, 0.55 }, { 0.48, 0.25, 0.75 } },          -- dark violet
    rdm = { { 0.95, 0.22, 0.18 }, { 1.00, 0.52, 0.18 } },          -- red / orange
    rng = { { 0.12, 0.42, 0.18 }, { 0.25, 0.58, 0.28 } },          -- dark green
    thf = { { 0.55, 0.85, 0.25 }, { 0.75, 0.95, 0.45 } },          -- lime
    drk = { { 0.55, 0.05, 0.10 }, { 0.80, 0.12, 0.18 } },          -- blood red
    bst = { { 0.85, 0.55, 0.20 }, { 1.00, 0.72, 0.35 } },          -- amber
    brd = { { 0.25, 0.85, 0.80 }, { 0.55, 1.00, 0.92 } },          -- teal
    sam = { { 0.85, 0.15, 0.20 }, { 1.00, 0.42, 0.42 } },          -- crimson
    smn = { { 0.65, 0.30, 0.95 }, { 0.85, 0.55, 1.00 } },          -- amethyst
    blu = { { 0.15, 0.45, 0.95 }, { 0.30, 0.85, 0.95 } },          -- deep blue to cyan
    cor = { { 0.85, 0.65, 0.20 }, { 0.30, 0.55, 1.00 } },          -- gold and navy
    pup = { { 0.85, 0.40, 0.25 }, { 1.00, 0.65, 0.45 } },          -- copper
    dnc = { { 1.00, 0.45, 0.72 }, { 1.00, 0.70, 0.85 } },          -- pink
    sch = { { 0.95, 0.85, 0.55 }, { 0.55, 0.40, 0.25 } },          -- parchment and ink
    geo = { { 0.30, 0.85, 0.65 }, { 0.55, 1.00, 0.80 } },          -- jade
    run = { { 0.40, 0.65, 1.00 }, { 0.70, 0.90, 1.00 } },          -- ice blue
};

-- (old) The job icon in the middle: it rises out of a light purple smoke, stays a while with wisps drifting round it,
-- then dissolves back into the smoke and forms again (a 12 s cycle; a new cycle starts when the job changes)
JOBS.SMOKE = {};
for k = 1, 22 do
    JOBS.SMOKE[k] = { a = (k * 2.39996) % (math.pi * 2), d = 0.35 + 0.45 * ((k * 0.618) % 1), s = 0.25 + 0.2 * ((k * 0.377) % 1), ph = (k * 0.271) % 1 };
end
function JOBS.icon_smoke(dl, ic, cx, cy, half, bs, now, jab)
    -- the job's emblem, always there (no ring, no smoke), in the job's colours, glowing: a soft halo that swells
    -- and fades, the emblem brightening with it
    local jc = JOBS.ICON_COL[jab:lower()] or { { C.gold[1], C.gold[2], C.gold[3] }, { C.ice[1], C.ice[2], C.ice[3] } };
    local A_, B_ = jc[1], jc[2];
    local u = 0.5 + 0.5 * math.sin(now * 1.1);
    local col = { A_[1] + (B_[1] - A_[1]) * u, A_[2] + (B_[2] - A_[2]) * u, A_[3] + (B_[3] - A_[3]) * u };
    local dark = (0.299 * col[1] + 0.587 * col[2] + 0.114 * col[3]) < 0.15;
    local light = (jab:lower() == 'whm');                          -- (the new art is dark ink, except White Mage's pale one)
    local glow = dark and { 0.85, 0.85, 0.92 } or col;
    local g = 0.5 + 0.5 * math.sin(now * 2.0);                     -- the glow's beat
    local sym = logo_texture('jobicons/' .. jab:lower() .. '_sym.png') or ic;
    local h = half * 0.78;                                         -- (the user's ink art fills its picture)
    -- no glow outside: just the outline, then the emblem filled with a gradient of the job's two colours
    -- (top to bottom), and a soft band of light that slowly rises through it
    -- the picture made at the size nearest to the one it's drawn at (outline baked in), so it stays sharp
    local want = 2 * h;
    local best;
    for _, P in ipairs({ 48, 64, 80, 96, 128, 160, 200 }) do
        if best == nil and P >= want * 0.95 then best = P; end
    end
    sym = logo_texture('jobicons/' .. jab:lower() .. '_sym_' .. (best or 200) .. '.png') or sym;
    local x1_, y1_ = math.floor(cx - h + 0.5), math.floor(cy - h + 0.5);
    local sz = math.floor(2 * h + 0.5);
    cx, cy, h = x1_ + sz / 2, y1_ + sz / 2, sz / 2;                -- on whole pixels
    -- the user's ink art keeps its own colours; a soft band of light slowly rises through it (inside the art only)
    draw_image(dl, sym, cx - h, cy - h, cx + h, cy + h, 1);
    local y0, y1 = cy - h, cy + h;
    local N = (cfg.mid_anim == false) and 0 or 12;                -- "Middle animation" off: a still icon
    local shine = (now * 0.25) % 1.4 - 0.2;                         -- 1 = top, 0 = bottom
    for q = 0, N - 1 do
        local f = (q + 0.5) / N;
        local sh = math.max(0, 1 - math.abs((1 - f) - shine) / 0.16);
        if sh > 0.01 then
            JOBS.clip(dl, { cx - h, y0 + (y1 - y0) * q / N }, { cx + h, y0 + (y1 - y0) * (q + 1) / N + 0.5 }, true);
            draw_image(dl, sym, cx - h, cy - h, cx + h, cy + h, nil, { col[1] + (1 - col[1]) * 0.5, col[2] + (1 - col[2]) * 0.5, col[3] + (1 - col[3]) * 0.5, 0.45 * sh });
            dl:PopClipRect();
        end
    end
end

-- The set's name in the MIDDLE of the wheel (the "Middle: Gear set" option): the old word fades out drifting up,
-- the new one fades in rising from below, with a soft glow of your job's colour that breathes behind it
function JOBS.mid_label(dl, cx, cy, half, bs, fs, label, jkey)
    local now = os.clock();
    if JOBS.mid_cur ~= label then
        JOBS.mid_prev, JOBS.mid_cur, JOBS.mid_t = JOBS.mid_cur, label, now;
    end
    local t = math.min(1, (now - (JOBS.mid_t or -9)) / 0.45);
    local e = t * t * (3 - 2 * t);
    local jc = (jkey and JOBS.color[jkey]) or { 0.6, 0.66, 1 };
    local breathe = 0.5 + 0.5 * math.sin(now * 1.6);
    for k = 1, 8 do
        dl:AddCircleFilled({ cx, cy }, half * (0.95 - k * 0.09), u32({ jc[1], jc[2], jc[3], (0.025 + 0.015 * breathe) * (0.6 + 0.4 * e) }), 48);
    end
    local f = fonts.set[cfg.set_font or 'bahn'] or fonts.set.bahn;
    local function word(str, a, dy, sc)
        if str == nil or a <= 0.01 then return; end
        local px_ = 34 * bs * sc;
        local pushed = push_font(f, math.floor(px_ + 0.5));
        local new = pushed and YUI_NEWFONT(f);
        local base = pushed and (new and 1 or px_ / 26) or (px_ / 17);
        imgui.SetWindowFontScale(base);
        local sp = 3 * bs * sc;                                     -- spaced-out capitals
        local tw, th = 0, 0;
        for ch in str:gmatch('.') do local cw, chh = imgui.CalcTextSize(ch); tw = tw + cw + sp; th = chh; end
        tw = tw - sp;
        if tw > half * 1.7 then
            local k = half * 1.7 / tw;
            imgui.SetWindowFontScale(base * k); sp = sp * k;
            tw = 0; for ch in str:gmatch('.') do local cw, chh = imgui.CalcTextSize(ch); tw = tw + cw + sp; th = chh; end
            tw = tw - sp;
        end
        local tx, ty = cx - tw / 2, cy - th / 2 + dy;
        local w = 0.35 * (1 - e) * a;                               -- a little brighter as it arrives
        local sweep = ((now * 0.35) % 1.6) - 0.3;                   -- a light that sweeps across now and then
        local x = tx;
        for ch in str:gmatch('.') do
            local cw = imgui.CalcTextSize(ch);
            local u = (x - tx) / math.max(1, tw);
            local shine = math.max(0, 1 - math.abs(u - sweep) / 0.12);
            for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 }, { 0, 2 } }) do
                dl:AddText({ x + o[1], ty + o[2] }, u32({ 0, 0, 0, 0.85 * a }), ch);
            end
            for _, o in ipairs({ { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } }) do  -- a soft glow of the job's colour
                dl:AddText({ x + o[1] * bs, ty + o[2] * bs }, u32({ jc[1], jc[2], jc[3], 0.16 * a }), ch);
            end
            local m = 0.30 * (1 - u);                               -- white on the left, taking the job's colour to the right
            local c = { 1 - m * (1 - jc[1]) * 0.4, 1 - m * (1 - jc[2]) * 0.4 - 0.1 * w, 1 - m * (1 - jc[3]) * 0.4 - 0.3 * w, a };
            c = { c[1] + (1 - c[1]) * shine, c[2] + (1 - c[2]) * shine, c[3] + (1 - c[3]) * shine, a };
            dl:AddText({ x, ty }, u32(c), ch);
            x = x + cw + sp;
        end
        -- a thin line under it in the job's colour, fading at both ends
        local ly = ty + th + 4 * bs;
        for q = 0, 9 do
            local f1, f2 = q / 10, (q + 1) / 10;
            local al = math.sin((f1 + 0.05) * math.pi) * 0.7 * a;
            dl:AddLine({ cx - tw * 0.4 + tw * 0.8 * f1, ly }, { cx - tw * 0.4 + tw * 0.8 * f2, ly }, u32({ jc[1], jc[2], jc[3], al }), 1.5 * bs);
        end
        if pushed then imgui.PopFont(); end
    end
    word(JOBS.mid_prev, 1 - e, -12 * bs * e, 1 - 0.08 * e);
    word(JOBS.mid_cur, e * (0.9 + 0.1 * breathe), 12 * bs * (1 - e), 1.06 - 0.06 * e);
    imgui.SetWindowFontScale(fs);
end

-- Under the wheel: the gear set you're wearing. A small grey header, the name in Bahnschrift, and under it a red
-- line, a small gold diamond and a blue line. The name lights up for a moment when the set changes.
function JOBS.title(dl, cx, cy, R, bs, fs, status)
    if cfg.middle == 'set' then                                     -- the set's name is in the middle: the job icon sits here
        local jab = nil;
        pcall(function() jab = JOBS.abbr[AshitaCore:GetMemoryManager():GetPlayer():GetMainJob()]; end);
        local ic = jab and logo_texture('jobicons/' .. jab:lower() .. '.png') or nil;
        if ic then
            local h = R * 0.24;
            JOBS.icon_smoke(dl, ic, cx, cy + R + h * 0.55, h, bs, os.clock(), jab);
        end
        return;
    end
    if (cfg.bottom or 'set') == 'off' then return; end
    local now = os.clock();
    local label = JOBS.set_label(status);
    if JOBS.crest_sig ~= label then
        if JOBS.crest_sig ~= nil then JOBS.crest_t = now; end
        JOBS.crest_sig = label;
    end
    local flash = math.max(0, 1 - (now - (JOBS.crest_t or -9)) / 0.9);
    -- the ornate plaque (the user's mockup: gold frame, red / blue wings, bars and a gold diamond), with the
    -- header and the set's name written into it in a serif
    -- the set's name on a soft black patch just under the ring (no frame), in the chosen font and colour, with a
    -- red line, a small gold diamond and a blue line under it; it brightens for a moment when the set changes
    local sc = SET_COLORS[1][3];
    for _, c in ipairs(SET_COLORS) do if c[1] == cfg.set_color then sc = c[3]; end end
    local col = { sc[1] + (1 - sc[1]) * flash, sc[2] + (1 - sc[2]) * flash, sc[3] + (1 - sc[3]) * flash, 1 };
    -- in YunaUI's font (the chat's)
    local pushed, ysc = JOBS.yfont(17 * bs);
    imgui.SetWindowFontScale(ysc);
    local tw, th = imgui.CalcTextSize(label);
    local r1, r2 = R + 3 * bs, R + 3 * bs + th + 8 * bs;         -- just the name, under the ring (no band)
    local tx, ty = cx - tw / 2, cy + (r1 + r2) / 2 - th / 2;
    for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 }, { 0, 2 } }) do
        dl:AddText({ tx + o[1], ty + o[2] }, u32({ 0, 0, 0, 0.85 }), label);
    end
    dl:AddText({ tx, ty }, u32(col), label);
    if pushed then imgui.PopFont(); end
    imgui.SetWindowFontScale(fs);
end

-- On top of the Sumi-e / Neon looks: your job and level in a pill at the top, HP and MP outside the ring on the
-- left and right, TP in the middle at the bottom
function JOBS.overlay(dl, cx, cy, R, bs, fs, theme)
    local hp, mp, tp = JOBS.last_hp or 0, JOBS.last_mp or 0, JOBS.last_tp or 0;
    local b = JOBS.bars;
    JOBS.title(dl, cx, cy, R, bs, fs, JOBS.status);
    local hpc, mpc = { 1.00, 0.42, 0.72, 1 }, { 0.55, 0.55, 1.00, 1 };
    local tpc = tp >= 1000 and { 1.00, 0.84, 0.36, 1 } or { 0.88, 0.70, 0.30, 1 };
    -- HP on the left and MP on the right, outside the ring at mid height: the ring itself shows how full they are
    local now_ = os.clock();
    local hb, mb = JOBS.low_beat(JOBS.hpp, now_, 0.37), JOBS.low_beat(JOBS.mpp, now_, 0.74);
    if (cfg.stat_mode or 'wheel') == 'bars' then return; end           -- they have bars of their own
    JOBS.stat(dl, cx - R * 1.10, cy, -1, 'HP', tostring(hp), hpc, fs, bs, nil, b.hp, hb);
    JOBS.stat(dl, cx + R * 1.10, cy, 1, 'MP', tostring(mp), mpc, fs, bs, nil, b.mp, mb);
    -- TP in the middle at the bottom: a small gold notch, the label, the value, and short gold lines either side
    -- TP above the wheel (the job pill is underneath)
    local ss = math.max(0.6, math.min(2.0, tonumber(cfg.stat_size) or 1));
    local ty = cy - R - 4 * bs;
    if theme == 'neon' then
        dl:AddTriangleFilled({ cx - 6 * bs, ty + 6 * bs }, { cx + 6 * bs, ty + 6 * bs }, { cx, ty + 12 * bs }, u32(tpc));
    end
    JOBS.stat(dl, cx, ty - 16 * bs * ss, 0, 'TP', tostring(tp), tpc, fs, bs, false, b.tp);
end

function JOBS.disc(dl, cx, cy, R, ring_r, bs, gs, c1, c2, jkey, fs)
    local theme = cfg.theme or 'classic';
    if theme ~= 'classic' then
        JOBS.last_hp, JOBS.last_mp, JOBS.last_tp = JOBS.stats();
        do return; end                                              -- (YunaUI) no ring: HP / MP are bars in the middle now
    end
    local bg = cfg.bg or 'ink';
    if bg == 'ink' then
        -- nearly black, semi-transparent, a charcoal grain and faint dry ink brushstrokes under the ring
        local tex = logo_texture('bg_ink.png');
        if tex then
            for i = 1, 3 do
                dl:AddCircleFilled({ cx, cy + i * 1.5 * bs }, R + i * 1.2 * bs, u32({ 0, 0, 0, 0.06 }), 64);
            end
            draw_image(dl, tex, cx - R, cy - R, cx + R, cy + R, 1);
            JOBS.bezel(dl, cx, cy, R, bs, fs);
            return;
        end
        bg = 'glass';
    end
    if bg == 'solid' then
        for i = 1, 6 do
            local o = i * bs;
            dl:AddCircleFilled({ cx + o, cy + o * 1.5 }, R + o * 0.5, u32({ 0, 0, 0, 0.10 }), 64);
        end
        dl:AddCircleFilled({ cx, cy }, R, u32(C.face), 96);
        JOBS.bezel(dl, cx, cy, R, bs, fs);
        return;
    end
    if bg == 'none' then
        dl:AddCircle({ cx, cy }, ring_r, u32({ 0, 0, 0, 0.22 }), 96, 3 * bs);
        dl:AddCircle({ cx, cy }, ring_r, u32({ 1, 1, 1, 0.16 }), 96, 1 * bs);
        for i = 1, 10 do                                    -- a soft shade behind the figure, so it reads on bright ground
            dl:AddCircleFilled({ cx, cy }, (ring_r * 0.62) * (1 - (i - 1) / 12), u32({ 0.02, 0.02, 0.05, 0.045 }), 48);
        end
        JOBS.bezel(dl, cx, cy, R, bs, fs);
        return;
    end
    local t = { C.face[1], C.face[2], C.face[3] };
    if bg == 'job' then
        local jc = (jkey and JOBS.color[jkey]) or { 0.95, 0.15, 0.15 };
        t = { t[1] * 0.55 + jc[1] * 0.16, t[2] * 0.55 + jc[2] * 0.16, t[3] * 0.55 + jc[3] * 0.16 };
    end
    for i = 1, 3 do                                         -- a light shadow, spread out
        dl:AddCircleFilled({ cx, cy + i * 1.5 * bs }, R + i * 1.2 * bs, u32({ 0, 0, 0, 0.05 }), 64);
    end
    dl:AddCircleFilled({ cx, cy }, R, u32({ t[1], t[2], t[3], 0.74 }), 96);        -- smoked glass
    for i = 1, 8 do                                         -- lighter towards the middle
        dl:AddCircleFilled({ cx, cy }, R * (0.92 - i * 0.09), u32({ t[1] + 0.10, t[2] + 0.10, t[3] + 0.14, 0.035 }), 64);
    end
    for i = 1, 6 do                                         -- darker at the edge
        dl:AddCircle({ cx, cy }, R - i * 2 * bs, u32({ 0, 0, 0, 0.07 * (1 - i / 7) }), 96, 2 * bs);
    end
    JOBS.bezel(dl, cx, cy, R, bs, fs);
    JOBS.arc(dl, cx, cy, R - 3 * bs, 200, 340, u32({ 1, 1, 1, 0.08 }), 3 * bs);     -- a sheen across the top
end

-- Every piece of gear you own (inventory and wardrobes) gets its sharp copy made in the background, after the
-- equipped ones and one every few frames, so whatever you swap into is sharp straight away. The list is
-- refreshed every minute and whenever the icon size changes.
function JOBS.prewarm()
    if #big_queue > 0 or ye.big_S == nil or ye.big_S <= 34 or IS_DX8 ~= false then return; end   -- icons drawn at their own size need no copy
    local now = os.clock();
    if ye.warm_list == nil or ye.warm_S ~= ye.big_S or now > ye.warm_rescan then
        local list, seen = {}, {};
        pcall(function()
            local inv, res = AshitaCore:GetMemoryManager():GetInventory(), AshitaCore:GetResourceManager();
            for _, bag in ipairs({ 0, 8, 10, 11, 12, 13, 14, 15, 16 }) do
                for i = 1, 80 do
                    local it = inv:GetContainerItem(bag, i);
                    local id = it and it.Id or 0;
                    if id ~= 0 and id ~= 65535 and not seen[id] then
                        seen[id] = true;
                        local ri = res:GetItemById(id);
                        if ri and (ri.Slots or 0) ~= 0 then list[#list + 1] = id; end
                    end
                end
            end
        end);
        ye.warm_list, ye.warm_i, ye.warm_S, ye.warm_rescan = list, 1, ye.big_S, now + 60;
    end
    ye.warm_tick = (ye.warm_tick or 0) + 1;
    if ye.warm_tick % 20 ~= 0 then return; end                    -- gently: one icon every 20 frames
    for _ = 1, 40 do                                       -- skip the ones already done, then make one
        local id = ye.warm_list[ye.warm_i];
        if id == nil then return; end
        ye.warm_i = ye.warm_i + 1;
        if bigs[id .. ':' .. ye.warm_S] == nil then
            local ic = item_icon(id);
            if ic then item_big(id, ic, ye.warm_S); end
            return;
        end
    end
end

-- HP, MP and TP round the Orbit's bezel: HP down the left side, MP down the right, TP across the top, each with
-- rounded ends and its number beside it, outside the ring. HP and MP are alive: a light runs along them, and their
-- tip glows. Each bar eases to its value; a lighter piece shows what was just lost and drains after it. Low HP
-- pulses; TP brightens once you can weapon skill (marks at 1000 and 2000).
JOBS.bars = { hp = 1, mp = 1, tp = 0, hp_lag = 1, mp_lag = 1 };
-- A bar along the circle from angle a1 to a2 (degrees), with round ends. col = colour at a1, col2 = colour at a2
function JOBS.bar(dl, cx, cy, r, a1, a2, col, col2, th)
    col2 = col2 or col;
    local n = math.max(2, math.floor(math.abs(a2 - a1) / 2.5));
    for i = 0, n - 1 do
        local f, g = i / n, (i + 1) / n;
        local p, q = math.rad(a1 + (a2 - a1) * f), math.rad(a1 + (a2 - a1) * g);
        local m = (f + g) / 2;
        local c = u32({ col[1] + (col2[1] - col[1]) * m, col[2] + (col2[2] - col[2]) * m, col[3] + (col2[3] - col[3]) * m, col[4] + (col2[4] - col[4]) * m });
        dl:AddLine({ cx + math.cos(p) * r, cy + math.sin(p) * r }, { cx + math.cos(q) * r, cy + math.sin(q) * r }, c, th);
        -- fill the little notch where two straight pieces meet (the black outline showed through there)
        if i < n - 1 then dl:AddCircleFilled({ cx + math.cos(q) * r, cy + math.sin(q) * r }, th / 2, c, 10); end
    end
    local s1, s2 = math.rad(a1), math.rad(a2);                            -- the round ends
    dl:AddCircleFilled({ cx + math.cos(s1) * r, cy + math.sin(s1) * r }, th / 2, u32(col), 16);
    dl:AddCircleFilled({ cx + math.cos(s2) * r, cy + math.sin(s2) * r }, th / 2, u32(col2), 16);
end
-- A small label and value beside a bar: the label in the bar's colour over the value, in the card's own font
function JOBS.tag(dl, x, y, ax, label, value, c, fs)
    local ss = math.max(0.6, math.min(2.0, tonumber(cfg.stat_size) or 1));
    local LS, VS = 0.85 * ss, 1.25 * ss;                           -- label and value sizes
    imgui.SetWindowFontScale(fs * LS);
    local lw, lh = imgui.CalcTextSize(label);
    imgui.SetWindowFontScale(fs * VS);
    local vw, vh = imgui.CalcTextSize(value);
    local w, h = math.max(lw, vw), lh + vh - 2;
    local x1 = x - w / 2;                                          -- ax: -1 = text to the left of x, 1 = to the right, 0 = centred
    if ax < 0 then x1 = x - w; elseif ax > 0 then x1 = x; end
    local y1 = y - h / 2;
    local function al(tw) if ax < 0 then return x1 + w - tw; elseif ax > 0 then return x1; end return x1 + (w - tw) / 2; end
    imgui.SetWindowFontScale(fs * LS);
    dl:AddText({ al(lw) + 1, y1 + 1 }, u32({ 0, 0, 0, 0.85 }), label);
    dl:AddText({ al(lw), y1 }, u32({ c[1], c[2], c[3], 1 }), label);
    imgui.SetWindowFontScale(fs * VS);
    for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do       -- a dark outline: readable anywhere
        dl:AddText({ al(vw) + o[1], y1 + lh - 2 + o[2] }, u32({ 0, 0, 0, 0.75 }), value);
    end
    dl:AddText({ al(vw) + 1, y1 + lh - 1 }, u32({ 0, 0, 0, 0.85 }), value);
    dl:AddText({ al(vw), y1 + lh - 2 }, u32({ 1, 1, 1, 0.96 }), value);
    imgui.SetWindowFontScale(fs);
end
function JOBS.bezel(dl, cx, cy, R, bs, fs)
    local b = JOBS.bars;
    local now = os.clock();
    local dt = math.min(0.1, now - (b.t or now));
    b.t = now;
    local hp, mp, tp, hpp, mpp = 0, 0, 0, 100, 100;
    pcall(function()
        local pt = AshitaCore:GetMemoryManager():GetParty();
        hp, mp, tp = pt:GetMemberHP(0), pt:GetMemberMP(0), pt:GetMemberTP(0);
        hpp, mpp = pt:GetMemberHPPercent(0), pt:GetMemberMPPercent(0);
    end);
    local first = (b.seen == nil);
    b.seen = true;
    local function ease(key, v)
        if first then b[key] = v; if b[key .. '_lag'] then b[key .. '_lag'] = v; end return; end   -- no drain on load
        b[key] = b[key] + (v - b[key]) * math.min(1, dt * 8);
        local lag = key .. '_lag';
        if b[lag] then
            if v >= b[lag] then b[lag] = v; else b[lag] = math.max(v, b[lag] - dt * 0.35); end
        end
    end
    ease('hp', hpp / 100); ease('mp', mpp / 100); ease('tp', math.min(3000, tp) / 3000);
    local th = 6 * bs;
    dl:AddCircle({ cx, cy }, R, u32({ 0, 0, 0, 0.45 }), 128, th + 4 * bs);                -- the bezel under the bars
    local low = (hpp <= 25 and hpp > 0) and (0.5 + 0.5 * math.sin(now * 8)) or 0;
    local hpc = { 0.95 + 0.05 * low, 0.33 - 0.1 * low, 0.38 - 0.1 * low };
    local mpc = { 0.40, 0.66, 1.00 };
    local tpc = tp >= 1000 and { 1.00, 0.86, 0.38 } or { 0.88, 0.70, 0.30 };
    -- { from angle, to angle (fills from -> to), value, lag, colour, alive, phase }  (0 = right, 90 = down)
    local bars = { { 108, 234, b.hp, b.hp_lag, hpc, true, 0 }, { 72, -54, b.mp, b.mp_lag, mpc, true, 0.5 }, { 248, 292, b.tp, nil, tpc, false } };
    for _, bar in ipairs(bars) do
        local a1, a2, v, lag, c = bar[1], bar[2], bar[3], bar[4], bar[5];
        local dir = (a2 > a1) and 1 or -1;
        JOBS.bar(dl, cx, cy, R, a1, a2, { c[1] * 0.20, c[2] * 0.20, c[3] * 0.20, 0.95 }, nil, th);   -- the track
        if lag and lag > v + 0.002 then
            JOBS.bar(dl, cx, cy, R, a1 + (a2 - a1) * v, a1 + (a2 - a1) * lag, { 1, 0.92, 0.85, 0.5 }, nil, th);
        end
        if v > 0.004 then
            local e = a1 + (a2 - a1) * math.min(1, v);
            JOBS.bar(dl, cx, cy, R, a1, e, { c[1], c[2], c[3], 0.18 }, nil, th + 5 * bs);   -- soft glow
            -- deeper at the start, bright at the tip
            JOBS.bar(dl, cx, cy, R, a1, e, { c[1] * 0.62, c[2] * 0.62, c[3] * 0.62, 1 }, { c[1], c[2], c[3], 1 }, th);
            if bar[6] and cfg.bezel_fx then
                -- alive: a soft light running from the start to the tip, again and again
                local span = math.abs(e - a1);
                local ph = (now / 2.6 + bar[7]) % 1;
                local pa = a1 + (e - a1) * ph;
                for k, wdt in ipairs({ 9, 5, 2.5 }) do
                    local s1 = pa - dir * wdt;
                    local s2 = pa + dir * wdt;
                    local lo, hi = math.min(a1, e), math.max(a1, e);
                    s1, s2 = math.max(lo, math.min(hi, s1)), math.max(lo, math.min(hi, s2));
                    if math.abs(s2 - s1) > 0.3 and span > 4 then
                        JOBS.arc(dl, cx, cy, R, s1, s2, u32({ 1, 1, 1, 0.10 * k }), th * (0.5 + 0.15 * k));
                    end
                end
                -- the tip breathes
                local ta = math.rad(e);
                local pulse = 0.5 + 0.5 * math.sin(now * 3 + bar[7] * 6);
                dl:AddCircleFilled({ cx + math.cos(ta) * R, cy + math.sin(ta) * R }, th * (0.9 + 0.35 * pulse), u32({ c[1], c[2], c[3], 0.25 }), 16);
                dl:AddCircleFilled({ cx + math.cos(ta) * R, cy + math.sin(ta) * R }, th * 0.28, u32({ 1, 1, 1, 0.55 + 0.3 * pulse }), 12);
            end
            JOBS.arc(dl, cx, cy, R - th * 0.25, a1, e, u32({ 1, 1, 1, 0.18 }), 1 * bs);      -- a thin shine along it
        end
        if not bar[6] then                                                          -- TP: marks at 1000 and 2000
            for _, f in ipairs({ 1 / 3, 2 / 3 }) do
                local a = math.rad(a1 + (a2 - a1) * f);
                dl:AddLine({ cx + math.cos(a) * (R - th / 2), cy + math.sin(a) * (R - th / 2) }, { cx + math.cos(a) * (R + th / 2), cy + math.sin(a) * (R + th / 2) }, u32({ 0, 0, 0, 0.85 }), 1.5 * bs);
            end
        end
    end
    -- the numbers, beside their bars outside the ring
    local function at(deg, d) local a = math.rad(deg); return cx + math.cos(a) * (R + d), cy + math.sin(a) * (R + d); end
    local x, y = at(171, th / 2 + 5 * bs); JOBS.tag(dl, x, y, -1, 'HP', tostring(hp), hpc, fs);
    x, y = at(9, th / 2 + 5 * bs);         JOBS.tag(dl, x, y, 1, 'MP', tostring(mp), mpc, fs);
    x, y = at(270, th / 2 + 18 * bs);      JOBS.tag(dl, x, y, 0, 'TP', tostring(tp), tpc, fs);
end

-- ---------------------------------------------------------------------------------------------------
-- "Separate bars" (HP / MP / TP setting): HP, MP and TP leave the wheel and become three long thin bars of their own,
-- each in a window you can drag anywhere, in YunaUI's look (its font, its living bars). Under 50% HP or MP, that
-- bar breathes with a warning glow that quickens as it gets lower.
-- ---------------------------------------------------------------------------------------------------
function JOBS.yfont(size)
    local list = fonts.yui or {};
    if #list == 0 then return push_font(fonts.semi, size), size / 20; end
    local pick = list[#list];
    for _, e in ipairs(list) do if e[2] >= size - 0.5 then pick = e; break; end end
    local pushed = push_font(pick[1], pick[2]);
    return pushed, size / pick[2];
end
function JOBS.frac(v) return v - math.floor(v); end
-- YunaUI's bar: dark track, a breathing coloured glow, the two colours flowing along the fill, a sheen gliding by,
-- a white head, and a lighter piece draining after a loss. warn (0..1): the low-HP/MP breath, stronger glow and light.
function JOBS.ybar(dl, x, y, w, h, v, lag, c1, c2, seed, warn)
    v = math.max(0, math.min(1, v or 0));
    warn = warn or 0;
    local now = os.clock();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32({ 0.05, 0.04, 0.07, 0.70 }), h / 2);
    if lag and lag > v then dl:AddRectFilled({ x + w * v, y }, { x + w * lag, y + h }, u32({ 1, 0.92, 0.95, 0.40 }), h / 2); end
    if v <= 0 then return; end
    local fw = w * v;
    local pulse = 0.5 + 0.5 * math.sin(now * 2.2 + seed);
    local gl = (0.75 + 0.5 * pulse) + warn * 2.2;
    for k = 1, 4 + math.floor(warn * 4) do
        dl:AddRectFilled({ x - k, y - k }, { x + fw + k, y + h + k }, u32({ c2[1], c2[2], c2[3], math.max(0, 0.11 - k * 0.018) * gl }), h / 2 + k);
    end
    dl:AddRectFilled({ x - 1, y - 1 }, { x + fw + 1, y + h + 1 }, u32({ c2[1], c2[2], c2[3], 0.85 }), h / 2 + 1);
    local segs = math.max(4, math.floor(w / 40));
    local still = (cfg.sb_fx == 'still') or ((cfg.sb_fx or 'same') == 'same' and YUI_BAR_FX and YUI_BAR_FX() ~= 'flow');
    local ph = still and 0.3 or (now * (0.35 + warn * 0.5) + seed * 0.21);
    local function col_at(f)
        local u = 0.5 + 0.5 * math.sin((f * 1.6 - ph) * math.pi * 2);
        return u32({ c1[1] + (c2[1] - c1[1]) * u, c1[2] + (c2[2] - c1[2]) * u, c1[3] + (c2[3] - c1[3]) * u, 1 });
    end
    for k = 0, segs - 1 do
        local f1, f2 = k / segs, (k + 1) / segs;
        local x1, x2 = x + w * f1, math.min(x + fw, x + w * f2);
        if x2 > x1 then
            local a, b = col_at(f1), col_at(x2 == x + fw and (fw / w) or f2);
            dl:AddRectFilledMultiColor({ x1, y }, { x2, y + h }, a, b, b, a);
        end
    end
    if warn > 0.01 then dl:AddRectFilled({ x, y }, { x + fw, y + h }, u32({ 1, 1, 1, 0.30 * warn }), h / 2); end
    local sp = JOBS.frac(now * 0.32 + seed * 0.137);
    local hx, hw = x - 40 + sp * (fw + 80), 40;
    local function band(x1, x2, a1, a2)
        local cx1, cx2 = math.max(x, x1), math.min(x + fw, x2);
        if cx2 <= cx1 then return; end
        local f1, f2 = (cx1 - x1) / (x2 - x1), (cx2 - x1) / (x2 - x1);
        local b1, b2 = a1 + (a2 - a1) * f1, a1 + (a2 - a1) * f2;
        dl:AddRectFilledMultiColor({ cx1, y }, { cx2, y + h }, u32({ 1, 1, 1, b1 }), u32({ 1, 1, 1, b2 }), u32({ 1, 1, 1, b2 }), u32({ 1, 1, 1, b1 }));
    end
    -- the effect: 'same' follows YunaUI's bar effect; flow (the sheen), electric, pulse or still
    local fx = cfg.sb_fx or 'same';
    if fx == 'same' then fx = (YUI_BAR_FX and YUI_BAR_FX()) or 'flow'; end
    if fx == 'flow' then
        band(hx - hw, hx, 0, 0.55);
        band(hx, hx + hw, 0.55, 0);
    elseif fx == 'electric' then
        local beat = math.max(0, math.sin(now * 2.6 + seed)) ^ 3;
        local a = 0.18 + 0.55 * beat;
        dl:PushClipRect({ x, y }, { x + fw, y + h }, true);
        local tick = math.floor(now * 14);
        local step = math.max(4, h * 1.8);
        for pass = 1, 2 do
            local px, py = x, y + h / 2;
            local k = 0;
            while px < x + fw do
                k = k + 1;
                local r = JOBS.frac(math.sin(tick * 31.7 + k * 12.9898 + seed * 7.1 + pass * 3.3) * 43758.5453);
                local nx = math.min(x + fw, px + step * (0.6 + 0.8 * JOBS.frac(r * 7.7)));
                local ny = y + h * (0.12 + 0.76 * r);
                dl:AddLine({ px, py }, { nx, ny }, u32({ 0.92, 0.97, 1, a * ((pass == 1) and 1 or 0.4) }), (pass == 1) and 1 or 1.6);
                px, py = nx, ny;
            end
        end
        dl:AddRectFilled({ x, y }, { x + fw, y + h }, u32({ 1, 1, 1, 0.10 * beat }));
        dl:PopClipRect();
    elseif fx == 'pulse' then
        local pb = 0.5 - 0.5 * math.cos(now * 2.2 + seed);
        dl:AddRectFilled({ x, y }, { x + fw, y + h }, u32({ 1, 1, 1, 0.22 * pb }), h / 2);
    end
    if fw > 0.5 and v < 0.985 then                                   -- the end: a soft light in the bar's own colour, a fine bright edge (not on a full bar)
        local e = c2 or { 1, 1, 1 };
        local lt = { e[1] + (1 - e[1]) * 0.85, e[2] + (1 - e[2]) * 0.85, e[3] + (1 - e[3]) * 0.85 };
        local L = math.min(fw, math.max(8, h * 2.6));
        pcall(function()
            dl:AddRectFilledMultiColor({ x + fw - L, y }, { x + fw, y + h }, u32({ lt[1], lt[2], lt[3], 0 }), u32({ lt[1], lt[2], lt[3], 0.50 }),
                u32({ lt[1], lt[2], lt[3], 0.50 }), u32({ lt[1], lt[2], lt[3], 0 }));
        end);
        local cw_ = math.max(1.2, math.min(2, h * 0.25));
        dl:AddRectFilled({ x + fw - cw_, y }, { x + fw, y + h }, u32({ 1, 1, 1, 0.95 }));
    end
end
-- Text with a dark outline all round (as YunaUI's chat)
function JOBS.otext(dl, x, y, s, c)
    local oc = u32({ 0, 0, 0, 0.9 * (c[4] or 1) });
    for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 1, 2 } }) do
        dl:AddText({ x + o[1], y + o[2] }, oc, s);
    end
    dl:AddText({ x, y }, u32(c), s);
end
JOBS.SB = {
    hp = { 'HP', { 1.00, 0.36, 0.62 }, { 0.86, 0.24, 0.86 }, { 1.00, 0.42, 0.72 }, 0 },
    mp = { 'MP', { 0.40, 0.55, 1.00 }, { 0.62, 0.40, 1.00 }, { 0.62, 0.58, 1.00 }, 1 },
    tp = { 'TP', { 1.00, 0.95, 0.74 }, { 0.95, 0.76, 0.34 }, { 1.00, 0.84, 0.42 }, 2 },
};
-- The anchor dots next to your HP number (the Damage Meter's look): a click stacks MP and TP under HP, a second
-- click puts them side by side, a third lets them go. While anchored they follow the HP bar (drag HP, they all move).
JOBS.sb_size, JOBS.sb_from, JOBS.sb_off = {}, {}, {};   -- sb_off: where each bar's line is, from its window's top
function JOBS.sb_anchor_icon(dl, ix, iy, h)
    local mode = tonumber(cfg.sb_anchor) or 0;
    local w = h * 1.3;
    imgui.SetCursorScreenPos({ ix, iy });
    local clicked = imgui.InvisibleButton('##ye_sb_anchor', { w, h });
    local hov = imgui.IsItemHovered();
    if hov then
        (YUI_TIP or imgui.SetTooltip)(({ [0] = 'Bars free\nClick: MP and TP stack under HP',
            [1] = 'Anchored: stacked under HP\nClick: side by side', [2] = 'Anchored: side by side\nClick: let them go' })[mode]);
    end
    local cx, cy, r = ix + w / 2, iy + h / 2, h * 0.27;
    local a = hov and 1 or ((mode > 0) and 0.95 or 0.40);
    local pk, vi = JOBS.SB.hp[2], JOBS.SB.mp[3];                    -- pink and violet, as the bars
    local pts = (mode == 1) and { { cx, cy - r * 0.92, pk }, { cx, cy + r * 0.92, vi } }   -- stacked: one over the other
        or { { cx - r * 0.92, cy, pk }, { cx + r * 0.92, cy, vi } };                      -- side by side
    if mode == 1 then r = r * 0.85; end
    for _, d in ipairs(pts) do
        local c = (mode > 0) and d[3] or { 1, 1, 1 };
        if mode > 0 and hov then c = { math.min(1, c[1] + 0.2), math.min(1, c[2] + 0.2), math.min(1, c[3] + 0.2) }; end
        dl:AddCircleFilled({ d[1], d[2] }, r + 1.2, u32({ 0.15, 0.14, 0.18, 0.75 * math.max(a, 0.6) }), 20);   -- the dark rim
        dl:AddCircleFilled({ d[1], d[2] }, r, u32({ c[1], c[2], c[3], a }), 20);
    end
    if clicked then
        cfg.sb_anchor = (mode + 1) % 3;
        JOBS.sb_t0 = os.clock();                                     -- (MP and TP glide to their new places)
        for _, k in ipairs({ 'mp', 'tp' }) do JOBS.sb_from[k] = { tonumber(cfg[k .. 'bar_x']) or 0, tonumber(cfg[k .. 'bar_y']) or 0 }; end
        save();
    end
end
-- Where MP / TP go while anchored (nil when free): under the bar before it, or to its right
function JOBS.sb_anchor_pos(key)
    local mode = tonumber(cfg.sb_anchor) or 0;
    if mode == 0 or key == 'hp' or YUI_LOCKED then return nil; end
    local prev = (key == 'mp' or cfg.sb_mp == false) and 'hp' or 'mp';   -- (no MP bar: TP follows the HP bar)
    local px, py = tonumber(cfg[prev .. 'bar_x']), tonumber(cfg[prev .. 'bar_y']);
    local sz = JOBS.sb_size[prev];
    if px == nil or py == nil or sz == nil then return nil; end
    local tx, ty;
    local o1, o2 = JOBS.sb_off[prev], JOBS.sb_off[key];
    if mode == 1 then                                               -- stacked: same left edge, the same gap under each line
        tx = px;
        ty = (o1 and o2) and (py + o1[2] + 6 - o2[1]) or (py + sz[2] - 6);
    else                                                             -- side by side: all the bars on one line
        tx = px + sz[1] + 6;
        ty = (o1 and o2) and (py + o1[2] - o2[2]) or py;
    end
    tx, ty = math.floor(tx + 0.5), math.floor(ty + 0.5);
    local e = JOBS.sb_t0 and math.min(1, (os.clock() - JOBS.sb_t0) / 0.35) or 1;
    local f = JOBS.sb_from[key];
    if e < 1 and f then
        local ee = 1 - (1 - e) ^ 3;
        return f[1] + (tx - f[1]) * ee, f[2] + (ty - f[2]) * ee;
    end
    return tx, ty;
end
function JOBS.statbar(key, value, v, lag, pct)
    local d = JOBS.SB[key];
    if key == 'hp' and type(YUI_HP_COL) == 'table' then             -- YunaUI's BARS > Your HP bar (Pink, Red or White)
        d[2], d[3], d[4] = YUI_HP_COL[1], YUI_HP_COL[2], YUI_HP_COL[3];
    end
    local kx, ky = key .. 'bar_x', key .. 'bar_y';
    local sc = math.max(0.5, math.min(2.5, (tonumber(cfg.sb_scale) or 1) * (tonumber(cfg['sb_' .. key .. '_size']) or 1)));
    if (tonumber(cfg[kx]) or -1) < 0 then                           -- first time: in a column near the middle of the screen
        local ds = imgui.GetIO().DisplaySize;
        local dw, dh = (ds and ds.x) or 1920, (ds and ds.y) or 1080;
        cfg[kx], cfg[ky] = math.floor(dw / 2 - 140 * sc), math.floor(dh * 0.62 + d[5] * 46 * sc);
    end
    JOBS.sb_flags = JOBS.sb_flags or bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoSavedSettings);
    local flags = JOBS.sb_flags;
    if YUI_LOCKED then                                      -- (YunaUI's GENERAL > Lock positions; EQUIP's lock is for the wheel)
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove); end
    local ax, ay = JOBS.sb_anchor_pos(key);                          -- anchored: it follows the bar before it
    if ax then
        flags = bit.bor(flags, ImGuiWindowFlags_NoMove);
        imgui.SetNextWindowPos({ ax, ay }, ImGuiCond_Always);
    else
    imgui.SetNextWindowPos({ cfg[kx], cfg[ky] }, ((JOBS.sb_move or 0) > 0) and ImGuiCond_Always or ImGuiCond_FirstUseEver);
    end
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    if imgui.Begin('YunaEquip ' .. d[1] .. '##ye_sb_' .. key, { true }, flags) then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        x, y = x + 8, y + 6;
        local w = 260 * math.max(0.3, math.min(4, (tonumber(cfg.sb_len) or 1) * (tonumber(cfg['sb_' .. key .. '_len']) or 1))) * sc;
        local now = os.clock();
        local warn = 0;
        if key ~= 'tp' and cfg.low_on ~= false and pct and pct < 50 and pct > 0 then
            warn = JOBS.low_beat(pct, now, d[5] * 0.37 + 0.2) * 1.6;      -- breathes faster as it gets lower
        end
        -- the stat's name in its colour (small), the number in white beside it
        local pushed, fsc = JOBS.yfont(13 * sc);
        imgui.SetWindowFontScale(fsc);
        local lw, lh = imgui.CalcTextSize(d[1]);
        local lc = d[4];
        if warn > 0 then lc = { lc[1] + (1 - lc[1]) * warn * 0.5, lc[2] * (1 - warn * 0.3), lc[3] * (1 - warn * 0.3), 1 }; end
        imgui.SetWindowFontScale(1);
        if pushed then imgui.PopFont(); end
        local pushed2, fsc2 = JOBS.yfont(22 * sc);
        imgui.SetWindowFontScale(fsc2);
        local vw, vh = imgui.CalcTextSize(value);
        local vy = y;
        local vc = { 1, 1, 1, 1 };
        if key == 'tp' and (tonumber(value) or 0) >= 1000 then
            local br = 0.5 + 0.5 * math.sin(now * 4);
            vc = { 1, 0.9 + 0.1 * br, 0.5 + 0.35 * br, 1 };
        end
        JOBS.otext(dl, x + lw + 8 * sc, vy, value, vc);
        imgui.SetWindowFontScale(1);
        if pushed2 then imgui.PopFont(); end
        pushed, fsc = JOBS.yfont(13 * sc);
        imgui.SetWindowFontScale(fsc);
        JOBS.otext(dl, x, vy + vh - lh - 2 * sc, d[1], { lc[1], lc[2], lc[3], 1 });
        imgui.SetWindowFontScale(1);
        if pushed then imgui.PopFont(); end
        if key == 'hp' then                                          -- the anchor dots, just right of the HP number
            local ih = 13 * sc;
            JOBS.sb_anchor_icon(dl, x + lw + 8 * sc + vw + 6 * sc, vy + vh - ih - 3 * sc, ih);
            imgui.SetCursorScreenPos({ x - 8, y - 6 });
        end
        -- the bar under them
        local thk = (key == 'mp') and (tonumber(cfg.sb_mp_thick) or tonumber(cfg.sb_thick)) or tonumber(cfg.sb_thick);   -- BARS > HP / MP bar thickness
        local bh = math.max(2, math.floor(4 * sc * math.max(0.5, math.min(3, thk or 1)) + 0.5));
        local by = vy + vh + 3 * sc;
        JOBS.ybar(dl, x, by, w, bh, v, lag, d[2], d[3], d[5] * 1.7 + 0.4, warn);
        if key == 'hp' and YUI_BAR_OVERLAY then YUI_BAR_OVERLAY(x, by, w * math.max(0, math.min(1, v or 0)), bh, 2.2); end   -- YunaUI's HP bar overlay
        if (key == 'hp' or key == 'mp') and YUI_BAR_OUTLINE then YUI_BAR_OUTLINE(dl, x, by, w, bh); end   -- (the thin black edge, HP and MP)
        YUI_EQ_BARPOS = YUI_EQ_BARPOS or {};                         -- where this bar is (YunaUI's gear strip sits under one)
        YUI_EQ_BARPOS[key] = { x, by + bh, w, now, sc, tonumber(cfg.sb_anchor) or 0 };   -- (6: how the bars are anchored)
        if key == 'tp' then                                          -- marks at 1000 and 2000
            for m = 1, 2 do
                local mx = x + w * m / 3;
                dl:AddLine({ mx, by - 2 }, { mx, by + bh + 2 }, u32({ 0, 0, 0, 0.6 }), 1.5);
            end
        end
        imgui.Dummy({ w + 16, by + bh - y + 12 });
        local wx0, wy0 = imgui.GetWindowPos();
        if type(wx0) == 'table' then wx0, wy0 = wx0.x or wx0[1], wx0.y or wx0[2]; end
        if type(wy0) == 'number' then JOBS.sb_off[key] = { vy - wy0, by + bh - wy0 }; end   -- its text's top, its bar's line
        local sw, sh = imgui.GetWindowSize();                        -- (for the bars anchored to this one)
        if type(sw) == 'table' then sw, sh = sw.x or sw[1], sw.y or sw[2]; end
        if type(sw) == 'number' and type(sh) == 'number' and sw > 0 then JOBS.sb_size[key] = { sw, sh }; end
        local wx, wy = imgui.GetWindowPos();
        if math.abs(wx - cfg[kx]) > 0.5 or math.abs(wy - cfg[ky]) > 0.5 then
            cfg[kx], cfg[ky] = wx, wy;
            if not imgui.IsMouseDown(0) then save(); end
        end
        if not ax and YUI_ONSCREEN and type(sw) == 'number' then    -- (always on the screen)
            local nx, ny, moved = YUI_ONSCREEN(wx, wy, sw, sh);
            if moved then cfg[kx], cfg[ky] = nx, ny; JOBS.sb_move = math.max(JOBS.sb_move or 0, 2); save(); end
        end
    end
    imgui.End();
    imgui.PopStyleVar(2);
end
-- The settings YunaUI may change with /ye set (its EQUIP tab)
JOBS.SETTABLE = {};
for k in ('visible locked style theme middle bottom mid_anim big_logo show_ring low_on bezel_fx flash mini icon art_alpha ' ..
    'stat_mode stat_size sb_scale sb_len sb_tp sb_mp layout'):gmatch('%S+') do JOBS.SETTABLE[k] = true; end
-- The first time (per character): bring over your settings from the separate YunaEquip addon, if you had it
function JOBS.import()
    cfg.imported = true;
    pcall(function()
        local p = AshitaCore:GetMemoryManager():GetParty();
        local base = AshitaCore:GetInstallPath():gsub('[\\/]+$', '') .. '\\config\\addons\\yunaequip\\';
        local data = nil;
        for _, sub in ipairs({ string.format('%s_%d', p:GetMemberName(0) or '', p:GetMemberServerId(0) or 0), 'defaults' }) do
            local fh = io.open(base .. sub .. '\\settings.lua', 'rb');
            if fh then data = fh:read('*a'); fh:close(); break; end
        end
        if data == nil then return; end
        local chunk = loadstring(data);
        if chunk == nil then return; end
        setfenv(chunk, { T = function(x) return x; end, require = function() end });
        local ok, old = pcall(chunk);
        if ok and type(old) == 'table' then
            for k, v in pairs(old) do if k ~= 'imported' then cfg[k] = v; end end
            msg('YunaEquip is now part of YunaUI: your YunaEquip settings were brought over. You can unload the old yunaequip addon.');
        end
    end);
    ui.place = true;
    save();
end
function JOBS.statbars()
    if (JOBS.sb_move or 0) > 0 then JOBS.sb_move = JOBS.sb_move - 1; end
    if (cfg.stat_mode or 'wheel') ~= 'bars' then return; end
    local hp, mp, tp, hpp, mpp = JOBS.stats();
    local b = JOBS.bars;
    JOBS.statbar('hp', tostring(hp), b.hp, b.hp_lag, hpp);
    if cfg.sb_mp ~= false then JOBS.statbar('mp', tostring(mp), b.mp, b.mp_lag, mpp); end   -- (BARS > MP bar: can be turned off)
    if cfg.sb_tp ~= false then JOBS.statbar('tp', tostring(tp), b.tp, nil, nil); end
end

local function draw_card(status)
    JOBS.prewarm();
    if os.clock() >= ye.next_scan then
        ye.next_scan = os.clock() + 0.05;
        pcall(scan_equipment);
    end
    make_next_big();

    local sc = math.max(0.5, math.min(2.5, tonumber(cfg.scale) or 1));
    local base = cfg.mini and 16 or math.max(16, math.min(48, tonumber(cfg.icon) or 36));
    local d = base / 36;                                            -- how big the icons are compared to normal
    local bs = sc * math.max(0.5, d);                               -- scale for the small details (border, shadow, marks)
    local TILE = math.floor(base * sc);
    local GAP, CP = math.max(2, math.floor(5 * sc * d)), math.max(3, math.floor(5 * sc * d));
    local ss_ = math.max(0.6, math.min(2.0, tonumber(cfg.stat_size) or 1));
    local M = math.floor((cfg.style == 'orbit' and (((cfg.theme or 'classic') ~= 'classic') and (20 + 88 * ss_) or (12 + 40 * ss_)) or 18) * bs);
    -- above / below the wheel only TP and the set name need room: a much smaller margin there
    local MY = (cfg.style == 'orbit') and math.floor((14 + 34 * ss_) * bs) or M;                                  -- room around the card for the glow and shadow
    local fs = font_scale(sc);
    local orbit = cfg.style == 'orbit';

    -- Card: the grid. Orbit: the main weapon big in the centre, the other 15 on a ring around it.
    local cols, rows, card_w, card_h, RT, ring_r, disc_r;
    if orbit then
        RT = math.floor(TILE * 0.9);                                -- ring items
        -- 16 on the ring, 22.5 degrees apart: neighbours mustn't touch
        ring_r = (RT + GAP) / (2 * math.sin(math.rad(11.25)));
        if cfg.big_logo then ring_r = ring_r * 1.45; end            -- "Big logo": the gear moves out
        disc_r = ring_r + RT / 2 + CP + 2 * bs;
        card_w, card_h = math.ceil(disc_r * 2), math.ceil(disc_r * 2);
    else
        cols = layout_cols();
        rows = math.ceil(#GRID / cols);
        card_w = TILE * cols + GAP * (cols - 1) + CP * 2;
        card_h = TILE * rows + GAP * (rows - 1) + CP * 2;
    end

    if ui.place then
        imgui.SetNextWindowPos({ tonumber(cfg.x) or 200, tonumber(cfg.y) or 200 }, ImGuiCond_Always);
        ui.place = false;
    end
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_AlwaysAutoResize,
        ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoBackground,
        ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoSavedSettings);
    if cfg.locked then flags = bit.bor(flags, ImGuiWindowFlags_NoMove); end

    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    imgui.PushStyleVar(ImGuiStyleVar_Alpha, 1);                     -- Opacity only fades the background (JOBS.disc_alpha)
    local pushed = push_font(fonts.main, math.floor(17 * sc + 0.5));
    if imgui.Begin('YunaEquip##ye_main', { true }, flags) then
        imgui.SetWindowFontScale(fs);
        local dl = imgui.GetWindowDrawList();
        local ox, oy = imgui.GetCursorScreenPos();
        local cx1, cy1 = ox + M, oy + MY;
        local cx2, cy2 = cx1 + card_w, cy1 + card_h;
        local R = math.max(3, math.floor(8 * bs));
        local win, win_h = card_w + M * 2, card_h + MY * 2;
        local dsp = { 1e5, 1e5 };
        pcall(function() local io_ = imgui.GetIO(); dsp = { io_.DisplaySize.x, io_.DisplaySize.y }; end);
        JOBS.dsp = dsp;
        JOBS.clip(dl, { math.max(0, ox), math.max(0, oy) }, { math.min(dsp[1], ox + win), math.min(dsp[2], oy + win_h) }, false);   -- never past the screen

        local gs, gcol, gcol2 = update_glow(status);
        local now = os.clock();
        if status == 'Engaged' and ye.prev_status ~= 'Engaged' and ye.prev_status ~= nil then ye.ripple_t = now; end
        ye.prev_status = status;
        local k = { dl = dl, bs = bs, d = d, fs = fs, gcol = gcol, now = now, round = orbit, socket = false };   -- (the grey sockets behind the items: removed at the user's request)
        local lsc = sc * math.max(0.7, d);
        track_rest(status);

        if orbit then
            local ccx, ccy = cx1 + disc_r, cy1 + disc_r;
            local jkey = nil;
            pcall(function() jkey = JOBS.art[AshitaCore:GetMemoryManager():GetPlayer():GetMainJob()]; end);
            if jkey == 'blm' and cfg.blm_art == 'wak' then jkey = 'wak'; end
            JOBS.ring_in = cfg.big_logo and (ring_r - RT / 2 - 10 * bs) or nil;
            JOBS.disc(dl, ccx, ccy, JOBS.ring_in or disc_r, ring_r, bs, gs, gcol, gcol2, jkey, fs);
            local rot = 0;                                              -- the ring always stands still
            for j, o in ipairs(ORBIT) do
                local a = math.rad(o[2]) + rot;
                local mx, my = ccx + math.cos(a) * ring_r, ccy + math.sin(a) * ring_r;
                if not DBG.slots then draw_slot(k, j, o[1], mx - RT / 2, my - RT / 2, RT, 0.10 + (j - 1) * 0.035); end       -- the ripple runs round the ring
            end
            -- the Yuna logo in the middle (it pops with the engage ripple too). Out of combat the katana is sheathed
            -- (only the hilt shows); when you engage it slides out of the hilt with a glint, and blood starts to drip.
            -- Engaged, the samurai also turns blood red and pulses with the border, glowing along his own outline.
            ART.on, ART.a = true, math.max(0.1, math.min(1, tonumber(cfg.art_alpha) or 1));
            JOBS.status = status;
            ye.job_key = jkey;
            local jdone = false;
            local mid = cfg.middle or 'art';
            local jab = nil;
            pcall(function() jab = JOBS.abbr[AshitaCore:GetMemoryManager():GetPlayer():GetMainJob()]; end);
            local icon_half = 0;
            if mid == 'icon' and jab and cfg.show_icon == false then jdone = true;   -- the job icon is switched off
            elseif mid == 'icon' and jab then                       -- the job icon, coming and going in purple smoke
                local ic = logo_texture('jobicons/' .. jab:lower() .. '.png');
                if ic then
                    local half = JOBS.ring_in and ((JOBS.ring_in - 8 * bs) * 0.62) or ((ring_r - RT / 2 - 6 * bs) * 0.48);
                    if cfg.ripple and ye.ripple_t then
                        local ra = now - ye.ripple_t;
                        if ra > 0 and ra < 0.45 then half = half * (1 + 0.08 * math.sin(ra / 0.45 * math.pi)); end
                    end
                    if not DBG.icon then JOBS.icon_smoke(dl, ic, ccx, ccy, half, bs, now, jab); end
                    icon_half = half * 0.78;
                    jdone = true;
                end
            elseif mid == 'set' then
                JOBS.mid_label(dl, ccx, ccy, ring_r - RT / 2 - 6 * bs, bs, fs, JOBS.set_label(status), jkey or (jab and jab:lower()));
                jdone = true;
            end
            if jkey and mid == 'art' and not DBG.icon then
                local half = JOBS.ring_in and ((JOBS.ring_in - 8 * bs) * 0.95) or ((ring_r - RT / 2 - 6 * bs) * 0.74);
                half = math.floor(half + 0.5);                          -- whole pixels: sharp
                local flash = 0;
                if cfg.ripple and ye.ripple_t then
                    local ra = now - ye.ripple_t;
                    if ra > 0 and ra < 0.45 then half = half * (1 + 0.08 * math.sin(ra / 0.45 * math.pi)); end
                    if ra > 0 and ra < 0.6 then flash = 0.6 * (1 - ra / 0.6); end     -- the energy bursts on engage
                end
                local dt_ = math.min(0.1, now - (JOBS.t or now));
                JOBS.t = now;
                -- little or no background: a soft dark shade just behind the figure, so it still reads on the ground
                local shade = 1 - math.min(1, JOBS.disc_alpha() / 0.7);
                if shade > 0.01 then
                    for k = 1, 48 do                                    -- many faint layers: a smooth shade, no ring lines
                        dl:AddCircleFilled({ ccx, ccy }, half * (1.16 - k * 0.022), u32({ 0.01, 0.01, 0.02, 0.022 * shade }), 96);
                    end
                end
                jdone = JOBS.draw(dl, jkey, math.floor(ccx - half + 0.5), math.floor(ccy - half + 0.5), half * 2, status == 'Engaged', now < ye.cast_until, now, dt_, bs, flash);
            end
            local body, blade, hilt = logo_texture('logo_body.png'), logo_texture('logo_blade.png'), logo_texture('logo_hilt.png');
            local full = (body == nil or blade == nil or hilt == nil) and logo_texture('logo.png') or nil;
            if full then body, blade, hilt = nil, nil, nil; end
            if not jdone and mid == 'art' and not DBG.icon and (body or full) then
                local half = JOBS.ring_in and ((JOBS.ring_in - 8 * bs) * 0.95) or ((ring_r - RT / 2 - 6 * bs) * 0.74);
                if cfg.ripple and ye.ripple_t then
                    local ra = now - ye.ripple_t;
                    if ra > 0 and ra < 0.45 then half = half * (1 + 0.08 * math.sin(ra / 0.45 * math.pi)); end
                end
                local lw = half * 2;                                  -- the picture is square
                local lx, ly = ccx - half, ccy - half;
                local dt_ = math.min(0.1, now - (ye.logo_t or now));
                ye.logo_t = now;
                local engaged = (status == 'Engaged');
                ye.logo_red = (ye.logo_red or 0) + ((engaged and 1 or 0) - (ye.logo_red or 0)) * math.min(1, dt_ * 4);
                -- drawing the sword: the hilt appears in his hand first, then the blade slides out (0.4 s in all);
                -- putting it away goes the other way, slower (0.9 s)
                local was = ye.blade or 0;
                ye.blade = engaged and math.min(1, was + dt_ / 0.4) or math.max(0, was - dt_ / 0.9);
                local hilt_a = math.min(1, ye.blade / 0.25);
                local bo = math.max(0, math.min(1, (ye.blade - 0.2) / 0.8));
                local out = bo * bo * (3 - 2 * bo);                      -- smooth start and stop
                local red = ye.logo_red;
                local beat = 0.5 + 0.5 * math.sin(now / 1.1 * math.pi * 2);
                local kr = red * (0.75 + 0.25 * beat);
                local tint = { 1, 1 - 0.72 * kr, 1 - 0.70 * kr, 0.92 };
                local base = body or full;
                -- glow along the figure itself: red copies nudged a little in every direction, behind it
                if red > 0.01 then
                    local o = 1.6 * bs;
                    local gtint = { 0.95, 0.10, 0.12, (0.10 + 0.08 * beat) * red };
                    for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -0.7, -0.7 }, { 0.7, -0.7 }, { -0.7, 0.7 }, { 0.7, 0.7 } }) do
                        draw_image(dl, base, lx + d[1] * o, ly + d[2] * o, lx + lw + d[1] * o, ly + lw + d[2] * o, nil, gtint);
                    end
                end
                draw_image(dl, base, lx, ly, lx + lw, ly + lw, nil, tint);
                if hilt and hilt_a > 0.01 then                         -- the hilt, fading into his hand
                    draw_image(dl, hilt, lx, ly, lx + lw, ly + lw, nil, { tint[1], tint[2], tint[3], tint[4] * hilt_a });
                end
                if blade and body and out > 0.001 then
                    -- only the drawn part of the blade shows: from the guard to how far it has slid out
                    local gx, gy = lx + BLADE_AXIS[1] * lw, ly + BLADE_AXIS[2] * lw;
                    local hx = gx + (BLADE_AXIS[3] - BLADE_AXIS[1]) * lw * out;
                    local hy = gy + (BLADE_AXIS[4] - BLADE_AXIS[2]) * lw * out;
                    JOBS.clip(dl, { gx - 0.04 * lw, gy - 0.08 * lw }, { hx + 0.03 * lw, hy + 0.10 * lw }, true);
                    draw_image(dl, blade, lx, ly, lx + lw, ly + lw, nil, tint);
                    dl:PopClipRect();
                    if ye.blade < 1 and engaged then                  -- a glint running along the edge as it comes out
                        local gr = (2.5 + 2.5 * out) * bs;
                        dl:AddCircleFilled({ hx, hy }, gr * 2.2, u32({ 1, 1, 1, 0.18 }), 16);
                        dl:AddLine({ hx - gr * 2, hy }, { hx + gr * 2, hy }, u32({ 1, 1, 1, 0.9 }), 1.2 * bs);
                        dl:AddLine({ hx, hy - gr * 2 }, { hx, hy + gr * 2 }, u32({ 1, 1, 1, 0.9 }), 1.2 * bs);
                        dl:AddCircleFilled({ hx, hy }, gr * 0.6, u32({ 1, 1, 1, 1 }), 12);
                    end
                end
                if out > 0.97 or full then logo_blood(dl, lx, ly, lw); end   -- blood only off a drawn blade
            end
            ART.on = false;
            if cfg.mid_bars ~= false then JOBS.mid_bars(dl, ccx, ccy, (JOBS.ring_in or (ring_r - RT / 2 - 6 * bs)), icon_half, bs); end
            if not DBG.text and (cfg.theme or 'classic') ~= 'classic' then JOBS.overlay(dl, ccx, ccy, disc_r, bs, fs, cfg.theme); end
            -- the state name in a notch on the top of the circle, like the card
            if cfg.state then draw_state(dl, ccx, cy1, lsc, state_name(status), gcol, gcol2, disc_r * 1.4); end
            if cfg.mptimer then draw_mp_timer(dl, ccx, cy1 + card_h, lsc, gcol, gcol2, disc_r * 1.6); end
        else
            -- Card: soft shadow, dark face with a faint sheen at the top, the living border
            for i = 1, 6 do
                local o = i * bs;
                dl:AddRectFilled({ cx1 + o, cy1 + o * 1.5 }, { cx2 + o, cy2 + o * 1.5 }, u32({ 0, 0, 0, 0.10 }), R + o);
            end
            dl:AddRectFilled({ cx1, cy1 }, { cx2, cy2 }, u32(C.face), R);
            pcall(function()
                local t, b = u32({ 0.30, 0.38, 0.60, 0.10 }), u32({ 0.30, 0.38, 0.60, 0.0 });
                dl:AddRectFilledMultiColor({ cx1 + R * 0.6, cy1 + 1 }, { cx2 - R * 0.6, cy1 + card_h * 0.4 }, t, t, b, b);
            end);
            draw_border(dl, cx1, cy1, cx2, cy2, R, bs, gs, gcol, gcol2);
            if cfg.state then draw_state(dl, (cx1 + cx2) / 2, cy1, lsc, state_name(status), gcol, gcol2, card_w - R * 2); end
            if cfg.mptimer then draw_mp_timer(dl, (cx1 + cx2) / 2, cy2, lsc, gcol, gcol2, card_w - R * 2); end
            -- items, floating on the card in Equipmon's positions; the ripple spreads from the middle
            local mid_c, mid_r = (cols - 1) / 2, (rows - 1) / 2;
            for i, slot in ipairs(GRID) do
                local col, row = (i - 1) % cols, math.floor((i - 1) / cols);
                draw_slot(k, i, slot, cx1 + CP + col * (TILE + GAP), cy1 + CP + row * (TILE + GAP), TILE,
                    math.sqrt((col - mid_c) ^ 2 + (row - mid_r) ^ 2) * 0.08);
            end
        end

        dl:PopClipRect();
        imgui.SetCursorScreenPos({ ox, oy });
        imgui.Dummy({ win, win_h });


        -- keep it on screen whatever the resolution: the window has a wide see-through margin round the wheel, so
        -- it may hang off the edges, but the wheel itself (and a bit of room for TP / the set name) always stays
        -- inside the game window. This also brings it back if it was saved on a bigger screen.
        pcall(function()
            if DBG.clamp then return; end
            local io = imgui.GetIO();
            local dw, dh = io.DisplaySize.x, io.DisplaySize.y;
            if dw and dh and dw > 100 and dh > 100 then
                local px, py = imgui.GetWindowPos();
                local kx, ky = cx1 - px, cy1 - py;                  -- where the wheel starts inside the window
                local keep = math.floor(28 * bs);                   -- room kept for TP above / the set name below
                local nx = math.max(-kx, math.min(dw - kx - card_w, px));
                local ny = math.max(-ky + keep, math.min(dh - ky - card_h - keep, py));
                if math.abs(nx - px) > 0.5 or math.abs(ny - py) > 0.5 then imgui.SetWindowPos({ nx, ny }); end
            end
        end);

        -- remember where it was dragged to (saved once the mouse is let go)
        local wx, wy = imgui.GetWindowPos();
        if math.abs(wx - (tonumber(cfg.x) or 0)) > 0.5 or math.abs(wy - (tonumber(cfg.y) or 0)) > 0.5 then
            cfg.x, cfg.y = wx, wy;
            ye.pos_dirty = true;
        end
        if ye.pos_dirty and not imgui.IsMouseDown(0) then ye.pos_dirty = false; save(); end
    end
    imgui.End();
    if pushed then imgui.PopFont(); end
    imgui.PopStyleVar(3);
end

----------------------------------------------------------------------------------------------------
-- Settings panel, in YunaGearOpt's style: same fonts, colours, rounding, switches and steppers
----------------------------------------------------------------------------------------------------
local function push_theme()
    local cols = {
        { ImGuiCol_WindowBg, C.bg }, { ImGuiCol_ChildBg, { 0, 0, 0, 0 } }, { ImGuiCol_PopupBg, { 0.075, 0.079, 0.092, 0.99 } },
        { ImGuiCol_Border, C.border }, { ImGuiCol_Text, C.text }, { ImGuiCol_TextDisabled, C.muted },
        { ImGuiCol_FrameBg, C.frame }, { ImGuiCol_FrameBgHovered, C.frame_hi }, { ImGuiCol_FrameBgActive, C.frame_hi },
        { ImGuiCol_Button, { 1, 1, 1, 0.035 } }, { ImGuiCol_ButtonHovered, { 1, 1, 1, 0.08 } }, { ImGuiCol_ButtonActive, { 1, 1, 1, 0.12 } },
        { ImGuiCol_Separator, C.line },
    };
    for _, c in ipairs(cols) do imgui.PushStyleColor(c[1], c[2]); end
    local vars = {
        { ImGuiStyleVar_WindowRounding, 8 }, { ImGuiStyleVar_FrameRounding, 5 },
        { ImGuiStyleVar_WindowPadding, { 14, 12 } }, { ImGuiStyleVar_FramePadding, { 10, 5 } },
        { ImGuiStyleVar_ItemSpacing, { 8, 6 } }, { ImGuiStyleVar_WindowBorderSize, 1 }, { ImGuiStyleVar_FrameBorderSize, 1 },
    };
    for _, v in ipairs(vars) do imgui.PushStyleVar(v[1], v[2]); end
    return #cols, #vars;
end

-- YGO's switch: a pill that is periwinkle with the knob on the right when on. Returns true when clicked.
local function switch(id, on)
    local x, y = imgui.GetCursorScreenPos();
    local w, h = 38, 20;
    local clicked = imgui.InvisibleButton(id, { w, h });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32(on and { 0.24, 0.22, 0.30, 1 } or (hov and { 0.14, 0.13, 0.18, 1 } or { 0.10, 0.095, 0.13, 1 })), h / 2);
    local kx = on and (x + w - h / 2) or (x + h / 2);
    dl:AddCircleFilled({ kx, y + h / 2 }, h / 2 - 3, u32(on and { 1, 1, 1, 1 } or { 0.55, 0.53, 0.62, 1 }), 20);
    return clicked;
end

-- YGO's thin-line X button (red on hover)
local function close_button(id)
    local x, y = imgui.GetCursorScreenPos();
    local sz = 28;
    local clicked = imgui.InvisibleButton(id, { sz, sz });
    local hov, held = imgui.IsItemHovered(), imgui.IsItemActive();
    local dl = imgui.GetWindowDrawList();
    if hov then dl:AddRectFilled({ x, y }, { x + sz, y + sz }, u32({ 1.0, 0.35, 0.35, held and 0.28 or 0.16 }), 6); end
    local col = hov and { 1.0, 0.55, 0.55, 1 } or C.muted;
    local cx, cy, k = x + sz / 2, y + sz / 2, 5.5;
    dl:AddLine({ cx - k, cy - k }, { cx + k, cy + k }, u32(col), 1.6);
    dl:AddLine({ cx - k, cy + k }, { cx + k, cy - k }, u32(col), 1.6);
    return clicked;
end

-- The title as YGO draws it: YUNA in white, EQUIP letter by letter flowing between periwinkle and ice blue
local function title(dl)
    local pushed = push_font(fonts.title, 22);
    if not pushed then imgui.SetWindowFontScale(1.3); end
    local t = os.clock();
    local x0, y0 = imgui.GetCursorScreenPos();
    local full = 'YUNA EQUIP';
    local tw, lh = imgui.CalcTextSize(full);
    for i = 1, #full do
        local ch = full:sub(i, i);
        if ch ~= ' ' then
            local cx = x0 + imgui.CalcTextSize(full:sub(1, i - 1));
            local col = C.text;
            if i > 5 then
                local u = 0.5 + 0.5 * math.sin(t * 1.2 - i * 0.45);
                col = { C.gold[1] + (C.ice[1] - C.gold[1]) * u, C.gold[2] + (C.ice[2] - C.gold[2]) * u, 1.0, 1 };
            end
            dl:AddText({ cx, y0 }, u32(col), ch);
        end
    end
    imgui.Dummy({ tw, lh });
    if pushed then imgui.PopFont(); else imgui.SetWindowFontScale(1.0); end
end

-- A section name in the accent colour, like YGO's sidebar sections
local function section(text)
    if YUI_SECTION_HOOK then YUI_SECTION_HOOK(); end                -- (YunaUI's panel: may move on to its second column)
    imgui.Spacing();
    imgui.TextColored(C.gold, text);
end

-- One settings row: label on the left, the control right-aligned
local ROW_W = 280;
local function row_label(text, hint)
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, text);
    if hint and imgui.IsItemHovered() then (YUI_TIP or imgui.SetTooltip)(hint); end
end
local function row_switch(id, text, key, hint)
    local x0 = imgui.GetCursorPosX();
    row_label(text, hint);
    imgui.SameLine(x0 + ROW_W - 38);
    if switch(id, cfg[key]) then cfg[key] = not cfg[key]; save(); end
    if hint and imgui.IsItemHovered() then (YUI_TIP or imgui.SetTooltip)(hint); end
end
-- "< 100% >" like YGO's Window scale
local function row_stepper(id, text, key, step, lo, hi)
    local x0 = imgui.GetCursorPosX();
    row_label(text);
    local v = tonumber(cfg[key]) or 1;
    local bh = imgui.GetFrameHeight();
    local label = string.format('%d%%', math.floor(v * 100 + 0.5));
    local lw = imgui.CalcTextSize(label);
    local mid = math.max(50, lw + 16);                               -- room for the value between the arrows
    imgui.SameLine(x0 + ROW_W - bh * 2 - mid);
    if imgui.Button('<##' .. id, { bh, bh }) then cfg[key] = math.max(lo, math.floor((v - step) * 100 + 0.5) / 100); save(); end
    imgui.SameLine(x0 + ROW_W - bh - mid + (mid - lw) / 2);
    imgui.TextColored(C.text, esc(label));
    imgui.SameLine(x0 + ROW_W - bh);
    if imgui.Button('>##' .. id, { bh, bh }) then cfg[key] = math.min(hi, math.floor((v + step) * 100 + 0.5) / 100); save(); end
end

-- "< value >" for a list of choices; step(dir) moves to the previous (-1) or next (1) one
local function row_choice(id, text, value, step)
    local x0 = imgui.GetCursorPosX();
    row_label(text);
    local bh = imgui.GetFrameHeight();
    local mid = math.max(90, imgui.CalcTextSize(value) + 16);
    imgui.SameLine(x0 + ROW_W - bh * 2 - mid);
    if imgui.Button('<##' .. id, { bh, bh }) then step(-1); save(); end
    local vw = imgui.CalcTextSize(value);
    imgui.SameLine(x0 + ROW_W - bh - mid + (mid - vw) / 2);
    imgui.TextColored(C.text, esc(value));
    imgui.SameLine(x0 + ROW_W - bh);
    if imgui.Button('>##' .. id, { bh, bh }) then step(1); save(); end
end

-- An outlined accent button (YGO's EXPORT / LOCKSTYLE style)
local function accent_button(label, size)
    imgui.PushStyleColor(ImGuiCol_Button, { C.gold[1], C.gold[2], C.gold[3], 0.14 });
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { C.gold[1], C.gold[2], C.gold[3], 0.24 });
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { C.gold[1], C.gold[2], C.gold[3], 0.32 });
    imgui.PushStyleColor(ImGuiCol_Border, { C.gold[1], C.gold[2], C.gold[3], 0.55 });
    imgui.PushStyleColor(ImGuiCol_Text, { 0.70, 0.75, 1.0, 1 });
    local clicked = imgui.Button(label, size);
    imgui.PopStyleColor(5);
    return clicked;
end

-- The settings, drawn into YunaUI's EQUIP tab (YunaUI's window, look and font are already in place)
local function draw_settings()
    ROW_W = YUI_ROW_W or 280;                                       -- (YunaUI's panel size)
    do
        local dl = imgui.GetWindowDrawList();
        local x0 = imgui.GetCursorPosX();

        -- (the wheel and its options are gone: your gear is YunaUI's strip now)
    end
end
-- Your HP / MP / TP: drawn into YunaUI's BARS tab, under YOUR BARS
local function draw_bars_settings()
    ROW_W = YUI_ROW_W or 280;
    do
        cfg.stat_mode = 'bars';                                      -- (your HP / MP / TP are always separate bars now)
        do
            if cfg.sb_mp_thick == nil then cfg.sb_mp_thick = tonumber(cfg.sb_thick) or 1; end   -- (the MP bar starts as thick as the HP bar)
            row_stepper('ye_sbth', 'HP bar thickness', 'sb_thick', 0.25, 0.5, 3.0);
            row_stepper('ye_sbhs', 'HP bar size', 'sb_hp_size', 0.1, 0.5, 2.5);
            row_stepper('ye_sbhl', 'HP bar length', 'sb_hp_len', 0.1, 0.3, 4.0);
            row_switch('##ye_sbmp', 'MP bar', 'sb_mp', 'On: your MP bar shows. Off: it is hidden (an anchored TP bar moves up under HP).');
            if cfg.sb_mp ~= false then
                row_stepper('ye_sbmth', 'MP bar thickness', 'sb_mp_thick', 0.25, 0.5, 3.0);
                row_stepper('ye_sbms', 'MP bar size', 'sb_mp_size', 0.1, 0.5, 2.5);
                row_stepper('ye_sbml', 'MP bar length', 'sb_mp_len', 0.1, 0.3, 4.0);
            end
            row_switch('##ye_sbtp', 'TP bar', 'sb_tp', 'On: TP gets a bar of its own too.');
            if cfg.sb_tp ~= false then
                row_stepper('ye_sbts', 'TP bar size', 'sb_tp_size', 0.1, 0.5, 2.5);
                row_stepper('ye_sbtl', 'TP bar length', 'sb_tp_len', 0.1, 0.3, 4.0);
            end
        end
        row_switch('##ye_lowfx', 'Low HP / MP glow', 'low_on', 'On: under 50% HP or MP, that bar breathes.');
    end
end
YUI_EQ_BARS = function()
    local ok, e = pcall(draw_bars_settings);
    if not ok then imgui.TextColored({ 1, 0.5, 0.6, 1 }, 'Error: ' .. tostring(e)); end
end
local function draw_settings_end()
    do
    end
end
YUI_EQ_SETTINGS = function()
    local ok, e = pcall(function() draw_settings(); draw_settings_end(); end);
    if not ok then imgui.TextColored({ 1, 0.5, 0.6, 1 }, 'Error: ' .. tostring(e)); end
    return ok, e;
end
-- Settings copied in from another character (YunaUI sees the file change): take them at once, move everything
YUI_EQ_GET = function() return cfg; end
YUI_EQ_SETFONTS = function(f)                                        -- (plain Ashita: YunaUI's few fonts, shared; see YUI_OLDIMGUI)
    fonts.yui = (f.sized and f.sized.chat) or {};
    fonts.main, fonts.semi, fonts.serif = f.main, f.main, f.main;
    fonts.title = f.title or f.main;
    fonts.set[cfg.set_font or 'bahn'] = fonts.title;
end
YUI_EQ_RECT = function()                                             -- where your HP / MP / TP bars are, all together (YunaUI's guide)
    local x0, y0, x1, y1;
    for key, sz in pairs(JOBS.sb_size or {}) do
        local x, y = tonumber(cfg[key .. 'bar_x']), tonumber(cfg[key .. 'bar_y']);
        if x and y and x >= 0 and (key == 'hp' or cfg['sb_' .. key] ~= false) then
            x0, y0 = math.min(x0 or x, x), math.min(y0 or y, y);
            x1, y1 = math.max(x1 or (x + sz[1]), x + sz[1]), math.max(y1 or (y + sz[2]), y + sz[2]);
        end
    end
    if x0 then return { x0, y0, x1 - x0, y1 - y0 }; end
    return nil;
end                          -- (YunaUI's GENERAL > LAYOUT reads the bars' places)
YUI_EQ_APPLY = function(t)
    for k, v in pairs(t) do cfg[k] = v; end
    ui.place = true;
    JOBS.sb_move = 3;
    pcall(save);                                                     -- (kept: a layout loaded from YunaUI)
end

----------------------------------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------------------------------
ashita.events.register('load', 'ye_load', function()
    load_fonts();
    cfg.stat_mode = 'bars';                                          -- (HP / MP / TP: separate bars only)
    if cfg.ring_fx == 'electric' then cfg.ring_fx = 'same'; end      -- (the Electric bar effect is gone)
    if cfg.sb_fx == 'electric' then cfg.sb_fx = 'same'; end
    ye.sig = '';
end);

-- (no save on unload: every change is saved when it's made, and a save here could write over settings another
-- character just copied in)
ashita.events.register('unload', 'ye_unload', function() end);

ashita.events.register('d3d_present', 'ye_present', function()
    local ok, err = pcall(function()
        if not AshitaCore:GetFontManager():GetVisible() then return; end
        local status = player_status();
        if status == nil then return; end                           -- zoning / not logged in
        if not cfg.imported then JOBS.import(); end
        -- (the old gear wheel is gone: YunaUI's strip shows your gear. It never draws, not even for the frame or two
        -- while the game closes, when YunaUI's settings fall back to their defaults)
        JOBS.statbars();
    end);
    if not ok then pcall(YUI_ERRLOG, 'equip draw', err); end
    if not ok and ye.last_err ~= tostring(err) then
        ye.last_err = tostring(err);
        msg('Draw error: ' .. ye.last_err);
    end
end);

-- Your own action packets: start / interrupt / finish casting (violet border), weapon skills (gold flare)
local function on_action(data)
    local ok, me = pcall(function() return AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0); end);
    if not ok or me == nil or #data < 0x10 then return; end
    if struct.unpack('I', data, 0x05 + 1) ~= me then return; end
    local v = struct.unpack('I', data, 0x0A + 1);
    local cat, param = bit.band(bit.rshift(v, 2), 0x0F), bit.band(bit.rshift(v, 6), 0xFFFF);
    if cat == 8 then
        ye.cast_until = (param == 28787) and 0 or (os.clock() + 12);   -- 28787 = interrupted
    elseif cat == 4 then
        ye.cast_until = 0;
    elseif cat == 3 then
        ye.ws_t = os.clock();
        ye.ws_label_until = os.clock() + 1.6;
    end
end

-- Outgoing 0x1A: category 3 = casting a spell (param = spell id), 7 = weapon skill
ashita.events.register('packet_out', 'ye_packet_out', function(e)
    if e.id ~= 0x001A then return; end
    pcall(function()
        local cat = struct.unpack('H', e.data, 0x0A + 1);
        local param = struct.unpack('H', e.data, 0x0C + 1);
        if cat == 3 then ye.spell, ye.spell_t = param, os.clock();
        elseif cat == 7 then ye.ws_t = os.clock(); end
    end);
end);

ashita.events.register('packet_in', 'ye_packet_in', function(e)
    if e.id == 0x0028 then
        pcall(on_action, e.data);
    elseif e.id == 0x001B then
        ye.encumber = struct.unpack('L', e.data_modified, 0x60 + 1);
    elseif e.id == 0x0050 or e.id == 0x0116 or e.id == 0x0117 or e.id == 0x001D or e.id == 0x001F then
        ye.next_scan = 0;
    end
end);

local function help()
    msg('/yequip  - show / hide YunaEquip   (/ye works too)');
    msg('/yequip config  - the settings panel (or right-click it)');
    msg('/yequip style [orbit | card]  - the wheel round your job, or the classic grid');
    msg('/yequip theme [sumi | neon]  - the look of the wheel');
    msg('/yequip pulse  - the HP / MP ring animation on / off');
    msg('/yequip statsize <0.6-2>  - HP / MP / TP text size');
    msg('/yequip setname  - the gear set name under the wheel on / off');
    msg('/yequip blm  - Black Mage picture: wizard or warlock');
    msg('/yequip art <10-100>  - how see-through the artwork in the middle is');
    msg('/yequip middle [art | icon]  - the middle: artwork or job icon');
    msg('/yequip test  - play the Shadow swap effect on every slot');
    msg('/yequip lock | unlock  - stop or allow dragging');
    msg('/yequip mini  - mini mode on / off (16 px icons)');
    msg('/yequip icons <16-48>  - icon size in px');
    msg('/yequip layout [4x4 | 8x2 | 2x8 | 16x1 | 1x16]  - card style: how the slots are arranged');
    msg('/yequip reset  - everything back to default');
end

ashita.events.register('command', 'ye_command', function(e)
    local args = e.command:args();
    if #args == 0 or not (args[1]:lower() == '/yequip' or args[1]:lower() == '/ye') then return; end
    e.blocked = true;
    local sub = (args[2] or ''):lower();
    if sub == '' or sub == 'toggle' then cfg.visible = not cfg.visible;
    elseif sub == 'show' then cfg.visible = true;
    elseif sub == 'hide' then cfg.visible = false;
    elseif sub == 'config' or sub == 'settings' or sub == 'menu' then YUI_OPEN_EQUIP = true; return;
    elseif sub == 'test' then play_test(); return;
    elseif sub == 'ripple' then ye.ripple_t = os.clock(); return;
    elseif sub == 'style' then
        local want = (args[3] or ''):lower();
        cfg.style = (want == 'card' or want == 'orbit') and want or ((cfg.style == 'orbit') and 'card' or 'orbit');
        msg('Style: ' .. cfg.style .. '   (card, orbit)');
    elseif sub == 'bottom' or sub == 'setname' then
        local o = { set = 'off', off = 'set' };
        local want = (args[3] or ''):lower();
        cfg.bottom = (o[want] ~= nil) and want or (o[cfg.bottom] or 'job');
        JOBS.sets_t = 0;
        msg('Under the wheel: ' .. cfg.bottom .. '   (set, off)');
    elseif sub == 'art' and tonumber(args[3]) then
        local v = tonumber(args[3]); if v > 1 then v = v / 100; end
        cfg.art_alpha = math.max(0.1, math.min(1, v));
        msg('Artwork opacity: ' .. math.floor(cfg.art_alpha * 100 + 0.5) .. '%');
    elseif sub == 'middle' or sub == 'centre' or sub == 'center' then
        local o = { art = 'icon', icon = 'art' };
        local want = (args[3] or ''):lower();
        cfg.middle = (o[want] ~= nil) and want or (o[cfg.middle] or 'icon');
        msg('Middle: ' .. cfg.middle .. '   (art, icon)');
    elseif sub == 'debug' then
        local part = (args[3] or ''):lower();
        if DBG[part] ~= nil then
            DBG[part] = not DBG[part];
            msg('Debug: ' .. part .. ' ' .. (DBG[part] and 'HIDDEN' or 'shown') .. '   (ring, slots, icon, text, clamp)');
        else
            local t = {};
            for k2, v in pairs(DBG) do t[#t + 1] = k2 .. '=' .. (v and 'hidden' or 'shown'); end
            msg('Debug parts: ' .. table.concat(t, ', ') .. '   - /ye debug <part> hides / shows one');
        end
    elseif sub == 'ring' then
        cfg.show_ring = not (cfg.show_ring ~= false);
        msg('HP / MP ring ' .. (cfg.show_ring and 'on.' or 'off.'));
    elseif sub == 'still' then
        cfg.mid_anim = (cfg.mid_anim == false);
        msg('Middle animation ' .. (cfg.mid_anim and 'on.' or 'off.'));
    elseif sub == 'low' then
        cfg.low_on = (cfg.low_on == false);
        msg('Low HP / MP glow ' .. (cfg.low_on and 'on.' or 'off.'));
    elseif sub == 'big' then
        cfg.big_logo = not cfg.big_logo;
        msg('Big logo ' .. (cfg.big_logo and 'on.' or 'off.'));
    elseif sub == 'pulse' then
        cfg.bezel_fx = not cfg.bezel_fx;
        msg('Bezel animation ' .. (cfg.bezel_fx and 'on.' or 'off.'));
    elseif sub == 'statsize' and tonumber(args[3]) then
        cfg.stat_size = math.max(0.6, math.min(2.0, tonumber(args[3])));
        msg('HP / MP text size: ' .. math.floor(cfg.stat_size * 100 + 0.5) .. '%   (60 - 200)');
    elseif sub == 'theme' then
        local o = { sumi = 'neon', neon = 'sumi' };
        local want = (args[3] or ''):lower();
        cfg.theme = (o[want] ~= nil) and want or (o[cfg.theme] or 'sumi');
        msg('Theme: ' .. cfg.theme .. '   (sumi, neon)');
    elseif sub == 'bg' then
        local o = { ink = 'glass', glass = 'job', job = 'none', none = 'solid', solid = 'ink' };
        cfg.bg = (args[3] and o[args[3]] ~= nil) and args[3] or (o[cfg.bg] or 'ink');
        msg('Background: ' .. cfg.bg .. '   (ink, glass, job, none, solid)');
    elseif sub == 'blm' then
        cfg.blm_art = (cfg.blm_art == 'wak') and 'blm' or 'wak';
        msg('Black Mage picture: ' .. (cfg.blm_art == 'wak' and 'Warlock.' or 'Wizard.'));
    elseif sub == 'mini' then cfg.mini = not cfg.mini; msg('Mini mode ' .. (cfg.mini and 'on.' or 'off.'));
    elseif (sub == 'icon' or sub == 'icons' or sub == 'size') and tonumber(args[3]) then
        cfg.icon, cfg.mini = math.max(16, math.min(48, math.floor(tonumber(args[3])))), false;
    elseif sub == 'layout' then
        local want = (args[3] or ''):lower();
        local ok = false;
        for _, l in ipairs(LAYOUTS) do if l[1] == want then cfg.layout, ok = l[1], true; end end
        if not ok then cfg.layout = step_list(LAYOUTS, cfg.layout, 1, 1); end
        msg('Layout: ' .. cfg.layout .. '   (4x4, 8x2, 2x8, 16x1, 1x16)');
    elseif sub == 'set' and args[3] and args[4] then
        -- /ye set <setting> <value>: how YunaUI's EQUIP tab changes YunaEquip (quietly)
        local key, raw = args[3], args[4];
        if not JOBS.SETTABLE[key] then return; end
        local v = raw;
        if raw == 'true' then v = true; elseif raw == 'false' then v = false; elseif tonumber(raw) then v = tonumber(raw); end
        cfg[key] = v;
        ui.place = true;
    elseif sub == 'lock' then cfg.locked = true; msg('Locked.');
    elseif sub == 'unlock' then cfg.locked = false; msg('Unlocked: drag the card to move it.');
    elseif sub == 'reset' then settings.reset('equip'); ui.place = true; msg('Reset to default.');
    elseif sub == 'rescan' then ye.sig = ''; ye.next_scan = 0; return;
    else help(); return; end
    save();
end);
