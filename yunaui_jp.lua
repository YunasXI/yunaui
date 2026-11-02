-- YunaUI Japanese localization 1.1.4j - Copyright (C) 2026 Tsukasa
-- Based on YunaUI by Yunas - https://github.com/YunasXI/yunaui
-- License: GPL-3.0 with the YunaUI attribution term (GPL-3.0 section 7(b)); see LICENSE and NOTICE.
-- This program comes with ABSOLUTELY NO WARRANTY.
-- yunaui_jp.lua : YunaUI 日本語化モジュール
-- 公式 yunaui.lua には「-- [JP]」印の短いフック行だけを入れ、処理はすべてここに置く。
-- 英語表示（ui_lang=en、または auto で英語クライアント）のときは何もしない＝公式と同じ動き。
local imgui = require('imgui');
local L = require('yunaui_lang');

local JP = { active = false, cfg = { ui_lang = 'auto', font_scale = 1.0, minimap_text_scale = 1.3 } };
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
    end
end
local function save_cfg()
    local f = io.open(CFG_FILE, 'w');
    if not f then return; end
    f:write(string.format('return { ui_lang = %q, font_scale = %.2f, minimap_text_scale = %.2f };\n', JP.cfg.ui_lang, JP.cfg.font_scale, JP.cfg.minimap_text_scale or 1.3));
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
JP.msg = JP.t;

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
function JP.map_font(path)
    if not JP.active or type(path) ~= 'string' then return path; end
    local base = (path:match('[^/\\]+$') or path):lower();
    local to = FONTMAP[base];
    if not to then return path; end
    local dir = (os.getenv('WINDIR') or 'C:\\Windows') .. '\\Fonts\\';
    if fexists(dir .. to) then return dir .. to; end
    if to == 'meiryob.ttc' and fexists(dir .. 'meiryo.ttc') then return dir .. 'meiryo.ttc'; end
    return path;
end
local KEEP = {};
JP.MERGED = {};
local function hook_fonts()
    local add = imgui.AddFontFromFileTTF;
    if type(add) ~= 'function' then return; end
    local busy = false;
    local g = function(path, px, cfg, ...)
        path = JP.map_font(path);
        local font = add(path, px, cfg, ...);
        if font and cfg == nil and not busy then
            local jp = jp_font_path();
            if jp and path ~= jp then
                busy = true;
                pcall(function()
                    local T_ = (imgui.types or vana.imgui.types).ImFontConfig;
                    local c = T_.new();
                    c.MergeMode = true;
                    pcall(function() c.DstFont = font; end);
                    KEEP[#KEEP + 1] = c;
                    JP.MERGED[#JP.MERGED + 1] = font; JP.MERGED[tostring(font)] = true;
                    add(jp, tonumber(px) or 17, c);   -- (元フォントと同じサイズで合成: 違うと日本語だけ大きさがずれる)
                end);
                busy = false;
            end
        end
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
    for k, v in pairs(JA) do local u = k:upper(); if u ~= k and JA[u] == nil then UP[u] = v; end end
    for _, n in ipairs({ 'Text', 'TextUnformatted', 'TextWrapped', 'TextDisabled', 'CalcTextSize', 'SetTooltip',
                         'Button', 'SmallButton', 'Selectable', 'Checkbox', 'BulletText', 'SeparatorText' }) do wrap(n, 1); end
    wrap('TextColored', 2);
    L.dprint('active', m, tostring(client_jp));
end

-- 描画リスト DL.T（公式の文字描画の要）を翻訳付きに

-------------------------------------------------------------------- デバッグ（/yui jpdebug）
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
function JP.wrap_dl(DL)
    if not JP.active then return; end
    local T = DL.T;
    DL.T = function(d, a, b, col, t, ...) t = JP.t(t); return with_jp('DL.T', t, T, d, a, b, col, t, ...); end
end

-------------------------------------------------------------------- フォント（日本語フォントを合成）
function JP.fonts(fonts)
    -- ツールチップ（装備の「メイン: ○○」など）を日本語の字形があるフォントで出す
    if JP.active and type(YUI_TIP) == 'function' and not JP.tip_wrapped then
        JP.tip_wrapped = true;
        local TIP = YUI_TIP;
        YUI_TIP = function(t, ...) local s = JP.t(tostring(t or '')); return with_jp('YUI_TIP', s, TIP, s, ...); end
    end
    if JP.dbg then dlog('fonts', 'fonts', 'main=' .. tostring(fonts and fonts.main), 'chat=' .. tostring(fonts and fonts.chat), 'merged=' .. #JP.MERGED); end
    -- 合成は hook_fonts() がフォント追加のたびに行う。ここは旧フックとの互換用（何もしない）。
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
-------------------------------------------------------------------- トレジャープール
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
function JP.settings_ui(section, accent_button, hint)
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
end

-------------------------------------------------------------------- /yui lang
function JP.command(sub, args, msg)
    if sub == 'jpdebug' then
        JP.dbg = not JP.dbg; DSEEN = {};
        print('[YunaUI] jpdebug: ' .. (JP.dbg and 'ON（ミニマップの出口と装備欄にマウスを当ててください）' or 'OFF'));
        if JP.dbg then local f, h, how = cur_font_info(); dlog('fonts', 'fonts', 'chat=' .. tostring(YUI_FONTS and YUI_FONTS.chat), 'main=' .. tostring(YUI_FONTS and YUI_FONTS.main), 'merged=' .. #JP.MERGED, 'jpfile=' .. tostring(jp_font_path())); end
        return true;
    end
    if sub == 'iconcheck' then                                       -- トレジャープールのアイコン診断（読むだけ。英語表示でも動く）
        print('[YunaUI] iconcheck: YUI_EQ_ICON=' .. type(YUI_EQ_ICON));
        for _, id in ipairs({ 4096, 13014, 640 }) do
            local bm, sz = '?', '?';
            pcall(function() local r = AshitaCore:GetResourceManager():GetItemById(id); bm = tostring(r and r.Bitmap ~= nil); sz = tostring(r and r.ImageSize); end);
            local ok, ic = pcall(function() return YUI_EQ_ICON and YUI_EQ_ICON(id); end);
            print(string.format('  id=%d bitmap=%s size=%s icon=%s ptr=%s', id, bm, sz, ok and tostring(ic ~= nil and ic ~= false) or ('ERR ' .. tostring(ic)), ok and ic and tostring(ic.ptr) or '-'));
        end
        return true;
    end
    if sub ~= 'lang' then return false; end
    local v = (args[3] or ''):lower();
    if v == 'jp' or v == 'japanese' then v = 'ja'; end
    if v == 'english' then v = 'en'; end
    if v == 'auto' or v == 'ja' or v == 'en' then
        JP.cfg.ui_lang = v; save_cfg();
        print(JP.active and string.format('[YunaUI] 言語 / Language: %s  (/addon reload yunaui で反映 / reload to apply)', v)
            or string.format('[YunaUI] Language: %s (/addon reload yunaui to apply)', v));   -- (an English client shows Japanese as garbled signs)
    else
        print(JP.active and string.format('[YunaUI] /yui lang auto|ja|en   (今: %s  表示中: 日本語)', JP.cfg.ui_lang)
            or string.format('[YunaUI] /yui lang auto|ja|en   (now: %s, showing: English)', JP.cfg.ui_lang));
    end
    return true;
end
function JP.status() return JP.cfg.ui_lang, JP.active; end

return JP;
