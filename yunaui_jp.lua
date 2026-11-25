-- YunaUI Japanese localization 1.1.4j - Copyright (C) 2026 Tsukasa
-- Based on YunaUI by Yunas - https://github.com/YunasXI/yunaui
-- License: GPL-3.0 with the YunaUI attribution term (GPL-3.0 section 7(b)); see LICENSE and NOTICE.
-- This program comes with ABSOLUTELY NO WARRANTY.
-- yunaui_jp.lua : YunaUI 日本語化モジュール
-- 公式 yunaui.lua には「-- [JP]」印の短いフック行だけを入れ、処理はすべてここに置く。
-- 英語表示（ui_lang=en、または auto で英語クライアント）のときは何もしない＝公式と同じ動き。
local imgui = require('imgui');
local L = require('yunaui_lang');

local JP = { active = false, cfg = { ui_lang = 'auto', font_scale = 1.0, minimap_text_scale = 1.3, keep_fonts = false, font = 'default', chat_outline_on = true, chat_shadow = true, chat_shadow_dist = 2, chat_shadow_pct = 85, chat_outline_pct = 85, chat_outline_w = 1, chat_shadow_col = 'black' } };
local FX_DEF = { chat_shadow = true, chat_shadow_dist = 2, chat_shadow_pct = 85, chat_outline_pct = 85, chat_outline_w = 1, chat_shadow_col = 'black' };   -- (縁取りと影: ダブルクリックで戻す値 = 今までの見た目)
local good, install_core_proxy;   -- (前方宣言)
local JA, UP = L.JA, {};
local memo, memo_n = {}, 0;
local CFG_FILE = (addon and addon.path or '.') .. '/yunaui_jp_settings.lua';

-------------------------------------------------------------------- 設定ファイル
local function load_cfg()
    local f = loadfile(CFG_FILE);
    if not f then return; end
    local ok, t = pcall(f);
    if ok and type(t) == 'table' then
        if t.ui_lang == 'ja' or t.ui_lang == 'en' or t.ui_lang == 'auto' then JP.cfg.ui_lang = t.ui_lang; end
        local s = tonumber(t.font_scale);
        if s and s >= 0.8 and s <= 1.4 then JP.cfg.font_scale = s; end
        local m = tonumber(t.minimap_text_scale);
        if m and m >= 0.5 and m <= 2.0 then JP.cfg.minimap_text_scale = m; end
        if type(t.font) == 'string' and t.font ~= '' and not t.font:find('[/\\]') then JP.cfg.font = t.font; end   -- (言語 > フォント: 'default' / 'meiryo' / fonts フォルダのファイル名)
        for _, k in ipairs({ 'chat_outline_on', 'chat_shadow' }) do
            if type(t[k]) == 'boolean' then JP.cfg[k] = t[k]; end
        end
        local function num(k, lo, hi)
            local v = tonumber(t[k]); if v and v >= lo and v <= hi then JP.cfg[k] = math.floor(v + 0.5); end
        end
        num('chat_shadow_pct', 0, 100); num('chat_outline_pct', 0, 100);
        local function frac(k, lo, hi, st)                           -- (0.25 / 0.5 刻みの値: 刻みに丸めて範囲内だけ)
            local v = tonumber(t[k]); if v and v >= lo and v <= hi then JP.cfg[k] = math.floor(v / st + 0.5) * st; end
        end
        frac('chat_shadow_dist', 1, 6, 0.5);
        frac('chat_outline_w', 0, 3, 0.25);
        if tonumber(t.chat_outline_w) == nil and t.chat_outline_on == false then JP.cfg.chat_outline_w = 0; end   -- (前の「縁取り なし」= 太さ 0)
        if t.chat_shadow_col == 'black' or t.chat_shadow_col == 'gray' or t.chat_shadow_col == 'white' then JP.cfg.chat_shadow_col = t.chat_shadow_col; end
        JP.cfg.keep_fonts = t.keep_fonts == true;
    end
end
local function save_cfg()
    local f = io.open(CFG_FILE, 'w');
    if not f then return; end
    local c = JP.cfg;
    f:write(string.format('return { ui_lang = %q, font_scale = %.2f, minimap_text_scale = %.2f, keep_fonts = %s, font = %q, chat_outline_on = %s, chat_shadow = %s, chat_shadow_dist = %.2f, chat_shadow_pct = %d, chat_outline_pct = %d, chat_outline_w = %.2f, chat_shadow_col = %q };\n',
        c.ui_lang, c.font_scale, c.minimap_text_scale or 1.3, tostring(c.keep_fonts == true),
        tostring(c.font or 'default'), tostring((tonumber(c.chat_outline_w) or 1) > 0), tostring(c.chat_shadow),
        c.chat_shadow_dist, c.chat_shadow_pct, c.chat_outline_pct, c.chat_outline_w or 1, c.chat_shadow_col));
    f:close();
end

-------------------------------------------------------------------- 翻訳
local function lookup(v)
    local r = JA[v] or UP[v];
    if r then return r; end
    if not v:find('%a') then return nil; end
    -- 前後の空白（'   ' .. 名前 など）を保ったまま引く
    local a, core, b = v:match('^(%s*)(.-)(%s*)$');
    if core ~= v and core ~= '' then
        r = JA[core] or UP[core];
        if r then return a .. r .. b; end
    end
    for _, p in ipairs(L.PATTERNS) do
        if v:find(p[1]) then
            local s = v:gsub(p[1], p[2]);
            return s;
        end
    end
    return nil;
end
function JP.t(s)
    if not JP.active or type(s) ~= 'string' or #s < 2 then return s; end
    if YUI_JP_CHAN and L.CHAN[s] then return s; end   -- チャンネル名は英語のまま
    local c = memo[s];
    if c then return c; end
    c = s;
    local vis, id = s:match('^(.-)(##.*)$');
    if vis then
        if vis ~= '' then local r = lookup(vis); if r then c = r .. id; end end
    else
        c = lookup(s) or s;
    end
    if memo_n > 5000 then memo, memo_n = {}, 0; end
    memo[s], memo_n = c, memo_n + 1;
    return c;
end
function JP.msg(t)                                                   -- (公式 msg の文: 翻訳して、チャット欄用にShift-JISへ（UTF-8のままだと化ける）)
    t = JP.t(t);
    if JP.active and JP.to_sj then t = JP.to_sj(t); end
    return t;
end
YUI_JP_T = JP.msg;   -- dps.lua / equip.lua のチャットメッセージ用（翻訳してShift-JISへ。公式 msg と同じ）

function JP.fmt(s, ...)
    if not JP.active then
        if select('#', ...) > 0 then return string.format(s, ...); end
        return s;
    end
    local t = JP.t(s);
    if select('#', ...) > 0 then
        local ok, r = pcall(string.format, t, ...);
        if ok then return r; end
        return string.format(s, ...);
    end
    return t;
end
function JP.upd_status(ver, U, cfg)                                  -- (GENERAL > UPDATES: your version and what it last heard)
    if not JP.active then return nil; end
    local st = JP.fmt('You have %s.', ver);
    if U.state == 'checking' then return st .. '  ' .. JP.t('Checking...'); end
    if U.said and U.said ~= '' then return st .. '  ' .. U.said; end
    if type(cfg.upd_tag) == 'string' and U.newer and U.newer(cfg.upd_tag, ver) then return st .. '  ' .. JP.fmt('%s is out.', cfg.upd_tag); end
    if type(cfg.upd_tag) == 'string' then return st .. '  ' .. JP.t('Up to date.'); end
    return st;
end

function JP.wx(s)                                                    -- (weather names: a small table, so "Blizzard" the weather is not the spell)
    if not JP.active or type(s) ~= 'string' then return s; end
    local W = L and L.WX;
    if type(W) == 'table' and W[s] then return W[s]; end
    return JP.t(s);
end
function JP.upd_title(state, tag)
    if not JP.active then return nil; end
    if state == 'done' then return JP.t('YUNAUI UPDATED'); end
    return JP.fmt('YUNAUI %s IS OUT', tostring(tag or ''));
end

