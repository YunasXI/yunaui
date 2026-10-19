-- Damage Meter: part of YunaUI (it was the separate YunaDPS addon). YunaUI loads it with require('dps'); its settings are
-- dps.lua in YunaUI's config folder, its tab is DAMAGE METER (through YUI_DPS, at the end), and /dps still works.

require('common');
-- Its own view of ImGui: the meter changes a couple of functions for itself (tooltips, text size), and inside YunaUI
-- those changes must never reach YunaUI's own drawing (they shrank its text and doubled every '%'), so they live on
-- this private table, which falls back to the real ImGui for everything else.
local imgui_raw = require('imgui');
local imgui     = setmetatable({}, { __index = imgui_raw });
imgui.SetTooltip = function(t)
    if YUI_TIP then YUI_TIP(t); return; end                         -- YunaUI's tooltip style
    if imgui_raw.BeginTooltip and imgui_raw.EndTooltip then  -- drawn by hand so it follows the meter's size too
        if imgui_raw.BeginTooltip() == false then return; end
        imgui.SetWindowFontScale(1.0);
        imgui_raw.Text(tostring(t));
        imgui_raw.EndTooltip();
    else
        imgui_raw.SetTooltip(tostring(t));
    end
end

-- Size: everything is drawn at scale.k, set by the meter's width (drag its corner), 1 = Normal.
-- Z(n) is n pixels at that size; window text scales the same way.
local scale = { k = 1, f = 1 };   -- f: font size correction (see push_font)
local function Z(n) return n * scale.k; end
imgui.SetWindowFontScale = function(v) return imgui_raw.SetWindowFontScale(v * scale.k * scale.f); end   -- (only the meter's)
local chat     = require('chat');
local settings = require('settings');
local ffi      = require('ffi');
local d3d      = require('d3d8');

----------------------------------------------------------------------------------------------------
-- Pictures (images\yunadps.png: the YGO art without the letters), each loaded once (false = missing)
----------------------------------------------------------------------------------------------------
local logo = {};
local function logo_texture(name)
    if logo[name] ~= nil then return logo[name] or nil; end
    logo[name] = false;
    pcall(function()
        local f = io.open(addon.path .. '/images/' .. name, 'rb');
        if f == nil then return; end
        local data = f:read('*a');
        f:close();
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        if ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d.get_device(), data, #data, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
                ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0, nil, nil, ptr) == ffi.C.S_OK then
            local tex = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
            logo[name] = { tex = tex, ptr = tonumber(ffi.cast('uint32_t', tex)) };
        end
    end);
    return logo[name] or nil;
end

----------------------------------------------------------------------------------------------------
-- Theme: YunaUI's look (near-black, a violet accent, pink-to-violet bars)
----------------------------------------------------------------------------------------------------
local C = {
    bg       = { 0.035, 0.032, 0.050, 0.95 },
    card     = { 0.085, 0.080, 0.115, 1.00 },
    frame    = { 0.110, 0.100, 0.145, 1.00 },
    frame_hi = { 0.165, 0.155, 0.215, 1.00 },
    border   = { 0.620, 0.300, 1.000, 0.00 },   -- (the frame is drawn by fx.frame)
    line     = { 1.000, 1.000, 1.000, 0.07 },
    gold     = { 0.800, 0.580, 1.000, 1.00 },   -- (the accent: was YGO's periwinkle, now YunaUI's violet)
    gold_dim = { 0.740, 0.660, 0.950, 0.85 },
    text     = { 0.930, 0.920, 0.980, 1.00 },
    muted    = { 0.560, 0.550, 0.650, 1.00 },
    green    = { 0.450, 0.900, 0.600, 1.00 },
    red      = { 1.000, 0.450, 0.450, 1.00 },
    neon     = { 0.620, 0.300, 1.000 },
    neon2    = { 0.850, 0.650, 1.000 },
    hp       = { 1.000, 0.360, 0.620 },          -- YunaUI's HP bar: pink ...
    mp2      = { 0.620, 0.400, 1.000 },          -- ... to violet
};

local JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG',
               'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN' };

-- Bar colour per job, soft enough to sit on the navy panel
local JOB_COL = {
    { 0.85, 0.40, 0.35 }, { 0.90, 0.65, 0.30 }, { 0.92, 0.92, 0.86 }, { 0.58, 0.46, 0.90 }, { 0.90, 0.38, 0.52 },
    { 0.45, 0.80, 0.55 }, { 0.72, 0.84, 0.96 }, { 0.62, 0.32, 0.50 }, { 0.72, 0.56, 0.36 }, { 0.95, 0.75, 0.55 },
    { 0.56, 0.76, 0.40 }, { 0.95, 0.55, 0.30 }, { 0.48, 0.58, 0.74 }, { 0.40, 0.60, 0.95 }, { 0.40, 0.85, 0.85 },
    { 0.35, 0.55, 1.00 }, { 0.86, 0.70, 0.36 }, { 0.80, 0.60, 0.76 }, { 0.95, 0.60, 0.75 }, { 0.70, 0.70, 0.95 },
    { 0.50, 0.85, 0.70 }, { 0.60, 0.76, 0.86 },
};

local function push_theme()
    local cols = {
        { ImGuiCol_WindowBg, C.bg }, { ImGuiCol_ChildBg, { 0, 0, 0, 0 } }, { ImGuiCol_PopupBg, { 0.075, 0.079, 0.092, 0.99 } },
        { ImGuiCol_Border, C.border }, { ImGuiCol_Text, C.text }, { ImGuiCol_TextDisabled, C.muted },
        { ImGuiCol_FrameBg, C.frame }, { ImGuiCol_FrameBgHovered, C.frame_hi }, { ImGuiCol_FrameBgActive, C.frame_hi },
        { ImGuiCol_Button, { 1, 1, 1, 0.035 } }, { ImGuiCol_ButtonHovered, { 1, 1, 1, 0.08 } }, { ImGuiCol_ButtonActive, { 1, 1, 1, 0.12 } },
        { ImGuiCol_Separator, C.line },
        { ImGuiCol_ScrollbarBg, { 0, 0, 0, 0 } }, { ImGuiCol_ScrollbarGrab, { 1, 1, 1, 0.08 } },
        { ImGuiCol_ScrollbarGrabHovered, { 1, 1, 1, 0.16 } }, { ImGuiCol_ScrollbarGrabActive, { 1, 1, 1, 0.22 } },
        { ImGuiCol_ResizeGrip, { 0, 0, 0, 0 } },                      -- (hidden: fx.grip draws it inside the shadow)
        { ImGuiCol_ResizeGripHovered, { 0, 0, 0, 0 } },
        { ImGuiCol_ResizeGripActive, { 0, 0, 0, 0 } },
        { ImGuiCol_Header, { 1, 1, 1, 0.12 } }, { ImGuiCol_HeaderHovered, { 1, 1, 1, 0.08 } },
        { ImGuiCol_HeaderActive, { 1, 1, 1, 0.16 } },
    };
    for _, c in ipairs(cols) do imgui.PushStyleColor(c[1], c[2]); end
    local vars = {
        { ImGuiStyleVar_WindowRounding, 10 }, { ImGuiStyleVar_ChildRounding, 6 }, { ImGuiStyleVar_FrameRounding, 12 },
        { ImGuiStyleVar_PopupRounding, 6 }, { ImGuiStyleVar_ScrollbarRounding, 6 },
        { ImGuiStyleVar_WindowPadding, { 12, 10 } }, { ImGuiStyleVar_FramePadding, { 8, 4 } },
        { ImGuiStyleVar_ItemSpacing, { 6, 4 } }, { ImGuiStyleVar_WindowBorderSize, 1 }, { ImGuiStyleVar_ScrollbarSize, 6 },
        { ImGuiStyleVar_FrameBorderSize, 0 },
    };
    for _, v in ipairs(vars) do
        local val = v[2];
        if v[1] ~= ImGuiStyleVar_WindowBorderSize and v[1] ~= ImGuiStyleVar_FrameBorderSize then
            val = type(val) == 'table' and { Z(val[1]), Z(val[2]) } or Z(val);
        end
        imgui.PushStyleVar(v[1], val);
    end
    return #cols, #vars;
end

local function u32(c) return imgui.GetColorU32(c); end

