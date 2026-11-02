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