-- ガイド本文は行に折り返してから描くため、段落ごと先に翻訳し、日本語は文字単位で折り返す
function JP.guide_lines(s, maxw)
    if not JP.active or type(s) ~= 'string' then return nil; end
    local pref, path = s:match('^(It is turned off right now: turn it on in /yui > )(.+)%.$');
    if pref then
        s = '今はオフです。/yui > ' .. JP.t(path) .. ' でオンにしてください。';
    else
        s = JP.t(s);
    end
    if type(maxw) ~= 'number' or maxw <= 0 then return { s }; end
    local function cw(t)
        local w = imgui.CalcTextSize(t);
        if type(w) == 'table' then w = w[1] or w.x or 0; end
        return tonumber(w) or 0;
    end
    local chars = {};
    for ch in s:gmatch('[%z\1-\127\194-\244][\128-\191]*') do chars[#chars + 1] = ch; end
    local function break_after(ch)
        if ch == ' ' or ch == '\t' then return true; end
        if ch:byte(1) and ch:byte(1) >= 128 then return true; end   -- CJK などは直後で切ってよい
        return ch:find('[、。，,．%.！!？?%）%)%]」』]') ~= nil;
    end
    local out, line, last_br = {}, '', 0;
    for i, ch in ipairs(chars) do
        if ch == '\n' then
            out[#out + 1] = line; line, last_br = '', 0;
        else
            local try = line .. ch;
            if line ~= '' and cw(try) > maxw then
                if last_br > 0 and last_br < #line then
                    out[#out + 1] = line:sub(1, last_br);
                    local rest = line:sub(last_br + 1);
                    if rest:sub(1, 1) == ' ' then rest = rest:sub(2); end
                    line, last_br = rest .. ch, 0;
                else
                    out[#out + 1] = line;
                    line, last_br = ((ch == ' ') and '' or ch), 0;
                end
            else
                line = try;
                if break_after(ch) then last_br = #line; end
            end
        end
    end
    if line ~= '' then out[#out + 1] = line; end
    if #out == 0 then out[1] = s; end
    return out;
end

-------------------------------------------------------------------- UTF-8 文字単位の字間描画
function JP.mb(s) return JP.active and type(s) == 'string' and s:find('[\128-\255]') ~= nil; end
local function chars(s)
    if YUI_U8 then s = YUI_U8(s); end
    local out, i, n = {}, 1, #s;
    while i <= n do
        local c = s:byte(i);
        local len = (c < 0x80 and 1) or (c >= 0xF0 and 4) or (c >= 0xE0 and 3) or (c >= 0xC0 and 2) or 1;
        out[#out + 1] = s:sub(i, i + len - 1);
        i = i + len;
    end
    return out;
end
function JP.spaced(dl, x, y, str, col, gap, T)
    local cx = x;
    for _, ch in ipairs(chars(str)) do
        T(dl, cx, y, col, ch);
        cx = cx + imgui.CalcTextSize(ch) + gap;
    end
    return cx - x - gap;
end
function JP.spaced_w(str, gap)
    local w = 0;
    for _, ch in ipairs(chars(str)) do w = w + imgui.CalcTextSize(ch) + gap; end
    return w - gap;
end

-------------------------------------------------------------------- 起動（言語判定と ImGui の文字関数のラップ）
local function wrap(name, argi)
    local f = imgui[name];
    if type(f) ~= 'function' then return; end
    local g;
    if argi == 1 then g = function(t, ...) return f(JP.t(t), ...); end
    else g = function(a, t, ...) return f(a, JP.t(t), ...); end end
    pcall(function() imgui[name] = g; end);
end
-- 日本語クライアントか（公式の判定が失敗する環境があるので、複数の方法で確認）
local function detect_jp()
    if YUI_JP then return true; end
    local hit = false;
    for _, id in ipairs({ 230, 231, 232, 234, 235, 236 }) do
        pcall(function() local z = vana.ashita.string('zones.names', id, 0) or ''; if z:find('[\128-\255]') then hit = true; end end);
        pcall(function() local z = AshitaCore:GetResourceManager():GetString('zones.names', id) or ''; if z:find('[\128-\255]') then hit = true; end end);
        if hit then break; end
    end
    return hit;
end
local JPFONT = nil;
local function jp_font_path()
    if JPFONT ~= nil then return JPFONT or nil; end
    JPFONT = false;
    local pp = JP.picked_path and JP.picked_path();
    if pp and JP.font_has_jp_file(pp) then JPFONT = pp; return JPFONT; end   -- (選んだフォントに日本語がある: それを合成)
    local dir = (os.getenv('WINDIR') or 'C:\\Windows') .. '\\Fonts\\';
    for _, n in ipairs({ 'meiryo.ttc', 'YuGothM.ttc', 'msgothic.ttc' }) do
        local f = io.open(dir .. n, 'rb');
        if f then f:close(); JPFONT = dir .. n; break; end
    end
    return JPFONT or nil;
end
-- フォントを1つ足すたびに、その直後に日本語フォントを合成する
-- （ImGui の MergeMode は「直前に追加したフォント」に合成されるため、後からまとめて合成すると別のフォントに入ってしまう）
-- 日本語表示のときは英数字も含めてメイリオで描く（102j と同じ）。英語表示では何も変えない。
local FONTMAP = {
    ['segoeui.ttf'] = 'meiryo.ttc', ['seguivar.ttf'] = 'meiryo.ttc', ['seguisb.ttf'] = 'meiryo.ttc',
    ['bahnschrift.ttf'] = 'meiryob.ttc', ['segoeuib.ttf'] = 'meiryob.ttc', ['seguibl.ttf'] = 'meiryob.ttc',
    ['gothic.ttf'] = 'meiryo.ttc', ['avantgarde-book.ttf'] = 'meiryo.ttc', ['avantgarde-book.otf'] = 'meiryo.ttc',
    ['avantgardebook.ttf'] = 'meiryo.ttc', ['avantgarde.ttf'] = 'meiryo.ttc', ['avgardn.ttf'] = 'meiryo.ttc',
    ['texgyreadventor-regular.otf'] = 'meiryo.ttc',
    ['yugothm.ttc'] = 'meiryo.ttc', ['msgothic.ttc'] = 'meiryo.ttc',
};
local FEXIST = {};
local function fexists(p)
    if FEXIST[p] == nil then local f = io.open(p, 'rb'); FEXIST[p] = f ~= nil; if f then f:close(); end end
    return FEXIST[p];
end

-------------------------------------------------------------------- 言語 > フォント（fonts フォルダ＋Windowsのメイリオ）
local function win_fonts() return (os.getenv('WINDIR') or 'C:\\Windows') .. '\\Fonts\\'; end
local function fonts_dir() return (addon and addon.path or '.') .. '/fonts/'; end
local FONT_EXT = { ttf = true, otf = true, ttc = true };
-- fonts フォルダの一覧（実行時に読む。5秒ごとに読み直し）。
-- ashita.fs.get_directory はパスだけだと「フォルダ」しか返さない（空の表）→ ファイルにはフィルターが要る。
-- フィルターの書き方（正規表現 / ワイルドカード）が環境で違うので、いくつか試して全部まとめる。
local function fonts_dir_win()
    local base = tostring((addon and addon.path) or '.'):gsub('/', '\\'):gsub('\\+$', '');
    return base .. '\\fonts\\';
end
local FLIST = { at = -100, list = nil, how = nil, popen_done = false, popen = nil };
local KNOWN_FONTS = { 'texgyreadventor-regular.otf', 'TeXGyreAdventor-Regular.otf', 'AvantGarde-Book.ttf', 'AvantGarde-Book.otf',
    'AvantGardeBook.ttf', 'avantgarde.ttf', 'AVGARDN.TTF' };
function JP.font_list()
    if FLIST.list and os.clock() < FLIST.at then return FLIST.list, FLIST.how; end
    FLIST.at = os.clock() + 5;
    local list, seen, how = {}, {}, {};
    local function take(names, tag)
        if type(names) ~= 'table' then return; end
        local got = 0;
        for k, n in pairs(names) do
            if type(n) ~= 'string' and type(k) == 'string' then n = k; end   -- (名前がキーで返る形にも対応)
            if type(n) == 'table' then n = n.name or n.Name or n[1]; end
            if type(n) == 'string' then
                n = n:match('[^/\\]+$') or n;
                local ext = (n:match('%.([^%.]+)$') or ''):lower();
                if FONT_EXT[ext] and not seen[n:lower()] then
                    local f = io.open(fonts_dir() .. n, 'rb');         -- (本当に読めるファイルだけ)
                    if f then f:close(); seen[n:lower()] = true; list[#list + 1] = n; got = got + 1; end
                end
            end
        end
        if got > 0 and not how[tag] then how[tag] = true; how[#how + 1] = tag; end
    end
    local gd = ashita and ashita.fs and ashita.fs.get_directory;     -- (Ashita v4: フィルターは正規表現)
    local dirs = { fonts_dir_win(), (fonts_dir_win():gsub('\\$', '')), fonts_dir() };
    if type(gd) == 'function' then
        for _, d in ipairs(dirs) do
            for _, flt in ipairs({ '.*\\.[tT][tT][fF]$', '.*\\.[oO][tT][fF]$', '.*\\.[tT][tT][cC]$', '.*' }) do
                local ok, names = pcall(gd, d, flt);
                if ok then take(names, 'fs'); end
            end
            if #list > 0 then break; end
        end
    end
    if #list == 0 then                                               -- (ワイルドカード形式: ashita.fs のフィルターが正規表現でない環境 / v3 の ashita.file.get_dir)
        local gd3 = ashita and ashita.file and ashita.file.get_dir;
        for _, d in ipairs(dirs) do
            for _, flt in ipairs({ '*.ttf', '*.otf', '*.ttc' }) do
                if type(gd) == 'function' then local ok, names = pcall(gd, d, flt); if ok then take(names, 'fs*'); end end
                if type(gd3) == 'function' then local ok, names = pcall(gd3, d, flt, false); if ok then take(names, 'file'); end end
            end
            if #list > 0 then break; end
        end
    end
    if #list == 0 and not FLIST.popen_done then                      -- (最後の手段: dir /b。黒い窓が一瞬出ることがあるので1回だけ)
        FLIST.popen_done = true;
        pcall(function()
            if type(io.popen) ~= 'function' then return; end
            local h = io.popen('dir /b /a-d "' .. fonts_dir_win() .. '" 2>nul');
            if not h then return; end
            local t = {};
            for line in h:lines() do t[#t + 1] = (line:gsub('[\r\n]+$', '')); end
            h:close();
            FLIST.popen = t;
        end);
    end
    if FLIST.popen then take(FLIST.popen, 'dir'); end
    local probe = {};                                                -- (公式が使うフォント名と、保存されている選択)
    for _, n in ipairs(KNOWN_FONTS) do probe[#probe + 1] = n; end
    if type(JP.cfg.font) == 'string' and JP.cfg.font ~= 'default' and JP.cfg.font ~= 'meiryo' then probe[#probe + 1] = JP.cfg.font; end
    take(probe, 'probe');
    table.sort(list, function(a, b) return a:lower() < b:lower(); end);
    FLIST.list = list;
    FLIST.how = (#how > 0) and table.concat(how, '+') or nil;
    FLIST.ok = how[1] ~= nil and how[1] ~= 'probe';
    return list, FLIST.how;
end
function JP.font_list_status() return FLIST.ok == true, fonts_dir_win(), FLIST.how; end
-- 選んだフォントのファイル（無ければ nil = 既定）。起動時に1回だけ決める（フォントは起動時に読むため）。
local PICK = nil;
local function picked_path()
    if PICK ~= nil then return PICK or nil; end
    PICK = false;
    local k = JP.cfg.font or 'default';
    if k == 'meiryo' then
        if fexists(win_fonts() .. 'meiryo.ttc') then PICK = win_fonts() .. 'meiryo.ttc'; end
    elseif k ~= 'default' and not k:find('[/\\]') then
        if fexists(fonts_dir() .. k) then PICK = fonts_dir() .. k; end
    end
    return PICK or nil;
end
JP.picked_path = picked_path;
-- フォントに日本語があるか: OS/2 表の ulCodePageRange1 の bit17（JIS/日本）を見る（ヘッダだけ読む）
local function u32be(b, i) local a, c, d, e = b:byte(i, i + 3); if not e then return nil; end return ((a * 256 + c) * 256 + d) * 256 + e; end
local function u16be(b, i) local a, c = b:byte(i, i + 1); if not c then return nil; end return a * 256 + c; end
local JPCP = {};
local function has_japanese(path)
    if path == nil then return false; end
    local key = tostring(path):lower();
    if JPCP[key] ~= nil then return JPCP[key]; end
    JPCP[key] = false;
    pcall(function()
        local f = io.open(path, 'rb'); if not f then return; end
        local function at(off, n) f:seek('set', off); return f:read(n) or ''; end
        local base = 0;
        if at(0, 4) == 'ttcf' then base = u32be(at(12, 4), 1) or 0; end   -- (.ttc: 1つ目のフォント = 読み込まれるもの)
        local n = u16be(at(base + 4, 2), 1) or 0;
        local dir = at(base + 12, 16 * math.min(n, 64));
        for i = 0, math.min(n, 64) - 1 do
            if dir:sub(i * 16 + 1, i * 16 + 4) == 'OS/2' then
                local off = u32be(dir, i * 16 + 9);
                local t = off and at(off, 86) or '';
                local ver = u16be(t, 1) or 0;
                local cp = (ver >= 1) and u32be(t, 79) or nil;
                if cp then JPCP[key] = math.floor(cp / 131072) % 2 == 1; end
                break;
            end
        end
        f:close();
    end);
    return JPCP[key];
end
JP.font_has_jp_file = has_japanese;
function JP.map_font(path)
    if not JP.active or type(path) ~= 'string' then return path; end
    if JP.cfg.keep_fonts then return path; end                       -- (Keep YunaUI fonts: English letters and numbers in YunaUI's own fonts - the Japanese merged in)
    local base = (path:match('[^/\\]+$') or path):lower();
    local to = FONTMAP[base];
    if not to then return path; end
    local pp = picked_path();                                        -- (言語 > フォント: 選んだもの。既定なら今まで通りメイリオ)
    if pp then return pp; end
    local dir = (os.getenv('WINDIR') or 'C:\\Windows') .. '\\Fonts\\';
    if fexists(dir .. to) then return dir .. to; end
    if to == 'meiryob.ttc' and fexists(dir .. 'meiryo.ttc') then return dir .. 'meiryo.ttc'; end
    return path;
end
-- このロード内だけの共用。unloadを越えてnativeポインタを保持しない。
local KEEP, FONT_CACHE, FONT_DYNAMIC, FONT_JP, AUTO_TRIED = {}, {}, {}, {}, {};
JP.MERGED = {};
local function font_key(path) return tostring(path):gsub('/', '\\'):lower(); end
local function dynamic_font(font)
    local ok, v = pcall(function() return font.LegacySize; end);
    return ok and v ~= nil;
end
local function japanese_file(path)
    local base = (tostring(path):match('[^/\\]+$') or ''):lower();
    if base == 'meiryo.ttc' or base == 'meiryob.ttc' or base == 'yugothm.ttc' or base == 'msgothic.ttc' then return true; end
    return has_japanese(path);                                       -- (fonts フォルダの日本語フォントも: 二重に合成しない)
end
local function mark_japanese(font)
    if not font or FONT_JP[tostring(font)] then return; end
    FONT_JP[tostring(font)] = true;
    JP.MERGED[#JP.MERGED + 1] = font; JP.MERGED[tostring(font)] = true;
end
function JP.font_has_japanese(font) return font and FONT_JP[tostring(font)] == true; end
local function hook_fonts()
    local add = imgui.AddFontFromFileTTF;
    if type(add) ~= 'function' then return; end
    -- 同一ファイル・同一サイズを共用。新ImGuiはサイズ可変なのでファイル単位で共用。
    -- cfg/追加引数つきは個別設定か合成なので、一切キャッシュしない。
    local function shared_add(domain, path, px, cfg, ...)
        if cfg ~= nil or select('#', ...) > 0 then return add(path, px, cfg, ...); end
        local key = domain .. ':' .. font_key(path);
        if FONT_DYNAMIC[key] then return FONT_DYNAMIC[key]; end
        local sized_key = key .. ':' .. tostring(px);
        if FONT_CACHE[sized_key] then return FONT_CACHE[sized_key]; end
        local font = add(path, px);
        if font then
            FONT_CACHE[sized_key] = font;
            if dynamic_font(font) then FONT_DYNAMIC[key] = font; end
            if japanese_file(path) then mark_japanese(font); end
        end
        return font;
    end
    -- 日本語の字がないフォントにだけ、1回だけ日本語フォントを合成（サイズ可変フォントは1つ＝合成も1回）
    local function merge_jp(font, px)
        if not font or JP.font_has_japanese(font) or AUTO_TRIED[tostring(font)] then return; end
        AUTO_TRIED[tostring(font)] = true;
        local jp = jp_font_path();
        if not jp then return; end
        pcall(function()
            local T_ = (imgui.types or vana.imgui.types).ImFontConfig;
            local c = T_.new(); c.MergeMode = true;
            pcall(function() c.DstFont = font; end);
            KEEP[#KEEP + 1] = c;
            local k_ = tonumber(YUI_JPK) or 1;               -- (CHAT > Japanese text size: official YUI_JPK)
            local merged = add(jp, (tonumber(px) or 17) * k_, c);
            if merged then mark_japanese(font); end
        end);
    end
    -- チャットとUIは別の領域: CHATの描画判定が他のUIへ波及しないようにする。
    JP.raw_add_font = function(path, px, cfg, ...)
        local font = shared_add('chat', path, px, cfg, ...);
        if cfg == nil then merge_jp(font, px); end                  -- (fonts フォルダの英字フォント: 日本語はメイリオで)
        return font;
    end
    local g = function(path, px, cfg, ...)
        path = JP.map_font(path);
        local font = shared_add('ui', path, px, cfg, ...);
        if cfg == nil then merge_jp(font, px); end
        return font;
    end
    pcall(function() imgui.AddFontFromFileTTF = g; end);
end

function JP.boot()
    load_cfg();
    local m = JP.cfg.ui_lang;
    local client_jp = detect_jp();
    JP.active = (m == 'ja') or (m == 'auto' and client_jp);
    if not JP.active then return; end
    -- 日本語表示のときはゲームの文字（Shift-JIS）を必ずUTF-8に変換させる。
    -- 公式の YUI_JP 判定が外れると、アイテム名・エリア名・チャットが「?」になるため。
    -- （ここは公式の imgui 変換・フォント処理より前に実行されるので、公式の日本語対応がすべて有効になる）
    YUI_JP = true;
    hook_fonts();
    JP.hook_chat_metrics();
    for k, v in pairs(JA) do local u = k:upper(); if u ~= k and JA[u] == nil then UP[u] = v; end end
    for _, n in ipairs({ 'Text', 'TextUnformatted', 'TextWrapped', 'TextDisabled', 'CalcTextSize', 'SetTooltip',
                         'Button', 'SmallButton', 'Selectable', 'Checkbox', 'BulletText', 'SeparatorText' }) do wrap(n, 1); end
    wrap('TextColored', 2);
    L.dprint('active', m, tostring(client_jp));
end

-- 描画リスト DL.T（公式の文字描画の要）を翻訳付きに

-------------------------------------------------------------------- デバッグ表示（内部用）
JP.dbg = false;
local DSEEN = {};
local function hex(x)
    if type(x) ~= 'string' then return tostring(x); end
    local t = {};
    for i = 1, math.min(#x, 12) do t[#t + 1] = string.format('%02X', x:byte(i)); end
    return t[1] and table.concat(t, ' ') or '(空)';
end
JP.hex = hex;
local function dlog(key, ...)
    if not JP.dbg or DSEEN[key] then return; end
    DSEEN[key] = true;
    local p = {};
    for i = 1, select('#', ...) do p[#p + 1] = tostring((select(i, ...))); end
    print('[YUI-JPDBG] ' .. table.concat(p, ' | '));
end
JP.dlog = dlog;
-- いま使われているフォントに日本語の字形があるか（true/false、わからなければ nil）
local function cur_font_info()
    local f, has, how = nil, nil, '?';
    pcall(function() f = imgui.GetFont(); end);
    if f ~= nil then
        pcall(function()
            local g = f:FindGlyphNoFallback(0x3042);
            has = (g ~= nil); how = 'FindGlyphNoFallback';
        end);
        if has == nil then
            has = JP.MERGED[tostring(f)] == true; how = 'merged-list';
            if not has then for _, m in ipairs(JP.MERGED) do if rawequal(m, f) or m == f then has = true; break; end end end
            if not has and YUI_FONTS then for _, k in ipairs({ 'main', 'semi', 'title', 'chat' }) do if YUI_FONTS[k] == f then has = true; break; end end end
            if not has and YUI_FONTS and YUI_FONTS.sized then
                for _, list in pairs(YUI_FONTS.sized) do for _, e in ipairs(list) do if e[1] == f then has = true; break; end end end
            end
        end
    end
    return f, has, how;
end
local function jp_font()
    local F = YUI_FONTS;
    if F then
        if F.chat then return F.chat; end
        if F.main then return F.main; end
    end
    return JP.MERGED[1];
end
-- 日本語を含む描画を「日本語の字形がある」フォントで行う（公式は既定フォントのまま描く場所がある → ???）
local function with_jp(where, text, fn, ...)
    if not (JP.active and type(text) == 'string' and text:find('[\128-\255]')) then return fn(...); end
    local cur, has, how = cur_font_info();
    local pf = nil;
    if has ~= true then pf = jp_font(); end
    if JP.dbg then dlog('font:' .. where .. ':' .. tostring(cur), 'font', where, 'cur=' .. tostring(cur), 'hasJP=' .. tostring(has) .. '(' .. how .. ')', 'push=' .. tostring(pf), 'text=' .. text:sub(1, 30)); end
    if pf == nil then return fn(...); end
    local ok = false;
    local sz = nil; pcall(function() sz = imgui.GetFontSize(); end);
    local restore = nil;
    if YUI_NEWFONT and YUI_NEWFONT(pf) then
        -- 0 = 今の文字サイズのまま（GetFontSize() は窓の倍率込みなので渡すと倍率が二重に掛かり、日本語だけ小さくなっていた）
        ok = pcall(imgui.PushFont, pf, 0);
    else
        ok = pcall(imgui.PushFont, pf);
        if ok and sz then                                            -- 古い ImGui: 差し替えたフォントの元サイズに合わせて倍率を補正
            pcall(function()
                local fs0, fs1 = cur and cur.FontSize, pf.FontSize;
                if fs0 and fs1 and fs0 > 0 and fs1 > 0 then
                    imgui.SetWindowFontScale(sz / fs1); restore = sz / fs0;
                end
            end);
        end
    end
    local r = { pcall(fn, ...) };
    if restore then pcall(imgui.SetWindowFontScale, restore); end
    if ok then pcall(imgui.PopFont); end
    if not r[1] then error(r[2], 0); end
    return unpack(r, 2);
end
JP.with_jp = with_jp;
function JP.me_font()                                                -- (マクロ編集の窓: 既定フォントに日本語の字がない → ??? 。窓ごと日本語入りのフォントで)
    local cur, has = cur_font_info();
    if has == true then return false; end
    local pf = jp_font();
    if pf == nil then return false; end
    local ok = (YUI_NEWFONT and YUI_NEWFONT(pf)) and pcall(imgui.PushFont, pf, 0) or pcall(imgui.PushFont, pf);
    return ok;
end
function JP.wrap_dl(DL)
    if not JP.active then return; end
    local T = DL.T;
    DL.T = function(d, a, b, col, t, ...) t = JP.t(t); if JP.chat_current() then return JP.chat_draw(T, d, a, b, col, t, ...); end return with_jp('DL.T', t, T, d, a, b, col, t, ...); end
end

-------------------------------------------------------------------- フォント（日本語フォントを合成）
function JP.fonts(fonts)
    JP.load_chat_fonts(fonts);
    -- ツールチップ（装備の「メイン: ○○」など）を日本語の字形があるフォントで出す
    if JP.active and type(YUI_TIP) == 'function' and not JP.tip_wrapped then
        JP.tip_wrapped = true;
        local TIP = YUI_TIP;
        YUI_TIP = function(t, ...) local s = JP.t(tostring(t or '')); return with_jp('YUI_TIP', s, TIP, s, ...); end
    end
    if JP.dbg then dlog('fonts', 'fonts', 'main=' .. tostring(fonts and fonts.main), 'chat=' .. tostring(fonts and fonts.chat), 'merged=' .. #JP.MERGED); end
    -- 日本語の合成と同一フォントの共用は hook_fonts() で管理する。
end

-------------------------------------------------------------------- リキャストタイマーの名前
local SP1 = { 'マイティストライク', '百烈拳', '女神の印', '魔力の泉', '連続魔', '絶対回避', 'インビンシブル',
    'ブラッドウェポン', '使い魔', 'ソウルボイス', 'イーグルアイ', '明鏡止水', '微塵がくれ', '竜剣', 'アストラルフロウ',
    'アジュールロー', 'ワイルドカード', 'オーバードライヴ', 'トランス', '連環計', 'ボルスター', 'エレメンタルスフォルツォ' };
local SP2 = { 'ブラーゼンラッシュ', 'インナーストレングス', 'アサイラム', 'サトルソーサリー', 'スタイミー', 'ラーセニー', 'インターヴィーン', 'ソールエンスレーヴ',
    'アンリーシュ', 'クラリオンコール', 'オーバーキル', '八重霞', '御影', 'フライハイ', 'アストラルパッセージ', 'アンブライドルワイズダム', 'カットカード',
    'ヘディーアーティファイス', 'グランドパー', 'ケイパーエミサリウス', 'ワイデンコンパス', 'オディリックサブタージュ' };
local NAMES = { [12] = 'カスケード', [231] = 'ストラタジェム', [242] = 'ジグ' };
local CHG = { ['Quick Draw'] = 'クイックドロー', ['Ready'] = 'しじをさせろ' };
local FAKE = { { '明鏡止水', 3600, 'sp' }, { '八双', 60, 'ja' }, { '黙想', 180, 'ja' }, { 'バーサク', 300, 'ja' },
    { 'ウォークライ', 300, 'ja' }, { 'ケアルIV', 12, 'ma' } };
-- ゲームデータの名前（日本語クライアント: 言語0=日本語 を優先。「???」はデータの読み違いなので捨てる）
good = function(x) return type(x) == 'string' and x ~= '' and not x:find('^[%?%s]+$'); end
local function u8(x) if YUI_U8 then local ok, r = pcall(YUI_U8, x); if ok and type(r) == 'string' then return r; end end return x; end
local function gs(kind, id)
    local s;
    pcall(function() local x = vana.ashita.string(kind, id, 0); if good(x) then s = x; end end);
    if not s then pcall(function() local x = AshitaCore:GetResourceManager():GetString(kind, id); if good(x) then s = x; end end); end
    return s and u8(s) or nil;
end
JP.gs = gs;
-- ゲームデータの名前の取り違えを一か所で直す（公式は r.Name[1] と GetString を使うが、
-- 日本語クライアントでは Name[1] / GetString が「???」になる環境がある → Name[0]・言語0 を使う）
-- AshitaCore を薄い代理に差し替えるだけなので、公式本体の名前取得コードは一切変えなくてよい。
local function fix_name(r)
    if r == nil then return r; end
    local ok, nm = pcall(function() return r.Name; end);
    if not ok or nm == nil then return r; end
    local n0, n1;
    pcall(function() n0 = nm[0]; end);
    pcall(function() n1 = nm[1]; end);
    if good(n1) and not (good(n0) and n0:find('[\128-\255]')) then return r; end   -- (そのままで正しい)
    if not good(n0) then return r; end
    local names = setmetatable({ [0] = n0, [1] = n0 }, { __index = function(_, k) local v; pcall(function() v = nm[k]; end); return v; end });
    return setmetatable({}, { __index = function(_, k) if k == 'Name' then return names; end return r[k]; end });
end
install_core_proxy = function()
    local real = AshitaCore;
    if type(real) ~= 'userdata' and type(real) ~= 'table' then return; end
    local rm_real, rm_proxy;
    local function method(obj, k, proxy, wrap)
        local v = obj[k];
        if type(v) ~= 'function' then return v; end
        return function(self, ...)
            if self == proxy then self = obj; end
            if wrap then return wrap(v(self, ...), ...); end
            return v(self, ...);
        end
    end
    local function rm()
        local cur = real:GetResourceManager();
        if cur ~= rm_real or rm_proxy == nil then
            rm_real = cur;
            local cache = {};
            rm_proxy = setmetatable({}, { __index = function(t, k)
                local c = cache[k];
                if c ~= nil then return c; end
                local w = nil;
                if type(k) == 'string' and k:find('^Get%a+By') then
                    w = function(r) return fix_name(r); end
                elseif k == 'GetString' then
                    w = function(s, kind, id)
                        if good(s) then return s; end
                        local x; pcall(function() x = vana.ashita.string(kind, id, 0); end);
                        return good(x) and x or s;
                    end
                end
                c = method(cur, k, t, w);
                if type(c) == 'function' then cache[k] = c; end
                return c;
            end });
        end
        return rm_proxy;
    end
    local core = {};
    local proxy = setmetatable({}, { __index = function(t, k)
        if k == 'GetResourceManager' then return function() return rm(); end end
        local c = core[k];
        if c ~= nil then return c; end
        c = method(real, k, t);
        if type(c) == 'function' then core[k] = c; end
        return c;
    end });
    AshitaCore = proxy;
end
-- 装備名（102j と同じ: Name[0] を優先し、YUI_U8 で UTF-8 にする）
function JP.item_name(r, name)
    if not JP.active then return name; end
    local raw = nil;
    pcall(function() raw = r and r.Name and (r.Name[0] or r.Name[1]) or nil; end);
    if JP.dbg then
        local n0, n1; pcall(function() n0 = r.Name[0]; end); pcall(function() n1 = r.Name[1]; end);
        local id_; pcall(function() id_ = r.Id; end);
        dlog('item:' .. tostring(id_), 'item', 'id=' .. tostring(id_), 'Name0=' .. hex(n0), 'Name1=' .. hex(n1), 'u8(Name0)=' .. tostring(n0 and u8(n0)), 'u8hex=' .. hex(n0 and u8(n0)));
    end
    if not good(raw) then raw = name; end
    if raw == nil then return name; end
    local u = u8(raw);
    if good(u) then return u; end
    return name;
end
-------------------------------------------------------------------- 戦利品ボックス
-- 公式は Name[1]（英語）で名前を取り、大文字にして1バイトずつ描く → 日本語名にし、文字単位で描く（letters 側のフック）
local function loot_jp_name(id)
    local r = nil;
    pcall(function() r = AshitaCore:GetResourceManager():GetItemById(id); end);
    if r == nil then return nil; end
    local nm = JP.item_name(r, nil);
    if good(nm) and nm ~= '' then return nm; end
    return nil;
end
function JP.loot(C)
    if not JP.active or type(C) ~= 'table' or type(C.loot_name) ~= 'function' or C.jp_loot then return; end
    C.jp_loot = true;
    local ORIG, cache = C.loot_name, {};
    C.loot_name = function(id)
        local v = cache[id];
        if v == nil then
            v = loot_jp_name(id);
            if v then cache[id] = v; else return ORIG(id); end   -- (取れない時は公式どおり・次回また試す)
        end
        return v;
    end
    -- 設定画面・編集モードのお試し表示（公式は英語名を直書き）
    local F = C.LOOT and C.LOOT.FAKE;
    if type(F) == 'table' then
        local DEF = { [4096] = '炎のクリスタル', [13014] = 'リーピングブーツ', [640] = '銅鉱' };
        for _, f in ipairs(F) do if type(f) == 'table' and DEF[f[1]] then f[2] = DEF[f[1]]; end end
    end
end
-- 名前が枠に入らない時、文字の途中で切らずに縮める（公式は1バイトずつ削る＝日本語が壊れる）
function JP.fit(nm, room, gap)
    if not JP.mb(nm) then return nm; end
    if JP.spaced_w(nm, gap) <= room then return nm; end
    local cs = chars(nm);
    while #cs > 1 do
        cs[#cs] = nil;
        local t = table.concat(cs) .. '.';
        if JP.spaced_w(t, gap) <= room then return t; end
    end
    return table.concat(cs) .. '.';
end
-- ミニマップ出口名（102j と同じ順で探す。「???」はキャッシュしない）
-- 戻り値: 正しい名前 / ''（描かない・キャッシュしない → 次のフレームで再試行）
function JP.exit_name(cache, id, nm)
    if not JP.active then return nm; end
    if good(nm) and not (JP.dbg and not DSEEN['exit:' .. tostring(id)]) then return nm; end
    local rn = '';
    if JP.dbg then
        local rm, a1, a2, a3, a4; pcall(function() rm = AshitaCore:GetResourceManager(); end);
        pcall(function() a1 = rm:GetString('zones.names', id); end);
        pcall(function() a2 = rm:GetString('ZoneName', id); end);
        pcall(function() a3 = rm:GetZoneName(id); end);
        pcall(function() a4 = vana.ashita.string('zones.names', id, 0); end);
        dlog('exit:' .. tostring(id), 'exit', 'id=' .. tostring(id), 'zones.names=' .. hex(a1), 'ZoneName=' .. hex(a2), 'GetZoneName=' .. hex(a3), 'vana(0)=' .. hex(a4), 'u8(vana)=' .. tostring(a4 and u8(a4)) .. ' [' .. hex(a4 and u8(a4)) .. ']', 'cached=' .. hex(nm));
    end
    pcall(function()
        local rm = AshitaCore:GetResourceManager();
        local s; pcall(function() s = rm:GetString('zones.names', id); end);
        if good(s) then rn = s; return; end
        pcall(function() s = rm:GetString('ZoneName', id); end);
        if good(s) then rn = s; return; end
        if rm.GetZoneName then pcall(function() s = rm:GetZoneName(id); end); if good(s) then rn = s; return; end end
    end);
    if rn == '' and vana and vana.ashita and vana.ashita.string then
        local s; pcall(function() s = vana.ashita.string('zones.names', id, 0); end);
        if good(s) then rn = s; end
    end
    rn = tostring(rn):gsub('^%s+', ''):gsub('%s+$', '');
    if good(rn) then
        local u = u8(rn); if good(u) then rn = u; end
        cache[id] = rn;
        return rn;
    end
    cache[id] = nil;
    return '';
end
-- 「文字サイズのみ」（ja.lua と同じ cfg.font_scale を使う。英語表示では 1 倍＝公式どおり）
-- ミニマップ窓の中だけ文字を大きくする（yunaui_jp_settings.lua の minimap_text_scale、既定 1.3）
-- YMAP.mini（ミニマップ窓の描画）を包み、その実行中だけ sized()/push_font の大きさに掛ける。窓の外には効かない。
local in_mini = false;
local function mini_k()
    if not (in_mini and JP.active) then return 1; end
    return tonumber(JP.cfg.minimap_text_scale) or 1.3;
end
local function hook_mini()
    if JP.mini_wrapped or type(YMAP) ~= 'table' or type(YMAP.mini) ~= 'function' then return; end
    JP.mini_wrapped = true;
    local MINI = YMAP.mini;
    YMAP.mini = function(...)
        in_mini = true;
        local r = { pcall(MINI, ...) };
        in_mini = false;
        if not r[1] then error(r[2], 0); end
        return unpack(r, 2);
    end
    -- 出口名（ジュノ港など）は既定フォントのまま描かれるので、ミニマップ内の時だけ窓の文字倍率を掛ける
    -- （公式の sized()/unsized() も倍率 1 を基準に戻すので、それに合わせて 1 に戻す）
    if type(YMAP.exits_draw) == 'function' then
        local EX = YMAP.exits_draw;
        YMAP.exits_draw = function(...)
            local k = mini_k();
            if k == 1 then return EX(...); end
            pcall(imgui.SetWindowFontScale, k);
            local r = { pcall(EX, ...) };
            pcall(imgui.SetWindowFontScale, 1);
            if not r[1] then error(r[2], 0); end
            return unpack(r, 2);
        end
    end
end
JP.hook_mini = hook_mini;
function JP.fsize(size, cfg)
    if not JP.active or type(cfg) ~= 'table' then return size; end   -- (English: nothing wrapped - YunaUI exactly as it is)
    if not JP.mini_wrapped then hook_mini(); end
    JP.skip_ps = true;                                               -- (sized() はここで倍率済み: 直後の push_font では掛けない)
    return size * (tonumber(cfg.font_scale) or 1.0) * mini_k();
end
-- push_font を直接使う所（設定メニュー・見出し・ボタンなど）にも「テキストサイズのみ」を効かせる
function JP.psize(size, cfg)
    if JP.skip_ps then JP.skip_ps = false; return size; end
    if not JP.active or type(cfg) ~= 'table' or type(size) ~= 'number' then return size; end
    return size * (tonumber(cfg.font_scale) or 1.0) * mini_k();
end
-- 古い ImGui（フォントにサイズを渡せない）では設定メニューの文字倍率に掛ける
function JP.panel_wfs(C, pf, cfg)
    if not JP.active or type(cfg) ~= 'table' then return; end
    local k = tonumber(cfg.font_scale) or 1.0;
    if k == 1 then return; end
    if pf == nil or not YUI_NEWFONT(pf) then C.wfs = (C.wfs or 1) * k; pcall(imgui.SetWindowFontScale, C.wfs); end
end
function JP.size_ui(row_slider, cfg)
    if not JP.active or type(cfg) ~= 'table' then return; end
    if tonumber(cfg.font_scale) == nil then cfg.font_scale = 1.0; end
    row_slider('##yui_fscale', 'Text size only', 'font_scale', 0.5, 3.0, 0.05, '%.2fx');
end
function JP.timers(TIMERS)
    if not JP.active or type(TIMERS) ~= 'table' then return; end
    local abil, chg, strats, scan = TIMERS.abil_name, TIMERS.charges, TIMERS.strats, TIMERS.scan;
    local an, sn = {}, {};
    TIMERS.abil_name = function(id, job)
        if id == 0 or id == 254 then
            local key = 'sp' .. id .. '_' .. tostring(job);
            if an[key] == nil then
                an[key] = false;
                local en = abil(id, job);
                pcall(function()
                    local rm = AshitaCore:GetResourceManager();
                    local r = rm:GetAbilityByName(en, 0) or rm:GetAbilityByName(en, 2);
                    if r and r.Id then an[key] = gs('abilities.names', r.Id) or false; end
                end);
                if an[key] and not an[key]:find('[\128-\255]') then an[key] = false; end   -- (英語が返ったら下の表を使う)
            end
            if an[key] then return an[key]; end
            if id == 0 then return SP1[job] or '（1時間）'; end
            return SP2[job] or '（2時間）';
        end
        if NAMES[id] then return NAMES[id]; end
        if YUI_JP then
            local key = id;
            if an[key] == nil then
                local r = AshitaCore:GetResourceManager():GetAbilityByTimerId(id);
                an[key] = (r and r.Id and gs('abilities.names', r.Id)) or false;
            end
            if an[key] then return an[key]; end
        end
        local n = abil(id, job);
        return (n == '(Ability)') and '（アビリティ）' or n;
    end
    TIMERS.charges = function(name, ...) return chg(CHG[name] or name, ...); end
    TIMERS.strats = function(...)
        local s, a, b = strats(...);
        return (s:gsub('^Stratagems', 'ストラタジェム')), a, b;
    end
    TIMERS.scan = function(...)
        scan(...);
        if not YUI_JP then return; end              -- (英語クライアントでは魔法名の日本語データが無い)
        for id, e in pairs(TIMERS.spells or {}) do
            if type(id) == 'number' and type(e) == 'table' then
                if sn[id] == nil then sn[id] = gs('spells.names', id) or false; end
                if sn[id] then e.name = sn[id]; end
            end
        end
    end
    TIMERS.FAKE = FAKE;
end

-------------------------------------------------------------------- 設定画面「言語」セクション
local LBL = { auto = 'Auto', en = 'English', ja = '日本語' };
function JP.settings_ui(section, accent_button, hint, row_slider, row_pick)
    section('LANGUAGE');
    local avail = 300;
    pcall(function() local a = imgui.GetContentRegionAvail(); avail = (type(a) == 'table' and a[1]) or tonumber(a) or avail; end);
    if tonumber(YUI_ROW_W) then avail = math.min(avail, tonumber(YUI_ROW_W)); end   -- (on a card in the panel: the card's width)
    local bw = math.floor((avail - 16) / 3);
    for i, k in ipairs({ 'auto', 'en', 'ja' }) do
        if i > 1 then imgui.SameLine(); end
        local nm = LBL[k];
        if k == 'ja' and not JP.active then nm = 'Japanese'; end    -- (英語表示のフォントには日本語の字がない: "???" ではなく Japanese と出す)
        local label = JP.t(nm) .. '##yui_lang_' .. k;                -- (the chosen one: its chip white, no dot)
        local ok, clicked = pcall(accent_button, label, { bw, 0 }, JP.cfg.ui_lang ~= k, true);
        if not ok then clicked = imgui.Button(label, { bw, 0 }); end
        if clicked and JP.cfg.ui_lang ~= k then JP.cfg.ui_lang = k; save_cfg(); end
    end
    hint(JP.t('Auto follows the game client. Reload the addon after changing (/addon reload yunaui).'));
    if JP.active then                                                -- (Japanese: keep YunaUI's own fonts for English letters and numbers)
        local on = JP.cfg.keep_fonts == true;
        local label = JP.t(on and 'Keep YunaUI fonts: On' or 'Keep YunaUI fonts: Off') .. '##yui_jp_keepf';
        local ok, clicked = pcall(accent_button, label, { avail, 0 }, not on, true);
        if not ok then clicked = imgui.Button(label, { avail, 0 }); end
        if clicked then JP.cfg.keep_fonts = not on; save_cfg(); end
        hint(JP.t("On: HP, MP, numbers and English names keep YunaUI's own fonts; menus, items and weapon skills stay in Japanese. Reload the addon after changing."));
    end
    if JP.active and type(row_pick) == 'function' then             -- 言語 > フォント（プルダウン）
        local opts = { { 'default', 'デフォルト（メイリオ）' }, { 'meiryo', 'メイリオ (Windows)' } };
        local have = { default = true, meiryo = true };
        for _, n in ipairs(JP.font_list()) do
            opts[#opts + 1] = { n, (n:gsub('%.[^%.]+$', '')) }; have[n] = true;
        end
        local cur = JP.cfg.font or 'default';
        if not have[cur] then opts[#opts + 1] = { cur, (cur:gsub('%.[^%.]+$', '')) .. '（見つかりません）' }; end
        row_pick('##yui_jp_font', 'フォント', 'font', opts, JP.cfg, function() save_cfg(); end);
        hint('変更後は /addon reload yunaui で反映されます。');
        hint('fonts フォルダのフォントから選べます。日本語の字がないフォントは、日本語の部分をメイリオで表示します。');
        local pp = picked_path();
        if (JP.cfg.font or 'default') ~= 'default' and not pp then hint('選んだフォントが見つからないため、デフォルトで表示中です。'); end
        local okl, dir_, how_ = JP.font_list_status();
        if not okl then imgui.TextColored({ 0.6, 0.6, 0.65, 1 }, 'fontsフォルダを読めませんでした: ' .. tostring(dir_) .. (how_ and ('（' .. how_ .. '）') or '')); end
    end
end

-------------------------------------------------------------------- チャット > 縁取りと影（チャットの文字だけに効く）
-- 縁取りと影の行は公式の行（row_slider / row_switch / row_pick）をそのまま使う:
-- 変更は公式の「元に戻す」（Undo の表示・Ctrl+Z）に入る。公式の行と同じく、ダブルクリックで既定値に戻す（これも Undo 可）。
local function row_hovered(x0, y0, h)
    local rw = tonumber(YUI_ROW_W) or 300;
    local inside = false;
    pcall(function() inside = imgui.IsMouseHoveringRect({ x0, y0 }, { x0 + rw, y0 + h }); end);
    if not inside then pcall(function() local mx, my = imgui.GetMousePos(); if type(mx) == 'table' then mx, my = mx[1] or mx.x, mx[2] or mx.y; end inside = mx >= x0 and mx <= x0 + rw and my >= y0 and my <= y0 + h; end); end
    if inside then local wh = true; pcall(function() wh = imgui.IsWindowHovered(); end); inside = wh ~= false; end
    return inside;
end
local function fx_row(draw, key, text, tip, on_change)
    local c = JP.cfg;
    local x0, y0 = imgui.GetCursorScreenPos();
    local h = imgui.GetFrameHeight();
    draw();
    if not row_hovered(x0, y0, h) then return; end
    if tip then YUI_TIP(tip); end
    if key and FX_DEF[key] ~= nil and imgui.IsMouseDoubleClicked(0) and c[key] ~= FX_DEF[key] then
        local old = c[key];
        c[key] = FX_DEF[key]; on_change(key, c[key]);
        if YUI_UNDO_PUSH then pcall(YUI_UNDO_PUSH, c, key, old, text, on_change); end
    end
end
function JP.chat_fx_ui(section, accent_button, hint, row_slider, row_switch, row_pick)
    if not JP.active or type(row_slider) ~= 'function' then return; end
    local c = JP.cfg;
    local function fix(step, after)                                  -- (公式の行の on_change: 刻みに丸めて保存。Undo からも呼ばれる)
        return function(key)
            if step then c[key] = math.floor((tonumber(c[key]) or 0) / step + 0.5) * step; end
            if after then after(); end
            save_cfg();
        end
    end
    local function slider(id, text, key, lo, hi, step, fmt, tip, after)
        local oc = fix(step, after);
        fx_row(function() row_slider(id, text, key, lo, hi, step, fmt, c, oc); end, key, text, tip, oc);
    end
    section('チャットの縁取りと影');
    slider('##yui_jpow', '縁取りの太さ', 'chat_outline_w', 0, 3, 0.25, '%.2f px',
        'チャットの文字のまわりの黒い縁取りの太さ（ピクセル）。0 で縁取りなし。1 が公式と同じです。\nダブルクリックで既定値（1.00 px）に戻します。',
        function() c.chat_outline_on = (tonumber(c.chat_outline_w) or 0) > 0; end);
    slider('##yui_jpoa', '縁取りの濃さ', 'chat_outline_pct', 0, 100, 1, '%d%%', '縁取りの濃さ。0% で見えなくなります。\nダブルクリックで既定値（85%）に戻します。');
    local sw = fix(nil);
    if type(row_switch) == 'function' then
        row_switch('##yui_jpsh', '影', 'chat_shadow', 'オン: 文字の右下に影を付けます。オフ: 影なし（縁取りだけ）。', c, sw);
    end
    if c.chat_shadow ~= false then
        if type(row_pick) == 'function' then
            fx_row(function() row_pick('##yui_jpsc', '影の色', 'chat_shadow_col', { { 'black', '黒' }, { 'gray', '濃い灰' }, { 'white', '白' } }, c, sw); end,
                nil, '影の色', '黒（既定）・少し柔らかい濃い灰・白（暗い背景で文字を浮き立たせます）。', sw);
        end
        slider('##yui_jpsd', '影の距離', 'chat_shadow_dist', 1, 6, 0.5, '%.1f px', '文字から右下へ、影をどれだけずらすか（ピクセル）。\nダブルクリックで既定値（2.0 px）に戻します。');
        slider('##yui_jpsa', '影の濃さ', 'chat_shadow_pct', 0, 100, 1, '%d%%', '影の濃さ。0% で見えなくなります。\nダブルクリックで既定値（85%）に戻します。');
    end
    hint('すぐに反映。変更は「元に戻す」（Ctrl+Z）で戻せます。');
end

-------------------------------------------------------------------- チャットの縁取りと影
-- chat_line のフック1: 公式の縁取り（黒い8点）の濃さ・なしを設定から返す
local EDGE_CACHE = {};
function JP.chat_edge(edge)
    if not JP.active or type(edge) ~= 'table' then return edge; end
    local c = JP.cfg;
    local w = tonumber(c.chat_outline_w) or 1;
    local al = (w <= 0) and 0 or ((tonumber(c.chat_outline_pct) or 85) / 100);
    local key = tostring(edge) .. ':' .. al .. ':' .. w;
    if EDGE_CACHE[key] then return EDGE_CACHE[key]; end
    local pts = edge[1];
    if al > 0 and math.abs(w - 1) > 1e-6 then                         -- (太さ: 1 は公式の8点そのまま。1.5 を超えると隙間が出るので16点）
        pts = {};
        local n = (w > 1.5) and 16 or 8;
        for k = 0, n - 1 do
            local t_ = k * 2 * math.pi / n;
            local ox, oy = math.cos(t_), math.sin(t_);
            if n == 8 then ox, oy = (math.abs(ox) > 0.3) and (ox > 0 and 1 or -1) or 0, (math.abs(oy) > 0.3) and (oy > 0 and 1 or -1) or 0; end
            pts[#pts + 1] = { ox * w, oy * w };
        end
    end
    local r = { (al > 0) and pts or {}, al };
    EDGE_CACHE[key] = r;
    return r;
end
-- chat_line のフック2: 縁取りの前に右下の影を、設定の色・濃さ・距離で描く
local SHCOL = { black = { 0, 0, 0 }, gray = { 0.28, 0.28, 0.30 }, white = { 1, 1, 1 } };
function JP.chat_shadow_pass(dl, T, x, y, str, a)
    local c = JP.cfg;
    if not JP.active or c.chat_shadow == false then return; end
    local al = c.chat_shadow_pct / 100 * (tonumber(a) or 1);
    if al <= 0 then return; end
    local rgb = SHCOL[c.chat_shadow_col] or SHCOL.black;
    local col = imgui.GetColorU32({ rgb[1], rgb[2], rgb[3], al });
    T(dl, x + c.chat_shadow_dist, y + c.chat_shadow_dist, col, str);
end

-------------------------------------------------------------------- チャットのフォント（言語 > フォントで選んだもの）
-- UI全体のフォントとは別の領域で保持（CHATの描画判定が他のUIへ波及しないように）。
-- 1つのフォントで日英とも同じ大きさ: 計測・描画は公式どおり（uniform）。サイズ可変フォントなら1つだけ読む。
local CHAT = { fonts = {}, ja = {}, en = {}, max = 1, ja_k = 1, en_k = 1, scale = 1, busy = false };
local function first_font(paths)
    for _, path in ipairs(paths) do if fexists(path) then return path; end end
end
function JP.load_chat_fonts(fonts)
    if not JP.active or not fonts or not fonts.sized or not JP.raw_add_font then return; end
    local dir = win_fonts();
    local ja = picked_path() or first_font({ dir .. 'meiryob.ttc', dir .. 'meiryo.ttc', dir .. 'YuGothM.ttc', dir .. 'msgothic.ttc' });   -- (デフォルト: 今まで通りメイリオ太字)
    if not ja then return; end
    CHAT.uniform = true;
    -- CHAT > 日本語の文字サイズ (cfg.chat_jp_scale, YUI_CHAT_JPK): 英字フォントなら合成する日本語をその大きさで、
    -- 日本語のあるフォントなら日本語の部分だけをその倍率で描く（1.1.66 で効かなくなっていた）
    local jk = tonumber(YUI_CHAT_JPK) or 1;
    local own_jp = has_japanese(ja);
    if own_jp and math.abs(jk - 1) > 0.001 then CHAT.uniform, CHAT.ja_k = false, jk; end
    local prev = YUI_JPK;
    YUI_JPK = (not own_jp and math.abs(jk - 1) > 0.001) and jk or nil;
    for _, px in ipairs({ 13, 16, 20, 26, 34 }) do
        local ok, jf = pcall(JP.raw_add_font, ja, px);
        if ok and jf then
            CHAT.ja[#CHAT.ja + 1] = { jf, px }; CHAT.en[#CHAT.en + 1] = { jf, px };
            CHAT.fonts[tostring(jf)] = true;
        end
    end
    YUI_JPK = prev;
    if #CHAT.ja == 0 then return; end
    fonts.sized.jpchat = CHAT.ja;
    CHAT.ready = true;
end
function JP.chat_kind() return CHAT.ready and 'jpchat' or 'chat'; end
function JP.chat_size(size) return CHAT.ready and size * CHAT.max or size; end
function JP.chat_current()
    if not CHAT.ready or CHAT.busy then return false; end
    local f = imgui.GetFont(); return f ~= nil and CHAT.fonts[tostring(f)] == true;
end
local RUNS, RN = {}, 0;
local function chat_runs(text)
    text = tostring((YUI_U8 and YUI_U8(text)) or text or '');
    if RUNS[text] then return RUNS[text]; end
    local runs, cur, kind = {}, '', nil;
    for _, ch in ipairs(chars(text)) do
        local k = ch:byte() < 128 and 'en' or 'ja';
        if k ~= kind and cur ~= '' then runs[#runs + 1] = { cur, kind }; cur = ''; end
        cur, kind = cur .. ch, k;
    end
    if cur ~= '' then runs[#runs + 1] = { cur, kind }; end
    if RN > 2048 then RUNS, RN = {}, 0; end
    RUNS[text], RN = runs, RN + 1;
    return runs;
end
-- PushFont(font, 0) は新ImGuiの現在の基準サイズを引き継ぐ。
-- 旧ImGuiはベイク済みの大きさを使い、窓倍率を一時補正する。
local function chat_run(kind, size, fn)
    local k = (kind == 'ja') and CHAT.ja_k or CHAT.en_k;
    local list = CHAT[kind];
    local pick = list[#list];
    for _, e in ipairs(list) do if e[2] >= size * k / CHAT.max then pick = e; break; end end
    local scale, new = CHAT.scale, YUI_NEWFONT and YUI_NEWFONT(pick[1]);
    local ok, err;
    if new then ok, err = pcall(imgui.PushFont, pick[1], 0);
    else ok, err = pcall(imgui.PushFont, pick[1]); end
    if not ok then error(err, 0); end
    local ratio = k / CHAT.max;
    imgui.SetWindowFontScale(new and (scale * ratio) or (size * ratio / pick[2]));
    local result = { pcall(fn) };
    imgui.PopFont(); imgui.SetWindowFontScale(scale);
    if not result[1] then error(result[2], 0); end
    return unpack(result, 2);
end
-- この計測と描画はラップ前のCalcTextSizeを使用（翻訳や再帰による日英の不一致を防止）。
function JP.hook_chat_metrics()
    local scale = imgui.SetWindowFontScale;
    imgui.SetWindowFontScale = function(k) CHAT.scale = k; return scale(k); end
    local calc = imgui.CalcTextSize;
    CHAT.calc = calc;
    imgui.CalcTextSize = function(text, ...)
        if not JP.chat_current() then return calc(text, ...); end
        text = JP.t(text);
        return JP.chat_measure(text);
    end
end
local WIDTHS, WN = {}, 0;
function JP.chat_measure(text)
    if CHAT.uniform then return CHAT.calc((YUI_U8 and YUI_U8(text)) or text); end
    local size = imgui.GetFontSize();
    local str = tostring((YUI_U8 and YUI_U8(text)) or text or '');
    local key = tostring(size) .. ':' .. str;
    local cached = WIDTHS[key]; if cached then return cached[1], cached[2]; end
    local width, height = 0, 0;
    CHAT.busy = true;
    local ok, err = pcall(function()
        for _, run in ipairs(chat_runs(str)) do
            local w, h = chat_run(run[2], size, function() return CHAT.calc(run[1]); end);
            width, height = width + w, math.max(height, h or 0);
        end
    end);
    CHAT.busy = false;
    if not ok then error(err, 0); end
    if WN > 4096 then WIDTHS, WN = {}, 0; end
    WIDTHS[key], WN = { width, height }, WN + 1;
    return width, height;
end
function JP.chat_draw(T, dl, x, y, col, text, ...)
    if CHAT.uniform then return T(dl, x, y, col, text, ...); end
    local size, cx = imgui.GetFontSize(), x;
    local args = { ... };
    CHAT.busy = true;
    local ok, err = pcall(function()
        for _, run in ipairs(chat_runs(text)) do
            local w = chat_run(run[2], size, function()
                T(dl, cx, y, col, run[1], unpack(args));
                return CHAT.calc(run[1]);
            end);
            cx = cx + w;
        end
    end);
    CHAT.busy = false;
    if not ok then error(err, 0); end
end
function JP.chat_icon_height(lh)
    return JP.chat_current() and imgui.GetTextLineHeight() or (lh - 2);
end
function JP.chat_line_width(s)
    s = (YUI_U8 and YUI_U8(s)) or s;
    local w, i = 0, 1;
    while i <= #s do
        local j = s:find('[<>\1\2]', i);
        local run = s:sub(i, (j or (#s + 1)) - 1);
        if run ~= '' then w = w + imgui.CalcTextSize(run); end
        if not j then break; end
        local ch = s:sub(j, j);
        if ch == '\1' or ch == '\2' then w = w + imgui.GetTextLineHeight() * 0.42 + 2;
        else w = w + imgui.CalcTextSize(ch); end
        i = j + 1;
    end
    if s:match('^<([^<>\1\2]+)>') then w = w + 2 * math.max(1, imgui.GetTextLineHeight() * 0.14); end
    return w;
end

-- 公式の空白区切りを維持し、長い単語・空白のない日本語だけ文字単位で安全に折り返す。
-- UTF-8 / 定型文アイコン(\1,\2)をバイト途中で切らない。
function JP.chat_wrap(e, maxw, key, clear)
    local sig = tostring(maxw) .. ':' .. tostring(imgui.GetFontSize()) .. ':' .. tostring(key) .. ':' .. tostring(clear);
    if e.jp_wrap_sig == sig and e.jp_wrap_text == e.text then return e.jp_lines, e.jp_ts; end
    local tl = clear and (e.tslen or 0) or 0;
    local ts = (tl > 0 and #e.text > tl) and e.text:sub(1, tl) or nil;
    local body = ts and e.text:sub(tl + 1) or e.text;
    body = (YUI_U8 and YUI_U8(body)) or body;
    local out, cur = {}, '';
    for word in body:gmatch('%S+') do
        local try = cur == '' and word or cur .. ' ' .. word;
        if cur ~= '' and JP.chat_line_width(try) > maxw then out[#out + 1], cur = cur, ''; end
        if JP.chat_line_width(word) <= maxw then cur = cur == '' and word or cur .. ' ' .. word;
        else
            for _, ch in ipairs(chars(word)) do
                if cur ~= '' and JP.chat_line_width(cur .. ch) > maxw then out[#out + 1], cur = cur, ''; end
                cur = cur .. ch;
            end
        end
    end
    if cur ~= '' then out[#out + 1] = cur; end
    if #out == 0 then out[1] = ''; end
    e.jp_wrap_sig, e.jp_wrap_text, e.jp_lines = sig, e.text, out;
    e.jp_ts = ts and (ts:gsub('[%[%]]', ''):match('^%s*(.-)%s*$')) or nil;
    return out, e.jp_ts;
end

-------------------------------------------------------------------- /yui lang
function JP.command(sub, args, msg)
    if type(msg) == 'function' then JP.msgf = msg; end               -- (公式の msg: ほかのYunaUIのメッセージと同じ出し方)
    if sub == 'jpcf' then                                            -- (戦闘ログの色分けの診断: ファイルに書く。保存はしない)
        JP.cfdbg = not JP.cfdbg;
        JP.say(JP.cfdbg and ('戦闘ログデバッグ：オン (' .. tostring(JP.CFLOG) .. ')') or '戦闘ログデバッグ：オフ');
        if JP.cfdbg then JP.cflog('---- ON ' .. os.date('%Y-%m-%d %H:%M:%S')); end
        return true;
    end
    if sub ~= 'lang' then return false; end
    local v = (args[3] or ''):lower();
    if v == 'jp' or v == 'japanese' then v = 'ja'; end
    if v == 'english' then v = 'en'; end
    if v == 'auto' or v == 'ja' or v == 'en' then
        JP.cfg.ui_lang = v; save_cfg();
        (JP.active and JP.say or print)(JP.active and string.format('言語 / Language: %s  (/addon reload yunaui で反映 / reload to apply)', v)
            or string.format('[YunaUI] Language: %s (/addon reload yunaui to apply)', v));   -- (an English client shows Japanese as garbled signs)
    else
        (JP.active and JP.say or print)(JP.active and string.format('/yui lang auto|ja|en   (今: %s  表示中: 日本語)', JP.cfg.ui_lang)
            or string.format('[YunaUI] /yui lang auto|ja|en   (now: %s, showing: English)', JP.cfg.ui_lang));
    end
    return true;
end
-------------------------------------------------------------------- 連携ガイドのWS名
-- 公式は skillchains.lua の英語名（en）をそのまま出す → ゲームのアビリティ資料（WSのid）から Name[0] を取り、
-- YUI_U8 で UTF-8 にする（装備名と同じ方法）。取れない時は英語のまま・次回また試す。
function JP.ws(FIGHT, C)
    if not JP.active or type(FIGHT) ~= 'table' or FIGHT.jp_ws then return; end
    FIGHT.jp_ws = true;
    local id_of, cache, ja2 = nil, {}, {};
    local function ja(en)
        if type(en) ~= 'string' then return en; end
        local v = cache[en];
        if v then return v; end
        if id_of == nil then
            id_of = {};
            for k, w in pairs((FIGHT.SKILLS or {})[3] or {}) do if type(w) == 'table' and w.en then id_of[w.en] = k; end end
        end
        local id = id_of[en];
        if id == nil then return en; end
        local r = nil;
        pcall(function() r = AshitaCore:GetResourceManager():GetAbilityById(id); end);
        local nm = r and JP.item_name(r, nil) or nil;
        if good(nm) and nm ~= en then cache[en] = nm; ja2[en:lower()] = nm; return nm; end
        return en;
    end
    JP.ws_name = ja;
    -- 編集モード・プレビュー用の仮のWS一覧（FIGHT.PSOPTS）も日本語に（取れるまで毎回試す）
    local function ps()
        if type(FIGHT.PSOPTS) ~= 'table' then return; end
        for _, o in ipairs(FIGHT.PSOPTS) do if type(o) == 'table' then o[1] = ja(o[1]); end end
    end
    pcall(ps);
    JP.ws_ps = ps;
    if type(FIGHT.options) == 'function' then
        local ORIG = FIGHT.options;
        FIGHT.options = function(...)
            pcall(ps);
            local res = ORIG(...);
            if type(res) == 'table' then for _, o in ipairs(res) do if type(o) == 'table' then o[1] = ja(o[1]); end end end
            return res;
        end
    end
    -- マクロの /ws "英語名" も日本語名の候補と照らし合わせられるように（光る枠の判定）
    if type(C) == 'table' and type(C.mb_wsname) == 'function' then
        local ORIGM = C.mb_wsname;
        C.mb_wsname = function(...)
            local nm = ORIGM(...);
            if type(nm) == 'string' then
                local u = ja2[nm:lower()];
                if u then return u; end
            end
            return nm;
        end
    end
end
-------------------------------------------------------------------- 戦闘ログの種類（日本語クライアント）
-- 公式 C.cf_sort の前に呼ばれる（YUI_JP_CF）。日本語の行でなければ nil を返し、英語の判定はそのまま。
local CFN = nil;                                                     -- (日本語の技名 → 'magic' / 'uses'、最初の日本語行で一度だけ作る)
local function cf_names()
    if CFN then return CFN; end
    CFN = {};
    pcall(function()
        local rm = AshitaCore:GetResourceManager();
        local function add(r, k)
            if not r or not r.Name then return; end
            for lg = 0, 3 do
                local ok, n = pcall(function() return r.Name[lg]; end);
                if ok and type(n) == 'string' and n ~= '' then
                    n = YUI_U8 and YUI_U8(n) or n;
                    if CFN[n] == nil then CFN[n] = k; end
                end
            end
        end
        for id = 0, 1023 do pcall(function() add(rm:GetSpellById(id), 'magic'); end); end
        for id = 0, 2047 do pcall(function() add(rm:GetAbilityById(id), 'uses'); end); end
    end);
    return CFN;
end
local function act_kind(nm) return cf_names()[nm]; end
JP.act_kind = act_kind;
JP.cf_last = { who = nil, t = nil };                                 -- (前の戦闘行: 「＞…」「⇒…」の続きの行が引き継ぐ)
JP.CFLOG = ((addon and addon.path or '.'):gsub('[\\/]+$', '')) .. '\\jpdebug.log';
function JP.cflog(s)                                                 -- (UTF-8 で1行ずつ追記。チャット欄には出さない）
    if not JP.cfdbg then return; end
    pcall(function() local f = io.open(JP.CFLOG, 'a'); if f then f:write(os.date('%H:%M:%S '), string.format('%.2f ', os.clock()), s, '\n'); f:close(); end end);
end
local function heal(sl) return sl:find('[HM]P.-%d+回復') or sl:find('回復した') or sl:find('吸収') end
local function arrow(sl)                                             -- (→ ＞ ⇒ のいちばん前の位置)
    local h;
    for _, a in ipairs({ '→', '＞', '⇒', '>' }) do local k = sl:find(a, 1, true); if k and (not h or k < h) then h = k; end end
    return h;
end
local function cf_text(sl)                                           -- (文字だけでの判定: 人・種類)
    local h = arrow(sl);
    local head = h and sl:sub(1, h - 1) or sl;
    local who = head:match('^(.-)の') or head:match('^(.-)は、') or head:match('^(.-)に、');
    local wh = head:match('^(.-)は、'); if wh and #wh < #(who or wh .. ' ') then who = wh; end   -- (「Aは、Xの構え」: いちばん前の名前)
    if who == '' then who = nil; end
    local x = h and head:match('^.-の(.+)$') or nil;                  -- (「AのX＞」の X)
    local t = nil;
    local w2, xa = head:match('^(.-)は、(.-)を実行');
    local w3, xh = sl:match('^(.-)の(.-)が発動');
    if heal(sl) then t = 'healing';
    elseif xa then who, t = w2, 'uses';                               -- (「Aは、Xを実行」: WS・モンスターの技)
    elseif xh then who, t = w3, (act_kind(xh) == 'uses') and 'uses' or 'magic';   -- (「AのXが発動」: ふつうは魔法)
    elseif sl:find('^.-の攻撃。') or sl:find('^.-の攻撃$') then t = 'melee';   -- (「Aの攻撃。クリティカル！」)
    elseif not h and sl:match('^.-の(.-)！$') and not L.CF_NOTACT[sl:match('^.-の(.-)！$')] then   -- (「Aの乱れ撃ち！」: アビリティ)
        t = act_kind(sl:match('^.-の(.-)！$')) or 'uses';
    elseif x and x ~= '' and not L.CF_NOTACT[x] then
        t = act_kind(x);
        if t == nil then
            for _, p in ipairs(L.CF_TYPES) do if p[1] ~= 'effects' and p[1] ~= 'damage' and sl:find(p[2]) then t = p[1]; break; end end
            if t == nil or t == 'melee' then t = 'uses'; end           -- (「AのX＞」: 名前が引けなくても技)
        end
    elseif x == '反撃効果' then t = 'damage';                         -- (スパイク系: ダメージ扱い・色なし)
    end
    if t == nil then
        for _, p in ipairs(L.CF_TYPES) do if sl:find(p[2]) then t = p[1]; break; end end
    end
    return who, t;
end
JP.cf_text = cf_text;

-- (1) アクションパケット（0x028）: 誰が何をしたか。チャットの行はその人の名前で結び付ける（言葉に頼らない）
JP.CAT = { [1] = 'melee', [2] = 'ranged', [12] = 'ranged', [3] = 'uses', [4] = 'magic', [5] = 'items', [6] = 'uses',
           [11] = 'uses', [13] = 'uses', [14] = 'uses', [15] = 'uses', [7] = 'readies', [8] = 'casting', [9] = 'items' };
JP.START = { readies = true, casting = true };
JP.ACTS, JP.PEND, JP.IDN, JP.Q = {}, {}, {}, {};
JP.EXP = 10.0;                                                       -- (行を待つパケットの安全な期限（秒）。ふだんは行の数だけ使えば消える)
local function now_() return os.clock(); end
local function name_of(id)                                           -- (サーバーID → 名前（UTF-8）、少しの間覚える)
    local c = JP.IDN[id];
    if c and now_() - c.t < 30 then return c.n; end
    local n = nil;
    pcall(function()
        local ent = AshitaCore:GetMemoryManager():GetEntity();
        for i = 0, 2303 do
            if ent:GetServerId(i) == id then n = ent:GetName(i); break; end
        end
    end);
    if type(n) == 'string' and n ~= '' then n = YUI_U8 and YUI_U8(n) or n; else n = nil; end
    JP.IDN[id] = { n = n, t = now_() };
    return n;
end
JP.name_of = name_of;
local function nkey(x) return x and (x:gsub('^[^%w\128-\255]+', ''):gsub('%s+', '')) or nil; end
local function same(a, b)                                            -- (名前の一致: 前の印や空白の違いは無視)
    if not a or not b then return false; end
    if a == b then return true; end
    return nkey(a) == nkey(b);
end
local SPN = {};                                                      -- (魔法ID → 名前（全言語）)
local function spell_names(id)
    if SPN[id] ~= nil then return SPN[id] or nil; end
    local r = false;
    pcall(function()
        local s = AshitaCore:GetResourceManager():GetSpellById(id);
        if s and s.Name then
            for lg = 0, 3 do
                local ok, n = pcall(function() return s.Name[lg]; end);
                if ok and type(n) == 'string' and n ~= '' then r = r or {}; r[#r + 1] = YUI_U8 and YUI_U8(n) or n; end
            end
        end
    end);
    SPN[id] = r;
    return r or nil;
end
local function has_name(sl, names)                                   -- (行にその魔法の名前があるか。名前が引けなければ true)
    if not names then return true; end
    for _, n in ipairs(names) do if sl:find(n, 1, true) then return true; end end
    return false;
end
-- 敵か味方か: 行動した人のID だけで決める。プレイヤーは 0x01000000 未満。それ以上は 0x01000000 + (エリア << 12) + 番号 で、
-- 番号（下 12 ビット）が 0x700 以上はペット・フェイス（味方）、それ未満はモンスター・NPC（敵）
local function side_id(id)
    if type(id) ~= 'number' then return nil; end
    if id < 0x01000000 then return 'ally'; end
    return (id % 0x1000 >= 0x700) and 'ally' or 'enemy';
end
JP.side_id = side_id;
-- チャットモードから（行動した側が決まっている番号だけ。confirmed_numbers.md）
JP.SIDE = { [21] = 'ally', [24] = 'ally', [42] = 'ally', [43] = 'ally', [25] = 'ally', [26] = 'ally', [27] = 'ally', [31] = 'ally', [50] = 'ally', [51] = 'ally',   -- (20/22/100/105 はモンスターも出るので使わない)
            [59] = 'ally', [63] = 'ally', [90] = 'ally', [101] = 'ally', [106] = 'ally', [114] = 'ally',
            [28] = 'enemy', [29] = 'enemy', [69] = 'enemy', [102] = 'enemy', [32] = 'enemy', [33] = 'enemy', [104] = 'enemy', [107] = 'enemy', [109] = 'enemy', [112] = 'enemy' };
local function side_of(who, mode, pid)
    local s = pid and side_id(pid);
    if s then return s, 'pkt'; end
    if who then                                                      -- (その人の最近のパケットのID: 同じ名前のモンスターでも側は同じ)
        for i = #JP.ACTS, 1, -1 do local a = JP.ACTS[i]; if same(a.n, who) then return side_id(a.id), 'pkt-id'; end end
    end
    if JP.SIDE[mode or -1] then return JP.SIDE[mode], 'mode'; end
    return nil, 'none';
end
JP.side_of = side_of;

-- パケットが出す行の数: 近接・遠隔は 1 回の攻撃ごとに 1 行（全員の分の合計）、ほかは 1 行（続きの「＞」行は数えない）
function JP.pkt_lines(cat, pe)
    if cat ~= 1 and cat ~= 2 and cat ~= 12 then return 1; end
    local n = 0;
    pcall(function()
        local data, pos, max = pe.data_raw, 150, pe.size * 8;
        local function bits(k) if pos + k > max then error('end'); end local v = ashita.bits.unpack_be(data, 0, pos, k); pos = pos + k; return v; end
        pos = 82; local nt = bits(6);
        pos = 150;
        for _ = 1, nt do
            bits(32); local na = bits(4);
            for _ = 1, na do
                pos = pos + 85; n = n + 1;
                if bits(1) == 1 then pos = pos + 37; end
                if bits(1) == 1 then pos = pos + 34; end
            end
        end
    end);
    return math.max(n, 1);
end
-- 技連携: WS（cat 3 / 11）の追加効果のメッセージが技連携の番号なら、その数だけ「技連携-X＞」の行が増える
JP.SCMSG = {};
for m = 288, 302 do JP.SCMSG[m] = true; end
for _, m in ipairs({ 385, 386, 387, 388, 767, 768, 769, 770 }) do JP.SCMSG[m] = true; end
function JP.pkt_sc(cat, pe)
    if cat ~= 3 and cat ~= 11 then return 0; end
    local n = 0;
    pcall(function()
        local data, pos, max = pe.data_raw, 150, pe.size * 8;
        local function bits(k) if pos + k > max then error('end'); end local v = ashita.bits.unpack_be(data, 0, pos, k); pos = pos + k; return v; end
        pos = 82; local nt = bits(6);
        pos = 150;
        for _ = 1, nt do
            bits(32); local na = bits(4);
            for _ = 1, na do
                pos = pos + 85;
                if bits(1) == 1 then pos = pos + 27; if JP.SCMSG[bits(10)] then n = n + 1; end end
                if bits(1) == 1 then pos = pos + 34; end
            end
        end
    end);
    return n;
end
-- 技・アビリティの名前（全言語）: WS は cat 3、アビリティは cat 6/14/15（+0x200）、モンスターの技は cat 11（monsters.abilities, -256）
local ABN = {};
local function abil_names(cat, id)
    local key = cat .. ':' .. tostring(id);
    if ABN[key] ~= nil then return ABN[key] or nil; end
    local r = false;
    pcall(function()
        local rm = AshitaCore:GetResourceManager();
        local function add(n) if type(n) == 'string' and n ~= '' then r = r or {}; r[#r + 1] = YUI_U8 and YUI_U8(n) or n; end end
        if cat == 11 then
            if id >= 256 then                                        -- (フェイスの WS も: 言語なしは英語だけ → 言語 1/2 も（日本語の名前）)
                add(rm:GetString('monsters.abilities', id - 256));
                for lg = 0, 2 do pcall(function() local n = rm:GetString('monsters.abilities', id - 256, lg); if type(n) == 'string' then add((n:gsub('%z.*$', ''))); end end); end
            end
            if id < 256 then local a = rm:GetAbilityById(id); if a and a.Name then for lg = 0, 3 do pcall(function() add(a.Name[lg]); end); end end end
        else
            local a = rm:GetAbilityById((cat == 3) and id or (id + 0x200));
            if a and a.Name then for lg = 0, 3 do pcall(function() add(a.Name[lg]); end); end end
        end
    end);
    ABN[key] = r;
    return r or nil;
end
JP.NAMED = { [3] = true, [6] = true, [11] = true, [13] = true, [14] = true, [15] = true };
JP.SELFJA = { [100] = true, [102] = true, [115] = true, [116] = true, [117] = true, [118] = true, [119] = true, [120] = true, [121] = true };
JP.ACTK = { melee = true, ranged = true, uses = true, magic = true, items = true, healing = true, misses = true };
JP.QN = {};                                                          -- (名前 → その名前のアクターID の一覧。キューは ID ごと: 同じ名前の別の人を分ける)
local function q_of(id, nm)
    JP.Q[id] = JP.Q[id] or {};
    local k = nkey(nm);
    if k then JP.QN[k] = JP.QN[k] or {}; JP.QN[k][id] = true; end
    return JP.Q[id];
end
local function q_take(q, i) local a = q[i]; a.left = a.left - 1; if a.left <= 0 then table.remove(q, i); end return a; end

function JP.on_action(actor, cat, param, pe)                             -- (read_action から: パケットを覚え、先に来ていた行は塗り直す)
    if not YUI_JP then return; end
    local kind = JP.CAT[cat];
    if not kind then return; end
    local nm = name_of(actor);
    local mid = nil;
    pcall(function() if pe and pe.size * 8 > 241 then mid = ashita.bits.unpack_be(pe.data_raw, 0, 230, 10); end end);   -- (1人目の最初のメッセージID)
    local sd = side_id(actor);
    local nl = JP.START[kind] and 0 or JP.pkt_lines(cat, pe);
    if cat == 6 and JP.SELFJA[mid or -1] then nl = 0; end             -- (自分への強化アビリティ: ダメージの行は出ない)
    if cat == 12 or cat == 5 or cat == 9 then nl = 0; end
    if cat == 4 and (mid == 0 or mid == 78 or mid == 84) then nl = 0; end   -- (魔法が出なかった（遠い・中断など）: 行を取らない)             -- (遠隔の構え・アイテム: 行を取らない。側だけに使う)
    local sc = (nl > 0) and JP.pkt_sc(cat, pe) or 0;                  -- (技連携の行の数)
    nl = nl + sc;
    local sp = (cat == 4) and spell_names(param) or (JP.NAMED[cat] and abil_names(cat, param)) or nil;
    if JP.cfdbg then
        JP.cflog(string.format('PKT actor=%s(%d/0x%08X) side=%s cat=%d(%s) id=%s msg=%s n=%d sc=%d nm=%s', tostring(nm), actor, actor, tostring(sd), cat, tostring(kind), tostring(param), tostring(mid or '?'), nl, sc, sp and table.concat(sp, '/') or '-'));
    end
    if not nm then return; end
    local t = now_();
    if cat == 4 and mid == 7 then kind = 'healing'; elseif cat == 1 and mid == 15 then kind = 'misses';   -- (魔法の回復 / 近接のミス)
    elseif cat == 11 and (mid == 352 or mid == 353 or mid == 354) then kind = 'ranged'; end            -- (モンスターの遠隔攻撃)
    local a = { n = nm, k = kind, t = t, c = cat, m = mid, id = actor, s = sd, sp = sp, left = nl, sc = sc };
    local A = JP.ACTS;
    A[#A + 1] = a;
    while #A > 0 and t - A[1].t > JP.EXP do table.remove(A, 1); end
    if #A > 128 then table.remove(A, 1); end
    if nl <= 0 then return; end
    local named = false;                                             -- (その人の名前のあるパケットがまだ待っている: 名前のないパケットでは塗り直さない)
    if not sp then for _, b in ipairs(JP.Q[actor] or {}) do if b.sp and b.left > (b.sc or 0) and t - b.t <= JP.EXP then named = true; end end end
    local i = #JP.PEND;
    while i >= 1 and a.left > 0 and not named do                    -- (行のほうが先に来た: あとから種類を直す。新しい行から（ひとつずれの連鎖を防ぐ）)
        local p = JP.PEND[i];
        local _, tk = cf_text(p.sl or '');                           -- (文字の種類と合わないパケットでは塗り直さない（近接で「…を実行」など）)
        local fit = not (tk == 'uses' or tk == 'magic' or tk == 'ranged' or tk == 'melee') or tk == kind or (tk == 'uses' and kind == 'magic') or (kind == 'misses');
        if not p.done and t - p.t <= JP.EXP and same(p.who, nm) and p.e and JP.ACTK[kind] and fit
           and has_name(p.sl or '', sp) then
            p.done = true; a.left = a.left - 1;
            JP.cflog(string.format('LATE who=%s side=%s %s -> %s', tostring(nm), tostring(sd), tostring(p.e.ctype), kind));
            p.e.ctype = (kind == 'misses') and JP.CAT[cat] or kind; p.e.cside = sd or p.e.cside;
            for _, q in ipairs(p.kids or {}) do q.ctype = p.e.ctype; q.cside = p.e.cside; end   -- (同じメッセージの続きの行も)
        end
        i = i - 1;
    end
    if a.left > 0 then local q = q_of(actor, nm); q[#q + 1] = a; end
end
YUI_JP_ACT = JP.on_action;
-- その人の待っているパケット（古い順）。魔法は名前が行にあるものを先に。ok: 使ってよい種類か。peek: 使用済みにしない
local function from_packet(who, sl, peek, ok)
    if not who then return nil; end
    local ids = JP.QN[nkey(who)];
    if not ids then return nil; end
    local t = now_();
    local C = {};                                                    -- (同じ名前の全員のパケット、古い順)
    for id in pairs(ids) do
        local q = JP.Q[id];
        if q then
            while #q > 0 and t - q[1].t > JP.EXP do table.remove(q, 1); end
            for i, a in ipairs(q) do C[#C + 1] = { q = q, i = i, a = a }; end
        end
    end
    table.sort(C, function(x, y) return x.a.t < y.a.t; end);
    local function pick(x) if peek then return x.a; end return q_take(x.q, x.i); end
    for _, x in ipairs(C) do local a = x.a; if a.sp and has_name(sl, a.sp) and a.left > (a.sc or 0) and (not ok or ok(a)) then return pick(x); end end   -- (名前が行にある技・魔法)
    for _, x in ipairs(C) do local a = x.a; if not a.sp and a.c ~= 4 and (not ok or ok(a)) then return pick(x); end end   -- (名前のないパケット: 近接・遠隔など)
    for _, x in ipairs(C) do local a = x.a; if not a.sp and a.c == 4 and (not ok or ok(a)) then return pick(x); end end
    if ok then for _, x in ipairs(C) do if x.a.sp and x.a.left > (x.a.sc or 0) and ok(x.a) then return pick(x); end end end   -- (番号で種類が決まる行: 名前が合わなくても同じ種類なら)
    return nil;                                                      -- (名前のあるパケットは、名前のない行には使わない)
end
local function from_sc()                                             -- (「技連携-X＞」: 人の名前がない。技連携の数が残っている いちばん新しい WS)
    local best, bq, bi = nil, nil, nil;
    local t = now_();
    for _, q in pairs(JP.Q) do
        for i, a in ipairs(q) do if (a.sc or 0) > 0 and t - a.t <= JP.EXP and (not best or a.t > best.t) then best, bq, bi = a, q, i; end end
    end
    if not best then return nil; end
    best.sc = best.sc - 1;
    return q_take(bq, bi);
end
JP.from_packet = from_packet;
local function recent_cat(who, cat)                                  -- (その人の最近（期限内）のそのカテゴリーのパケット)
    if not who then return nil; end
    local t = now_();
    for i = #JP.ACTS, 1, -1 do local a = JP.ACTS[i]; if t - a.t <= JP.EXP and a.c == cat and same(a.n, who) then return a; end end
    return nil;
end
-- 番号でない種類の行に使ってよいパケット
JP.FAMOK = {
    misses = function(a) return a.c ~= 4 and a.c ~= 5 and a.c ~= 9; end,
    healing = function(a) return a.c == 4 or a.c == 6 or a.c == 5 or a.c == 9; end,
    magic = function(a) return a.c == 4 and a.sp ~= nil; end,
    uses = function(a) return a.c == 3 or a.c == 6 or a.c == 11 or a.c == 13 or a.c == 14 or a.c == 15; end,
    ja = function(a) return a.c == 6 or a.c == 13 or a.c == 14 or a.c == 15; end,   -- (101: アビリティの行。WS（cat 3 / 11）は取らない)
    items = function(a) return a.c == 5 or a.c == 9; end };

-- (2) 番号だけの判定（jpdebug_1/3.log で確認）。チャットモードで行の「家族」を決め、ダメージの家族だけパケットで分ける。
--     未確認の番号は色なし（ふつうの色のまま → 気づきやすい）
function JP.cf_entry(e)                                              -- (CHATLOG に入った直後の行: 敵か味方かを付け、あとからの塗り直し用に覚える)
    if type(e) ~= 'table' then return; end
    e.cside = JP.cf_side;
    if JP.cfdbg and JP.cf_dbg then
        local d = JP.cf_dbg;
        JP.cflog(string.format('LINE mode=%s fam=%s side=%s(%s) who=%s pkt=%s rule=%s kind=%s | %s', tostring(d[1]), tostring(JP.cf_fam), tostring(JP.cf_side), tostring(JP.cf_sidewhy), tostring(d[2]), tostring(d[5]), tostring(JP.cf_why), tostring(e.ctype), tostring(d[4])));
        JP.cf_dbg = nil;
    end
    if JP.cf_new then JP.cf_new.e = e; JP.cf_new = nil;
    elseif JP.cf_kid then JP.cf_kid.kids = JP.cf_kid.kids or {}; table.insert(JP.cf_kid.kids, e); JP.cf_kid = nil; end
end
YUI_JP_CFE = JP.cf_entry;
JP.FAM = {
    [20] = 'action', [25] = 'action', [42] = 'action', [28] = 'action', [32] = 'action', [40] = 'action',   -- (ダメージ: 近接・WS・技・魔法が混ざる → パケット)
    [21] = 'misses', [26] = 'misses', [29] = 'misses', [33] = 'misses', [41] = 'misses',
    [22] = 'healing', [24] = 'healing', [27] = 'healing', [31] = 'healing', [43] = 'healing',
    [50] = 'casting', [51] = 'casting', [52] = 'casting',            -- (「Aは、(Bに)Xを唱えた」: 詠唱の開始、色なし)
    [56] = 'magic', [57] = 'magic', [64] = 'magic', [65] = 'magic', [69] = 'magic', [59] = 'magic', [63] = 'magic',   -- (魔法の発動・効果・レジスト。64/65 はアビリティの結果も)
    [100] = 'readies', [105] = 'readies', [110] = 'readies',
    [101] = 'uses', [102] = 'uses', [104] = 'uses', [106] = 'uses', [114] = 'uses', [111] = 'uses', [107] = 'uses', [109] = 'uses', [112] = 'uses',
    [90] = 'items', [191] = 'effects',
    [36] = 'none', [37] = 'none', [44] = 'none', [68] = 'none', [81] = 'none', [122] = 'none', [129] = 'none', [131] = 'none' };
local function is_cont(sl) return sl:find('^＞') or sl:find('^⇒') or sl:find('^>') or sl:find('^→'); end
local function done(mode, fam, who, t, why, pk, sl, side, swhy, whole, pend)
    JP.cf_fam, JP.cf_side, JP.cf_sidewhy = fam, side, swhy;
    JP.cf_why = why; JP.cf_dbg = { mode, who, t, sl, pk or '-' };
    JP.cf_kid = nil; JP.cf_new = pend;
    JP.cf_last = { who = who, t = t, whole = whole, at = now_(), pend = pend, mode = mode, side = side };
    return who, t;
end
-- 言葉で決める例外（ユーザー確認済み）: スパイクの行（「Xの反撃効果」）・カウンター・/check の結果
local function is_check(sl) return sl:find('相手だ。$') or sl:find('モンスターだ。$'); end
function JP.cf_sort(sl)
    if not YUI_JP and not JP.TEST then return nil, nil; end           -- (英語クライアント: なにもしない)
    if type(sl) ~= 'string' or not sl:find('[\227-\239]') then return nil, nil; end   -- (日本語の文字がない: 英語の行)
    sl = sl:gsub('%c', '');
    local mode, whole = YUI_JP_MODE, YUI_JP_WHOLE;
    local fam = JP.FAM[mode or -1];
    local last, cont = JP.cf_last, is_cont(sl);
    if cont then                                                     -- (続きの行: 同じメッセージならモードが違っても受け継ぐ（64→56 など）、側も)
        local same_msg = whole ~= nil and last.whole == whole;
        local ok_ = same_msg or (last.mode == mode and now_() - (last.at or 0) < 1.0);
        local who, t, why, sd = nil, nil, 'none', nil;
        if ok_ then who, t, why, sd = last.who, last.t, same_msg and 'carry' or 'carry-t', last.side; end
        if fam ~= nil and fam ~= 'action' and fam ~= 'none' and (not ok_ or t == nil) then t, why = fam, ok_ and why or 'mode'; end   -- (受け継ぐ種類がない: 番号の種類)
        if fam == 'none' and not same_msg then t = nil; end
        JP.cf_fam, JP.cf_side, JP.cf_sidewhy = fam or 'unknown', sd, ok_ and 'carry' or 'none';
        JP.cf_dbg = { mode, who, t, sl, '-' }; JP.cf_why = (fam == nil and not ok_) and 'unknown-mode' or why;
        JP.cf_kid = ok_ and last.pend or nil; JP.cf_new = nil;
        return who, t;
    end
    if fam == nil then                                               -- (未確認の番号: 色なし)
        local who = cf_text(sl);
        local sd, sw = side_of(who, mode, nil);
        done(mode, 'unknown', who, nil, 'unknown-mode', nil, sl, sd, sw, whole, nil);
        return nil, nil;
    end
    if fam == 'none' then                                            -- (お知らせ・倒した・経験値: 色なし、人もなし)
        local who = (mode == 36 or mode == 37 or mode == 44) and (cf_text(sl)) or nil;
        return done(mode, fam, who, nil, 'mode', nil, sl, nil, 'none', whole, nil);
    end
    if mode == 191 and is_check(sl) then                             -- (/check の結果: 色なし)
        return done(mode, fam, nil, nil, 'check', nil, sl, nil, 'none', whole, nil);
    end
    local who = (cf_text(sl));
    if sl:find('^.-の反撃効果') then                                   -- (スパイク: 強化と弱体の色、側はスパイクを持つ人)
        local sd, sw = side_of(who, nil, nil);
        return done(mode, fam, who, 'effects', 'spikes', nil, sl, sd, sw, whole, nil);
    end
    if fam ~= 'action' then                                          -- (番号だけで種類が決まる)
        local t = fam;
        local a = nil;
        if mode == 64 or mode == 65 then                             -- (アビリティの結果も来る: 魔法のパケットが合わなければアビリティ)
            a = from_packet(who, sl, false, JP.FAMOK.magic);
            if not a then local j = recent_cat(who, 6); if j then t = 'uses'; a = j; end end
        elseif fam ~= 'casting' and fam ~= 'readies' and fam ~= 'effects' then
            a = from_packet(who, sl, false, (mode == 101) and JP.FAMOK.ja or JP.FAMOK[fam]);
        end
        local sd, sw = side_of(who, mode, a and a.id);
        return done(mode, fam, who, t, 'mode', a and a.k, sl, sd, sw, whole, nil);
    end
    if sl:find('^追加ダメージ') or sl:find('^追加効果') then           -- (「追加ダメージ>Xに、N」: 直前の同じモードの近接の行の追加効果。42 は 40 の続き)
        local ok_ = (last.mode == mode or (mode == 42 and last.mode == 40)) and last.t == 'melee' and now_() - (last.at or 0) < 1.0;
        if ok_ then return done(mode, fam, last.who, 'melee', 'carry-ae', nil, sl, last.side, 'carry', whole, nil); end
        return done(mode, fam, nil, nil, 'none', nil, sl, nil, 'none', whole, nil);
    end
    if sl:find('^.-のカウンター') and last.t == 'melee' and now_() - (last.at or 0) < 3.0 then   -- (カウンター: 直前の敵の攻撃のパケットに入っている)
        local sd, sw = side_of(who, mode, nil);
        return done(mode, fam, who, 'melee', 'carry-ctr', nil, sl, sd, sw, whole, nil);
    end
    local a = nil;
    if who then a = from_packet(who, sl); else a = from_sc(); end
    if a then
        local k = (a.k == 'misses') and JP.CAT[a.c] or a.k;         -- (ダメージの行: 1回目がミスのパケットでも、ほかの回は当たっている)
        local sd, sw = side_of(who, mode, a.id);
        return done(mode, fam, who, k, 'packet', a.k, sl, sd, sw, whole, nil);
    end
    local pend = nil;
    if who then                                                      -- (パケットがまだ: あとで来たら塗り直す)
        pend = { who = who, t = now_(), soft = true, sl = sl };
        JP.PEND[#JP.PEND + 1] = pend;
        while #JP.PEND > 0 and (now_() - JP.PEND[1].t > JP.EXP or #JP.PEND > 32) do table.remove(JP.PEND, 1); end
    end
    local sd, sw = side_of(who, mode, nil);
    return done(mode, fam, who, nil, 'wait', nil, sl, sd, sw, whole, pend);
end
YUI_JP_CF = JP.cf_sort;

-- (3) 敵の色: CHAT > 戦闘ログ > 種類ごとに色分け の下に、種類ごとにもう1つ（キー cf_ecol_<種類>）
JP.CF_ECOL = { melee = { 0.95, 0.45, 0.40 }, ranged = { 0.90, 0.55, 0.35 }, magic = { 0.85, 0.40, 0.70 }, uses = { 1.00, 0.33, 0.25 },
               healing = { 0.70, 0.80, 0.35 }, defence = { 0.70, 0.55, 0.65 }, effects = { 0.80, 0.50, 0.60 }, items = { 0.85, 0.60, 0.30 } };
function JP.cf_col(cfg, e, base)                                     -- (公式の色の前に: 敵の行なら敵の色)
    if e.cside ~= 'enemy' or not e.ctype then return base; end
    local c = cfg['cf_ecol_' .. e.ctype];
    if type(c) == 'table' and tonumber(c[1]) then return c; end
    return JP.CF_ECOL[e.ctype] or base;
end
function JP.cf_enemy_ui(colour_row, hint, what)
    if not YUI_JP then return; end                                   -- (英語クライアントでは使われない)
    hint(JP.t('Enemies (monsters):'));
    for _, w in ipairs(what) do
        if JP.CF_ECOL[w[1]] then colour_row('cf_ecol_' .. w[1], JP.t('Enemy: ' .. w[2]), JP.CF_ECOL[w[1]], true); end
    end
end
function JP.status() return JP.cfg.ui_lang, JP.active; end

-------------------------------------------------------------------- 文字コード（チャット出力・マクロのコマンド・マクロ編集）
-- UTF-8 → Shift-JIS（日本語クライアントのゲーム側はShift-JIS）。変換できない時はそのまま
local function to_sj(s)
    if type(s) ~= 'string' or not s:find('[\128-\255]') or not YUI_U8OK or not YUI_U8OK(s) then return s; end
    local ok, r = pcall(vana.encoding.to_shift_jis, s);
    return (ok and type(r) == 'string') and r or s;
end
JP.to_sj = to_sj;
function JP.say(s)                                                   -- (チャット欄への表示: 公式の msg と同じ道（UTF-8）。print にShift-JISを渡すと何も出なかった)
    if JP.msgf then local ok = pcall(JP.msgf, s); if ok then return; end end   -- (msg → JP.msg が Shift-JIS にする)
    if JP.active then s = to_sj(s); end
    print('[YunaUI] ' .. s);
end
-- マクロ行を「コマンドとして送れる文字」に（UTF-8で返す。送る直前に JP.cmd で Shift-JIS へ）
-- 公式の mb_plain は定型文の名前から 0x7F-0xFF を消す → 日本語名が空になる。ここでは
--  ・0xFD+4バイト+0xFD（定型文）→ ParseAutoTranslate の名前（括弧・色コードなし）
--  ・0xEF 0x27 / 0xEF 0x28（定型文の緑/赤の括弧）→ 消す
--  ・残りのShift-JISはUTF-8へ。2語以上の名前は "..." で囲む（公式と同じ）
local function u8(x) local ok, r = pcall(YUI_U8, x); return (ok and type(r) == 'string') and r or x; end
function JP.mb_plain(ln)
    if not JP.active or type(ln) ~= 'string' or not ln:find('[\128-\255]') then return nil; end
    if YUI_U8OK and YUI_U8OK(ln) then return nil; end                -- (UTF-8 のまま来た行: 公式のまま)
    local out, buf, i, n = {}, {}, 1, #ln;
    local function flush() if #buf > 0 then out[#out + 1] = u8(table.concat(buf)); buf = {}; end end
    local function name(t)
        t = u8(t):gsub('[%c{}]', ''):gsub('\239\188\155', ''):gsub('\239\188\157', ''):gsub('^%s+', ''):gsub('%s+$', '');
        local _, nq = table.concat(out):gsub('"', '');
        if t:find(' ', 1, true) and nq % 2 == 0 then t = '"' .. t .. '"'; end
        return t;
    end
    while i <= n do
        local c = ln:byte(i);
        if c == 0xFD and i + 5 <= n and ln:byte(i + 5) == 0xFD then
            flush();
            local seg = ln:sub(i, i + 5);
            local ok, t = pcall(function() return AshitaCore:GetChatManager():ParseAutoTranslate(seg, false); end);
            t = (ok and type(t) == 'string') and t or '';
            t = t:gsub('\239[\39\40]', '');
            out[#out + 1] = name(t);
            i = i + 6;
        elseif c == 0xEF and (ln:byte(i + 1) == 0x27 or ln:byte(i + 1) == 0x28) then
            -- 展開済みの定型文（緑括弧 名前 赤括弧）: 名前をそのまま取り出す
            if ln:byte(i + 1) == 0x27 then
                local e = ln:find('\239\40', i + 2, true);
                if e then flush(); out[#out + 1] = name(ln:sub(i + 2, e - 1)); i = e + 2; else i = i + 2; end
            else i = i + 2; end
        elseif (c >= 0x81 and c <= 0x9F) or (c >= 0xE0 and c <= 0xFC) then
            buf[#buf + 1] = ln:sub(i, i + 1); i = i + 2;
        else
            buf[#buf + 1] = ln:sub(i, i); i = i + 1;
        end
    end
    flush();
    local r = table.concat(out);
    return r;
end
function JP.cmd(s)                                                   -- (QueueCommand に渡す直前)
    if not JP.active then return s; end
    return to_sj(s);                                                 -- (Shift-JIS で送る)
end
-- マクロ編集: 開く時にShift-JIS→UTF-8（入力欄で読めるように）、保存時にUTF-8→Shift-JIS（変えていない行は元の生データ）
function JP.me_open(E)
    if not JP.active or type(E) ~= 'table' then return; end
    E.name[1] = u8(E.name[1] or ''); E.name0 = E.name[1];
    for l = 1, 6 do E.lines[l][1] = u8(E.lines[l][1] or ''); E.plain[l] = E.lines[l][1]; end
end
local function sj_cut(s, max)                                        -- (Shift-JIS で max バイトまで: 2バイト文字の途中で切らない)
    local i, n = 1, #s;
    while i <= n do
        local c = s:byte(i);
        local w = ((c >= 0x81 and c <= 0x9F) or (c >= 0xE0 and c <= 0xFC)) and 2 or 1;
        if i + w - 1 > max then return s:sub(1, i - 1); end
        i = i + w;
    end
    return s;
end
function JP.me_name(s) if not JP.active then return s; end return sj_cut(to_sj(s or ''), 8); end
function JP.me_lines(E, t)
    if not JP.active then return t; end
    for l = 1, 6 do
        local v = t[l] or '';
        if not (E.raw and v == E.raw[l]) then t[l] = sj_cut(to_sj(v), 60); end
    end
    return t;
end

return JP;