-- Text at a screen position, drawn as normal ImGui text so it always uses the window's own font and size
-- (draw-list text came out tiny on some players' ImGui). The layout cursor is put back afterwards.
local function put_text(x, y, col, text)
    local cx, cy = imgui.GetCursorScreenPos();
    imgui.SetCursorScreenPos({ x, y });
    imgui.TextColored(col, text);
    imgui.SetCursorScreenPos({ cx, cy });
end

local function text_w(text)
    local ok, a = pcall(imgui.CalcTextSize, text);
    if ok then
        if type(a) == 'number' then return a; end
        if type(a) == 'table' then return a.x or a[1] or (#text * 7); end
    end
    return #text * 7;
end

local function ghost_button(label, size)
    imgui.PushStyleColor(ImGuiCol_Button, { 0, 0, 0, 0 });
    imgui.PushStyleColor(ImGuiCol_Text, C.muted);
    local clicked = imgui.Button(label, size);
    imgui.PopStyleColor(2);
    return clicked;
end

-- 12345678 -> "12,345,678"
local function fmt(n)
    local str = tostring(math.floor((n or 0) + 0.5));
    local r;
    repeat str, r = str:gsub('^(-?%d+)(%d%d%d)', '%1,%2'); until r == 0;
    return str;
end

local function clock_text(sec)
    sec = math.floor(sec or 0);
    if sec >= 3600 then return string.format('%d:%02d:%02d', sec / 3600, (sec % 3600) / 60, sec % 60); end
    return string.format('%d:%02d', sec / 60, sec % 60);
end

local function msg(text) print(chat.header('Damage Meter'):append(chat.message(text))); end

-- Wall clock in seconds (os.clock is wall time on Windows)
local function now() return os.clock(); end

----------------------------------------------------------------------------------------------------
-- Settings & state
----------------------------------------------------------------------------------------------------
local defaults = T{ visible = true, minimized = false, mode = 1, x = 120, y = 220, w = 404, h = 300, idle = 20, size = 100, last_dps = 1 };
local s = settings.load(defaults, 'dps');

local ui = { open = { s.visible ~= false }, expanded = {}, place = true, font = nil,
             dbg = { seen = 0, errs = 0, last = nil, lines = 0, party = 0 } };   -- /dps debug counters

-- The Enmity tab of the meter: a click opens it, a second click goes back to the DPS view you had
if s.mode == 2 then s.mode = 1; end                                 -- (one damage view now: the old Total view is gone)
function ui.toggle_hate()
    if s.mode == 3 then
        s.mode = 1;
    else
        s.last_dps, s.mode = s.mode, 3;
    end
    settings.save('dps');
end

-- A segment holds everyone's damage: the current fight, or the whole session (total)
local function new_segment(t) return { start = t, last = t, sum = 0, actors = {}, done = 0, paused = 0 }; end
-- The numbers only start again when you RESET. A break of 20 s or more with no party damage (between monsters, resting)
-- isn't counted as fight time, so the DPS doesn't sink while you wait.
local BREAK = 20;
local function touch(seg, t)
    if t - seg.last >= BREAK then seg.paused = (seg.paused or 0) + (t - seg.last); end
    seg.last = t;
end
local meter = { fight = nil, total = new_segment(now()) };

-- Order the breakdown is shown in
local CATS = { 'Melee', 'Ranged', 'Weapon skill', 'Magic', 'Ability', 'Pet', 'Skillchain', 'Add. effect', 'Spikes' };

----------------------------------------------------------------------------------------------------
-- Combat log: action packet 0x28
----------------------------------------------------------------------------------------------------
-- Message ids that carry damage (hit / crit) or a miss. Which kind of damage it is comes from the packet category.
local HIT  = { [1] = 'hit', [67] = 'crit', [352] = 'hit', [353] = 'crit', [576] = 'hit', [577] = 'hit', [157] = 'hit',
               [185] = 'hit', [197] = 'hit', [264] = 'hit', [2] = 'hit', [252] = 'hit', [110] = 'hit', [317] = 'hit',
               [77] = 'hit', [522] = 'hit' };
local MISS = { [15] = true, [63] = true, [354] = true, [188] = true };
-- A spell on a monster that didn't land at all ("resists the spell", "completely resists"): counts against magic accuracy
local MRESIST = { [85] = true, [284] = true, [655] = true, [656] = true };
local CAT_OF = { [1] = 'Melee', [2] = 'Ranged', [3] = 'Weapon skill', [4] = 'Magic', [6] = 'Ability',
                 [11] = 'Pet', [13] = 'Pet', [14] = 'Ability', [15] = 'Ability' };
local SC_MSG = { [163] = 'Add. effect', [229] = 'Add. effect' };
for m = 288, 302 do SC_MSG[m] = 'Skillchain'; end
for m = 385, 388 do SC_MSG[m] = 'Skillchain'; end
for m = 767, 770 do SC_MSG[m] = 'Skillchain'; end

-- Weapon skill / spell / job ability names, looked up once
local names = {};
local function ability_name(cat, param)
    local key = cat .. ':' .. param;
    if names[key] ~= nil then return names[key] or nil; end
    names[key] = false;
    pcall(function()
        local rm, res = AshitaCore:GetResourceManager(), nil;
        if cat == 3 then res = rm:GetAbilityById(param);
        elseif cat == 4 then res = rm:GetSpellById(param);
        elseif cat == 6 or cat == 14 or cat == 15 then res = rm:GetAbilityById(param + 0x200); end
        if res ~= nil and res.Name ~= nil and res.Name[1] ~= nil and res.Name[1] ~= '' then names[key] = res.Name[1]; end
    end);
    return names[key] or nil;
end

-- Server id -> who gets the credit: you, your party / alliance (trusts included) and their pets
local function party_map()
    local map = {};
    local pm = AshitaCore:GetMemoryManager():GetParty();
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    for i = 0, 17 do
        if pm:GetMemberIsActive(i) == 1 then
            local sid = pm:GetMemberServerId(i);
            if sid ~= nil and sid ~= 0 then
                local who = { key = sid, name = pm:GetMemberName(i), job = pm:GetMemberMainJob(i), me = (i == 0), slot = i };
                map[sid] = { who = who };
                local idx = pm:GetMemberTargetIndex(i);
                if idx ~= nil and idx > 0 and idx < 0x900 then
                    pcall(function()                          -- a member far away can have no entity: skip their pet
                        local pidx = ent:GetPetTargetIndex(idx);
                        if pidx ~= nil and pidx > 0 then
                            local psid = ent:GetServerId(pidx);
                            if psid ~= nil and psid ~= 0 then map[psid] = { who = who, pet = true }; end
                        end
                    end);
                end
            end
        end
    end
    return map;
end

-- Monsters: NPC-range server ids (players are below 0x01000000) that aren't your party's trusts or pets.
-- Not by index: CatsEyeXI's Campaign monsters (e.g. Skrudningr, 01068804) use the 0x700+ indexes pets use.
local function is_mob(id, map)
    return id >= 0x01000000 and map[id] == nil;
end

local function add_stat(c, dmg, kind)
    if kind == 'miss' then
        c.miss = c.miss + 1;
    else
        c.dmg, c.hits = c.dmg + dmg, c.hits + 1;
        if kind == 'crit' then c.crits = c.crits + 1; end
        if dmg > c.max then c.max = dmg; end
    end
end

local function actor_of(seg, who)
    local a = seg.actors[who.key];
    if a == nil then
        a = { name = who.name, job = who.job, me = who.me, total = 0, cats = {}, abil = {} };
        seg.actors[who.key] = a;
    end
    if who.job and who.job > 0 then a.job = who.job; end
    return a;
end

local function add_to(seg, who, cat, dmg, kind, abil)
    local a = actor_of(seg, who);
    local c = a.cats[cat];
    if c == nil then c = { dmg = 0, hits = 0, crits = 0, miss = 0, max = 0 }; a.cats[cat] = c; end
    add_stat(c, dmg, kind);
    if kind ~= 'miss' then a.total, seg.sum = a.total + dmg, seg.sum + dmg; end
    if abil then
        local b = a.abil[abil];
        if b == nil then b = { cat = cat, dmg = 0, count = 0, max = 0, miss = 0 }; a.abil[abil] = b; end
        if kind == 'miss' then b.miss = b.miss + 1;
        else
            b.dmg, b.count = b.dmg + dmg, b.count + 1;
            if dmg > b.max then b.max = dmg; end
        end
    end
end

-- One damage line into the current fight and the session total
local function record(who, cat, dmg, kind, abil)
    ui.dbg.lines = ui.dbg.lines + 1;
    local t = now();
    local f = meter.fight;
    if f == nil then f = new_segment(t); meter.fight = f; end
    touch(f, t);
    touch(meter.total, t);
    add_to(f, who, cat, dmg, kind, abil);
    add_to(meter.total, who, cat, dmg, kind, abil);
end

-- Magic accuracy: one spell on one monster, landed or fully resisted (into the current fight and the session total)
local function record_macc(who, landed)
    local t0 = now();
    local f = meter.fight;
    if f == nil then f = new_segment(t0); meter.fight = f; end
    touch(f, t0);
    touch(meter.total, t0);
    for _, seg in ipairs({ f, meter.total }) do
        local a = actor_of(seg, who);
        a.macc = a.macc or { land = 0, miss = 0 };
        if landed then a.macc.land = a.macc.land + 1; else a.macc.miss = a.macc.miss + 1; end
    end
end

----------------------------------------------------------------------------------------------------
-- Enmity (an estimate). The server never sends enmity, so it's worked out with LandSandBoat's own rules
-- (enmity_container.cpp / battleutils.cpp; CatsEyeXI runs on LandSandBoat):
--   damage:   CE + 80 / m * dmg,  VE + 240 / m * dmg     m = floor(level * 31 / 50) + 6
--   cures:    CE + 40 / c * hp,   VE + 240 / c * hp      c = level + 10 / 20 + (level - 10) / 2 / 40 + 0.6 * (level - 50)
--   spells and job abilities: their fixed CE / VE (enmity_data.lua, from the server's tables)
--   first one on a monster: + 200 CE, + 900 VE
--   getting hit: CE - 1800 * dmg / your max HP
--   VE fades by 60 a second; CE and VE stop at 30000 each
-- Not known here: other players' enmity gear (taken as none), the monster's level (your level is used).
-- Who the monster is attacking right now is real, though: it comes from its own attack messages.
----------------------------------------------------------------------------------------------------
local lg = { f = nil, path = nil, t0 = 0, snap_t = 0, n = 0 };   -- the enmity log (/dps log), below
local hate = { mobs = {}, data = nil, CAP = 30000, last_tick = nil,
               CURE_MSG = { [7] = true, [263] = true, [367] = true } };   -- 367: HP restored by an area cure (Majesty)

function hate.load()
    hate.data = { spells = {}, abilities = {} };
    local fn = loadfile(addon.path .. '/enmity_data.lua');
    if fn == nil then return; end
    setfenv(fn, {});
    local ok, d = pcall(fn);
    if ok and type(d) == 'table' then hate.data = d; end
end

function hate.level()
    local lv = 75;
    pcall(function() lv = AshitaCore:GetMemoryManager():GetPlayer():GetMainJobLevel(); end);
    return (tonumber(lv) or 75) > 0 and lv or 75;
end

function hate.dmg_mod(lv) return math.floor(lv * 31 / 50) + 6; end
function hate.cure_mod(lv)
    if lv <= 10 then return lv + 10; end
    if lv <= 50 then return 20 + math.floor((lv - 10) / 2); end
    return math.floor(40 + 0.6 * (lv - 50));
end

-- The monster's entry (made on first sight), with its name from the game
-- The entity index of a server id: the quick guess from the id, else a search (Domain Invasion / Campaign monsters)
function hate.index_of(id)
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    local idx = bit.band(id, 0xFFF);
    if idx >= 0x900 then idx = idx - 0x100; end
    if idx < 0x900 and ent:GetServerId(idx) == id then return idx; end
    for i = 1, 0x8FF do
        if ent:GetServerId(i) == id then return i; end
    end
    return nil;
end

-- The monster's level and whether it's a notorious monster, from the mobdb addon's data (addons\mobdb\data\<zone>.lua),
-- read once per zone. Unknown monsters (e.g. CatsEyeXI's own Campaign ones) use your level, as before.
hate.zone_db = {};
function hate.mobdb(name)
    local zone = 0;
    pcall(function() zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0); end);
    if hate.zone_db[zone] == nil then
        hate.zone_db[zone] = false;
        pcall(function()
            local fn = loadfile(addon.path .. '/../mobdb/data/' .. tostring(zone) .. '.lua');
            if fn == nil then return; end
            setfenv(fn, {});
            local ok, d = pcall(fn);
            if ok and type(d) == 'table' and type(d.Names) == 'table' then hate.zone_db[zone] = d.Names; end
        end);
    end
    local names = hate.zone_db[zone];
    local e = names and names[name];
    if type(e) ~= 'table' then return nil, false; end
    local lo, hi = tonumber(e.MinLevel), tonumber(e.MaxLevel);
    local lv = (lo and hi) and math.floor((lo + hi) / 2 + 0.5) or lo or hi;
    return lv, e.Notorious == true;
end

function hate.name_mob(m)
    pcall(function()
        local idx = hate.index_of(m.id);
        if idx then
            local n = AshitaCore:GetMemoryManager():GetEntity():GetName(idx);
            if n and n ~= '' then m.name, m.idx = n, idx; end
        end
    end);
    if m.name ~= 'Monster' then m.level, m.nm = hate.mobdb(m.name); end
    m.name_t = now();
end

function hate.mob(id)
    local m = hate.mobs[id];
    if m == nil then
        m = { id = id, name = 'Monster', list = {}, target = nil, target_t = 0, last = now(), streak = 0 };
        hate.mobs[id] = m;
        hate.name_mob(m);
    elseif m.name == 'Monster' and now() - (m.name_t or 0) > 2 then
        hate.name_mob(m);                                     -- not loaded yet when first seen: try again
    end
    m.last = now();
    return m;
end

-- Out of range: the server gives no enmity to someone farther than 25 yalms from the monster (28 for a notorious one)
function hate.in_range(m, who)
    local ok, far = pcall(function()
        local ent = AshitaCore:GetMemoryManager():GetEntity();
        local pm = AshitaCore:GetMemoryManager():GetParty();
        local midx = m.idx or hate.index_of(m.id);
        local widx = pm:GetMemberTargetIndex(who.slot or 0);
        if not midx or not widx or widx == 0 then return false; end
        m.idx = midx;
        local dx = ent:GetLocalPositionX(midx) - ent:GetLocalPositionX(widx);
        local dy = ent:GetLocalPositionY(midx) - ent:GetLocalPositionY(widx);
        local dz = ent:GetLocalPositionZ(midx) - ent:GetLocalPositionZ(widx);
        return math.sqrt(dx * dx + dy * dy + dz * dz) > (m.nm and 28 or 25);
    end);
    return not (ok and far);
end

-- Learned from TARGET (see hate.correct): how much each player's enmity really counts, x1 to start
hate.calib = {};

function hate.add(m, who, ce, ve)
    if (ce > 0 or ve > 0) and not hate.in_range(m, who) then return; end
    local c = hate.calib[who.key] or 1;
    if ce > 0 then ce = ce * c; end
    if ve > 0 then ve = ve * c; end
    local e = m.list[who.key];
    if e == nil then
        if next(m.list) == nil then ce, ve = ce + 200, ve + 900; end
        e = { who = who, ce = 0, ve = 0 };
        m.list[who.key] = e;
    end
    e.who = who;
    e.ce = math.max(0, math.min(hate.CAP, e.ce + ce));
    e.ve = math.max(0, math.min(hate.CAP, e.ve + ve));
end

-- Paladins tanking with YunaGearOpt wear its PLD Enmity set for Provoke, Flash, Reprisal, Atonement and other job
-- abilities, and its Cure set (also Enmity+) for cures. That set comes to about +43 Enmity at level 75 (Ritter Gorget
-- +3, 2x Pluto's Earring +6, Odium Ring +4, Iron Ram Sallet +5, Vlr. Surcoat +1 +5, Vlr. Gauntlets +1 +4,
-- Cerb. Mantle +1 +4, Sattva Ring +3, Warwolf Belt +3, Kings Cuisses +3, Vlr. Leggings +1 +2, Charitoni Sling +1:
-- CatsEyeXI item stats). +40 is used, for PLDs not fully geared. The server multiplies enmity by (100 + Enmity) / 100.
-- Only for a main-job PLD, and only for those actions (melee is done in TP gear).
hate.PLD_ENMITY = 40;
function hate.bonus(who)
    if who and who.job == 7 then return (100 + hate.PLD_ENMITY) / 100; end
    return 1;
end

function hate.damage(id, who, dmg, mult)
    local m = hate.mob(id);
    local d = hate.dmg_mod(m.level or hate.level());          -- the monster's level when mobdb knows it
    dmg = math.max(1, dmg);
    mult = mult or 1;
    hate.add(m, who, 80 / d * dmg * mult, 240 / d * dmg * mult);
end

-- Buffs, cures and self-target abilities: every monster that already hates the caster or the one helped
function hate.on_lists(who, ce, ve, other_key)
    for _, m in pairs(hate.mobs) do
        if m.list[who.key] or (other_key and m.list[other_key]) then hate.add(m, who, ce, ve); end
    end
end

function hate.cure(who, target_key, hp)
    local c = hate.cure_mod(hate.level());
    local b = hate.bonus(who);                                -- a PLD cures in its Enmity+ Cure set
    hate.on_lists(who, 40 / c * hp * b, 240 / c * hp * b, target_key);
end

-- Self-correction. A monster's normal attacks go to whoever really has the most enmity. When it attacks the same
-- player twice in a row and the estimate has someone else above them, the estimate is wrong: that player is lifted to
-- the top, everyone wrongly above is brought just below, and the meter learns from it (their enmity counts x1.05 more,
-- the others' x0.95 less, from then on, kept for the session). TP moves don't count: some hit random players.
function hate.correct(m, victim)
    if m.streak_key == victim.key then m.streak = (m.streak or 0) + 1; else m.streak_key, m.streak = victim.key, 1; end
    if m.streak < 2 then return; end
    local e = m.list[victim.key];
    if e == nil then
        e = { who = victim, ce = 0, ve = 0 };
        m.list[victim.key] = e;
    end
    local mine = e.ce + e.ve;
    local wrong = false;
    for key, o in pairs(m.list) do
        if key ~= victim.key and o.ce + o.ve > mine * 1.02 and o.ce + o.ve - mine > 24 then
            wrong = true;
            -- learn "counts less" only for someone who isn't holding another monster right now: with two tanks,
            -- the one tanking elsewhere isn't over-estimated, they just aren't this monster's target
            local tanking = false;
            for _, m2 in pairs(hate.mobs) do
                if m2 ~= m and m2.target == key and now() - (m2.target_t or 0) < 12 then tanking = true; end
            end
            if not tanking then hate.calib[key] = math.max(0.3, (hate.calib[key] or 1) * 0.95); end
        end
    end
    if not wrong then return; end
    if lg.f then lg.snapshot(m, 'WRONG (monster keeps hitting ' .. tostring(victim.name) .. '), before the fix'); end
    hate.calib[victim.key] = math.min(3.0, (hate.calib[victim.key] or 1) * 1.05);
    -- lift the target (CE first: it doesn't fade), then bring anyone still above just under it
    local top = 0;
    for key, o in pairs(m.list) do if key ~= victim.key then top = math.max(top, o.ce + o.ve); end end
    local need = top * 1.01 - mine;
    if need > 0 then
        local add = math.min(need, hate.CAP - e.ce);
        e.ce = e.ce + add;
        e.ve = math.min(hate.CAP, e.ve + (need - add));
    end
    mine = e.ce + e.ve;
    for key, o in pairs(m.list) do
        local tot = o.ce + o.ve;
        if key ~= victim.key and tot >= mine then
            local k = (mine * 0.98) / tot;
            o.ce, o.ve = o.ce * k, o.ve * k;
        end
    end
    if lg.f then lg.snapshot(m, 'after the fix'); end
end

-- The monster hit a party member: that's who it's attacking, and they lose some CE.
-- melee = a normal attack (category 1), used for the self-correction.
function hate.hit_taken(id, victim, dmg, melee)
    local m = hate.mob(id);
    local switched = m.target ~= victim.key;
    if switched and lg.f then lg.snapshot(m, 'before target -> ' .. tostring(victim.name)); end
    m.target, m.target_t = victim.key, now();
    if melee then hate.correct(m, victim); end
    if switched and lg.f then lg.snapshot(m, 'after'); end
    if dmg <= 0 then return; end
    local maxhp = 0;
    pcall(function()
        local pm = AshitaCore:GetMemoryManager():GetParty();
        local hp, hpp = pm:GetMemberHP(victim.slot or 0), pm:GetMemberHPPercent(victim.slot or 0);
        if hpp and hpp > 0 then maxhp = hp * 100 / hpp; end
    end);
    if maxhp <= 0 then return; end
    local e = m.list[victim.key];
    if e then e.ce = math.max(0, e.ce - 1800 * dmg / maxhp); end
end

-- Once a frame: VE fades (60 a second); monsters nobody touched for 90 seconds are dropped
function hate.tick()
    local t = now();
    local dt = hate.last_tick and (t - hate.last_tick) or 0;
    hate.last_tick = t;
    -- a party member who is KO'd loses all their enmity (the server wipes it), checked twice a second
    if t - (hate.dead_check or 0) > 0.5 then
        hate.dead_check = t;
        pcall(function()
            local pm = AshitaCore:GetMemoryManager():GetParty();
            for i = 0, 17 do
                if pm:GetMemberIsActive(i) == 1 and pm:GetMemberHPPercent(i) == 0 and pm:GetMemberHP(i) == 0 then
                    local sid = pm:GetMemberServerId(i);
                    if sid and sid ~= 0 then for _, m in pairs(hate.mobs) do m.list[sid] = nil; end end
                end
            end
        end);
    end
    for id, m in pairs(hate.mobs) do
        if t - m.last > 90 then
            hate.mobs[id] = nil;
        elseif dt > 0 then
            for _, e in pairs(m.list) do e.ve = math.max(0, e.ve - 60 * dt); end
        end
    end
end

-- The monster to show: your target if it's one we know, else the one fought most recently
function hate.focus()
    local tid = nil;
    pcall(function()
        local idx = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0);
        if idx and idx > 0 then tid = AshitaCore:GetMemoryManager():GetEntity():GetServerId(idx); end
    end);
    if tid and hate.mobs[tid] and next(hate.mobs[tid].list) then return hate.mobs[tid]; end
    local best = nil;
    for _, m in pairs(hate.mobs) do
        if next(m.list) and (best == nil or m.last > best.last) then best = m; end
    end
    return best;
end

-- Its list, biggest first: { who, ce, ve, total, target }
function hate.rows(m)
    local out = {};
    if m == nil then return out; end
    local tgt = (m.target and now() - m.target_t < 12) and m.target or nil;
    for key, e in pairs(m.list) do
        table.insert(out, { who = e.who, name = e.who.name, job = e.who.job, me = e.who.me, ce = e.ce, ve = e.ve,
                            total = e.ce + e.ve, target = key == tgt });
    end
    -- Ties go to the monster's current target, like the server (GetHighestEnmity): at the cap (30000 CE + 30000 VE)
    -- the tank and the nukers are all equal, and the tank keeps it. "Equal" = within one VE fade step (24).
    table.sort(out, function(a, b)
        if math.abs(a.total - b.total) <= 24 and a.target ~= b.target then return a.target; end
        return a.total > b.total;
    end);
    return out;
end

-- Abilities whose server script moves enmity instead of adding it (LandSandBoat scripts/globals/job_utils):
--   Enmity Douse (BLM, 272): your enmity on that monster -30% (CatsEyeXI; standard LandSandBoat sets it to CE 1, VE 0)
--   High Jump (DRG, 67): your enmity on it -50% (DRG main job) or -30% (DRG sub)
--   Super Jump (DRG, 68): your enmity on every monster -> CE 1, VE 0
--   Accomplice (THF, 84) / Collaborator (THF, 236): 50% / 25% of the party member's enmity moves to the thief
function hate.special(ja, who, target)
    if ja == 272 then
        local m = hate.mobs[target];
        local e = m and m.list[who.key];
        if e then e.ce, e.ve = e.ce * 0.7, e.ve * 0.7; end
    elseif ja == 67 then
        local m = hate.mobs[target];
        local e = m and m.list[who.key];
        if e then
            local k = (who.job == 14) and 0.5 or 0.3;
            e.ce, e.ve = e.ce * (1 - k), e.ve * (1 - k);
        end
    elseif ja == 68 then
        for _, m in pairs(hate.mobs) do
            local e = m.list[who.key];
            if e then e.ce, e.ve = 1, 0; end
        end
    elseif ja == 84 or ja == 236 then
        local k = (ja == 84) and 0.5 or 0.25;
        for _, m in pairs(hate.mobs) do
            local e = m.list[target];
            if e and target ~= who.key then
                local ce, ve = e.ce * k, e.ve * k;
                e.ce, e.ve = e.ce - ce, e.ve - ve;
                hate.add(m, who, ce, ve);
            end
        end
    end
end

-- Jumps arrive as weaponskill-type actions (category 3) carrying the job ability's id and a job ability message
local JUMP_MSG = { [0] = true, [110] = true, [158] = true, [324] = true };

----------------------------------------------------------------------------------------------------
-- Enmity log (/dps log): a text file a tester can send so the enmity estimate can be checked against what really
-- happened. It holds the party (jobs, levels), every action on a monster, cures / buffs on the party, what the
-- monster does (who it hits), a snapshot of the estimate whenever the monster changes target (and every 10 s while
-- fighting), KOs and kills. Written to addons\yunadps\logs\enmity_<date>_<time>.txt
----------------------------------------------------------------------------------------------------

function lg.w(text)
    if lg.f == nil then return; end
    lg.f:write(string.format('%8.2f  %s\n', now() - lg.t0, text));
    lg.n = lg.n + 1;
    if lg.n % 20 == 0 then lg.f:flush(); end
end

local function hex(id) return string.format('%08X', id or 0); end

-- Name of a server id: party member (with job), a known monster, else the id
function lg.name(id, map)
    local e = map and map[id];
    if e then
        local j = JOBS[e.who.job or 0] or '?';
        return e.pet and (e.who.name .. "'s pet") or (e.who.name .. '(' .. j .. ')');
    end
    local m = hate.mobs[id];
    if m then return m.name .. '[' .. hex(id) .. ']'; end
    return hex(id);
end

-- The estimate on one monster: top 5 with CE / VE and what the meter learned
function lg.snapshot(m, why)
    if lg.f == nil or m == nil then return; end
    local parts = {};
    for i, r in ipairs(hate.rows(m)) do
        if i > 5 then break; end
        local c = hate.calib[r.who and r.who.key or 0] or 1;
        table.insert(parts, string.format('%d.%s %d(CE %d VE %d%s)%s', i, r.name, math.floor(r.total), math.floor(r.ce),
            math.floor(r.ve), math.abs(c - 1) > 0.01 and string.format(' x%.2f', c) or '', r.target and ' TARGET' or ''));
    end
    lg.w(string.format('ESTIMATE %s on %s[%s] lv %s: %s', why, m.name, hex(m.id), tostring(m.level or '?'), table.concat(parts, ', ')));
end

function lg.start()
    local install = addon.path .. '/logs/';
    pcall(function() if ashita.fs and ashita.fs.create_directory then ashita.fs.create_directory(install); end end);
    local f = io.open(install .. '.probe', 'w');
    if f then f:close(); os.remove(install .. '.probe'); else pcall(os.execute, 'mkdir "' .. install:gsub('/', '\\'):gsub('\\$', '') .. '"'); end
    lg.path = install .. os.date('enmity_%Y%m%d_%H%M%S.txt');
    lg.f = io.open(lg.path, 'w');
    if lg.f == nil then lg.path = addon.path .. '/' .. os.date('enmity_%Y%m%d_%H%M%S.txt'); lg.f = io.open(lg.path, 'w'); end
    if lg.f == nil then return false; end
    lg.t0, lg.n = now(), 0;
    lg.f:write(string.format('YunaDPS %s enmity log, %s\n', tostring(addon.version), os.date('%Y-%m-%d %H:%M:%S')));
    pcall(function()
        local pm = AshitaCore:GetMemoryManager():GetParty();
        lg.f:write(string.format('zone %s, your level %s\nparty / alliance:\n', tostring(pm:GetMemberZone(0)), tostring(hate.level())));
        for i = 0, 17 do
            if pm:GetMemberIsActive(i) == 1 and pm:GetMemberServerId(i) ~= 0 then
                lg.f:write(string.format('  %s  %s%s/%s%s  %s\n', pm:GetMemberName(i), JOBS[pm:GetMemberMainJob(i)] or '?',
                    tostring(pm:GetMemberMainJobLevel(i)), JOBS[pm:GetMemberSubJob(i)] or '?', tostring(pm:GetMemberSubJobLevel(i)),
                    hex(pm:GetMemberServerId(i))));
            end
        end
    end);
    lg.f:write('columns: seconds  what\n');
    lg.f:flush();
    return true;
end

function lg.stop()
    if lg.f then lg.w('log stopped'); lg.f:close(); end
    lg.f = nil;
end

-- One action line: who, category / id / name, on whom, message, number, extra effect
function lg.action(actor, cat, param, abil, target, m, p, ae_m, ae_p, map)
    local what = ({ [1] = 'melee', [2] = 'ranged', [3] = 'WS', [4] = 'spell', [6] = 'ability', [11] = 'mob TP move',
                    [13] = 'pet ability', [14] = 'ability', [15] = 'ability' })[cat] or ('cat ' .. cat);
    lg.w(string.format('%s %s %s%s -> %s  msg %d  %d%s', lg.name(actor, map), what, tostring(param),
        abil and (' ' .. abil) or '', lg.name(target, map), m, p, (ae_m and ae_m > 0) and string.format('  +effect msg %d %d', ae_m, ae_p) or ''));
end


local function parse_action(e)
    local raw, pos = e.data_raw or e.data, 40;
    local max = (tonumber(e.size) or (type(e.data) == 'string' and #e.data) or 0) * 8;
    local function bits(n)
        if pos + n > max then error('short packet'); end
        local v = ashita.bits.unpack_be(raw, 0, pos, n);
        pos = pos + n;
        return v;
    end
    local actor = bits(32);
    local targets = bits(10);
    local cat = bits(4);
    local param = bits(16);
    bits(16); bits(32);                                       -- unknown, recast
    local map = party_map();
    local src = map[actor];
    if src then ui.dbg.party = ui.dbg.party + 1; end
    local base = CAT_OF[cat];
    if src and src.pet then base = 'Pet'; end
    local abil = (src and not src.pet) and ability_name(cat, param) or nil;

    -- Enmity: the fixed CE / VE of this spell or job ability (added once per action)
    local fixed = nil;
    if src and not src.pet and hate.data then
        if cat == 4 then fixed = hate.data.spells[param];
        elseif cat == 6 or cat == 14 or cat == 15 then fixed = hate.data.abilities[param]; end
    end

    local first_target, special, ja3_seen = nil, nil, false;
    if src and not src.pet and (cat == 6 or cat == 14 or cat == 15) then special = param; end

    for _ = 1, targets do
        local target = bits(32);
        local count = bits(4);
        first_target = first_target or target;
        for _ = 1, count do
            bits(5); bits(11); bits(5); bits(6);              -- reaction, animation, effect, stagger
            local p = bits(17);
            local m = bits(10);
            bits(31);
            local ae_p, ae_m, sp_p, sp_m = 0, 0, 0, 0;
            if bits(1) == 1 then bits(6); bits(4); ae_p = bits(17); ae_m = bits(10); end
            if bits(1) == 1 then bits(6); bits(4); sp_p = bits(14); sp_m = bits(10); end
            if cat == 3 and src and not src.pet and JUMP_MSG[m] then
                -- a Jump / High Jump / Super Jump, not a weaponskill: file it under Ability with its real name
                base, abil, special = 'Ability', ability_name(6, param), param;
                -- its fixed enmity too (Shield Bash 450 / 900, Weapon Bash...), once per action
                if not ja3_seen then ja3_seen = true; fixed = hate.data and hate.data.abilities[param] or nil; end
            end
            if src and base and is_mob(target, map) then
                local kind = HIT[m];
                if kind then record(src.who, base, p, kind, abil);
                elseif MISS[m] then record(src.who, base, 0, 'miss', abil); end
                local extra = SC_MSG[ae_m];
                if extra and ae_p > 0 then record(src.who, extra, ae_p, 'hit', nil); end
                if cat == 4 and not src.pet then record_macc(src.who, not MRESIST[m]); end
            elseif src == nil and is_mob(actor, map) and map[target] and sp_m == 44 and sp_p > 0 then
                record(map[target].who, 'Spikes', sp_p, 'hit', nil);   -- your spikes hit the monster
            end

            -- Enmity
            if src and not src.pet then
                if is_mob(target, map) then
                    if HIT[m] and cat ~= 11 and cat ~= 13 then
                        -- Atonement: a PLD's weaponskill done in the Enmity set
                        hate.damage(target, src.who, p, (cat == 3 and abil == 'Atonement') and hate.bonus(src.who) or 1);
                    end
                    if SC_MSG[ae_m] and ae_p > 0 then hate.damage(target, src.who, ae_p); end
                    if fixed then local b = hate.bonus(src.who); hate.add(hate.mob(target), src.who, fixed[1] * b, fixed[2] * b); fixed = nil; end
                elseif map[target] and not map[target].pet then
                    if cat == 4 and hate.CURE_MSG[m] and p > 0 then hate.cure(src.who, target, p); end
                    if fixed then local b = hate.bonus(src.who); hate.on_lists(src.who, fixed[1] * b, fixed[2] * b, target); fixed = nil; end
                end
            elseif src == nil and is_mob(actor, map) and map[target] and not map[target].pet and (cat == 1 or cat == 11) then
                hate.hit_taken(actor, map[target].who, HIT[m] and p or 0, cat == 1);
            end

            if lg.f and (src or (is_mob(actor, map) and map[target])) and cat ~= 7 and cat ~= 8 and cat ~= 9 and cat ~= 12 then
                lg.action(actor, cat, param, abil, target, m, p, ae_m, ae_p, map);
            end
        end
    end

    -- After the action's own damage / fixed enmity: Enmity Douse, High / Super Jump, Accomplice, Collaborator
    if special and first_target then hate.special(special, src.who, first_target); end
end

----------------------------------------------------------------------------------------------------
-- Numbers for the window
----------------------------------------------------------------------------------------------------
local function segment()
    return meter.fight;
end

-- Seconds of fighting: it ticks while damage is coming in and holds still during a break (see BREAK).
local function duration(seg)
    if seg == nil then return 1; end
    local t = now();
    local upto = (t - seg.last >= BREAK) and seg.last or t;
    return math.max(1, upto - seg.start - (seg.paused or 0));
end

local function sorted_actors(seg)
    local list = {};
    if seg == nil then return list; end
    for _, a in pairs(seg.actors) do if a.total > 0 then table.insert(list, a); end end
    table.sort(list, function(a, b) return a.total > b.total; end);
    return list;
end

-- Everyone in your party and alliance who is in your zone, shown even before they've done any damage
local function roster_rows(seg)
    local list = sorted_actors(seg);
    local seen = {};
    for _, a in ipairs(list) do seen[a.name or ''] = true; end
    local extra = {};
    pcall(function()
        local pm = AshitaCore:GetMemoryManager():GetParty();
        local zone = pm:GetMemberZone(0);
        for i = 0, 17 do
            if pm:GetMemberIsActive(i) == 1 and pm:GetMemberServerId(i) ~= 0 and (i == 0 or pm:GetMemberZone(i) == zone) then
                local name = pm:GetMemberName(i);
                if name ~= nil and name ~= '' and not seen[name] then
                    seen[name] = true;
                    table.insert(extra, { name = name, job = pm:GetMemberMainJob(i), me = (i == 0), total = 0, cats = {}, abil = {} });
                end
            end
        end
    end);
    table.sort(extra, function(a, b)
        if a.me ~= b.me then return a.me; end
        return a.name < b.name;
    end);
    for _, a in ipairs(extra) do table.insert(list, a); end
    return list;
end

local function my_dps()
    local seg = segment();
    if seg == nil then return 0; end
    for _, a in pairs(seg.actors) do if a.me then return a.total / duration(seg); end end
    return 0;
end

local function reset()
    meter.fight, meter.total = nil, new_segment(now());
    hate.mobs = {};
    ui.expanded = {};
end

----------------------------------------------------------------------------------------------------
-- Living logo (the same glow and sparkle as YunaGearOpt's header)
----------------------------------------------------------------------------------------------------
local fx = {};
function fx.time()
    local ok, t = pcall(imgui.GetTime);
    return (ok and type(t) == 'number') and t or os.clock();
end

function fx.glow(dl, cx, cy, r, col, a)
    for i = 4, 1, -1 do
        dl:AddCircleFilled({ cx, cy }, r * i / 4, u32({ col[1], col[2], col[3], a * 0.32 }), 24);
    end
end

function fx.star(dl, cx, cy, sz, a)
    local c, k = u32({ 1, 1, 0.92, a }), sz * 0.22;
    dl:AddTriangleFilled({ cx - sz, cy }, { cx, cy - k }, { cx, cy + k }, c);
    dl:AddTriangleFilled({ cx + sz, cy }, { cx, cy + k }, { cx, cy - k }, c);
    dl:AddTriangleFilled({ cx, cy - sz }, { cx + k, cy }, { cx - k, cy }, c);
    dl:AddTriangleFilled({ cx, cy + sz }, { cx - k, cy }, { cx + k, cy }, c);
end

-- Behind the logo: a breathing glow, blue at rest, faster and warmer while a fight is on
function fx.back(dl, x, y, w, h, hov, fighting)
    local t = fx.time();
    local p = 0.5 + 0.5 * math.sin(t * (fighting and 4.0 or 1.4));
    local col = fighting and { 1.0, 0.30, 0.25 } or { 0.85, 0.20, 0.22 };   -- red, like the blood on the blade
    fx.glow(dl, x + 0.55 * w, y + 0.50 * h, w * (0.40 + 0.03 * p), col, (hov and 0.14 or 0.05) + 0.05 * p);   -- a soft halo behind the samurai
end

-- In front: a glint running down the katana (hilt -> tip), and a little star when it reaches the tip
function fx.front(dl, x, y, w, h, hov)
    local t = fx.time();
    local function at(fx_, fy) return x + fx_ * w, y + fy * h; end
    local period = hov and 2.2 or 4.5;
    local ph = t % period;
    if ph < 0.55 then
        local u = ph / 0.55;
        local gx, gy = at(0.27 + (0.95 - 0.27) * u, 0.38 + (0.90 - 0.38) * u);
        fx.glow(dl, gx, gy, w * 0.05, { 0.88, 0.75, 1.0 }, 0.55);
        dl:AddCircleFilled({ gx, gy }, w * 0.012, u32({ 1, 1, 1, 0.9 }), 12);
    elseif ph < 0.95 then
        local a = 1 - (ph - 0.55) / 0.4;
        local tx, ty = at(0.95, 0.90);
        fx.star(dl, tx, ty, 2 + 5 * a, a);
    end
end

-- A row's bar: pink to violet like YunaUI's HP bars, a thin bright line at its end
function fx.bar(dl, x, y, w, h, frac, a)
    local fw = math.max(Z(4), w * math.max(0, math.min(1, frac)));
    local ok = pcall(function()
        dl:AddRectFilledMultiColor({ x, y }, { x + fw, y + h }, u32({ C.hp[1], C.hp[2], C.hp[3], a }), u32({ C.mp2[1], C.mp2[2], C.mp2[3], a }),
            u32({ C.mp2[1], C.mp2[2], C.mp2[3], a }), u32({ C.hp[1], C.hp[2], C.hp[3], a }));
    end);
    if not ok then dl:AddRectFilled({ x, y }, { x + fw, y + h }, u32({ C.mp2[1], C.mp2[2], C.mp2[3], a }), Z(6)); end
    dl:AddRectFilled({ x + fw - 2, y + 2 }, { x + fw, y + h - 2 }, u32({ 1, 0.92, 1, 0.85 }));
end
-- Draw the logo at the cursor, with its effects. Returns true while the mouse is on it.
local function draw_logo(size, hov, fighting)
    local yg = logo_texture('yunadps_violet.png') or logo_texture('yunadps.png');
    if yg == nil then
        imgui.Dummy({ size, size });
        return imgui.IsItemHovered();
    end
    local dl = imgui.GetWindowDrawList();
    local gx, gy = imgui.GetCursorScreenPos();
    imgui.Image(yg.ptr, { size, size });
    local h = imgui.IsItemHovered();
    pcall(fx.front, dl, gx, gy, size, size, hov);
    return h;
end

----------------------------------------------------------------------------------------------------
-- Font (Segoe UI like YunaGearOpt)
----------------------------------------------------------------------------------------------------
-- The font: YunaUI's AvantGarde (its fonts are shared through YUI_FONTS; the meter adds none of its own, which used to
-- fill the game's font texture and shrink everything back to the small default font)
local function load_font() ui.font, ui.font_px = nil, nil; end

local function push_font()
    if ui.font == nil and type(YUI_FONTS) == 'table' and YUI_FONTS.sized and YUI_FONTS.sized.chat then
        local pick = nil;                                     -- the smallest one made at 16 px or more (sharp at 16)
        for _, e in ipairs(YUI_FONTS.sized.chat) do
            if pick == nil and e[2] >= 16 then pick = e; end
        end
        pick = pick or YUI_FONTS.sized.chat[#YUI_FONTS.sized.chat];
        if pick then ui.font, ui.font_px = pick[1], pick[2]; end
    end
    local f = ui.font;
    if f == nil then return false; end
    local ok = false;
    if YUI_NEWFONT(f) then
        ok = pcall(imgui.PushFont, f, 16);                    -- newer ImGui draws fonts at any size itself
        scale.f = 1;
    else
        ok = pcall(imgui.PushFont, f);
        scale.f = ok and (16 / (ui.font_px or 16)) or 1;      -- shown at 16 whatever size it was made at
    end
    return ok;
end

----------------------------------------------------------------------------------------------------
-- Report: the top five into party / linkshell chat (only when you click the logo or type /dps report)
----------------------------------------------------------------------------------------------------
local function report(channel)
    local seg = segment();
    local list = sorted_actors(seg);
    if #list == 0 then msg('Nothing to report yet.'); return; end
    local dur = duration(seg);
    -- No '%' sign: the game rejects a chat line with one ("A command error occurred"). The lines go out one by one
    -- (ui.chat_queue, sent from d3d_present) so the game's chat doesn't drop any for coming too fast.
    ui.chat_queue = { string.format('/%s [Damage Meter] %s  %s dmg', channel, clock_text(dur), fmt(seg.sum)) };
    for i, a in ipairs(list) do
        if i > 5 then break; end
        -- damage, then accuracy (melee + ranged swings that hit) and magic accuracy (spells that landed), when there are any
        local line = string.format('/%s %d. %s  %s dmg', channel, i, a.name, fmt(a.total));
        local hits, swings = 0, 0;
        for _, cat in ipairs({ 'Melee', 'Ranged' }) do
            local c = a.cats[cat];
            if c then hits, swings = hits + c.hits, swings + c.hits + c.miss; end
        end
        if swings > 0 then line = line .. string.format('  Acc %d', math.floor(hits / swings * 100 + 0.5)); end
        local mc = a.macc;
        if mc and mc.land + mc.miss > 0 then line = line .. string.format('  MAcc %d', math.floor(mc.land / (mc.land + mc.miss) * 100 + 0.5)); end
        table.insert(ui.chat_queue, line);
    end
    ui.chat_next = 0;
end

-- Send the next queued report line, one every 1.2 seconds
local function send_chat_queue()
    local q = ui.chat_queue;
    if q == nil or #q == 0 or now() < (ui.chat_next or 0) then return; end
    AshitaCore:GetChatManager():QueueCommand(1, table.remove(q, 1));
    ui.chat_next = now() + 1.2;
end

----------------------------------------------------------------------------------------------------
-- UI: the meter window
----------------------------------------------------------------------------------------------------
local W = 380;   -- inside width of the meter (follows the window when you resize it)

local function fighting()
    local f = meter.fight;
    return f ~= nil and now() - f.last < BREAK;
end

-- Post the top 5 (party, linkshell, linkshell 2): opened by a right click anywhere on the meter, or a click on its title
function fx.report_menu(id)
    ui.report_open = false;
    if imgui.BeginPopup(id) then
        ui.report_open = true;
        imgui.TextColored(C.muted, 'Post the top 5');
        imgui.Separator();
        if imgui.Selectable('Party chat') then report('p'); end
        if imgui.Selectable('Linkshell chat') then report('l'); end
        if imgui.Selectable('Linkshell 2 chat') then report('l2'); end
        imgui.EndPopup();
    end
end
-- The top line: the view's name (click it to post the meter in chat) and the fight's clock; on the right the view
-- menu, Enmity, - and X, each as wide as its text
local function draw_header()
    local dl = imgui.GetWindowDrawList();
    local ox, oy = imgui.GetCursorPos();
    local H = Z(30);
    local ww = imgui.GetWindowWidth();
    local seg = segment();
    local title = (s.mode == 3) and 'ENMITY' or 'DAMAGE';
    -- the buttons' places first (right side), so the title can see whether it fits beside them
    local right = ww - Z(12);
    local bw = Z(28);
    local x_close = right - bw;
    local x_min = x_close - bw - Z(2);
    local enw = text_w('Enmity') + Z(26);
    local x_enm = x_min - Z(10) - enw;
    local cw = text_w('Reset') + Z(26);                           -- the Reset button
    local x_cb = x_enm - Z(8) - cw;
    local need = text_w(title) + ((seg and s.mode ~= 3) and (Z(10) + text_w('00:00')) or 0) + Z(14) + Z(28);   -- (+ the anchor)
    local two = (ox + need > x_cb);                           -- too narrow: title on a line of its own
    local ty = two and (oy + Z(34)) or (oy + Z(5));
    if two then H = Z(58); end
    imgui.SetCursorPos({ ox, ty });
    local tcol = fx.lit('col_title', C.gold, 'bright_title');        -- YunaUI > ADDONS: colour + brightness
    local tsx, tsy = imgui.GetCursorScreenPos();
    for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { 1, 1 } }) do put_text(tsx + d[1], tsy + d[2], { 0, 0, 0, 0.9 }, title); end
    imgui.TextColored(tcol, title);
    if imgui.IsItemHovered() and not ui.report_open then
        imgui.SetTooltip('Damage Meter\nClick (or right click anywhere) to post the meter in party or linkshell chat.');
    end
    if imgui.IsItemClicked() then imgui.OpenPopup('##ydps_report'); end
    if seg and s.mode ~= 3 then imgui.SameLine(0, Z(10)); imgui.TextColored(C.muted, clock_text(duration(seg))); end
    imgui.SameLine(0, Z(4));
    fx.anchor_button('##ym_anchor', imgui.GetTextLineHeight());
    fx.report_menu('##ydps_report');

    imgui.SetCursorPos({ x_cb, oy + Z(3) });                -- RESET: the numbers only start again when you press it
    imgui.PushStyleColor(ImGuiCol_Button, { 0.74, 0.66, 0.95, 0.12 });
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.74, 0.66, 0.95, 0.28 });
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.74, 0.66, 0.95, 0.40 });
    imgui.PushStyleColor(ImGuiCol_Text, { 0.86, 0.82, 1.0, 1 });
    if imgui.Button('Reset##ym_reset', { cw, Z(24) }) then reset(); end
    imgui.PopStyleColor(4);
    if imgui.IsItemHovered() then
        local dur = duration(seg);
        imgui.SetTooltip(string.format('Clear every number and start again.%s',
            seg and string.format('\nNow: %s  |  %s dmg  |  party %s DPS', clock_text(dur), fmt(seg.sum), fmt(seg.sum / dur)) or ''));
    end

    local on = s.mode == 3;                                   -- ENMITY: lit while open; a second click goes back
    imgui.SetCursorPos({ x_enm, oy + Z(3) });
    imgui.PushStyleColor(ImGuiCol_Button, on and { 1.0, 0.36, 0.62, 0.55 } or { 1.0, 0.36, 0.62, 0.12 });
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, on and { 1.0, 0.36, 0.62, 0.70 } or { 1.0, 0.36, 0.62, 0.25 });
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { 1.0, 0.36, 0.62, 0.80 });
    imgui.PushStyleColor(ImGuiCol_Text, on and { 1, 1, 1, 1 } or { 1.0, 0.70, 0.82, 1 });
    if imgui.Button('Enmity##ym_hate', { enw, Z(24) }) then ui.toggle_hate(); end
    imgui.PopStyleColor(4);
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Estimated enmity on your target (or the last monster fought).\nShows who the monster is attacking right now.');
    end

    imgui.SetCursorPos({ x_min, oy + Z(3) });
    if fx.icon_button('##ym_min', '-', { bw, Z(24) }) then s.minimized, ui.place = true, true; settings.save('dps'); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Shrink to the top 3'); end
    imgui.SetCursorPos({ x_close, oy + Z(3) });
    if fx.icon_button('##ym_close', 'x', { bw, Z(24) }) then ui.open[1] = false; s.visible = false; settings.save('dps'); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Hide (type /dps to bring it back)'); end

    imgui.SetCursorPos({ ox, oy + H });
    local x, y = imgui.GetCursorScreenPos();
    dl:AddRectFilled({ x, y + 1 }, { x + W, y + 2 }, u32(C.line));
    imgui.Dummy({ W, Z(6) });
