-- YunaUI - Copyright (C) 2026 Yunas - https://github.com/YunasXI/yunaui
-- GPL-3.0 with an attribution term: keep this credit (see NOTICE and LICENSE).
addon.name    = 'yunaui';
addon.author  = 'Yunas';
addon.version = '1.0.67';
addon.desc    = 'YunaUI: target bar, party and alliance lists, chat, your bars, gear strip, pet bar, cooldowns and a damage meter, in one style.';
addon.link    = '';

-- YunaUI is a VanaCore addon: VanaCore\addons\vanacore\yunaui. Loaded any other way (as an Ashita addon, where `vana`
-- isn't there) it says so and does nothing else. Its code uses Ashita's addon API names: native.lua sets them up first,
-- from VanaCore's own Ashita layer.
if rawget(_G, 'vana') == nil then
    print('YunaUI is a VanaCore addon now: it goes in VanaCore\\addons\\vanacore\\yunaui (then /addon load yunaui).');
    return;
end
if rawget(_G, 'AshitaCore') == nil then
    local src = (debug.getinfo(1, 'S').source or ''):gsub('^@', '');
    local dir = src:match('^(.*)[\\/][^\\/]+$') or (vana.paths.addons .. '\\vanacore\\yunaui');
    assert(loadfile(dir .. '\\native.lua'))(dir);
end

require('common');
local imgui    = require('imgui');
local settings = require('settings');
local chat     = require('chat');
local ffi      = require('ffi');
local d3d      = require('d3d8');

-- Is this font able to be pushed at any size (VanaCore's ImGui)? Asked once per font, safely.
YUI_FONTNEW = YUI_FONTNEW or setmetatable({}, { __mode = 'k' });
YUI_NEWFONT = function(f)
    if f == nil then return false; end
    local v = YUI_FONTNEW[f];
    if v == nil then
        local ok, ls = pcall(function() return f.LegacySize; end);
        v = (ok and ls ~= nil) and true or false;
        pcall(function() YUI_FONTNEW[f] = v; end);
    end
    return v;
end

----------------------------------------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------------------------------------
local defaults = T{
    logo_x = 700, logo_y = 600, logo_size = 72, fan_right = false, fan_room = false,
    win_x = 240, win_y = 160,
    target = true, target_x = 560, target_y = 60, target_w = 520,
    party = true, party_x = 1600, party_y = 450, buffs_left = false,
    alliance = true, alliance_x = 40, alliance_y = 250, ally2_x = 330, ally2_y = 250, ally1_scale = 0.75, ally2_scale = 0.75, party_cols = 1, ally1_cols = 1, ally2_cols = 1, party_gap = 0,
    barfx = 'none', barfx_target = 'same', barfx_party = 'same', barfx_alliance = 'same', barfx_equip = 'same', barfx_pet = 'same', barfx_alpha = 1.0, barfx_size = 0.6,
    strip_under = 'mp', strip_fx = 'muzzle', strip_fit = true, strip_cols = 8, strip_icon = 26, strip_dim = 0.35, strip_swap_only = false, strip_x = -1, strip_y = -1,
    equip_look = 'strip', doll_x = -1, doll_y = -1, doll_scale = 1.0, doll_slot = 34, doll_alpha = 0.85, ring_radius = 175, center_size = 1.3, portal_strength = 1.0,
    buffs = true, job_icons = 'hats', icon_scale = 1.0, arrow_scale = 1.0, target_mark = 'flare', flare_try = false, glow_style = 4, glow_anim = 'still', inferno_try = false, glow_bright = 1.3, glow_len = 1.0, buff_set = 'XIView_Elemental', crisp_try = false, tets_pick = false, pixel_try = false, remaster_try = false, elem_try = false, hat_anim = 'float', bar_fx = 'still',
    subtarget = true, sub_x = 560, sub_y = 140, sub_w = 300, sub_scale = 1.0,
    enemylist = true, enemy_x = 1500, enemy_y = 200, enemy_w = 200, enemy_scale = 1.0, enemy_max = 8,
    castbar = true, cast_x = -1, cast_y = -1, cast_w = 300, cast_h = 5, cast_scale = 1.0, cast_fx = 'same',
    gil = true, gil_x = -1, gil_y = -1, bag = true, bag_x = -1, bag_y = -1, gb_scale = 1.0, bag_style = 'row',
    petbar = true, pet_x = -1, pet_y = -1, pet_scale = 1.0, pet_w = 260, pet_recasts = true, pet_target = true, pet_anim = true, pet_fx = 'fade',
    timers = true, timer_x = -1, timer_y = -1, timers_scale = 1.0, timers_w = 260, timers_h = 4, timers_max = 10, timers_abils = true,
    timers_spells = true, timers_flash = true, timers_up = false, timers_fmt = 'short', timers_fx = 'same',
    expbar = true, exp_x = -1, exp_y = -1, exp_w = 520, exp_scale = 1.0,
    chat = true, chat_x = 20, chat_y = 720, chat_w = 620, chat_h = 260, chat_size = 16,
    chat_split = false, chat2_x = 660, chat2_y = 720, chat2_w = 520, chat2_h = 260,
    chat_fade = true, spine_edge_anim = 'shine', card_shape = 'blade', card_theme = 'pearl', card_fx = 'sheen', card_low = true, mb_scale = 1.0, tag_look = 'role', target_buff_scale = 1.0, target_name_scale = 1.0, ecast_font = 1.0, target_look = 'dd2', spine_line = true, ecast_scale = 0.75, spine_trace = true, card_style = 'clean', bracket_look = 'glass', card_h = 1.0, fan_scale = 1.0, hp_outline = true, target_hp_color = 'pink', party_look = 'spine', spine_edge = 'thin', spine_edge_col = 'black', ally1_icon = 1.0, ally2_icon = 1.0, ally_anchor = false, ally_select_fx = 'chroma', ally_style = 'full', ally_smart_hp = 75, strip_show = true, hp_color = 'pink', fight_info = true, fan_layout = 'fan', fan_shape = 'blade', fan_accent = 'slash', fan_tint = 'dark', target_bar_h = 4, fan_place = 'bar', ecast_place = 'bar', fan_x = -1, fan_y = -1, ecast_x = -1, ecast_y = -1, buffs_off = {}, party_bar_h = 3, party_vgap = 0, chat_save = false, chat_gap = 6, chat_outline = 'outline', chat_ground = true, chat_ground_a = 0.5, chat_linebg = true, party_dim_far = true, party_range = 20.8, party_dist = true, party_buff_side = 'left', exp_text = 1.0, target_fx = 'blade', minimap = true, map_size = 220, map_zoom = 60, map_mobs = true, bigmap_size = 640, map_color = 'white', map_title = 'fade', map3d_size = 560, map_style = '2d', map3d_follow = true, map_ground = 'none', map_replace = false, map_arrow_color = 'lines', chat_time_dim = true, chat_hold = 12, chat_bright = 1.0, chat_tab = 1, chat_anim = true, chat_feed = true, chat_bubbles = true, chat_fade_old = true, chat_f_others = true, chat_f_debuff = true, chat_f_wear = true, cf_w_me = true, cf_w_party = true, cf_w_alliance = true, cf_w_trust = true, cf_w_monster = true, cf_w_npc = true, cf_t_melee = true, cf_t_ranged = true, cf_t_magic = true, cf_t_uses = true, cf_t_healing = true, cf_t_defence = true, cf_t_effects = true, cf_t_items = true, cf_cols = false, party_zone = true, loot_win = true, loot_scale = 1.0, loot_coin_scale = 1.0, chat_time_sec = false, chat_time_12 = false, chat_time_case = 'lower', target_bar_anim = true, map_hub = false, chat_look = 'clear', head_bars = 'fixed', head_bars_scale = 1.0, head_bars_y = 0, head_nums = 'always', hl_path = 'elbow', hl_line = 'neon', hl_lcol = 'match', hl_lw = 0.6, hl_rest = 'hide', hl_pulse = false, hl_head = 'none', hl_icon = 'diamond', hl_isz = 0.65, hl_mcol = 'gold', hl_fcol = 'mint', hl_ianim = 'pulse', hl_fan = 0.8, show_fan = true, show_mb = true, hl_pct = 1.0, hl_cast = 0.8, hl_tot = 0.8, hl_hidename = true, hl_claim = true, map_tilt = true, party_buff_ffxi = true, party_tag_col = 'job', party_hp_th = 1.0, party_mp_th = 1.0, target_buff_tips = true, buff_timer_scale = 1.0, tp_sound = true, tp_sound_vol = 0.6, chat_panel_a = 0.72, chat_msg_gap = 5,  map_dock = true, enemy_buff_scale = 1.0, enemy_buff_text = 1.0, chat_tab_reset = true, chat_rounds = true, hex_party = true, setup_done = false,
    hide_game_chat = true, chat_time = false, hide_game_input = false, chat_typing = true, min_anim = 'fly', dps_backdrop = 0.55, dps_title_b = 1.0, dps_detail_b = 1.0,
    target_scale = 1.0, party_scale = 1.0, alliance_scale = 1.0, buff_scale = 1.0,
    locked = false, panel_scale = 1.0, panel_alpha = 0.95, mini_x = -1, mini_y = -1,
    scale = 1.0,
};
local cfg = settings.load(defaults);
settings.register('settings', 'yui_settings', function(s) if s ~= nil then cfg = s; end end);
-- Settings shared between characters: when another character copies its settings into ours (the COPY button), our
-- settings file changes under us; every 2 s we look, and if it did, we take the new settings at once (windows move
-- too). WATCH.own / WATCH.eq hold what the files said the last time we looked or saved.
local WATCH = { at = 0, own = nil, eq = nil, move = 0 };
-- Edit Mode (GENERAL > LAYOUT > EDIT MODE, or /yui edit): every piece shows (with a pretend one where needed), a grid and
-- the screen's middle lines appear, and a piece you drag shows pink-to-violet guides when it lines up with another one
-- or the middle; let go and it snaps there (or to the grid)
local EDIT = { on = false, guides = {}, drag = nil };
local function own_file(name)
    local ok, data = pcall(function()
        local p = AshitaCore:GetMemoryManager():GetParty();
        local path = AshitaCore:GetInstallPath():gsub('[\\/]+$', '') .. string.format('\\config\\addons\\yunaui\\%s_%d\\%s',
            p:GetMemberName(0) or '', p:GetMemberServerId(0) or 0, name);
        local f = io.open(path, 'rb');
        if f == nil then return nil; end
        local d = f:read('*a'); f:close();
        return d;
    end);
    return ok and data or nil;
end
local function save()
    settings.save();
    WATCH.own = own_file('settings.lua');                          -- our own change: not "from outside"
end
local function msg(t) print(chat.header(addon.name):append(chat.message(t))); end
-- Errors also go to a file (yunaui-errors.txt in the addon's folder): with the game's chat hidden they can't always
-- be seen in game
YUI_ERRSEEN = {};
YUI_ERRLOG = function(where, err)
    local e = tostring(err);
    if YUI_ERRSEEN[e] then return; end
    YUI_ERRSEEN[e] = true;
    pcall(function()
        local f = io.open((addon.path:gsub('[\\/]+$', '')) .. '\\yunaui-errors.txt', 'a');
        if f then f:write(os.date('%Y-%m-%d %H:%M:%S') .. '  [' .. where .. ']  ' .. e .. '\n'); f:close(); end
    end);
end

-- YunaEquip, now part of YunaUI: its code is equip.lua, its pictures and fonts are in the equip folder. It reads
-- YunaUI's bar effect through YUI_BAR_FX, and asks for its settings tab with YUI_OPEN_EQUIP.
YUI_EQ_PATH = (addon.path:gsub('[\\/]+$', '')) .. '\\equip';
YUI_BAR_FX = function() return cfg.bar_fx or 'flow'; end
do
    local ok, err = pcall(require, 'equip');
    if not ok then print('[yunaui] YunaEquip part failed to load: ' .. tostring(err)); YUI_ERRLOG('load equip', err); end
end
-- The Damage Meter (it was the separate YunaDPS addon): dps.lua, settings in its own dps.lua, the DAMAGE METER tab
do
    local ok, err = pcall(require, 'dps');
    if not ok then print('[yunaui] Damage Meter part failed to load: ' .. tostring(err)); YUI_ERRLOG('load dps', err); end
end

----------------------------------------------------------------------------------------------------
-- Look: YunaGearOpt's palette, fonts and controls
----------------------------------------------------------------------------------------------------
local C = {
    bg       = { 0.086, 0.098, 0.145, 1.00 },
    frame    = { 0.176, 0.196, 0.271, 1.00 },
    frame_hi = { 0.220, 0.243, 0.333, 1.00 },
    border   = { 0.560, 0.620, 1.000, 0.12 },
    line     = { 0.700, 0.750, 1.000, 0.08 },
    gold     = { 0.490, 0.557, 1.000, 1.00 },   -- YGO's periwinkle accent
    ice      = { 0.550, 0.880, 1.000, 1.00 },
    text     = { 0.910, 0.922, 0.957, 1.00 },
    muted    = { 0.545, 0.576, 0.667, 1.00 },
    rall     = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15,   -- round all corners (0 = none in this ImGui)
    rleft    = ImDrawFlags_RoundCornersLeft or ImDrawCornerFlags_Left or 5,   -- round the left corners only
    acc      = { 0.74, 0.66, 0.95, 1.00 },      -- the settings panel's accent: a soft lavender
    pbg      = { 0.068, 0.066, 0.088 },          -- the panel: near-black with a hint of violet
    pframe   = { 0.165, 0.158, 0.205 },
    ps       = 1, wfs = 1,                       -- panel size, and the window font scale it runs at
    hp       = { 1.000, 0.36, 0.62 },            -- the HP bars: pink to magenta
    hp2      = { 0.86, 0.24, 0.86 },
    hpb1     = { 1.000, 0.36, 0.62 },            -- your / party / alliance HP bars (BARS > HP bar colour: Pink or Red)
    hpb2     = { 0.86, 0.24, 0.86 },
    mp       = { 0.40, 0.55, 1.00 },             -- the MP bars: blue to violet
    mp2      = { 0.62, 0.40, 1.00 },
};
local function u32(c) return imgui.GetColorU32(c); end
-- Frame cost (VanaCore's findings): no Lua table made per draw call. U4(r, g, b, a) is u32({ r, g, b, a }) through one
-- scratch table; DL.L(dl, x, y, x2, y2, ...) is dl:AddLine({ x, y }, { x2, y2 }, ...) through scratch points (the binding
-- reads them during the call and keeps nothing). The arguments are all worked out before a call fills its scratch.
local U4, DL;
do
    local c4, P1, P2, P3, P4 = { 0, 0, 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 }, { 0, 0 };
    U4 = function(r, g, b, a) c4[1], c4[2], c4[3], c4[4] = r, g, b, a; return imgui.GetColorU32(c4); end
    DL = {};
    function DL.L(d, a, b, c, e, ...) P1[1], P1[2], P2[1], P2[2] = a, b, c, e; return d:AddLine(P1, P2, ...); end
    function DL.R(d, a, b, c, e, ...) P1[1], P1[2], P2[1], P2[2] = a, b, c, e; return d:AddRect(P1, P2, ...); end
    function DL.RF(d, a, b, c, e, ...) P1[1], P1[2], P2[1], P2[2] = a, b, c, e; return d:AddRectFilled(P1, P2, ...); end
    function DL.RFM(d, a, b, c, e, ...) P1[1], P1[2], P2[1], P2[2] = a, b, c, e; return d:AddRectFilledMultiColor(P1, P2, ...); end
    function DL.C(d, a, b, ...) P1[1], P1[2] = a, b; return d:AddCircle(P1, ...); end
    function DL.CF(d, a, b, ...) P1[1], P1[2] = a, b; return d:AddCircleFilled(P1, ...); end
    function DL.T(d, a, b, ...) P1[1], P1[2] = a, b; return d:AddText(P1, ...); end
    function DL.TF(d, a, b, c, e, f, g, ...) P1[1], P1[2], P2[1], P2[2], P3[1], P3[2] = a, b, c, e, f, g; return d:AddTriangleFilled(P1, P2, P3, ...); end
    function DL.I(d, t, a, b, c, e, f, g, h, k, ...) P1[1], P1[2], P2[1], P2[2], P3[1], P3[2], P4[1], P4[2] = a, b, c, e, f, g, h, k; return d:AddImage(t, P1, P2, P3, P4, ...); end
    function DL.I2(d, t, a, b, c, e, ...) P1[1], P1[2], P2[1], P2[2] = a, b, c, e; return d:AddImage(t, P1, P2, ...); end
end
-- Every clip area goes through here: inside the screen, on whole pixels and at least 1 px. Plain Ashita (DirectX 8)
-- can't draw with one bigger than the screen (every window after it vanishes, the settings too), and one partly off the
-- screen, on half pixels or with no size makes every addon's window shake (as equip.lua's JOBS.clip already knew).
function C.screen()
    local ds = imgui.GetIO().DisplaySize;
    return math.floor((ds and tonumber(ds.x)) or 1920), math.floor((ds and tonumber(ds.y)) or 1080);
end
function C.cliprect(a, b)
    local w, h = C.screen();
    local x1 = math.floor(math.max(0, math.min(w - 1, a[1])));
    local y1 = math.floor(math.max(0, math.min(h - 1, a[2])));
    local x2 = math.ceil(math.max(x1 + 1, math.min(w, b[1])));
    local y2 = math.ceil(math.max(y1 + 1, math.min(h, b[2])));
    return { x1, y1 }, { x2, y2 };
end
function C.clip(dl, a, b, inter) local p1, p2 = C.cliprect(a, b); dl:PushClipRect(p1, p2, inter); end
function C.iclip(a, b, inter) local p1, p2 = C.cliprect(a, b); imgui.PushClipRect(p1, p2, inter); end
function C.fullclip(dl)                                              -- (drawing outside a window's own box: the whole screen)
    local w, h = C.screen();
    dl:PushClipRect({ 0, 0 }, { w, h }, false);
end

-- Tooltips in YunaUI's style (used by the whole UI, the Damage Meter and the bars too): a dark violet card with
-- rounded corners, a thin violet edge, a pink-to-violet line along the top; the first line white, the rest softer.
function YUI_TIP(t)
    t = tostring(t or '');
    if not (imgui.BeginTooltip and imgui.EndTooltip) then imgui.SetTooltip(t); return; end
    local hx = YUI_HEX and C.GOLDH ~= nil;                           -- (Hex link mode: square corners, a gold edge, the line gold to azure)
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, hx and 0 or 6);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 7, 3 });       -- (snug: just a little bigger than the text)
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1);
    imgui.PushStyleColor(ImGuiCol_PopupBg, hx and { 0.030, 0.035, 0.055, 0.95 } or { 0.045, 0.040, 0.065, 0.96 });
    imgui.PushStyleColor(ImGuiCol_Border, hx and { C.GOLDH[1], C.GOLDH[2], C.GOLDH[3], 0.55 } or { 0.62, 0.40, 1.00, 0.55 });
    imgui.PushStyleColor(ImGuiCol_Text, hx and { 1.0, 0.97, 0.90, 1 } or { 0.93, 0.92, 0.98, 1 });
    if imgui.BeginTooltip() ~= false then
        imgui.SetWindowFontScale(0.88);
        local first = true;
        for line in (t .. '\n'):gmatch('([^\n]*)\n') do
            if first then imgui.Text(line); else imgui.TextColored(hx and { 0.78, 0.74, 0.66, 1 } or { 0.70, 0.68, 0.80, 1 }, line); end
            first = false;
        end
        pcall(function()                                             -- the line along the top, like the HP bar
            local dl = imgui.GetWindowDrawList();
            local wx, wy = imgui.GetWindowPos();
            local ww = imgui.GetWindowSize();
            if type(wx) == 'table' then wx, wy = wx.x or wx[1], wx.y or wx[2]; end
            if type(ww) == 'table' then ww = ww.x or ww[1]; end
            local p1, p2 = imgui.GetColorU32({ 1.0, 0.36, 0.62, 0.9 }), imgui.GetColorU32({ 0.62, 0.40, 1.0, 0.9 });
            if hx then
                p1, p2 = imgui.GetColorU32({ C.GOLDH[1], C.GOLDH[2], C.GOLDH[3], 0.95 }), imgui.GetColorU32({ C.HEXMP[1][1], C.HEXMP[1][2], C.HEXMP[1][3], 0.95 });
                DL.RFM(dl, wx + 1, wy + 1, wx + ww - 1, wy + 2, p1, p2, p2, p1);
                local gc = imgui.GetColorU32({ C.GOLDH2[1], C.GOLDH2[2], C.GOLDH2[3], 1 });
                if C.hexdot then C.hexdot(dl, wx, wy, 3, gc); C.hexdot(dl, wx + ww, wy, 2.4, imgui.GetColorU32({ C.HEXMP[1][1], C.HEXMP[1][2], C.HEXMP[1][3], 1 })); end
            else
                DL.RFM(dl, wx + 6, wy + 1, wx + ww - 6, wy + 2, p1, p2, p2, p1);
            end
        end);
        imgui.SetWindowFontScale(1);
        imgui.EndTooltip();
    end
    imgui.PopStyleColor(3);
    imgui.PopStyleVar(3);
end
local function esc(t) return (tostring(t):gsub('%%', '%%%%')); end

local fonts = { main = nil, title = nil };
local function load_fonts()
    local dir = (os.getenv('WINDIR') or 'C:\\Windows') .. '\\Fonts\\';
    local function add(name, size)
        local f = io.open(dir .. name, 'rb');
        if f == nil then return nil; end
        f:close();
        local ok, font = pcall(imgui.AddFontFromFileTTF, dir .. name, size);
        return (ok and font) or nil;
    end
    fonts.main = add('segoeui.ttf', 17) or add('SegUIVar.ttf', 17);
    fonts.semi = add('seguisb.ttf', 17);
    fonts.title = add('bahnschrift.ttf', 22);
    -- the same fonts made at a few sizes, so the size sliders stay sharp (the nearest bigger one is shrunk a little)
    fonts.sized = { main = {}, semi = {}, chat = {} };
    for _, px in ipairs({ 13, 17, 22, 28, 36 }) do
        local m = (px == 17) and fonts.main or (add('segoeui.ttf', px) or add('SegUIVar.ttf', px));
        local s = (px == 17) and fonts.semi or add('seguisb.ttf', px);
        if m then table.insert(fonts.sized.main, { m, px }); end
        if s then table.insert(fonts.sized.semi, { s, px }); end
    end
    -- the chat's font: AvantGarde-Book, from the addon's fonts folder (any of these names); if it's missing,
    -- Century Gothic (the closest Windows font), then Segoe UI
    local fdir = addon.path .. '/fonts/';
    local file = nil;
    for _, n in ipairs({ 'AvantGarde-Book.ttf', 'AvantGarde-Book.otf', 'AvantGardeBook.ttf', 'avantgarde.ttf', 'AVGARDN.TTF',
                         'texgyreadventor-regular.otf', 'TeXGyreAdventor-Regular.otf' }) do
        local f = io.open(fdir .. n, 'rb');
        if f then f:close(); file = fdir .. n; fonts.chat_name = n; break; end
    end
    for _, px in ipairs({ 13, 16, 20, 26, 34 }) do
        local font = nil;
        if file then
            local ok, ff = pcall(imgui.AddFontFromFileTTF, file, px);
            font = ok and ff or nil;
        end
        font = font or add('GOTHIC.TTF', px) or add('segoeui.ttf', px);
        if font then table.insert(fonts.sized.chat, { font, px }); end
    end
    fonts.chat = fonts.sized.chat[2] and fonts.sized.chat[2][1] or fonts.main;
    YUI_FONTS = fonts;                                              -- (the Damage Meter uses these: no font of its own)
end
local function push_font(f, size)
    if f == nil then return false; end
    if YUI_NEWFONT(f) then return (pcall(imgui.PushFont, f, size)); end
    return (pcall(imgui.PushFont, f));
end
-- Text at any size: picks the nearest made size at or above it and scales it down a touch. Returns a token for unsize().
local FS = 1;                                                       -- the font scale now in use (for small text inside)
local function sized(kind, size)
    local list = fonts.sized and fonts.sized[kind] or nil;
    if list == nil or #list == 0 then FS = 1; return false; end
    local pick = list[#list];
    for _, e in ipairs(list) do if e[2] >= size - 0.5 then pick = e; break; end end
    local pushed = push_font(pick[1], pick[2]);
    FS = pushed and (size / pick[2]) or (size / 17);
    imgui.SetWindowFontScale(FS);
    return pushed;
end
local function unsized(pushed)
    imgui.SetWindowFontScale(1);
    FS = 1;
    if pushed then imgui.PopFont(); end
end

-- Pictures from the images folder, loaded once
local texs = {};
local function tex(name)
    if texs[name] ~= nil then return texs[name] or nil; end
    texs[name] = false;
    pcall(function()
        local f = io.open(addon.path .. '/images/' .. name, 'rb');
        if f == nil then return; end
        local data = f:read('*a');
        f:close();
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        if ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), data, #data, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
                ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0, nil, nil, ptr) == ffi.C.S_OK then
            local t = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
            texs[name] = { tex = t, ptr = tonumber(ffi.cast('uint32_t', t)) };
        end
    end);
    return texs[name] or nil;
end
-- A picture made at exactly the size it's drawn (px x px), shrunk once with a smooth filter when it's loaded:
-- sharper than letting the screen squeeze a big picture every frame. Each size you use gets its own copy.
function C.tex_at(name, px)
    local key = name .. '@' .. px;
    if texs[key] ~= nil then return texs[key] or nil; end
    texs[key] = false;
    pcall(function()
        local f = io.open(addon.path .. '/images/' .. name, 'rb');
        if f == nil then return; end
        local data = f:read('*a');
        f:close();
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        if ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), data, #data, px, px, 1, 0,
                ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, 4, ffi.C.D3DX_DEFAULT, 0, nil, nil, ptr) == ffi.C.S_OK then   -- (4: the triangle filter)
            local t = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
            texs[key] = { tex = t, ptr = tonumber(ffi.cast('uint32_t', t)) };
        end
    end);
    return texs[key] or nil;
end
local function image(dl, t, x1, y1, x2, y2, col)
    if t == nil then return; end
    pcall(function() DL.I(dl, t.ptr, x1, y1, x2, y2, 0, 0, 1, 1, u32(col or { 1, 1, 1, 1 })); end);
end

local function push_theme()
    local cols = {
        { ImGuiCol_WindowBg, { C.pbg[1], C.pbg[2], C.pbg[3], 0.92 } }, { ImGuiCol_ChildBg, { 0, 0, 0, 0 } }, { ImGuiCol_PopupBg, { C.pbg[1], C.pbg[2], C.pbg[3], 0.98 } },
        { ImGuiCol_Border, { 1, 1, 1, 0.08 } }, { ImGuiCol_Text, C.text }, { ImGuiCol_TextDisabled, C.muted },
        { ImGuiCol_FrameBg, { C.pframe[1], C.pframe[2], C.pframe[3], 0.70 } }, { ImGuiCol_FrameBgHovered, { 0.22, 0.21, 0.27, 1 } }, { ImGuiCol_FrameBgActive, { 0.22, 0.21, 0.27, 1 } },
        { ImGuiCol_Button, { 1, 1, 1, 0.035 } }, { ImGuiCol_ButtonHovered, { 1, 1, 1, 0.08 } }, { ImGuiCol_ButtonActive, { 1, 1, 1, 0.12 } },
        { ImGuiCol_Separator, { 1, 1, 1, 0.07 } }, { ImGuiCol_ScrollbarBg, { 0, 0, 0, 0 } },
        { ImGuiCol_ScrollbarGrab, { C.acc[1], C.acc[2], C.acc[3], 0.30 } }, { ImGuiCol_ScrollbarGrabHovered, { C.acc[1], C.acc[2], C.acc[3], 0.5 } },
    };
    local nc, nv = 0, 0;                                             -- (any name this ImGui doesn't have is skipped)
    for _, c in ipairs(cols) do if c[1] ~= nil then imgui.PushStyleColor(c[1], c[2]); nc = nc + 1; end end
    local vars = {
        { ImGuiStyleVar_WindowRounding, 12 }, { ImGuiStyleVar_FrameRounding, 8 },
        { ImGuiStyleVar_WindowPadding, { 20, 16 } }, { ImGuiStyleVar_FramePadding, { 10, 6 } },
        { ImGuiStyleVar_ItemSpacing, { 8, 8 } }, { ImGuiStyleVar_WindowBorderSize, 1 }, { ImGuiStyleVar_FrameBorderSize, 0 },
        { ImGuiStyleVar_ScrollbarSize, 6 }, { ImGuiStyleVar_ScrollbarRounding, 3 },
    };
    for _, v in ipairs(vars) do if v[1] ~= nil then imgui.PushStyleVar(v[1], v[2]); nv = nv + 1; end end
    return nc, nv;
end
local NEON = { 0.86, 0.24, 0.86 };                                   -- (the panel's colours: your own HP bar's, see C.apply_hp)
-- fill a box with its four corners cut off (c), using straight bands only (no seams)
local function fill_cut(dl, x, y, w, h, c, col)
    x, y, w, h, c = math.floor(x), math.floor(y), math.floor(w), math.floor(h), math.floor(c);
    if c * 2 >= h then c = math.floor(h / 2); end
    DL.RF(dl, x, y + c, x + w, y + h - c, col);
    for k = 0, c - 1, 2 do
        local inset = c - k - 1;
        DL.RF(dl, x + inset, y + k, x + w - inset, y + k + 2, col);
        DL.RF(dl, x + inset, y + h - k - 2, x + w - inset, y + h - k, col);
    end
end                                  -- the panel's violet (its edges, fills and marks)
local NEON2 = { 1.00, 0.42, 0.72 };
-- a small diamond (the panel's mark): an outline, and a filled one inside when it's lit
local function diamond(dl, cx, cy, r, lit, alpha)
    alpha = alpha or 1;
    local c = U4(lit and NEON2[1] or 0.62, lit and NEON2[2] or 0.60, lit and NEON2[3] or 0.70, alpha);
    DL.L(dl, cx, cy - r, cx + r, cy, c, 1.4);
    DL.L(dl, cx + r, cy, cx, cy + r, c, 1.4);
    DL.L(dl, cx, cy + r, cx - r, cy, c, 1.4);
    DL.L(dl, cx - r, cy, cx, cy - r, c, 1.4);
    local q = r * 0.45;
    local f = u32(lit and { 0.95, 0.85, 1, alpha } or { 0.55, 0.52, 0.65, alpha * 0.8 });
    DL.TF(dl, cx, cy - q, cx + q, cy, cx, cy + q, f);
    DL.TF(dl, cx, cy + q, cx - q, cy, cx, cy - q, f);
end
-- text with letter spacing (the section names, the buttons)
local function spaced(dl, x, y, str, col, gap)
    local cx = x;
    for i = 1, #str do
        local ch = str:sub(i, i);
        DL.T(dl, cx, y, col, ch);
        cx = cx + imgui.CalcTextSize(ch) + gap;
    end
    return cx - x - gap;
end
local function spaced_w(str, gap)
    local w = 0;
    for i = 1, #str do w = w + imgui.CalcTextSize(str:sub(i, i)) + gap; end
    return w - gap;
end
local function switch(id, on)
    local x, y = imgui.GetCursorScreenPos();
    local w, h = math.floor(52 * C.ps), math.floor(26 * C.ps);
    local clicked = imgui.InvisibleButton(id, { w, h });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    -- the panel's own dark colour: on = a white knob on the right and a light edge, off = a grey knob on the left
    DL.RF(dl, x, y, x + w, y + h, u32(on and { NEON[1] * 0.42, NEON[2] * 0.42, NEON[3] * 0.42, 1 } or (hov and { 0.14, 0.13, 0.18, 1 } or { 0.10, 0.095, 0.13, 1 })), h / 2);
    DL.CF(dl, on and (x + w - h / 2) or (x + h / 2), y + h / 2, h / 2 - 4 * C.ps, u32(on and { 1, 1, 1, 1 } or { 0.55, 0.53, 0.62, 1 }), 24);
    return clicked;
end
local ROW_W = 340;
-- The controls below change YunaUI's own settings, or another table when given one (tbl) with on_change(key, value)
-- called instead of saving (the EQUIP tab uses that to change YunaEquip)
local function row_switch(id, text, key, hint, tbl, on_change)
    local S = tbl or cfg;
    local x0 = imgui.GetCursorPosX();
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, text);
    if hint and imgui.IsItemHovered() then YUI_TIP(hint); end
    imgui.SameLine(x0 + ROW_W - math.floor(52 * C.ps));
    if switch(id, S[key] == true) then
        S[key] = not (S[key] == true);
        if on_change then on_change(key, S[key]); else save(); end
    end
end
-- A slider on one line: the name, a violet track, the value at the end. Double click puts it back to normal.
local function row_slider(id, text, key, lo, hi, step, fmt, tbl, on_change)
    local S = tbl or cfg;
    local v = tonumber(S[key]) or lo;
    local ps = C.ps;
    local x0 = imgui.GetCursorPosX();
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, text);
    local lw = imgui.CalcTextSize(text);
    local label = string.format(fmt, v);
    local vw = imgui.CalcTextSize(label);
    local tl = math.max(lw + 24 * ps, ROW_W * 0.30);                 -- the track: after the name, before the value
    local tr = ROW_W - math.max(vw, 44 * ps) - 22 * ps;
    imgui.SameLine(x0 + tl);
    local x, y = imgui.GetCursorScreenPos();
    local w, h = math.max(40, tr - tl), imgui.GetFrameHeight();
    imgui.InvisibleButton(id, { w, h });
    local act, hov = imgui.IsItemActive(), imgui.IsItemHovered();
    if act then
        local mx = imgui.GetMousePos();
        local f = math.max(0, math.min(1, (mx - x) / w));
        local nv = lo + math.floor((f * (hi - lo)) / step + 0.5) * step;
        if math.abs(nv - v) > step * 0.01 then S[key] = nv; v = nv; label = string.format(fmt, v); end
    end
    if imgui.IsItemDeactivated() then if on_change then on_change(key, S[key]); else save(); end end
    if not tbl and hov and imgui.IsMouseDoubleClicked(0) then cfg[key] = defaults[key]; v = defaults[key]; save(); end
    local dl = imgui.GetWindowDrawList();
    local f = math.max(0, math.min(1, (v - lo) / (hi - lo)));
    local cy = y + h / 2;
    local th = math.max(4, math.floor(6 * ps));
    DL.RF(dl, x, cy - th / 2, x + w, cy + th / 2, U4(0.20, 0.19, 0.25, 1), th / 2);
    local ok_ = pcall(function()
        DL.RFM(dl, x, cy - th / 2, x + w * f, cy + th / 2, u32(NEON), u32(NEON2), u32(NEON2), u32(NEON));
    end);
    if not ok_ then DL.RF(dl, x, cy - th / 2, x + w * f, cy + th / 2, u32(NEON), th / 2); end
    DL.CF(dl, x + w * f, cy, ((act or hov) and 13 or 11) * ps, U4(NEON[1], NEON[2], NEON[3], 0.30), 24);
    DL.CF(dl, x + w * f, cy, 8 * ps, U4(1, 1, 1, 1), 24);
    imgui.SameLine(x0 + ROW_W - vw);
    imgui.TextColored(C.text, label);
end
-- A section's name: the name in spaced capitals, a faint line on to the edge
local function section(text)
    if C.split then C.split(); end
    imgui.Spacing(); imgui.Spacing();
    local ps = C.ps;
    local dl = imgui.GetWindowDrawList();
    local x0, y0 = imgui.GetCursorScreenPos();
    local pushed = push_font(fonts.semi, 17 * ps);
    local lh = imgui.GetTextLineHeight();
    local tw = spaced(dl, x0, y0, text:upper(), U4(0.93, 0.90, 1.00, 1), 2.5 * ps);
    if pushed then imgui.PopFont(); end
    DL.L(dl, x0 + tw + 18 * ps, y0 + lh / 2, x0 + ROW_W, y0 + lh / 2, U4(1, 1, 1, 0.08), 1);
    imgui.Dummy({ ROW_W, lh + 2 * ps });
end
-- A rounded button: violet-edged (the main one) or dark (quiet = true), its name in spaced capitals
local function accent_button(label, size, quiet, small)
    local ps = C.ps;
    local w = (size and size[1] and size[1] > 0) and size[1] or (spaced_w(label, 3 * ps) + 40 * ps);
    local h = (size and size[2] and size[2] > 0) and size[2] or math.floor(imgui.GetFrameHeight() * (small and 0.95 or 1.25));
    local x, y = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton(label, { w, h });
    local hov, act = imgui.IsItemHovered(), imgui.IsItemActive();
    local dl = imgui.GetWindowDrawList();
    local rr = math.min(h * 0.45, 14 * ps);
    local fill = { 0.10, 0.09, 0.13, 1 };                            -- the panel's dark colour inside (the violet edge stays)
    if hov or act then fill = act and { 0.18, 0.17, 0.23, 1 } or { 0.15, 0.14, 0.19, 1 }; end
    DL.RF(dl, x, y, x + w, y + h, u32(fill), rr);
    local ec = u32(quiet and { 1, 1, 1, hov and 0.25 or 0.14 } or { NEON2[1], NEON2[2], NEON2[3], hov and 1 or 0.8 });
    DL.R(dl, x, y, x + w, y + h, ec, rr, C.rall, quiet and 1 or 1.6);
    local name = label:gsub('##.*$', ''):upper();
    if small then imgui.SetWindowFontScale((C.wfs or 1) * 0.82); end -- (small: a smaller label, tighter letters)
    local sp = (small and 2 or 3) * ps;
    local lw = spaced_w(name, sp);
    local lh = imgui.GetTextLineHeight();
    spaced(dl, x + (w - lw) / 2, y + (h - lh) / 2, name, U4(0.93, 0.91, 0.98, 1), sp);
    if small then imgui.SetWindowFontScale(C.wfs or 1); end
    return clicked;
end
-- A choice: the name on the left, a dark pill on the right with the current one and a small arrow; click it for the list
local function row_pick(id, text, key, opts, tbl, on_change)
    local S = tbl or cfg;
    local ps = C.ps;
    local x0 = imgui.GetCursorPosX();
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, text);
    local cur = 1;
    for k, o in ipairs(opts) do if o[1] == S[key] then cur = k; end end
    local bw, bh = math.floor(math.min(ROW_W * 0.55, 320 * ps)), imgui.GetFrameHeight();
    for _, o in ipairs(opts) do bw = math.max(bw, math.floor(imgui.CalcTextSize(o[2]) + 70 * ps)); end
    imgui.SameLine(x0 + ROW_W - bw);
    local bx, by = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton(id, { bw, bh });
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    DL.RF(dl, bx, by, bx + bw, by + bh, u32(hov and { 0.15, 0.14, 0.19, 1 } or { 0.10, 0.09, 0.13, 1 }), bh / 2);
    DL.R(dl, bx, by, bx + bw, by + bh, u32(hov and { NEON2[1], NEON2[2], NEON2[3], 0.45 } or { 1, 1, 1, 0.10 }), bh / 2, C.rall, 1);
    local label = opts[cur][2];
    local lw, lh = imgui.CalcTextSize(label);
    DL.T(dl, bx + (bw - lw) / 2, by + (bh - lh) / 2, U4(0.93, 0.92, 0.98, 1), label);
    local ax, ay, r = bx + bw - 22 * ps, by + bh / 2, 4.5 * ps;     -- the little down arrow
    local ac = U4(0.85, 0.83, 0.95, hov and 1 or 0.75);
    DL.L(dl, ax - r, ay - r * 0.5, ax, ay + r * 0.5, ac, 1.5);
    DL.L(dl, ax, ay + r * 0.5, ax + r, ay - r * 0.5, ac, 1.5);
    if clicked then imgui.OpenPopup(id .. '_list'); end
    -- the list of choices: some room inside (it was stuck to the edges), dark like the panel, a soft violet on the chosen
    local pv = 0;
    for _, v in ipairs({ { ImGuiStyleVar_WindowPadding, { 12 * ps, 10 * ps } }, { ImGuiStyleVar_ItemSpacing, { 6 * ps, 6 * ps } },
                         { ImGuiStyleVar_PopupRounding, 8 * ps }, { ImGuiStyleVar_PopupBorderSize, 1 } }) do
        if v[1] ~= nil then imgui.PushStyleVar(v[1], v[2]); pv = pv + 1; end
    end
    imgui.PushStyleColor(ImGuiCol_PopupBg, { 0.055, 0.050, 0.075, 0.98 });
    imgui.PushStyleColor(ImGuiCol_Border, { 1, 1, 1, 0.10 });
    imgui.PushStyleColor(ImGuiCol_Header, { 1, 1, 1, 0.12 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 1, 1, 1, 0.08 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 1, 1, 1, 0.16 });
    if imgui.BeginPopup(id .. '_list') then
        for k, o in ipairs(opts) do
            if imgui.Selectable('  ' .. o[2] .. '##' .. id .. k, k == cur, 0, { bw, 0 }) then
                S[key] = o[1];
                if on_change then on_change(key, S[key]); else save(); end
            end
        end
        imgui.EndPopup();
    end
    imgui.PopStyleColor(5);
    imgui.PopStyleVar(pv);
end
-- The title as YGO draws it: YUNA in white, the rest flowing between periwinkle and ice blue
local function title(dl, full)
    local pushed = push_font(fonts.title, 22 * C.ps);
    if not pushed then imgui.SetWindowFontScale(1.3 * C.wfs); end
    local t = os.clock();
    local x0, y0 = imgui.GetCursorScreenPos();
    local tw, lh = imgui.CalcTextSize(full);
    for i = 1, #full do
        local ch = full:sub(i, i);
        if ch ~= ' ' then
            local cx = x0 + imgui.CalcTextSize(full:sub(1, i - 1));
            local col = C.text;
            if i > 5 then
                local u = 0.5 + 0.5 * math.sin(t * 1.2 - i * 0.45);
                local a1, a2 = C.hp, C.mp2;
                if cfg.target_fx == 'link' then a1, a2 = NEON, NEON2; end   -- (Hex link mode: gold)
                col = { a1[1] + (a2[1] - a1[1]) * u, a1[2] + (a2[2] - a1[2]) * u, a1[3] + (a2[3] - a1[3]) * u, 1 };
            end
            DL.T(dl, cx, y0, u32(col), ch);
        end
    end
    imgui.Dummy({ tw, lh });
    if pushed then imgui.PopFont(); else imgui.SetWindowFontScale(C.wfs); end
end

-- A window with no background or frame, that remembers where it was dragged to
local NOFRAME = nil;
local function plain_window(name, kx, ky, force)
    if NOFRAME == nil then
        NOFRAME = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_AlwaysAutoResize,
            ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoBackground,
            ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoSavedSettings);
    end
    local one = WATCH.one and WATCH.one[kx];                        -- (just this window put back on the screen: only it moves)
    if one then WATCH.one[kx] = (one > 1) and (one - 1) or nil; end
    local px, py = tonumber(cfg[kx]) or 100, tonumber(cfg[ky]) or 100;
    if px > -1000 and py > -1000 then                                -- (kept on the screen before it's drawn, by its last size: on plain
        local W, H = C.screen();                                     --  Ashita a window partly off the screen for even one frame hides the
        local sz = WATCH.size and WATCH.size[kx];                    --  windows drawn after it, the settings panel flickered)
        local sw, sh = (sz and sz[1]) or 1, (sz and sz[2]) or 1;
        local nx = math.max(0, math.min(W - math.min(sw, W), px));
        local ny = math.max(0, math.min(H - math.min(sh, H), py));
        if nx ~= px or ny ~= py then px, py, one = nx, ny, one or 1; cfg[kx], cfg[ky] = nx, ny; end
    end
    imgui.SetNextWindowPos({ px, py }, (WATCH.move > 0 or force or one) and ImGuiCond_Always or ImGuiCond_FirstUseEver);
    local flags = NOFRAME;
    if (cfg.locked and not EDIT.on) or force or (EDIT.on and EDIT.rs_hot) then flags = bit.bor(flags, ImGuiWindowFlags_NoMove); end
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    local open = imgui.Begin(name, { true }, flags);
    return open;
end
-- Every YunaUI window stays on the screen, whatever its size: one that sticks out (a smaller resolution, a monitor change,
-- settings copied from a bigger screen) is pushed back inside - never while it's being dragged. Gives back the new
-- place and true when it moved it. (YUI_ONSCREEN: the same for equip.lua's bars and the Damage Meter.)
function YUI_ONSCREEN(wx, wy, sw, sh)
    if type(wx) ~= 'number' or type(wy) ~= 'number' or type(sw) ~= 'number' or type(sh) ~= 'number' or sw < 4 then return wx, wy, false; end
    if imgui.IsMouseDown(0) or wx < -1000 then return wx, wy, false; end   -- (not while dragged; not one parked off screen on purpose)
    local ds = imgui.GetIO().DisplaySize;
    local W, H = ds and tonumber(ds.x), ds and tonumber(ds.y);
    if not W or W < 200 or not H or H < 200 then return wx, wy, false; end
    local nx = math.max(0, math.min(W - math.min(sw, W), wx));
    local ny = math.max(0, math.min(H - math.min(sh, H), wy));
    if math.abs(nx - wx) > 1 or math.abs(ny - wy) > 1 then return math.floor(nx), math.floor(ny), true; end
    return wx, wy, false;
end
local function end_plain(kx, ky)
    local wx, wy = imgui.GetWindowPos();
    local sw, sh = imgui.GetWindowSize();                             -- (its size, for GENERAL > LAYOUT)
    if type(sw) == 'number' and type(sh) == 'number' then WATCH.size = WATCH.size or {}; WATCH.size[kx] = { sw, sh }; end
    if math.abs(wx - (tonumber(cfg[kx]) or 0)) > 0.5 or math.abs(wy - (tonumber(cfg[ky]) or 0)) > 0.5 then
        cfg[kx], cfg[ky] = wx, wy;
        if EDIT.on then EDIT.drag = kx; end                           -- (Edit Mode: this one is being dragged)
        if not imgui.IsMouseDown(0) then save(); end
    end
    if EDIT.on and EDIT.drag == kx and type(sw) == 'number' then
        local nx, ny, guides = EDIT.snap(kx, wx, wy, sw, sh);
        EDIT.guides = guides;
        if not imgui.IsMouseDown(0) then                             -- let go: it snaps
            cfg[kx], cfg[ky] = nx, ny;
            EDIT.drag, EDIT.guides = nil, {};
            WATCH.move = 2;
            save();
        end
    end
    local nx, ny, moved = YUI_ONSCREEN(wx, wy, sw, sh);              -- (always on the screen)
    if moved then                                                    -- only this window goes back (moving all of them made the whole UI
        cfg[kx], cfg[ky] = nx, ny;                                   --  tremble while one was growing, e.g. the pet bar popping in);
        WATCH.one = WATCH.one or {};                                 --  saved at most once a second
        WATCH.one[kx] = 2;
        if os.clock() - (WATCH.saved or 0) > 1 then WATCH.saved = os.clock(); save(); else WATCH.later = true; end
    end
    imgui.End();
    imgui.PopStyleVar(2);
end

-- Text with a thin dark edge (readable on any ground)
local function text(dl, x, y, str, col)
    for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do DL.T(dl, x + o[1], y + o[2], U4(0, 0, 0, 0.8), str); end
    DL.T(dl, x, y, u32(col), str);
end

-- A thin living bar: a glowing coloured edge, the colours flowing along inside it,
-- a sheen that sweeps along now and then, and a lighter piece that drains after a loss. Used by the target bar and the party/alliance lists.
local function frac(v) return v - math.floor(v); end
local function glow_bar(dl, x, y, w, h, v, lag, c1, c2, seed, fxo)
    v = math.max(0, math.min(1, v or 0));
    seed = seed or 0;
    local now = os.clock();
    DL.RF(dl, x, y, x + w, y + h, U4(0.05, 0.04, 0.07, 0.70), h / 2);
    if lag and lag > v + 0.002 then
        DL.RF(dl, x + math.max(0, math.min(w * v, w * lag - h)), y, x + w * lag, y + h, U4(1, 0.92, 0.95, 0.40), h / 2);   -- (what was just lost: never a sliver - that came out square, its corners poking out of the round edge)
    end
    if v <= 0 then return; end
    local fw = w * v;
    local pulse = 0.5 + 0.5 * math.sin(now * 2.2 + seed);
    for k = 1, 4 do                                                  -- the coloured glow around it, breathing
        DL.RF(dl, x - k, y - k, x + fw + k, y + h + k, U4(c2[1], c2[2], c2[3], (0.11 - k * 0.022) * (0.75 + 0.5 * pulse)), h / 2 + k);
    end
    DL.RF(dl, x - 1, y - 1, x + fw + 1, y + h + 1, U4(c2[1], c2[2], c2[3], 0.85), h / 2 + 1);   -- the edge
    -- the fill: the two colours flow along the bar in slow waves
    local segs = math.max(4, math.floor(w / 40));
    local fx = fxo or cfg.bar_fx or 'flow';                          -- the bars' effect (a setting; fxo: this bar's own)
    local ph = (fx == 'flow') and (now * 0.35 + seed * 0.21) or 0.3;
    local function col_at(f)
        local u = 0.5 + 0.5 * math.sin((f * 1.6 - ph) * math.pi * 2);
        return U4(c1[1] + (c2[1] - c1[1]) * u, c1[2] + (c2[2] - c1[2]) * u, c1[3] + (c2[3] - c1[3]) * u, 1);
    end
    local r_ = math.min(h / 2, fw / 2);                              -- (the fill's two ends are round, like its edge)
    local L_ = (v < 0.985) and math.min(fw, math.max(8, h * 2.6)) or 0;   -- (its end lights up in the bar's own colour: not on a full bar)
    local lt_ = { c2[1] + (1 - c2[1]) * 0.85, c2[2] + (1 - c2[2]) * 0.85, c2[3] + (1 - c2[3]) * 0.85 };
    local function colx(px)                                          -- the fill's colour at px: the flowing colours, lighter towards the end
        local f = (px - x) / w;
        local u = 0.5 + 0.5 * math.sin((f * 1.6 - ph) * math.pi * 2);
        local c = { c1[1] + (c2[1] - c1[1]) * u, c1[2] + (c2[2] - c1[2]) * u, c1[3] + (c2[3] - c1[3]) * u };
        local t = (L_ > 0) and 0.45 * math.max(0, math.min(1, (px - (x + fw - L_)) / math.max(1, L_ - r_))) or 0;
        return U4(c[1] + (lt_[1] - c[1]) * t, c[2] + (lt_[2] - c[2]) * t, c[3] + (lt_[3] - c[3]) * t, 1);
    end
    DL.RF(dl, x, y, x + math.min(fw, h), y + h, colx(x), r_);
    DL.RF(dl, x + fw - math.min(fw, h), y, x + fw, y + h, colx(x + fw), r_);
    local cuts = {};                                                 -- (the strips: the colours' steps, and where the light starts)
    for k = 0, segs do cuts[#cuts + 1] = x + w * k / segs; end
    if L_ > 0 then cuts[#cuts + 1] = x + fw - L_; end
    table.sort(cuts);
    for k = 1, #cuts - 1 do
        local x1, x2 = math.max(x + r_, cuts[k]), math.min(x + fw - r_, cuts[k + 1]);
        if x2 > x1 then
            local a, b = colx(x1), colx(x2);
            DL.RFM(dl, x1, y, x2, y + h, a, b, b, a);
        end
    end
    -- the sheen: a soft band of light that runs along the bar every few seconds
    local sp = frac(now * 0.32 + seed * 0.137);
    local hx, hw = x - 40 + sp * (fw + 80), 40;
    local function band(x1, x2, a1, a2)
        local cx1, cx2 = math.max(x + math.min(h / 2, fw / 2), x1), math.min(x + fw - math.min(h / 2, fw / 2), x2);   -- (inside the round ends)
        if cx2 <= cx1 then return; end
        local f1, f2 = (cx1 - x1) / (x2 - x1), (cx2 - x1) / (x2 - x1);
        local b1, b2 = a1 + (a2 - a1) * f1, a1 + (a2 - a1) * f2;
        DL.RFM(dl, cx1, y, cx2, y + h, U4(1, 1, 1, b1), U4(1, 1, 1, b2), U4(1, 1, 1, b2), U4(1, 1, 1, b1));
    end
    if fx == 'flow' then
        band(hx - hw, hx, 0, 0.55);
        band(hx, hx + hw, 0.55, 0);
    elseif fx == 'electric' then
        -- a light electric crackle that lives inside the fill: thin jagged threads that jump about many times a
        -- second, brightening in pulses (never outside the bar)
        local beat = math.max(0, math.sin(now * 2.6 + seed)) ^ 3;
        local a = 0.18 + 0.55 * beat;
        C.clip(dl, { x, y }, { x + fw, y + h }, true);
        local tick = math.floor(now * 14);
        local step = math.max(4, h * 1.8);
        for pass = 1, 2 do
            local px, py = x, y + h / 2;
            local k = 0;
            while px < x + fw do
                k = k + 1;
                local r = frac(math.sin(tick * 31.7 + k * 12.9898 + seed * 7.1 + pass * 3.3) * 43758.5453);
                local nx = math.min(x + fw, px + step * (0.6 + 0.8 * frac(r * 7.7)));
                local ny = y + h * (0.12 + 0.76 * r);
                DL.L(dl, px, py, nx, ny, U4(0.92, 0.97, 1, a * ((pass == 1) and 1 or 0.4)), (pass == 1) and 1 or 1.6);
                px, py = nx, ny;
            end
        end
        DL.RF(dl, x, y, x + fw, y + h, U4(1, 1, 1, 0.10 * beat));
        dl:PopClipRect();
    elseif fx == 'pulse' then
        -- the whole fill brightens softly and back
        local b = 0.5 - 0.5 * math.cos(now * 2.2 + seed);
        DL.RF(dl, x, y, x + fw, y + h, U4(1, 1, 1, 0.22 * b), h / 2);
    end
end

-- Animated effects laid over the HP bars (the user's FootageCrate clips): stretched over the filled part, so the beam's
-- bright head sits where the HP ends. Which one: GENERAL tab > Bar overlay (for all), or each bar on its own.
local BAR_FX = {
    beam    = { fmt = 'beam/%03d.png',    wfmt = 'beam_w/%03d.png',    n = 65, fps = 15, tall = 14 },   -- Electric Beam (its core ~ the bar's thickness)
    inferno = { fmt = 'inferno/%02d.png', wfmt = 'inferno_w/%02d.png', n = 41, fps = 24, tall = 7 },    -- Blue Inferno
};
-- The effect takes the bar's colour (BARS > Your HP bar / Target bar): drawn from white copies of its frames (_w), tinted.
-- White bars keep the effect's own colours.
C.FXTINT = { pink = { 1.0, 0.52, 0.86 }, red = { 1.0, 0.46, 0.42 } };
function C.fxtint(choice) return C.FXTINT[choice or 'pink']; end
local function bar_fx_for(which)                                    -- which: 'target', 'party', 'alliance', 'equip', 'pet'
    local k = cfg['barfx_' .. which] or 'same';
    if k == 'same' then k = cfg.barfx or 'none'; end
    return BAR_FX[k];
end
local function bar_overlay(x, y, fw, h, fx, seed, tint)
    if fx == nil or fw < 2 or C.bigchat then return; end            -- (not over the pad's big chat: it draws on top of every window)
    local k = (math.floor(os.clock() * fx.fps) + math.floor(seed * 7)) % fx.n;
    local t = tex(string.format((tint and fx.wfmt) or fx.fmt, k));
    if t == nil then return; end
    local fl = nil;
    pcall(function() fl = imgui.GetForegroundDrawList(); end);       -- on top, so it's never cut by its window
    if fl == nil then return; end
    local k = math.max(0.3, math.min(1, tonumber(cfg.barfx_size) or 0.6));   -- (BARS > Height: how far it reaches out of the bar)
    local hh = math.max(6, h * fx.tall * k);
    local a = math.max(0, math.min(1, tonumber(cfg.barfx_alpha) or 1));
    local c = tint or { 1, 1, 1 };
    local y0, y1 = y + h / 2 - hh / 2, y + h / 2 + hh / 2;
    pcall(function()                                                 -- (the frames are weak at their ends: their middle stretched over
        DL.I(fl, t.ptr, x, y0, x + fw, y1, 0.06, 0, 0.95, 1, U4(c[1], c[2], c[3], a));   -- the bar, and a mirrored
        DL.I(fl, t.ptr, x, y0, x + fw, y1, 0.95, 0, 0.06, 1, U4(c[1], c[2], c[3], a * 0.55));   -- copy, so it fills it evenly)
    end);
end
-- TARGET > Bar style (the glowing target bar): pre-rendered frames (images/dd2, 48 looping, 1024 x 48 each):
-- a deep-magenta band with clean soft edges, a white core whose edges crackle and drift organically, a pink bloom; and a
-- clean white tip (dd2/tip.png) where the HP ends. The frames keep their own scale (never stretched with the HP), and
-- the HP just lost drains away as a faint trail.
function C.dd2bar(dl, x, y, w, h, v, lag, seed)
    v = math.max(0, math.min(1, v or 0));
    local cy = y + h / 2;
    local fw = w * v;
    local Hd = math.max(18, h * 12);                                 -- (the frame's height on screen: its core ~ the bar's thickness)
    local k = Hd / 48;
    local B = 13 * k;                                                -- (its band's height)
    DL.RF(dl, x, cy - B / 2, x + w, cy + B / 2, U4(0.05, 0.03, 0.07, 0.45), B / 2);   -- (the empty part: a dark band, round ends)
    if lag and lag > v then DL.RF(dl, math.max(x, x + fw - B), cy - B / 2, x + w * lag, cy + B / 2, U4(1, 0.85, 1, 0.22), B / 2); end
    if fw < 1 then return; end
    local plain = cfg.target_bar_anim == false;                      -- (TARGET > Bar effect off: no running white line)
    local f = (math.floor(os.clock() * 24) + math.floor(seed * 7)) % 48;
    local t = plain and tex('dd2/nocore.png') or tex(string.format('dd2/%02d.png', f));   -- (TARGET > Bar effect off: just the band, no white line)
    if t then
        local mw = math.max(1, fw - 4 * k);                          -- (up to where the tip's round end takes over)
        local u1 = math.min(1, mw / (1024 * k));                     -- (as much of the frame as the HP covers, at its own scale)
        pcall(function() DL.I(dl, t.ptr, x, cy - Hd / 2, x + mw, cy + Hd / 2, 0, 0, u1, 1, U4(1, 1, 1, 1)); end);
    end
    local tp = tex(plain and 'dd2/tip_nocore.png' or 'dd2/tip.png');   -- the clean white tip, its round end on the HP's end
    if tp then
        local tw = math.min(44 * k, fw + 4 * k);                     -- (the band's round end on the HP's end; at low HP the whole tip narrows -
        local tx = x + fw + 4 * k - tw;                              --  a small pill, round both ends, never past the bar's left end)
        pcall(function() DL.I(dl, tp.ptr, tx, cy - Hd / 2, tx + tw, cy + Hd / 2, 0, 0, 1, 1, U4(1, 1, 1, 1)); end);
    end
end
-- Hex link's bars: a band with pointed ends (a stretched hexagon), the value filling it (o.c2 at the
-- left fading to o.c1) with a white pointed tip, what was just lost in pale pink. o: c1, c2, cf (one flat fill), band (height), tip, al
function C.hexbar(dl, x, y, w, h, v, lag, seed, o)
    o = o or {};
    v = math.max(0, math.min(1, v or 0));
    local al = o.al or 1;
    local cy = y + h / 2;
    local B = o.band or math.max(6, h * 2.2);                        -- (the band's height)
    local c1, c2 = o.c1 or C.tgt1 or { 1, 0.78, 0.96 }, o.c2 or C.tgt2 or C.hp2 or { 0.75, 0.35, 1 };
    local function col(c, a) return U4(c[1], c[2], c[3], a * al); end
    local function shape(x0, x1, cl, cr, p)                          -- (the band from x0 to x1: pointed ends, cl at the left fading to cr)
        p = p or 0;
        if x1 - x0 < 1 then return; end
        local y0, y1 = cy - B / 2 - p, cy + B / 2 + p;
        local k = math.min(B / 2 + p, (x1 - x0) / 2);
        cr = cr or cl;
        DL.TF(dl, x0, cy, x0 + k, y0, x0 + k, y1, cl);
        if x1 - k > x0 + k then DL.RFM(dl, x0 + k, y0, x1 - k, y1, cl, cr, cr, cl); end
        DL.TF(dl, x1, cy, x1 - k, y1, x1 - k, y0, cr);
    end
    local fw = w * v;
    local live = o.live;                                             -- (the head bars: depth and life)
    if live then                                                     -- (on whole pixels: the shading inside meets its edges exactly - no sliver of a line)
        B = math.max(2, math.floor(B + 0.5));
        cy = math.floor(cy - B / 2 + 0.5) + B / 2;
    end
    shape(x - 1, x + w + 1, col({ 0, 0, 0 }, 0.55), nil, 1.5);         -- (a dark rim, readable on snow)
    shape(x, x + w, col({ 0.07, 0.05, 0.10 }, 0.8));                 -- (the empty part)
    if live and w > B then                                           -- (the empty part carved in: a shadow under its top edge)
        local k = math.min(B / 2, w / 2);
        local z0, z1 = col({ 0, 0, 0 }, 0.5), col({ 0, 0, 0 }, 0);
        DL.RFM(dl, x + k, cy - B / 2, x + w - k, cy, z0, z0, z1, z1);   -- (inside the edge: never a line over it)
    end
    if lag and lag > v then shape(x, x + w * lag, live and col({ 1, 0.93, 0.78 }, 0.60) or col({ 1, 0.88, 1 }, 0.30)); end   -- (just lost: head bars cream)
    if live and o.lead and o.lead > v + 0.002 then                   -- (a heal: a light ahead, the bar catching up to it)
        shape(x, x + w * math.min(1, o.lead), col({ 1, 1, 1 }, 0.20 + 0.10 * math.sin(os.clock() * 12)));
    end
    if fw >= 1 then
        shape(x, x + fw, col(o.cf or c2, 0.95), col(o.cf or c1, 1));
        local k = math.min(B / 2, fw / 2);
        if live and fw > 2 * k + 2 then                              -- (a glass tube: light on its upper half, shade on its lower one)
            local w0, w1, b0, b1 = col({ 1, 1, 1 }, 0.32), col({ 1, 1, 1 }, 0), col({ 0, 0, 0 }, 0), col({ 0, 0, 0 }, 0.32);
            DL.RFM(dl, x + k, cy - B / 2, x + fw - k, cy, w0, w0, w1, w1);   -- (inside the edge)
            DL.RFM(dl, x + k, cy, x + fw - k, cy + B / 2, b0, b0, b1, b1);
        end
        if B >= 5 and fw > 2 * k + 2 then DL.L(dl, x + k, cy - B / 2 + 1, x + fw - k, cy - B / 2 + 1, col({ 1, 1, 1 }, 0.35), 1); end   -- (light along its top)
        if o.tip ~= false then
            local tl = math.min(fw, B * 2.2);                        -- (the white tip, pointed, on the end)
            shape(x + fw - tl, x + fw, col({ 1, 1, 1 }, 0), col({ 1, 1, 1 }, 0.95));
        end
    end
    local k = math.min(B / 2, w / 2);                                -- (its outline)
    local y0, y1 = cy - B / 2, cy + B / 2;
    local pts = { { x, cy }, { x + k, y0 }, { x + w - k, y0 }, { x + w, cy }, { x + w - k, y1 }, { x + k, y1 } };
    if not live then for i = 1, 6 do dl:AddLine(pts[i], pts[i % 6 + 1], col(c1, 0.45), 1); end end   -- (the head bars: none - over the carved top it read as a stray line)
end
-- Hex link: a monster's bar in its claim colour, as the game colours names - not claimed: orange, yours or your
-- party's / alliance's: red, someone else's: purple (each a dark-to-light pair: left, right)
C.CLAIMCOL = { free = { { 0.92, 0.42, 0.10 }, { 1.00, 0.72, 0.35 } }, mine = { { 0.82, 0.12, 0.18 }, { 1.00, 0.45, 0.42 } },
               other = { { 0.52, 0.24, 0.92 }, { 0.82, 0.60, 1.00 } } };
function C.claimcol(idx, fake)
    if fake then return C.CLAIMCOL.mine; end                         -- (the pretend target: an enemy you're fighting)
    local cl = 0;
    pcall(function()
        local e = vana and vana.game and vana.game.entity and vana.game.entity(idx);
        if type(e) == 'table' then cl = tonumber(e.claim) or 0; end
    end);
    if cl == 0 then return C.CLAIMCOL.free; end
    if C.is_party_id and C.is_party_id(cl) then return C.CLAIMCOL.mine; end
    return C.CLAIMCOL.other;
end
function C.hexpts(x, y, r)                                           -- (a hexagon's corners, pointy top)
    local out = {};
    for k = 0, 5 do local an = -math.pi / 2 + k * math.pi / 3; out[k + 1] = { x + r * math.cos(an), y + r * math.sin(an) }; end
    return out;
end
function C.hexdot(dl, x, y, r, col)                                  -- (a filled hexagon, in one go: as six triangles their seams
    local p_ = C.hexpts(x, y, r);                                    --  showed as a dark cross over what was under it)
    if not pcall(function() dl:AddConvexPolyFilled(p_, col); end) then
        for k = 1, 6 do dl:AddTriangleFilled({ x, y }, p_[k], p_[k % 6 + 1], col); end
    end
end
function C.hexlow(dl, x, y, r, yl, col)                             -- (the part of a hexagon under the level yl, filled: a liquid in it)
    local p_, out = C.hexpts(x, y, r), {};
    for k = 1, 6 do
        local a_, b_ = p_[k], p_[k % 6 + 1];
        local ia, ib = a_[2] >= yl, b_[2] >= yl;
        if ia then out[#out + 1] = a_; end
        if ia ~= ib then local q = (yl - a_[2]) / (b_[2] - a_[2]); out[#out + 1] = { a_[1] + (b_[1] - a_[1]) * q, yl }; end
    end
    if #out < 3 then return nil; end
    if not pcall(function() dl:AddConvexPolyFilled(out, col); end) then
        for t_ = 2, #out - 1 do dl:AddTriangleFilled(out[1], out[t_], out[t_ + 1], col); end
    end
    local x0, x1 = nil, nil;                                         -- (where its surface is, left and right)
    for _, q in ipairs(out) do if math.abs(q[2] - yl) < 0.01 then x0 = math.min(x0 or q[1], q[1]); x1 = math.max(x1 or q[1], q[1]); end end
    return x0, x1;
end
function C.hexring(dl, x, y, r, col, th)                             -- (a hexagon's edge)
    local p_ = C.hexpts(x, y, r);
    for k = 1, 6 do dl:AddLine(p_[k], p_[k % 6 + 1], col, th or 1); end
end
-- the same for YunaEquip's own HP bar ('Separate bars'), which lives in equip.lua
YUI_HIDE_STATBARS = function() return cfg.target_fx == 'link' and (cfg.head_bars or 'fixed') == 'head'; end   -- (equip.lua: BARS > Where = Over your head - Hex link mode only)
YUI_BAR_OVERLAY = function(x, y, fw, h, seed) bar_overlay(x, y, fw, h, bar_fx_for('equip'), seed or 1, C.fxtint(cfg.my_hp_color or cfg.hp_color or 'pink')); end

----------------------------------------------------------------------------------------------------
-- Game data
----------------------------------------------------------------------------------------------------
local JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM', 'NIN', 'DRG', 'SMN',
               'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN' };
local lag = {};                                                     -- per bar: the draining "what was lost" value
local function lagged(key, v, dt)
    local l = lag[key];
    if l == nil or v >= l then l = v; else l = math.max(v, l - dt * 0.5); end
    lag[key] = l;
    return l;
end
-- "Show party" / "Show alliance" (GENERAL tab): fill the empty places with pretend members, so the lists can be placed
-- and sized when you're alone (not saved: they're off again next time)
local PREVIEW = { party = false, alliance = false };
local DEMO = { 'Yunas', 'Slayern', 'Tankie', 'Ninjy', 'Bardo', 'Corsi' };
-- The leader's mark (PARTY > Leader mark). The alliance leader's is the same with a little extra.
--   crown: a small gold crown        dots: two dots, pink and violet (the anchor's look)
--   bar: a short glowing pink-to-violet line with a bright tip (the bars' look)
--   gem: a violet diamond with a pink heart        halo: a pink-to-violet ring round a white dot
--   name: no mark; the name gets a glowing pink-to-violet line under it
LEAD_STYLES = { { 'crown', 'Crown' }, { 'dots', 'YunaUI dots' }, { 'bar', 'YunaUI bar' }, { 'gem', 'YunaUI gem' },
                { 'halo', 'YunaUI halo' }, { 'name', 'Underlined name' }, { 'none', 'None' } };
local function lead_mix(u, a)
    return U4(1.0 + (0.62 - 1.0) * u, 0.36 + (0.40 - 0.36) * u, 0.62 + (1.0 - 0.62) * u, a);
end
function LEAD_MARK(dl, cx, cy, r, alliance, a, style)
    a = a or 1;
    style = style or 'dots';
    local dark = U4(0, 0, 0, 0.7 * a);
    if style == 'dots' and YUI_HEX then                              -- (Hex link mode: small hexagons, gold to azure, a little apart)
        local n = alliance and 3 or 2;
        local rr = r * 0.46;
        local step = rr * 2.1;
        local x0 = cx - (n - 1) * step / 2;
        local g1, g2 = C.GOLDH, C.HEXMP[1];
        for k = 1, n do
            local u = (k - 1) / math.max(1, n - 1);
            local px = x0 + (k - 1) * step;
            C.hexdot(dl, px, cy, rr * 1.12 + 1.2, dark);
            C.hexdot(dl, px, cy, rr * 1.12, U4(g1[1] + (g2[1] - g1[1]) * u, g1[2] + (g2[2] - g1[2]) * u, g1[3] + (g2[3] - g1[3]) * u, a));
        end
    elseif style == 'dots' then
        local n = alliance and 3 or 2;
        local rr = r * 0.46;
        local x0 = cx - (n - 1) * rr * 0.92;
        for k = 1, n do
            local px = x0 + (k - 1) * rr * 1.84;
            DL.CF(dl, px, cy, rr + 1.2, dark, 16);
            DL.CF(dl, px, cy, rr, lead_mix((k - 1) / math.max(1, n - 1), a), 16);
        end
    elseif style == 'bar' then
        local n = alliance and 2 or 1;
        for k = 1, n do
            local x = cx + (k - (n + 1) / 2) * r * 0.75;
            local y0, y1 = cy - r * 0.95, cy + r * 0.95;
            DL.L(dl, x, y0, x, y1, dark, 4);
            pcall(function()
                DL.RFM(dl, x - 1.2, y0, x + 1.2, y1, lead_mix(0, a), lead_mix(0, a), lead_mix(1, a), lead_mix(1, a));
            end);
            DL.CF(dl, x, y0 + 0.5, 2.2, U4(1, 1, 1, a), 10);   -- the bright tip, like the bars'
        end
    elseif style == 'gem' then
        local function diamond(rr, col, th)
            local p = { { cx, cy - rr }, { cx + rr * 0.72, cy }, { cx, cy + rr }, { cx - rr * 0.72, cy } };
            if th then for k = 1, 4 do dl:AddLine(p[k], p[k % 4 + 1], col, th); end
            else dl:AddTriangleFilled(p[1], p[2], p[3], col); dl:AddTriangleFilled(p[1], p[3], p[4], col); end
        end
        if alliance then diamond(r * 1.25, U4(0.62, 0.40, 1.0, 0.75 * a), 1.2); end
        diamond(r * 0.95, dark, 3);
        diamond(r * 0.95, U4(0.62, 0.40, 1.0, a));
        diamond(r * 0.52, U4(1.0, 0.42, 0.68, a));
        DL.CF(dl, cx - r * 0.12, cy - r * 0.28, math.max(1, r * 0.12), U4(1, 1, 1, 0.95 * a), 8);
    elseif style == 'halo' then
        local function ring(rr, th)
            local n = 28;
            for k = 0, n - 1 do
                local a0, a1 = k / n * math.pi * 2 - math.pi / 2, (k + 1) / n * math.pi * 2 - math.pi / 2;
                local u = (k < n / 2) and (k / (n / 2)) or ((n - k) / (n / 2));
                DL.L(dl, cx + math.cos(a0) * rr, cy + math.sin(a0) * rr, cx + math.cos(a1) * rr, cy + math.sin(a1) * rr, lead_mix(u, a), th);
            end
        end
        DL.C(dl, cx, cy, r * 0.82, dark, 24, 3.4);
        ring(r * 0.82, 1.8);
        if alliance then ring(r * 1.2, 1.1); end
        DL.CF(dl, cx, cy, r * 0.30, U4(1, 1, 1, a), 12);
    else                                                             -- crown
        local w, top, base = r * 1.15, cy - r * 0.62, cy + r * 0.55;
        local pts = { { cx - w, base }, { cx - w, top + r * 0.18 }, { cx - w * 0.48, cy - r * 0.02 }, { cx, top },
                      { cx + w * 0.48, cy - r * 0.02 }, { cx + w, top + r * 0.18 }, { cx + w, base } };
        for k = 1, #pts do dl:AddLine(pts[k], pts[k % #pts + 1], U4(0, 0, 0, 0.75 * a), 2.6); end
        local mid = { cx, base };
        local c1, c2 = U4(1.00, 0.86, 0.46, a), U4(0.96, 0.70, 0.26, a);
        for k = 2, #pts - 2 do dl:AddTriangleFilled(mid, pts[k], pts[k + 1], (k % 2 == 0) and c1 or c2); end
        dl:AddTriangleFilled(mid, pts[1], pts[2], c2);
        dl:AddTriangleFilled(mid, pts[#pts - 1], pts[#pts], c2);
        DL.L(dl, cx - w, base - r * 0.14, cx + w, base - r * 0.14, U4(0.70, 0.46, 0.14, a), 1);
        for _, k in ipairs({ 2, 4, 6 }) do dl:AddCircleFilled(pts[k], math.max(1, r * 0.16), U4(1, 0.97, 0.85, a), 8); end
        if alliance then
            DL.CF(dl, cx, cy + r * 0.16, r * 0.24, U4(1.0, 0.36, 0.62, a), 10);
            DL.CF(dl, cx + r * 0.06, cy + r * 0.12, r * 0.12, U4(0.62, 0.40, 1.0, a), 8);
        end
    end
end
-- "name" style: a glowing pink-to-violet line under the leader's name, a bright dot at its end (two for the alliance leader)
function LEAD_UNDERLINE(dl, x, y, w, alliance, a)
    pcall(function()
        DL.RFM(dl, x, y - 1, x + w, y + 2, lead_mix(0, 0.25 * a), lead_mix(1, 0.25 * a), lead_mix(1, 0.25 * a), lead_mix(0, 0.25 * a));
        DL.RFM(dl, x, y, x + w, y + 1.4, lead_mix(0, a), lead_mix(1, a), lead_mix(1, a), lead_mix(0, a));
    end);
    DL.CF(dl, x + w, y + 0.7, 2.2, U4(1, 1, 1, a), 10);
    if alliance then DL.CF(dl, x, y + 0.7, 2.2, U4(1, 1, 1, a), 10); end
end
local function member(i)
    local p = AshitaCore:GetMemoryManager():GetParty();
    if p:GetMemberIsActive(i) == 0 then
        if (i < 6 and PREVIEW.party) or (i >= 6 and PREVIEW.alliance) then
            local k = i % 6 + 1;
            local nm = (i < 6) and DEMO[k] or ('Ally ' .. (i - 5));
            for j = 0, 17 do                                         -- (never the name of someone really there: two cards would share a place)
                if p:GetMemberIsActive(j) ~= 0 and (p:GetMemberName(j) or '') == nm then nm = 'Member ' .. (i + 1); break; end
            end
            return { name = nm, zone = 0, job = (i * 7) % 22 + 1, lvl = 75, sub = (i * 5) % 22 + 1,
                     sublvl = 37, hp = 900 + i * 61, mp = 300 + i * 47, tp = (i * 450) % 3000, hpp = 1 - (i % 5) * 0.17,
                     mpp = 1 - (i % 4) * 0.2, idx = 0, inzone = true, fake = true, leader = (k == 1), aleader = (i == 0), far = (k == 5) };
        end
        return nil;
    end
    local m = { name = p:GetMemberName(i), zone = p:GetMemberZone(i), job = p:GetMemberMainJob(i), lvl = p:GetMemberMainJobLevel(i),
                sub = p:GetMemberSubJob(i), sublvl = p:GetMemberSubJobLevel(i), hp = p:GetMemberHP(i), mp = p:GetMemberMP(i),
                tp = p:GetMemberTP(i), hpp = p:GetMemberHPPercent(i) / 100, mpp = p:GetMemberMPPercent(i) / 100,
                idx = p:GetMemberTargetIndex(i) };
    m.inzone = (m.zone == p:GetMemberZone(0));
    if i == 0 and (m.job or 0) == 0 then                             -- (yourself, with the party list's job not filled in - solo, /anon: from
        pcall(function()                                             --  your own character, as the game's own menu shows it)
            local pl = AshitaCore:GetMemoryManager():GetPlayer();
            m.job, m.lvl = pl:GetMainJob() or 0, pl:GetMainJobLevel() or 0;
            m.sub, m.sublvl = pl:GetSubJob() or 0, pl:GetSubJobLevel() or 0;
            if (m.mpp or 0) == 0 and (pl:GetMPMax() or 0) > 0 then m.mpp = (m.mp or 0) / pl:GetMPMax(); end
        end);
    end
    if i ~= 0 and m.inzone then                                      -- how far they are: beyond spell range (or too far to be seen) = far
        pcall(function()
            if (m.idx or 0) == 0 then m.far = true; return; end
            local d2 = AshitaCore:GetMemoryManager():GetEntity():GetDistance(m.idx);
            if type(d2) == 'number' and d2 >= 0 then
                m.dist = math.sqrt(d2);
                m.far = m.dist > (tonumber(cfg.party_range) or 20.8);
            end
        end);
    end
    pcall(function()
        local sid = p:GetMemberServerId(i);
        local lead = (i < 6 and p:GetAlliancePartyLeaderServerId1()) or (i < 12 and p:GetAlliancePartyLeaderServerId2()) or p:GetAlliancePartyLeaderServerId3();
        m.leader = (sid ~= 0 and sid == lead);
        local al = p:GetAllianceLeaderServerId();
        local others = (p:GetAlliancePartyLeaderServerId2() or 0) ~= 0 or (p:GetAlliancePartyLeaderServerId3() or 0) ~= 0;
        m.aleader = others and sid ~= 0 and sid == al;               -- (only in an alliance)
        if i == 0 and (lead or 0) == 0 and (PREVIEW.party or PREVIEW.alliance) then   -- (alone, with pretend members: you lead them,
            m.leader, m.aleader = true, PREVIEW.alliance and true or false;           --  so the marks show while you place the lists)
        end
    end);
    return m;
end
-- Buffs and debuffs. Your own come from the game; the other party members' arrive in packet 0x076 (the server
-- doesn't send the alliance's). The icons are the game's own, made into pictures once each.
local DEBUFF = {};
for id in ('1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,28,29,30,31,128,129,130,131,132,133,134,135,136,137,' ..
    '138,139,140,141,142,143,144,145,146,147,148,149,155,156,168,171,172,173,174,175,186,189,192,193,194,223,259,260,261,262,' ..
    '263,264,291,298,299,309,391,392,393,394,395,396,397,398,399,400,448,449,450,451,452,404,557,536,558,559,560,561,562,563,' ..
    '564,565,566,567,572,576,597,798,805,630,631'):gmatch('%d+') do DEBUFF[tonumber(id)] = true; end
local party_buffs = {};                                             -- server id -> { status ids }
local function read_party_buffs(e)
    local t = {};
    for i = 0, 4 do
        local off = 0x04 + 0x30 * i + 1;
        local id = struct.unpack('L', e.data, off);
        if id > 0 then
            local list = {};
            for j = 0, 31 do
                local hi = bit.lshift(ashita.bits.unpack_be(e.data, off + 7, j * 2, 2), 8);  -- (the packet's bytes, as the low part)
                local b = hi + struct.unpack('B', e.data, off + 0x10 + j);
                if b == 255 then break; end
                list[#list + 1] = b;
            end
            t[id] = list;
        end
    end
    party_buffs = t;
end
local function member_buffs(i)
    local out = {};
    if i == 0 then
        local pl = AshitaCore:GetMemoryManager():GetPlayer();         -- (the game's own icons, as its buff bar: a Cursna'd Curse
        local ok, b = pcall(function() return pl:GetStatusIcons(); end);  --  leaves at once; else the buff list)
        if not (ok and type(b) == 'table') then b = pl:GetBuffs(); end
        if b then for k = 0, 32 do local v = tonumber(b[k]); if v and v > 0 and v ~= 255 then out[#out + 1] = v; end end end
    elseif i < 6 then
        local list = party_buffs[AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(i)];
        if list then for _, v in ipairs(list) do if v > 0 and v ~= 255 then out[#out + 1] = v; end end end
    end
    -- debuffs first, so they're easy to spot; otherwise the game's own order (kept steady, so nothing swaps places)
    local deb, rest = {}, {};
    for _, v in ipairs(out) do if DEBUFF[v] then deb[#deb + 1] = v; else rest[#rest + 1] = v; end end
    for _, v in ipairs(rest) do deb[#deb + 1] = v; end
    return deb;
end
local icons = {};
local function buff_icon(id, px)
    -- your redrawn sets (images/status/HD, XIView, Tetsouou: <id>.png); a missing one falls back to the game's icon
    local set = cfg.buff_set or 'HD';
    if set ~= 'game' then
        local name = 'status/' .. set .. '/' .. id .. '.png';
        px = px and math.floor(px + 0.5) or nil;
        if px and px >= 8 and px <= 128 then                         -- (made at the size it's drawn: crisp at any Size)
            local t = C.tex_at(name, px);
            if t then return t; end
        end
        local t = tex(name);
        if t then return t; end
    end
    if icons[id] ~= nil then return icons[id] or nil; end
    icons[id] = false;
    pcall(function()
        local info = AshitaCore:GetResourceManager():GetStatusIconByIndex(id);
        if info == nil or info.Bitmap == nil or (info.ImageSize or 0) <= 0 then return; end
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        if ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), info.Bitmap, info.ImageSize, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
                ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, ptr) == ffi.C.S_OK then
            local t = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
            icons[id] = { tex = t, ptr = tonumber(ffi.cast('uint32_t', t)) };
        end
    end);
    return icons[id] or nil;
end
local function buff_name(id)
    local ok, n = pcall(function() return AshitaCore:GetResourceManager():GetString('buffs.names', id); end);
    return (ok and n and n ~= '') and n or ('#' .. id);
end
-- Rows of icons (perrow per row, at most rows rows), going right from x (dir 1) or left from x (dir -1); hovering one
-- shows its name. Returns the width and height used.
-- Each party member's buffs can be folded away: click their job icon (cfg.buffs_off[name] = true). v per member goes
-- 0 (hidden) .. 1 (shown) over ~0.45 s; pop = when the icon was clicked (it bounces)
local BUFFS = { v = {}, pop = {}, last = nil, dt = 0 };
function BUFFS.tick()
    local now = os.clock();
    BUFFS.dt = BUFFS.last and math.min(0.1, now - BUFFS.last) or 0;
    BUFFS.last = now;
end
function BUFFS.off(key) return type(cfg.buffs_off) == 'table' and cfg.buffs_off[key] == true; end
function BUFFS.val(key)
    local want = BUFFS.off(key) and 0 or 1;
    local v = BUFFS.v[key] or want;
    if v < want then v = math.min(want, v + BUFFS.dt / 0.45); elseif v > want then v = math.max(want, v - BUFFS.dt / 0.45); end
    BUFFS.v[key] = v;
    return v;
end
function BUFFS.flip(key)
    local t = {};
    if type(cfg.buffs_off) == 'table' then for k, v in pairs(cfg.buffs_off) do if v == true and k ~= key then t[k] = true; end end end
    if not BUFFS.off(key) then t[key] = true; end                    -- (a plain table: saved tables come back as T{})
    cfg.buffs_off = t;
    BUFFS.pop[key] = os.clock();
    save();
end
-- One buff's share of the fold: the ones nearest the job icon come out first and go back last (a ripple)
function BUFFS.part(v, k, n)
    local st = 0.10;
    local p = v * (1 + (n - 1) * st) - (k - 1) * st;
    p = math.max(0, math.min(1, p));
    return p, 1 - (1 - p) ^ 3;
end
local function draw_buffs(dl, x, y, list, size, perrow, rows, dir, timers, fold, tips)   -- (tips: hovering an icon shows its name and time left)
    local mx, my = imgui.GetMousePos();
    local n = math.min(#list, perrow * rows);
    if fold and fold <= 0 then return 0, 0; end
    local th = 0;                                                   -- timers: a small line of seconds under each icon
    if timers and next(timers) then                                  -- (its size grows with the icons; TARGET > Debuff timer size on top)
        local tk = math.max(0.5, math.min(2.5, BUFFS.tk or tonumber(cfg.buff_timer_scale) or 1));   -- (BUFFS.tk: the enemy list's own text size)
        imgui.SetWindowFontScale(math.max(0.55, math.min(2.6, 0.72 * (size / 22) * tk)));
        th = imgui.GetTextLineHeight();
    end
    for k = 1, n do
        local id = list[k];
        local c, r = (k - 1) % perrow, math.floor((k - 1) / perrow);
        local ix = (dir == -1) and (x - (c + 1) * (size + 2) + 2) or (x + c * (size + 2));
        local iy = y + r * (size + 2 + th);
        if fold and fold < 1 then                                    -- folding: each slides in from / back to the job icon
            local p, e = BUFFS.part(fold, c + 1, math.min(n, perrow));
            if p <= 0 then goto next_buff; end
            local ox = (dir == -1) and (x - size) or x;              -- (where they fold to: next to the job icon)
            local fx = ox + (ix - ox) * e;
            local k = 0.45 + 0.55 * e;                               -- small while tucked away
            local cx, cy = fx + size / 2, iy + size / 2;
            if p < 1 then                                            -- a short pink-to-violet streak behind it as it moves
                local tail = (dir == -1) and (cx + size * 0.9 * (1 - e)) or (cx - size * 0.9 * (1 - e));
                DL.L(dl, cx, cy, tail, cy, U4(1.0, 0.36, 0.62, 0.35 * p * (1 - p) * 4), size * 0.35);
                DL.L(dl, cx, cy, tail, cy, U4(0.85, 0.70, 1.0, 0.6 * p * (1 - p) * 4), 1.2);
            end
            image(dl, buff_icon(id), cx - size * k / 2, cy - size * k / 2, cx + size * k / 2, cy + size * k / 2, { 1, 1, 1, math.min(1, p * 1.6) });
            goto next_buff;
        end
        ix, iy = math.floor(ix + 0.5), math.floor(iy + 0.5);           -- (on whole pixels: the icon's pixels land on the screen's)
        image(dl, buff_icon(id, size), ix, iy, ix + size, iy + size);
        if tips and mx >= ix and mx < ix + size and my >= iy and my < iy + size then   -- (TARGET > Debuff details on hover)
            local secs_ = timers and timers[id];
            local tl = nil;
            if secs_ then
                local sec = math.max(0, math.ceil(secs_));
                tl = (sec >= 60) and string.format('%d:%02d left', math.floor(sec / 60), sec % 60) or string.format('%ds left', sec);
            end
            DL.R(dl, ix - 1, iy - 1, ix + size + 1, iy + size + 1, U4(1, 1, 1, 0.8), 2, C.rall, 1.2);
            YUI_TIP(buff_name(id) .. (tl and ('\n' .. tl) or ''));
        end
        local secs = timers and timers[id];
        if secs then
            local str = (secs >= 100) and string.format('%dm', math.floor(secs / 60 + 0.5)) or string.format('%d', math.ceil(secs));
            local tw = imgui.CalcTextSize(str);
            text(dl, ix + (size - tw) / 2, iy + size, str, (secs <= 10) and { 1, 0.55, 0.55, 1 } or { 1, 1, 1, 0.95 });
        end
        ::next_buff::
    end
    if th > 0 then imgui.SetWindowFontScale(1); end
    if n == 0 then return 0, 0; end
    return math.min(n, perrow) * (size + 2), math.ceil(n / perrow) * (size + 2 + th);
end

-- Debuffs on enemies (XIUI's way): the server never lists a monster's effects, so they're followed from the action
-- packets (0x028: "is afflicted with...", Dia/Bio and the like) and dropped on "wears off" / death (0x029).
local SPELL_DEBUFF = {};
for k, v in ('230=135,231=135,232=135,23=134,33=134,24=134,25=134,58=4,80=4,56=13,79=13,357=13,216=12,217=12,254=5,276=5,361=5,59=6,359=6,253=2,' ..
    '259=19,273=2,274=19,258=11,362=11,252=10,220=3,221=3,222=3,223=3,224=3,225=3,226=3,227=3,228=3,229=3,239=132,238=131,' ..
    '237=130,236=129,235=128,240=133,421=194,422=194,423=194,368=192,369=192,370=192,371=192,372=192,373=192,374=192,376=193,' ..
    '377=193,463=193,471=193,466=14,472=223,454=217,455=217,456=217,457=217,458=217,459=217,460=217,461=217,597=13,341=4,' ..
    '342=4,343=4,344=13,345=13,346=13,347=5,348=5,349=5,350=3,351=3,352=3,319=147,508=168,286=21,256=31,257=9,98=19,356=4,' ..
    '366=12,255=7,365=7,278=186,279=186,280=186,281=186,282=186,283=186,284=186,285=186'):gmatch('(%d+)=(%d+)') do
    SPELL_DEBUFF[tonumber(k)] = tonumber(v);
end
local function set_of(s) local t = {}; for n in s:gmatch('%d+') do t[tonumber(n)] = true; end return t; end
local MSG_ON    = set_of('127,160,164,166,186,194,203,205,230,236,266,267,268,269,237,271,272,277,278,279,280,319,320,375,412,645,754,755,804');
local MSG_OFF   = set_of('64,83,159,168,204,206,321,322,341,342,343,344,350,378,531,647,805,806');
local MSG_DEATH = set_of('6,20,97,113,406,605,646');
local MSG_SPELLDMG = set_of('2,252,264,265');
local DEBUFF_TIME = { [2] = 60, [19] = 90, [193] = 60, [11] = 60, [10] = 5, [4] = 120, [13] = 180, [5] = 180, [6] = 120,
                      [12] = 120, [3] = 90, [134] = 120, [135] = 120, [7] = 60, [28] = 60, [21] = 60 };
local enemies = {};                                                 -- server id -> { [status] = expiry time }
local DEBUFF_DB = {};                                               -- debuff_durations.lua: how long each spell / WS / JA's lasts
pcall(function()
    local fn = loadfile(addon.path .. '/debuff_durations.lua');
    if fn then DEBUFF_DB = fn() or {}; end
end);
-- how long a debuff lasts: by what caused it (action kind: 4 spell, 3 weapon skill, 6/14/15 ability, 11/13 pet), else by
-- the debuff itself
local function debuff_secs(kind, param, status)
    local e = nil;
    if kind == 4 then e = DEBUFF_DB.spells and DEBUFF_DB.spells[param];
    elseif kind == 3 then e = DEBUFF_DB.weaponSkills and DEBUFF_DB.weaponSkills[param];
    elseif kind == 6 or kind == 14 or kind == 15 then e = (DEBUFF_DB.ja and DEBUFF_DB.ja[param]) or (DEBUFF_DB.jaPhysical and DEBUFF_DB.jaPhysical[param]);
    elseif kind == 11 or kind == 13 then e = DEBUFF_DB.pet and DEBUFF_DB.pet[param]; end
    local d = (type(e) == 'table') and tonumber(e.duration) or nil;
    return d or DEBUFF_TIME[status] or 180;
end
-- the 2-hours a monster can use (as a job ability or a mob skill id): debuff_durations.lua's ja table gives their effect
C.MOB2HR = { [16] = true, [17] = true, [19] = true, [20] = true, [21] = true, [22] = true, [23] = true, [688] = true, [690] = true,
             [691] = true, [692] = true, [693] = true, [694] = true, [695] = true, [696] = true, [730] = true, [1933] = true };
local function enemy_add(id, status, secs)
    if id == nil or id == 0 or status == nil or status <= 0 or status == 255 then return; end
    enemies[id] = enemies[id] or {};
    if status == 134 then enemies[id][135] = nil; elseif status == 135 then enemies[id][134] = nil; end   -- (Dia and Bio overwrite each other)
    enemies[id][status] = os.clock() + (secs or DEBUFF_TIME[status] or 180);
end
C.MSG_PHYS = set_of('103,110,185,187,238,242,317,802');              -- (a physical hit: melee, ability or weapon skill)
C.MSG_JAONLY = set_of('110,317');                                    -- (only an ability says these)
function C.ja_hit(tid, kind, param, m)                               -- an ability that hit: its hidden effect (a Bash's stun), on the monster
    if not (kind == 3 or kind == 6 or kind == 14) or not C.MSG_PHYS[m] then return; end
    local id = param % 65536;
    local jid = (id >= 512 and id < 1024) and (id - 512) or id;
    if kind == 3 and jid == id and not C.MSG_JAONLY[m] then return; end   -- (a weapon skill's id, not an ability's)
    local e = DEBUFF_DB.jaPhysical and (DEBUFF_DB.jaPhysical[jid] or DEBUFF_DB.jaPhysical[id]);
    if type(e) ~= 'table' or not e.buffId then return; end
    local ids = e.buffIds or { e.buffId };
    for _, b in ipairs(ids) do
        enemy_add(tid, b, (e.buffDurations and e.buffDurations[b]) or e.duration);
    end
end
local function enemy_off(id, status)
    if enemies[id] then enemies[id][status] = nil; end
    local pb = party_buffs[id];                                     -- (a party member's: off their card now, not at the next update)
    if pb then for k = #pb, 1, -1 do if pb[k] == status then table.remove(pb, k); end end end
end
-- Enemy list (XIUI's way): a monster joins the list when it acts on you or a party member, or when its claim passes to
-- one of you (packet 0x00E); it leaves when it dies, despawns or goes out of sight, and on zoning.
local ENGAGED = {};                                                 -- entity index -> true
-- Target of target (XIUI's way): who each one last hit with an attack, spell or skill (types 1, 4, 7, 11), for 30 s
local LASTHIT = {};                                                 -- server id -> { id = its target's server id, t = time }
local PIDS = { at = 0, ids = {} };
local function is_party_id(id)
    if id == nil or id == 0 then return false; end
    if os.clock() >= PIDS.at then
        PIDS.at = os.clock() + 1;
        PIDS.ids = {};
        pcall(function()
            local p = AshitaCore:GetMemoryManager():GetParty();
            local ent = AshitaCore:GetMemoryManager():GetEntity();
            for i = 0, 17 do
                if p:GetMemberIsActive(i) ~= 0 then
                    PIDS.ids[p:GetMemberServerId(i)] = true;
                    pcall(function()                                 -- (and their pet: automaton, avatar, wyvern...)
                        local ti = p:GetMemberTargetIndex(i);
                        local pi = (ti and ti > 0) and ent:GetPetTargetIndex(ti) or 0;
                        if pi and pi > 0 then local ps = ent:GetServerId(pi); if ps and ps ~= 0 then PIDS.ids[ps] = true; end end
                    end);
                end
            end
        end);
    end
    return PIDS.ids[id] == true;
end
local function index_of(id)
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    local guess = bit.band(id, 0xFFF);
    if ent:GetServerId(guess) == id then return guess; end
    for i = 0, 2303 do if ent:GetServerId(i) == id then return i; end end
    return nil;
end
local function engage(mob_id)
    pcall(function()
        local idx = index_of(mob_id);
        if idx and idx < 0x400 and not is_party_id(mob_id) and bit.band(AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(idx), 0x10) ~= 0 then ENGAGED[idx] = true; end   -- (monsters only: never trusts, pets or players)
    end);
end
local function read_claim(e)
    local idx = struct.unpack('H', e.data, 0x08 + 1);
    local flags = struct.unpack('B', e.data, 0x0A + 1);
    if bit.band(flags, 0x02) == 0x02 then
        local claim = struct.unpack('L', e.data, 0x2C + 1);
        if idx < 0x400 and is_party_id(claim) then ENGAGED[idx] = true; end
    end
end

-- Your casting (XIUI's way): an action packet from you of type 8 (spell) or 9 (item) with param 0x6163 starts it
-- (the spell / item id is in the first action), 28787 there means interrupted; type 4 / 5 is the cast landing.
SUBPREVIEW = nil;                                                   -- set later: true while the BARS tab is open (previews)
local CAST = { on = false, name = '', t0 = 0, done = 0, broke = false, preview = false };
local function cast_event(actor, kind, param, first)
    local me = 0;
    pcall(function() me = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0); end);
    if actor == 0 or actor ~= me then return; end
    local rm = AshitaCore:GetResourceManager();
    if (kind == 8 or kind == 9) and param == 0x6163 then
        local name = '';
        pcall(function()
            local r = (kind == 8) and rm:GetSpellById(first) or rm:GetItemById(first);
            name = (r and r.Name and r.Name[1]) or '';
        end);
        CAST.on, CAST.name, CAST.t0, CAST.broke = true, name, os.clock(), false;
    elseif (kind == 8 or kind == 9) and param == 28787 then
        if CAST.on then CAST.on, CAST.done, CAST.broke = false, os.clock(), true; end
    elseif kind == 4 or kind == 5 then
        if CAST.on then CAST.on, CAST.done, CAST.broke = false, os.clock(), false; end
    end
end
-- In the fight, read from the action packets (0x028), shown over your target's name:
--   casts[mob]: what a monster is casting or readying (spell: its cast time; TP move: ~3 s), gone when it lands or breaks
--   sc[mob]: the party's last weapon skill on it (the window to chain) and the skillchain it made (the Magic Burst window)
local FIGHT = { casts = {}, sc = {} };
FIGHT.SC = {                                                        -- skillchain message -> its name and the burst elements
    [288] = { 'Light', { 'Fire', 'Wind', 'Thunder', 'Light' } }, [289] = { 'Darkness', { 'Ice', 'Earth', 'Water', 'Dark' } },
    [290] = { 'Gravitation', { 'Earth', 'Dark' } }, [291] = { 'Fragmentation', { 'Wind', 'Thunder' } },
    [292] = { 'Distortion', { 'Ice', 'Water' } }, [293] = { 'Fusion', { 'Fire', 'Light' } }, [294] = { 'Compression', { 'Dark' } },
    [295] = { 'Liquefaction', { 'Fire' } }, [296] = { 'Induration', { 'Ice' } }, [297] = { 'Reverberation', { 'Water' } },
    [298] = { 'Transfixion', { 'Light' } }, [299] = { 'Scission', { 'Earth' } }, [300] = { 'Detonation', { 'Wind' } },
    [301] = { 'Impaction', { 'Thunder' } }, [767] = { 'Radiance', { 'Fire', 'Wind', 'Thunder', 'Light' } },
    [768] = { 'Umbra', { 'Ice', 'Earth', 'Water', 'Dark' } },
};
for k = 0, 13 do FIGHT.SC[385 + k] = FIGHT.SC[288 + k]; end         -- (the same chains, made with magic)
FIGHT.SC[769], FIGHT.SC[770] = FIGHT.SC[767], FIGHT.SC[768];
FIGHT.ELEM = { Fire = { 1.0, 0.36, 0.25 }, Ice = { 0.55, 0.90, 1.0 }, Wind = { 0.45, 0.95, 0.55 }, Earth = { 0.90, 0.72, 0.35 },
               Thunder = { 0.78, 0.50, 1.0 }, Water = { 0.35, 0.60, 1.0 }, Light = { 1.0, 1.0, 0.92 }, Dark = { 0.55, 0.30, 0.75 } };
FIGHT.CHAIN_WAIT, FIGHT.CHAIN_END, FIGHT.BURST = 3.0, 8.0, 8.0;      -- (seconds: a chain can close from 3 to 8 s; burst ~8 s)
-- (XIUI's logic, handlers/enemycasts.lua: type 7 = a TP move starts (message 0 = it broke), type 8 = a spell starts (the
-- same spell again = it broke), type 4 / 11 = it landed unless the message is 16 / 84 / 106 (interrupted, paralyzed,
-- intimidated); 0x029 with those messages breaks it too)
FIGHT.BREAK = { [16] = true, [84] = true, [106] = true };
function FIGHT.readies_name(line)                                    -- (a TP move still unnamed, started just now: named from its chat line)
    local nm = line:gsub('[\1\2]', ''):match(' readies (.-)%.?$');
    if not nm or nm == '' or not nm:find('%w') then return; end
    local best, bt = nil, -1;
    for _, c in pairs(FIGHT.casts) do
        if c.pending and os.clock() - c.t0 < 2 and c.t0 > bt then best, bt = c, c.t0; end
    end
    if best then best.name, best.pending = nm, nil; end
end
function FIGHT.broke(actor)
    local c = FIGHT.casts[actor];
    if c and not c.broke then c.broke = os.clock(); c.at = math.min(1, (os.clock() - c.t0) / c.dur); end
end
function FIGHT.on_action(actor, kind, param, p, m, tid)
    local now = os.clock();
    local rm = AshitaCore:GetResourceManager();
    if not is_party_id(actor) then
        if kind == 7 then                                            -- a TP move (or an ability) starts
            if m == 0 or param == 28787 then FIGHT.broke(actor); return; end
            local name = nil;
            pcall(function()
                if p < 256 then
                    local r = rm:GetAbilityById(p);
                    name = r and r.Name and r.Name[1] or nil;
                else
                    local n = rm:GetString('monsters.abilities', p - 256);
                    if type(n) == 'string' and n ~= '' then name = n:gsub('%z.*$', ''); end
                end
            end);
            if name and not name:find('%w') then name = nil; end    -- (a blank entry - "." - in the list: the chat line will name it)
            if name and name ~= '' then FIGHT.casts[actor] = { name = name, t0 = now, dur = 3, kind = 'tp', tid = tid };
            else FIGHT.casts[actor] = { name = '...', t0 = now, dur = 3, kind = 'tp', tid = tid, pending = true }; end
        elseif kind == 8 then                                        -- a spell starts (the same one again: it broke)
            local c = FIGHT.casts[actor];
            if param == 28787 or (c and c.spell == p and not c.broke) then FIGHT.broke(actor); return; end
            local name, dur = nil, 3;
            pcall(function()
                local r = rm:GetSpellById(p);
                if r and r.Name then name = r.Name[1]; dur = math.max(0.5, (tonumber(r.CastTime) or 12) / 4); end
            end);
            if name and name ~= '' then FIGHT.casts[actor] = { name = name, t0 = now, dur = dur, kind = 'spell', spell = p, tid = tid }; end
        elseif kind == 4 or kind == 11 then                          -- it landed, or broke (paralyzed, intimidated...)
            if FIGHT.BREAK[m] then FIGHT.broke(actor); else FIGHT.casts[actor] = nil; end
        end
    end
end
-- Skillchains, the way the Chains addon works it out (Sippius, from Ivaar's skillchains; skillchains.lua is its
-- skills.lua, BSD licence): each weapon skill / spell / pet move has properties; the first one on a monster opens them
-- (wait = its delay, the window lasts 7 + delay s); a skill whose property meets one of them makes a skillchain (the
-- added effect carries which: 1..16), opening that one (window 8 - step + delay s) and the Magic Burst.
FIGHT.SKILLS = {};
pcall(function() local fn = loadfile(addon.path .. '/skillchains.lua'); if fn then FIGHT.SKILLS = fn() or {}; end end);
FIGHT.PROP = { 'Light', 'Darkness', 'Gravitation', 'Fragmentation', 'Distortion', 'Fusion', 'Compression', 'Liquefaction',
               'Induration', 'Reverberation', 'Transfixion', 'Scission', 'Detonation', 'Impaction', 'Radiance', 'Umbra' };
FIGHT.MSG = { [2] = true, [110] = true, [185] = true, [187] = true, [317] = true, [802] = true };
FIGHT.PETMSG = { [110] = true, [317] = true };
FIGHT.SCMSG = {};                                                    -- the added-effect messages of a skillchain (damage, healing...)
for _, id in ipairs({ 288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 385, 386, 387, 388, 389, 390, 391,
                      392, 393, 394, 395, 396, 397, 398, 399, 732, 767, 768, 769, 770 }) do FIGHT.SCMSG[id] = true; end
FIGHT.CHAIN = {                                                     -- opened property -> { level, burst, [closing property] = result }
    Radiance = { 4, { 'Fire', 'Wind', 'Thunder', 'Light' } }, Umbra = { 4, { 'Earth', 'Ice', 'Water', 'Dark' } },
    Light = { 3, { 'Fire', 'Wind', 'Thunder', 'Light' }, Light = { 4, 'Light' } },
    Darkness = { 3, { 'Earth', 'Ice', 'Water', 'Dark' }, Darkness = { 4, 'Darkness' } },
    Gravitation = { 2, { 'Earth', 'Dark' }, Distortion = { 3, 'Darkness' }, Fragmentation = { 2, 'Fragmentation' } },
    Fragmentation = { 2, { 'Wind', 'Thunder' }, Fusion = { 3, 'Light' }, Distortion = { 2, 'Distortion' } },
    Distortion = { 2, { 'Ice', 'Water' }, Gravitation = { 3, 'Darkness' }, Fusion = { 2, 'Fusion' } },
    Fusion = { 2, { 'Fire', 'Light' }, Fragmentation = { 3, 'Light' }, Gravitation = { 2, 'Gravitation' } },
    Compression = { 1, { 'Dark' }, Transfixion = { 1, 'Transfixion' }, Detonation = { 1, 'Detonation' } },
    Liquefaction = { 1, { 'Fire' }, Impaction = { 2, 'Fusion' }, Scission = { 1, 'Scission' } },
    Induration = { 1, { 'Ice' }, Reverberation = { 2, 'Fragmentation' }, Compression = { 1, 'Compression' }, Impaction = { 1, 'Impaction' } },
    Reverberation = { 1, { 'Water' }, Induration = { 1, 'Induration' }, Impaction = { 1, 'Impaction' } },
    Transfixion = { 1, { 'Light' }, Scission = { 2, 'Distortion' }, Reverberation = { 1, 'Reverberation' }, Compression = { 1, 'Compression' } },
    Scission = { 1, { 'Earth' }, Liquefaction = { 1, 'Liquefaction' }, Reverberation = { 1, 'Reverberation' }, Detonation = { 1, 'Detonation' } },
    Detonation = { 1, { 'Wind' }, Compression = { 2, 'Gravitation' }, Scission = { 1, 'Scission' } },
    Impaction = { 1, { 'Thunder' }, Liquefaction = { 1, 'Liquefaction' }, Detonation = { 1, 'Detonation' } },
};
FIGHT.PCOL = { Light = { 1, 1, 0.92 }, Darkness = { 0.62, 0.38, 0.85 }, Gravitation = { 0.72, 0.50, 0.38 },
               Fragmentation = { 0.78, 0.60, 1.0 }, Distortion = { 0.45, 0.72, 1.0 }, Fusion = { 1.0, 0.58, 0.32 },
               Compression = { 0.62, 0.45, 0.82 }, Liquefaction = { 1.0, 0.40, 0.28 }, Induration = { 0.55, 0.90, 1.0 },
               Reverberation = { 0.40, 0.62, 1.0 }, Transfixion = { 1, 1, 0.92 }, Scission = { 0.90, 0.72, 0.35 },
               Detonation = { 0.45, 0.95, 0.55 }, Impaction = { 0.80, 0.52, 1.0 }, Radiance = { 1, 1, 1 }, Umbra = { 0.55, 0.30, 0.75 } };
-- SCH Immanence, BLU Chain Affinity: the next spell of that player can open or close a skillchain. It shows from the
-- moment the cast starts (the fan waits in rose for it to land, the Magic Burst card comes up at once), so the party
-- can get ready - and burst casts started - before it lands; when it lands the exact window takes over.
FIGHT.READY = { [317] = true, [94] = true };
FIGHT.ready, FIGHT.pre = {}, {};
function FIGHT.early(actor, param, spell, tid, rdy)
    local e = FIGHT.pre[actor];
    if param == 28787 then                                           -- (the cast broke: back to what was there)
        if e and FIGHT.sc[e.tid] == e.st then FIGHT.sc[e.tid] = e.st.prev; end
        FIGHT.pre[actor] = nil;
        return;
    end
    local sk = rdy and FIGHT.SKILLS[4] and FIGHT.SKILLS[4][spell or 0] or nil;
    if sk == nil then return; end
    local ct = 3;
    pcall(function()
        local r = AshitaCore:GetResourceManager():GetSpellById(spell);
        if r then ct = math.max(0.5, (tonumber(r.CastTime) or 12) / 4); end
    end);
    local now, old = os.clock(), FIGHT.sc[tid];
    if old and old.early then old = old.prev; end
    local hit = nil;
    if old and not old.closed and now + ct < old.ts + old.dur then     -- (it lands while the window is open: what it would make)
        for _, p1 in ipairs(old.property or {}) do
            local row = FIGHT.CHAIN[p1];
            if row then for _, p2 in ipairs(sk.skillchain or {}) do if row[p2] then hit = row[p2]; break; end end end
            if hit then break; end
        end
    end
    local st;
    if hit then                                                      -- it closes one: the Magic Burst card now
        local step = (old.step or 1) + 1;
        local level = hit[1];
        if level == 3 and old.property[1] == hit[2] then level = 4; end
        st = { en = sk.en, property = { hit[2] }, ts = now, dur = ct + 8 - step + 3, wait = ct, step = step,
               closed = (level == 4), chain = hit[2], elems = FIGHT.CHAIN[hit[2]] and FIGHT.CHAIN[hit[2]][2] or {} };
    else                                                             -- it opens its own properties
        st = { en = sk.en, property = sk.skillchain or {}, ts = now, dur = ct + 10, wait = ct + 3, step = 1 };
    end
    st.early, st.prev = true, old;
    FIGHT.sc[tid] = st;
    FIGHT.pre[actor] = { tid = tid, st = st };
end
-- A party member's skill on a monster (its first target and action, with the added effect's property if any)
function FIGHT.on_skill(actor, kind, param, m, tid, ap, first)
    if tid == nil or tid == 0 or not is_party_id(actor) then return; end
    local rdy = FIGHT.ready[actor] ~= nil and os.clock() - FIGHT.ready[actor] < 60;
    if kind == 6 and FIGHT.READY[param] then FIGHT.ready[actor] = os.clock(); return; end
    if kind == 8 then return FIGHT.early(actor, param, first, tid, rdy); end
    local cat = FIGHT.PETMSG[m] and 13 or kind;
    local sk = FIGHT.SKILLS[cat] and FIGHT.SKILLS[cat][bit.band(param or 0, 0xFFFF)] or nil;
    if sk == nil then return; end
    local prop = ap and FIGHT.PROP[bit.band(ap, 0x3F)] or nil;
    local now, old = os.clock(), FIGHT.sc[tid];
    local pre = (kind == 4) and FIGHT.pre[actor] or nil;
    if kind == 4 then FIGHT.ready[actor], FIGHT.pre[actor] = nil, nil; end
    if old and old.early then                                        -- (the early one: the real thing replaces it)
        if pre and FIGHT.sc[tid] == pre.st then FIGHT.sc[tid] = old.prev; end
        old = old.prev;
    end
    local delay = sk.delay or 3;
    if prop and FIGHT.CHAIN[prop] then                               -- it made a skillchain
        local step = ((old and old.step) or 1) + 1;
        local level = FIGHT.CHAIN[prop][1];
        if level == 3 and old and old.property and old.property[1] == prop then level = 4; end
        FIGHT.sc[tid] = { en = sk.en, property = { prop }, ts = now, dur = 8 - step + delay, wait = delay, step = step,
                          closed = (level == 4), chain = prop, elems = FIGHT.CHAIN[prop][2] };
    elseif FIGHT.MSG[m] and (kind ~= 4 or rdy) then                  -- the first step: it opens its own properties (a spell: under Immanence / Chain Affinity)
        FIGHT.sc[tid] = { en = sk.en, property = sk.skillchain or {}, ts = now, dur = 7 + delay, wait = delay, step = 1 };
    elseif m == 529 then                                             -- "... is chainbound" (SAM Konzen-ittai, DNC Wild Flourish): opens theirs
        FIGHT.sc[tid] = { en = sk.en, property = sk.skillchain or {}, ts = now, dur = 9, wait = 2, step = 1 };
    end
end
-- Your weapon skills now (from the game: which ones you have), refreshed every few seconds
function FIGHT.mine()
    local now = os.clock();
    if FIGHT.mine_at and now < FIGHT.mine_at then return FIGHT.mine_list or {}; end
    FIGHT.mine_at = now + 3;
    local out = {};
    pcall(function()
        local pl = AshitaCore:GetMemoryManager():GetPlayer();
        for k, v in pairs(FIGHT.SKILLS[3] or {}) do if v and pl:HasWeaponSkill(k) then out[#out + 1] = v; end end
    end);
    FIGHT.mine_list = out;
    return out;
end
-- What each of your weapon skills would make on what's open now (best first): { name, result, level }
function FIGHT.options(st)
    local res = {};
    for _, ws in ipairs(FIGHT.mine()) do
        for _, p1 in ipairs(st.property or {}) do
            local row, hit = FIGHT.CHAIN[p1], nil;
            if row then for _, p2 in ipairs(ws.skillchain or {}) do if row[p2] then hit = row[p2]; break; end end end
            if hit then
                local lvl = hit[1];
                if lvl == 3 and p1 == hit[2] then lvl = 4; end
                res[#res + 1] = { ws.en, hit[2], lvl };
                break;
            end
        end
    end
    table.sort(res, function(a, b) if a[3] ~= b[3] then return a[3] > b[3]; end return a[1] < b[1]; end);
    return res;
end
-- The UI's own font (AvantGarde) at px for the fight lines; gives back what to put back afterwards
function FIGHT.font(px)
    local keep = FS or 1;
    local pushed = sized('chat', px);
    return { pushed, keep };
end
function FIGHT.unfont(k)
    if k[1] then imgui.PopFont(); end
    FS = k[2];
    imgui.SetWindowFontScale(k[2]);
end
-- The Magic Burst window over the target's name, after a skillchain: MAGIC BURST and the chain, the elements to burst
-- with, and the time left as a thin bar (violet to ice blue). (It was lost once in a restyle: put back 2026-10-19.)
function FIGHT.draw(dl, sid, x, y, w, sc, side)
    if sid == nil or sid == 0 then return; end
    local now = os.clock();
    local fs = FS or 1;
    local k = (side == 'left' or side == 'center') and math.max(0.3, math.min(2.0, tonumber(cfg.hl_mb) or 0.8)) or math.max(0.5, math.min(2.5, tonumber(cfg.mb_scale) or 1));   -- (TARGET > Magic Burst size; unused since the Banner)
    local s2 = sc * k;
    pcall(function() C.fullclip(dl); end);
    imgui.SetWindowFontScale(fs * 0.80 * k);
    local lh = imgui.GetTextLineHeight();
    local st = FIGHT.sc[sid];
    if st and st.chain and cfg.show_mb ~= false then                 -- (TARGET > Magic Burst: off - not drawn)
        local t = now - st.ts;
        if t < st.dur then
            local all = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15;
            local pc = FIGHT.PCOL[st.chain] or { 1, 1, 1 };
            local left = 1 - t / math.max(0.1, st.dur);
            local pop = math.max(0, 1 - t / 0.4);
            local al = math.min(1, t / 0.15);                        -- (it fades in)
            local padx, pady = 10 * s2, 5 * s2;
            local row = y - lh - 6 * sc - pady;
            local lab = 'MAGIC BURST';
            local w1 = imgui.CalcTextSize(lab);
            local w2 = imgui.CalcTextSize(st.chain);
            local r = lh * 0.26;
            local dotsw = 0;
            for _ in ipairs(st.elems or {}) do dotsw = dotsw + r * 2 + 5 * s2; end
            local bw, bh = 110 * s2, math.max(2, math.floor(3 * s2));
            local secw = imgui.CalcTextSize('0.0') + 8 * s2;               -- (the seconds left, after the bar)
            local x0 = x;
            local grow = 1;
            if side == 'left' then                                   -- (Hex link: right-aligned at x - the line's bend - centred on y; it pops
                x0 = x - (padx + w1 + 10 * s2 + 10 * s2 + w2 + 8 * s2 + dotsw + 6 * s2 + bw + secw + padx);   --  out of the bend, growing leftward)
                row = y - lh / 2;
                grow = 1 - (1 - math.min(1, t / 0.28)) ^ 3;
            elseif side == 'center' then                             -- (Hex link, by you: centred on x, its row's middle on y)
                x0 = x - (padx + w1 + 10 * s2 + 10 * s2 + w2 + 8 * s2 + dotsw + 6 * s2 + bw + secw + padx) / 2;
                row = y - lh / 2;
            end
            local sepx = x0 + padx + w1 + 10 * s2;
            local x1 = sepx + 10 * s2 + w2 + 8 * s2 + dotsw + 6 * s2 + bw + secw + padx;
            local y0, y1 = row - pady, row + lh + pady;
            local rr = 6 * s2;
            local br = 0.5 + 0.5 * math.sin(now * 5);
            local gclip = grow < 1;
            if gclip then                                            -- (still growing: only the part out of the bend shows)
                local gx = x1 - (x1 - x0) * grow;
                pcall(function() C.clip(dl, { gx, y0 - 8 }, { x1 + 8, y1 + 8 }, true); end);
            end
            for g = 3, 1, -1 do                                      -- a soft glow in the chain's colour, breathing
                local gp = g * 2;
                DL.R(dl, x0 - gp, y0 - gp, x1 + gp, y1 + gp, U4(pc[1], pc[2], pc[3], 0.06 * (4 - g) * al * (0.6 + 0.4 * br)), rr + gp, all, 3);
            end
            DL.RF(dl, x0, y0, x1, y1, U4(0.045, 0.040, 0.065, 0.88 * al), rr);   -- the card (the fan's Tab look)
            FIGHT.drawn.mb = { x0, y0, x1 - x0, y1 - y0, now };
            pcall(function()                                         -- (the chain's part a little lighter)
                C.clip(dl, { sepx, y0 - 2 }, { x1 + 2, y1 + 2 }, true);
                DL.RF(dl, x0, y0, x1, y1, U4(0.09, 0.08, 0.12, 0.88 * al), rr);
                dl:PopClipRect();
            end);
            DL.R(dl, x0, y0, x1, y1, U4(pc[1], pc[2], pc[3], 0.70 * al), rr, all, 1);
            DL.L(dl, sepx, y0 + 3, sepx, y1 - 3, U4(1, 1, 1, 0.14 * al), 1);
            text(dl, x0 + padx, row, lab, { 0.86, 0.84, 0.94, al });
            local cx = sepx + 10 * s2;
            text(dl, cx, row, st.chain, { pc[1] * 0.4 + 0.6, pc[2] * 0.4 + 0.6, pc[3] * 0.4 + 0.6, al });
            cx = cx + w2 + 8 * s2;
            for _, e in ipairs(st.elems or {}) do                    -- the elements to burst with
                local ec = FIGHT.ELEM[e] or { 1, 1, 1 };
                local rp = r * (1 + 0.5 * pop);
                DL.CF(dl, cx + r, row + lh / 2, rp + 1, U4(0, 0, 0, 0.6 * al), 12);
                DL.CF(dl, cx + r, row + lh / 2, rp, U4(ec[1], ec[2], ec[3], al), 12);
                cx = cx + r * 2 + 5 * s2;
            end
            local bx, by = cx + 6 * s2, row + lh / 2 - bh / 2;       -- the time left
            DL.RF(dl, bx, by, bx + bw, by + bh, U4(0, 0, 0, 0.55 * al), bh);
            pcall(function()
                DL.RFM(dl, bx, by, bx + bw * left, by + bh, U4(0.68, 0.50, 1.0, al), U4(0.55, 0.86, 1.0, al), U4(0.55, 0.86, 1.0, al), U4(0.68, 0.50, 1.0, al));
            end);
            DL.R(dl, bx - 1, by - 1, bx + bw + 1, by + bh + 1, U4(0, 0, 0, 0.9 * al), bh, all, 1.3);   -- (a black edge: seen on light ground)
            local secs = math.max(0, st.dur - t);                    -- the seconds left, beside it (rose for the last two)
            local sc_ = (secs < 2) and { 1, 0.62, 0.70, al } or { 0.86, 0.92, 1, al };
            text(dl, bx + bw + 8 * s2, row, string.format('%.1f', secs), sc_);
            if gclip then
                pcall(function() dl:PopClipRect(); end);
                local gx = x1 - (x1 - x0) * grow;                    -- the bright edge leading it out
                DL.L(dl, gx, y0, gx, y1, U4(0.75, 0.97, 1.0, 1 - grow), 2);
            end
        end
    end
    if st and now - st.ts > st.dur then FIGHT.sc[sid] = nil; end
    imgui.SetWindowFontScale(fs);
    pcall(function() dl:PopClipRect(); end);
end
-- The fan: when the party opens a skillchain, your weapon skills that close it swing out from the hub (hx, hy) to its
-- left, one after another, each in a dark pill edged in the colour of what it makes ("WS  >  result", best at the
-- top); a light runs along each spoke as it opens. The hub's ring runs down the window: rose while you wait, gold
-- when you can close (then the best ones' edges breathe gold); a ripple marks the moment a chain opens.
function FIGHT.draw_fan(dl, sid, hx, hy, sc)
    if cfg.show_fan == false then return false; end                -- (TARGET > Skillchain fan / banner: off)
    local st = FIGHT.sc[sid];
    if st == nil or st.closed then return false; end
    local now = os.clock();
    local t = now - st.ts;
    if t > st.dur then return false; end
    local opts = (sid == -1) and { { 'Savage Blade', 'Light', 3 }, { 'Requiescat', 'Gravitation', 2 }, { 'Red Lotus Blade', 'Liquefaction', 1 } }
        or FIGHT.options(st);
    pcall(function() C.fullclip(dl); end);
    local fk = FIGHT.font(17 * sc);
    local lh = imgui.GetTextLineHeight();
    local all = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15;
    local go = t >= (st.wait or 3);
    local r = 10 * sc;
    -- the hub
    if t < 0.6 then                                                  -- a ripple as the chain opens
        local q = t / 0.6;
        DL.C(dl, hx, hy, r + 22 * sc * q, U4(1.0, 0.36, 0.62, 0.7 * (1 - q)), 32, 2);
    end
    DL.CF(dl, hx, hy, r + 3, U4(0.03, 0.02, 0.05, 0.88), 24);
    DL.C(dl, hx, hy, r, U4(1, 1, 1, 0.10), 32, 2.2);
    local f = go and (1 - (t - st.wait) / math.max(0.1, st.dur - st.wait)) or (t / math.max(0.1, st.wait));
    local col = go and { 1.0, 0.82, 0.42 } or { 1.0, 0.42, 0.62 };
    local beat = go and (0.65 + 0.35 * math.sin(now * 7)) or 0.75;
    DL.CF(dl, hx, hy, r - 1.5, U4(col[1], col[2], col[3], 0.16 + 0.10 * beat), 24);   -- the inside softly lit in the ring's colour (not a black gap)
    local seg = 64;                                                  -- the ring: smooth, a glow under it
    local fr = math.max(0, math.min(1, f));
    for pass = 1, 2 do
        local th, ca = (pass == 1) and 5 or 2.4, (pass == 1) and 0.22 or 1;
        for k = 0, math.floor(seg * fr) - 1 do
            local a0, a1 = -math.pi / 2 + k / seg * math.pi * 2, -math.pi / 2 + (k + 1.15) / seg * math.pi * 2;   -- (a little overlap: no seams)
            DL.L(dl, hx + math.cos(a0) * r, hy + math.sin(a0) * r, hx + math.cos(a1) * r, hy + math.sin(a1) * r, U4(col[1], col[2], col[3], ca), th);
        end
    end
    do                                                               -- the heart: the seconds - till the window opens (rose), then left in it (gold)
        local secs = math.max(0, math.ceil(go and (st.dur - t) or ((st.wait or 3) - t)));
        local str = tostring(secs);
        local fs0 = FS or 1;
        imgui.SetWindowFontScale(fs0 * 0.62);
        local tw_, th_ = imgui.CalcTextSize(str);
        text(dl, math.floor(hx - tw_ / 2 + 0.5), math.floor(hy - th_ * 0.397 + 0.5), str, { col[1] * 0.3 + 0.7, col[2] * 0.3 + 0.7, col[3] * 0.3 + 0.7, 1 });   -- (the digits' own middle sits at 0.397 of the line in this font)
        imgui.SetWindowFontScale(fs0);
    end
    -- the cards: they open down and to the left on a slant, the best at the top; each is a dark banner with a tip
    -- pointing at the hub, a slash of its result's colour at the start, and the result in a lighter part after a slanted cut
    local n = math.min(#opts, 6);
    local ch = lh + 12 * sc;                                         -- a card's height
    local cut = ch * 0.38;                                           -- how far its tip / slants lean
    local arrow = '  >  ';
    local wa = imgui.CalcTextSize(arrow);
    local wn, wr = 0, 0;
    for k = 1, n do
        wn = math.max(wn, imgui.CalcTextSize(opts[k][1]));
        wr = math.max(wr, imgui.CalcTextSize(opts[k][2]));
    end
    local cw = 18 * sc + cut + wn + wa + wr + 16 * sc + cut;        -- all the same width, so they line up
    local gap = ch + 6 * sc;
    if (cfg.fan_layout or 'fan') == 'drop' then                      -- TARGET > Fan layout: Drop down
        FIGHT.drop(dl, opts, n, hx, hy, r, t, cw, ch, cut, wn, wa, lh, sc, go, now);
        FIGHT.unfont(fk);
        pcall(function() dl:PopClipRect(); end);
        return true;
    end
    local R = 70 * sc;
    local a0 = math.rad(158);                                        -- the first one: left and a little down
    local da = math.rad(n > 1 and math.min(14, 46 / (n - 1)) or 0);   -- each next one further down (down-left, not straight left)
    do                                                               -- (its full size once open, for the guide)
        local bx0, by0, bx1, by1 = hx - r - 3, hy - r - 3, hx + r + 3, hy + r + 3;
        for i = 1, n do
            local a = a0 - (i - 1) * da;
            local rr = R + (i - 1) * gap * 0.55;
            local tx, ty = hx + math.cos(a) * rr - 6 * sc, hy + math.sin(a) * rr;
            if FIGHT.mir then                                        -- (mirrored: up and to the right, the best on top)
                local a2 = a0 - (n - i) * da;
                local rr2 = R + (n - i) * gap * 0.55;
                tx, ty = hx - math.cos(a2) * rr2 + 6 * sc, hy - math.sin(a2) * rr2;
            end
            bx0, by0 = math.min(bx0, FIGHT.mir and (tx - cut) or (tx - cw)), math.min(by0, ty - ch / 2);
            bx1, by1 = math.max(bx1, FIGHT.mir and (tx + cw) or (tx + cut)), math.max(by1, ty + ch / 2);
        end
        FIGHT.drawn.fo = { bx0, by0, bx1 - bx0, by1 - by0, now };
    end
    for i = 1, n do
        local o = opts[i];
        local u = math.max(0, math.min(1, (t - (i - 1) * 0.07) / 0.34));
        local c1 = 1.70158;
        local e = (u > 0) and (1 + (c1 + 1) * (u - 1) ^ 3 + c1 * (u - 1) ^ 2) or 0;   -- (a little overshoot as it lands)
        local al = math.min(1, u * 1.8);
        if al > 0.01 then
            local a = a0 - (i - 1) * da;                             -- (on screen 180 deg is left; less = more downward)
            local dirx, diry = math.cos(a), math.sin(a);
            local slot = i - 1;
            if FIGHT.mir then                                        -- (mirrored: up and to the right, the best on top - the highest)
                slot = n - i;
                a = a0 - slot * da;
                dirx, diry = -math.cos(a), -math.sin(a);
            end
            local rr = r + 6 * sc + (R + slot * gap * 0.55 - r) * e;
            local tipx, tipy = hx + dirx * rr, hy + diry * rr;       -- where the card's tip points from
            local pc = FIGHT.PCOL[o[2]] or { 1, 1, 1 };
            local best = (o[3] >= 3);
            local sx, sy = hx + dirx * (r + 3), hy + diry * (r + 3);
            local dotx, doty = tipx + (FIGHT.mir and -6 or 6) * sc, tipy;
            DL.L(dl, sx, sy, dotx, doty, U4(pc[1], pc[2], pc[3], 0.55 * al), best and 1.8 or 1.3);
            DL.CF(dl, dotx, doty, 3 * sc, U4(pc[1], pc[2], pc[3], al), 12);
            if u < 1 then                                            -- the light running out along the line
                DL.CF(dl, sx + (dotx - sx) * u, sy + (doty - sy) * u, 2.6 * sc, U4(1, 1, 1, 0.9 * (1 - u)), 10);
            end
            FIGHT.card(dl, o, FIGHT.mir and (tipx + 6 * sc + cw) or (tipx - 6 * sc), tipy, cw, ch, cut, wn, wa, lh, sc, al, pc, best, go, now, i);
        end
    end
    FIGHT.unfont(fk);
    pcall(function() dl:PopClipRect(); end);
    return true;
end
-- One card of the fan, in the look picked in TARGET > Fan look:
--   shape:  blade (slanted start, tip at the end)  chevron (straight start, tip)  pill (round)  tab (soft corners)
--           line (no box: the words over a glowing line)
--   accent: slash (a stripe of the result's colour along its start)  bar (a straight stripe)  glow (a soft glow round it)  none
--   colour: dark  tinted (by its result)  glass (see-through)  yunaui (a pink-to-violet edge)
FIGHT.SHAPES = { { 'blade', 'Blade' }, { 'chevron', 'Chevron' }, { 'pill', 'Pill' }, { 'tab', 'Tab' }, { 'line', 'Line only' } };
FIGHT.ACCENTS = { { 'slash', 'Slash' }, { 'bar', 'Bar' }, { 'glow', 'Glow' }, { 'none', 'None' } };
FIGHT.TINTS = { { 'dark', 'Dark' }, { 'tinted', 'Tinted' }, { 'glass', 'Glass' }, { 'yunaui', 'YunaUI edge' } };
function FIGHT.card(dl, o, x2, ym, cw, ch, cut, wn, wa, lh, sc, al, pc, best, go, now, i)
    local shape, accent, tint = cfg.fan_shape or 'blade', cfg.fan_accent or 'slash', cfg.fan_tint or 'dark';
    local x1, y1, y2 = x2 - cw, ym - ch / 2, ym + ch / 2;
    local all = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15;
    local function poly(pts, col) for k = 2, #pts - 1 do dl:AddTriangleFilled(pts[1], pts[k], pts[k + 1], col); end end
    local function mix(a, b, k) return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k }; end
    -- the colours of the look
    local base, light, ea = { 0.045, 0.040, 0.065 }, { 0.09, 0.08, 0.12 }, 0.88;
    if tint == 'tinted' then base, light = mix({ 0.045, 0.040, 0.065 }, pc, 0.16), mix({ 0.09, 0.08, 0.12 }, pc, 0.26);
    elseif tint == 'glass' then base, light, ea = { 0.12, 0.11, 0.17 }, { 0.20, 0.18, 0.27 }, 0.55; end
    local edge = (tint == 'tinted') and { pc[1], pc[2], pc[3], 0.65 * al } or ((tint == 'glass') and { 1, 1, 1, 0.30 * al } or { 1, 1, 1, 0.16 * al });
    if go and best then local g = 0.5 + 0.5 * math.sin(now * 6 + i); edge = { 1.0, 0.82, 0.42, (0.40 + 0.45 * g) * al }; end
    -- the shape: its outline, and where the result part starts (a cut, slanted or straight)
    local slant = (shape == 'blade');
    local mir = FIGHT.mir;                                           -- (mirrored: tip on the left, towards a hub on the left)
    local lx = (slant or (mir and shape == 'chevron')) and (x1 + cut) or x1;   -- (where the text starts after the start)
    local sepx = lx + 14 * sc + wn + wa - 4 * sc + ((not slant and shape ~= 'line' and (accent == 'slash' or accent == 'bar')) and 6 * sc or 0) + ((shape == 'pill') and 4 * sc or 0);
    local outline, respart = nil, nil;
    if shape == 'blade' and mir then
        outline = { { x1, ym }, { x1 + cut, y1 }, { x2, y1 }, { x2 - cut, y2 }, { x1 + cut, y2 } };
        respart = { { sepx, y2 }, { sepx + cut, y1 }, { x2, y1 }, { x2 - cut, y2 } };
    elseif shape == 'chevron' and mir then
        outline = { { x1, ym }, { x1 + cut, y1 }, { x2, y1 }, { x2, y2 }, { x1 + cut, y2 } };
        respart = { { sepx, y2 }, { sepx + cut * 0.6, y1 }, { x2, y1 }, { x2, y2 } };
    elseif shape == 'blade' then
        outline = { { x1, y2 }, { x1 + cut, y1 }, { x2 - cut, y1 }, { x2, ym }, { x2 - cut, y2 } };
        respart = { { sepx, y2 }, { sepx + cut, y1 }, { x2 - cut, y1 }, { x2, ym }, { x2 - cut, y2 } };
    elseif shape == 'chevron' then
        outline = { { x1, y1 }, { x2 - cut, y1 }, { x2, ym }, { x2 - cut, y2 }, { x1, y2 } };
        respart = { { sepx, y2 }, { sepx + cut * 0.6, y1 }, { x2 - cut, y1 }, { x2, ym }, { x2 - cut, y2 } };
    end
    if accent == 'glow' and shape ~= 'line' then                    -- a soft glow round it, in its result's colour
        for k = 3, 1, -1 do
            local gpad = k * 2;
            DL.R(dl, x1 - gpad, y1 - gpad, x2 + gpad, y2 + gpad, U4(pc[1], pc[2], pc[3], 0.06 * (4 - k) * al), (shape == 'pill') and (ch / 2 + gpad) or 8, all, 3);
        end
    end
    if outline then
        poly(outline, U4(base[1], base[2], base[3], ea * al));
        poly(respart, U4(light[1], light[2], light[3], ea * al));
        for k = 1, #outline do
            local c = edge;
            if tint == 'yunaui' and not (go and best) then             -- the edge flowing pink to violet
                local m = mix({ 1.0, 0.36, 0.62 }, { 0.62, 0.40, 1.0 }, (k - 1) / (#outline - 1));
                c = { m[1], m[2], m[3], 0.75 * al };
            end
            dl:AddLine(outline[k], outline[k % #outline + 1], u32(c), 1);
        end
        dl:AddLine(respart[1], respart[2], U4(1, 1, 1, 0.14 * al), 1);
    elseif shape == 'pill' or shape == 'tab' then
        local rr = (shape == 'pill') and ch / 2 or 6 * sc;
        DL.RF(dl, x1, y1, x2, y2, U4(base[1], base[2], base[3], ea * al), rr);
        pcall(function()                                             -- the result part, a little lighter
            C.clip(dl, { sepx, y1 - 2 }, { x2 + 2, y2 + 2 }, true);
            DL.RF(dl, x1, y1, x2, y2, U4(light[1], light[2], light[3], ea * al), rr);
            dl:PopClipRect();
        end);
        local c = edge;
        if tint == 'yunaui' and not (go and best) then c = { 0.80, 0.40, 0.82, 0.75 * al }; end
        DL.R(dl, x1, y1, x2, y2, u32(c), rr, all, 1);
        DL.L(dl, sepx, y1 + 3, sepx, y2 - 3, U4(1, 1, 1, 0.14 * al), 1);
    else                                                             -- line only: a glowing line under the words
        pcall(function()
            DL.RFM(dl, x1, y2 - 2, x2, y2, U4(pc[1], pc[2], pc[3], 0), U4(pc[1], pc[2], pc[3], 0.95 * al), U4(pc[1], pc[2], pc[3], 0.95 * al), U4(pc[1], pc[2], pc[3], 0));
        end);
    end
    -- the accent at its start
    if mir and slant and (accent == 'slash' or accent == 'bar') then   -- (mirrored: the stripe along the slanted end, on the right)
        local w_ = (accent == 'slash') and 4 * sc or 3 * sc;
        poly({ { x2 - 1, y1 + 1 }, { x2 - cut - 1, y2 - 1 }, { x2 - cut - 1 - w_, y2 - 1 }, { x2 - 1 - w_, y1 + 1 } }, U4(pc[1], pc[2], pc[3], al));
    elseif accent == 'slash' and shape ~= 'line' then
        if slant then                                                -- a stripe along the slanted start, inside it
            local w_ = 4 * sc;
            poly({ { x1 + 1, y2 - 1 }, { x1 + cut + 1, y1 + 1 }, { x1 + cut + 1 + w_, y1 + 1 }, { x1 + 1 + w_, y2 - 1 } }, U4(pc[1], pc[2], pc[3], al));
        else
            local sx0 = x1 + 7 * sc;
            DL.L(dl, sx0, y2 - 4, sx0 + cut * 0.6, y1 + 4, U4(pc[1], pc[2], pc[3], al), 2.4 * sc);
        end
    elseif accent == 'bar' and shape ~= 'line' then
        if slant then
            local w_ = 3 * sc;
            poly({ { x1 + 1, y2 - 1 }, { x1 + cut + 1, y1 + 1 }, { x1 + cut + 1 + w_, y1 + 1 }, { x1 + 1 + w_, y2 - 1 } }, U4(pc[1], pc[2], pc[3], al));
        else
            local rr = (shape == 'pill') and 1.5 * sc or 0;
            DL.RF(dl, x1 + 4 * sc, y1 + 4 * sc, x1 + 7 * sc, y2 - 4 * sc, U4(pc[1], pc[2], pc[3], al), rr);
        end
    end
    -- the words
    local ty = ym - lh / 2 - ((shape == 'line') and 2 or 0);
    local tx = lx + 14 * sc;
    if not slant and shape ~= 'line' and (accent == 'slash' or accent == 'bar') then tx = tx + 6 * sc; end   -- (room for the stripe)
    if shape == 'pill' then tx = tx + 4 * sc; end
    text(dl, tx, ty, o[1], { 1, 1, 1, al });
    text(dl, tx + wn, ty, '  >  ', { 0.70, 0.68, 0.80, al });
    text(dl, sepx + ((slant or shape == 'chevron') and cut or 0) + 6 * sc, ty, o[2], { pc[1], pc[2], pc[3], al });
end
-- The YunaUI line (the cards hang from it; the skillchain fan drops down it): violet at the top to ice blue at the
-- bottom, fading in and out at its ends. Crisp: a solid 2 px core on whole pixels, a 1 px halo each side and a fainter
-- pixel past it - no wide soft glow, so it never looks blurred.
function C.vline(dl, lx, y0, y1, sc, a)
    if y1 - y0 < 4 then return; end
    local X = math.floor(lx + 0.5) - 1;                              -- (the core covers pixels X and X + 1)
    local P, V = { 0.68, 0.50, 1.0 }, { 0.55, 0.86, 1.0 };
    local function c(y, al)
        local u = math.max(0, math.min(1, (y - y0) / (y1 - y0)));
        return U4(P[1] + (V[1] - P[1]) * u, P[2] + (V[2] - P[2]) * u, P[3] + (V[3] - P[3]) * u, al * a);
    end
    local f = math.min(30 * sc, (y1 - y0) * 0.20);
    local pieces = { { y0, y0 + f, 0, 1 }, { y0 + f, y1 - f, 1, 1 }, { y1 - f, y1, 1, 0 } };
    for _, pc in ipairs(pieces) do
        local ya, yb, fa, fb = pc[1], pc[2], pc[3], pc[4];
        if yb > ya then
            local function col(x0, x1, al)
                pcall(function()
                    local ct, cb = c(ya, al * fa), c(yb, al * fb);
                    DL.RFM(dl, x0, ya, x1, yb, ct, ct, cb, cb);
                end);
            end
            col(X - 2, X - 1, 0.10); col(X + 3, X + 4, 0.10);        -- the faint outer pixels
            col(X - 1, X, 0.32); col(X + 2, X + 3, 0.32);            -- the halo
            col(X, X + 2, 1.0);                                      -- the core
        end
    end
end
-- Edit Mode: the target's name, the skillchain fan and the enemy cast (when they sit with the target bar) can each be
-- dragged on their own. They keep their place as an offset from the target bar, so they still follow it when it moves.
FIGHT.anc = {};
function FIGHT.off(p) return tonumber(cfg[p .. '_dx']) or 0, tonumber(cfg[p .. '_dy']) or 0; end
FIGHT.PIECES = { { 'tn', 'Target name' }, { 'mb', 'Magic Burst' }, { 'fo', 'Skillchain fan' }, { 'co', 'Enemy cast' } };
function FIGHT.edit_pieces()
    if not EDIT.on then return; end
    if cfg.target_fx == 'link' then return; end                      -- (Hex link: the name, cast and Magic Burst follow the bar over its head, the
                                                                     --  skillchain sits at the top - nothing of theirs to place)
    for _, pc in ipairs(FIGHT.PIECES) do
        local p = pc[1];
        local a = FIGHT.anc[p];                                      -- { x, y, w, h } at no offset (set by the target bar)
        local free = (p == 'fo' and (cfg.fan_place or 'bar') == 'free') or (p == 'co' and (cfg.ecast_place or 'bar') == 'free');
        if a and not free and a[3] > 2 and a[4] > 2 then
            local kx, ky = p .. '_x', p .. '_y';
            local dx, dy = FIGHT.off(p);
            local rx, ry = a[1] + dx, a[2] + dy;
            local down = imgui.IsMouseDown(0);
            if not down then cfg[kx], cfg[ky] = rx, ry; end
            imgui.SetNextWindowPos({ rx, ry }, down and ImGuiCond_FirstUseEver or ImGuiCond_Always);
            imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
            imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
            if imgui.Begin('YunaUI ' .. pc[2] .. '##yui_ed_' .. p, { true }, EDIT.rs_hot and bit.bor(NOFRAME, ImGuiWindowFlags_NoMove) or NOFRAME) then
                imgui.Dummy({ a[3], a[4] });
            end
            end_plain(kx, ky);
            local nx, ny = tonumber(cfg[kx]), tonumber(cfg[ky]);
            if nx and ny then cfg[p .. '_dx'], cfg[p .. '_dy'] = math.floor(nx - a[1] + 0.5), math.floor(ny - a[2] + 0.5); end
        end
    end
end
-- Fan layout "Drop down": from the hub a YunaUI line runs down (the Damage Meter's anchor light: a soft glow, a pink to
-- violet line, a bright core, a white head), and the cards appear one under the other as it passes them, each fading in
-- while it slides out to the left, joined to the line by a short tick and a dot in its result's colour
function FIGHT.drop(dl, opts, n, hx, hy, r, t, cw, ch, cut, wn, wa, lh, sc, go, now)
    local gap = ch + 7 * sc;
    local y0 = hy + r + 3;                                           -- the line starts under the hub
    local total = 8 * sc + n * gap;
    local grow = math.min(1, t / 0.45);
    local len = total * (1 - (1 - grow) ^ 2);
    C.vline(dl, hx, y0, y0 + len, sc, 1);                            -- the line, violet at the top to ice blue at the bottom
    if grow < 1 then DL.CF(dl, hx, y0 + len, 3 * sc, U4(1, 1, 1, 0.95), 12); end   -- its head while it runs
    for i = 1, n do
        local o = opts[i];
        local cy = y0 + 8 * sc + (i - 0.5) * gap;
        local reach = (cy - y0) / math.max(1, total) * 0.45;          -- (when the line gets to it)
        local u = math.max(0, math.min(1, (t - reach) / 0.35));
        local e = 1 - (1 - u) ^ 3;
        local al = u;
        if al > 0.01 then
            local pc = FIGHT.PCOL[o[2]] or { 1, 1, 1 };
            local best = (o[3] >= 3);
            local tip = hx - 14 * sc + 34 * sc * (1 - e);            -- fades in while it slides out to the left
            if FIGHT.mir then tip = hx + 14 * sc - 34 * sc * (1 - e); end   -- (mirrored: out to the right)
            DL.L(dl, hx, cy, FIGHT.mir and (tip - 2) or (tip + 2), cy, U4(pc[1], pc[2], pc[3], 0.7 * al), 1.4 * sc);   -- the tick to the line
            DL.CF(dl, hx, cy, 3.2 * sc, U4(0, 0, 0, 0.6 * al), 12);
            DL.CF(dl, hx, cy, 2.4 * sc, U4(pc[1], pc[2], pc[3], al), 12);
            FIGHT.card(dl, o, FIGHT.mir and (tip + cw) or tip, cy, cw, ch, cut, wn, wa, lh, sc, al, pc, best, go, now, i);
        end
    end
end
-- How big the fan is, for its own window when it's placed anywhere (TARGET > Skillchain fan)
function FIGHT.fan_size(sc) return 420 * sc, 260 * sc; end
-- Edit Mode's pretend fight on the pretend target (id -1): a spell being cast, a chain window and a burst, every 6 s
function FIGHT.preview(id)
    id = id or -1;
    local now = os.clock();
    local t0 = now - (now % 6);
    FIGHT.casts[id] = { name = 'Firaga III', t0 = t0, dur = 4, kind = 'spell', tid = 0, pretend = true };
    FIGHT.sc[id] = { en = 'Savage Blade', property = { 'Fusion' }, ts = t0, dur = 8, wait = 2, step = 2, chain = 'Fusion',
                     elems = { 'Fire', 'Light' }, pretend = true };
end
-- TARGET > "Show them to place them": while it's on, the fan, the Magic Burst line and the enemy cast show all the time
-- (on a pretend target when you have none), so you can see where they sit
FIGHT.show = false;
function FIGHT.showing(sid)
    if not FIGHT.show then return; end
    local c, st = FIGHT.casts[sid], FIGHT.sc[sid];
    if (c == nil or c.pretend) and (st == nil or st.pretend) then FIGHT.preview(sid); end   -- (a real fight comes first)
end
FIGHT.drawn = {};                                                    -- where the fan, burst card and cast were last drawn ({ x, y, w, h, time })
-- Hex link: the cast under the bar's right end, right-aligned to the HP %'s end (xr) - its words, small, and a thin line
-- under them filling as it goes. Gives back how tall it is (the target of target goes under it; the debuffs don't move).
function FIGHT.draw_cast_under(dl, sid, xr, y0, sc)
    if sid == nil or sid == 0 then return 0; end
    local c = FIGHT.casts[sid];
    if c == nil then return 0; end
    local now = os.clock();
    local t = now - c.t0;
    if (c.broke and now - c.broke > 1.0) or t > c.dur + 2.0 then FIGHT.casts[sid] = nil; return 0; end
    local f = math.min(1, t / c.dur);
    local tp = (c.kind == 'tp');
    local fl = c.broke and math.max(0, 1 - (now - c.broke)) or 0;
    local fk = FIGHT.font(14 * sc);
    local lh = imgui.GetTextLineHeight();
    local label = (c.broke and 'Interrupted: ' or (tp and 'Readies ' or 'Casting ')) .. c.name;
    local lw = imgui.CalcTextSize(label);
    local col = c.broke and { 1, 1, 1, 0.4 + 0.6 * fl } or (tp and { 1.0, 0.78, 0.88, 1 } or { 0.90, 0.84, 1.0, 1 });
    local tx, ty = math.floor(xr - lw + 0.5), math.floor(y0 + 2 * sc + 0.5);
    text(dl, tx, ty, label, col);
    local lt = math.max(4, math.floor(4.5 * sc + 0.5));              -- (a thin hexagon bar under the words, as the target bar)
    local ly = ty + lh + 2;
    if c.broke then
        C.hexbar(dl, tx, ly, lw, lt, c.at or f, nil, 0, { c1 = { 1, 1, 1 }, c2 = { 1, 1, 1 }, cf = { 0.7, 0.7, 0.75 }, band = lt, tip = false, al = 0.3 + 0.7 * fl });
    else
        local c1 = tp and { 1.0, 0.36, 0.62 } or { 0.62, 0.40, 1.0 };
        local c2 = tp and { 1.0, 0.70, 0.40 } or { 0.85, 0.70, 1.0 };
        C.hexbar(dl, tx, ly, lw, lt, f, nil, 0, { c1 = c2, c2 = c1, band = lt });
    end
    FIGHT.drawn.co = { tx - 2, ty - 2, lw + 4, lh + lt + 6, now };
    FIGHT.unfont(fk);
    return (ty - y0) + lh + lt + 4 * sc;
end
function FIGHT.draw_cast(dl, sid, x, y, w, sc, th, mid, fsc)
    if sid == nil or sid == 0 then return 0; end
    local c = FIGHT.casts[sid];
    if c == nil then return 0; end
    local now = os.clock();
    local t = now - c.t0;
    if (c.broke and now - c.broke > 1.0) or t > c.dur + 2.0 then FIGHT.casts[sid] = nil; return 0; end
    local fk = FIGHT.font(16 * (fsc or sc) * (mid and math.max(0.5, math.min(2.5, tonumber(cfg.ecast_font) or 1)) or 1));   -- (the text: TARGET > Enemy cast text; the bar: Enemy cast size)
    local lh = imgui.GetTextLineHeight();
    local f = math.min(1, t / c.dur);
    local tp = (c.kind == 'tp');
    local beat = 0.5 + 0.5 * math.sin(now * 9);
    local fl = c.broke and math.max(0, 1 - (now - c.broke)) or 0;
    local col = c.broke and { 1, 1, 1, 0.4 + 0.6 * fl } or (tp and { 1.0, 0.66 + 0.2 * beat, 0.78, 1 } or { 0.90, 0.82, 1.0, 1 });
    local label = (c.broke and 'Interrupted: ' or (tp and 'Readies ' or 'Casting ')) .. c.name;
    if not c.broke and c.tid and c.tid ~= 0 and c.tid ~= sid then  -- who it's aimed at
        pcall(function()
            local ti = index_of(c.tid);
            local tn = ti and AshitaCore:GetMemoryManager():GetEntity():GetName(ti) or nil;
            if tn and tn ~= '' then label = label .. '  >  ' .. tn; end
        end);
    end
    local lw = imgui.CalcTextSize(label);
    local tx = x + w - lw;                                           -- the text ends where the HP bar ends
    local bh = math.max(1, th or math.floor(3 * sc));                -- (as thick as the target bar)
    local bw = math.max(50 * sc, math.min(200 * sc, w - lw - 14 * sc));
    if mid then                                                      -- (under the target bar's middle: its bar and the words, centred)
        bw = math.max(40 * sc, math.min(140 * sc, w * 0.60));
        tx = x + w / 2 - (bw + 12 * sc + lw) / 2 + bw + 12 * sc;
    end
    text(dl, tx, y, label, col);
    local bx, by = tx - 12 * sc - bw, y + lh / 2 - bh / 2;           -- its bar just before the text
    DL.RF(dl, bx, by, bx + bw, by + bh, U4(0, 0, 0, 0.55), bh);
    if c.broke then
        DL.RF(dl, bx, by, bx + bw * (c.at or f), by + bh, U4(1, 1, 1, 0.3 + 0.7 * fl));
    else
        local c1 = tp and { 1.0, 0.36, 0.62 } or { 0.62, 0.40, 1.0 };
        local c2 = tp and { 1.0, 0.70, 0.40 } or { 0.85, 0.70, 1.0 };
        pcall(function()
            DL.RFM(dl, bx, by, bx + bw * f, by + bh, U4(c1[1], c1[2], c1[3], 1), U4(c2[1], c2[2], c2[3], 1), U4(c2[1], c2[2], c2[3], 1), U4(c1[1], c1[2], c1[3], 1));
        end);
        DL.RF(dl, bx + bw * f - 1.5, by - 1, bx + bw * f, by + bh + 1, U4(1, 1, 1, 0.95));
    end
    DL.R(dl, bx - 1, by - 1, bx + bw + 1, by + bh + 1, U4(0, 0, 0, 0.9), bh, ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15, 1.3);   -- (a black edge: seen on light ground)
    FIGHT.drawn.co = { bx - 2, y - 2, tx + lw - bx + 4, lh + 4, now };   -- (where it is, for the guide)
    FIGHT.unfont(fk);
    return lh + 4 * sc;
end
local function read_action(e)
    local data, pos, max = e.data_raw, 40, e.size * 8;
    local function bits(n)
        if pos + n >= max then max = 0; return 0; end
        local v = ashita.bits.unpack_be(data, 0, pos, n);
        pos = pos + n;
        return v;
    end
    local actor = bits(32);                                         -- who acted
    local first = nil;
    local ntargets = bits(6);
    pos = pos + 4;
    local kind = bits(4);
    local param;
    if kind == 8 or kind == 9 then param = bits(16); bits(16); else param = bits(32); end
    bits(32);
    if (kind == 6 or kind == 11 or kind == 14 or kind == 15) and C.MOB2HR[param] and not is_party_id(actor) then
        local e = DEBUFF_DB.ja and DEBUFF_DB.ja[param];              -- (a monster's 2-hour - "uses Mighty Strikes": the message names the move,
        if e and e.buffId then enemy_add(actor, e.buffId, e.duration); end   --  not the effect, so it's put on the monster here, icon and timer)
    end
    local mob_on_us, hit_noted = false, false;
    for _ = 1, ntargets do
        local tid = bits(32);
        if not mob_on_us and is_party_id(tid) and not is_party_id(actor) then mob_on_us = true; engage(actor); end
        if not hit_noted and (kind == 1 or kind == 4 or kind == 7 or kind == 11) then  -- its first target: who it hit
            hit_noted = true;
            LASTHIT[actor] = { id = tid, t = os.clock() };
        end
        local nact = bits(4);
        if nact == 0 or max == 0 then break; end
        for _ = 1, nact do
            bits(5); bits(12); bits(7); bits(3);
            local p = bits(17);
            local m = bits(10);
            bits(31);
            local is_first = (first == nil);
            if is_first then first = p; cast_event(actor, kind, param, p); pcall(FIGHT.on_action, actor, kind, param, p, m, tid); end
            local fx_ap = nil;
            if bits(1) == 1 then                                    -- an added effect
                local aa = bits(10);                                 -- (its animation: for a skillchain, which one, 1..16)
                local ap, am = bits(17), bits(10);
                if am == 160 or am == 164 then enemy_add(tid, ap); end
                if FIGHT.SCMSG[am] then fx_ap = aa; end              -- (a skillchain's own message only; its param is the damage)
            end
            if is_first then pcall(FIGHT.on_skill, actor, kind, param, m, tid, fx_ap, first); end   -- skillchains (the Chains way)
            if bits(1) == 1 then bits(10); bits(14); bits(10); end  -- spikes
            if max == 0 then return; end
            if not is_party_id(tid) then pcall(C.ja_hit, tid, kind, param, m); end
            if MSG_ON[m] then enemy_add(tid, p, debuff_secs(kind, param, p));
            elseif MSG_OFF[m] then enemy_off(tid, p);
            elseif MSG_DEATH[m] then enemies[tid] = nil;
            elseif kind == 4 and MSG_SPELLDMG[m] and SPELL_DEBUFF[param] then enemy_add(tid, SPELL_DEBUFF[param], debuff_secs(4, param, SPELL_DEBUFF[param])); end
        end
    end
end
local function read_message(e)
    local sender = struct.unpack('I4', e.data, 0x04 + 1);
    local target = struct.unpack('I4', e.data, 0x08 + 1);
    local mid = struct.unpack('H', e.data, 0x18 + 1);
    if FIGHT.BREAK[mid] then pcall(FIGHT.broke, sender); end         -- a monster's cast broke (XIUI's cleanest signal)
    local param = struct.unpack('I4', e.data, 0x0C + 1);
    local m = struct.unpack('H', e.data, 0x18 + 1);
    if MSG_OFF[m] then enemy_off(target, param);
    elseif MSG_DEATH[m] then enemies[target] = nil; end
end
-- What to show under the target bar: your own buffs, a party member's, or the debuffs seen landing on a monster
local function target_buffs(idx)
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    local sid = ent:GetServerId(idx);
    local p = AshitaCore:GetMemoryManager():GetParty();
    for i = 0, 5 do
        if p:GetMemberIsActive(i) ~= 0 and p:GetMemberServerId(i) == sid then return member_buffs(i); end
    end
    local out, t, now = {}, enemies[sid], os.clock();
    local left = {};                                                -- status -> seconds left (a monster's debuffs)
    if t then
        for status, exp in pairs(t) do
            if exp < now then t[status] = nil; else out[#out + 1] = status; left[status] = exp - now; end
        end
        table.sort(out);
    end
    return out, left;
end

local function target_index()
    local t = AshitaCore:GetMemoryManager():GetTarget();
    if t == nil then return 0; end
    local sub = (t.GetIsSubTargetActive and t:GetIsSubTargetActive() == 1) and t:GetTargetIndex(1) or 0;
    return t:GetTargetIndex(0) or 0, sub;
end
local function party_cursor()
    local main, sub = target_index();
    local slot = nil;
    pcall(function()                                                -- the game's party menu: is a <stpt> / <stal> pick open?
        local ptr = AshitaCore:GetPointerManager():Get('party');
        if ptr == nil or ptr == 0 then return; end
        ptr = ashita.memory.read_uint32(ptr);
        if ptr == nil or ptr == 0 then return; end
        ptr = ashita.memory.read_uint32(ptr);
        if ptr == nil or ptr == 0 then return; end
        if (ashita.memory.read_uint32(ptr + 0x54) or 0) ~= 0 then slot = ashita.memory.read_uint8(ptr + 0x50); end
    end);
    if slot then
        local ti = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(slot);
        if ti and ti ~= 0 then return ti; end
        return -(slot + 1);                                          -- (someone in another zone: their slot, as -(slot + 1); Leader / Kick)
    end
    -- <st> / <stpc> with a target already held (engaged: a Cure while you fight): the cursor is in the first slot and the
    -- held monster in the second; with nothing held the cursor is in the second
    if sub and sub ~= 0 and main ~= 0 then return main; end
    if sub and sub ~= 0 then return sub; end
    return main;
end

----------------------------------------------------------------------------------------------------
-- Target bar: the name over a long thin glowing bar, the HP % at the right
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
-- TARGET > Entrance: a short show when you target something (about half a second): a line of light opens from the
-- middle, the bar opens behind it, then the name fades in. Drawn without moving clip areas (they shake every window on
-- plain Ashita): the bar's own size changes and the light is drawn on top.
----------------------------------------------------------------------------------------------------
FIGHT.fx = { idx = nil, t0 = -10 };
FIGHT.FXDUR = { blade = 0.6, link = 1.1 };
function FIGHT.fx_cl(t) return math.max(0, math.min(1, t)); end
function FIGHT.fx_eo(t) t = FIGHT.fx_cl(t); return 1 - (1 - t) ^ 3; end
function FIGHT.fxstate(idx, ent, fake)
    local kind = (cfg.target_fx == 'off' or cfg.target_fx == 'link') and cfg.target_fx or 'blade';
    local F = FIGHT.fx;
    local now = os.clock();
    if kind == 'off' then F.idx = idx; return nil; end
    if idx ~= F.idx then                                             -- a new target: the show starts
        F.idx = idx;
        F.t0 = now;
    end
    local e = (now - F.t0) / (FIGHT.FXDUR[kind] or 0.6);
    if e < 0 or e >= 1 then return nil; end
    local cl, eo = FIGHT.fx_cl, FIGHT.fx_eo;
    local st = { kind = kind, e = e, fa = 1, nla = 1, bwk = 1, bal = 1, hk = 1, chars = nil, yoff = 0 };
    if kind == 'link' then                                           -- (the hex link: the bar is simply there; FIGHT.linkdraw plays the show -
        if not (fake and C.MD and C.MD.on) then return nil; end      --  in the mode chooser's demo the bar opens too, from the left)
        st.bwk = eo(e / 0.55);
        st.bal = cl(e / 0.25);
        st.nla = cl((e - 0.35) / 0.35);
        return st;
    end
    st.bwk = eo((e - 0.12) / 0.5);
    st.nla = cl((e - 0.45) / 0.4);
    return st;
end
function FIGHT.fxdraw(st, x, top, by, w, h, sc)
    local fg = nil;
    pcall(function() fg = imgui.GetForegroundDrawList(); end);
    if fg == nil then return; end
    local e, cl, eo = st.e, FIGHT.fx_cl, FIGHT.fx_eo;
    local cx, cy = x + w / 2, by + h / 2;
    local pk, vi = C.hp, C.mp2;
    if st.kind == 'blade' then                                       -- the line of light, opening from the middle
        local L = (w / 2) * eo(e / 0.42);
        local la = (e < 0.45) and 1 or cl(1 - (e - 0.45) / 0.35);
        if la > 0.01 then
            DL.L(fg, cx - L, cy, cx + L, cy, U4(vi[1], vi[2], vi[3], 0.22 * la), 9 * sc);
            DL.L(fg, cx - L, cy, cx + L, cy, U4(pk[1], pk[2], pk[3], 0.45 * la), 4 * sc);
            DL.L(fg, cx - L, cy, cx + L, cy, U4(1, 1, 1, 0.95 * la), math.max(1.5, 1.6 * sc));
            for _, ex in ipairs({ cx - L, cx + L }) do                -- bright sparks riding the two ends
                DL.CF(fg, ex, cy, 5 * sc, U4(pk[1], pk[2], pk[3], 0.35 * la), 14);
                DL.CF(fg, ex, cy, 2.2 * sc, U4(1, 1, 1, la), 10);
            end
        end
        local fl = cl(1 - e / 0.25);                                 -- the flash where it starts
        if fl > 0.01 then DL.CF(fg, cx, cy, (6 + 18 * (1 - fl)) * sc, U4(1, 1, 1, 0.55 * fl), 24); end
    end
end
-- How tall something is (for the Hex link line's start and the bar over its head): from where the game puts its target
-- arrow when that can be read (kept for that one); else the game's own name height (C.model_h); else from its
-- hitbox - 1.5 x, never under 2 yalms - else its model's size.
C.TALL = {};
function C.tall(idx, ent)
    local sid = 0;
    pcall(function() sid = ent:GetServerId(idx) or 0; end);
    local known = C.TALL[sid];
    pcall(function()
        local tg = AshitaCore:GetMemoryManager():GetTarget();
        for slot = 0, 1 do
            if (tg:GetTargetIndex(slot) or 0) == idx then
                local axw, azw, ayw = tg:GetArrowPositionX(slot), tg:GetArrowPositionZ(slot), tg:GetArrowPositionY(slot);
                local ap = ent:GetActorPointer(idx);
                if axw and azw and ayw and ap and ap ~= 0 then
                    local px, py, pz = ashita.memory.read_float(ap + 0x678), ashita.memory.read_float(ap + 0x680), ashita.memory.read_float(ap + 0x67C);
                    local up = pz - azw;                             -- (the game's "up" is minus: the arrow is over the feet by this much)
                    if (axw - px) ^ 2 + (ayw - py) ^ 2 < 25 and up > 0.8 and up < 40 then
                        known = math.max(1.2, up - 0.35);            -- (just under the arrow: the top of the head)
                        C.TALL[sid] = known;
                    end
                end
                return;
            end
        end
    end);
    if known then return known; end
    local hz = C.model_h(idx, ent);                                  -- (the height the game itself puts names at, every monster alike)
    if hz then return hz; end
    local m, hb = C.msize(idx, ent);                                  -- (the hitbox is what the game fills in for monsters: a Giant's is 3,
    if hb and hb > 0.05 and hb < 40 then                             --  its head ~4.5 yalms up; anything small stays at 2)
        local h = math.max(2.0, 1.5 * hb);
        if C.flat(idx, ent) then h = math.min(h, 1.8); end           -- (wide but low: a Pugil's hitbox is 3.2, it's ~1 yalm tall)
        return h;
    end
    return 2.0 * math.max(1, m or 1);
end
-- Families that are wide but low (their hitbox is big, they aren't tall): the bar over them stays low
C.FLAT = { 'pugil', 'jagil', 'crab', 'clipper', 'snipper', 'leech', 'worm', 'scorpion', 'spider', 'beetle', 'crawler', 'uragnite',
           'urchin', 'lizard', 'eft', 'slime', 'ooze', 'rabbit', 'hare', 'funguar', 'mandragora', 'sapling', 'coeurl', 'tiger', 'wolf', 'raptor' };
function C.flat(idx, ent)
    local nm = '';
    pcall(function() nm = string.lower(ent:GetName(idx) or ''); end);
    for _, f in ipairs(C.FLAT) do if nm:find(f, 1, true) then return true; end end
    return false;
end
-- The game's own rule for a name over a head (FFXiMain.dll: the actor's name point, +0xD42B0 - read from memory 2026-10-23):
-- the feet, raised by the model's height (the entity record + 0x204, through the actor + 0x70) x 1.3. The bar's line
-- goes a little under that: the top of the head.
C.NAMEK = 1.3;
function C.model_h(idx, ent)
    local h = nil;
    pcall(function()
        local ap = ent:GetActorPointer(idx);
        if not ap or ap == 0 then return; end
        local ep = ashita.memory.read_uint32(ap + 0x70);
        if not ep or ep == 0 then return; end
        local m = ashita.memory.read_float(ep + 0x204);
        if m and m == m and m > 0.1 and m < 40 then h = m * C.NAMEK * 0.92; end   -- (just under where the name sits)
    end);
    return h;
end
function C.msize(idx, ent)                                           -- (the model's size, from the game's own entity record - VanaCore's
    local m, hb = nil, nil;                                           --  GetModelSize gives -1)
    pcall(function()
        local r = ent:GetRawEntity(idx);
        if r then m, hb = tonumber(r.ModelSize), tonumber(r.ModelHitboxSize); end
    end);
    if m == nil or m <= 0.05 or m > 40 then
        pcall(function() local v = ent:GetModelSize(idx); if v and v > 0.05 and v < 40 then m = v; end end);
    end
    if m and (m <= 0.05 or m > 40) then m = nil; end
    return m, hb;
end
-- TARGET > Entrance: Hex link: where the target window goes - up and to the right of the
-- head, so the hex sits there and the bar runs right from it; eased a little so it doesn't jitter. nil (its usual
-- place) when the head isn't on the screen.
function C.thead(idx, ent, sc)
    local me_ = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0) or 0;
    local HB_ = C.HB;
    if idx == me_ and HB_ and HB_.rx and os.clock() - (HB_.seen_t or -99) < 0.5 then   -- (you, with your head bars showing: just right of
        local R = FIGHT.LR(sc);                                       --  them, level with them - not over them)
        local D = R * 1.35 * math.max(0.6, math.min(2.0, tonumber(cfg.hl_isz) or 1));
        local tx = HB_.rx + 12 * sc + 2 * D + R * 0.55 - 6;
        local ty = HB_.my - 10 - 24 * sc;
        local T = C.TH;
        if T and T.idx == idx then T.x, T.y = T.x + (tx - T.x) * 0.35, T.y + (ty - T.y) * 0.35;
        else T = { idx = idx, x = tx, y = ty }; C.TH = T; end
        return { math.floor(T.x + 0.5), math.floor(T.y + 0.5) };
    end
    local sx, sy = nil, nil;
    pcall(function()
        local ap = ent:GetActorPointer(idx);
        if ap == nil or ap == 0 then return; end
        local px, py, pz = ashita.memory.read_float(ap + 0x678), ashita.memory.read_float(ap + 0x680), ashita.memory.read_float(ap + 0x67C);
        sx, sy = C.w2s(px, pz - C.tall(idx, ent), py);
    end);
    local W, H = C.screen();
    if not sx or sx < -40 or sx > W + 40 or sy < -40 or sy > H + 40 then C.TH = nil; return nil; end
    local R = FIGHT.LR(sc);
    local tx = sx + 22 * sc + R * 1.9 - 6;                            -- (the emblem ~22 px right of the head...)
    local ty = sy - 28 * sc - 10 - 24 * sc;                           -- (...and its bar ~28 px over it, under the name: a short line)
    local T = C.TH;
    if T and T.idx == idx then T.x, T.y = T.x + (tx - T.x) * 0.35, T.y + (ty - T.y) * 0.35;
    else T = { idx = idx, x = tx, y = ty }; C.TH = T; end
    return { math.floor(T.x + 0.5), math.floor(T.y + 0.5) };
end
-- TARGET > Entrance: Hex link - a line from the target's head to an icon at the start of the bar, both drawn as the
-- cfg.hl_* settings say. As you target it the line draws itself, the icon turns in and grows while a ripple of its shape
-- runs out, then it locks with a white flash. While you keep the target the icon stays (and its animation plays) and
-- the line stays as cfg.hl_rest says. (ax, ay: the bar's start; the look: the cfg.hl_* settings)
--   path:  elbow (diagonal, then flat into the icon)  straight  step (up, then across)  curve
--   line:  neon (a tube, the glow inside it)  thin  dashed (marching)  double (two parallel lines)  fade (in from the head)
--   icon:  hex2 (a hexagon in a hexagon)  hex  diamond  bracket (lock-on corners)  triangle (pointing at the bar)  none
-- the Banner's pretend weapon skills, for the preview (name, result, level)
FIGHT.PSOPTS = { { 'Savage Blade', 'Light', 3 }, { 'Requiescat', 'Gravitation', 2 }, { 'Red Lotus Blade', 'Liquefaction', 1 } };
function FIGHT.ps_draw(sid, sc)                                     -- (Hex link: the skillchain and Magic Burst as the Banner at the top)
    if sid == nil or sid == 0 then return; end
    local st = FIGHT.sc[sid];
    if st == nil then return; end
    local t = os.clock() - st.ts;
    if t > st.dur then return; end
    return FIGHT.ps_alt(sid, st, t);
end
-- Hex link's skillchain Banner, at the top of the screen in the middle: the chain's name big in spaced capitals, tracking
-- in; two lines either side of it are the time; your weapon skills in one line under it (result and level); Magic Burst
-- under that
function FIGHT.ps_alt(sid, st, t)
    local fg = nil;
    pcall(function() fg = imgui.GetForegroundDrawList(); end);
    if fg == nil then return; end
    local now = os.clock();
    local wait = st.wait or 3;
    local go = t >= wait;
    local frac = go and math.max(0, 1 - (t - wait) / math.max(0.1, st.dur - wait)) or math.min(1, t / math.max(0.1, wait));
    local secs = math.max(0, math.ceil(go and (st.dur - t) or (wait - t)));
    local rose, gold, WH = { 1.0, 0.42, 0.62 }, { 1.0, 0.82, 0.42 }, { 1, 1, 1 };
    local col = go and gold or rose;
    local fan_on = cfg.show_fan ~= false and not st.closed;
    local mb_on = cfg.show_mb ~= false and st.chain;
    local opts = fan_on and ((sid == -1) and FIGHT.PSOPTS or FIGHT.options(st)) or {};
    local n = math.min(#opts, 4);
    local function cl01(u) return math.max(0, math.min(1, u)); end
    local function ease(u) u = cl01(u); return 1 - (1 - u) ^ 3; end
    local function c32(c, a) return U4(c[1], c[2], c[3], cl01(a)); end
    local function rnd(k) local v = math.sin(k * 12.9898 + 78.233) * 43758.5453; return v - math.floor(v); end
    local SW_, SH_ = C.screen();
    local s_ = math.max(0.6, SH_ / 1080) * math.max(0.3, math.min(2.0, tonumber(cfg.hl_fan) or 0.8)) / 0.8;
    local mx = math.floor(SW_ / 2 + 0.5);
    local left = st.dur - t;
    local ex_ = (left < 0.4) and (1 - left / 0.4) or 0;
    local inn = ease(t / 0.3);
    local A = inn * (1 - ex_);
    if A <= 0 then return; end
    local pulse = 1;
    do                                                               -- (a soft dark band behind it all: readable on snow and sunlight)
        local B = FIGHT.drawn.bn;
        if B and now - (B[5] or 0) < 0.5 then
            local HW = math.max(B[3] / 2, (FIGHT.bnhw or 0)) + 150 * s_;
            local bot = B[2] + B[4] + 26 * s_;
            local core = HW * 0.42;
            local N = 32;
            local function al(y)                                     -- (full at the top, easing out over its lowest part)
                local av = cl01((bot - y) / ((bot - (FIGHT.psy and (FIGHT.psy - 8 * s_) or 0)) * 0.45));
                return 0.58 * A * av * av * (3 - 2 * av);
            end
            local cl0 = U4(0.01, 0.01, 0.03, 0);
            local xl, xc0, xc1, xr = math.floor(mx - HW), math.floor(mx - core), math.floor(mx + core), math.floor(mx + HW);
            local top_ = FIGHT.psy and (FIGHT.psy - 8 * s_) or 0;    -- (from the top of the screen - or of the guide's picture)
            for j = 0, N - 1 do                                      -- (each step shaded top to bottom: no lines between them)
                local y0, y1 = math.floor(top_ + (bot - top_) * j / N), math.floor(top_ + (bot - top_) * (j + 1) / N);
                if y1 > y0 then
                    local t_, b_ = U4(0.01, 0.01, 0.03, al(y0)), U4(0.01, 0.01, 0.03, al(y1));
                    pcall(function()
                        DL.RFM(fg, xl, y0, xc0, y1, cl0, t_, b_, cl0);
                        DL.RFM(fg, xc0, y0, xc1, y1, t_, t_, b_, b_);
                        DL.RFM(fg, xc1, y0, xr, y1, t_, cl0, cl0, b_);
                    end);
                end
            end
        end
    end
    local function show(str) return str; end
    local function wid(str, px, sp)                                  -- (how wide, in that size; sp: spacing between letters)
        local k = FIGHT.font(px);
        local w_, h_ = imgui.CalcTextSize(str);
        if sp then w_ = 0; for i = 1, #str do w_ = w_ + imgui.CalcTextSize(str:sub(i, i)) + ((i < #str) and sp or 0); end end
        h_ = imgui.GetTextLineHeight();
        FIGHT.unfont(k);
        return w_, h_;
    end
    local OL = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 0, 2 }, { 1, 2 } };
    local function otx(x_, y_, ch, c, a)                             -- (a full dark outline, a little heavier below, then the letters)
        local xi, yi = math.floor(x_ + 0.5), math.floor(y_ + 0.5);
        local oc = U4(0, 0, 0, 0.88 * cl01(a));
        for _, o in ipairs(OL) do DL.T(fg, xi + o[1], yi + o[2], oc, ch); end
        DL.T(fg, xi, yi, U4(c[1], c[2], c[3], cl01(a)), ch);
    end
    local function txt(str, px, x_, y_, c, a, sp)                    -- (left at x_, top at y_; sp: spaced letters)
        local k = FIGHT.font(px);
        if sp then
            for i = 1, #str do
                local ch = str:sub(i, i);
                otx(x_, y_, ch, c, a);
                x_ = x_ + imgui.CalcTextSize(ch) + sp;
            end
        else
            otx(x_, y_, str, c, a);
        end
        FIGHT.unfont(k);
    end
    local LVC = { 0.96, 0.92, 0.82 };
    local function lv(o) return 'Lv. ' .. tostring(o[3] or 1); end   -- (the skillchain's level: 1, 2, 3 - 4 for a double Light / Darkness)
    local function mbline(cy_, a)                                    -- (the element gems, MAGIC BURST, the chain's name - centred)
        local pc = FIGHT.PCOL[st.chain] or WH;
        local m = #(st.elems or {});
        local gw = m * 14 * s_;
        local w1 = wid('MAGIC BURST', 9 * s_, 2 * s_);
        local w2 = wid(tostring(st.chain), 12 * s_);
        local tot = gw + 8 * s_ + w1 + 8 * s_ + w2;
        local x_ = mx - tot / 2;
        for k, e in ipairs(st.elems or {}) do
            local ec = FIGHT.ELEM[e] or WH;
            local u = ease((t - 0.45 - 0.08 * k) / 0.25);
            local gx = x_ + (k - 0.5) * 14 * s_;
            C.hexdot(fg, gx, cy_, 6 * s_ * u + 1, c32({ 0, 0, 0 }, 0.6 * a));
            C.hexdot(fg, gx, cy_, 5 * s_ * u, c32(ec, a));
            if u < 1 then C.hexring(fg, gx, cy_, 5 * s_ + (1 - u) * 8 * s_, c32(ec, a * (1 - u)), 1.5); end
        end
        local _, h1 = wid('A', 9 * s_);
        local _, h2 = wid('A', 12 * s_);
        local ua = a * cl01((t - 0.5) / 0.3);
        txt('MAGIC BURST', 9 * s_, x_ + gw + 8 * s_, cy_ - h1 / 2, { 0.98, 0.94, 0.86 }, ua, 2 * s_);
        txt(show(tostring(st.chain), (t - 0.5) / 0.3, 77), 12 * s_, x_ + gw + 8 * s_ + w1 + 8 * s_, cy_ - h2 / 2, { pc[1] * 0.4 + 0.6, pc[2] * 0.4 + 0.6, pc[3] * 0.4 + 0.6 }, ua);
    end
    local state = go and 'CHAIN NOW' or 'GET READY';
    do
        local y_ = 22 * s_ - (1 - inn) * 14 * s_ + (FIGHT.psy or 0);   -- (FIGHT.psy: the guide's slide moves it down)
        local title = st.chain and tostring(st.chain):upper() or 'SKILLCHAIN';
        local tc = st.chain and (FIGHT.PCOL[st.chain] or WH) or col;
        local sp = (6 + 18 * (1 - inn)) * s_;                         -- (tracking in: the letters close up as it arrives)
        local _, hs = wid('A', 10 * s_);
        local ss_ = tostring(secs);
        local nw_, nh_ = wid(ss_, 24 * s_);                          -- (the seconds: big, beside the small CHAIN NOW / GET READY)
        local sw = wid(state, 10 * s_, 2 * s_);
        local lx_ = mx - (sw + 8 * s_ + nw_) / 2;
        y_ = y_ - (nh_ - hs) * 0.5;
        txt(state, 10 * s_, lx_, y_ + (nh_ - hs) * 0.62, col, A * pulse, 2 * s_);
        txt(ss_, 24 * s_, lx_ + sw + 8 * s_ + 1.5, y_ + 1.5, { 0, 0, 0 }, A * 0.5);
        txt(ss_, 24 * s_, lx_ + sw + 8 * s_, y_, { col[1] * 0.4 + 0.6, col[2] * 0.4 + 0.6, col[3] * 0.4 + 0.6 }, A);
        local ty_ = y_ + nh_ + 1 * s_;
        local tw_, th_ = wid(title, 30 * s_, sp);
        txt(title, 30 * s_, mx - tw_ / 2 + 2, ty_ + 2, { 0, 0, 0 }, A * 0.45, sp);   -- (a soft shadow)
        txt(title, 30 * s_, mx - tw_ / 2, ty_, { tc[1] * 0.3 + 0.7, tc[2] * 0.3 + 0.7, tc[3] * 0.3 + 0.7 }, A, sp);
        local ly = ty_ + th_ * 0.52;                                  -- (the time: a line each side, shrinking in towards the name)
        local L = 170 * s_ * frac * inn;
        for _, dir in ipairs({ -1, 1 }) do
            local x0_ = mx + dir * (tw_ / 2 + 12 * s_);
            local x1_ = x0_ + dir * L;
            DL.L(fg, x0_, ly, x1_, ly, c32({ 0, 0, 0 }, 0.5 * A), 3.5);
            DL.L(fg, x0_, ly, x1_, ly, c32(col, A * pulse), 1.5);
            C.hexdot(fg, x1_, ly, 3 * s_, c32(WH, A));
            C.hexring(fg, x0_ + dir * 6 * s_ * 0, ly, 2.5 * s_, c32(col, A * 0.6), 1);
        end
        local oy = ty_ + th_ + 6 * s_;                                -- (the weapon skills, in one line)
        FIGHT.bnhw = 0;
        if n > 0 then
            local parts, tot = {}, 0;
            for i = 1, n do
                local o = opts[i];
                local w1, w2, w3 = wid(o[1], 12 * s_), wid(o[2], 11 * s_), wid(lv(o), 9 * s_);
                parts[i] = { w1, w2, w3 };
                tot = tot + w1 + 6 * s_ + w2 + 4 * s_ + w3 + ((i < n) and 22 * s_ or 0);
            end
            local x_ = mx - tot / 2;
            FIGHT.bnhw = tot / 2;
            local _, h1 = wid('A', 12 * s_);
            for i = 1, n do
                local o, pw = opts[i], parts[i];
                local pc = FIGHT.PCOL[o[2]] or WH;
                local best = go and i == 1 and (o[3] or 0) >= 3;
                local u = ease((t - 0.2 - 0.08 * i) / 0.3);
                txt(show(o[1], (t - 0.2 - 0.08 * i) / 0.35, i * 10), 12 * s_, x_, oy, best and gold or WH, A * u);
                txt(o[2], 11 * s_, x_ + pw[1] + 6 * s_, oy + 1 * s_, pc, A * u);
                txt(lv(o), 9 * s_, x_ + pw[1] + 6 * s_ + pw[2] + 4 * s_, oy + 3 * s_, LVC, A * u);
                if best then DL.L(fg, x_, oy + h1 + 1, x_ + pw[1], oy + h1 + 1, c32(gold, A * u * (0.6 + 0.4 * math.sin(now * 4))), 1.5); end
                x_ = x_ + pw[1] + 6 * s_ + pw[2] + 4 * s_ + pw[3];
                if i < n then
                    C.hexdot(fg, x_ + 11 * s_, oy + h1 * 0.55, 3 * s_, c32({ 0, 0, 0 }, 0.7 * A * u));
                    C.hexdot(fg, x_ + 11 * s_, oy + h1 * 0.55, 2 * s_, c32(gold, 0.85 * A * u));
                    x_ = x_ + 22 * s_;
                end
            end
            oy = oy + h1 + 8 * s_;
        end
        if mb_on then mbline(oy + 8 * s_, A); end
        local half_ = math.max(tw_ / 2 + 190 * s_, 300 * s_);
        FIGHT.drawn.bn = { mx - half_, y_ - 4, half_ * 2, (oy + (mb_on and 22 * s_ or 0)) - y_ + 8, os.clock() };   -- (for the guide's box)
    end
end
FIGHT.HLCOL = { cyan = { 0.35, 0.90, 1.0 }, azure = { 0.35, 0.72, 1.0 }, pink = { 1.0, 0.45, 0.72 }, violet = { 0.70, 0.52, 1.0 },
                white = { 0.95, 0.96, 1.0 }, gold = { 1.0, 0.80, 0.42 }, red = { 1.0, 0.36, 0.45 }, mint = { 0.45, 0.95, 0.85 } };
function FIGHT.LR(sc) return math.max(6, 9 * sc); end
function FIGHT.linkdraw(idx, ent, ax, ay, sc, tk)
    local fg = nil;
    pcall(function() fg = imgui.GetForegroundDrawList(); end);
    if fg == nil then return; end
    local now = os.clock();
    local t = now - (FIGHT.fx.t0 or 0);
    local cl, eo = FIGHT.fx_cl, FIGHT.fx_eo;
    local HC = FIGHT.HLCOL;
    local R = FIGHT.LR(sc);
    local isz = math.max(0.6, math.min(2.0, tonumber(cfg.hl_isz) or 1));
    local D = R * 1.35 * isz;                                         -- (the icon's radius)
    local icon = cfg.hl_icon or 'hex2';
    local hx, hy = ax - D - R * 0.55, ay;                             -- (the icon: just left of where the bar starts)
    if icon == 'none' then hx = ax - R * 0.5; D = 0; end
    local acc = (tk == 'mob') and (HC[cfg.hl_mcol or 'azure'] or HC.azure) or (HC[cfg.hl_fcol or 'mint'] or HC.mint);
    local lc = (cfg.hl_lcol == 'match') and acc or (HC[cfg.hl_lcol or 'cyan'] or HC.cyan);
    local lw = math.max(0.5, math.min(3, tonumber(cfg.hl_lw) or 1));
    local function col(c, a_) return U4(c[1], c[2], c[3], a_); end
    local function mix(c, k) return { c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k }; end
    local function poly(pts_, c, th, closed)
        for k = 1, #pts_ - 1 do fg:AddLine(pts_[k], pts_[k + 1], c, th); end
        if closed then fg:AddLine(pts_[#pts_], pts_[1], c, th); end
    end
    -- the head (a little over it), on the screen
    local sx, sy = nil, nil;
    pcall(function()
        if idx == nil or idx == 0 then                                -- (the pretend target: no head, no line -
            if C.MD and C.MD.on then sx, sy = ax + 80 * sc, ay + 170 * sc; end   --  but in the mode chooser a pretend head under it)
            return;
        end
        if idx == (AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0) or 0) then return; end   -- (yourself: no line over your own bars)
        local ap = ent:GetActorPointer(idx);
        if ap == nil or ap == 0 then return; end
        local px, py, pz = ashita.memory.read_float(ap + 0x678), ashita.memory.read_float(ap + 0x680), ashita.memory.read_float(ap + 0x67C);
        sx, sy = C.w2s(px, pz - C.tall(idx, ent), py);
    end);
    FIGHT.LBX = hx - D - 8 * sc;                                      -- (where Magic Burst hangs: the line's bend, else left of the icon)
    FIGHT.HXC = { hx, hy, os.clock() };                               -- (the icon's middle: the Chain link runs from it)
    if sx then
        -- the path, as points
        local ix = hx - D - 1;
        local path = { { sx, sy } };
        local pth = cfg.hl_path or 'elbow';
        if pth == 'straight' then
            local dx, dy = hx - sx, hy - sy;
            local dd = math.sqrt(dx * dx + dy * dy);
            local k = (dd > 0) and ((dd - D - 1) / dd) or 0;
            path[2] = { sx + dx * k, sy + dy * k };
        elseif pth == 'step' then
            path[2] = { sx, hy }; path[3] = { ix, hy };
            FIGHT.LBX = sx - 4 * sc;
        elseif pth == 'curve' then
            for q = 1, 16 do
                local u = q / 16;
                local cx_, cy_ = sx, hy;                              -- (bending from straight up into the flat)
                path[#path + 1] = { (1 - u) ^ 2 * sx + 2 * (1 - u) * u * cx_ + u * u * ix, (1 - u) ^ 2 * sy + 2 * (1 - u) * u * cy_ + u * u * hy };
            end
        else
            local ex = hx - D - 14 * sc;
            path[2] = { ex, hy }; path[3] = { ix, hy };
            FIGHT.LBX = ex;
        end
        local cum = { 0 };                                            -- (how far along each point is)
        for k = 2, #path do cum[k] = cum[k - 1] + math.sqrt((path[k][1] - path[k - 1][1]) ^ 2 + (path[k][2] - path[k - 1][2]) ^ 2); end
        local total = cum[#cum];
        local function at(d)
            d = math.max(0, math.min(total, d));
            for k = 2, #path do
                if d <= cum[k] then
                    local sl = cum[k] - cum[k - 1];
                    local u = (sl > 0) and ((d - cum[k - 1]) / sl) or 0;
                    return { path[k - 1][1] + (path[k][1] - path[k - 1][1]) * u, path[k - 1][2] + (path[k][2] - path[k - 1][2]) * u };
                end
            end
            return path[#path];
        end
        local function upto(d0, d1)                                   -- (the path from d0 to d1, as points)
            local out = { at(d0) };
            for k = 2, #path - 1 do if cum[k] > d0 and cum[k] < d1 then out[#out + 1] = path[k]; end end
            out[#out + 1] = at(d1);
            return out;
        end
        local rest = cfg.hl_rest or 'show';
        local la = (t < 0.8) and 1 or ((t < 1.1) and (1 - (1 - ((rest == 'hide') and 0 or ((rest == 'faint') and 0.25 or 0.8))) * (t - 0.8) / 0.3)
            or ((rest == 'hide') and 0 or ((rest == 'faint') and 0.25 or 0.8)));
        local g = eo(t / 0.25) * total;
        local pts = upto(0, g);
        local th = math.max(1, 1.2 * sc * lw);
        local style = cfg.hl_line or 'neon';
        if la > 0.01 then
            if style == 'neon' then                                   -- a neon tube: deep outside, bright, a white-hot core; round joints
                for _, L_ in ipairs({ { { lc[1] * 0.35, lc[2] * 0.7, lc[3] * 0.95 }, th * 3 }, { lc, th * 1.9 }, { mix(lc, 0.85), math.max(1, th * 0.8) } }) do
                    local c_ = col(L_[1], la);
                    poly(pts, c_, L_[2]);
                    for k = 1, #pts do fg:AddCircleFilled(pts[k], L_[2] / 2, c_, 10); end
                end
            elseif style == 'thin' then
                poly(pts, col({ 0, 0, 0 }, 0.5 * la), th + 2);
                poly(pts, col(lc, la), th);
            elseif style == 'dashed' then                              -- dashes marching towards the icon
                local dl_, gp = 7 * sc, 5 * sc;
                local off = (now * 30 * sc) % (dl_ + gp);
                local d = -dl_ + off;
                while d < g do
                    local d0, d1 = math.max(0, d), math.min(g, d + dl_);
                    if d1 > d0 then
                        local p_ = upto(d0, d1);
                        poly(p_, col({ 0, 0, 0 }, 0.5 * la), th + 2);
                        poly(p_, col(lc, la), th);
                    end
                    d = d + dl_ + gp;
                end
            elseif style == 'double' then                             -- two thin parallel lines
                for _, o_ in ipairs({ -1.7, 1.7 }) do
                    local q_ = {};
                    for k = 1, #pts do
                        local a_, b_ = pts[math.max(1, k - 1)], pts[math.min(#pts, k + 1)];
                        local dx, dy = b_[1] - a_[1], b_[2] - a_[2];
                        local dd = math.sqrt(dx * dx + dy * dy);
                        if dd < 0.001 then dx, dy, dd = 1, 0, 1; end
                        q_[k] = { pts[k][1] - dy / dd * o_ * sc * lw, pts[k][2] + dx / dd * o_ * sc * lw };
                    end
                    poly(q_, col(lc, 0.9 * la), math.max(1, th * 0.7));
                end
            else                                                      -- fade: from nothing at the head to full at the icon
                local n_ = 12;
                for q = 0, n_ - 1 do
                    local d0, d1 = g * q / n_, g * (q + 1) / n_;
                    local p_ = upto(d0, d1);
                    local k_ = (q + 1) / n_;
                    poly(p_, col(lc, la * k_ * 0.35), th * 2.6);
                    poly(p_, col(mix(lc, 0.5), la * k_), th);
                end
            end
            if cfg.hl_pulse ~= false and t > 0.3 then                 -- a pulse of light running along it, head to icon, every ~1.2 s
                local q = ((t - 0.3) % 1.2) / 1.2 * total;
                poly(upto(math.max(0, q - 9 * sc), q), col({ 1, 1, 1 }, 0.9 * la), th * 2);
            end
            local hm = cfg.hl_head or 'cap';                          -- the end on the head
            if hm == 'dot' then DL.CF(fg, sx, sy, 2.6 * sc, col(acc, la), 12);
            elseif hm == 'ring' then DL.C(fg, sx, sy, 3.6 * sc, col(acc, la), 14, 1.4); end
        end
        if t < 0.27 then fg:AddCircleFilled(pts[#pts], 2.2 * sc, col({ 1, 1, 1 }, 0.95), 10); end   -- (a spark on its tip)
        if t < 0.2 then return; end                                   -- (the icon comes in as the line arrives)
    end
    if icon == 'none' then return; end
    -- the icon
    local inn = eo((t - 0.2) / 0.16);
    local turn = (1 - eo((t - 0.2) / 0.42)) * math.pi / 3;
    local anim = cfg.hl_ianim or 'spin';
    local breathe = (anim == 'pulse') and (1 + 0.07 * math.sin(now * 3.2)) or 1;
    local ia = (anim == 'pulse') and (0.78 + 0.22 * (0.5 + 0.5 * math.sin(now * 3.2))) or 1;
    local d = D * (0.45 + 0.55 * inn) * breathe;
    local dk = col({ 0, 0, 0 }, 0.75 * inn);
    local function shape(r, rot)                                      -- the icon's outline, as points
        local n_, off = 6, -math.pi / 2;
        if icon == 'diamond' then n_, off = 4, -math.pi / 2;
        elseif icon == 'triangle' then n_, off = 3, 0; end            -- (a triangle pointing right, at the bar)
        local out = {};
        for k = 0, n_ - 1 do local an = rot + off + k * math.pi * 2 / n_; out[k + 1] = { hx + r * math.cos(an), hy + r * math.sin(an) }; end
        return out;
    end
    local rp = cl((t - 0.24) / 0.5);                                  -- the ripple, in its own shape
    if rp > 0 and rp < 1 and icon ~= 'bracket' then poly(shape(D * (1 + 1.4 * rp), 0), col(acc, 0.55 * (1 - rp)), 1.2, true); end
    if icon == 'bracket' then                                         -- lock-on corners round a square; they breathe in and out
        local g_ = d * ((anim == 'spin') and (1 + 0.10 * math.sin(now * 4)) or 1);
        local L_ = g_ * 0.5;
        for _, c_ in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            local px, py = hx + c_[1] * g_, hy + c_[2] * g_;
            for pass = 1, 2 do
                local cc = (pass == 1) and dk or col(acc, inn * ia);
                local tt = (pass == 1) and 3.4 or 1.5;
                DL.L(fg, px, py, px - c_[1] * L_, py, cc, tt);
                DL.L(fg, px, py, px, py - c_[2] * L_, cc, tt);
            end
        end
        DL.CF(fg, hx, hy, math.max(1, d * 0.1), col(acc, inn * ia), 8);
    else
        local outer = shape(d, turn);
        poly(outer, dk, 3.4, true);
        poly(outer, col(acc, inn * ia), 1.4, true);
        if icon == 'hex2' or icon == 'diamond' then                   -- the inner one: turning slowly the other way (Spin)
            local irot = turn - ((anim == 'spin') and now * 0.4 or 0);
            local inner = shape(d * 0.72, irot);
            poly(inner, dk, 2.8, true);
            poly(inner, col(acc, 0.7 * inn * ia), 1, true);
        end
        if anim == 'spin' and t > 0.85 then                           -- a short light running round the outer edge
            local n_ = #outer;
            local u = (now * 0.62 % 1) * n_;
            local function on(v)
                v = v % n_;
                local i_ = math.floor(v);
                local f_ = v - i_;
                local p0, p1 = outer[i_ + 1], outer[(i_ + 1) % n_ + 1];
                return { p0[1] + (p1[1] - p0[1]) * f_, p0[2] + (p1[2] - p0[2]) * f_ };
            end
            for q = 0, 5 do
                local v0, v1 = u - 0.5 * (q + 1) / 6, u - 0.5 * q / 6;
                if math.floor(v0) ~= math.floor(v1) then v0 = math.floor(v1); end
                fg:AddLine(on(v0), on(v1), col({ 0.92, 1.0, 1.0 }, inn * (1 - q / 6)), 1.6);
            end
        end
    end
    local lk = cl((t - 0.62) / 0.23);                                 -- the lock: a white flash round it
    if lk > 0 and lk < 1 then
        if icon == 'bracket' then DL.R(fg, hx - d * (1 + 0.4 * lk), hy - d * (1 + 0.4 * lk), hx + d * (1 + 0.4 * lk), hy + d * (1 + 0.4 * lk), col({ 1, 1, 1 }, 0.9 * (1 - lk)), 0, 15, 1.6);
        else poly(shape(d * (1 + 0.45 * lk), 0), col({ 1, 1, 1 }, 0.9 * (1 - lk)), 1.6, true); end
    end
end
-- TARGET > Friends look different: what the target is - 'mob', 'pc' (a player, or anyone in your party / alliance,
-- trusts too: then its member slot) or 'npc'
function C.tkind(idx, ent, fake)
    if fake then return 'mob'; end
    local sid = ent:GetServerId(idx);
    local p = AshitaCore:GetMemoryManager():GetParty();
    for i = 0, 17 do
        if p:GetMemberIsActive(i) ~= 0 and p:GetMemberServerId(i) == sid and p:GetMemberName(i) == ent:GetName(idx) then return 'pc', i; end
    end
    local ok, fl = pcall(function() return ent:GetSpawnFlags(idx); end);
    if ok and type(fl) == 'number' then
        if bit.band(fl, 0x10) ~= 0 then return 'mob'; end
        if bit.band(fl, 0x01) ~= 0 then return 'pc'; end
    end
    return 'npc';
end
C.TFRIEND = { pc = { 0.40, 0.95, 0.80 }, npc = { 1.0, 0.86, 0.50 } };   -- the Ally banner's colour: aqua for players, gold for NPCs
-- A friend (a player or NPC) in the target bar's place: the Ally banner - a slim frame with a cross, the name, HP and MP
-- side by side. Gives back the height it used.
function C.tfriend(dl, x, y, w, sc, idx, ent, name, hpp, tk, tmi, dt)
    local m = tmi and member(tmi) or nil;
    if m == nil then
        m = { name = name, hpp = hpp, mpp = 0, tp = 0, inzone = true };                                                       -- (no tag: only party / alliance members show their job)
        pcall(function() local d2 = ent:GetDistance(idx); if type(d2) == 'number' and d2 >= 0 then m.dist = math.sqrt(d2); end end);
    end
    m.far = nil;                                                     -- (never faded here)
    local nohp = (tk == 'npc');                                      -- (NPCs and objects have no HP worth showing: no bars)
    local col = C.TFRIEND[tk] or C.TFRIEND.pc;
    -- Laid out before anything is drawn, so nothing ever overlaps at any size or resolution: on one line when it fits
    -- (the bars may shrink a little first), else on two - the tag, name and distance on top, HP and MP under them.
    -- On either line the distance goes, then the name is shortened with "...", before anything could touch.
    local pushed = sized('chat', 18 * sc);
    local fs = FS or 1;
    local lh = imgui.GetTextLineHeight();
    local nmw = imgui.CalcTextSize(name);
    imgui.SetWindowFontScale(fs * 0.74);                             -- (the job tag's width, as ALLY.tag makes it)
    local tagtxt = m.tagtext or (m.job and JOBS[m.job]) or nil;
    local jw, jh = imgui.CalcTextSize(tagtxt or 'WHM');
    local th_ = math.min(lh * 0.95 * 0.78, (tonumber(jh) or 10) + 6 * sc);
    local tagw = tagtxt and (math.floor(math.max(jw, imgui.CalcTextSize('WHM')) + 12 * sc + th_ * 0.30) + 8 * sc) or 0;
    imgui.SetWindowFontScale(fs * 0.78);
    local _, sh = imgui.CalcTextSize('A');
    local dstr = m.dist and string.format('%.1f', m.dist) or nil;
    local dw = dstr and imgui.CalcTextSize(dstr) or 0;
    local hlab = 'HP ' .. math.floor((m.hpp or hpp) * 100 + 0.5) .. '%';
    local hlw = imgui.CalcTextSize(hlab);
    local hasmp = tmi ~= nil and ((m.mp or 0) > 0 or (m.mpp or 0) > 0);
    local mlw = hasmp and imgui.CalcTextSize('MP') or 0;
    imgui.SetWindowFontScale(fs);
    local g1, g2, g3 = 7 * sc, 18 * sc, 16 * sc;                     -- label-bar, between HP and MP, between the two sides
    local left0, right0 = x + 14 * sc, x + w - 14 * sc;
    local hpw, mpw = math.floor(w * 0.22), hasmp and math.floor(w * 0.16) or 0;
    local hmin, mmin = math.floor(48 * sc), hasmp and math.floor(34 * sc) or 0;
    local function rw() if nohp then return 0; end return hlw + g1 + hpw + (hasmp and (g2 + mlw + g1 + mpw) or 0); end
    local left_need = tagw + nmw + (dstr and (10 * sc + dw) or 0);
    local over = left_need + rw() - (right0 - left0 - g3);
    if over > 0 then                                                 -- the bars give way first, down to their minimum
        local take = math.min(over, (hpw - hmin) + (mpw - mmin));
        if take > 0 then
            local share = (hpw - hmin) / math.max(1, (hpw - hmin) + (mpw - mmin));
            hpw = math.floor(hpw - take * share);
            mpw = math.floor(mpw - take * (1 - share));
        end
        over = left_need + rw() - (right0 - left0 - g3);
    end
    local two = over > 0 and not nohp;                               -- still no room: two lines
    local room1 = two and (right0 - left0) or (right0 - left0 - g3 - rw());   -- (the name line's room)
    if two then                                                      -- (the bars' line: HP and MP share the whole width)
        local bars = (right0 - left0) - hlw - g1 - (hasmp and (g2 + mlw + g1) or 0);
        if hasmp and bars < 40 * sc then hasmp = false; bars = (right0 - left0) - hlw - g1; end   -- (too narrow for both: HP only)
        bars = math.max(0, bars);
        hpw = hasmp and math.floor(bars * 0.58) or math.floor(bars);
        mpw = hasmp and math.floor(bars - hpw) or 0;
    end
    if tagw + nmw + (dstr and (10 * sc + dw) or 0) > room1 then dstr = nil; end
    local nm = name;
    if tagw + nmw > room1 then
        local maxw = math.max(0, room1 - tagw);
        while #nm > 1 and imgui.CalcTextSize(nm .. '...') > maxw do nm = nm:sub(1, -2); end
        nm = nm .. '...';
        nmw = imgui.CalcTextSize(nm);
    end
    local h = math.floor(two and (lh * 2 + 18 * sc) or (lh + 14 * sc));
    local cy = y + 7 * sc + lh / 2;                                  -- (the name line's middle)
    local by_ = two and (cy + lh * 0.5 + 4 * sc + sh / 2) or cy;     -- (the bars' line's middle)
    local obj = false;                                               -- (NPCs and objects alike: the gold banner, no tag, no HP - custom NPCs can't be told from doors)
    if not obj then pcall(function()                                 -- a dark band behind it (readable on any ground), fading at both ends
        local d1, d0 = U4(0.02, 0.02, 0.04, 0.62), U4(0.02, 0.02, 0.04, 0);
        local e = math.min(80 * sc, w * 0.18);
        DL.RFM(dl, x, y, x + e, y + h, d0, d1, d1, d0);
        DL.RF(dl, x + e, y, x + w - e, y + h, d1);
        DL.RFM(dl, x + w - e, y, x + w, y + h, d1, d0, d0, d1);
    end); end
    local function line(ly)                                          -- (a thin line, brightest in the middle, fading at both ends)
        local c1, c0 = U4(col[1], col[2], col[3], 0.9), U4(col[1], col[2], col[3], 0);
        pcall(function()
            DL.RFM(dl, x, ly, x + w / 2, ly + 1.2 * sc, c0, c1, c1, c0);
            DL.RFM(dl, x + w / 2, ly, x + w, ly + 1.2 * sc, c1, c0, c0, c1);
        end);
    end
    if not obj then line(y); line(y + h); end
    local tx = left0;
    pcall(function()                                                 -- its job tag in its role's colour, as in the party list (PC / NPC when unknown)
        local fs_ = FS or 1;
        FS = fs_ / 0.80;
        if tagw > 0 then C.ALLY.tag(dl, m, 95, tx, cy, lh * 0.95, sc, 1, false); end
        FS = fs_;
        imgui.SetWindowFontScale(fs_);
    end);
    tx = tx + tagw;
    text(dl, tx, cy - lh / 2, nm, { 1, 1, 1, 1 });
    tx = tx + nmw + 10 * sc;
    imgui.SetWindowFontScale(fs * 0.78);
    if dstr then text(dl, tx, cy - sh / 2, dstr, (m.dist > (tonumber(cfg.party_range) or 20.8)) and { 1, 0.66, 0.80, 1 } or { 0.96, 0.95, 1, 1 }); end
    local bh = math.max(4, math.floor(6 * sc));
    local function bar(bx, label, lw, v, bw, c)                      -- a label, then its bar; gives back where it ends
        text(dl, bx, by_ - sh / 2, label, { 0.97, 0.96, 1, 1 });
        bx = bx + lw + g1;
        DL.RF(dl, bx - 1, by_ - bh / 2 - 1, bx + bw + 1, by_ + bh / 2 + 1, U4(0, 0, 0, 0.9), 2);
        DL.RF(dl, bx, by_ - bh / 2, bx + bw, by_ + bh / 2, U4(0.16, 0.15, 0.21, 1), 2);
        DL.RF(dl, bx, by_ - bh / 2, bx + bw * math.max(0, math.min(1, v)), by_ + bh / 2, U4(c[1], c[2], c[3], 1), 2);
        return bx + bw;
    end
    if not nohp then
        local bx0 = two and left0 or (right0 - rw());
        local e1 = bar(bx0, hlab, hlw, m.hpp or hpp, hpw, col);
        if hasmp then bar(e1 + g2, 'MP', mlw, m.mpp or 0, mpw, { 0.48, 0.58, 1.0 }); end
    end
    imgui.SetWindowFontScale(fs);
    unsized(pushed);
    return h + 2 * sc;
end
C.is_party_id = is_party_id;                                         -- (for C.claimcol, above)
local function draw_target(dt)
    if not cfg.target then return; end
    local idx = target_index();
    local fake = false;
    if YUI_PRES then idx = 0; end                                    -- (the guide's slides: always the pretend target)
    if idx and idx ~= 0 and cfg.target_fx == 'link' and C.head_bars_on() and not (EDIT.on or FIGHT.show) then   -- (Hex link, you on yourself:
        local me_ = 0;                                               --  your head bars already show you - no second set beside them)
        pcall(function() me_ = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0) or 0; end);
        if idx == me_ then FIGHT.fx.idx = nil; return; end
    end
    if idx == nil or idx == 0 then
        if not (EDIT.on or FIGHT.show) then FIGHT.fx.idx = nil; return; end   -- (no target: the next one gets its entrance)
        idx, fake = 0, true;                                         -- (Edit Mode / preview: a pretend target to place)
    end
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    local name = fake and 'Target' or C.mob_name(ent:GetName(idx));
    if name == nil or name == '' then return; end
    local hpp = fake and 0.65 or ((ent:GetHPPercent(idx) or 0) / 100);
    local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.target_scale) or 1);
    local mdemo = fake and cfg.target_fx == 'link' and C.MD and C.MD.on;   -- (the mode chooser's Hex link demo: on the right)
    local ndemo = fake and cfg.target_fx ~= 'link' and C.MD and C.MD.on;   -- (its Normal demo: bigger, top middle)
    if ndemo then sc = math.min(sc, (tonumber(cfg.scale) or 1) * 1.05); end   -- (the chooser's Normal demo: a normal size, whatever yours is)
    local w, h = (tonumber(cfg.target_w) or 520) * sc, math.max(1, math.floor((tonumber(cfg.target_bar_h) or 4) * sc + 0.5));   -- TARGET > Bar thickness
    local fxs = FIGHT.fxstate(idx, ent, fake);                       -- (TARGET > Entrance, while it plays)
    local tkx, tky = 'target_x', 'target_y';
    local hp_ = nil;                                                  -- (Hex link: the bar sits over the target's head, following it)
    if cfg.target_fx == 'link' and not fake and not EDIT.on then
        local okh, r_ = pcall(C.thead, idx, ent, sc);
        hp_ = okh and r_ or nil;
    end
    if mdemo then local W_, H_ = C.screen(); hp_ = { math.floor(W_ * 0.60), math.floor(H_ * 0.26) }; end
    if ndemo then local W_ = C.screen(); hp_ = { math.floor(W_ / 2 - w / 2 - 6), math.floor(90 * sc) }; end   -- (room over it for Magic Burst)
    if C.GST and C.GST.t and cfg.target_fx == 'link' then hp_ = { C.GST.t[1], C.GST.t[2] }; end   -- (the guide's slide: in its picture)
    if hp_ then cfg._tx, cfg._ty = hp_[1], hp_[2]; tkx, tky = '_tx', '_ty'; WATCH.move = WATCH.move + 1; end
    local topen = plain_window('YunaUI Target##yui_target', tkx, tky);
    if hp_ then WATCH.move = WATCH.move - 1; end
    if topen then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        x, y = x + 6, y + 4;
        local tk, tmi = C.tkind(idx, ent, fake);                     -- TARGET > Friends look: a player / NPC never looks like a monster
        local fm_ = nil;                                             -- (Hex link: a player / NPC uses the monster's layout - see below)
        if cfg.target_fx == 'link' and tk ~= 'mob' then
            fm_ = tmi and member(tmi) or nil;
            local tg_ = fm_ and (fm_.tagtext or (fm_.job and JOBS[fm_.job])) or nil;
            if tg_ then name = tg_ .. '  ' .. name; end
        end
        if tk ~= 'mob' and not FIGHT.show and cfg.target_fx ~= 'link' then   -- (a player or NPC: the Ally banner - not while previewing the fan and casts)
            local used = 0;
            local okf, errf = pcall(function() used = C.tfriend(dl, x, y, w, sc, idx, ent, name, hpp, tk, tmi, dt); end);
            if not okf then pcall(YUI_ERRLOG, 'target friend', errf); end
            if cfg.target_fx == 'link' then pcall(FIGHT.linkdraw, idx, ent, x, y + math.max(10, used) * 0.5, sc, tk); end   -- (TARGET > Entrance: Hex link)
            local bh2 = 0;
            if cfg.buffs then                                        -- its buffs, under it
                local blist, bleft = target_buffs(idx);
                local tbs = tonumber(cfg.target_buff_scale) or tonumber(cfg.buff_scale) or 1;
                local _, bu = draw_buffs(dl, x, y + used + 6 * sc, blist, math.floor(22 * sc * tbs), 16, 2, 1, bleft, nil, cfg.target_buff_tips ~= false);
                bh2 = bu > 0 and (bu + 6 * sc) or 0;
            end
            if cfg.target_fx == 'link' then FIGHT.tbar = { x + w, y + used + 6 * sc, w, os.clock(), sc };   -- (Hex link: the target of target under it)
            else FIGHT.ndemo = { x, y + used + 6 * sc + bh2, w, os.clock() }; end   -- (Normal mode: under it, centred)
            imgui.Dummy({ w + 12, used + 10 + bh2 });
            end_plain(tkx, tky);
            cfg._tx, cfg._ty = nil, nil;
            return;
        end
        local fa_ = fxs and fxs.fa or 1;
        local nla = fxs and fxs.nla or 1;
        if fxs then y = y + fxs.yoff * sc; end
        if fa_ < 1 then imgui.PushStyleVar(ImGuiStyleVar_Alpha, math.max(0.01, fa_)); end
        local top_ = y;
        local pushed = sized('chat', 20 * sc);                       -- (AvantGarde, as the rest of YunaUI)
        local nw, nh = imgui.CalcTextSize(name);
        local fsid = fake and -1 or ent:GetServerId(idx);
        if fake then pcall(FIGHT.preview); else pcall(FIGHT.showing, fsid); end   -- (pretend cast, chain and burst, looping)
        local fullclip = pcall(function() C.fullclip(dl); end);   -- (moved pieces may sit outside the window)
        local tdx, tdy = FIGHT.off('tn');                            -- (Edit Mode: the name can be moved)
        FIGHT.anc.tn = { x, y, nw + 60 * sc, nh };
        local mdx, mdy = FIGHT.off('mb');                            -- the Magic Burst line: its own place (over the bar's start), movable in Edit Mode
        FIGHT.anc.mb = { x, y - nh * 0.85 - 6 * sc, math.min(w, 420 * sc), nh * 0.85 };
        local link = cfg.target_fx == 'link';                         -- (Hex link: one fixed layout - Magic Burst left of the icon, the fan
        if cfg.fight_info ~= false and not link and not (C.GST and C.GST.nobn) then pcall(FIGHT.draw, dl, fsid, x + mdx, y + mdy, w, sc); end   --  right of the bar, the cast under it, 80% of the bar's size)
        local nh0 = nh;                                              -- TARGET > Target name size: the name (and its distance) in its own size
        local nk = math.max(0.5, math.min(2.5, tonumber(cfg.target_name_scale) or 1));
        if nk ~= 1 then
            unsized(pushed);
            pushed = sized('chat', 20 * sc * nk);
            nw, nh = imgui.CalcTextSize(name);
            FIGHT.anc.tn = { x, y, nw + 60 * sc * nk, nh };
        end
        if link then tdx, tdy = math.floor(w * 0.45 - nw / 2), 0; end   -- (Hex link: the name over the bar's middle, a little to the left)
        text(dl, x + tdx, y + tdy, name, { 1, 1, 1, nla });
        do                                                           -- how far it is, just after the name (in yalms)
            local ok, d2 = pcall(function() return ent:GetDistance(idx); end);
            local d = (ok and type(d2) == 'number' and d2 >= 0) and math.sqrt(d2) or nil;
            if d then
                local far = d > 20.8;                                -- (beyond spell range: a soft pink)
                local ds = string.format('%.1f', d);
                local fs = FS or 1;
                imgui.SetWindowFontScale(fs * 0.78);
                local _, dh = imgui.CalcTextSize(ds);
                local da = nla;
                text(dl, x + tdx + nw + 10 * sc, y + tdy + (nh - dh) * 0.75, ds, far and { 1, 0.66, 0.80, da } or { 0.96, 0.95, 1, da });
                imgui.SetWindowFontScale(fs);
            end
        end
        if nk ~= 1 then unsized(pushed); pushed = sized('chat', 20 * sc); end   -- (the HP % keeps the bar's size, on the name's line)
        local pct = string.format('%d%%', math.floor(hpp * 100 + 0.5));
        local pw = imgui.CalcTextSize(pct);
        FIGHT.pctw = 0;
        if link then                                                 -- (Hex link: just after the bar's right end, level with it, its own size -
            local pk = math.max(0.5, math.min(2.0, tonumber(cfg.hl_pct) or 1));   --  TARGET > HP percent size, Hex link mode)
            unsized(pushed); pushed = sized('chat', 20 * sc * pk);
            local pw2, ph2 = imgui.CalcTextSize(pct);
            local bmid = y + nh + 6 + h / 2;
            text(dl, math.floor(x + w + 4 * sc + 0.5), math.floor(bmid - ph2 / 2 + 0.5), pct, { 1, 1, 1, 0.95 * nla });
            FIGHT.pctw, FIGHT.pctx, FIGHT.pcty = pw2 + 4 * sc, x + w + 4 * sc, bmid + ph2 / 2;   -- (the cast goes under it)
        else
            text(dl, x + w - pw, y + (nh - nh0), pct, { 1, 1, 1, 0.95 * nla });
        end
        unsized(pushed);
        local by = y + nh + 6;
        do                                                           -- the bar (Entrance: opening from the middle, lighting up or filling up)
            local lg = lagged('target' .. idx, hpp, dt);
            local bwk, bal, hk = fxs and fxs.bwk or 1, fxs and fxs.bal or 1, fxs and fxs.hk or 1;
            local bx, bw = x + w * (1 - bwk) / 2, w * bwk;
            local pa = bal < 1;
            if pa then imgui.PushStyleVar(ImGuiStyleVar_Alpha, math.max(0.01, bal * fa_)); end
            if bw >= 2 and bal > 0.01 then
                if link then                                         -- (Hex link: its own bar, a stretched hexagon)
                    local cc_ = (cfg.hl_claim ~= false) and C.claimcol(idx, fake) or nil;   -- (TARGET > Claim colour)
                    if tk ~= 'mob' then                              -- (a player: aqua, an NPC: gold - as the Ally banner was)
                        local fc = C.TFRIEND[tk] or C.TFRIEND.pc;
                        cc_ = { { fc[1] * 0.55, fc[2] * 0.55, fc[3] * 0.55 }, fc };
                    end
                    C.hexbar(dl, bx, by, bw, h, hpp * hk, lg * hk, 0.5, cc_ and { c1 = cc_[2], c2 = cc_[1] } or nil);
                    if fm_ and (fm_.mpp or 0) > 0 then               -- (a party member: their MP, a thin azure bar under it)
                        local mh = math.max(2, math.floor(h * 0.5));
                        C.hexbar(dl, bx, by + h + 4 * sc, bw * 0.7, mh, fm_.mpp, fm_.mpp, 0.3, { c1 = C.HEXMP[3], c2 = C.HEXMP[2], band = math.max(4, mh * 2.2) });
                    end
                elseif (cfg.target_look or 'dd2') == 'dd2' then      -- TARGET > Bar style: the glowing bar (its own glow; no overlay, no edge)
                    C.dd2bar(dl, bx, by, bw, h, hpp * hk, lg * hk, 0.5);
                else
                    glow_bar(dl, bx, by, bw, h, hpp * hk, lg * hk, C.tgt1 or { 1, 0.78, 0.96 }, C.tgt2 or C.hp2, 0.5);   -- (BARS > Target bar)
                    bar_overlay(bx, by, bw * hpp * hk, h, bar_fx_for('target'), 0.5, C.fxtint(cfg.target_hp_color or 'pink'));   -- (in the bar's colour)
                    pcall(C.outline, dl, bx, by, bw, h);             -- (a thin black edge: BARS > Black edge)
                end
            end
            if pa then imgui.PopStyleVar(1); end
        end
        if fxs then pcall(FIGHT.fxdraw, fxs, x, top_, by, w, h, sc); end
        if link then pcall(FIGHT.linkdraw, fake and 0 or idx, ent, x, by + h / 2, sc, tk); end   -- (TARGET > Entrance: Hex link)
        local ps = link;                                              -- (Hex link: the skillchain and Magic Burst as the honeycomb at the top)
        if ps and cfg.fight_info ~= false and not (C.GST and C.GST.nobn) then pcall(FIGHT.ps_draw, fsid, sc); end
        if link and not ps and cfg.fight_info ~= false then           -- (Magic Burst, left of the icon, level with the bar)
            pcall(FIGHT.draw, dl, fsid, FIGHT.LBX or (x - FIGHT.LR(sc) * 3.25 - 14 * sc), by + h / 2, w, sc, 'left');   -- (its right edge on the line's bend)
        end
        if cfg.fight_info ~= false and ((cfg.fan_place or 'bar') ~= 'free' or link) and not ps and not (C.GST and C.GST.nobn) then   -- the skillchain fan, to the left (its own size; movable in Edit Mode)
            local fdx, fdy = FIGHT.off('fo');
            local fsc = link and (sc * math.max(0.3, math.min(2.0, tonumber(cfg.hl_fan) or 0.8))) or (sc * FIGHT.fsc());   -- (Hex link: TARGET > Banner size)
            local fw, fh = FIGHT.fan_size(fsc);
            local hx, hy = x - 18 * sc, by + h / 2;
            if link then                                             -- (Hex link: the hub at the bar's right end, the fan opening up and to
                hx, fdx, fdy = x + w + 26 * sc + (FIGHT.pctw or 0), 0, 0;   --  the right, clear of the HP % - mirrored; Edit Mode's offset is for the usual place)
                FIGHT.mir = true;
            end
            FIGHT.anc.fo = { hx - fw + 14 * fsc, hy - 16 * fsc, fw, fh };   -- (both layouts open down and left: the box starts just over the hub, so it can sit at the screen's top)
            pcall(FIGHT.draw_fan, dl, fsid, hx + fdx, hy + fdy, fsc);
            FIGHT.mir = nil;
        end
        local ch = 0;                                                -- what it's casting: under the bar, at its right end
        if cfg.fight_info ~= false and ((cfg.ecast_place or 'bar') ~= 'free' or link) and not (C.GST and C.GST.nocast) then
            local ek = link and math.max(0.3, math.min(2.0, tonumber(cfg.hl_cast) or 0.8)) or math.max(0.4, math.min(2.0, tonumber(cfg.ecast_scale) or 0.75));   -- (TARGET > Enemy cast size; Hex link mode: its own Enemy cast size)
            local csc = sc * ek;
            local cdx, cdy = FIGHT.off('co');                        -- (movable in Edit Mode)
            if link then cdx, cdy = 0, 0; end                        -- (Hex link: right under the bar)
            local cth = math.max(1, math.floor(h * ek + 0.5));       -- (its bar: as long and as thick as Enemy cast size says)
            local ok, used;
            if link then ok, used = pcall(FIGHT.draw_cast_under, dl, fsid, x + w + (FIGHT.pctw or 0), FIGHT.pcty or (by + h), csc);   -- (Hex link: under the bar's right end, ending with the HP %)
            else ok, used = pcall(FIGHT.draw_cast, dl, fsid, x + cdx, by + h + 5 * sc + cdy, w, csc, cth, true, sc * 0.75); end   -- (under the bar's middle; the text has its own size)
            ch = (ok and tonumber(used)) or 0;
            if link then FIGHT.castb, ch = (FIGHT.pcty or (by + h)) + ch, 0; end   -- (Hex link: the cast sits by the HP %; the debuffs keep their row)
            FIGHT.anc.co = { x, by + h + 5 * sc, w, math.max(ch, 18 * csc) };
            if cdx ~= 0 or cdy ~= 0 then ch = 0; end                -- (moved away: the buffs keep their place)
        end
        if link then FIGHT.tbar = { x + w + (FIGHT.pctw or 0), math.max(by + h + 6 * sc, (FIGHT.castb or 0) + 2 * sc), w, os.clock(), sc, x + w, by + h / 2, y }; FIGHT.castb = nil; end
        if not link then FIGHT.ndemo = { x, by + h + 10 * sc + ch, w, os.clock() }; end   -- (Normal mode: the target of target hangs under it)
        if link then FIGHT.drawn.tb = { x - 34 * sc, top_ - 2, w + (FIGHT.pctw or 0) + 40 * sc, (by + h) - top_ + 8 * sc, os.clock() }; end   -- (for the guide's box)   -- (the chooser's Normal demo: the target of target goes under it)   -- (Hex link: the target of target under the bar's right end, out to the HP %'s end, below the cast)
        local bh2 = 0;
        if cfg.buffs then                                            -- its buffs / debuffs, under the bar
            local blist, bleft = target_buffs(idx);                  -- a monster's debuffs come with their time left
            local tbs = tonumber(cfg.target_buff_scale) or tonumber(cfg.buff_scale) or 1;   -- (TARGET > Buffs / debuffs size: its own, not the party's)
            local _, used = draw_buffs(dl, x, by + h + 8 * sc + ch, blist, math.floor(22 * sc * tbs), 16, 2, 1, bleft, nil, cfg.target_buff_tips ~= false);
            bh2 = used > 0 and (used + 6 * sc) or 0;
        end
        if not link and FIGHT.ndemo then FIGHT.ndemo[2] = FIGHT.ndemo[2] + bh2; end   -- (under its debuffs too)
        imgui.Dummy({ w + 12, nh + h + 18 + bh2 + ch });
        if fullclip then pcall(function() dl:PopClipRect(); end); end
        if fa_ < 1 then imgui.PopStyleVar(1); end
        end_plain(tkx, tky);
        cfg._tx, cfg._ty = nil, nil;
    else
        imgui.End(); imgui.PopStyleVar(2);
        cfg._tx, cfg._ty = nil, nil;
    end
end

----------------------------------------------------------------------------------------------------
-- Target of target: who your target is fighting / targeting (its last attack, spell or skill in the last 30 s, else
-- the one the game says it's looking at; you, if you target yourself). While you pick a sub target (<st>) it shows
-- that instead. Its name and HP over a cool blue bar.
----------------------------------------------------------------------------------------------------
local function tot_index(idx)
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    local me = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
    if idx == me then return me; end
    local sid = ent:GetServerId(idx);
    local h = LASTHIT[sid];
    if h and os.clock() - h.t < 30 then
        local ti = index_of(h.id);
        if ti then return ti; end
    end
    local ok, ti = pcall(function() return ent:GetTargetedIndex(idx); end);
    if ok and ti and ti > 0 then return ti; end
    return nil;
end
local function draw_subtarget(dt)
    if not cfg.subtarget then return; end
    local main, sub = target_index();
    local preview = SUBPREVIEW and SUBPREVIEW() or false;
    local idx, tag = nil, 'TARGET';
    if sub and sub ~= 0 then idx, tag = sub, 'SUB';
    elseif main and main ~= 0 then
        local ok, ti = pcall(tot_index, main);
        if ok then idx = ti; end
    end
    if (idx == nil or idx == 0) and not preview then return; end
    if cfg.target_fx == 'link' and tag ~= 'SUB' and idx == main and not preview then return; end   -- (Hex link: yourself again under yourself - no)
    local name, hpp = 'Yunas', 0.7;
    if idx and idx ~= 0 then
        local ent = AshitaCore:GetMemoryManager():GetEntity();
        name = C.mob_name(ent:GetName(idx));
        if name == nil or name == '' then return; end
        hpp = (ent:GetHPPercent(idx) or 0) / 100;
    end
    local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.sub_scale) or 1);
    local w, h = (tonumber(cfg.sub_w) or 300) * sc, math.max(2, math.floor(3 * sc));
    local skx, sky = 'sub_x', 'sub_y';
    local TB = FIGHT.tbar;                                            -- (Hex link: hung under the target bar's right end, right-aligned with it,
    local hang = cfg.target_fx == 'link' and TB and os.clock() - TB[4] < 0.3 and not EDIT.on;   --  at 80% of its size)
    if cfg.target_fx == 'link' and not hang then return; end         -- (Hex link: only hung off the target bar, never floating on its own - not even in Edit Mode)
    local ND = FIGHT.ndemo;                                          -- (the chooser's Normal demo: under the target bar, centred)
    local nd = (not hang) and cfg.target_fx ~= 'link' and ND and os.clock() - ND[4] < 0.3;   -- (Normal mode: always under the target bar)
    if nd then
        cfg._sbx, cfg._sby = math.floor(ND[1] + ND[3] / 2 - w / 2), math.floor(ND[2] + 6);
        skx, sky = '_sbx', '_sby';
        WATCH.move = WATCH.move + 1;
    end
    if hang then
        sc = TB[5] * math.max(0.3, math.min(2.0, tonumber(cfg.hl_tot) or 0.8));                                             -- (TARGET > Target of target size in Hex link mode, a share of the target bar)
        w, h = math.min((tonumber(cfg.sub_w) or 300) * sc, TB[3] * 0.6), math.max(2, math.floor(3 * sc));
        local toth = 15 * sc * 1.25 + h + 16;                         -- (about its height)
        local wy_ = TB[8] and (TB[8] - toth - 2 * sc) or TB[2];      -- (over the name's row, popping up from the bar's end)
        cfg._sbx, cfg._sby = math.floor(TB[1] - w - 6 + 0.5), math.floor(wy_ + 0.5);
        skx, sky = '_sbx', '_sby';
        WATCH.move = WATCH.move + 1;
    end
    local sopen = plain_window('YunaUI Subtarget##yui_sub', skx, sky);
    if hang or nd then WATCH.move = WATCH.move - 1; end
    local slide = 0;
    if hang and sopen and TB[6] then                                  -- (Hex link: a thin line from the bar's end up into it)
        local A = C.TOTA or {};
        C.TOTA = A;
        if A.idx ~= (idx or 0) or A.t0 == nil then A.idx, A.t0 = idx or 0, os.clock(); end   -- (a new one - or the preview's: the line grows up, then it rises in from it)
        local g = FIGHT.fx_eo((os.clock() - A.t0) / 0.22);
        local ex, ey = TB[6], TB[7];
        local wx, wy = imgui.GetCursorScreenPos();
        local ty_ = wy + 4 + 15 * sc * 1.25 + 5 + 1.5 * sc;            -- (up to its own bar)
        local ly = (ey - h) + (ty_ - (ey - h)) * g;
        local fgd = nil;
        pcall(function() fgd = imgui.GetForegroundDrawList(); end);
        if fgd then
            DL.L(fgd, ex, ey - h, ex, ly, U4(0, 0, 0, 0.6), 3);
            DL.L(fgd, ex, ey - h, ex, ly, U4(0.55, 0.85, 1.0, 0.95), 1.4);
            DL.CF(fgd, ex, ey, 2.2 * sc, U4(0.85, 0.96, 1.0, 1), 10);   -- (where it hangs from)
            if g < 1 then DL.CF(fgd, ex, ly, 2 * sc, U4(1, 1, 1, 0.95), 10); end
        end
        slide = (1 - FIGHT.fx_eo((os.clock() - A.t0 - 0.15) / 0.22)) * 10 * sc;
        if os.clock() - A.t0 < 0.15 then sopen = 'line'; end           -- (the bar waits for the line)
    end
    if sopen == 'line' then
        imgui.Dummy({ w + 12, 10 });
        end_plain(skx, sky);
    elseif sopen then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        x, y = x + 6, y + 4 + slide;                                  -- (Hex link: rising in from the line)
        local pushed = sized('semi', 15 * sc);
        local nw, nh = imgui.CalcTextSize(name);
        local fs = FS;
        imgui.SetWindowFontScale(fs * 0.7);
        local label = (tag == 'SUB') and 'SUB ' or '> ';
        local tw = imgui.CalcTextSize(label);
        text(dl, x, y + nh * 0.18, label, { 0.55, 0.85, 1, 0.9 });
        imgui.SetWindowFontScale(fs);
        text(dl, x + tw, y, name, { 1, 1, 1, 1 });
        local pct = string.format('%d%%', math.floor(hpp * 100 + 0.5));
        local pw = imgui.CalcTextSize(pct);
        text(dl, x + w - pw, y, pct, { 0.8, 0.92, 1, 1 });
        unsized(pushed);
        local by = y + nh + 5;
        if hang then                                                  -- (Hex link: its bar in the same hexagon style)
            C.hexbar(dl, x, by, w, h, hpp, lagged('sub' .. tostring(idx), hpp, dt), 0, { c1 = { 0.80, 0.96, 1.00 }, c2 = { 0.35, 0.65, 1.00 }, band = math.max(5, h * 1.8) });
        else
            glow_bar(dl, x, by, w, h, hpp, lagged('sub' .. tostring(idx), hpp, dt), { 0.80, 0.96, 1.00 }, { 0.35, 0.65, 1.00 }, 4.4);
        end
        FIGHT.drawn.tot = { x - 2, y - 2, w + 4, nh + h + 10, os.clock() };   -- (for the guide's box)
        imgui.Dummy({ w + 12, nh + h + 16 });
        end_plain(skx, sky);
    else
        imgui.End(); imgui.PopStyleVar(2);
    end
    cfg._sbx, cfg._sby = nil, nil;
end
----------------------------------------------------------------------------------------------------
-- Enemy list: the monsters fighting you and your party, each with its name, HP %, a thin red bar and the debuffs seen
-- on it; the one you're targeting is marked. Click one to target it.
----------------------------------------------------------------------------------------------------
local function draw_enemies(dt)
    if not cfg.enemylist then return; end
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    local list = {};
    local preview = SUBPREVIEW and SUBPREVIEW() or false;
    for idx in pairs(ENGAGED) do
        local ok, valid, nm, hp = pcall(function()
            if idx >= 0x400 or is_party_id(ent:GetServerId(idx)) then return false; end   -- (trusts, pets, players: not enemies)
            local rf = ent:GetRenderFlags0(idx);
            local vis = bit.band(rf, 0x200) == 0x200 and bit.band(rf, 0x4000) == 0;
            return vis and (ent:GetHPPercent(idx) or 0) > 0, C.mob_name(ent:GetName(idx)), ent:GetHPPercent(idx);
        end);
        if ok and valid and nm and nm ~= '' then list[#list + 1] = { idx = idx, name = nm, hp = (hp or 0) / 100 };
        else ENGAGED[idx] = nil; end
    end
    if #list == 0 and preview then
        list = { { idx = -1, name = 'Goblin Smithy', hp = 0.75 }, { idx = -2, name = 'Yagudo Templar', hp = 0.4 }, { idx = -3, name = 'Crab', hp = 0.15 } };
    end
    if #list == 0 then return; end
    table.sort(list, function(a, b) return a.idx < b.idx; end);
    local maxn = math.max(1, math.floor(tonumber(cfg.enemy_max) or 8));
    local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.enemy_scale) or 1);
    local w = (tonumber(cfg.enemy_w) or 200) * sc;
    local bh = math.max(2, math.floor(3 * sc));
    local tidx = target_index();
    if plain_window('YunaUI Enemies##yui_enemies', 'enemy_x', 'enemy_y') then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        x, y = x + 8, y + 4;
        local pushed = sized('chat', 14 * sc);
        local lh = imgui.GetTextLineHeight();
        local fs = FS;
        imgui.SetWindowFontScale(fs * 0.75);
        text(dl, x, y, 'ENEMIES', { C.muted[1], C.muted[2], C.muted[3], 0.9 });
        local hh = imgui.GetTextLineHeight();
        imgui.SetWindowFontScale(fs);
        local ry = y + hh + 4 * sc;
        local rowh = lh + bh + 10 * sc;
        local isz = math.floor(14 * sc * (tonumber(cfg.buff_scale) or 1) * (tonumber(cfg.enemy_buff_scale) or 1));   -- (ENEMY LIST > Debuff icon size)
        for k = 1, math.min(#list, maxn) do
            local e = list[k];
            local on = (e.idx == tidx);
            if on then                                               -- your target: a soft frame and a marker
                DL.RF(dl, x - 6, ry - 2, x + w + 6, ry + rowh - 4, U4(C.gold[1], C.gold[2], C.gold[3], 0.12), 5);
                DL.TF(dl, x - 12, ry + lh / 2 - 4, x - 12, ry + lh / 2 + 4, x - 7, ry + lh / 2, U4(1, 1, 1, 0.9));
            end
            local nm = e.name;
            local pct = string.format('%d%%', math.floor(e.hp * 100 + 0.5));
            local pw = imgui.CalcTextSize(pct);
            while #nm > 3 and imgui.CalcTextSize(nm) > w - pw - 10 do nm = nm:sub(1, #nm - 2); end
            if nm ~= e.name then nm = nm .. '..'; end
            text(dl, x, ry, nm, { 1, 1, 1, 1 });
            text(dl, x + w - pw, ry, pct, { 1, 0.75, 0.7, 1 });
            glow_bar(dl, x, ry + lh + 3 * sc, w, bh, e.hp, lagged('en' .. e.idx, e.hp, dt), { 1.00, 0.62, 0.45 }, { 0.92, 0.22, 0.28 }, e.idx * 0.7);
            -- the debuffs seen landing on it, small, to its right
            if cfg.buffs and e.idx > 0 then
                local sid = ent:GetServerId(e.idx);
                local d, now = enemies[sid], os.clock();
                if d then                                            -- its debuffs, each with the time it has left under it (sleep, bind...)
                    local ids, left = {}, {};
                    for st, exp in pairs(d) do if exp > now then ids[#ids + 1] = st; left[st] = exp - now; end end
                    table.sort(ids);
                    if #ids > 0 then                                 -- (ENEMY LIST > Debuff text size: its timers' own size)
                        BUFFS.tk = tonumber(cfg.enemy_buff_text) or 1;
                        draw_buffs(dl, x + w + 10 * sc, ry + (rowh - isz) / 2 - 3 - isz * 0.28, ids, isz, 8, 1, 1, left);
                        BUFFS.tk = nil;
                    end
                end
            end
            if e.idx > 0 then                                        -- click: target it
                imgui.SetCursorScreenPos({ x - 6, ry - 2 });
                if imgui.InvisibleButton('##yui_en' .. e.idx, { w + 12, rowh - 2 }) then
                    local sid = ent:GetServerId(e.idx);
                    if sid and sid > 0 then AshitaCore:GetChatManager():QueueCommand(-1, '/target ' .. sid); end
                end
            end
            ry = ry + rowh;
        end
        unsized(pushed);
        imgui.SetCursorScreenPos({ x - 8, y - 4 });
        imgui.Dummy({ w + 16 + 8 * (isz + 2), ry - y + 8 });
        end_plain('enemy_x', 'enemy_y');
    else
        imgui.End(); imgui.PopStyleVar(2);
    end
end

----------------------------------------------------------------------------------------------------
-- Party / alliance: a row per member: job icon, name, level, HP and MP bars with their numbers
----------------------------------------------------------------------------------------------------
-- The hats' animation (a setting, "Hat animation"): none, float, sway, pulse, glint, halo
local function hat_anim(dl, jt, job, x, y, icon, sc, ia, i)
    local mode = 'none';                                             -- (the other animations are kept, not offered)
    local t = os.clock() + i * 1.1;
    if job == nil or jt == nil then return; end                      -- job not known yet (just joined, a trust...)
    local hl = (mode ~= 'none') and tex('jobs_halo/' .. job:lower() .. '.png') or nil;
    local g = icon * 0.10;
    if mode == 'float' then                                          -- bobs gently, a soft shadow under it
        local fy = math.sin(t * 1.3) * 1.6 * sc;
        local up = 0.5 - 0.5 * math.sin(t * 1.3);
        local sw = icon * (0.34 - 0.05 * up);
        for k = 1, 3 do DL.CF(dl, x + icon / 2, y + icon * 0.96, sw * (1 - k * 0.2), U4(0, 0, 0, (0.10 - 0.03 * up) * ia), 20); end
        image(dl, jt, x, y + fy, x + icon, y + icon + fy, { 1, 1, 1, ia });
    elseif mode == 'sway' then                                       -- tilts a little side to side, from its base
        local ang = math.rad(math.sin(t * 1.1) * 5);
        local cx, cy = x + icon / 2, y + icon * 0.85;
        local function rot(px, py)
            local dx, dy = px - cx, py - cy;
            return { cx + dx * math.cos(ang) - dy * math.sin(ang), cy + dx * math.sin(ang) + dy * math.cos(ang) };
        end
        local ok = jt and pcall(function()
            dl:AddImageQuad(jt.ptr, rot(x, y), rot(x + icon, y), rot(x + icon, y + icon), rot(x, y + icon),
                { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, U4(1, 1, 1, ia));
        end);
        if not ok then image(dl, jt, x, y, x + icon, y + icon, { 1, 1, 1, ia }); end
    elseif mode == 'pulse' then                                      -- swells a touch and back, like breathing
        local k = icon * 0.035 * (0.5 + 0.5 * math.sin(t * 1.8));
        image(dl, jt, x - k, y - k, x + icon + k, y + icon + k, { 1, 1, 1, ia });
    elseif mode == 'glint' then                                      -- every few seconds a quick soft flash of light
        local ph = (t / 5) % 1;
        local f = (ph < 0.12) and math.sin(ph / 0.12 * math.pi) or 0;
        if f > 0.01 then image(dl, hl, x - g, y - g, x + icon + g, y + icon + g, { 1, 0.95, 0.85, 0.45 * f * ia }); end
        image(dl, jt, x, y, x + icon, y + icon, { 1, 1, 1, ia });
    elseif mode == 'halo' then                                       -- still, a faint light breathing behind it
        local br = 0.5 + 0.5 * math.sin(t * 1.2);
        image(dl, hl, x - g, y - g, x + icon + g, y + icon + g, { 1, 0.95, 0.85, (0.06 + 0.14 * br) * ia });
        image(dl, jt, x, y, x + icon, y + icon, { 1, 1, 1, ia });
    else                                                             -- none
        image(dl, jt, x, y, x + icon, y + icon, { 1, 1, 1, ia });
    end
end
-- The member you're targeting: your triangle (images/arrow.png) over their job icon, pointing down, still, in the
-- target bar's look, all inside the shape: its two colours flowing down through it and a sheen sliding down.
-- The colours are settings (PARTY tab > TARGET ARROW).
local ARROW_V0, ARROW_V1 = 0.289, 0.711;                            -- where the shape sits, top to bottom, in arrow.png
local function target_arrow(dl, cx, y, sc)
    local t1, tg = tex('arrow.png'), tex('arrow_glow.png');
    if t1 == nil then return; end
    local now = os.clock();
    local pulse = 0.5 + 0.5 * math.sin(now * 2.2);
    local c1 = (type(cfg.arrow_c1) == 'table') and cfg.arrow_c1 or { 1.00, 0.78, 0.96 };
    local c2 = (type(cfg.arrow_c2) == 'table') and cfg.arrow_c2 or { C.hp2[1], C.hp2[2], C.hp2[3] };
    local S = 22 * sc * (tonumber(cfg.arrow_scale) or 1);           -- the picture's square; the shape is ~3/4 as wide
    local x1, top = cx - S / 2, y - S * ARROW_V1;                    -- the point ends just above the icon
    -- (no glow outside it: the effect stays inside the shape)
    -- the fill in strips: the colours flow down through it, a sheen slides down now and then
    local n = 10;
    local sh = (now * 0.9) % 1.6 - 0.3;
    for k = 0, n - 1 do
        local fa, fb = k / n, (k + 1) / n;
        local va, vb = ARROW_V0 + (ARROW_V1 - ARROW_V0) * fa, ARROW_V0 + (ARROW_V1 - ARROW_V0) * fb;
        local u = 0.5 + 0.5 * math.sin((fa * 1.2 - now * 0.35) * math.pi * 2);
        local col = { c1[1] + (c2[1] - c1[1]) * u, c1[2] + (c2[2] - c1[2]) * u, c1[3] + (c2[3] - c1[3]) * u };
        local s = math.max(0, 1 - math.abs(fa - sh) / 0.3) * 0.55;
        col = { col[1] + (1 - col[1]) * s, col[2] + (1 - col[2]) * s, col[3] + (1 - col[3]) * s, 1 };
        pcall(function()
            DL.I(dl, t1.ptr, x1, top + S * va, x1 + S, top + S * vb, 0, va, 1, vb, u32(col));
        end);
    end
end
-- The glow line under your target's MP bar: which streak (glow0 = the golden flare, glow1-3 = the user's blue
-- streaks, all white so they take any colour), its colour, brightness and animation are settings (PARTY tab)
local GLOW_FX = {
    [4] = { dir = 'inferno', fmt = '%s/%02d.png', n = 41, fps = 24, aspect = 56 / 512 },                 -- Blue Inferno (loops)
    [5] = { dir = 'paint',   fmt = '%s/%03d.png', n = 60, fps = 30, aspect = 41 / 512, tint = true, once = true },   -- Paint Stroke
    [6] = { dir = 'spell',   fmt = '%s/%03d.png', n = 75, fps = 15, aspect = 79 / 384 },                 -- Magic Spell (loops)
    [7] = { dir = 'bolt',    fmt = '%s/%02d.png', n = 24, fps = 30, aspect = 158 / 512 },                -- Looping Blaster Bolt
};
local function glow_line(dl, cx, cy, w, h, sc, seed)
    local style = tonumber(cfg.glow_style) or 0;
    local now = os.clock();
    local t, c;
    local fx = GLOW_FX[style];
    if fx then
        -- one of the user's animated effects (FootageCrate frames): played in a loop, or drawn once when you pick a new
        -- target and then held; in their own colours unless they're white (then the Glow colour)
        if GLOW_FX.seed ~= seed then GLOW_FX.seed, GLOW_FX.t0 = seed, now; end
        local k = math.floor((now - (GLOW_FX.t0 or now)) * fx.fps);
        k = fx.once and math.min(fx.n - 1, k) or (k % fx.n);
        t = tex(string.format(fx.fmt, fx.dir, k));
        c = fx.tint and ((type(cfg.glow_col) == 'table') and cfg.glow_col or { 1, 1, 1 }) or { 1, 1, 1 };
        h = w * fx.aspect;                                           -- the effect's own shape
    else
        t = tex('glow' .. style .. '.png');
        c = (type(cfg.glow_col) == 'table') and cfg.glow_col or { 1.00, 0.80, 0.45 };
    end
    if t == nil then return; end
    local b = tonumber(cfg.glow_bright) or 1.3;
    local anim = cfg.glow_anim or 'breathe';
    local x1, y1 = cx - w / 2, cy - h / 2;
    local k = 1;                                                     -- how bright it is right now (0..1+)
    if anim == 'breathe' then k = 0.8 + 0.2 * math.sin(now * 2.2 + seed);
    elseif anim == 'fade' then k = 0.5 - 0.5 * math.cos(now * 2.4 + seed);
    elseif anim == 'thunder' then                                    -- dim, then sudden bright flickers
        local tick = math.floor(now * 12);
        local r = frac(math.sin(tick * 12.9898 + seed * 7.1) * 43758.5453);
        k = (r > 0.82) and (1.1 + r * 0.4) or 0.45;
    elseif anim == 'electric' then k = 0.75 + 0.25 * math.sin(now * 5 + seed); end
    local function pass(alpha)
        if anim == 'wave' then                                       -- light travelling along it in waves
            local n = 16;
            for s = 0, n - 1 do
                local f1, f2 = s / n, (s + 1) / n;
                local a = alpha * (0.45 + 0.55 * (0.5 + 0.5 * math.sin((f1 * 2 - now * 0.9) * math.pi * 2)));
                pcall(function()
                    DL.I(dl, t.ptr, x1 + w * f1, y1, x1 + w * f2, y1 + h, f1, 0, f2, 1, U4(c[1], c[2], c[3], math.min(1, a)));
                end);
            end
        else
            image(dl, t, x1, y1, x1 + w, y1 + h, { c[1], c[2], c[3], math.min(1, alpha) });
        end
    end
    local total = b * k;
    while total > 0.01 do pass(math.min(1, total)); total = total - 1; end    -- above 1: drawn again on top, brighter
    if anim == 'electric' then                                       -- thin crackling threads along the line
        local tick = math.floor(now * 14);
        local px, py = x1 + w * 0.15, cy;
        local kk = 0;
        while px < x1 + w * 0.85 do
            kk = kk + 1;
            local r = frac(math.sin(tick * 31.7 + kk * 12.9898 + seed * 3.3) * 43758.5453);
            local nx = math.min(x1 + w * 0.85, px + (4 + 8 * frac(r * 7.7)) * sc);
            local ny = cy + (r - 0.5) * h * 0.35;
            DL.L(dl, px, py, nx, ny, U4(1, 1, 1, 0.55 * k), 1);
            px, py = nx, ny;
        end
    end
end
-- cols: how the members are laid out (the list's 'Layout' setting): 1 = one under the other, 6 = side by side,
-- 2 or 3 = a grid. With more than one column the buffs go under each member instead of to the left.
local function draw_members(dl, x0, y, first, n, small, dt, tidx, scl, cols)
    cols = cols or 1;
    local sc = (tonumber(cfg.scale) or 1) * (scl or tonumber(small and cfg.alliance_scale or cfg.party_scale) or 1);
    local base_icon = (small and 22 or 30) * sc;
    local ikey = (first >= 12 and 'ally2_icon') or (first >= 6 and 'ally1_icon') or 'icon_scale';   -- (party / alliance 1 / alliance 2: each its own)
    local icon = base_icon * math.max(0.4, math.min(2.5, tonumber(cfg[ikey]) or 1));   -- 'Job icons' size
    local bw = (small and 110 or 150) * sc;
    local bsz = math.floor(20 * sc * (tonumber(cfg.buff_scale) or 1));
    local rowh = (small and 30 or 42) * sc + ((cols > 1 and cfg.buffs and not small) and (bsz + 6 * sc) or 0);
    local thx = math.max(0, (math.max(1, math.min(10, tonumber(cfg.party_bar_h) or 3)) - 3)) * sc;   -- (thicker bars: a taller row)
    rowh = rowh + (small and thx * 4 / 3 or thx * 2);
    rowh = math.max(10 * sc, rowh + (tonumber(cfg.party_vgap) or 0) * sc);   -- PARTY > Space between rows
    local colw = icon + bw + 70 * sc + 14 * sc + (tonumber(cfg.party_gap) or 0) * sc;   -- PARTY > Space between members
    local shown = 0;
    for i = first, first + n - 1 do
        local m = member(i);
        if m then
            local col, row = shown % cols, math.floor(shown / cols);
            local x = x0 + col * colw;
            local ry = y + row * rowh;
            local targeted = (m.idx ~= 0 and m.idx == tidx);
            local mark = 'flare';                                    -- your target in the party: the glow (the arrow is kept, not offered)
            if targeted and (mark == 'flare' or mark == 'both') then
                -- a bright golden streak of light just under the MP bar, breathing softly
                local bx0 = x + icon + 8 * sc;                         -- where the bars start
                local fw = bw * 1.35;
                local fcx = bx0 + bw / 2;
                local th_ = math.max(1, math.min(10, tonumber(cfg.party_bar_h) or 3));
                local bh_ = math.max(1, math.floor((small and th_ * 2 / 3 or th_) * sc + 0.5));
                local by_ = ry + (small and 17 or 20) * sc;
                local fcy = small and (by_ + bh_ + 6 * sc) or (by_ + bh_ * 2 + 5 * sc + 4 * sc);   -- just under the MP bar, however thick the bars are
                local fh = 16 * sc;
                glow_line(dl, fcx, fcy, fw * (tonumber(cfg.glow_len) or 1), fh, sc, i);
            end
            local style = 'hats';                                    -- the hats, still (the standard look)
            local iy = ry + (base_icon - icon) / 2;                  -- centred on the row whatever its size
            local glow = (style == 'glow' or style == 'line');
            -- the hats come ready-sized (32 / 48 / 64 px, sharpened, dark ones lifted, a thin dark edge): the nearest size
            -- at or above the one drawn, so they stay crisp instead of being squeezed down from 128 px every frame
            local hd = (icon <= 34 and 'jobs_32/') or (icon <= 52 and 'jobs_48/') or (icon <= 70 and 'jobs_64/') or 'jobs/';
            local dir = (style == 'glow' and 'jobs_glow/') or (style == 'line' and 'jobs_line/') or hd;
            local jt = JOBS[m.job or 0] and tex(dir .. JOBS[m.job]:lower() .. '.png') or nil;
            local ia = m.inzone and 1 or 0.4;
            if glow then
                -- the glowing symbols breathe softly: a faint, slightly bigger copy swells and fades behind it
                local br = 0.5 + 0.5 * math.sin(os.clock() * 1.6 + i * 0.9);
                local g = icon * (0.06 + 0.05 * br);
                local hc = (style == 'line') and { 0.75, 0.7, 1 } or { 1, 0.9, 0.7 };
                image(dl, jt, x - g, ry - g, x + icon + g, ry + icon + g, { hc[1], hc[2], hc[3], (0.10 + 0.12 * br) * ia });
                image(dl, jt, x, iy, x + icon, iy + icon, { 1, 1, 1, (0.88 + 0.12 * br) * ia });
            elseif small or not cfg.buffs or m.name == nil then
                hat_anim(dl, jt, JOBS[m.job or 1], x, iy, icon, sc, ia, i);
            else
                BUFFS.job_icon(dl, jt, JOBS[m.job or 1], m, x, iy, icon, sc, ia, i);
            end
            if targeted and (mark == 'arrow' or mark == 'both') then  -- your target: the arrow over its icon
                -- drawn on top of everything (never cut off by the window's edge, even with big icons on the first row),
                -- its point resting just inside the icon's top so it stays with the icon at any size
                local fl = dl;
                pcall(function() fl = imgui.GetForegroundDrawList() or dl; end);
                target_arrow(fl, x + icon / 2, iy + icon * 0.08, sc);
            end
            local tx = x + icon + 8 * sc;
            local nm = m.name or '';
            local alpha = m.inzone and 1 or 0.5;
            local nx = tx;
            local lstyle = 'dots';                                    -- (the leader's mark: YunaUI dots)
            if (m.leader or m.aleader) and lstyle ~= 'none' and lstyle ~= 'name' then   -- the leader's mark before the name
                local lh = imgui.GetTextLineHeight();
                local r = math.max(4, lh * 0.34);
                local mw = (lstyle == 'crown') and r * 2.3 or ((lstyle == 'dots' and m.aleader) and r * 2.6 or r * 2);
                LEAD_MARK(dl, tx + mw / 2, ry - 2 + lh * 0.50, r, m.aleader, alpha, lstyle);
                nx = tx + mw + 5 * sc;
            end
            text(dl, nx, ry - 2, nm, { 1, 1, 1, alpha });
            if (m.leader or m.aleader) and lstyle == 'name' then
                local nw, nh = imgui.CalcTextSize(nm);
                LEAD_UNDERLINE(dl, nx, ry - 2 + nh + 1, nw, m.aleader, alpha);
            end

            if m.inzone then
                local by = ry + (small and 17 or 20) * sc;
                local th = math.max(1, math.min(10, tonumber(cfg.party_bar_h) or 3));   -- PARTY > Bar thickness
                local bh = math.max(1, math.floor((small and th * 2 / 3 or th) * sc + 0.5));
                glow_bar(dl, tx, by, bw, bh, m.hpp, lagged('hp' .. i, m.hpp, dt), C.hpb1, C.hpb2, i);
                bar_overlay(tx, by, bw * math.max(0, math.min(1, m.hpp or 0)), bh, bar_fx_for((first < 6) and 'party' or 'alliance'), i);
                if not small then
                    glow_bar(dl, tx, by + bh + 5 * sc, bw, bh, m.mpp, lagged('mp' .. i, m.mpp, dt), C.mpb1 or C.mp, C.mpb2 or C.mp2, i + 30);
                    local fs = FS;
                    imgui.SetWindowFontScale(fs * 0.82);
                    text(dl, tx + bw + 8 * sc, by - 6 * sc, tostring(m.hp), { 1, 0.80, 0.88, 1 });
                    text(dl, tx + bw + 8 * sc, by + 4 * sc, tostring(m.mp), { 0.78, 0.82, 1, 1 });
                    -- TP: on the name line, lined up with the end of the bars. Soft gold under 1000; at 1000+ (a
                    -- weapon skill is ready) bright gold that breathes
                    local tp = tonumber(m.tp) or 0;
                    local tps = tostring(tp);
                    local tw = imgui.CalcTextSize(tps);
                    local lw = imgui.CalcTextSize('TP ');
                    local tpx, tpy = tx + bw - tw, ry - 1;
                    if tp >= 1000 then
                        local br = 0.5 + 0.5 * math.sin(os.clock() * 4 + i);
                        text(dl, tpx, tpy, tps, { 1, 0.86 + 0.1 * br, 0.35 + 0.3 * br, 1 });
                    else
                        text(dl, tpx, tpy, tps, { 0.82, 0.76, 0.55, 0.85 });
                    end
                    text(dl, tpx - lw, tpy, 'TP', { C.muted[1], C.muted[2], C.muted[3], 0.8 });
                    imgui.SetWindowFontScale(fs);
                end
            end
            if not small and cfg.buffs then
                local bs = bsz;
                local list = member_buffs(i);
                if cols > 1 then                                     -- in a row or grid: under the member
                    draw_buffs(dl, x + icon + 8 * sc, ry + rowh - bs - 6 * sc, list, bs, math.max(1, math.floor((bw + 60 * sc) / (bs + 2))), 1, 1, nil, BUFFS.val(m.name or i));
                else                                                 -- in a column: to the left of the job icon
                    local top = (#list > 16) and (ry - 1 * sc) or (ry + (rowh - bs) / 2 - 4 * sc);
                    draw_buffs(dl, x - 6 * sc, top, list, bs, 16, 2, -1, nil, BUFFS.val(m.name or i));
                end
            end
            shown = shown + 1;
        end
    end
    local used_cols = math.min(cols, math.max(1, shown));
    return math.ceil(shown / cols) * rowh, (cols > 1) and (used_cols * colw - 14 * sc) or (icon + bw + 70 * sc);
end
-- A party member's job icon, alive: the mouse over it lifts and grows it a little; a click folds that member's buffs
-- into it (the icon gives a little bounce) and again brings them back.
function BUFFS.job_icon(dl, jt, job, m, x, y, icon, sc, ia, i)
    local key = m.name;
    imgui.SetCursorScreenPos({ x, y });
    local clicked = imgui.InvisibleButton('##yui_jobicon' .. i, { icon, icon });
    local hov = imgui.IsItemHovered();
    if clicked then BUFFS.flip(key); end
    BUFFS.hv = BUFFS.hv or {};
    local h = BUFFS.hv[key] or 0;                                    -- the hover, eased in and out
    h = h + ((hov and 1 or 0) - h) * math.min(1, BUFFS.dt * 10);
    BUFFS.hv[key] = h;
    local k = 1 + 0.08 * h;
    local t = os.clock() - (BUFFS.pop[key] or -9);
    if t < 0.35 then k = k + 0.22 * math.sin(math.pi * t / 0.35) * (1 - t / 0.35); end   -- the bounce
    local cx, cy = x + icon / 2, y + icon / 2 - 2 * sc * h;
    local s2 = icon * k;
    hat_anim(dl, jt, job, cx - s2 / 2, cy - s2 / 2, s2, sc, ia, i);
end
-- Edit Mode: where a piece of size w x h at (x, y) should snap. Lines up its left / middle / right (and top / middle /
-- bottom) with the other pieces' and with the screen's middle when within 10 px; otherwise the 8 px grid.
EDIT.NAMES = { target_x = 'Target', sub_x = 'Sub-target', enemy_x = 'Enemies', party_x = 'Party', alliance_x = 'Alliance 1',
               ally2_x = 'Alliance 2', exp_x = 'Exp', gil_x = 'Gil', bag_x = 'Bag', cast_x = 'Cast bar', timer_x = 'Timers',
               pet_x = 'Pet', doll_x = 'Equipment', strip_x = 'Gear strip', logo_x = 'Logo', mini_x = 'Logo',
               fan_x = 'Skillchain fan', ecast_x = 'Enemy cast', tn_x = 'Target name', mb_x = 'Magic Burst', fo_x = 'Skillchain', co_x = 'Enemy cast',
               loot_x = 'Treasure pool' };
EDIT.HEXOFF = { tn_x = true, mb_x = true, fo_x = true, co_x = true, fan_x = true, ecast_x = true, sub_x = true };   -- (Hex link: these follow the
function EDIT.listed(k) return EDIT.NAMES[k] and not (cfg.target_fx == 'link' and EDIT.HEXOFF[k]); end       --  target bar or the top - not placed)
EDIT.SIZE = { target_x = { 'target_scale', 0.6, 2.0 }, sub_x = { 'sub_scale', 0.6, 2.0 }, enemy_x = { 'enemy_scale', 0.6, 2.0 },
              party_x = { 'party_scale', 0.6, 2.0 }, alliance_x = { 'ally1_scale', 0.6, 2.0 }, ally2_x = { 'ally2_scale', 0.6, 2.0 },
              exp_x = { 'exp_scale', 0.5, 2.5 }, gil_x = { 'gb_scale', 0.5, 2.5 }, bag_x = { 'gb_scale', 0.5, 2.5 },
              cast_x = { 'cast_scale', 0.6, 2.0 }, timer_x = { 'timers_scale', 0.6, 2.0 }, pet_x = { 'pet_scale', 0.6, 2.0 },
              loot_x = { 'loot_scale', 0.6, 2.0 }, fan_x = { 'fan_scale', 0.4, 2.0 }, fo_x = { 'fan_scale', 0.4, 2.0 },
              ecast_x = { 'ecast_scale', 0.4, 2.0 }, co_x = { 'ecast_scale', 0.4, 2.0 }, mb_x = { 'mb_scale', 0.5, 2.5 },
              tn_x = { 'target_name_scale', 0.5, 2.5 } };
-- Edit Mode's resize grips: one at each piece's bottom-right corner; dragging it changes that piece's Size (grows to the
-- right and down, its top-left corner stays). EDIT.rs = the one being dragged; EDIT.rs_hot = the mouse is on a grip
-- (the pieces don't move then, so the drag is a resize)
function EDIT.grips(fg, boxes)
    local mx, my = imgui.GetMousePos();
    local down, R = imgui.IsMouseDown(0), EDIT.rs;
    if R and not down then save(); EDIT.rs, R = nil, nil; end           -- let go: kept
    if R and boxes[R.k] == nil then EDIT.rs, R = nil, nil; end
    local hot = nil;
    for k, b in pairs(boxes) do
        local sz = EDIT.SIZE[k];
        if cfg.target_fx == 'link' and (k == 'fo_x' or k == 'co_x' or k == 'mb_x' or k == 'fan_x' or k == 'ecast_x') then sz = nil; end   -- (Hex link: they follow the bar)
        if sz then
            local g = 16;
            local x1, y1 = b[1] + b[3], b[2] + b[4];
            local over = mx >= x1 - g - 2 and mx <= x1 + 4 and my >= y1 - g - 2 and my <= y1 + 4;
            if over and not R then hot = k; end
            local on = (R and R.k == k) or (not R and over);
            local a = on and 1 or 0.6;
            for i = 1, 3 do                                          -- (three short diagonal lines, pink to violet)
                local d = i * 4.5;
                DL.L(fg, x1 - d - 1, y1 - 3, x1 - 3, y1 - d - 1, U4(0, 0, 0, 0.7 * a), 3.5);
                DL.L(fg, x1 - d - 1, y1 - 3, x1 - 3, y1 - d - 1, U4(1.0 - 0.3 * i / 3, 0.40 + 0.1 * i / 3, 0.62 + 0.38 * i / 3, a), 1.6);
            end
        end
    end
    if hot and imgui.IsMouseClicked(0) then                          -- a grip taken: from this size, at this mouse
        local b, sz = boxes[hot], EDIT.SIZE[hot];
        EDIT.rs = { k = hot, mx = mx, my = my, w = math.max(20, b[3]), h = math.max(20, b[4]), s = tonumber(cfg[sz[1]]) or 1 };
        R = EDIT.rs;
    end
    if R then
        local sz = EDIT.SIZE[R.k];
        local r = ((R.w + (mx - R.mx)) / R.w + (R.h + (my - R.my)) / R.h) / 2;
        local v = math.max(sz[2], math.min(sz[3], math.floor(R.s * r * 20 + 0.5) / 20));
        if v ~= tonumber(cfg[sz[1]]) then cfg[sz[1]] = v; end
        local b = boxes[R.k];                                        -- (its size beside the grip)
        local str = string.format('%.2fx', v);
        local tw = imgui.CalcTextSize(str);
        local tx, ty = b[1] + b[3] - tw - 26, b[2] + b[4] - 20;
        DL.RF(fg, tx - 6, ty - 1, tx + tw + 6, ty + 17, U4(0.05, 0.045, 0.07, 0.92), 5);
        DL.T(fg, tx, ty, U4(1.0, 0.70, 0.88, 1), str);
    end
    EDIT.rs_hot = (hot ~= nil) or (R ~= nil);
    return R and R.k or hot;
end
function EDIT.snap(kx, x, y, w, h)
    local ds = imgui.GetIO().DisplaySize;
    local W, H = (ds and ds.x) or 1920, (ds and ds.y) or 1080;
    local xs, ys = { W / 2 }, { H / 2 };                             -- the lines to line up with
    for k, sz in pairs(WATCH.size or {}) do
        local ky = k:gsub('_x$', '_y');
        local ox, oy = tonumber(cfg[k]), tonumber(cfg[ky]);
        if k ~= kx and ox and oy and EDIT.listed(k) then
            xs[#xs + 1] = ox; xs[#xs + 1] = ox + sz[1] / 2; xs[#xs + 1] = ox + sz[1];
            ys[#ys + 1] = oy; ys[#ys + 1] = oy + sz[2] / 2; ys[#ys + 1] = oy + sz[2];
        end
    end
    local guides = {};
    local function best(v, size, lines)                              -- v: its start; tries its start, middle and end
        local bd, bv, bl = 11, nil, nil;
        for _, l in ipairs(lines) do
            for _, o in ipairs({ 0, size / 2, size }) do
                local d = math.abs(v + o - l);
                if d < bd then bd, bv, bl = d, l - o, l; end
            end
        end
        return bv, bl;
    end
    local sx, lx = best(x, w, xs);
    local sy, ly = best(y, h, ys);
    if lx then guides[#guides + 1] = { 'v', lx }; end
    if ly then guides[#guides + 1] = { 'h', ly }; end
    return math.floor((sx or (math.floor(x / 8 + 0.5) * 8)) + 0.5), math.floor((sy or (math.floor(y / 8 + 0.5) * 8)) + 0.5), guides;
end
-- Edit Mode's screen: a soft dark veil, the grid, the middle lines, every piece outlined with its name, the guides while
-- dragging, and a bar at the top with DONE
function EDIT.draw()
    if not EDIT.on then return; end
    if EDIT.G and EDIT.G.on then return; end                         -- (the guide is showing: no grid, no panel)
    local ds = imgui.GetIO().DisplaySize;
    local W, H = (ds and ds.x) or 1920, (ds and ds.y) or 1080;
    local dl = nil;
    pcall(function() dl = imgui.GetBackgroundDrawList(); end);
    local fg = nil;
    pcall(function() fg = imgui.GetForegroundDrawList(); end);
    if dl then
        DL.RF(dl, 0, 0, W, H, U4(0.02, 0.01, 0.04, 0.35));
        for gx = 0, W, 40 do DL.L(dl, gx, 0, gx, H, U4(1, 1, 1, 0.045), 1); end
        for gy = 0, H, 40 do DL.L(dl, 0, gy, W, gy, U4(1, 1, 1, 0.045), 1); end
        DL.L(dl, W / 2, 0, W / 2, H, U4(1.0, 0.36, 0.62, 0.30), 1);
        DL.L(dl, 0, H / 2, W, H / 2, U4(0.62, 0.40, 1.0, 0.30), 1);
    end
    if fg then
        local all = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15;
        local lf = push_font(fonts.chat, 15);                        -- (the labels in the UI's font)
        local boxes, order = {}, {};
        local mx, my = imgui.GetMousePos();
        for k, sz in pairs(WATCH.size or {}) do
            local ky = k:gsub('_x$', '_y');
            local ox, oy = tonumber(cfg[k]), tonumber(cfg[ky]);
            if ox and oy and EDIT.listed(k) and sz[1] > 4 then
                boxes[k] = { ox, oy, sz[1], sz[2] };
                order[#order + 1] = k;
            end
        end
        local focus = EDIT.drag or (EDIT.rs and EDIT.rs.k) or EDIT.last_hot;
        if not focus then                                            -- (the smallest piece under the mouse)
            local best = nil;
            for k, b in pairs(boxes) do
                if mx >= b[1] and mx <= b[1] + b[3] and my >= b[2] and my <= b[2] + b[4] and (best == nil or b[3] * b[4] < best[2]) then best = { k, b[3] * b[4] }; end
            end
            focus = best and best[1];
        end
        table.sort(order, function(a, b) return (boxes[a][2] < boxes[b][2]) or (boxes[a][2] == boxes[b][2] and a < b); end)
        for _, k in ipairs(order) do
            local b = boxes[k];
            local on = (k == focus);
            DL.R(fg, b[1], b[2], b[1] + b[3], b[2] + b[4], U4(0.62, 0.40, 1.0, on and 0.95 or 0.45), 6, all, on and 2 or 1);
        end
        local placed = {};
        local function label(k)
            local b, nm = boxes[k], EDIT.NAMES[k];
            local tw = imgui.CalcTextSize(nm);
            local r = { b[1], b[2] - 18, b[1] + tw + 12, b[2] - 2 };
            if k ~= focus then
                for _, q in ipairs(placed) do
                    if r[1] < q[3] and r[3] > q[1] and r[2] < q[4] and r[4] > q[2] then return; end   -- (on top of another: left out)
                end
            end
            placed[#placed + 1] = r;
            local on = (k == focus);
            DL.RF(fg, r[1], r[2], r[3], r[4], u32(on and { 0.20, 0.10, 0.26, 0.96 } or { 0.05, 0.045, 0.07, 0.9 }), 5);
            DL.T(fg, b[1] + 6, b[2] - 18, u32(on and { 1.0, 0.80, 0.93, 1 } or { 0.93, 0.92, 0.98, 1 }), nm);
        end
        if focus and boxes[focus] then label(focus); end
        for _, k in ipairs(order) do if k ~= focus then label(k); end end
        EDIT.last_hot = EDIT.grips(fg, boxes);
        if lf then imgui.PopFont(); end
        for _, g in ipairs(EDIT.guides or {}) do                     -- the guides: pink-to-violet lines across the screen
            if g[1] == 'v' then
                DL.L(fg, g[2], 0, g[2], H, U4(1.0, 0.36, 0.62, 0.25), 5);
                DL.L(fg, g[2], 0, g[2], H, U4(1.0, 0.70, 0.88, 0.95), 1.2);
            else
                DL.L(fg, 0, g[2], W, g[2], U4(0.62, 0.40, 1.0, 0.25), 5);
                DL.L(fg, 0, g[2], W, g[2], U4(0.85, 0.75, 1.0, 0.95), 1.2);
            end
        end
    end
    -- the panel on the left, half way down (the top of the screen stays free for the pieces placed there)
    if not pcall(imgui.SetNextWindowPos, { 14, H / 2 }, ImGuiCond_Always, { 0, 0.5 }) then imgui.SetNextWindowPos({ 14, H / 2 - 60 }, ImGuiCond_Always); end
    local ehx = YUI_HEX;                                             -- (Hex link mode: square, a gold edge, gold heading)
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 16, 8 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, ehx and 0 or 14);
    imgui.PushStyleColor(ImGuiCol_WindowBg, ehx and { 0.03, 0.035, 0.055, 0.95 } or { 0.05, 0.045, 0.07, 0.95 });
    imgui.PushStyleColor(ImGuiCol_Border, ehx and { C.GOLDH[1], C.GOLDH[2], C.GOLDH[3], 0.7 } or { 0.62, 0.40, 1.0, 0.7 });
    if imgui.Begin('YunaUI Edit##yui_edit', { true }, bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize,
            ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoSavedSettings)) then
        local ef = sized('chat', 16);                                -- (the UI's font)
        imgui.TextColored(ehx and { C.GOLDH2[1], C.GOLDH2[2], C.GOLDH2[3], 1 } or { 1.0, 0.70, 0.88, 1 }, 'EDIT MODE');
        imgui.Spacing();
        if EDIT.welcome then                                         -- (the first launch)
            imgui.TextColored({ 1, 1, 1, 1 }, 'Welcome to YunaUI!');
            imgui.TextColored(ehx and { 0.84, 0.80, 0.72, 1 } or { 0.80, 0.78, 0.88, 1 }, 'Place everything where you like,');
            imgui.TextColored(ehx and { 0.84, 0.80, 0.72, 1 } or { 0.80, 0.78, 0.88, 1 }, 'then press DONE. (Later: /yui edit)');
            imgui.Spacing();
        end
        imgui.TextColored(ehx and { 0.84, 0.80, 0.72, 1 } or { 0.80, 0.78, 0.88, 1 }, 'Drag anything.');
        imgui.TextColored(ehx and { 0.84, 0.80, 0.72, 1 } or { 0.80, 0.78, 0.88, 1 }, 'It snaps to the grid and');
        imgui.TextColored(ehx and { 0.84, 0.80, 0.72, 1 } or { 0.80, 0.78, 0.88, 1 }, 'lines up with the others.');
        imgui.Spacing();
        imgui.TextColored(ehx and { 0.84, 0.80, 0.72, 1 } or { 0.80, 0.78, 0.88, 1 }, 'Drag a corner grip to resize.');
        imgui.Spacing();
        if accent_button('DONE##yui_edit_done', { 190, 0 }) then
            EDIT.on, EDIT.drag, EDIT.guides, EDIT.welcome = false, nil, {}, nil; save();
            if EDIT.G.finale then EDIT.G.finale, EDIT.G.splash_t = nil, os.clock(); end   -- (after the guide: the send-off)
        end
        unsized(ef);
    end
    imgui.End();
    imgui.PopStyleColor(2);
    imgui.PopStyleVar(2);
end
-- The alliance's look (PARTY > Alliance look), so a full alliance doesn't fill the screen:
--   full:    like the party list
--   compact: thin rows - job icon, name, HP % and one thin HP bar (no MP / TP)
--   tiles:   raid-frame tiles, 3 to a row: the HP fills each tile softly, a bright line at its foot; a low one's edge glows red
--   smart:   one line of six dots coloured by HP; a member opens into a compact row only when it matters - low HP, your
--            target, or the mouse over that alliance - and closes again (smoothly) when it doesn't
local ALLY = { v = {}, hov = {} };
function ALLY.lead(dl, m, x, cy, sc, a)                              -- (on a card: the leader's dots at x; gives back the room they take)
    if not (m.leader or m.aleader) then return 0; end
    local r = 4.5 * sc;
    local mw = m.aleader and r * 2.6 or r * 2;
    LEAD_MARK(dl, x + mw / 2, cy, r, m.aleader, a * (m.inzone and 1 or 0.5), 'dots');
    return mw + 5 * sc;
end
C.ALLY = ALLY;                                                       -- (for the target bar, drawn earlier in the file: a member's job tag)
function ALLY.fit(str, room)                                        -- a name cut short (with a dot) to fit room
    if imgui.CalcTextSize(str) <= room then return str; end
    while #str > 2 and imgui.CalcTextSize(str .. '.') > room do str = str:sub(1, -2); end
    return str .. '.';
end
function ALLY.isc()                                                 -- (PARTY > Job icons, ALLIANCE 1 / 2 > Job icons)
    local key = (ALLY.cur == 0 and 'icon_scale') or (ALLY.cur == 2 and 'ally2_icon') or 'ally1_icon';
    return math.max(0.4, math.min(2.5, tonumber(cfg[key]) or 1));
end
function ALLY.icon(dl, m, x, y, size, a)
    local k = ALLY.isc();
    if k ~= 1 then local d = size * (k - 1) / 2; x, y, size = x - d, y - d, size * k; end   -- (grows / shrinks round its middle)
    local jt = JOBS[m.job or 0] and tex('jobs_32/' .. JOBS[m.job]:lower() .. '.png') or nil;
    image(dl, jt, x, y, x + size, y + size, { 1, 1, 1, a * (m.inzone and 1 or 0.4) });
end
-- One compact row; gives back its height
function ALLY.row(dl, m, i, x, y, w, sc, dt, tidx)
    local fs = FS or 1;
    imgui.SetWindowFontScale(fs * 0.82);
    local lh = imgui.GetTextLineHeight();
    local ih = math.floor(lh + 2 * sc);
    local bh = math.max(2, math.floor(2.5 * sc));
    local rh = lh + bh + 7 * sc;
    if m.idx ~= 0 and m.idx == tidx then                             -- your target: a soft violet behind the row
        DL.RF(dl, x - 3, y - 2, x + w + 3, y + rh - 3, U4(0.62, 0.40, 1.0, 0.16), 5);
    end
    ALLY.icon(dl, m, x, y, ih, 1);
    local tx = x + ih + 6 * sc;
    if m.leader or m.aleader then LEAD_MARK(dl, tx + 5 * sc, y + lh / 2, 4.5 * sc, m.aleader, m.inzone and 1 or 0.5, 'dots'); tx = tx + 14 * sc; end
    local pct = m.inzone and string.format('%d%%', math.floor((m.hpp or 0) * 100 + 0.5)) or '';
    local pw = imgui.CalcTextSize(pct);
    text(dl, tx, y - 1, ALLY.fit(m.name or '?', x + w - tx - pw - 8 * sc), { 1, 1, 1, m.inzone and 1 or 0.45 });
    if m.inzone then
        text(dl, x + w - pw, y - 1, pct, { 1, 0.80, 0.88, 1 });
        glow_bar(dl, tx, y + lh + 1, x + w - tx, bh, m.hpp, lagged('ah' .. i, m.hpp, dt), C.hpb1 or C.hp, C.hpb2 or C.hp2, i + 60);
    end
    imgui.SetWindowFontScale(fs);
    return rh;
end
-- One tile
function ALLY.tile(dl, m, i, x, y, w, h, sc, tidx)
    local all = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15;
    local hp = m.inzone and math.max(0, math.min(1, m.hpp or 0)) or 0;
    local c1, c2 = C.hpb1 or C.hp, C.hpb2 or C.hp2;
    DL.RF(dl, x, y, x + w, y + h, U4(0.05, 0.045, 0.07, 0.82), 6);
    if hp > 0 then
        DL.RF(dl, x, y, x + w * hp, y + h, U4(c1[1], c1[2], c1[3], 0.20), 6);
        pcall(function()
            DL.RFM(dl, x + 3, y + h - 4, x + 3 + (w - 6) * hp, y + h - 2, U4(c1[1], c1[2], c1[3], 1), U4(c2[1], c2[2], c2[3], 1), U4(c2[1], c2[2], c2[3], 1), U4(c1[1], c1[2], c1[3], 1));
        end);
    end
    local edge = { 1, 1, 1, 0.10 };
    if m.idx ~= 0 and m.idx == tidx then edge = { 0.75, 0.55, 1.0, 0.95 };
    elseif m.inzone and hp < 0.5 then local b = 0.5 + 0.5 * math.sin(os.clock() * 6 + i); edge = { 1.0, 0.30, 0.35, 0.45 + 0.5 * b }; end
    DL.R(dl, x, y, x + w, y + h, u32(edge), 6, all, 1.2);
    local fs = FS or 1;
    imgui.SetWindowFontScale(fs * 0.76);
    local lh = imgui.GetTextLineHeight();
    local ih = math.floor(h * 0.52);
    ALLY.icon(dl, m, x + 4 * sc, y + (h - ih) / 2 - 1, ih, 1);
    local tx = x + 4 * sc + ih + 4 * sc;
    text(dl, tx, y + (h - lh) / 2 - 2, ALLY.fit(m.name or '?', x + w - tx - 4 * sc), { 1, 1, 1, m.inzone and 1 or 0.45 });
    imgui.SetWindowFontScale(fs);
end
-- The three "showcase" alliance looks (PARTY > Alliance look), each with its own life:
--   orbs:  a round badge per member, the job's hat inside, an HP ring round it (pink to violet) with a glowing head; a
--          glint runs round each bezel now and then; low HP turns the ring red and it beats; your target gets a violet halo
--   spine: a YunaUI line with a node per member; a light runs down it every few seconds; a member who needs you (low HP,
--          your target, or the mouse over it) slides out as a card with name, HP % and a thin bar
--   hex:   honeycomb cells with a glowing contour (YunaUI's), the HP as the living bar inside each cell; red when low;
--          the mouse over a cell shows the name
-- Selecting: a click on an alliance member targets them (/ta); on a pretend one (Pretend members on) it just marks them,
-- so the selection can be seen without a real alliance. PARTY > Selected look: glow (violet) or chromatic (a rainbow
-- light running round the bezel).
ALLY.pick = nil;
function ALLY.is_tgt(m, i, tidx)
    if tidx and tidx < 0 then return not m.fake and i == -tidx - 1; end   -- (the game's party cursor on someone not in your zone)
    return (m.idx ~= 0 and m.idx == tidx) or (m.fake and ALLY.pick == i);   -- (a pick marks only pretend members)
end   -- (a pick marks only pretend members)
function ALLY.click(m, i, over)
    if not over then return; end
    local r = ALLY.irect[i];                                         -- (a click on its hat folds the buffs instead)
    if r then local mx, my = imgui.GetMousePos(); if mx >= r[1] and mx <= r[3] and my >= r[2] and my <= r[4] then return; end end
    if imgui.IsMouseDoubleClicked(0) then ALLY.turn(m, i); return; end   -- (a double click turns the card over: HP and MP in numbers)
    if not imgui.IsMouseClicked(0) then return; end
    if m.fake then ALLY.pick = (ALLY.pick == i) and nil or i; return; end
    pcall(function() AshitaCore:GetChatManager():QueueCommand(1, '/ta ' .. (m.name or '')); end);
end
ALLY.FL = {};                                                        -- (each plate's side: back = the numbers; t = when it turned)
function ALLY.turn(m, i)
    local k = m.name or ('m' .. i);
    local f = ALLY.FL[k] or { back = false, t = -9 };
    f.back, f.t, f.was = not f.back, os.clock(), false;
    ALLY.FL[k] = f;
end
function ALLY.hue(h, a)                                              -- a colour round the wheel (h 0..1)
    h = h % 1;
    local k = h * 6;
    local f = k - math.floor(k);
    local q = 1 - f;
    local r, g, b;
    local seg = math.floor(k);
    if seg == 0 then r, g, b = 1, f, 0; elseif seg == 1 then r, g, b = q, 1, 0; elseif seg == 2 then r, g, b = 0, 1, f;
    elseif seg == 3 then r, g, b = 0, q, 1; elseif seg == 4 then r, g, b = f, 0, 1; else r, g, b = 1, 0, q; end
    return U4(0.35 + 0.65 * r, 0.35 + 0.65 * g, 0.35 + 0.65 * b, a);   -- (a little soft, not neon)
end
function ALLY.chroma() return (cfg.ally_select_fx or 'chroma') == 'chroma'; end
-- a chromatic outline along the points (closed), its colours running round over time
function ALLY.chroma_path(dl, pts, th, a)
    local now = os.clock();
    local n = #pts;
    for k = 1, n do
        local h = (k - 1) / n + now * 0.35;
        dl:AddLine(pts[k], pts[k % n + 1], ALLY.hue(h, 0.22 * a), th + 5);
        dl:AddLine(pts[k], pts[k % n + 1], ALLY.hue(h, 0.95 * a), th);
    end
end
function ALLY.circle_pts(cx, cy, r, n)
    local p = {};
    for k = 0, n - 1 do local a = k / n * math.pi * 2 - math.pi / 2; p[#p + 1] = { cx + math.cos(a) * r, cy + math.sin(a) * r }; end
    return p;
end
-- A convex shape filled in one go (no seams between triangles), or as triangles if this ImGui can't
function ALLY.poly(dl, pts, col)
    if not pcall(function() dl:AddConvexPolyFilled(pts, col); end) then
        for t_ = 2, #pts - 1 do dl:AddTriangleFilled(pts[1], pts[t_], pts[t_ + 1], col); end
    end
end
-- A convex shape cut to the x range [xa, xb] (for filling part of a card)
function ALLY.clip_x(pts, xa, xb)
    local function clip(poly, keep, edge)
        local out = {};
        for k = 1, #poly do
            local a, b = poly[k], poly[k % #poly + 1];
            local ia, ib = keep(a), keep(b);
            if ia then out[#out + 1] = a; end
            if ia ~= ib then
                local t = (edge - a[1]) / (b[1] - a[1]);
                out[#out + 1] = { edge, a[2] + (b[2] - a[2]) * t };
            end
        end
        return out;
    end
    local p1 = clip(pts, function(q) return q[1] >= xa; end, xa);
    if #p1 < 3 then return {}; end
    return clip(p1, function(q) return q[1] <= xb; end, xb);
end
function ALLY.hue_rgb(h)
    h = h % 1;
    local k = h * 6;
    local f = k - math.floor(k);
    local q = 1 - f;
    local seg = math.floor(k);
    if seg == 0 then return 1, f, 0; elseif seg == 1 then return q, 1, 0; elseif seg == 2 then return 0, 1, f;
    elseif seg == 3 then return 0, q, 1; elseif seg == 4 then return f, 0, 1; end
    return 1, 0, q;
end
-- The cards' edge (ALLIANCE > Card edge / Edge colour):
--   thin:   a thin clean line            light: a thin line with two bright lights running round it (with a small flare)
--   glow:   a soft glow round it          double: a line and a fainter one just inside
--   none:   no edge
ALLY.EDGES = { { 'thin', 'Thin line' }, { 'light', 'Running light' }, { 'glow', 'Soft glow' }, { 'double', 'Double line' }, { 'none', 'None' } };
ALLY.EDGECOLS = { { 'black', 'Black' }, { 'white', 'White' }, { 'pink', 'Pink' }, { 'violet', 'Violet' }, { 'gold', 'Gold' }, { 'cyan', 'Ice blue' } };
ALLY.ECOL = { black = { 0, 0, 0 }, white = { 1, 1, 1 }, pink = { 1.0, 0.42, 0.68 }, violet = { 0.68, 0.48, 1.0 },
              gold = { 1.0, 0.82, 0.45 }, cyan = { 0.60, 0.88, 1.0 } };
function ALLY.along(pts, d)                                         -- the point at distance d round a closed outline
    local per, lens = 0, {};
    for k = 1, #pts do
        local a, b = pts[k], pts[k % #pts + 1];
        lens[k] = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2);
        per = per + lens[k];
    end
    d = d % per;
    for k = 1, #pts do
        if d <= lens[k] then
            local a, b = pts[k], pts[k % #pts + 1];
            local t = d / math.max(0.001, lens[k]);
            return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, per;
        end
        d = d - lens[k];
    end
    return pts[1][1], pts[1][2], per;
end
-- The outline pushed out by g px all round (each corner moved along its bisector), for a glow with no gaps
function ALLY.grow(pts, g)
    local n, out = #pts, {};
    for k = 1, n do
        local a, b, c = pts[(k - 2) % n + 1], pts[k], pts[k % n + 1];
        local function nrm(p, q) local dx, dy = q[1] - p[1], q[2] - p[2]; local l = math.max(0.001, math.sqrt(dx * dx + dy * dy)); return dy / l, -dx / l; end
        local n1x, n1y = nrm(a, b);
        local n2x, n2y = nrm(b, c);
        local bx, by = n1x + n2x, n1y + n2y;
        local bl = math.max(0.001, math.sqrt(bx * bx + by * by));
        bx, by = bx / bl, by / bl;
        local cosh = math.max(0.35, bx * n1x + by * n1y);
        out[k] = { b[1] + bx * g / cosh, b[2] + by * g / cosh };
    end
    return out;
end
-- Soft glow: layers of the outline grown outward, filled (so there are no gaps at the corners), under the card
function ALLY.edge_under(dl, pts, v, sc)
    do return; end                                                   -- (not used: the user preferred the stroke glow)
    local c = ALLY.ECOL[cfg.spine_edge_col or 'black'] or ALLY.ECOL.black;
    local sgn = ALLY.grow(pts, 0);
    local area = 0;                                                  -- (which way round it goes, so "out" is out)
    for k = 1, #sgn do local a, b = sgn[k], sgn[k % #sgn + 1]; area = area + (a[1] * b[2] - b[1] * a[2]); end
    local dir = (area > 0) and 1 or -1;
    for g = 4, 1, -1 do
        ALLY.poly(dl, ALLY.grow(pts, dir * g * 1.6 * sc), U4(c[1], c[2], c[3], 0.11 * v));
    end
end
-- An outline th px wide with mitred corners (each side a filled piece meeting the next), so no corner is ever open
-- A closed outline drawn as ONE line (ImGui joins its corners itself: no overlap, so a faint glow never gets darker spots
-- at the corners); if this ImGui can't, it falls back to ALLY.stroke
function ALLY.polyline(dl, pts, col, th)
    ALLY.stroke(dl, pts, th, col);                                   -- (AddPolyline draws nothing in this Ashita: the user saw no edge)
end
-- A glow band w px wide, only OUTSIDE the outline: a strip along each side and a small fan round each corner, every piece
-- meeting the next edge to edge (no overlap, so no darker corners; nothing spills inside the card)
function ALLY.glow_ring(dl, pts, w, col)
    local n = #pts;
    local area = 0;
    for k = 1, n do local a, b = pts[k], pts[k % n + 1]; area = area + (a[1] * b[2] - b[1] * a[2]); end
    local sgn = (area > 0) and 1 or -1;
    local nrm = {};
    for k = 1, n do
        local a, b = pts[k], pts[k % n + 1];
        local dx, dy = b[1] - a[1], b[2] - a[2];
        local l = math.max(0.001, math.sqrt(dx * dx + dy * dy));
        nrm[k] = { sgn * dy / l, -sgn * dx / l };
    end
    for k = 1, n do
        local a, b, q = pts[k], pts[k % n + 1], nrm[k];
        ALLY.poly(dl, { a, b, { b[1] + q[1] * w, b[2] + q[2] * w }, { a[1] + q[1] * w, a[2] + q[2] * w } }, col);
        local q2 = nrm[k % n + 1];                                   -- the corner at b: a fan from this side's normal to the next
        local a1, a2 = math.atan2(q[2], q[1]), math.atan2(q2[2], q2[1]);
        local d = a2 - a1;
        while d > math.pi do d = d - 2 * math.pi; end
        while d < -math.pi do d = d + 2 * math.pi; end
        local steps = 4;
        for t = 0, steps - 1 do
            local u0, u1 = a1 + d * t / steps, a1 + d * (t + 1) / steps;
            dl:AddTriangleFilled(b, { b[1] + math.cos(u0) * w, b[2] + math.sin(u0) * w }, { b[1] + math.cos(u1) * w, b[2] + math.sin(u1) * w }, col);
        end
    end
end
function ALLY.stroke(dl, pts, th, col)
    local n = #pts;
    for k = 1, n do
        local a, b = pts[k], pts[k % n + 1];
        local dx, dy = b[1] - a[1], b[2] - a[2];
        local l = math.max(0.001, math.sqrt(dx * dx + dy * dy));
        local nx, ny = -dy / l * th / 2, dx / l * th / 2;
        ALLY.poly(dl, { { a[1] + nx, a[2] + ny }, { b[1] + nx, b[2] + ny }, { b[1] - nx, b[2] - ny }, { a[1] - nx, a[2] - ny } }, col);
    end
    if th > 1.2 then for k = 1, n do dl:AddCircleFilled(pts[k], th / 2, col, 10); end end   -- (round joints; a 1 px line needs none)
end
-- The cards' edge: a thin black line, smooth (antialiased lines, not filled strips), with a small animation picked in
-- ALLIANCE > Edge animation:
--   none     still
--   shine    now and then a soft light sweeps along the top of the card, left to right
--   trace    a small light runs slowly round the edge
--   pulse    a soft dark halo breathes round it
--   twinkle  a corner sparkles for a moment, now here, now there
ALLY.EDGE_ANIMS = { { 'shine', 'Shine' }, { 'trace', 'Trace' }, { 'pulse', 'Pulse' }, { 'twinkle', 'Twinkle' }, { 'none', 'None' } };
function ALLY.edge(dl, pts, v, sc, seed, g, th)
    local n = #pts;
    local now = os.clock();
    local anim = cfg.spine_edge_anim or 'shine';
    seed = seed or 0;
    if anim == 'pulse' then                                          -- the halo first, under the line
        local b = 0.5 + 0.5 * math.sin(now * 2.2 + seed * 0.7);
        for k = 1, n do dl:AddLine(pts[k], pts[k % n + 1], U4(0, 0, 0, (0.10 + 0.16 * b) * v), 3.5 * sc); end
    end
    local ec = (th and th.edge) or { 0, 0, 0, 0.92 };
    for k = 1, n do dl:AddLine(pts[k], pts[k % n + 1], U4(ec[1], ec[2], ec[3], ec[4] * v), 1.2); end   -- the line itself
    if anim == 'shine' then                                          -- a light along the top side (points 2 -> 3), every ~5 s
        local ph = ((now + seed * 0.37) / 5) % 1;
        if ph < 0.30 then
            local q = ph / 0.30;
            local a, b = pts[2], pts[3];
            if g and g.top then a, b = { g.top[1], g.top[3] }, { g.top[2], g.top[3] }; end
            local cx = a[1] + (b[1] - a[1]) * q;
            local half = 26 * sc;
            local strength = math.sin(q * math.pi);
            for t = -6, 5 do
                local u0, u1 = t / 6, (t + 1) / 6;
                local f = 1 - math.abs((u0 + u1) / 2);
                local x0 = math.max(a[1], math.min(b[1], cx + u0 * half));
                local x1 = math.max(a[1], math.min(b[1], cx + u1 * half));
                if x1 > x0 then DL.L(dl, x0, a[2], x1, a[2], U4(1, 1, 1, 0.85 * f * strength * v), 1.4); end
            end
        end
    elseif anim == 'trace' then                                      -- a small light running round, slowly
        local _, _, per = ALLY.along(pts, 0);
        local head = ((now * 38 * sc) + seed * 53) % per;
        local prev = nil;
        for t = 0, 10 do
            local px, py = ALLY.along(pts, head - t * 2.5 * sc);
            if prev then dl:AddLine(prev, { px, py }, U4(1, 1, 1, 0.85 * (1 - t / 10) * v), 1.3); end
            prev = { px, py };
        end
    elseif anim == 'twinkle' then                                    -- a corner sparkles, one at a time
        local slot = math.floor((now + seed * 0.61) / 2.2);
        local ph = ((now + seed * 0.61) / 2.2) % 1;
        if ph < 0.35 then
            local q = math.sin(ph / 0.35 * math.pi);
            local sp = (g and g.spark) or pts;
            local p = sp[(slot * 3 + seed) % #sp + 1];
            local r = 4.5 * sc * q;
            DL.L(dl, p[1] - r, p[2], p[1] + r, p[2], U4(1, 1, 1, 0.9 * q * v), 1.2);
            DL.L(dl, p[1], p[2] - r, p[1], p[2] + r, U4(1, 1, 1, 0.9 * q * v), 1.2);
            dl:AddCircleFilled(p, 1.4 * sc, U4(1, 1, 1, q * v), 8);
        end
    end
end
-- A card's hat, alive (as the party list's): the mouse over it lifts and grows it; a click folds that member's buffs into it
-- (or brings them back) with a little bounce. Its place is kept so a click there doesn't also target the member.
ALLY.irect = {};
function ALLY.anim_icon(dl, m, i, x, y, size, a)
    local key = m.name or ('m' .. i);
    local mx, my = imgui.GetMousePos();
    local hov = mx >= x and mx <= x + size and my >= y and my <= y + size;
    ALLY.irect[i] = { x, y, x + size, y + size };
    if hov and imgui.IsMouseClicked(0) and m.name then BUFFS.flip(m.name); end
    BUFFS.hv = BUFFS.hv or {};
    local h = BUFFS.hv[key] or 0;
    h = h + ((hov and 1 or 0) - h) * math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 10);
    BUFFS.hv[key] = h;
    local k = 1 + 0.10 * h;
    local t = os.clock() - (BUFFS.pop[key] or -9);
    if t < 0.35 then k = k + 0.22 * math.sin(math.pi * t / 0.35) * (1 - t / 0.35); end
    local s2 = size * k;
    local cx, cy = x + size / 2, y + size / 2 - 2 * h;
    ALLY.icon(dl, m, cx - s2 / 2, cy - s2 / 2, s2, a);
end
-- When a party or an alliance forms (you're invited, or Pretend members goes on), it comes in from the right: the whole
-- list slides in and fades in (~0.7 s) and its cards open one after another
ALLY.was, ALLY.t0 = {}, {};
function ALLY.entry(key, active, list)
    local now = os.clock();
    if active and not ALLY.was[key] then
        local fake = false;                                          -- (pretend members, shown while placing things: no entrance, they just appear)
        for _, e in ipairs(list) do if e[1] and e[1].fake then fake = true; end end
        if fake then
            ALLY.t0[key] = now - 60;
            for _, e in ipairs(list) do ALLY.v[ALLY.vkey(key, e)] = 1; end
        else
            ALLY.t0[key] = now;
            for k, e in ipairs(list) do ALLY.v[ALLY.vkey(key, e)] = -(k - 1) * 0.22; end   -- (each card waits a little more)
        end
    end
    ALLY.was[key] = active;
    local t0 = ALLY.t0[key];
    if t0 == nil then return 1; end
    return math.min(1, (now - t0) / 0.7);
end
-- The party / alliance windows always stay on the screen: placed by their real size (not a guess), and pushed back
-- inside if they ever stick out (a let-go drag, a member joining, a smaller screen)
function ALLY.screen()
    local ds = imgui.GetIO().DisplaySize;
    local w, h = ds and tonumber(ds.x), ds and tonumber(ds.y);
    if not w or w < 100 or not h or h < 100 then return nil; end
    return w, h;
end
function ALLY.inside(x, y, sw, sh)
    local W, H = ALLY.screen();
    if not W then return x, y; end
    x = math.max(0, math.min(W - sw, x));
    y = math.max(0, math.min(H - sh, y));
    return math.floor(x), math.floor(y);
end
function ALLY.keep(kx, ky)                                          -- (after end_plain, which measured the window)
    local sz = WATCH.size and WATCH.size[kx];
    local sw, sh = sz and sz[1], sz and sz[2];
    local W, H = ALLY.screen();
    if type(sw) ~= 'number' or type(sh) ~= 'number' or not W or sw < 20 then return; end
    if ALLY.home and kx == 'party_x' then                            -- (the default place: bottom right, by its real size)
        ALLY.home = nil;
        cfg.party_x, cfg.party_y = math.floor(W - sw - 16), math.floor(H - sh - 110);
        WATCH.move = 2;
        save();
        return;
    end
    if imgui.IsMouseDown(0) then ALLY.lastw = ALLY.lastw or {}; ALLY.lastw[kx] = sw; return; end   -- (not while it's being dragged)
    ALLY.lastw = ALLY.lastw or {};
    local ek = ({ party_x = 'PARTY', alliance_x = '1', ally2_x = '2' })[kx];   -- (while it slides in - the party forming, a trust's first
    local t0 = ek and ALLY.t0 and ALLY.t0[ek];                       --  card: it reaches past its place for a moment - leave it be,
    if t0 and os.clock() - t0 < 2.0 then ALLY.lastw[kx] = nil; return; end   --  or it'd be pushed left and stay there)
    local pw = ALLY.lastw[kx];
    ALLY.lastw[kx] = sw;
    if pw and math.abs(pw - sw) > 1 then                             -- it got wider / narrower (a trust joined...): on the right half of the
        local x0 = tonumber(cfg[kx]) or 0;                           -- screen its RIGHT edge stays put, so a list by the screen's right edge
        if x0 + pw / 2 > W / 2 then                                  -- doesn't creep left
            cfg[kx] = math.floor(x0 + pw - sw);
            WATCH.move = 2;
            save();
        end
    end
    local x, y = tonumber(cfg[kx]) or 0, tonumber(cfg[ky]) or 0;
    local nx, ny = ALLY.inside(x, y, sw, sh);
    if math.abs(nx - x) > 1 or math.abs(ny - y) > 1 then
        cfg[kx], cfg[ky] = nx, ny;
        WATCH.move = 2;
        save();
    end
end
-- The cards' looks (PARTY > CARDS), for your party (Spine) and the alliances:
--   a shape (ALLY.shape), colours (ALLY.THEME: the card, its HP fill from left to right, the ink on it) and a living effect
--   on the HP (ALLY.CARD_FX). Every shape is convex, so the HP can be cut from it exactly (ALLY.clip_x).
ALLY.SHAPES = { { 'blade', 'Blade' }, { 'round', 'Rounded' }, { 'pill', 'Pill' }, { 'slant', 'Slanted' }, { 'prism', 'Prism' },
    { 'cut', 'Cut corners' } };
function ALLY.arc(out, cx, cy, r, a0, a1, steps)                     -- points round a circle, a0 -> a1 degrees (screen: clockwise)
    for k = 0, steps do
        local a = math.rad(a0 + (a1 - a0) * k / steps);
        out[#out + 1] = { cx + math.cos(a) * r, cy + math.sin(a) * r };
    end
end
-- A card's outline and where things go in it: inl / inr = room kept at its ends, ma..mb = where it is full height,
-- slant = its left side's lean (the MP bar follows it), top = its top side (the Shine runs there), spark = its corners
function ALLY.shape(x1, tip, y1, y2, sc)
    local ch = y2 - y1;
    local ny = (y1 + y2) / 2;
    local kind = cfg.card_shape or 'blade';
    local g = { slant = 0, round = false };
    local p = {};
    if kind == 'round' or kind == 'pill' then
        local r = (kind == 'pill') and ch / 2 or ch * 0.30;
        local st = math.max(4, math.floor(r / 1.5));                 -- (enough points for a smooth curve)
        if kind == 'pill' then
            ALLY.arc(p, x1 + r, ny, r, 90, 270, st * 2);
            ALLY.arc(p, tip - r, ny, r, 270, 450, st * 2);
            g.spark = { { x1, ny }, { x1 + r, y1 }, { tip, ny }, { tip - r, y2 } };
        else
            ALLY.arc(p, x1 + r, y2 - r, r, 90, 180, st);
            ALLY.arc(p, x1 + r, y1 + r, r, 180, 270, st);
            ALLY.arc(p, tip - r, y1 + r, r, 270, 360, st);
            ALLY.arc(p, tip - r, y2 - r, r, 0, 90, st);
            local d = r * 0.29;
            g.spark = { { x1 + d, y2 - d }, { x1 + d, y1 + d }, { tip - d, y1 + d }, { tip - d, y2 - d } };
        end
        local inn = ch * ((kind == 'pill') and 0.42 or 0.30);
        g.inl, g.inr, g.ma, g.mb, g.round = inn, inn, x1 + r, tip - r, true;
        g.top = { x1 + r, tip - r, y1 };
    elseif kind == 'slant' then
        local c = ch * 0.40;
        p = { { x1, y2 }, { x1 + c, y1 }, { tip, y1 }, { tip - c, y2 } };
        g.inl, g.inr, g.ma, g.mb, g.slant = c, c, x1 + c, tip - c, c / ch;
        g.top = { x1 + c, tip, y1 };
    elseif kind == 'prism' then
        local c = ch * 0.38;
        p = { { x1, ny }, { x1 + c, y1 }, { tip - c, y1 }, { tip, ny }, { tip - c, y2 }, { x1 + c, y2 } };
        g.inl, g.inr, g.ma, g.mb = c, c, x1 + c, tip - c;
        g.top = { x1 + c, tip - c, y1 };
    elseif kind == 'cut' then
        local c = ch * 0.26;
        p = { { x1, y2 }, { x1, y1 + c }, { x1 + c, y1 }, { tip, y1 }, { tip, y2 - c }, { tip - c, y2 } };
        g.inl, g.inr, g.ma, g.mb = c * 0.7, c * 0.7, x1 + c, tip - c;
        g.top = { x1 + c, tip, y1 };
    else                                                             -- blade: the first look, pointed at the line
        local c = ch * 0.40;
        p = { { x1, y2 }, { x1 + c, y1 }, { tip - c * 0.6, y1 }, { tip, ny }, { tip - c * 0.6, y2 } };
        g.inl, g.inr, g.ma, g.mb, g.slant = c, c, x1 + c, tip - c * 0.6, c / ch;
        g.top = { x1 + c, tip - c * 0.6, y1 };
    end
    g.spark = g.spark or p;
    return p, g;
end
-- The colours: base = the card, f1 -> f2 = the HP from left to right (fa its opacity), ink = the text on the HP (dark or
-- light), endl = the line where the HP ends, edge = the outline, glint = the effects' light, spark = the Sparkles
ALLY.THEMES = { { 'pearl', 'Pearl white' }, { 'yuna', 'Yuna (pink to violet)' }, { 'rose', 'Rose' }, { 'lavender', 'Lavender' },
    { 'gold', 'Champagne gold' }, { 'ice', 'Ice blue' }, { 'mint', 'Mint' }, { 'crimson', 'Crimson' }, { 'midnight', 'Midnight' },
    { 'onyx', 'Onyx' }, { 'glass', 'Glass' }, { 'hp', 'By HP (green to red)' } };
ALLY.THEME = {
    pearl    = { base = { 0.13, 0.12, 0.17, 0.86 }, f1 = { 0.96, 0.94, 0.97 }, fa = 0.90, ink = 'dark', glint = { 0.80, 0.66, 1.0 }, spark = { 0.62, 0.42, 1.0 } },
    yuna     = { base = { 0.11, 0.09, 0.15, 0.88 }, f1 = { 1.0, 0.52, 0.76 }, f2 = { 0.70, 0.52, 1.0 }, ink = 'dark', endl = { 0.10, 0.03, 0.14 }, spark = { 1, 1, 1 } },
    rose     = { base = { 0.14, 0.10, 0.13, 0.88 }, f1 = { 1.0, 0.86, 0.91 }, f2 = { 1.0, 0.64, 0.80 }, ink = 'dark', glint = { 1.0, 0.52, 0.76 }, spark = { 1.0, 0.34, 0.62 } },
    lavender = { base = { 0.11, 0.10, 0.16, 0.88 }, f1 = { 0.91, 0.87, 1.0 }, f2 = { 0.72, 0.62, 1.0 }, ink = 'dark', glint = { 0.62, 0.48, 1.0 }, spark = { 0.52, 0.34, 1.0 } },
    gold     = { base = { 0.12, 0.10, 0.07, 0.88 }, f1 = { 1.0, 0.93, 0.72 }, f2 = { 0.92, 0.70, 0.34 }, ink = 'dark', endl = { 0.24, 0.14, 0.02 }, glint = { 1, 1, 0.94 } },
    ice      = { base = { 0.08, 0.11, 0.15, 0.88 }, f1 = { 0.88, 0.97, 1.0 }, f2 = { 0.55, 0.80, 1.0 }, ink = 'dark', glint = { 0.45, 0.74, 1.0 }, spark = { 0.30, 0.62, 1.0 } },
    mint     = { base = { 0.07, 0.12, 0.11, 0.88 }, f1 = { 0.84, 1.0, 0.93 }, f2 = { 0.42, 0.88, 0.70 }, ink = 'dark', glint = { 1, 1, 1 } },
    crimson  = { base = { 0.13, 0.07, 0.09, 0.88 }, f1 = { 1.0, 0.46, 0.50 }, f2 = { 0.78, 0.16, 0.30 }, ink = 'light', endl = { 0.14, 0.02, 0.04 } },
    midnight = { base = { 0.05, 0.05, 0.08, 0.92 }, f1 = { 0.38, 0.42, 0.78 }, f2 = { 0.20, 0.22, 0.50 }, ink = 'light', endl = { 0.85, 0.88, 1.0 } },
    onyx     = { base = { 0.04, 0.04, 0.05, 0.92 }, f1 = { 0.62, 0.62, 0.68 }, f2 = { 0.30, 0.30, 0.35 }, ink = 'light', endl = { 0.92, 0.92, 0.95 } },
    glass    = { base = { 0.10, 0.10, 0.14, 0.42 }, f1 = { 1, 1, 1 }, fa = 0.30, ink = 'light', endl = { 1, 1, 1 }, edge = { 1, 1, 1, 0.30 } },
};
function ALLY.th(hp)
    local id = cfg.card_theme or 'pearl';
    if id == 'hp' then                                               -- By HP: green when full, gold at half, red when low
        local gr, yl, rd = { 0.62, 0.95, 0.72 }, { 1.0, 0.86, 0.46 }, { 1.0, 0.46, 0.46 };
        local a, b, t;
        if hp > 0.5 then a, b, t = yl, gr, (hp - 0.5) / 0.5; else a, b, t = rd, yl, hp / 0.5; end
        local c = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t };
        return { base = { 0.10, 0.10, 0.13, 0.88 }, f1 = c, ink = 'dark', glint = { 1, 1, 1 } };
    end
    return ALLY.THEME[id] or ALLY.THEME.pearl;
end
-- The living effect on the HP:
--   sheen    a soft light on its top half (the first look)
--   gloss    glass: a brighter top, a fine highlight line, a little shade at its foot
--   shimmer  now and then a light sweeps across it
--   flow     soft lights drift along it all the time
--   sparkle  little stars twinkle on it
--   breathe  it glows a little brighter and softer, slowly
--   none     flat
ALLY.CARD_FX = { { 'sheen', 'Soft sheen' }, { 'gloss', 'Glass gloss' }, { 'shimmer', 'Shimmer' }, { 'flow', 'Flowing light' },
    { 'sparkle', 'Sparkles' }, { 'breathe', 'Breathing' }, { 'none', 'Flat' } };
function ALLY.grad(dl, a, b, c1, c2, c3, c4)                         -- a rectangle, its four corners' colours (top left first)
    pcall(function() dl:AddRectFilledMultiColor(a, b, u32(c1), u32(c2), u32(c3), u32(c4)); end);
end
-- A soft vertical band of light (centre cx, half-width bw) inside x0..x1
function ALLY.band(dl, cx, bw, x0, x1, y1, y2, col, a)
    if cx + bw < x0 or cx - bw > x1 or x1 <= x0 then return; end
    if not pcall(function() C.clip(dl, { x0, y1 }, { x1, y2 }, true); end) then return; end
    local c0, cA = { col[1], col[2], col[3], 0 }, { col[1], col[2], col[3], a };
    ALLY.grad(dl, { cx - bw, y1 }, { cx, y2 }, c0, cA, cA, c0);
    ALLY.grad(dl, { cx, y1 }, { cx + bw, y2 }, cA, c0, c0, cA);
    dl:PopClipRect();
end
-- The card itself: its ground, the HP (cut from the same shape), the effect, the low HP warning and the HP's end line.
-- Gives back where the HP ends.
function ALLY.body(dl, pts, g, x1, tip, y1, y2, hp, v, sc, seed, th)
    local now = os.clock();
    local b = th.base;
    ALLY.poly(dl, pts, U4(b[1], b[2], b[3], b[4] * v));
    local fx = x1 + (tip - x1) * hp;
    if hp <= 0 then return fx; end
    local fill = ALLY.clip_x(pts, x1 - 1, fx);
    if #fill < 3 then return fx; end
    local f1, f2, fa = th.f1, th.f2 or th.f1, (th.fa or 1) * v;
    if YUI_HEX then f1, f2 = C.HEXHP[1], C.HEXHP[2]; end             -- (Hex link mode: gold)
    if f2 == f1 then
        ALLY.poly(dl, fill, U4(f1[1], f1[2], f1[3], fa));
    else                                                             -- a gradient: its two ends cut from the shape, a smooth middle
        local function at(x)
            local u = math.max(0, math.min(1, (x - x1) / math.max(1, tip - x1)));
            return { f1[1] + (f2[1] - f1[1]) * u, f1[2] + (f2[2] - f1[2]) * u, f1[3] + (f2[3] - f1[3]) * u, fa };
        end
        local ma, mb = g.ma, math.min(g.mb, fx);
        local ca, cb = at(ma), at(mb);
        local left = ALLY.clip_x(pts, x1 - 1, math.min(fx, ma + 0.5));
        if #left >= 3 then ALLY.poly(dl, left, u32(ca)); end
        if mb > ma then ALLY.grad(dl, { ma, y1 }, { mb, y2 }, ca, cb, cb, ca); end
        if fx > g.mb then
            local right = ALLY.clip_x(pts, g.mb - 0.5, fx);
            if #right >= 3 then ALLY.poly(dl, right, u32(cb)); end
        end
    end
    local ny = (y1 + y2) / 2;
    local bx0, bx1 = g.ma, math.min(g.mb, fx);
    local W = function(a) return { 1, 1, 1, a * v }; end
    local K = function(a) return { 0, 0, 0, a * v }; end
    local gl = th.glint or { 1, 1, 1 };
    local kind = cfg.card_fx or 'sheen';
    if kind ~= 'none' and kind ~= 'gloss' and bx1 > bx0 then          -- (the soft sheen, under every living effect)
        ALLY.grad(dl, { bx0, y1 + 1 }, { bx1, ny }, W(0.35), W(0.35), W(0), W(0));
    end
    if kind == 'gloss' and bx1 > bx0 then
        ALLY.grad(dl, { bx0, y1 + 1 }, { bx1, ny }, W(0.55), W(0.55), W(0.06), W(0.06));
        ALLY.grad(dl, { bx0, ny }, { bx1, y2 - 1 }, K(0), K(0), K(0.18), K(0.18));
        DL.L(dl, bx0 + 1, y1 + 2, bx1 - 1, y1 + 2, u32(W(0.85)), 1);
    elseif kind == 'shimmer' then
        local ph = ((now + seed * 0.53) / 4.5) % 1;
        if ph < 0.4 then
            local q = ph / 0.4;
            local bw = 24 * sc;
            local cx = g.ma - bw + (g.mb - g.ma + 2 * bw) * q;
            ALLY.band(dl, cx, bw, bx0, bx1, y1 + 1, y2 - 1, gl, 0.70 * math.sin(q * math.pi) * v);
        end
    elseif kind == 'flow' then
        local span = g.mb - g.ma;
        for k = 0, 1 do
            local u = ((now * 0.16 + seed * 0.21 + k * 0.5) % 1);
            local bw = 46 * sc;
            ALLY.band(dl, g.ma - bw + (span + 2 * bw) * u, bw, bx0, bx1, y1 + 1, y2 - 1, gl, 0.30 * v);
        end
    elseif kind == 'sparkle' and bx1 - bx0 > 12 then
        local sp = th.spark or { 1, 1, 1 };
        for k = 0, 2 do
            local t = now * 0.7 + seed * 0.31 + k * 0.333;
            local cyc, ph = math.floor(t), t % 1;
            if ph < 0.45 then
                local q = math.sin(ph / 0.45 * math.pi);
                local h1 = ((cyc * 73 + k * 37 + seed * 11) % 97) / 97;
                local h2 = ((cyc * 41 + k * 59 + seed * 7) % 89) / 89;
                local sx, sy = bx0 + 6 + (bx1 - bx0 - 12) * h1, y1 + 4 * sc + (y2 - y1 - 8 * sc) * h2;
                local r = 5 * sc * q;
                local c = U4(sp[1], sp[2], sp[3], 0.95 * q * v);
                DL.CF(dl, sx, sy, 3.2 * sc * q, U4(sp[1], sp[2], sp[3], 0.22 * q * v), 12);   -- (a soft halo)
                DL.L(dl, sx - r, sy, sx + r, sy, c, 1);
                DL.L(dl, sx, sy - r, sx, sy + r, c, 1);
                local d = r * 0.45;
                DL.L(dl, sx - d, sy - d, sx + d, sy + d, U4(sp[1], sp[2], sp[3], 0.55 * q * v), 1);
                DL.L(dl, sx - d, sy + d, sx + d, sy - d, U4(sp[1], sp[2], sp[3], 0.55 * q * v), 1);
                DL.CF(dl, sx, sy, 1.2 * sc, c, 8);
            end
        end
    elseif kind == 'breathe' then
        local bq = 0.5 + 0.5 * math.sin(now * 1.8 + seed * 0.6);
        ALLY.poly(dl, fill, u32(K(0.18 * bq)));
    end
    if cfg.card_low ~= false and hp < 0.30 then                      -- low HP: the fill beats red
        local bq = 0.5 + 0.5 * math.sin(now * 6 + seed);
        ALLY.poly(dl, fill, U4(1.0, 0.22, 0.28, (0.28 + 0.34 * bq) * v));
    end
    if hp < 0.995 then                                               -- the line where it ends
        local e = th.endl or { 0, 0, 0 };
        local poly = ALLY.clip_x(pts, fx - 2 * sc, fx);
        if #poly >= 3 then ALLY.poly(dl, poly, U4(e[1], e[2], e[3], 0.95 * v)); end
    end
    return fx;
end
-- The party's MP bar in the card's foot: cut on the card's slant (Blade / Slanted), round on the round cards
function ALLY.mpbar(dl, m, g, x1, y2, sc, v)
    local bh = math.max(3, math.floor(3.5 * sc));
    local sl = bh * g.slant;
    local mx0, mx1 = x1 + g.inl * 0.9 + 4 * sc, g.mb - 6 * sc;
    local by = y2 - bh - 2.5 * sc;
    local mpp = math.max(0, math.min(1, m.mpp or 0));
    if mx1 <= mx0 then return; end
    if g.round then
        local r = bh / 2;
        DL.RF(dl, mx0 - 1, by - 1, mx1 + 1, by + bh + 1, U4(0, 0, 0, 0.80 * v), r + 1);
        DL.RF(dl, mx0, by, mx1, by + bh, U4(0.09, 0.09, 0.13, 0.95 * v), r);
        if mpp > 0 then
            local fx = math.max(mx0 + bh, mx0 + (mx1 - mx0) * mpp);
            DL.RF(dl, mx0, by, fx, by + bh, U4(0.22, 0.50, 1.0, v), r);
            if fx - r > mx0 + r then DL.L(dl, mx0 + r, by + 0.5, fx - r, by + 0.5, U4(0.70, 0.88, 1.0, 0.9 * v), 1); end
        end
        return;
    end
    ALLY.poly(dl, { { mx0 - 1, by + bh + 1 }, { mx0 + sl - 1, by - 1 }, { mx1 + sl + 1, by - 1 }, { mx1 + 1, by + bh + 1 } }, U4(0, 0, 0, 0.80 * v));
    ALLY.poly(dl, { { mx0, by + bh }, { mx0 + sl, by }, { mx1 + sl, by }, { mx1, by + bh } }, U4(0.09, 0.09, 0.13, 0.95 * v));
    if mpp > 0 then
        local fx = mx0 + (mx1 - mx0) * mpp;
        ALLY.poly(dl, { { mx0, by + bh }, { mx0 + sl, by }, { fx + sl, by }, { fx, by + bh } }, U4(0.22, 0.50, 1.0, v));
        DL.L(dl, mx0 + sl, by + 0.5, fx + sl, by + 0.5, U4(0.70, 0.88, 1.0, 0.9 * v), 1);   -- a bright top edge
        if mpp < 0.995 then DL.L(dl, fx, by + bh, fx + sl, by, U4(1, 1, 1, 0.9 * v), 1); end   -- and its end
    end
end
-- Text on a card, never cut in two: dark ink when the whole word sits on a light HP; white with its dark edge when it
-- sits on the dark, when the HP ends inside it, or on the dark looks
function ALLY.ink(dl, x0, ty, str, fx, y1, y2, tip, v, th)
    local tw = imgui.CalcTextSize(str);
    if th.ink == 'light' or fx < x0 + tw + 2 then text(dl, x0, ty, str, { 1, 1, 1, v }); return; end
    DL.T(dl, x0, ty, U4(0.10, 0.08, 0.14, v), str);
end
-- PARTY > CARDS > Style / Card height: how tall a card is. Slim: a dark card with a thin glowing HP line under the name
-- (the look of your own HP bar: same colours, same Blue Inferno / Beam effect); Filled: the HP fills the card.
function ALLY.sbh(sc) return math.max(1, math.floor(3 * sc * math.max(0.5, math.min(3, tonumber(cfg.party_hp_th) or 1)) + 0.5)); end   -- (PARTY > HP bar thickness)
function ALLY.hexrows() return YUI_HEX and cfg.hex_party ~= false; end   -- (Hex link: PARTY > Hex bars)
function ALLY.ch(lh, sc, party)
    if ALLY.hexrows() then return lh + (party and 22 or 16) * sc; end   -- (Hex link plates: the name, the HP bar, the MP bar)
    local m = math.max(0.7, math.min(1.3, tonumber(cfg.card_h) or 1));
    if (cfg.card_style or 'plate') ~= 'filled' then
        local bars = ALLY.sbh(sc) + (party and (2 * sc + math.max(2, math.floor(2.2 * sc + 0.5))) or 0);
        return math.max(lh + bars + 3 * sc, (lh + bars + 6 * sc) * m);
    end
    return math.max(lh + (party and 7 or 2) * sc, (lh + (party and 11 or 8) * sc) * m);
end
-- Clean style: a member's tag - a small slanted block in its role's colour (tank blue, healer green, support violet,
-- damage red) with its job in it. Alive like the hats: the mouse over it lifts it, a click folds the member's buffs away
-- (or brings them back) with a little bounce. Gives back where it ends.
ALLY.TAGCOL = {                                                      -- flat role colours, the job written in the darkest of each
    tank = { { 0.216, 0.541, 0.867 }, { 0.016, 0.173, 0.325 } }, heal = { { 0.365, 0.792, 0.647 }, { 0.016, 0.204, 0.173 } },
    sup  = { { 0.498, 0.467, 0.867 }, { 0.149, 0.129, 0.361 } }, dps  = { { 0.886, 0.294, 0.290 }, { 0.314, 0.075, 0.075 } } };
-- PARTY > Job tag colours: each job its own colour (the tag, and the job written in a dark or light ink on it)
ALLY.JOBCOL = { [1] = { 0.62, 0.42, 0.26 }, [2] = { 0.96, 0.80, 0.26 }, [3] = { 0.95, 0.95, 0.96 }, [4] = { 0.30, 0.26, 0.40 },
                [5] = { 0.86, 0.22, 0.26 }, [6] = { 0.28, 0.56, 0.36 }, [7] = { 0.96, 0.76, 0.30 }, [8] = { 0.48, 0.14, 0.20 },
                [9] = { 0.82, 0.52, 0.26 }, [10] = { 0.96, 0.56, 0.72 }, [11] = { 0.42, 0.66, 0.30 }, [12] = { 0.92, 0.42, 0.20 },
                [13] = { 0.24, 0.30, 0.58 }, [14] = { 0.60, 0.40, 0.88 }, [15] = { 0.30, 0.76, 0.62 }, [16] = { 0.28, 0.55, 0.96 },
                [17] = { 0.24, 0.74, 0.80 }, [18] = { 0.96, 0.62, 0.30 }, [19] = { 0.90, 0.40, 0.72 }, [20] = { 0.56, 0.70, 0.86 },
                [21] = { 0.40, 0.86, 0.70 }, [22] = { 0.76, 0.50, 0.56 } };
function ALLY.tagcol(job)                                            -- { fill, ink } for a job's tag
    if cfg.party_tag_col ~= 'role' then
        local c = ALLY.JOBCOL[job or 0];
        if c then
            local lum = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3];
            return { c, lum > 0.55 and { c[1] * 0.25, c[2] * 0.25, c[3] * 0.25 } or { 1, 1, 1 } };   -- (dark ink on a light tag, white on a dark one)
        end
    end
    return ALLY.TAGCOL[ALLY.ROLE[job or 0] or 'dps'];
end
function ALLY.tag(dl, m, i, x, ny, ch, sc, v, live, mir)            -- (mir: x is its RIGHT edge, the slant on its left - the card mirrored)
    local tc = ALLY.tagcol(m.job);
    local dim = m.inzone and 1 or 0.45;
    local job = m.tagtext or JOBS[m.job or 0] or '?';
    local fs0 = (FS or 1) * 0.80;
    imgui.SetWindowFontScale(fs0 * 0.74);
    local jw, jh = imgui.CalcTextSize(job);
    jh = tonumber(jh) or 10;
    local th = math.floor(math.min(ch * 0.78, jh + 6 * sc) + 0.5);
    local s = th * 0.30;
    local tw = math.floor(math.max(jw, imgui.CalcTextSize('WHM')) + 12 * sc + s);   -- (all the same width, so the names line up)
    if mir then x = x - tw; end
    local key = m.name or ('m' .. i);
    local h = 0;
    if live then
        local mx, my = imgui.GetMousePos();
        local hov = mx >= x and mx <= x + tw and my >= ny - th / 2 and my <= ny + th / 2;
        ALLY.irect[i] = { x, ny - th / 2, x + tw, ny + th / 2 };
        if hov and imgui.IsMouseClicked(0) and m.name then BUFFS.flip(m.name); end
        BUFFS.hv = BUFFS.hv or {};
        h = BUFFS.hv[key] or 0;
        h = h + ((hov and 1 or 0) - h) * math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 10);
        BUFFS.hv[key] = h;
    end
    local t = os.clock() - ((BUFFS.pop and BUFFS.pop[key]) or -9);
    local bump = (t < 0.35) and (math.sin(math.pi * t / 0.35) * (1 - t / 0.35) * 3 * sc) or 0;
    local y0 = ny - th / 2 - 1.5 * sc * h - bump;
    local pts = { { x, y0 }, { x + tw, y0 }, { x + tw - s, y0 + th }, { x, y0 + th } };
    local jx = x + (tw - s - jw) / 2 + 1 * sc;
    if mir then pts, jx = { { x + s, y0 }, { x + tw, y0 }, { x + tw, y0 + th }, { x, y0 + th } }, x + s + (tw - s - jw) / 2; end
    local f, ink = tc[1], tc[2];
    local ta = 1;                                                    -- (its writing: faded while the tag is turning)
    local fl = C.lot_flip(m, i);                                     -- PARTY > TREASURE POOL: the tag turns over to show the lot
    if fl then
        local cx = x + tw / 2;
        for _, p_ in ipairs(pts) do p_[1] = cx + (p_[1] - cx) * fl.w; end
        ta = math.max(0, (fl.w - 0.35) / 0.65);
        if fl.back then
            job, f, ink = fl.text, fl.fill, fl.ink;
            jw = imgui.CalcTextSize(job);
            jx = (mir and (x + s) or x) + (tw - s - jw) / 2 + (mir and 0 or 1 * sc);
        end
    end
    if fl and fl.back then                                           -- the back: the lot (gold for the highest, grey for a pass)
        ALLY.poly(dl, pts, U4(f[1], f[2], f[3], v));
        if ta > 0.01 then DL.T(dl, jx, y0 + (th - jh) / 2, U4(ink[1], ink[2], ink[3], v * ta), job); end
    elseif (cfg.tag_look or 'role') == 'black' then                 -- (PARTY > CARDS > Job tags: black, the job in white with a dark edge)
        ALLY.poly(dl, pts, U4(0.035, 0.03, 0.045, 0.92 * v * dim));
        if ta > 0.01 then text(dl, jx, y0 + (th - jh) / 2, job, { 1, 1, 1, v * dim * ta }); end
    else
        ALLY.poly(dl, pts, U4(f[1], f[2], f[3], v * dim));      -- (one flat colour: no sheen, no outline)
        if ta > 0.01 then DL.T(dl, jx, y0 + (th - jh) / 2, U4(ink[1], ink[2], ink[3], v * ta), job); end
    end
    imgui.SetWindowFontScale(fs0);
    if mir then return x, s; end
    return x + tw;
end
function ALLY.tpw(sc)                                                -- the TP column's width (room for "3000")
    imgui.SetWindowFontScale((FS or 1) * 0.80 * 0.92);
    local w = imgui.CalcTextSize('3000');
    imgui.SetWindowFontScale((FS or 1) * 0.80);
    return w + 10 * sc;
end
function ALLY.slim(dl, m, i, x1, tip, ny, ch, lh, sc, v, party, live)
    local y1, y2 = ny - ch / 2, ny + ch / 2;
    local pts, g = ALLY.shape(x1, tip, y1, y2, sc);
    local hp = m.inzone and math.max(0, math.min(1, m.hpp or 0)) or 0;
    local th = ALLY.th(hp);
    local b = th.base;
    local style = cfg.card_style or 'clean';
    local bare = style == 'bracket' or style == 'clean';             -- (Bracket: a band behind it; Clean: nothing at all)
    if style == 'bracket' then ALLY.row_bg(dl, x1, tip, y1, y2, sc, v, ALLY.is_tgt(m, i, ALLY.tidx_cur)); end
    local low = cfg.card_low ~= false and m.inzone and hp < 0.30;
    local beat = 0;
    if low then                                                      -- low HP: a heartbeat (lub-dub) of red glow round the card
        local tt = os.clock() * 1.25 + i * 0.13;
        local f = tt - math.floor(tt);
        beat = math.min(1, math.max(0, math.sin(f * math.pi * 2)) ^ 6 + 0.6 * math.max(0, math.sin((f - 0.16) * math.pi * 2)) ^ 6);
        if not bare then pcall(ALLY.glow_ring, dl, pts, (1.2 + 1.6 * beat) * sc, U4(1.0, 0.24, 0.30, (0.12 + 0.28 * beat) * v)); end
    end
    if not bare then
        ALLY.poly(dl, pts, U4(b[1], b[2], b[3], math.min(b[4], 0.80) * v));   -- the card: dark, a little see-through
        if g.mb > g.ma then ALLY.grad(dl, { g.ma, y1 + 1 }, { g.mb, ny }, { 1, 1, 1, 0.07 * v }, { 1, 1, 1, 0.07 * v }, { 1, 1, 1, 0 }, { 1, 1, 1, 0 }); end
        ALLY.edge(dl, pts, v, sc, i, g, th);
    end
    if low and not bare then                                         -- (tinted red, its edge red, both beating)
        ALLY.poly(dl, pts, U4(1.0, 0.20, 0.26, (0.06 + 0.14 * beat) * v));
        for k = 1, #pts do dl:AddLine(pts[k], pts[k % #pts + 1], U4(1.0, 0.32, 0.36, (0.45 + 0.55 * beat) * v), 1.3); end
    end
    local bh = ALLY.sbh(sc);
    local mph = party and math.max(1, math.floor(2.2 * sc * math.max(0.5, math.min(3, tonumber(cfg.party_mp_th) or 1)) + 0.5)) or 0;   -- (PARTY > MP bar thickness)
    local block = lh + 1 * sc + bh + (party and (2 * sc + mph) or 0);
    local top = y1 + (ch - block) * 0.45;
    local tx;
    local bx1 = bare and (tip - 2 * sc) or (tip - g.inr - 3 * sc);
    local tpc = party and ALLY.tpw(sc) or 0;                         -- (your party: room for the TP column on the right)
    bx1 = bx1 - tpc;
    local pct = m.inzone and string.format('%d%%', math.floor((m.hpp or 0) * 100 + 0.5)) or '';
    local pw = imgui.CalcTextSize(pct);
    local nc = low and { 1, 1 - 0.62 * beat, 1 - 0.58 * beat } or { 1, 1, 1 };   -- (low HP: the name and % beat red)
    if style == 'clean' then                                         -- Clean: a slanted tag in its role's colour with its job, the name in capitals
        local sl = ch * 0.30;
        local gp = 3 * sc;
        local mir = party and cfg.party_buff_side == 'right';        -- (PARTY > Buffs side: right - the card mirrored: its tag at the right end, by the buffs)
        local tend, cend = nil, tip;
        if mir then
            local ts_, s_ = ALLY.tag(dl, m, i, tip - 2 * sc, ny, ch, sc, v, live, true);
            tend, cend = x1 + 2 * sc - gp, ts_ + (s_ or 0) - gp;      -- (its slanted edge just off the tag's, as on the left)
        else
            tend = ALLY.tag(dl, m, i, x1 + 2 * sc, ny, ch, sc, v, live);
        end
        local card = { { tend + gp, y1 }, { cend, y1 }, { cend - sl, y2 }, { tend + gp - sl, y2 } };
        if low then pcall(ALLY.glow_ring, dl, card, (1.2 + 1.6 * beat) * sc, U4(1.0, 0.24, 0.30, (0.12 + 0.28 * beat) * v)); end   -- (a thin glow, hugging the card)
        ALLY.poly(dl, card, U4(0.085, 0.08, 0.115, 0.82 * v));
        ALLY.grad(dl, { tend + gp, y1 }, { cend - sl, y1 + 1 }, { 1, 1, 1, 0.14 * v }, { 1, 1, 1, 0 }, { 1, 1, 1, 0 }, { 1, 1, 1, 0.14 * v });
        local tg = ALLY.is_tgt(m, i, ALLY.tidx_cur);
        if low then
            ALLY.poly(dl, card, U4(1.0, 0.20, 0.26, (0.06 + 0.14 * beat) * v));
            for k = 1, 4 do dl:AddLine(card[k], card[k % 4 + 1], U4(1.0, 0.32, 0.36, (0.45 + 0.55 * beat) * v), 1.3); end
        else
            for k = 1, 4 do dl:AddLine(card[k], card[k % 4 + 1], tg and U4(1, 1, 1, 0.85 * v) or U4(0, 0, 0, 0.85 * v), tg and 1.2 or 1); end
        end
        tx = tend + gp + 6 * sc;
        bx1 = cend - sl * 0.5 - 6 * sc - tpc;
        local sp = 1.0 * sc;
        local nm = (m.name or '?'):upper();
        local lmw = ALLY.lead(dl, m, tx, top - 1 + lh * 0.5, sc, v);   -- (the leader's dots before the name)
        local room = bx1 - pw - tx - lmw - 8 * sc;
        local dist = nil;                                            -- PARTY > Distance: how far they are, small, after the name
        if cfg.party_dist ~= false and i ~= 0 and m.inzone then
            dist = m.dist or (m.fake and (m.far and 32.4 or (3 + (i * 3.7) % 15))) or nil;
        end
        local dstr = dist and string.format('%.1f', dist) or nil;
        local dw = 0;
        if dstr then
            imgui.SetWindowFontScale((FS or 1) * 0.80 * 0.66);
            dw = imgui.CalcTextSize(dstr) + 7 * sc;
            imgui.SetWindowFontScale((FS or 1) * 0.80);
            room = room - dw;
        end
        if spaced_w(nm, sp) > room then
            while #nm > 2 and spaced_w(nm .. '.', sp) > room do nm = nm:sub(1, -2); end
            nm = nm .. '.';
        end
        local cx = tx + lmw;
        for k = 1, #nm do                                            -- (each letter with its dark edge)
            local chr = nm:sub(k, k);
            text(dl, cx, top - 1, chr, { nc[1], nc[2], nc[3], (m.inzone and 1 or 0.5) * v });
            cx = cx + imgui.CalcTextSize(chr) + sp;
        end
        if dstr then                                                 -- (white, clearly readable; pink when out of range, as on the target bar)
            local _, nh_ = imgui.CalcTextSize('A');
            imgui.SetWindowFontScale((FS or 1) * 0.80 * 0.66);
            local _, dh_ = imgui.CalcTextSize(dstr);
            local far_ = dist > (tonumber(cfg.party_range) or 20.8);
            text(dl, cx + 6 * sc, top - 1 + (nh_ - dh_) * 0.80, dstr, far_ and { 1, 0.55, 0.75, v } or { 0.96, 0.95, 1, v });
            imgui.SetWindowFontScale((FS or 1) * 0.80);
        end
        text(dl, bx1 - pw, top - 1, pct, { nc[1] * 0.88, nc[2] * 0.86, nc[3] * 0.94, 0.95 * v });
    else
        local ih = math.min(ch * 1.05, lh * 1.45);                   -- the hat: big, floating gently (each at its own pace)
        local ix = bare and (x1 + 2 * sc) or (x1 + g.inl + 1 * sc);
        local fy = math.sin(os.clock() * 1.8 + i * 1.3) * 1.2 * sc;
        if live then ALLY.anim_icon(dl, m, i, ix, ny - ih / 2 + fy, ih, v); else ALLY.icon(dl, m, ix, ny - ih / 2 + fy, ih, v); end
        tx = ix + ih + 6 * sc;
        local lmw = ALLY.lead(dl, m, tx, top - 1 + lh * 0.5, sc, v);
        local nm = ALLY.fit(m.name or '?', bx1 - pw - tx - lmw - 6 * sc);
        text(dl, tx + lmw, top - 1, nm, { nc[1], nc[2], nc[3], (m.inzone and 1 or 0.5) * v });
        text(dl, bx1 - pw, top - 1, pct, { nc[1], nc[2], nc[3], 0.92 * v });
    end
    if not m.inzone then pcall(C.zone_line, dl, m, tx, top + lh + 1 * sc, bx1 - tx, sc, v); end   -- (in another zone: where)
    if not m.inzone or v < 0.5 or bx1 - tx < 10 then return; end
    local c1 = th.f1;
    local c2 = th.f2 or { c1[1] * 0.83, c1[2] * 0.83, c1[3] * 0.88 };
    if YUI_HEX then c1, c2 = C.HEXHP[1], C.HEXHP[2]; end             -- (Hex link mode: gold, as every HP bar)
    if cfg.card_low ~= false and hp < 0.30 then                      -- low HP: the line beats red
        local q = 0.5 + 0.5 * math.sin(os.clock() * 6 + i);
        local function red(c) return { c[1] + (1.0 - c[1]) * q, c[2] + (0.30 - c[2]) * q, c[3] + (0.34 - c[3]) * q }; end
        c1, c2 = red(c1), red(c2);
    end
    local hy = top + lh + 1 * sc;
    local bw = bx1 - tx;
    local dt = imgui.GetIO().DeltaTime or 0.016;
    glow_bar(dl, tx, hy, bw, bh, hp, lagged('sl' .. i, hp, dt), c1, c2, i);
    bar_overlay(tx, hy, bw * hp, bh, bar_fx_for(party and 'party' or 'alliance'), i);
    if party then                                                    -- the MP line
        local my = hy + bh + 2 * sc;
        local mpp = math.max(0, math.min(1, m.mpp or 0));
        DL.RF(dl, tx, my, tx + bw, my + mph, U4(0, 0, 0, 0.45 * v), mph / 2);
        if mpp > 0 then DL.RF(dl, tx, my, tx + math.max(mph, bw * mpp), my + mph, u32(YUI_HEX and { C.HEXMP[1][1], C.HEXMP[1][2], C.HEXMP[1][3], 0.95 * v } or { 0.45, 0.62, 1.0, 0.95 * v }), mph / 2); end
        local tp = tonumber(m.tp) or 0;                              -- the TP, in its column: a tiny "TP" over the number
        local cx = bx1 + 6 * sc + (tpc - 6 * sc) / 2;
        imgui.SetWindowFontScale((FS or 1) * 0.80 * 0.62);
        local lw, lhh = imgui.CalcTextSize('TP');
        lhh = tonumber(lhh) or lh * 0.62;
        imgui.SetWindowFontScale((FS or 1) * 0.80 * 0.92);
        local ts = tostring(tp);
        local vw, vh = imgui.CalcTextSize(ts);
        vh = tonumber(vh) or lh * 0.92;
        local y0 = ny - (lhh + vh - 2 * sc) / 2;
        local full = tp >= 1000;
        local tcol = full and { 1.0, 0.82, 0.42, (0.82 + 0.18 * math.sin(os.clock() * 3 + i)) * v } or { 0.80, 0.79, 0.88, 0.85 * v };
        text(dl, cx - vw / 2, y0 + lhh - 2 * sc, ts, tcol);
        imgui.SetWindowFontScale((FS or 1) * 0.80 * 0.62);
        text(dl, cx - lw / 2, y0, 'TP', full and { 1.0, 0.82, 0.42, 0.75 * v } or { 0.62, 0.60, 0.72, 0.8 * v });
        imgui.SetWindowFontScale((FS or 1) * 0.80);
    end
end
-- Plate style (PARTY > CARDS > Style): each member on an angular dark plate, led by a block in its role's colour holding
-- its hat; the name in spaced capitals, the HP % at the right, the thin HP line (and your party's MP) under the name.
-- Roles: tank (PLD, NIN, RUN) blue, healer (WHM, SCH) green, support (RDM, BRD, COR, GEO) violet, damage red.
ALLY.ROLE = { [7] = 'tank', [13] = 'tank', [22] = 'tank', [3] = 'heal', [20] = 'heal', [5] = 'sup', [10] = 'sup', [17] = 'sup', [21] = 'sup' };
ALLY.RCOL = { tank = { 0.36, 0.62, 1.0 }, heal = { 0.40, 0.84, 0.62 }, sup = { 0.68, 0.52, 1.0 }, dps = { 1.0, 0.42, 0.44 } };
function ALLY.role(job) return ALLY.RCOL[ALLY.ROLE[job or 0] or 'dps']; end
function ALLY.plate(dl, m, i, x1, tip, ny, ch, lh, sc, v, party, live)
    local y1, y2 = ny - ch / 2, ny + ch / 2;
    local s = ch * 0.32;                                             -- (the lean of every slanted side)
    local bw = math.floor(ch * 1.15);
    local rc = ALLY.role(m.job);
    local dim = m.inzone and 1 or 0.45;
    local hp = m.inzone and math.max(0, math.min(1, m.hpp or 0)) or 0;
    local th = ALLY.th(hp);
    local tgt = ALLY.is_tgt(m, i, ALLY.tidx_cur);
    local function edge(pts, col, w) for k = 1, #pts do dl:AddLine(pts[k], pts[k % #pts + 1], col, w); end end
    local blk = { { x1, y1 }, { x1 + bw, y1 }, { x1 + bw - s, y2 }, { x1, y2 } };   -- the role block: dark, its colour rising from the foot
    ALLY.poly(dl, blk, U4(0.07, 0.065, 0.10, 0.92 * v));
    local fb = ALLY.clip_x(blk, x1, x1 + bw);
    if #fb >= 3 then                                                 -- (the colour: strong at the foot, gone at the top)
        local mid = (y1 + y2) / 2;
        pcall(function()
            C.clip(dl, { x1, y1 }, { x1 + bw, y2 }, true);
            ALLY.grad(dl, { x1, mid - 2 }, { x1 + bw, y2 }, { rc[1], rc[2], rc[3], 0 }, { rc[1], rc[2], rc[3], 0 }, { rc[1], rc[2], rc[3], 0.55 * v * dim }, { rc[1], rc[2], rc[3], 0.55 * v * dim });
            dl:PopClipRect();
        end);
    end
    local px0 = x1 + bw + 2 * sc;                                    -- the plate
    local plate = { { px0, y1 }, { tip, y1 }, { tip - s, y2 }, { px0 - s, y2 } };
    ALLY.poly(dl, plate, U4(0.09, 0.085, 0.12, 0.84 * v));
    ALLY.grad(dl, { px0, y1 }, { tip - s, y1 + 1 }, { 1, 1, 1, 0.12 * v }, { 1, 1, 1, 0 }, { 1, 1, 1, 0 }, { 1, 1, 1, 0.12 * v });
    ALLY.grad(dl, { px0 - s, y2 - 1 }, { tip - s, y2 }, { rc[1], rc[2], rc[3], 0.85 * v * dim }, { rc[1], rc[2], rc[3], 0 }, { rc[1], rc[2], rc[3], 0 }, { rc[1], rc[2], rc[3], 0.85 * v * dim });   -- (its role colour, a hairline at its foot)
    DL.RF(dl, x1, y1, x1 + 2 * sc, y2, U4(rc[1], rc[2], rc[3], 0.95 * v * dim));   -- (and a stripe on the block's left)
    edge(blk, U4(0, 0, 0, 0.85 * v), 1);
    if tgt then                                                      -- your target: a fine white edge, the plate a touch lighter
        ALLY.poly(dl, plate, U4(1, 1, 1, 0.06 * v));
        edge(plate, U4(1, 1, 1, 0.85 * v), 1.1);
    else
        edge(plate, U4(0, 0, 0, 0.85 * v), 1);
    end
    local ih = ch * 0.80;                                            -- the hat, in the block
    local icx = x1 + (bw - s * 0.5) / 2;
    if live then ALLY.anim_icon(dl, m, i, icx - ih / 2, ny - ih / 2, ih, v); else ALLY.icon(dl, m, icx - ih / 2, ny - ih / 2, ih, v); end
    local bh = ALLY.sbh(sc);
    local mph = party and math.max(1, math.floor(2.2 * sc * math.max(0.5, math.min(3, tonumber(cfg.party_mp_th) or 1)) + 0.5)) or 0;   -- (PARTY > MP bar thickness)
    local block = lh + 1 * sc + bh + (party and (2 * sc + mph) or 0);
    local top = y1 + (ch - block) * 0.45;
    local tx = px0 + 3 * sc;
    local rx = tip - s * 0.35 - 6 * sc;
    local pct = m.inzone and string.format('%d%%', math.floor((m.hpp or 0) * 100 + 0.5)) or '';
    local pw = imgui.CalcTextSize(pct);
    local sp = 1.5 * sc;
    local nm = (m.name or '?'):upper();
    local lmw = ALLY.lead(dl, m, tx, top - 1 + lh * 0.5, sc, v);
    local room = rx - pw - tx - lmw - 8 * sc;
    if spaced_w(nm, sp) > room then
        while #nm > 2 and spaced_w(nm .. '.', sp) > room do nm = nm:sub(1, -2); end
        nm = nm .. '.';
    end
    spaced(dl, tx + lmw, top - 1, nm, U4(1, 1, 1, v * dim), sp);
    text(dl, rx - pw, top - 1, pct, { 1, 1, 1, 0.92 * v });
    if not m.inzone then pcall(C.zone_line, dl, m, tx, top + lh + 1 * sc, rx - tx, sc, v); end   -- (in another zone: where)
    if not m.inzone or v < 0.5 then return; end
    local hy = top + lh + 1 * sc;
    local bx1 = tip - s * ((hy - y1) / ch) - 6 * sc;                 -- (the bar ends inside the slanted right side)
    local bw2 = bx1 - tx;
    if bw2 < 10 then return; end
    local c1 = th.f1;
    local c2 = th.f2 or { c1[1] * 0.83, c1[2] * 0.83, c1[3] * 0.88 };
    if YUI_HEX then c1, c2 = C.HEXHP[1], C.HEXHP[2]; end             -- (Hex link mode: gold)
    if cfg.card_low ~= false and hp < 0.30 then
        local q = 0.5 + 0.5 * math.sin(os.clock() * 6 + i);
        local function red(c) return { c[1] + (1.0 - c[1]) * q, c[2] + (0.30 - c[2]) * q, c[3] + (0.34 - c[3]) * q }; end
        c1, c2 = red(c1), red(c2);
    end
    local dt = imgui.GetIO().DeltaTime or 0.016;
    glow_bar(dl, tx, hy, bw2, bh, hp, lagged('pl' .. i, hp, dt), c1, c2, i);
    bar_overlay(tx, hy, bw2 * hp, bh, bar_fx_for(party and 'party' or 'alliance'), i);
    if party then
        local my = hy + bh + 2 * sc;
        local mpp = math.max(0, math.min(1, m.mpp or 0));
        DL.RF(dl, tx, my, tx + bw2, my + mph, U4(0, 0, 0, 0.45 * v), mph / 2);
        if mpp > 0 then DL.RF(dl, tx, my, tx + math.max(mph, bw2 * mpp), my + mph, u32(YUI_HEX and { C.HEXMP[1][1], C.HEXMP[1][2], C.HEXMP[1][3], 0.95 * v } or { 0.45, 0.62, 1.0, 0.95 * v }), mph / 2); end
    end
end
-- a card's back: "cur/max" - the current value smaller, the max bigger, on one baseline - as big as fits room;
-- gives back the line's height
function ALLY.curmax(dl, x, cy, cur, max, room, fs0, fsc, col)
    local cs, ms = tostring(cur), '/' .. tostring(max);
    local function sizes(f)
        imgui.SetWindowFontScale(fs0 * f * 0.74);
        local cw, chh = imgui.CalcTextSize(cs);
        imgui.SetWindowFontScale(fs0 * f);
        local mw, mh = imgui.CalcTextSize(ms);
        return cw, tonumber(chh) or 8, mw, tonumber(mh) or 10;
    end
    local cw, chh, mw, mh = sizes(fsc);
    while room and cw + mw > room and fsc > 0.55 do fsc = fsc - 0.04; cw, chh, mw, mh = sizes(fsc); end
    local base = cy + mh / 2;                                        -- (their common foot)
    imgui.SetWindowFontScale(fs0 * fsc * 0.74);
    text(dl, x, base - chh * 1.0, cs, { col[1], col[2], col[3], (col[4] or 1) * 0.9 });
    imgui.SetWindowFontScale(fs0 * fsc);
    local sw = tonumber((imgui.CalcTextSize('/'))) or 0;             -- (the slash faint: the slanted cut between HP and MP stays the only clear one)
    text(dl, x + cw + 1, cy - mh / 2, '/', { col[1], col[2], col[3], (col[4] or 1) * 0.32 });
    text(dl, x + cw + 1 + sw, cy - mh / 2, tostring(max), col);
    imgui.SetWindowFontScale(fs0);
    return mh;
end
-- a card's back: one size for HP and MP, and where the cut between them goes - each gets the room its numbers need
-- (x0 .. x1: both; lw: a label's width; gap: between them); gives back the size and the cut
function ALLY.split2(x0, x1, hc, hm, mc, mm, lw, gap, fs0, fmax, sc)
    local function w1(cur, max)                                      -- (its width at size 1)
        imgui.SetWindowFontScale(fs0 * 0.74);
        local a = imgui.CalcTextSize(tostring(cur));
        imgui.SetWindowFontScale(fs0);
        local b = imgui.CalcTextSize('/' .. tostring(max));
        return (tonumber(a) or 0) + (tonumber(b) or 0) + 1;
    end
    local wh, wm = w1(hc, hm), w1(mc, mm);
    local avail = (x1 - x0) - 2 * (lw + 3 * sc) - gap;
    local f = math.max(0.55, math.min(fmax, avail / math.max(1, wh + wm)));
    imgui.SetWindowFontScale(fs0);
    return f, x0 + lw + 3 * sc + f * wh + gap / 2;
end
-- Normal mode's card turned over (see ALLY.turn): while turning, the card's shape flattening and opening again with a
-- light across it; then its back - the tag, the name, HP and MP in numbers, the TP
function ALLY.nflip(dl, m, i, x1, tip, ny, ch, lh, sc, v, party, live, f)
    local now = os.clock();
    local fs0 = (FS or 1) * 0.80;
    local p = math.min(1, (now - f.t) / 0.46);
    local face = f.back;
    if p < 0.5 then face = not f.back; end
    local e = p < 1 and (0.5 - 0.5 * math.cos(math.pi * p)) or 1;
    local k = math.abs(math.cos(math.pi * e));
    if p >= 1 then
        local tb = now - f.t - 0.46;
        if tb >= 0 and tb < 0.25 then k = 1 + 0.05 * math.sin(math.pi * tb / 0.25); end
    end
    local hp = m.inzone and math.max(0, math.min(1, m.hpp or 0)) or 0;
    local low = cfg.card_low ~= false and m.inzone and hp < 0.30;
    local tgt = ALLY.is_tgt(m, i, ALLY.tidx_cur);
    local hh = ch / 2 * k;
    local y1, y2 = ny - hh, ny + hh;
    local sl = ch * 0.30 * k;
    local gp = 3 * sc;
    local tend;
    if p >= 1 and k >= 0.99 then
        tend = ALLY.tag(dl, m, i, x1 + 2 * sc, ny, ch, sc, v, live);
    else                                                             -- (while turning: a stripe of the tag's colour)
        local tc = ALLY.tagcol(m.job)[1];
        local th_ = ch * 0.78 * k;
        ALLY.poly(dl, { { x1 + 2 * sc, ny - th_ / 2 }, { x1 + 40 * sc, ny - th_ / 2 }, { x1 + 40 * sc - th_ * 0.3, ny + th_ / 2 }, { x1 + 2 * sc, ny + th_ / 2 } }, U4(tc[1], tc[2], tc[3], v));
        tend = x1 + 40 * sc;
    end
    local card = { { tend + gp, y1 }, { tip, y1 }, { tip - sl, y2 }, { tend + gp - sl, y2 } };
    ALLY.poly(dl, card, U4(0.085, 0.08, 0.115, 0.82 * v));
    ALLY.grad(dl, { tend + gp, y1 }, { tip - sl, y1 + 1 }, { 1, 1, 1, 0.14 * v }, { 1, 1, 1, 0 }, { 1, 1, 1, 0 }, { 1, 1, 1, 0.14 * v });
    for q = 1, 4 do dl:AddLine(card[q], card[q % 4 + 1], low and U4(1.0, 0.32, 0.36, 0.9 * v) or (tgt and U4(1, 1, 1, 0.85 * v) or U4(0, 0, 0, 0.85 * v)), tgt and 1.2 or 1); end
    local ta = (k > 0.55) and math.min(1, (k - 0.55) / 0.35) or 0;
    if face and ta > 0 then                                          -- the back
        local tx = tend + gp + 6 * sc;
        local tpc = party and ALLY.tpw(sc) or 0;
        local bx1 = tip - sl * 0.5 - 6 * sc - tpc;
        local top = ny - ch / 2 + 2 * sc;
        local nm = (m.name or '?'):upper();
        local sp = 1.0 * sc;
        local room = bx1 - tx;
        if spaced_w(nm, sp) > room then
            while #nm > 2 and spaced_w(nm .. '.', sp) > room do nm = nm:sub(1, -2); end
            nm = nm .. '.';
        end
        spaced(dl, tx, top, nm, U4(1, 1, 1, v * ta * (m.inzone and 1 or 0.5)), sp);
        local _, nh = imgui.CalcTextSize('A');
        local ry = top + nh;
        if m.inzone then
            local hpmax = (m.hpp and m.hpp > 0) and math.floor((m.hp or 0) / m.hpp + 0.5) or (m.hp or 0);
            local mpmax = (m.mpp and m.mpp > 0) and math.floor((m.mp or 0) / m.mpp + 0.5) or (m.mp or 0);
            local hasmp = party or (m.mp or 0) > 0;
            imgui.SetWindowFontScale(fs0 * 0.62);
            local lwm = tonumber((imgui.CalcTextSize('MP'))) or 10;
            imgui.SetWindowFontScale(fs0);
            local fsz, mid = 1.0, bx1;
            if hasmp then fsz, mid = ALLY.split2(tx, bx1, m.hp or 0, hpmax, m.mp or 0, mpmax, lwm, 10 * sc, fs0, 1.0, sc); end
            local function section(x0, x2, lab, cur, max, col, vcol)
                imgui.SetWindowFontScale(fs0 * 0.62);
                local lw_, lh_ = imgui.CalcTextSize(lab);
                lh_ = tonumber(lh_) or lh * 0.6;
                local cy = ry + (y2 - 1 * sc - ry) / 2;
                local vh = ALLY.curmax(dl, x0 + lw_ + 3 * sc, cy, cur, max, (not hasmp) and (x2 - x0 - lw_ - 3 * sc) or nil, fs0, fsz, { vcol[1], vcol[2], vcol[3], v * ta });
                imgui.SetWindowFontScale(fs0 * 0.62);
                text(dl, x0, cy - vh / 2 + (vh - lh_) * 0.75, lab, { col[1], col[2], col[3], 0.9 * v * ta });
                imgui.SetWindowFontScale(fs0);
            end
            local hc = low and { 1, 0.42, 0.46 } or { 1, 0.55, 0.82 };
            section(tx, mid - 5 * sc, 'HP', m.hp or 0, hpmax, hc, low and { 1, 0.70, 0.72 } or { 1, 0.80, 0.92 });
            if hasmp then section(mid + 5 * sc, bx1, 'MP', m.mp or 0, mpmax, { 0.50, 0.68, 1 }, { 0.74, 0.84, 1 }); end
        end
        if party and m.inzone then                                   -- (the TP, in its column as on the front)
            local tp = tonumber(m.tp) or 0;
            local cx = bx1 + 6 * sc + (tpc - 6 * sc) / 2;
            imgui.SetWindowFontScale(fs0 * 0.62);
            local lw, lhh = imgui.CalcTextSize('TP');
            lhh = tonumber(lhh) or lh * 0.62;
            imgui.SetWindowFontScale(fs0 * 0.92);
            local ts = tostring(tp);
            local vw, vh = imgui.CalcTextSize(ts);
            vh = tonumber(vh) or lh * 0.92;
            local y0 = ny - (lhh + vh - 2 * sc) / 2;
            local full = tp >= 1000;
            text(dl, cx - vw / 2, y0 + lhh - 2 * sc, ts, full and { 1.0, 0.82, 0.42, v * ta } or { 0.80, 0.79, 0.88, 0.85 * v * ta });
            imgui.SetWindowFontScale(fs0 * 0.62);
            text(dl, cx - lw / 2, y0, 'TP', full and { 1.0, 0.82, 0.42, 0.75 * v * ta } or { 0.62, 0.60, 0.72, 0.8 * v * ta });
            imgui.SetWindowFontScale(fs0);
        end
    end
    if p < 1 then                                                    -- (the turn: a light across the middle, brightest edge-on)
        local gl = (1 - k) ^ 2;
        DL.L(dl, tend, ny, tip, ny, U4(1, 0.75, 0.92, 0.9 * gl * v), (1 + 2 * gl) * sc);
    end
end
-- Hex link's party plate (see ALLY.hexrows and ALLY.turn): the front or the back, turning between them
function ALLY.hexrow(dl, m, i, x1, tip, ny, ch, lh, sc, v, party, live)
    local now = os.clock();
    local fs0 = (FS or 1) * 0.80;
    local GO, GO2, DK = C.HEXHP[1], { 1, 0.90, 0.62 }, { 0.79, 0.65, 0.35 };
    local AZ = C.HEXMP[1];
    local hp = m.inzone and math.max(0, math.min(1, m.hpp or 0)) or 0;
    local mpp = math.max(0, math.min(1, m.mpp or 0));
    local tp = tonumber(m.tp) or 0;
    local low = cfg.card_low ~= false and m.inzone and hp < 0.30;
    local beat = low and (0.5 + 0.5 * math.sin(now * 6 + i)) or 0;
    local tgt = ALLY.is_tgt(m, i, ALLY.tidx_cur);
    local dim = m.inzone and 1 or 0.5;
    -- the turn
    local key = m.name or ('m' .. i);
    local f = ALLY.FL[key];
    local p = f and math.min(1, (now - f.t) / 0.46) or 1;
    local back = f and f.back or false;
    local face = back;
    if p < 0.5 then face = not back; end                             -- (the first half still shows the side it leaves)
    local e = p < 1 and (0.5 - 0.5 * math.cos(math.pi * p)) or 1;
    local k = math.abs(math.cos(math.pi * e));                        -- (its height while turning: 1 -> 0 -> 1)
    if p >= 1 and f then
        local tb = now - f.t - 0.46;                                 -- (a little bounce as it lands)
        if tb >= 0 and tb < 0.25 then k = 1 + 0.06 * math.sin(math.pi * tb / 0.25); end
    end
    local ta = (k > 0.55) and math.min(1, (k - 0.55) / 0.35) or 0;    -- (the writing fades while it's edge-on)
    local hh = ch / 2 * k;
    local y1, y2 = ny - hh, ny + hh;
    local K = math.min(9 * sc, ch * 0.32) * k;                        -- (the corner cut)
    -- the plate (one piece; your party's TP in a compartment at its right end)
    local plate = { { x1 + K, y1 }, { tip, y1 }, { tip, y2 - K }, { tip - K, y2 }, { x1, y2 }, { x1, y1 + K } };
    local CR = { 1, 0.94, 0.78 };                                    -- (the selection arrow's cream: your target's edge)
    local ec = low and { 1.0, 0.32, 0.36 } or (tgt and CR or DK);
    local ea = low and (0.55 + 0.45 * beat) or (tgt and 0.95 or 0.45);
    if low then pcall(ALLY.glow_ring, dl, plate, (1.2 + 1.6 * beat) * sc, U4(1.0, 0.24, 0.30, (0.12 + 0.28 * beat) * v)); end
    pcall(function() dl:AddConvexPolyFilled(plate, tgt and U4(0.085, 0.085, 0.115, 0.88 * v) or U4(0.067, 0.059, 0.09, 0.86 * v)); end);   -- (the picked one a touch lighter)
    local tw = party and 36 * sc or 0;                               -- (the TP compartment's width)
    local cut = tip - tw;                                            -- (its slanted cut: from cut + sl at the top to cut - sl at the foot)
    local sl = 4 * sc * k;
    if party then
        local full = tp >= 1000;
        if full then                                                 -- (lit gold from 1000, breathing)
            local cmp = { { cut + sl, y1 }, { tip, y1 }, { tip, y2 - K }, { tip - K, y2 }, { cut - sl, y2 } };
            pcall(function() dl:AddConvexPolyFilled(cmp, U4(GO[1], GO[2], GO[3], (0.13 + 0.06 * math.sin(now * 3 + i)) * v)); end);
        end
        DL.L(dl, cut + sl, y1 + 2 * sc, cut - sl, y2 - 2 * sc, full and U4(GO2[1], GO2[2], GO2[3], 0.8 * v) or U4(DK[1], DK[2], DK[3], 0.45 * v), 1);
        if ta > 0 and m.inzone then
            local cx = cut + (tip - cut) / 2;
            imgui.SetWindowFontScale(fs0 * 0.55);
            local lw, lhh = imgui.CalcTextSize('TP');
            imgui.SetWindowFontScale(fs0 * 0.82);
            local ts = tostring(tp);
            local vw, vh = imgui.CalcTextSize(ts);
            lhh, vh = tonumber(lhh) or 8, tonumber(vh) or 12;
            local yy = ny - (lhh + vh * 0.9) / 2;
            text(dl, cx - vw / 2, yy + lhh * 0.95, ts, full and { GO2[1], GO2[2], GO2[3], v * ta } or { 0.80, 0.79, 0.88, 0.85 * v * ta });
            imgui.SetWindowFontScale(fs0 * 0.55);
            text(dl, cx - lw / 2, yy, 'TP', full and { GO[1], GO[2], GO[3], 0.85 * v * ta } or { 0.62, 0.60, 0.72, 0.8 * v * ta });
            imgui.SetWindowFontScale(fs0);
        end
    end
    if tgt and not low then                                          -- (your target: the arrow's soft glow round its edge)
        for q = 1, 6 do dl:AddLine(plate[q], plate[q % 6 + 1], U4(1, 0.80, 0.43, 0.22 * v), 4 * sc); end
    end
    for q = 1, 6 do dl:AddLine(plate[q], plate[q % 6 + 1], U4(ec[1], ec[2], ec[3], ea * v), tgt and 1.4 or 1); end
    if k > 0.9 then
        local cc = tgt and CR or GO2;                                -- (the cuts lit, as Hex link's frames - cream on your target)
        DL.L(dl, x1, y1 + K, x1 + K, y1, U4(cc[1], cc[2], cc[3], (tgt and 1 or 0.6) * v), 1.6 * sc);
        DL.L(dl, tip - K, y2, tip, y2 - K, U4(cc[1], cc[2], cc[3], (tgt and 1 or 0.6) * v), 1.6 * sc);
    end
    -- the job's tag (its click folds the buffs; while turning: a stripe of its colour)
    local tend;
    if p >= 1 and k >= 0.99 then
        tend = ALLY.tag(dl, m, i, x1 + 5 * sc, ny, ch * 0.78, sc, v, live);
    else
        local tc = ALLY.tagcol(m.job)[1];
        local th_ = ch * 0.5 * k;
        DL.RF(dl, x1 + 5 * sc, ny - th_ / 2, x1 + 39 * sc, ny + th_ / 2, U4(tc[1], tc[2], tc[3], v * dim));
        tend = x1 + 39 * sc;
    end
    local bx = tend + 7 * sc;
    local bw = (party and (cut - sl - 7 * sc) or (tip - 8 * sc)) - bx;
    local _, nh = imgui.CalcTextSize('A');
    local top = ny - ch / 2 + 3 * sc;
    if ta > 0 then
        -- the name, on both sides
        local nc = low and { 1, 0.62 + 0.38 * (1 - beat), 0.62 + 0.38 * (1 - beat) } or { 1, 1, 1 };
        local lmw = ALLY.lead(dl, m, bx, top + lh * 0.5, sc, v * ta);
        local nm = (m.name or '?'):upper();
        local sp = 1.2 * sc;
        local dist = (cfg.party_dist ~= false and i ~= 0 and m.inzone) and (m.dist or (m.fake and (m.far and 32.4 or (3 + (i * 3.7) % 15))) or nil) or nil;
        local room = bw - lmw - (dist and 30 * sc or 0);
        if spaced_w(nm, sp) > room then
            while #nm > 2 and spaced_w(nm .. '.', sp) > room do nm = nm:sub(1, -2); end
            nm = nm .. '.';
        end
        local nw = spaced(dl, bx + lmw, top, nm, U4(nc[1], nc[2], nc[3], v * ta * dim), sp);
        if dist then
            local dstr = string.format('%.1f', dist);
            imgui.SetWindowFontScale(fs0 * 0.62);
            local _, dh = imgui.CalcTextSize(dstr);
            local far_ = dist > (tonumber(cfg.party_range) or 20.8);
            text(dl, bx + lmw + nw + 6 * sc, top + (nh - (tonumber(dh) or nh)) * 0.78, dstr, far_ and { 1, 0.55, 0.75, v * ta } or { 0.84, 0.83, 0.90, 0.9 * v * ta });
            imgui.SetWindowFontScale(fs0);
        end
        local ry = top + nh + 1.5 * sc;                              -- (under the name: the bars, or the numbers)
        if not m.inzone then
            pcall(C.zone_line, dl, m, bx, ry, bw, sc, v * ta);
        elseif not face then                                         -- FRONT: Hex link's HP bar, the MP under it
            if v > 0.3 then
                local dt = imgui.GetIO().DeltaTime or 0.016;
                local hb = 7.5 * sc;
                local hy = ry + 1 * sc + hb / 2;
                local hc1, hc2 = C.HEXHP[1], C.HEXHP[2];
                if low then
                    local function red(c) return { c[1] + (1.0 - c[1]) * (0.7 + 0.3 * beat), c[2] + (0.30 - c[2]) * (0.7 + 0.3 * beat), c[3] + (0.34 - c[3]) * (0.7 + 0.3 * beat) }; end
                    hc1, hc2 = red(hc1), red(hc2);
                end
                C.hexbar(dl, bx, hy - 1, bw, 2, hp, lagged('hx' .. i, hp, dt), i, { c1 = hc1, c2 = hc2, band = hb, al = v * ta });
                if party or (m.mp or 0) > 0 then
                    local my = hy + hb / 2 + 3 * sc;
                    local mh = math.max(2, 3 * sc);
                    DL.RF(dl, bx + 3 * sc, my, bx + bw - 3 * sc, my + mh, U4(0.05, 0.10, 0.14, 0.9 * v * ta), mh / 2);
                    if mpp > 0 then DL.RF(dl, bx + 3 * sc, my, bx + 3 * sc + (bw - 6 * sc) * mpp, my + mh, U4(AZ[1], AZ[2], AZ[3], 0.95 * v * ta), mh / 2); end
                end
            end
        else                                                         -- BACK: HP | MP in numbers where the bars were
            local hpmax = (m.hpp and m.hpp > 0) and math.floor((m.hp or 0) / m.hpp + 0.5) or (m.hp or 0);
            local mpmax = (m.mpp and m.mpp > 0) and math.floor((m.mp or 0) / m.mpp + 0.5) or (m.mp or 0);
            local hasmp = party or (m.mp or 0) > 0;
            imgui.SetWindowFontScale(fs0 * 0.74);
            local lwm = tonumber((imgui.CalcTextSize('MP'))) or 10;
            imgui.SetWindowFontScale(fs0);
            local fsz, mid = 1.28, bx + bw;
            if hasmp then fsz, mid = ALLY.split2(bx, bx + bw, m.hp or 0, hpmax, m.mp or 0, mpmax, lwm, 12 * sc, fs0, 1.28, sc); end
            if hasmp then DL.L(dl, mid + 3 * sc, ry + 1 * sc, mid - 3 * sc, y2 - 3 * sc, U4(DK[1], DK[2], DK[3], 0.5 * v * ta), 1); end
            local function section(x0, x2, lab, cur, max, col, vcol)   -- ("HP" small, then the numbers - as big as fit)
                imgui.SetWindowFontScale(fs0 * 0.74);
                local lw_, lh_ = imgui.CalcTextSize(lab);
                lh_ = tonumber(lh_) or lh * 0.55;
                local cy = ry + (y2 - 2 * sc - ry) / 2;
                local vh = ALLY.curmax(dl, x0 + lw_ + 3 * sc, cy, cur, max, (not hasmp) and (x2 - x0 - lw_ - 3 * sc) or nil, fs0, fsz, { vcol[1], vcol[2], vcol[3], v * ta });
                imgui.SetWindowFontScale(fs0 * 0.74);
                text(dl, x0, cy - vh / 2 + (vh - lh_) * 0.75, lab, { col[1], col[2], col[3], 0.9 * v * ta });
                imgui.SetWindowFontScale(fs0);
            end
            section(bx, mid - 6 * sc, 'HP', m.hp or 0, hpmax, low and { 1, 0.4, 0.42 } or GO, low and { 1, 0.66, 0.68 } or GO2);
            if hasmp then section(mid + 6 * sc, bx + bw, 'MP', m.mp or 0, mpmax, AZ, { 0.72, 0.90, 1 }); end
        end
    end
    if p < 1 then                                                    -- the turn: a gold light across the middle, brightest edge-on
        local gl = (1 - k) ^ 2;
        DL.L(dl, x1, ny, tip, ny, U4(GO2[1], GO2[2], GO2[3], 0.9 * gl * v), (1 + 2 * gl) * sc);
    end
end
-- One whole card (centred on ny, from x1 to tip): the card, its edge, the MP bar (your party), the hat, the name and HP %.
-- live = its hat is alive (a click folds the buffs); off for the settings' preview.
-- PARTY > Fade far members: a member out of spell range is drawn faded (the whole card, every style)
function ALLY.card(dl, m, i, x1, tip, ny, ch, lh, sc, v, party, live)
    if not (m.far and cfg.party_dim_far ~= false) then return ALLY.card_(dl, m, i, x1, tip, ny, ch, lh, sc, v, party, live); end
    imgui.PushStyleVar(ImGuiStyleVar_Alpha, 0.42);
    local ok, err = pcall(ALLY.card_, dl, m, i, x1, tip, ny, ch, lh, sc, v, party, live);
    imgui.PopStyleVar(1);
    if not ok then error(err, 0); end
end
function ALLY.card_(dl, m, i, x1, tip, ny, ch, lh, sc, v, party, live)
    if ALLY.lowtest and m.inzone then m = setmetatable({ hpp = math.min(m.hpp or 1, 0.22) }, { __index = m }); end   -- (Preview low HP)
    if cfg.card_low ~= false and m.inzone and (m.hpp or 1) < 0.30 then   -- low HP: the card trembles, in bursts
        local t = os.clock();
        local env = (0.5 + 0.5 * math.sin(t * 5 + i)) ^ 2;
        local k = sc * (0.35 + 0.65 * env);
        local dx = (math.sin(t * 47 + i * 3) * 1.3 + math.sin(t * 29 + i) * 0.7) * k;
        local dy = math.sin(t * 39 + i * 5) * 0.6 * k;
        x1, tip, ny = x1 + dx, tip + dx, ny + dy;
    end
    if ALLY.hexrows() then return ALLY.hexrow(dl, m, i, x1, tip, ny, ch, lh, sc, v, party, live); end   -- (Hex link: Hex bars)
    do                                                               -- (Normal: a card turned over, or turning)
        local f = ALLY.FL[m.name or ('m' .. i)];
        if f and (f.back or os.clock() - f.t < 0.46) then return ALLY.nflip(dl, m, i, x1, tip, ny, ch, lh, sc, v, party, live, f); end
    end
    if (cfg.card_style or 'plate') == 'plate' then return ALLY.plate(dl, m, i, x1, tip, ny, ch, lh, sc, v, party, live); end
    if (cfg.card_style or 'plate') ~= 'filled' then return ALLY.slim(dl, m, i, x1, tip, ny, ch, lh, sc, v, party, live); end
    local y1, y2 = ny - ch / 2, ny + ch / 2;
    local pts, g = ALLY.shape(x1, tip, y1, y2, sc);
    local hp = m.inzone and math.max(0, math.min(1, m.hpp or 0)) or 0;
    local th = ALLY.th(hp);
    local fx = ALLY.body(dl, pts, g, x1, tip, y1, y2, hp, v, sc, i, th);
    ALLY.edge(dl, pts, v, sc, i, g, th);
    if party and m.inzone then ALLY.mpbar(dl, m, g, x1, y2, sc, v); end
    local ih = lh;
    local ix = x1 + g.inl + 4 * sc;
    local up = party and 2.5 * sc or 0;                              -- (your party: room for the MP bar under the name)
    if live then ALLY.anim_icon(dl, m, i, ix, ny - ih / 2 - 1 - up, ih, v); else ALLY.icon(dl, m, ix, ny - ih / 2 - 1 - up, ih, v); end
    local tx = ix + ih + 6 * sc;
    local pct = m.inzone and string.format('%d%%', math.floor((m.hpp or 0) * 100 + 0.5)) or '';
    local pw = imgui.CalcTextSize(pct);
    local px = tip - g.inr - pw - 4 * sc;
    local nm = ALLY.fit(m.name or '?', px - tx - 6 * sc);
    local ty = ny - lh / 2 - 2 - up;
    ALLY.ink(dl, tx, ty, nm, fx, y1, y2, tip, v, th);
    ALLY.ink(dl, px, ty, pct, fx, y1, y2, tip, v, th);
end
function ALLY.vline(dl, lx, y0, y1, sc, a) C.vline(dl, lx, y0, y1, sc, a); end   -- (the crisp YunaUI line)
-- PARTY > CARDS > Spine outline: once a list has come in, a light runs down its line; at each member it turns out along
-- the tick and runs round the card both ways, leaving the card outlined in the line's colour at that height (violet at
-- the top to ice blue at the bottom). The outline then stays.
function ALLY.vcol(u)                                                -- the line's colour at u (0 top .. 1 bottom)
    u = math.max(0, math.min(1, u));
    return 0.68 + (0.55 - 0.68) * u, 0.50 + (0.86 - 0.50) * u, 1.0;
end
function ALLY.perim_at(pts, px, py)                                  -- how far round the outline the point nearest (px, py) is
    local best, bd, acc = 0, 1e9, 0;
    for k = 1, #pts do
        local a, b = pts[k], pts[k % #pts + 1];
        local dx, dy = b[1] - a[1], b[2] - a[2];
        local l2 = math.max(0.0001, dx * dx + dy * dy);
        local t = math.max(0, math.min(1, ((px - a[1]) * dx + (py - a[2]) * dy) / l2));
        local qx, qy = a[1] + dx * t, a[2] + dy * t;
        local d = (qx - px) ^ 2 + (qy - py) ^ 2;
        if d < bd then bd, best = d, acc + math.sqrt(l2) * t; end
        acc = acc + math.sqrt(l2);
    end
    return best, acc;
end
-- The outline drawn from d0 both ways round, p of the way (0..1: the two ends meet on the far side), with a bright head
function ALLY.trace(dl, pts, d0, per, p, r, g, b, a, sc)
    local half = per / 2 * p;
    local n = math.max(2, math.ceil(half / (3 * sc)));
    for dir = -1, 1, 2 do
        local px, py = ALLY.along(pts, d0);
        for k = 1, n do
            local nx, ny = ALLY.along(pts, d0 + dir * half * k / n);
            DL.L(dl, px, py, nx, ny, U4(r, g, b, a), 1.2);
            px, py = nx, ny;
        end
        if p < 1 then                                                -- its running head
            DL.CF(dl, px, py, 3.2 * sc, U4(r, g, b, 0.30 * a), 12);
            DL.CF(dl, px, py, 1.5 * sc, U4(1, 1, 1, math.min(1, a * 1.6)), 10);   -- (the running head stays bright)
        end
    end
end
-- Bracket style: a [ on the left holds the whole group (party, alliance 1 or 2), from its first member to its last, in
-- the line's colours (violet at the top to ice blue at the bottom) with a fine glow. When the group forms it draws
-- itself: the upright grows out from the middle, then its arms slide out; when a member joins or leaves it stretches
-- smoothly to fit. PARTY > CARDS > Bracket look:
--   glass   each member on a dark glass band (a soft light on top, a fine highlight), fading out to the right
--   ribbon  each member on a plain dark band fading out to the right
--   frame   a lighter band; the bracket's arms run all the way to the line, framing the group
ALLY.BLOOKS = { { 'glass', 'Glass' }, { 'ribbon', 'Ribbon' }, { 'frame', 'Frame' } };
ALLY.bk = {};
function ALLY.bracket(dl, key, bx, top, bot, sc, a, now, lx)
    local bk = ALLY.bk[key];
    local t0 = ALLY.t0[key];
    local age = t0 and (now - t0) or 99;
    if bk == nil or age < 0.05 then bk = { top = top, bot = bot }; ALLY.bk[key] = bk; end
    local k = math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 10);
    bk.top, bk.bot = bk.top + (top - bk.top) * k, bk.bot + (bot - bk.bot) * k;
    local a1 = math.max(0, math.min(1, (age - 0.15) / 0.45)); a1 = 1 - (1 - a1) ^ 3;   -- the upright
    local a2 = math.max(0, math.min(1, (age - 0.50) / 0.35)); a2 = 1 - (1 - a2) ^ 3;   -- then its arms
    local cy = (bk.top + bk.bot) / 2;
    local half = (bk.bot - bk.top) / 2 * a1;
    if half < 0.5 then return; end
    local look = cfg.bracket_look or 'glass';
    local th = math.max(2, math.floor(2 * sc + 0.5));
    bx = math.floor(bx + 0.5);
    local y0, y1 = math.floor(cy - half + 0.5), math.floor(cy + half + 0.5);
    local r1, g1, b1 = ALLY.vcol(0);
    local r2, g2, b2 = ALLY.vcol(1);
    local function c1(al) return { r1, g1, b1, al * a }; end
    local function c2(al) return { r2, g2, b2, al * a }; end
    local function up(x0, x1, al) ALLY.grad(dl, { x0, y0 }, { x1, y1 }, c1(al), c1(al), c2(al), c2(al)); end
    up(bx - 2, bx - 1, 0.10); up(bx + th + 1, bx + th + 2, 0.10);    -- the upright: faint outer pixels, a halo, the core
    up(bx - 1, bx, 0.32); up(bx + th, bx + th + 1, 0.32);
    up(bx, bx + th, 1.0);
    local reach = (look == 'frame' and lx) and (lx - bx) or 10 * sc; -- (Frame: the arms run to the line)
    local sw = reach * a2;
    if sw > 0.5 then
        local ath = (look == 'frame') and math.max(1, th - 1) or th;
        local function arm(y, c, cf)
            ALLY.grad(dl, { bx, y - 1 }, { bx + sw, y }, cf(0.30), cf(0.30), cf(0.30), cf(0.30));
            ALLY.grad(dl, { bx, y }, { bx + sw, y + ath }, c, c, c, c);
            ALLY.grad(dl, { bx, y + ath }, { bx + sw, y + ath + 1 }, cf(0.30), cf(0.30), cf(0.30), cf(0.30));
        end
        arm(y0, c1(1), c1);
        arm(y1 - ath, c2(1), c2);
    end
end
-- A member's band (Bracket style): dark, fading out to the right; lit violet when it's your target
function ALLY.row_bg(dl, x1, tip, y1, y2, sc, v, tgt)
    local look = cfg.bracket_look or 'glass';
    local L, R = x1 - 3 * sc, tip + 6 * sc;
    local function d(al) return { 0.05, 0.04, 0.08, al * v }; end
    local function w(al) return { 1, 1, 1, al * v }; end
    local strong = (look == 'frame') and 0.48 or ((look == 'glass') and 0.64 or 0.72);
    local M = L + (R - L) * 0.55;                                    -- (full under the name, fading out past the HP %)
    ALLY.grad(dl, { L, y1 }, { M, y2 }, d(strong), d(strong * 0.85), d(strong * 0.85), d(strong));
    ALLY.grad(dl, { M, y1 }, { R, y2 }, d(strong * 0.85), d(strong * 0.18), d(strong * 0.18), d(strong * 0.85));
    if look == 'glass' then
        local mid = (y1 + y2) / 2;
        ALLY.grad(dl, { L, y1 }, { R, mid }, w(0.10), w(0), w(0), w(0.02));   -- a soft light on its top half
        ALLY.grad(dl, { L, y1 }, { R, y1 + 1 }, w(0.30), w(0), w(0), w(0.30)); -- a fine highlight along the top
        ALLY.grad(dl, { L, y2 - 1 }, { R, y2 }, d(0.60), d(0), d(0), d(0.60)); -- and a dark line at its foot
    end
    if tgt then                                                      -- your target: the band lights up violet
        local p = 0.85 + 0.15 * math.sin(os.clock() * 3);
        ALLY.grad(dl, { L, y1 }, { R, y2 }, { 0.62, 0.45, 1.0, 0.42 * p * v }, { 0.62, 0.45, 1.0, 0 }, { 0.62, 0.45, 1.0, 0 }, { 0.62, 0.45, 1.0, 0.42 * p * v });
    end
end
-- PARTY > CARDS: three sample cards as they look now (full, hurt, low), on the YunaUI line
function ALLY.preview()
    local ps = C.ps or 1;
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    local pushed = sized('chat', 17 * ps);
    imgui.SetWindowFontScale(FS * 0.80);
    local lh = imgui.GetTextLineHeight();
    local sc = ps;
    local ch = ALLY.ch(lh, sc, true);
    local gap = ch + 6 * sc;
    local lx = x + ROW_W - 8 * sc;
    local tip = lx - 10 * sc;
    local cw = math.min((((cfg.card_style or 'clean') == 'clean') and 300 or 220) * sc, ROW_W - 30 * sc);
    local list = { { name = 'Yunas', job = 4, hpp = 1.0, mpp = 0.85, inzone = true }, { name = 'Slayern', job = 3, hpp = 0.62, mpp = 0.45, inzone = true },
        { name = 'Tankie', job = 7, hpp = 0.18, mpp = 0.12, inzone = true } };
    local y0, y1 = y + 4 * sc, y + 4 * sc + #list * gap;
    ALLY.cur = 0;
    ALLY.tidx_cur = nil;
    if cfg.spine_line ~= false and (cfg.card_style or 'clean') ~= 'clean' then ALLY.vline(dl, lx, y0, y1, sc, 1); end
    if (cfg.card_style or 'plate') == 'bracket' then ALLY.bracket(dl, 'preview', tip - cw - 6 * sc, y0 + gap / 2 - ch / 2, y0 + gap / 2 + (#list - 1) * gap + ch / 2, sc, 1, os.clock(), lx); end
    for k, m in ipairs(list) do
        local ny = y0 + gap / 2 + (k - 1) * gap;
        ALLY.card(dl, m, 900 + k, tip - cw, tip, ny, ch, lh, sc, 1, true, false);
        if cfg.spine_line ~= false and (cfg.card_style or 'clean') ~= 'clean' then DL.L(dl, tip, ny, lx, ny, U4(1, 1, 1, 0.40), 1); end
    end
    if pushed then imgui.PopFont(); end
    FS = 1;
    imgui.SetWindowFontScale(C.wfs or 1);
    imgui.Dummy({ ROW_W, #list * gap + 8 * sc });
end
function ALLY.hpcol(m, thr)
    local hp = m.hpp or 0;
    if not m.inzone then return nil; end
    if hp < 0.5 then local b = 0.5 + 0.5 * math.sin(os.clock() * 7); return { 1.0, 0.28, 0.30, 0.65 + 0.35 * b }, true; end
    if hp < (thr or 0.75) then return { 1.0, 0.36, 0.62, 1 }; end
    return { 0.62, 0.40, 1.0, 1 };
end
function ALLY.orbs(dl, list, x, y, sc, dt, tidx)
    local R = 17 * sc;
    local step = R * 2 + 14 * sc;
    local now = os.clock();
    local c1, c2 = C.hpb1 or C.hp, C.hpb2 or C.hp2;
    local fs = FS or 1;
    imgui.SetWindowFontScale(fs * 0.70);
    local lh = imgui.GetTextLineHeight();
    for k, e in ipairs(list) do
        local m, i = e[1], e[2];
        local cx, cy = x + R + 4 * sc + (k - 1) * step, y + R + 4 * sc;
        local a = m.inzone and 1 or 0.4;
        local hp = m.inzone and math.max(0, math.min(1, m.hpp or 0)) or 0;
        local low = m.inzone and hp < 0.5;
        local tgt = ALLY.is_tgt(m, i, tidx);
        ALLY.click(m, i, (imgui.GetMousePos() - cx) ^ 2 + (select(2, imgui.GetMousePos()) - cy) ^ 2 < (R + 4) ^ 2);
        if tgt then                                                  -- selected: a violet halo, or a chromatic ring running round
            if ALLY.chroma() then ALLY.chroma_path(dl, ALLY.circle_pts(cx, cy, R + 5, 36), 2, 1);
            else for g = 3, 1, -1 do DL.C(dl, cx, cy, R + 3 + g * 2, U4(0.62, 0.40, 1.0, 0.10 * (4 - g)), 32, 3); end end
        end
        if low then                                                  -- low: a red beat round it
            local b = (now * 1.6 + i * 0.3) % 1;
            DL.C(dl, cx, cy, R + 4 + b * 10 * sc, U4(1.0, 0.30, 0.32, 0.6 * (1 - b)), 32, 2);
        end
        DL.CF(dl, cx, cy, R + 3, U4(0.03, 0.025, 0.045, 0.90 * a), 32);
        DL.C(dl, cx, cy, R, U4(1, 1, 1, 0.08 * a), 40, 3.5);
        local seg = 48;                                              -- the HP ring, from the top, clockwise
        local nseg = math.floor(seg * hp + 0.5);
        for s_ = 0, nseg - 1 do
            local u = s_ / seg;
            local a0, a1 = -math.pi / 2 + u * math.pi * 2, -math.pi / 2 + (s_ + 1) / seg * math.pi * 2;
            local col = low and { 1.0, 0.30, 0.32 } or { c1[1] + (c2[1] - c1[1]) * u, c1[2] + (c2[2] - c1[2]) * u, c1[3] + (c2[3] - c1[3]) * u };
            DL.L(dl, cx + math.cos(a0) * R, cy + math.sin(a0) * R, cx + math.cos(a1) * R, cy + math.sin(a1) * R, U4(col[1], col[2], col[3], a), 3.2);
        end
        if hp > 0 and hp < 1 then                                    -- its head: a small bright dot
            local ah = -math.pi / 2 + hp * math.pi * 2;
            DL.CF(dl, cx + math.cos(ah) * R, cy + math.sin(ah) * R, 2.4 * sc, U4(1, 1, 1, 0.95 * a), 10);
        end
        local gp = ((now / 3.2) + k * 0.13) % 1;                     -- a glint running round the bezel
        if gp < 0.35 then
            local q = gp / 0.35;
            for t_ = 0, 5 do
                local ag = -math.pi / 2 + (q - t_ * 0.02) * math.pi * 2;
                DL.CF(dl, cx + math.cos(ag) * (R + 3), cy + math.sin(ag) * (R + 3), (2 - t_ * 0.25) * sc, U4(1, 0.95, 1, (0.55 - t_ * 0.09) * a * math.sin(q * math.pi)), 8);
            end
        end
        local ih = R * 1.25;                                         -- the hat
        ALLY.icon(dl, m, cx - ih / 2, cy - ih / 2, ih, a);
        if m.leader or m.aleader then LEAD_MARK(dl, cx + R * 0.8, cy - R * 0.85, 3.6 * sc, m.aleader, a, 'dots'); end
        local nm = ALLY.fit(m.name or '?', step - 4 * sc);
        local nw = imgui.CalcTextSize(nm);
        text(dl, cx - nw / 2, cy + R + 6 * sc, nm, low and { 1, 0.70, 0.72, a } or { 0.92, 0.90, 0.98, a });
    end
    imgui.SetWindowFontScale(fs);
    return R * 2 + 12 * sc + lh, math.max(1, #list) * step;
end
-- Comings and goings: a member who joins fades in; one who leaves slides off to the right as it fades (a "ghost" of its
-- card, kept for a moment); the others glide to their new places. The arrow by PARTY slides every list off to the right
-- of the screen (and back), the anchor by it ties the alliances to the party (or frees them).
function ALLY.vkey(key, e) return 's' .. tostring(key) .. ':' .. tostring((e[1] and e[1].name) or e[2]) .. ((e[1] and e[1].fake) and ('#' .. tostring(e[2])) or ''); end
ALLY.yp, ALLY.seen, ALLY.ghosts, ALLY.hbh, ALLY.hold = {}, {}, {}, {}, {};
function ALLY.hide_k()                                               -- 0 shown .. 1 slid away (eased)
    local h = ALLY.hk or 0;
    return h * h * (3 - 2 * h);
end
function ALLY.head_icons(dl, x, cy, sc)                              -- the arrow and the anchor, left of the PARTY title
    local r = {};
    local bs = 14 * sc;
    local ax = x - bs;                                               -- the anchor: two dots, joined while the alliances are anchored
    local on = cfg.ally_anchor == true;
    local hv = ALLY.hbh.anchor;
    local c = on and { 0.86, 0.58, 1.0, hv and 1 or 0.9 } or { 0.62, 0.60, 0.70, hv and 1 or 0.7 };
    local cxa = ax + bs / 2;
    if YUI_HEX then                                                  -- (Hex link mode: a gold and an azure hexagon, a fine gold line when anchored)
        local dx = 4.2 * sc;
        local c1_, c2_ = on and C.GOLDH or { 0.62, 0.60, 0.70 }, on and C.HEXMP[1] or { 0.62, 0.60, 0.70 };
        if on then DL.L(dl, cxa - dx, cy, cxa + dx, cy, U4(C.GOLDH2[1], C.GOLDH2[2], C.GOLDH2[3], 0.55 * c[4]), 1); end
        for _, q in ipairs({ { -1, c1_ }, { 1, c2_ } }) do
            C.hexdot(dl, cxa + q[1] * dx, cy, 3.3 * sc, U4(0.05, 0.045, 0.07, 0.85 * c[4]));
            C.hexdot(dl, cxa + q[1] * dx, cy, 2.5 * sc, U4(q[2][1], q[2][2], q[2][3], c[4]));
        end
    else
        if on then DL.L(dl, cxa - 3.6 * sc, cy, cxa + 3.6 * sc, cy, u32(c), 1.6 * sc); end
        DL.CF(dl, cxa - 3.6 * sc, cy, 2.4 * sc, u32(c), 10);
        DL.CF(dl, cxa + 3.6 * sc, cy, 2.4 * sc, u32(c), 10);
    end
    r.anchor = { ax, cy - bs / 2, bs, bs };
    local rx = ax - bs - 2 * sc;                                     -- the arrow: > slides them away, < brings them back
    local hidden = cfg.party_hidden == true;
    local cc = U4(1, 1, 1, ALLY.hbh.arrow and 1 or 0.75);
    local cxr = rx + bs / 2;
    local d = hidden and -1 or 1;
    DL.L(dl, cxr - 2.6 * sc * d, cy - 4.2 * sc, cxr + 2.6 * sc * d, cy, cc, 1.6 * sc);
    DL.L(dl, cxr + 2.6 * sc * d, cy, cxr - 2.6 * sc * d, cy + 4.2 * sc, cc, 1.6 * sc);
    r.arrow = { rx, cy - bs / 2, bs, bs };
    ALLY.hbtn = r;
end
function ALLY.spine(dl, list, x, y, sc, dt, tidx, n, party)
    local ent = ALLY.entry(tostring(n), #list > (party and 1 or 0), list);   -- (sliding in from the right as it forms)
    local ee = 1 - (1 - ent) ^ 3;
    x = x + (1 - ee) * 170 * sc;
    if party then                                                    -- (the arrow by PARTY: slide everything off to the right, or back)
        local want = cfg.party_hidden and 1 or 0;
        ALLY.hk = (ALLY.hk or want) + (want - (ALLY.hk or want)) * math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 5);
        if math.abs(ALLY.hk - want) < 0.002 then ALLY.hk = want; end
    end
    local hk = ALLY.hide_k();
    local SW = (ALLY.screen()) or 1920;
    local clipped = (ee < 1 or party or hk > 0) and pcall(function() C.fullclip(dl); end);   -- (it may come from outside its window; the party's buffs sit outside it)
    local thr = (tonumber(cfg.ally_smart_hp) or 75) / 100;
    local now = os.clock();
    local fs = FS or 1;
    local wide = (cfg.card_style or 'clean') == 'clean';             -- (Clean: wider, so the name in capitals has room)
    local w = (wide and 300 or 230) * sc;
    local lx = x + w - 8 * sc;                                       -- the line, at the right
    pcall(function()                                                 -- (where its line rests, for lining the alliances up on it)
        local wx = imgui.GetWindowPos();
        ALLY.lx = ALLY.lx or {};
        ALLY.lx[tostring(n)] = { lx - (1 - ee) * 170 * sc, lx - (1 - ee) * 170 * sc - wx };
    end);
    imgui.SetWindowFontScale((FS or 1) * 0.80);                      -- (a card's height, so the cards never overlap)
    local lh80 = imgui.GetTextLineHeight();
    local gap = ALLY.ch(lh80, sc, party) + (party and 6 or 4) * sc;   -- (PARTY > CARDS: style, height)
    if party then ALLY.pgap, ALLY.pn = gap, #list; end               -- (PARTY > Grow upward: how far a full party reaches)
    local brk = (cfg.card_style or 'plate') == 'bracket';          -- (Bracket: the arrow and buffs step left of the [)
    ALLY.tidx_cur = tidx;                                            -- (Bracket: your target's band lights up)
    local lp = brk and 12 * sc or 0;
    imgui.SetWindowFontScale(FS or 1);
    imgui.SetWindowFontScale(fs * 0.66);
    local lab = (type(n) == 'string') and n or ('ALLIANCE ' .. n);
    local lw = imgui.CalcTextSize(lab);
    local labh = imgui.GetTextLineHeight();
    text(dl, lx - lw - 8 * sc, y, lab, { C.muted[1], C.muted[2], C.muted[3], 0.9 });
    if party then ALLY.head_icons(dl, lx - lw - 14 * sc, y + labh / 2, sc); end
    imgui.SetWindowFontScale(fs);
    local y0 = y + labh + 6 * sc;                                    -- (under its title)
    local y1 = y0 + 10 * sc + (#list - 1) * gap + 10 * sc;
    local trace = cfg.spine_trace ~= false and not brk and (cfg.card_style or 'clean') ~= 'plate' and (cfg.card_style or 'clean') ~= 'clean';   -- (Spine outline: Slim / Filled)
    local t0 = ALLY.t0[tostring(n)];
    local ts = t0 and (t0 + 0.95 + math.max(0, #list - 1) * 0.22) or -1e9;   -- (when the cards have all come in)
    local tT = 0.35 + 0.07 * #list;                                  -- (how long the light takes down the line)
    local sl = cfg.spine_line ~= false and (cfg.card_style or 'clean') ~= 'clean';   -- (the spine: not with Clean)
    if sl then ALLY.vline(dl, lx, y0, y1, sc, ee); end               -- the line: violet to ice blue, fading out at both ends
    if sl and trace and now >= ts and now < ts + tT then             -- the light running down the line
        local hy = y0 + (y1 - y0) * ((now - ts) / tT);
        local r, g, b = ALLY.vcol((hy - y0) / math.max(1, y1 - y0));
        local X = math.floor(lx + 0.5) - 1;
        pcall(function()
            DL.RFM(dl, X, math.max(y0, hy - 22 * sc), X + 2, hy, U4(1, 1, 1, 0), U4(1, 1, 1, 0), U4(1, 1, 1, 0.9), U4(1, 1, 1, 0.9));
        end);
        DL.CF(dl, X + 1, hy, 4.5 * sc, U4(r, g, b, 0.30), 14);
        DL.CF(dl, X + 1, hy, 2.0 * sc, U4(1, 1, 1, 1), 12);
    end
    local skey = tostring(n);
    local seen_now = {};
    local dtl = imgui.GetIO().DeltaTime or 0.016;
    do                                                               -- who left since the last frame: their card slides off right, fading
        local here = {};                                             -- (and the others wait for it before gliding up)
        for _, e in ipairs(list) do here[ALLY.vkey(skey, e)] = true; end
        for k_, g_ in pairs(ALLY.seen[skey] or {}) do
            if not here[k_] and not g_.m.fake then
                ALLY.ghosts[#ALLY.ghosts + 1] = { list = skey, m = g_.m, i = g_.i, ny = g_.ny, t0 = now, party = party };
                ALLY.hold[skey] = now + 0.28;
            end
        end
    end
    for k, e in ipairs(list) do
        local m, i = e[1], e[2];
        local key = ALLY.vkey(skey, e);
        local tny = y0 + 10 * sc + (k - 1) * gap;
        local py = ALLY.yp[key] or tny;                              -- (it glides to its place when others come or go,
        if now >= (ALLY.hold[skey] or 0) then py = py + (tny - py) * math.min(1, dtl * 12); end   -- once a leaving card has slid away)
        if math.abs(py - tny) < 0.3 then py = tny; end
        ALLY.yp[key] = py;
        local ny = py;
        seen_now[key] = { m = m, i = i, ny = ny };
        local mx, my = imgui.GetMousePos();
        local over = hk < 0.5 and math.abs(my - ny) < gap / 2 and mx >= x and mx <= lx + 10 * sc;
        ALLY.click(m, i, over);
        local tgt = ALLY.is_tgt(m, i, tidx);
        local want = true;                                           -- (every member's card always shows)
        local v = ALLY.v[key] or 0;
        if v < 0 then v = v + (imgui.GetIO().DeltaTime or 0.016);       -- (still waiting its turn)
        else v = v + ((want and 1 or 0) - v) * math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 9); end
        ALLY.v[key] = v;
        v = math.max(0, v) * ee * (1 - hk);                          -- (and fading in with the list; out when slid away)
        if v > 0.02 then                                             -- the card, sliding out to the left
            imgui.SetWindowFontScale(fs * 0.80);
            local lh = imgui.GetTextLineHeight();
            local ch = ALLY.ch(lh, sc, party);                         -- (PARTY > CARDS: style, height)
            local cw = (wide and 250 or 180) * sc;
            local tip = lx - 10 * sc + hk * (SW - x + 60 * sc);      -- (it fades in where it stays; slides off right when hidden)
            local x1 = tip - cw;
            ALLY.card(dl, m, i, x1, tip, ny, ch, lh, sc, v, party, true);   -- (PARTY > CARDS: its shape, colours, effect)
            pcall(C.lot_badge, dl, m, x1, tip, ny, ch, sc, v, party);   -- (PARTY > TREASURE POOL: its lot on the picked item)
            if trace then                                            -- the light reaching this card: out along the tick, then round it
                local u = (ny - y0) / math.max(1, y1 - y0);
                local tk = ts + u * tT;
                local rc = ALLY.role(m.job);                         -- (its role's colour)
                local r, g, b = rc[1], rc[2], rc[3];
                if sl and now >= tk and now < tk + 0.12 then
                    local q0 = (now - tk) / 0.12;
                    DL.CF(dl, lx + (tip - lx) * q0, ny, 1.8 * sc, U4(1, 1, 1, v), 10);
                end
                local q = math.max(0, math.min(1, (now - tk - 0.12) / 0.55));
                if sl and now >= tk + 0.12 then DL.L(dl, tip, ny, lx, ny, U4(r, g, b, 0.55 * v), 1.2); end   -- (its tick, coloured too)
                if q > 0 then
                    local pts = ALLY.shape(x1, tip, ny - ch / 2, ny + ch / 2, sc);
                    local d0, per = ALLY.perim_at(pts, tip, ny);
                    ALLY.trace(dl, pts, d0, per, 1 - (1 - q) ^ 2, r, g, b, 0.55 * v, sc);   -- (a soft outline)
                end
            end
            if tgt then                                              -- selected: the chromatic white arrow, pointing at it, gently swaying
                local as = ch * (ALLY.hexrows() and 1.0 or 0.72);    -- (Hex link's arrow: a 2:1 picture, longer)
                local sway = math.sin(os.clock() * 4) * 3 * sc;
                local ax = x1 - as - 1 * sc + sway - lp;
                if ALLY.hexrows() then local aw = as * 0.75; ax = ax + (as - aw); image(dl, tex('sel_arrow_hex.png'), ax, ny - as / 4, ax + aw, ny + as / 4, { 1, 1, 1, v });   -- (shorter: 3/4 of its length, same height, tip where it was)   -- (the user's own arrow alone - no chevron, haze or trail: 2:1)   -- (Hex link's plates: its own arrow)
                else image(dl, tex('sel_arrow.png'), ax, ny - as / 2, ax + as, ny + as / 2, { 1, 1, 1, v }); end
            end
            if sl then
                DL.L(dl, tip, ny, lx, ny, U4(1, 1, 1, 0.40 * v), 1);   -- joined to the line
                if v < 0.98 then                                     -- as it opens, a light runs from the line out to it
                    DL.CF(dl, lx + (tip - lx) * v, ny, 2.2 * sc, U4(1, 1, 1, 0.9 * (1 - v)), 10);
                end
            end
            if party and cfg.buffs then                               -- your party: its buffs left of the card, or right of the line (PARTY > Buffs side)
                local bs = math.floor(16 * sc * (tonumber(cfg.buff_scale) or 1));
                if cfg.party_buff_side == 'right' then
                    pcall(function() draw_buffs(dl, math.max(lx, tip) + 6 * sc, ny - bs / 2, member_buffs(i), bs, 16, 1, 1, nil,
                        BUFFS.val(m.name or i)); end);
                else
                    pcall(function()
                        local bl_ = member_buffs(i);
                        if cfg.party_buff_ffxi ~= false then             -- (PARTY > FFXI order: read left to right as the game shows them)
                            local r_ = {};
                            local n_ = math.min(#bl_, 16);
                            for k_ = 1, n_ do r_[k_] = bl_[n_ - k_ + 1]; end
                            bl_ = r_;
                        end
                        draw_buffs(dl, x1 - 6 * sc - lp - ((tgt and ch * (ALLY.hexrows() and 1.0 or 0.72) + 4 * sc) or 0), ny - bs / 2, bl_, bs, 16, 1, -1, nil, BUFFS.val(m.name or i));
                    end);
                end
            end
            imgui.SetWindowFontScale(fs);
        end
    end
    ALLY.seen[skey] = seen_now;
    for gi = #ALLY.ghosts, 1, -1 do
        local g_ = ALLY.ghosts[gi];
        local a = (now - g_.t0) / 0.38;
        if a >= 1 then table.remove(ALLY.ghosts, gi);
        elseif g_.list == skey then
            imgui.SetWindowFontScale(fs * 0.80);
            local lh = imgui.GetTextLineHeight();
            local ch = ALLY.ch(lh, sc, party);
            local cw = (wide and 250 or 180) * sc;
            local tip = lx - 10 * sc + (a * a) * 120 * sc;
            ALLY.card(dl, g_.m, g_.i, tip - cw, tip, g_.ny, ch, lh, sc, (1 - a) * (1 - hk), party, false);
            imgui.SetWindowFontScale(fs);
        end
    end
    if brk and #list > 0 then                                        -- the [ holding the whole group
        local chb = ALLY.ch(lh80, sc, party);
        ALLY.bracket(dl, tostring(n), lx - 10 * sc - (wide and 250 or 180) * sc - 6 * sc, y0 + 10 * sc - chb / 2, y0 + 10 * sc + (#list - 1) * gap + chb / 2, sc, ee, now, lx);
    end
    if clipped then pcall(function() dl:PopClipRect(); end); end
    return y1 - y + 4 * sc, w;
end
function ALLY.hex(dl, list, x, y, sc, dt, tidx)
    local Rh = 24 * sc;
    local hw = math.sqrt(3) * Rh;                                    -- a cell's width (points up)
    local now = os.clock();
    local c1 = C.hpb1 or C.hp;
    local mx, my = imgui.GetMousePos();
    local hover = nil;
    local function corners(cx, cy, r)
        local p = {};
        for k = 0, 5 do local a = math.rad(-90 + 60 * k); p[#p + 1] = { cx + math.cos(a) * r, cy + math.sin(a) * r }; end
        return p;
    end
    local function fill(p, col) for k = 2, 5 do dl:AddTriangleFilled(p[1], p[k], p[k + 1], col); end end
    for k, e in ipairs(list) do
        local m, i = e[1], e[2];
        local row, col = math.floor((k - 1) / 3), (k - 1) % 3;
        local cx = x + hw / 2 + 2 * sc + col * (hw + 3 * sc) + row * (hw / 2 + 1.5 * sc);
        local cy = y + Rh + 2 * sc + row * (Rh * 1.5 + 3 * sc);
        local a = m.inzone and 1 or 0.4;
        local hp = m.inzone and math.max(0, math.min(1, m.hpp or 0)) or 0;
        local low = m.inzone and hp < 0.5;
        local tgt = ALLY.is_tgt(m, i, tidx);
        local p = corners(cx, cy, Rh);
        ALLY.click(m, i, (mx - cx) ^ 2 + (my - cy) ^ 2 < Rh * Rh);
        fill(p, U4(0.03, 0.025, 0.045, 0.90 * a));
        -- the contour, glowing like YunaUI's panel: violet (red and beating when low, brighter on your target)
        local gc = { 0.62, 0.40, 1.0 };
        local ga, la = 0.55 + 0.20 * math.sin(now * 2 + k), 0.85;
        if tgt then gc, ga = { 0.85, 0.65, 1.0 }, 1; end
        if low then local b = 0.5 + 0.5 * math.sin(now * 7 + i); gc, ga = { 1.0, 0.30, 0.32 }, 0.6 + 0.4 * b; end
        for g = 3, 1, -1 do                                          -- the glow: wide faint strokes
            local pg = corners(cx, cy, Rh + g * 1.2);
            for t_ = 1, 6 do dl:AddLine(pg[t_], pg[t_ % 6 + 1], U4(gc[1], gc[2], gc[3], 0.09 * (4 - g) * ga * a), 1.6 + g * 1.8); end
        end
        for t_ = 1, 6 do dl:AddLine(p[t_], p[t_ % 6 + 1], U4((gc[1] + 1) / 2, (gc[2] + 1) / 2, (gc[3] + 1) / 2, la * a), 1.3); end
        if tgt and ALLY.chroma() then ALLY.chroma_path(dl, corners(cx, cy, Rh + 1.5), 2, 1); end   -- selected: the contour turns chromatic
        if hp > 0 then                                               -- the HP: the living bar, inside the cell under the hat
            local bw, bh_ = hw * 0.66, math.max(3, math.floor(4 * sc));
            glow_bar(dl, cx - bw / 2, cy + Rh * 0.42, bw, bh_, hp, lagged('hx' .. i, hp, dt), low and { 1.0, 0.40, 0.40 } or (C.hpb1 or C.hp),
                low and { 0.85, 0.15, 0.22 } or (C.hpb2 or C.hp2), i + 90);
        end
        local ih = Rh * 0.95;
        ALLY.icon(dl, m, cx - ih / 2, cy - ih / 2 - Rh * 0.16, ih, a);  -- (a little up: the HP bar sits under it)
        if m.leader or m.aleader then LEAD_MARK(dl, cx, cy - Rh + 5 * sc, 3.4 * sc, m.aleader, a, 'dots'); end
        if (mx - cx) ^ 2 + (my - cy) ^ 2 < Rh * Rh then hover = { m, cx, cy }; end
    end
    local rows = math.max(1, math.ceil(#list / 3));
    local h = 2 * Rh + (rows - 1) * (Rh * 1.5 + 3 * sc) + 6 * sc;
    if hover then                                                    -- the mouse over a cell: its name in a little pill
        local fs = FS or 1;
        imgui.SetWindowFontScale(fs * 0.78);
        local m = hover[1];
        local str = (m.name or '?') .. (m.inzone and string.format('  %d%%', math.floor((m.hpp or 0) * 100 + 0.5)) or '');
        local tw, th = imgui.CalcTextSize(str);
        local px, py = hover[2] - tw / 2 - 8, hover[3] - Rh - th - 12;
        DL.RF(dl, px, py, px + tw + 16, py + th + 6, U4(0.045, 0.04, 0.065, 0.95), (th + 6) / 2);
        DL.R(dl, px, py, px + tw + 16, py + th + 6, U4(0.62, 0.40, 1.0, 0.7), (th + 6) / 2, ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15, 1);
        text(dl, px + 8, py + 3, str, { 1, 1, 1, 1 });
        imgui.SetWindowFontScale(fs);
    end
    return h, 3 * (hw + 3 * sc) + hw / 2 + 6 * sc;
end
-- One alliance party in the chosen look; gives back its height and width
function ALLY.draw(dl, x, y, first, style, sc, dt, tidx, n)
    ALLY.cur = n;
    local list = {};
    for i = first, first + 5 do local m = member(i); if m then list[#list + 1] = { m, i }; end end
    if style == 'orbs' then return ALLY.orbs(dl, list, x, y, sc, dt, tidx); end
    if style == 'spine' then return ALLY.spine(dl, list, x, y, sc, dt, tidx, n); end
    if style == 'hex' then return ALLY.hex(dl, list, x, y, sc, dt, tidx); end
    local w = 210 * sc;
    if style == 'tiles' then
        local tw, th, g = (w - 8 * sc) / 3, 32 * sc, 4 * sc;
        for k, e in ipairs(list) do
            local col, row = (k - 1) % 3, math.floor((k - 1) / 3);
            ALLY.tile(dl, e[1], e[2], x + col * (tw + g), y + row * (th + g), tw, th, sc, tidx);
        end
        return math.max(1, math.ceil(#list / 3)) * (th + g) - g, w;
    end
    local yy = y;
    if style == 'smart' then                                         -- the line of dots
        local r = 5 * sc;
        local thr = (tonumber(cfg.ally_smart_hp) or 75) / 100;
        local fs = FS or 1;
        imgui.SetWindowFontScale(fs * 0.70);
        local lab = 'ALLIANCE ' .. n;
        text(dl, x, yy, lab, { C.muted[1], C.muted[2], C.muted[3], 0.9 });
        local lw = imgui.CalcTextSize(lab);
        local lh0 = imgui.GetTextLineHeight();
        imgui.SetWindowFontScale(fs);
        local px = x + lw + 12 * sc;
        local cy = yy + lh0 / 2;
        for _, e in ipairs(list) do
            local m = e[1];
            local hp = m.hpp or 0;
            local c;
            if not m.inzone then c = nil;
            elseif hp >= thr then c = { 0.62, 0.40, 1.0, 0.85 };
            elseif hp >= 0.5 then c = { 1.0, 0.36, 0.62, 1 };
            else local b = 0.5 + 0.5 * math.sin(os.clock() * 7); c = { 1.0, 0.28, 0.30, 0.6 + 0.4 * b }; end
            if c then
                DL.CF(dl, px + r, cy, r + 1, U4(0, 0, 0, 0.6), 14);
                DL.CF(dl, px + r, cy, r, u32(c), 14);
            else
                DL.C(dl, px + r, cy, r, U4(0.6, 0.58, 0.68, 0.6), 14, 1.2);   -- (not in the zone)
            end
            px = px + r * 2 + 5 * sc;
        end
        yy = yy + lh0 + 6 * sc;
        for _, e in ipairs(list) do                                  -- the members that need you, opened
            local m, i = e[1], e[2];
            local want = ALLY.hov[n] or (m.idx ~= 0 and m.idx == tidx) or (m.inzone and (m.hpp or 1) < thr);
            local key = 'a' .. i;
            local v = ALLY.v[key] or 0;
            v = v + ((want and 1 or 0) - v) * math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 9);
            ALLY.v[key] = v;
            if v > 0.02 then
                local rh = 0;
                local ok = pcall(function()
                    C.clip(dl, { x - 6, yy - 2 }, { x + w + 6, yy + 40 * sc * v }, true);
                    rh = ALLY.row(dl, m, i, x, yy, w, sc, dt, tidx);
                    dl:PopClipRect();
                end);
                if not ok then rh = 0; end
                yy = yy + rh * v;
            end
        end
        return yy - y, w;
    end
    for _, e in ipairs(list) do yy = yy + ALLY.row(dl, e[1], e[2], x, yy, w, sc, dt, tidx); end   -- compact
    return yy - y, w;
end
local function draw_party(dt)
    local tidx = party_cursor();                                     -- (follows <stpt> / <stal> too)
    if cfg.party and not (C.GST and C.GST.noparty) and plain_window('YunaUI Party##yui_party', 'party_x', 'party_y') then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        local psc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.party_scale) or 1);
        local pushed = sized('main', 17 * psc);
        local cols = tonumber(cfg.party_cols) or 1;
        -- in a column: room for the buffs on the left (kept even when they're off, so the list never jumps)
        local bl = (cols == 1) and ((math.floor(20 * psc * (tonumber(cfg.buff_scale) or 1)) + 2) * 16 + 8) or 0;
        local top = 0;
        BUFFS.tick();
        local h, w;
        do                                                           -- Spine (the only party look): the YunaUI line and a card per member
            unsized(pushed);
            pushed = sized('chat', 17 * psc);
            local list = {};
            for i = 0, 5 do local m = member(i); if m then list[#list + 1] = { m, i }; end end
            ALLY.cur = 0;
            ALLY.hbtn, ALLY.tip = nil, nil;
            h, w = ALLY.spine(dl, list, x + 4, y + 4, psc, dt, tidx, 'PARTY', true);
            bl = 0;                                                  -- (the box is just the list; the buffs sit outside it)
            for name, r in pairs(ALLY.hbtn or {}) do                 -- the arrow and the anchor by PARTY
                -- (kept inside the list's own width: while the party slides in from the right they'd reach past it, the window
                --  would grow, and being kept on the screen it was pushed left - a party by the right edge crept left at every trust)
                imgui.SetCursorScreenPos({ math.max(x, math.min(r[1], x + w + 8 - r[3])), r[2] });
                if imgui.InvisibleButton('##yui_pb_' .. name, { r[3], r[4] }) then
                    if name == 'anchor' then cfg.ally_anchor = not cfg.ally_anchor; else cfg.party_hidden = not cfg.party_hidden; end
                    save();
                end
                ALLY.hbh[name] = imgui.IsItemHovered();
                if ALLY.hbh[name] then ALLY.tip = (name == 'anchor') and (cfg.ally_anchor and 'Free the alliances from the party' or 'Anchor the alliances to the party')
                    or (cfg.party_hidden and 'Bring the party back' or 'Slide the party away'); end
            end
        end
        unsized(pushed);
        if ALLY.tip then YUI_TIP(ALLY.tip); ALLY.tip = nil; end           -- (the icons' tip, at the normal size: after the list's big font)
        imgui.SetCursorScreenPos({ x, y });
        imgui.Dummy({ w + 8 + bl, math.max(10, h + 6 + top) });
        end_plain('party_x', 'party_y');
        if cfg.party_up then                                         -- PARTY > Grow upward: when the list's height changes, its top moves by as
            local sz = WATCH.size and WATCH.size.party_x;            --  much the other way - its bottom stays put, new members push it up
            local hn = sz and sz[2];
            if hn and ALLY.ph and math.abs(hn - ALLY.ph) > 0.5 and not imgui.IsMouseDown(0) then
                cfg.party_y = (tonumber(cfg.party_y) or 0) + (ALLY.ph - hn);
                WATCH.one = WATCH.one or {}; WATCH.one.party_x = 2;
                WATCH.later = true;
            end
            ALLY.ph = hn;
        else ALLY.ph = nil; end
        ALLY.keep('party_x', 'party_y');                              -- (always on the screen)
    elseif cfg.party then imgui.End(); imgui.PopStyleVar(2); end
    -- the two alliance parties, side by side
    if not cfg.alliance then return; end
    local p = AshitaCore:GetMemoryManager():GetParty();
    -- each alliance party in a window of its own, with its own size and place (the party list's look)
    local b1, b2 = 6, 12;                                            -- (which slots are the game's party 2 and 3: by their leaders, so the
    pcall(function()                                                 --  windows follow the game's order - the one <stal> goes through)
        local function has(first, sid)
            if sid == nil or sid == 0 then return false; end
            for i = first, first + 5 do if p:GetMemberIsActive(i) ~= 0 and p:GetMemberServerId(i) == sid then return true; end end
            return false;
        end
        local l2, l3 = p:GetAlliancePartyLeaderServerId2(), p:GetAlliancePartyLeaderServerId3();
        if has(12, l2) or has(6, l3) then b1, b2 = 12, 6; end
    end);
    if C.GST and C.GST.noally then return; end                       -- (the guide's Party slide: the party alone)
    for n, a in ipairs({ { b1, 'alliance_x', 'alliance_y', 'ally1_scale', 'ally1_cols' }, { b2, 'ally2_x', 'ally2_y', 'ally2_scale', 'ally2_cols' } }) do
        local any = PREVIEW.alliance;
        for i = a[1], a[1] + 5 do if p:GetMemberIsActive(i) ~= 0 then any = true; end end
        if any then
            local anch = cfg.ally_anchor and cfg.party and not (C.GST and C.GST.noparty);   -- anchored: stacked on the party, right edges lined up
            if anch then
                local ref = (n == 1) and 'party' or 'alliance';
                local rs = WATCH.size and WATCH.size[ref .. '_x'];
                local me = (WATCH.size and WATCH.size[a[2]]) or { 220, 150 };
                local rx, ry = tonumber(cfg[ref .. '_x']), tonumber(cfg[ref .. '_y']);
                if rs and rx and ry then
                    local ds = imgui.GetIO().DisplaySize;
                    local up = (tonumber(cfg.party_y) or 0) > ((ds and ds.y) or 1080) * 0.45;   -- (party low on screen: they go above it)
                    local nx = rx + rs[1] - me[1];
                    local pl, ml = ALLY.lx and ALLY.lx.PARTY, ALLY.lx and ALLY.lx[tostring(n)];
                    if pl and ml then nx = pl[1] - ml[2]; end                -- (its line on the party's line)
                    cfg[a[2]], cfg[a[3]] = ALLY.inside(nx, up and (ry - me[2] - 6) or (ry + rs[2] + 6), me[1], me[2]);
                    if not (WATCH.size and WATCH.size[a[2]] and ml) then cfg[a[2]], cfg[a[3]] = -4000, -4000; end   -- (its first frame: measured off screen, so it never jumps)
                end
            end
            if plain_window('YunaUI Alliance ' .. n .. '##yui_ally' .. n, a[2], a[3], anch) then
                local dl = imgui.GetWindowDrawList();
                local x, y = imgui.GetCursorScreenPos();
                local s = tonumber(cfg[a[4]]) or 0.75;                    -- (ALLIANCE > Alliance 1 / 2 size)
                local style = 'spine';                                   -- (the alliances are always in Spine)
                local pushed = sized((style == 'full') and 'main' or 'chat', 17 * (tonumber(cfg.scale) or 1) * s);   -- (the new looks: AvantGarde)
                local h, w;
                if style == 'full' then
                    h, w = draw_members(dl, x + 4, y + 4, a[1], 6, false, dt, tidx, s, tonumber(cfg[a[5]]) or 1);
                else
                    ALLY.hov[n] = imgui.IsWindowHovered();
                    h, w = ALLY.draw(dl, x + 4, y + 4, a[1], style, (tonumber(cfg.scale) or 1) * s, dt, tidx, n);
                end
                unsized(pushed);
                imgui.Dummy({ w + 12, math.max(10, h + 6) });
                end_plain(a[2], a[3]);
                if not anch then ALLY.keep(a[2], a[3]); end
            else imgui.End(); imgui.PopStyleVar(2); end
        end
    end
end

----------------------------------------------------------------------------------------------------
-- Chat: a minimal log, no frame. Dark at the bottom, see-through toward the top (the text fades the same way).
-- Shows only the newest lines, which fade away after a while; the mouse over it lights it all up again.
-- Mouse wheel over it scrolls back; drag it to move; drag the little corner at the top right to resize.
----------------------------------------------------------------------------------------------------
-- Two windows: 1 = general chat (with the channel buttons), 2 = combat log (only when "Split combat log" is on;
-- otherwise everything goes to 1).
local logs = { {}, {} };
local cw = { { scroll = 0, hv = 0 }, { scroll = 0, hv = 0 } };      -- per window: lines scrolled up, hover glow 0..1
local OUTLINE = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 1, 2 } };
local chat_lit_all = false;                                         -- YunaUI's window is open (or first setup): keep the chats lit
-- The chat's colours, one per kind of message (each can be changed in the CHAT tab; Linkshell is bright white)
local CHAT_COLS = {
    { 'say', 'Say', { 1, 1, 1 } }, { 'party', 'Party', { 0.50, 0.84, 1 } }, { 'ls', 'Linkshell', { 1, 1, 1 } },
    { 'ls2', 'Linkshell 2', { 0.62, 1, 0.55 } }, { 'shout', 'Shout', { 1, 0.45, 0.45 } }, { 'yell', 'Yell', { 1, 0.6, 0.45 } },
    { 'tell', 'Tell', { 0.86, 0.48, 1 } }, { 'emote', 'Emote', { 0.80, 0.65, 1 } }, { 'unity', 'Unity', { 0.95, 0.88, 0.55 } },
    { 'system', 'System / loot / exp', { 1, 0.95, 0.82 } }, { 'error', 'Errors', { 1, 0.35, 0.65 } },
    { 'combat', 'Combat (combat log)', { 0.80, 0.86, 0.95 } }, { 'roe', 'Records of Eminence', { 0.62, 0.92, 0.78 } },
    { 'addon', 'Addons and plugins ([Name] ...)', { 0.56, 0.84, 0.96 } },
    { 'other', 'Everything else', { 0.92, 0.92, 0.94 } },
};
local CHAT_DEF = {};
for _, c in ipairs(CHAT_COLS) do CHAT_DEF[c[1]] = c[3]; end
local function cat_of(m)
    if m == 1 or m == 9 then return 'say';
    elseif m == 2 or m == 10 then return 'shout';
    elseif m == 3 or m == 11 then return 'yell';
    elseif m == 4 or m == 12 then return 'tell';
    elseif m == 5 or m == 13 then return 'party';
    elseif m == 6 or m == 14 then return 'ls';
    elseif m == 213 or m == 214 then return 'ls2';
    elseif m == 7 or m == 15 then return 'emote';
    elseif m == 211 or m == 212 then return 'unity';
    elseif m == 123 or m == 157 then return 'error';
    elseif m == 121 or (m >= 127 and m <= 148) then return 'system';
    elseif m >= 20 and m <= 122 then return 'combat';
    end
    return 'other';
end
local function chat_col(cat)
    local c = cfg['col_' .. (cat or 'other')];
    if type(c) == 'table' and tonumber(c[1]) then return c; end
    return CHAT_DEF[cat or 'other'] or CHAT_DEF.other;
end-- Combat-log lines: battle messages, "can't do that" (122), skill-ups (129), exp and gil (131)
local function is_combat(m) return (m >= 20 and m <= 120) or m == 122 or m == 129 or m == 131; end
local SJIS = { ['\129\168'] = '>', ['\129\169'] = '<', ['\129\170'] = '^', ['\129\171'] = 'v', ['\129\64'] = ' ',
               ['\129\154'] = '*', ['\129\153'] = '*', ['\129\69'] = '-', ['\129\124'] = '-', ['\129\117'] = '"', ['\129\118'] = '"' };
function C.mob_name(s)                                               -- (a name without the marker symbol it may start with)
    if type(s) ~= 'string' then return s; end
    return (s:gsub('%?', ''):gsub('[\128-\255]', ''));
end
local function clean(s)
    s = s:gsub('\239\39', '{'):gsub('\239%(', '}');                 -- auto-translate brackets
    s = s:gsub('}%(', '}');                                         -- a stray "(" the game leaves after some phrases
    s = s:gsub('[\30\31\127].', '');                                -- colour / control codes (2 bytes each)
    s = s:gsub('[\129-\159\224-\252].', function(c) return SJIS[c] or ''; end);    -- Shift-JIS symbols
    s = s:gsub('[%z\1-\6\8\9\11-\31]', '');
    s = ((' ' .. s):gsub('([%s>])%?(%u)', '%1%2')):sub(2);           -- (a monster's marker symbol, as "?": "The ?Banshee")
    -- auto-translate phrases: their brackets become marks (\1 open, \2 close) drawn as the game's green / red icons
    s = s:gsub('{([^{}\n]-)}', '\1%1\2');
    return s;
end
-- The tabs under the general chat: each shows only its channel; All shows everything. A dot marks
-- a tab with messages you haven't looked at yet.
local CHANNELS = {
    { 'All',   nil,                 { 0.85, 0.87, 0.95 } },
    { 'Say',   { 1, 9, 7, 15 },     { 1, 1, 1 } },
    { 'Party', { 5, 13 },           { 0.50, 0.84, 1 } },
    { 'LS',    { 6, 14 },           { 0.40, 1, 0.82 } },
    { 'LS2',   { 213, 214 },        { 0.62, 1, 0.55 } },
    { 'Shout', { 2, 10 },           { 1, 0.45, 0.45 } },
    { 'Yell',  { 3, 11 },           { 1, 0.6, 0.45 } },
    { 'Tell',  { 4, 12 },           { 0.86, 0.48, 1 } },
    { 'RoE',   { 300 },             { 0.62, 0.92, 0.78 } },          -- (Records of Eminence: YunaUI's own mode 300, see C.is_roe)
};
C.CHAT_COMBAT = #CHANNELS + 1;                                       -- (the Combat tab: after the channels)
-- CHAT > Tabs: which tabs show under the chat (cfg.chat_tabs_on[name] = false hides one; All always shows)
function C.tab_on(name) return name == 'All' or type(cfg.chat_tabs_on) ~= 'table' or cfg.chat_tabs_on[name] ~= false; end
local TAB_OF = {};                                                  -- chat mode -> tab number
for ti, ch in ipairs(CHANNELS) do if ch[2] then for _, m in ipairs(ch[2]) do TAB_OF[m] = ti; end end end
local unread = {};                                                  -- tab number -> true
local function chat_seen_new(mode)
    local ti = TAB_OF[mode];
    local cur = tonumber(cfg.chat_tab) or 1;
    if ti and ti ~= cur then unread[ti] = true; end
end
-- Chat history: what people say (say, party, linkshells, tells, shouts...) is kept apart from the battle / system
-- spam, so a long fight never pushes your conversations out: the last 3000 conversation lines and 2000 others stay.
-- CHAT > Save chat logs also writes every line to Ashita\chatlogs\<name>_<date>.txt as it comes in, and
-- SAVE THE CHAT NOW writes everything still in the chat to a file of its own.
local CHATLOG = { TALK = { say = true, party = true, ls = true, ls2 = true, shout = true, yell = true, tell = true, emote = true, unity = true },
    CAP_TALK = 3000, CAP_OTHER = 2000 };
function CHATLOG.add(log, e)
    local talk = CHATLOG.TALK[e.cat] == true;
    e.talk = talk;
    log[#log + 1] = e;
    log.n_talk, log.n_other = (log.n_talk or 0) + (talk and 1 or 0), (log.n_other or 0) + (talk and 0 or 1);
    local cap = talk and CHATLOG.CAP_TALK or CHATLOG.CAP_OTHER;
    if (talk and log.n_talk or log.n_other) > cap then             -- too many of this kind: drop its oldest line
        for i = 1, #log do
            if (log[i].talk == true) == talk then
                table.remove(log, i);
                if talk then log.n_talk = log.n_talk - 1; else log.n_other = log.n_other - 1; end
                break;
            end
        end
    end
    pcall(CHATLOG.write, e);
end
function CHATLOG.dir()
    local d = AshitaCore:GetInstallPath():gsub('[\\/]+$', '') .. '\\chatlogs\\';
    pcall(function() if ashita.fs and ashita.fs.create_directory and not ashita.fs.exists(d) then ashita.fs.create_directory(d); end end);
    return d;
end
function CHATLOG.who()
    local n = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0) or '';
    n = n:gsub('[^%w]', '');
    return (n ~= '') and n or 'chat';
end
function CHATLOG.label(cat)
    for _, c in ipairs(CHAT_COLS) do if c[1] == cat then return c[2]:gsub(' %(.*%)', ''):gsub(' /.*', ''); end end
    return 'Other';
end
function CHATLOG.line(e)
    local txt = (e.raw or e.text or ''):gsub('\1', '{'):gsub('\2', '}');
    return string.format('%s [%s] %s\n', os.date('[%Y-%m-%d %H:%M:%S]', e.ts or os.time()), CHATLOG.label(e.cat), txt);
end
function CHATLOG.write(e)
    if not cfg.chat_save then
        if CHATLOG.f then CHATLOG.f:close(); CHATLOG.f, CHATLOG.path = nil, nil; end
        return;
    end
    local path = CHATLOG.dir() .. CHATLOG.who() .. '_' .. os.date('%Y-%m-%d', e.ts or os.time()) .. '.txt';
    if CHATLOG.path ~= path then                                    -- (a new day, or a new character: a new file)
        if CHATLOG.f then CHATLOG.f:close(); end
        CHATLOG.f, CHATLOG.path = io.open(path, 'a'), path;
    end
    if CHATLOG.f then CHATLOG.f:write(CHATLOG.line(e)); CHATLOG.f:flush(); end
end
function CHATLOG.save_now()
    local all = {};
    for _, lg in ipairs(logs) do for _, e in ipairs(lg) do all[#all + 1] = e; end end
    table.sort(all, function(a, b) return (a.ts or 0) < (b.ts or 0); end);
    local path = CHATLOG.dir() .. CHATLOG.who() .. '_' .. os.date('%Y-%m-%d_%H-%M-%S') .. '_saved.txt';
    local f = io.open(path, 'w');
    if f == nil then CHATLOG.msg = 'Could not write ' .. path; return; end
    for _, e in ipairs(all) do f:write(CHATLOG.line(e)); end
    f:close();
    CHATLOG.msg = string.format('Saved %d lines to %s', #all, path);
end
-- CHAT > Combat feed: a spell or an ability is ONE line that grows as it happens - "Floona > Stoneskin > Floona", then
-- a tick when it lands, the damage, the HP healed or "miss" - instead of "starts casting...", "casts...", "gains the
-- effect of..." each on a line of its own. Returns 'new' (a feed line was added), 'merged' (an older one grew) or nil
-- (not a feed line: added as usual).
C.FEED = {};
function C.ts_text(ts)                                              -- "[18:24] ", "[18:24:07] ", "[6:24pm] ", "[6:24:07 PM] "...
    local t = os.date('*t', ts or os.time());
    local h, suf = t.hour, '';
    if cfg.chat_time_12 then
        suf = (h < 12) and 'am' or 'pm';
        if cfg.chat_time_case == 'upper' then suf = suf:upper(); end
        if cfg.chat_time_sec then suf = ' ' .. suf; end
        h = h % 12; if h == 0 then h = 12; end
    end
    local str = string.format(cfg.chat_time_12 and '%d:%02d' or '%02d:%02d', h, t.min);
    if cfg.chat_time_sec then str = str .. string.format(':%02d', t.sec); end
    return '[' .. str .. suf .. '] ';
end
function C.ts_col()
    local c = cfg.chat_time_col;
    if type(c) == 'table' and tonumber(c[1]) then return { c[1], c[2], c[3] }; end
    return { 0.62, 0.60, 0.68 };
end
function C.ts_rebuild()                                              -- (the options changed: every line's time written again)
    for _, lg in ipairs(logs) do
        for _, e in ipairs(lg) do
            if e.ts and e.raw then
                local pre = cfg.chat_time and C.ts_text(e.ts) or '';
                if e.feed then e.tpre = (pre ~= '') and pre or nil; e.text = C.feed_text(e);
                else e.text, e.tslen = pre .. e.raw, #pre; end
                e.lines = nil;
            end
        end
    end
end
function C.feed_text(e)                                              -- (its plain text: the saved log, the line's width)
    local f = e.feed;
    if f.kind == 'melee' then                                        -- (a melee round: hits, their total, crits and misses)
        local t = (e.tpre or '') .. f.actor .. ' > ' .. f.target .. '  ' .. f.hits .. ((f.hits == 1) and ' hit' or ' hits');
        if f.dmg > 0 then local ds, k = tostring(f.dmg); repeat ds, k = ds:gsub('^(%d+)(%d%d%d)', '%1,%2'); until k == 0; t = t .. '  ' .. ds; end   -- (1,245)
        local x = {};
        if f.crit > 0 then x[#x + 1] = f.crit .. ' crit'; end
        if f.miss > 0 then x[#x + 1] = f.miss .. ' miss'; end
        if #x > 0 then t = t .. '  (' .. table.concat(x, ', ') .. ')'; end
        return t;
    end
    local t = (e.tpre or '') .. f.actor .. ' > ' .. f.act .. (f.state == 'cast' and '...' or '');
    if f.target then t = t .. ' > ' .. f.target; end
    local none = {};
    for _, r in ipairs(f.res) do
        if r.none then none[#none + 1] = r.who;
        elseif r.dmg then t = t .. '  ' .. r.who .. ' ' .. r.dmg;
        elseif r.heal then t = t .. '  ' .. r.who .. ' +' .. r.heal;
        elseif r.miss then t = t .. '  ' .. r.who .. ' miss';
        else t = t .. '  ok ' .. ((r.who ~= f.target) and r.who or ''); end
    end
    if #none > 0 then t = t .. '  no effect on ' .. table.concat(none, ', ') .. (f.more and (' +' .. f.more) or ''); end
    return t;
end
function C.feed_take(log, line, mode, only)
    -- only: a line the COMBAT LOG filters hide - it may still finish a feed line already showing (its "casts", its
    -- damage), never start one; a hidden spell's own results then don't land on the line before it
    if cfg.chat_feed == false then return nil; end
    local F = C.FEED;
    local now = os.clock();
    local sl = line:gsub('[\1\2]', '');
    local function new(actor, act, target, kind, state)
        if only then F.last = nil; return nil; end
        local e = { raw = line, cat = cat_of(mode), t = now, t0 = now, flash = now, ts = os.time(), mode = mode,
            tpre = cfg.chat_time and C.ts_text(os.time()) or nil,
            feed = { actor = actor, act = act, target = target, kind = kind, state = state, res = {} } };
        e.text = C.feed_text(e);
        CHATLOG.add(log, e);
        F.last, F.last_t = e, now;
        return 'new';
    end
    local function grow(e)
        e.t, e.flash = now, now;
        e.text, e.lines = C.feed_text(e), nil;
        F.last, F.last_t = e, now;
        pcall(CHATLOG.write, { raw = line, cat = cat_of(mode), ts = os.time() });
        return 'merged';
    end
    do                                                               -- "X's Poisona has no effect on Y": onto that spell's line
        local na, nsp, nt = sl:match("^(.-)'s (.-) has no effect on (.-)%.$");
        if na then
            local L = F.last;
            if not (L and L.feed and L.feed.kind ~= 'melee' and L.feed.actor == na and L.feed.act == nsp and now - (F.last_t or 0) < 2.5) then
                if only then return nil; end
                new(na, nsp, nil, 'magic', 'done');
                L = F.last;
            end
            if #L.feed.res < 12 then L.feed.res[#L.feed.res + 1] = { who = nt, none = true };
            else L.feed.more = (L.feed.more or 0) + 1; end
            return grow(L);
        end
    end
    if cfg.chat_rounds ~= false then                                 -- CHAT > Melee rounds: one attack round, one line
        local ma, mt, md = sl:match('^(.-) hits (.-) for (%d+) points? of damage%.$');
        local crit, miss = false, false;
        if ma == nil and F.crit and now - F.crit.t < 0.3 then        -- (a critical hit: its damage comes on the next line)
            mt, md = sl:match('^(.-) takes (%d+) points? of damage%.$');
            if mt then ma, crit = F.crit.who, true; end
        end
        F.crit = nil;
        if ma == nil then
            local who = sl:match('^(.-) scores a critical hit!$');
            if who then F.crit = { who = who, t = now }; return 'merged'; end
        end
        if ma == nil then
            local L = F.last;                                        -- (a miss right after an ability is that ability's)
            local wa, wt = sl:match('^(.-) misses (.-)%.$');
            if wa and not (L and L.feed and L.feed.state == 'done' and L.feed.actor == wa and now - (F.last_t or 0) < 2.5) then ma, mt, miss = wa, wt, true; end
        end
        if ma then
            local M = F.mel;
            if not (M and M.feed.actor == ma and M.feed.target == mt and now - (F.mel_t or 0) < 1.2) then
                if only then return nil; end
                M = { raw = line, cat = cat_of(mode), t = now, t0 = now, flash = now, ts = os.time(), mode = mode,
                    tpre = cfg.chat_time and C.ts_text(os.time()) or nil,
                    feed = { actor = ma, target = mt, kind = 'melee', state = 'melee', res = {}, hits = 0, dmg = 0, crit = 0, miss = 0 } };
                CHATLOG.add(log, M);
                F.mel = M;
                F.mel_t = now;
                M.feed.hits, M.feed.dmg = (miss and 0 or 1), tonumber(md) or 0;
                M.feed.crit, M.feed.miss = crit and 1 or 0, miss and 1 or 0;
                M.text = C.feed_text(M);
                return 'new';
            end
            if not miss then M.feed.hits = M.feed.hits + 1; M.feed.dmg = M.feed.dmg + (tonumber(md) or 0); end
            if crit then M.feed.crit = M.feed.crit + 1; end
            if miss then M.feed.miss = M.feed.miss + 1; end
            F.mel_t = now;
            M.t, M.flash = now, now;
            M.text, M.lines = C.feed_text(M), nil;
            pcall(CHATLOG.write, { raw = line, cat = cat_of(mode), ts = os.time() });
            return 'merged';
        end
    end
    local a, sp, tg = sl:match('^(.-) starts casting (.-) on (.-)%.$');
    if a then return new(a, sp, tg, 'magic', 'cast'); end
    a, sp = sl:match('^(.-) starts casting (.-)%.$');
    if a then return new(a, sp, nil, 'magic', 'cast'); end
    a, sp = sl:match('^(.-) casts (.-)%.$');
    if a then
        for i = #log, math.max(1, #log - 40), -1 do                  -- (its "starts casting" line, if it's recent)
            local e = log[i];
            if e.feed and e.feed.state == 'cast' and e.feed.actor == a and e.feed.act == sp and now - (e.t0 or 0) < 30 then
                e.feed.state = 'done';
                return grow(e);
            end
        end
        return new(a, sp, nil, 'magic', 'done');
    end
    a, sp = sl:match('^(.-) uses (.-)%.$');
    if a then return new(a, sp, nil, 'ability', 'done'); end
    local L = F.last;                                                -- the results: onto the spell / ability that just went off
    if L and L.feed and L.feed.state == 'done' and now - (F.last_t or 0) < 2.5 then
        local r = nil;
        local w, x = sl:match('^(.-) gains the effect of (.-)%.$');
        if w then r = { who = w }; end
        if not r then w = sl:match('^(.-) receives the effect of .-%.$'); if w then r = { who = w }; end end
        if not r then w, x = sl:match('^(.-) takes (%d+) points? of damage%.$'); if w then r = { who = w, dmg = x }; end end
        if not r then w, x = sl:match('^(.-) takes (%d+) damage%.$'); if w then r = { who = w, dmg = x }; end end
        if not r then w, x = sl:match('^(.-) recovers (%d+) HP%.$'); if w then r = { who = w, heal = x }; end end
        if not r then w = sl:match('^(.-) resists the spell%.$') or sl:match('^.- misses (.-)%.$'); if w then r = { who = w, miss = true }; end end
        if r then
            if #L.feed.res < 12 then L.feed.res[#L.feed.res + 1] = r; end
            return grow(L);
        end
    end
    return nil;
end
-- CHAT > Speech bubbles. Who said a line, and what: "Name : text" (say, shout, yell), "Name>> text"
-- (a tell to you), "(Name) text" (party), "[1]<Name> text" (linkshells).
function C.speaker(mode, line)
    local sl = line:gsub('[\1\2]', '');
    if mode == 12 then return sl:match('^(%S+)>> ?(.*)$'); end
    if mode == 5 or mode == 13 then return sl:match('^%((%S+)%) (.*)$'); end
    if mode == 6 or mode == 14 or mode == 213 or mode == 214 then return sl:match('^%[?%d?%]?<(%S+)> (.*)$'); end
    if mode == 1 or mode == 9 or mode == 2 or mode == 10 or mode == 3 or mode == 11 then return sl:match('^(%S+) : (.*)$'); end
    return nil;
end
function C.atext(dl, x, y, str, col)                             -- (text with a dark edge that fades with it)
    local oc = U4(0, 0, 0, 0.8 * (col[4] or 1));
    for _, o in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do DL.T(dl, x + o[1], y + o[2], oc, str); end
    DL.T(dl, x, y, u32(col), str);
end
C.BUBS = {};
function C.me()
    local ok, n = pcall(function() return AshitaCore:GetMemoryManager():GetParty():GetMemberName(0); end);
    return ok and n or '';
end
function C.chat_pop(mode, line)                                      -- (from chat_add: say / party -> a bubble)
    local who, msg = C.speaker(mode, line);
    if who == nil or msg == nil or msg == '' then return; end
    local now = os.clock();
    if cfg.chat_bubbles ~= false and (mode == 1 or mode == 9 or mode == 5 or mode == 13) then
        local idx = nil;
        pcall(function()                                             -- (who said it, nearby: their entity)
            local ent = AshitaCore:GetMemoryManager():GetEntity();
            for i = 0, 2303 do
                if ent:GetRawEntity(i) ~= nil and ent:GetName(i) == who then idx = i; break; end
            end
        end);
        if idx then C.BUBS[who] = { idx = idx, msg = msg, cat = cat_of(mode), t = now }; end
    end
end
-- A point in the world on the screen (nil when behind the camera): the game's own view and projection
function C.w2s(wx, wy, wz)
    local dev = d3d.get_device();
    local _, v = dev:GetTransform(ffi.C.D3DTS_VIEW);
    local _, pj = dev:GetTransform(ffi.C.D3DTS_PROJECTION);
    if v == nil or pj == nil then return nil; end
    local x = wx * v._11 + wy * v._21 + wz * v._31 + v._41;
    local y = wx * v._12 + wy * v._22 + wz * v._32 + v._42;
    local z = wx * v._13 + wy * v._23 + wz * v._33 + v._43;
    local cx = x * pj._11 + y * pj._21 + z * pj._31 + pj._41;
    local cy = x * pj._12 + y * pj._22 + z * pj._32 + pj._42;
    local cw = x * pj._14 + y * pj._24 + z * pj._34 + pj._44;
    if cw < 0.1 then return nil; end
    local ds = imgui.GetIO().DisplaySize;
    return (cx / cw + 1) * 0.5 * ds.x, (1 - cy / cw) * 0.5 * ds.y;
end
-- Text broken into rows of at most maxw (at most 3 rows; the last one cut with "...")
function C.pop_rows(msg, maxw)
    local rows, cur = {}, '';
    local words = {};
    for word in msg:gmatch('%S+') do                                 -- (a word too long for a row - "aaaaaaaa..." - is cut into pieces that fit)
        while #word > 1 and imgui.CalcTextSize(word) > maxw do
            local k = #word - 1;
            while k > 1 and imgui.CalcTextSize(word:sub(1, k)) > maxw do k = k - 1; end
            words[#words + 1] = word:sub(1, k);
            word = word:sub(k + 1);
        end
        words[#words + 1] = word;
    end
    for _, word in ipairs(words) do
        local try = (cur == '') and word or (cur .. ' ' .. word);
        if cur ~= '' and imgui.CalcTextSize(try) > maxw then rows[#rows + 1] = cur; cur = word; else cur = try; end
    end
    if cur ~= '' then rows[#rows + 1] = cur; end
    if #rows > 3 then
        rows = { rows[1], rows[2], rows[3] };
        while #rows[3] > 1 and imgui.CalcTextSize(rows[3] .. '...') > maxw do rows[3] = rows[3]:sub(1, -2); end
        rows[3] = rows[3] .. '...';
    end
    return rows;
end
-- BARS > YOUR BARS > Where: 'head' / 'both' - thin HP, MP and TP bars over your own head, no numbers. TP in three
-- pieces (1000 each), dim while filling, gold when full (a gold piece = a weapon skill ready), a flash each time one
-- fills. Low HP breathes. They follow you smoothly; hidden in cutscenes and under the big map.
C.HB = { x = nil, y = nil, hp = nil, mp = nil, tp = nil, segs = 0, flash = -9 };
function C.head_bars_on()                                           -- (over your head: Hex link mode only - Normal mode has the fixed bars)
    if cfg.target_fx ~= 'link' then return false; end
    local w = cfg.head_bars or 'fixed';
    return w == 'head' or w == 'both';
end
-- each race's height over the ground for the bars (yalms): Hume m/f, Elvaan m/f, Tarutaru m/f, Mithra, Galka
C.HB_RACE = { [1] = 2.25, [2] = 2.15, [3] = 2.45, [4] = 2.35, [5] = 1.35, [6] = 1.35, [7] = 2.1, [8] = 2.5 };
-- VanaCore's own setting [graphics] nameplates.hideown (/vana > Options > Nameplates > Hide own nameplate): on while the
-- bars are over your head (your name and stars would sit on them), put back as it was when they're not. Only where
-- VanaCore lets addons reach its settings (vana.config); otherwise BARS says where to turn it on by hand.
function C.vana_cfg()
    local v = rawget(_G, 'vana');
    if type(v) == 'table' and type(v.config) == 'table' and type(v.config.set) == 'function' and type(v.config.get) == 'function' then return v.config; end
    return nil;
end
-- CHAT > hide the game's chat / typing bar through VanaCore's own settings ([client] chat.hide, chat2.hide, input.hide):
-- set while the options are on, put back as they were when they're off. true when VanaCore does it (then YunaUI leaves
-- the game's windows alone: no memory written into them).
C.VCH_KEYS = { 'chat.hide', 'chat2.hide', 'input.hide' };
function C.vchat_sync()
    local vc = C.vana_cfg();
    if vc == nil then return false; end
    local now = os.clock();
    local want = { (cfg.chat and cfg.hide_game_chat) and true or false, (cfg.chat and cfg.hide_game_chat) and true or false, (cfg.chat and cfg.hide_game_input) and true or false };
    local key = tostring(want[1]) .. tostring(want[3]);
    if key == C.VCH_last then return true; end
    if C.VCH_at and now < C.VCH_at then return true; end
    C.VCH_at = now + 1;
    local ok = pcall(function()
        cfg.vch_prev = cfg.vch_prev or {};
        for i, k in ipairs(C.VCH_KEYS) do
            if want[i] then
                if cfg.vch_prev[k] == nil then local v = vc.get('client', k); cfg.vch_prev[k] = (v ~= nil) and tostring(v) or ''; end
                vc.set('client', k, '1');
            elseif cfg.vch_prev[k] ~= nil then                       -- (off: as it was before YunaUI set it)
                local v = cfg.vch_prev[k];
                vc.set('client', k, (v ~= '' and v ~= '0') and v or '0');
                cfg.vch_prev[k] = nil;
            end
        end
    end);
    if not ok then return false; end
    C.VCH_last = key;
    pcall(save);
    return true;
end
function C.hideown_sync()
    local on = C.head_bars_on();
    if C.HB.own == on then return; end
    C.HB.own = on;
    local vc = C.vana_cfg();
    if vc == nil then return; end
    pcall(function()
        local lp = vc.get('yunalink', 'hideown.prev');               -- (how it was, as the old helper yunalink kept it: taken over)
        if lp ~= nil then
            if cfg.hideown_prev == nil then cfg.hideown_prev = tostring(lp); end
            vc.set('yunalink', 'hideown.prev', nil);
        end
        if on then
            if cfg.hideown_prev == nil then cfg.hideown_prev = tostring(vc.get('graphics', 'nameplates.hideown') or '0'); end
            vc.set('graphics', 'nameplates.hideown', '1');
        elseif cfg.hideown_prev ~= nil then
            vc.set('graphics', 'nameplates.hideown', (cfg.hideown_prev ~= '0' and cfg.hideown_prev ~= '') and cfg.hideown_prev or nil);
            cfg.hideown_prev = nil;
        elseif not cfg.hideown_fix1 then                             -- (once: a name left hidden with no note of how it was - Normal mode
            vc.set('graphics', 'nameplates.hideown', nil);           --  has no bars over your head, so your name shows again)
        end
        if not on then cfg.hideown_fix1 = true; end
        pcall(save);
    end);
end
function C.head_bars()
    pcall(C.hideown_sync);                                           -- (your own name over your head: hidden while the bars are there)
    if not C.head_bars_on() or YUI_MAPCOVER or (YMAP and YMAP.big) then C.HB.x = nil; return; end
    local ds = imgui.GetIO().DisplaySize;
    imgui.SetNextWindowPos({ 0, 0 }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ ds.x, ds.y }, ImGuiCond_Always);
    local fl = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoInputs,
        ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoBringToFrontOnFocus, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoScrollbar);
    if imgui.Begin('##yui_headbars', { true }, fl) then
        local ok, err = pcall(C.head_bars_);
        if not ok and YUI_ERRLOG then YUI_ERRLOG('headbars', err); end
    end
    imgui.End();
end
-- Hex link: your TP as a slim bar hung under the MP bar (in place of the three dots) - straight top and bottom, its left
-- and right sides slanted in (a trapezoid); silver while it builds, gold once a weapon skill is ready, a notch at each 1000
function C.head_tp(dl, H, x0, y0, W, hh, mh, g, sc, tp, ua, now)
    if ua <= 0.01 then return; end
    local th_ = math.max(4, math.floor(5 * sc + 0.5));
    local tw_ = math.floor(W * 0.6);
    local tx, ty = math.floor(x0 + (W - tw_) / 2), y0 + hh + g + mh + math.max(1, math.floor(1.5 * sc));
    local sl = th_;                                                  -- (how far each side slants in)
    local function trap(x1, x2, col)                                 -- (the shape between x1 and x2, cut to the slanted sides)
        local l0, r0 = tx, tx + tw_;                                 -- (top edge)
        local l1, r1 = tx + sl, tx + tw_ - sl;                       -- (bottom edge)
        local function cut(x, lo, hi) return math.max(lo, math.min(hi, x)); end
        local p_ = { { cut(x1, l0, r0), ty }, { cut(x2, l0, r0), ty }, { cut(x2, l1, r1), ty + th_ }, { cut(x1, l1, r1), ty + th_ } };
        if p_[2][1] - p_[1][1] < 0.5 and p_[3][1] - p_[4][1] < 0.5 then return; end
        pcall(function() dl:AddConvexPolyFilled(p_, col); end);
    end
    local ready = tp >= 1000;
    local f = math.max(0, math.min(1, (H.tp or tp) / 3000));
    local c = { 0.86, 0.87, 0.95 };
    if ready then
        local pu = 0.5 + 0.5 * math.sin(now * 3.2);
        c = { C.GOLDH[1] + (C.GOLDH2[1] - C.GOLDH[1]) * pu * 0.5, C.GOLDH[2] + (C.GOLDH2[2] - C.GOLDH[2]) * pu * 0.5, C.GOLDH[3] + (C.GOLDH2[3] - C.GOLDH[3]) * pu * 0.5 };
    end
    local L, R = tx - 1, tx + tw_ + 1;                               -- (a dark track, a pixel bigger)
    pcall(function() dl:AddConvexPolyFilled({ { L, ty - 1 }, { R, ty - 1 }, { R - sl - 0.5, ty + th_ + 1 }, { L + sl + 0.5, ty + th_ + 1 } }, U4(0, 0, 0, 0.6 * ua)); end);
    trap(tx, tx + tw_, U4(0.10, 0.10, 0.16, 0.75 * ua));
    if f > 0 then
        local fx = tx + tw_ * f;
        trap(tx, fx, U4(c[1], c[2], c[3], ua));
        DL.L(dl, tx + 1, ty + 0.5, math.min(fx, tx + tw_ - 1), ty + 0.5, U4(1, 1, 1, 0.45 * ua), 1);   -- (light on its top edge)
    end
    for k = 1, 2 do                                                  -- (where each 1000 TP ends: a fine dark notch)
        local nx = math.floor(tx + tw_ * k / 3 + 0.5);
        DL.L(dl, nx, ty, nx, ty + th_, U4(0, 0, 0, 0.6 * ua), 1);
    end
    local fl = math.max(0, 1 - (now - (H.flash or -99)) / 0.7);      -- (a piece just filled: a flash over it)
    if fl > 0 and f > 0 then trap(tx, tx + tw_ * f, U4(1, 1, 1, 0.55 * fl * ua)); end
end
-- BARS > TP sound: an energy surge as your TP reaches 1000, 2000 and 3000 (sounds/tp1-3.wav, made for YunaUI) - each
-- one stronger. Played from memory by Windows (winmm PlaySound), at TP sound volume: the samples scaled once per volume.
C.SND = { last = 0, bufs = {}, raw = {}, keep = {} };
pcall(ffi.cdef, 'int __stdcall PlaySoundA(const char* pszSound, void* hmod, uint32_t fdwSound);');
function C.snd_play(name)
    local S = C.SND;
    if S.winmm == nil then local ok, lib = pcall(ffi.load, 'winmm'); S.winmm = ok and lib or false; end
    if not S.winmm then return; end
    local vol = math.max(0, math.min(1.5, tonumber(cfg.tp_sound_vol) or 0.6));
    if vol <= 0.001 then return; end
    local key = name .. '@' .. string.format('%.2f', vol);
    local buf = S.bufs[key];
    if buf == nil then
        local raw = S.raw[name];
        if raw == nil then
            local f = io.open(addon.path .. '/sounds/' .. name .. '.wav', 'rb');
            if not f then S.raw[name] = false; return; end
            raw = f:read('*a'); f:close();
            S.raw[name] = raw;
        end
        if not raw or #raw < 48 then return; end
        buf = ffi.new('uint8_t[?]', #raw);
        ffi.copy(buf, raw, #raw);
        local n = math.floor((#raw - 44) / 2);                       -- (16-bit samples after the 44-byte header)
        local smp = ffi.cast('int16_t*', buf + 44);
        for i = 0, n - 1 do
            local v = smp[i] * vol;
            if v > 32767 then v = 32767; elseif v < -32768 then v = -32768; end
            smp[i] = v;
        end
        S.bufs[key] = buf;
    end
    S.keep[#S.keep + 1] = buf;                                       -- (kept alive while Windows plays it)
    if #S.keep > 4 then table.remove(S.keep, 1); end
    pcall(function() S.winmm.PlaySoundA(ffi.cast('const char*', buf), nil, 0x0001 + 0x0002 + 0x0004); end);   -- (async, no default beep, from memory)
end
function C.tp_sound()
    local tp = 0;
    pcall(function() tp = AshitaCore:GetMemoryManager():GetParty():GetMemberTP(0) or 0; end);
    local tier = math.min(3, math.floor(tp / 1000));
    local S = C.SND;
    if not S.init then S.init = true; S.last = tier; return; end     -- (a reload with TP already up: no chime)
    if tier > S.last and cfg.tp_sound ~= false and YUI_HEX then C.snd_play('tp' .. tier); end   -- (Hex link mode only)
    S.last = tier;
end
function C.head_bars_()                                             -- (the bars themselves, inside that window)
    local mm = AshitaCore:GetMemoryManager();
    local party, ent = mm:GetParty(), mm:GetEntity();
    local me = party:GetMemberTargetIndex(0) or 0;
    if me == 0 or ent:GetRawEntity(me) == nil then C.HB.x = nil; return; end
    local okst, st_ = pcall(function() return ent:GetStatus(me); end);
    if okst and st_ == 4 then C.HB.x = nil; return; end               -- (in a cutscene)
    local ap = ent:GetActorPointer(me);
    if ap == nil or ap == 0 then return; end
    local px, py, pz = ashita.memory.read_float(ap + 0x678), ashita.memory.read_float(ap + 0x680), ashita.memory.read_float(ap + 0x67C);
    local race = 0;                                                  -- (how tall your character is: the bars just over its head, any race)
    pcall(function() race = ent:GetRace(me) or 0; end);
    if race == 0 then pcall(function() race = mm:GetPlayer():GetRace() or 0; end); end
    local tall = C.HB_RACE[race] or 2.45;
    local riding = okst and (st_ == 5 or st_ == 85);                 -- (on a chocobo or a mount: you sit about a yalm higher - eased, so it glides)
    C.HB.ride = (C.HB.ride or 0) + (((riding and 1) or 0) - (C.HB.ride or 0)) * math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 6);
    tall = tall + 1.05 * C.HB.ride;
    local sx, sy = C.w2s(px, pz - tall, py);                         -- (a little over the head, not on it)
    if sx == nil then C.HB.x = nil; return; end
    local SW, SH = C.screen();
    local sc = 0.85 * math.max(0.6, SH / 1080) * math.max(0.5, math.min(2.5, tonumber(cfg.head_bars_scale) or 1));   -- (0.85: a touch smaller at 1x)
    sy = sy - 24 * sc + (tonumber(cfg.head_bars_y) or 0) * sc;      -- (BARS > Head bars height: up or down from there)
    do                                                               -- (you target yourself: the game's arrow shows over your head - the bars
        local self_ = (target_index() or 0) == me;                   --  glide up out of its way, and back down after)
        local dt_ = imgui.GetIO().DeltaTime or 0.016;
        C.HB.lift = (C.HB.lift or 0) + (((self_ and 1) or 0) - (C.HB.lift or 0)) * math.min(1, dt_ * 10);
        sy = sy - C.HB.lift * 22 * sc;
    end
    if C.GST and C.GST.hb then sx, sy = C.GST.hb[1], C.GST.hb[2]; end   -- (the guide's slide: in its picture)
    local dt = imgui.GetIO().DeltaTime or 0.016;
    local H = C.HB;
    if H.x == nil and os.clock() - (H.seen or -99) > 1.5 then H.t0 = os.clock(); end   -- (back after a while: the entrance plays)
    H.seen = os.clock();
    if H.x == nil or math.abs(sx - H.x) > 120 or math.abs(sy - H.y) > 120 then H.x, H.y = sx, sy;   -- (a jump: straight there)
    else local k = math.min(1, dt * 16); H.x, H.y = H.x + (sx - H.x) * k, H.y + (sy - H.y) * k; end
    local hpp = (party:GetMemberHPPercent(0) or 0) / 100;
    local mpp = (party:GetMemberMPPercent(0) or 0) / 100;
    local tp = party:GetMemberTP(0) or 0;
    if YUI_FAKE_TP then tp = YUI_FAKE_TP; end                        -- (the guide's slide: a pretend TP filling up)
    local e = math.min(1, dt * 8);                                   -- (the bars ease to their values - down quickly, up slower: a heal's light
    local eu = math.min(1, dt * 2.5);                                --  shows ahead and the bar catches up)
    H.hp = H.hp and (H.hp + (hpp - H.hp) * ((hpp > H.hp) and eu or e)) or hpp;
    H.mp = H.mp and (H.mp + (mpp - H.mp) * ((mpp > H.mp) and eu or e)) or mpp;
    local function trail(cur, kl, kc, kt)                            -- (what was just lost: held half a second, then it drains)
        if H[kl] == nil or cur >= H[kl] then H[kl], H[kc], H[kt] = cur, cur, os.clock(); return; end
        if cur < (H[kc] or cur) - 0.0001 then H[kt] = os.clock(); end
        H[kc] = cur;
        if os.clock() - (H[kt] or 0) > 0.5 then H[kl] = math.max(cur, H[kl] - dt * 0.35); end
    end
    trail(hpp, 'hl', 'hlc', 'hlt');
    trail(mpp, 'ml', 'mlc', 'mlt');
    H.tp = H.tp and (H.tp + (tp - H.tp) * math.min(1, dt * 12)) or tp;
    local segs = math.floor(tp / 1000);
    local now = os.clock();
    if segs > H.segs then H.flash = now; end                         -- (a piece just filled: a flash)
    H.segs = segs;
    -- two thin straight bars, HP over MP, and the TP as three dots under them (a little bigger than the bars are thick)
    local dl = imgui.GetBackgroundDrawList();
    local W = math.floor(110 * sc);
    local hmir = cfg.target_fx == 'link';                            -- (Hex link: the bars right over the head, the numbers mirrored to their left)
    local x0, y0 = math.floor(H.x - W / 2 - (hmir and 0 or (H.colw or 0) / 2)), math.floor(H.y);   -- (bars and numbers together centred over the head:
                                                                     --  the numbers' width from the frame before)
    local function bar(y, h, v, c1, c2, bx, bw, al, ex)              -- (bx, bw, al: where and how wide it is now, how see-through - the entrance)
        bx, bw, al = bx or x0, bw or W, al or 1;                     -- (ex: Hex link's life - lag, lead)
        if hmir then ex = ex or {}; C.hexbar(dl, bx, y, bw, h, v, ex.lag, 0, { c1 = c2, c2 = c1, band = h + 1, al = al, live = true, lead = ex.lead }); return; end   -- (Hex link: the hexagon style)
        DL.RF(dl, bx - 1, y - 1, bx + bw + 1, y + h + 1, U4(0, 0, 0, 0.55 * al), (h + 2) / 2);   -- (a dark track)
        local fw = bw * math.max(0, math.min(1, v));
        if fw >= 1 then
            local r = math.min(h / 2, fw / 2);
            DL.RF(dl, bx, y, bx + math.min(fw, h), y + h, U4(c1[1], c1[2], c1[3], al), r);
            DL.RF(dl, bx + fw - math.min(fw, h), y, bx + fw, y + h, U4(c2[1], c2[2], c2[3], al), r);
            if fw > h then
                pcall(function() DL.RFM(dl, bx + r, y, bx + fw - r, y + h, U4(c1[1], c1[2], c1[3], al), U4(c2[1], c2[2], c2[3], al), U4(c2[1], c2[2], c2[3], al), U4(c1[1], c1[2], c1[3], al)); end);
            end
        end
    end
    local hc = (type(YUI_HP_COL) == 'table' and type(YUI_HP_COL[1]) == 'table') and YUI_HP_COL or { { 1.00, 0.36, 0.62 }, { 0.86, 0.24, 0.86 } };
    local h1, h2 = hc[1], hc[2];
    if hpp < 0.5 and hpp > 0 then                                    -- (low HP: it breathes, faster as it gets lower)
        local bb = 0.5 + 0.5 * math.sin(now * (4 + (0.5 - hpp) * 10));
        h1 = { h1[1] + (1 - h1[1]) * bb * 0.5, h1[2] + (1 - h1[2]) * bb * 0.5, h1[3] + (1 - h1[3]) * bb * 0.5 };
    end
    local hh, mh, g = math.max(4, math.floor(6 * sc + 0.5)), math.max(3, math.floor(5 * sc + 0.5)), math.max(3, math.floor(4 * sc + 0.5));
    H.rx, H.my, H.seen_t, H.top, H.sc = x0 + W, y0 + (hh + g + mh) / 2, os.clock(), y0, sc;
    local cw_ = H.colw or 0;                                         -- (the whole thing - numbers, bars, TP - for the guide's box)
    H.rect = { x0 - (hmir and cw_ or 0) - 4, y0 - 6, W + cw_ + 8, hh + g + mh + 8 * sc + 2 * math.max(4, 5 * sc) * 1.5 + 12 };   -- (their right end, middle, top and size: Hex link sits beside them)
    -- The entrance (about a second and a half): the pieces arrive one after the other - the HP bar slides in from the left
    -- and settles, then the MP bar from the right, then the TP dots pop out, then HP, MP and TP attach beside them; a light
    -- runs along each bar as it lands
    local ae = now - (H.t0 or -99);
    local intro = ae < 1.6;
    local function clamp01(v) return math.max(0, math.min(1, v)); end
    local function back(u) u = u - 1; return 1 + 2.70158 * u ^ 3 + 1.70158 * u ^ 2; end   -- (eases in, overshooting a touch)
    local uh = intro and clamp01(ae / 0.28) or 1;
    local um = intro and clamp01((ae - 0.3) / 0.28) or 1;
    if uh > 0 then bar(y0, hh, H.hp, h1, h2, x0 - (1 - back(uh)) * 26 * sc, W, uh, { lag = H.hl, lead = hpp }); end
    local mc_ = (type(YUI_MP_COL) == 'table') and YUI_MP_COL or C.MPCOL;
    if um > 0 then bar(y0 + hh + g, mh, H.mp, mc_[1], mc_[2], x0 + (1 - back(um)) * 26 * sc, W, um, { lag = H.ml, lead = mpp }); end
    local function sweep(y, h, t0, v)                                -- a light running along one bar once, inside its filled part only (clear of its round ends)
        local q = (ae - t0) / 0.42;
        if not intro or q <= 0 or q >= 1 then return; end
        local bw = 18 * sc;
        local bx = x0 - bw + q * (W + bw * 2);
        local in0, in1 = x0 + h / 2, x0 + W * math.max(0, math.min(1, v)) - h / 2;
        if math.min(in1, bx + bw) <= math.max(in0, bx - bw) then return; end
        C.clip(dl, { in0, y }, { in1, y + h }, true);
        pcall(function()
            local c0, c1 = U4(1, 1, 1, 0), U4(1, 1, 1, 0.6);
            DL.RFM(dl, bx - bw, y, bx, y + h, c0, c1, c1, c0);
            DL.RFM(dl, bx, y, bx + bw, y + h, c1, c0, c0, c1);
        end);
        dl:PopClipRect();
    end
    sweep(y0, hh, 0.28, H.hp);
    sweep(y0 + hh + g, mh, 0.58, H.mp);
    local na = 1;
    do                                                               -- BARS > Head bars numbers: the HP / MP at the end of each bar - when they
        local mode = cfg.head_nums or 'always';
        if mode == 'inside' then mode = 'off'; end                   -- (the old "inside the bars" choice: gone)
        if mode == 'off' then H.colw = 0; end                        -- (their room is kept while they're faded or still coming in, so the bars
                                                                     --  never shift sideways when they show)                      --  change (shown 3 s, then they fade), always, or never
        if mode ~= 'off' then
            local hpv, mpv = party:GetMemberHP(0) or 0, party:GetMemberMP(0) or 0;
            if H.hpv ~= hpv then H.hpv, H.ht = hpv, (H.hpv ~= nil) and now or -99; end
            if H.mpv ~= mpv then H.mpv, H.mt = mpv, (H.mpv ~= nil) and now or -99; end
            if H.tpv ~= tp then H.tpv, H.tt = tp, (H.tpv ~= nil) and now or -99; end
            local function alpha(t) if mode == 'always' then return 1; end return math.max(0, math.min(1, 1 - (now - (t or -99) - 2.5) / 0.6)); end
            local pushed = sized('chat', 11 * sc / 0.85);
            local th_ = imgui.GetTextLineHeight();
            local a = math.max(alpha(H.ht), alpha(H.mt), alpha(H.tt)) * na;            -- (right of the bars: "| HP  1306" over "| MP  745" - a little bar in each one's
            do                                                       --  colour, the label, the number right-aligned; no box, a thin dark outline)
                local hs, ms, ts = tostring(hpv), tostring(mpv), tostring(tp);
                local lw = math.max(tonumber((imgui.CalcTextSize('HP'))) or 0, tonumber((imgui.CalcTextSize('MP'))) or 0, tonumber((imgui.CalcTextSize('TP'))) or 0);
                local nw = math.max(tonumber((imgui.CalcTextSize(hs))) or 0, tonumber((imgui.CalcTextSize(ms))) or 0, tonumber((imgui.CalcTextSize(ts))) or 0, tonumber((imgui.CalcTextSize('0000'))) or 0);
                local rowh = th_ * 1.1;
                local pw = math.max(2, 2.2 * sc);                    -- (the little bar before each label)
                local lg = math.max(3, 4 * sc);
                local fw_ = pw + lg + lw + 10 * sc + nw;
                local fx = math.floor(hmir and (x0 - 8 * sc - fw_) or (x0 + W + 8 * sc));
                H.colw = 8 * sc + fw_;
                local my = y0 + (hh + g + mh) / 2;
                local function otext(px_, py_, col, str, oa)
                    for _, o in ipairs(OUTLINE) do DL.T(dl, px_ + o[1], py_ + o[2], U4(0, 0, 0, 0.9 * (oa or a)), str); end   -- (the chat's full outline)
                    DL.T(dl, px_, py_, col, str);
                end
                local rowk = 0;
                local function row(lbl, str, cy_, lc)
                    local rk = rowk; rowk = rowk + 1;                -- (the entrance: each line slides in from the right after the one before and
                    local ra = intro and clamp01((ae - (0.95 + 0.08 * rk)) / 0.22) or 1;   --  attaches, a flash on its little bar as it lands)
                    if ra <= 0 then return; end
                    local q = 1 - (1 - ra) ^ 3;
                    local ra_ = a * q;
                    local fx = fx + (hmir and -1 or 1) * (1 - q) * 22 * sc;   -- (slides in from the outer side)
                    local mc = cy_ - th_ * 0.14;                     -- (the capitals sit a little above the line's middle: the bar lines up with them)
                    local bx_ = hmir and (fx + fw_ - pw) or fx;      -- (the little bar: on the bars' side)
                    DL.RF(dl, bx_ - 1, mc - th_ * 0.34 - 1, bx_ + pw + 1, mc + th_ * 0.34 + 1, U4(0, 0, 0, 0.7 * ra_), pw / 2 + 1);
                    DL.RF(dl, bx_, mc - th_ * 0.34, bx_ + pw, mc + th_ * 0.34, U4(lc[1], lc[2], lc[3], ra_), pw / 2);
                    local land = intro and clamp01(1 - (ae - (0.95 + 0.08 * rk + 0.22)) / 0.25) or 0;
                    if ra >= 1 and land > 0 then DL.CF(dl, bx_ + pw / 2, mc, (3 + 4 * (1 - land)) * sc, U4(lc[1], lc[2], lc[3], 0.5 * land * a), 14); end
                    local w_ = tonumber((imgui.CalcTextSize(str))) or 0;
                    if hmir then                                     -- (mirrored: "1306  HP |" - the number on the outside, the label by the little bar)
                        local lbw = tonumber((imgui.CalcTextSize(lbl))) or 0;
                        otext(bx_ - lg - lbw, cy_ - th_ / 2, U4(lc[1], lc[2], lc[3], ra_), lbl, ra_);
                        otext(fx + nw - w_, cy_ - th_ / 2, U4(0.95, 0.95, 0.97, ra_), str, ra_);
                    else
                        otext(fx + pw + lg, cy_ - th_ / 2, U4(lc[1], lc[2], lc[3], ra_), lbl, ra_);
                        otext(fx + fw_ - w_, cy_ - th_ / 2, U4(0.95, 0.95, 0.97, ra_), str, ra_);   -- (the numbers right-aligned)
                    end
                end
                local tpy = y0 + hh + mh + g + 8 * sc + math.max(4, 5 * sc) + th_ * 0.14;   -- (TP on the dots' line; MP and HP evenly above it)
                if hmir then tpy = y0 + hh + mh + g + math.max(1, math.floor(1.5 * sc)) + math.max(4, math.floor(5 * sc + 0.5)) / 2 + th_ * 0.14 + rowh * 0.35; end   -- (Hex link: by the TP bar)
                if hmir then                                         -- (Hex link: each number on its own bar's line, the bars' size and colours)
                    unsized(pushed);
                    pushed = sized('chat', math.max(8, (hh + g) * 1.0));   -- (each number inside its own bar's height: they never touch)
                    local fs = FS or 1;
                    local right = x0 - 6 * sc;
                    local widest = 0;
                    local function hrow(lbl, str, cy_, lc, rk)
                        local ra = intro and clamp01((ae - (0.95 + 0.08 * rk)) / 0.22) or 1;
                        if ra <= 0 then return; end
                        local ra_ = a * (1 - (1 - ra) ^ 3);
                        local nw_, nh_ = imgui.CalcTextSize(str);
                        nw_, nh_ = tonumber(nw_) or 0, tonumber(nh_) or 10;
                        imgui.SetWindowFontScale(fs * 0.78);
                        local lw_, lh_ = imgui.CalcTextSize(lbl);
                        lw_, lh_ = tonumber(lw_) or 0, tonumber(lh_) or 7;
                        local nx = right - nw_ - (1 - ra) * 14 * sc;
                        local base = cy_ + nh_ / 2;                  -- (label and number on one foot)
                        otext(nx - 3 * sc - lw_, base - lh_ - nh_ * 0.06, U4(lc[1], lc[2], lc[3], 0.75 * ra_), lbl, ra_);
                        imgui.SetWindowFontScale(fs);
                        otext(nx, cy_ - nh_ / 2, U4(lc[1], lc[2], lc[3], ra_), str, ra_);
                        widest = math.max(widest, nw_ + 3 * sc + lw_);
                    end
                    hrow('HP', hs, y0 + hh / 2, C.HEXHP[3], 0);
                    hrow('MP', ms, y0 + hh + g + mh / 2, C.HEXMP[3], 1);
                    if tp > 0 then
                        local tb = math.max(4, math.floor(5 * sc + 0.5));
                        hrow('TP', ts, y0 + hh + g + mh + math.max(1, math.floor(1.5 * sc)) + tb / 2, { 1.0, 0.83, 0.42 }, 2);
                    end
                    H.colw = 6 * sc + widest;
                else
                row('HP', hs, tpy - rowh * 2, YUI_HEX and C.HEXHP[3] or { 0.95, 0.50, 0.76 });
                row('MP', ms, tpy - rowh, YUI_HEX and C.HEXMP[3] or { 0.62, 0.58, 1.00 });
                if tp > 0 then row('TP', ts, tpy, { 1.0, 0.83, 0.42 }); end   -- (not while it's 0: the empty dots say so)
                end
            end
            unsized(pushed);
        end
    end
    -- TP: an outline while empty, a dim dot growing in it while it fills, gold when full (a weapon skill ready), a ring
    -- of light opening from one as it fills
    if hmir then                                                     -- (Hex link: the TP bar under MP, not the dots)
        C.head_tp(dl, H, x0, y0, W, hh, mh, g, sc, tp, intro and clamp01((ae - 0.62) / 0.25) or 1, now);
        return;
    end
    local fl = math.max(0, 1 - (now - H.flash) / 0.7);
    local gold = { 1.0, 0.83, 0.42 };
    local d = math.max(4, 5 * sc);
    local dy = y0 + hh + mh + g + 8 * sc + d;
    local cx = x0 + W / 2;                                           -- (under the bars' middle)
    local dbase = d;
    for k = 0, 2 do
        local dx = math.floor(cx + (k - 1) * (dbase * 2 + 8 * sc) + 0.5);
        local f = math.max(0, math.min(1, (H.tp - k * 1000) / 1000));
        local pu_ = intro and clamp01((ae - (0.62 + 0.07 * k)) / 0.25) or 1;   -- (the entrance: each dot pops out after the one before)
        local d = dbase * ((pu_ >= 1) and 1 or (1 + 2.70158 * (pu_ - 1) ^ 3 + 1.70158 * (pu_ - 1) ^ 2));
        if pu_ > 0 and hmir then                                     -- (Hex link: hexagons - an edge while empty, filling from the middle, gold when full)
            local hr = d * 1.45;                                     -- (big enough to read as a hexagon)
            local p_ = C.hexpts(dx, dy, hr);
            if f >= 0.999 then                                       -- (full: a gold gem - a lighter facet in the middle, a fine darker
                local pu = 0.5 + 0.5 * math.sin(now * 3.2 - k * 0.6); --  edge, light on its top edges, a soft glow breathing round it)
                C.hexdot(dl, dx, dy, hr * (1.3 + 0.2 * pu), U4(gold[1], gold[2], gold[3], 0.06 + 0.12 * pu + 0.40 * fl));
                C.hexdot(dl, dx, dy, hr, U4(C.GOLDH[1], C.GOLDH[2], C.GOLDH[3], 1));
                C.hexdot(dl, dx, dy, hr * 0.58, U4(C.GOLDH2[1], C.GOLDH2[2], C.GOLDH2[3], 0.85));
                C.hexring(dl, dx, dy, hr, U4(0.45, 0.30, 0.08, 0.9), 1);
                dl:AddLine(p_[6], p_[1], U4(1, 0.98, 0.88, 0.95), 1);
                dl:AddLine(p_[1], p_[2], U4(1, 0.98, 0.88, 0.95), 1);
            else                                                     -- (empty: dark glass with a fine edge; filling: gold rising in it
                C.hexdot(dl, dx, dy, hr, U4(0.05, 0.04, 0.08, 0.78)); --  from the bottom, a bright line on its surface)
                if f > 0 then
                    local ri = hr - 1.5;
                    local yl = dy + ri - 2 * ri * f;
                    local A_ = C.HEXMP;                              -- (Hex link's azure filling up, gold once full)
                    local sx0, sx1 = C.hexlow(dl, dx, dy, ri, yl, U4(A_[1][1], A_[1][2], A_[1][3], 0.55));
                    if sx0 and sx1 - sx0 > 1 then DL.L(dl, sx0, yl, sx1, yl, U4(A_[3][1], A_[3][2], A_[3][3], 0.95), 1); end
                end
                C.hexring(dl, dx, dy, hr + 1.2, U4(0, 0, 0, 0.6), 2.4);   -- (a dark rim, then a brighter edge: readable on any ground)
                C.hexring(dl, dx, dy, hr, U4(0.70, 0.88, 1.0, 0.90), 1.3);
                dl:AddLine(p_[6], p_[1], U4(1, 1, 1, 0.35), 1);   -- (light on its top edges)
                dl:AddLine(p_[1], p_[2], U4(1, 1, 1, 0.35), 1);
            end
        elseif pu_ > 0 then
        if f >= 0.999 then
            local pu = 0.5 + 0.5 * math.sin(now * 3.2 - k * 0.6);   -- (its glow breathes, each dot a little after the one before)
            DL.CF(dl, dx, dy, d * (1.2 + 0.3 * pu), U4(gold[1], gold[2], gold[3], 0.06 + 0.18 * pu + 0.40 * fl), 20);
            DL.CF(dl, dx, dy, d + 1, U4(0, 0, 0, 0.40), 16);
            DL.CF(dl, dx, dy, d, U4(gold[1], gold[2], gold[3], 1), 16);
            DL.CF(dl, dx - d * 0.25, dy - d * 0.25, d * 0.35, U4(1, 0.98, 0.88, 0.8), 10);   -- (a little shine)
        else
            DL.CF(dl, dx, dy, d + 1, U4(0, 0, 0, 0.55), 20);
            DL.C(dl, dx, dy, d - 0.8, U4(0.80, 0.78, 0.86, 0.75), 20, 1.6);   -- (empty: a ring)
            if f > 0 then DL.CF(dl, dx, dy, math.max(1, (d - 2.6) * f), U4(0.88, 0.86, 0.94, 0.95), 16); end   -- (filling: a dot growing in it)
        end
        end
    end
    local d = dbase;
    if fl > 0 then
        local k = math.max(0, math.min(2, H.segs - 1));
        local dx = math.floor(cx + (k - 1) * (d * 2 + 8 * sc) + 0.5);
        if hmir then C.hexring(dl, dx, dy, d * (1.6 + (1 - fl) * 3), U4(1, 0.92, 0.65, 0.8 * fl), 1.5);   -- (Hex link: a hexagon of light opening)
        else DL.C(dl, dx, dy, d * (1.4 + (1 - fl) * 3), U4(1, 0.92, 0.65, 0.8 * fl), 24, 1.5); end
    end
end
-- Say and party lines: a bubble over the head of whoever said it, nearby, for a few seconds
function C.bubble_draw()
    if next(C.BUBS) == nil then return; end
    -- (its text size needs a window of its own - without one ImGui opens its "Debug" window): an invisible one, the
    -- whole screen, that takes no clicks
    local ds = imgui.GetIO().DisplaySize;
    imgui.SetNextWindowPos({ 0, 0 }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ ds.x, ds.y }, ImGuiCond_Always);
    local fl = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoInputs,
        ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoBringToFrontOnFocus, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoScrollbar);
    if imgui.Begin('##yui_bubbles', { true }, fl) then pcall(C.bubble_draw_); end
    imgui.End();
end
function C.bubble_draw_()
    local now = os.clock();
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    local bg = imgui.GetBackgroundDrawList();
    local SW, SH = C.screen();
    local sc = math.max(0.8, SH / 1080);
    local pushed = sized('chat', 15 * sc);
    local lh = imgui.GetTextLineHeight();
    for who, B in pairs(C.BUBS) do
        local life = 5 + math.min(5, #B.msg / 25);
        local age = now - B.t;
        if age > life or ent:GetRawEntity(B.idx) == nil or ent:GetName(B.idx) ~= who then C.BUBS[who] = nil;
        else
            local ok, sx, sy = pcall(function()
                local ap = ent:GetActorPointer(B.idx);
                if ap == nil or ap == 0 then return nil; end
                local px, py, pz = ashita.memory.read_float(ap + 0x678), ashita.memory.read_float(ap + 0x680), ashita.memory.read_float(ap + 0x67C);
                return C.w2s(px, pz - 2.25, py);                     -- (over the head: the game's "up" is minus)
            end);
            local dist = (ent:GetDistance(B.idx) or 0);
            if ok and sx and sy and dist < 30 * 30 and sx > -200 and sx < SW + 200 and sy > -100 and sy < SH + 100 then
                local inn = 1 - (1 - math.min(1, age / 0.25)) ^ 3;
                local a = inn * math.max(0, math.min(1, (life - age) / 0.5));
                local c = chat_col(B.cat);
                local rows = C.pop_rows(B.msg, 240 * sc);
                local w = 0;
                for _, row in ipairs(rows) do w = math.max(w, imgui.CalcTextSize(row)); end
                w = w + 20 * sc;
                local h = lh * #rows + 12 * sc;
                local x, y = sx + 30 * sc + (1 - inn) * 8 * sc, sy + 16 * sc - h / 2;   -- right of the head, sliding in
                local sh = tex('bubble_soft.png');                       -- on a soft shadow: one smooth picture, darkest in the middle
                if sh then image(bg, sh, x - 26 * sc, y - 14 * sc, x + w + 26 * sc, y + h + 14 * sc, { 1, 1, 1, 0.80 * a }); end
                for r, row in ipairs(rows) do
                    C.atext(bg, x + 10 * sc, y + 6 * sc + lh * (r - 1), row, { 0.97, 0.96, 1, a });
                end
            end
        end
    end
    unsized(pushed);
end
-- With the combat log split off, the battle's aftermath goes there too (it isn't a battle message to the game, so it
-- used to fill the All tab): experience, limit points, EXP chains, gil and items found or obtained, Records of
-- Eminence progress, sparks / accolades, level-ups, "You cannot attack that target"...
C.SPAM = { 'experience points', 'limit points', 'EXP chain', 'Obtained %d[%d,]* gil', 'Records of Eminence', '^Progress: %d+/%d+',
           'You find .+ on the ', ' obtains? .+%.$', 'sparks of eminence', 'Unity accolades', 'attains level %d+',
           'cannot attack that target', 'concealing a treasure', 'Venture mobs must', 'This objective may be repeated',
           'You have completed the following Records', 'falls to the ground', 'too far away', 'out of range',
           'cannot see ', 'Unable to see ', 'You must wait longer', 'lost the ', 'was defeated', 'defeats ',
           'venture target', 'activity points', 'venture points', 'Linkshell Point Accumulation', 'Your venture begins',
           'cleared to fulfill this objective', ' effect wears off', ' wears off%.$' };   -- (effects wearing off: battle lines too)
function C.battle_spam(mode, line)
    if is_combat(mode) then return false; end
    local cat = cat_of(mode);
    if cat ~= 'system' and cat ~= 'other' and cat ~= 'error' and cat ~= 'say' then return false; end
    local sl = line:gsub('[\1\2]', '');
    if cat == 'say' and sl:find(' : ', 1, true) then return false; end   -- (somebody really talking)
    for _, pat in ipairs(C.SPAM) do if sl:find(pat) then return true; end end
    return false;
end
-- CHAT > COMBAT FILTERS: battle lines left out by who did them - your party's / trusts' plain hits and misses, and
-- everything players outside your party do. Your own lines and monsters' always stay.
C.CF = { kinds = {}, at = 0 };
function C.actor_kind(name)                                          -- 'me', 'party', 'trust', 'outsider' or 'other' (monsters...)
    local K = C.CF;
    if os.clock() - K.at > 2 then K.kinds, K.at = {}, os.clock(); end
    if K.kinds[name] then return K.kinds[name]; end
    local kind = 'other';
    pcall(function()
        local p = AshitaCore:GetMemoryManager():GetParty();
        for i = 0, 17 do
            if p:GetMemberIsActive(i) ~= 0 and p:GetMemberName(i) == name then
                kind = (i == 0) and 'me' or (((p:GetMemberServerId(i) or 0) >= 0x01000000) and 'trust' or 'party');
                return;
            end
        end
        local ent = AshitaCore:GetMemoryManager():GetEntity();
        for i = 0x400, 0x6FF do                                      -- (players' entities: someone outside the party)
            if ent:GetRawEntity(i) ~= nil and ent:GetName(i) == name then
                if bit.band(ent:GetSpawnFlags(i) or 0, 0x01) ~= 0 then kind = 'outsider'; end
                return;
            end
        end
    end);
    K.kinds[name] = kind;
    return kind;
end
C.CF.ACT = { ' casts ', ' uses ', ' readies ', ' starts casting ', ' hits ', ' misses ', 'critical hit', ' performs ' };
function C.cf_starts(sl)                                             -- (true: this line starts someone's new action)
    for _, w in ipairs(C.CF.ACT) do if sl:find(w, 1, true) then return true; end end
    return false;
end
-- CHAT > COMBAT FILTERS > Buffs wearing off: "X's Haste effect wears off." / "X is no longer paralyzed." for anyone but you
function C.wear_skip(line)
    if cfg.chat_f_wear ~= false then return false; end
    local sl = line:gsub('[\1\2]', '');
    local w = sl:match("^(.-)'s? .- effect wears off%.$") or sl:match('^(.-) is no longer .-%.$');
    return w ~= nil and C.actor_kind(w) ~= 'me';
end
function C.cf_sets()                                                 -- (players near you outside your party, and your party, by name)
    local K = C.CF;
    if K.sets_at and os.clock() - K.sets_at < 2 then return K.outs, K.ins; end
    local outs, ins = {}, {};
    pcall(function()
        local p = AshitaCore:GetMemoryManager():GetParty();
        for i = 0, 17 do if p:GetMemberIsActive(i) ~= 0 then ins[p:GetMemberName(i) or ''] = true; end end
        local ent = AshitaCore:GetMemoryManager():GetEntity();
        for i = 0x400, 0x8FF do                                      -- (players, and from 0x700 their pets)
            if ent:GetRawEntity(i) ~= nil then
                local nm = ent:GetName(i);
                if nm and nm ~= '' and not ins[nm] and (i >= 0x700 or bit.band(ent:GetSpawnFlags(i) or 0, 0x01) ~= 0) then outs[nm] = true; end
            end
        end
    end);
    K.outs, K.ins, K.sets_at = outs, ins, os.clock();
    return outs, ins;
end
function C.combat_skip(line)                                         -- (true: this battle line is filtered out)
    local sl = line:gsub('[\1\2]', '');
    local F = C.CF;
    if F.tskip and os.clock() - F.tskip < 0.02 and not C.cf_starts(sl) then return true; end   -- (what a left-out trust action did)
    F.tskip = nil;
    if cfg.chat_f_debuff == false then                               -- (Area debuff lines: one spell on many monsters = its first line only)
        local t, what = sl:match('^(.-) is (.-)%.$');
        if t == nil then t, what = sl:match('^(.-) receives the effect of (.-)%.$'); end
        if t == nil then t = sl:match('^(.-) resists the spell') or sl:match('^(.-) resists the effects of the spell'); what = 'resist'; end
        if t ~= nil and what ~= nil and not what:find('^no longer') and C.actor_kind(t) == 'other' then
            local now = os.clock();
            if F.deb and F.deb.what == what and now - F.deb.t < 0.5 then F.deb.t = now; return true; end
            F.deb = { what = what, t = now };
        end
    end
    if F.skipnext and os.clock() - F.skipnext < 0.25 and sl:find('^.- takes %d+ points? of damage%.$') then F.skipnext = nil; return true; end
    F.skipnext = nil;
    local who = sl:match('^(.-) hits .- for %d+ points? of damage%.$') or sl:match('^(.-) misses .-%.$')
             or sl:match('^(.-) scores a critical hit!$');
    local melee = who ~= nil;
    who = who or sl:match('^([%w%-]+)[ \']');                         -- (anything else: its first word, the one who did it)
    if who == nil then return false; end
    local kind = C.actor_kind(who);
    local skip = false;
    if not skip and cfg.chat_f_others == false then                  -- (a player outside your party in it - doing it or having it done - and
        local outs, ins = C.cf_sets();                               --  none of yours: what they do to you or your party still shows)
        local out_, in_ = kind == 'outsider', false;
        for w in sl:gmatch('%u[%w]*') do
            if ins[w] then in_ = true; elseif outs[w] then out_ = true; end
        end
        if out_ and not in_ then skip = true; end
    end
    if skip and sl:find('critical hit!$') then F.skipnext = os.clock(); end   -- (its damage comes on the next line)
    return skip;
end
-- CHAT > COMBAT LOG - every battle line sorted by who did it (you, your party, alliance, your pet, trusts, others'
-- pets, other players, NPCs, the monsters you're fighting, other monsters) and by what it is (melee, ranged, magic,
-- damage, healing, misses, blocks, parries, dodges, guards, items, abilities, readies, casting, effects): each can be
-- switched off, and each kind can have a colour of its own (CHAT > COMBAT LOG > Colour by kind)
C.CF_WHO = { { 'me', 'You and your pet' }, { 'party', 'Your party' }, { 'alliance', 'Your alliance' }, { 'trust', 'Trusts' },
             { 'monster', 'Monsters' }, { 'npc', 'NPCs' } };          -- (other players: chat_f_others, the smart filter)
C.CF_GROUP = { me = 'me', mypet = 'me', party = 'party', alliance = 'alliance', trust = 'trust', other = 'other', pet = 'other',
               enemy = 'monster', monster = 'monster', npc = 'npc' };
C.CF_WHAT = {
    { 'melee', 'Melee hits', { 1.00, 0.86, 0.70 } }, { 'ranged', 'Ranged', { 0.86, 0.95, 0.66 } },
    { 'magic', 'Magic', { 0.76, 0.70, 1.00 } }, { 'uses', 'Abilities and weapon skills', { 1.00, 0.76, 0.46 } },
    { 'healing', 'Healing', { 0.56, 1.00, 0.70 } }, { 'defence', 'Misses and defences', { 0.70, 0.80, 0.95 } },
    { 'effects', 'Buffs and debuffs', { 0.95, 0.86, 1.00 } }, { 'items', 'Items', { 1.00, 0.90, 0.55 } },
};
C.CF_KIND = { misses = 'defence', blocks = 'defence', parries = 'defence', dodges = 'defence', guards = 'defence' };   -- (into the eight)
C.CF_TYPES = {                                                       -- (what a line is: the first of these it matches)
    { 'readies', ' readies ' }, { 'casting', ' starts casting ' }, { 'items', ' uses an? ' }, { 'items', ' uses %d+ ' },
    { 'ranged', 'ranged attack' }, { 'magic', ' casts ' }, { 'magic', 'Magic Burst' }, { 'magic', 'resists the spell' },
    { 'uses', ' uses ' }, { 'guards', ' guards ' }, { 'blocks', ' blocks ' }, { 'parries', ' parries ' },
    { 'dodges', ' evades' }, { 'dodges', 'shadow' }, { 'dodges', ' dodges' }, { 'dodges', ' anticipates' },
    { 'misses', ' misses' }, { 'healing', ' recovers %d+ [HM]P' }, { 'healing', '[HM]P drained' },
    { 'effects', 'effect of ' }, { 'effects', 'effect wears off' }, { 'effects', ' is no longer ' }, { 'effects', '^.- is %a+%.$' },
    { 'melee', ' hits ' }, { 'melee', 'critical hit' }, { 'damage', 'points? of damage' },
};
function C.cf_type(sl)
    for _, t in ipairs(C.CF_TYPES) do if sl:find(t[2]) then return t[1]; end end
    return nil;
end
C.CW = { kinds = {}, at = 0 };
function C.cf_who(name)                                              -- (who a name is: one of C.CF_WHO's keys)
    local K = C.CW;
    if os.clock() - K.at > 2 then K.kinds, K.at = {}, os.clock(); end
    if K.kinds[name] then return K.kinds[name]; end
    local kind = 'monster';
    pcall(function()
        local mm = AshitaCore:GetMemoryManager();
        local p = mm:GetParty();
        for i = 0, 17 do
            if p:GetMemberIsActive(i) ~= 0 and p:GetMemberName(i) == name then
                if i == 0 then kind = 'me'; elseif (p:GetMemberServerId(i) or 0) >= 0x01000000 then kind = 'trust';
                elseif i < 6 then kind = 'party'; else kind = 'alliance'; end
                return;
            end
        end
        local ent = mm:GetEntity();
        local me = p:GetMemberTargetIndex(0) or 0;
        local pi = (me > 0) and ent:GetPetTargetIndex(me) or 0;
        if pi and pi > 0 and ent:GetName(pi) == name then kind = 'mypet'; return; end
        for i = 0, 0x8FF do
            if ent:GetRawEntity(i) ~= nil and ent:GetName(i) == name then
                if i >= 0x700 then kind = 'pet';
                elseif i >= 0x400 then kind = 'other';
                elseif bit.band(ent:GetSpawnFlags(i) or 0, 0x10) ~= 0 then kind = ENGAGED[i] and 'enemy' or 'monster';
                else kind = 'npc'; end
                return;
            end
        end
    end);
    K.kinds[name] = kind;
    return kind;
end
-- simplelog's short lines ("[Actor] 57 hit > Target", "[Actor] 652 HP Cure V > Target", "[Actor] Meditate > Actor"): who,
-- and what by the action's name (a spell, an ability or weapon skill, an item); nil when the line isn't one of them
C.SLOG = { hit = 'melee', ['critical hit'] = 'melee', RA = 'ranged', ['critical RA'] = 'ranged', ['RA hit squarely'] = 'ranged',
           ['RA struck true'] = 'ranged', Barrage = 'ranged', missed = 'misses', ['missed RA'] = 'misses', ['dodged by'] = 'dodges',
           ['evaded by'] = 'dodges', ['anticipated by'] = 'dodges', ['absorbed by'] = 'dodges', ['parried by'] = 'parries',
           ['intimidated by'] = 'dodges', ['is paralyzed'] = 'effects', AE = 'melee', counter = 'melee', ['from counter'] = 'melee',
           ['missed counter'] = 'misses', retaliation = 'melee', ['from retaliation'] = 'melee' };
for n in ('Light Darkness Gravitation Fragmentation Distortion Fusion Compression Liquefaction Induration Reverberation ' ..
          'Transfixion Scission Detonation Impaction Radiance Umbra'):gmatch('%a+') do C.SLOG[n] = 'uses'; end   -- (skillchains)
C.SLOG_N = {};                                                       -- (action name -> kind, looked up once)
function C.cf_slog(sl)
    sl = sl:gsub('^%[%d+%] ', '');                                   -- ("[2] [Actor] 540 hit": hits counted together)
    local a, mid = sl:match('^%[(.-)%] (.-) > ');
    if not a then a, mid = sl:match('^(%S+) (.-) > '); if a == 'AOE' then a = nil; end end
    if not mid then return nil, nil; end
    if a then a = a:gsub(' %(.*%)$', ''); end                         -- (a pet's line: "Carbuncle (Yunas)")
    local heal = mid:match('^%d+ [HM]P ') ~= nil;
    local nm = mid:gsub('^%d+ [HMT]P ', ''):gsub('^%d+ ', ''):gsub(' %(.*%)$', '');
    if heal then return a, 'healing'; end
    if C.SLOG[nm] then return a, C.SLOG[nm]; end
    if nm:find('^Magic Burst! ') then return a, 'magic'; end
    if nm:find('^AE: ') then return a, 'melee'; end                  -- (an added effect: TH, Death...)
    nm = nm:gsub('^Bust! ', ''):gsub(' fails$', '');
    if nm == '' or nm:match('^%d+$') then return a, nil; end
    local k = C.SLOG_N[nm];
    if k == nil then
        k = false;
        pcall(function()
            local rm = AshitaCore:GetResourceManager();
            if rm:GetSpellByName(nm, 0) then k = 'magic';
            elseif rm:GetAbilityByName(nm, 0) then k = 'uses';
            elseif rm:GetItemByName(nm, 0) then k = 'items'; end
        end);
        C.SLOG_N[nm] = k;
    end
    return a, k or nil;
end
function C.cf_sort(line)                                             -- (who did it, and what it is)
    local sl = line:gsub('[\1\2]', '');
    local sa, st = C.cf_slog(sl);                                    -- (simplelog's way of writing them)
    if sa or st then return sa and C.cf_who(sa) or nil, st; end
    local nm = sl:match("^%d+ of (.-)'s shadow") or sl:match('^(.-) hits ') or sl:match('^(.-) misses') or sl:match('^(.-) casts ')
            or sl:match('^(.-) uses ') or sl:match('^(.-) readies ') or sl:match('^(.-) starts casting ') or sl:match('^(.-) scores ')
            or sl:match('^(.-) recovers ') or sl:match('^(.-) takes ') or sl:match('^(.-) is ') or sl:match('^(.-) receives ')
            or sl:match('^(.-) gains ') or sl:match('^(.-) blocks ') or sl:match('^(.-) parries ') or sl:match('^(.-) guards ')
            or sl:match('^(.-) evades') or sl:match('^(.-) dodges') or sl:match("^(.-)'s ") or sl:match('^([%w%-]+)');
    if nm then nm = nm:gsub("'s .*$", ''):gsub("'s$", ''):gsub('^[Tt]he ', ''); end   -- ("Yunas's ranged attack" -> Yunas)
    return nm and C.cf_who(nm) or nil, C.cf_type(sl);
end
function C.cf_col(t)                                                 -- (CHAT > COMBAT LOG > Colour by kind: this kind's colour)
    local c = cfg['cf_col_' .. t];
    if type(c) == 'table' and tonumber(c[1]) then return c; end
    for _, w in ipairs(C.CF_WHAT) do if w[1] == t then return w[3]; end end
    return nil;
end
C.RL = { n = 0, t = {} };                                            -- (the lines of the last few seconds, by text)
function C.seen_line(line, stamped)                                  -- (true: a time-stamped copy of a line YunaUI just had)
    local R, now = C.RL, os.clock();
    local dup = stamped and R.t[line] ~= nil and now - R.t[line] < 3;
    if R.n > 400 then R.t, R.n = {}, 0; end
    if R.t[line] == nil then R.n = R.n + 1; end
    R.t[line] = now;
    return dup;
end
-- NPC dialogue (a home point, a moogle, any menu NPC): the game sends the same line again each time its menu opens or
-- redraws - its own log hides the copies, so the same line from an NPC within 15 s is left out here too (and any other
-- system line, not talk or battle, sent twice within 3 s)
C.NPCMODE = { [142] = true, [144] = true, [150] = true, [151] = true };
C.NPCSEEN = { n = 0, t = {} };
function C.npc_dup(mode, line, combat)
    local win = C.NPCMODE[mode] and 2.5 or 2;                        -- (short: a menu's copies come within a second or two; a chest
                                                                     --  peered into again, or another with the same words, still shows)
    if combat or (mode >= 1 and mode <= 15) or mode == 213 or mode == 214 then return false; end   -- (talk and battle: never)
    local R, now = C.NPCSEEN, os.clock();
    local dup = R.t[line] ~= nil and now - R.t[line] < win;
    if R.n > 200 then R.t, R.n = {}, 0; end
    if R.t[line] == nil then R.n = R.n + 1; end
    R.t[line] = now;                                                 -- (copies coming one after another stay hidden; a pause and it shows again)
    return dup;
end
C.ROE_MODE = 300;
C.ROE = { 'Records of Eminence', '^Progress: %d+/%d+', 'sparks of eminence', 'Unity accolades', 'This objective may be repeated',
          'You have completed the following Records', 'cleared to fulfill this objective' };
function C.is_roe(line)
    local sl = line:gsub('[\1\2]', '');
    for _, pat in ipairs(C.ROE) do if sl:find(pat) then return true; end end
    return false;
end
-- A trust's line, "(Koru-Moru) Hoo hoo...": as it comes it's said in the party's mode, as it leaves in another one; both
-- go as party lines (one colour, the Party tab)
C.TRN = {};                                                          -- (name -> is a trust, looked up once)
function C.trust_line(s)
    local nm = s:match('^%(([^%(%)]+)%) %S');
    if not nm then return false; end
    if C.TRN[nm] == nil then
        C.TRN[nm] = false;
        pcall(function()
            local rm = AshitaCore:GetResourceManager();
            for _, n in ipairs({ nm, nm .. ' (UC)', nm .. ' II' }) do
                local sp = rm:GetSpellByName(n, 0);
                if sp and (tonumber(sp.Type) == 8 or (tonumber(sp.Index) or 0) >= 896) then C.TRN[nm] = true; return; end
            end
        end);
    end
    return C.TRN[nm];
end
local function chat_add(mode, raw)
    local ok, s = pcall(function()
        local m = raw;
        if mode < 20 or mode > 212 then
            local ok2, p = pcall(function() return AshitaCore:GetChatManager():ParseAutoTranslate(raw, true); end);
            if ok2 and p then m = p; end
        end
        return clean(m);
    end);
    if not ok or s == nil then return; end
    if mode ~= 5 and mode ~= 13 then                                 -- (a trust's goodbye: a party line, like its hello)
        local okt, tr = pcall(C.trust_line, s);
        if okt and tr then mode = 5; end
    end
    local n = (cfg.chat_split and is_combat(mode)) and 2 or 1;
    local log = logs[n];
    for line in (s .. '\n'):gmatch('([^\n\7]*)[\n\7]') do
        line = line:match('^%s*(.-)%s*$');
        if line ~= '' then
            local stamped, l2 = false, line:gsub('^%[%d%d?:%d%d[^%]]-%]%s*', '');   -- (another chat addon's "[12:43:45]": YunaUI
            if l2 ~= line and l2 ~= '' then stamped, line = true, l2; end            --  has its own times; its copy of a line
            if C.seen_line(line, stamped) then goto skip_line; end
            if is_combat(mode) then pcall(FIGHT.readies_name, line); end   -- ("The Golem readies Ice Break.": the name a move's number didn't give)
            if C.npc_dup(mode, line, is_combat(mode)) then goto skip_line; end         -- (an NPC's line sent again by its menu)                  --  YunaUI already has is left out)
            local raw_line = line;
            if C.is_roe(raw_line) then                               -- (Records of Eminence: to their own tab, RoE)
                local pre_ = cfg.chat_time and C.ts_text(os.time()) or '';
                CHATLOG.add(logs[1], { text = pre_ .. line, raw = raw_line, cat = 'roe', t = os.clock(), t0 = os.clock(), ts = os.time(), mode = C.ROE_MODE, tslen = #pre_ });
                chat_seen_new(C.ROE_MODE);
                if cw[1].scroll > 0 then cw[1].scroll = cw[1].scroll + 1; end
                goto skip_line;
            end
            local fd = nil;
            local n_, log_ = n, log;
            if n == 1 and cfg.chat_split then                        -- (the battle's aftermath: to the combat log)
                local oks, sp = pcall(C.battle_spam, mode, raw_line);
                if oks and sp then n_, log_ = 2, logs[2]; end
            end
            local cut_ = false;
            if is_combat(mode) then local okc, r = pcall(C.combat_skip, raw_line); cut_ = okc and r; end   -- (CHAT > COMBAT FILTERS)
            if not cut_ and mode >= 20 then local okw, r = pcall(C.wear_skip, raw_line); cut_ = okw and r; end
            local ctype = nil;
            if not cut_ and is_combat(mode) then                     -- (CHAT > COMBAT LOG)
                local okk, who, what = pcall(C.cf_sort, raw_line);
                if okk then
                    who = who and C.CF_GROUP[who] or who;
                    what = what and (C.CF_KIND[what] or what) or nil;
                    if what == 'readies' or what == 'casting' or what == 'damage' then what = nil; end   -- (always shown)
                    ctype = what;
                    if (who and who ~= 'other' and cfg['cf_w_' .. who] == false) or (what and cfg['cf_t_' .. what] == false) then cut_ = true; end
                end
            end
            if cut_ then                                             -- (hidden: still finishes a feed line already showing)
                if is_combat(mode) then pcall(C.feed_take, log_, raw_line, mode, true); end
                goto skip_line;
            end
            if is_combat(mode) then local okf, r = pcall(C.feed_take, log_, raw_line, mode); fd = okf and r or nil; end   -- (CHAT > Combat feed)
            if fd == nil then
                if not is_combat(mode) then pcall(C.chat_pop, mode, raw_line); end   -- (CHAT > Speech bubbles)
                local pre = cfg.chat_time and C.ts_text(os.time()) or '';
                line = pre .. line;
                local cat_ = cat_of(mode);                            -- (an addon's own message - "[Name] ..." on a channel nobody talks on: Addons)
                if cat_ ~= 'combat' and raw_line:match('^%[[%a][%w%s%._:%-]*%]') then cat_ = 'addon'; end   -- (any channel: players' lines never start so - a linkshell's is "[1]<Name>")
                CHATLOG.add(log_, { text = line, raw = raw_line, cat = cat_, t = os.clock(), t0 = os.clock(), ts = os.time(), mode = mode, tslen = #pre, ctype = ctype });
                if n_ == 1 then chat_seen_new(mode); end
            end
            if fd ~= 'merged' and cw[n_].scroll > 0 then cw[n_].scroll = cw[n_].scroll + 1; end
        end
        ::skip_line::
    end
end
-- Break a line into pieces that fit the width (kept until the width or the text size changes)
-- How wide a line is, with the auto-translate marks counted as their icons
local function line_w(s)
    local plain = s:gsub('[\1\2]', '');
    local _, n = s:gsub('[\1\2]', '');
    return imgui.CalcTextSize(plain) + n * (imgui.GetTextLineHeight() * 0.42 + 2);
end
-- The game's auto-translate icons: a green bracket opening the phrase, a red one closing it
local function at_icon(dl, x, y, lh, open, a)
    local bw = lh * 0.42;
    local col = open and { 0.35, 1.0, 0.45, a } or { 1.0, 0.32, 0.32, a };
    local x1, x2 = x + bw * 0.15, x + bw * 0.85;
    local p = open and { { x2, y + lh * 0.22 }, { x1, y + lh * 0.52 }, { x2, y + lh * 0.82 } }
                    or { { x1, y + lh * 0.22 }, { x2, y + lh * 0.52 }, { x1, y + lh * 0.82 } };
    local oc = U4(0, 0, 0, 0.85 * a);
    dl:AddLine(p[1], p[2], oc, 4); dl:AddLine(p[2], p[3], oc, 4);
    dl:AddLine(p[1], p[2], u32(col), 2); dl:AddLine(p[2], p[3], u32(col), 2);
    return bw + 2;
end
-- One chat line: dark outline round every letter (readable on any ground), its colour, and the auto-translate icons
-- How the letters are edged (CHAT > Letter edge): strong = dark all round (the old look, best on snow), soft = a
-- lighter edge so the letters keep their shape, shadow = only a soft drop shadow (the cleanest, for darker places)
local CHAT_EDGE = {
    outline = { { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }, 0.85 },   -- (a thin black line all round)
    strong = { OUTLINE, 0.9 },
    soft   = { { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { 1, 1 } }, 0.75 },
    shadow = { { { 1, 1 }, { 2, 2 } }, 0.55 },
};
-- Words picked out in colour in the chat: how tough a monster is when you /check it (the game's own check colours)
C.HL = { { 'too weak to be worthwhile', { 0.62, 0.62, 0.66 } }, { 'easy prey', { 0.55, 0.85, 1.0 } },
         { 'decent challenge', { 0.40, 0.65, 1.0 } }, { 'even match', { 1, 1, 1 } }, { 'incredibly tough', { 1.0, 0.30, 0.30 } },
         { 'very tough', { 1.0, 0.58, 0.25 } }, { 'tough', { 1.0, 0.90, 0.35 } }, { 'impossible to gauge', { 0.85, 0.45, 1.0 } } };
local function chat_line(dl, x, y, s, c, a, lh)
    local edge = CHAT_EDGE.outline;                                  -- (always: a thin dark line round every letter)
    local OUTLINE = edge[1];
    local oc = U4(0, 0, 0, edge[2] * a);
    local tc = U4(c[1], c[2], c[3], a);
    local cx = x;
    local low = -math.floor(imgui.GetTextLineHeight() * 0.11 + 0.5);   -- (this font draws < and > low, centred on small letters: raised to sit centred on capitals and numbers, as in "<3")
    local put1;
    local function put(str)                                          -- (a piece of text at cx: the C.HL words in their colour)
        local low_ = str:lower();
        local best, bs, be;
        for _, h in ipairs(C.HL) do
            local i = low_:find(h[1], 1, true);
            if i and (bs == nil or i < bs) then best, bs, be = h, i, i + #h[1] - 1; end
        end
        if best == nil then put1(str, tc); return; end
        if bs > 1 then put1(str:sub(1, bs - 1), tc); end
        put1(str:sub(bs, be), U4(best[2][1], best[2][2], best[2][3], a));
        if be < #str then put(str:sub(be + 1)); end
    end
    put1 = function(str, tc)                                         -- (its < and > set down)
        local p_ = 1;
        while p_ <= #str do
            local q = str:find('[<>]', p_);
            local run = str:sub(p_, (q or (#str + 1)) - 1);
            if run ~= '' then
                for _, o in ipairs(OUTLINE) do DL.T(dl, cx + o[1], y + o[2], oc, run); end
                DL.T(dl, cx, y, tc, run);
                cx = cx + imgui.CalcTextSize(run);
            end
            if q == nil then break; end
            local ch = str:sub(q, q);
            for _, o in ipairs(OUTLINE) do DL.T(dl, cx + o[1], y + low + o[2], oc, ch); end
            DL.T(dl, cx, y + low, tc, ch);
            cx = cx + imgui.CalcTextSize(ch);
            p_ = q + 1;
        end
    end
    do                                                               -- "<Name>" at the start: a little room inside the brackets
        local nm, rest = s:match('^<([^<>\1\2]+)>(.*)$');
        if nm then
            local gap = math.max(1, imgui.GetTextLineHeight() * 0.14);
            for _, seg in ipairs({ { '<', gap }, { nm, gap }, { '>', 0 } }) do
                put(seg[1]);
                cx = cx + seg[2];
            end
            s = rest;
        end
    end
    local i, n = 1, #s;
    while i <= n do
        local j = s:find('[\1\2]', i);
        local seg = s:sub(i, (j or (n + 1)) - 1);
        if seg ~= '' then put(seg); end
        if j == nil then break; end
        cx = cx + at_icon(dl, cx, y, lh - 2, s:byte(j) == 1, a);
        i = j + 1;
    end
end
-- One combat-feed line: who (bright), a small chevron, the spell (violet) or ability (gold), dots while it's being cast,
-- the target, then a green tick when it lands, damage in orange, HP healed in green, "miss" in red. Returns its width;
-- measure = true only measures. row: 1 (or nil) the spell and its first result; 2.. each further result (an area
-- spell's other targets), a row of its own under it, indented.
function C.feed_rows(e) return math.max(1, #((e.feed and e.feed.res) or {})) + ((e.feed and e.feed.split) and 1 or 0); end
function C.feed_fit(dl, e, maxw, notime)                             -- (does its first row fit maxw? if not it's split - kept until the width changes)
    local f = e.feed;
    if f == nil then return; end
    local sig = tostring(maxw) .. ':' .. tostring(#(f.res or {})) .. ':' .. tostring(f.state) .. ':' .. tostring(f.target);
    if f.fit_sig == sig then return; end
    f.split = nil;
    local w_ = C.feed_draw(dl, 0, 0, e, 1, 0, true, notime, 1) or 0;
    f.split = (w_ > maxw) and f.target ~= nil or nil;
    f.fit_sig = sig;
end
function C.feed_draw(dl, x, y, e, a, lh, measure, notime, row)
    local f = e.feed;
    local part = nil;                                                -- (split in two: row 1 who > what, row 2 > target and the result)
    if f.split then
        if (row or 1) == 1 then part = 'head';
        elseif row == 2 then part = 'tail'; row = 1;
        else row = row - 1; end
    end
    local th = imgui.GetTextLineHeight();
    local cx = x;
    local function txt(str, col, al)
        if str == nil or str == '' then return; end
        if not measure then chat_line(dl, cx, y, str, col, a * (al or 1), lh); end
        cx = cx + imgui.CalcTextSize(str);
    end
    local function chev(col)                                         -- (a small ">" drawn, with its dark edge)
        local w_ = th * 0.42;
        if not measure then
            local x0, x1, ym = cx + w_ * 0.3, cx + w_ * 0.75, y + th * 0.52;
            local p = { { x0, ym - th * 0.2 }, { x1, ym }, { x0, ym + th * 0.2 } };
            dl:AddLine(p[1], p[2], U4(0, 0, 0, 0.8 * a), 3.2); dl:AddLine(p[2], p[3], U4(0, 0, 0, 0.8 * a), 3.2);
            dl:AddLine(p[1], p[2], U4(col[1], col[2], col[3], a), 1.5); dl:AddLine(p[2], p[3], U4(col[1], col[2], col[3], a), 1.5);
        end
        cx = cx + w_;
    end
    local function tick()                                            -- (a green tick: it landed)
        local w_ = th * 0.62;
        if not measure then
            local x0, ym = cx + w_ * 0.12, y + th * 0.55;
            local p = { { x0, ym }, { x0 + w_ * 0.28, ym + th * 0.2 }, { x0 + w_ * 0.78, ym - th * 0.26 } };
            dl:AddLine(p[1], p[2], U4(0, 0, 0, 0.8 * a), 3.6); dl:AddLine(p[2], p[3], U4(0, 0, 0, 0.8 * a), 3.6);
            dl:AddLine(p[1], p[2], U4(0.45, 1.0, 0.55, a), 1.8); dl:AddLine(p[2], p[3], U4(0.45, 1.0, 0.55, a), 1.8);
        end
        cx = cx + w_;
    end
    local sp = imgui.CalcTextSize(' ');
    local function result(r, named)                                  -- (one result: who, then the damage / heal / miss / tick)
        if r.dmg then
            if named then txt(r.who .. ' ', { 0.88, 0.87, 0.94 }); end
            txt(r.dmg, { 1.0, 0.62, 0.32 });
        elseif r.heal then
            if named then txt(r.who .. ' ', { 0.88, 0.87, 0.94 }); end
            txt('+' .. r.heal, { 0.45, 1.0, 0.55 });
        elseif r.miss then
            if named then txt(r.who .. ' ', { 0.88, 0.87, 0.94 }); end
            txt('miss', { 1.0, 0.40, 0.45 });
        else
            tick();
            if named then cx = cx + sp * 0.3; txt(r.who, { 0.88, 0.87, 0.94 }); end
        end
    end
    if row and row > 1 then                                          -- a further target: indented, a dim chevron, then it
        local r = f.res[row];
        if r == nil then return 0; end
        cx = cx + sp * 4;
        chev({ 0.55, 0.53, 0.64 });
        cx = cx + sp * 0.5;
        result(r, true);
        return cx - x;
    end
    if part ~= 'tail' then
        if e.tpre and not notime then txt(e.tpre, C.ts_col(), 0.85); end   -- (the clear look draws it itself, small, after the bar)
        txt(f.actor, { 0.97, 0.96, 1.0 });
        cx = cx + sp * 0.5;                                          -- (a space each side of the chevron)
        chev({ 0.70, 0.68, 0.80 });
        cx = cx + sp * 0.5;
        local kc = (f.kind == 'magic') and { 0.74, 0.64, 1.0 } or { 1.0, 0.82, 0.45 };
        txt(f.act, kc);
        if f.state == 'cast' then                                    -- (being cast: three dots that pulse)
            local k = math.floor(os.clock() * 3) % 3;
            for d = 0, 2 do txt('.', kc, (d == k) and 1 or 0.35); end
        end
        if part == 'head' then return cx - x; end
    else
        cx = cx + sp * 2;                                            -- (the second half, indented)
    end
    if f.target then cx = cx + sp * 0.5; chev({ 0.70, 0.68, 0.80 }); cx = cx + sp * 0.5; txt(f.target, { 0.88, 0.87, 0.94 }); end
    local function same(a_, b_)                                      -- ("the Goblin Gambler" is "The Goblin Gambler")
        if a_ == nil or b_ == nil then return false; end
        return (a_:lower():gsub('^the ', '')) == (b_:lower():gsub('^the ', ''));
    end
    if f.res[1] then cx = cx + sp * 1.2; result(f.res[1], not same(f.res[1].who, f.target)); end   -- (the first result on this row)
    return cx - x;
end
-- CHAT > LOOK > Look: 'clear' (a dark rounded panel, channel bars, the time small on the left) or 'classic' (the first
-- look: a soft shade behind the lines, the time in brackets at the start of each message)
function C.clear_on() return cfg.chat_look ~= 'classic'; end
function C.wrapc(e, maxw, key)                                       -- (classic: the whole line, time and all, wrapped)
    if e.ww == maxw and e.wk == key and e.lines then return e.lines; end
    local out, cur = {}, '';
    for word in e.text:gmatch('%S+') do
        local try = (cur == '') and word or (cur .. ' ' .. word);
        if cur ~= '' and line_w(try) > maxw then out[#out + 1] = cur; cur = word; else cur = try; end
    end
    if cur ~= '' then out[#out + 1] = cur; end
    e.lines, e.ww, e.wk = out, maxw, key;
    return out;
end
function C.soft_ground(dl, x, y, w, h, a, solid_l, solid_r)          -- (classic: a dark ground with soft edges all round; solid_l / _r: that side
    if a <= 0.01 then return; end                                    --  doesn't fade - another chat touches it)
    local e = math.min(28, w * 0.1);
    local xs = { x, x + e, x + w - e, x + w };
    local ys = { y, y + h * 0.45, y + h - 10, y + h };
    local rowa = { 0, 0.50 * a, 0.88 * a, 0 };
    local function c(i, j)
        local edge = ((i == 1 and not solid_l) or (i == 4 and not solid_r)) and 0 or 1;
        return U4(0.02, 0.02, 0.04, rowa[j] * edge);
    end
    for i = 1, 3 do
        for j = 1, 3 do
            DL.RFM(dl, xs[i], ys[j], xs[i + 1], ys[j + 1], c(i, j), c(i + 1, j), c(i + 1, j + 1), c(i, j + 1));
        end
    end
end
-- The chat's rows (clear look): the message without its time, wrapped narrower (the time and the channel bar sit on its left, so
-- the rows after the first start under the message, not under the time). Gives the rows and the time ("12:39").
function C.wrapb(e, maxw, key)
    if e.btext == e.text and e.bw == maxw and e.bk == key and e.blines then return e.blines, e.bts; end
    local tl = e.tslen or 0;
    local ts = (tl > 0 and #e.text > tl) and e.text:sub(1, tl) or nil;
    local body = ts and e.text:sub(tl + 1) or e.text;
    local out, cur = {}, '';
    for word in body:gmatch('%S+') do
        local try = (cur == '') and word or (cur .. ' ' .. word);
        if cur ~= '' and line_w(try) > maxw then out[#out + 1] = cur; cur = word; else cur = try; end
    end
    if cur ~= '' then out[#out + 1] = cur; end
    if #out == 0 then out[1] = ''; end
    e.blines, e.bw, e.bk, e.btext = out, maxw, key, e.text;
    e.bts = ts and (ts:gsub('[%[%]]', ''):match('^%s*(.-)%s*$')) or nil;
    return out, e.bts;
end
-- Keep the game's own chat log closed while YunaUI chat is on: every frame, set the "stay open"
-- timer of both log windows to zero, so a new message never pops them open. The full log you open yourself still works.
local legacy = { draw = nil, tries = 0 };
-- Experimental (CHAT > Hide the game's typing bar), step 1: only READS. While you type, the game's input menu
-- ("menu    inline") is the focused one; two snapshots of its memory go to inline_dump.txt so its screen position can
-- be found. Nothing in the game is changed.
function legacy.menu_ptrs()
    legacy.pmenu = legacy.pmenu or ashita.memory.find('FFXiMain.dll', 0, '8B480C85C974??8B510885D274??3B05', 16, 0);
    if legacy.pmenu == nil or legacy.pmenu == 0 then return nil; end
    local sub = ashita.memory.read_uint32(legacy.pmenu);
    if sub == nil or sub == 0 then return nil; end
    local obj = ashita.memory.read_uint32(sub);
    if obj == nil or obj == 0 then return nil; end
    local head = ashita.memory.read_uint32(obj + 4);
    if head == nil or head == 0 then return nil; end
    return obj, head, (ashita.memory.read_string(head + 0x46, 16) or ''):gsub('%z', '');
end
-- Hiding the game's own windows the way UIBegone does (DragoHorse, after atom0s's hideparty, GPL): each native window
-- has a UI object whose byte +0x69 says "draw my graphics". Set to 0 the window isn't drawn at all; the game still
-- runs it (typing still works). The original byte is kept and put back when the option is off or YunaUI unloads.
--   chat1 / chat2: the two chat log windows (slots found from the party-frame signature, +0x0F / +0x37)
--   inline:        the typing bar: while you type it is the game's focused menu ("menu    inline"), found with
--                  legacy.menu_ptrs(); its menu object has the same +0x69 byte (seen in inline_dump.txt)
legacy.UI = {
    chat1  = { sig = '66C78182000000????C7818C000000????????C781900000', off = 0x0F },
    chat2  = { sig = '66C78182000000????C7818C000000????????C781900000', off = 0x37 },
    inline = { focused = 'inline' },
    logwin = { focused = 'logwindo', fresh = true },                 -- the log the pad expands (Triangle) and its full view (then X):
    fulllog = { focused = 'fulllog', fresh = true },                 -- hidden too, YunaUI's chat opens instead (see legacy.pad)
};
function legacy.in_game(a)
    if type(a) ~= 'number' or a < 0x10000 then return false; end
    legacy.base = legacy.base or ashita.memory.get_base('FFXiMain.dll');
    legacy.size = legacy.size or ashita.memory.get_size('FFXiMain.dll');
    if not legacy.base or not legacy.size then return true; end
    return a >= legacy.base and a + 4 <= legacy.base + legacy.size;
end
function legacy.ui_object(row)
    if row.focused then                                              -- (only while it's the focused menu)
        local obj, _, name = legacy.menu_ptrs();
        row.tries = (legacy.pmenu and legacy.pmenu ~= 0) and 0 or 9;
        if obj and name:find(row.focused) then return obj; end
        return nil;
    end
    if row.slot == nil then
        if (row.tries or 0) > 3 then return nil; end
        row.tries = (row.tries or 0) + 1;
        local m = ashita.memory.find('FFXiMain.dll', 0, row.sig, 0, 0);
        if m == nil or m == 0 then return nil; end
        local slot = ashita.memory.read_uint32(m + row.off);
        if not legacy.in_game(slot) then return nil; end
        row.slot = slot;
    end
    local first = ashita.memory.read_uint32(row.slot);
    if first == nil or first == 0 then return nil; end
    local obj = ashita.memory.read_uint32(first + 0x08);
    if obj == nil or obj == 0 then return nil; end
    return obj;
end
function legacy.ui_hide(key, on)
    local row = legacy.UI[key];
    if on then
        local obj = legacy.ui_object(row);
        if obj == nil then return; end
        if row.obj ~= obj then row.obj, row.orig = obj, ashita.memory.read_uint8(obj + 0x69); end
        if row.orig ~= 0 and ashita.memory.read_uint8(obj + 0x69) ~= 0 then ashita.memory.write_uint8(obj + 0x69, 0); end
        row.found = true;
    elseif row.fresh then
        row.obj, row.orig = nil, nil;                                -- (a menu made anew each time: nothing to put back)
    elseif row.obj then
        local obj = legacy.ui_object(row) or (row.focused and row.obj);  -- (the typing bar: put back even when closed)
        if obj == row.obj and ashita.memory.read_uint8(obj + 0x69) == 0 and (row.orig or 0) ~= 0 then
            ashita.memory.write_uint8(obj + 0x69, row.orig);
        end
        row.obj, row.orig = nil, nil;
    end
end
function legacy.hide_input(on) pcall(legacy.ui_hide, 'inline', on); end
function legacy.hide_logs(on)
    pcall(legacy.ui_hide, 'chat1', on); pcall(legacy.ui_hide, 'chat2', on);
    pcall(legacy.ui_hide, 'logwin', on); pcall(legacy.ui_hide, 'fulllog', on);
end
-- Pad players: every pad has its own layout (on many Xbox pads Y is the main menu and X the log), so YunaUI learns it:
-- the button that opened the game's own log is remembered (cfg.pad_log, e.g. 'd51' = DirectInput Triangle, 'x14' =
-- XInput X), and the one that then opened the full log (cfg.pad_big). Until then no button is taken from the game.
-- The log button stays the game's: its own log opens (moved below the screen, see legacy.log_away) and YunaUI's chat
-- lights up, and a second press highlights your buffs (top left, to cancel one) as always. The big-log button (Cross /
-- A) opens YunaUI's big chat instead of the game's full log; Circle / B closes it. While YunaUI's chat is lit, L1 / R1
-- (LB / RB) change the tab and the D-pad up / down scrolls; in the big chat the log button is the next tab.
-- CHAT > Pad: learn again forgets the learned buttons.
legacy.pad = { open = false, mine = false, big = false, menu = '', prev = '' };
legacy.PADN = { d = { [48] = 'SQUARE', [49] = 'CROSS', [50] = 'CIRCLE', [51] = 'TRIANGLE', [52] = 'L1', [53] = 'R1', [54] = 'L2', [55] = 'R2' },
    x = { [12] = 'A', [13] = 'B', [14] = 'X', [15] = 'Y', [8] = 'LB', [9] = 'RB', [4] = 'START', [5] = 'BACK' } };
function legacy.pad_name(id)
    if type(id) ~= 'string' then return '?'; end
    local n = tonumber(id:sub(2));
    return (legacy.PADN[id:sub(1, 1)] or {})[n] or ('BUTTON ' .. tostring(n));
end
function legacy.pad_press(api, b)                                    -- (a press: maybe the one that opens the game's log)
    legacy.pad.last, legacy.pad.last_t, legacy.pad.kind = api .. b, os.clock(), api;
end
function legacy.pad_btn(api, what)                                   -- (the learned button, or the usual one for this pad)
    if what == 'log' then return cfg.pad_log; end
    if what == 'big' then return cfg.pad_big or ((api == 'd') and 'd49' or 'x12'); end
    return (api == 'd') and 'd50' or 'x13';                          -- back: Circle / B
end
-- The big chat's HELP, right-aligned at rx: a small "HELP" tag; the mouse on it opens the buttons guide under it
function C.big_help(dl, rx, ty)
    pcall(function() dl = imgui.GetForegroundDrawList() or dl; end);   -- (over the chat's lines, when it's full)
    local tp = sized('chat', 15);
    local lab = 'HELP';
    local lw, lh = imgui.CalcTextSize(lab);
    local x0, y0, x1, y1 = rx - lw - 18, ty, rx, ty + lh + 8;
    local mx, my = imgui.GetMousePos();
    local hov = mx >= x0 and mx <= x1 and my >= y0 and my <= y1;
    DL.RF(dl, x0, y0, x1, y1, u32(hov and { 0.20, 0.10, 0.26, 0.96 } or { 0.10, 0.08, 0.14, 0.9 }), (y1 - y0) / 2);
    text(dl, x0 + 9, y0 + 4, lab, hov and { 1.0, 0.80, 0.93, 1 } or { 0.80, 0.78, 0.88, 1 });
    if hov then
        local xb = legacy.pad.kind == 'x';
        local rows = {
            { legacy.pad_name(cfg.pad_log or (xb and 'x15' or 'd51')) .. ' / F / ' .. (xb and 'LB / RB' or 'L1 / R1'), 'change tab' },
            { 'UP / DOWN / PAGE UP / DOWN', 'scroll' },
            { legacy.pad_name(legacy.pad_btn(xb and 'x' or 'd', 'back')) .. ' / ESC', 'back' },
        };
        local kw, dw = 0, 0;
        for _, r in ipairs(rows) do kw = math.max(kw, (imgui.CalcTextSize(r[1]))); dw = math.max(dw, (imgui.CalcTextSize(r[2]))); end
        local cw, gap = kw + dw + 50, lh + 8;
        local cx0, cy0 = rx - cw, y1 + 6;
        DL.RF(dl, cx0, cy0, rx, cy0 + #rows * gap + 14, U4(0.07, 0.06, 0.10, 0.97), 8);
        DL.RF(dl, cx0, cy0 + 8, cx0 + 3, cy0 + #rows * gap + 6, u32(C.hp), 2);   -- (the YunaUI line on its left)
        for i, r in ipairs(rows) do
            local yy = cy0 + 7 + (i - 1) * gap;
            text(dl, cx0 + 16, yy, r[1], { 0.97, 0.96, 0.99, 1 });
            text(dl, cx0 + 16 + kw + 22, yy, r[2], { 0.70, 0.68, 0.80, 1 });
        end
    end
    unsized(tp);
end
function legacy.pad_tick()
    local ok, _, _, name = pcall(legacy.menu_ptrs);
    legacy.pad.menu = (ok and name) or '';
    do                                                               -- the game's Map ("map0", then "mapframe" while open): YunaUI's big map
        local inmap = legacy.pad.menu:find('map', 1, true) ~= nil;   --  opens over it, the whole screen (BARS > MINIMAP > Open with the game's Map)
        if not inmap and legacy.inmap and legacy.pad.menu ~= '' then inmap = true; end   -- (Widescan, Markers... opened from the Map: still the Map, until every menu closes)
        if cfg.map_native_v == nil then cfg.map_native_v = 1; cfg.map_replace = false; end   -- (once: the game's own Map, now drawn in YunaUI's look, is used as it is)
        if cfg.map_replace == true and YMAP.have() then
            if inmap and not legacy.inmap then YMAP.big, YMAP.bygame = true, true; end
            if not inmap and legacy.inmap and YMAP.bygame then YMAP.big, YMAP.bygame = false, nil; end
        end
        legacy.inmap = inmap;
    end
    local game = legacy.pad.menu:find('logwindo', 1, true) ~= nil or legacy.pad.menu:find('fulllog', 1, true) ~= nil;
    local was = legacy.pad.prev;
    legacy.pad.prev = legacy.pad.menu;
    pcall(legacy.log_away);                                          -- (the game's log, while open: below the screen)
    if legacy.pad.last and os.clock() - (legacy.pad.last_t or 0) < 0.7 and was ~= legacy.pad.menu then   -- (learn the pad's layout)
        local now_log, now_full = legacy.pad.menu:find('logwindo', 1, true) ~= nil, legacy.pad.menu:find('fulllog', 1, true) ~= nil;
        local was_log = was:find('logwindo', 1, true) ~= nil;
        if now_log and not was_log and was:find('fulllog', 1, true) == nil and cfg.pad_log ~= legacy.pad.last then
            cfg.pad_log = legacy.pad.last; legacy.pad.last = nil; pcall(save);
        elseif now_full and was_log and cfg.pad_big ~= legacy.pad.last then
            cfg.pad_big = legacy.pad.last; legacy.pad.last = nil; pcall(save);
        end
    end
    if not (cfg.chat and cfg.hide_game_chat) then legacy.pad.mine = false; end
    if legacy.pad.mine and legacy.pad.menu ~= '' and not game then legacy.pad.mine, legacy.pad.big = false, false; end   -- (a menu opened: it closes)
    local open = legacy.pad.mine or (game and cfg.chat and cfg.hide_game_chat) or false;
    if open and not legacy.pad.open then cw[1].scroll = 0; end
    legacy.pad.open = open;
    if not open and legacy.pad.big then legacy.pad.big, legacy.pad.combat = false, false; end   -- (the log closed: the big chat too)
end
-- The game's log, while active, is chat window 1 grown taller (the same menu object; its +0x69 "draw" byte is ignored
-- then), so it can't be hidden the usual way: it's moved below the screen instead (its y at +0x3C and +0x8E), every
-- frame while it's open, and put back when it closes. Still the game's: a second press of the log button highlights
-- your buffs (top left) as always.
function legacy.log_away()
    local open = legacy.pad.menu:find('logwindo', 1, true) ~= nil and cfg.chat and cfg.hide_game_chat and not C.byvc;   -- (VanaCore's chat.hide: not needed)
    local T = legacy.lt or {};
    legacy.lt = T;
    if not open then
        if T.obj then
            local still = false;                                     -- (put back only on the log's own window - never on another one now there)
            pcall(function()
                local head = ashita.memory.read_uint32(T.obj + 4);
                local nm = head and head ~= 0 and (ashita.memory.read_string(head + 0x46, 16) or '') or '';
                still = nm:find('logwindo', 1, true) ~= nil or nm:find('logwin', 1, true) ~= nil;
            end);
            if still then for off, v in pairs(T.orig or {}) do pcall(ashita.memory.write_uint16, T.obj + off, v); end end
            T.obj, T.orig = nil, nil;
        end
        return;
    end
    local obj = legacy.menu_ptrs();
    if obj == nil then return; end
    if T.obj ~= obj then
        T.obj, T.orig = obj, {};
        for _, off in ipairs({ 0x3C, 0x8E }) do T.orig[off] = ashita.memory.read_uint16(obj + off); end
    end
    ashita.memory.write_uint16(obj + 0x3C, 0x3000); ashita.memory.write_uint16(obj + 0x8E, 0x3000);
end
function legacy.pad_once(key)                                        -- (each press arrives twice: count it once)
    legacy.pad.t = legacy.pad.t or {};
    local now = os.clock();
    if now - (legacy.pad.t[key] or -1) < 0.12 then return false; end
    legacy.pad.t[key] = now;
    return true;
end
function legacy.pad_toggle(on)                                       -- (the log button: no menu open, YunaUI chat on)
    legacy.pad.mine = on;
    legacy.pad.open = on;
    if not on then legacy.pad.big, legacy.pad.combat = false, false; end
    cw[1].scroll = 0;
end
function legacy.pad_back()                                           -- (Circle / B: from big back to lit, then closed)
    if legacy.pad.big then legacy.pad.big, legacy.pad.combat = false, false; else legacy.pad_toggle(false); end
end
function legacy.pad_tab(dir)
    local n = #CHANNELS;
    local combat = legacy.pad.big;                                   -- (the combat log: a tab of its own in the big chat)
    local count = combat and (n + 1) or n;
    local cur = legacy.pad.combat and (n + 1) or (tonumber(cfg.chat_tab) or 1);
    local t = (cur - 1 + dir) % count + 1;
    legacy.pad.combat = (t == n + 1);
    if not legacy.pad.combat then cfg.chat_tab = t; unread[t] = nil; end
    cw[1].scroll = 0;
    pcall(save);
end
function legacy.pad_scroll(lines)
    local lg = (legacy.pad.combat and cfg.chat_split) and logs[2] or logs[1];
    cw[1].scroll = math.max(0, math.min(#lg * 2, (cw[1].scroll or 0) + lines));
end
function legacy.snapshot()
    if (legacy.snapped or 0) >= 2 then return; end
    local now = os.clock();
    if legacy.snap_at and now < legacy.snap_at then return; end
    local obj, head, name = legacy.menu_ptrs();
    if obj == nil or not name:find('inline') then return; end
    local out = {};
    local ds = imgui.GetIO().DisplaySize;
    out[#out + 1] = string.format('== snapshot %d  menu "%s"  obj=%08X head=%08X  screen=%dx%d', (legacy.snapped or 0) + 1, name, obj, head,
        (ds and ds.x) or 0, (ds and ds.y) or 0);
    local function dump(label, base, size)
        out[#out + 1] = '-- ' .. label .. string.format(' @%08X', base);
        for row = 0, size - 1, 16 do
            local hex, sh = {}, {};
            for k = 0, 15 do hex[#hex + 1] = string.format('%02X', ashita.memory.read_uint8(base + row + k) or 0); end
            for k = 0, 14, 2 do sh[#sh + 1] = string.format('%6d', ashita.memory.read_int16(base + row + k) or 0); end
            out[#out + 1] = string.format('+%03X  %s  | %s', row, table.concat(hex, ' '), table.concat(sh, ' '));
        end
    end
    dump('menu object', obj, 0x100);
    dump('menu header', head, 0x180);
    for off = 0, 0x7C, 4 do                                          -- and whatever the header points at
        local v = ashita.memory.read_uint32(head + off) or 0;
        if v > 0x00400000 and v < 0x7FFF0000 then pcall(dump, string.format('header+%02X ->', off), v, 0x60); end
    end
    local f = io.open(addon.path .. '/inline_dump.txt', ((legacy.snapped or 0) == 0) and 'w' or 'a');
    if f then f:write(table.concat(out, '\n') .. '\n\n'); f:close(); end
    legacy.snapped, legacy.snap_at = (legacy.snapped or 0) + 1, now + 1.5;
end
local function pin_game_chat()
    if legacy.draw == nil or legacy.draw == 0 then
        if legacy.tries > 5 then return; end
        legacy.tries = legacy.tries + 1;
        legacy.draw = ashita.memory.find('FFXiMain.dll', 0, 'A1????????C64059018B0D????????C6415901C20800', 0, 0);
        if legacy.draw == nil or legacy.draw == 0 then return; end
    end
    for _, off in ipairs({ 0x01, 0x0B }) do
        local slot = ashita.memory.read_uint32(legacy.draw + off);
        if slot ~= nil and slot ~= 0 then
            local win = ashita.memory.read_uint32(slot);
            if win ~= nil and win ~= 0 then
                ashita.memory.unprotect(win + 0x34, 4);
                ashita.memory.write_uint32(win + 0x34, 0);
            end
        end
    end
end


-- What you're typing in the game's input line: the text (auto-translate phrases as their icons), where the caret is,
-- and the colour of the channel it will go to (from its /command)
local TYPE_COL = { ['/s'] = 'say', ['/say'] = 'say', ['/p'] = 'party', ['/party'] = 'party', ['/l'] = 'ls', ['/linkshell'] = 'ls',
    ['/l2'] = 'ls2', ['/linkshell2'] = 'ls2', ['/sh'] = 'shout', ['/shout'] = 'shout', ['/y'] = 'yell', ['/yell'] = 'yell',
    ['/t'] = 'tell', ['/tell'] = 'tell', ['/em'] = 'emote', ['/emote'] = 'emote', ['/u'] = 'unity', ['/unity'] = 'unity' };
local function typing_now()
    local ok, r = pcall(function()
        local cm = AshitaCore:GetChatManager();
        local open = cm:IsInputOpen();
        if open ~= 0x11 and open ~= 1 then return nil; end
        local raw = cm:GetInputTextRaw() or '';
        local caret = #raw;
        pcall(function() caret = math.max(0, math.min(#raw, cm:GetInputTextRawCaretPosition() or #raw)); end);
        local function shown(t)
            local ok2, q = pcall(function() return cm:ParseAutoTranslate(t, true); end);
            return clean((ok2 and q) or t);
        end
        local cmd = raw:match('^%s*(/%a+%d?)');
        return { text = shown(raw), before = shown(raw:sub(1, caret)), cat = cmd and TYPE_COL[cmd:lower()] or 'say' };
    end);
    return ok and r or nil;
end
local CHATFLAGS = nil;
-- YunaGearOpt's neon bezel (its actions.neon_corner): a bottom-left 'L' - a bar on the left edge brightening downwards,
-- a slanted foot, a glossy highlight, a soft glow, and a thin line running off along the bottom. o.fx / o.fy mirror it
-- (right side / top); o.k its size; o.bare: no faint backing.
function C.neon_corner(dl, x, y, w, h, o)
    o = o or {};
    local function col(r, g, b, al) return U4(r, g, b, al); end
    local function P(px, py) return o.fx and (2 * x + w - px) or px, o.fy and (2 * y + h - py) or py; end
    local function rect(ax, ay, bx, by, cul, cur, cbr, cbl)
        local x0, y0 = P(ax, ay);
        local x1, y1 = P(bx, by);
        if o.fx then x0, x1 = x1, x0; cul, cur = cur, cul; cbl, cbr = cbr, cbl; end
        if o.fy then y0, y1 = y1, y0; cul, cbl = cbl, cul; cur, cbr = cbr, cur; end
        pcall(function() DL.RFM(dl, x0, y0, x1, y1, cul, cur, cbr, cbl); end);
    end
    local k = o.k or h / 26;
    local bx0, bx1 = x - 1, x - 1 + math.max(3, math.floor(4 * k));
    local yt, yb, ye = y + 3 * k, y + h - 6 * k, y + h;
    local foot = { { bx0, yb }, { bx1, yb - 3 * k }, { bx1 + 11 * k, ye - 1 }, { bx1 + 5 * k, ye + 1 } };
    local function quad(q, c, grow)
        local g = grow or 0;
        local a1, a2 = P(q[1][1] - g, q[1][2]);
        local b1, b2 = P(q[2][1] + g, q[2][2] - g);
        local c1, c2 = P(q[3][1] + g, q[3][2]);
        local d1, d2 = P(q[4][1], q[4][2] + g);
        if (o.fx and true or false) ~= (o.fy and true or false) then
            a1, a2, b1, b2, c1, c2, d1, d2 = d1, d2, c1, c2, b1, b2, a1, a2;
        end
        pcall(function() dl:AddQuadFilled({ a1, a2 }, { b1, b2 }, { c1, c2 }, { d1, d2 }, c); end);
    end
    if not o.bare then
        rect(x, y, x + w, y + h, col(0.55, 0.30, 0.95, 0.05), col(0.55, 0.30, 0.95, 0),
            col(0.55, 0.30, 0.95, 0.05), col(0.60, 0.35, 1.0, 0.15));
    end
    for _, gp in ipairs({ { 4, 0.05 }, { 2, 0.10 } }) do
        rect(bx0 - gp[1], yt + 4 * k, bx1 + gp[1], yb, col(0.6, 0.3, 1, 0), col(0.6, 0.3, 1, 0),
            col(0.7, 0.4, 1, gp[2]), col(0.7, 0.4, 1, gp[2]));
        quad(foot, col(0.75, 0.45, 1, gp[2]), gp[1]);
    end
    local gx, gy = P(bx1 + 4 * k, ye - 2 * k);
    DL.CF(dl, gx, gy, 6 * k, col(0.75, 0.45, 1, 0.06));
    rect(bx0, yt, bx1, yb, col(0.40, 0.18, 0.75, 0.0), col(0.40, 0.18, 0.75, 0.0),
        col(0.80, 0.52, 1.0, 1.0), col(0.70, 0.42, 1.0, 1.0));
    quad(foot, col(0.82, 0.56, 1.0, 1.0));
    rect(bx1 - 1.5, y + h * 0.35, bx1 - 0.5, yb - 2 * k, col(1, 0.9, 1, 0), col(1, 0.9, 1, 0),
        col(1, 0.92, 1, 0.9), col(1, 0.92, 1, 0.9));
    local l1, l2 = P(bx1 - 1, yb - 2.5 * k);
    local m1, m2 = P(bx1 + 8 * k, ye - 1.5);
    DL.L(dl, l1, l2, m1, m2, col(1, 0.94, 1, 0.85), 1.2);
    rect(bx1 + 8 * k, ye - 1, x + w, ye, col(0.75, 0.45, 1, 0.9), col(0.6, 0.3, 1, 0.0),
        col(0.6, 0.3, 1, 0.0), col(0.75, 0.45, 1, 0.9));
end
-- YunaGearOpt's window corner (its actions.frame_corner): (cx, cy) the corner, sx / sy = +1 or -1 pointing into the
-- window; arms lx along the top / bottom and ly down the side, t thick; bright at the corner, fading along the arms
function C.frame_corner(dl, cx, cy, sx, sy, lx, ly, t)
    local function col(r, g, b, al) return U4(r, g, b, al); end
    local function arm(nx0, ny0, nx1, ny1, horiz, near, far)
        local x0, x1, y0, y1 = math.min(nx0, nx1), math.max(nx0, nx1), math.min(ny0, ny1), math.max(ny0, ny1);
        local ul, ur, br, bl;
        if horiz then
            local left_near = nx0 <= nx1;
            ul = left_near and near or far; bl = ul; ur = left_near and far or near; br = ur;
        else
            local top_near = ny0 <= ny1;
            ul = top_near and near or far; ur = ul; bl = top_near and far or near; br = bl;
        end
        pcall(function() DL.RFM(dl, x0, y0, x1, y1, ul, ur, br, bl); end);
    end
    local function shape(g, near, far)
        arm(cx, cy - sy * g, cx + sx * lx, cy + sy * (t + g), true, near, far);
        arm(cx - sx * g, cy, cx + sx * (t + g), cy + sy * ly, false, near, far);
    end
    shape(3, col(0.70, 0.40, 1.0, 0.07), col(0.6, 0.3, 1, 0));      -- glow
    shape(0, col(0.85, 0.62, 1.0, 1.0), col(0.55, 0.30, 1.0, 0));   -- the frame
    arm(cx, cy, cx + sx * lx * 0.5, cy + sy * 1, true, col(1, 0.92, 1, 0.7), col(1, 0.92, 1, 0));   -- a fine bright edge
    arm(cx, cy, cx + sx * 1, cy + sy * ly * 0.5, false, col(1, 0.92, 1, 0.7), col(1, 0.92, 1, 0));
end
-- Items in the chat: a line that names an item (loot, "You obtain...", an auto-translate item in linkshell...) gets its
-- icon at the end; the mouse over the icon shows a card with the item (its icon, name, level, jobs and stats).
-- The game's item names are read once into a table, a few hundred a frame so it never stutters.
C.ITEMS = { map = {}, nxt = 1, done = false };
function C.items_index()
    local I = C.ITEMS;
    if I.done then return; end
    local res = AshitaCore:GetResourceManager();
    local stop = math.min(I.nxt + 700, 30000);
    for id = I.nxt, stop do
        local ok, it = pcall(function() return res:GetItemById(id); end);
        if ok and it then
            pcall(function()
                for _, nm in ipairs({ it.Name and it.Name[1], it.LogNameSingular and it.LogNameSingular[1], it.LogNamePlural and it.LogNamePlural[1] }) do
                    if type(nm) == 'string' and #nm > 2 then
                        local k = nm:lower();
                        if I.map[k] == nil then I.map[k] = id; end
                    end
                end
            end);
        end
    end
    I.nxt = stop + 1;
    if I.nxt > 30000 then I.done = true; end
end
function C.items_find(line)                                          -- (the item ids a chat line names; {} when none)
    local I = C.ITEMS;
    local out, seen = {}, {};
    local function try(nm)
        if nm == nil then return; end
        nm = nm:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%.$', ''):gsub('^the ', ''):gsub('^an? ', '');
        local id = I.map[nm:lower()];
        if id == nil then id = I.map[(nm:gsub('^%d+ ', '')):lower()]; end   -- ("3 beastcoins")
        if id and not seen[id] and #out < 3 then seen[id] = true; out[#out + 1] = id; end
    end
    for nm in line:gmatch('\1([^\1\2]+)\2') do try(nm); end         -- auto-translate phrases
    local sl = line:gsub('[\1\2]', '');
    for _, pat in ipairs({ 'obtains? (.+)%.', 'Obtained: (.+)%.', 'finds? (.+) on ', 'finds? (.+)%.', 'You buy (.+) for', 'You sell (.+) for',
                           'bought (.+) for', 'sold (.+) for', 'You throw away (.+)%.', 'lost (.+)%.', 'receive[sd]? (.+)%.' }) do
        local m = sl:match(pat);
        if m then try(m); end
    end
    return out;
end
-- The item card: drawn by YunaUI (not ImGui's plain tooltip) next to the mouse - a soft shadow, a dark rounded panel,
-- the icon, name, level and jobs, Rare / Ex, then the stats, with the game's element marks drawn as little gems in
-- each element's colour (the font can't show the game's own symbols).
C.ELEM = { [0x1F] = { 1.0, 0.36, 0.26 }, [0x20] = { 0.60, 0.88, 1.0 }, [0x01] = { 0.60, 0.88, 1.0 }, [0x21] = { 0.45, 0.95, 0.50 }, [0x22] = { 0.86, 0.70, 0.36 },
           [0x23] = { 0.78, 0.52, 1.0 }, [0x24] = { 0.32, 0.56, 1.0 }, [0x25] = { 1.0, 0.98, 0.82 }, [0x26] = { 0.42, 0.30, 0.62 } };
function C.elem_gem(dl, x, cy, r, col, a)
    local pts = { { x + r, cy - r }, { x + 2 * r, cy }, { x + r, cy + r }, { x, cy } };
    dl:AddQuadFilled(pts[1], pts[2], pts[3], pts[4], U4(0, 0, 0, 0.85 * a));
    local k = r * 0.78;
    dl:AddQuadFilled({ x + r, cy - k }, { x + r + k, cy }, { x + r, cy + k }, { x + r - k, cy }, U4(col[1], col[2], col[3], a));
    DL.CF(dl, x + r - k * 0.3, cy - k * 0.35, math.max(1, k * 0.22), U4(1, 1, 1, 0.75 * a), 8);
end
-- A black brush stroke behind a line of text (the Paint Stroke frames, tinted black), painted in when the card opens
function C.brush(dl, x, cy, w, th, t, flip, a)
    local p = math.max(0, math.min(1, t / 0.28));
    local f = math.max(0, math.min(59, math.floor((1 - (1 - p) ^ 2) * 59 + 0.5)));
    local tx = tex(string.format('paint/%03d.png', f));
    if tx == nil then return; end
    local hh = th * 1.35;                                            -- (the stroke's band is ~40% of its picture: it covers the text)
    local x0, x1 = x - th * 0.9, x + w + th * 1.6;
    local u0, u1 = flip and 1 or 0, flip and 0 or 1;
    pcall(function() DL.I(dl, tx.ptr, x0, cy - hh, x1, cy + hh, u0, 0, u1, 1, U4(0, 0, 0, a)); end);
end
function C.item_card(id)
    -- The item card: a solid dark card (nothing shows through it), above the mouse so it never covers the line you're
    -- reading. A coloured edge on the left (gold Rare, violet Ex, else soft blue), the icon in a framed slot, the name,
    -- level and jobs, RARE / EX pills, a thin line, then the stats as little chips, each on its own - "DEF:6",
    -- "Attack+8", "Double Attack"+1% - with the element marks as coloured gems. A line like "On Darksdays: ..." gets its
    -- condition as a small heading over its own chips. Laid out first, then drawn; it opens with a quick fade and rise.
    local ok, it = pcall(function() return AshitaCore:GetResourceManager():GetItemById(id); end);
    if not ok or it == nil then return; end
    local fg = imgui.GetForegroundDrawList();
    local SW, SH = C.screen();
    local sc = math.max(0.8, SH / 1080);
    local CD = C.CARD or {};
    C.CARD = CD;
    if CD.id ~= id or os.clock() - (CD.seen or 0) > 0.3 then CD.id, CD.t0 = id, os.clock(); end
    CD.seen = os.clock();
    local k = 1 - (1 - math.min(1, (os.clock() - CD.t0) / 0.18)) ^ 3;  -- (its opening: 0 -> 1)
    local pushed = sized('chat', 13.5 * sc);
    local fs = FS or 1;
    local lh = imgui.GetTextLineHeight();
    local name = (it.Name and it.Name[1]) or '?';
    local lv = tonumber(it.Level) or 0;
    local jobs = tonumber(it.Jobs) or 0;
    local js;
    if bit.band(jobs, 0x007FFFFE) == 0x007FFFFE then js = 'All jobs';
    else local t_ = {}; for j = 1, 22 do if bit.band(jobs, bit.lshift(1, j)) ~= 0 then t_[#t_ + 1] = JOBS[j]; end end; js = table.concat(t_, ' '); end
    local sub = ((lv > 0) and ('Lv.' .. lv) or '') .. ((lv > 0 and js ~= '') and '  \xC2\xB7  ' or '') .. js;
    sub = sub:gsub('\xC2\xB7', '-');
    local fl = tonumber(it.Flags) or 0;
    local rare, ex = bit.band(fl, 0x8000) ~= 0, bit.band(fl, 0x6040) ~= 0;
    local acc = rare and { 0.95, 0.76, 0.31 } or (ex and { 0.76, 0.66, 1.0 } or { 0.45, 0.70, 1.0 });
    -- the stats: groups (a heading or none, then chips); a chip is a list of pieces (text, or an element gem)
    local d = ((it.Description and it.Description[1]) or ''):gsub('\x81\x60', '~'):gsub('\xEF\x20', '\xEF\x01');
    local groups = {};
    local function chips_of(str)
        local out, cur, inq = {}, '', false;
        for i = 1, #str do
            local ch = str:sub(i, i);
            local prev = (i > 1) and str:byte(i - 1) or 0;
            if ch == '"' then inq = not inq; end
            if ch == ' ' and not inq and prev ~= 0xEF then
                if cur ~= '' then out[#out + 1] = cur; end
                cur = '';
            else cur = cur .. ch; end
        end
        if cur ~= '' then out[#out + 1] = cur; end
        local merged, pend = {}, nil;                                -- (a stat is words up to the one with its number: "Magic Accuracy+3")
        for _, w_ in ipairs(out) do
            pend = pend and (pend .. ' ' .. w_) or w_;
            if w_:find('%d') then merged[#merged + 1] = pend; pend = nil; end
        end
        if pend then merged[#merged + 1] = pend; end
        return merged;
    end
    for para in (d .. '\n'):gmatch('([^\n]*)\n') do
        para = para:gsub('^%s+', ''):gsub('%s+$', '');
        if para ~= '' then
            local headp, rest = para:match('^([^:%d%+]+):%s+(.+)$');
            if headp and #headp >= 3 then groups[#groups + 1] = { head = headp, chips = chips_of(rest) };
            else
                if #groups == 0 or groups[#groups].head then groups[#groups + 1] = { chips = {} }; end
                for _, c_ in ipairs(chips_of(para)) do table.insert(groups[#groups].chips, c_); end
            end
        end
    end
    local SM = 0.84;                                                 -- (the chips' text: a little smaller than the name)
    local isz = math.floor(lh * SM * 0.78);
    local function parts_of(chip)                                    -- (a chip's pieces and its width, at the chips' size)
        local parts, w_, i = {}, 0, 1;
        while i <= #chip do
            if chip:byte(i) == 0xEF and i < #chip and C.ELEM[chip:byte(i + 1)] then
                parts[#parts + 1] = { gem = C.ELEM[chip:byte(i + 1)] }; w_ = w_ + isz + 3; i = i + 2;
            else
                local j = chip:find('\xEF', i + 1, true) or (#chip + 1);
                local t_ = chip:sub(i, j - 1):gsub('[\x80-\xFF]', '');
                if t_ ~= '' then parts[#parts + 1] = { t = t_ }; w_ = w_ + imgui.CalcTextSize(t_); end
                i = j;
            end
        end
        return parts, w_;
    end
    local W = math.floor(264 * sc);
    local pad, gap = math.floor(10 * sc), math.floor(5 * sc);
    local cpx, cpy = math.floor(6 * sc), math.floor(1 * sc);
    imgui.SetWindowFontScale(fs * SM);
    local clh = imgui.GetTextLineHeight();
    local chh = clh + cpy * 2;
    local maxw = W - pad * 2;
    local layout, yy = {}, 0;                                         -- (each chip's place, from the stats' top)
    for gi, g in ipairs(groups) do
        if g.head then yy = yy + ((gi > 1) and 4 * sc or 0); layout[#layout + 1] = { head = g.head, y = yy }; yy = yy + clh + 3 * sc; end
        local cx_, rowon = 0, false;
        for _, chip in ipairs(g.chips) do
            local parts, cw = parts_of(chip);
            local wbox = cw + cpx * 2;
            if wbox > maxw then                                      -- (too long for a chip - a sentence, the item's story: plain text,
                if rowon then cx_, rowon = 0, false; yy = yy + chh + gap; end   --  wrapped to the card's width)
                local cur_ = '';
                for word in chip:gsub('[\x80-\xFF]', ''):gmatch('%S+') do
                    local try = (cur_ == '') and word or (cur_ .. ' ' .. word);
                    if cur_ ~= '' and imgui.CalcTextSize(try) > maxw then layout[#layout + 1] = { text = cur_, y = yy }; yy = yy + clh; cur_ = word;
                    else cur_ = try; end
                end
                if cur_ ~= '' then layout[#layout + 1] = { text = cur_, y = yy }; yy = yy + clh; end
                yy = yy + gap;
            else
                if cx_ > 0 and cx_ + wbox > maxw then cx_ = 0; yy = yy + chh + gap; end
                layout[#layout + 1] = { parts = parts, x = cx_, y = yy, w = wbox };
                cx_, rowon = cx_ + wbox + gap, true;
            end
        end
        if rowon then yy = yy + chh + gap; end
    end
    imgui.SetWindowFontScale(fs);
    local isl = math.floor(30 * sc);                                 -- (the icon's slot)
    local pills = (rare and 1 or 0) + (ex and 1 or 0);
    local avail = W - pad - (pad + isl + math.floor(9 * sc));        -- (the room right of the icon)
    local subrows = {};
    imgui.SetWindowFontScale(fs * SM);
    do
        local cur_ = '';
        for word in sub:gmatch('%S+') do
            local try = (cur_ == '') and word or (cur_ .. ' ' .. word);
            if cur_ ~= '' and imgui.CalcTextSize(try) > avail then subrows[#subrows + 1] = cur_; cur_ = word; else cur_ = try; end
        end
        if cur_ ~= '' then subrows[#subrows + 1] = cur_; end
    end
    imgui.SetWindowFontScale(fs);
    if imgui.CalcTextSize(name) > avail then
        while #name > 1 and imgui.CalcTextSize(name .. '...') > avail do name = name:sub(1, -2); end
        name = name .. '...';
    end
    local textblock = lh + clh * #subrows + ((pills > 0) and (clh + 6 * sc) or 0);
    local headh = math.max(isl, textblock);
    local H = pad + headh + ((yy > 0) and (pad * 0.8 + 1 + pad * 0.8 + yy - gap) or 0) + pad;
    local mx, my = imgui.GetMousePos();
    local x = math.max(4, math.min(mx - 20 * sc, SW - W - 4));
    local y = my - H - 16 * sc;                                      -- (above the mouse; under it only if there's no room)
    if y < 4 then y = math.min(my + 22 * sc, SH - H - 4); end
    y = y + (1 - k) * 8 * sc;
    x, y, H = math.floor(x), math.floor(y), math.floor(H);            -- (whole pixels: crisp edges, nothing blurred)
    local A = k;
    local r = math.floor(7 * sc);
    local rgt = ImDrawFlags_RoundCornersRight or ImDrawCornerFlags_Right or 10;
    local sh_ = tex('bubble_soft.png');                              -- a soft shadow under it
    if sh_ then image(fg, sh_, x - 24 * sc, y - 10 * sc, x + W + 24 * sc, y + H + 26 * sc, { 1, 1, 1, 0.65 * A }); end
    -- the card: a thin dark line all round it (it stands out on any ground), then its colour as the left edge - the
    -- whole card filled in that colour, the dark face laid over it from 3 px in, so the edge follows the round corners
    -- exactly - then a fine light rim inside, brighter along the top
    DL.R(fg, x - 1, y - 1, x + W + 1, y + H + 1, U4(0, 0, 0, 0.85 * A), r + 1, C.rall, 1.5);
    DL.RF(fg, x, y, x + W, y + H, U4(acc[1], acc[2], acc[3], A), r);
    local ew = math.max(3, math.floor(3 * sc));
    DL.RF(fg, x + ew, y, x + W, y + H, U4(0.050, 0.046, 0.075, A), r, rgt);
    DL.R(fg, x + 0.5, y + 0.5, x + W - 0.5, y + H - 0.5, U4(0.36, 0.33, 0.50, 0.55 * A), r, C.rall, 1);
    pcall(function()                                                 -- (the top rim: a touch of light, fading toward the ends)
        local c1, c0 = U4(1, 1, 1, 0.16 * A), U4(1, 1, 1, 0);
        DL.RFM(fg, x + r, y + 1, x + W / 2, y + 2, c0, c1, c1, c0);
        DL.RFM(fg, x + W / 2, y + 1, x + W - r, y + 2, c1, c0, c0, c1);
    end);
    local ix, iy = x + pad, y + pad;                                 -- the icon in its slot
    DL.RF(fg, ix, iy, ix + isl, iy + isl, U4(0.10, 0.095, 0.15, A), 6);
    DL.R(fg, ix, iy, ix + isl, iy + isl, U4(0.30, 0.28, 0.42, A), 6, C.rall, 1);
    local t = YUI_EQ_ICON and YUI_EQ_ICON(id) or nil;
    local ip = math.floor(3 * sc);
    if t then pcall(function() DL.I(fg, t.ptr, ix + ip, iy + ip, ix + isl - ip, iy + isl - ip, 0, 0, 1, 1, U4(1, 1, 1, A)); end); end
    local tx = ix + isl + 9 * sc;
    local ty = iy + (headh - textblock) / 2;
    C.atext(fg, tx, ty, name, { 1, 1, 1, A });
    imgui.SetWindowFontScale(fs * SM);
    for ri, row in ipairs(subrows) do C.atext(fg, tx, ty + lh + clh * (ri - 1), row, { 0.70, 0.64, 0.90, A }); end
    if pills > 0 then                                                -- RARE / EX
        local px_, py_ = tx, ty + lh + clh * #subrows + 6 * sc;
        imgui.SetWindowFontScale(fs * SM * 0.86);
        local plh = imgui.GetTextLineHeight();
        for _, pl in ipairs({ rare and { 'RARE', { 0.95, 0.76, 0.31 } } or nil, ex and { 'EX', { 0.76, 0.66, 1.0 } } or nil }) do
            if pl then
                local pw = imgui.CalcTextSize(pl[1]) + 14 * sc;
                DL.RF(fg, px_, py_, px_ + pw, py_ + plh + 2 * sc, U4(pl[2][1] * 0.28, pl[2][2] * 0.24, pl[2][3] * 0.30, A), (plh + 2 * sc) / 2);
                DL.T(fg, px_ + 7 * sc, py_ + 1 * sc, U4(pl[2][1], pl[2][2], pl[2][3], A), pl[1]);
                px_ = px_ + pw + 6 * sc;
            end
        end
        imgui.SetWindowFontScale(fs * SM);
    end
    if yy > 0 then                                                   -- a thin line, then the stats
        local ly_ = y + pad + headh + pad * 0.8;
        pcall(function() DL.RFM(fg, x + pad, ly_, x + W - pad, ly_ + 1, U4(0.40, 0.36, 0.60, A), U4(0.40, 0.36, 0.60, 0), U4(0.40, 0.36, 0.60, 0), U4(0.40, 0.36, 0.60, A)); end);
        local sy0 = ly_ + 1 + pad * 0.8;
        for _, L_ in ipairs(layout) do
            if L_.head then
                C.atext(fg, x + pad, sy0 + L_.y, L_.head, { 0.58, 0.54, 0.76, A });
            elseif L_.text then                                      -- (a wrapped sentence)
                C.atext(fg, x + pad, sy0 + L_.y, L_.text, { 0.82, 0.79, 0.92, A });
            else
                local bx, by = x + pad + L_.x, sy0 + L_.y;
                DL.RF(fg, bx, by, bx + L_.w, by + chh, U4(0.12, 0.11, 0.17, A), 5);
                local cx2 = bx + cpx;
                for _, pt in ipairs(L_.parts) do
                    if pt.gem then C.elem_gem(fg, cx2, by + chh / 2, isz / 2, pt.gem, A); cx2 = cx2 + isz + 3;
                    else DL.T(fg, cx2, by + cpy, U4(0.93, 0.92, 0.98, A), pt.t); cx2 = cx2 + imgui.CalcTextSize(pt.t); end
                end
            end
        end
    end
    imgui.SetWindowFontScale(fs);
    unsized(pushed);
end
-- The chat's ground, by how bright it is where you are (no options): darker in the snow, the desert and the sun, lighter
-- at night - from the zone, Vana'diel's time and the weather (the real pixels behind it can't be read cheaply here)
C.AMB = { v = 0.55, wx = 0 };
C.BRIGHT_ZONES = { [111] = true, [112] = true, [5] = true, [203] = true, [114] = true, [125] = true, [247] = true, [130] = true,
                   [178] = true, [119] = true, [120] = true, [24] = true, [25] = true };
function C.amb_alpha(dt)
    local A = C.AMB;
    local hr = math.floor((os.time() - 1009810800) * 25 / 3600) % 24;   -- (Vana'diel's hour)
    local b = (hr >= 7 and hr <= 16) and 0.6 or ((hr >= 20 or hr <= 4) and 0.25 or 0.45);
    local zid = 0;
    pcall(function() zid = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) or 0; end);
    if C.BRIGHT_ZONES[zid] then b = b + 0.3; end
    local wx = A.wx or 0;
    if wx == 1 or wx == 12 or wx == 13 or wx == 16 or wx == 17 then b = b + 0.15;
    elseif wx == 3 or wx == 6 or wx == 7 or wx == 18 or wx == 19 then b = b - 0.1; end
    b = math.max(0, math.min(1, b));
    A.v = A.v + (b - A.v) * math.min(1, (dt or 0.016) * 0.5);       -- (changes slowly, never jumps)
    return 0.40 + 0.40 * A.v;
end
function C.weather_packet(e)                                         -- (0x057: the weather changed; 0x00A: a new zone)
    local w = nil;
    if e.id == 0x057 then w = struct.unpack('H', e.data, 0x08 + 1);
    elseif e.id == 0x00A then w = struct.unpack('H', e.data, 0x68 + 1); end
    if w and w >= 0 and w <= 19 then C.AMB.wx = w; end
end
local function draw_chat(n)
    if n == 1 then
        local sig = tostring(cfg.chat_time) .. tostring(cfg.chat_time_sec) .. tostring(cfg.chat_time_12) .. tostring(cfg.chat_time_case);
        if sig ~= C.tssig then if C.tssig then pcall(C.ts_rebuild); end C.tssig = sig; end
    end
    if n == 1 then C.bigchat = false; end
    if not cfg.chat or (n == 2 and not cfg.chat_split) then return; end
    if n == 2 and legacy.pad.big then return; end                    -- (the big chat is open: the combat log shows inside it, as a tab)
    if CHATFLAGS == nil then
        CHATFLAGS = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar,
            ImGuiWindowFlags_NoScrollWithMouse, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoBackground,
            ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav, ImGuiWindowFlags_NoSavedSettings,
            ImGuiWindowFlags_NoBringToFrontOnFocus);
    end
    local p = (n == 1) and 'chat_' or 'chat2_';
    local st, log = cw[n], logs[n];
    if n == 2 and cfg.chat_link then                                 -- anchored: the combat log sits right beside the chat, the same size,
        local tw, th = tonumber(cfg.chat_w) or 620, tonumber(cfg.chat_h) or 260;   -- its edges lined up, and follows it when it moves
        local cx_, cy_ = tonumber(cfg.chat_x) or 20, tonumber(cfg.chat_y) or 700;
        local W, H = ALLY.screen();
        W, H = W or 1920, H or 1080;
        local nx, ny = cx_ + tw, cy_;                                -- (edge to edge: one panel)
        if cfg.chat_link_v then                                      -- (the anchor's 2nd click: on top of the chat, or under it if there's no room)
            nx, ny = cx_, cy_ - th;
            if ny < 0 then ny = cy_ + th; end
        elseif nx + tw > W then nx = cx_ - tw; end                   -- (no room on its right: on its left)
        cfg.chat2_w, cfg.chat2_h = tw, th;
        cfg.chat2_x, cfg.chat2_y = math.floor(nx), math.floor(ny);
        st.relink = true;
    end
    local w, h = math.max(200, tonumber(cfg[p .. 'w']) or 600), math.max(80, tonumber(cfg[p .. 'h']) or 260);
    local big = (n == 1) and legacy.pad.big;                         -- (the pad's big chat: Triangle, then X)
    if n == 1 then C.bigchat = big; end
    if big then
        local SW, SH = C.screen();
        local bw = math.floor(math.max(math.min(w, SW - 40), SW * 0.55));
        local bh = math.floor(SH * 0.70);
        local bx = math.floor((SW - bw) / 2);
        local by = SH - bh - math.max(6, math.floor(SH * 0.01));      -- (sits on the bottom of the screen, any resolution)
        imgui.SetNextWindowPos({ bx, by }, ImGuiCond_Always);
        w, h = bw, bh;
        st.wasbig = true;
    else
        if st.wasbig then st.wasbig, st.relink = nil, true; end      -- (back to its own size and place)
        imgui.SetNextWindowPos({ tonumber(cfg[p .. 'x']) or 20, tonumber(cfg[p .. 'y']) or 700 }, (WATCH.move > 0 or st.relink) and ImGuiCond_Always or ImGuiCond_FirstUseEver);
    end
    st.relink = false;                                               -- (resized by its linked twin: placed again, its bottom kept)
    imgui.SetNextWindowSize({ w, h }, ImGuiCond_Always);
    local flags = CHATFLAGS;
    if cfg.locked or (n == 2 and cfg.chat_link) then flags = bit.bor(flags, ImGuiWindowFlags_NoMove); end   -- (anchored: it moves with the chat)
    if big then                                                      -- (the big chat sits on top of everything: bars, damage...)
        flags = bit.band(flags, bit.bnot(ImGuiWindowFlags_NoBringToFrontOnFocus));
        pcall(imgui.SetNextWindowFocus);
    end
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    if imgui.Begin((n == 1) and 'YunaUI Chat##yui_chat' or 'YunaUI Combat##yui_chat2', { true }, flags) then
        pcall(function()                                             -- (where it is, for the guide's box)
            local wx_, wy_ = imgui.GetWindowPos();
            local ww_, wh_ = imgui.GetWindowSize();
            C.CHATR = C.CHATR or {};
            C.CHATR[n] = { wx_, wy_, ww_, wh_, os.clock() };
        end);
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetWindowPos();
        local now = os.clock();
        -- the mouse over it lights it up (smoothly); away, it fades back to just the newest lines
        local hov = imgui.IsWindowHovered(ImGuiHoveredFlags_AllowWhenBlockedByActiveItem or 0) or imgui.IsWindowFocused() and imgui.IsMouseDown(0);
        local typing = (n == 1 and cfg.chat_typing ~= false) and typing_now() or nil;   -- you're typing: it shows it (CHAT tab)
        st.hovraw = hov;
        local linked = cfg.chat_link and cfg.chat_split;
        local other = cw[(n == 1) and 2 or 1];
        local hovx = hov or (linked and other.hovraw) or false;     -- (anchored: the mouse over either lights both)
        local want = (hovx or typing or chat_lit_all or st.scroll > 0) and 1 or 0;
        st.hv = st.hv + (want - st.hv) * math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 8);
        if n == 1 then                                               -- CHAT > Back to All when it closes: a tab picked in the full screen chat
            if legacy.pad.big then st.was_open = true;               --  (Say, Party, Shout...) goes back to All as it closes - command results
            elseif st.was_open then                                  --  (/find...) show again; a tab picked anywhere else stays
                st.was_open = false;
                if cfg.chat_tab_reset ~= false and (tonumber(cfg.chat_tab) or 1) ~= 1 then cfg.chat_tab = 1; save(); end
            end
        end
        local right = (tonumber(cfg.chat2_x) or 0) > (tonumber(cfg.chat_x) or 0);   -- (which side the combat log is on)
        local sl_, sr_ = false, false;
        if linked and not cfg.chat_link_v then
            if n == 1 then if right then sr_ = true; else sl_ = true; end
            else if right then sl_ = true; else sr_ = true; end end
        end
        -- The chat's one look (no options): a soft dark ground with no edges, behind the newest lines when it's at rest (a
        -- little darker for a moment when a line arrives), growing to the whole chat when it's lit (the mouse over it,
        -- typing, scrolling). Readable on grass, snow or sand, and never a box.
        do
            local lg_ = logs[(n == 1) and 1 or 2];
            local last = (lg_ and lg_[#lg_] and (lg_[#lg_].t0 or lg_[#lg_].t)) or -99;
            local pulse = math.max(0, 1 - (now - last) / 2.5);
            st.pulse = pulse;
            local uh = st.used_h or 0;
            local oth = linked and (((other.used_h or 0) > 0) or (other.hv or 0) > 0.02);   -- (the linked one shows a panel too: they join; empty, this one stands alone)
            if linked and cfg.chat_link_v and C.clear_on() then      -- (anchored one on top of the other: the top one's panel as tall as
                local me_y = tonumber(cfg[(n == 1) and 'chat_y' or 'chat2_y']) or 0;   --  its own lines; the bottom one's whole height when the top
                local ot_y = tonumber(cfg[(n == 1) and 'chat2_y' or 'chat_y']) or 0;   --  one has lines - so they always meet, no gap between them)
                if ot_y < me_y and (other.used_h or 0) > 0 then uh = h; end
                pulse = math.max(pulse, other.pulse or 0);
            elseif linked and (not C.clear_on() or (oth and uh > 0)) then   -- (anchored, both with lines: the same height and strength, so where they meet
                uh = math.max(uh, other.used_h or 0);                 --  there's no step and no seam)
                pulse = math.max(pulse, other.pulse or 0);
            end
            local gh = math.min(h, uh + 26);
            local gy = y + (h - gh) * (1 - st.hv);
            if C.clear_on() then                                     -- (clear: a dark rounded panel, so the words read on any ground)
                local A = math.max(0, math.min(1, tonumber(cfg.chat_panel_a) or 0.72));
                if (gh > 30 or st.hv > 0.02) and not big then        -- (the big chat has its own panel)
                    local fl = C.rall;                               -- (round corners; linked side by side: only the outer ones, so the two read as one panel;
                    if not oth then                                  --  the other one empty: all four)
                    elseif sl_ then fl = ImDrawFlags_RoundCornersRight or ImDrawCornerFlags_Right or 10;
                    elseif sr_ then fl = ImDrawFlags_RoundCornersLeft or ImDrawCornerFlags_Left or 5; end
                    if linked and cfg.chat_link_v then               -- (linked one on top of the other: only the corners away from the other one)
                        local me_y = tonumber(cfg[(n == 1) and 'chat_y' or 'chat2_y']) or 0;
                        local ot_y = tonumber(cfg[(n == 1) and 'chat2_y' or 'chat_y']) or 0;
                        if ot_y < me_y then fl = ((other.used_h or 0) > 0) and (ImDrawFlags_RoundCornersBottom or ImDrawCornerFlags_Bot or 12) or C.rall;   -- (the top one empty: all round)
                        else fl = oth and (ImDrawFlags_RoundCornersTop or ImDrawCornerFlags_Top or 3) or C.rall; end
                    end
                    local rr = YUI_HEX and 3 or 10;                  -- (Hex link: crisper corners)
                    local first_ = not oth or not (sl_ or (linked and cfg.chat_link_v and (tonumber(cfg[(n == 1) and 'chat2_y' or 'chat_y']) or 0) < (tonumber(cfg[(n == 1) and 'chat_y' or 'chat2_y']) or 0)));
                    local pfill = U4(0.055, 0.045, 0.08, math.min(1, A * (0.92 + 0.08 * pulse + 0.10 * st.hv)));
                    local kc = 18;                                   -- (Hex link: the top left corner cut at 45 degrees, as its frames' corners - big enough to read)
                    local cutp = YUI_HEX and first_ and pcall(function()   -- (Hex link: light - the panel fades upward, faint at rest, full when lit)
                        local pa = math.min(1, A * (1.12 + 0.08 * pulse + 0.10 * st.hv));
                        local top = pa * (0.78 + 0.22 * st.hv);   -- (at rest: still dark enough to read every line)
                        dl:AddConvexPolyFilled({ { x + kc, gy }, { x + w, gy }, { x + w, y + h }, { x, y + h }, { x, gy + kc } }, U4(0.055, 0.045, 0.08, top));
                        local yb = math.min(y + h, gy + kc);
                        local add = math.max(0, pa - top);
                        local c0, c1 = U4(0.055, 0.045, 0.08, 0), U4(0.055, 0.045, 0.08, add);
                        DL.RFM(dl, x, yb, x + w, y + h, c0, c0, c1, c1);
                    end);
                    if not cutp and YUI_HEX then                     -- (Hex link, the second one beside it: the same fading panel, no cut)
                        local pa = math.min(1, A * (1.12 + 0.08 * pulse + 0.10 * st.hv));
                        local top = pa * (0.78 + 0.22 * st.hv);
                        local c0, c1 = U4(0.055, 0.045, 0.08, top), U4(0.055, 0.045, 0.08, pa);
                        cutp = pcall(DL.RFM, dl, x, gy, x + w, y + h, c0, c0, c1, c1);
                        kc = 0;
                    end
                    if not cutp then DL.RF(dl, x, gy, x + w, y + h, pfill, rr, fl); kc = 0; end
                    if YUI_HEX and kc > 0 then                       -- (Hex link: just the corner cut, a fine light gold edge on it - the chat stays quiet)
                        local GO2 = C.GOLDH2 or { 1, 0.90, 0.62 };
                        local la = math.min(1, A * 1.1) * (0.75 + 0.25 * st.hv);
                        DL.L(dl, x, math.floor(gy) + kc, x + kc, math.floor(gy), U4(GO2[1], GO2[2], GO2[3], 0.80 * la), 1);
                    end
                end
            elseif (gh > 30 or st.hv > 0.02) and not big then        -- (classic: the soft shade, darker where the game is bright)
                C.soft_ground(dl, x, gy, w, (y + h) - gy, math.min(1, C.amb_alpha(imgui.GetIO().DeltaTime) + 0.15 * pulse + 0.30 * st.hv), sl_, sr_);
            end
        end
        if big then                                                  -- the pad's big chat: a panel like the game's full log
            DL.RF(dl, x, y, x + w, y + h, U4(0.055, 0.045, 0.08, 0.92), 10, C.rall);   -- (the chat's own panel, rounded; no edge, no corners)
            pcall(C.big_help, dl, x + w - 12, y + 10);               -- (a small HELP at the top right: the buttons guide on hover)
        end
        st.vis_n = 0;
        pcall(C.items_index);                                         -- (the game's item names, read a little each frame until done)
        local itip = nil;                                            -- (an item icon under the mouse: its card, after the text)
        -- the text, from the bottom up
        local size = tonumber(cfg.chat_size) or 16;
        local pushed = sized('chat', size);
        local lh = imgui.GetTextLineHeight() + math.max(0, math.min(16, tonumber(cfg.chat_gap) or 6));   -- CHAT > Line spacing
        local pad = 12;
        local bar = math.floor(size * 1.5 + 6);                       -- room for the tabs (the combat window's label)
        local maxw = w - pad * 2;
        C.iclip({ x, y }, { x + w, y + h }, true);
        local tk = 1 - (1 - math.max(0, math.min(1, st.hv))) ^ 3;
        if cfg.chat_tabs_always and n == 1 and not big then tk = 1; end   -- (CHAT > Always show tabs: their room stays open)    -- (the tabs' room opens only while it's lit - the mouse over it,
        local barv = bar * tk;                                       --  typing - and the lines slide up; at rest they go to the bottom)
        local ly = y + h - pad - lh - barv;
        local type_h = typing and (lh + 10) or 0;                     -- room for the typing line above the tabs
        ly = ly - type_h;
        local skip = st.scroll;
        local hold, fade = tonumber(cfg.chat_hold) or 12, 3;
        local bright = 1.4;                                          -- (the chat's brightness: fixed, Yunas's own setting)
        local tab = (n == 1) and (tonumber(cfg.chat_tab) or 1) or 1;
        local only = nil;                                            -- (the big chat: 'combat' = only battle lines, 'talk' = none)
        if n == 1 and not big then                                   -- (a hidden tab picked before: back to All)
            local nm_ = (tab == C.CHAT_COMBAT) and 'Combat' or (CHANNELS[tab] and CHANNELS[tab][1]);
            if not nm_ or not C.tab_on(nm_) then tab = 1; end
            if tab == C.CHAT_COMBAT then                             -- (the Combat tab: the combat log - its own window's lines when split)
                if cfg.chat_split then log = logs[2]; else only = 'combat'; end
                tab = 1;
            end
        end
        if big then
            if legacy.pad.combat then
                if cfg.chat_split then log = logs[2]; else only = 'combat'; end
                tab = 1;
            elseif not cfg.chat_split then only = 'talk'; end
        end
        local CL;                                                    -- (clear look: the time column, the indent, the space between messages)
        if C.clear_on() then
            CL = { gap = math.max(0, math.min(14, tonumber(cfg.chat_msg_gap) or 5)), extra = 0, tsk = 0.78 };
            local fs = FS;
            imgui.SetWindowFontScale(fs * CL.tsk);
            local sample = cfg.chat_time and (C.ts_text(os.time()):gsub('[%[%]]', ''):match('^%s*(.-)%s*$')) or nil;
            CL.tw = sample and ((tonumber((imgui.CalcTextSize(sample))) or 0) + 8) or 0;   -- (the time's column: as wide as the time)
            CL.sh = imgui.GetTextLineHeight();
            imgui.SetWindowFontScale(fs);
            CL.ind = 3 + 7 + CL.tw;                                  -- (the bar, a little room, the time)
        end
        local i = #log;
        local rown, vrows = 0, 0;                                    -- (vrows: the rows still showing at rest - the ground's height)                                              -- (rows drawn so far, from the bottom: at rest the newest 3 show, 2 more fade)
        while i >= 1 and ly > y - lh do
            local e = log[i];
            if tab ~= 1 and TAB_OF[e.mode or 0] ~= tab then i = i - 1; goto next_line; end
            if tab == 1 and e.mode == C.ROE_MODE then i = i - 1; goto next_line; end   -- (RoE: only in its own tab)
            if only and ((only == 'combat') ~= is_combat(e.mode or 0)) then i = i - 1; goto next_line; end
            do
            local keep = cfg.chat_fade_old == false;                 -- CHAT > Fade when idle: on, a line shows for 'Lines stay for' then fades
            local lt = keep and 1 or math.max(0, math.min(1, 1 - ((now - (e.t or now)) - hold) / fade));   --  away, shade and all (the chat
            local life = lt;                                         --  clears when nobody writes); off, every line stays
            local vis = math.max(st.hv, life);
            if vis <= 0.01 and skip <= 0 then break; end            -- older lines are all faded out
            local lines, bts = nil, nil;
            if e.feed then                                           -- (a combat-feed line: drawn by C.feed_draw, a row for the spell
                pcall(C.feed_fit, dl, e, maxw - (CL and CL.ind or 0), CL and true or false);   --  and each further target it hit - split in two when too wide)
                lines = {};
                for r_ = 1, C.feed_rows(e) do lines[r_] = e.text; end
                if CL and e.tpre then bts = (e.tpre:gsub('[%[%]]', ''):match('^%s*(.-)%s*$')); end
            elseif CL then lines, bts = C.wrapb(e, maxw - CL.ind, size);
            else lines = C.wrapc(e, maxw, size); end
            local drew = false;
            local age = (cfg.chat_anim ~= false) and (now - (e.t0 or -99)) or 99;   -- CHAT > Animated lines: slides in, then settles
            local slide, ain = 0, 1;
            if age < 0.35 then local q = 1 - (1 - age / 0.35) ^ 3; slide, ain = (1 - q) * 28, q; end
            local glow = (cfg.chat_anim ~= false) and math.max(0, 1 - (now - (e.flash or e.t0 or -99)) / 0.9) or 0;
            for k = #lines, 1, -1 do
                if skip > 0 then skip = skip - 1;
                else
                    local rest = 1;
                    local a = math.max(0, math.min(1, (ly - y) / (h * 0.25))) * math.max(st.hv, rest * lt) * ain;    -- fades toward the top
                    if rest * lt > 0.05 then vrows = vrows + 1; end
                    if a > 0.01 then
                        st.vis_n = math.max(st.vis_n or 0, vis);
                        -- readable on any ground (snow, sand, bright floors): a full dark outline round every letter
                        local c = (cfg.cf_cols and e.ctype and C.cf_col(e.ctype)) or chat_col(e.cat);   -- (CHAT > COMBAT LOG > Colour by kind)
                        local cg = math.max(0.6, math.min(2.0, tonumber(cfg.chat_bright) or 1));   -- CHAT > COLOURS > Brightness
                        if cg ~= 1 then c = { math.min(1, c[1] * cg), math.min(1, c[2] * cg), math.min(1, c[3] * cg) }; end
                        if bright >= 1 then                          -- brighter: toward white; dimmer: toward dark
                            local u = math.min(1, bright - 1);
                            c = { c[1] + (1 - c[1]) * u, c[2] + (1 - c[2]) * u, c[3] + (1 - c[3]) * u };
                        else
                            c = { c[1] * bright, c[2] * bright, c[3] * bright };
                        end
                        local txt = lines[k];
                        local px = x + pad - slide;                  -- (where this row starts: sliding in when new)
                        local cl_ = CL and true or false;
                        if cl_ then                                  -- clear look: the channel's bar, the time on the first row, the words after them
                            local th0 = lh - math.max(0, math.min(16, tonumber(cfg.chat_gap) or 6));
                            local bc = chat_col(e.cat);
                            if e.cat == 'system' or e.cat == 'other' or e.cat == 'combat' then bc = { 0.40, 0.38, 0.46 }; end
                            DL.RF(dl, px, ly - ((k < #lines) and 0 or 0), px + 3, ly + ((k < #lines) and lh or th0), U4(bc[1], bc[2], bc[3], 0.95 * a), 1.5);
                            if k == 1 and bts then
                                local fs = FS;
                                imgui.SetWindowFontScale(fs * CL.tsk);
                                chat_line(dl, px + 10, ly + math.floor((th0 - CL.sh) / 2 + 1), bts, C.ts_col(), a * 0.75, lh);
                                imgui.SetWindowFontScale(fs);
                            end
                            px = px + CL.ind;
                        end
                        local tw_ = e.feed and C.feed_draw(dl, px, ly, e, a, lh, true, cl_, k) or line_w(txt);
                        local th = lh - math.max(0, math.min(16, tonumber(cfg.chat_gap) or 6));
                        if glow > 0.01 then                          -- (new, or a feed line that just grew: a soft glow in its colour)
                            DL.RF(dl, px - 5, ly - 2, px + tw_ + 5, ly + th + 1, U4(c[1], c[2], c[3], 0.22 * glow * glow * a), 4);
                        end
                        local fresh = (cfg.chat_anim ~= false) and math.max(0, math.min(1, 1 - ((now - (e.flash or e.t0 or -99)) - 1.5) / 1.5)) or 0;
                        if fresh > 0.01 and not cl_ then             -- (the clear look has its bar all the time)                         -- (new, or a feed line that just grew: a short bar in its colour on the
                            DL.RF(dl, px - 10, ly, px - 7, ly + th - 1, U4(c[1], c[2], c[3], 0.9 * fresh * a), 1.5);   --  left, for a moment)
                        end
                        local ts = (not cl_ and not e.feed and k == 1 and (e.tslen or 0) > 0 and #txt > e.tslen) and txt:sub(1, e.tslen) or nil;
                        if e.feed then
                            C.feed_draw(dl, px, ly, e, a, lh, false, cl_, k);
                        elseif ts then                               -- the time in its own colour (CHAT > Timestamps > Colour), so the words stand out
                            chat_line(dl, px, ly, ts, C.ts_col(), a * 0.85, lh);
                            chat_line(dl, px + line_w(ts), ly, txt:sub(#ts + 1), c, a, lh);
                        else
                            chat_line(dl, px, ly, txt, c, a, lh);
                        end
                        if k == #lines and not e.feed and C.ITEMS.done then   -- the items it names: their icons after its last row
                            if e.items == nil then local oki, r_ = pcall(C.items_find, e.raw or e.text or ''); e.items = oki and r_ or {}; end
                            local ix = px + tw_ + 6;
                            local isz = math.floor(th * 0.82);
                            local ly0 = ly;
                            ly = ly0 + (th - isz) / 2;
                            for _, iid in ipairs(e.items) do
                                local t = YUI_EQ_ICON and YUI_EQ_ICON(iid) or nil;
                                if t then
                                    pcall(function() DL.I(dl, t.ptr, ix, ly, ix + isz, ly + isz, 0, 0, 1, 1, U4(1, 1, 1, a)); end);
                                    local mx, my = imgui.GetMousePos();
                                    if a > 0.3 and mx >= ix and mx <= ix + isz and my >= ly and my <= ly + isz then
                                        itip = iid;
                                        DL.R(dl, ix - 1, ly - 1, ix + isz + 1, ly + isz + 1, U4(1, 1, 1, 0.8), 2, C.rall, 1.2);
                                    end
                                    ix = ix + isz + 3;
                                end
                            end
                            ly = ly0;
                        end
                    end
                    ly = ly - lh;
                    rown = rown + 1;
                    drew = true;
                    if ly <= y - lh then break; end
                end
            end
            if CL and drew then                                      -- (clear look: a little room between messages)
                ly = ly - CL.gap;
                if lt > 0.05 then CL.extra = CL.extra + CL.gap; end
            end
            i = i - 1;
            end
            ::next_line::
        end
        st.vis = st.vis_n;
        st.used_h = (vrows > 0) and (vrows * lh + (CL and CL.extra or 0) + barv + pad + type_h) or 0;   -- (how tall the resting ground is: the rows still showing - none, no ground)
        imgui.PopClipRect();
        if itip then pcall(C.item_card, itip); end
        if typing then                                               -- the typing line: a dark strip, your text, a blinking caret
            local tx0, ty0 = x + pad - 4, y + h - barv - type_h - 2;
            local tw0, th0 = maxw + 8, lh + 6;
            DL.RF(dl, tx0, ty0, tx0 + tw0, ty0 + th0, U4(0.03, 0.03, 0.05, 0.75), 6);
            local tc_ = (YUI_HEX and C.GOLDH) or C.acc;           -- (Hex link: a faint gold edge)
            DL.R(dl, tx0, ty0, tx0 + tw0, ty0 + th0, U4(tc_[1], tc_[2], tc_[3], 0.35), YUI_HEX and 2 or 6, C.rall, 1);
            local c = { 1, 1, 1 };                                -- (what you type: always white, whatever channel it goes to)
            local cx = line_w(typing.before);
            local shift = math.max(0, cx - (maxw - 14));               -- long text: keep the caret in view
            C.iclip({ tx0 + 2, ty0 }, { tx0 + tw0 - 2, ty0 + th0 }, true);
            chat_line(dl, x + pad - shift, ty0 + 3, typing.text, c, 1, lh);
            if math.floor(now * 2.4) % 2 == 0 then
                local kx = x + pad - shift + cx + 1;
                DL.RF(dl, kx, ty0 + 4, kx + 2, ty0 + th0 - 4, U4(c[1], c[2], c[3], 0.95));
            end
            imgui.PopClipRect();
        end
        -- the channel buttons, only while the chat is lit up
        local thv = (cfg.chat_tabs_always and not big) and 1 or st.hv;  -- (CHAT > Always show tabs: shown at rest too)
        if n == 1 and thv > 0.05 then
            local bx, by = x + pad, y + h - barv - 2;                -- (rising from the bottom as it lights up)
            local mx, my = imgui.GetMousePos();
            local tabs_ = {};                                        -- (the Combat log tab at the end; CHAT > Tabs leaves some out)
            for ci_, ch in ipairs(CHANNELS) do if big or C.tab_on(ch[1]) then tabs_[#tabs_ + 1] = { ch, ci_ }; end end
            if big or C.tab_on('Combat') then tabs_[#tabs_ + 1] = { { 'Combat' }, C.CHAT_COMBAT }; end
            local sel_ = tonumber(cfg.chat_tab) or 1;                -- (the tab shown: a hidden one counts as All)
            if sel_ == C.CHAT_COMBAT then if not C.tab_on('Combat') then sel_ = 1; end
            elseif not (CHANNELS[sel_] and C.tab_on(CHANNELS[sel_][1])) then sel_ = 1; end
            for _, tci in ipairs(tabs_) do
                local ch, ci = tci[1], tci[2];
                local tw = imgui.CalcTextSize(ch[1]);
                local bw2 = tw + 16;
                local over = mx >= bx and mx < bx + bw2 and my >= by and my < by + bar - 4;
                local cmb = big and ci == #CHANNELS + 1;
                local on = (big and legacy.pad.combat) and cmb or (not cmb and tab == ci and not (big and legacy.pad.combat));
                if not big then on = (sel_ == ci); end
                local col = { 0.95, 0.95, 0.97 };                -- the tabs are plain white
                -- just the words (no boxes): the chosen tab bright with a short line under it, the others dimmer
                local ty_ = by + (bar - 4 - lh + 2) / 2;
                local ta = (on and 1 or (over and 0.85 or 0.5)) * thv;
                DL.T(dl, bx + 9, ty_ + 1, U4(0, 0, 0, 0.8 * ta), ch[1]);
                DL.T(dl, bx + 8, ty_, U4(col[1], col[2], col[3], ta), ch[1]);
                if on then
                    local tw_ = imgui.CalcTextSize(ch[1]);
                    local uc = YUI_HEX and (C.GOLDH or col) or col;     -- (Hex link: the chosen tab underlined in gold)
                    DL.L(dl, bx + 8, ty_ + lh - 1, bx + 8 + tw_, ty_ + lh - 1, U4(uc[1], uc[2], uc[3], 0.8 * thv), YUI_HEX and 1.4 or 1);
                end
                if unread[ci] then                                   -- new messages on this tab
                    DL.CF(dl, bx + bw2 - 3, by + 3, 3, U4(col[1], col[2], col[3], thv), 10);
                end
                imgui.SetCursorScreenPos({ bx, by });
                if imgui.InvisibleButton('##yui_ch' .. ci, { bw2, bar - 4 }) then
                    if cmb then legacy.pad.combat = true; st.scroll = 0;
                    else legacy.pad.combat = false; cfg.chat_tab = ci; unread[ci] = nil; st.scroll = 0; save(); end
                end
                bx = bx + bw2 + 6;
            end
        end
        if n == 2 and st.hv > 0.05 then                              -- the combat window says what it is
            local fs = FS;
            imgui.SetWindowFontScale(fs * 0.62);
            DL.T(dl, x + pad, y + h - imgui.GetTextLineHeight() - 8, U4(C.muted[1], C.muted[2], C.muted[3], 0.7 * st.hv), 'COMBAT LOG');
            imgui.SetWindowFontScale(fs);
        end
        unsized(pushed);
        -- the mouse wheel scrolls back; a small arrow at the bottom right jumps to the newest
        if hov then
            local wheel = imgui.GetIO().MouseWheel or 0;
            if wheel ~= 0 then st.scroll = math.max(0, math.min(#log * 2, st.scroll + math.floor(wheel * 3))); end
        end
        if st.scroll > 0 then
            imgui.SetCursorScreenPos({ x + w - 26, y + h - bar - 22 });
            if imgui.InvisibleButton('##yui_chat_end' .. n, { 20, 18 }) then st.scroll = 0; end
            local cx, cy = x + w - 16, y + h - bar - 13;
            DL.TF(dl, cx - 5, cy - 3, cx + 5, cy - 3, cx, cy + 3, U4(C.gold[1], C.gold[2], C.gold[3], 0.9));
        end
        -- resize from the top right corner (the bottom stays where it is)
        local nowc = os.clock();                                     -- (the corner icons fade 5 s after the mouse leaves; back when it's over)
        if hov or st.lastov == nil then st.lastov = nowc; end
        local gf = math.max(0, math.min(1, 1 - (nowc - st.lastov - 5) / 0.6));
        if n == 2 and gf > 0.02 and st.hv > 0.05 then                -- the anchor (the combat log's bottom right, while it's lit): beside the chat
            local bs = 22;
            local ax, ay = x + w - bs - 10, y + h - bar + (bar - bs) / 2 - 2;
            imgui.SetCursorScreenPos({ ax, ay });
            if imgui.InvisibleButton('##yui_chat_link', { bs, bs }) then   -- clicks go round: beside the chat -> on top of it (if there's room) -> free
                if not cfg.chat_link then cfg.chat_link, cfg.chat_link_v = true, false;
                elseif not cfg.chat_link_v then
                    local _, H = ALLY.screen();
                    local th_, cy_ = tonumber(cfg.chat_h) or 260, tonumber(cfg.chat_y) or 700;
                    if cy_ - th_ >= 0 or cy_ + 2 * th_ <= (H or 1080) then cfg.chat_link_v = true;   -- (room above, or under)
                    else cfg.chat_link, cfg.chat_link_v = false, false; end
                else cfg.chat_link, cfg.chat_link_v = false, false; end
                save();
            end
            local hv2 = imgui.IsItemHovered();
            if hv2 then YUI_TIP((not cfg.chat_link) and 'Anchor the combat log to the chat: beside it, the same size'
                or ((not cfg.chat_link_v) and 'Beside the chat (click: on top of it)' or 'On top of the chat (click to free it)')); end
            local on = cfg.chat_link == true;
            local c = on and { 0.86, 0.58, 1.0, (hv2 and 1 or 0.9) * gf } or { 0.62, 0.60, 0.70, (hv2 and 1 or 0.7) * gf };
            local cx, cy = ax + bs / 2, ay + bs / 2;
            local vx, vy = 5, 0;                                     -- (the two dots: side by side, or one above the other when on top)
            if on and cfg.chat_link_v then vx, vy = 0, 5; end
            if YUI_HEX then                                          -- (Hex link mode: two small hexagons, gold and azure, a dark rim each,
                local a_ = c[4];                                     --  apart - a fine gold line joins them when anchored)
                local hx_, hy_ = vx * 1.15, vy * 1.15;
                local c1_, c2_ = on and C.GOLDH or { 0.62, 0.60, 0.70 }, on and C.HEXMP[1] or { 0.62, 0.60, 0.70 };
                if on then DL.L(dl, cx - hx_, cy - hy_, cx + hx_, cy + hy_, U4(C.GOLDH2[1], C.GOLDH2[2], C.GOLDH2[3], 0.55 * a_), 1); end
                for _, q in ipairs({ { -1, c1_ }, { 1, c2_ } }) do
                    local px_, py_ = cx + q[1] * hx_, cy + q[1] * hy_;
                    C.hexdot(dl, px_, py_, 4.4, U4(0.05, 0.045, 0.07, 0.85 * a_));
                    C.hexdot(dl, px_, py_, 3.4, U4(q[2][1], q[2][2], q[2][3], a_));
                end
            else
                if on then DL.L(dl, cx - vx, cy - vy, cx + vx, cy + vy, u32(c), 2.2); end
                DL.CF(dl, cx - vx, cy - vy, 3.3, u32(c), 12);
                DL.CF(dl, cx + vx, cy + vy, 3.3, u32(c), 12);
            end
        end
        if not cfg.locked and not big then                           -- (the big chat has no resize grip)
            imgui.SetCursorScreenPos({ x + w - 24, y });
            imgui.InvisibleButton('##yui_chat_size' .. n, { 24, 24 });
            local act = imgui.IsItemActive();
            if st.hv > 0.05 and gf > 0.02 then
                -- the grip: a small dot in the corner, a soft halo round it, a little bigger under the mouse
                local on = act or imgui.IsItemHovered();
                local k = st.hv * (on and 1 or 0.6) * gf;
                local cx, cy = x + w - 9, y + 9;
                local r = on and 3.6 or 3;
                local g1, g2 = C.hp, C.hp2;
                if YUI_HEX then g1, g2 = C.GOLDH or g1, C.GOLDH or g2; end   -- (Hex link: gold, not pink)
                DL.CF(dl, cx, cy, r + 3, U4(g2[1], g2[2], g2[3], 0.18 * k), 20);
                DL.CF(dl, cx, cy, r, U4(g1[1], g1[2], g1[3], 0.85 * k), 16);
            end
            if act then
                local dx, dy = imgui.GetMouseDragDelta(0);
                if dx ~= 0 or dy ~= 0 then
                    local nw, nh = math.max(200, w + dx), math.max(80, h - dy);
                    cfg[p .. 'w'], cfg[p .. 'h'] = nw, nh;
                    imgui.SetWindowPos({ x, y + (h - nh) });
                    if cfg.chat_link and cfg.chat_split and n == 2 then -- (anchored: resizing the combat log resizes the chat too, its bottom kept)
                        cfg.chat_y = (tonumber(cfg.chat_y) or 700) + ((tonumber(cfg.chat_h) or 260) - nh);
                        cfg.chat_w, cfg.chat_h = nw, nh;
                        cw[1].relink = true;
                    end
                    imgui.ResetMouseDragDelta(0);
                end
            end
        end
        local wx, wy = imgui.GetWindowPos();
        if not big then                                              -- (the big chat's place is never kept)
            cfg[p .. 'x'], cfg[p .. 'y'] = wx, wy;
            do                                                       -- (always on the screen)
                local nx, ny, moved = YUI_ONSCREEN(wx, wy, tonumber(cfg[p .. 'w']) or w, tonumber(cfg[p .. 'h']) or h);
                if moved then cfg[p .. 'x'], cfg[p .. 'y'] = nx, ny; st.relink = true; end
            end
            local key = string.format('%d,%d,%d,%d', math.floor(wx), math.floor(wy), math.floor(cfg[p .. 'w']), math.floor(cfg[p .. 'h']));
            if st.saved == nil then st.saved = key; end
            if key ~= st.saved and not imgui.IsMouseDown(0) then st.saved = key; save(); end
        end
    end
    imgui.End();
    imgui.PopStyleVar(2);
end

----------------------------------------------------------------------------------------------------
-- EXP bar: job and level, the experience (or limit points when they're on), a thin living bar in a soft yellow,
-- and at its right your gil (with what you've made since logging in) and your bag as a grid of little slots
----------------------------------------------------------------------------------------------------
local gil_start = nil;
local function commas(n)
    local s = tostring(math.floor(n or 0));
    local neg = s:sub(1, 1) == '-';
    if neg then s = s:sub(2); end
    s = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '');
    return (neg and '-' or '') .. s;
end
local function outlined(dl, tx, ty, s, col)
    local oc = U4(0, 0, 0, 0.9 * (col[4] or 1));
    for _, o in ipairs(OUTLINE) do DL.T(dl, tx + o[1], ty + o[2], oc, s); end
    DL.T(dl, tx, ty, u32(col), s);
end
-- the first time, each one is placed near the bottom middle of the screen (then they go wherever you drag them)
local function first_place(kx, ky, dx, dy)
    if (tonumber(cfg[kx]) or -1) >= 0 then return; end
    local ds = imgui.GetIO().DisplaySize;
    local dw, dh = (ds and ds.x) or 1920, (ds and ds.y) or 1080;
    cfg[kx], cfg[ky] = math.floor(dw / 2 + dx), math.floor(dh + dy);
end
local GOLD = { 1.00, 0.90, 0.58 };
-- The fan and the cast line in windows of their own, when they're placed anywhere (TARGET > Skillchain fan / Enemy
-- cast: "Anywhere"): drag them, or place them in Edit Mode. They show only while there's something in them.
function FIGHT.fsc() return math.max(0.4, math.min(2.0, tonumber(cfg.fan_scale) or 1)); end   -- the fan's own size
function FIGHT.win()
    if cfg.fight_info == false or not cfg.target then return; end
    if (cfg.fan_place or 'bar') ~= 'free' and (cfg.ecast_place or 'bar') ~= 'free' then return; end
    local idx = target_index();
    local sid;
    if idx == nil or idx == 0 then
        if not (EDIT.on or FIGHT.show) then return; end
        sid = -1; pcall(FIGHT.preview);
    else
        sid = AshitaCore:GetMemoryManager():GetEntity():GetServerId(idx);
        pcall(FIGHT.showing, sid);
    end
    local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.target_scale) or 1);
    local tw = (tonumber(cfg.target_w) or 520) * sc;
    local th = math.max(1, math.floor((tonumber(cfg.target_bar_h) or 4) * sc + 0.5));
    if (cfg.fan_place or 'bar') == 'free' and cfg.target_fx ~= 'link' and FIGHT.sc[sid] and not FIGHT.sc[sid].closed then
        first_place('fan_x', 'fan_y', -700, -640);
        if plain_window('YunaUI Skillchain##yui_fan', 'fan_x', 'fan_y') then
            local dl = imgui.GetWindowDrawList();
            local x, y = imgui.GetCursorScreenPos();
            local fsc = sc * FIGHT.fsc();                            -- (TARGET > Skillchain fan size)
            local fw, fh = FIGHT.fan_size(fsc);
            local drop = (cfg.fan_layout or 'fan') == 'drop';
            FIGHT.draw_fan(dl, sid, x + fw - 14 * fsc, drop and (y + 16 * fsc) or (y + fh / 2), fsc);
            imgui.Dummy({ fw, fh });
            end_plain('fan_x', 'fan_y');
        else imgui.End(); imgui.PopStyleVar(2); end
    end
    if (cfg.ecast_place or 'bar') == 'free' and cfg.target_fx ~= 'link' and FIGHT.casts[sid] then
        first_place('ecast_x', 'ecast_y', -tw / 2, -560);
        if plain_window('YunaUI Enemy cast##yui_ecast', 'ecast_x', 'ecast_y') then
            local dl = imgui.GetWindowDrawList();
            local x, y = imgui.GetCursorScreenPos();
            local used = FIGHT.draw_cast(dl, sid, x + 4, y + 2, tw, sc, th);
            imgui.Dummy({ tw + 8, math.max(10, (used or 0) + 4) });
            end_plain('ecast_x', 'ecast_y');
        else imgui.End(); imgui.PopStyleVar(2); end
    end
end
-- BARS > EXP BAR: the ring. A picture of 40 glowing dashes, pink at the top turning violet (images/exp_ring.png, made
-- from the user's own design), drawn in 40 slices: each dash lit or faint by how far the experience has got.
-- Beside it: the jobs, the points and the % in pink.
C.RING = { n = 40, mid = 0.435, r1 = 0.355, r2 = 0.5 };             -- (in the picture: the dashes' middle, the slices' inner and outer edge)
function C.exp_ring(sc, v, job, label)
    if not plain_window('YunaUI Exp##yui_exp', 'exp_x', 'exp_y') then imgui.End(); imgui.PopStyleVar(2); return; end
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    x, y = x + 10, y + 10;
    local G = C.RING;
    local R = 36 * sc;                                               -- the dashes' middle on screen
    local S_ = R / G.mid;                                            -- (the whole picture's size on screen)
    local half = S_ * G.r2;
    local cx, cy = math.floor(x + half) + 0.5, math.floor(y + half) + 0.5;
    local px = math.max(16, math.min(1024, math.floor(S_ + 0.5)));
    local t = C.tex_at('exp_ring.png', px) or tex('exp_ring.png');   -- (made at the size it's drawn: sharp)
    local head = v * G.n;
    if YUI_HEX then                                                  -- (Hex link mode: a clean hexagon - a dark track, the experience
        local function V(j) local a_ = -math.pi / 2 + j * math.pi / 3; return cx + math.cos(a_) * R, cy + math.sin(a_) * R; end   --  as one gold line round it, clockwise from the top)
        local pts = {};
        for j = 0, 5 do local vx, vy = V(j); pts[#pts + 1] = { vx, vy }; end
        pcall(function() dl:AddConvexPolyFilled(pts, U4(0, 0, 0, 0.42)); end);   -- (a soft dark inside: the % reads on any ground)
        local tw_ = 4.5 * sc;
        for j = 0, 5 do                                              -- (the track)
            local ax, ay = V(j); local bx_, by_ = V(j + 1);
            DL.L(dl, ax, ay, bx_, by_, U4(0, 0, 0, 0.65), tw_ + 2.5);
            DL.L(dl, ax, ay, bx_, by_, U4(1, 1, 1, 0.10), tw_);
        end
        local g1, g2 = C.HEXHP[2], C.GOLDH2;
        local function gc(f, al) return U4(g1[1] + (g2[1] - g1[1]) * f, g1[2] + (g2[2] - g1[2]) * f, g1[3] + (g2[3] - g1[3]) * f, al); end
        local U = math.max(0, math.min(1, v)) * 6;
        for pass = 1, 2 do                                           -- (a glow, then the line)
            for j = 0, 5 do
                if U > j then
                    local ax, ay = V(j); local bx_, by_ = V(j + 1);
                    local e = math.min(1, U - j);
                    local ex, ey = ax + (bx_ - ax) * e, ay + (by_ - ay) * e;
                    local f0, f1 = j / 6, (j + e) / 6;
                    if pass == 1 then DL.L(dl, ax, ay, ex, ey, gc(f1, 0.22), tw_ * 2.4);
                    else
                        DL.L(dl, ax, ay, ex, ey, gc((f0 + f1) / 2, 1), tw_);
                        DL.CF(dl, ax, ay, tw_ / 2, gc(f0, 1), 10);   -- (the corners joined)
                    end
                end
            end
        end
        t = nil;
    end
    if t then
        local step = math.pi * 2 / G.n;
        for k = 0, G.n - 1 do
            local a0 = -math.pi / 2 + (k - 0.5) * step;
            local a1 = a0 + step;
            local c0, s0, c1, s1 = math.cos(a0), math.sin(a0), math.cos(a1), math.sin(a1);
            local function P(cc, ss, r) return { cx + cc * r * S_, cy + ss * r * S_ }; end
            local function U(cc, ss, r) return { 0.5 + cc * r, 0.5 + ss * r }; end
            local on = (k + 1) <= head + 0.001;
            pcall(function()
                dl:AddImageQuad(t.ptr, P(c0, s0, G.r1), P(c0, s0, G.r2), P(c1, s1, G.r2), P(c1, s1, G.r1),
                    U(c0, s0, G.r1), U(c0, s0, G.r2), U(c1, s1, G.r2), U(c1, s1, G.r1), U4(1, 1, 1, on and 1 or 0.14));
            end);
        end
    end
    local L = half - R;                                              -- (for the layout below: from the dashes' middle to the edge)
    do                                                               -- the % in the middle of the ring, in pink
        local pp = sized('chat', 17 * sc);                           -- (small: it sits well inside the dashes)
        local ps = C.exp_mid or string.format('%d%%', math.floor(v * 100));   -- (at 75: your merits)
        local pw = tonumber((imgui.CalcTextSize(ps))) or 0;
        local ph = imgui.GetTextLineHeight();                        -- (the line's height: CalcTextSize gives only the width here)
        outlined(dl, math.floor(cx - pw / 2 + 0.5), math.floor(cy - ph / 2 + 0.5), ps, YUI_HEX and { C.GOLDH2[1], C.GOLDH2[2], C.GOLDH2[3], 1 } or { 1.00, 0.62, 0.80, 1 });
        unsized(pp);
    end
    -- beside it, with room: the jobs, the points, the % in pink
    local tsc = (tonumber(cfg.scale) or 1) * math.max(0.5, math.min(2.5, tonumber(cfg.exp_text) or 1));   -- BARS > EXP BAR > Text size
    local pushed = sized('chat', 20 * tsc);
    local lh = imgui.GetTextLineHeight();
    local gap = 6 * tsc;
    local tx = cx + R + L + 24 * sc;
    local ty = cy - (lh * 2 + gap) / 2;                              -- (two lines beside it: the % is inside the ring)
    outlined(dl, tx, ty, job, { 0.97, 0.96, 0.98, 1 });
    outlined(dl, tx, ty + lh + gap, label, { 0.84, 0.83, 0.88, 1 });
    local tw = math.max(imgui.CalcTextSize(job), imgui.CalcTextSize(label));
    unsized(pushed);
    imgui.Dummy({ (tx - x) + tw + 20, math.max(R * 2 + L * 2, lh * 2 + gap) + 20 });
    end_plain('exp_x', 'exp_y');
end
-- your jobs and experience (or limit points), for the map hub: nil when there's no character
-- EXP / merits: the job at 75 or more - its real level, not the synced one (a level sync party lowers GetMainJobLevel;
-- the game's own per-job level keeps the real one)
function C.lv75(pl, lvl)
    if (tonumber(lvl) or 0) >= 75 then return true; end
    local ok, real = pcall(function() return pl:GetJobLevel(pl:GetMainJob() or 0); end);
    return ok and (tonumber(real) or 0) >= 75 or false;
end
function C.expinfo()
    local pl = AshitaCore:GetMemoryManager():GetPlayer();
    if pl == nil or (pl:GetMainJob() or 0) == 0 then return nil; end
    local mj, lvl, sub, sublvl = pl:GetMainJob(), pl:GetMainJobLevel() or 0, pl:GetSubJob() or 0, pl:GetSubJobLevel() or 0;
    local cur, need = pl:GetExpCurrent() or 0, pl:GetExpNeeded() or 1;
    local limit = (pl.GetIsLimitModeEnabled and pl:GetIsLimitModeEnabled()) and C.lv75(pl, lvl);
    local label, v;
    if limit then
        local lp, mp, mpx = pl:GetLimitPoints() or 0, pl:GetMeritPoints() or 0, pl:GetMeritPointsMax() or 0;
        label, v = string.format('LIMIT %s / 10,000   MERITS %d/%d', commas(lp), mp, mpx), lp / 10000;
    else
        label, v = string.format('EXP %s / %s', commas(cur), commas(need)), (need > 0) and (cur / need) or 0;
        if C.lv75(pl, lvl) then label = string.format('MERITS %d/%d', pl:GetMeritPoints() or 0, pl:GetMeritPointsMax() or 0); end   -- (capped: your merits instead)
    end
    local rest = tostring(lvl) .. ((JOBS[sub] and sublvl > 0) and ('  /  ' .. JOBS[sub] .. ' ' .. sublvl) or '');
    local tc = ALLY.tagcol(mj);                                      -- (the job's tag in its colour, as in the party list)
    return { v = math.max(0, math.min(1, v)), label = label, tag = JOBS[mj] or '?', rest = rest, col = tc[1], ink = tc[2] };
end
function C.gil_read()
    local gil = 0;
    pcall(function() local it = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, 0); gil = (it and it.Count) or 0; end);
    if gil_start == nil and gil > 0 then gil_start = gil; end
    return gil;
end
function C.gil_diff(gil)                                             -- what just changed: changes close together add up (+500, +500 = +1,000);
    local G = C.GIL or {};                                           --  shown 8 s, then it fades. Gives the change and its alpha.
    C.GIL = G;
    local now = os.clock();
    if G.prev == nil and gil > 0 then G.prev, G.base, G.t = gil, gil, -99; end
    if G.prev and gil ~= G.prev then
        if now - G.t > 9.5 then G.base = G.prev; end                 -- (the last one had faded: a new count)
        G.prev, G.t = gil, now;
    end
    local ga = math.max(0, math.min(1, 1 - (now - (G.t or -99) - 8) / 1.5));
    return (ga > 0 and G.base) and (gil - G.base) or 0, ga;
end
local function draw_exp(dt)
    if not cfg.expbar then return; end
    if YMAP and YMAP.hub_on and YMAP.hub_on() then return; end      -- (MINIMAP > EXP, gil and bag on the map: shown there)
    if YMAP and YMAP.dock_on and YMAP.dock_on() then return; end    -- (docked to the minimap: Visor / Capsule)
    local pl = AshitaCore:GetMemoryManager():GetPlayer();
    if pl == nil or (pl:GetMainJob() or 0) == 0 then return; end
    local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.exp_scale) or 1);
    first_place('exp_x', 'exp_y', -(tonumber(cfg.exp_w) or 520) * sc / 2, -110);
    local lvl, sub, sublvl = pl:GetMainJobLevel() or 0, pl:GetSubJob() or 0, pl:GetSubJobLevel() or 0;
    local cur, need = pl:GetExpCurrent() or 0, pl:GetExpNeeded() or 1;
    local limit = (pl.GetIsLimitModeEnabled and pl:GetIsLimitModeEnabled()) and C.lv75(pl, lvl);
    local label, v;
    if limit then
        local lp, mp, mpx = pl:GetLimitPoints() or 0, pl:GetMeritPoints() or 0, pl:GetMeritPointsMax() or 0;
        label, v = string.format('LIMIT %s / 10,000   MERITS %d/%d', commas(lp), mp, mpx), lp / 10000;
    else
        label, v = string.format('EXP %s / %s', commas(cur), commas(need)), (need > 0) and (cur / need) or 0;
    end
    C.exp_mid = nil;
    if C.lv75(pl, lvl) and not limit then                                  -- (capped: your merits instead - in the ring, which fills with them)
        local mp, mpx = pl:GetMeritPoints() or 0, pl:GetMeritPointsMax() or 0;
        label, v, C.exp_mid = 'MERITS', (mpx > 0) and (mp / mpx) or 0, string.format('%d/%d', mp, mpx);
    end
    v = math.max(0, math.min(1, v));
    local job = (JOBS[pl:GetMainJob()] or '?') .. ' ' .. lvl .. ((JOBS[sub] and sublvl > 0) and (' / ' .. JOBS[sub] .. ' ' .. sublvl) or '');
    do return C.exp_ring(sc, v, job, label); end                     -- (the ring: the old bar look is gone)
    if plain_window('YunaUI Exp##yui_exp', 'exp_x', 'exp_y') then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        x, y = x + 8, y + 6;
        local w = (tonumber(cfg.exp_w) or 520) * sc;
        local pushed = sized('chat', 15 * sc);
        local lh = imgui.GetTextLineHeight();
        local bh = math.max(3, math.floor(4 * sc));
        local by = y + 4 * sc;
        glow_bar(dl, x, by, w, bh, v, nil, { 1.00, 0.95, 0.74 }, { 0.95, 0.76, 0.34 }, 3.3);
        local ty = by + bh + 6 * sc;
        outlined(dl, x, ty, job, { 0.95, 0.95, 0.97, 1 });
        local pct = string.format('%d%%', math.floor(v * 100));
        local pw, lw = imgui.CalcTextSize(pct), imgui.CalcTextSize(label);
        outlined(dl, x + w - pw, ty, pct, { GOLD[1], GOLD[2], GOLD[3], 1 });
        outlined(dl, x + w - pw - 10 * sc - lw, ty, label, { 0.82, 0.82, 0.88, 1 });
        unsized(pushed);
        imgui.Dummy({ w + 16, ty + lh - y + 10 });
        end_plain('exp_x', 'exp_y');
    else
        imgui.End(); imgui.PopStyleVar(2);
    end
end
-- Gil: a little coin and the amount
local function draw_gil()
    if not cfg.gil then return; end
    if YMAP and YMAP.hub_on and YMAP.hub_on() then C.gil_diff(C.gil_read()); return; end   -- (shown on the map hub)
    if YMAP and YMAP.dock_on and YMAP.dock_on() then return; end    -- (docked to the minimap: Visor / Capsule)
    local gil = 0;
    pcall(function() local it = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, 0); gil = (it and it.Count) or 0; end);
    if gil_start == nil and gil > 0 then gil_start = gil; end
    local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.gil_scale) or tonumber(cfg.gb_scale) or 1);   -- BARS > GIL > Size
    first_place('gil_x', 'gil_y', 300, -112);
    if plain_window('YunaUI Gil##yui_gil', 'gil_x', 'gil_y') then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        x, y = x + 6, y + 6;
        local pushed = sized('chat', 16 * sc);
        local lh = imgui.GetTextLineHeight();
        local cr = 7 * sc;
        local ccx, ccy = x + cr, y + lh / 2;
        DL.CF(dl, ccx, ccy, cr + 2, U4(0.95, 0.76, 0.34, 0.18), 20);
        DL.CF(dl, ccx, ccy, cr, U4(0.86, 0.66, 0.24, 1), 20);
        DL.CF(dl, ccx, ccy, cr * 0.68, U4(1, 0.88, 0.50, 1), 20);
        DL.C(dl, ccx, ccy, cr, U4(0, 0, 0, 0.7), 20, 1);
        local gs = commas(gil);
        outlined(dl, x + cr * 2 + 6 * sc, y, gs, { GOLD[1], GOLD[2], GOLD[3], 1 });
        local gw = imgui.CalcTextSize(gs);
        local h2 = lh;
        do                                                           -- what just changed, under it: green +, pink -; 8 s, then it fades
            local diff, ga = C.gil_diff(gil);
            if diff ~= 0 then
                local fs = FS;
                imgui.SetWindowFontScale(fs * 0.8);
                outlined(dl, x + cr * 2 + 6 * sc, y + lh, (diff > 0 and '+' or '') .. commas(diff), diff > 0 and { 0.55, 1, 0.65, ga } or { 1, 0.5, 0.65, ga });
                h2 = lh + imgui.GetTextLineHeight();
                imgui.SetWindowFontScale(fs);
            end
        end
        unsized(pushed);
        imgui.Dummy({ cr * 2 + 6 * sc + gw + 16, h2 + 12 });
        end_plain('gil_x', 'gil_y');
    else
        imgui.End(); imgui.PopStyleVar(2);
    end
end
-- Bag: the count over a single row of 20 little blocks (each a share of the bag), blue to violet as it fills,
-- pink when it's nearly full
local function draw_bag()
    if not cfg.bag then return; end
    if YMAP and YMAP.hub_on and YMAP.hub_on() then return; end      -- (shown on the map hub)
    if YMAP and YMAP.dock_on and YMAP.dock_on() then return; end    -- (docked to the minimap: Visor / Capsule)
    local used, max = 0, 0;
    pcall(function() local inv = AshitaCore:GetMemoryManager():GetInventory(); used, max = inv:GetContainerCount(0) or 0, inv:GetContainerCountMax(0) or 0; end);
    if max <= 0 then return; end
    local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.gb_scale) or 1);
    first_place('bag_x', 'bag_y', 470, -120);
    if plain_window('YunaUI Bag##yui_bag', 'bag_x', 'bag_y') then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        x, y = x + 6, y + 4;
        local style = cfg.bag_style or 'row';
        local n = 20;
        local cs, gap = math.max(4, math.floor(8 * sc)), math.max(2, math.floor(3 * sc));
        local gcols = 10;                                            -- grid / dots: one cell per slot, 10 a row
        local gs, gg = math.max(3, math.floor(7 * sc)), math.max(1, math.floor(2 * sc));
        local w = (style == 'grid' or style == 'dots') and (gcols * (gs + gg) - gg) or (n * (cs + gap) - gap);
        local full = used >= max - 5;
        local pushed = sized('chat', 19 * sc);
        local lh = imgui.GetTextLineHeight();
        local cnt = string.format('%d/%d', used, max);
        local cw = imgui.CalcTextSize(cnt);
        outlined(dl, x + w - cw, y, cnt, full and { 1, 0.6, 0.78, 1 } or { 0.92, 0.92, 0.96, 1 });
        unsized(pushed);
        local by = y + lh + 4 * sc;
        local function slot_col(f)
            if full then return { C.hp[1], C.hp[2], C.hp[3], 1 }; end
            return { C.mp[1] + (C.mp2[1] - C.mp[1]) * f, C.mp[2] + (C.mp2[2] - C.mp[2]) * f, C.mp[3] + (C.mp2[3] - C.mp[3]) * f, 1 };
        end
        local bottom = by + cs;
        if style == 'grid' or style == 'dots' then
            -- every slot its own little square (or dot), full ones lit
            local rows = math.ceil(max / gcols);
            for k = 0, max - 1 do
                local r, c = math.floor(k / gcols), k % gcols;
                local sx, sy = x + c * (gs + gg), by + r * (gs + gg);
                local on = k < used;
                local col = on and slot_col(c / (gcols - 1)) or { 0.32, 0.33, 0.38, 0.55 };
                if style == 'dots' then
                    if on then DL.CF(dl, sx + gs / 2, sy + gs / 2, gs / 2 + 1, U4(col[1], col[2], col[3], 0.2), 10); end
                    DL.CF(dl, sx + gs / 2, sy + gs / 2, gs / 2, u32(col), 10);
                else
                    DL.RF(dl, sx, sy, sx + gs, sy + gs, u32(col), 1);
                end
            end
            bottom = by + rows * (gs + gg) - gg;
            n = 0;
        elseif style == 'bar' then
            -- a thin living bar like the others
            local f = used / max;
            if YUI_HEX then                                          -- (Hex link: a hex bar - azure, red when nearly full)
                local c1, c2 = C.HEXMP[3], C.HEXMP[2];
                if full then c1, c2 = C.CLAIMCOL.mine[2], C.CLAIMCOL.mine[1]; end
                local bh_ = math.max(3, math.floor(4 * sc));
                C.hexbar(dl, x, by + 2, w, bh_, f, f, 0.3, { c1 = c1, c2 = c2, band = bh_ * 2 });
            else
                glow_bar(dl, x, by + 2, w, math.max(3, math.floor(4 * sc)), f, nil, full and C.hp or C.mp, full and C.hp2 or C.mp2, 7.7);
            end
            bottom = by + 8 * sc;
            n = 0;
        end
        local filled = math.ceil(used / max * n - 0.001);
        for k = 0, n - 1 do
            local bx = x + k * (cs + gap);
            if k < filled then
                local f = k / (n - 1);
                local col = full and { C.hp[1], C.hp[2], C.hp[3], 1 }
                    or { C.mp[1] + (C.mp2[1] - C.mp[1]) * f, C.mp[2] + (C.mp2[2] - C.mp[2]) * f, C.mp[3] + (C.mp2[3] - C.mp[3]) * f, 1 };
                DL.RF(dl, bx - 1, by - 1, bx + cs + 1, by + cs + 1, U4(col[1], col[2], col[3], 0.18), 2);
                DL.RF(dl, bx, by, bx + cs, by + cs, u32(col), 1.5);
                DL.L(dl, bx + 1, by + 1, bx + cs - 1, by + 1, U4(1, 1, 1, 0.35), 1);
            else
                DL.RF(dl, bx, by, bx + cs, by + cs, U4(0.32, 0.33, 0.38, 0.55), 1.5);
            end
        end
        imgui.Dummy({ w + 14, bottom - y + 10 });
        end_plain('bag_x', 'bag_y');
    else
        imgui.End(); imgui.PopStyleVar(2);
    end
end

-- Paper doll (EQUIP > Look: Paper doll): your 16 equipment slots, each just the item's icon (no body, no square) (HQ / +1 items get the sketchy circle). Drag a slot to put it anywhere;
-- drag the empty space round the body to move the whole doll. Hover a slot for the item's name.
----------------------------------------------------------------------------------------------------
-- slot: { name, where it starts on the body (0..1 across, 0..1 down) }
local DOLL_SLOTS = {
    [0] = { 'Main', 0.06, 0.47 }, [1] = { 'Sub', 0.94, 0.47 }, [2] = { 'Range', 0.80, 0.16 }, [3] = { 'Ammo', 0.95, 0.31 },
    [4] = { 'Head', 0.50, 0.065 }, [5] = { 'Body', 0.50, 0.33 }, [6] = { 'Hands', 0.16, 0.62 }, [7] = { 'Legs', 0.50, 0.70 },
    [8] = { 'Feet', 0.50, 0.92 }, [9] = { 'Neck', 0.50, 0.195 }, [10] = { 'Waist', 0.50, 0.51 }, [11] = { 'Ear 1', 0.30, 0.11 },
    [12] = { 'Ear 2', 0.70, 0.11 }, [13] = { 'Ring 1', 0.10, 0.75 }, [14] = { 'Ring 2', 0.90, 0.75 }, [15] = { 'Back', 0.84, 0.62 },
};
local item_icons = {};
local function item_icon(id)
    if id == nil or id == 0 or id == 65535 then return nil; end
    if item_icons[id] ~= nil then return item_icons[id] or nil; end
    item_icons[id] = false;
    pcall(function()
        local it = AshitaCore:GetResourceManager():GetItemById(id);
        if it == nil or it.Bitmap == nil or (it.ImageSize or 0) <= 0 then return; end
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        if ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), it.Bitmap, it.ImageSize, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
                ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, ptr) == ffi.C.S_OK then
            local t = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
            item_icons[id] = { tex = t, ptr = tonumber(ffi.cast('uint32_t', t)) };
        end
    end);
    return item_icons[id] or nil;
end
local function equipped(slot)                                       -- the item id in a slot, and its name
    local id, name = nil, nil;
    pcall(function()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local e = inv:GetEquippedItem(slot);
        if e == nil or (e.Index or 0) == 0 then return; end
        local idx, cont = bit.band(e.Index, 0x00FF), bit.rshift(bit.band(e.Index, 0xFF00), 8);
        local it = inv:GetContainerItem(cont, idx);
        if it and it.Id and it.Id ~= 0 and it.Id ~= 65535 then
            id = it.Id;
            local r = AshitaCore:GetResourceManager():GetItemById(id);
            name = r and r.Name and r.Name[1] or nil;
        end
    end);
    return id, name;
end
local DOLL = { drag = nil, items = {}, at = 0, prev = {}, hit = {} };
-- The equipment as a rune circle (EQUIP > Look: Diamond ring): your 16 slots in violet-edged diamonds round a dark
-- circle with the Violet Portal (the user's animated clip) in the middle, a thin line from the circle to each diamond.
-- Drag anywhere on it to move it all (the diamonds keep their places in the circle).
-- the same slots at the same angles as the wheel (range, main, sub, ammo on top; neck, ears, rings right; back, waist
-- below; feet up to head on the left)
local RING_ORDER = { { 2, -123.75 }, { 0, -101.25 }, { 1, -78.75 }, { 3, -56.25 }, { 9, -33.75 }, { 11, -11.25 }, { 12, 11.25 },
    { 13, 33.75 }, { 14, 56.25 }, { 15, 78.75 }, { 10, 101.25 }, { 8, 123.75 }, { 7, 146.25 }, { 6, 168.75 }, { 5, 191.25 }, { 4, 213.75 } };
local function quad_fill(dl, a, b, c, d, col) dl:AddTriangleFilled(a, b, c, col); dl:AddTriangleFilled(a, c, d, col); end
local function quad_line(dl, a, b, c, d, col, th)
    dl:AddLine(a, b, col, th); dl:AddLine(b, c, col, th); dl:AddLine(c, d, col, th); dl:AddLine(d, a, col, th);
end
local function draw_doll()
    if (cfg.equip_look or 'wheel') ~= 'doll' then return; end
    local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.doll_scale) or 1);
    local S = math.floor((tonumber(cfg.doll_slot) or 34) * sc);       -- the item icon's size
    local hd = S * 0.85;                                              -- half the diamond's diagonal
    local R = (tonumber(cfg.ring_radius) or 175) * sc;                -- how far out the diamonds sit
    local cr = (tonumber(cfg.center_size) or 1.3) * 38 * sc;          -- the centre circle's radius
    local half = R + hd + 8 * sc;
    first_place('doll_x', 'doll_y', 260, -560);
    if plain_window('YunaUI Doll##yui_doll', 'doll_x', 'doll_y') then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        local cx, cy = x + half, y + half;
        local now = os.clock();
        local V = { 0.62, 0.45, 1.00 };                               -- the violet
        local pos = (type(cfg.ring_pos) == 'table') and cfg.ring_pos or {};
        -- where each slot is (its default spot on the circle, or where you dragged it)
        local spots = {};
        for _, so in ipairs(RING_ORDER) do
            local slot = so[1];
            local a = math.rad(so[2]);
            local ux, uy = math.cos(a), math.sin(a);
            spots[slot] = { cx + ux * R, cy + uy * R, ux, uy };
        end
        -- the centre: the animated portal (its size and colour strength are settings), dark only inside its void
        local pr = cr * 1.35;
        for q = 0, 5 do                                              -- the void: dark, with a soft edge
            DL.CF(dl, cx, cy, pr * (0.30 - q * 0.02), U4(0.02, 0.01, 0.04, 0.12 + q * 0.14), 40);
        end
        local ptex = tex(string.format('portal/%03d.png', math.floor(now * 15) % 115));   -- a seamless loop
        local ps = tonumber(cfg.portal_strength) or 1;               -- above 1: drawn again on top, more vivid
        while ps > 0.01 do
            image(dl, ptex, cx - pr, cy - pr, cx + pr, cy + pr, { 1, 1, 1, math.min(1, ps) });
            ps = ps - 1;
        end
        -- the diamonds
        local hovered = nil;
        for _, so in ipairs(RING_ORDER) do
            local slot = so[1];
            local sp = spots[slot];
            local sx, sy = sp[1], sp[2];
            -- (the diamonds stay in their circle; the whole thing moves when you drag anywhere on it)
            local mxp, myp = imgui.GetMousePos();
            local hov = imgui.IsWindowHovered() and (math.abs(mxp - sx) + math.abs(myp - sy) <= hd);
            if hov then hovered = slot; end
            local top, rgt, bot, lft = { sx, sy - hd }, { sx + hd, sy }, { sx, sy + hd }, { sx - hd, sy };
            for g = 3, 1, -1 do                                      -- a soft violet glow round it
                local k = g * 1.6 * sc;
                quad_fill(dl, { sx, sy - hd - k }, { sx + hd + k, sy }, { sx, sy + hd + k }, { sx - hd - k, sy }, U4(V[1], V[2], V[3], 0.05));
            end
            quad_fill(dl, top, rgt, bot, lft, U4(0.05, 0.04, 0.09, 0.82));
            quad_line(dl, top, rgt, bot, lft, U4(V[1], V[2], V[3], hov and 1 or 0.8), 1.5);
            local ih = hd - 3 * sc;                                  -- a thin inner line
            quad_line(dl, { sx, sy - ih }, { sx + ih, sy }, { sx, sy + ih }, { sx - ih, sy }, U4(1, 1, 1, 0.08), 1);
            if os.clock() >= DOLL.at then DOLL.items[slot] = { equipped(slot) }; end   -- looked up twice a second
            local it_ = DOLL.items[slot] or {};
            local id, name = it_[1], it_[2];
            local was = DOLL.prev[slot];                             -- a swap: item -> another item (not login / zoning)
            if type(was) == 'number' and id and id ~= was then DOLL.hit[slot] = os.clock(); end
            if id then DOLL.prev[slot] = id; end
            local nm = DOLL_SLOTS[slot][1];
            if id then
                local isz = hd * 0.95;                               -- the biggest square that fits inside the diamond
                image(dl, (YUI_EQ_ICON or item_icon)(id), sx - isz / 2, sy - isz / 2, sx + isz / 2, sy + isz / 2);
                if hov then YUI_TIP(nm .. ': ' .. (name or '?')); end
            elseif hov then YUI_TIP(nm .. ': (empty)'); end
            local ht = DOLL.hit[slot];
            if ht then                                               -- the swap burst, on top of everything
                local k = math.floor((now - ht) * 30);
                if k >= 44 then DOLL.hit[slot] = nil;
                else
                    local fl = dl;
                    pcall(function() fl = imgui.GetForegroundDrawList() or dl; end);
                    local r = S * 1.4;
                    image(fl, tex(string.format('hit/%02d.png', k)), sx - r, sy - r, sx + r, sy + r);
                end
            end
        end
        if os.clock() >= DOLL.at then DOLL.at = os.clock() + 0.5; end
        if DOLL.drag and not imgui.IsMouseDown(0) then DOLL.drag = nil; save(); end
        imgui.SetCursorScreenPos({ x, y });
        imgui.Dummy({ half * 2, half * 2 });
        end_plain('doll_x', 'doll_y');
    else
        imgui.End(); imgui.PopStyleVar(2);
    end
end

-- The equipment as a slim strip (EQUIP > Look: Strip): your 16 slots in two rows of 8 (the game's own equipment order),
-- no frames, under your MP (or HP / TP) bar and as wide as it. Dimmed while nothing happens; a gear swap lights it up
-- for a moment with a soft glow on each slot that changed. Hover it to see it all, hover an icon for the item's name.
DOLL.STRIP = { 0, 1, 2, 3, 4, 9, 11, 12, 5, 6, 13, 14, 15, 10, 7, 8 };
-- the swap effects (FootageCrate clips cut to small frames): size is how many icons wide it's drawn
DOLL.SWAP_FX = {
    muzzle = { dir = 'swap_muzzle', n = 20, fps = 30, size = 2.2, aspect = 1 },               -- Scifi Muzzle Flash 1
    swirl = { dir = 'swap_swirl', n = 44, fps = 30, size = 2.6, aspect = 108 / 256 },         -- Anime Auras: Swirly Lines
    lightning = { dir = 'swap_lightning', n = 23, fps = 24, size = 2.2, aspect = 1 },         -- Super Lightning Wall 10
    spell9 = { dir = 'swap_spell9', n = 24, fps = 30, size = 2.0, aspect = 1 },               -- Magic Spell 9 Attack Glow (black keyed out)
    hit = { dir = 'hit', n = 30, fps = 34, size = 1.45, aspect = 1, dx = -0.06, alpha = 0.8, behind = true },   -- Magic Hit Side 1
    -- (hit: a side-on burst, so nudged left to sit on the piece, drawn behind it at icon size, its faint tail cut)
};
DOLL.lit = 0;
-- Hex link's one window frame, in the Visor's language: cut corners, a dark glass fill, a fine gold edge with brighter
-- gold running round two opposite corners; o.title sits on the top edge, which breaks round it. The gear strip and the
-- Damage Meter wear it, so every Hex link window looks like one family.   o: a (alpha), s (scale), cut, fill, title
function YUI_HEXFRAME(dl, x0, y0, x1, y1, o)
    o = o or {};                                                     -- (o.t: seconds since it appeared - it draws itself in; o.glint: 0..1
    local a, s = o.a or 1, o.s or 1;                                 --  round the edge, a light running along it (o.gs its strength);
    local GO = C.GOLDH or { 1.0, 0.76, 0.34 };                       --  o.pulse: { colour, 0..1 } the whole edge lit)
    local e = o.t and math.max(0, math.min(1, o.t / 0.55)) or 1;
    local ee = 1 - (1 - e) ^ 3;
    local k = math.min(o.cut or 11 * s, (y1 - y0) * 0.3, (x1 - x0) * 0.3);
    local P = { { x0 + k, y0 }, { x1 - k, y0 }, { x1, y0 + k }, { x1, y1 - k }, { x1 - k, y1 }, { x0 + k, y1 }, { x0, y1 - k }, { x0, y0 + k } };
    local fill = U4(0.03, 0.035, 0.055, (o.fill or 0.82) * a * ee);
    if not pcall(function() dl:AddConvexPolyFilled(P, fill); end) then
        local mx, my = (x0 + x1) / 2, (y0 + y1) / 2;
        for i = 1, #P do dl:AddTriangleFilled({ mx, my }, P[i], P[i % #P + 1], fill); end
    end
    local g0, g1 = nil, nil;                                         -- (the title's gap in the top edge)
    local tw, th, pushed = 0, 0, nil;
    if o.title then
        pushed = sized('chat', 12 * s);
        tw = tonumber((imgui.CalcTextSize(o.title))) or 0;
        th = imgui.GetTextLineHeight();
        g0, g1 = (x0 + x1) / 2 - tw / 2 - 7 * s, (x0 + x1) / 2 + tw / 2 + 7 * s;
    end
    local function L(p0, p1, c, w)                                   -- a line, broken round the title on the top edge
        if g0 and math.abs(p0[2] - y0) < 0.5 and math.abs(p1[2] - y0) < 0.5 then
            local xa, xb = math.min(p0[1], p1[1]), math.max(p0[1], p1[1]);
            if xb <= g0 or xa >= g1 then dl:AddLine(p0, p1, c, w); return; end
            if xa < g0 then DL.L(dl, xa, y0, g0, y0, c, w); end
            if xb > g1 then DL.L(dl, g1, y0, xb, y0, c, w); end
            return;
        end
        dl:AddLine(p0, p1, c, w);
    end
    local function dist(p, q) return math.sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2); end
    local function along(path, f, c, w)                              -- the first f of a path
        local tot = 0;
        for i = 1, #path - 1 do tot = tot + dist(path[i], path[i + 1]); end
        local left = tot * f;
        for i = 1, #path - 1 do
            if left <= 0 then break; end
            local p0, p1 = path[i], path[i + 1];
            local d = dist(p0, p1);
            if d <= left then L(p0, p1, c, w);
            else local u = left / d; L(p0, { p0[1] + (p1[1] - p0[1]) * u, p0[2] + (p1[2] - p0[2]) * u }, c, w); end
            left = left - d;
        end
    end
    local ec = U4(GO[1], GO[2], GO[3], 0.42 * a);
    if e >= 1 then
        for i = 1, #P do L(P[i], P[i % #P + 1], ec, 1); end
    else                                                             -- drawing itself in: from the top left corner round both ways,
        local A, B = { P[8], P[1], P[2], P[3], P[4], P[5] }, { P[8], P[7], P[6], P[5] };   --  meeting at the bottom right
        local bc = U4(GO[1], GO[2], GO[3], 0.95 * a);
        along(A, ee, bc, 1.4 * s); along(B, ee, bc, 1.4 * s);
    end
    local ra = a * math.max(0, math.min(1, (e - 0.55) / 0.45));     -- (the bright corners and the title come in at the end)
    if ra > 0.01 then
        local L2 = math.min(26 * s, (x1 - x0) * 0.2);                -- the bright gold round the top left and bottom right corners
        local bc, gc = U4(GO[1], GO[2], GO[3], 0.95 * ra), U4(GO[1], GO[2], GO[3], 0.22 * ra);
        local function run(pts) for i = 1, #pts - 1 do dl:AddLine(pts[i], pts[i + 1], gc, 3.5 * s); dl:AddLine(pts[i], pts[i + 1], bc, 1.4 * s); end end
        run({ { x0, y0 + k + L2 * 0.6 }, { x0, y0 + k }, { x0 + k, y0 }, { math.min(x0 + k + L2, g0 or 1e9), y0 } });
        run({ { x1, y1 - k - L2 * 0.6 }, { x1, y1 - k }, { x1 - k, y1 }, { x1 - k - L2, y1 } });
    end
    if o.pulse and (o.pulse[2] or 0) > 0.01 then                     -- the whole edge lit for a moment (a fight starts)
        local pc, pk = o.pulse[1], o.pulse[2];
        for i = 1, #P do
            L(P[i], P[i % #P + 1], U4(pc[1], pc[2], pc[3], 0.30 * pk * a), 5 * s);
            L(P[i], P[i % #P + 1], U4(pc[1], pc[2], pc[3], 0.90 * pk * a), 1.5 * s);
        end
    end
    if o.glint and e >= 1 then                                       -- a light running round the edge
        local loop, cum = { P[1], P[2], P[3], P[4], P[5], P[6], P[7], P[8], P[1] }, { 0 };
        for i = 1, #loop - 1 do cum[i + 1] = cum[i] + dist(loop[i], loop[i + 1]); end
        local tot = cum[#cum];
        local function at(d)
            d = d % tot;
            for i = 1, #loop - 1 do
                if d <= cum[i + 1] then
                    local u = (d - cum[i]) / math.max(0.001, cum[i + 1] - cum[i]);
                    return { loop[i][1] + (loop[i + 1][1] - loop[i][1]) * u, loop[i][2] + (loop[i + 1][2] - loop[i][2]) * u };
                end
            end
            return loop[1];
        end
        local d0, half, n = o.glint * tot, 34 * s, 10;
        local gs = (o.gs or 1) * a;
        local wc = { 1.0, 0.95, 0.82 };
        for q = 0, n - 1 do
            local u0, u1 = q / n, (q + 1) / n;
            local p0, p1 = at(d0 - half + 2 * half * u0), at(d0 - half + 2 * half * u1);
            local tent = 1 - math.abs((u0 + u1) - 1);                -- (brightest in the middle)
            L(p0, p1, U4(GO[1], GO[2], GO[3], 0.30 * tent * gs), 4.5 * s);
            L(p0, p1, U4(wc[1], wc[2], wc[3], 0.95 * tent * gs), 1.6 * s);
        end
    end
    if o.title then
        local c2 = o.tcol or C.GOLDH2 or { 1.0, 0.90, 0.62 };       -- (o.tcol: the title in its own colour)
        local tx, ty = math.floor((x0 + x1) / 2 - tw / 2), math.floor(y0 - th / 2);
        outlined(dl, tx, ty, o.title, { c2[1], c2[2], c2[3], math.max(0.01, ra) });
        unsized(pushed);
        return { tx, ty, tw, th };                                   -- (where the title is: the Damage Meter's is a button)
    end
end
function YUI_HEXGLINT(t0)                                            -- (the idle glint: once every 11 s, from 2 s after it appeared)
    local t = os.clock() - (t0 or 0);
    if t < 2 then return nil; end
    local ph = (t % 11) / 1.6;
    if ph < 1 then return ph; end
    return nil;
end
function DOLL.cell(dl, x0, y0, x1, y1, a, lit, s)                    -- (Hex link: a gear slot - a small cut-corner cell)
    local kc = (y1 - y0) * 0.22;
    local p = { { x0 + kc, y0 }, { x1, y0 }, { x1, y1 - kc }, { x1 - kc, y1 }, { x0, y1 }, { x0, y0 + kc } };
    pcall(function() dl:AddConvexPolyFilled(p, U4(0.05, 0.06, 0.09, 0.70 * a)); end);
    local AZ = (C.HEXMP and C.HEXMP[1]) or { 0.35, 0.80, 1.00 };
    local GO = C.GOLDH or { 1.0, 0.76, 0.34 };
    local c = lit > 0 and AZ or GO;
    local ea = lit > 0 and (0.35 + 0.6 * lit) or 0.22;
    for i = 1, #p do dl:AddLine(p[i], p[i % #p + 1], U4(c[1], c[2], c[3], ea * a), (lit > 0) and 1.4 * s or 1); end
end
-- What caused a swap (Hex link: the grid's title as it comes up): the action you just sent - a weapon skill, a spell, an
-- ability - names the swaps right after it; otherwise your status (ENGAGED, IDLE...).
function DOLL.on_out(e)                                              -- (packet_out 0x1A: what you just did)
    local d = e.data;
    local cat = d:byte(11) + d:byte(12) * 256;
    local p_ = d:byte(13) + d:byte(14) * 256;
    local rm = AshitaCore:GetResourceManager();
    local label, kind = nil, nil;
    if cat == 3 then local r = rm:GetSpellById(p_); label, kind = r and r.Name and r.Name[1], 'spell';
    elseif cat == 7 then local r = rm:GetAbilityById(p_); label, kind = r and r.Name and r.Name[1], 'ws';
    elseif cat == 9 then local r = rm:GetAbilityById(p_ + 512); label, kind = r and r.Name and r.Name[1], 'ja';
    elseif cat == 16 then label, kind = 'Ranged attack', 'ws';
    elseif cat == 2 then label, kind = 'Engaged', 'state';
    elseif cat == 4 then label, kind = 'Idle', 'state'; end
    if label and label ~= '' then DOLL.cause = { t = os.clock(), label = label, kind = kind }; end
end
function DOLL.cause_of(now)
    local c = DOLL.cause;
    if c and now - c.t < ((c.kind == 'spell') and 3 or 0.9) then return c; end
    local st = 0;
    pcall(function()
        local mm = AshitaCore:GetMemoryManager();
        local me = mm:GetParty():GetMemberTargetIndex(0) or 0;
        if me ~= 0 then st = mm:GetEntity():GetStatus(me) or 0; end
    end);
    return { label = ({ [1] = 'Engaged', [33] = 'Resting' })[st] or 'Idle', kind = 'state' };
end
function DOLL.why_col(kind)                                          -- (gold: a weapon skill; azure: a spell or ability; white: your status)
    local h = (type(YUI_HEXCOL) == 'table') and YUI_HEXCOL or {};
    if kind == 'ws' then return h.gold2; elseif kind == 'spell' then return h.azure; elseif kind == 'ja' then return h.azure2; end
    return { 0.95, 0.95, 1.0 };
end
local function draw_strip()
    if (cfg.equip_look or 'wheel') ~= 'strip' then return; end
    if cfg.strip_show == false then return; end                     -- EQUIP > GEAR STRIP > Show
    local now = os.clock();
    local look = (now >= DOLL.at);
    for _, slot in ipairs(DOLL.STRIP) do
        if look then DOLL.items[slot] = { equipped(slot) }; end      -- looked up twice a second
        local id = (DOLL.items[slot] or {})[1];
        local was = DOLL.prev[slot];                                 -- a swap: item -> another item (not login / zoning)
        if type(was) == 'number' and id and id ~= was then
            if YUI_HEX and now - (DOLL.lit or 0) > 0.4 then DOLL.why = DOLL.cause_of(now); end   -- (a new swap: what caused it)
            DOLL.hit[slot] = now; DOLL.lit = now;
        end
        if id then DOLL.prev[slot] = id; end
    end
    if look then DOLL.at = now + (YUI_HEX and 0.1 or 0.5); end       -- (Hex link: quick, so the swap is matched to what caused it)
    local per = math.floor(tonumber(cfg.strip_cols) or 8);           -- icons in a row: 8 (2 rows), 16 (1 row), 4 (4 rows)
    local sc = tonumber(cfg.scale) or 1;
    local S = math.floor((tonumber(cfg.strip_icon) or 26) * sc);
    local pad = math.max(2, math.floor(3 * sc));                     -- (room for the violet outline round a piece)
    local gap = math.floor(6 * sc);
    local under = cfg.strip_under or 'mp';
    local bp = (under ~= 'free' and type(YUI_EQ_BARPOS) == 'table') and YUI_EQ_BARPOS[under] or nil;
    if bp and now - (bp[4] or 0) > 1 then bp = nil; end             -- that bar isn't showing: a window of its own
    if bp and cfg.strip_fit ~= false then                            -- spread the row across the bar's width
        gap = math.max(math.floor(6 * sc), (bp[3] - per * S) / math.max(1, per - 1));
    end
    local rows = math.ceil(16 / per);
    local W, H = per * S + (per - 1) * gap, rows * S + (rows - 1) * gap;
    -- how bright: dimmed at rest, full when you swap gear (then it fades back) or hover it, or while EQUIP is open
    local rest = cfg.strip_swap_only and 0 or (tonumber(cfg.strip_dim) or 0.35);
    local a = rest;
    local since = now - (DOLL.lit or 0);
    local hold = YUI_HEX and 4 or 2.5;                               -- (Hex link: hidden at rest, it comes up when you change gear)
    if YUI_HEX then rest = 0; end
    if since < hold then a = 1; elseif since < hold + 0.8 then a = rest + (1 - rest) * (1 - (since - hold) / 0.8); end
    if DOLL.hover or DOLL.preview then a = 1; end
    if YUI_HEX and type(DOLL.rect) == 'table' then                   -- (hover where it sits: it comes up too)
        local mx0, my0 = imgui.GetMousePos();
        local r_ = DOLL.rect;
        if mx0 >= r_[1] and mx0 <= r_[3] and my0 >= r_[2] and my0 <= r_[4] then a = 1; end
    end
    if a > 0.01 and not DOLL.shown then DOLL.t0 = now; end          -- (just came up: it draws itself in)
    DOLL.shown = a > 0.01;
    if a <= 0.01 then DOLL.hover = false; return; end
    local kx, ky = 'strip_x', 'strip_y';
    if bp then
        cfg._sx, cfg._sy = bp[1] - 8, bp[2] + 6 * sc;                -- (the window adds no padding: 8 px like the bars)
        kx, ky = '_sx', '_sy';
        WATCH.move = WATCH.move + 1;                                 -- follow the bar every frame
    else
        first_place('strip_x', 'strip_y', -W / 2, -330);
    end
    local open = plain_window('YunaUI Strip##yui_strip', kx, ky);
    if bp then WATCH.move = WATCH.move - 1; cfg._sx, cfg._sy = nil, nil; end
    local hxf = YUI_HEX and not bp;                                  -- (Hex link, on its own: in Hex link's frame, GEAR on its edge)
    local top_ = hxf and math.floor(10 * sc) or 0;
    if open then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        x, y = x + 8 + pad, y + 2 + pad + top_;
        if YUI_HEX then DOLL.rect = { x - pad - 6 * sc, y - pad - 16 * sc, x + W + pad + 6 * sc, y + H + pad + 6 * sc }; end
        if hxf then
            local m_ = 6 * sc;
            YUI_HEXFRAME(dl, x - pad - m_, y - pad - m_, x + W + pad + m_, y + H + pad + m_,
                { a = a, s = sc, title = (DOLL.why and since < hold + 0.8) and string.upper(DOLL.why.label) or 'GEAR',
                  tcol = (DOLL.why and since < hold + 0.8) and DOLL.why_col(DOLL.why.kind) or nil,
                  t = now - (DOLL.t0 or 0), glint = YUI_HEXGLINT(DOLL.t0), gs = 0.6 });
        end
        local mx, my = imgui.GetMousePos();
        DOLL.hover = imgui.IsWindowHovered() or (mx >= x and mx <= x + W and my >= y and my <= y + H);
        local allc = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15;
        for k, slot in ipairs(DOLL.STRIP) do
            local c, r = (k - 1) % per, math.floor((k - 1) / per);
            local sx, sy = x + c * (S + gap), y + r * (S + gap);
            local id, name = (DOLL.items[slot] or {})[1], (DOLL.items[slot] or {})[2];
            local cx_, cy_ = sx + S / 2, sy + S / 2;
            local ca, wave = 1, 0;                                   -- (Hex link: as it comes up, the pieces come in one after another,
            if YUI_HEX then                                          --  an azure wave running over them)
                local tt, d0 = now - (DOLL.t0 or 0), 0.18 + (k - 1) * 0.025;
                ca = math.max(0, math.min(1, (tt - d0) / 0.18));
                wave = math.max(0, math.min(1, 1 - math.abs(tt - d0 - 0.12) / 0.22)) * 0.8;
            end
            local ic = id and (YUI_EQ_ICON or item_icon)(id) or nil;
            local ht = DOLL.hit[slot];
            local t = ht and (now - ht) or nil;
            if t and t > 1.6 then DOLL.hit[slot], t = nil, nil; end
            local sfx = cfg.strip_fx or 'muzzle';
            local sw = t and DOLL.SWAP_FX[sfx] or nil;
            local function swap_clip()                               -- the swap: one of the user's clips, played once on the slot
                local fk = math.floor(t * sw.fps);
                if fk >= sw.n then return; end
                local fl = dl;                                       -- (over the others: the foreground; behind the piece: this window)
                if not sw.behind then pcall(function() fl = imgui.GetForegroundDrawList() or dl; end); end
                local hw = S * sw.size / 2;
                local hh = hw * sw.aspect;
                local ox = (sw.dx or 0) * hw * 2;
                local fa = (sw.alpha or 1) * ((fk > sw.n * 0.6) and (1 - (fk - sw.n * 0.6) / (sw.n * 0.4)) or 1);
                image(fl, tex(string.format('%s/%02d.png', sw.dir, fk)), cx_ - hw + ox, cy_ - hh, cx_ + hw + ox, cy_ + hh, { 1, 1, 1, fa });
            end
            if YUI_HEX then                                          -- (Hex link: every piece in its own small cell; azure when it changes)
                local hv_ = DOLL.hover and mx >= sx and mx < sx + S and my >= sy and my < sy + S;
                local lit = hv_ and 1 or ((t and t < 1.2) and math.max(0, 1 - t / 1.2) or 0);
                DOLL.cell(dl, sx - pad, sy - pad, sx + S + pad, sy + S + pad, a * ca, math.max(lit, wave), sc);
            else                                                     -- no slot behind it (clean); a violet glowing outline only
                local hv_ = DOLL.hover and mx >= sx and mx < sx + S and my >= sy and my < sy + S;   -- under the mouse or just swapped
                if hv_ or (t and t < 1.2) then
                    local x0, y0, x1, y1 = sx - pad, sy - pad, sx + S + pad, sy + S + pad;
                    local rr = math.max(3, 5 * sc);
                    local k = hv_ and 1 or math.max(0, 1 - t / 1.2);
                    for g = 3, 1, -1 do DL.R(dl, x0 - g, y0 - g, x1 + g, y1 + g, U4(0.66, 0.48, 1.0, 0.10 * k * a), rr + g, allc, 2); end
                    DL.R(dl, x0, y0, x1, y1, U4(0.74, 0.58, 1.0, 0.95 * k * a), rr, allc, 1.5);
                end
            end
            if sw and sw.behind then swap_clip(); end
            if ic then
                local hv = DOLL.hover and mx >= sx and mx < sx + S and my >= sy and my < sy + S;
                local m = hv and -2 or 0;                            -- the one under the mouse grows a touch
                if t and t < 0.3 then m = m - S * 0.14 * (1 - t / 0.3); end   -- a new piece pops in, then settles
                image(dl, ic, sx + m, sy + m, sx + S - m, sy + S - m, { 1, 1, 1, a * ca });
            end
            if sw and not sw.behind then swap_clip(); end
            if t and sfx == 'line' then                              -- the swap, drawn like the HP / MP bars: a thin pink-to-violet
                local grow = math.min(1, t / 0.35);                  -- line runs in under the piece with the bright tip, then fades
                grow = 1 - (1 - grow) * (1 - grow);
                local f = (t < 0.9) and 1 or math.max(0, 1 - (t - 0.9) / 0.7);
                local ly, lw = sy + S + math.max(1, gap * 0.35), math.max(1.5, 2 * sc);
                local c1, c2 = { 1.00, 0.36, 0.62 }, { 0.62, 0.40, 1.00 };
                local n = 8;
                for q = 0, n - 1 do
                    local u0, u1 = q / n, (q + 1) / n;
                    if u0 >= grow then break; end
                    local u = (u0 + u1) / 2;
                    local col = { c1[1] + (c2[1] - c1[1]) * u, c1[2] + (c2[2] - c1[2]) * u, c1[3] + (c2[3] - c1[3]) * u };
                    DL.RF(dl, sx + S * u0, ly, sx + S * math.min(u1, grow), ly + lw, U4(col[1], col[2], col[3], f));
                    DL.RF(dl, sx + S * u0, ly - lw, sx + S * math.min(u1, grow), ly + lw * 2, U4(col[1], col[2], col[3], 0.18 * f));
                end
                local hx = sx + S * grow;                            -- the tip: a small white dot with a soft halo
                DL.CF(dl, hx, ly + lw / 2, lw * 2.6, U4(1, 0.85, 1, 0.22 * f), 12);
                DL.CF(dl, hx, ly + lw / 2, lw * 1.1, U4(1, 1, 1, 0.95 * f), 10);
            end
            if ic then
                local hv = DOLL.hover and mx >= sx and mx < sx + S and my >= sy and my < sy + S;
                if hv then YUI_TIP(DOLL_SLOTS[slot][1] .. ': ' .. (name or '?')); end
            else                                                     -- empty: a faint dot
                DL.CF(dl, cx_, cy_, math.max(1.5, S * 0.06), U4(1, 1, 1, 0.25 * a), 8);
            end
        end
        imgui.Dummy({ W + 16 + pad * 2 + (hxf and 6 * sc or 0), H + 6 + pad * 2 + (hxf and (top_ + 8 * sc) or 0) });
        if bp then imgui.End(); imgui.PopStyleVar(2); else end_plain('strip_x', 'strip_y'); end
    else
        imgui.End(); imgui.PopStyleVar(2);
    end
end

-- Cast bar: the spell (or item) you're casting, in YunaUI's font, over a living bar that fills as the cast goes;
-- it flashes and fades when the cast lands, and turns red and fades if it's interrupted
local function draw_cast()
    if not cfg.castbar then return; end
    local now = os.clock();
    local pct, alpha, label, broke = 0, 1, CAST.name, false;
    if CAST.on then
        pcall(function() pct = AshitaCore:GetMemoryManager():GetCastBar():GetPercent() or 0; end);
        if now - CAST.t0 > 30 then CAST.on = false; end             -- never left hanging
    elseif now - CAST.done < 0.6 then                               -- landed / interrupted: a short fade
        alpha = 1 - (now - CAST.done) / 0.6;
        pct = CAST.broke and pct or 1;
        broke = CAST.broke;
    elseif CAST.preview then
        pct, label = 0.5 + 0.45 * math.sin(now * 0.8), 'Cure IV';
    else
        return;
    end
    pct = math.max(0, math.min(1, pct));
    local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.cast_scale) or 1);
    local w = (tonumber(cfg.cast_w) or 300) * sc;
    local bh = math.max(2, math.floor((tonumber(cfg.cast_h) or 5) * sc));
    first_place('cast_x', 'cast_y', -w / 2, -260);
    if plain_window('YunaUI Cast##yui_cast', 'cast_x', 'cast_y') then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        x, y = x + 8, y + 6;
        local c1 = (type(cfg.cast_c1) == 'table') and cfg.cast_c1 or { 0.55, 0.88, 1.00 };
        local c2 = (type(cfg.cast_c2) == 'table') and cfg.cast_c2 or { 0.49, 0.56, 1.00 };
        if broke then c1, c2 = { 1, 0.45, 0.45 }, { 0.85, 0.15, 0.25 }; end
        local fx = cfg.cast_fx or 'same';
        if fx == 'same' then fx = nil; end
        local pushed = sized('chat', 16 * sc);
        local lh = imgui.GetTextLineHeight();
        local tc = (type(cfg.cast_tc) == 'table') and cfg.cast_tc or { 1, 1, 1 };
        outlined(dl, x, y, label ~= '' and label or '...', { tc[1], tc[2], tc[3], alpha });
        local ps = broke and 'Interrupted' or string.format('%d%%', math.floor(pct * 100));
        local pw = imgui.CalcTextSize(ps);
        outlined(dl, x + w - pw, y, ps, broke and { 1, 0.55, 0.6, alpha } or { tc[1], tc[2], tc[3], 0.8 * alpha });
        unsized(pushed);
        local by = y + lh + 4 * sc;
        glow_bar(dl, x, by, w, bh, pct, nil, { c1[1], c1[2], c1[3] }, { c2[1], c2[2], c2[3] }, 9.1, fx);
        if alpha < 1 and not broke then                              -- the landing flash
            DL.RF(dl, x - 2, by - 2, x + w + 2, by + bh + 2, U4(1, 1, 1, 0.5 * alpha), bh);
        end
        imgui.Dummy({ w + 16, by + bh - y + 12 });
        end_plain('cast_x', 'cast_y');
    else
        imgui.End(); imgui.PopStyleVar(2);
    end
end

----------------------------------------------------------------------------------------------------
-- The old floating logo with its fan of buttons (no longer drawn: the violet logo at the top of the screen opens YunaUI)
----------------------------------------------------------------------------------------------------
local ui = { open = false, fan = false, fan_t = 0, min = false };
local FAN = {
    { 'btn_dps.png',   'Damage Meter', '/dps' },
};
local function draw_logo(dt)
    local sz = (tonumber(cfg.logo_size) or 72) * (tonumber(cfg.scale) or 1);
    if not plain_window('YunaUI Logo##yui_logo', 'logo_x', 'logo_y') then imgui.End(); imgui.PopStyleVar(2); return; end
    local dl = imgui.GetWindowDrawList();
    local now = os.clock();
    local x, y = imgui.GetCursorScreenPos();
    -- room above and below the logo for the fan's top and bottom buttons (so they're never cut off)
    local fr, fR = sz * 0.31, sz * 0.5 + sz * 0.31 + 12;
    local room = math.max(10, math.ceil(fR * math.sin(math.rad(25)) + fr - sz / 2 + 6));
    local lx, ly = x + 10, y + room;
    local bob = math.sin(now * 1.3) * 2;
    local br = 0.5 + 0.5 * math.sin(now * 1.8);
    imgui.SetCursorScreenPos({ lx, ly });
    imgui.InvisibleButton('##yui_logo_btn', { sz, sz });
    local hov = imgui.IsItemHovered();
    if imgui.IsItemClicked(0) then ui.press = { imgui.GetMousePos() }; end
    if imgui.IsItemDeactivated() and ui.press then                   -- a click (not a drag) opens YunaUI
        local mx, my = imgui.GetMousePos();
        if math.abs(mx - ui.press[1]) < 4 and math.abs(my - ui.press[2]) < 4 then ui.open = not ui.open; end
        ui.press = nil;
    end
    if imgui.IsItemActive() and not cfg.locked then                  -- drag the logo by itself
        local dx, dy = imgui.GetMouseDragDelta(0);
        if math.abs(dx) + math.abs(dy) > 3 then
            local wx, wy = imgui.GetWindowPos();
            imgui.SetWindowPos({ wx + dx, wy + dy });
            imgui.ResetMouseDragDelta(0);
        end
    end
    if hov and imgui.IsMouseClicked(1) then ui.fan = not ui.fan; ui.fan_t = now; end
    -- the logo, over a dark shade that stays inside its own shape (so it stands out on any ground), breathing softly
    local cx, cy = lx + sz / 2, ly + sz / 2 + bob;
    local s2 = sz * (hov and 1.05 or 1);
    image(dl, tex('logo_shade.png'), cx - s2 / 2, cy - s2 / 2, cx + s2 / 2, cy + s2 / 2, { 1, 1, 1, 0.70 + 0.25 * br });
    image(dl, tex('logo_bright.png') or tex('logo.png'), cx - s2 / 2, cy - s2 / 2, cx + s2 / 2, cy + s2 / 2);
    -- the fan: round buttons that open out to the right of the logo like a fan, each swinging into place a moment
    -- after the one before
    local t = math.min(1, (now - ui.fan_t) / 0.35);
    local k = ui.fan and t or (1 - t);
    local r = sz * 0.31;
    local R = sz * 0.5 + r + 12;                                     -- how far out the buttons sit
    if k > 0.01 then
        local n = #FAN;
        for i, b in ipairs(FAN) do
            local d = math.max(0, math.min(1, k * 1.6 - (i - 1) * 0.25));
            local e = 1 - (1 - d) ^ 3;
            local final = (i - (n + 1) / 2) * 50;                    -- spread round the right side
            local ang = math.rad(final * e - 40 * (1 - e));          -- they swing down into place as they come out
            local bx, by = cx + math.cos(ang) * R * e, cy + math.sin(ang) * R * e;
            imgui.SetCursorScreenPos({ bx - r, by - r });
            if e > 0.6 and imgui.InvisibleButton('##yui_fan' .. i, { r * 2, r * 2 }) then
                AshitaCore:GetChatManager():QueueCommand(1, b[3]);
                ui.fan = false; ui.fan_t = now;
            end
            local bh = e > 0.6 and imgui.IsItemHovered();
            DL.CF(dl, bx, by, r * e, U4(0.06, 0.07, 0.11, 0.95 * e), 32);
            DL.C(dl, bx, by, r * e, U4(C.gold[1], C.gold[2], C.gold[3], (bh and 1 or 0.6) * e), 32, bh and 2 or 1.3);
            image(dl, tex(b[1]), bx - r * 0.78 * e, by - r * 0.78 * e, bx + r * 0.78 * e, by + r * 0.78 * e, { 1, 1, 1, e });
            if bh then YUI_TIP(b[2]); end
        end
    end
    imgui.SetCursorScreenPos({ x, y });
    imgui.Dummy({ sz + 20 + ((k > 0.01) and (R + r) or 0), sz + room * 2 });
    end_plain('logo_x', 'logo_y');
end

----------------------------------------------------------------------------------------------------
-- The YunaUI window (YunaGearOpt's style): what to show, and shortcuts to the three addons
----------------------------------------------------------------------------------------------------
-- The EQUIP tab: YunaEquip is part of YunaUI (equip.lua); this is its own settings panel
local function equip_tab()
    section('GEAR STRIP');
    do
        row_switch('##yui_stshow', 'Show', 'strip_show', 'On: the gear you are wearing shows as a strip of icons (under your bars, or anywhere). Off: hidden.');
        row_pick('##yui_stu', 'Sits under', 'strip_under', { { 'mp', 'MP bar' }, { 'hp', 'HP bar' }, { 'tp', 'TP bar' }, { 'free', 'Anywhere (drag it)' } });
        if cfg.strip_under ~= 'free' then row_switch('##yui_stf', 'As wide as the bar', 'strip_fit', 'On: the icons spread out to the width of the bar.'); end
        row_pick('##yui_stc', 'Rows', 'strip_cols', { { 8, '2 rows' }, { 16, '1 row' }, { 4, '4 rows' } });
        row_slider('##yui_sti', 'Icon size', 'strip_icon', 16, 48, 1, '%d px');
        row_pick('##yui_stx', 'Swap effect', 'strip_fx', { { 'muzzle', 'Muzzle flash' }, { 'spell9', 'Magic spell' }, { 'none', 'None' } });
        if accent_button('TRY THE SWAP EFFECT', { ROW_W, 0 }) then          -- plays it on every slot, to compare them
            local now = os.clock();
            for _, sl in ipairs(DOLL.STRIP) do DOLL.hit[sl] = now; end
            DOLL.lit = now;
        end
        row_switch('##yui_sts', 'Only show on gear change', 'strip_swap_only', 'On: hidden until you swap gear, then it shows for a moment.');
        if not cfg.strip_swap_only then row_slider('##yui_std', 'Brightness when idle', 'strip_dim', 0.05, 1.0, 0.05, '%.2f'); end
        imgui.TextColored(C.muted, 'Lights up when you swap gear. Hover an icon for its name.');
        imgui.Spacing();
        imgui.TextColored(C.muted, "Note: the white boxes that mark HQ gear are not shown here yet.");
        imgui.TextColored(C.muted, "That part is still being reworked to match the rest of YunaUI.");
        imgui.TextColored(C.muted, "Don't worry: your HQ gear is still HQ :)");
    end
    if YUI_EQ_SETTINGS then YUI_EQ_SETTINGS();
    else imgui.TextColored({ 1, 0.5, 0.6, 1 }, 'YunaEquip did not load (equip.lua).'); end
end
-- Copy your settings to another character: YunaUI's own (settings.lua) and YunaEquip's (equip.lua) are copied from
-- your folder in config\addons\yunaui into theirs. The list is every character seen in the Yuna addons' folders.
local COPY = { list = nil, at = 0, pick = 1, confirm = 0, note = nil };
local function copy_base() return AshitaCore:GetInstallPath():gsub('[\\/]+$', '') .. '\\config\\addons\\'; end
local function my_folder()
    local p = AshitaCore:GetMemoryManager():GetParty();
    return string.format('%s_%d', p:GetMemberName(0) or '', p:GetMemberServerId(0) or 0);
end
local function copy_targets()
    if COPY.list and os.clock() < COPY.at then return COPY.list; end
    COPY.at = os.clock() + 5;
    local seen, list = {}, {};
    pcall(function()
        local mine = my_folder();
        for _, a in ipairs({ 'yunaui', 'yunaequip', 'yunagearopt', 'yunadps' }) do
            local ok, dirs = pcall(ashita.fs.get_directory, copy_base() .. a .. '\\');
            if ok and type(dirs) == 'table' then
                for _, d in pairs(dirs) do
                    if type(d) == 'string' and d:match('^.+_%d+$') and d ~= mine and not seen[d] then
                        seen[d] = true;
                        list[#list + 1] = d;
                    end
                end
            end
        end
    end);
    table.sort(list);
    COPY.list = list;
    if COPY.pick > #list then COPY.pick = 1; end
    return list;
end
local function copy_to(target)
    save();
    pcall(settings.save, 'equip');
    local src = copy_base() .. 'yunaui\\' .. my_folder() .. '\\';
    local dst = copy_base() .. 'yunaui\\' .. target .. '\\';
    pcall(ashita.fs.create_directory, dst);
    pcall(ashita.fs.create_dir, dst);
    local done = 0;
    for _, n in ipairs({ 'settings.lua', 'equip.lua', 'dps.lua' }) do
        local f = io.open(src .. n, 'rb');
        if f then
            local data = f:read('*a'); f:close();
            local w = io.open(dst .. n, 'wb');
            if w then w:write(data); w:close(); done = done + 1; end
        end
    end
    local name = target:match('^(.+)_%d+$') or target;
    if done > 0 then
        COPY.note = { 'Copied to ' .. name .. ': if they\'re online they switch to it within 2 seconds.', true };
        msg('Settings copied to ' .. name .. '.');
    else
        COPY.note = { 'Could not copy (your settings file was not found).', false };
    end
end
local function copy_section()
    section('COPY TO ANOTHER CHARACTER');
    local list = copy_targets();
    if #list == 0 then
        imgui.TextColored(C.muted, 'No other character found yet (log in with them once).');
        return;
    end
    local x0 = imgui.GetCursorPosX();
    imgui.AlignTextToFramePadding();
    imgui.TextColored(C.text, 'Character');
    imgui.SameLine(x0 + ROW_W - 150);
    local cur = list[COPY.pick] or list[1];
    local shown = cur:match('^(.+)_%d+$') or cur;
    if accent_button(shown .. '##yui_copy_who', { 150, 0 }) then COPY.pick = COPY.pick % #list + 1; COPY.confirm = 0; end
    if imgui.IsItemHovered() then YUI_TIP('Click for the next character'); end
    local sure = os.clock() < COPY.confirm;
    if accent_button((sure and ('SURE? THIS REPLACES ' .. shown:upper() .. '\'S SETTINGS') or 'COPY MY SETTINGS') .. '##yui_copy', { ROW_W, 0 }) then
        if sure then COPY.confirm = 0; copy_to(cur);
        else COPY.confirm = os.clock() + 4; COPY.note = nil; end
    end
    if COPY.note then imgui.TextColored(COPY.note[2] and { 0.55, 1, 0.65, 1 } or { 1, 0.5, 0.6, 1 }, COPY.note[1]); end
end

-- The tabs under the title: each shows one group of settings
----------------------------------------------------------------------------------------------------
-- Cooldowns (TIMERS tab): your job ability and spell recasts, read from the game's recast memory the same way the
-- Timers addon does (the game counts them in 1/60 s; the first value seen is taken as the full length). Shortest at
-- the top: the name, the time left, and a bar that drains. A short READY flash when one comes back.
----------------------------------------------------------------------------------------------------
local TIMERS = { abils = {}, spells = {}, ready = {}, at = 0, snap = 0, preview = false };
TIMERS.SP1 = { 'Mighty Strikes', 'Hundred Fists', 'Benediction', 'Manafont', 'Chainspell', 'Perfect Dodge', 'Invincible',
    'Blood Weapon', 'Familiar', 'Soul Voice', 'Eagle Eye Shot', 'Meikyo Shisui', 'Mijin Gakure', 'Spirit Surge', 'Astral Flow',
    'Azure Lore', 'Wild Card', 'Overdrive', 'Trance', 'Tabula Rasa', 'Bolster', 'Elemental Sforzo' };
TIMERS.SP2 = { 'Brazen Rush', 'Inner Strength', 'Asylum', 'Subtle Sorcery', 'Stymie', 'Larceny', 'Intervene', 'Soul Enslavement',
    'Unleash', 'Clarion Call', 'Overkill', 'Yaegasumi', 'Mikage', 'Fly High', 'Astral Conduit', 'Unbridled Wisdom', 'Cutting Cards',
    'Heady Artifice', 'Grand Pas', 'Caper Emissarius', 'Widened Compass', 'Odyllic Subterfuge' };
TIMERS.NAMES = { [12] = 'Cascade', [231] = 'Stratagems', [242] = 'Jigs' };
TIMERS.SKIP = { [10] = true, [218] = true };
TIMERS.FAKE = { { 'Meikyo Shisui', 3600, 'sp' }, { 'Hasso', 60, 'ja' }, { 'Meditate', 180, 'ja' }, { 'Berserk', 300, 'ja' },
    { 'Warcry', 300, 'ja' }, { 'Cure IV', 12, 'ma' } };
function TIMERS.abil_name(id, job)
    if id == 0 then return TIMERS.SP1[job] or '(One hour)'; end
    if id == 254 then return TIMERS.SP2[job] or '(Second one hour)'; end
    if TIMERS.NAMES[id] then return TIMERS.NAMES[id]; end
    local r = AshitaCore:GetResourceManager():GetAbilityByTimerId(id);
    return (r and r.Name and r.Name[1]) or '(Ability)';
end
-- the seconds your gear / merits take off an ability's recast (Ready and Quick Draw need it to count charges)
function TIMERS.reduction(recast_id)
    local v = 0;
    pcall(function()
        local base = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('recast.abilities'));
        for i = 1, 32 do
            if ashita.memory.read_uint8(base + i * 8 + 3) == recast_id then v = ashita.memory.read_int16(base + i * 8 + 4); return; end
        end
    end);
    return v;
end
-- charged abilities: the charges you have, and the time to the next one
function TIMERS.charges(name, t, recast_id, secs, n)
    local full = 60 * (secs + TIMERS.reduction(recast_id));
    local one = full / n;
    return string.format('%s [%d]', name, math.max(0, math.floor((full - t) / one))), math.fmod(t, one), one;
end
function TIMERS.strats(t, pl)
    local lvl = (pl:GetMainJob() == 20) and pl:GetMainJobLevel() or pl:GetSubJobLevel();
    local r = (lvl < 30 and 240) or (lvl < 50 and 120) or (lvl < 70 and 80) or (lvl < 90 and 60) or 48;
    return string.format('Stratagems [%d]', math.max(0, math.floor((240 - t / 60) / r))), math.fmod(t, r * 60), r * 60;
end
function TIMERS.scan()
    local mm = AshitaCore:GetMemoryManager();
    local rc, pl = mm:GetRecast(), mm:GetPlayer();
    local job = pl:GetMainJob() or 0;
    local abils, spells = {}, {};
    if cfg.timers_abils ~= false then
        for i = 0, 31 do
            local id, t = rc:GetAbilityTimerId(i), rc:GetAbilityTimer(i);
            if (id ~= 0 or i == 0) and (t or 0) > 0 and not TIMERS.SKIP[id] then
                local name, left, full;
                if id == 0xC3 then name, left, full = TIMERS.charges('Quick Draw', t, 0xC3, 120, 2);
                elseif id == 0x66 then name, left, full = TIMERS.charges('Ready', t, 0x66, 90, 3);
                elseif id == 0xE7 then name, left, full = TIMERS.strats(t, pl);
                else name, left = TIMERS.abil_name(id, job), t; end
                local old = TIMERS.abils[id];
                full = full or ((old and old.full >= left) and old.full or left);
                abils[id] = { name = name, left = left, full = full, kind = (id == 0 or id == 254) and 'sp' or 'ja' };
            end
        end
    end
    if cfg.timers_spells ~= false then
        for i = 0, 1024 do
            local t = rc:GetSpellTimer(i);
            if (t or 0) > 0 then
                local old = TIMERS.spells[i];
                local name = old and old.name;
                if name == nil then
                    local r = AshitaCore:GetResourceManager():GetSpellById(i);
                    name = (r and r.Name and r.Name[1]) or '(Spell)';
                end
                spells[i] = { name = name, left = t, full = (old and old.full >= t) and old.full or t, kind = 'ma' };
            end
        end
    end
    -- the ones that just came back (gone while almost done, not from a job change): READY
    local now = os.clock();
    local gone = (now - TIMERS.snap) * 60;
    for _, pair in ipairs({ { TIMERS.abils, abils }, { TIMERS.spells, spells } }) do
        for k, e in pairs(pair[1]) do
            if pair[2][k] == nil and e.left - gone < 90 then TIMERS.ready[e.name] = { now, e.kind }; end
        end
    end
    TIMERS.abils, TIMERS.spells, TIMERS.snap = abils, spells, now;
end
function TIMERS.clock(left)
    local s = math.max(0, math.ceil(left / 60));
    local h, m = math.floor(s / 3600), math.floor(s / 60) % 60;
    if cfg.timers_fmt == 'clock' then return string.format('%02d:%02d:%02d', h, m, s % 60); end
    if h > 0 then return string.format('%d:%02d:%02d', h, m, s % 60); end
    if m > 0 then return string.format('%d:%02d', m, s % 60); end
    return string.format('%ds', s);
end
function TIMERS.colour(kind)
    if kind == 'sp' then return (type(cfg.timers_csp) == 'table') and cfg.timers_csp or { 1.00, 0.45, 0.75 }; end
    if kind == 'ma' then return (type(cfg.timers_cma) == 'table') and cfg.timers_cma or { 0.55, 0.80, 1.00 }; end
    return (type(cfg.timers_cja) == 'table') and cfg.timers_cja or { 1.00, 0.85, 0.45 };
end
function TIMERS.draw()
    if not cfg.timers then return; end
    local pl = AshitaCore:GetMemoryManager():GetPlayer();
    if pl == nil or (pl:GetMainJob() or 0) == 0 then return; end
    local now = os.clock();
    if now >= TIMERS.at then TIMERS.at = now + 0.25; pcall(TIMERS.scan); end
    local list = {};
    if TIMERS.preview then                                           -- the TIMERS tab is open: pretend ones
        for k, f in ipairs(TIMERS.FAKE) do
            local secs = f[2] * (0.9 - ((now * (f[2] > 600 and 20 or 1) / f[2] + k * 0.17) % 0.85));
            list[#list + 1] = { f[1], math.max(1, secs) * 60, f[2] * 60, f[3] };
        end
    else
        local gone = (now - TIMERS.snap) * 60;                      -- smooth between the looks
        for _, src in ipairs({ TIMERS.abils, TIMERS.spells }) do
            for _, e in pairs(src) do
                local left = e.left - gone;
                if left > 0 then list[#list + 1] = { e.name, left, e.full, e.kind }; end
            end
        end
    end
    for name, r in pairs(TIMERS.ready) do
        if cfg.timers_flash ~= false and now - r[1] < 2 then list[#list + 1] = { name, 0, 1, r[2], now - r[1] };
        else TIMERS.ready[name] = nil; end
    end
    if #list == 0 then return; end
    table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] < b[2]; end return a[1] < b[1]; end);
    local maxn = math.floor(tonumber(cfg.timers_max) or 10);
    local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.timers_scale) or 1);
    local w = (tonumber(cfg.timers_w) or 260) * sc;
    local bh = math.max(2, math.floor((tonumber(cfg.timers_h) or 4) * sc));
    first_place('timer_x', 'timer_y', -w / 2 - 420, -420);
    if plain_window('YunaUI Timers##yui_timers', 'timer_x', 'timer_y') then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        x, y = x + 8, y + 6;
        local pushed = sized('chat', 15 * sc);
        local lh = imgui.GetTextLineHeight();
        local rowh = lh + 3 * sc + bh + 6 * sc;
        local n = math.min(#list, maxn);
        local tc = (type(cfg.timers_tc) == 'table') and cfg.timers_tc or { 1, 1, 1 };
        local fx = 'same';                                           -- (the timers move like the bars)
        if fx == 'same' then fx = nil; end
        for k = 1, n do
            local e = list[k];
            local ry = cfg.timers_up and (y + (maxn - k) * rowh) or (y + (k - 1) * rowh);
            local c = TIMERS.colour(e[4]);
            local by = ry + lh + 3 * sc;
            if e[5] then                                             -- READY: a bright flash that fades
                local a = 1 - e[5] / 2;
                local pulse = 0.6 + 0.4 * math.sin(e[5] * 12);
                DL.RF(dl, x - 6, ry - 2, x + w + 6, by + bh + 3, U4(c[1], c[2], c[3], 0.18 * a * pulse), 4);
                outlined(dl, x, ry, e[1], { tc[1], tc[2], tc[3], a });
                local rs = 'READY';
                outlined(dl, x + w - imgui.CalcTextSize(rs), ry, rs, { c[1], c[2], c[3], a });
                DL.RF(dl, x, by, x + w, by + bh, U4(c[1], c[2], c[3], a * pulse), bh / 2);
            else
                outlined(dl, x, ry, e[1], { tc[1], tc[2], tc[3], 1 });
                local ts = TIMERS.clock(e[2]);
                local soon = e[2] < 600 and (0.75 + 0.25 * math.sin(now * 8)) or 1;   -- the last 10 s blink softly
                outlined(dl, x + w - imgui.CalcTextSize(ts), ry, ts, { c[1], c[2], c[3], soon });
                glow_bar(dl, x, by, w, bh, e[2] / math.max(1, e[3]), nil, { c[1], c[2], c[3] },
                    { c[1] * 0.75, c[2] * 0.75, c[3] * 0.75 }, 3.3 + k, fx);
            end
        end
        unsized(pushed);
        imgui.Dummy({ w + 16, (cfg.timers_up and maxn or n) * rowh + 10 });
        end_plain('timer_x', 'timer_y');
    else
        imgui.End(); imgui.PopStyleVar(2);
    end
end

----------------------------------------------------------------------------------------------------
-- Pet bar (BARS tab > PET): your avatar / wyvern / automaton / beast as YunaUI draws things: the name and HP% over a
-- thin bar, MP when it has some, TP, its job's ability timers (Blood Pact: Rage READY...), and what it's fighting.
-- Data as XIUI reads it: the pet is your entity's pet index; MP and TP from the player; the pet's target from the
-- pet sync packet (0x068) and from the pet's own actions (0x028).
----------------------------------------------------------------------------------------------------
local PET = { target = nil, tidx = nil, full = {}, preview = false };
-- per job (main or sub): the ability timers worth seeing while the pet is out
PET.ABILS = {
    [15] = { { 173, 'Blood Pact: Rage' }, { 174, 'Blood Pact: Ward' } },        -- SMN
    [9]  = { { 102, 'Ready' }, { 103, 'Reward' } },                             -- BST
    [14] = { { 162, 'Spirit Link' }, { 164, 'Deep Breathing' } },               -- DRG
    [18] = { { 206, 'Repair' }, { 207, 'Deploy' } },                            -- PUP
};
function PET.sync(e)                                                -- 0x068: the pet's owner and what it's targeting
    local me = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);
    if struct.unpack('I', e.data, 0x08 + 1) ~= me then return; end
    local t = struct.unpack('I', e.data, 0x14 + 1);
    if t and t ~= 0 then PET.target = t; PET.tidx = nil; end
end
function PET.action(e)                                              -- 0x028: the pet hitting something = its target
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    local me = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
    local pi = ent:GetPetTargetIndex(me);
    if pi == nil or pi == 0 then return; end
    if struct.unpack('I', e.data, 0x05 + 1) ~= ent:GetServerId(pi) then return; end
    local t = ashita.bits.unpack_be(e.data_raw, 0, 0x96, 0x20);
    if t and t ~= 0 and t ~= ent:GetServerId(pi) then PET.target = t; PET.tidx = nil; end
end
function PET.index_of(sid)                                          -- entity index of a server id (mobs: its low 12 bits)
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    local i = bit.band(sid, 0xFFF);
    if ent:GetServerId(i) == sid then return i; end
    for k = 0, 2303 do if ent:GetServerId(k) == sid then return k; end end
    return nil;
end
function PET.timers(pl)
    local out = {};
    local rc = AshitaCore:GetMemoryManager():GetRecast();
    for _, job in ipairs({ pl:GetMainJob(), pl:GetSubJob() }) do
        for _, a in ipairs(PET.ABILS[job] or {}) do
            local left = 0;
            for i = 0, 31 do
                if rc:GetAbilityTimerId(i) == a[1] then left = rc:GetAbilityTimer(i) or 0; break; end
            end
            local name = a[2];                                       -- (our names: a timer is shared by many pacts / moves)
            if left > (PET.full[a[1]] or 0) then PET.full[a[1]] = left; end      -- the first value seen is the full length
            if left <= 0 then PET.full[a[1]] = nil; end
            out[#out + 1] = { name, left, PET.full[a[1]] or 1 };
        end
        if #out > 0 then break; end                                  -- (main job's pet first)
    end
    return out;
end
PET.FX_DUR = { fade = 0.45, rise = 0.5, drop = 0.6, fill = 0.7, wipe = 0.5, glitch = 0.45, summon = 0.8, spell = 0.8 };
function PET.draw(dt)
    if cfg.petbar == false then return; end
    local mm = AshitaCore:GetMemoryManager();
    local pl, ent = mm:GetPlayer(), mm:GetEntity();
    if pl == nil or (pl:GetMainJob() or 0) == 0 then return; end
    local now = os.clock();
    local me = mm:GetParty():GetMemberTargetIndex(0);
    local pi = ent:GetPetTargetIndex(me) or 0;
    local d;                                                         -- what's shown
    if pi ~= 0 and (ent:GetName(pi) or '') ~= '' then
        local tp = pl:GetPetTP() or 0;
        if tp < 0 or tp > 3000 then tp = 0; end
        d = { name = ent:GetName(pi), hp = (ent:GetHPPercent(pi) or 0) / 100, mp = (pl:GetPetMPPercent() or 0) / 100, tp = tp,
            dist = math.sqrt(ent:GetDistance(pi) or 0), timers = (cfg.pet_recasts ~= false) and PET.timers(pl) or {}, idx = pi };
        if PET.pet ~= d.name then PET.pet, PET.target, PET.tidx, PET.full, PET.born = d.name, nil, nil, {}, now; end   -- a new pet: start clean
        PET.last, PET.gone, PET.pv = d, nil, nil;
        if PET.target and cfg.pet_target ~= false then
            PET.tidx = PET.tidx or PET.index_of(PET.target);
            local ti = PET.tidx;
            if ti and ti ~= pi and ent:GetServerId(ti) == PET.target and (ent:GetHPPercent(ti) or 0) > 0 then
                d.tname, d.thp = C.mob_name(ent:GetName(ti)), (ent:GetHPPercent(ti) or 0) / 100;
            else PET.target, PET.tidx = nil, nil; end                -- it died or went away
        end
    elseif PET.preview then                                          -- the BARS tab is open: a pretend Carbuncle
        if not PET.pv then PET.pv, PET.born = true, now; end
        d = { name = 'Carbuncle', hp = 1, mp = 0.8, tp = 450, dist = 8.5, idx = -1,
            timers = { { 'Blood Pact: Rage', 0, 1 }, { 'Blood Pact: Ward', 60 * (1 + (now % 60)), 3660 } }, tname = 'Goblin Mugger', thp = 0.72 };
    elseif PET.last and cfg.pet_anim ~= false then                    -- it just went: the last look fades away
        PET.gone = PET.gone or now;
        if now - PET.gone > 0.4 then PET.last, PET.gone, PET.pet, PET.pv = nil, nil, nil, nil; return; end
        d = PET.last;
    else
        PET.pet, PET.pv = nil, nil;
        return;
    end
    local fx = 'wipe';                                               -- (the pop-in: Wipe, the cleanest; the others are kept in the code)
    if cfg.pet_anim == false then fx = 'none'; end
    local appear = (fx == 'none') and 1 or math.max(0, math.min(1, (now - (PET.born or 0)) / (PET.FX_DUR[fx] or 0.5)));
    local ease = 1 - (1 - appear) ^ 3;
    local out = PET.gone and math.max(0, 1 - (now - PET.gone) / 0.4) or 1;   -- fading away when it's dismissed
    local alpha, yoff, xoff, grow = ease, 0, 0, 1;
    if fx == 'rise' then yoff = (1 - ease) * 16;
    elseif fx == 'drop' then                                         -- falls in and settles with a tiny bounce
        local b = appear - 1;
        yoff = -(1 - (1 + 2.7 * b * b * b + 1.7 * b * b)) * 28;
        alpha = math.min(1, appear * 2.5);
    elseif fx == 'fill' then grow = ease; alpha = math.min(1, appear * 3);   -- the bars fill up from empty
    elseif fx == 'wipe' then alpha = 1;
    elseif fx == 'glitch' then                                       -- flickers and jitters in
        if appear < 1 then
            local r = frac(math.sin(math.floor(now * 30) * 12.9898) * 43758.5453);
            alpha = (r > 0.35 or appear > 0.8) and (0.4 + 0.6 * appear) or 0.08;
            xoff = (r - 0.5) * 12 * (1 - appear);
        end
    elseif fx == 'summon' or fx == 'spell' then alpha = math.max(0, math.min(1, (appear - 0.25) / 0.6)); end
    alpha = alpha * out;
    local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.pet_scale) or 1);
    local w = (tonumber(cfg.pet_w) or 260) * sc;
    local bh = math.max(3, math.floor(4 * sc));
    first_place('pet_x', 'pet_y', 200, -420);
    if plain_window('YunaUI Pet##yui_pet', 'pet_x', 'pet_y') then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        local y_top = y;
        x, y = x + 6 + xoff * sc, y + 4 + yoff * sc;
        imgui.PushStyleVar(ImGuiStyleVar_Alpha, math.max(0.01, alpha));
        local clipped = false;
        if fx == 'wipe' and appear < 1 then                          -- revealed left to right
            clipped = pcall(function() C.clip(dl, { x - 8, y_top - 4 }, { x - 8 + (w + 24 * sc) * ease, y_top + 2000 }, true); end);
        end
        -- the name (and how far it is), its HP% on the right
        local pushed = sized('semi', 16 * sc);
        local nw, nh = imgui.CalcTextSize(d.name);
        text(dl, x, y, d.name, { 1, 1, 1, 1 });
        local pct = string.format('%d%%', math.floor(d.hp * 100 + 0.5));
        text(dl, x + w - imgui.CalcTextSize(pct), y, pct, { 1, 0.85, 0.92, 1 });
        unsized(pushed);
        local p2 = sized('chat', 12 * sc);
        local sh = imgui.GetTextLineHeight();
        outlined(dl, x + nw + 8 * sc, y + nh - sh - 1, string.format('%.1f', d.dist), { 0.75, 0.75, 0.85, 0.8 });
        unsized(p2);
        local cy = y + nh + 5 * sc;
        glow_bar(dl, x, cy, w, bh, d.hp * grow, (grow < 1) and nil or lagged('pet' .. d.idx, d.hp, dt), C.hp, C.hp2, 6.1);
        bar_overlay(x, cy, w * math.max(0, math.min(1, d.hp * grow)), bh, bar_fx_for('pet'), 6.1);
        cy = cy + bh + 5 * sc;
        if d.mp > 0 then
            glow_bar(dl, x, cy, w, math.max(2, bh - 1), d.mp * grow, nil, C.mpb1 or C.mp, C.mpb2 or C.mp2, 6.7);
            cy = cy + bh + 4 * sc;
        end
        -- TP, small, gold when it's 1000 or more
        p2 = sized('chat', 13 * sc);
        sh = imgui.GetTextLineHeight();
        local tpc = d.tp >= 1000 and { 1, 0.9, 0.5, 1 } or { 0.85, 0.85, 0.9, 0.85 };
        outlined(dl, x, cy, 'TP ' .. d.tp, tpc);
        cy = cy + sh + 4 * sc;
        -- its abilities: the name, READY (glowing gold) or the time left, and a thin bar that fills back up
        for k, t in ipairs(d.timers) do
            local ready = t[2] <= 0;
            outlined(dl, x, cy, t[1], ready and { 1, 0.92, 0.6, 1 } or { 0.8, 0.8, 0.88, 0.9 });
            local rs = ready and 'READY' or TIMERS.clock(t[2]);
            local pulse = ready and (0.75 + 0.25 * math.sin(now * 4 + k)) or 0.8;
            outlined(dl, x + w - imgui.CalcTextSize(rs), cy, rs, ready and { 1, 0.85, 0.45, pulse } or { 0.85, 0.85, 0.9, 0.8 });
            local ty = cy + sh + 2 * sc;
            if ready then
                glow_bar(dl, x, ty, w, 2, grow, nil, { 1.00, 0.95, 0.74 }, { 0.95, 0.76, 0.34 }, 7 + k);
            else
                glow_bar(dl, x, ty, w, 2, (1 - t[2] / math.max(1, t[3])) * grow, nil, { 0.70, 0.74, 0.95 }, { 0.45, 0.50, 0.85 }, 7 + k);
            end
            cy = ty + 2 + 6 * sc;
        end
        -- what it's fighting: a faint line, then the name and HP% over a thin bar in the enemy list's colours
        if d.tname then
            DL.L(dl, x, cy, x + w, cy, U4(1, 1, 1, 0.12), 1);
            cy = cy + 5 * sc;
            outlined(dl, x, cy, '> ' .. d.tname, { 1, 0.8, 0.75, 1 });
            local tp_ = string.format('%d%%', math.floor(d.thp * 100 + 0.5));
            outlined(dl, x + w - imgui.CalcTextSize(tp_), cy, tp_, { 1, 0.75, 0.7, 0.9 });
            cy = cy + sh + 2 * sc;
            glow_bar(dl, x, cy, w, 3, d.thp * grow, nil, { 1.00, 0.62, 0.45 }, { 0.92, 0.22, 0.28 }, 8.8);
            cy = cy + 3 + 4 * sc;
        end
        unsized(p2);
        if clipped then pcall(function() dl:PopClipRect(); end); end
        imgui.PopStyleVar(1);
        if appear < 1 and not PET.gone then                          -- each effect's own flourish, drawn at full strength
            local fade_ = 1 - appear;
            local fg = dl;                                           -- (the ones bigger than the bar go on top: not cut at its edge)
            pcall(function() fg = imgui.GetForegroundDrawList() or dl; end);
            if fx == 'rise' then                                     -- a soft light sweeping across it
                local t = math.max(0, math.min(1, (appear - 0.1) / 0.8));
                local lx = x - 40 * sc + (w + 80 * sc) * t;
                local la = math.sin(t * math.pi) * 0.45;
                pcall(function()
                    DL.RFM(dl, lx - 30 * sc, y - 2, lx, cy, U4(1, 0.85, 1, 0), U4(1, 0.85, 1, la), U4(1, 0.85, 1, la), U4(1, 0.85, 1, 0));
                    DL.RFM(dl, lx, y - 2, lx + 30 * sc, cy, U4(1, 0.85, 1, la), U4(1, 0.85, 1, 0), U4(1, 0.85, 1, 0), U4(1, 0.85, 1, la));
                end);
            elseif fx == 'wipe' then                                 -- the bright edge of the reveal
                local ex = x - 8 + (w + 24 * sc) * ease;
                DL.RF(dl, ex - 10 * sc, y - 4, ex, cy, U4(C.hp2[1], C.hp2[2], C.hp2[3], 0.16 * fade_));
                DL.RF(dl, ex - 2, y - 4, ex, cy, U4(1, 0.9, 1, 0.9 * fade_));
            elseif fx == 'glitch' then                               -- a few pink / blue scan lines
                for q = 1, 3 do
                    local r = frac(math.sin((math.floor(now * 30) + q * 7) * 78.233) * 43758.5453);
                    local ly = y + (cy - y) * r;
                    local col = (q % 2 == 0) and { 0.45, 0.85, 1.0 } or { 1.0, 0.36, 0.62 };
                    DL.RF(dl, x - 4 + (r - 0.5) * 20 * sc, ly, x + w * (0.4 + r * 0.6), ly + 2 * sc, U4(col[1], col[2], col[3], 0.45 * fade_));
                end
            elseif fx == 'summon' then                               -- rings opening out from the pet's name
                local cxr, cyr = x + 10 * sc, y + nh / 2;
                local r = (8 + appear * 70) * sc;
                DL.C(fg, cxr, cyr, r, U4(C.mp2[1], C.mp2[2], C.mp2[3], 0.9 * fade_), 48, 2);
                DL.C(fg, cxr, cyr, r * 0.6, U4(C.hp[1], C.hp[2], C.hp[3], 0.6 * fade_), 40, 1.5);
                DL.CF(fg, cxr, cyr, 10 * sc * fade_, U4(1, 0.9, 1, 0.8 * fade_), 20);
            elseif fx == 'spell' then                                -- the violet magic flash (Magic Spell 9) on the name
                local fk = math.floor((now - (PET.born or now)) * 30);
                if fk < 24 then
                    local rr = 48 * sc;
                    image(fg, tex(string.format('swap_spell9/%02d.png', fk)), x + 12 * sc - rr, y + nh / 2 - rr, x + 12 * sc + rr, y + nh / 2 + rr);
                end
            end
        end
        imgui.Dummy({ w + 12, cy - y_top + 8 });
        end_plain('pet_x', 'pet_y');
    else
        imgui.End(); imgui.PopStyleVar(2);
    end
end

local TABS = { 'GENERAL', 'TARGET', 'PARTY', 'BARS', 'CHAT', 'EQUIP', 'TIMERS', 'DAMAGE METER', 'MINIMAP', 'TREASURE POOL' };
-- Layouts (GENERAL > LAYOUT): one click puts every piece of the UI in its place for your screen size.
-- Built-in: Classic (bars bottom middle, party top right, timers left), Raid (party top left, bars stacked bottom
-- middle, timers right) and Compact (everything gathered round the bars, a little below the middle).
-- My layout 1 / 2: SAVE keeps where everything is now, LOAD puts it back.
-- PARTY > TREASURE POOL: what's in the pool (from the game's memory), everyone's lots and passes (from the game's 0x0D3
-- messages), YunaUI's own pool window with Lot / Pass, and each member's lot on the party and alliance lists while an
-- item is picked - in that window (mouse over it, or a click to keep it), or with the cursor on it in the game's own pool.
C.LOOT = { pool = {}, lots = {}, first = {}, menus = {}, n = 0, t = -1, fly = {}, hold = {}, flash = {}, rowy = {}, seen = {} };
C.LOOT.MENUS = { 'loot', 'pool', 'trea', 'lotw' };                   -- (the game's own pool window: its menu name has one of these)
C.LOOT.LIFE = 300;                                                   -- (an item stays 5 minutes in the pool)
C.LOOT.FAKE = { { 4096, 'Fire Crystal' }, { 13014, 'Leaping Boots' }, { 640, 'Copper Ore' } };   -- (the preview, to place it)
function C.loot_name(id)
    C.LOOT.names = C.LOOT.names or {};
    local nm = C.LOOT.names[id];
    if nm == nil then
        nm = '';
        pcall(function() local it = AshitaCore:GetResourceManager():GetItemById(id); nm = (it and it.Name and it.Name[1]) or ''; end);
        C.LOOT.names[id] = nm;
    end
    return nm;
end
-- Your Lot / Pass, to the game
function C.loot_act(slot, lot) C.loot_send(lot and 0x41 or 0x42, slot); end
function C.loot_read()
    local L = C.LOOT;
    local pool, n = {}, 0;
    pcall(function()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        for slot = 0, 9 do
            local it = inv:GetTreasurePoolItem(slot);
            local id = it and tonumber(it.ItemId) or 0;
            if id > 0 and id ~= 65535 then
                local key = slot .. ':' .. id .. ':' .. tostring(it.DropTime or 0);
                L.first[key] = L.first[key] or os.time();            -- (when it was first seen: the 5 minutes count from there)
                local mine = tonumber(it.Lot) or 0;
                pool[slot] = { slot = slot, id = id, key = key, at = L.first[key], mine = (mine >= 65535) and -1 or ((mine > 0) and mine or nil),
                               win = tonumber(it.WinningLot) or 0, winner = tostring(it.WinningEntityName or '') };
                n = n + 1;
            end
        end
    end);
    for slot, t in pairs(L.lots) do                                  -- (a slot with another item now: its old lots go)
        local p = pool[slot];
        if p and t.key == nil then t.key = p.key; elseif p and t.key ~= p.key then L.lots[slot] = nil; end
    end
    if n == 0 then L.lots = {}; L.first = {}; end
    L.pool, L.n = pool, n;
    if L.pick and pool[L.pick] == nil then L.pick = nil; end
end
-- The game's own treasure pool window, when it's the one in use: which item its cursor is on (nil if it isn't open)
function C.loot_menu()
    local L = C.LOOT;
    local obj, _, name = legacy.menu_ptrs();
    if obj == nil or name == nil or name == '' then return nil; end
    L.menus[name] = true;                                            -- (/yui lootmenu: the menus seen while something was in the pool)
    local low = name:lower();
    local hit = false;
    for _, k in ipairs(L.MENUS) do if low:find(k, 1, true) then hit = true; break; end end
    if not hit then return nil; end
    local idx = (ashita.memory.read_uint8(obj + 0x4C) or 1) - 1;     -- (its cursor: the row, from 1)
    pcall(function()                                                 -- (a list: its own count from the top, from 0)
        local lp = ashita.memory.read_uint32(obj + 0x0C);
        if lp and lp ~= 0 then idx = ashita.memory.read_uint16(lp + 0x30) or idx; end
    end);
    local k = 0;
    for slot = 0, 9 do
        if L.pool[slot] then
            if k == idx then return slot; end
            k = k + 1;
        end
    end
    return nil;
end
function C.loot_tick()
    local L = C.LOOT;
    if os.clock() - L.t < 0.05 then return; end
    L.t = os.clock();
    C.loot_read();
    local sel = nil;
    if L.n > 0 then
        if L.hov and L.pool[L.hov] then sel = L.hov; end
        if sel == nil then local ok, s = pcall(C.loot_menu); if ok then sel = s; end end
        if sel == nil and L.pick and L.pool[L.pick] then sel = L.pick; end
    end
    L.sel = sel;
end
-- 0x0D3: a member lotted or passed (or the item went to someone)
function C.loot_packet(e)
    local L = C.LOOT;
    local d = e.data;
    local wid = struct.unpack('I4', d, 0x04 + 1);
    local eid = struct.unpack('I4', d, 0x08 + 1);
    local wlot = struct.unpack('H', d, 0x0E + 1);
    local flag = bit.band(bit.rshift(struct.unpack('H', d, 0x10 + 1), 15), 1);
    local lot = struct.unpack('h', d, 0x12 + 1);
    local slot = struct.unpack('B', d, 0x14 + 1);
    local judge = struct.unpack('B', d, 0x15 + 1);
    local wname = (d:sub(0x16 + 1, 0x16 + 16):match('^[^%z]*')) or '';
    local ename = (d:sub(0x26 + 1, 0x26 + 16):match('^[^%z]*')) or '';
    if slot == nil or slot > 9 then return; end
    if (judge or 0) >= 1 then L.lots[slot] = nil; return; end         -- (it went to someone, or nobody wanted it)
    local cur = L.pool[slot];
    local t = L.lots[slot];
    if t == nil or (cur and t.key and t.key ~= cur.key) then t = { key = cur and cur.key or nil, by = {} }; L.lots[slot] = t; end
    if (eid or 0) > 0 and ename ~= '' then
        if flag == 1 or (lot or 0) < 0 then t.by[ename] = -1; else t.by[ename] = lot; end
    end
    if (wid or 0) > 0 and (wlot or 0) > 0 then t.win, t.wlot = wname, wlot; end
end
-- A member's lot on the picked item: a number, -1 for a pass, nil for not yet
function C.lot_of(name, slot)
    local L = C.LOOT;
    slot = slot or L.sel;
    if slot == nil or name == nil then return nil; end
    local t = L.lots[slot];
    local v = t and t.by[name];
    if v == nil then                                                 -- (yourself: the game keeps your own lot)
        local me = '';
        pcall(function() me = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0) or ''; end);
        if name == me and L.pool[slot] then v = L.pool[slot].mine; end
    end
    return v;
end
function C.loot_waiting(slot)
    local out = {};
    for i = 0, 17 do
        local m = member(i);
        if m and m.name and m.inzone ~= false and C.lot_of(m.name, slot) == nil then out[#out + 1] = m.name; end
    end
    return out;
end
function C.lot_winner(slot)
    local L = C.LOOT;
    local t, p = L.lots[slot], L.pool[slot];
    if t and t.win and t.win ~= '' then return t.win, t.wlot; end
    if p and p.winner ~= '' and (p.win or 0) > 0 and p.win < 65535 then return p.winner, p.win; end
    return nil, nil;
end
-- The job tag turning over to its back (the lot) and back again: how far it has turned, eased; gives back nil when it
-- shows the job and isn't moving. The lot stays on the back while it turns back, so it never shows an empty tag.
function C.lot_flip(m, i)
    if m == nil then return nil; end
    local L = C.LOOT;
    L.fk, L.fv = L.fk or {}, L.fv or {};
    local key = m.name or ('m' .. i);
    local lv = (L.sel ~= nil) and C.lot_of(m.name) or nil;
    local wait = L.sel ~= nil and lv == nil and m.inzone ~= false;   -- (still to lot or pass: an amber "?")
    if lv ~= nil then L.fv[key] = lv; elseif wait then L.fv[key] = 'wait'; end
    local k = L.fk[key] or 0;
    local want = (lv ~= nil or wait) and 1 or 0;
    if k == 0 and want == 0 then return nil; end
    local dt = imgui.GetIO().DeltaTime or 0.016;
    k = (want > k) and math.min(1, k + dt * 3.0) or math.max(0, k - dt * 3.0);
    L.fk[key] = k;
    local e = (k < 0.5) and (2 * k * k) or (1 - ((2 - 2 * k) ^ 2) / 2);
    local val = L.fv[key] or -1;
    local back = e > 0.5;
    if val == 'wait' then
        local q = 0.80 + 0.20 * math.sin(os.clock() * 3 + i);
        return { w = math.max(0.04, math.abs(math.cos(math.pi * e))), back = back, text = '?', fill = { 1.0 * q, 0.66 * q, 0.26 * q },
                 ink = { 0.22, 0.12, 0.02 }, glow = 0 };
    end
    local wn = L.sel and C.lot_winner(L.sel) or nil;
    local win = back and val >= 0 and wn ~= nil and wn == m.name;
    return { w = math.max(0.04, math.abs(math.cos(math.pi * e))), back = back, text = (val < 0) and '--' or tostring(val),
             fill = win and { 1.0, 0.80, 0.34 } or ((val < 0) and { 0.22, 0.21, 0.27 } or { 0.93, 0.91, 0.98 }),
             ink = win and { 0.30, 0.18, 0.02 } or ((val < 0) and { 0.70, 0.68, 0.78 } or { 0.10, 0.09, 0.14 }),
             glow = win and (0.5 + 0.5 * math.sin(os.clock() * 4)) or 0 };
end
-- On a member's card: its lot on the picked item, in a small dark pill at the card's right end (over the HP %);
-- the highest in gold, a pass as "--"
function C.lot_badge(dl, m, x1, tip, ny, ch, sc, v, party)
    if C.LOOT.sel == nil or m == nil or (cfg.card_style or 'clean') == 'clean' then return; end
    local lv = C.lot_of(m.name);
    if lv == nil then return; end
    local str = (lv < 0) and '--' or tostring(lv);
    local wn = C.lot_winner(C.LOOT.sel);
    local win = lv >= 0 and wn ~= nil and wn == m.name;
    local fs = FS or 1;
    imgui.SetWindowFontScale(fs * 0.80 * 0.86);
    local tw_, th_ = imgui.CalcTextSize(str);
    th_ = tonumber(th_) or 12;
    local pw, ph = tw_ + 14 * sc, th_ + 4 * sc;
    local rx = tip - ch * 0.30 * 0.5 - 6 * sc - (party and ALLY.tpw(sc) or 0);
    local bx, by = rx - pw, ny - ph / 2;
    DL.RF(dl, bx, by, bx + pw, by + ph, U4(0.045, 0.04, 0.065, 0.95 * v), ph / 2);
    local ec = win and { 1.0, 0.82, 0.42, 0.95 * v } or { NEON2[1], NEON2[2], NEON2[3], ((lv < 0) and 0.25 or 0.6) * v };
    DL.R(dl, bx, by, bx + pw, by + ph, u32(ec), ph / 2, C.rall, 1.2);
    local tc = win and { 1.0, 0.86, 0.48, v } or ((lv < 0) and { 0.62, 0.60, 0.70, v } or { 1, 1, 1, v });
    text(dl, bx + (pw - tw_) / 2, by + (ph - th_) / 2, str, tc);
    imgui.SetWindowFontScale(fs * 0.80);
end
-- Under a member's name, when they're in another zone: where they are (PARTY > Zone of members elsewhere)
function C.zone_name(id)
    C.ZN = C.ZN or {};
    if C.ZN[id] == nil then
        local nm = '';
        pcall(function() nm = AshitaCore:GetResourceManager():GetString('zones.names', id) or ''; end);
        C.ZN[id] = nm;
    end
    return C.ZN[id];
end
function C.zone_line(dl, m, x, y, w, sc, v)
    if cfg.party_zone == false or m == nil or m.inzone or m.fake or (tonumber(m.zone) or 0) <= 0 or w < 20 then return; end
    local zn = C.zone_name(m.zone);
    if zn == nil or zn == '' then return; end
    local fs = FS or 1;
    imgui.SetWindowFontScale(fs * 0.80 * 0.70);
    text(dl, x, y, ALLY.fit(zn, w), { 0.80, 0.74, 0.92, 0.85 * v });
    imgui.SetWindowFontScale(fs * 0.80);
end
-- YunaUI's treasure pool, in the party list's look: each item a slanted card - its icon in a dark block, its name in
-- spaced capitals, a thin glowing time bar, who is winning and the time left - with slanted LOT / PASS tags at its right.
-- The cards slide in from the left; an item that drops pops out of the monster and glides in first.
function C.lw_bez(P, t)
    local u = 1 - t;
    local a, b, c, d = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t;
    return a * P[1][1] + b * P[2][1] + c * P[3][1] + d * P[4][1], a * P[1][2] + b * P[2][2] + c * P[3][2] + d * P[4][2];
end
function C.loot_send(pid, slot)
    pcall(function() AshitaCore:GetPacketManager():AddOutgoingPacket(pid, { pid, 0x04, 0x00, 0x00, slot, 0x00, 0x00, 0x00 }); end);
end
-- 0x0D2: an item fell in the pool - from which monster (0x12: its index; 0x08: its id) - so it can fly from where it died
function C.loot_drop(e)
    local d = e.data;
    local sid = struct.unpack('I4', d, 0x08 + 1) or 0;
    local id = struct.unpack('H', d, 0x10 + 1) or 0;
    local idx = struct.unpack('H', d, 0x12 + 1) or 0;
    local slot = struct.unpack('B', d, 0x14 + 1);
    local old = struct.unpack('B', d, 0x15 + 1) or 0;                -- (already there when you came in: no flight)
    if slot == nil or slot > 9 or id == 0 or old ~= 0 then return; end
    if idx == 0 and sid > 0 then idx = bit.band(sid, 0xFFF); end
    C.loot_fly(slot, id, idx);
end
function C.loot_fly(slot, id, idx)
    local L = C.LOOT;
    local w = nil;
    pcall(function()
        local ent = AshitaCore:GetMemoryManager():GetEntity();
        local ap = (idx and idx > 0) and ent:GetActorPointer(idx) or nil;
        local ahead = false;
        if ap == nil or ap == 0 then                                 -- (no monster: from just in front of you)
            ap = ent:GetActorPointer(AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0) or 0);
            ahead = true;
        end
        if ap and ap ~= 0 then
            w = { ashita.memory.read_float(ap + 0x678), ashita.memory.read_float(ap + 0x680), ashita.memory.read_float(ap + 0x67C) };
            if ahead then w[1] = w[1] + 2.5; end
        end
    end);
    local t0 = math.max(os.clock(), (L.fly_last or 0) + 0.22);       -- (several at once: one after another)
    L.fly_last = t0;
    L.fly[#L.fly + 1] = { t0 = t0, slot = slot, id = id, w = w };
    L.hold[slot] = t0 + C.LOOT.FLY;
end
C.LOOT.FLY = 1.0;
-- The flights: from the monster's place on screen, curving into the line on the pool's left side, the item's icon at its head
function C.loot_flights(fg, sc)
    local L = C.LOOT;
    local now = os.clock();
    local keep = {};
    local W, H = C.screen();
    for _, f in ipairs(L.fly) do
        local t = (now - f.t0) / L.FLY;
        if t < 1.05 then keep[#keep + 1] = f; end
        if t >= 0 and t < 1.05 then
            local sx, sy = nil, nil;
            if f.w then pcall(function() sx, sy = C.w2s(f.w[1], f.w[3] - 1.0, f.w[2]); end); end
            if sx == nil then sx, sy = W * 0.5, H * 0.62; end
            local win = L.win or { tonumber(cfg.loot_x) or 100, tonumber(cfg.loot_y) or 100, 360 * sc, 200 * sc };
            local tx, ty = win[1] + 2 * sc, L.rowy[f.slot] or (win[2] + win[4] * 0.5);
            local P = { { sx, sy }, { sx + (tx - sx) * 0.25, sy - 140 * sc }, { tx - 160 * sc, ty - 30 * sc }, { tx + 30 * sc, ty } };
            if t < 1 then
                local pop = math.min(1, t / 0.18);                   -- (the pop: out of the monster, a touch past full size)
                local grow = (pop < 1) and (1 - (1 - pop) ^ 3) * 1.15 or (1 + 0.15 * math.max(0, 1 - (t - 0.18) / 0.15));
                local tt = math.max(0, (t - 0.12) / 0.88);           -- (the toss: up and over, into its place)
                local e = tt * tt * (3 - 2 * tt);
                local hx, hy = C.lw_bez(P, e);
                local spin = math.cos(e * math.pi * 6);              -- (three turns: it narrows to its edge and opens again)
                local wk = math.max(0.06, math.abs(spin));
                local R = 17 * sc * grow * math.max(0.3, math.min(3, tonumber(cfg.loot_coin_scale) or 1));   -- (PARTY > TREASURE POOL > Drop coin size)
                local ga = (t < 0.85) and 1 or math.max(0, 1 - (t - 0.85) / 0.15);
                local function ell(cx_, cy_, rx, ry)                  -- (an ellipse, as points: a coin seen turning)
                    local pts = {};
                    for k = 0, 27 do local an = k / 28 * math.pi * 2; pts[#pts + 1] = { cx_ + math.cos(an) * rx, cy_ + math.sin(an) * ry }; end
                    return pts;
                end
                DL.CF(fg, hx, hy, R * 1.25, U4(1.0, 0.82, 0.40, 0.06 * ga), 24);   -- (a faint warm halo, hugging it)
                local side = (1 - wk) * 3.5 * sc * ((spin < 0) and -1 or 1);   -- (its thickness, showing as it turns)
                ALLY.poly(fg, ell(hx + side, hy, R * wk, R), U4(0.66, 0.42, 0.10, ga));
                ALLY.poly(fg, ell(hx, hy, R * wk, R), U4(1.0, 0.84, 0.38, ga));   -- its bright rim
                ALLY.poly(fg, ell(hx, hy, R * 0.82 * wk, R * 0.82), U4(0.70, 0.46, 0.12, ga));   -- its face, a deeper gold
                local ic = YUI_EQ_ICON and YUI_EQ_ICON(f.id) or nil;  -- the item on its face (mirrored on the back)
                if ic and wk > 0.22 then
                    local iw, ih = R * 1.08 * wk / 2, R * 1.08 / 2;
                    pcall(function() DL.I(fg, ic.ptr, hx - iw, hy - ih, hx + iw, hy + ih, (spin < 0) and 1 or 0, 0, (spin < 0) and 0 or 1, 1, U4(1, 1, 1, ga)); end);
                end
                DL.CF(fg, hx - R * 0.45 * wk, hy - R * 0.55, math.max(1, R * 0.10), U4(1, 1, 0.92, 0.75 * ga * wk), 10);   -- (a glint on its rim)
                local tw = 0.5 + 0.5 * math.sin(now * 14 + f.slot * 2.1);   -- a small sparkle by it, twinkling
                local sx_, sy_ = hx + R * 0.95, hy - R * 0.95;
                local sr = (3 + 4 * tw) * sc;
                local sq = sr * 0.22;
                ALLY.poly(fg, { { sx_, sy_ - sr }, { sx_ + sq, sy_ }, { sx_, sy_ + sr }, { sx_ - sq, sy_ } }, U4(1, 0.95, 0.75, ga));
                ALLY.poly(fg, { { sx_ - sr, sy_ }, { sx_, sy_ - sq }, { sx_ + sr, sy_ }, { sx_, sy_ + sq } }, U4(1, 0.95, 0.75, ga));
            elseif not f.done then
                f.done = true;
                L.flash[f.slot] = now;                               -- (it arrived: the line on the left lights up, the row slides out)
            end
        end
    end
    L.fly = keep;
end
-- Who is still to lot or pass on the item under the mouse: a small dark card by the pool - "WAITING ON" and how many in
-- amber, then their names in columns, each with a dot in its role's colour
function C.loot_wait_card(w, sc)
    local fg = imgui.GetForegroundDrawList();
    local fs = FS or 1;
    local rows_ = {};
    for _, nm in ipairs(w.wait) do
        local col = { 0.75, 0.72, 0.85 };
        for i = 0, 17 do local m = member(i); if m and m.name == nm then col = ALLY.role(m.job); break; end end
        rows_[#rows_ + 1] = { nm, col };
    end
    local n = #rows_;
    local cols = (n > 10) and 3 or ((n > 5) and 2 or 1);
    local per = math.ceil(n / cols);
    imgui.SetWindowFontScale(fs * 0.62);
    local cw, lh = 0, 0;
    for _, r in ipairs(rows_) do local tw_, th_ = imgui.CalcTextSize(r[1]); cw = math.max(cw, tw_); lh = math.max(lh, tonumber(th_) or 12); end
    cw = cw + 18 * sc;
    local pad = 10 * sc;
    local head = lh + 10 * sc;
    local htxt = 'WAITING ON ' .. n;                                 -- (its title: spaced letters, measured at the size they're drawn)
    local hw = 0;
    for i = 1, #htxt do hw = hw + imgui.CalcTextSize(htxt:sub(i, i)) + 1.6 * sc; end
    local Wc = math.max(cols * cw + (cols - 1) * 8 * sc, hw + 14 * sc) + pad * 2;
    local Hc = head + per * (lh + 3 * sc) + pad * 1.6;
    local SW, SH = C.screen();
    local x, y = w.x, w.y;
    if x + Wc > SW - 4 then x = SW - 4 - Wc; end
    if y + Hc > SH - 4 then y = SH - 4 - Hc; end
    for k = 3, 1, -1 do DL.RF(fg, x - k * 2, y - k * 2 + 3, x + Wc + k * 2, y + Hc + k * 2 + 3, U4(0, 0, 0, 0.10), 10 * sc + k * 2); end
    DL.RF(fg, x, y, x + Wc, y + Hc, U4(0.035, 0.03, 0.05, 0.95), 9 * sc);
    DL.R(fg, x, y, x + Wc, y + Hc, U4(1.0, 0.66, 0.28, 0.35), 9 * sc, C.rall, 1);
    DL.RF(fg, x + 9 * sc, y, x + Wc - 9 * sc, y + 1.5 * sc, U4(1.0, 0.70, 0.32, 0.85));   -- (a fine amber line along its top)
    local q = 0.75 + 0.25 * math.sin(os.clock() * 3);
    DL.CF(fg, x + pad + 3 * sc, y + pad + lh / 2, 2.6 * sc, U4(1.0, 0.66, 0.26, q), 10);
    local hx = x + pad + 12 * sc;
    for i = 1, #htxt do
        local ch = htxt:sub(i, i);
        text(fg, hx, y + pad, ch, { 1.0, 0.74, 0.38, 1 });
        hx = hx + imgui.CalcTextSize(ch) + 1.6 * sc;
    end
    DL.L(fg, x + pad, y + pad + head - 4 * sc, x + Wc - pad, y + pad + head - 4 * sc, U4(1, 1, 1, 0.08), 1);
    for k, r in ipairs(rows_) do
        local c_ = math.floor((k - 1) / per);
        local r_ = (k - 1) % per;
        local nx = x + pad + c_ * (cw + 8 * sc);
        local ny = y + pad + head + r_ * (lh + 3 * sc);
        DL.CF(fg, nx + 3 * sc, ny + lh / 2, 2.4 * sc, U4(r[2][1], r[2][2], r[2][3], 1), 10);
        text(fg, nx + 11 * sc, ny, r[1], { 0.93, 0.91, 0.97, 1 });
    end
    imgui.SetWindowFontScale(fs);
end
-- A slanted tag button, as the party list's job tags: LOT pink with dark letters, PASS lavender-grey with light ones;
-- under the mouse (or lit) it brightens and lifts a little
function C.loot_btn(dl, id, x, y, w, h, label, kind, on, lit)
    imgui.SetCursorScreenPos({ x, y });
    local hit = imgui.InvisibleButton(id, { w, h });
    local hov = (imgui.IsItemHovered() and on) or lit;
    local pink = kind == 'lot';
    local s = h * 0.30;
    local up = hov and 1.5 * C.ps or 0;
    local f = pink and { 0.97, 0.76, 0.30 } or { 0.40, 0.38, 0.54 };   -- (LOT: gold - it's loot)
    if hov then f = { math.min(1, f[1] + 0.06), math.min(1, f[2] + 0.10), math.min(1, f[3] + 0.08) }; end
    local ink = pink and { 0.28, 0.16, 0.02 } or { 0.96, 0.95, 1.0 };
    local a = on and 1 or 0.45;
    local pts = { { x + s, y - up }, { x + w, y - up }, { x + w - s, y + h - up }, { x, y + h - up } };
    ALLY.poly(dl, pts, U4(f[1], f[2], f[3], a));
    local tw_, th_ = imgui.CalcTextSize(label);
    DL.T(dl, x + (w - tw_) / 2, y - up + (h - (tonumber(th_) or h)) / 2, U4(ink[1], ink[2], ink[3], a), label);
    return hit and on;
end
function C.loot_win()
    C.loot_tick();
    local L = C.LOOT;
    local now = os.clock();
    local fg = nil;
    pcall(function() fg = imgui.GetForegroundDrawList(); end);
    local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.loot_scale) or 1);
    if fg and #L.fly > 0 then pcall(C.loot_flights, fg, sc); end
    if cfg.loot_win == false then L.hov = nil; return; end
    local fake = L.n == 0 and (EDIT.on or (ui.open and ui.tab == 10));   -- (its tab open, or Edit Mode: a preview to place it)
    if L.n == 0 and not fake then L.hov = nil; return; end
    local items = {};
    if fake then
        for k, f in ipairs(L.FAKE) do items[#items + 1] = { slot = k - 1, id = f[1], name = f[2], at = os.time() - k * 70, fake = true }; end
    else
        for slot = 0, 9 do
            local p = L.pool[slot];
            if p and not (L.hold[slot] and now < L.hold[slot]) then items[#items + 1] = p; end   -- (still flying in: not yet)
        end
    end
    first_place('loot_x', 'loot_y', 320, -560);
    if not plain_window('YunaUI Treasure##yui_loot', 'loot_x', 'loot_y') then imgui.End(); imgui.PopStyleVar(2); return; end
    local dl = imgui.GetWindowDrawList();
    pcall(function() C.fullclip(dl); end);
    local x, y = imgui.GetCursorScreenPos();
    local pushed = sized('chat', 17 * sc);
    local fs = FS or 1;
    local W = math.floor(350 * sc);
    local rh = math.floor(46 * sc);
    local gap = math.floor(6 * sc);
    local th = math.floor(rh * 0.50);                                -- (the LOT / PASS tags' height)
    local sl = rh * 0.30;                                            -- (the cards' lean, as the party's)
    local all = (#items > 1 or fake);
    local H = math.max(1, #items) * (rh + gap) + (all and (th + 12 * sc) or 0);
    L.win = { x, y, W, H };
    local ry = math.floor(y + 0.5);
    local hov = nil;
    L.wtip = nil;
    local mx, my = imgui.GetMousePos();
    L.rowy = L.rowy or {};
    local function letters(px, py, str, col, sp)                     -- (spaced capitals, each letter with its dark edge)
        for i = 1, #str do
            local ch = str:sub(i, i);
            text(dl, px, py, ch, col);
            px = px + imgui.CalcTextSize(ch) + sp;
        end
        return px;
    end
    for r_, it in ipairs(items) do
        local slot = it.slot;
        local key = it.key or ('f' .. slot);
        local seen = L.seen[key];
        if seen == nil then seen = now + (r_ - 1) * 0.07; L.seen[key] = seen; end   -- (several at once: one after another)
        local ik = math.max(0, math.min(1, (now - seen) / 0.35));    -- (it slides in from the left, fading in)
        ik = 1 - (1 - ik) ^ 3;
        local ox = -(1 - ik) * 30 * sc;
        local cy = ry + rh / 2;
        L.rowy[slot] = cy;
        local over = mx >= x and mx <= x + W and my >= ry and my <= ry + rh;
        if over then hov = slot; end
        local picked = (not fake) and L.pick == slot;
        imgui.PushStyleVar(ImGuiStyleVar_Alpha, math.max(0.01, ik));
        local x0 = math.floor(x + ox + 0.5);                          -- (on whole pixels: crisp edges)
        local bw0 = rh * 1.05;                                       -- the icon's block: dark, a bright stripe down its left side
        local blk = { { x0 + sl, ry }, { x0 + sl + bw0, ry }, { x0 + bw0, ry + rh }, { x0, ry + rh } };
        ALLY.poly(dl, blk, U4(0.07, 0.065, 0.10, 0.92));
        local mine0 = (not fake) and it.mine or nil;                 -- (its colour: gold; brighter if it's going to you, grey once passed)
        local wn0 = (not fake) and C.lot_winner(slot) or nil;
        local me0 = '';
        pcall(function() me0 = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0) or ''; end);
        local hc = (mine0 and mine0 >= 0 and wn0 == me0) and { 1.0, 0.93, 0.62 } or ((mine0 and mine0 < 0) and { 0.50, 0.48, 0.62 } or { 0.96, 0.74, 0.28 });
        for k = 1, 4 do dl:AddLine(blk[k], blk[k % 4 + 1], U4(0.96, 0.76, 0.32, picked and 1 or 0.45), picked and 1.3 or 1); end
        local sw1 = math.max(2, math.floor(2.5 * sc + 0.5));         -- (just the line, crisp, over the block's edge)
        ALLY.poly(dl, { { x0 + sl, ry }, { x0 + sl + sw1, ry }, { x0 + sw1, ry + rh }, { x0, ry + rh } }, U4(hc[1], hc[2], hc[3], 1));
        local isz = rh - 12 * sc;
        local ic = YUI_EQ_ICON and YUI_EQ_ICON(it.id) or nil;
        local icx = x0 + (bw0 + sl) / 2 + 2 * sc;
        if ic then pcall(function() DL.I(dl, ic.ptr, icx - isz / 2, cy - isz / 2, icx + isz / 2, cy + isz / 2, 0, 0, 1, 1, U4(1, 1, 1, 1)); end); end
        local gp = 3 * sc;                                           -- the card: dark, a little see-through, a light along its top
        local c0 = x0 + bw0 + gp;
        local card = { { c0 + sl, ry }, { x0 + W, ry }, { x0 + W - sl, ry + rh }, { c0, ry + rh } };
        ALLY.poly(dl, card, U4(0.085, 0.08, 0.115, (over or picked) and 0.90 or 0.82));
        ALLY.grad(dl, { c0 + sl, ry }, { x0 + W - sl, ry + 1 }, { 1, 1, 1, 0.14 }, { 1, 1, 1, 0 }, { 1, 1, 1, 0 }, { 1, 1, 1, 0.14 });
        local fl1 = L.flash[slot] and math.max(0, 1 - (now - L.flash[slot]) / 0.6) or 0;   -- (just landed: its gold edge flashes)
        if fl1 > 0 then pcall(ALLY.glow_ring, dl, card, 3 * sc, U4(1.0, 0.85, 0.45, 0.30 * fl1)); end
        local ea = math.max(picked and 1 or 0.45, fl1);
        for k = 1, 4 do dl:AddLine(card[k], card[k % 4 + 1], U4(0.96 + 0.04 * fl1, 0.76 + 0.14 * fl1, 0.32 + 0.30 * fl1, ea), (picked and 1.3 or 1) + fl1); end   -- (a gold edge; bright on the picked one)
        local bx_ = x0 + W - sl * 0.5 - 8 * sc;                      -- your LOT / PASS (or what you did), at its right end
        local mine = (not fake) and it.mine or nil;
        local bw_ = math.floor(46 * sc);
        imgui.SetWindowFontScale(fs * 0.62);
        local by_ = cy - th / 2;
        if mine == nil then
            if C.loot_btn(dl, '##yui_pass' .. slot, bx_ - bw_, by_, bw_, th, 'PASS', 'pass', not fake) then C.loot_act(slot, false); end
            if C.loot_btn(dl, '##yui_lot' .. slot, bx_ - bw_ * 2 - 4 * sc, by_, bw_, th, 'LOT', 'lot', not fake, picked) then C.loot_act(slot, true); end
            bx_ = bx_ - bw_ * 2 - 12 * sc;
        else
            if mine >= 0 then
                if C.loot_btn(dl, '##yui_pass' .. slot, bx_ - bw_, by_, bw_, th, 'PASS', 'pass', true) then C.loot_act(slot, false); end
                bx_ = bx_ - bw_ - 8 * sc;
            end
            local s_ = (mine < 0) and 'PASSED' or ('YOU ' .. mine);
            local sw_ = 0;
            for i = 1, #s_ do sw_ = sw_ + imgui.CalcTextSize(s_:sub(i, i)) + 1 * sc; end
            letters(bx_ - sw_, cy - 7 * sc, s_, (mine < 0) and { 0.66, 0.64, 0.78, 1 } or { 1, 0.90, 0.96, 1 }, 1 * sc);
            bx_ = bx_ - sw_ - 10 * sc;
        end
        local tx = c0 + sl * 0.6 + 6 * sc;                           -- its name in spaced capitals, the time bar, who is winning
        local nm = it.name or C.loot_name(it.id);
        nm = ((nm ~= '' and nm) or ('Item ' .. it.id)):upper();
        imgui.SetWindowFontScale(fs * 0.72);
        local _, nh = imgui.CalcTextSize('A');
        nh = tonumber(nh) or 14;
        local room = bx_ - tx;
        if spaced_w(nm, 1 * sc) > room then
            while #nm > 2 and spaced_w(nm .. '.', 1 * sc) > room do nm = nm:sub(1, -2); end
            nm = nm .. '.';
        end
        local ny = ry + 5 * sc;
        letters(tx, ny, nm, { 1, 1, 1, 1 }, 1 * sc);
        local left = math.max(0, L.LIFE - (os.time() - (it.at or os.time())));
        local f = left / L.LIFE;
        local barw = math.max(10, bx_ - tx);
        local hy = ny + nh + 2 * sc;
        local bh2 = math.max(2, math.floor(3 * sc));
        local c1 = (left < 60) and { 1.0, 0.36, 0.40 } or { 1.0, 0.86, 0.46 };
        local c2 = (left < 60) and { 0.80, 0.10, 0.20 } or { 0.86, 0.56, 0.16 };
        pcall(glow_bar, dl, tx, hy, barw, bh2, f, f, c1, c2, slot);
        imgui.SetWindowFontScale(fs * 0.60);
        local wn, wl = nil, nil;
        if fake then wn, wl = (slot == 0) and 'Yunas' or nil, (slot == 0) and 742 or nil; else wn, wl = C.lot_winner(slot); end
        local wait = fake and { 'Bardo', 'Corsi' } or C.loot_waiting(slot);
        local ts = string.format('%d:%02d', math.floor(left / 60), left % 60);
        local tsw = imgui.CalcTextSize(ts);
        local sub = wn and (wn .. ' ' .. wl) or 'No lots yet';
        local sy_ = hy + bh2 + 2 * sc;
        text(dl, tx, sy_, ALLY.fit(sub, barw - tsw - 10 * sc), wn and { 1.0, 0.82, 0.42, 1 } or { 0.66, 0.70, 0.96, 1 });
        local tq = (left < 60) and (0.70 + 0.30 * math.sin(now * 5)) or 1;
        text(dl, tx + barw - tsw, sy_, ts, (left < 60) and { 1.0, 0.45, 0.48, tq } or { 0.80, 0.78, 0.90, 0.9 });
        if over and #wait > 0 then L.wtip = { wait = wait, x = x + W + 10 * sc, y = ry }; end
        imgui.SetWindowFontScale(fs);
        if not fake and over and mx < bx_ and imgui.IsMouseClicked(0) then L.pick = (L.pick == slot) and nil or slot; end   -- (a click keeps it picked)
        imgui.PopStyleVar(1);
        ry = ry + rh + gap;
    end
    if all then                                                      -- LOT ALL / PASS ALL: two tags at its foot, on the right
        imgui.SetWindowFontScale(fs * 0.60);
        local bw2 = math.floor(76 * sc);
        local fy = ry + 4 * sc;
        local x2 = x + W - sl * 0.5 - 8 * sc - bw2 * 2 - 4 * sc;
        if C.loot_btn(dl, '##yui_lotall', x2, fy, bw2, th, 'LOT ALL', 'lot', not fake, (not fake) and L.pick ~= nil) then
            for _, it in ipairs(items) do if it.mine == nil then C.loot_act(it.slot, true); end end
        end
        if C.loot_btn(dl, '##yui_passall', x2 + bw2 + 4 * sc, fy, bw2, th, 'PASS ALL', 'pass', not fake) then
            for _, it in ipairs(items) do if it.mine == nil then C.loot_act(it.slot, false); end end
        end
        imgui.SetWindowFontScale(fs);
    end
    L.hov = (not fake) and hov or nil;
    if L.wtip then pcall(C.loot_wait_card, L.wtip, sc); end
    unsized(pushed);
    imgui.SetCursorScreenPos({ x, y });
    imgui.Dummy({ W, H });
    end_plain('loot_x', 'loot_y');
end
local LAYOUT = {
    KEYS = { 'target', 'sub', 'enemy', 'party', 'alliance', 'ally2', 'chat', 'chat2', 'exp', 'gil', 'bag', 'cast', 'timer', 'pet', 'doll', 'map', 'bigmap', 'loot' },
    GUESS = { loot = { 350, 270 }, target = { 540, 60 }, sub = { 320, 50 }, enemy = { 230, 220 }, party = { 340, 300 }, alliance = { 260, 170 },
              ally2 = { 260, 170 }, exp = { 540, 40 }, gil = { 170, 26 }, bag = { 320, 26 }, cast = { 320, 44 },
              timer = { 290, 230 }, pet = { 290, 180 }, doll = { 300, 420 } },
    FULL = { party = true, alliance = true, ally2 = true, enemy = true, timer = true, pet = true },   -- (lists that grow)
};
function LAYOUT.size(k)
    if k == 'chat' then return tonumber(cfg.chat_w) or 620, tonumber(cfg.chat_h) or 260; end
    if k == 'chat2' then return tonumber(cfg.chat2_w) or 520, tonumber(cfg.chat2_h) or 260; end
    if k == 'dps' then                                               -- the Damage Meter: its own window (dps.lua), at its size
        local ds = YUI_DPS and YUI_DPS.get and YUI_DPS.get() or nil;
        local z = ((ds and tonumber(ds.size)) or 100) / 100;
        return math.floor(404 * z), math.floor(((ds and tonumber(ds.h)) or 300) * z);
    end
    if k == 'fan' then                                               -- the skillchain fan in a window of its own (TARGET > Anywhere)
        local fsc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.target_scale) or 1) * FIGHT.fsc();
        return FIGHT.fan_size(fsc);
    end
    local sc = tonumber(cfg.scale) or 1;
    local m = WATCH.size and WATCH.size[k .. '_x'];
    if k == 'loot' then                                              -- (the pool: as it shows with four items)
        local ls = sc * (tonumber(cfg.loot_scale) or 1);
        if m and m[1] > 4 then return m[1], math.max(m[2], 270 * ls); end
        return 350 * ls, 270 * ls;
    end
    if k == 'map' and not (m and m[1] > 4) then                      -- (not shown yet: the map's own size and its title)
        local M = (tonumber(cfg.map_size) or 220) * sc;
        return M + 8, M + 40;
    end
    local g = LAYOUT.GUESS[k] or { 300, 100 };
    local gh = g[2] * sc * ((k == 'party') and (tonumber(cfg.party_scale) or 1) or 1);
    if m and m[1] > 4 and m[2] > 4 then                              -- (measured while it was on screen)
        if LAYOUT.FULL[k] then return m[1], math.max(m[2], gh); end  -- (a list measured short - solo, one enemy: room for a full one)
        return m[1], m[2];
    end
    return g[1] * sc, gh;
end
-- Put piece k so its own (ax, ay) corner sits at the screen's (ax, ay) point, moved by (ox, oy)
function LAYOUT.at(out, k, ax, ay, ox, oy)
    local W, H = LAYOUT.W, LAYOUT.H;
    local w, h = LAYOUT.size(k);
    LAYOUT.xy(out, k, W * ax - w * ax + (ox or 0), H * ay - h * ay + (oy or 0));
end
function LAYOUT.xy(out, k, x, y)
    if k == 'dps' then out._dps = { math.floor(x), math.floor(y) }; return; end   -- (the meter is placed through dps.lua)
    if LAYOUT.auto and LAYOUT.auto[k] then return; end               -- (alliances anchored to the party: they follow it)
    out[k .. '_x'], out[k .. '_y'] = math.floor(x), math.floor(y);
end
-- The room already given out, so no two pieces ever sit on each other
function LAYOUT.take(x, y, w, h) LAYOUT.taken[#LAYOUT.taken + 1] = { x, y, w, h }; end
function LAYOUT.hit(x, y, w, h)
    for _, r in ipairs(LAYOUT.taken) do
        if x < r[1] + r[3] and x + w > r[1] and y < r[2] + r[4] and y + h > r[2] then return r; end
    end
    return nil;
end
function LAYOUT.put(o, k, x, y)                                      -- (a piece at a fixed place, its room taken)
    local w, h = LAYOUT.size(k);
    LAYOUT.xy(o, k, x, y);
    LAYOUT.take(x, y, w, h);
end
function LAYOUT.put_free(o, k, x, y, dx, dy)
    local w, h = LAYOUT.size(k);
    for _ = 1, 20 do
        local r = LAYOUT.hit(x, y, w, h);
        if r == nil then break; end
        if dx < 0 then x = r[1] - w - 16; elseif dx > 0 then x = r[1] + r[3] + 16; end
        if dy < 0 then y = r[2] - h - 12; elseif dy > 0 then y = r[2] + r[4] + 12; end
    end
    x, y = math.max(0, math.min(LAYOUT.W - w, x)), math.max(0, math.min(LAYOUT.H - h, y));
    LAYOUT.xy(o, k, x, y);
    LAYOUT.take(x, y, w, h);
end
-- Pieces in a column from (x, y0) down to ybot, each under the one before (and under anything already there); one that
-- doesn't fit starts the next column beside it, toward the middle. side 1: x is the left edge; -1: x is the right edge
function LAYOUT.on(k)
    if k == 'doll' then return (cfg.equip_look or 'wheel') == 'doll'; end
    if k == 'map' then return cfg.minimap ~= false; end
    if k == 'loot' then return cfg.loot_win ~= false; end
    if k == 'timer' then return cfg.timers ~= false; end
    if k == 'alliance' or k == 'ally2' then return cfg.alliance ~= false; end
    if k == 'party' then return cfg.party ~= false; end
    return true;
end
function LAYOUT.column(o, keys, x, y0, ybot, side)
    local y, cw = y0, 0;
    local W, H = LAYOUT.W, LAYOUT.H;
    for _, k in ipairs(keys) do
        if not LAYOUT.on(k) then goto next_piece; end
        local w, h = LAYOUT.size(k);
        local px = (side > 0) and x or (x - w);
        for _ = 1, 40 do
            if y > y0 and y + h > ybot then                          -- (no room left here: the next column)
                x, y, cw = x + side * (cw + 24), y0, 0;
                px = (side > 0) and x or (x - w);
            end
            local r = LAYOUT.hit(px, y, w, h);
            if r == nil then break; end
            y = r[2] + r[4] + 16;                                    -- (something there: just under it)
        end
        px, y = math.max(0, math.min(W - w, px)), math.max(0, math.min(H - h, y));   -- (a small screen: never off it)
        LAYOUT.xy(o, k, px, y);
        LAYOUT.take(px, y, w, h);
        y, cw = y + h + 16, math.max(cw, w);
        ::next_piece::
    end
end
-- Your HP / MP / TP bars' windows (equip.lua): their width and height, from where the bars were last drawn
function LAYOUT.bar_size(key)
    local m = (type(YUI_EQ_SBSIZE) == 'function') and YUI_EQ_SBSIZE(key) or nil;   -- (its window as measured: the real size)
    if type(m) == 'table' and (tonumber(m[1]) or 0) > 4 and (tonumber(m[2]) or 0) > 4 then return m[1], m[2]; end
    local bp = (type(YUI_EQ_BARPOS) == 'table') and YUI_EQ_BARPOS[key] or nil;
    local sc = bp and bp[5] or 1;
    if bp then return bp[3] + 16, math.floor(62 * sc); end
    return 276, 62;
end
-- How tall the three bars are stacked (MP and TP under HP, BARS > anchored): each one starts just under the one before
function LAYOUT.stack_h(hh) return hh * 3 - 12; end
-- Every built-in layout places every piece: target (with its name, Magic Burst line, skillchain fan and enemy cast back
-- in their own places by the bar), sub-target, enemies, party, alliances, your bars, cast bar, pet, timers, equipment,
-- minimap, chats, Damage Meter, exp, gil and bag - each in room nothing else has.
function LAYOUT.build(name)
    local ds = imgui.GetIO().DisplaySize;
    LAYOUT.W, LAYOUT.H = (ds and ds.x) or 1920, (ds and ds.y) or 1080;
    local W, H, m = LAYOUT.W, LAYOUT.H, 24;
    local o, eq = {}, {};
    LAYOUT.taken = {};
    local anch = cfg.ally_anchor and cfg.party and true or false;
    LAYOUT.auto = { alliance = anch, ally2 = anch };
    local split = cfg.chat_split and true or false;                  -- (the combat log in a chat of its own: two chats)
    cfg.chat2_w, cfg.chat2_h = tonumber(cfg.chat_w) or 620, tonumber(cfg.chat_h) or 260;   -- (both chats the same size)
    o.chat2_w, o.chat2_h = cfg.chat2_w, cfg.chat2_h;
    local ch = tonumber(cfg.chat_h) or 260;
    for _, p in ipairs({ 'tn', 'mb', 'fo', 'co' }) do o[p .. '_dx'], o[p .. '_dy'] = 0, 0; end   -- (name, Magic Burst, fan, cast: by the bar)
    -- the bottom row, in every layout: the exp bar right at the bottom of the screen, gil on its right, the bag on its left
    local ew, eh = LAYOUT.size('exp');
    local gw_, gh = LAYOUT.size('gil');
    local bw_, bh_ = LAYOUT.size('bag');
    LAYOUT.put(o, 'exp', W / 2 - ew / 2, H - eh - 4);
    LAYOUT.put(o, 'gil', W / 2 + ew / 2 + 24, H - gh - 6);
    LAYOUT.put(o, 'bag', W / 2 - ew / 2 - 24 - bw_, H - bh_ - 6);
    local floor_ = H - eh - 16;                                      -- (nothing reaches into the bottom row)
    LAYOUT.cb = math.min(H - 46, floor_);                           -- (where the chats' foot is)
    -- the target at the top middle; its Magic Burst line just over it, its fan on its left; the sub-target under it
    local tw, th = LAYOUT.size('target');
    local tx = W / 2 - tw / 2;
    LAYOUT.xy(o, 'target', tx, 40);
    local tsc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.target_scale) or 1);
    LAYOUT.take(tx, 6, tw, th + 34);
    if cfg.fight_info ~= false then
        local fw, fh = LAYOUT.size('fan');
        if (cfg.fan_place or 'bar') == 'free' then LAYOUT.put(o, 'fan', tx - fw - 20, 40);
        else LAYOUT.take(tx - 18 * tsc - fw + 14 * tsc * FIGHT.fsc(), 40, fw + 4, fh + 40 * tsc); end
    end
    local sw_ = LAYOUT.size('sub');
    LAYOUT.put(o, 'sub', W / 2 - sw_ / 2, 40 + th + 12);
    local hw, hh = LAYOUT.bar_size('hp');
    local mw = LAYOUT.bar_size('mp');
    local tpw = LAYOUT.bar_size('tp');
    local pw, peth = LAYOUT.size('pet');
    local cw_, cth = LAYOUT.size('cast');
    local dps;
    if name == 'classic' then                                       -- bars bottom middle, party top right, timers left
        local gw = hw + mw + tpw + 12;                               -- (the three side by side)
        local bx, by = W / 2 - gw / 2, floor_ - hh - 40;
        local x0 = m + math.floor(W * 0.13);
        if math.min(bx - 24 - x0, (W - m) - (bx + gw + 24)) < math.min(260, tonumber(cfg.chat_w) or 620) then
            by = LAYOUT.cb - ch - 12 - hh - 8;
        end
        eq = { sb_anchor = 2, hpbar_x = math.floor(bx), hpbar_y = math.floor(by) };
        LAYOUT.take(bx, by, gw, hh);
        LAYOUT.put(o, 'cast', W / 2 - cw_ / 2, by - cth - 14);
        LAYOUT.put(o, 'pet', W / 2 - pw / 2, by - cth - 14 - peth - 12);
        LAYOUT.chats(o, bx, bx + gw, split);
        local ctop = LAYOUT.cb - ch - 12;
        LAYOUT.column(o, { 'party', 'alliance', 'ally2', 'enemy', 'dps', 'doll' }, W - m, 40, split and ctop or floor_, -1);
        LAYOUT.column(o, { 'map', 'timer', 'loot' }, m, 40, ctop, 1);
    elseif name == 'raid' then                                      -- party top left, bars stacked bottom middle, timers right
        local stack = LAYOUT.stack_h(hh);
        local bx, by = W / 2 - hw / 2, floor_ - stack - 20;
        eq = { sb_anchor = 1, hpbar_x = math.floor(bx), hpbar_y = math.floor(by) };
        LAYOUT.take(bx, by, hw, stack);
        LAYOUT.put(o, 'cast', W / 2 - cw_ / 2, by - cth - 14);
        LAYOUT.put_free(o, 'pet', bx - pw - 30, by + stack - peth, -1, 0);   -- (left of the bars, its foot on theirs)
        local cw = math.floor(math.max(260, math.min(tonumber(cfg.chat_w) or 620, W - m - (bx + hw) - 24)));   -- (the chats right
        cfg.chat_w, cfg.chat2_w, o.chat_w, o.chat2_w = cw, cw, cw, cw;                                          --  of the bars)
        LAYOUT.put(o, 'chat', W - m - cw, LAYOUT.cb - ch);
        local top = LAYOUT.cb - ch - 12;
        if split then LAYOUT.put(o, 'chat2', W - m - cw, top - ch); top = top - ch - 12; end
        LAYOUT.column(o, { 'timer', 'enemy', 'loot', 'map' }, W - m, 60, top, -1);
        LAYOUT.column(o, { 'party', 'alliance', 'ally2', 'doll', 'dps' }, m, 60, math.floor(H * 0.74), 1);   -- (clear of the game's
    else                                                             -- compact: gathered round the bars          menus, bottom left)
        local stack = LAYOUT.stack_h(hh);
        local bx = W / 2 - hw / 2;
        local ctop = LAYOUT.cb - ch - 12;
        local by = math.min(math.floor(H * 0.58), ctop - stack);
        eq = { sb_anchor = 1, hpbar_x = math.floor(bx), hpbar_y = math.floor(by) };
        LAYOUT.take(bx, by, hw, stack);
        LAYOUT.put(o, 'cast', W / 2 - cw_ / 2, by - cth - 14);
        LAYOUT.put_free(o, 'pet', W / 2 - pw / 2, math.min(by + stack + 12, floor_ - peth), 0, 1);
        LAYOUT.chats(o, bx, bx + hw, split);
        local pw2, ph = LAYOUT.size('party');                        -- the party right of the bars, the timers left of them
        local px, py = bx + hw + 40, math.max(40 + th + 80, ctop - ph);
        LAYOUT.put_free(o, 'party', px, py, 1, 0);
        px = tonumber(o.party_x) or px;
        if anch then                                                 -- (anchored alliances go over a low party)
            local _, ah = LAYOUT.size('alliance');
            LAYOUT.take(px, py - ah * 2 - 24, pw2, ah * 2 + 24);
        end
        local tmw, tmh = LAYOUT.size('timer');
        LAYOUT.put_free(o, 'timer', bx - tmw - 40, math.max(40 + th + 80, ctop - tmh), -1, 0);
        LAYOUT.column(o, { 'enemy', 'dps', 'loot' }, m, 40, ctop, 1);
        LAYOUT.column(o, anch and { 'doll', 'map' } or { 'doll', 'alliance', 'ally2', 'map' }, W - m, 40, ctop, -1);
    end
    dps = o._dps;
    o._dps = nil;
    return o, eq, dps;
end
-- The two chats at the bottom corners, both the same size: the left one starts after the room the game's own menus
-- use (magic, items... open at the bottom left), and neither reaches the bars in the middle (lo .. hi). The right one
-- only when the combat log has a chat of its own (CHAT > Split combat log).
function LAYOUT.chats(o, lo, hi, split)
    local W, H, m = LAYOUT.W, LAYOUT.H, 24;
    local x0 = m + math.floor(W * 0.13);
    local room = math.min(lo - 24 - x0, (W - m) - (hi + 24));
    local cw = math.floor(math.max(260, math.min(tonumber(cfg.chat_w) or 620, room)));
    local ch = tonumber(cfg.chat_h) or 260;
    cfg.chat_w, cfg.chat2_w, cfg.chat2_h = cw, cw, ch;
    o.chat_w, o.chat2_w, o.chat2_h = cw, cw, ch;
    LAYOUT.put(o, 'chat', x0, LAYOUT.cb - ch);
    if split then LAYOUT.put(o, 'chat2', W - m - cw, LAYOUT.cb - ch); else LAYOUT.xy(o, 'chat2', W - m - cw, LAYOUT.cb - ch); end
end
function LAYOUT.apply(o, eq, dps)
    for k, v in pairs(o) do cfg[k] = v; end
    WATCH.move = 3;                                                  -- every window jumps to its new place
    save();
    if eq and next(eq) and YUI_EQ_APPLY then pcall(YUI_EQ_APPLY, eq); end
    if dps and dps[3] and YUI_DPS and YUI_DPS.get then              -- (a layout of yours: the meter's size and rows too)
        pcall(function()
            local ds = YUI_DPS.get();
            ds.size = tonumber(dps[3]) or ds.size;
            if dps[4] then ds.h = tonumber(dps[4]) or ds.h; end
        end);
    end
    if dps and YUI_DPS and YUI_DPS.place then pcall(YUI_DPS.place, dps[1], dps[2]); end
end
-- What MY LAYOUTS keep besides the places: every size, length and thickness (the look, colours and on / off stay as they are)
LAYOUT.SIZES = { 'scale', 'target_scale', 'target_name_scale', 'target_w', 'target_bar_h', 'fan_scale', 'mb_scale', 'ecast_scale',
    'ecast_font', 'target_buff_scale', 'sub_scale', 'sub_w', 'enemy_scale', 'enemy_w', 'party_scale', 'icon_scale', 'ally1_scale',
    'ally1_icon', 'ally2_scale', 'ally2_icon', 'buff_scale', 'party_bar_h', 'party_vgap', 'card_h', 'exp_scale', 'exp_w', 'cast_scale',
    'cast_w', 'cast_h', 'pet_scale', 'pet_w', 'gb_scale', 'gil_scale', 'exp_text', 'chat_size', 'chat_gap', 'timers_scale', 'timers_w', 'timers_h', 'strip_icon' };
LAYOUT.EQ_SIZES = { 'sb_scale', 'sb_thick', 'sb_hp_size', 'sb_hp_len', 'sb_mp_thick', 'sb_mp_size', 'sb_mp_len', 'sb_tp_size', 'sb_tp_len' };
function LAYOUT.use(name) LAYOUT.apply(LAYOUT.build(name)); LAYOUT.msg = 'Layout: ' .. name; end
-- GENERAL > MY LAYOUTS: five slots, each with a name you type (kept in cfg.layout_names; the layouts in cfg.layouts)
LAYOUT.bufs = {};
function LAYOUT.name(n)
    local t = cfg.layout_names;
    local v = (type(t) == 'table') and t[n] or nil;
    return (type(v) == 'string' and v ~= '') and v or nil;
end
function LAYOUT.mine_rows()
    local ps = C.ps;
    local bw = math.floor(64 * ps);
    for n = 1, 5 do
        local b = LAYOUT.bufs[n];
        if b == nil then b = { LAYOUT.name(n) or '' }; LAYOUT.bufs[n] = b; end
        local has = type(cfg.layouts) == 'table' and type(cfg.layouts['mine' .. n]) == 'table';
        imgui.PushItemWidth(ROW_W - 2 * bw - 16);
        imgui.InputText('##yui_lname' .. n, b, 32);
        imgui.PopItemWidth();
        if imgui.IsItemDeactivated() then                            -- (its name, kept when you leave the box)
            local names = {};
            for k = 1, 5 do names[k] = LAYOUT.name(k) or ''; end
            names[n] = tostring(b[1] or '');
            cfg.layout_names = names;
            save();
        end
        if (b[1] or '') == '' and not imgui.IsItemActive() then     -- (an empty box: a faint placeholder)
            local mx, my = imgui.GetItemRectMin();
            pcall(function() imgui.GetWindowDrawList():AddText({ mx + 8 * ps, my + 4 * ps }, U4(1, 1, 1, 0.30), 'Layout ' .. n .. (has and ' (saved)' or '')); end);
        end
        imgui.SameLine(0, 8);
        if accent_button('SAVE##yui_lsave' .. n, { bw, 0 }, false, true) then LAYOUT.save_mine(n); end
        imgui.SameLine(0, 8);
        if accent_button('LOAD##yui_lload' .. n, { bw, 0 }, not has, true) then LAYOUT.load_mine(n); end
    end
end
function LAYOUT.capture()                                            -- where everything is now, and every size
    local o, eq = {}, {};
    for _, k in ipairs(LAYOUT.KEYS) do o[k .. '_x'], o[k .. '_y'] = tonumber(cfg[k .. '_x']), tonumber(cfg[k .. '_y']); end
    for _, k in ipairs({ 'chat_w', 'chat_h', 'chat2_w', 'chat2_h' }) do o[k] = tonumber(cfg[k]); end   -- (the chats' sizes too)
    local ec = YUI_EQ_GET and YUI_EQ_GET() or nil;
    if ec then
        for _, k in ipairs({ 'hpbar_x', 'hpbar_y', 'mpbar_x', 'mpbar_y', 'tpbar_x', 'tpbar_y' }) do eq[k] = tonumber(ec[k]); end
        eq.sb_anchor = ec.sb_anchor;                                 -- (true / false: not a number)
        for _, k in ipairs(LAYOUT.EQ_SIZES) do eq[k] = tonumber(ec[k]); end   -- your HP / MP / TP bars' sizes
    end
    for _, k in ipairs(LAYOUT.SIZES) do o[k] = tonumber(cfg[k]); end   -- every size, length and thickness
    local ds = YUI_DPS and YUI_DPS.get and YUI_DPS.get() or nil;
    return { o = o, eq = eq, dps = ds and { tonumber(ds.x), tonumber(ds.y), tonumber(ds.size), tonumber(ds.h) } or nil };
end
function LAYOUT.save_mine(n)
    local t = LAYOUT.capture();
    t.link = cfg.target_fx == 'link';                                -- (the mode it was saved in: loading it goes back to that mode)
    local all = {};
    if type(cfg.layouts) == 'table' then for k, v in pairs(cfg.layouts) do all[k] = v; end end
    all['mine' .. n] = t;
    cfg.layouts = all;
    save();
    LAYOUT.msg = 'Saved: ' .. (LAYOUT.name(n) or ('Layout ' .. n)) .. '.';
end
function LAYOUT.load_mine(n)
    local t = type(cfg.layouts) == 'table' and cfg.layouts['mine' .. n] or nil;
    if type(t) ~= 'table' then LAYOUT.msg = (LAYOUT.name(n) or ('Layout ' .. n)) .. ' is empty: SAVE it first.'; return; end
    local o = {};
    for k, v in pairs(t.o or {}) do o[k] = v; end
    local eq = {};
    for k, v in pairs(t.eq or {}) do eq[k] = v; end
    if t.link ~= nil and (t.link == true) ~= (cfg.target_fx == 'link') then pcall(C.setmode, t.link == true); end   -- (its own mode first: Normal or Hex link)
    LAYOUT.apply(o, eq, (type(t.dps) == 'table' and t.dps[1]) and t.dps or nil);
    LAYOUT.msg = 'Loaded: ' .. (LAYOUT.name(n) or ('Layout ' .. n)) .. '.';
end

-- GENERAL > SHARE MY UI: your whole UI as one code to send to someone - every setting you changed (not the defaults),
-- every place, your HP / MP / TP bars and the Damage Meter. Places are kept with your screen's size, so on another
-- screen everything lands in the same spot. Importing keeps what you had first (UNDO puts it back).
LAYOUT.SKIP = { setup_done = true, welcomed = true, mode_v1 = true, mode_v2 = true, md_backup = true, g_backup = true, g_dps0 = true, layouts = true,
    layout_names = true, share_backup = true, locked = true };
function LAYOUT.plain(v, d)                                          -- (a copy with only numbers, strings, booleans and tables of them)
    d = d or 0;
    local tv = type(v);
    if tv == 'number' or tv == 'string' or tv == 'boolean' then return v; end
    if tv ~= 'table' or d > 6 then return nil; end
    local o = {};
    for k, x in pairs(v) do
        if type(k) == 'number' or type(k) == 'string' then o[k] = LAYOUT.plain(x, d + 1); end
    end
    return o;
end
function LAYOUT.ser(v)                                               -- (a Lua literal of it)
    local tv = type(v);
    if tv == 'number' then
        if v ~= v or v == math.huge or v == -math.huge then return '0'; end
        return (v == math.floor(v)) and string.format('%d', v) or string.format('%.6g', v);
    end
    if tv == 'string' then return string.format('%q', v); end
    if tv == 'boolean' then return tostring(v); end
    if tv ~= 'table' then return 'nil'; end
    local parts = {};
    local keys = {};
    for k in pairs(v) do keys[#keys + 1] = k; end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b); end);
    for _, k in ipairs(keys) do
        local ks = (type(k) == 'string' and k:match('^[%a_][%w_]*$')) and k or ('[' .. LAYOUT.ser(k) .. ']');
        parts[#parts + 1] = ks .. '=' .. LAYOUT.ser(v[k]);
    end
    return '{' .. table.concat(parts, ',') .. '}';
end
LAYOUT.B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
function LAYOUT.b64(str)
    local b, out = LAYOUT.B64, {};
    for i = 1, #str, 3 do
        local a, c, d = str:byte(i, i + 2);
        local n = a * 65536 + (c or 0) * 256 + (d or 0);
        local q = { math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64 };
        out[#out + 1] = b:sub(q[1] + 1, q[1] + 1) .. b:sub(q[2] + 1, q[2] + 1) .. (c and b:sub(q[3] + 1, q[3] + 1) or '=') .. (d and b:sub(q[4] + 1, q[4] + 1) or '=');
    end
    return table.concat(out);
end
function LAYOUT.unb64(str)
    local b, map, out = LAYOUT.B64, {}, {};
    for i = 1, 64 do map[b:byte(i)] = i - 1; end
    str = str:gsub('[^%w%+/=]', '');
    for i = 1, #str, 4 do
        local q = { str:byte(i, i + 3) };
        local v = {};
        for k = 1, 4 do v[k] = map[q[k] or 61] ; end
        if v[1] == nil or v[2] == nil then break; end
        local n = v[1] * 262144 + v[2] * 4096 + (v[3] or 0) * 64 + (v[4] or 0);
        out[#out + 1] = string.char(math.floor(n / 65536) % 256);
        if v[3] then out[#out + 1] = string.char(math.floor(n / 256) % 256); end
        if v[4] then out[#out + 1] = string.char(n % 256); end
    end
    return table.concat(out);
end
function LAYOUT.share_pack()                                         -- (what goes in the code)
    local W, H = C.screen();
    local o = {};
    for k, v in pairs(cfg) do
        if type(k) == 'string' and not LAYOUT.SKIP[k] and not k:find('^_') and not k:find('_try$') and not k:find('_v%d$') then
            local pv = LAYOUT.plain(v);
            if pv ~= nil and LAYOUT.ser(pv) ~= LAYOUT.ser(LAYOUT.plain(defaults[k])) then o[k] = pv; end
        end
    end
    local eq = YUI_EQ_GET and LAYOUT.plain(YUI_EQ_GET()) or nil;
    local ds = YUI_DPS and YUI_DPS.get and LAYOUT.plain(YUI_DPS.get()) or nil;
    if ds then ds.visible, ds.minimized, ds.last_dps = nil, nil, nil; end
    return { v = 1, sw = W, sh = H, link = cfg.target_fx == 'link', cfg = o, eq = eq, dps = ds };
end
function LAYOUT.share_code() return 'YUI1:' .. LAYOUT.b64(LAYOUT.ser(LAYOUT.share_pack())); end
function LAYOUT.clip_ffi()
    pcall(ffi.cdef, [[
        int OpenClipboard(void* h); int EmptyClipboard(void); int CloseClipboard(void);
        void* SetClipboardData(unsigned int f, void* h); void* GetClipboardData(unsigned int f);
        void* GlobalAlloc(unsigned int f, size_t n); void* GlobalLock(void* h); int GlobalUnlock(void* h);
    ]]);
    return ffi.load('user32'), ffi.load('kernel32');
end
function LAYOUT.clip_set(str)
    if imgui.SetClipboardText and pcall(imgui.SetClipboardText, str) then return true; end
    return pcall(function()
        local u, k = LAYOUT.clip_ffi();
        local n = #str + 1;
        local h = k.GlobalAlloc(0x0002, n);
        local q = k.GlobalLock(h);
        ffi.copy(q, str, n);
        k.GlobalUnlock(h);
        assert(u.OpenClipboard(nil) ~= 0);
        u.EmptyClipboard();
        u.SetClipboardData(1, h);
        u.CloseClipboard();
    end);
end
function LAYOUT.clip_get()
    if imgui.GetClipboardText then
        local ok, t = pcall(imgui.GetClipboardText);
        if ok and type(t) == 'string' and t ~= '' then return t; end
    end
    local out = nil;
    pcall(function()
        local u, k = LAYOUT.clip_ffi();
        if u.OpenClipboard(nil) == 0 then return; end
        local h = u.GetClipboardData(1);
        if h ~= nil then
            local q = k.GlobalLock(h);
            if q ~= nil then out = ffi.string(q); k.GlobalUnlock(h); end
        end
        u.CloseClipboard();
    end);
    return out;
end
function LAYOUT.share_export()
    local code = LAYOUT.share_code();
    local copied = LAYOUT.clip_set(code);
    local file = nil;
    pcall(function()                                                 -- (and a file in config\addons\yunaui\exports, to send as it is)
        local dir = copy_base() .. 'yunaui\\exports\\';
        pcall(function() ashita.fs.create_directory(dir); end);
        pcall(function() ashita.fs.create_dir(dir); end);
        local who = '';
        pcall(function() who = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0) or ''; end);
        local fn = dir .. 'YunaUI-' .. (who ~= '' and who or 'layout') .. os.date('-%Y%m%d-%H%M') .. '.txt';
        local f = io.open(fn, 'w');
        if f then f:write(code); f:close(); file = fn; end
    end);
    LAYOUT.smsg = (copied and 'Copied! Paste it to whoever wants your UI (Discord makes it a file - that works too).' or 'Couldn\'t copy it: use the file.')
        .. (file and ('\nAlso saved: ' .. file) or '');
    if file then msg('Your UI code is saved in ' .. file); end
end
function LAYOUT.scale_pos(t, fx, fy)                                 -- (places, from their screen to yours)
    if type(t) ~= 'table' then return t; end
    for k, v in pairs(t) do
        if type(k) == 'string' and type(v) == 'number' and v >= 0 then
            if k:find('_x$') or k == 'x' then t[k] = math.floor(v * fx + 0.5);
            elseif k:find('_y$') or k == 'y' then t[k] = math.floor(v * fy + 0.5); end
        end
    end
    return t;
end
function LAYOUT.share_apply(pk, undo)
    local W, H = C.screen();
    local fx, fy = W / math.max(1, tonumber(pk.sw) or W), H / math.max(1, tonumber(pk.sh) or H);
    if not undo then cfg.share_backup = LAYOUT.ser(LAYOUT.share_pack()); end   -- (what you had: UNDO LAST IMPORT)
    if pk.link ~= nil and (pk.link == true) ~= (cfg.target_fx == 'link') then pcall(C.setmode, pk.link == true); end
    if undo then                                                     -- (undo: the settings the import changed go back to their defaults first)
        local back = {};
        for k in pairs(pk.cfg or {}) do back[k] = true; end
        for k, v in pairs(LAYOUT.share_pack().cfg) do if not back[k] and defaults[k] ~= nil then cfg[k] = LAYOUT.plain(defaults[k]); end end
    end
    local c = LAYOUT.scale_pos(pk.cfg or {}, fx, fy);
    for k, v in pairs(c) do
        if type(k) == 'string' and not LAYOUT.SKIP[k] then
            if type(v) == 'table' then local ok, tv = pcall(T, v); cfg[k] = (ok and type(tv) == 'table') and tv or v; else cfg[k] = v; end
        end
    end
    WATCH.move = 3;
    save();
    if type(pk.eq) == 'table' and YUI_EQ_APPLY then pcall(YUI_EQ_APPLY, LAYOUT.scale_pos(pk.eq, fx, fy)); end
    if type(pk.dps) == 'table' and YUI_DPS and YUI_DPS.get then
        pcall(function()
            local ds = YUI_DPS.get();
            local d = LAYOUT.scale_pos(pk.dps, fx, fy);
            for k, v in pairs(d) do if k ~= 'x' and k ~= 'y' then ds[k] = v; end end
            if d.x and d.y then YUI_DPS.place(d.x, d.y); elseif YUI_DPS.save then YUI_DPS.save(); end
        end);
    end
end
function LAYOUT.share_read(txt)                                      -- (a code back into its table; nil and why when it isn't one)
    if type(txt) ~= 'string' then return nil, 'The clipboard is empty.'; end
    local b = txt:match('YUI1:([%w%+/=%s]+)');
    if not b then return nil, 'No YunaUI code on the clipboard (it starts with YUI1:).'; end
    local src = LAYOUT.unb64(b);
    local fn = loadstring('return ' .. src);
    if not fn then return nil, 'That code is broken (copied only part of it?).'; end
    setfenv(fn, {});                                                 -- (just a table: nothing in it can run)
    local ok, pk = pcall(fn);
    if not ok or type(pk) ~= 'table' or pk.v ~= 1 or type(pk.cfg) ~= 'table' then return nil, 'That code is broken (copied only part of it?).'; end
    return pk;
end
function LAYOUT.share_import()
    local pk, why = LAYOUT.share_read(LAYOUT.clip_get());
    if not pk then LAYOUT.smsg = why; return; end
    LAYOUT.share_apply(pk);
    LAYOUT.smsg = 'Imported! UNDO LAST IMPORT puts your own UI back.';
end
function LAYOUT.share_undo()
    local fn = type(cfg.share_backup) == 'string' and loadstring('return ' .. cfg.share_backup) or nil;
    if not fn then LAYOUT.smsg = 'Nothing to undo.'; return; end
    setfenv(fn, {});
    local ok, pk = pcall(fn);
    if not ok or type(pk) ~= 'table' then LAYOUT.smsg = 'Nothing to undo.'; return; end
    LAYOUT.share_apply(pk, true);
    cfg.share_backup = nil;
    save();
    LAYOUT.smsg = 'Your own UI is back.';
end
function LAYOUT.share_rows()
    if accent_button('EXPORT MY UI (COPY THE CODE)##yui_shx', { ROW_W, 0 }, false, true) then pcall(LAYOUT.share_export); LAYOUT.sure = nil; end
    if imgui.IsItemHovered() then YUI_TIP('Copies a code with your whole UI: settings, places, sizes, your bars, the Damage Meter\nSend it to anyone: they import it'); end
    local sure = LAYOUT.sure and os.clock() - LAYOUT.sure < 4;
    if accent_button((sure and 'SURE? CLICK AGAIN TO IMPORT' or 'IMPORT A UI FROM THE CLIPBOARD') .. '##yui_shi', { ROW_W, 0 }, false, true) then
        if sure then LAYOUT.sure = nil; pcall(LAYOUT.share_import);
        else LAYOUT.sure = os.clock(); LAYOUT.smsg = 'Copy someone\'s code first, then click again: your UI changes to theirs (UNDO brings yours back).'; end
    end
    if type(cfg.share_backup) == 'string' then
        if accent_button('UNDO LAST IMPORT##yui_shu', { ROW_W, 0 }, false, true) then pcall(LAYOUT.share_undo); end
    end
    return LAYOUT.smsg or 'Share your UI: EXPORT copies a code (also saved as a file), the other person copies it and clicks IMPORT. Places fit any screen size.';
end

local function tab_bar(dl)
    local x0, y0 = imgui.GetCursorScreenPos();
    local fs = 0.82 * C.wfs;
    imgui.SetWindowFontScale(fs);
    local total = 0;
    for _, n in ipairs(TABS) do total = total + imgui.CalcTextSize(n); end
    if total > ROW_W - 8 * (#TABS - 1) then                         -- too many to fit: a little smaller
        fs = fs * (ROW_W - 8 * (#TABS - 1)) / total;
        imgui.SetWindowFontScale(fs);
        total = 0;
        for _, n in ipairs(TABS) do total = total + imgui.CalcTextSize(n); end
    end
    local gap = (ROW_W - total) / (#TABS - 1);
    local x = x0;
    local lh = imgui.GetTextLineHeight();
    local mx, my = imgui.GetMousePos();
    for k, n in ipairs(TABS) do
        local w = imgui.CalcTextSize(n);
        local on = (ui.tab or 1) == k;
        local over = mx >= x - 4 and mx < x + w + 4 and my >= y0 - 2 and my < y0 + lh + 6;
        local col = on and C.acc or (over and C.text or C.muted);
        DL.T(dl, x, y0, u32(col), n);
        if on then                                                   -- the chosen tab: a glowing line under it
            pcall(function() DL.RFM(dl, x - 2, y0 + lh + 3, x + w + 2, y0 + lh + 5, u32(C.hp), u32(C.mp2), u32(C.mp2), u32(C.hp)); end);
            DL.RF(dl, x - 4, y0 + lh + 1, x + w + 4, y0 + lh + 7, U4(C.hp2[1], C.hp2[2], C.hp2[3], 0.18), 3);
        end
        imgui.SetCursorScreenPos({ x - 4, y0 - 2 });
        if imgui.InvisibleButton('##yui_tab' .. k, { w + 8, lh + 8 }) then ui.tab = k; end
        x = x + w + gap;
    end
    imgui.SetWindowFontScale(C.wfs);
    imgui.SetCursorScreenPos({ x0, y0 + lh + 10 });
    imgui.Dummy({ ROW_W, 1 });
end
----------------------------------------------------------------------------------------------------
-- The settings panel's frame: a sidebar (your logo in violet-white, YUNA UI, the tabs) on the left, the settings in
-- two columns (split at the section nearest half way, measured the frame before), - and X at the top right.
-- Minimised, it's just the logo at the top of the screen: click it to open the panel again (drag it to move it).
----------------------------------------------------------------------------------------------------
local PANEL = { h = {}, col = 1 };
function PANEL.split()
    if PANEL.col ~= 1 or (PANEL.split_at or 0) <= 0 then return; end
    local _, cy = imgui.GetCursorScreenPos();
    if cy - PANEL.top < PANEL.split_at then return; end
    PANEL.col, PANEL.h1, PANEL.bot1 = 2, cy - PANEL.top, cy;
    imgui.PopTextWrapPos();
    imgui.Indent(PANEL.ind2);
    imgui.SetCursorScreenPos({ PANEL.cx2, PANEL.top });
    imgui.PushTextWrapPos(imgui.GetCursorPosX() + ROW_W);
end
-- The two modes (the switch at the top of the panel, and the first-run chooser): Normal - YunaUI's own look; Hex link -
-- the target bar over the target's head with a line to it, hexagon bars, the skillchain banner at the top
C.MODEKEYS = { 'target_scale', 'target_name_scale', 'target_w', 'target_bar_h', 'target_buff_scale', 'sub_w',
               'head_bars', 'head_bars_scale', 'head_bars_y', 'head_nums' };
function C.modesave(link)                                            -- (this mode's sizes, kept: cfg.ms_hex / cfg.ms_norm)
    local t = {};
    for _, k in ipairs(C.MODEKEYS) do t[k] = cfg[k]; end
    cfg[link and 'ms_hex' or 'ms_norm'] = t;
end
function C.modeload(link)                                            -- (that mode's sizes, if it has some kept)
    local t = cfg[link and 'ms_hex' or 'ms_norm'];
    if type(t) ~= 'table' then return false; end
    for _, k in ipairs(C.MODEKEYS) do if t[k] ~= nil then cfg[k] = t[k]; end end
    return true;
end
function C.setmode(link)
    local was = cfg.target_fx == 'link';
    if was ~= link then C.modesave(was); C.modeload(link); end       -- (each mode with its own sizes)
    if link then
        if cfg.target_fx ~= 'link' then cfg.std_fx = cfg.target_fx; end
        cfg.target_fx = 'link';
    else
        cfg.target_fx = (cfg.std_fx and cfg.std_fx ~= 'link') and cfg.std_fx or 'blade';
        if was then                                                  -- (from Hex link: the target bar back on top of the screen, centred,
            local W_ = C.screen();                                   --  room over it for Magic Burst - as the chooser shows it)
            local sc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.target_scale) or 1);
            local w = (tonumber(cfg.target_w) or 520) * sc;
            cfg.target_x, cfg.target_y = math.floor(W_ / 2 - w / 2 - 6), math.floor(50 * sc);
            WATCH.one = WATCH.one or {};
            WATCH.one.target_x = 3;                                  -- (moved there now, not only next time)
            for _, pc in ipairs(FIGHT.PIECES) do cfg[pc[1] .. '_dx'], cfg[pc[1] .. '_dy'] = 0, 0; end   -- (name, Magic Burst, fan, cast: back on the bar)
        end
    end
    save();
end
C.GOLDH, C.GOLDH2 = { 1.0, 0.76, 0.34 }, { 1.0, 0.90, 0.62 };   -- (Hex link's gold: C fields, for code above PANEL)
PANEL.GOLD, PANEL.GOLD2 = C.GOLDH, C.GOLDH2;
function C.normcol(k)                                                -- (Normal mode's panel colour, from your HP bar - NEON is gold in Hex link mode)
    return (type(YUI_HP_COL) == 'table' and YUI_HP_COL[k]) or ((k == 2) and { 0.86, 0.24, 0.86 } or { 1.00, 0.42, 0.72 });
end
function PANEL.modes(dl, x, y)                                       -- NORMAL MODE | HEX LINK MODE, top of the panel
    local ps = C.ps;
    local HX = cfg.target_fx == 'link';
    imgui.SetWindowFontScale(C.wfs * 0.8);
    local labels = { 'NORMAL MODE', 'HEX LINK MODE' };
    local sp = 2 * ps;
    local bw = math.floor(math.max(spaced_w(labels[1], sp), spaced_w(labels[2], sp)) + 34 * ps);
    local bh = math.floor(26 * ps);
    local _, th = imgui.CalcTextSize('A');
    local mx, my = imgui.GetMousePos();
    for i = 1, 2 do
        local bx = x + (i - 1) * bw;
        local on = (i == 2) == HX;
        local over = mx >= bx and mx < bx + bw and my >= y and my < y + bh;
        local ac = (i == 2) and PANEL.GOLD or C.normcol(2);
        local ac2 = (i == 2) and PANEL.GOLD2 or C.normcol(3);
        if i == 2 then                                               -- (Hex link's half: hexagon ends)
            local c = bh / 2;
            local pts = { { bx, y }, { bx + bw - c, y }, { bx + bw, y + c }, { bx + bw - c, y + bh }, { bx, y + bh } };
            local fill = u32(on and { ac[1], ac[2], ac[3], 0.22 } or (over and { 1, 1, 1, 0.06 } or { 0.10, 0.09, 0.13, 1 }));
            if not pcall(function() dl:AddConvexPolyFilled(pts, fill); end) then
                for t_ = 2, #pts - 1 do dl:AddTriangleFilled(pts[1], pts[t_], pts[t_ + 1], fill); end
            end
            for k = 1, #pts do dl:AddLine(pts[k], pts[k % #pts + 1], U4(ac2[1], ac2[2], ac2[3], on and 0.95 or 0.35), on and 1.6 or 1); end
        else                                                         -- (Normal's half: a round end)
            DL.RF(dl, bx, y, bx + bw, y + bh, u32(on and { ac[1], ac[2], ac[3], 0.30 } or (over and { 1, 1, 1, 0.06 } or { 0.10, 0.09, 0.13, 1 })), bh / 2, C.rleft);
            DL.R(dl, bx, y, bx + bw, y + bh, U4(ac2[1], ac2[2], ac2[3], on and 0.95 or 0.35), bh / 2, C.rleft, on and 1.6 or 1);
        end
        local lw = spaced_w(labels[i], sp);
        spaced(dl, bx + (bw - lw) / 2, y + (bh - th) / 2, labels[i], u32(on and { 1, 1, 1, 1 } or (over and C.text or C.muted)), sp);
        imgui.SetCursorScreenPos({ bx, y });
        if imgui.InvisibleButton('##yui_mode' .. i, { bw, bh }) and not on then C.setmode(i == 2); end
        if over then YUI_TIP((i == 2) and 'Hex link: the target bar over its head with a line to it, hexagon bars, the skillchain banner at the top.' or 'Normal: the YunaUI target bar, skillchain fan and Magic Burst card.'); end
    end
    imgui.SetWindowFontScale(C.wfs);
end
function PANEL.hexframe(dl, x, y, w, h, SW)                          -- Hex link mode's panel: cut corners, a gold edge, hexagons
    local ps = C.ps;
    local c = 30 * ps;
    x, y, w, h = x + 5, y + 5, w - 10, h - 10;
    local bga = math.max(0.15, math.min(1, tonumber(cfg.panel_alpha) or 0.95));
    local pts = { { x + c, y }, { x + w - c, y }, { x + w, y + c }, { x + w, y + h - c }, { x + w - c, y + h }, { x + c, y + h }, { x, y + h - c }, { x, y + c } };
    local fill = U4(0.032, 0.030, 0.046, bga);
    if not pcall(function() dl:AddConvexPolyFilled(pts, fill); end) then
        for t_ = 2, #pts - 1 do dl:AddTriangleFilled(pts[1], pts[t_], pts[t_ + 1], fill); end
    end
    local G, G2 = PANEL.GOLD, PANEL.GOLD2;
    for k = 3, 1, -1 do                                              -- (the glow: faint wide strokes on the edge)
        for i = 1, 8 do dl:AddLine(pts[i], pts[i % 8 + 1], U4(G[1], G[2], G[3], 0.05 * (4 - k)), (2 + k * 2.2) * ps); end
    end
    for i = 1, 8 do dl:AddLine(pts[i], pts[i % 8 + 1], U4(G2[1], G2[2], G2[3], 0.85), 1.4); end
    for i = 2, 8, 2 do                                               -- (a small hexagon on each cut corner)
        local a_, b_ = pts[i], pts[i % 8 + 1];
        local mx_, my_ = (a_[1] + b_[1]) / 2, (a_[2] + b_[2]) / 2;
        C.hexdot(dl, mx_, my_, 4.5 * ps, U4(0.032, 0.030, 0.046, 1));
        C.hexring(dl, mx_, my_, 4.5 * ps, U4(G2[1], G2[2], G2[3], 0.95), 1.2);
    end
    for row = 0, 3 do                                                -- (a faint honeycomb in the top left corner, fading out)
        for col = 0, 5 - row do
            local r_ = 13 * ps;
            local hx = x + 26 * ps + col * r_ * 1.732 + ((row % 2 == 1) and r_ * 0.866 or 0);
            local hy = y + 22 * ps + row * r_ * 1.5;
            C.hexring(dl, hx, hy, r_, U4(G[1], G[2], G[3], 0.07 * (1 - (row + col) / 7)), 1);
        end
    end
    local sx = x + SW + 6 * ps;                                      -- (the sidebar's edge: a straight line, a hexagon at each end)
    DL.L(dl, sx, y + 30 * ps, sx, y + h - 30 * ps, U4(1, 1, 1, 0.07), 1);
    DL.L(dl, sx, y + 30 * ps, sx, y + 30 * ps + (h - 60 * ps) * 0.28, U4(G2[1], G2[2], G2[3], 0.8), 1.4);
    for _, yy in ipairs({ y + 30 * ps, y + h - 30 * ps }) do
        C.hexdot(dl, sx, yy, 3.5 * ps, U4(G2[1], G2[2], G2[3], 0.9));
    end
end
function PANEL.frame(dl, x, y, w, h, SW)                         -- rounded, with a soft violet glow all round
    if cfg.target_fx == 'link' then return PANEL.hexframe(dl, x, y, w, h, SW); end
    local ps = C.ps;
    local r = 30 * ps;
    x, y, w, h = x + 5, y + 5, w - 10, h - 10;
    local bga = math.max(0.15, math.min(1, tonumber(cfg.panel_alpha) or 0.95));
    DL.RF(dl, x, y, x + w, y + h, U4(0.035, 0.032, 0.050, bga), r);
    for k = 3, 1, -1 do                                              -- the glow: a few wide faint strokes on the edge
        DL.R(dl, x, y, x + w, y + h, U4(NEON[1], NEON[2], NEON[3], 0.07 * (4 - k)), r, C.rall, (2 + k * 2.2) * ps);
    end
    DL.R(dl, x, y, x + w, y + h, U4(NEON2[1], NEON2[2], NEON2[3], 0.85), r, C.rall, 1.6);
    -- the sidebar's slanted edge: faint all the way down, bright near the top
    local tx, bx = x + SW + 30 * ps, x + SW - 60 * ps;
    DL.L(dl, tx, y + 24 * ps, bx, y + h - 24 * ps, U4(1, 1, 1, 0.08), 1);
    local k = 0.28;
    local mx2, my2 = tx + (bx - tx) * k, y + 24 * ps + (h - 48 * ps) * k;
    DL.L(dl, tx, y + 24 * ps, mx2, my2, U4(NEON[1], NEON[2], NEON[3], 0.25), 6 * ps);
    DL.L(dl, tx, y + 24 * ps, mx2, my2, U4(NEON2[1], NEON2[2], NEON2[3], 0.9), 1.6);
end
-- The beta testers (bottom left of the panel) and the heart by YUNA UI: thanks, and a link to the author's Ko-fi
PANEL.TESTERS = { 'rezzattack', 'Loudnoises', 'Chadbrowick', 'Rusbando' };
PANEL.KOFI = 'https://ko-fi.com/yunasxi';
function PANEL.heart(dl, cx, cy, r, col)                             -- (a small heart: two round tops and a point)
    DL.CF(dl, cx - r * 0.5, cy - r * 0.15, r * 0.55, col, 16);
    DL.CF(dl, cx + r * 0.5, cy - r * 0.15, r * 0.55, col, 16);
    DL.TF(dl, cx - r * 1.02, cy + r * 0.02, cx + r * 1.02, cy + r * 0.02, cx, cy + r * 1.05, col);
end
function PANEL.sidebar(dl, x0, y0, SW, bottom)
    local ps = C.ps;
    local y = y0 + 2 * ps;                                           -- YUNA UI at the top (no logo)
    local pushed = push_font(fonts.title, 24 * ps);                  -- YUNA UI, centred
    if not pushed then imgui.SetWindowFontScale(1.4 * C.wfs); end
    local tw = imgui.CalcTextSize('YUNA UI');
    if pushed then imgui.PopFont(); else imgui.SetWindowFontScale(C.wfs); end
    imgui.SetCursorScreenPos({ x0 + (SW - tw) / 2, y });
    title(dl, 'YUNA UI');
    local _, ty = imgui.GetCursorScreenPos();
    do                                                               -- the heart, left of YUNA UI: a soft beat; over it, thanks; a click opens Ko-fi
        local r = math.floor(7 * ps);
        local hx, hy = x0 + (SW - tw) / 2 - r * 2 - 8 * ps, y + (ty - y) * 0.45;
        local mx_, my_ = imgui.GetMousePos();
        local over = mx_ >= hx - r * 1.6 and mx_ <= hx + r * 1.6 and my_ >= hy - r * 1.6 and my_ <= hy + r * 1.6;
        local beat = 1 + 0.08 * math.max(0, math.sin(os.clock() * 3.2)) ^ 8;
        if over then PANEL.heart(dl, hx, hy, r * 1.55 * beat, U4(1, 0.42, 0.72, 0.22)); end
        PANEL.heart(dl, hx, hy, (r + 1.5) * beat, U4(0, 0, 0, 0.8));
        PANEL.heart(dl, hx, hy, r * beat, u32(over and { 1, 0.55, 0.80, 1 } or { 1, 0.42, 0.70, 0.95 }));
        imgui.SetCursorScreenPos({ hx - r * 1.6, hy - r * 1.6 });
        if imgui.InvisibleButton('##yui_kofi', { r * 3.2, r * 3.2 }) then pcall(function() ashita.misc.open_url(PANEL.KOFI); end); end
        if over then YUI_TIP("Thank you for joining the YunaUI beta test!\nYunaUI is free. If you'd like to support the project,\nclick the heart to open my Ko-fi: ko-fi.com/yunasxi"); end
        imgui.SetCursorScreenPos({ x0, ty });
    end
    local vs = 'v' .. addon.version;
    local vw, vh = imgui.CalcTextSize(vs);
    DL.T(dl, x0 + (SW - vw) / 2, ty, u32(C.muted), vs);
    y = ty + vh + 34 * ps;
    -- the tabs: the chosen one lit, with a violet glow fading to the right
    local ih = math.floor(40 * ps);
    local mx, my = imgui.GetMousePos();
    for k, n in ipairs(TABS) do
        local on = (ui.tab or 1) == k;
        local over = mx >= x0 and mx < x0 + SW and my >= y and my < y + ih;
        if on then
            local A1 = (cfg.target_fx == 'link') and PANEL.GOLD or NEON;     -- (Hex link mode: gold, and a hexagon for the marker)
            local A2 = (cfg.target_fx == 'link') and PANEL.GOLD2 or NEON2;
            pcall(function()
                DL.RFM(dl, x0, y, x0 + SW, y + ih, U4(A1[1], A1[2], A1[3], 0.30), U4(A1[1], A1[2], A1[3], 0), U4(A1[1], A1[2], A1[3], 0), U4(A1[1], A1[2], A1[3], 0.30));
                DL.RFM(dl, x0, y + ih - 2, x0 + SW, y + ih, U4(A2[1], A2[2], A2[3], 1), U4(A2[1], A2[2], A2[3], 0), U4(A2[1], A2[2], A2[3], 0), U4(A2[1], A2[2], A2[3], 1));
            end);
            if cfg.target_fx == 'link' then C.hexdot(dl, x0 + 6 * ps, y + ih / 2, 4 * ps, U4(A2[1], A2[2], A2[3], 1));
            else DL.RF(dl, x0, y, x0 + 3, y + ih, U4(0.92, 0.80, 1, 1)); end
        elseif over then
            DL.RF(dl, x0, y, x0 + SW, y + ih, U4(1, 1, 1, 0.04));
        end
        local tw0 = imgui.CalcTextSize(n);
        local room = SW - 34 * ps;
        local fit = (tw0 > room) and (room / tw0) or 1;
        if fit < 1 then imgui.SetWindowFontScale(C.wfs * fit); end
        local _, nh = imgui.CalcTextSize(n);
        DL.T(dl, x0 + 20 * ps, y + (ih - nh) / 2, u32(on and { 0.97, 0.94, 1, 1 } or (over and { 1, 1, 1, 1 } or C.text)), n);   -- (the same white as YUNA)
        if fit < 1 then imgui.SetWindowFontScale(C.wfs); end
        imgui.SetCursorScreenPos({ x0, y });
        if imgui.InvisibleButton('##yui_side' .. k, { SW, ih }) then ui.tab = k; end
        y = y + ih + 8 * ps;
    end
    if bottom then                                                   -- BETA TESTERS at the bottom; the mouse over it shows their names
        imgui.SetWindowFontScale(C.wfs * 0.82);
        local lh = imgui.GetTextLineHeight();
        local top = bottom - lh - 6 * ps;
        if top > y + 10 * ps then
            local bw = imgui.CalcTextSize('BETA TESTERS');
            local mx_, my_ = imgui.GetMousePos();
            local over = mx_ >= x0 + 20 * ps and mx_ <= x0 + 20 * ps + bw and my_ >= top and my_ <= top + lh;
            local b1, b2, b3 = C.hp2, C.hp, C.mp2;
            if cfg.target_fx == 'link' then b1, b2, b3 = NEON2, NEON, NEON2; end   -- (Hex link mode: gold)
            DL.T(dl, x0 + 20 * ps, top, U4(b1[1], b1[2], b1[3], over and 1 or 0.85), 'BETA TESTERS');
            pcall(function() DL.RFM(dl, x0 + 20 * ps, top + lh + 1, x0 + 20 * ps + bw, top + lh + 2, u32(b2), U4(b3[1], b3[2], b3[3], 0), U4(b3[1], b3[2], b3[3], 0), u32(b2)); end);
            if over then YUI_TIP('Thank you to our beta testers:\n' .. table.concat(PANEL.TESTERS, '\n')); end
        end
        imgui.SetWindowFontScale(C.wfs);
    end
    return y;
end
function PANEL.buttons(dl, wx, wy, ww)                               -- size arrows, - (minimise) and X (close), top right
    local ps = C.ps;
    local bs = math.floor(22 * ps);
    local by = wy + 10 * ps;
    -- the panel's size: < 100% >, 5% a click (a slider here made the window jump about under the mouse)
    local right = wx + ww - 14 * ps - (bs + 6 * ps) - 12 * ps;
    local pct = string.format('%d%%', math.floor(ps * 100 + 0.5));
    local pw, ph = imgui.CalcTextSize(pct);
    local spots = { { -1, right - bs - 6 * ps - pw - 6 * ps - bs, 'Smaller panel' }, { 1, right - bs, 'Bigger panel' } };
    for _, a in ipairs(spots) do
        local ax = a[2];
        imgui.SetCursorScreenPos({ ax, by });
        local clicked = imgui.InvisibleButton('##yui_sz' .. a[1], { bs, bs });
        local hov = imgui.IsItemHovered();
        if hov then
            DL.RF(dl, ax, by, ax + bs, by + bs, U4(C.acc[1], C.acc[2], C.acc[3], 0.22), bs / 2);
            YUI_TIP(a[3]);
        end
        local col = u32(hov and { 1, 1, 1, 1 } or { 0.80, 0.78, 0.90, 0.9 });
        local cx, cy, r = ax + bs / 2, by + bs / 2, bs * 0.18;
        if a[1] < 0 then DL.TF(dl, cx + r * 0.7, cy - r, cx + r * 0.7, cy + r, cx - r * 0.8, cy, col);
        else DL.TF(dl, cx - r * 0.7, cy - r, cx + r * 0.8, cy, cx - r * 0.7, cy + r, col); end
        if clicked then
            cfg.panel_scale = math.max(0.7, math.min(1.8, math.floor((ps + a[1] * 0.05) * 100 + 0.5) / 100));
            save();
        end
    end
    DL.T(dl, right - bs - 6 * ps - pw, by + (bs - ph) / 2, U4(0.85, 0.83, 0.93, 1), pct);
    for k, b in ipairs({ { 'x', 'Close (type /yunaui to open it again)' } }) do
        local bx = wx + ww - 14 * ps - bs;
        imgui.SetCursorScreenPos({ bx, by });
        local clicked = imgui.InvisibleButton('##yui_tb' .. k, { bs, bs });
        local hov = imgui.IsItemHovered();
        if hov then
            DL.RF(dl, bx, by, bx + bs, by + bs, U4(1, 0.36, 0.62, 0.30), bs / 2);
            YUI_TIP(b[2]);
        end
        local col = u32(hov and { 1, 1, 1, 1 } or { 0.80, 0.78, 0.90, 0.9 });
        local cx, cy, r = bx + bs / 2, by + bs / 2, bs * 0.22;
        do
            DL.L(dl, cx - r, cy - r, cx + r, cy + r, col, 1.6 * ps);
            DL.L(dl, cx - r, cy + r, cx + r, cy - r, col, 1.6 * ps);
        end
        if clicked then ui.open, ui.min, PANEL.anim = false, false, nil; end
    end
end
function PANEL.mini()                                                -- minimised: the logo, top of the screen
    if (tonumber(cfg.mini_x) or -1) < 0 then
        local ds = imgui.GetIO().DisplaySize;
        cfg.mini_x, cfg.mini_y = math.floor(((ds and ds.x) or 1920) / 2 - 28), 6;
    end
    if plain_window('YunaUI Mini##yui_mini', 'mini_x', 'mini_y') then
        local dl = imgui.GetWindowDrawList();
        local x, y = imgui.GetCursorScreenPos();
        local s = math.floor(72 * (tonumber(cfg.scale) or 1));
        local hov = imgui.IsWindowHovered();
        x, y = math.floor(x), math.floor(y);
        local fin = math.min(1, (os.clock() - (PANEL.icon_t0 or 0)) / 0.25);
        image(dl, tex((s == 72) and 'logo_violet_72.png' or 'logo_violet_128.png'), x, y, x + s, y + s, { 1, 1, 1, (hov and 1 or 0.9) * fin });
        if hov then YUI_TIP('Open YunaUI'); end
        local mx, my = imgui.GetMousePos();
        if hov and imgui.IsMouseClicked(0) then PANEL.down = { mx, my }; end
        if PANEL.down and not imgui.IsMouseDown(0) then              -- a click (not a drag) opens it
            if math.abs(mx - PANEL.down[1]) + math.abs(my - PANEL.down[2]) < 5 then
                ui.open, ui.min = true, false;
                PANEL.anim = { kind = 'open', t0 = os.clock() };
            end
            PANEL.down = nil;
        end
        imgui.Dummy({ s, s });
        end_plain('mini_x', 'mini_y');
    else
        imgui.End(); imgui.PopStyleVar(2);
    end
end
local function draw_window()
    if not ui.open then return; end                                 -- (closed: /yunaui or /yui opens it)
    C.ps = math.max(0.7, math.min(1.8, tonumber(cfg.panel_scale) or 1));   -- GENERAL > Settings panel size
    local ps = C.ps;
    local SW = math.floor(220 * ps);                                 -- the sidebar
    ROW_W = math.floor(560 * ps);                                    -- the settings column
    YUI_ROW_W = ROW_W;                                               -- (the EQUIP tab's own rows, in equip.lua)
    local MARGIN = math.floor(8 * ps);                               -- a little room on the left of the column
    local WIN_W = SW + math.floor(30 * ps) + MARGIN + ROW_W + math.floor(50 * ps);
    local ds = imgui.GetIO().DisplaySize;
    local WIN_H = math.floor(math.min(((ds and ds.y) or 1080) - 40, 820 * ps));
    -- minimising / opening: the panel fades into the icon (or out of it) with the chosen look (GENERAL > Minimise animation)
    local palpha = 1;
    local an = PANEL.anim;
    if an then
        local style = cfg.min_anim or 'fly';
        local dur = ({ fly = 0.30, shrink = 0.32, trail = 0.40, beam = 0.38, fold = 0.45, fade = 0.25 })[style] or 0.30;
        local e = math.min(1, (os.clock() - an.t0) / dur);
        local u = (an.kind == 'min') and e or (1 - e);               -- 0 = the panel, 1 = the icon
        local uu = (an.kind == 'min') and (1 - (1 - u) ^ 3) or (u * u * u);
        palpha = 1 - uu;
        if style == 'shrink' then palpha = math.max(0, 1 - u * 2.5);
        elseif style == 'fold' then palpha = math.max(0, 1 - u * 2.2); end
        local s_ = math.floor(72 * (tonumber(cfg.scale) or 1));
        local ix, iy = tonumber(cfg.mini_x) or ((((ds and ds.x) or 1920) / 2) - 36), tonumber(cfg.mini_y) or 6;
        local PA = { tonumber(cfg.win_x) or 240, tonumber(cfg.win_y) or 160, WIN_W, WIN_H };
        local IB = { ix, iy, s_, s_ };
        local function at(t) local q = {}; for k = 1, 4 do q[k] = PA[k] + (IB[k] - PA[k]) * t; end return q; end
        local function cut(fg, q, a, fill)                           -- the panel's rounded shape
            local x1, y1, x2, y2 = q[1], q[2], q[1] + q[3], q[2] + q[4];
            local r = math.min(q[3], q[4]) * 0.10;
            if fill then DL.RF(fg, x1, y1, x2, y2, U4(0.035, 0.032, 0.050, fill), r); end
            DL.R(fg, x1, y1, x2, y2, U4(NEON[1], NEON[2], NEON[3], 0.25 * a), r, C.rall, 6);
            DL.R(fg, x1, y1, x2, y2, U4(0.85, 0.65, 1.00, 0.9 * a), r, C.rall, 1.5);
        end
        if e < 1 then pcall(function()
            local fg = imgui.GetForegroundDrawList();
            local mid = 0.25 + 0.75 * (1 - math.abs(uu - 0.5) * 1.2);
            if style == 'fly' then                                   -- a violet outline flies between them
                cut(fg, at(uu), mid);
            elseif style == 'shrink' then                            -- the panel's dark shape shrinks into the icon
                cut(fg, at(uu), 0.8 * (1 - uu * 0.4), 0.85 * (1 - uu * 0.6));
            elseif style == 'trail' then                             -- outlines strung out behind like a comet
                for k = 0, 4 do
                    local t = math.max(0, math.min(1, uu - k * 0.07 * ((an.kind == 'min') and 1 or -1)));
                    cut(fg, at(t), mid * (1 - k * 0.2));
                end
            elseif style == 'beam' then                              -- a streak of light, and a flash where it lands
                local function centre(q) return q[1] + q[3] / 2, q[2] + q[4] / 2; end
                local ax, ay = centre(PA);
                local bx, by = centre(IB);
                local h1 = (an.kind == 'min') and uu or (1 - uu);
                local h0 = math.max(0, h1 - 0.35);
                local fx, fy = (an.kind == 'min') and ax or bx, (an.kind == 'min') and ay or by;
                local tx, ty = (an.kind == 'min') and bx or ax, (an.kind == 'min') and by or ay;
                local hx, hy = fx + (tx - fx) * h1, fy + (ty - fy) * h1;
                local qx, qy = fx + (tx - fx) * h0, fy + (ty - fy) * h0;
                DL.L(fg, qx, qy, hx, hy, U4(NEON[1], NEON[2], NEON[3], 0.35), 10);
                DL.L(fg, qx, qy, hx, hy, U4(0.92, 0.80, 1.00, 0.95), 2.5);
                DL.CF(fg, hx, hy, 6, U4(1, 0.95, 1, 0.9), 16);
                if h1 > 0.7 then
                    local f = (h1 - 0.7) / 0.3;
                    DL.C(fg, tx, ty, 8 + f * 40, U4(0.80, 0.55, 1.00, 0.9 * (1 - f)), 32, 2);
                end
                cut(fg, PA, 0.6 * (1 - uu));
            elseif style == 'fold' then                              -- folds flat into a line, the line flies into the icon
                if u < 0.5 then
                    local f = u / 0.5;
                    local q = { PA[1], PA[2] + PA[4] * f / 2, PA[3], math.max(2, PA[4] * (1 - f)) };
                    cut(fg, q, 0.9, 0.85);
                else
                    local f = (u - 0.5) / 0.5;
                    local cx1, cy1 = PA[1] + PA[3] / 2, PA[2] + PA[4] / 2;
                    local cx2, cy2 = IB[1] + IB[3] / 2, IB[2] + IB[4] / 2;
                    local cx, cy = cx1 + (cx2 - cx1) * f, cy1 + (cy2 - cy1) * f;
                    local hw = (PA[3] / 2) * (1 - f) + 4;
                    DL.L(fg, cx - hw, cy, cx + hw, cy, U4(NEON[1], NEON[2], NEON[3], 0.35), 8);
                    DL.L(fg, cx - hw, cy, cx + hw, cy, U4(0.92, 0.82, 1.00, 0.95), 2);
                end
            end
        end); end
        if e >= 1 then
            PANEL.anim = nil;
            if an.kind == 'min' then ui.open, ui.min, PANEL.icon_t0 = false, true, os.clock(); return; end
        end
    end
    local nc, nv = push_theme();
    imgui.PushStyleVar(ImGuiStyleVar_Alpha, math.max(0.01, palpha));
    nv = nv + 1;
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    nv = nv + 2;
    imgui.SetNextWindowPos({ tonumber(cfg.win_x) or 240, tonumber(cfg.win_y) or 160 }, ImGuiCond_FirstUseEver);
    imgui.SetNextWindowSize({ WIN_W, WIN_H }, ImGuiCond_Always);
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse);
    local pushed = push_font(fonts.chat or fonts.main, 18 * C.ps);
    local open = { true };
    if imgui.Begin('YunaUI##yui_main', open, flags) then
        local dl = imgui.GetWindowDrawList();
        local pf = fonts.chat or fonts.main;
        C.wfs = 1;                                                   -- older ImGui can't size a font: scale the window's text
        if pf == nil or not YUI_NEWFONT(pf) then C.wfs = C.ps; imgui.SetWindowFontScale(C.wfs); end
        local wx, wy = imgui.GetWindowPos();
        PANEL.frame(dl, wx, wy, WIN_W, WIN_H, SW);
        PANEL.sidebar(dl, wx + 26 * ps, wy + 34 * ps, SW - 40 * ps, wy + WIN_H - 30 * ps);
        PANEL.buttons(dl, wx, wy + 6 * ps, WIN_W - 10 * ps);
        pcall(PANEL.modes, dl, wx + SW + math.floor(30 * ps) + MARGIN, wy + math.floor(18 * ps));   -- NORMAL MODE | HEX LINK MODE
        if (ui.tab or 1) > #TABS then ui.tab = 1; end                -- (the old HEX LINK tab's number)
        local tab = ui.tab or 1;
        -- the settings, in one column that scrolls (the sidebar stays put)
        local cx = wx + SW + math.floor(30 * ps);
        local ctop = wy + math.floor(54 * ps);
        local ch = WIN_H - math.floor(54 * ps) - math.floor(84 * ps);
        imgui.SetCursorScreenPos({ cx, ctop });
        imgui.BeginChild('##yui_body', { MARGIN + ROW_W + math.floor(14 * ps), ch }, false);
        if C.wfs ~= 1 then imgui.SetWindowFontScale(C.wfs); end
        imgui.Indent(MARGIN);
        imgui.PushTextWrapPos(imgui.GetCursorPosX() + ROW_W);         -- long hints wrap inside the column
        -- a colour row: the name, a swatch to pick the colour, R to put it back
        local function colour_row(key, label, def, name_col)
            local x0 = imgui.GetCursorPosX();
            imgui.AlignTextToFramePadding();
            local cur = (type(cfg[key]) == 'table') and cfg[key] or def;
            imgui.TextColored(name_col and { cur[1], cur[2], cur[3], 1 } or C.text, label);
            imgui.SameLine(x0 + ROW_W - 64);
            local edit = { cur[1], cur[2], cur[3] };
            if imgui.ColorEdit3('##' .. key, edit, bit.bor(ImGuiColorEditFlags_NoInputs, ImGuiColorEditFlags_NoLabel)) then
                cfg[key] = { edit[1], edit[2], edit[3] };
                ui.col_dirty = true;
            end
            imgui.SameLine(x0 + ROW_W - 30);
            if imgui.Button('R##r' .. key, { 30, 0 }) then cfg[key] = nil; save(); end
            if imgui.IsItemHovered() then YUI_TIP('Back to the normal colour'); end
        end
        local function hint(s) imgui.TextColored(C.muted, s); end
        if tab == 1 then
            ------------------------------------------------------------------ GENERAL
            section('LAYOUT');
            do
                local bw3 = math.floor((ROW_W - 16) / 3);
                if accent_button('CLASSIC##yui_lay1', { bw3, 0 }, false, true) then LAYOUT.use('classic'); end
                if imgui.IsItemHovered() then YUI_TIP('Your bars side by side at the bottom middle\nParty top right, timers on the left, chat bottom left'); end
                imgui.SameLine(0, 8);
                if accent_button('RAID##yui_lay2', { bw3, 0 }, false, true) then LAYOUT.use('raid'); end
                if imgui.IsItemHovered() then YUI_TIP('Party and alliance top left, your bars stacked bottom middle\nTimers top right, chat bottom right'); end
                imgui.SameLine(0, 8);
                if accent_button('COMPACT##yui_lay3', { bw3, 0 }, false, true) then LAYOUT.use('compact'); end
                if imgui.IsItemHovered() then YUI_TIP('Everything close round your bars, a little below the middle\nParty on their right, timers on their left'); end
                if accent_button('EDIT MODE##yui_editmode', { ROW_W, 0 }, false, true) then EDIT.on = true; ui.open = false; end
                if imgui.IsItemHovered() then YUI_TIP('Shows every piece with a grid; drag them and they snap into line\nAlso: /yui edit'); end
                hint(LAYOUT.msg or 'One click moves every piece of the UI for your screen size. Move anything afterwards as you like.');
            end
            section('MY LAYOUTS');                                   -- five of your own, each with a name
            pcall(LAYOUT.mine_rows);
            hint('Give it a name, SAVE keeps where everything is now and every size (sizes, lengths, thickness, the chat and the Damage Meter too), LOAD puts it all back. Colours, looks and on / off are not changed.');
            section('SHARE MY UI');                                  -- your whole UI as a code, for someone else (or theirs for you)
            local oksh, shh = pcall(LAYOUT.share_rows);
            hint(oksh and shh or 'Share my UI: something went wrong.');
            section('MOVING');
            row_switch('##yui_l', 'Lock positions', 'locked', 'On: nothing can be dragged.');
            hint('Drag anything to move it; each piece is free.');
            section('THIS PANEL');
            row_slider('##yui_palpha', 'Background', 'panel_alpha', 0.15, 1.0, 0.05, '%.2f');
            hint('How see-through the panel is: lower shows more of the game behind it. Double click to put it back.');
            copy_section();
        elseif tab == 2 then
            ------------------------------------------------------------------ TARGET
            local HX = cfg.target_fx == 'link';                      -- (Hex link mode: its own settings in place of the Normal ones)
            section('TARGET BAR');
            row_switch('##yui_t', 'Show', 'target');
            row_slider('##yui_s_t', 'Size', 'target_scale', 0.6, 2.0, 0.05, '%.2fx');
            row_slider('##yui_tnsc', 'Target name size', 'target_name_scale', 0.5, 2.5, 0.05, '%.2fx');
            if HX then
                row_switch('##yui_hl_cc', 'Claim colour', 'hl_claim', 'On: the bar is coloured as the game colours names - orange not claimed, red claimed by you or your party, purple claimed by someone else.');
                row_switch('##yui_hl_hn', "Hide the game's name over your target", 'hl_hidename', "On: the name the game draws over the monster or player you target is hidden - the Hex link bar over its head already shows it. Other names stay.");
                row_slider('##yui_hl_pct', 'HP percent size', 'hl_pct', 0.5, 2.0, 0.05, '%.2fx');
            else
                row_switch('##yui_tban', 'Bar effect', 'target_bar_anim', 'On: a crackling white line runs inside the bar. Off: no white line, just the plain coloured bar.');
            end
            row_slider('##yui_tbh', 'Bar thickness', 'target_bar_h', 1, 12, 1, '%d px');
            row_slider('##yui_tbw', 'Bar length', 'target_w', 160, 700, 10, '%d px');
            row_slider('##yui_tbs', 'Buffs / debuffs size', 'target_buff_scale', 0.6, 2.5, 0.05, '%.2fx');
            row_slider('##yui_tbts', 'Debuff timer size', 'buff_timer_scale', 0.6, 2.5, 0.05, '%.2fx');
            row_switch('##yui_tbtip', 'Debuff details on hover', 'target_buff_tips', 'On: put the mouse over a buff or debuff under the target bar to see its name and the time it has left.');
            section('CASTS AND SKILLCHAINS');
            row_switch('##yui_tfi', 'Show', 'fight_info', HX and 'What the monster is casting or readying (under the bar), and the skillchain banner with Magic Burst at the top of the screen.'
                or "Under the bar: what the monster is casting or readying. From the bar's start: a fan of your weapon skills that close the skillchain. Over the name: the Magic Burst window and its elements.");
            if cfg.fight_info ~= false then
                row_switch('##yui_tfan', HX and 'Skillchain banner' or 'Skillchain fan', 'show_fan', HX and 'On: when your party opens a skillchain, a banner at the top of the screen with the chain, the time and your weapon skills that close it.'
                    or 'On: when your party opens a skillchain, a fan of your weapon skills that close it.');
                row_switch('##yui_tmb', 'Magic Burst', 'show_mb', 'On: after a skillchain, the Magic Burst elements and the chain.');
                if HX then
                    row_slider('##yui_hl_fan', 'Banner size', 'hl_fan', 0.3, 2.0, 0.05, '%.2fx');
                    row_slider('##yui_hl_cast', 'Enemy cast size', 'hl_cast', 0.3, 2.0, 0.05, '%.2fx');
                    hint('The enemy cast size is a share of the target bar size.');
                else
                    row_slider('##yui_fansc', 'Skillchain fan size', 'fan_scale', 0.4, 2.0, 0.05, '%.2fx');
                    row_slider('##yui_mbsc', 'Magic Burst size', 'mb_scale', 0.5, 2.5, 0.05, '%.2fx');
                    row_slider('##yui_ecsc', 'Enemy cast size', 'ecast_scale', 0.4, 2.0, 0.05, '%.2fx');
                    row_slider('##yui_ecft', 'Enemy cast text', 'ecast_font', 0.5, 2.5, 0.05, '%.2fx');
                end
                do
                    local sh = { show = FIGHT.show };
                    row_switch('##yui_fshow', 'Preview them', 'show', 'On: the skillchain, Magic Burst, the enemy cast and the target of target stay on screen (on a pretend target if you have none), so you can see them while you size them. Turn it off when you are done.',
                        sh, function(k, v) FIGHT.show = v; end);
                end
                if not HX then hint('To move the target name, the fan and the enemy cast on screen: GENERAL > LAYOUT > EDIT MODE.'); end
            end
            section('ENTRANCE');
            if HX then
                hint("When you target something a line runs from its head to a diamond, and the bar sits over its head.");
            else
                row_pick('##yui_tfx', 'When you target', 'target_fx', { { 'off', 'Off' }, { 'blade', 'Blade of light' } });
            end
            if HX or (cfg.target_fx or 'blade') ~= 'off' then
                if accent_button('PLAY IT##yui_tfxp', { ROW_W, 0 }) then FIGHT.fx.t0 = os.clock(); end
                hint('Target something and press PLAY IT to see it again.');
            end
            section('TARGET OF TARGET');
            row_switch('##yui_st', 'Show', 'subtarget', 'Who your target is fighting or looking at (and your sub target while you pick one with <st>).');
            if HX then
                row_slider('##yui_hl_tot', 'Size', 'hl_tot', 0.3, 2.0, 0.05, '%.2fx');
                hint('In Hex link it hangs off the target bar: its size is a share of the target bar size.');
            else
                row_slider('##yui_s_sub', 'Size', 'sub_scale', 0.6, 2.0, 0.05, '%.2fx');
            end
            row_slider('##yui_s_subw', 'Length', 'sub_w', 120, 800, 10, '%d px');
            section('ENEMY LIST');
            row_switch('##yui_el', 'Show', 'enemylist', 'Monsters fighting you and your party; click one to target it.');
            row_slider('##yui_s_en', 'Size', 'enemy_scale', 0.6, 2.0, 0.05, '%.2fx');
            row_slider('##yui_s_enw', 'Bar length', 'enemy_w', 100, 500, 10, '%d px');
            row_slider('##yui_s_enm', 'Most shown', 'enemy_max', 1, 20, 1, '%d');
            row_slider('##yui_s_enbi', 'Debuff icon size', 'enemy_buff_scale', 0.6, 2.5, 0.05, '%.2fx');
            row_slider('##yui_s_enbt', 'Debuff text size', 'enemy_buff_text', 0.5, 2.5, 0.05, '%.2fx');
            hint('Previews show while this tab is open.');
        elseif tab == 3 then
            ------------------------------------------------------------------ PARTY
            section('PARTY LIST');
            row_switch('##yui_p', 'Show', 'party');
            if cfg.target_fx == 'link' then row_switch('##yui_hexp', 'Hex plates', 'hex_party', 'Hex link mode: each member on a cut-corner plate - the job tag, the name, Hex link\'s HP bar and the MP, the TP in its own plate. Double-click a plate to turn it over: HP and MP in numbers (double-click again to turn it back). Off: the cards.'); end
            row_switch('##yui_pup', 'Grow upward', 'party_up', 'On: the list fills from the bottom - with a small party (or alone) it sits low, its bottom where a full party\'s would be, and new members push it up.', nil, function()
                if ALLY.pgap and ALLY.pn then                        -- (turned on: down to where a full party's bottom would be; off: back up)
                    local d = (6 - ALLY.pn) * ALLY.pgap;
                    cfg.party_y = (tonumber(cfg.party_y) or 0) + (cfg.party_up and d or -d);
                    WATCH.one = WATCH.one or {}; WATCH.one.party_x = 2;
                    ALLY.ph = nil;
                end
                save();
            end);
            row_switch('##yui_pp', 'Pretend members (to place it)', 'party', 'Fills the empty places so you can place and size the list when alone.', PREVIEW, function() end);
            row_slider('##yui_s_p', 'Size', 'party_scale', 0.6, 2.0, 0.05, '%.2fx');
            row_switch('##yui_pfar', 'Fade far members', 'party_dim_far', 'On: a member farther than the distance below (out of range for spells like Cure) is shown faded, party and alliance. A pretend member shows it while you place the list.');
            if cfg.party_dim_far ~= false then row_slider('##yui_s_pfar', 'Far from', 'party_range', 10, 50, 0.5, '%.1f yalms'); end
            row_pick('##yui_pbside', 'Buffs side', 'party_buff_side', { { 'left', 'Left of the cards' }, { 'right', 'Right of the line' } });
            row_switch('##yui_pbord', 'FFXI buff order', 'party_buff_ffxi', "On: each member's buffs read left to right in the game's own order. Off: the newest next to the card.");
            row_pick('##yui_ptagc', 'Job tag colours', 'party_tag_col', { { 'job', 'Each job its colour' }, { 'role', 'By role' } });
            row_slider('##yui_phth', 'HP bar thickness', 'party_hp_th', 0.5, 3.0, 0.05, '%.2fx');
            row_slider('##yui_pmth', 'MP bar thickness', 'party_mp_th', 0.5, 3.0, 0.05, '%.2fx');
            row_switch('##yui_pdist', 'Distance', 'party_dist', 'On: how far each member is (in yalms), small, after the name. Pink when out of range.');
            row_switch('##yui_pzone', 'Zone of members elsewhere', 'party_zone', 'On: a member in another zone shows where they are, under their name (party and alliance).');
            section('ALLIANCE');
            row_switch('##yui_a', 'Show', 'alliance');
            row_switch('##yui_ap', 'Pretend members (to place it)', 'alliance', 'Shows both alliance parties so you can place and size them when not in an alliance.', PREVIEW, function() end);
            row_switch('##yui_aanc', 'Anchor to the party', 'ally_anchor', 'On: both alliance parties sit right next to your party list, one after the other, and follow it when you move it. Off: each one is its own window: drag it anywhere.');
            row_slider('##yui_s_a1', 'Alliance 1 size', 'ally1_scale', 0.6, 2.0, 0.05, '%.2fx');
            row_slider('##yui_s_a2', 'Alliance 2 size', 'ally2_scale', 0.6, 2.0, 0.05, '%.2fx');
            if not cfg.ally_anchor then hint('Each alliance party is its own window: drag it anywhere.'); end
            hint('Click a member to target them. With Pretend members on, a click just marks one, to see how it looks.');
            section('CARDS');
            hint('Your party and the alliances: job tag, name, HP and MP for each member.');
            row_switch('##yui_clow', 'Low HP warning', 'card_low', 'Under 30% HP the card beats red.');
            do
                local lt = { on = ALLY.lowtest == true };
                row_switch('##yui_clowt', 'Preview low HP', 'on', 'Shows every member as under 30% HP, to see the animation. Turn it off when you are done.', lt, function(k, v) ALLY.lowtest = v; end);
            end
            imgui.Spacing();
            pcall(ALLY.preview);
            section('BUFFS');
            row_switch('##yui_b', 'Show', 'buffs', 'Buff and debuff icons next to each party member, under the target bar and in the enemy list (hover one for its name).');

            row_slider('##yui_s_b', 'Size', 'buff_scale', 0.6, 2.5, 0.05, '%.2fx');
        elseif tab == 4 then
            ------------------------------------------------------------------ BARS
            section('YOUR BARS');                                    -- your own HP / MP / TP (equip.lua's settings)
            if cfg.target_fx == 'link' then                          -- (Hex link mode only)
            row_switch('##yui_tps', 'TP sound', 'tp_sound', 'A chime as your TP reaches 1000, 2000 and 3000 - each one a step higher, so you can hear a weapon skill is ready.');
            end
            if cfg.tp_sound ~= false and cfg.target_fx == 'link' then
                row_slider('##yui_tpv', 'TP sound volume', 'tp_sound_vol', 0.05, 1.5, 0.05, '%.2fx', nil, function()
                    C.SND.bufs = {};                                 -- (made again at the new volume; a preview plays)
                    C.SND.prev = os.clock();
                    save();
                end);
                if C.SND.prev and os.clock() - C.SND.prev > 0.35 then C.SND.prev = nil; C.snd_play('tp3'); end
            end
            if C.head_bars_on() then
                hint('Over your head: thin HP and MP bars, the TP as three dots (gold when full: a weapon skill is ready) and the numbers beside them.');
                row_slider('##yui_hbs', 'Head bars size', 'head_bars_scale', 0.5, 2.5, 0.05, '%.2fx');
                row_slider('##yui_hby', 'Head bars height', 'head_bars_y', -80, 80, 1, '%d');
                row_pick('##yui_hbn', 'Head bars numbers', 'head_nums', { { 'always', 'Always' }, { 'change', 'When they change' }, { 'off', 'Off' } });
                if C.vana_cfg() then hint('Your own name and stars over your head are hidden while these bars are on (VanaCore\'s Hide own nameplate), and come back with Fixed.');
                else hint('Tip: hide your own name and stars over your head in /vana > Options > Nameplates > Hide own nameplate.'); end
            end
            if cfg.target_fx ~= 'link' or (cfg.head_bars or 'fixed') ~= 'head' then   -- (the fixed bars' own settings: only while they show)
                if YUI_EQ_BARS then YUI_EQ_BARS(); end
            end
            local docked = YMAP.dock_on and YMAP.dock_on();          -- (EXP, gil and bag built into the minimap: their own pieces never show)
            if docked then
                section('EXP, GIL AND BAG');
                hint('They are built into the minimap: your EXP (or merits), gil and bag show on it. Want them as windows of their own? MINIMAP > EXP, gil and bag on the map: Off.');
            else
            section('EXP BAR');
            row_switch('##yui_e', 'Show', 'expbar', 'Experience, or limit points and merits when limit mode is on.');
            row_slider('##yui_s_e', 'Ring size', 'exp_scale', 0.5, 2.5, 0.05, '%.2fx');
            row_slider('##yui_s_et', 'Text size', 'exp_text', 0.5, 2.5, 0.05, '%.2fx');
            end
            section('CAST BAR');
            row_switch('##yui_cb', 'Show', 'castbar', 'The spell or item you are casting, over a bar that fills (a preview shows while this tab is open).');
            row_pick('##yui_cbfx', 'Effect', 'cast_fx', { { 'same', 'As the bars' }, { 'still', 'Still' }, { 'flow', 'Flow' }, { 'pulse', 'Pulse' } });
            row_slider('##yui_cbs', 'Size', 'cast_scale', 0.6, 2.0, 0.05, '%.2fx');
            row_slider('##yui_cbw', 'Length', 'cast_w', 120, 900, 10, '%d px');
            row_slider('##yui_cbh', 'Thickness', 'cast_h', 2, 16, 1, '%d px');
            colour_row('cast_c1', 'Bar colour (start)', { 0.55, 0.88, 1.00 });
            colour_row('cast_c2', 'Bar colour (end)', { 0.49, 0.56, 1.00 });
            colour_row('cast_tc', 'Text colour', { 1, 1, 1 });
            section('PET');
            row_switch('##yui_pt', 'Show', 'petbar', 'Your avatar, wyvern, automaton or beast: HP, MP, TP, its ability timers and what it is fighting (a preview shows while this tab is open).');
            row_switch('##yui_ptr', 'Ability timers', 'pet_recasts', 'Blood Pact: Rage / Ward, Ready / Reward, Spirit Link... READY or the time left.');
            row_switch('##yui_ptt', 'What it is fighting', 'pet_target');
            row_slider('##yui_pts', 'Size', 'pet_scale', 0.6, 2.0, 0.05, '%.2fx');
            row_slider('##yui_ptw', 'Length', 'pet_w', 150, 600, 10, '%d px');
            if not docked then                                       -- (only while the minimap is off: then they are pieces of their own)
            section('GIL');
            row_switch('##yui_g', 'Show', 'gil', 'Your gil.');
            if cfg.gil_scale == nil then cfg.gil_scale = tonumber(cfg.gb_scale) or 1; end
            row_slider('##yui_s_gil', 'Size', 'gil_scale', 0.5, 2.5, 0.05, '%.2fx');
            section('BAG');
            row_switch('##yui_bg', 'Show', 'bag', 'How full your bag is.');
            row_pick('##yui_bs', 'Look', 'bag_style', { { 'row', 'Row' }, { 'grid', 'Grid' }, { 'dots', 'Dots' }, { 'bar', 'Bar' } });
            row_slider('##yui_s_gb', 'Size', 'gb_scale', 0.5, 2.5, 0.05, '%.2fx');
            end
        elseif tab == 5 then
            ------------------------------------------------------------------ CHAT
            section('CHAT');
            row_switch('##yui_c', 'Show', 'chat');
            row_switch('##yui_ctype', 'Show what you type', 'chat_typing', "On: while you type, your text also shows in YunaUI's chat (a line above the tabs). Off: only the game's own typing bar shows it.");
            row_switch('##yui_ch', 'Hide the game chat', 'hide_game_chat', 'On: while YunaUI chat is on, the game\'s own chat windows are not drawn at all.');
            if cfg.pad_log then
                imgui.TextColored(C.text, 'Pad: log on ' .. legacy.pad_name(cfg.pad_log) .. ', big on ' .. legacy.pad_name(cfg.pad_big or ((cfg.pad_log:sub(1, 1) == 'd') and 'd49' or 'x12')));
            else
                imgui.TextColored(C.text, 'Pad: not learned yet');
            end
            if accent_button('PAD: LEARN AGAIN##yui_cpad', { ROW_W, 0 }) then cfg.pad_log, cfg.pad_big = nil, nil; legacy.pad_toggle(false); save(); end
            hint("YunaUI learns your pad: the button that opens the game's log (Triangle, X...) then opens YunaUI's chat instead. Learn again: forget it, then press your log button once.");
            row_switch('##yui_c2', 'Split combat log', 'chat_split', 'On: battle messages go to a second chat window of their own (move and size it like the first).');
            row_switch('##yui_ct', 'Timestamps', 'chat_time');
            if cfg.chat_time then
                row_switch('##yui_cts', 'Seconds', 'chat_time_sec');
                row_switch('##yui_ct12', '12-hour clock (8:34pm)', 'chat_time_12');
                if cfg.chat_time_12 then row_pick('##yui_ctc', 'AM/PM case', 'chat_time_case', { { 'lower', 'am / pm' }, { 'upper', 'AM / PM' } }); end
                colour_row('chat_time_col', 'Colour', { 0.62, 0.60, 0.68 }, true);
            end
            section('COMBAT LOG');
            hint('Who:');
            for _, w in ipairs(C.CF_WHO) do
                row_switch('##yui_cfwho_' .. w[1], w[2], 'cf_w_' .. w[1], 'Off: their battle lines are left out of the chat.');
                if w[1] == 'trust' then
                    row_switch('##yui_cfo', 'Other players', 'chat_f_others', 'Off: everything about players outside your party - what they do, and monsters hitting them - is left out. Anything that involves you or your party still shows.');
                end
            end
            hint('What:');
            for _, w in ipairs(C.CF_WHAT) do row_switch('##yui_cfwhat_' .. w[1], w[2], 'cf_t_' .. w[1], 'Off: these battle lines are left out of the chat, whoever did them.'); end
            row_switch('##yui_cfd', 'Area debuff lines', 'chat_f_debuff', 'Off: when one spell or ability puts the same debuff on several monsters (or several resist it), only the first line shows.');
            row_switch('##yui_cfw', 'Buffs wearing off', 'chat_f_wear', 'Off: "... effect wears off" and "... is no longer ..." lines are left out, for everyone but you.');
            hint('"Readies" and "starts casting" lines always show. A battle line shows when both who did it and what it is are on.');
            row_switch('##yui_cfcols', 'Colour by kind', 'cf_cols', 'On: each kind of battle line in its own colour (set them below).');
            if cfg.cf_cols then
                for _, w in ipairs(C.CF_WHAT) do colour_row('cf_col_' .. w[1], w[2], w[3], true); end
            end
            section('LOOK');
            row_pick('##yui_clook', 'Look', 'chat_look', { { 'clear', 'Clear' }, { 'classic', 'Classic' } });
            do                                                       -- CHAT > Tabs: which ones show (All always does)
                if type(cfg.chat_tabs_on) ~= 'table' then cfg.chat_tabs_on = {}; end
                local names = {};
                for i_ = 2, #CHANNELS do names[#names + 1] = CHANNELS[i_][1]; end
                names[#names + 1] = 'Combat';
                hint('Tabs to show (All always shows):');
                for _, nm in ipairs(names) do
                    if cfg.chat_tabs_on[nm] == nil then cfg.chat_tabs_on[nm] = true; end
                    row_switch('##yui_ctab_' .. nm, nm == 'Combat' and 'Combat (the combat log)' or nm, nm, nil, cfg.chat_tabs_on);
                end
            end
            row_switch('##yui_ctbr', 'Back to All when it closes', 'chat_tab_reset', 'On: a tab you pick in the full screen chat (Say, Party, Shout...) goes back to All when you leave it, so command results (/find...) show again. A tab picked anywhere else stays.');
            row_switch('##yui_ctabs', 'Always show tabs', 'chat_tabs_always', 'On: the channel tabs (All, Say, Party...) stay at the bottom of the chat all the time. Off: they show while the mouse is over the chat or you type.');
            if cfg.chat_look ~= 'classic' then
                hint('Clear: a dark rounded panel, a thin bar in each channel\'s colour, the time small on the left, long messages kept in one block.');
                row_slider('##yui_cpa', 'Panel darkness', 'chat_panel_a', 0.0, 1.0, 0.05, '%.2f');
                row_slider('##yui_cmg', 'Space between messages', 'chat_msg_gap', 0, 14, 1, '%d px');
                hint('Panel darkness: 0 is no panel at all. Space between messages: the room between one message and the next (TEXT > Line spacing is the room between the rows of the same message).');
            else
                hint('Classic: the first look - a soft shade behind the lines, the time in brackets at the start of each message.');
            end
            row_switch('##yui_canim', 'Animated lines', 'chat_anim', 'On: new lines slide in with a soft glow (Classic: also a short bar in their channel\'s colour for a moment).');
            row_switch('##yui_cfeed', 'Combat feed', 'chat_feed', 'On: a spell or ability is one line that grows as it happens (who > spell > target, then a tick, the damage, the HP healed or miss) instead of three or four lines. Only new lines.');
            if cfg.chat_feed ~= false then row_switch('##yui_crounds', 'Melee rounds', 'chat_rounds', 'On: one attack round (several hits - Kraken Club, double and triple attacks) is one line: who > target, hits, their damage, crits and misses. Only new lines.'); end
            row_switch('##yui_cfade', 'Fade when idle', 'chat_fade_old', 'On: each line shows for a while, then fades away, and the panel shrinks with it, so the chat clears when nobody writes (put the mouse over it to see everything). Off: every line stays visible all the time.');
            if cfg.chat_fade_old ~= false then row_slider('##yui_s_h', 'Lines stay for', 'chat_hold', 3, 60, 1, '%d s'); end
            row_switch('##yui_cbub', 'Speech bubbles', 'chat_bubbles', 'On: say and party lines also show as a bubble over the head of whoever said it (when they\'re near you).');
            section('HISTORY');
            row_switch('##yui_csave', 'Save chat logs', 'chat_save', 'On: every chat line is also written to a text file, one per day: Ashita\\chatlogs\\<your name>_<date>.txt');
            if accent_button('SAVE THE CHAT NOW##yui_csnow', { ROW_W, 0 }) then pcall(CHATLOG.save_now); end
            hint(CHATLOG.msg or 'The chat keeps your last 3000 conversation lines (say, party, linkshells, tells...) and 2000 battle / system lines. Scroll up with the mouse wheel to read them.');
            if cfg.hide_game_chat and legacy.tries > 5 and (legacy.draw == nil or legacy.draw == 0) then
                imgui.TextColored({ 1, 0.5, 0.6, 1 }, 'Could not find the game chat to hide.');
            end
            section('TEXT');
            row_slider('##yui_s_c', 'Size', 'chat_size', 11, 34, 1, '%d px');
            row_slider('##yui_s_cg', 'Line spacing', 'chat_gap', 0, 16, 1, '%d px');
            hint('Line spacing: the room between rows, also inside a long message.');
            hint('Font: ' .. (fonts.chat_name or 'AvantGarde not found - using a fallback'));
            section('COLOURS');
            hint('Each channel\'s colour is used for its text and (Clear look) for the bar on the left of its messages.');
            row_slider('##yui_cbri', 'Brightness', 'chat_bright', 0.6, 2.0, 0.05, '%.2fx');
            hint('Makes every chat colour brighter (or darker), for screens where the colours are hard to see.');
            for _, cc in ipairs(CHAT_COLS) do colour_row('col_' .. cc[1], cc[2], cc[3], true); end
        elseif tab == 6 then
            equip_tab();
        elseif tab == 7 then
            ------------------------------------------------------------------ TIMERS
            section('COOLDOWNS');
            row_switch('##yui_tm', 'Show', 'timers', 'Your job ability and spell recasts, shortest at the top (a preview shows while this tab is open).');
            row_switch('##yui_tma', 'Job abilities', 'timers_abils');
            row_switch('##yui_tms', 'Spells', 'timers_spells');
            row_switch('##yui_tmr', 'READY flash', 'timers_flash', 'A short flash with READY when a cooldown comes back.');
            row_switch('##yui_tmu', 'Grow upward', 'timers_up', 'On: the shortest sits at the bottom and the list grows up from there.');
            row_pick('##yui_tmf', 'Time', 'timers_fmt', { { 'short', '4:51' }, { 'clock', '00:04:51' } });
            section('SIZE');
            row_slider('##yui_tmsc', 'Size', 'timers_scale', 0.6, 2.0, 0.05, '%.2fx');
            row_slider('##yui_tmw', 'Length', 'timers_w', 120, 600, 10, '%d px');
            row_slider('##yui_tmh', 'Thickness', 'timers_h', 2, 12, 1, '%d px');
            row_slider('##yui_tmn', 'Most shown', 'timers_max', 3, 20, 1, '%d');
            section('COLOURS');
            colour_row('timers_cja', 'Job abilities', { 1.00, 0.85, 0.45 }, true);
            colour_row('timers_cma', 'Spells', { 0.55, 0.80, 1.00 }, true);
            colour_row('timers_csp', 'One-hour abilities', { 1.00, 0.45, 0.75 }, true);
            colour_row('timers_tc', 'Names', { 1, 1, 1 });
            if accent_button('RESTORE DEFAULT COLOURS##yui_tmcr', { ROW_W, 0 }) then
                cfg.timers_cja, cfg.timers_cma, cfg.timers_csp, cfg.timers_tc = nil, nil, nil, nil;
                save();
            end
            hint('Drag the list to move it.');
        elseif tab == 9 then
            ------------------------------------------------------------------ MINIMAP
            section('MINIMAP');
            if YMAP.have() then
            row_switch('##yui_mm', 'Show', 'minimap', 'The map around you, redrawn dark in YunaUI\'s look: you (the arrow), your party in their role colours, monsters and your target.');
            row_switch('##yui_mmdock', 'EXP, gil and bag on the map', 'map_dock', 'On: your EXP (or merits), gil and bag are built into the minimap\'s frame. Off: a plain minimap, and EXP, gil and bag are windows of their own again (their settings in BARS).');
            row_slider('##yui_mms', 'Size', 'map_size', 120, 480, 5, '%d px');
            row_slider('##yui_mmz', 'Zoom', 'map_zoom', 16, 256, 2, '%d');
            hint('Zoom: how much of the map shows round you (smaller is closer). The mouse wheel over the minimap zooms too.');
            row_switch('##yui_mm3f', 'Turn with you', 'map3d_follow', 'The minimap turns as you do, looking the way you face. Off: north stays up.');
            row_switch('##yui_mmtilt', 'Tilt the map', 'map_tilt', 'On: in zones with no 3D shape (most of the open country) the map lies on the ground under you, seen from behind you like the cities\' 3D look. Off: the flat map from above.');
            row_switch('##yui_mmm', 'Monsters', 'map_mobs', 'On: monsters near you show as red dots.');
            row_pick('##yui_mma', 'Your arrow', 'map_arrow_color', { { 'lines', 'As the lines' }, { 'white', 'White' }, { 'pink', 'Pink' },
                { 'violet', 'Violet' }, { 'cyan', 'Cyan' }, { 'gold', 'Gold' }, { 'green', 'Green' } });
            if accent_button('PLAY THE ZONE NAME##yui_mmt_play', { ROW_W, 0 }) then YMAP.tt = os.clock(); end
            hint('The zone\'s name over the minimap comes in with a little animation when you change zone: this plays it again.');
            else
                hint('The minimap needs its map files (the mapsimg and maps3d folders in YunaUI\'s folder).');
            end
        elseif tab == 10 then
            ------------------------------------------------------------------ TREASURE POOL
            section('TREASURE POOL');
            row_switch('##yui_lootw', 'Show the pool', 'loot_win', "On: when something drops, YunaUI's own treasure pool shows it: time left, who is winning, and Lot / Pass buttons. Click an item to keep it picked.");
            row_slider('##yui_s_loot', 'Pool size', 'loot_scale', 0.6, 2.0, 0.05, '%.2fx');
            row_slider('##yui_s_coin', 'Drop coin size', 'loot_coin_scale', 0.5, 2.5, 0.05, '%.2fx');
            hint("With an item picked (the mouse over it or a click in the pool, or the cursor on it in the game's own pool), everyone's lot shows on their party card: a number, -- for a pass, ? for still to go, the highest in gold.");
        else
            ------------------------------------------------------------------ DAMAGE METER
            local D = YUI_DPS;
            if D == nil then
                imgui.TextColored({ 1, 0.5, 0.6, 1 }, 'The damage meter did not load (dps.lua).');
            else
                local ds = D.get();
                local function dsave() D.save(); end
                if ds.bright_title == nil then ds.bright_title = 1; end
                if ds.bright_detail == nil then ds.bright_detail = 1; end
                if ds.backdrop == nil then ds.backdrop = 0.55; end
                section('DAMAGE METER');
                local vis = { visible = ds.visible ~= false, minimized = ds.minimized == true };
                row_switch('##yui_dm_on', 'Show it', 'visible', "Your party's damage, live (also /dps).", vis, function(k, v) D.set_visible(v); end);
                row_switch('##yui_dm_min', 'Minimised (top 3)', 'minimized', 'Only the top lines: click DAMAGE on it to open it again.', vis, function(k, v) D.set_minimized(v); end);
                local anc = { anchor = ds.anchor == true };
                row_switch('##yui_dm_anc', 'Anchor to your HP bar', 'anchor', 'On: the meter flies to the right of your HP bar and stays there (it follows the bar if you move it). Off: drag it anywhere.',
                    anc, function(k, v) if D.set_anchor then D.set_anchor(v); end end);
                if D.try_anchor and accent_button('TRY IT##yui_dm_atry', { ROW_W, 0 }) then D.try_anchor(); end
                local mv = { mode = tonumber(ds.mode) or 1 };
                row_pick('##yui_dm_mode', 'View', 'mode', { { 1, 'Damage' }, { 3, 'Enmity' } }, mv, function(k, v) D.set_mode(v); end);
                if accent_button('RESET THE NUMBERS', { ROW_W, 0 }) then D.reset(); end
                hint('Right click the meter to post the top 5 in party or linkshell chat. /dps shows or hides it.');
                section('COLOURS');
                local function dcol(key, label, def)                -- a colour of the meter: swatch to pick it, R to put it back
                    local x0 = imgui.GetCursorPosX();
                    imgui.AlignTextToFramePadding();
                    local cur = (type(ds[key]) == 'table') and ds[key] or def;
                    imgui.TextColored({ cur[1], cur[2], cur[3], 1 }, label);
                    imgui.SameLine(x0 + ROW_W - 64);
                    local edit = { cur[1], cur[2], cur[3] };
                    if imgui.ColorEdit3('##dm_' .. key, edit, bit.bor(ImGuiColorEditFlags_NoInputs, ImGuiColorEditFlags_NoLabel)) then
                        ds[key] = { edit[1], edit[2], edit[3] };
                        ui.dm_dirty = true;
                    end
                    imgui.SameLine(x0 + ROW_W - 30);
                    if imgui.Button('R##dmr' .. key, { 30, 0 }) then ds[key] = nil; dsave(); end
                    if imgui.IsItemHovered() then YUI_TIP('Back to the normal colour'); end
                end
                dcol('col_name', 'Names', { 1, 1, 1 });
                dcol('col_bar1', 'Bars (start)', { 1.00, 0.36, 0.62 });
                dcol('col_bar2', 'Bars (end)', { 0.62, 0.40, 1.00 });
                dcol('col_title', 'DAMAGE title', { 0.80, 0.58, 1.00 });
                row_slider('##yui_dm_tb', 'DAMAGE title brightness', 'bright_title', 0.4, 1.8, 0.05, '%.2f', ds, dsave);
                dcol('col_detail', 'Details (click a name)', { 0.88, 0.84, 1.00 });
                row_slider('##yui_dm_db', 'Details brightness', 'bright_detail', 0.4, 1.8, 0.05, '%.2f', ds, dsave);
                row_slider('##yui_dm_bk', 'Shadow behind it', 'backdrop', 0, 1, 0.05, '%.2f', ds, dsave);
                hint('A soft dark shadow behind the meter so it reads on bright ground.');
                if ui.dm_dirty and not imgui.IsMouseDown(0) then ui.dm_dirty = false; dsave(); end
            end
        end
        if ui.col_dirty and not imgui.IsMouseDown(0) then ui.col_dirty = false; save(); end   -- colours: saved once you let go
        imgui.Spacing();
        imgui.PopTextWrapPos();
        imgui.Unindent(MARGIN);
        imgui.EndChild();
        -- the bottom: a faint line, and CLOSE
        local by = wy + WIN_H - math.floor(70 * ps);
        DL.L(dl, cx + MARGIN - 20 * ps, by - 10 * ps, cx + MARGIN + ROW_W, by - 10 * ps, U4(1, 1, 1, 0.08), 1);
        local cw = math.floor(260 * ps);
        imgui.SetCursorScreenPos({ cx + MARGIN + (ROW_W - cw) / 2, by });
        if accent_button('CLOSE##yui_close', { cw, math.floor(40 * ps) }, true) then ui.open = false; end
        cfg.win_x, cfg.win_y = wx, wy;
    end
    imgui.End();
    if pushed then imgui.PopFont(); end
    imgui.PopStyleVar(nv);
    imgui.PopStyleColor(nc);
end

----------------------------------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------------------------------
ashita.events.register('load', 'yui_load', function()
    -- the party window now has the buffs on its left: move it left once so the list stays where it was
    if not cfg.buffs_left then
        cfg.party_x = (tonumber(cfg.party_x) or 40) - ((math.floor(16 * (tonumber(cfg.scale) or 1)) + 2) * 16 + 8);
        cfg.buffs_left = true;
        save();
    end
    -- the new Crisp icon sets: switch to Crisp HD once, to try them (the old sets stay in the list)
    if not cfg.crisp_try then cfg.buff_set = 'Crisp_HD'; cfg.crisp_try = true; save(); end
    -- the user's pick: the Crisp Tetsouou set (the bright, clean-drawn icons)
    if not cfg.tets_pick then cfg.buff_set = 'Crisp_Tetsouou'; cfg.tets_pick = true; save(); end
    -- and now the Pixel Preserving version of it, to try
    if not cfg.pixel_try then cfg.buff_set = 'Pixel_Tetsouou'; cfg.pixel_try = true; save(); end
    if not cfg.remaster_try then cfg.buff_set = 'XIView_Remastered'; cfg.remaster_try = true; save(); end
    -- the standards now: XIView buff icons, the glow mark, Blue inferno or Magic spell, Still or Breathe
    cfg.buff_set, cfg.target_mark = 'XIView_HD', 'flare';
    if tonumber(cfg.glow_style) ~= 4 and tonumber(cfg.glow_style) ~= 6 then cfg.glow_style = 4; end
    cfg.glow_anim = 'still';                                         -- (the glow's animation choice is gone: the clips play as they are)
    cfg.equip_look = 'strip';                                        -- (your gear: always the strip; the wheel / diamond ring are gone)
    if cfg.strip_fx ~= 'muzzle' and cfg.strip_fx ~= 'spell9' and cfg.strip_fx ~= 'none' then cfg.strip_fx = 'muzzle'; end   -- (the others are gone)
    if cfg.bar_fx == 'electric' then cfg.bar_fx = 'still'; end       -- (Electric bar effect and Magic spell overlay are gone)
    if cfg.cast_fx == 'electric' then cfg.cast_fx = 'same'; end
    for _, k in ipairs({ 'barfx', 'barfx_target', 'barfx_party', 'barfx_alliance', 'barfx_equip' }) do
        if cfg[k] == 'spell' then cfg[k] = (k == 'barfx') and 'none' or 'same'; end
    end
    if not cfg.inferno_try then cfg.glow_style = 4; cfg.glow_anim = 'still'; cfg.target_mark = 'flare'; cfg.inferno_try = true; save(); end   -- try the blue flame
    if not cfg.flare_try then cfg.target_mark = 'flare'; cfg.flare_try = true; save(); end   -- try the golden glow once
    if not cfg.elem_try then cfg.buff_set = 'XIView_Elemental'; cfg.elem_try = true; save(); end
    -- the fan now opens to the right, so the logo no longer needs room above it: move it once so it stays put
    if not cfg.fan_right then
        local sz = (tonumber(cfg.logo_size) or 72) * (tonumber(cfg.scale) or 1);
        cfg.logo_y = (tonumber(cfg.logo_y) or 0) + 3 * (sz * 0.62 + 8);
        cfg.fan_right = true;
        save();
    end
    -- and it now has a little room above it for the fan's top button: move it up by that once
    if not cfg.fan_room then
        local sz = (tonumber(cfg.logo_size) or 72) * (tonumber(cfg.scale) or 1);
        local fr, fR = sz * 0.31, sz * 0.5 + sz * 0.31 + 12;
        cfg.logo_y = (tonumber(cfg.logo_y) or 0) - (math.max(10, math.ceil(fR * math.sin(math.rad(25)) + fr - sz / 2 + 6)) - 10);
        cfg.fan_room = true;
        save();
    end
    load_fonts();
end);
-- On unload, save only if our settings file is still the one we know: if another character copied its settings in
-- meanwhile, keep them (saving here used to write the old settings back over the copy)
-- TARGET > Hide the game's name over your target (Hex link mode): the game skips a name when bit 0x8 of the entity's
-- flags at +0x128 is set (FFXiMain.dll's name pass, read 2026-10-23) - VanaCore's own names come after that check, so
-- they go too. Set on your target, taken off again when you change target, turn it off, leave Hex link or unload.
-- Written only when VanaCore's own name_flags / render_flags for that entity sit beside it (+0x124 / +0x120): never a wrong address.
C.HN = { idx = 0, ep = 0, set = false };
function C.hn_off()
    local H = C.HN;
    if H.set and H.ep ~= 0 then
        pcall(function()
            local f = ashita.memory.read_uint32(H.ep + 0x128);
            if f and bit.band(f, 8) ~= 0 then ashita.memory.write_uint32(H.ep + 0x128, bit.band(f, bit.bnot(8))); end
        end);
    end
    H.idx, H.ep, H.set = 0, 0, false;
end
function C.hide_tname()
    local idx = 0;
    pcall(function() idx = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0) or 0; end);
    local me = 0;
    pcall(function() me = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0) or 0; end);
    local want = cfg.target_fx == 'link' and cfg.hl_hidename ~= false and idx ~= 0 and idx ~= me and cfg.target ~= false;
    local H = C.HN;
    if not want or idx ~= H.idx then C.hn_off(); end
    if not want then return; end
    pcall(function()
        local ap = AshitaCore:GetMemoryManager():GetEntity():GetActorPointer(idx);
        if not ap or ap == 0 then return; end
        local ep = ashita.memory.read_uint32(ap + 0x70);
        if not ep or ep == 0 then return; end
        local f = ashita.memory.read_uint32(ep + 0x128);
        if H.idx ~= idx then                                         -- (a new target: check it's the right place first)
            local e = vana and vana.game and vana.game.entity and vana.game.entity(idx);
            if type(e) ~= 'table' or tonumber(e.name_flags) ~= ashita.memory.read_uint32(ep + 0x124)   -- (VanaCore's name_flags and render_flags are
                or tonumber(e.render_flags) ~= ashita.memory.read_uint32(ep + 0x120) then return; end    --  this record's +0x124 / +0x120: it's the right one)
            H.idx, H.ep = idx, ep;
        end
        if bit.band(f, 8) == 0 then                                  -- (the server can rewrite it: put it back each frame)
            ashita.memory.write_uint32(ep + 0x128, bit.bor(f, 8));
            H.set = true;
        end
    end);
end
ashita.events.register('unload', 'yui_unload', function()
    pcall(C.hn_off);                                                 -- (the name over your target back)
    pcall(function() if CHATLOG.f then CHATLOG.f:close(); CHATLOG.f = nil; end end);   -- the chat log file
    pcall(legacy.hide_input, false);                                 -- the game's typing bar and chat windows back
    pcall(legacy.hide_logs, false);
    if WATCH.own ~= nil and own_file('settings.lua') == WATCH.own then save(); end
end);

local last = os.clock();
-- BARS > HP bar colour: Pink (YunaUI) or Red, for your HP bar and the party / alliance lists
C.HPCOL = { pink  = { { 1.00, 0.36, 0.62 }, { 0.86, 0.24, 0.86 }, { 1.00, 0.42, 0.72 } },
            red   = { { 1.00, 0.32, 0.30 }, { 0.80, 0.10, 0.20 }, { 1.00, 0.45, 0.42 } },
            white = { { 1.00, 1.00, 1.00 }, { 0.80, 0.80, 0.86 }, { 1.00, 1.00, 1.00 } } };
C.HEXHP = { { 1.00, 0.84, 0.42 }, { 0.95, 0.56, 0.16 }, { 1.00, 0.88, 0.55 } };   -- (Hex link mode: gold HP, azure MP)
C.HEXMP = { { 0.35, 0.80, 1.00 }, { 0.22, 0.48, 1.00 }, { 0.55, 0.85, 1.00 } };
C.MPCOL = { { 0.40, 0.55, 1.00 }, { 0.62, 0.40, 1.00 }, { 0.62, 0.58, 1.00 } };
C.TGTCOL = { pink = { { 1, 0.78, 0.96 }, nil }, red = { { 1.00, 0.45, 0.42 }, { 0.80, 0.10, 0.20 } },
             white = { { 1.00, 1.00, 1.00 }, { 0.80, 0.80, 0.86 } } };
function C.apply_hp()
    local h = C.HPCOL[cfg.hp_color or 'pink'] or C.HPCOL.pink;
    C.hpb1, C.hpb2 = h[1], h[2];
    YUI_HP_COL = C.HPCOL[cfg.my_hp_color or cfg.hp_color or 'pink'] or h;   -- (equip.lua: your own HP bar)
    for k = 1, 3 do                                                  -- the settings panel in your HP bar's colours
        NEON[k], NEON2[k] = YUI_HP_COL[2][k], YUI_HP_COL[3][k];
        C.acc[k] = YUI_HP_COL[3][k];
    end
    if cfg.target_fx == 'link' then                                  -- (Hex link mode: the panel's gold instead)
        for k = 1, 3 do NEON[k], NEON2[k], C.acc[k] = PANEL.GOLD[k], PANEL.GOLD2[k], PANEL.GOLD2[k]; end
    end
    local t = C.TGTCOL[cfg.target_hp_color or 'pink'] or C.TGTCOL.pink;
    C.tgt1, C.tgt2 = t[1], t[2] or C.hp2;
    YUI_HEX = cfg.target_fx == 'link';                               -- (equip.lua and dps.lua: Hex link mode's look)
    if YUI_HEX and cfg.head_bars ~= 'head' then cfg.head_bars = 'head'; end   -- (Hex link: your bars always over your head - no other place)
    YUI_MP_COL = C.MPCOL;
    C.mpb1, C.mpb2 = C.mp, C.mp2;
    if YUI_HEX then                                                  -- Hex link mode: gold HP everywhere, azure MP
        C.hpb1, C.hpb2 = C.HEXHP[1], C.HEXHP[2];
        YUI_HP_COL = C.HEXHP;
        YUI_MP_COL = C.HEXMP;
        C.mpb1, C.mpb2 = C.HEXMP[1], C.HEXMP[2];
        C.tgt1, C.tgt2 = C.HEXHP[3], C.HEXHP[2];
    end
    YUI_HEXCOL = { gold = PANEL.GOLD, gold2 = PANEL.GOLD2, azure = C.HEXMP[1], azure2 = C.HEXMP[3] };
    YUI_HP_OUTLINE = cfg.hp_outline ~= false;                        -- (equip.lua: the thin black edge on your HP bar)
end
-- A thin black edge round a bar (the whole track), so it always shows on any ground
function C.outline(dl, x, y, w, h)
    if cfg.hp_outline == false then return; end
    local all = ImDrawFlags_RoundCornersAll or ImDrawCornerFlags_All or 15;
    DL.R(dl, x - 1, y - 1, x + w + 1, y + h + 1, U4(0, 0, 0, 0.92), h / 2 + 1, all, 1.5);   -- (touching the bar: no gap of background inside it)
end
YUI_BAR_OUTLINE = function(dl, x, y, w, h) pcall(C.outline, dl, x, y, w, h); end
----------------------------------------------------------------------------------------------------
-- Minimap and big map (BARS > MINIMAP, /yui map): the game's own maps, redrawn dark in YunaUI's look (mapsimg\
-- <zone>_<floor>.png, made from your installed maps), placed the way the game places them. Which map and floor: the
-- game's map table and its floor check, found in FFXiMain.dll as boussole (loonsies, github.com/loonsies/boussole)
-- does. A map is 512 "map pixels"; a world spot is at X * |scale| / 5, -Y * |scale| / 5, less the map's offset.
----------------------------------------------------------------------------------------------------
YMAP = { zone = -1, floor = -1, entry = nil, tex = nil, mobs = {}, mobs_t = 0, check_t = 0, big = false };
function YMAP.have()                                                 -- (the maps are made on your own PC and never published:
    if YMAP.has == nil then                                          --  without the mapsimg folder there is no minimap at all)
        local ok, r = pcall(function() return ashita.fs.exists((addon.path:gsub('[\\/]+$', '')) .. '\\mapsimg'); end);
        YMAP.has = (ok and r) and true or false;
    end
    return YMAP.has;
end
YMAP.COLS = { white = { 1.00, 1.00, 1.00 }, pink = { 1.00, 0.55, 0.78 },                                      -- BARS > MINIMAP > Lines
              cyan = { 0.55, 0.85, 1.00 } };                                                                       -- (cyan: the Target of Target's)
YMAP.ACOLS = { white = { 1, 1, 1 }, pink = { 1.00, 0.55, 0.78 }, violet = { 0.70, 0.55, 1.00 }, cyan = { 0.55, 0.85, 1.00 },
               gold = { 1.00, 0.84, 0.45 }, green = { 0.55, 1.00, 0.65 } };
function YMAP.linecol()                                              -- the map's lines: Hex link mode's azure (its MP bar), else your HP bar's colour
    if YUI_HEX then return C.HEXMP[1]; end
    local h = (type(YUI_HP_COL) == 'table' and type(YUI_HP_COL[1]) == 'table') and YUI_HP_COL[1] or YMAP.COLS.pink;
    return h;
end
function YMAP.acol(al)                                               -- your arrow's colour (MINIMAP > Your arrow; 'lines' = as the lines)
    local c = YMAP.ACOLS[cfg.map_arrow_color or 'lines'] or YMAP.linecol();
    return U4(c[1], c[2], c[3], al or 1);
end
function YMAP.lcol(dim)                                              -- (dim: the place names, softer than the lines)
    local c = YMAP.linecol();
    local m = dim and 0.66 or 1;
    return U4(c[1] * m, c[2] * m, c[3] * m, 1);
end
pcall(ffi.cdef, 'typedef int32_t (__thiscall* YUI_FloorFn)(void* pThis, float X, float Y, float Z);');
function YMAP.table_ptr()
    if YMAP.tp == nil then
        YMAP.tp = 0;
        pcall(function()
            local at = ashita.memory.find('FFXiMain.dll', 0, '8A0D????????5333C05684C95774??8A5424188B7424148B7C2410B9', 0, 0);
            if at ~= 0 then YMAP.tp = ashita.memory.read_uint32(at + 0x1C); end
        end);
    end
    return YMAP.tp;
end
function YMAP.floor_of(x, y, z)                                      -- the game's own floor check (Y and Z swapped, as it wants)
    if YMAP.ffn == nil then
        YMAP.ffn = false;
        pcall(function()
            local fa = ashita.memory.find('FFXiMain.dll', 0, '8B542408568D4424108BF18B4C2410508B44240C', 0, 0);
            local ta = ashita.memory.find('FFXiMain.dll', 0, '8B7424148B4424108B7C240C8B0D', 0x0E, 0);
            if fa ~= 0 and ta ~= 0 then YMAP.ffn, YMAP.fthis = ffi.cast('YUI_FloorFn', fa), ta; end
        end);
    end
    if not YMAP.ffn then return 0; end
    local ok, f = pcall(function()
        local this = ashita.memory.read_uint32(ashita.memory.read_uint32(YMAP.fthis));
        if this == 0 then return 0; end
        return YMAP.ffn(ffi.cast('void*', this), x, z, y);
    end);
    return (ok and tonumber(f)) or 0;
end
function C.map_info()                                                -- /yui mapinfo: one line for a minimap report
    local mm = AshitaCore:GetMemoryManager();
    local zid, x, y, z = 0, 0, 0, 0;
    pcall(function() zid = tonumber(mm:GetParty():GetMemberZone(0)) or 0; end);
    pcall(function()
        local ent, me = mm:GetEntity(), mm:GetParty():GetMemberTargetIndex(0) or 0;
        x, y, z = tonumber(ent:GetLocalPositionX(me)) or 0, tonumber(ent:GetLocalPositionY(me)) or 0, tonumber(ent:GetLocalPositionZ(me)) or 0;
    end);
    local okf, fl = pcall(YMAP.floor_of, x, y, z);
    fl = okf and tonumber(fl) or -1;
    local oke, e = pcall(YMAP.best_entry, zid, fl, x, y);
    if not oke then e = nil; end
    local fls = {};
    local tp = 0;
    pcall(function() tp = YMAP.table_ptr() or 0; end);
    if tp ~= 0 then
        pcall(function()
            for i = 0, 1999 do
                local b_ = tp + i * 0x0E;
                local zz, dat = ashita.memory.read_uint16(b_), ashita.memory.read_uint16(b_ + 8);
                if zz == 0 and dat == 0 and i > 10 then break; end
                if zz == zid then fls[#fls + 1] = tostring(ashita.memory.read_uint8(b_ + 2)); end
            end
        end);
    end
    local zn = '';
    pcall(function() zn = AshitaCore:GetResourceManager():GetString('zones.names', zid) or ''; end);
    msg(string.format('Map info: zone %d%s, at %.1f / %.1f / %.1f, floor %d, map %s%s. Floors in the table: %s%s',
        zid, (zn ~= '') and (' (' .. zn .. ')') or '', x, y, z, fl, e and tostring(e.floor) or 'none',
        (e and e.picked) and ' (picked: the one that shows where you stand)' or ((e and not e.exact) and ' (no exact match: the first map of the zone shown)' or ''),
        (#fls > 0) and table.concat(fls, ' ') or 'none', (tp == 0) and ' (map table not found)' or ''));
end
function YMAP.entry_of(zone, floor)                                  -- the map table's line for this zone and floor
    local tp = YMAP.table_ptr();
    if tp == 0 then return nil; end
    local first = nil;
    for i = 0, 1999 do
        local b = tp + i * 0x0E;
        local z = ashita.memory.read_uint16(b);
        local dat = ashita.memory.read_uint16(b + 8);
        if z == 0 and dat == 0 and i > 10 then break; end
        if z == zone then
            local s = ashita.memory.read_uint8(b + 5);
            local e = { zone = z, floor = ashita.memory.read_uint8(b + 2), scale = (s >= 0x80) and (s - 0x100) or s,
                        ox = ashita.memory.read_int16(b + 0x0A), oy = ashita.memory.read_int16(b + 0x0C) };
            if e.floor == floor then e.exact = true; return e; end
            first = first or e;
        end
    end
    return first;
end
-- mapsimg\cover.lua: for each zone with several maps, which parts of each map have something drawn (64 x 64 squares of
-- 8 map pixels). When the map the game's floor picks has nothing round where you stand (Arrapago Reef's eleven maps),
-- the zone's map that does is shown instead.
function YMAP.cover(zid)
    if YMAP.COV == nil then
        YMAP.COV = false;
        pcall(function()
            local t = dofile((addon.path:gsub('[\\/]+$', '')) .. '\\mapsimg\\cover.lua');
            if type(t) == 'table' then YMAP.COV = t; end
        end);
    end
    return YMAP.COV and YMAP.COV[zid] or nil;
end
function YMAP.covered(e, wx, wy)                                     -- (true: this map has lines within ~2 squares of the spot)
    local cv = YMAP.cover(e.zone);
    local h = cv and cv[e.floor];
    if not h then return true; end                                   -- (nothing known: trusted)
    local k = math.abs(e.scale) / 2560 * 512;
    local mx, my = wx * k - e.ox, -wy * k - e.oy;
    local cx, cy = math.floor(mx / 8), math.floor(my / 8);
    for y_ = cy - 2, cy + 2 do
        for x_ = cx - 2, cx + 2 do
            if x_ >= 0 and x_ < 64 and y_ >= 0 and y_ < 64 then
                local b = y_ * 64 + x_;
                local nib = tonumber(h:sub(math.floor(b / 4) + 1, math.floor(b / 4) + 1), 16) or 0;
                if bit.band(nib, bit.lshift(1, 3 - b % 4)) ~= 0 then return true; end
            end
        end
    end
    return false;
end
function YMAP.entries(zone)                                          -- every line of the map table for this zone
    local tp, out = YMAP.table_ptr(), {};
    if tp == 0 then return out; end
    for i = 0, 1999 do
        local b = tp + i * 0x0E;
        local z = ashita.memory.read_uint16(b);
        local dat = ashita.memory.read_uint16(b + 8);
        if z == 0 and dat == 0 and i > 10 then break; end
        if z == zone then
            local sv = ashita.memory.read_uint8(b + 5);
            out[#out + 1] = { zone = z, floor = ashita.memory.read_uint8(b + 2), scale = (sv >= 0x80) and (sv - 0x100) or sv,
                              ox = ashita.memory.read_int16(b + 0x0A), oy = ashita.memory.read_int16(b + 0x0C) };
        end
    end
    return out;
end
function YMAP.best_entry(zid, fl, wx, wy)                            -- the game's floor's map, or the zone's map that shows this spot
    local e = YMAP.entry_of(zid, fl);
    if e == nil or YMAP.cover(zid) == nil or YMAP.covered(e, wx, wy) then return e; end
    for _, e2 in ipairs(YMAP.entries(zid)) do
        if e2.floor ~= e.floor and YMAP.covered(e2, wx, wy) then e2.picked = true; return e2; end
    end
    return e;
end
function YMAP.load_tex(path)
    local t = nil;
    pcall(function()
        local f = io.open(path, 'rb');
        if f == nil then return; end
        local data = f:read('*a');
        f:close();
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        if ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), data, #data, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
                ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0, nil, nil, ptr) == ffi.C.S_OK then
            local tx = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
            t = { tex = tx, ptr = tonumber(ffi.cast('uint32_t', tx)) };
        end
    end);
    return t;
end
function YMAP.update(ent, me, zid)                                   -- the right map for where you are (checked a few times a second)
    local now = os.clock();
    if zid == YMAP.zone and now - YMAP.check_t < 0.5 then return; end
    YMAP.check_t = now;
    local x, y, z = ent:GetLocalPositionX(me) or 0, ent:GetLocalPositionY(me) or 0, ent:GetLocalPositionZ(me) or 0;
    local fl = YMAP.floor_of(x, y, z);
    if zid == YMAP.zone and fl == YMAP.floor and (YMAP.entry == nil or YMAP.covered(YMAP.entry, x, y)) then return; end
    local e = YMAP.best_entry(zid, fl, x, y);                        -- (still the same map: nothing to load)
    if zid == YMAP.zone and e and YMAP.entry and e.floor == YMAP.entry.floor then YMAP.floor = fl; return; end   -- (still the same map: nothing to load)
    YMAP.zone, YMAP.floor = zid, fl;
    pcall(function() YMAP.name = AshitaCore:GetResourceManager():GetString('zones.names', zid) or ''; end);
    YMAP.entry = e;
    YMAP.tex, YMAP.ltex, YMAP.ntex, YMAP.mtex = nil, nil, nil, nil;
    if YMAP.entry then                                               -- (no map for this exact floor: the zone's first one still shows;
        local dir = (addon.path:gsub('[\\/]+$', '')) .. '\\mapsimg\\';  --  /yui mapinfo tells which is shown, for reports)
        YMAP.tex = YMAP.load_tex(dir .. zid .. '_' .. YMAP.entry.floor .. '.png');        -- the floor and the icons
        YMAP.ltex = YMAP.load_tex(dir .. zid .. '_' .. YMAP.entry.floor .. '_l.png');     -- the lines, white: tinted as drawn
        YMAP.ntex = YMAP.load_tex(dir .. zid .. '_' .. YMAP.entry.floor .. '_n.png');     -- the place names (tinted, softer)
        YMAP.mtex = YMAP.load_tex(dir .. zid .. '_' .. YMAP.entry.floor .. '_m.png');     -- (some maps) the numbered exit boxes, as drawn
    end
end
function YMAP.to_map(wx, wy)                                         -- world (x east, y north) to map pixels (0..512)
    local e = YMAP.entry;
    local k = math.abs(e.scale) / 2560 * 512;
    return wx * k - e.ox, -wy * k - e.oy;
end
function YMAP.mobs_near(ent)                                         -- monsters around, refreshed a few times a second
    local now = os.clock();
    if now - YMAP.mobs_t < 0.25 then return YMAP.mobs; end
    YMAP.mobs_t = now;
    local out = {};
    for i = 1, 0x3FF do
        pcall(function()
            local fl = ent:GetSpawnFlags(i);
            if fl and bit.band(fl, 0x10) ~= 0 and (ent:GetHPPercent(i) or 0) > 0 and (ent:GetRenderFlags0(i) or 0) ~= 0 then
                out[#out + 1] = { ent:GetLocalPositionX(i), ent:GetLocalPositionY(i), i, ent:GetLocalPositionZ(i) or 0 };
            end
        end);
    end
    YMAP.mobs = out;
    return out;
end
-- What sits on the map: monsters, the party in their role colours, the target, and you (the glowing arrow)
function YMAP.marks(dl, ent, party, zid, me, tomap, sc, inside, tilted)
    local tidx = target_index() or 0;
    local function dot(wx, wy, col, r, ring)
        local sx, sy = tomap(wx, wy);
        if not inside(sx, sy) then return; end
        DL.CF(dl, sx, sy, r + 1.2, U4(0, 0, 0, 0.85), 12);
        DL.CF(dl, sx, sy, r, u32(col), 12);
        if ring then DL.C(dl, sx, sy, r + 4 * sc, U4(1, 1, 1, 0.95), 16, 1.6); end
    end
    if cfg.map_mobs ~= false then                                   -- (monsters on another floor - over 6 yalms up or down - fade, gone past 10)
        local myz = ent:GetLocalPositionZ(me) or 0;
        for _, m in ipairs(YMAP.mobs_near(ent)) do
            local fa = 1 - math.max(0, math.min(1, (math.abs((m[4] or myz) - myz) - 6) / 4));
            if fa > 0.05 or m[3] == tidx then dot(m[1], m[2], { 0.89, 0.35, 0.33, 0.9 * math.max(fa, 0.3) }, 2.4 * sc, m[3] == tidx); end
        end
    end
    for i = 1, 17 do
        if party:GetMemberIsActive(i) ~= 0 and party:GetMemberZone(i) == zid then
            local idx = party:GetMemberTargetIndex(i) or 0;
            if idx ~= 0 then
                local tc = ALLY.tagcol(party:GetMemberMainJob(i))[1];
                local col = (i < 6) and { tc[1], tc[2], tc[3], 1 } or { 0.70, 0.69, 0.75, 0.9 };
                dot(ent:GetLocalPositionX(idx) or 0, ent:GetLocalPositionY(idx) or 0, col, 3.2 * sc, idx == tidx);
            end
        end
    end
    if tidx ~= 0 and tidx ~= me then
        local ok, tx, ty = pcall(function() return ent:GetLocalPositionX(tidx), ent:GetLocalPositionY(tidx); end);
        if ok and tx then
            local sx, sy = tomap(tx, ty);
            if inside(sx, sy) then DL.C(dl, sx, sy, 5 * sc, U4(1, 1, 1, 0.95), 16, 1.6); end
        end
    end
    local px, py = tomap(ent:GetLocalPositionX(me) or 0, ent:GetLocalPositionY(me) or 0);
    local yaw = 0;
    pcall(function() yaw = ent:GetLocalPositionYaw(me) or 0; end);
    local fx, fy = math.cos(yaw), math.sin(yaw);
    if tilted then                                                   -- (a tilted map: the way you face, as the view shows it - a step ahead, seen)
        local wx, wy = ent:GetLocalPositionX(me) or 0, ent:GetLocalPositionY(me) or 0;
        local ax, ay = tomap(wx + math.cos(yaw) * 2, wy - math.sin(yaw) * 2);
        local dx, dy = ax - px, ay - py;
        local L = math.sqrt(dx * dx + dy * dy);
        if L > 1e-3 then fx, fy = dx / L, dy / L; end
    end
    do                                                               -- you: the neon outline arrow (images/map_arrow.png), turned your way
        local h = 9.5 * sc;
        local t = C.tex_at('map_arrow.png', math.max(16, math.min(256, math.floor(h * 2 + 0.5)))) or tex('map_arrow.png');
        if t then
            local rx, ry = -fy, fx;                                  -- (the picture's right, as it turns)
            local ok = pcall(function()
                dl:AddImageQuad(t.ptr, { px + (fx - rx) * h, py + (fy - ry) * h }, { px + (fx + rx) * h, py + (fy + ry) * h },
                    { px + (-fx + rx) * h, py + (-fy + ry) * h }, { px + (-fx - rx) * h, py + (-fy - ry) * h },
                    { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 }, YMAP.acol());   -- (white, tinted: MINIMAP > Your arrow)
            end);
            if ok then return; end
        end
    end
    local s = 7 * sc;
    local tip = { px + fx * s, py + fy * s };
    local l = { px - fx * s * 0.7 - fy * s * 0.65, py - fy * s * 0.7 + fx * s * 0.65 };
    local r = { px - fx * s * 0.7 + fy * s * 0.65, py - fy * s * 0.7 - fx * s * 0.65 };
    local back = { px - fx * s * 0.35, py - fy * s * 0.35 };
    ALLY.poly(dl, { tip, r, back }, U4(1.0, 0.36, 0.62, 1));
    ALLY.poly(dl, { tip, back, l }, U4(1.0, 0.36, 0.62, 1));
    local wc = U4(1, 1, 1, 1);
    dl:AddLine(tip, l, wc, 1.2); dl:AddLine(l, back, wc, 1.2); dl:AddLine(back, r, wc, 1.2); dl:AddLine(r, tip, wc, 1.2);
end
-- MINIMAP > Tilt the map: in a zone with no 3D shape (most of the open country), its map is laid flat on the ground under
-- you and seen by the 3D look's camera - behind you, tilted, turning with you - so every zone reads the same way.
-- Drawn in tiles (each one placed by the camera, a little see-through toward the edge); you, your party and monsters
-- sit on it.
function YMAP.tilt2d(dl, ent, party, zid, me, sc, x, y, M, W, H)
    W, H = W or M, H or M;                                           -- (a map that isn't square: the Visor frame)
    local e = YMAP.entry;
    local kk = math.abs(e.scale) / 2560 * 512;                       -- (map pixels a yalm)
    local X, Y = ent:GetLocalPositionX(me) or 0, ent:GetLocalPositionY(me) or 0;
    local yaw = (cfg.map3d_follow ~= false) and YMAP.d3facing(ent, me) or 0;
    local R2 = math.max(8, tonumber(cfg.map_zoom) or 60);            -- (the zoom: map pixels to the edge, as the flat map has it)
    local pitch, dist = 0.95, R2 / kk * 0.62;                        -- (the camera's distance in yalms: about as much ground as the flat map)
    local cy_, sy_ = math.cos(yaw), math.sin(yaw);
    local cp, sp = math.cos(pitch), math.sin(pitch);
    local f = H * 1.1;
    local cxs, cys = x + W / 2, y + H / 2;
    local function proj(wx, wy)                                      -- (a spot on the ground at your height -> the screen)
        local dx, dn = wx - X, wy - Y;
        local rx = dx * cy_ - dn * sy_;
        local rn = dx * sy_ + dn * cy_;
        local depth = rn * cp + dist;
        if depth < 1 then return nil; end
        return cxs + f * rx / depth, cys - f * (rn * sp) / depth;
    end
    local pmx, pmy = YMAP.to_map(X, Y);
    local Rm = R2 * 2.2 * math.max(1, W / H);                                             -- (how much of the map round you: past the view's edge)
    local N = 22;
    local step = Rm * 2 / N;
    C.clip(dl, { x + 2, y + 2 }, { x + W - 2, y + H - 2 }, true);
    local layers = { { YMAP.tex, nil }, { YMAP.ltex, 'l' }, { YMAP.ntex, 'n' } };
    for pass = 1, 3 do
        local tx_ = layers[pass][1];
        if tx_ then
            for i = 0, N - 1 do
                for j = 0, N - 1 do
                    local m0x, m0y = pmx - Rm + i * step, pmy - Rm + j * step;
                    local m1x, m1y = m0x + step, m0y + step;
                    local a0, b0, a1, b1 = math.max(0, m0x), math.max(0, m0y), math.min(512, m1x), math.min(512, m1y);
                    if a1 > a0 and b1 > b0 then
                        local function w(mx_, my_) return (mx_ + e.ox) / kk, -(my_ + e.oy) / kk; end   -- (map pixels -> the world)
                        local p1x, p1y = proj(w(a0, b0));
                        local p2x, p2y = proj(w(a1, b0));
                        local p3x, p3y = proj(w(a1, b1));
                        local p4x, p4y = proj(w(a0, b1));
                        if p1x and p2x and p3x and p4x then
                            local al = 1;                            -- (solid: the minimap's soft dark ground under it does the fading)
                            do
                                local uv1, uv2, uv3, uv4 = { a0 / 512, b0 / 512 }, { a1 / 512, b0 / 512 }, { a1 / 512, b1 / 512 }, { a0 / 512, b1 / 512 };
                                if pass == 2 then                    -- (the lines: a dark copy a pixel down first, readable over snow)
                                    pcall(function() dl:AddImageQuad(tx_.ptr, { p1x + 1, p1y + 1 }, { p2x + 1, p2y + 1 }, { p3x + 1, p3y + 1 }, { p4x + 1, p4y + 1 }, uv1, uv2, uv3, uv4, U4(0, 0, 0, 0.30 * al)); end);   -- (lighter: a full dark copy made the lines look thick)
                                end
                                local c_ = (pass == 1) and { 1, 1, 1 } or YMAP.linecol();
                                if pass == 2 then al = al * 0.72; end    -- (the lines a little softer: thinner-looking on the tilted map)
                                if pass == 3 then c_ = { c_[1] * 0.66, c_[2] * 0.66, c_[3] * 0.66 }; end
                                pcall(function() dl:AddImageQuad(tx_.ptr, { p1x, p1y }, { p2x, p2y }, { p3x, p3y }, { p4x, p4y }, uv1, uv2, uv3, uv4, U4(c_[1], c_[2], c_[3], al)); end);
                            end
                        end
                    end
                end
            end
        end
    end
    dl:PopClipRect();
    local function tomap(wx, wy) local sx_, sy_ = proj(wx, wy); if not sx_ then return -9999, -9999; end return sx_, sy_; end
    local function inside(sx_, sy_)
        local qx, qy = sx_ - cxs, sy_ - cys;
        return sx_ > x + 2 and sx_ < x + W - 2 and sy_ > y + 2 and sy_ < y + H - 2 and (qx / (W * 0.47)) ^ 2 + (qy / (H * 0.47)) ^ 2 < 1;
    end
    YMAP.marks(dl, ent, party, zid, me, tomap, sc, inside, true);
end
-- The 3D map (/yui map3d, and the minimap's 3D look): the zone's own shape in 3D - the edges of its collision mesh
-- (maps3d\<zone>.lua, made from LandSandBoat's xiNavmeshOBJs, GPL-3.0) in the map's line colour, round you. Drag the
-- window to turn it, the wheel zooms; far lines fade. You, your party, monsters and your target sit on it.
YMAP.d3 = { yaw = 0.0, pitch = 0.95, dist = 110, zone = -1, on = false };
function YMAP.d3load(zid)
    local D = YMAP.d3;
    if D.zone == zid then return D.mesh; end
    D.zone, D.mesh, D.hs = zid, nil, nil;
    local path = (addon.path:gsub('[\\/]+$', '')) .. '\\maps3d\\' .. tostring(zid) .. '.lua';
    local f = io.open(path, 'r');
    if f == nil then return nil; end
    f:close();
    local ok, m = pcall(dofile, path);
    if ok and type(m) == 'table' and m.v and m.e then D.mesh = m; D.sx, D.sy, D.sd = {}, {}, {}; end
    return D.mesh;
end
function YMAP.d3height(m, X, Y, Z)                                   -- (which way up the game's height runs against the mesh: once a zone)
    local best, sgn = 1e9, -1;
    local v = m.v;
    for i = 1, #v, 3 do
        local dx, dy = v[i] - X, v[i + 2] - Y;
        if dx * dx + dy * dy < 9 then
            local a, b = math.abs(v[i + 1] - Z), math.abs(v[i + 1] + Z);
            if a < best then best, sgn = a, 1; end
            if b < best then best, sgn = b, -1; end
        end
    end
    return sgn;
end
function YMAP.d3facing(ent, me)                                      -- (a camera yaw behind you, looking the way you face)
    local gy = 0;
    pcall(function() gy = ent:GetLocalPositionYaw(me) or 0; end);
    return math.atan2(math.cos(gy), -math.sin(gy));
end
-- The 3D drawing itself, into the box vx, vy, W, H: the zone's lines, then what sits on it
function YMAP.cell(X, Y)                                             -- your square on the game's grid, as the game writes it: "H-7"
    if not (YMAP.entry and YMAP.entry.scale and YMAP.entry.scale ~= 0) then return nil; end
    local mx, my = YMAP.to_map(X, Y);
    local c, r = math.floor((mx - 16) / 32), math.floor((my - 16) / 32) + 1;
    if c < 0 or c > 14 or r < 1 or r > 15 then return nil; end
    return string.char(65 + c) .. '-' .. r;
end
function YMAP.d3render(dl, m, ent, party, zid, me, sc, vx, vy, W, H, yaw, pitch, dist, soft, grid)
    local D = YMAP.d3;
    local X, Y, Z = ent:GetLocalPositionX(me) or 0, ent:GetLocalPositionY(me) or 0, ent:GetLocalPositionZ(me) or 0;
    D.hs = -1;                                                       -- (the mesh's height runs against the game's: checked on every zone with
                                                                     --  known positions; guessing it from nearby points went wrong where few lines are)
    local hs = D.hs;
    local tx, th, ty = X, Z * hs, Y;
    local cy_, sy_ = math.cos(yaw), math.sin(yaw);
    local cp, sp = math.cos(pitch), math.sin(pitch);
    local f = H * 1.1;
    local cxs, cys = vx + W / 2, vy + H / 2;
    local function proj(px, ph, py)                                  -- a world point -> the screen (nil behind the camera)
        local dx, dh, dn = px - tx, ph - th, py - ty;
        local rx = dx * cy_ - dn * sy_;
        local rn = dx * sy_ + dn * cy_;
        local depth = -dh * sp + rn * cp + dist;
        if depth < 1 then return nil; end
        local up = dh * cp + rn * sp;
        return cxs + f * rx / depth, cys - f * up / depth, depth;
    end
    local v, e = m.v, m.e;
    local SX, SY, SD = D.sx, D.sy, D.sd;
    local n = #v / 3;
    for i = 1, n do
        local j = i * 3 - 2;
        local dx, dh, dn = v[j] - tx, v[j + 1] - th, v[j + 2] - ty;
        local rx = dx * cy_ - dn * sy_;
        local rn = dx * sy_ + dn * cy_;
        local depth = -dh * sp + rn * cp + dist;
        if depth < 1 then SD[i] = -1; else
            SD[i] = depth;
            SX[i] = cxs + f * rx / depth;
            SY[i] = cys - f * (dh * cp + rn * sp) / depth;
        end
    end
    C.clip(dl, { vx + 2, vy + 2 }, { vx + W - 2, vy + H - 2 }, true);
    local lc = YMAP.linecol();
    local fade = dist * 2.6;
    local x0, x1, y0, y1 = vx, vx + W, vy, vy + H;
    local cols = {};                                                 -- (a handful of brightness steps, made once a frame)
    for k = 0, 8 do cols[k] = U4(lc[1], lc[2], lc[3], 0.18 + 0.82 * k / 8); end
    local softc = {};                                                -- (the soft edge: from nothing to full, in 16 steps)
    for k = 0, 16 do softc[k] = U4(lc[1], lc[2], lc[3], k / 16); end
    local blackc = {};                                               -- (the outline: black, a little softer than the line)
    for k = 0, 16 do blackc[k] = U4(0, 0, 0, 0.75 * k / 16); end
    -- (open country: past m.net come the lines of the ground's net - left out: bent over the hills, it read as a crooked
    --  copy of the position grid)
    local netk = m.net or (#e + 1);
    local last = netk - 1;
    -- (the minimap: a black outline under every line first, so they read over bright ground; then the lines)
    for pass = (soft and 1 or 2), 2 do
    for k = 1, last, 2 do
        local a, b = e[k], e[k + 1];
        local da, db = SD[a], SD[b];
        if da > 0 and db > 0 then
            local ax, ay, bx_, by_ = SX[a], SY[a], SX[b], SY[b];
            if not ((ax < x0 and bx_ < x0) or (ax > x1 and bx_ > x1) or (ay < y0 and by_ < y0) or (ay > y1 and by_ > y1)) then
                local t = 1 - (da + db) / (2 * fade);
                local dim = (k >= netk) and 0.28 or 1;
                local fh = math.max(math.abs(v[a * 3 - 1] - th), math.abs(v[b * 3 - 1] - th));   -- (other floors fade out: only yours shows, a little above
                local hx, hy = (v[a * 3 - 2] + v[b * 3 - 2]) / 2 - tx, (v[a * 3] + v[b * 3]) / 2 - ty;   --  and below for steps and ramps -
                local tol = 3.5 + math.min(3, 0.08 * math.sqrt(hx * hx + hy * hy));   --  a little more further away (ramps); tunnels stacked
                if fh > tol then dim = dim * math.max(0, 1 - (fh - tol) / 4.5); end   --  right above or under you still fades)
                if soft or dim < 1 then                              -- (no edge at all: the lines fade out in a circle)
                    local ef = 1;
                    if soft then
                        local ex, ey = ((ax + bx_) / 2 - cxs) / (W / 2), ((ay + by_) / 2 - cys) / (H / 2);
                        ef = math.max(0, math.min(1, (1 - math.sqrt(ex * ex + ey * ey)) / 0.32));
                    end
                    local a_ = (0.18 + 0.82 * math.max(0, math.min(1, t))) * ef * dim;
                    if a_ > 0.03 then
                        if pass == 1 then DL.L(dl, ax, ay, bx_, by_, blackc[math.floor(a_ * 16 + 0.5)], 3);
                        else DL.L(dl, ax, ay, bx_, by_, softc[math.floor(a_ * 16 + 0.5)], 1); end
                    end
                else
                    local step = math.floor(math.max(0, math.min(1, t)) * 8 + 0.5);
                    DL.L(dl, ax, ay, bx_, by_, cols[step], 1);
                end
            end
        end
    end
    end
    if grid and YMAP.entry and YMAP.entry.scale and YMAP.entry.scale ~= 0 then   -- the position grid (A-O, 1-15) on the ground, at your height
        local en = YMAP.entry;
        local kk = math.abs(en.scale) / 2560 * 512;
        local function w2(mx_, my_) return (mx_ + en.ox) / kk, -(my_ + en.oy) / kk; end   -- (map pixels -> the world)
        local function fadeat(sx_, sy_)
            if not soft then return 1; end
            local ex, ey = (sx_ - cxs) / (W / 2), (sy_ - cys) / (H / 2);
            return math.max(0, math.min(1, (1 - math.sqrt(ex * ex + ey * ey)) / 0.32));
        end
        local function seg(m0x, m0y, m1x, m1y, a_)
            for q = 0, 11 do                                         -- (in pieces: a long line still bends right in perspective)
                local ax0, ay0 = w2(m0x + (m1x - m0x) * q / 12, m0y + (m1y - m0y) * q / 12);
                local ax1, ay1 = w2(m0x + (m1x - m0x) * (q + 1) / 12, m0y + (m1y - m0y) * (q + 1) / 12);
                local sx0, sy0 = proj(ax0, th, ay0);
                local sx1, sy1 = proj(ax1, th, ay1);
                if sx0 and sx1 then
                    local al = a_ * fadeat((sx0 + sx1) / 2, (sy0 + sy1) / 2);
                    if al > 0.01 then DL.L(dl, sx0, sy0, sx1, sy1, U4(lc[1], lc[2], lc[3], al), 1); end
                end
            end
        end
        for i = 0, 15 do
            local v = 16 + 32 * i;
            seg(v, 16, v, 496, 0.24);
            seg(16, v, 496, v, 0.24);
        end
        local pg = sized('chat', 12 * sc);
        -- its letters along the top and bottom borders and numbers down both sides, as the game's maps have them: each
        -- one where its column / row crosses the view (taken through where you stand)
        local pmx, pmy = YMAP.to_map(X, Y);
        local lh_ = imgui.GetTextLineHeight();
        local lcol_ = { lc[1], lc[2], lc[3], 0.9 };
        for i = 0, 14 do
            local c = 32 + 32 * i;
            local wx_, wy_ = w2(c, pmy);                             -- (column i, at your row)
            local sx_ = proj(wx_, th, wy_);
            if sx_ and sx_ > x0 + 14 and sx_ < x1 - 14 then
                local L_ = string.char(65 + i);
                local tw_ = imgui.CalcTextSize(L_);
                outlined(dl, math.floor(sx_ - tw_ / 2), math.floor(y0 + 4 * sc), L_, lcol_);
                outlined(dl, math.floor(sx_ - tw_ / 2), math.floor(y1 - lh_ - 4 * sc), L_, lcol_);
            end
            local wx2, wy2 = w2(pmx, c);                             -- (row i, at your column)
            local _, sy_ = proj(wx2, th, wy2);
            if sy_ and sy_ > y0 + lh_ + 8 and sy_ < y1 - lh_ - 8 then
                local N_ = tostring(i + 1);
                local nw_ = imgui.CalcTextSize(N_);
                outlined(dl, math.floor(x0 + 6 * sc), math.floor(sy_ - lh_ / 2), N_, lcol_);
                outlined(dl, math.floor(x1 - nw_ - 6 * sc), math.floor(sy_ - lh_ / 2), N_, lcol_);
            end
        end
        unsized(pg);
    end
    local tidx = target_index() or 0;
    local function dot(wx, wy, wz, col, r, ring)
        local px, py = proj(wx, wz * hs, wy);
        if px == nil or px < x0 or px > x1 or py < y0 or py > y1 then return; end
        if soft then                                                 -- (outside the circle: not shown)
            local ex, ey = (px - cxs) / (W / 2), (py - cys) / (H / 2);
            if ex * ex + ey * ey > 0.80 then return; end
        end
        DL.CF(dl, px, py, r + 1.2, U4(0, 0, 0, 0.85), 12);
        DL.CF(dl, px, py, r, u32(col), 12);
        if ring then DL.C(dl, px, py, r + 4 * sc, U4(1, 1, 1, 0.95), 16, 1.6); end
    end
    if cfg.map_mobs ~= false then
        for _, mo in ipairs(YMAP.mobs_near(ent)) do
            local ok, mz = pcall(function() return ent:GetLocalPositionZ(mo[3]); end);
            mz = (ok and mz) or Z;
            local fa = 1 - math.max(0, math.min(1, (math.abs(mz - Z) - 6) / 4));   -- (another floor: faded, gone past 10 yalms)
            if fa > 0.05 or mo[3] == tidx then dot(mo[1], mo[2], mz, { 0.89, 0.35, 0.33, 0.9 * math.max(fa, 0.3) }, 2.6 * sc, mo[3] == tidx); end
        end
    end
    for i = 1, 17 do
        if party:GetMemberIsActive(i) ~= 0 and party:GetMemberZone(i) == zid then
            local idx = party:GetMemberTargetIndex(i) or 0;
            if idx ~= 0 then
                local tc = ALLY.tagcol(party:GetMemberMainJob(i))[1];
                local col = (i < 6) and { tc[1], tc[2], tc[3], 1 } or { 0.70, 0.69, 0.75, 0.9 };
                dot(ent:GetLocalPositionX(idx) or 0, ent:GetLocalPositionY(idx) or 0, ent:GetLocalPositionZ(idx) or 0, col, 3.4 * sc, idx == tidx);
            end
        end
    end
    do                                                               -- you: the arrow, laid on the ground and turned your way
        local gy = 0;
        pcall(function() gy = ent:GetLocalPositionYaw(me) or 0; end);
        local fx, fy = math.cos(gy), -math.sin(gy);                  -- (the game's yaw: 0 east, turning towards south)
        local L_ = 2.2;
        local ax, ay = proj(X + fx * L_, th, Y + fy * L_);
        local lx_, ly_ = proj(X - fx * L_ * 0.7 - fy * L_ * 0.7, th, Y - fy * L_ * 0.7 + fx * L_ * 0.7);
        local rx_, ry_ = proj(X - fx * L_ * 0.7 + fy * L_ * 0.7, th, Y - fy * L_ * 0.7 - fx * L_ * 0.7);
        local cx_, cy2 = proj(X, th, Y);
        if ax and lx_ and rx_ and cx_ then
            local wc = YMAP.acol();
            DL.CF(dl, cx_, cy2, 9 * sc, YMAP.acol(0.16), 20);
            ALLY.poly(dl, { { ax, ay }, { rx_, ry_ }, { cx_, cy2 } }, wc);
            ALLY.poly(dl, { { ax, ay }, { cx_, cy2 }, { lx_, ly_ } }, wc);
        end
    end
    dl:PopClipRect();
end
function YMAP.d3draw(party, ent, zid, me, sc)
    local D = YMAP.d3;
    local W = math.floor((tonumber(cfg.map3d_size) or 560) * sc);
    local H = math.floor(W * 0.72);
    first_place('map3d_x', 'map3d_y', -W / 2, -H - 220);
    if not plain_window('YunaUI 3D map##yui_map3d', 'map3d_x', 'map3d_y') then imgui.End(); imgui.PopStyleVar(2); return; end
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    x, y = math.floor(x + 4), math.floor(y + 4);
    local top = math.floor(30 * sc);
    DL.RF(dl, x, y, x + W, y + H + top, U4(0.035, 0.032, 0.05, 0.96), 10 * sc);
    DL.R(dl, x, y, x + W, y + H + top, U4(NEON2[1], NEON2[2], NEON2[3], 0.6), 10 * sc, C.rall, 1.2);
    local pushed = sized('chat', 16 * sc);
    text(dl, x + 12 * sc, y + 6 * sc, ((YMAP.name and YMAP.name ~= '') and YMAP.name or '?') .. '  -  3D', { 1, 1, 1, 1 });
    unsized(pushed);
    local bx = x + W - 26 * sc;                                      -- X to close it
    imgui.SetCursorScreenPos({ bx, y + 4 * sc });
    if imgui.InvisibleButton('##yui_map3d_x', { 22 * sc, 22 * sc }) then D.on = false; end
    local xcol = u32(imgui.IsItemHovered() and { 1, 1, 1, 1 } or { 0.8, 0.78, 0.9, 0.9 });
    local xc, yc, rr = bx + 11 * sc, y + 15 * sc, 5 * sc;
    DL.L(dl, xc - rr, yc - rr, xc + rr, yc + rr, xcol, 1.6);
    DL.L(dl, xc - rr, yc + rr, xc + rr, yc - rr, xcol, 1.6);
    local vx, vy = x, y + top;
    imgui.SetCursorScreenPos({ vx, vy });                            -- the view: drag to turn, the wheel to zoom
    imgui.InvisibleButton('##yui_map3d_view', { W, H });
    local io = imgui.GetIO();
    local mx, my = tonumber(io.MousePos.x) or 0, tonumber(io.MousePos.y) or 0;
    if imgui.IsItemActive() and D.lx then
        D.yaw = D.yaw + (mx - D.lx) * 0.008;
        D.pitch = math.max(0.12, math.min(1.50, D.pitch + (my - D.ly) * 0.006));
    end
    D.lx, D.ly = mx, my;
    if imgui.IsItemHovered() then
        local wheel = io.MouseWheel or 0;
        if wheel ~= 0 then D.dist = math.max(12, math.min(700, D.dist * ((wheel > 0) and (1 / 1.15) or 1.15))); end
    end
    local m = YMAP.d3load(zid);
    if m == nil then
        local p2 = sized('chat', 14 * sc);
        local s_ = 'No 3D map for this zone yet';
        local sw = imgui.CalcTextSize(s_);
        text(dl, vx + (W - sw) / 2, vy + H / 2 - 8 * sc, s_, { 0.75, 0.74, 0.8, 1 });
        unsized(p2);
    else
        YMAP.d3render(dl, m, ent, party, zid, me, sc, vx, vy, W, H, D.yaw, D.pitch, D.dist, false, true);
        local p3 = sized('chat', 11 * sc);                           -- how to use it
        text(dl, vx + 10 * sc, vy + H - 18 * sc, 'Drag to turn  -  wheel to zoom', { 0.7, 0.68, 0.8, 0.8 });
        unsized(p3);
    end
    imgui.SetCursorScreenPos({ x, y });
    imgui.Dummy({ W + 8, H + top + 8 });
    end_plain('map3d_x', 'map3d_y');
end
function YMAP.draw()
    if not YMAP.have() then return; end
    local mm = AshitaCore:GetMemoryManager();
    local party, ent = mm:GetParty(), mm:GetEntity();
    local zid = party:GetMemberZone(0) or 0;
    local me = party:GetMemberTargetIndex(0) or 0;
    if me == 0 then return; end
    if cfg.minimap == false and not YMAP.big and not YMAP.d3.on then return; end
    YMAP.update(ent, me, zid);
    local sc = tonumber(cfg.scale) or 1;
    if cfg.minimap ~= false and not YUI_MAPCOVER then pcall(YMAP.mini, party, ent, zid, me, sc); end   -- (not under the big map)
    if YMAP.big then pcall(YMAP.bigmap, party, ent, zid, me, sc); end
    if YMAP.d3.on then local ok, err = pcall(YMAP.d3draw, party, ent, zid, me, sc); if not ok then YUI_ERRLOG('map3d', err); end end
end
-- How bright the game is round the minimap (twice a second): the four corners of its square, outside its round fade, are
-- copied from the back buffer and averaged. Bright ground (snow, sky, sand): the fade under the map goes darker; dark
-- ground (caves, night): lighter. Eased over half a second; if the screen can't be read the fade stays as it is.
YMAP.lum, YMAP.lum_t, YMAP.lum_s = nil, 0, 1;
function YMAP.read_lum(x, y, M)
    local dev = d3d.get_device();
    local res, bb = dev:GetBackBuffer(0, 0);
    if res ~= 0 or bb == nil then return nil; end
    local out = nil;
    pcall(function()
        local r2, desc = bb:GetDesc();
        if r2 ~= 0 or desc == nil then return; end
        local fmt, BW, BH = tonumber(desc.Format), tonumber(desc.Width), tonumber(desc.Height);
        if fmt ~= 21 and fmt ~= 22 then return; end                  -- (A8R8G8B8 / X8R8G8B8 only)
        local SW, SH = C.screen();
        local kx, ky = BW / SW, BH / SH;
        local c = math.max(8, math.floor(M * 0.16 * kx));            -- (each corner patch, in back-buffer pixels)
        local Y = YMAP.lumsurf;
        if Y == nil or Y.c ~= c or Y.fmt ~= fmt then
            local r3, s = dev:CreateImageSurface(c * 2, c * 2, fmt);
            if r3 ~= 0 or s == nil then return; end
            YMAP.lumsurf = { s = d3d.gc_safe_release(s), c = c, fmt = fmt }; Y = YMAP.lumsurf;
        end
        local rects = ffi.new('RECT[4]');
        local pts = ffi.new('POINT[4]');
        local corners = { { x, y }, { x + M, y }, { x, y + M }, { x + M, y + M } };
        for i, p in ipairs(corners) do
            local px = math.floor(p[1] * kx - ((i == 2 or i == 4) and c or 0));
            local py = math.floor(p[2] * ky - ((i >= 3) and c or 0));
            px = math.max(0, math.min(BW - c, px)); py = math.max(0, math.min(BH - c, py));
            rects[i - 1].left, rects[i - 1].top, rects[i - 1].right, rects[i - 1].bottom = px, py, px + c, py + c;
            pts[i - 1].x, pts[i - 1].y = ((i == 2 or i == 4) and c or 0), ((i >= 3) and c or 0);
        end
        if dev:CopyRects(bb, rects, 4, Y.s, pts) ~= 0 then return; end
        local r4, lock = Y.s:LockRect(nil, 16);                      -- (D3DLOCK_READONLY)
        if r4 ~= 0 or lock == nil then return; end
        local bits, pitch = ffi.cast('uint8_t*', lock.pBits), tonumber(lock.Pitch);
        local sum, n = 0, 0;
        for yy = 0, c * 2 - 1, 3 do
            local row = bits + yy * pitch;
            for xx = 0, c * 2 - 1, 3 do
                local q = row + xx * 4;
                sum = sum + (0.0722 * q[0] + 0.7152 * q[1] + 0.2126 * q[2]); n = n + 1;
            end
        end
        Y.s:UnlockRect();
        if n > 0 then out = sum / n / 255; end
    end);
    bb:Release();
    return out;
end
function YMAP.shade(x, y, M)                                         -- the fade's strength now: 0.5 (dark ground) .. 2.6 (bright)
    local now = os.clock();
    if now - YMAP.lum_t > 0.5 then                                   -- (how bright it is round you, from the zone, the time and the weather -
        YMAP.lum_t = now;                                            --  never read off the screen: that made the game stall twice a second)
        pcall(C.amb_alpha, 0.5);
        YMAP.lum = (C.AMB and C.AMB.v) or 0.55;
    end
    local target = 1;
    if YMAP.lum then target = math.max(0.5, math.min(2.6, 0.45 + YMAP.lum * 2.2 + math.max(0, YMAP.lum - 0.35) * 2.6)); end   -- (bright ground: much darker)
    YMAP.lum_s = YMAP.lum_s + (target - YMAP.lum_s) * math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 3);
    return YMAP.lum_s;
end
-- The zone's name over the minimap, in the "Fade" look (no box, a soft shade, a hairline). It comes in with a little
-- animation each time the zone changes. Gives back the room it took above the map.
function YMAP.gridpos()                                              -- your place on the map's grid, as the game's <pos>: "(I-7)"
    if not (YMAP.entry and YMAP.to_map) then return nil; end
    local out = nil;
    pcall(function()
        local mm = AshitaCore:GetMemoryManager();
        local me = mm:GetParty():GetMemberTargetIndex(0) or 0;
        if me == 0 then return; end
        local ent = mm:GetEntity();
        local mx, my = YMAP.to_map(ent:GetLocalPositionX(me) or 0, ent:GetLocalPositionY(me) or 0);
        local c, r = math.floor((mx - 16) / 32), math.floor((my - 16) / 32) + 1;   -- (15 squares a side, A-O and 1-15, from map pixel 16)
        if c >= 0 and c <= 14 and r >= 1 and r <= 15 then out = string.format('(%s-%d)', string.char(65 + c), r); end
    end);
    return out;
end
function YMAP.title_edge(dl, mid, cyl, sc, low)                     -- (low: on the bottom edge, under the frame)                          -- (MINIMAP > Zone name look > On the frame: the name centred on the frame's
    local name = (YMAP.name and YMAP.name ~= '') and YMAP.name or '?';   --  top edge, which breaks round it - YMAP.tgap)
    local now = os.clock();
    if YMAP.tname ~= name then YMAP.tname, YMAP.tt = name, now; end
    local ez = 1 - (1 - math.min(1, (now - (YMAP.tt or 0)) / 0.6)) ^ 3;
    local pushed = sized('chat', 14 * sc);
    local tw = tonumber((imgui.CalcTextSize(name))) or 0;
    local th = imgui.GetTextLineHeight();
    local ty = math.floor(low and (cyl - th * 0.15) or (cyl - th * 0.85));   -- (sitting on the edge, outside the frame: the chips inside stay clear)
    outlined(dl, math.floor(mid - tw / 2), ty, name, { 0.98, 0.97, 1.0, ez });
    local gp = YMAP.gridpos();
    if gp then
        local fs = FS;
        imgui.SetWindowFontScale(fs * 0.92);
        local gh = imgui.GetTextLineHeight();
        local gc = C.GOLDH2 or { 1, 0.9, 0.62 };
        outlined(dl, math.floor(mid + tw / 2 + 7 * sc), math.floor(ty + th - gh), gp, { gc[1], gc[2], gc[3], ez });
        imgui.SetWindowFontScale(fs);
    end
    YMAP.trect = { math.floor(mid - tw / 2), ty, tw, th, os.clock() };
    unsized(pushed);
end
function YMAP.tgap_of(mid, sc)                                       -- (where the frame's top edge breaks for the name: x from, x to)
    local name = (YMAP.name and YMAP.name ~= '') and YMAP.name or '?';
    local tw = YMAP.tsize(name, 14 * sc);
    local gpw = 0;
    local gp = YMAP.gridpos();
    if gp then gpw = YMAP.tsize(gp, 14 * sc * 0.92) + 7 * sc; end
    return { mid - tw / 2 - 9 * sc, mid + tw / 2 + gpw + 9 * sc };   -- (.low is set by the minimap)
end
function YMAP.gapline(dl, a, b, c, th, ytop)                         -- (a line, broken round the name where it runs along the top edge)
    local g = YMAP.tgap;
    if not g or math.abs(a[2] - ytop) > 0.6 or math.abs(b[2] - ytop) > 0.6 then dl:AddLine(a, b, c, th); return; end
    local x0, x1 = math.min(a[1], b[1]), math.max(a[1], b[1]);
    if x1 <= g[1] or x0 >= g[2] then dl:AddLine(a, b, c, th); return; end
    if x0 < g[1] then DL.L(dl, x0, a[2], g[1], a[2], c, th); end
    if x1 > g[2] then DL.L(dl, g[2], a[2], x1, a[2], c, th); end
end
function YMAP.title(dl, x, y, M, sc, Wt)                             -- (Wt: the map's width, when it isn't square)
    local name = (YMAP.name and YMAP.name ~= '') and YMAP.name or '?';
    local now = os.clock();
    if YMAP.tname ~= name then YMAP.tname, YMAP.tt = name, now; end
    local age = now - (YMAP.tt or 0);
    local p = math.min(1, age / 0.6);
    local ez = 1 - (1 - p) ^ 3;                                      -- (eased: fast, then settling)
    sc = math.max(0.55, M / 220);                                    -- (it grows and shrinks with the minimap)
    local H = math.floor(26 * sc);
    local pushed = sized('chat', 14 * sc);
    local s = name;
    local tw = tonumber((imgui.CalcTextSize(s))) or 0;
    if tw > M - 28 * sc and tw > 0 then                              -- (a long name: a smaller size, so it fits the map's width)
        unsized(pushed);
        pushed = sized('chat', math.max(9, 14 * sc * (M - 28 * sc) / tw));
        tw = tonumber((imgui.CalcTextSize(s))) or 0;
    end
    local th = imgui.GetTextLineHeight();
    local mid = x + (Wt or M) / 2;
    local pk, vi = C.hp, C.mp2;
    do                                                               -- the name with no box at all: on the same soft dark fade as the map,
        local ty = math.floor(y + (H - th) / 2 + (1 - ez) * 4 * sc); --  a hairline under it fading out both ways
        local ft = tex('map_fade.png');
        if ft then                                                   -- (a soft fade under the name and its map position together: a wide,
            local gpw = 0;                                           --  light layer and a narrower one on it - no edge to see)
            local gp0 = YMAP.gridpos();
            if gp0 then local fs = FS; imgui.SetWindowFontScale(fs * 0.92); gpw = (tonumber((imgui.CalcTextSize(gp0))) or 0) + 7 * sc; imgui.SetWindowFontScale(fs); end
            local fmid = mid + gpw / 2;                              -- (drawn here, all inside the name's own room: soft to every side,
            local half = (tw + gpw) / 2 + 90 * sc;                   --  never cut by the window's edge; to the sides it eases out in steps)
            half = math.max((tw + gpw) / 2 + 10 * sc, math.min(half, fmid - x + 2, x + (Wt or M) - fmid - 2));   -- (never wider than the map: no flat cut at the sides)
            local core = (tw + gpw) / 2 * 0.35;
            local y0f, y1f = y + 1, y + H - 1;
            local N, K = 14, 8;
            local function va(yy) local q = 1 - math.abs((yy - (y0f + y1f) / 2) / ((y1f - y0f) / 2)); q = math.max(0, math.min(1, q * 1.6)); return 0.62 * ez * q * q * (3 - 2 * q); end
            local function ha(u) u = math.max(0, math.min(1, 1 - u)); return u * u * (3 - 2 * u); end   -- (u: 0 at the core's edge, 1 at the far end)
            for j = 0, N - 1 do
                local a0 = y0f + (y1f - y0f) * j / N;
                local a1 = y0f + (y1f - y0f) * (j + 1) / N;
                local t0, t1 = va(a0), va(a1);
                local function c(a) return U4(0.01, 0.01, 0.03, a); end
                pcall(function()
                    DL.RFM(dl, fmid - core, a0, fmid + core, a1, c(t0), c(t0), c(t1), c(t1));
                    for k = 0, K - 1 do
                        local u0, u1 = k / K, (k + 1) / K;
                        local h0, h1 = ha(u0), ha(u1);
                        local xa, xb = core + (half - core) * u0, core + (half - core) * u1;
                        DL.RFM(dl, fmid + xa, a0, fmid + xb, a1, c(t0 * h0), c(t0 * h1), c(t1 * h1), c(t1 * h0));
                        DL.RFM(dl, fmid - xb, a0, fmid - xa, a1, c(t0 * h1), c(t0 * h0), c(t1 * h0), c(t1 * h1));
                    end
                end);
            end
        end
        outlined(dl, math.floor(mid - tw / 2), ty, s, { 0.98, 0.97, 1.0, ez });
        local gp = YMAP.gridpos();                                   -- (where you are on the map's grid, as <pos> gives it)
        if gp then
            local fs = FS;
            imgui.SetWindowFontScale(fs * 0.92);                   -- (clear: nearly the name's size, in gold)
            local gh = imgui.GetTextLineHeight();
            local gc = C.GOLDH2 or { 1, 0.9, 0.62 };
            outlined(dl, math.floor(mid + tw / 2 + 7 * sc), math.floor(ty + th - gh), gp, { gc[1], gc[2], gc[3], ez });
            imgui.SetWindowFontScale(fs);
        end
        YMAP.trect = { math.floor(mid - tw / 2), ty, tw, th, os.clock() };   -- (where the name is: the Hex link dock's day tab keeps clear of it)
        local lc = YMAP.linecol();
        local uw = (tw / 2 + 26 * sc) * ez;
        local ly_ = ty + th + 3 * sc;
        local c1, c0 = U4(lc[1], lc[2], lc[3], 0.85 * ez), U4(lc[1], lc[2], lc[3], 0);
        pcall(function() DL.RFM(dl, mid - uw, ly_, mid, ly_ + 1, c0, c1, c1, c0); end);
        pcall(function() DL.RFM(dl, mid, ly_, mid + uw, ly_ + 1, c1, c0, c0, c1); end);
    end
    unsized(pushed);
    return H + math.floor(6 * sc);
end
-- MINIMAP > EXP, gil and bag on the map: under the minimap your jobs, the points, your gil and your bag - one piece
-- instead of four floating ones.
function YMAP.hub_on() return cfg.map_hub == true and cfg.minimap ~= false and YMAP.have() and not YMAP.dock_on(); end
-- Hex link's map dock, the Visor: the minimap wide in a cut-corner frame - your EXP (or limit points) a gold line along
-- its top, your bag an azure line along its bottom, your jobs and gil in two tags under it. Alive: EXP comets fly in from
-- you, a level up bursts out of the map, the bag beats red when nearly full and shakes when it fills, the gil rolls to
-- its new amount with what changed beside it, a new zone draws the frame and scans it, Vana'diel's time and day sit in
-- its corner. With the map at the top of the screen the tags go over it and the zone's name under it.
function YMAP.frame_on() return cfg.minimap ~= false and YMAP.have(); end   -- (the map's frame: always with the minimap; EXP, gil and bag in it: dock_on)
function YMAP.dock_on() return cfg.minimap ~= false and cfg.map_dock ~= false and YMAP.have(); end   -- (both modes: Hex link's Visor, Normal's Capsule)
C.HD = { comets = {} };
C.VDAYS = { { 'Firesday', { 1.0, 0.36, 0.28 } }, { 'Earthsday', { 0.86, 0.68, 0.30 } }, { 'Watersday', { 0.32, 0.62, 1.0 } },
            { 'Windsday', { 0.40, 0.92, 0.50 } }, { 'Iceday', { 0.62, 0.92, 1.0 } }, { 'Lightningday', { 0.78, 0.48, 1.0 } },
            { 'Lightsday', { 1.0, 0.97, 0.88 } }, { 'Darksday', { 0.50, 0.40, 0.72 } } };
C.WXEL = { [4] = 1, [5] = 1, [6] = 3, [7] = 3, [8] = 2, [9] = 2, [10] = 4, [11] = 4, [12] = 5, [13] = 5, [14] = 6, [15] = 6,
           [16] = 7, [17] = 7, [18] = 8, [19] = 8 };                 -- (the weather's element: an index into C.VDAYS' colours)
C.WXNAME = { [4] = 'Hot spell', [5] = 'Heat wave', [6] = 'Rain', [7] = 'Squall', [8] = 'Dust storm', [9] = 'Sandstorm', [10] = 'Wind',
             [11] = 'Gales', [12] = 'Snow', [13] = 'Blizzard', [14] = 'Thunder', [15] = 'Thunderstorm', [16] = 'Auroras', [17] = 'Stellar glare',
             [18] = 'Gloom', [19] = 'Darkness' };
function YMAP.tsize(str, px)                                         -- (a text's width and line height at a size)
    local pushed = sized('chat', px);
    local w_ = tonumber((imgui.CalcTextSize(str))) or 0;
    local h_ = imgui.GetTextLineHeight();
    unsized(pushed);
    return w_, h_;
end
function YMAP.chip(dl, x0, y0, x1, y1, edge, ea, s, kc, flip)        -- (a slanted chip behind words on the map: dark, a fine edge; kc: its
    kc = kc or (y1 - y0) * 0.45;                                     --  slant; flip: leaning the other way, for the right side)
    local p = flip and { { x0, y0 }, { x1 - kc, y0 }, { x1, y1 }, { x0 + kc, y1 } } or { { x0 + kc, y0 }, { x1, y0 }, { x1 - kc, y1 }, { x0, y1 } };
    pcall(function() dl:AddConvexPolyFilled(p, U4(0.03, 0.035, 0.055, 0.88)); end);
    for i = 1, 4 do dl:AddLine(p[i], p[i % 4 + 1], U4(edge[1], edge[2], edge[3], ea), 1); end
end
function YMAP.dock(dl, x, y, M, cx, cy, low, MW, MH)                 -- (low: the map at the top of the screen - its jobs and gil go over it)
    local H = C.HD;
    local now = os.clock();
    local s = math.max(0.55, M / 220);
    local GO, GO2, AZ = C.GOLDH, C.GOLDH2, C.HEXMP[1];
    local function col(c, a) return U4(c[1], c[2], c[3], a); end
    MW, MH = MW or M, MH or M;
    -- the frame: a wide box with cut corners round the map
    local pad = 4 * s;
    local lft, top, rgt, bot = cx - MW / 2 - pad, cy - MH / 2 - pad, cx + MW / 2 + pad, cy + MH / 2 + pad;
    local cut = 0.12 * MH;
    local P = { { lft + cut, top }, { rgt - cut, top }, { rgt, top + cut }, { rgt, bot - cut }, { rgt - cut, bot }, { lft + cut, bot }, { lft, bot - cut }, { lft, top + cut } };
    local function frame(pp, f, c_, th, bars)                        -- (a closed shape's outline from its first corner, f of the way; bars: the
        local n = #pp;                                               --  top and bottom edges left out - the EXP and bag bars are drawn there)
        local L = f * n;
        for i = 1, n do
            if L <= 0 then break; end
            local a, b = pp[i], pp[i % n + 1];
            local e = math.min(1, L);
            if not (bars and (i == 1 or i == 5)) then dl:AddLine(a, { a[1] + (b[1] - a[1]) * e, a[2] + (b[2] - a[2]) * e }, c_, th); end
            L = L - 1;
        end
    end
    local function bar(a, b, f, c_, ga)                              -- (an edge as a bar: a fine dark track, the frame's hairline faint along
        local L = function(p0, p1, c2, t2) YMAP.gapline(dl, p0, p1, c2, t2, (YMAP.tgap and YMAP.tgap.low) and bot or top); end   --  it, then the colour f of the way with a soft glow - one clean
        L(a, b, col({ 0, 0, 0 }, 0.55), 3.6 * s);                    --  line; broken round the zone's name when it sits on the edge)
        L(a, b, col(GO, 0.22), 1);
        if f > 0.002 then
            local e = { a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f };
            L(a, e, col(c_, ga), 4 * s);
            L(a, e, col(c_, 1), 1.8 * s);
        end
    end
    local function scaled(k_)                                        -- (the frame grown round its middle: the level-up burst)
        local q = {};
        for i, p_ in ipairs(P) do q[i] = { cx + (p_[1] - cx) * k_, cy + (p_[2] - cy) * k_ }; end
        return q;
    end
    -- a new zone: the frame draws itself, then a scan runs down it
    local za = now - (YMAP.tt or 0);
    local zf = math.min(1, za / 0.9); zf = 1 - (1 - zf) ^ 3;
    local info = YMAP.dock_on();                                     -- (EXP, gil and bag on the map: off - the frame whole, nothing in it but the day)
    frame(P, 1, col({ 0, 0, 0 }, 0.55), 4 * s, info);
    frame(P, zf, col(GO, 0.75), 1.4 * s, info);
    if za > 0.6 and za < 1.6 then
        local q = (za - 0.6) / 1.0;
        local sy = top + q * (bot - top);
        local hw = (rgt - lft) / 2 - 4 * s;
        DL.L(dl, cx - hw, sy, cx + hw, sy, col(AZ, 0.7 * (1 - q)), 2 * s);
        DL.L(dl, cx - hw, sy - 3 * s, cx + hw, sy - 3 * s, col(AZ, 0.25 * (1 - q)), 5 * s);
    end
    -- Vana'diel's time and day (and the weather), inside the frame's top left corner where the map has faded out
    do
        local vt = (os.time() - 1009810800) * 25;
        local hr, mn = math.floor(vt / 3600) % 24, math.floor(vt / 60) % 60;
        local d = C.VDAYS[math.floor(vt / 86400) % 8 + 1];
        local wx = C.AMB and C.AMB.wx or 0;
        local we = C.WXEL[wx];
        local ts, dc = string.format('%s  %02d:%02d', d[1], hr, mn), d[2];
        local wn, wc = we and C.WXNAME[wx] or nil, we and C.VDAYS[we][2] or nil;
        local pushed = sized('chat', 10.5 * s);
        local th_ = imgui.GetTextLineHeight();
        local tw0 = tonumber((imgui.CalcTextSize(ts))) or 0;         -- (one line in a slanted chip under the top edge, the tags' shape)
        local ww0 = wn and (tonumber((imgui.CalcTextSize(wn))) or 0) or 0;
        local chh = math.floor(th_ * 1.15);
        local kc = chh;                                              -- (45 degrees, as the frame's cut corner: it lies snug along it)
        local inner = 11 * s + tw0 + (wn and (10 * s + 11 * s + ww0) or 0);
        local y0c = top + 3 * s;
        local x0c = lft + cut - (y0c + chh - top) + 3 * s;          -- (its slanted left end on the cut, a hair inside)
        YMAP.chip(dl, x0c, y0c, x0c + kc + 4 * s + inner + 6 * s + kc * 0.5, y0c + chh, GO, 0.55 * zf, s, kc);
        local tx, ty = x0c + kc + 4 * s, y0c + (chh - th_) / 2;
        C.hexdot(dl, tx + 4 * s, y0c + chh / 2, 3.5 * s, col(dc, 0.95 * zf));
        outlined(dl, tx + 11 * s, ty, ts, { 0.92, 0.90, 0.85, 0.95 * zf });
        if wn then
            local wx_ = tx + 11 * s + tw0 + 10 * s;
            C.hexring(dl, wx_ + 4 * s, y0c + chh / 2, 3.5 * s, col(wc, 0.95 * zf), 1.3);
            outlined(dl, wx_ + 11 * s, ty, wn, { wc[1], wc[2], wc[3], 0.95 * zf });
        end
        unsized(pushed);
    end
    if not YMAP.dock_on() then return bot + 4 * s; end            -- (EXP, gil and bag not on the map: just the frame)
    -- the readings
    local pl = AshitaCore:GetMemoryManager():GetPlayer();
    local mj, lvl = pl and pl:GetMainJob() or 0, pl and pl:GetMainJobLevel() or 0;
    local sub, sublvl = pl and pl:GetSubJob() or 0, pl and pl:GetSubJobLevel() or 0;
    local limit = pl and pl.GetIsLimitModeEnabled and pl:GetIsLimitModeEnabled() and C.lv75(pl, lvl);
    local pts, need, v = 0, 1, 0;
    if pl then
        if limit then pts, need = pl:GetLimitPoints() or 0, 10000; else pts, need = pl:GetExpCurrent() or 0, pl:GetExpNeeded() or 1; end
        v = need > 0 and math.max(0, math.min(1, pts / need)) or 0;
    end
    local merits, mmax = pl and pl:GetMeritPoints() or 0, pl and pl:GetMeritPointsMax() or 0;
    local used, bmax = 0, 0;
    pcall(function() local inv = AshitaCore:GetMemoryManager():GetInventory(); used, bmax = inv:GetContainerCount(0) or 0, inv:GetContainerCountMax(0) or 0; end);
    local gil = C.gil_read();
    local blank_ = (lvl <= 0 or mj == 0 or bmax <= 0);                -- (zoning: the game reads level 0, no bag... for a moment -
    if blank_ then H.blank = now; end                                --  no level up, comets or bag alarm from that, nor for 3 s after)
    local live = not blank_ and now - (H.blank or -99) > 3;
    if live and H.pts and pts > H.pts and H.limit == limit and H.lvl == lvl then   -- (EXP comets: what you gained flies from you into the EXP line)
        H.comets[#H.comets + 1] = { t = now, n = pts - H.pts, sx = cx + (math.random() - 0.5) * 20 * s, sy = cy };
    end
    if live and H.lvl and lvl > H.lvl and H.mj == mj then H.burst = now; end   -- (a level up)
    if live and H.used and used > H.used and used >= bmax and bmax > 0 then H.shake = now; end   -- (the bag just filled)
    H.pts, H.limit, H.lvl, H.mj, H.used = pts, limit, lvl, mj, used;
    H.v = H.v and (H.v + (v - H.v) * math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 4)) or v;
    local bu = H.burst and (now - H.burst) or 99;
    local lit = (bu < 1.2) and (1 - bu / 1.2) or 0;
    local fl = 0;                                                    -- (a comet just arrived: the line flashes)
    for _, c in ipairs(H.comets) do if now - c.t > 0.8 and now - c.t < 1.2 then fl = math.max(fl, 1 - (now - c.t - 0.8) / 0.4); end end
    local sh = H.shake and (now - H.shake) or 99;
    local ox = (sh < 0.5) and math.sin(sh * 60) * 3 * s * (1 - sh / 0.5) or 0;
    local near = bmax > 0 and used >= bmax - 5;
    local beat = near and (0.5 + 0.5 * math.sin(now * 6)) or 0;
    local fc = near and { 1.0, 0.36, 0.40 } or AZ;
    local f = bmax > 0 and used / bmax or 0;
    -- the level-up burst: the frame's shape opening out of the map in light
    if bu < 1.6 then
        for k = 0, 2 do
            local q = (bu - k * 0.18) / 1.2;
            if q > 0 and q < 1 then frame(scaled(0.3 + q * 1.1), 1, col(GO2, 0.85 * (1 - q)), (3 - k) * s); end
        end
        local pushed = sized('chat', 22 * s);
        local ls = 'LEVEL UP';
        local lw = tonumber((imgui.CalcTextSize(ls))) or 0;
        outlined(dl, cx - lw / 2, cy - MH * 0.2, ls, { GO2[1], GO2[2], GO2[3], math.min(1, (1.6 - bu) / 0.4) });
        unsized(pushed);
    end
    local function label(str, px_, x_, y_, c_, align)               -- (a little outlined text; align 'r': right-aligned at x_)
        local pushed = sized('chat', px_);
        local w_ = tonumber((imgui.CalcTextSize(str))) or 0;
        local h_ = imgui.GetTextLineHeight();
        outlined(dl, math.floor((align == 'r') and (x_ - w_) or x_), math.floor(y_), str, c_);
        unsized(pushed);
        return w_, h_;
    end
    -- EXP: a gold line along the top edge, its % at the top right; the bag: an azure line along the bottom edge, its count
    -- at the bottom left
    local pctS = string.format('%d%%', math.floor(v * 100));
    local subS = limit and string.format('LP  %d/%d', merits, mmax) or 'EXP';
    if C.lv75(pl, lvl) and not limit then pctS, subS = string.format('%d/%d', merits, mmax), 'MERITS'; end   -- (capped: your merits instead)
    local a, b = P[1], P[2];
    local ex_ = a[1] + (b[1] - a[1]) * H.v;
    bar(a, b, H.v, GO, 0.20 + 0.4 * fl + 0.4 * lit);
    do
        local pw, ph = YMAP.tsize(pctS, 14 * s);                     -- (in a slanted chip under the top edge's right end: "99%  EXP" on one baseline)
        local sw2, ph2 = YMAP.tsize(subS, 9.5 * s);
        local chh = math.floor(ph * 0.95);
        local kc = chh;                                              -- (mirrored: its slanted right end snug along the right cut corner)
        local y0c = top + 3 * s;
        local x1c = rgt - cut + (y0c + chh - top) - 3 * s;
        local x0c = x1c - (kc * 0.5 + 6 * s + pw + 5 * s + sw2 + 4 * s + kc);
        YMAP.chip(dl, x0c, y0c, x1c, y0c + chh, GO, 0.55, s, kc, true);
        local tyc = y0c + (chh - ph) / 2;
        local tx0 = x0c + kc * 0.5 + 6 * s;
        label(pctS, 14 * s, tx0, tyc, { GO2[1], GO2[2], GO2[3], 1 });
        label(subS, 9.5 * s, tx0 + pw + 5 * s, tyc + ph * 0.80 - ph2 * 0.80, { 0.80, 0.76, 0.66, 0.95 });
    end
    do
        local c0, c1 = P[6], P[5];
        bar({ c0[1] + ox, bot }, { c1[1] + ox, bot }, f, fc, 0.20 + 0.3 * beat);
        local uw0, bh = YMAP.tsize(tostring(used), 15 * s);          -- (in a slanted chip on the bag's line, the tags' shape: the count and
        local mw0, bh2 = YMAP.tsize('/' .. tostring(bmax), 11 * s);  --  the size on one baseline)
        local chh = math.floor(bh * 0.95);
        local kc = chh * 0.45;
        local x0c, x1c = c0[1] + ox, c0[1] + ox + kc + 6 * s + uw0 + 2 * s + mw0 + 6 * s + kc;
        local y1c = bot - 3 * s;
        local y0c = y1c - chh;
        local pts_ = { { x0c + kc, y0c }, { x1c, y0c }, { x1c - kc, y1c }, { x0c, y1c } };
        pcall(function() dl:AddConvexPolyFilled(pts_, col({ 0.03, 0.035, 0.055 }, 0.88)); end);
        for i = 1, 4 do dl:AddLine(pts_[i], pts_[i % 4 + 1], col(fc, 0.55 + 0.3 * beat), 1); end
        local tyc = y0c + (chh - bh) / 2;
        local base = tyc + bh * 0.80;                                -- (the big number's baseline: the small one sits on it)
        local uw = label(tostring(used), 15 * s, x0c + kc + 6 * s, tyc, near and { 1, 0.7, 0.72, 1 } or { 0.88, 0.95, 1, 1 });
        label('/' .. tostring(bmax), 11 * s, x0c + kc + 6 * s + uw + 2 * s, base - bh2 * 0.80, { 0.68, 0.76, 0.88, 1 });
    end
    -- the comets: "+N" flying from you into the EXP line's end, a spark at its head
    for i = #H.comets, 1, -1 do
        local c = H.comets[i];
        local q = (now - c.t) / 0.8;
        if now - c.t > 1.3 then table.remove(H.comets, i);
        elseif q < 1 then
            local e = q * q * (3 - 2 * q);
            local mx_ = c.sx + (ex_ - c.sx) * e;
            local my_ = c.sy + (top - c.sy) * e - math.sin(q * math.pi) * 30 * s;
            C.hexdot(dl, mx_, my_, 3.5 * s, col(GO2, 1));
            C.hexdot(dl, mx_, my_, 6 * s, col(GO, 0.3));
            label('+' .. commas(c.n), 12 * s, mx_ + 6 * s, my_ - 14 * s, { GO2[1], GO2[2], GO2[3], 1 - q * 0.6 });
        end
    end
    -- your jobs and gil: two tags hung just outside the frame (under it; over it when low), their outer ends carrying on
    -- the frame's cut corners, their inner ends slanting back to meet in the middle
    local phh = math.floor(18 * s);
    local gap = 3 * s;
    local py0 = low and (top - gap - phh) or (bot + gap);
    local py1 = py0 + phh;
    H.gd = H.gd or gil;
    H.gd = H.gd + (gil - H.gd) * math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 5);
    if math.abs(gil - H.gd) < 1 then H.gd = gil; end
    local function edgeL(yy) return low and (lft + cut + (top - yy)) or (lft + cut + (yy - bot)); end   -- (the cut corners' lines, carried on)
    local function edgeR(yy) return low and (rgt - cut - (top - yy)) or (rgt - cut - (yy - bot)); end
    local near_, far_ = low and py1 or py0, low and py0 or py1;     -- (the side by the frame, the side away from it)
    local function tag4(p)
        pcall(function() dl:AddConvexPolyFilled(p, col({ 0.03, 0.035, 0.055 }, 0.85)); end);
        for i = 1, 4 do dl:AddLine(p[i], p[i % 4 + 1], col(GO, 0.55), 1); end
    end
    local mL, mR = cx - 4 * s, cx + 4 * s;
    local isl = phh * 0.5;                                           -- (the inner ends: a gentler slant, more room for the words)
    tag4({ { edgeL(near_), near_ }, { mL, near_ }, { mL - isl, far_ }, { edgeL(far_), far_ } });
    tag4({ { mR, near_ }, { edgeR(near_), near_ }, { edgeR(far_), far_ }, { mR + isl, far_ } });
    local pushed = sized('chat', 11.5 * s);
    local th = imgui.GetTextLineHeight();
    local tyy = math.floor(py0 + (phh - th) / 2);
    local midy = py0 + phh / 2;
    do                                                               -- the main job's tag in its role colour, then "75 / SAM 37"
        local x0_, xmax = edgeL(midy) + 7 * s, mL - isl * 0.5 - 5 * s;
        local tag = JOBS[mj] or '?';
        local jt = ' ' .. lvl;
        local st = (JOBS[sub] and sublvl > 0) and (' / ' .. JOBS[sub] .. ' ' .. sublvl) or nil;   -- (the support job, a little smaller: it fits)
        local tgw = tonumber((imgui.CalcTextSize(tag))) or 0;
        local jw = tonumber((imgui.CalcTextSize(jt))) or 0;
        local tc = ALLY.tagcol(mj) or { { 0.9, 0.9, 0.9 } };
        outlined(dl, x0_, tyy, tag, { tc[1][1], tc[1][2], tc[1][3], 1 });
        outlined(dl, x0_ + tgw, tyy, jt, { 0.92, 0.90, 0.86, 1 });
        if st then
            local fs = FS;
            imgui.SetWindowFontScale(fs * 0.84);
            local sw = tonumber((imgui.CalcTextSize(st))) or 0;
            local sh = imgui.GetTextLineHeight();
            if x0_ + tgw + jw + sw <= xmax then outlined(dl, x0_ + tgw + jw, tyy + th - sh - 1 * s, st, { 0.78, 0.76, 0.72, 1 }); end
            imgui.SetWindowFontScale(fs);
        end
    end
    do                                                               -- the coin, the amount rolling to its new value, what changed beside it
        local gs = commas(math.floor(H.gd + 0.5));
        local gw = tonumber((imgui.CalcTextSize(gs))) or 0;
        local diff, ga = C.gil_diff(gil);
        local ds = (diff ~= 0) and ((diff > 0 and '+' or '') .. commas(diff)) or nil;
        local dw = ds and ((tonumber((imgui.CalcTextSize(ds))) or 0) * 0.85 + 8 * s) or 0;
        local gx = edgeR(midy) - 8 * s - gw - dw;
        C.hexdot(dl, gx - 9 * s, tyy + th / 2, 5 * s, col(GO, 1));
        C.hexdot(dl, gx - 9 * s, tyy + th / 2, 2.5 * s, col(GO2, 1));
        outlined(dl, gx, tyy, gs, { GO2[1], GO2[2], GO2[3], 1 });
        if ds then
            local fs = FS;
            imgui.SetWindowFontScale(fs * 0.85);
            outlined(dl, gx + gw + 8 * s, tyy + 1 * s, ds, diff > 0 and { 0.55, 1, 0.65, ga } or { 1, 0.5, 0.65, ga });
            imgui.SetWindowFontScale(fs);
        end
    end
    unsized(pushed);
    if low then return bot + 4 * s; end                              -- (the tags are over the map: the zone's name comes under it)
    return py0 + phh + 4 * s;
end
-- Normal mode's map dock, the Capsule: the minimap in a rounded glass card with a pink-to-violet edge - your EXP (or
-- merits, or limit points) glowing along its foot, your bag in a pill at its top right, the day and time in a pill at its
-- top left, your jobs and gil in one rounded pill under it (over it, with the zone's name under, when the map is at the
-- top of the screen). Alive as the Visor is: EXP comets, a level-up burst, the bag beating red near full and shaking when
-- it fills, the gil rolling to its new amount, the frame drawing itself in a new zone.
function YMAP.rrpts(x0, y0, x1, y1, r, n)                            -- (a rounded box's outline, clockwise from its top left)
    local p = {};
    local function arc(cx_, cy_, a0)
        for k = 0, n do local a = a0 + (math.pi / 2) * k / n; p[#p + 1] = { cx_ + math.cos(a) * r, cy_ + math.sin(a) * r }; end
    end
    arc(x1 - r, y0 + r, -math.pi / 2);
    arc(x1 - r, y1 - r, 0);
    arc(x0 + r, y1 - r, math.pi / 2);
    arc(x0 + r, y0 + r, math.pi);
    return p;
end
function YMAP.capsule(dl, x, y, M, cx, cy, low, MW, MH)
    local H = C.HD;
    local now = os.clock();
    local s = math.max(0.55, M / 220);
    local PK, VI, AZ = C.hp or { 1, 0.42, 0.72 }, C.mp2 or { 0.62, 0.40, 1 }, { 0.35, 0.78, 1 };
    local GO2 = { 1, 0.9, 0.62 };
    local function col(c, a) return U4(c[1], c[2], c[3], a); end
    local function mix(t) return { PK[1] + (VI[1] - PK[1]) * t, PK[2] + (VI[2] - PK[2]) * t, PK[3] + (VI[3] - PK[3]) * t }; end
    local pad = 6 * s;
    local lft, top, rgt, bot = cx - MW / 2 - pad, cy - MH / 2 - pad, cx + MW / 2 + pad, cy + MH / 2 + pad;
    local R = 18 * s;
    local P = YMAP.rrpts(lft, top, rgt, bot, R, 6);
    local function edge(pp, f, a, th)                                -- (the outline f of the way round, pink at the left to violet at the right)
        local n = #pp;
        local L = f * n;
        local w = math.max(1, rgt - lft);
        for i = 1, n do
            if L <= 0 then break; end
            local p0, p1 = pp[i], pp[i % n + 1];
            local e = math.min(1, L);
            local q = { p0[1] + (p1[1] - p0[1]) * e, p0[2] + (p1[2] - p0[2]) * e };
            YMAP.gapline(dl, p0, q, col(mix(math.max(0, math.min(1, (p0[1] - lft) / w))), a), th, (YMAP.tgap and YMAP.tgap.low) and bot or top);
            L = L - 1;
        end
    end
    local function scaled(k_)
        local q = {};
        for i, p_ in ipairs(P) do q[i] = { cx + (p_[1] - cx) * k_, cy + (p_[2] - cy) * k_ }; end
        return q;
    end
    -- a new zone: the edge draws itself round, then a soft scan runs down the card
    local za = now - (YMAP.tt or 0);
    local zf = math.min(1, za / 0.9); zf = 1 - (1 - zf) ^ 3;
    for i = 1, #P do local p0, p1 = P[i], P[i % #P + 1]; YMAP.gapline(dl, p0, p1, col({ 0, 0, 0 }, 0.5), 4 * s, (YMAP.tgap and YMAP.tgap.low) and bot or top); end
    edge(P, zf, 0.25, 5 * s);
    edge(P, zf, 0.9, 1.5 * s);
    if za > 0.6 and za < 1.6 then
        local q = (za - 0.6) / 1.0;
        local sy = top + q * (bot - top);
        local hw = (rgt - lft) / 2 - R * 0.6;
        DL.L(dl, cx - hw, sy, cx + hw, sy, col(PK, 0.6 * (1 - q)), 2 * s);
        DL.L(dl, cx - hw, sy - 3 * s, cx + hw, sy - 3 * s, col(VI, 0.2 * (1 - q)), 5 * s);
    end
    local function pill(x0, y0, x1, y1, ec, ea)                      -- (a rounded pill behind words: dark, a fine edge)
        local r = (y1 - y0) / 2;
        DL.RF(dl, x0, y0, x1, y1, U4(0.07, 0.06, 0.10, 0.88), r);
        DL.R(dl, x0, y0, x1, y1, col(ec, ea), r, C.rall, 1);
    end
    local function label(str, px_, x_, y_, c_, align)
        local pushed = sized('chat', px_);
        local w_ = tonumber((imgui.CalcTextSize(str))) or 0;
        local h_ = imgui.GetTextLineHeight();
        outlined(dl, math.floor((align == 'r') and (x_ - w_) or x_), math.floor(y_), str, c_);
        unsized(pushed);
        return w_, h_;
    end
    -- the day and time (and the weather) in a pill at the top left
    do
        local vt = (os.time() - 1009810800) * 25;
        local hr, mn = math.floor(vt / 3600) % 24, math.floor(vt / 60) % 60;
        local d = C.VDAYS[math.floor(vt / 86400) % 8 + 1];
        local wx = C.AMB and C.AMB.wx or 0;
        local we = C.WXEL[wx];
        local ts = string.format('%s  %02d:%02d', d[1], hr, mn);
        local wn, wc = we and C.WXNAME[wx] or nil, we and C.VDAYS[we][2] or nil;
        local tw0, th0 = YMAP.tsize(ts, 10.5 * s);
        local ww0 = wn and YMAP.tsize(wn, 10.5 * s) or 0;
        local ph = math.floor(th0 * 1.25);
        local x0, y0 = lft + R * 0.55, top + 7 * s;
        local inner = 11 * s + tw0 + (wn and (10 * s + 11 * s + ww0) or 0);
        pill(x0, y0, x0 + 8 * s + inner + 9 * s, y0 + ph, PK, 0.5 * zf);
        local tx, ty = x0 + 8 * s, y0 + (ph - th0) / 2;
        DL.CF(dl, tx + 4 * s, y0 + ph / 2, 3.5 * s, col(d[2], 0.95 * zf), 12);
        label(ts, 10.5 * s, tx + 11 * s, ty, { 0.94, 0.92, 0.96, 0.95 * zf });
        if wn then
            local wxx = tx + 11 * s + tw0 + 10 * s;
            DL.C(dl, wxx + 4 * s, y0 + ph / 2, 3.5 * s, col(wc, 0.95 * zf), 12, 1.3);
            label(wn, 10.5 * s, wxx + 11 * s, ty, { wc[1], wc[2], wc[3], 0.95 * zf });
        end
    end
    if not YMAP.dock_on() then return bot + 4 * s; end            -- (EXP, gil and bag not on the map: just the frame)
    -- the readings
    local pl = AshitaCore:GetMemoryManager():GetPlayer();
    local mj, lvl = pl and pl:GetMainJob() or 0, pl and pl:GetMainJobLevel() or 0;
    local sub, sublvl = pl and pl:GetSubJob() or 0, pl and pl:GetSubJobLevel() or 0;
    local limit = pl and pl.GetIsLimitModeEnabled and pl:GetIsLimitModeEnabled() and C.lv75(pl, lvl);
    local pts, need, v = 0, 1, 0;
    if pl then
        if limit then pts, need = pl:GetLimitPoints() or 0, 10000; else pts, need = pl:GetExpCurrent() or 0, pl:GetExpNeeded() or 1; end
        v = need > 0 and math.max(0, math.min(1, pts / need)) or 0;
    end
    local merits, mmax = pl and pl:GetMeritPoints() or 0, pl and pl:GetMeritPointsMax() or 0;
    local used, bmax = 0, 0;
    pcall(function() local inv = AshitaCore:GetMemoryManager():GetInventory(); used, bmax = inv:GetContainerCount(0) or 0, inv:GetContainerCountMax(0) or 0; end);
    local gil = C.gil_read();
    local blank_ = (lvl <= 0 or mj == 0 or bmax <= 0);                -- (zoning: the game reads level 0, no bag... for a moment -
    if blank_ then H.blank = now; end                                --  no level up, comets or bag alarm from that, nor for 3 s after)
    local live = not blank_ and now - (H.blank or -99) > 3;
    if live and H.pts and pts > H.pts and H.limit == limit and H.lvl == lvl then
        H.comets[#H.comets + 1] = { t = now, n = pts - H.pts, sx = cx + (math.random() - 0.5) * 20 * s, sy = cy };
    end
    if live and H.lvl and lvl > H.lvl and H.mj == mj then H.burst = now; end
    if live and H.used and used > H.used and used >= bmax and bmax > 0 then H.shake = now; end
    H.pts, H.limit, H.lvl, H.mj, H.used = pts, limit, lvl, mj, used;
    local shown = (C.lv75(pl, lvl) and not limit) and ((mmax > 0) and merits / mmax or 0) or v;   -- (capped: the bar fills with your merits)
    H.v = H.v and (H.v + (shown - H.v) * math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 4)) or shown;
    local bu = H.burst and (now - H.burst) or 99;
    local lit = (bu < 1.2) and (1 - bu / 1.2) or 0;
    local fl = 0;
    for _, c in ipairs(H.comets) do if now - c.t > 0.8 and now - c.t < 1.2 then fl = math.max(fl, 1 - (now - c.t - 0.8) / 0.4); end end
    local sh = H.shake and (now - H.shake) or 99;
    local ox = (sh < 0.5) and math.sin(sh * 60) * 3 * s * (1 - sh / 0.5) or 0;
    local near = bmax > 0 and used >= bmax - 5;
    local beat = near and (0.5 + 0.5 * math.sin(now * 6)) or 0;
    local bc = near and { 1.0, 0.36, 0.40 } or AZ;
    if bu < 1.6 then                                                 -- (a level up: rounded cards of light opening out of the map)
        for k = 0, 2 do
            local q = (bu - k * 0.18) / 1.2;
            if q > 0 and q < 1 then edge(scaled(0.3 + q * 1.1), 1, 0.85 * (1 - q), (3 - k) * s); end
        end
        local pushed = sized('chat', 22 * s);
        local lw = tonumber((imgui.CalcTextSize('LEVEL UP'))) or 0;
        outlined(dl, cx - lw / 2, cy - MH * 0.2, 'LEVEL UP', { 1, 0.85, 0.95, math.min(1, (1.6 - bu) / 0.4) });
        unsized(pushed);
    end
    -- the bag in a pill at the top right: the count, a fine azure line under it filling with the bag
    do
        local bs = string.format('%d/%d', used, bmax);
        local bw0, bh0 = YMAP.tsize(bs, 12 * s);
        local ph = math.floor(bh0 * 1.25);
        local x1 = rgt - R * 0.55 + ox;
        local x0 = x1 - (bw0 + 18 * s);
        local y0 = top + 7 * s;
        pill(x0, y0, x1, y0 + ph, bc, 0.65 + 0.3 * beat);
        label(bs, 12 * s, x0 + 9 * s, y0 + (ph - bh0) / 2 - 1 * s, near and { 1, 0.72, 0.75, 1 } or { 0.86, 0.94, 1, 1 });
        local f = bmax > 0 and used / bmax or 0;
        local lx0, lx1, ly = x0 + ph * 0.5, x1 - ph * 0.5, y0 + ph - 2.5 * s;
        DL.L(dl, lx0, ly, lx1, ly, col({ 1, 1, 1 }, 0.10), 1.5 * s);
        if f > 0 then DL.L(dl, lx0, ly, lx0 + (lx1 - lx0) * f, ly, col(bc, 1), 1.5 * s); end
    end
    -- EXP (or merits, or limit points) glowing along the card's foot, its words just over its start
    local bx0, bx1 = lft + R * 0.8, rgt - R * 0.8;
    local by = bot - 10 * s;
    local bth = math.max(3, math.floor(4 * s + 0.5));
    DL.RF(dl, bx0, by, bx1, by + bth, U4(0.10, 0.08, 0.14, 0.9), bth / 2);
    local ex_ = bx0 + (bx1 - bx0) * H.v;
    if H.v > 0.003 then
        local fx = math.max(bx0 + bth, ex_);
        DL.RF(dl, bx0 - 2 * s, by - 2 * s, fx + 2 * s, by + bth + 2 * s, col(mix(H.v), 0.12 + 0.3 * fl + 0.3 * lit), bth);
        pcall(function()
            local c1, c2 = col(PK, 1), col(mix(H.v), 1);
            DL.RFM(dl, bx0 + bth / 2, by, fx - bth / 2, by + bth, c1, c2, c2, c1);
        end);
        DL.CF(dl, bx0 + bth / 2, by + bth / 2, bth / 2, col(PK, 1), 10);
        DL.CF(dl, fx - bth / 2, by + bth / 2, bth / 2, col(mix(H.v), 1), 10);
    end
    do
        local word, val;
        if limit then word, val = 'LIMIT', string.format('%d%%  -  merits %d/%d', math.floor(v * 100), merits, mmax);
        elseif C.lv75(pl, lvl) then word, val = 'MERITS', string.format('%d/%d', merits, mmax);
        else word, val = 'EXP', string.format('%d%%', math.floor(v * 100)); end
        local ww, wh = YMAP.tsize(word, 9.5 * s);
        local _, vh = YMAP.tsize(val, 12 * s);
        local ly = by - 4 * s - vh;
        label(word, 9.5 * s, bx0, ly + vh * 0.80 - wh * 0.80, { 0.82, 0.76, 0.90, 0.95 });
        label(val, 12 * s, bx0 + ww + 6 * s, ly, { 1, 0.72, 0.88, 1 });
    end
    -- the comets: "+N" flying from you into the bar's end
    for i = #H.comets, 1, -1 do
        local c = H.comets[i];
        local q = (now - c.t) / 0.8;
        if now - c.t > 1.3 then table.remove(H.comets, i);
        elseif q < 1 then
            local e = q * q * (3 - 2 * q);
            local mx_ = c.sx + (ex_ - c.sx) * e;
            local my_ = c.sy + (by - c.sy) * e - math.sin(q * math.pi) * 30 * s;
            DL.CF(dl, mx_, my_, 6 * s, col(PK, 0.3), 14);
            DL.CF(dl, mx_, my_, 3.5 * s, col({ 1, 0.85, 0.95 }, 1), 12);
            label('+' .. commas(c.n), 12 * s, mx_ + 6 * s, my_ - 14 * s, { 1, 0.72, 0.88, 1 - q * 0.6 });
        end
    end
    -- your jobs and gil in one rounded pill under the card (over it when low)
    local phh = math.floor(20 * s);
    local py0 = low and (top - 6 * s - phh) or (bot + 6 * s);
    H.gd = H.gd or gil;
    H.gd = H.gd + (gil - H.gd) * math.min(1, (imgui.GetIO().DeltaTime or 0.016) * 5);
    if math.abs(gil - H.gd) < 1 then H.gd = gil; end
    pill(lft + 4 * s, py0, rgt - 4 * s, py0 + phh, mix(0.5), 0.5);
    local pushed = sized('chat', 11.5 * s);
    local th = imgui.GetTextLineHeight();
    local tyy = math.floor(py0 + (phh - th) / 2);
    local gx;
    do                                                               -- (the gil at the right: the coin, the amount rolling, what changed)
        local gs = commas(math.floor(H.gd + 0.5));
        local gw = tonumber((imgui.CalcTextSize(gs))) or 0;
        local diff, ga = C.gil_diff(gil);
        local ds = (diff ~= 0) and ((diff > 0 and '+' or '') .. commas(diff)) or nil;
        local dw = ds and ((tonumber((imgui.CalcTextSize(ds))) or 0) * 0.85 + 8 * s) or 0;
        gx = rgt - 4 * s - phh / 2 - 6 * s - gw - dw;
        DL.CF(dl, gx - 9 * s, tyy + th / 2, 5 * s, U4(0.86, 0.66, 0.24, 1), 14);
        DL.CF(dl, gx - 9 * s, tyy + th / 2, 3 * s, U4(1, 0.88, 0.50, 1), 12);
        outlined(dl, gx, tyy, gs, { GO2[1], GO2[2], GO2[3], 1 });
        if ds then
            local fs = FS;
            imgui.SetWindowFontScale(fs * 0.85);
            outlined(dl, gx + gw + 8 * s, tyy + 1 * s, ds, diff > 0 and { 0.55, 1, 0.65, ga } or { 1, 0.5, 0.65, ga });
            imgui.SetWindowFontScale(fs);
        end
    end
    do                                                               -- (your jobs at the left: the main one's tag in its colour, "75 / SAM 37")
        local x0_ = lft + 4 * s + phh / 2 + 4 * s;
        local tag = JOBS[mj] or '?';
        local jt = ' ' .. lvl;
        local st = (JOBS[sub] and sublvl > 0) and (' / ' .. JOBS[sub] .. ' ' .. sublvl) or '';
        local tgw = tonumber((imgui.CalcTextSize(tag))) or 0;
        local jw = tonumber((imgui.CalcTextSize(jt))) or 0;
        local sw = tonumber((imgui.CalcTextSize(st))) or 0;
        local tc = ALLY.tagcol(mj) or { { 0.9, 0.9, 0.9 } };
        outlined(dl, x0_, tyy, tag, { tc[1][1], tc[1][2], tc[1][3], 1 });
        outlined(dl, x0_ + tgw, tyy, jt, { 0.94, 0.92, 0.96, 1 });
        if x0_ + tgw + jw + sw < gx - 22 * s then outlined(dl, x0_ + tgw + jw, tyy, st, { 0.80, 0.76, 0.86, 1 }); end
    end
    unsized(pushed);
    if low then return bot + 4 * s; end
    return py0 + phh + 4 * s;
end
function YMAP.hub(dl, cx, cy, M)                                     -- the jobs, the points, gil and bag under the map; gives back its bottom
    local s = math.max(0.55, M / 220);
    local info = (cfg.expbar ~= false) and C.expinfo() or nil;
    local y = cy + M / 2 + 6 * s;
    if info then
        local pushed = sized('chat', 14 * s);                        -- the job's tag, then the levels
        local lh = imgui.GetTextLineHeight();
        local tw = tonumber((imgui.CalcTextSize(info.tag))) or 0;
        local rw = tonumber((imgui.CalcTextSize(info.rest))) or 0;
        local px_ = math.floor(5 * s);
        local th = lh + 2;
        local sl = th * 0.30;                                        -- (the party tag's shape: square on the left, its right side slanted)
        local gw = tw + px_ * 2 + sl;
        local W = gw + 7 * s + rw;
        local x0 = math.floor(cx - W / 2);
        local tc, ink = info.col, info.ink;
        ALLY.poly(dl, { { x0, y }, { x0 + gw, y }, { x0 + gw - sl, y + th }, { x0, y + th } }, U4(tc[1], tc[2], tc[3], 1));
        DL.T(dl, x0 + px_, y + 1, U4(ink[1], ink[2], ink[3], 1), info.tag);
        outlined(dl, x0 + gw + 7 * s, y + 1, info.rest, { 0.97, 0.96, 0.98, 1 });
        y = y + lh + 6 * s;
        unsized(pushed);
        local p2 = sized('chat', 12 * s);                            -- the points under it, and the % in pink
        local ps = string.format('   %d%%', math.floor(info.v * 100));
        local lw = tonumber((imgui.CalcTextSize(info.label))) or 0;
        local pw = tonumber((imgui.CalcTextSize(ps))) or 0;
        local lx = math.floor(cx - (lw + pw) / 2);
        outlined(dl, lx, y, info.label, { 0.80, 0.78, 0.86, 1 });
        outlined(dl, lx + lw, y, ps, { 1.00, 0.62, 0.80, 1 });
        y = y + imgui.GetTextLineHeight() + 7 * s;
        unsized(p2);
    end
    -- under it: your gil (and what just changed, under it) and your bag (a thin bar along its bottom)
    local pushed = sized('chat', 13 * s);
    local lh = imgui.GetTextLineHeight();
    local ch, pad, gap = lh + 8 * s, 9 * s, 8 * s;
    local gil = (cfg.gil ~= false) and C.gil_read() or nil;
    local used, max = 0, 0;
    if cfg.bag ~= false then pcall(function() local inv = AshitaCore:GetMemoryManager():GetInventory(); used, max = inv:GetContainerCount(0) or 0, inv:GetContainerCountMax(0) or 0; end); end
    local gs = gil and commas(gil) or nil;
    local bs = (max > 0) and string.format('%d/%d', used, max) or nil;
    local gw = gs and (pad * 2 + 14 * s + (tonumber((imgui.CalcTextSize(gs))) or 0)) or 0;
    local bw = bs and (pad * 2 + 16 * s + (tonumber((imgui.CalcTextSize(bs))) or 0)) or 0;
    local total = gw + bw + ((gs and bs) and gap or 0);
    local x0 = math.floor(cx - total / 2);
    local function chip(x1, w) end                                   -- (no box behind them: just the coin / bag, the text and the bag's bar)
    local bottom = (gs or bs) and (y + ch) or y;
    if gs then
        chip(x0, gw);
        local cr = 5 * s;
        local ccx, ccy = x0 + pad + cr, y + ch / 2;
        DL.CF(dl, ccx, ccy, cr, U4(0.86, 0.66, 0.24, 1), 16);
        DL.CF(dl, ccx, ccy, cr * 0.66, U4(1, 0.88, 0.50, 1), 16);
        outlined(dl, x0 + pad + 14 * s, math.floor(y + (ch - lh) / 2), gs, { GOLD[1], GOLD[2], GOLD[3], 1 });
        local diff, ga = C.gil_diff(gil);
        if diff ~= 0 then
            local fs = FS;
            imgui.SetWindowFontScale(fs * 0.85);
            local ds = (diff > 0 and '+' or '') .. commas(diff);
            local dw = tonumber((imgui.CalcTextSize(ds))) or 0;
            outlined(dl, math.floor(x0 + gw / 2 - dw / 2), y + ch + 2 * s, ds, diff > 0 and { 0.55, 1, 0.65, ga } or { 1, 0.5, 0.65, ga });
            bottom = math.max(bottom, y + ch + 2 * s + imgui.GetTextLineHeight());
            imgui.SetWindowFontScale(fs);
        end
        x0 = x0 + gw + gap;
    end
    if bs then
        chip(x0, bw);
        local full = used >= max - 5;
        local ic = math.floor(9 * s);
        local ix, iy = x0 + pad, math.floor(y + ch / 2 - ic / 2 - 1 * s);
        local vc = full and C.hp or C.mp2;
        DL.R(dl, ix, iy, ix + ic, iy + ic, U4(vc[1], vc[2], vc[3], 1), 2 * s, C.rall, 1.5);
        DL.L(dl, ix + ic * 0.3, iy, ix + ic * 0.3, iy - 2.5 * s, U4(vc[1], vc[2], vc[3], 1), 1.5);
        DL.L(dl, ix + ic * 0.7, iy, ix + ic * 0.7, iy - 2.5 * s, U4(vc[1], vc[2], vc[3], 1), 1.5);
        outlined(dl, x0 + pad + 16 * s, math.floor(y + (ch - lh) / 2 - 1 * s), bs, full and { 1, 0.6, 0.78, 1 } or { 0.92, 0.92, 0.96, 1 });
        local bx0, bx1, by_ = x0 + ch / 2, x0 + bw - ch / 2, math.floor(y + ch - 4 * s);
        local f = math.max(0, math.min(1, used / max));
        DL.RF(dl, bx0, by_, bx1, by_ + 2 * s, U4(1, 1, 1, 0.10), s);
        local a, b = full and C.hp or C.mp, full and C.hp2 or C.mp2;
        if YUI_HEX then                                              -- (Hex link: a thin hex bar - azure, red when nearly full)
            local c1, c2 = C.HEXMP[3], C.HEXMP[2];
            if full then c1, c2 = C.CLAIMCOL.mine[2], C.CLAIMCOL.mine[1]; end
            C.hexbar(dl, bx0, by_, bx1 - bx0, 2 * s, f, f, 0.3, { c1 = c1, c2 = c2, band = 4.5 * s });
            f = 0;
        end
        if f > 0 then
            pcall(function() DL.RFM(dl, bx0, by_, bx0 + (bx1 - bx0) * f, by_ + 2 * s, U4(a[1], a[2], a[3], 1), U4(b[1], b[2], b[3], 1), U4(b[1], b[2], b[3], 1), U4(a[1], a[2], a[3], 1)); end);
        end
    end
    unsized(pushed);
    return bottom;
end
function YMAP.mini(party, ent, zid, me, sc)                          -- the minimap: the map around you, no grid
    local M = math.floor((tonumber(cfg.map_size) or 220) * sc);
    first_place('map_x', 'map_y', 560, -560);
    if not plain_window('YunaUI Map##yui_map', 'map_x', 'map_y') then imgui.End(); imgui.PopStyleVar(2); return; end
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    x, y = math.floor(x + 4), math.floor(y + 4);
    local y0_ = y;
    local style = YMAP.frame_on() and (YUI_HEX and 'visor' or 'capsule') or nil;
                                                                     -- (the map with your EXP, bag, jobs and gil built in: Hex link's
                                                                     --  Visor, Normal mode's Capsule)
    local MW, MH = M, M;
    if style == 'visor' then MW, MH = math.floor(M * 1.35), math.floor(M * 0.8); end   -- (the Visor: a wide map)
    if style == 'capsule' then MW, MH = math.floor(M * 1.25), math.floor(M * 0.9); end   -- (the Capsule: a little wide)
    local s_ = math.max(0.55, M / 220);
    local dockL = style and math.floor(6 * s_) or 0;                 -- (a little room either side for the frame)
    local padR = dockL;
    x = x + dockL;
    local _, SH_ = C.screen();                                       -- (the zone's name above the map - or under it when the map is at the
    local tlow = (tonumber(cfg.map_y) or 0) + M / 2 < SH_ * 0.4;     --  top of the screen; Hex link's dock flips with it)
    local onedge = style and true or false;                          -- (with a frame the zone's name sits on its edge: the top, or the bottom when low)
    local T;
    if onedge and not tlow then T = math.floor(20 * s_);                          -- (a little room: the name sits on the frame's top edge, drawn after it)
    elseif tlow then T = style and math.floor(30 * s_) or 0;
    else T = YMAP.title(dl, x, y, M, sc, MW); end   -- the zone's name, above the map (under it: the dock flips - its plate over the map, the day tab under)
    y = y + T;
    local cx, cy = x + MW / 2, y + MH / 2;
    YMAP.tgap = onedge and YMAP.tgap_of(cx, s_) or nil;
    if YMAP.tgap then YMAP.tgap.low = tlow; end
    if imgui.IsWindowHovered() then                                  -- the mouse wheel zooms in and out (as the Minimap plugin does)
        local wheel = imgui.GetIO().MouseWheel or 0;
        if wheel ~= 0 then
            local z = tonumber(cfg.map_zoom) or 60;
            z = (wheel > 0) and (z / 1.18) or (z * 1.18);
            cfg.map_zoom = math.floor(math.max(16, math.min(256, z)) + 0.5);
            WATCH.later = true;                                      -- (saved a moment later, not every notch)
        end
    end
    local ground = 'none';                                           -- (no frame: just the lines over the game, on a soft fade)
    if ground ~= 'none' then
        DL.RF(dl, x, y, x + M, y + M, U4(0.055, 0.05, 0.078, (ground == 'soft') and 0.38 or 0.92), 8 * sc);   -- (the party cards' violet, a little darker)
    else                                                             -- (no frame: a smooth dark fade under the map, images/map_fade.png -
        local ft = tex('map_fade.png');                              --  darkest in the middle, nothing at the edge, no rim anywhere)
        if ft then                                                   -- (darker over bright ground, lighter over dark: YMAP.lum)
            local k = YMAP.shade(x, y, M);
            while k > 0.01 do                                        -- (above 1: drawn again on top, darker)
                DL.I(dl, ft.ptr, x, y, x + MW, y + MH, 0, 0, 1, 1, U4(1, 1, 1, math.min(1, k)));
                k = k - 1;
            end
        end
    end
    local done3 = false;
    do                                                               -- the minimap is 3D (2D only where a zone has no 3D shape; the wheel's zoom is its distance)
        local m3 = YMAP.d3load(zid);
        if m3 then
            local yaw = (cfg.map3d_follow ~= false) and YMAP.d3facing(ent, me) or 0;
            pcall(YMAP.d3render, dl, m3, ent, party, zid, me, sc, x, y, MW, MH, yaw, 0.95, math.max(16, tonumber(cfg.map_zoom) or 60), ground == 'none');
            done3 = true;
        end
    end
    local e = (not done3) and YMAP.entry or nil;
    if e and YMAP.tex and cfg.map_tilt ~= false then                 -- (MINIMAP > Tilt the map: the 3D look's camera over the flat map)
        local ok_, err_ = pcall(YMAP.tilt2d, dl, ent, party, zid, me, sc, x, y, M, MW, MH);
        if not ok_ then YUI_ERRLOG('maptilt', err_); end
    elseif e and YMAP.tex then
        local R = math.max(8, tonumber(cfg.map_zoom) or 60);           -- map pixels from the middle to the edge
        local k = (MH / 2) / R;
        local Rx = (MW / 2) / k;                                     -- (a wide map: more of it either side)
        local pmx, pmy = YMAP.to_map(ent:GetLocalPositionX(me) or 0, ent:GetLocalPositionY(me) or 0);
        -- the part of the map in view (kept inside the picture, so its edge never repeats)
        local u0, v0, u1, v1 = pmx - Rx, pmy - R, pmx + Rx, pmy + R;
        local a0, b0 = math.max(0, u0), math.max(0, v0);
        local a1, b1 = math.min(512, u1), math.min(512, v1);
        if a1 > a0 and b1 > b0 then
            DL.I(dl, YMAP.tex.ptr, x + (a0 - u0) * k, y + (b0 - v0) * k, x + (a1 - u0) * k, y + (b1 - v0) * k, a0 / 512, b0 / 512, a1 / 512, b1 / 512, U4(1, 1, 1, 1));
            if YMAP.ltex then
                local ix0, iy0, ix1, iy1 = x + (a0 - u0) * k, y + (b0 - v0) * k, x + (a1 - u0) * k, y + (b1 - v0) * k;
                local bk = U4(0, 0, 0, 0.8);                    -- (a black outline first: readable over bright ground)
                for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
                    DL.I(dl, YMAP.ltex.ptr, ix0 + o[1], iy0 + o[2], ix1 + o[1], iy1 + o[2], a0 / 512, b0 / 512, a1 / 512, b1 / 512, bk);
                end
                DL.I(dl, YMAP.ltex.ptr, ix0, iy0, ix1, iy1, a0 / 512, b0 / 512, a1 / 512, b1 / 512, YMAP.lcol());
            end
            if YMAP.ntex then
                DL.I(dl, YMAP.ntex.ptr, x + (a0 - u0) * k, y + (b0 - v0) * k, x + (a1 - u0) * k, y + (b1 - v0) * k, a0 / 512, b0 / 512, a1 / 512, b1 / 512, YMAP.lcol(true));
            end
            if YMAP.mtex then                                        -- (the numbered exit boxes: in their own colours, on top)
                DL.I(dl, YMAP.mtex.ptr, x + (a0 - u0) * k, y + (b0 - v0) * k, x + (a1 - u0) * k, y + (b1 - v0) * k, a0 / 512, b0 / 512, a1 / 512, b1 / 512, U4(1, 1, 1, 1));
            end
        end
        local function tomap(wx, wy) local mx, my = YMAP.to_map(wx, wy); return cx + (mx - pmx) * k, cy + (my - pmy) * k; end
        local function inside(sx, sy) return sx > x + 2 and sx < x + MW - 2 and sy > y + 2 and sy < y + MH - 2; end
        YMAP.marks(dl, ent, party, zid, me, tomap, sc, inside);
    end
    if ground == 'dark' then DL.R(dl, x, y, x + M, y + M, U4(1, 1, 1, 0.10), 8 * sc, C.rall, 1); end
    local pushed = sized('chat', 13 * sc);
    if false then                                                    -- (the name sits over the map, never inside it)
        text(dl, x + 8 * sc, y + 5 * sc, (YMAP.name and YMAP.name ~= '') and YMAP.name or '?', { 0.95, 0.95, 0.97, 0.95 });
    end
    if not done3 and not (e and YMAP.tex) then
        local m_ = 'No map here';
        local mw = imgui.CalcTextSize(m_);
        text(dl, x + (MW - mw) / 2, y + MH / 2 - 8 * sc, m_, { 0.7, 0.7, 0.75, 0.9 });
    end
    unsized(pushed);
    local bottom = y + MH;
    if YMAP.hub_on() then bottom = YMAP.hub(dl, cx, cy, M) or bottom; end   -- (MINIMAP > EXP, gil and bag on the map)
    if style then                                                    -- (Hex link: the map dock)
        local okd, rb = pcall((style == 'capsule') and YMAP.capsule or YMAP.dock, dl, x, y, M, cx, cy, tlow, MW, MH);
        if okd and rb then bottom = math.max(bottom, rb); elseif not okd then YUI_ERRLOG('mapdock', rb); end
        if onedge then                                               -- (the name on the frame's top edge, over the break)
            local fp = ((style == 'capsule') and 6 or 4) * s_;
            if tlow then
                pcall(YMAP.title_edge, dl, cx, cy + MH / 2 + fp, s_, true);
                bottom = math.max(bottom, cy + MH / 2 + fp + 20 * s_);
            else pcall(YMAP.title_edge, dl, cx, cy - MH / 2 - fp, s_); end
        end
    end
    if tlow and not onedge then bottom = bottom + 4 * sc + YMAP.title(dl, x, bottom + 4 * sc, M, sc, MW); end   -- (the zone's name under it all)
    imgui.Dummy({ MW + 8 + dockL + padR, bottom - y0_ + 8 });   -- (the frame's right corner sticks out a little)
    end_plain('map_x', 'map_y');
end
function YMAP.bigmap(party, ent, zid, me, sc)                        -- the big map (/yui map): the whole map with YunaUI's grid,
    local M = math.floor((tonumber(cfg.bigmap_size) or 640) * sc);  --  or the zone in 3D (BARS > MINIMAP > Look) - in the minimap's look
    local kx, ky = 'bigmap_x', 'bigmap_y';
    if YMAP.bygame then                                              -- (opened by the game's Map: as big as the screen, centred, over a dark
        local SW, SH = C.screen();                                   --  cover that hides the game's own map behind it)
        sc = math.max(sc, math.min(SH - 100, SW - 60) / 900);         -- (its letters, name and marks grow with it: the same look at any resolution)
        M = math.floor(math.min(SH - 38 * sc - 60, SW - 60));
        kx, ky = 'gmap_x', 'gmap_y';
        cfg.gmap_x, cfg.gmap_y = math.floor((SW - M - 8) / 2), math.floor((SH - M - 38 * sc - 8) / 2);
        pcall(function()
            local bg = imgui.GetBackgroundDrawList();
            DL.RF(bg, 0, 0, SW, SH, U4(0.02, 0.018, 0.03, 1.0));
        end);
    end
    first_place(kx, ky, -M / 2, -M - 160);
    if not plain_window('YunaUI Big map##yui_bigmap', kx, ky) then imgui.End(); imgui.PopStyleVar(2); return; end
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    x, y = math.floor(x + 4), math.floor(y + 4);
    local top = math.floor(38 * sc);
    local my0 = y + top;
    local soft = true;                                               -- (no frame: the soft fade)
    if soft then                                                     -- (no frame: the same smooth dark fade as the minimap)
        local ft = tex('map_fade.png');
        if ft then
            local g = M * 0.08;
            DL.I(dl, ft.ptr, x - g, my0 - g, x + M + g, my0 + M + g, 0, 0, 1, 1, U4(1, 1, 1, 1));
        end
    else
        local ga = ((cfg.map_ground or 'none') == 'soft') and 0.45 or 0.95;
        DL.RF(dl, x, y, x + M, y + M + top, U4(0.055, 0.05, 0.078, ga), 10 * sc);   -- (the party cards' violet, a little darker)
        if ga > 0.9 then DL.R(dl, x, y, x + M, y + M + top, U4(NEON2[1], NEON2[2], NEON2[3], 0.6), 10 * sc, C.rall, 1.2); end
    end
    local k = M / 512;
    local e = YMAP.entry;
    local m3 = YMAP.d3load(zid);
    if m3 and e then                                                 -- the zone's 3D shapes seen from straight above, the whole map
        local lc = YMAP.linecol();
        if YMAP.ntex then DL.I(dl, YMAP.ntex.ptr, x, my0, x + M, my0 + M, 0, 0, 1, 1, YMAP.lcol(true)); end   -- (the place names)
        local X, Y, Z = ent:GetLocalPositionX(me) or 0, ent:GetLocalPositionY(me) or 0, ent:GetLocalPositionZ(me) or 0;
        if YMAP.d3.hs == nil then YMAP.d3.hs = YMAP.d3height(m3, X, Y, Z); end
        local th = Z * YMAP.d3.hs;
        local kk = math.abs(e.scale) / 2560 * 512;
        local v, ed = m3.v, m3.e;
        local SX, SY, SH = YMAP.d3.sx, YMAP.d3.sy, YMAP.d3.sd;
        for i = 1, #v / 3 do
            local j = i * 3 - 2;
            SX[i] = x + (v[j] * kk - e.ox) * k;
            SY[i] = my0 + (-v[j + 2] * kk - e.oy) * k;
            SH[i] = v[j + 1];
        end
        local cols = {};                                             -- (brightest at your level, fainter above and below)
        for q = 0, 8 do cols[q] = U4(lc[1], lc[2], lc[3], 0.18 + 0.82 * q / 8); end
        local last = (m3.net or (#ed + 1)) - 1;                      -- (open country: no ground net here)
        C.clip(dl, { x, my0 }, { x + M, my0 + M }, true);
        for q = 1, last, 2 do
            local a_, b_ = ed[q], ed[q + 1];
            local dh = math.abs((SH[a_] + SH[b_]) / 2 - th);
            local st = 8 - math.floor(math.min(1, dh / 40) * 7 + 0.5);
            DL.L(dl, SX[a_], SY[a_], SX[b_], SY[b_], cols[st], 1);
        end
        dl:PopClipRect();
        local gc = U4(1, 1, 1, 0.10);
        for i = 0, 15 do                                             -- the grid: every 32 map pixels from the 16th
            local gv = (16 + 32 * i) * k;
            DL.L(dl, x + gv, my0 + 16 * k, x + gv, my0 + M - 16 * k, gc, 1);
            DL.L(dl, x + 16 * k, my0 + gv, x + M - 16 * k, my0 + gv, gc, 1);
        end
        local pushed = sized('chat', 12 * sc);
        for i = 0, 14 do                                             -- its letters and numbers on the borders, in YunaUI's font
            local c = (32 + 32 * i) * k;
            local L_, N_ = string.char(65 + i), tostring(i + 1);
            local lw, lh = imgui.CalcTextSize(L_);
            outlined(dl, x + c - lw / 2, my0 + 8 * k - lh / 2, L_, { 0.86, 0.84, 0.92, 0.85 });
            outlined(dl, x + c - lw / 2, my0 + M - 8 * k - lh / 2, L_, { 0.86, 0.84, 0.92, 0.85 });
            local nw = imgui.CalcTextSize(N_);
            outlined(dl, x + 8 * k - nw / 2, my0 + c - lh / 2, N_, { 0.86, 0.84, 0.92, 0.85 });
            outlined(dl, x + M - 8 * k - nw / 2, my0 + c - lh / 2, N_, { 0.86, 0.84, 0.92, 0.85 });
        end
        unsized(pushed);
        local function tomap(wx, wy) local mx, my = YMAP.to_map(wx, wy); return x + mx * k, my0 + my * k; end
        local function inside(sx, sy) return sx > x and sx < x + M and sy > my0 and sy < my0 + M; end
        YMAP.marks(dl, ent, party, zid, me, tomap, sc, inside);
    elseif e and YMAP.tex then
        DL.I(dl, YMAP.tex.ptr, x, my0, x + M, my0 + M, 0, 0, 1, 1, U4(1, 1, 1, 1));
        if YMAP.ltex then DL.I(dl, YMAP.ltex.ptr, x, my0, x + M, my0 + M, 0, 0, 1, 1, YMAP.lcol()); end
        if YMAP.ntex then DL.I(dl, YMAP.ntex.ptr, x, my0, x + M, my0 + M, 0, 0, 1, 1, YMAP.lcol(true)); end
        if YMAP.mtex then DL.I(dl, YMAP.mtex.ptr, x, my0, x + M, my0 + M, 0, 0, 1, 1, U4(1, 1, 1, 1)); end
        local gc = U4(1, 1, 1, 0.08);
        for i = 0, 15 do                                             -- the grid: every 32 map pixels from the 16th
            local v = (16 + 32 * i) * k;
            DL.L(dl, x + v, my0 + 16 * k, x + v, my0 + M - 16 * k, gc, 1);
            DL.L(dl, x + 16 * k, my0 + v, x + M - 16 * k, my0 + v, gc, 1);
        end
        local pushed = sized('chat', 12 * sc);
        for i = 0, 14 do                                             -- its letters and numbers, in YunaUI's font
            local c = (32 + 32 * i) * k;
            local L_, N_ = string.char(65 + i), tostring(i + 1);
            local lw, lh = imgui.CalcTextSize(L_);
            outlined(dl, x + c - lw / 2, my0 + 8 * k - lh / 2, L_, { 0.86, 0.84, 0.92, 0.8 });
            local nw = imgui.CalcTextSize(N_);
            outlined(dl, x + 8 * k - nw / 2, my0 + c - lh / 2, N_, { 0.86, 0.84, 0.92, 0.8 });
        end
        unsized(pushed);
        local function tomap(wx, wy) local mx, my = YMAP.to_map(wx, wy); return x + mx * k, my0 + my * k; end
        local function inside(sx, sy) return sx > x and sx < x + M and sy > my0 and sy < my0 + M; end
        YMAP.marks(dl, ent, party, zid, me, tomap, sc, inside);
    end
    do                                                               -- the zone's name, as the minimap's Fade: no box, a soft shade, a hairline
        local name = (YMAP.name and YMAP.name ~= '') and YMAP.name or '?';
        local cl_ = YMAP.cell(ent:GetLocalPositionX(me) or 0, ent:GetLocalPositionY(me) or 0);
        if cl_ then name = name .. '   (' .. cl_ .. ')'; end                -- (your square on the grid)
        local pushed = sized('chat', 18 * sc);
        local tw = tonumber((imgui.CalcTextSize(name))) or 0;
        local th = imgui.GetTextLineHeight();
        local mid = x + M / 2;
        local ty = math.floor(y + (top - th) / 2 - 2 * sc);
        local ft = tex('map_fade.png');
        if ft then
            local gw, gh = tw * 0.85 + 34 * sc, th * 1.3;
            DL.I(dl, ft.ptr, mid - gw, ty + th / 2 - gh, mid + gw, ty + th / 2 + gh, 0, 0, 1, 1, U4(1, 1, 1, 1));
        end
        outlined(dl, math.floor(mid - tw / 2), ty, name, { 0.98, 0.97, 1.0, 1 });
        local lc = YMAP.linecol();
        local uw, ly_ = tw / 2 + 30 * sc, ty + th + 4 * sc;
        local c1, c0 = U4(lc[1], lc[2], lc[3], 0.85), U4(lc[1], lc[2], lc[3], 0);
        pcall(function() DL.RFM(dl, mid - uw, ly_, mid, ly_ + 1, c0, c1, c1, c0); end);
        pcall(function() DL.RFM(dl, mid, ly_, mid + uw, ly_ + 1, c1, c0, c0, c1); end);
        unsized(pushed);
    end
    local bx = x + M - 26 * sc;                                      -- X to close it (quiet until the mouse is on it)
    imgui.SetCursorScreenPos({ bx, y + 4 * sc });
    if imgui.InvisibleButton('##yui_bigmap_x', { 22 * sc, 22 * sc }) then YMAP.big = false; end
    local hov = imgui.IsItemHovered();
    local xc, yc, rr = bx + 11 * sc, y + 15 * sc, 5 * sc;
    local xcol = u32(hov and { 1, 1, 1, 1 } or { 0.8, 0.78, 0.9, 0.55 });
    DL.L(dl, xc - rr, yc - rr, xc + rr, yc + rr, xcol, 1.6);
    DL.L(dl, xc - rr, yc + rr, xc + rr, yc - rr, xcol, 1.6);
    imgui.SetCursorScreenPos({ x, y });
    imgui.Dummy({ M + 8, M + top + 8 });
    end_plain(kx, ky);
end
----------------------------------------------------------------------------------------------------
-- The first-time guide (also /yui guide): one card at a time, the screen dimmed except the piece it talks about.
-- Edit Mode stays on underneath, so every piece shows (a pretend target, fight, party, pet...). The last card hands
-- over to Edit Mode to place everything.
----------------------------------------------------------------------------------------------------
EDIT.G = { on = false, i = 1, h = 240 };
function EDIT.G.win(kx)                                              -- a YunaUI window: where it is and how big
    local ky = kx:gsub('_x$', '_y');
    local x, y = tonumber(cfg[kx]), tonumber(cfg[ky]);
    local sz = WATCH.size and WATCH.size[kx];
    if not (x and y and sz and sz[1] and sz[1] > 4 and sz[2] > 4) then return nil; end
    return { x, y, sz[1], sz[2] };
end
function EDIT.G.anc(p)                                               -- a piece of the target bar (its name, fan, burst, cast)
    local d = FIGHT.drawn and FIGHT.drawn[p];
    if d and os.clock() - d[5] < 0.5 then return { d[1], d[2], d[3], d[4] }; end   -- (just drawn: exactly its size)
    if p ~= 'tn' then return nil; end                                -- (not showing: no box)
    local a = FIGHT.anc and FIGHT.anc[p];
    if not a or a[3] < 2 then return nil; end
    local dx, dy = FIGHT.off(p);
    return { a[1] + dx, a[2] + dy, a[3], a[4] };
end
function EDIT.G.eq()                                                 -- your HP / MP / TP bars (equip.lua)
    local ok, r = pcall(function() return YUI_EQ_RECT and YUI_EQ_RECT() or nil; end);
    return ok and r or nil;
end
function EDIT.G.hx() return cfg.target_fx == 'link'; end            -- (Hex link mode: some cards say other things and box other places)
function EDIT.G.recent(r) if type(r) == 'table' and r[5] and os.clock() - r[5] < 0.5 then return { r[1], r[2], r[3], r[4] }; end return nil; end
function EDIT.G.chat(n) return EDIT.G.recent(C.CHATR and C.CHATR[n]); end
function EDIT.G.heads()                                              -- (your bars over your head)
    local H = C.HB;
    if H and H.rect and os.clock() - (H.seen_t or -99) < 0.5 then return H.rect; end
    return nil;
end
function EDIT.G.dps()                                                -- the Damage Meter
    local ok, r = pcall(function()
        local ds = YUI_DPS and YUI_DPS.get and YUI_DPS.get();
        if not ds or ds.visible == false or ds.minimized then return nil; end
        local dr = YUI_DPS.rect and YUI_DPS.rect();                  -- (as drawn: in Hex link its height follows its rows)
        if dr then return dr; end
        local k = math.max(0.5, math.min(2.5, (tonumber(ds.size) or 100) / 100));
        return { tonumber(ds.x) or 0, tonumber(ds.y) or 0, 404 * k, (tonumber(ds.h) or 300) * k };
    end);
    return ok and r or nil;
end
EDIT.G.STEPS = {
    { "Welcome to YunaUI", nil, { "This short guide shows what every piece on your screen does.",
        "Press NEXT to go on, BACK to go back, or SKIP to leave it. You can see it again at any time with /yui guide." } },
    { "Target bar", function(G) if G.hx() then return { G.anc('tb') }; end return { G.win('target_x'), G.anc('tn') }; end, function(G)
        if G.hx() then return { "The monster or player you target: the bar floats over its head and follows it, joined by a line to a diamond. Its name, how far it is (pink means too far for spells) and its HP percent at the end.",
            "With it: its buffs and debuffs, with the time left." }; end
        return { "The monster or player you target: its name, how far it is (pink means too far for spells) and its HP.",
            "With it: its buffs and debuffs, with the time left." }; end, { { 'target', 'TARGET' } } },
    { "Skillchains and Magic Burst", function(G) if G.hx() then return { G.anc('bn') }; end return { G.anc('fo'), G.anc('mb') }; end, function(G)
        if G.hx() then return { "When your party opens a skillchain, a banner comes in at the top of the screen: the chain, the time left as two lines either side of it, and your weapon skills that close it with their result and level - the best one in gold.",
            "When the skillchain lands, Magic Burst shows under it with the elements to burst with." }; end
        return { "When your party opens a skillchain, a fan opens with your weapon skills that close it, the best one on top.",
            "When the skillchain lands, the Magic Burst card shows the chain, the elements to burst with and the time left." }; end, { { 'target', 'TARGET' }, { 'fight_info', 'TARGET (Casts and skillchains)' } } },
    { "Enemy cast", function(G) return { G.anc('co') }; end, {
        "The spell or move the monster is getting ready, with the time left: you know when to interrupt it or get out of the way." }, { { 'target', 'TARGET' }, { 'fight_info', 'TARGET (Casts and skillchains)' } } },
    { "Target of target and enemies", function(G) return { G.hx() and G.anc('tot') or G.win('sub_x'), G.win('enemy_x') }; end, {
        "Who your target is looking at, and the monsters fighting you. Click a monster in the list to target it." }, { { 'subtarget', 'TARGET (Target of target)' }, { 'enemylist', 'TARGET (Enemy list)' } } },
    { "Party", function(G) return { G.win('party_x') }; end, {
        "Each member: the job tag in its role colour (tank, healer, damage, support), the name, HP, MP and TP.",
        "The job tags are animated: click one to hide or show that member's buffs. A member under 30% HP trembles and beats red.",
        "Double click a member to turn it over and see its exact HP and MP. Double click again to turn it back.",
        "The arrow next to the anchor icon, by PARTY, hides or shows the whole list." }, { { 'party', 'PARTY' } } },
    { "Alliance", function(G) return { G.win('alliance_x'), G.win('ally2_x') }; end, {
        "The other two parties of your alliance, smaller, so a full alliance doesn't fill your screen." }, { { 'alliance', 'PARTY (Alliance)' } } },
    { "Your HP, MP and TP", function(G) if C.head_bars_on() then return { G.heads(), (cfg.head_bars == 'both') and G.eq() or nil }; end return { G.eq() }; end, function(G)
        if C.head_bars_on() then return { "Your own bars, over your head: HP, MP, and your TP as a slim bar under them - it turns gold when a weapon skill is ready.",
            "Listen: a sound plays as your TP reaches 1000, 2000 and 3000, each one stronger, so you know without looking.",
            "Their size and height, and the TP sound (on / off, volume), are in BARS > YOUR BARS." }; end
        return { "Your own bars. Anchor them together or place each one apart. Their size, length and thickness are in BARS." }; end },
    { "Cast bar, EXP, gil and bag", function(G) return { G.win('cast_x'), G.win('exp_x'), G.win('gil_x'), G.win('bag_x') }; end, function(G)
        if YMAP.dock_on and YMAP.dock_on() then return { "The minimap: the map around you - you, your party and monsters - with the zone, your spot on its grid (as <pos> gives it) and Vana'diel's day, time and weather. The mouse wheel over it zooms.",
            YUI_HEX and "Your EXP (merits at level 75), gil and bag are built into it: EXP along its top edge, the bag along its bottom, your jobs and gil in the tags under it. Over it all, your casting time." or
            "Your EXP (merits at level 75), gil and bag are built into it: EXP along its foot, the bag at its top right, your jobs and gil under it. Over it all, your casting time." }; end   -- (the minimap on: about it, EXP, gil and bag built in)
        return { "Your casting time, your experience to the next level, your gil (and what you made since you logged in) and how full your bag is." }; end, { { 'castbar', 'BARS (Cast bar)' }, { 'expbar', 'BARS (EXP bar)' }, { 'gil', 'BARS (Gil)' }, { 'bag', 'BARS (Bag)' } },
        title = function() return (YMAP.dock_on and YMAP.dock_on()) and 'Cast bar and minimap' or nil; end },
    { "Pet", function(G) return { G.win('pet_x') }; end, {
        "Your avatar, wyvern, automaton or beast: its HP, MP, TP, its ability timers and what it is fighting. It shows only when you have a pet." }, { { 'petbar', 'BARS (Pet)' } } },
    { "Timers", function(G) return { G.win('timer_x') }; end, {
        "Your abilities and spells that are not ready yet, with the time left." }, { { 'timers', 'TIMERS' } } },
    { "Gear", function(G) return { G.win('strip_x') or G.win('_sx') }; end, {
        "Your 16 equipped items in HD. They light up when you change gear; put the mouse over them to see them at any time." }, { { 'strip_show', 'EQUIP (Gear strip)' } } },
    { "Damage Meter", function(G) return { G.dps() }; end, {
        "The damage of you and your party, with an enmity view. Click a name for the details; right click to post the top 5 in party or linkshell chat.",
        "/dps shows or hides it." }, { { 'dps', 'DAMAGE METER (Show it)' } } },
    { "Chat", function(G) return { G.chat(1), cfg.chat_split and G.chat(2) or nil }; end, {
        "Channel tabs (Say, Party, Tell...), timestamps, and a combat log of its own if you want one.",
        "Put the mouse over it to see the older lines, and scroll to read your history." }, { { 'chat', 'CHAT' } } },
    { "Settings", nil, {
        "Type /yui to open the settings: every piece has its own size, look and on / off switch.",
        "In GENERAL > MY LAYOUTS you can keep five layouts of your own, with their places and sizes." } },
    { "Make it yours", nil, {
        "Now place everything where you like: drag any piece, it snaps to the grid and lines up with the others. Press DONE when you are happy.",
        "Later: /yui edit to move things again, /yui guide to see this guide again." } },
};
function EDIT.G.start()
    local G = EDIT.G;
    G.on, G.i, G.edit0 = true, 1, EDIT.on;
    if not cfg.g_backup then                                         -- (your layout, kept: the slides borrow the pieces)
        local t = LAYOUT.capture();
        t.o.strip_x, t.o.strip_y = tonumber(cfg.strip_x), tonumber(cfg.strip_y);   -- (the gear strip too)
        cfg.g_backup = t;
        pcall(save);
    end
    C.GST, G.slide = {}, nil;
    if G.show0 == nil then G.show0 = FIGHT.show; end
    EDIT.on, ui.open, FIGHT.show = true, false, true;                -- (Edit Mode underneath: every piece shows; a pretend fight on your target)
    pcall(function()                                                 -- (the Damage Meter on, with a pretend fight, while the guide shows)
        local ds = YUI_DPS.get();
        if G.dps0 == nil then G.dps0 = { ds.visible ~= false, ds.minimized == true }; cfg.g_dps0 = G.dps0; end   -- (kept: a reload mid-guide puts it back)
        YUI_DPS.set_visible(true); YUI_DPS.set_minimized(false); YUI_DPS.demo(true);
    end);
end
function EDIT.G.unstage()                                            -- (every piece back where you had it)
    YUI_PRES, C.GST, FIGHT.psy, EDIT.G.slide, YUI_FAKE_TP = nil, nil, nil, nil, nil;
    local t = cfg.g_backup;
    if type(t) ~= 'table' then return; end
    cfg.g_backup = nil;
    local o, eq = {}, {};
    for k, v in pairs(t.o or {}) do o[k] = v; end
    for k, v in pairs(t.eq or {}) do eq[k] = v; end
    pcall(LAYOUT.apply, o, eq, (type(t.dps) == 'table' and t.dps[1]) and t.dps or nil);
end
function EDIT.G.stop(place)
    local G = EDIT.G;
    G.on = false;
    pcall(G.unstage);
    G.finale = place and true or nil;                                -- (finished it: the send-off comes when Edit Mode is DONE)
    if G.show0 ~= nil then FIGHT.show, G.show0 = G.show0, nil; end
    pcall(function()                                                 -- (the Damage Meter back as it was)
        YUI_DPS.demo(false);
        if G.dps0 then YUI_DPS.set_visible(G.dps0[1]); YUI_DPS.set_minimized(G.dps0[2]); G.dps0 = nil; end
        cfg.g_dps0 = nil;
    end);
    if not place and not EDIT.welcome and not G.edit0 then EDIT.on, EDIT.drag, EDIT.guides = false, nil, {}; end
    pcall(save);
end
-- The send-off: after the guide, when you press DONE in Edit Mode, a big line fills the screen for a few seconds
EDIT.G.TITLE, EDIT.G.SUB = "YUNA UI", "Built for me. Shared with you.";
function EDIT.G.splash()
    local G = EDIT.G;
    if not G.splash_t then return; end
    local t = os.clock() - G.splash_t;
    local T = 4.6;
    if t > T then G.splash_t = nil; return; end
    local fg = nil;
    pcall(function() fg = imgui.GetForegroundDrawList(); end);
    if fg == nil then G.splash_t = nil; return; end
    local ds = imgui.GetIO().DisplaySize;
    local W, H = (ds and ds.x) or 1920, (ds and ds.y) or 1080;
    local k = math.max(0.8, math.min(2.0, H / 1080));
    local a = math.min(1, t / 0.5) * math.min(1, (T - t) / 0.9);    -- in quickly, out slowly
    local e = 1 - (1 - math.min(1, t / 0.7)) ^ 3;                    -- (eases in: the letters spread out as it lands)
    imgui.SetNextWindowPos({ 0, 0 }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ 1, 1 }, ImGuiCond_Always);
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0, 0, 0, 0 });
    if imgui.Begin('YunaUI Send-off##yui_sendoff', { true }, bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoMove,
            ImGuiWindowFlags_NoInputs, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoFocusOnAppearing)) then
        pcall(function()                                             -- a dark band across the middle, soft at its top and bottom
            local cy, bh = H * 0.5, 170 * k;
            local c0, c1 = U4(0, 0, 0, 0), U4(0.01, 0.01, 0.02, 0.72 * a);
            DL.RFM(fg, 0, cy - bh, W, cy, c0, c0, c1, c1);
            DL.RFM(fg, 0, cy, W, cy + bh, c1, c1, c0, c0);
        end);
        local shx = YUI_HEX;                                         -- (Hex link: gold to azure instead of pink to violet)
        local s1, s2 = shx and C.GOLDH or C.hp, shx and C.HEXMP[1] or C.mp2;
        local f1 = sized('chat', 64 * k);                            -- the big line: letters spreading, pink to violet, a glow behind
        local sp = (4 + 10 * e) * k;
        local tw = spaced_w(G.TITLE, sp);
        local _, th = imgui.CalcTextSize(G.TITLE);
        local tx, ty = (W - tw) / 2, H * 0.5 - th - 10 * k;
        local cx = tx;
        for i = 1, #G.TITLE do
            local ch = G.TITLE:sub(i, i);
            local u = 0.5 + 0.5 * math.sin(os.clock() * 1.6 - i * 0.35);
            local c = { s1[1] + (s2[1] - s1[1]) * u, s1[2] + (s2[2] - s1[2]) * u, s1[3] + (s2[3] - s1[3]) * u };
            for _, o in ipairs({ { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } }) do
                DL.T(fg, cx + o[1] * k, ty + o[2] * k, U4(c[1], c[2], c[3], 0.18 * a), ch);
            end
            DL.T(fg, cx + 2, ty + 3, U4(0, 0, 0, 0.7 * a), ch);
            DL.T(fg, cx, ty, u32(shx and { 1, 0.97, 0.90, a } or { 1, 0.97, 1, a }), ch);
            cx = cx + imgui.CalcTextSize(ch) + sp;
        end
        unsized(f1);
        pcall(function()                                             -- a glowing line opening out from the middle
            local lw = tw * 0.5 * e;
            local ly = H * 0.5 + 2 * k;
            DL.RFM(fg, W / 2 - lw, ly, W / 2, ly + 2 * k, U4(s1[1], s1[2], s1[3], 0), U4(1, 1, 1, a), U4(1, 1, 1, a), U4(s1[1], s1[2], s1[3], 0));
            DL.RFM(fg, W / 2, ly, W / 2 + lw, ly + 2 * k, U4(1, 1, 1, a), U4(s2[1], s2[2], s2[3], 0), U4(s2[1], s2[2], s2[3], 0), U4(1, 1, 1, a));
            if shx and e > 0.05 then                                 -- (Hex link: a gold and an azure hexagon riding out with the line, one in the middle)
                C.hexdot(fg, W / 2 - lw * 0.92, ly + 1 * k, 4.5 * k, U4(s1[1], s1[2], s1[3], a * 0.9));
                C.hexdot(fg, W / 2 + lw * 0.92, ly + 1 * k, 4.5 * k, U4(s2[1], s2[2], s2[3], a * 0.9));
                C.hexdot(fg, W / 2, ly + 1 * k, 6 * k, U4(0, 0, 0, a * 0.7));
                C.hexdot(fg, W / 2, ly + 1 * k, 4.5 * k, U4(C.GOLDH2[1], C.GOLDH2[2], C.GOLDH2[3], a));
            end
        end);
        local f2 = sized('chat', 22 * k);                            -- the words under it, a moment later
        local a2 = a * math.max(0, math.min(1, (t - 0.45) / 0.5));
        local sw = spaced_w(G.SUB, 2 * k);
        spaced(fg, (W - sw) / 2 + 1, H * 0.5 + 22 * k + 2, G.SUB, U4(0, 0, 0, 0.7 * a2), 2 * k);
        spaced(fg, (W - sw) / 2, H * 0.5 + 22 * k, G.SUB, u32(shx and { 0.95, 0.88, 0.70, a2 } or { 0.90, 0.88, 0.96, a2 }), 2 * k);
        unsized(f2);
    end
    imgui.End();
    imgui.PopStyleColor(1);
end
function EDIT.G.lines(s, maxw)                                       -- a paragraph cut into lines that fit
    local out, cur = {}, '';
    for word in s:gmatch('%S+') do
        local try = (cur == '') and word or (cur .. ' ' .. word);
        if cur ~= '' and imgui.CalcTextSize(try) > maxw then out[#out + 1] = cur; cur = word; else cur = try; end
    end
    if cur ~= '' then out[#out + 1] = cur; end
    return out;
end
-- The guide is a presentation: the screen dims, and each slide borrows the piece it's about - drawn live, with a
-- pretend target, fight and party - into a picture in the middle of a card, the words under it. Nothing else shows;
-- your own layout is kept (cfg.g_backup) and put back when the guide ends, even after a reload.
-- What each slide shows (by its title): the pieces, each { rect, where it's anchored, move it, what draws it }
function EDIT.G.show(title)
    local hx = cfg.target_fx == 'link';
    if title == 'Target bar' or title == 'Enemy cast' then return { 'tgt' }; end
    if title == 'Skillchains and Magic Burst' then return hx and { 'bn' } or { 'tgt3' }; end
    if title == 'Target of target and enemies' then return { 'tgt2', 'enemy' }; end
    if title == 'Party' then return { 'party' }; end
    if title == 'Alliance' then return { 'ally1', 'ally2' }; end
    if title == 'Your HP, MP and TP' then return C.head_bars_on() and { 'heads' } or { 'eq' }; end
    if title == 'Cast bar, EXP, gil and bag' then return (YMAP.dock_on and YMAP.dock_on()) and { 'cast', 'map' } or { 'cast', 'exp', 'gil', 'bag' }; end
    if title == 'Pet' then return { 'pet' }; end
    if title == 'Timers' then return { 'timers' }; end
    if title == 'Gear' then return { 'strip' }; end
    if title == 'Damage Meter' then return { 'dps' }; end
    if title == 'Chat' then return { 'chat' }; end
    return {};
end
function EDIT.G.flags(title)                                         -- (what each slide leaves out)
    local hx = cfg.target_fx == 'link';
    if title == 'Target bar' or title == 'Target of target and enemies' then return { nocast = true, nobn = true }; end
    if title == 'Skillchains and Magic Burst' then return hx and { bnself = true } or { nocast = true }; end
    if title == 'Enemy cast' then return { nobn = true }; end
    if title == 'Party' then return { noally = true }; end
    if title == 'Alliance' then return { noparty = true }; end
    return {};
end
function EDIT.G.item(id)
    local G = EDIT.G;
    local function win(kx, gate)
        local ky = kx:gsub('_x$', '_y');
        return { gate = { gate }, rect = function() return G.win(kx); end,
            get = function() return tonumber(cfg[kx]) or 0, tonumber(cfg[ky]) or 0; end,
            set = function(x, y) cfg[kx], cfg[ky] = math.floor(x), math.floor(y); WATCH.move = math.max(WATCH.move, 2); end };
    end
    local function union(list)
        local r = nil;
        for _, q in pairs(list) do
            if type(q) == 'table' then
                if r == nil then r = { q[1], q[2], q[1] + q[3], q[2] + q[4] };
                else r = { math.min(r[1], q[1]), math.min(r[2], q[2]), math.max(r[3], q[1] + q[3]), math.max(r[4], q[2] + q[4]) }; end
            end
        end
        return r and { r[1], r[2], r[3] - r[1], r[4] - r[2] } or nil;
    end
    if id == 'tgt' or id == 'tgt2' or id == 'tgt3' then             -- (tgt2: with its target of target; tgt3: with its fan and Magic Burst)
        local tot, sc3 = id == 'tgt2', id == 'tgt3';
        local gate = tot and { 'tgt', 'sub' } or { 'tgt' };
        if cfg.target_fx == 'link' then
            return { gate = gate, rect = function() return union({ G.anc('tb'), tot and G.anc('tot') or nil }); end,
                get = function() local t = C.GST and C.GST.t; if t then return t[1], t[2]; end return tonumber(cfg.target_x) or 0, tonumber(cfg.target_y) or 0; end,
                set = function(x, y) C.GST = C.GST or {}; C.GST.t = { math.floor(x), math.floor(y) }; end };
        end
        local it = win('target_x', 'tgt');
        it.gate = gate;
        it.rect = function() return union({ G.win('target_x'), sc3 and G.anc('fo') or nil, sc3 and G.anc('mb') or nil, tot and G.win('sub_x') or nil }); end;   -- (only what this slide shows)
        return it;
    end
    if id == 'bn' then
        return { gate = {}, rect = function() return G.anc('bn'); end,
            get = function() return 0, FIGHT.psy or 0; end, set = function(_, y) FIGHT.psy = math.floor(y); end, fixed_x = true };
    end
    if id == 'heads' then
        return { gate = { 'heads' }, rect = function() return G.heads(); end,
            get = function() local h = C.GST and C.GST.hb; if h then return h[1], h[2]; end return (C.HB and C.HB.x) or 0, (C.HB and C.HB.y) or 0; end,
            set = function(x, y) C.GST = C.GST or {}; C.GST.hb = { math.floor(x), math.floor(y) }; end };
    end
    if id == 'eq' then
        return { gate = { 'eq' }, rect = function() return G.eq(); end,
            get = function() local e = YUI_EQ_GET and YUI_EQ_GET() or {}; return tonumber(e.hpbar_x) or 0, tonumber(e.hpbar_y) or 0; end,
            set = function(x, y)
                local e = YUI_EQ_GET and YUI_EQ_GET();
                if not e or not YUI_EQ_APPLY then return; end
                local dx, dy = x - (tonumber(e.hpbar_x) or 0), y - (tonumber(e.hpbar_y) or 0);   -- (all three bars moved together)
                local t = {};
                for _, b in ipairs({ 'hpbar', 'mpbar', 'tpbar' }) do
                    t[b .. '_x'], t[b .. '_y'] = math.floor((tonumber(e[b .. '_x']) or 0) + dx), math.floor((tonumber(e[b .. '_y']) or 0) + dy);
                end
                YUI_EQ_APPLY(t);
            end };
    end
    if id == 'dps' then
        return { gate = { 'dps' }, rect = function() return G.dps(); end,
            get = function() local d = YUI_DPS and YUI_DPS.get and YUI_DPS.get(); return tonumber(d and d.x) or 0, tonumber(d and d.y) or 0; end,
            set = function(x, y) if YUI_DPS and YUI_DPS.place then YUI_DPS.place(x, y); end end };
    end
    if id == 'chat' then
        local it = win('chat_x', 'chat');
        it.rect = function()                                         -- (the combat log anchored beside / on it: both in the picture)
            if cfg.chat_split and cfg.chat_link then return union({ G.chat(1), G.chat(2) }); end
            return G.chat(1);
        end;
        return it;
    end
    local W_ = { party = { 'party_x', 'party' }, ally1 = { 'alliance_x', 'party' }, ally2 = { 'ally2_x', 'party' }, enemy = { 'enemy_x', 'enemy' },
                 cast = { 'cast_x', 'cast' }, exp = { 'exp_x', 'exp' }, gil = { 'gil_x', 'gil' }, bag = { 'bag_x', 'bag' }, pet = { 'pet_x', 'pet' },
                 timers = { 'timer_x', 'timers' }, strip = { 'strip_x', 'strip' }, map = { 'map_x', 'map' } };
    local w = W_[id];
    return w and win(w[1], w[2]) or nil;
end
-- The slide's pieces laid out in rows (a new row when one gets too wide), each moved until it sits in its place
-- (pieces that draw beside their anchor are measured and nudged; a few tries at most). Gives back the picture's size.
function EDIT.G.stage(x0, y0, maxw, k)
    local G = EDIT.G;
    local S = G.slide;
    local gap = math.floor(30 * k);
    local rows, cur, cw, chh = {}, {}, 0, 0;
    for _, it in ipairs(S.items) do
        local r = it.rect();
        it.w, it.h = (r and r[3]) or 220 * k, (r and r[4]) or 70 * k;
        it.r = r;
        if #cur > 0 and cw + gap + it.w > maxw then rows[#rows + 1] = { cur, cw, chh }; cur, cw, chh = {}, 0, 0; end
        cw = cw + ((#cur > 0) and gap or 0) + it.w;
        chh = math.max(chh, it.h);
        cur[#cur + 1] = it;
    end
    if #cur > 0 then rows[#rows + 1] = { cur, cw, chh }; end
    local pw, ph = 0, 0;
    for ri, row in ipairs(rows) do pw = math.max(pw, row[2]); ph = ph + row[3] + ((ri > 1) and gap or 0); end
    local y = y0;
    local any = false;
    for _, row in ipairs(rows) do
        local x = x0 + (maxw - row[2]) / 2;
        for _, it in ipairs(row[1]) do
            local wx, wy = x, y + (row[3] - it.h) / 2;
            if it.r then any = true; end
            it.tries = it.tries or 0;
            local sig = math.floor(it.w / 3) .. 'x' .. math.floor(it.h / 3);   -- (its size changed - a piece came or went: it may move again)
            if sig ~= it.sig then it.sig, it.tries = sig, 0; end
            local dx, dy = wx - (it.r and it.r[1] or wx), wy - (it.r and it.r[2] or wy);
            if it.fixed_x then dx = 0; end
            if (not it.r and it.tries == 0) or ((math.abs(dx) > 1.5 or math.abs(dy) > 1.5) and it.tries < 12) then
                local ax, ay = it.get();
                if it.r then it.set(ax + dx, ay + dy); else it.set(wx, wy); end
                it.tries = it.tries + 1;
            end
            x = x + it.w + gap;
        end
        y = y + row[3] + gap;
    end
    return pw, ph, any;
end
-- Under the slide's pieces (drawn first each frame): the screen dimmed and the card, from the last frame's place
function EDIT.G.dim()
    local G = EDIT.G;
    if not G.on then return; end
    local bg = nil;
    pcall(function() bg = imgui.GetBackgroundDrawList(); end);
    if bg == nil then return; end
    local W, H = C.screen();
    DL.RF(bg, 0, 0, W, H, U4(0.01, 0.01, 0.02, 0.80));
    local g = G.geo;
    if not g then return; end
    local hx = YUI_HEX;
    local edge = hx and C.GOLDH or NEON2;
    local rr = hx and 0 or 14 * g.k;
    DL.RF(bg, g.x, g.y, g.x + g.w, g.y + g.h, U4(0.045, 0.042, 0.065, 0.97), rr);
    if g.ph > 0 then                                                 -- (the picture: a little darker, its own fine edge)
        local pr = hx and 0 or 10 * g.k;
        DL.RF(bg, g.px, g.py, g.px + g.pw, g.py + g.ph, U4(0.015, 0.015, 0.03, 0.9), pr);
        DL.R(bg, g.px, g.py, g.px + g.pw, g.py + g.ph, U4(edge[1], edge[2], edge[3], 0.22), pr, C.rall, 1);
    end
    DL.R(bg, g.x, g.y, g.x + g.w, g.y + g.h, U4(edge[1], edge[2], edge[3], 0.75), rr, C.rall, 1.4);
end
function EDIT.G.draw()
    local G = EDIT.G;
    if not G.on then YUI_PRES = nil; return; end
    local fg = nil;
    pcall(function() fg = imgui.GetForegroundDrawList(); end);
    if fg == nil then G.stop(true); return; end
    local W, H = C.screen();
    local k = math.max(0.8, math.min(1.8, H / 1080));
    local hx = YUI_HEX;
    local edge, edge2 = hx and C.GOLDH or NEON2, hx and C.HEXMP[1] or C.mp2;
    G.i = math.max(1, math.min(#G.STEPS, G.i));
    local st = G.STEPS[G.i];
    local key = G.i .. (hx and 'h' or 'n');
    if not G.slide or G.slide.key ~= key then                        -- (a new slide: its pieces, what may draw)
        local items = {};
        local pres = { all = true };
        for _, id in ipairs(G.show(st[1])) do
            local it = G.item(id);
            if it then items[#items + 1] = it; for _, gk in ipairs(it.gate) do pres[gk] = true; end end
        end
        G.slide = { key = key, items = items, t0 = os.clock() };
        YUI_PRES = pres;
        C.GST, FIGHT.psy = G.flags(st[1]), nil;
        YUI_FAKE_TP = nil;
    end
    if st[1] == 'Your HP, MP and TP' then                            -- (a pretend TP filling up, with the TP sound at each 1000)
        local e = (os.clock() - G.slide.t0) % 8;
        local tpv = math.min(3000, math.floor(e / 6 * 3000));
        YUI_FAKE_TP = tpv;
        local tier = math.floor(tpv / 1000);
        if tier > (G.slide.tier or 0) and cfg.tp_sound ~= false and YUI_HEX then pcall(C.snd_play, 'tp' .. tier); end   -- (the sound: Hex link mode only)
        G.slide.tier = tier;
    end
    local pad = math.floor(22 * k);
    local CW = math.floor(math.min(W - 40, math.max(600 * k, (G.pw or 0) + pad * 2)));
    local CH = G.h or math.floor(240 * k);
    local cx, cy = math.floor((W - CW) / 2), math.floor(math.max(16, (H - CH) / 2));
    local pw, ph, any = 0, 0, false;
    if #G.slide.items > 0 then
        local okp, a1, a2, a3 = pcall(G.stage, cx + pad + 12 * k, cy + pad + 14 * k, CW - pad * 2 - 24 * k, k);
        if okp then pw, ph, any = a1, a2, a3; end
    end
    G.pw = pw + 24 * k;
    local base = st[3];
    if type(base) == 'function' then local okw, w_ = pcall(base, G); base = (okw and type(w_) == 'table') and w_ or {}; end   -- (words per mode)
    local words = base;
    if #G.slide.items > 0 and not any and st[4] and os.clock() - G.slide.t0 > 0.4 then   -- (nothing to show: turned off? say where to turn it on)
        for _, o in ipairs(st[4]) do
            local off = false;
            if o[1] == 'dps' then
                pcall(function() local d = YUI_DPS and YUI_DPS.get and YUI_DPS.get(); off = d and d.visible == false; end);
            else off = cfg[o[1]] == false; end
            if off then
                words = {};
                for _, w0 in ipairs(base) do words[#words + 1] = w0; end
                words[#words + 1] = 'It is turned off right now: turn it on in /yui > ' .. o[2] .. '.';
                break;
            end
        end
    end
    imgui.SetNextWindowPos({ cx, cy }, ImGuiCond_Always);            -- (an invisible window over the card: it takes the clicks)
    imgui.SetNextWindowSize({ CW, CH }, ImGuiCond_Always);
    pcall(imgui.SetNextWindowFocus);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0, 0, 0, 0 });
    if imgui.Begin('YunaUI Guide##yui_guide', { true }, bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoMove,
            ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoBackground)) then
        if C.GST and C.GST.bnself and cfg.fight_info ~= false then    -- (Hex link's banner alone: its pretend chain - drawn inside this window,
            pcall(FIGHT.preview);                                    --  or ImGui opens a "Debug" one for its text)
            pcall(FIGHT.ps_draw, -1, 1);
        end
        local y = cy + pad;
        local picy, pich = y, 0;
        if ph > 0 then pich = ph + 28 * k; y = y + pich + 18 * k; end
        local f1 = sized('chat', 13 * k);                            -- the step, top right of the words
        local stp = string.format('%d / %d', G.i, #G.STEPS);
        local sw = imgui.CalcTextSize(stp);
        DL.T(fg, cx + CW - pad - sw, y + 4 * k, U4(0.62, 0.60, 0.70, 1), stp);
        unsized(f1);
        local f2 = sized('chat', 24 * k);                            -- the title
        local ttl = (st.title and st.title()) or st[1];             -- (a title that changes with your settings)
        local _, th = imgui.CalcTextSize(ttl);
        DL.T(fg, cx + pad, y, U4(1, 1, 1, 1), ttl);
        unsized(f2);
        y = y + th + 6 * k;
        pcall(function()                                             -- a short line under it, in the mode's colours
            DL.RFM(fg, cx + pad, y, cx + pad + 70 * k, y + 2, u32(edge), u32(edge2), u32(edge2), u32(edge));
        end);
        y = y + 14 * k;
        local f3 = sized('chat', 15.5 * k);                          -- the words
        local lh = imgui.GetTextLineHeight() + 3 * k;
        for pi, para in ipairs(words) do
            if pi > 1 then y = y + lh * 0.45; end
            for _, ln in ipairs(G.lines(para, CW - pad * 2)) do
                DL.T(fg, cx + pad, y, U4(0.88, 0.87, 0.93, 1), ln);
                y = y + lh;
            end
        end
        unsized(f3);
        y = y + 16 * k;
        local f4 = sized('chat', 14 * k);                            -- the buttons: SKIP on the left; BACK and NEXT on the right
        local bh = math.floor(34 * k);
        local last = G.i == #G.STEPS;
        local mx, my = imgui.GetMousePos();
        local function button(id, label, bx, bw, main)
            imgui.SetCursorScreenPos({ bx, y });
            local hit = imgui.InvisibleButton('##yui_g_' .. id, { bw, bh });
            local hov = mx >= bx and mx < bx + bw and my >= y and my < y + bh;
            local br = hx and 0 or bh * 0.45;
            DL.RF(fg, bx, y, bx + bw, y + bh, u32(hov and { 0.17, 0.15, 0.22, 1 } or { 0.10, 0.09, 0.13, 1 }), br);
            local ec = main and { edge[1], edge[2], edge[3], hov and 1 or 0.85 } or { 1, 1, 1, hov and 0.30 or 0.16 };
            DL.R(fg, bx, y, bx + bw, y + bh, u32(ec), br, C.rall, main and 1.6 or 1);
            local lw, lh2 = imgui.CalcTextSize(label);
            DL.T(fg, bx + (bw - lw) / 2, y + (bh - lh2) / 2, U4(0.95, 0.93, 1, 1), label);
            return hit;
        end
        local nw = math.floor((last and 190 or 100) * k);
        local bw2 = math.floor(90 * k);
        local nx = cx + CW - pad - nw;
        if button('next', last and 'PLACE EVERYTHING' or 'NEXT', nx, nw, true) then
            if last then G.stop(true); else G.i = G.i + 1; end
        end
        if G.on and G.i > 1 and button('back', 'BACK', nx - 10 * k - bw2, bw2, false) then G.i = G.i - 1; end
        if G.on and not last and button('skip', 'SKIP', cx + pad, bw2, false) then G.stop(false); end
        unsized(f4);
        y = y + bh + pad;
        G.h = math.floor(y - cy);                                    -- (the card's height, for the next frame)
        G.geo = { x = cx, y = cy, w = CW, h = G.h, k = k, px = cx + pad, py = picy, pw = CW - pad * 2, ph = pich };
    end
    imgui.End();
    imgui.PopStyleColor(1);
    imgui.PopStyleVar(2);
end
----------------------------------------------------------------------------------------------------
-- The mode chooser (once after this update, on the first launch, or /yui mode): a card at the bottom of the screen with
-- a NORMAL | HEX LINK switch. A pretend target, fight, cast and target of target show live, so flipping the switch shows
-- each mode on your own screen; NEXT walks through the pieces. The last card asks: Hex link or Normal?
----------------------------------------------------------------------------------------------------
C.MD = { on = false, i = 1, h = 260 };
C.MD.STEPS = {                                                       -- (one page: see both live, then pick)
    { 'Pick your style', { "YunaUI comes in two styles. Flip the switch above to see each one live on your screen: a pretend target and fight are showing.",
        'Then pick the one you like. You can change it any time at the top of /yui.' },
      { 'Normal: the target bar where you place it, a fan of weapon skills, the Magic Burst card.', 'Hex link: the target bar over the target, a line to it, hexagon bars, a skillchain banner at the top.' } },
};
function C.MD.start(then_guide)
    local M = C.MD;
    if M.on then return; end
    M.on, M.i, M.then_guide = true, 1, then_guide;
    M.fx0, M.hb0, M.show0 = cfg.target_fx, cfg.head_bars, FIGHT.show;
    M.link = cfg.target_fx == 'link';
    M.base = {};                                                     -- (your sizes now: the mode you're in keeps them)
    for _, k in ipairs(C.MODEKEYS) do M.base[k] = cfg[k]; end
    C.modesave(M.link);
    FIGHT.show = true;                                               -- (a pretend fight, cast and target of target on your target - or a pretend one)
    if not cfg.md_backup then                                        -- (your layout, kept - saved too, so a crash mid-demo can't lose it)
        local t = LAYOUT.capture();
        for _, p_ in ipairs({ 'tn', 'mb', 'fo', 'co' }) do t.o[p_ .. '_dx'], t.o[p_ .. '_dy'] = tonumber(cfg[p_ .. '_dx']), tonumber(cfg[p_ .. '_dy']); end
        t.fan_place, t.ecast_place = cfg.fan_place, cfg.ecast_place;
        t.fx0, t.hb0, t.base = cfg.target_fx, cfg.head_bars, M.base;   -- (your mode and sizes too: a reload mid-demo puts them back)
        cfg.md_backup = t;
    end
    cfg.fan_place, cfg.ecast_place = 'bar', 'bar';                   -- (the fan and the cast by the bar, where they belong)
    M.lay = true;                                                    -- (the Classic layout, on the next frame)
    M.apply();
end
function C.MD.restore()                                              -- (your own layout back, as it was before the demo)
    local t = cfg.md_backup;
    if type(t) ~= 'table' then return; end
    cfg.md_backup = nil;
    if type(t.base) == 'table' then for k, v in pairs(t.base) do cfg[k] = v; end end
    if t.fx0 ~= nil then cfg.target_fx = t.fx0; end
    if t.hb0 ~= nil then cfg.head_bars = t.hb0; end
    if t.fan_place ~= nil then cfg.fan_place = t.fan_place; end
    if t.ecast_place ~= nil then cfg.ecast_place = t.ecast_place; end
    local o = {};
    for k, v in pairs(t.o or {}) do o[k] = v; end
    local eq = {};
    for k, v in pairs(t.eq or {}) do eq[k] = v; end
    pcall(LAYOUT.apply, o, eq, (type(t.dps) == 'table' and t.dps[1]) and t.dps or nil);
end
function C.MD.apply()                                                -- (the switch: show that mode live, not saved yet)
    local M = C.MD;
    for k, v in pairs(M.base or {}) do cfg[k] = v; end              -- (your sizes as they were, then that mode's own if it has some kept)
    local had = C.modeload(M.link);
    if M.link then                                                   -- (each mode as it's meant to look: Hex link with your bars over your
        cfg.target_fx = 'link';                                      --  head, Normal with them in their place - unless that mode keeps its own)
        if not had then cfg.head_bars = 'head'; end
    else
        cfg.target_fx = (M.fx0 and M.fx0 ~= 'link') and M.fx0 or (cfg.std_fx or 'blade');
        if cfg.target_fx == 'off' then cfg.target_fx = 'blade'; end
        if not had then cfg.head_bars = 'fixed'; end
    end
    FIGHT.fx.t0 = os.clock();                                        -- (its entrance plays again)
end
function C.MD.pick(link)
    local M = C.MD;
    for k, v in pairs(M.base or {}) do cfg[k] = v; end              -- (back as it was, then the choice - with that mode's own sizes)
    cfg.target_fx = M.fx0;
    C.MD.restore();
    local had = type(cfg[link and 'ms_hex' or 'ms_norm']) == 'table' and (M.fx0 == 'link') ~= link;
    C.setmode(link);
    if not had then
        if link and (cfg.head_bars or 'fixed') == 'fixed' then cfg.head_bars = 'head'; end   -- (Hex link: your bars over your head)
        if not link and M.fx0 == 'link' and cfg.head_bars == 'head' then cfg.head_bars = 'fixed'; end
    end
    FIGHT.show = M.show0 or false;
    M.on = false;
    cfg.mode_v1 = true;
    pcall(save);
    if M.then_guide then pcall(EDIT.G.start); end                    -- (the first launch: the guide comes next)
end
function C.MD.draw()
    local M = C.MD;
    if not M.on then return; end
    local fg = nil;
    pcall(function() fg = imgui.GetForegroundDrawList(); end);
    if fg == nil then return; end
    local ds = imgui.GetIO().DisplaySize;
    local W, H = (ds and ds.x) or 1920, (ds and ds.y) or 1080;
    local k = math.max(0.8, math.min(1.8, H / 1080));
    if M.lay then M.lay = nil; pcall(function() LAYOUT.apply(LAYOUT.build('classic')); end); end   -- (the demo's clean layout)
    do local n_ = os.clock(); FIGHT.fx.t0 = n_ - (n_ % 6); end      -- (the entrance plays again with each pretend fight)
    M.i = math.max(1, math.min(#M.STEPS, M.i));
    local st = M.STEPS[M.i];
    local last = M.i == #M.STEPS;
    local CW, CH = math.floor(560 * k), M.h;
    local cx, cy = math.floor((W - CW) / 2), math.floor(H * 0.52 - CH / 2);   -- (the middle: the target at the top, your bars at the bottom)
    if tonumber(cfg.md_x) and tonumber(cfg.md_y) then               -- (dragged somewhere: there, kept on the screen)
        cx = math.floor(math.max(0, math.min(W - CW, tonumber(cfg.md_x))));
        cy = math.floor(math.max(0, math.min(H - CH, tonumber(cfg.md_y))));
    end
    imgui.SetNextWindowPos({ cx, cy }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ CW, CH }, ImGuiCond_Always);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0, 0, 0, 0 });
    if imgui.Begin('YunaUI Mode##yui_mode', { true }, bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoMove,
            ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoSavedSettings)) then
        local pad = math.floor(20 * k);
        local HX = M.link;
        local AC, AC2 = HX and PANEL.GOLD or C.normcol(2), HX and PANEL.GOLD2 or C.normcol(3);
        if HX then                                                   -- (the card itself in the chosen mode's look)
            local c = 16 * k;
            local pts = { { cx + c, cy }, { cx + CW - c, cy }, { cx + CW, cy + c }, { cx + CW, cy + CH - c }, { cx + CW - c, cy + CH }, { cx + c, cy + CH }, { cx, cy + CH - c }, { cx, cy + c } };
            local fill = U4(0.045, 0.04, 0.065, 0.97);
            if not pcall(function() fg:AddConvexPolyFilled(pts, fill); end) then
                for t_ = 2, #pts - 1 do fg:AddTriangleFilled(pts[1], pts[t_], pts[t_ + 1], fill); end
            end
            for i = 1, 8 do fg:AddLine(pts[i], pts[i % 8 + 1], U4(AC2[1], AC2[2], AC2[3], 0.8), 1.4); end
        else
            DL.RF(fg, cx, cy, cx + CW, cy + CH, U4(0.05, 0.045, 0.07, 0.97), 14 * k);
            DL.R(fg, cx, cy, cx + CW, cy + CH, U4(AC2[1], AC2[2], AC2[3], 0.75), 14 * k, C.rall, 1.4);
        end
        local y = cy + pad;
        local mx, my = imgui.GetMousePos();
        local f0 = sized('chat', 14 * k);                            -- the switch: NORMAL | HEX LINK
        local sw_, sh_ = math.floor(300 * k), math.floor(32 * k);
        local sx = cx + (CW - sw_) / 2;
        for i = 1, 2 do
            local bx = sx + (i - 1) * sw_ / 2;
            local on = (i == 2) == HX;
            local hov = mx >= bx and mx < bx + sw_ / 2 and my >= y and my < y + sh_;
            local a1 = (i == 2) and PANEL.GOLD or C.normcol(2);
            DL.RF(fg, bx, y, bx + sw_ / 2, y + sh_, u32(on and { a1[1], a1[2], a1[3], 0.32 } or (hov and { 1, 1, 1, 0.07 } or { 0.10, 0.09, 0.13, 1 })), (i == 1) and sh_ / 2 or 0, (i == 1) and C.rleft or 0);
            DL.R(fg, bx, y, bx + sw_ / 2, y + sh_, U4(a1[1], a1[2], a1[3], on and 0.95 or 0.3), (i == 1) and sh_ / 2 or 0, (i == 1) and C.rleft or 0, on and 1.6 or 1);
            local lb = (i == 1) and 'NORMAL' or 'HEX LINK';
            local lw = spaced_w(lb, 2 * k);
            local _, lh_ = imgui.CalcTextSize(lb);
            spaced(fg, bx + (sw_ / 2 - lw) / 2, y + (sh_ - lh_) / 2, lb, u32(on and { 1, 1, 1, 1 } or { 0.70, 0.68, 0.78, 1 }), 2 * k);
            imgui.SetCursorScreenPos({ bx, y });
            if imgui.InvisibleButton('##yui_md_sw' .. i, { sw_ / 2, sh_ }) and not on then M.link = (i == 2); M.apply(); end
        end
        if #M.STEPS > 1 then
            local stp = string.format('%d / %d', M.i, #M.STEPS);
            local stw = imgui.CalcTextSize(stp);
            DL.T(fg, cx + CW - pad - stw, y + 6 * k, U4(0.62, 0.60, 0.70, 1), stp);
        end
        unsized(f0);
        y = y + sh_ + 16 * k;
        local f2 = sized('chat', 22 * k);                            -- the title
        local ttl = (st.title and st.title()) or st[1];             -- (a title that changes with your settings)
        local _, th = imgui.CalcTextSize(ttl);
        DL.T(fg, cx + pad, y, U4(1, 1, 1, 1), ttl);
        unsized(f2);
        y = y + th + 6 * k;
        pcall(function() DL.RFM(fg, cx + pad, y, cx + pad + 60 * k, y + 2, u32(AC), u32(AC2), u32(AC2), u32(AC)); end);
        y = y + 14 * k;
        local f3 = sized('chat', 15.5 * k);                          -- the words: on a card that compares, the line for the mode showing is lit
        local lh = imgui.GetTextLineHeight() + 3 * k;
        local words = st[3] or st[2];
        if st[3] then
            for _, para in ipairs(st[2]) do
                for _, ln in ipairs(EDIT.G.lines(para, CW - pad * 2)) do DL.T(fg, cx + pad, y, U4(0.88, 0.87, 0.93, 1), ln); y = y + lh; end
                y = y + lh * 0.45;
            end
        end
        for pi, para in ipairs(words) do
            local lit = (#words == 2 and st[3] == nil and ((pi == 2) == HX)) or (st[3] ~= nil and ((pi == 2) == HX));
            local col = (#words == 2) and (lit and { 1, 1, 1, 1 } or { 0.55, 0.54, 0.62, 1 }) or { 0.88, 0.87, 0.93, 1 };
            if pi > 1 then y = y + lh * 0.45; end
            for li, ln in ipairs(EDIT.G.lines(para, CW - pad * 2 - ((#words == 2) and 14 * k or 0))) do
                if li == 1 and #words == 2 and lit then C.hexdot(fg, cx + pad + 4 * k, y + lh * 0.42, 4 * k, U4(AC2[1], AC2[2], AC2[3], 1)); end
                DL.T(fg, cx + pad + ((#words == 2) and 14 * k or 0), y, u32(col), ln);
                y = y + lh;
            end
        end
        unsized(f3);
        y = y + 16 * k;
        local f4 = sized('chat', 14 * k);                            -- the buttons
        local bh = math.floor(36 * k);
        local function button(id, label, bx, bw, main, acc)
            imgui.SetCursorScreenPos({ bx, y });
            local hit = imgui.InvisibleButton('##yui_md_' .. id, { bw, bh });
            local hov = mx >= bx and mx < bx + bw and my >= y and my < y + bh;
            local ac = acc or NEON2;
            DL.RF(fg, bx, y, bx + bw, y + bh, u32(hov and { 0.17, 0.15, 0.22, 1 } or { 0.10, 0.09, 0.13, 1 }), bh * 0.45);
            DL.R(fg, bx, y, bx + bw, y + bh, u32(main and { ac[1], ac[2], ac[3], hov and 1 or 0.85 } or { 1, 1, 1, hov and 0.30 or 0.16 }), bh * 0.45, C.rall, main and 1.6 or 1);
            local lw, lh2 = imgui.CalcTextSize(label);
            DL.T(fg, bx + (bw - lw) / 2, y + (bh - lh2) / 2, U4(0.95, 0.93, 1, 1), label);
            return hit;
        end
        if last then                                                 -- I AM NORMAL / I AM HEX LINK
            local bw = math.floor((CW - pad * 2 - 12 * k) / 2);
            if button('pn', 'NORMAL MODE', cx + pad, bw, true, C.normcol(3)) then M.pick(false); end
            if button('ph', 'HEX LINK MODE', cx + pad + bw + 12 * k, bw, true, PANEL.GOLD2) then M.pick(true); end
            y = y + bh + 10 * k;
            if M.i > 1 and button('back', 'BACK', cx + pad, math.floor(90 * k), false) then M.i = M.i - 1; end
        else
            local nw, bw2 = math.floor(100 * k), math.floor(90 * k);
            local nx = cx + CW - pad - nw;
            if button('next', 'NEXT', nx, nw, true, AC2) then M.i = M.i + 1; end
            if M.i > 1 and button('back', 'BACK', nx - 10 * k - bw2, bw2, false) then M.i = M.i - 1; end
            if button('skip', 'CHOOSE NOW', cx + pad, math.floor(130 * k), false) then M.i = #M.STEPS; end
        end
        unsized(f4);
        y = y + bh + pad;
        M.h = math.floor(y - cy);
        if imgui.IsWindowHovered() and imgui.IsMouseClicked(0) and not imgui.IsAnyItemHovered() then M.drag = { mx - cx, my - cy }; end   -- (drag it by the card)
        if M.drag then
            if imgui.IsMouseDown(0) then cfg.md_x, cfg.md_y = mx - M.drag[1], my - M.drag[2];
            else M.drag = nil; pcall(save); end
        end
    end
    imgui.End();
    imgui.PopStyleColor(1);
    imgui.PopStyleVar(2);
end
ashita.events.register('d3d_present', 'yui_present', function()
    pcall(C.apply_hp);
    local logged = false;                                            -- (logged in: a character really there - logging out or /shutdown
    pcall(function()                                                 --  switches to the settings with no character, which look brand new)
        local pt = AshitaCore:GetMemoryManager():GetParty();
        logged = pt:GetMemberIsActive(0) ~= 0 and (pt:GetMemberName(0) or '') ~= '' and (pt:GetMemberServerId(0) or 0) ~= 0;
    end);
    if cfg.welcomed == nil and logged then                           -- (the very first launch: Edit Mode opens once, to place everything;
        cfg.welcomed = true;                                         --  a player who already had YunaUI doesn't get it)
        if not cfg.spine_v2 then EDIT.welcome = true; cfg.mode_v1, cfg.mode_v2 = true, true; pcall(C.MD.start, true); end   -- (the mode chooser, then the guide, then Edit Mode)
        pcall(save);
    end
    if cfg.g_dps0 and logged and not EDIT.G.on then                  -- (left mid-guide last time: the Damage Meter as it was)
        local d0 = cfg.g_dps0; cfg.g_dps0 = nil;
        pcall(function() YUI_DPS.set_visible(d0[1] ~= false); YUI_DPS.set_minimized(d0[2] == true); end);
        pcall(save);
    end
    if cfg.md_backup and logged and not C.MD.on then pcall(C.MD.restore); pcall(save); end   -- (left mid-demo last time: your layout back)
    if cfg.g_backup and logged and not EDIT.G.on then pcall(EDIT.G.unstage); pcall(save); end   -- (left mid-guide: the same)
    if cfg.mode_v2 == nil and logged and not EDIT.G.on and not C.MD.on then cfg.mode_v1, cfg.mode_v2 = true, true; pcall(C.MD.start, true); pcall(save); end   -- (once after this update: Normal or Hex link?, then the guide - players who already had YunaUI too)
    if not cfg.pieces_v1 then                                        -- (once: old Edit Mode offsets of the target's name, Magic Burst, fan and
        for _, pc in ipairs(FIGHT.PIECES) do cfg[pc[1] .. '_dx'], cfg[pc[1] .. '_dy'] = 0, 0; end   --  cast cleared - they follow the bar)
        cfg.pieces_v1 = true; pcall(save);
    end
    if not cfg.slots_v1 then cfg.strip_cols, cfg.strip_icon, cfg.strip_fit, cfg.slots_v1 = 4, 32, false, true; pcall(save); end   -- (once: the gear as floating slots, 4 x 4)
    if not cfg.cards_v2 then cfg.card_style, cfg.tag_look, cfg.card_h, cfg.cards_v2 = 'clean', 'role', 1.0, true; pcall(save); end   -- (the look is fixed now: Clean)
    if not cfg.party_bl_v1 then                                      -- (once: the party box lost its buff room; keep the list where it was)
        if (cfg.party_look or 'spine') == 'spine' and (tonumber(cfg.party_cols) or 1) == 1 then
            local psc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.party_scale) or 1);
            cfg.party_x = (tonumber(cfg.party_x) or 0) + ((math.floor(20 * psc * (tonumber(cfg.buff_scale) or 1)) + 2) * 16 + 8);
        end
        cfg.party_bl_v1 = true; WATCH.move = 3; pcall(save);
    end
    if not cfg.bracket_v1 then cfg.bracket_v1 = true; end
    if not cfg.plate_v1 then cfg.plate_v1 = true; end
    if not cfg.style_v3 then cfg.style_v3 = true; end
    if not cfg.tags_v2 then cfg.tag_look, cfg.tags_v2 = 'role', true; pcall(save); end   -- (once: back to the coloured job tags)
    if not cfg.chatread_v1 then cfg.chat_outline, cfg.chat_ground, cfg.chat_ground_a, cfg.chatread_v1 = 'outline', true, 0.5, true; pcall(save); end   -- (once: the new readable chat)
    if not cfg.tbuff_v1 then cfg.target_buff_scale, cfg.tbuff_v1 = tonumber(cfg.buff_scale) or 1, true; pcall(save); end   -- (once: the target's buffs start at the party's size)
    if not cfg.style_v4 then cfg.card_style, cfg.style_v4 = 'clean', true; pcall(save); end   -- (once: Clean - no cards)
    if not cfg.clean_v1 then                                         -- (once: the options taken out of the panel take their default)
        cfg.target_look, cfg.fan_place, cfg.ecast_place, cfg.fan_layout = 'dd2', 'bar', 'bar', 'fan';
        cfg.fan_shape, cfg.fan_tint, cfg.party_cols = 'tab', 'dark', 1;
        cfg.clean_v1 = true; WATCH.move = 3; pcall(save);
    end
    if not cfg.slim_v2 then cfg.spine_line, cfg.spine_trace, cfg.slim_v2 = true, true, true; pcall(save); end   -- (an old step; it used to put Slim back on new installs)
    if cfg.card_style ~= 'clean' then cfg.card_style = 'clean'; pcall(save); end   -- (the party's look is fixed: Clean, the CARDS options are gone)
    if not cfg.spine_v2 then                                         -- (once: the new default places)
        pcall(function()
            local ds = imgui.GetIO().DisplaySize;
            if ds and ds.x and ds.x > 100 then
                local psc = (tonumber(cfg.scale) or 1) * (tonumber(cfg.party_scale) or 1);
                cfg.party_x = math.floor(ds.x - 330 * psc - 24);
                cfg.party_y = math.floor(ds.y - 230 * psc - 110);
                cfg.ally_anchor = true;
                if not cfg.spine_v1 then
                    cfg.ally1_scale = 0.75 * (tonumber(cfg.party_scale) or 1);
                    cfg.ally2_scale = 0.75 * (tonumber(cfg.party_scale) or 1);
                end
                cfg.spine_v1, cfg.spine_v2 = true, true;
                ALLY.home = true;                                    -- (then set right by the window's real size)
                WATCH.move = 3;
                save();
            end
        end);
    end
    local now = os.clock();
    local dt = math.min(0.1, now - last);
    last = now;
    local ok, err = pcall(function()
        if not AshitaCore:GetFontManager():GetVisible() then return; end
        local p = AshitaCore:GetMemoryManager():GetParty();
        if p == nil or p:GetMemberIsActive(0) == 0 then return; end   -- not logged in / zoning
        -- each piece on its own: a problem in one (shown once in chat) never stops the others, the logo or the window
        local function piece(fn, ...)
            if YUI_PRES and not YUI_PRES[(C.PF and C.PF[fn]) or '-'] then return; end   -- (the guide: only the slide's own pieces)
            local ok2, e2 = pcall(fn, ...);
            if not ok2 then
                YUI_ERRLOG('draw', e2);
                if ui.last_err ~= tostring(e2) then ui.last_err = tostring(e2); msg('Draw error: ' .. ui.last_err); end
            end
        end
        YUI_MAPCOVER = ((YMAP.big and YMAP.bygame) or legacy.inmap) and true or false;   -- (the game's Map open: none of the UI over it - or, with
        if YUI_MAPCOVER then                                         --  MINIMAP > Open with the game's Map, YunaUI's big map on its own)
            pcall(legacy.pad_tick);                                  -- (still watching for the game's Map closing)
            if YMAP.bygame then piece(YMAP.draw); end
            return;
        end
        -- settings copied in from another character? take them now
        if os.clock() >= WATCH.at then                               -- (settings copied in from another character: looked for every 15 s -
            WATCH.at = os.clock() + 15;                              --  two files read from disk, off the every-frame path)
            local function parse(data)
                local chunk = data and loadstring(data);
                if chunk == nil then return nil; end
                setfenv(chunk, { T = function(x) return x; end, require = function() end });
                local ok3, res = pcall(chunk);
                return (ok3 and type(res) == 'table') and res or nil;
            end
            local s = own_file('settings.lua');
            if WATCH.own == nil then WATCH.own = s;
            elseif s and s ~= WATCH.own then
                WATCH.own = s;
                local new = parse(s);
                if new then
                    for k, v in pairs(new) do cfg[k] = v; end
                    WATCH.move = 3;                                  -- move the windows to their new places
                    for _, e in ipairs(logs[1]) do e.lines = nil; end
                    for _, e in ipairs(logs[2]) do e.lines = nil; end
                    msg('Settings updated (copied from another character).');
                end
            end
            local q = own_file('equip.lua');
            if WATCH.eq == nil then WATCH.eq = q;
            elseif q and q ~= WATCH.eq then
                WATCH.eq = q;
                local new = parse(q);
                if new and YUI_EQ_APPLY then YUI_EQ_APPLY(new); end
            end
        end
        if WATCH.move > 0 then WATCH.move = WATCH.move - 1; end
        if WATCH.later and os.clock() - (WATCH.saved or 0) > 1 then WATCH.later, WATCH.saved = nil, os.clock(); pcall(save); end
        if not ui.open and not EDIT.on then ALLY.pick = nil; end     -- (the pretend selection mark lasts only while placing things)
        SUBPREVIEW = SUBPREVIEW or function() return (ui.open and ui.tab == 2) or EDIT.on or FIGHT.show; end   -- (Preview them: the target of target too)
        if EDIT.on then PREVIEW.party, PREVIEW.alliance = true, true;
        elseif EDIT.was then PREVIEW.party, PREVIEW.alliance = false, false; end
        EDIT.was = EDIT.on;
        C.PF = C.PF or { [draw_target] = 'tgt', [draw_subtarget] = 'sub', [draw_enemies] = 'enemy', [draw_chat] = 'chat',
            [draw_party] = 'party', [draw_exp] = 'exp', [draw_cast] = 'cast', [PET.draw] = 'pet', [TIMERS.draw] = 'timers',
            [C.head_bars] = 'heads', [draw_strip] = 'strip', [draw_gil] = 'gil', [draw_bag] = 'bag', [YMAP.draw] = 'map',
            [EDIT.G.dim] = 'all', [EDIT.G.draw] = 'all', [EDIT.G.splash] = 'all', [C.MD.draw] = 'all' };   -- (the guide: which slide shows what)
        piece(EDIT.G.dim);                                           -- (the guide: the screen dimmed under the slide's pieces)
        piece(draw_target, dt);
        piece(FIGHT.edit_pieces);                                    -- (Edit Mode: the target's name, fan and cast)
        piece(FIGHT.win);                                            -- (the fan / enemy cast when placed anywhere)
        piece(draw_subtarget, dt);
        piece(draw_enemies, dt);
        C.fc = (C.fc or 0) + 1;                                      -- (game memory read and written every 6th frame, not every one: plenty)
        local okv, byvc = pcall(C.vchat_sync);                       -- (VanaCore hides them itself: nothing written into the game's windows)
        C.byvc = okv and byvc or false;
        if C.byvc then
            if not C.byvc_done then C.byvc_done = true; pcall(legacy.hide_logs, false); pcall(legacy.hide_input, false); end   -- (anything YunaUI hid the old way: back)
        else
            if C.fc % 6 == 0 then
                if cfg.chat and cfg.hide_game_chat then pcall(pin_game_chat); end
                legacy.hide_logs(cfg.chat and cfg.hide_game_chat);       -- the game's chat windows: not drawn at all
            end
            legacy.hide_input(cfg.chat and cfg.hide_game_input);         -- the game's typing bar: not drawn (you type in YunaUI's)
        end
        if YUI_OPEN_EQUIP then YUI_OPEN_EQUIP = false; ui.open = true; ui.tab = 6; end
        pcall(legacy.pad_tick);                                      -- (the pad opened the game's log: YunaUI's chat instead)
        chat_lit_all = ui.open or not cfg.setup_done or EDIT.G.on or legacy.pad.open;
        if ui.open then ui.was_open = true;
        elseif ui.was_open and not cfg.setup_done then cfg.setup_done = true; save(); end
        piece(draw_chat, 1);
        piece(draw_chat, 2);
        piece(draw_party, dt);
        piece(draw_exp, dt);
        CAST.preview = (ui.open and ui.tab == 4) or EDIT.on;       -- the BARS tab (and Edit Mode) show a preview of it
        piece(draw_cast);
        PET.preview = (ui.open and ui.tab == 4) or EDIT.on;         -- the BARS tab (and Edit Mode) show a pretend pet
        piece(PET.draw, dt);
        piece(YMAP.draw);                                            -- the minimap (BARS > MINIMAP)
        TIMERS.preview = (ui.open and ui.tab == 7) or EDIT.on;      -- the TIMERS tab (and Edit Mode) show a preview of it
        piece(TIMERS.draw);
        piece(C.loot_win);                                           -- (TREASURE POOL)
        piece(C.bubble_draw);                                        -- (CHAT > Speech bubbles)
        pcall(C.hide_tname);                                         -- (Hex link: the game's name over your target hidden)
        pcall(C.tp_sound);                                           -- (BARS > TP sound: a chime at 1000 / 2000 / 3000)
        piece(C.head_bars);                                          -- (BARS > YOUR BARS > Where: over your head)
        YUI_EQ_HIDE = true;                                          -- (the old gear wheel never shows)
        YUI_LOCKED = cfg.locked and true or false;                 -- the HP / MP / TP bars (equip.lua) follow this lock
        DOLL.preview = (ui.open and ui.tab == 6) or (EDIT.G.on and EDIT.G.STEPS[EDIT.G.i][1] == 'Gear');                     -- the EQUIP tab shows the strip at full brightness
        piece(draw_strip);      -- the wheel steps aside while the paper doll is on
        piece(draw_doll);
        piece(draw_gil);
        piece(draw_bag);
        piece(draw_window);
        piece(EDIT.draw);
        piece(EDIT.G.draw);                                          -- the first-time guide (/yui guide)
        piece(EDIT.G.splash);                                        -- and its send-off
        piece(C.MD.draw);                                            -- (the mode chooser: Normal or Hex link)
    end);
    if not ok then YUI_ERRLOG('frame', err); end
    if not ok and ui.last_err ~= tostring(err) then ui.last_err = tostring(err); msg('Draw error: ' .. ui.last_err); end
end);

ashita.events.register('packet_out', 'yui_packet_out', function(e)   -- (what you just did: names your gear swaps)
    if e.id == 0x01A then pcall(DOLL.on_out, e); end
end);
ashita.events.register('packet_in', 'yui_packet', function(e)
    if e.id == 0x076 then pcall(read_party_buffs, e);
    elseif e.id == 0x028 then pcall(read_action, e); pcall(PET.action, e);
    elseif e.id == 0x068 then pcall(PET.sync, e);
    elseif e.id == 0x029 then pcall(read_message, e);
    elseif e.id == 0x0D3 then pcall(C.loot_packet, e);
    elseif e.id == 0x0D2 then pcall(C.loot_drop, e);               -- (an item fell in the pool: it flies in from the monster)              -- (a lot or a pass on a treasure pool item)
    elseif e.id == 0x00E then pcall(read_claim, e);
    elseif e.id == 0x057 then pcall(C.weather_packet, e);
    elseif e.id == 0x00A then enemies = {}; ENGAGED = {}; LASTHIT = {}; FIGHT.casts = {}; FIGHT.sc = {}; FIGHT.mine_at = nil; pcall(C.weather_packet, e);
    elseif e.id == 0x0AC then FIGHT.mine_at = nil; end                -- (your weapon skills changed)
end);

ashita.events.register('text_in', 'yui_text', function(e)
    if e.blocked or e.message == nil or #e.message > 2048 then return; end
    local mode = bit.band(e.mode, 0xFF);
    if mode == 152 then return; end
    chat_add(mode, e.message);
    -- (as FancyChat does) battle lines go only to YunaUI's chat: the game's own chat never gets them, so in a busy fight
    -- it doesn't keep trying to pop open. Talk, NPC dialogue (150 / 151) and system lines still reach it.
    if cfg.chat and cfg.hide_game_chat and is_combat(mode) then e.blocked = true; end
end);

ashita.events.register('dinput_button', 'yui_pad_d', function(e)    -- PlayStation and other DirectInput pads
    local b, st = e.button, e.state or 0;
    local id = 'd' .. b;
    if b ~= 32 and st >= 128 then legacy.pad_press('d', b); end
    if id == cfg.pad_log and cfg.chat and cfg.hide_game_chat and (legacy.pad.big or legacy.pad.mine) then   -- the log button: the game's (its log, a 2nd press your buffs), but the next tab in the big chat
        if st >= 128 and legacy.pad_once('log') then
            if legacy.pad.big then legacy.pad_tab(1); else legacy.pad_toggle(not legacy.pad.mine); end
        end
        e.blocked = true;
        return;
    end
    if not legacy.pad.open then return; end
    if id == legacy.pad_btn('d', 'back') and (legacy.pad.mine or legacy.pad.big) then    -- Circle: back (big -> lit -> closed)
        if st >= 128 and legacy.pad_once('close') then legacy.pad_back(); end
        e.blocked = true;
        return;
    end
    if id == legacy.pad_btn('d', 'big') and legacy.pad.open then     -- the full-log button (usually Cross): the big chat
        if st >= 128 and legacy.pad_once('big') then legacy.pad.big = not legacy.pad.big; legacy.pad.combat = false; cw[1].scroll = 0; end
        e.blocked = true;
        return;
    end
    if b == 52 or b == 53 then                                       -- L1 / R1: the tab
        if st >= 128 and legacy.pad_once('tab' .. b) then legacy.pad_tab((b == 52) and -1 or 1); end
        e.blocked = true;
    elseif b == 32 then                                              -- the D-pad (an angle): up / down scroll
        if st == 0 or st == 4500 or st == 31500 then if legacy.pad_once('up') then legacy.pad_scroll(3); end e.blocked = true;
        elseif st == 18000 or st == 13500 or st == 22500 then if legacy.pad_once('down') then legacy.pad_scroll(-3); end e.blocked = true; end
    end
end);
ashita.events.register('xinput_button', 'yui_pad_x', function(e)    -- Xbox (XInput) pads
    local b, st = e.button, e.state or 0;
    local id = 'x' .. b;
    if b > 3 and st ~= 0 then legacy.pad_press('x', b); end
    if id == cfg.pad_log and cfg.chat and cfg.hide_game_chat and (legacy.pad.big or legacy.pad.mine) then   -- the log button (often X): as above
        if st ~= 0 and legacy.pad_once('log') then
            if legacy.pad.big then legacy.pad_tab(1); else legacy.pad_toggle(not legacy.pad.mine); end
        end
        e.blocked = true;
        return;
    end
    if not legacy.pad.open then return; end
    if id == legacy.pad_btn('x', 'back') and (legacy.pad.mine or legacy.pad.big) then    -- B: back (big -> lit -> closed)
        if st ~= 0 and legacy.pad_once('close') then legacy.pad_back(); end
        e.blocked = true;
        return;
    end
    if id == legacy.pad_btn('x', 'big') and legacy.pad.open then     -- the full-log button (usually A): the big chat
        if st ~= 0 and legacy.pad_once('big') then legacy.pad.big = not legacy.pad.big; legacy.pad.combat = false; cw[1].scroll = 0; end
        e.blocked = true;
        return;
    end
    if b == 8 or b == 9 then                                         -- LB / RB: the tab
        if st ~= 0 and legacy.pad_once('tab' .. b) then legacy.pad_tab((b == 8) and -1 or 1); end
        e.blocked = true;
    elseif b == 0 or b == 1 then                                     -- D-pad up / down: scroll
        if st ~= 0 and legacy.pad_once('sc' .. b) then legacy.pad_scroll((b == 0) and 3 or -3); end
        e.blocked = true;
    end
end);
-- Keyboard players, the same as the pad: F is Triangle / Y (YunaUI's chat; with the big chat open, the next tab), Enter
-- is X / A (the big chat), Escape is Circle / B (back), Page Up / Page Down scroll. F works only with no menu open and
-- nothing being typed; the others only while YunaUI's chat is open. A key is kept from the game only when it did something.
-- The game's own way works too: numpad + moves the game's focus (your buffs, the cursor, the chat); when it lands on
-- the chat, the game's log is hidden (legacy.log_away) and YunaUI's chat lights up instead, and then Enter makes it big
-- (not the game's full log), Escape goes back, Page Up / Down scroll - numpad + itself always stays the game's.
legacy.kb = { held = {}, keys = { 0x21, 0x1C, 0x9C, 0x01, 0xC9, 0xD1, 0x4E } };
function legacy.kb_act(k)                                            -- (what a key does right now, or nil)
    if not (cfg.chat and cfg.hide_game_chat) then return nil; end
    local io = imgui.GetIO();
    if io.WantTextInput or io.KeyCtrl or io.KeyAlt or io.KeyShift then return nil; end
    if k == 0x21 then return (legacy.pad.menu == '' or legacy.pad.mine) and 'log' or nil; end
    if not legacy.pad.open then return nil; end                     -- (YunaUI's chat lit: opened with F, or the game's focus on its chat)
    if k == 0x4E then return legacy.pad.big and 'log' or nil; end   -- (numpad +: in the big chat, the next tab - as F; else it stays the game's)
    if k == 0x1C or k == 0x9C then return 'big'; end
    if k == 0x01 then return (legacy.pad.mine or legacy.pad.big) and 'back' or nil; end   -- (else Escape is the game's: it leaves its chat)
    if k == 0xC9 then return 'up'; end
    if k == 0xD1 then return 'down'; end
    return nil;
end
function legacy.kb_do(a)
    if a == 'log' then if legacy.pad.big then legacy.pad_tab(1); else legacy.pad_toggle(not legacy.pad.mine); end
    elseif a == 'big' then legacy.pad.big = not legacy.pad.big; legacy.pad.combat = false; cw[1].scroll = 0;
    elseif a == 'back' then legacy.pad_back();
    else legacy.pad_scroll((a == 'up') and 6 or -6); end
end
ashita.events.register('key_data', 'yui_kb', function(e)
    local k = e.key;
    if not e.down then
        if legacy.kb.held[k] then legacy.kb.held[k] = nil; e.blocked = true; end
        return;
    end
    if legacy.kb.held[k] then e.blocked = true; return; end          -- (held down: once per press)
    local ok, a = pcall(legacy.kb_act, k);
    if not ok or a == nil then return; end
    legacy.kb.held[k] = true;
    pcall(legacy.kb_do, a);
    e.blocked = true;
end);
ashita.events.register('key_state', 'yui_kb_state', function(e)    -- (the game also reads held keys from here)
    local keys = ffi.cast('uint8_t*', e.data_raw);
    for _, k in ipairs(legacy.kb.keys) do
        if keys[k] == 0 then legacy.kb.held[k] = nil;                -- (a key up whose event got lost: let it go)
        elseif legacy.kb.held[k] then keys[k] = 0;
        else local ok, a = pcall(legacy.kb_act, k); if ok and a then keys[k] = 0; end end
    end
end);
ashita.events.register('command', 'yui_command', function(e)
    local args = e.command:args();
    if #args == 0 then return; end
    local cmd = args[1]:lower():gsub('^/+', '');
    if cmd ~= 'yui' and cmd ~= 'yunaui' then return; end
    e.blocked = true;
    local sub = (args[2] or ''):lower();
    if sub == '' then ui.open = not ui.open;
    elseif sub == 'edit' then EDIT.on = not EDIT.on; if EDIT.on then ui.open = false; end
    elseif sub == 'lootmenu' then                                    -- (which game menus were open with something in the pool)
        local t = {};
        for k in pairs(C.LOOT.menus) do t[#t + 1] = k; end
        msg('Menus seen with items in the pool: ' .. ((#t > 0) and table.concat(t, ', ') or 'none yet'));
    elseif sub == 'tallinfo' then                                    -- (Hex link: how tall your target reads - the game's arrow, its feet, the result)
        local ok, err = pcall(function()
            local mm = AshitaCore:GetMemoryManager();
            local ent, tg = mm:GetEntity(), mm:GetTarget();
            local idx = tg:GetTargetIndex(0) or 0;
            if idx == 0 then msg('Tall info: target something first.'); return; end
            local ap = ent:GetActorPointer(idx);
            local px, py, pz = ashita.memory.read_float(ap + 0x678), ashita.memory.read_float(ap + 0x680), ashita.memory.read_float(ap + 0x67C);
            local a1, a2, a3 = tg:GetArrowPositionX(0), tg:GetArrowPositionY(0), tg:GetArrowPositionZ(0);
            local ms, hb = C.msize(idx, ent);
            local mh = 0;
            pcall(function() mh = ashita.memory.read_float(ashita.memory.read_uint32(ap + 0x70) + 0x204); end);
            msg(string.format('Tall info: %s at %.1f / %.1f / %.1f, arrow X %s Y %s Z %s, model height %.2f, hitbox %s, tall %.2f',
                tostring(ent:GetName(idx)), px, py, pz, tostring(a1), tostring(a2), tostring(a3), mh or 0, tostring(hb), C.tall(idx, ent)));
        end);
        if not ok then msg('Tall info failed: ' .. tostring(err)); end
    elseif sub == 'mapinfo' then                                     -- (for a minimap report: where you are, and which map is shown)
        local ok, err = pcall(C.map_info);                           -- (always says something: the line, or why it couldn't)
        if not ok then msg('Map info failed: ' .. tostring(err)); end
    elseif sub == 'welcome' then EDIT.welcome = true; EDIT.G.start();   -- (what a new player sees on the first launch; settings untouched)
    elseif sub == 'guide' or sub == 'tour' then EDIT.G.start();      -- the first-time guide again
    elseif sub == 'mode' then C.MD.start(false);                      -- the mode chooser again (Normal or Hex link)
    elseif sub == 'lock' or sub == 'unlock' then cfg.locked = (sub == 'lock'); save(); msg(cfg.locked and 'Locked.' or 'Unlocked.');
    elseif sub == 'reset' then settings.reset(); msg('Reset to default (reload the addon to move everything back).');
    else msg('/yui  - open YunaUI   |   /yui edit   |   /yui guide   |   /yui lock | unlock   |   /yui reset'); end
end);