end

-- One player's breakdown: each kind of damage, then their weapon skills / spells / abilities
local function draw_details(a)
    local x0 = imgui.GetCursorPosX() + Z(10);
    imgui.SetWindowFontScale(0.86);
    local c2x = x0 + text_w('Weapon Skill  ') + Z(10);         -- the columns leave room for their words
    local c3x = c2x + text_w('00,000 (100%)') + Z(14);
    local dcol = fx.lit('col_detail', { 0.88, 0.84, 1.00, 1 }, 'bright_detail');   -- YunaUI > ADDONS: colour + brightness
    local dsoft = { dcol[1] * 0.82, dcol[2] * 0.82, dcol[3] * 0.82, 1 };
    local lh = imgui.GetTextLineHeight() + Z(3);
    local function cols(c1, c2, c3, head)
        imgui.SetCursorPosX(x0);
        local sx, sy = imgui.GetCursorScreenPos();
        fx.otext(sx, sy, head and dcol or dsoft, c1);
        fx.otext(sx + (c2x - x0), sy, head and dcol or dsoft, c2);
        fx.otext(sx + (c3x - x0), sy, dsoft, c3);
        imgui.Dummy({ W - Z(10), lh });
    end
    for _, cat in ipairs(CATS) do
        local c = a.cats[cat];
        if c and (c.dmg > 0 or c.miss > 0) then
            local pct = a.total > 0 and c.dmg / a.total * 100 or 0;
            local swings = c.hits + c.miss;
            local info;
            if cat == 'Melee' or cat == 'Ranged' then
                info = string.format('acc %d%%  crit %d%%  avg %s  max %s',
                    swings > 0 and math.floor(c.hits / swings * 100 + 0.5) or 0,
                    c.hits > 0 and math.floor(c.crits / c.hits * 100 + 0.5) or 0,
                    fmt(c.hits > 0 and c.dmg / c.hits or 0), fmt(c.max));
            else
                info = string.format('x%d  avg %s  max %s', c.hits, fmt(c.hits > 0 and c.dmg / c.hits or 0), fmt(c.max));
                if c.miss > 0 then info = info .. string.format('  miss %d', c.miss); end
            end
            cols(cat, string.format('%s (%d%%)', fmt(c.dmg), math.floor(pct + 0.5)), info, true);
            -- the named moves of this kind, biggest first
            local list = {};
            for n, b in pairs(a.abil) do if b.cat == cat and (b.dmg > 0 or b.miss > 0) then table.insert(list, { n = n, b = b }); end end
            table.sort(list, function(p, q) return p.b.dmg > q.b.dmg; end);
            for i, e in ipairs(list) do
                if i > 6 then break; end
                local b = e.b;
                local extra = string.format('x%d  avg %s  max %s', b.count, fmt(b.count > 0 and b.dmg / b.count or 0), fmt(b.max));
                if b.miss > 0 then extra = extra .. string.format('  miss %d', b.miss); end
                cols('  ' .. e.n, fmt(b.dmg), extra);
            end
        end
    end
    imgui.SetWindowFontScale(1.0);
    imgui.Dummy({ W, 4 });
end

-- Text with a thin dark edge (like YunaUI's bars), and a thin glowing bar (like YunaUI's pet bar)
local OUT8 = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 }, { 1, 2 } };
function fx.otext(x, y, col, text)                                 -- a full dark edge round every letter (+ a little drop)
    for _, d in ipairs(OUT8) do put_text(x + d[1], y + d[2], { 0, 0, 0, 0.92 * (col[4] or 1) }, text); end
    put_text(x, y, col, text);
end
-- a soft dark shadow behind the meter (strength: s.backdrop, YunaUI > ADDONS): many rounded layers, each a little
-- smaller and adding a little darkness, so it fades smoothly on every side and corner. Drawn behind the windows, so
-- no window edge cuts it off.
function fx.backdrop(dl, x, y, w, h, a)
    if a <= 0.01 then return; end
    local bg = dl;
    pcall(function() bg = imgui.GetBackgroundDrawList() or dl; end);
    local f = math.min(Z(16), math.min(w, h) * 0.2);                -- a short soft edge: the rest is all shadow
    local n = 10;
    a = math.min(0.97, a);
    local prev = 0;                                                 -- the darkness reached so far (outside in)
    for k = 0, n - 1 do
        local t = (k + 1) / n;
        local want = a * t * t * (3 - 2 * t);                       -- eases in: almost nothing at the edge, full inside
        local per = (want - prev) / math.max(0.001, 1 - prev);
        prev = want;
        local ins = f * (k / n);
        local x1, y1, x2, y2 = x + ins, y + ins, x + w - ins, y + h - ins;
        if x2 > x1 and y2 > y1 and per > 0 then
            bg:AddRectFilled({ x1, y1 }, { x2, y2 }, u32({ 0.02, 0.015, 0.03, per }), math.max(2, Z(12) - ins * 0.5));
        end
    end
end
-- the resize corner: two short light strokes in the shadow's bottom-right corner (ImGui's own grip sits under it)
function fx.grip(x, y, w, h, hov)
    local fg = imgui.GetWindowDrawList();
    local cx, cy = x + w - Z(8), y + h - Z(8);
    local col = u32({ 0.86, 0.80, 1.00, hov and 0.95 or 0.55 });
    fg:AddLine({ cx - Z(10), cy }, { cx, cy - Z(10) }, col, 1.5);
    fg:AddLine({ cx - Z(5), cy }, { cx, cy - Z(5) }, col, 1.5);
end
function fx.lit(key, def, bkey)                                     -- a colour, then its brightness (s[bkey], 1 = as is)
    local c = fx.col(key, def);
    local b = tonumber(s[bkey]) or 1;
    if b >= 1 then
        local u = math.min(1, b - 1);
        return { c[1] + (1 - c[1]) * u, c[2] + (1 - c[2]) * u, c[3] + (1 - c[3]) * u, 1 };
    end
    return { c[1] * b, c[2] * b, c[3] * b, 1 };
end
function fx.col(key, def)                                           -- a colour from the settings, or its default
    local c = s[key];
    if type(c) == 'table' and tonumber(c[1]) then return { tonumber(c[1]), tonumber(c[2]), tonumber(c[3]), 1 }; end
    return def;
end
function fx.thin_bar(dl, x, y, w, frac, bright, c1, c2)
    c1, c2 = c1 or fx.col('col_bar1', C.hp), c2 or fx.col('col_bar2', C.mp2);
    local h = math.max(2, math.floor(Z(3)));
    local fw = math.max(h, w * math.max(0, math.min(1, frac or 0)));
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32({ 0.05, 0.04, 0.07, 0.70 }), h / 2);
    dl:AddRectFilled({ x, y - 2 }, { x + fw, y + h + 2 }, u32({ c2[1], c2[2], c2[3], 0.18 }), h);
    local a = bright and 1 or 0.85;
    local ok = pcall(function()
        dl:AddRectFilledMultiColor({ x, y }, { x + fw, y + h }, u32({ c1[1], c1[2], c1[3], a }), u32({ c2[1], c2[2], c2[3], a }),
            u32({ c2[1], c2[2], c2[3], a }), u32({ c1[1], c1[2], c1[3], a }));
    end);
    if not ok then dl:AddRectFilled({ x, y }, { x + fw, y + h }, u32({ c2[1], c2[2], c2[3], a }), h / 2); end
    dl:AddCircleFilled({ x + fw, y + h / 2 }, Z(4.5), u32({ 1, 0.85, 1, 0.22 }), 12);
    dl:AddCircleFilled({ x + fw, y + h / 2 }, Z(2.2), u32({ 1, 1, 1, 1 }), 10);
end

-- Enmity view: the monster's name, then one line per player by estimated enmity (CE + VE). Whoever it's attacking
-- right now is marked TARGET; your name glows orange when you're close to pulling it off the top.
local function draw_enmity_rows()
    local m = hate.focus();
    local list = hate.rows(m);
    local dl = imgui.GetWindowDrawList();
    if m == nil or #list == 0 then
        imgui.Dummy({ W, Z(4) });
        imgui.TextColored(C.muted, 'No monster yet. Enmity shows once your party fights.');
        imgui.Dummy({ W, Z(4) });
        return;
    end
    imgui.TextColored({ 1.0, 0.62, 0.70, 1 }, tostring(m.name));
    imgui.SameLine(0, Z(8));
    imgui.TextColored(C.muted, 'estimated enmity');
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Worked out from the server\'s own enmity rules.\nOther players\' enmity gear can\'t be seen, so it\'s taken as none.\nTARGET (who it is attacking now) is real.');
    end
    local top = math.max(1, list[1].total);
    local lh = imgui.GetTextLineHeight();
    local h = lh + Z(13);
    local t = fx.time();
    local pctw = text_w('100%') + Z(14);
    local name_col = fx.col('col_name', { 1, 1, 1, 1 });
    for i, a in ipairs(list) do
        local x, y = imgui.GetCursorScreenPos();
        imgui.InvisibleButton('##ym_hate' .. i, { W, h });
        if imgui.IsItemHovered() then
            local c = hate.calib[a.who and a.who.key or 0] or 1;
            imgui.SetTooltip(string.format('CE %s (drops when hit)\nVE %s (fades over time)%s', fmt(a.ce), fmt(a.ve),
                math.abs(c - 1) > 0.01 and string.format('\nLearned from TARGET: their enmity counts x%.2f', c) or ''));
        end
        local danger = a.me and not a.target and (i == 1 or a.total >= 0.85 * top);   -- you're about to pull it
        local col = name_col;
        if danger then col = { 1.0, 0.70, 0.35, 0.65 + 0.35 * math.abs(math.sin(t * 4)) }; end
        local left = string.format('%d. %s', i, a.name or '?');
        fx.otext(x, y, col, left);
        local tx = x + Z(6) + text_w(left);
        local job = JOBS[a.job or 0];
        if job then tx = tx + Z(4); fx.otext(tx, y, { 0.80, 0.78, 0.90, 1 }, job); tx = tx + text_w(job) + Z(10); end
        if a.target then fx.otext(tx, y, { 1.0, 0.40, 0.55, 1 }, 'TARGET'); end
        local pct_txt = string.format('%d%%', math.floor(a.total / top * 100 + 0.5));
        local val_txt = fmt(a.total);
        fx.otext(x + W - text_w(pct_txt), y, { 0.85, 0.83, 0.93, 1 }, pct_txt);
        fx.otext(x + W - pctw - text_w(val_txt), y, { 1, 1, 1, 1 }, val_txt);
        fx.thin_bar(dl, x, y + lh + Z(3), W, a.total / top, a.me or a.target,
            a.target and { 1.0, 0.45, 0.45 } or nil, a.target and { 1.0, 0.25, 0.45 } or nil);
    end
    imgui.SetWindowFontScale(0.8);
    local x, y = imgui.GetCursorScreenPos();
    put_text(x + W - text_w('100%') / 0.8 - Z(14) - text_w('ENMITY'), y + 2, C.muted, 'ENMITY');
    put_text(x + W - text_w('OF TOP'), y + 2, C.muted, 'OF TOP');
    put_text(x, y + 2, C.muted, 'estimate - hover a line for CE / VE');
    imgui.Dummy({ W, imgui.GetTextLineHeight() + 4 });
    imgui.SetWindowFontScale(1.0);
end

local function draw_rows()
    if s.mode == 3 then draw_enmity_rows(); return; end
    local seg = segment();
    local list = roster_rows(seg);
    if #list == 0 then
        imgui.Dummy({ W, 4 });
        imgui.TextColored(C.muted, 'Waiting for the party list...');
        imgui.Dummy({ W, 4 });
        return;
    end
    local sum = seg and seg.sum or 0;
    local dur = duration(seg);
    local top = list[1].total;
    local dl = imgui.GetWindowDrawList();
    local lh = imgui.GetTextLineHeight();
    local h = lh + Z(13);
    local pctw = text_w('100.0%') + Z(14);                    -- the share column, and the damage column left of it
    local name_col = fx.col('col_name', { 1, 1, 1, 1 });
    for i, a in ipairs(list) do
        local x, y = imgui.GetCursorScreenPos();
        imgui.InvisibleButton('##ym_row' .. i, { W, h });
        local hov = imgui.IsItemHovered();
        if imgui.IsItemClicked() then ui.expanded[a.name] = not ui.expanded[a.name]; end
        if hov then
            imgui.SetTooltip(string.format('%s DPS\n%s', fmt(a.total / dur), ui.expanded[a.name] and 'Click to hide the details' or 'Click for the details'));
            dl:AddRectFilled({ x - Z(4), y - Z(2) }, { x + W + Z(4), y + h - Z(2) }, u32({ 1, 1, 1, 0.05 }), Z(4));
        end
        local left = string.format('%d. %s', i, a.name or '?');
        fx.otext(x, y, name_col, left);
        local job = JOBS[a.job or 0];
        if job then fx.otext(x + Z(10) + text_w(left), y, { 0.80, 0.78, 0.90, 1 }, job); end
        local pct = sum > 0 and a.total / sum * 100 or 0;
        local pct_txt = string.format('%.1f%%', pct);
        local dmg_txt = fmt(a.total);
        fx.otext(x + W - text_w(pct_txt), y, { 0.85, 0.83, 0.93, 1 }, pct_txt);
        fx.otext(x + W - pctw - text_w(dmg_txt), y, { 1, 1, 1, 1 }, dmg_txt);
        fx.thin_bar(dl, x, y + lh + Z(3), W, top > 0 and a.total / top or 0, a.me);
        if ui.expanded[a.name] then draw_details(a); end
    end
    imgui.SetWindowFontScale(0.8);
    local x, y = imgui.GetCursorScreenPos();
    local pw = text_w('100.0%') / 0.8 + Z(14);                 -- (this line is drawn smaller: same column as the rows)
    put_text(x + W - pw - text_w('DAMAGE'), y + 2, C.muted, 'DAMAGE');
    put_text(x + W - text_w('SHARE'), y + 2, C.muted, 'SHARE');
    put_text(x, y + 2, C.muted, 'click a name for details');
    imgui.Dummy({ W, imgui.GetTextLineHeight() + 4 });
    imgui.SetWindowFontScale(1.0);
end

local function remember_pos()
    local x, y = imgui.GetWindowPos();
    if type(x) == 'table' then x, y = x.x or x[1], x.y or x[2]; end
    if type(x) == 'number' and type(y) == 'number' then s.x, s.y = math.floor(x), math.floor(y); end
end

-- The meter's width sets the size of everything in it: at Normal it is 404 wide, and dragging the corner wider or
-- narrower makes the text, bars and logo grow or shrink with it (that is the Size, saved as s.size). The height
-- only decides how many rows show (saved at Normal size, s.h).
local BASE_W = 404;

function fx.frame(dl, x, y, w, h)
    local c = Z(22);
    x, y, w, h = x + 2, y + 2, w - 4, h - 4;
    local P = { { x + c, y }, { x + w - c, y }, { x + w, y + c }, { x + w, y + h - c }, { x + w - c, y + h }, { x + c, y + h }, { x, y + h - c }, { x, y + c } };
    local mx, my = x + w / 2, y + h / 2;
    for i = 1, #P do dl:AddTriangleFilled({ mx, my }, P[i], P[i % #P + 1], u32(C.bg)); end
    for i = 1, #P do dl:AddLine(P[i], P[i % #P + 1], u32({ C.neon[1], C.neon[2], C.neon[3], 0.30 }), 1); end
    local function neon(pts)
        for i = 1, #pts - 1 do
            dl:AddLine(pts[i], pts[i + 1], u32({ C.neon[1], C.neon[2], C.neon[3], 0.22 }), Z(6));
            dl:AddLine(pts[i], pts[i + 1], u32({ C.neon2[1], C.neon2[2], C.neon2[3], 0.95 }), 2);
        end
    end
    local L = math.min(Z(110), w * 0.3);
    neon({ { x, y + c + L * 0.6 }, { x, y + c }, { x + c, y }, { x + c + L, y } });
    neon({ { x + w, y + h - c - L * 0.6 }, { x + w, y + h - c }, { x + w - c, y + h }, { x + w - c - L, y + h } });
end
-- the _ and X buttons, drawn as thin lines like YunaUI's
function fx.icon_button(id, kind, size)
    local x, y = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton(id, size);
    local hov = imgui.IsItemHovered();
    local dl = imgui.GetWindowDrawList();
    local w, h = size[1], size[2];
    if hov then dl:AddRectFilled({ x, y }, { x + w, y + h }, u32(kind == 'x' and { 1, 0.36, 0.62, 0.30 } or { 0.74, 0.66, 0.95, 0.22 }), h / 2); end
    local col = u32(hov and { 1, 1, 1, 1 } or { 0.80, 0.78, 0.90, 0.9 });
    local cx, cy, r = x + w / 2, y + h / 2, math.min(w, h) * 0.22;
    if kind == '-' then dl:AddLine({ cx - r, cy }, { cx + r, cy }, col, 1.6);
    else
        dl:AddLine({ cx - r, cy - r }, { cx + r, cy + r }, col, 1.6);
        dl:AddLine({ cx - r, cy + r }, { cx + r, cy - r }, col, 1.6);
    end
    return clicked;
end
-- The anchor icon next to the title: two round dots side by side, touching. Pink and violet like the HP / MP bars when
-- the meter is anchored to your HP bar, dim white when it's free; click it to switch.
function fx.anchor_button(id, h)
    local x, y = imgui.GetCursorScreenPos();
    local w = h * 1.3;
    local clicked = imgui.InvisibleButton(id, { w, h });
    local hov = imgui.IsItemHovered();
    ui.icon_hov = ui.icon_hov or hov;
    if hov then imgui.SetTooltip(s.anchor and 'Anchored to your HP bar\nClick to let it go (then drag it anywhere)' or 'Anchor to your HP bar'); end
    local dl = imgui.GetWindowDrawList();
    local cx, cy = x + w / 2, y + h / 2 - h * 0.10;                 -- (a little up: level with the capitals of DAMAGE)
    local r = h * 0.27;
    local on = s.anchor == true;
    local a = hov and 1 or (on and 0.95 or 0.40);
    for _, sx in ipairs({ -1, 1 }) do
        local px = cx + sx * r * 0.92;
        local c = { 1, 1, 1 };
        if on then c = (sx < 0) and C.hp or C.mp2; end               -- anchored: pink and violet
        if on and hov then c = { math.min(1, c[1] + 0.2), math.min(1, c[2] + 0.2), math.min(1, c[3] + 0.2) }; end
        dl:AddCircleFilled({ px, cy }, r + Z(1.2), u32({ 0.15, 0.14, 0.18, 0.75 * math.max(a, 0.6) }), 20);   -- the dark rim
        dl:AddCircleFilled({ px, cy }, r, u32({ c[1], c[2], c[3], a }), 20);
    end
    if clicked then s.anchor, ui.anchor_t0, ui.place = not s.anchor, nil, true; settings.save('dps'); end
    return clicked;
end
-- Anchored to your HP bar (DAMAGE METER > Anchor to your HP bar): it sits just right of the bar and follows it. When it
-- anchors it fades up into place, a little rise, with a bright pink-to-violet line running down its left edge.
function fx.fade_alpha()
    if not s.anchor then return 1; end
    local bp = (type(YUI_EQ_BARPOS) == 'table') and YUI_EQ_BARPOS.hp or nil;
    if bp == nil or os.clock() - (bp[4] or 0) > 1 then return 1; end
    if ui.anchor_t0 == nil then return 0.01; end                     -- (about to fade in)
    return math.max(0.01, math.min(1, (os.clock() - ui.anchor_t0) / 0.45));
end
function fx.anchor_pos()
    if not s.anchor then ui.anchor_t0 = nil; ui.anchor_fx = nil; return nil; end
    local bp = (type(YUI_EQ_BARPOS) == 'table') and YUI_EQ_BARPOS.hp or nil;
    if bp == nil or os.clock() - (bp[4] or 0) > 1 then return nil; end   -- your HP bar isn't showing: it stays where it is
    local tx, ty = bp[1] + bp[3] + Z(30), bp[2] - Z(64);           -- right of the bar, its title about level with the HP number
    local side = (bp[6] == 2) and 'below' or 'right';
    if side == 'below' then tx, ty = bp[1] - Z(8), bp[2] + Z(6); end   -- your bars side by side: it sits under the HP bar instead
    local now_ = os.clock();
    if ui.anchor_side ~= side then ui.anchor_side, ui.anchor_t0 = side, nil; end   -- (moved: it fades in again at its new place)
    if ui.anchor_t0 == nil then ui.anchor_t0, ui.anchor_try = now_, nil; end
    local e = math.min(1, (now_ - ui.anchor_t0) / 0.45);
    local py = ty + Z(16) * (1 - e) ^ 3;                            -- a small rise into place
    ui.anchor_fx = { t = now_ - ui.anchor_t0, px = tx, py = py };
    return tx, py;
end
function fx.anchor_effect()
    local a = ui.anchor_fx;
    if a == nil or a.t > 1.1 then return; end
    local fg = nil;
    pcall(function() fg = imgui.GetForegroundDrawList(); end);
    if fg == nil then return; end
    local f = 1 - math.min(1, a.t / 1.1);                           -- 1 -> 0 as it settles
    f = f ^ 0.7;                                                     -- (stays bright longer)
    local hgt = s.minimized and Z(60) or Z(s.h or 300);
    local len = hgt * math.min(1, a.t * 3.2 + 0.15);                -- the light runs down the edge
    local x, y0 = a.px - Z(3), a.py + Z(4);
    local n = 12;
    for k = 0, n - 1 do                                              -- pink at the top to violet at the bottom
        local u0, u1 = k / n, (k + 1) / n;
        local p0, p1 = { x, y0 + len * u0 }, { x, y0 + len * u1 };
        local c = { C.hp[1] + (C.mp2[1] - C.hp[1]) * u0, C.hp[2] + (C.mp2[2] - C.hp[2]) * u0, C.hp[3] + (C.mp2[3] - C.hp[3]) * u0 };
        fg:AddLine(p0, p1, u32({ c[1], c[2], c[3], 0.60 * f }), Z(4.5));  -- a tight glow, close to the line
        fg:AddLine(p0, p1, u32({ c[1], c[2], c[3], 1.0 * f }), Z(2.6));   -- the colour
        fg:AddLine(p0, p1, u32({ 1, 0.92, 1, 0.95 * f }), Z(1.2));         -- the bright core
    end
end
local function draw_meter()
    imgui.PushStyleVar(ImGuiStyleVar_Alpha, fx.fade_alpha());
    if ui.place then
        imgui.SetNextWindowPos({ s.x, s.y }, ImGuiCond_Always);
        imgui.SetNextWindowSize({ Z(BASE_W), Z(s.h or 300) }, ImGuiCond_Always);
        ui.place = false;
    end
    local ax, ay = fx.anchor_pos();
    if ax then imgui.SetNextWindowPos({ ax, ay }, ImGuiCond_Always); end
    imgui.SetNextWindowSizeConstraints({ BASE_W * 0.5, Z(110) }, { BASE_W * 2.5, 4000 });
    if imgui.Begin('Damage Meter##ym_main', ui.open, bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoCollapse,
            ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse, ImGuiWindowFlags_NoBackground,
            ax and ImGuiWindowFlags_NoMove or 0)) then
        remember_pos();
        local ww, wh = imgui.GetWindowSize();
        if type(ww) == 'table' then ww, wh = ww.x or ww[1], ww.y or ww[2]; end
        if not ax and YUI_ONSCREEN then                              -- (always on the screen)
            local nx, ny, moved = YUI_ONSCREEN(s.x, s.y, ww, wh);
            if moved then s.x, s.y, ui.place = nx, ny, true; settings.save('dps'); end
        end
        ui.dps_hov = imgui.IsWindowHovered(ImGuiHoveredFlags_ChildWindows or 0);
        if type(ww) == 'number' and type(wh) == 'number' then
            pcall(fx.backdrop, imgui.GetWindowDrawList(), s.x, s.y, ww, wh, tonumber(s.backdrop) or 0.55);   -- the window's own edges
            local mx, my = imgui.GetMousePos();
            if type(mx) == 'table' then mx, my = mx.x or mx[1], mx.y or mx[2]; end
            local near = type(mx) == 'number' and mx > s.x + ww - Z(26) and my > s.y + wh - Z(26) and mx < s.x + ww and my < s.y + wh;
            pcall(fx.grip, s.x, s.y, ww, wh, near);
        end
        -- right click anywhere on it: post the meter in party / linkshell chat
        if ui.dps_hov and imgui.IsMouseClicked(1) then imgui.OpenPopup('##ydps_report'); end
        if type(ww) == 'number' and type(wh) == 'number' then
            -- dragged wider / narrower: the Size follows (no re-placing, so the drag isn't interrupted)
            local k = math.max(0.5, math.min(2.5, ww / BASE_W));
            if math.abs(k - scale.k) > 0.005 then scale.k, ui.k_main, s.size = k, k, math.floor(k * 100 + 0.5); end
            ui.ww, ui.wh, s.h = ww, wh, math.floor(wh / scale.k);
        end
        imgui.SetWindowFontScale(1.0);
        W = math.max(Z(200), (ui.ww or Z(404)) - Z(24));
        draw_header();
        -- The list scrolls when the party doesn't fit; its rows leave room for the thin scrollbar
        if imgui.BeginChild('ym_rows', { 0, 0 }, false) then
            imgui.SetWindowFontScale(1.0);
            W = math.max(Z(200), (ui.ww or Z(404)) - Z(24) - Z(10));
            draw_rows();
        end
        imgui.EndChild();
    end
    imgui.End();
    imgui.PopStyleVar(1);
    pcall(fx.anchor_effect);
end

-- A minimized window: the logo with a top-3 card under it. Click it (no drag) to open the window again.
--   o.id: window id   o.x, o.y: where it is   o.place: put it there this frame   o.list: rows { name, total, me, target }
--   o.empty: text when the list is empty   o.tip: tooltip on the logo   o.moved(x, y): it was dragged
--   o.restore(): it was clicked   o.hov: key in ui for the logo's hover state
local function draw_mini_win(o)
    if o.place then imgui.SetNextWindowPos({ o.x, o.y }, ImGuiCond_Always); end
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { Z(4), Z(4) });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    if imgui.Begin(o.id, { true }, bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoCollapse,
            ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoBackground)) then
        local wx, wy = imgui.GetWindowPos();
        if type(wx) == 'table' then wx, wy = wx.x or wx[1], wx.y or wx[2]; end
        if type(wx) == 'number' and type(wy) == 'number' then wx, wy = math.floor(wx), math.floor(wy); o.moved(wx, wy); end
        imgui.SetWindowFontScale(1.0);
        local LW = o.width or Z(150);                         -- width of the list
        local cx = imgui.GetCursorPosX();
        ui[o.hov] = imgui.IsWindowHovered();
        ui.mini_over = ui[o.hov];
        if ui[o.hov] and imgui.IsMouseClicked(1) then imgui.OpenPopup('##ydps_report_m'); end   -- right click: post the meter
        fx.report_menu('##ydps_report_m');
        -- the title, like the open meter's (your colour + brightness, a dark edge): click it to open the meter
        do
            local bx, by = imgui.GetCursorScreenPos();
            imgui.SetWindowFontScale(0.85);
            local label = (o.cols and 'ENMITY' or 'DAMAGE');
            local bw, bh = text_w(label) + Z(4), imgui.GetTextLineHeight() + Z(4);
            if imgui.InvisibleButton('##ym_open' .. o.id, { bw, bh }) then o.restore(); end
            local hov = imgui.IsItemHovered();
            if hov then imgui.SetTooltip('Open the Damage Meter'); end
            ui.icon_hov = hov;
            local tcol = fx.lit('col_title', C.gold, 'bright_title');
            if hov then tcol = { math.min(1, tcol[1] + 0.2), math.min(1, tcol[2] + 0.2), math.min(1, tcol[3] + 0.2), 1 }; end
            fx.otext(bx, by + Z(2), tcol, label);
            if not o.cols then imgui.SameLine(0, Z(2)); fx.anchor_button('##ym_anchor_m', bh); end
            imgui.SetWindowFontScale(1.0);
        end
        imgui.PushStyleVar(ImGuiStyleVar_Alpha, fx.fade_alpha());

        -- The top lines, drawn like the open meter's: your name colour, white numbers, a thin glowing bar under each
        local list = o.list;
        imgui.SetWindowFontScale(0.95);
        local dl = imgui.GetWindowDrawList();
        local th = imgui.GetTextLineHeight();
        local lh = th + Z(11);                                -- a line: the text, then its bar
        local name_col = fx.col('col_name', { 1, 1, 1, 1 });
        local topv = (#list > 0 and list[1].total and list[1].total > 0) and list[1].total or 1;
        imgui.SetCursorPosX(cx);
        local x, y = imgui.GetCursorScreenPos();
        y = y + Z(3);
        local n = o.rows or 3;
        local rows = math.max(1, math.min(n, #list));
        local hdr = (o.cols and #list > 0) and 1 or 0;        -- enmity: a small ENMITY / CE / VE title line
        local box = (rows + hdr) * lh + Z(8);
        -- enmity columns end at: total, CE, VE (from the right)
        local c_ve, c_ce, c_tot = x + LW - Z(7), x + LW - Z(57), x + LW - Z(107);
        local function short(v)
            v = math.floor((v or 0) + 0.5);
            if v >= 1000 then return string.format('%.1fk', v / 1000); end
            return tostring(v);
        end
        local function outlined(px, py, col, text) fx.otext(px, py, col, text); end
        if #list == 0 and o.empty then outlined(x + (LW - text_w(o.empty)) / 2, y + Z(4), C.muted, o.empty); end
        if hdr == 1 then
            imgui.SetWindowFontScale(0.78);
            local hy = y + Z(5);
            put_text(c_tot - text_w('ENMITY'), hy, C.muted, 'ENMITY');
            put_text(c_ce - text_w('CE'), hy, C.muted, 'CE');
            put_text(c_ve - text_w('VE'), hy, C.muted, 'VE');
            imgui.SetWindowFontScale(0.95);
        end
        for i = 1, math.min(n, #list) do
            local a, py = list[i], y + Z(4) + (i - 1 + hdr) * lh;
            local name = tostring(a.name or '?');
            local num = fmt(a.total);
            -- a long name is cut short (with a dot) so it never runs into the number on its right
            local nx = x + Z(7) + text_w('0. ');
            local room = (o.cols and (c_tot - text_w(short(a.total))) or (x + LW - Z(7) - text_w(num))) - Z(8) - nx;
            if text_w(name) > room then
                while #name > 2 and text_w(name .. '.') > room do name = name:sub(1, -2); end
                name = name .. '.';
            end
            local col = name_col;
            if a.target then col = { 1.0, 0.40, 0.55, 1 }; end            -- enmity: who the monster is attacking
            outlined(x + Z(7), py, col, (a.rank or i) .. '.');
            outlined(x + Z(7) + text_w('0. '), py, col, name);
            fx.thin_bar(dl, x + Z(7), py + th + Z(3), LW - Z(14), (a.total or 0) / topv, a.me or a.target,
                a.target and { 1.0, 0.45, 0.45 } or nil, a.target and { 1.0, 0.25, 0.45 } or nil);
            if o.cols then                                    -- enmity: total, CE, VE
                local tot, ce, ve = short(a.total), short(a.ce), short(a.ve);
                outlined(c_tot - text_w(tot), py, { 1, 1, 1, 1 }, tot);
                outlined(c_ce - text_w(ce), py, { 0.80, 0.84, 0.95, 1 }, ce);
                outlined(c_ve - text_w(ve), py, { 0.80, 0.84, 0.95, 1 }, ve);
            else
                outlined(x + LW - Z(7) - text_w(num), py, { 1, 1, 1, 1 }, num);
            end
        end
        imgui.Dummy({ LW, box + Z(3) });
        imgui.PopStyleVar(1);
        imgui.SetWindowFontScale(1.0);
        if ui[o.hov] and not ui.icon_hov then imgui.SetTooltip(o.tip); end   -- (not over the icon's own tip)

        -- A click (not a drag) opens the window again
        local hovered = imgui.IsWindowHovered();
        local pk = o.hov .. '_press';
        if hovered and imgui.IsMouseClicked(0) then ui[pk] = { wx, wy }; end
        if ui[pk] and imgui.IsMouseReleased(0) then
            if hovered and wx and math.abs(wx - ui[pk][1]) < 3 and math.abs(wy - ui[pk][2]) < 3 then o.restore(); end
            ui[pk] = nil;
        end
    end
    imgui.End();
    imgui.PopStyleVar(2);
end

-- The top 5 by enmity for the minimized view. Whoever the monster is attacking (TARGET) is always in it: when
-- they're not in the top 5 by the estimate, they take the 5th line (with their real place in the list).
local function hate_top5()
    local all = hate.rows(hate.focus());
    local out = {};
    for i, a in ipairs(all) do a.rank = i; end
    for i = 1, math.min(5, #all) do out[i] = all[i]; end
    local shown = false;
    for _, a in ipairs(out) do if a.target then shown = true; end end
    if not shown then
        for _, a in ipairs(all) do
            if a.target then out[5] = a; break; end
        end
    end
    return out;
end

-- The meter minimized: logo + top 3 by damage, or on the Enmity tab the top 5 by enmity (with TARGET)
local function draw_mini()
    local enm = s.mode == 3;
    local ax, ay = fx.anchor_pos();                                   -- (anchored: it sits by your HP bar too)
    draw_mini_win({ id = 'Damage Meter##ym_mini', x = ax or s.x, y = ay or s.y, place = ui.place or (ax ~= nil),
        list = enm and hate_top5() or sorted_actors(segment()), rows = enm and 5 or 3,
        cols = enm, width = enm and Z(250) or nil,
        empty = nil, hov = 'mini_hov',                       -- (nothing written when there's no damage yet)
        tip = string.format('Damage Meter - %s DPS\nClick to open, drag to move', fmt(my_dps())),
        moved = function(x, y) s.x, s.y = x, y; end,
        restore = function() s.minimized, ui.place = false, true; settings.save('dps'); end });
    pcall(fx.anchor_effect);
    ui.place = false;
end

-- The size everything is drawn at: s.size, which follows the meter's width. Not taken from the screen:
-- the size ImGui reports can be far bigger than the monitor (game upscaling, Windows display scaling), which
-- made the meter come up huge for some players. A change re-places the window at its new size.
local function update_scale()
    local k = math.max(0.5, math.min(2.5, (tonumber(s.size) or 100) / 100));
    if math.abs(k - (ui.k_main or 0)) > 0.011 then ui.k_main, ui.place = k, true; end   -- e.g. a size changed in the settings file
    scale.k = ui.k_main;
end

local function draw_ui()
    local fp = false;
    if ui.open[1] then
        update_scale();
        local nc, nv = push_theme();
        fp = push_font();
        if s.minimized then draw_mini(); else draw_meter(); end
        if fp then imgui.PopFont(); end
        scale.f = 1;
        imgui.PopStyleVar(nv);
        imgui.PopStyleColor(nc);
        if not ui.open[1] then s.visible = false; settings.save('dps'); end
    end
end

----------------------------------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------------------------------
settings.register('dps', 'ym_settings_update', function(e)
    if e ~= nil then s = e; ui.open[1] = s.visible ~= false; ui.place = true; end
end);

-- The command list: printed when the addon loads, and by /dps help (or any command it doesn't know)
local function show_help(loaded)
    if loaded then return; end                                      -- (part of YunaUI: no list when it loads)
    msg('Damage Meter commands:');
    for _, line in ipairs({
        '/dps  -  open or close the meter',
        '/dps min  -  shrink it to the top 3 and back (or click - / the top 3)',
        '/dps damage | enmity  -  switch view (also the Enmity tab)',
        '/dps reset  -  clear every number',
        '/dps report [p | l | l2 | s | echo]  -  post the top 5 in party, linkshell... (or click DAMAGE at the top)',
        '/dps log  -  record an enmity log to send Yunas (again to stop and save)',
        '/dps help  -  this list',
    }) do msg(line); end
end

ashita.events.register('load', 'ym_load', function() load_font(); hate.load(); show_help(true); end);
ashita.events.register('unload', 'ym_unload', function() settings.save('dps'); lg.stop(); end);

-- The first time (per character): your settings from the separate YunaDPS addon, if you had it
local function import_old()
    s.imported = true;
    pcall(function()
        local p = AshitaCore:GetMemoryManager():GetParty();
        local base = AshitaCore:GetInstallPath():gsub('[\\/]+$', '') .. '\\config\\addons\\yunadps\\';
        local fh = io.open(base .. string.format('%s_%d', p:GetMemberName(0) or '', p:GetMemberServerId(0) or 0) .. '\\settings.lua', 'rb');
        if fh == nil then return; end
        local data = fh:read('*a');
        fh:close();
        local chunk = loadstring(data);
        if chunk == nil then return; end
        setfenv(chunk, { T = function(x) return x; end, require = function() end });
        local ok, old = pcall(chunk);
        if ok and type(old) == 'table' then
            for k, v in pairs(old) do if k ~= 'imported' then s[k] = v; end end
            ui.open[1], ui.place = s.visible ~= false, true;
            msg('YunaDPS is now part of YunaUI (Damage Meter): your settings were brought over. You can unload the old yunadps addon.');
        end
    end);
    settings.save('dps');
end
ashita.events.register('d3d_present', 'ym_present', function()
    if not s.imported then
        local nm = '';
        pcall(function() nm = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0) or ''; end);
        if nm ~= '' then import_old(); end
    end
    local f = meter.fight;
    pcall(hate.tick);
    if lg.f and now() - lg.snap_t > 10 and fighting() then lg.snap_t = now(); pcall(lg.snapshot, hate.focus(), 'every 10s'); end
    send_chat_queue();
    local ok, err = pcall(draw_ui);
    if not ok then pcall(YUI_ERRLOG, 'meter draw', err); end
end);

ashita.events.register('packet_in', 'ym_packet_in', function(e)
    if e.id == 0x28 then
        ui.dbg.seen = ui.dbg.seen + 1;
        local ok, err = pcall(parse_action, e);
        if not ok then
            ui.dbg.errs, ui.dbg.last = ui.dbg.errs + 1, tostring(err);
            if not ui.parse_warned then
                ui.parse_warned = true;
                msg('Could not read a combat message (' .. tostring(err) .. '). The meter keeps going.');
            end
        end
    elseif e.id == 0x29 then
        -- "defeats" / "falls to the ground": that monster's enmity list is gone
        pcall(function()
            local d = e.data;
            local function u(at, n) local v = 0; for i = n, 1, -1 do v = v * 256 + (d:byte(at + i) or 0); end return v; end
            local m = u(0x18, 2);
            if m == 6 or m == 20 or m == 97 or m == 113 or m == 406 or m == 605 or m == 646 then
                if lg.f then lg.w(string.format('DEATH msg %d  %s', m, hex(u(0x08, 4)))); end
                hate.mobs[u(0x08, 4)] = nil;
            end
        end);
    end
end);

ashita.events.register('command', 'ym_command', function(e)
    local args = e.command:args();
    if #args == 0 then return; end
    local cmd = args[1]:lower();
    if cmd ~= '/dps' and cmd ~= '/yunadps' then return; end
    e.blocked = true;
    local sub = (args[2] or ''):lower();
    if sub == '' or sub == 'show' or sub == 'toggle' then
        if sub == 'show' then ui.open[1] = true; else ui.open[1] = not ui.open[1]; end
        s.visible, ui.place = ui.open[1], true;
        settings.save('dps');
    elseif sub == 'hide' then
        ui.open[1], s.visible = false, false;
        settings.save('dps');
    elseif sub == 'reset' then
        reset();
        msg('Every number cleared.');
    elseif sub == 'min' or sub == 'mini' then
        s.minimized, ui.open[1], s.visible, ui.place = not s.minimized, true, true, true;
        settings.save('dps');
    elseif sub == 'fight' or sub == 'current' or sub == 'total' or sub == 'damage' then
        s.mode = 1; settings.save('dps');
    elseif sub == 'enmity' or sub == 'hate' then
        ui.toggle_hate();
    elseif sub == 'bright' and tonumber(args[4]) then
        local key = ({ title = 'bright_title', detail = 'bright_detail' })[(args[3] or ''):lower()];
        if key then s[key] = math.max(0.4, math.min(1.8, tonumber(args[4]))); settings.save('dps'); end
    elseif sub == 'backdrop' and tonumber(args[3]) then
        s.backdrop = math.max(0, math.min(1, tonumber(args[3])));
        settings.save('dps');
    elseif sub == 'color' or sub == 'colour' then
        local which = (args[3] or ''):lower();
        local key = ({ name = 'col_name', bar1 = 'col_bar1', bar2 = 'col_bar2', title = 'col_title', detail = 'col_detail' })[which];
        if which == 'reset' then
            s.col_name, s.col_bar1, s.col_bar2, s.col_title, s.col_detail, s.bright_title, s.bright_detail = nil, nil, nil, nil, nil, nil, nil;
            settings.save('dps');
        elseif key and tonumber(args[4]) and tonumber(args[5]) and tonumber(args[6]) then
            local function c01(v) return math.max(0, math.min(1, tonumber(v))); end
            s[key] = { c01(args[4]), c01(args[5]), c01(args[6]) };
            settings.save('dps');
        else msg('/dps color name|bar1|bar2|title|detail <r> <g> <b>  (0 to 1)   or   /dps color reset'); end
    elseif sub == 'log' then
        if lg.f then
            local path = lg.path;
            lg.stop();
            msg('Enmity log saved: ' .. tostring(path));
            msg('Send that file (it is in addons\\yunaui\\logs) to Yunas.');
        elseif lg.start() then
            msg('Enmity log ON. Fight as usual, then type /dps log again to save it.');
        else
            msg('Could not create the log file in the addon folder.');
        end
    elseif sub == 'debug' then
        local d, n = ui.dbg, 0;
        pcall(function() for _ in pairs(party_map()) do n = n + 1; end end);
        msg(string.format('combat messages seen %d  |  from your party %d  |  damage lines counted %d  |  read errors %d',
            d.seen, d.party, d.lines, d.errs));
        msg(string.format('party / alliance / pets known: %d', n));
        if d.last then msg('last read error: ' .. d.last); end
        local hm = hate.focus();
        if hm then
            local parts = {};
            for _, r in ipairs(hate.rows(hm)) do
                table.insert(parts, string.format('%s %s (CE %s VE %s)%s', r.name, fmt(r.total), fmt(r.ce), fmt(r.ve), r.target and ' TARGET' or ''));
            end
            msg('enmity on ' .. tostring(hm.name) .. ' (level ' .. tostring(hm.level or 'unknown') .. '): ' .. table.concat(parts, ', '));
            local top = {};
            for _, r in ipairs(hate_top5()) do table.insert(top, r.rank .. '.' .. r.name .. (r.target and ' TARGET' or '')); end
            msg('minimized top 5: ' .. table.concat(top, ', '));
        else
            msg('enmity: no monster yet');
        end
    elseif sub == 'report' then
        local ch = (args[3] or 'p'):lower();
        if ch ~= 'p' and ch ~= 'l' and ch ~= 'l2' and ch ~= 's' and ch ~= 'echo' then ch = 'p'; end
        report(ch);
    else
        show_help(false);
    end
end);

-- For YunaUI's DAMAGE METER tab: the settings, saving, and the few things that need more than a saved value
YUI_DPS = {
    get = function() return s; end,                                  -- (s can be replaced when the file changes)
    save = function() settings.save('dps'); end,
    reset = function() reset(); end,
    set_visible = function(v) ui.open[1], s.visible, ui.place = v, v, true; settings.save('dps'); end,
    set_minimized = function(v) s.minimized, ui.place = v, true; settings.save('dps'); end,
    set_anchor = function(v) s.anchor, ui.anchor_t0, ui.place = v, nil, true; settings.save('dps'); end,
    place = function(x, y) s.x, s.y, ui.place = math.floor(x), math.floor(y), true; settings.save('dps'); end,   -- (GENERAL > LAYOUT)
    try_anchor = function() s.anchor, ui.anchor_t0, ui.anchor_try = true, nil, true; settings.save('dps'); end,
    set_mode = function(m)
        if m == 2 then m = 1; end
        if m == 3 then if s.mode ~= 3 then ui.toggle_hate(); end
        else s.mode = m; end
        settings.save('dps');
    end,
};
