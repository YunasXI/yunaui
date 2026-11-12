-- YunaUI - Copyright (C) 2026 Yunas - https://github.com/YunasXI/yunaui
-- License: GPL-3.0 with the YunaUI attribution term (GPL-3.0 section 7(b)); see LICENSE and NOTICE.
-- yunaui_update.lua : the in-game updater. It asks GitHub for the newest release, shows what's new, and - when the
-- player presses Update - downloads only the files that changed since their version, checks them, keeps a copy of
-- the old ones (to go back), swaps them in and reloads YunaUI. Nothing is sent but the request itself: no name, no
-- character, no settings. Never touches a file that isn't part of a release (settings, the Japanese module's own).
local U = {
    REPO = 'YunasXI/yunaui',
    state = 'idle',                                                  -- idle / checking / offer / listing / downloading / applying / done / failed / manual
    offer = nil,                                                     -- { tag = '1.2.3', notes = { 'line', ... } }
    done = 0, total = 0,
    why = nil,                                                       -- (failed / manual: what to tell the player)
};
local HDR = { ['User-Agent'] = 'YunaUI-updater', ['Accept'] = 'application/vnd.github+json' };
local E = nil;                                                       -- (what yunaui.lua gives: cfg, save, msg, version, root)

local function ver(s)                                                -- '1.2.3' -> 1, 2, 3 (nil when it isn't one)
    local a, b, c = tostring(s or ''):match('^v?(%d+)%.(%d+)%.(%d+)$');
    if not a then return nil; end
    return tonumber(a), tonumber(b), tonumber(c);
end
function U.newer(a, b)                                               -- is version a newer than b?
    local a1, a2, a3 = ver(a);
    local b1, b2, b3 = ver(b);
    if not a1 or not b1 then return false; end
    if a1 ~= b1 then return a1 > b1; end
    if a2 ~= b2 then return a2 > b2; end
    return a3 > b3;
end
local function enc(path)                                             -- a repository path as a URL's
    return (path:gsub('[^%w%._~%-/]', function(ch) return string.format('%%%02X', ch:byte()); end));
end
local function win(path) return (path:gsub('/', '\\')); end
local function dir_of(path) return path:match('^(.*)[\\/][^\\/]+$'); end
local function read_all(path)
    local f = io.open(path, 'rb');
    if not f then return nil; end
    local s = f:read('*a');
    f:close();
    return s;
end
local function write_all(path, data)
    local d = dir_of(path);
    if d and not vana.fs.is_dir(d) then vana.fs.create_dir(d); end
    local ok, why = vana.fs.write(path, data);                       -- (whole or not at all)
    if ok then return true; end
    return nil, why;
end
local function notes_of(body)                                        -- (the release's notes: its lines, the "- " taken off, the version line's wrapper too)
    local t = {};
    for line in tostring(body or ''):gmatch('[^\r\n]+') do
        line = line:gsub('^%s*[%-%*]%s*', ''):gsub('^Version %d+%.%d+%.%d+ %(public: (.*)%)%s*$', '%1'):gsub('^%s+', ''):gsub('%s+$', '');
        if line ~= '' and not line:match('^Version %d+%.%d+%.%d+') and #t < 12 then t[#t + 1] = line:sub(1, 1):upper() .. line:sub(2); end
    end
    return t;
end

function U.init(env)
    E = env;
    U.root = (env.root or ''):gsub('[\\/]+$', '');
    U.cur = env.version;
    U.dev = false;
    pcall(function() U.dev = vana.fs.exists(U.root .. '\\.git') and true or false; end);   -- (a development copy: never updated over)
    local cfg = E.cfg;
    if type(cfg.upd_done) == 'table' and cfg.upd_done.to == U.cur then   -- (just updated: said once)
        E.msg(string.format('Updated to %s (from %s). GENERAL > UPDATES has a button to go back.', tostring(cfg.upd_done.to), tostring(cfg.upd_done.from)));
        cfg.upd_done.said = true;
        cfg.upd_back = cfg.upd_done.from;                            -- (what Go back returns to)
        cfg.upd_done = nil;
        pcall(E.save);
    end
end
function U.can() return type(rawget(_G, 'vana')) == 'table' and type(vana.http) == 'table' and type(vana.async) == 'function' and type(vana.fs) == 'table'; end

-- Is there a newer release? At most one request every 3 hours (the last answer is kept); force: now.
function U.check(force)
    if not E or not U.can() or (U.dev and not U.test and not force) then return; end   -- (a development copy: only when asked - Check now)
    local cfg = E.cfg;
    if cfg.upd_check == false and not force then return; end
    if U.state ~= 'idle' and U.state ~= 'offer' and U.state ~= 'failed' and U.state ~= 'manual' then return; end
    local now = os.time();
    if not force and type(cfg.upd_tag) == 'string' and now - (tonumber(cfg.upd_t) or 0) < 3 * 3600 then   -- (asked lately: what it said then)
        if U.newer(cfg.upd_tag, U.cur) and cfg.upd_skip ~= cfg.upd_tag then
            U.offer = { tag = cfg.upd_tag, notes = type(cfg.upd_notes) == 'table' and cfg.upd_notes or {} };
            U.state = 'offer';
        end
        return;
    end
    U.state, U.why = 'checking', nil;
    vana.async(function()
        local ok, res = pcall(function() return vana.http.json('https://api.github.com/repos/' .. U.REPO .. '/releases/latest', { headers = HDR, timeout = 15 }):await(); end);
        if not ok or type(res) ~= 'table' or not ver(res.tag_name) then
            U.state = 'idle';
            if force then U.state, U.why, U.said = 'failed', 'Could not reach GitHub to check. Try again later.', 'Could not reach GitHub.'; end
            return;
        end
        cfg.upd_tag, cfg.upd_t, cfg.upd_notes = tostring(res.tag_name):gsub('^v', ''), now, notes_of(res.body);
        cfg.upd_tag = tostring(cfg.upd_tag);
        pcall(E.save);
        if U.newer(cfg.upd_tag, U.cur) and (force or cfg.upd_skip ~= cfg.upd_tag) then
            U.offer = { tag = cfg.upd_tag, notes = cfg.upd_notes };
            U.state, U.said = 'offer', cfg.upd_tag .. ' is out.';
        else
            U.offer = nil;
            U.state = 'idle';
            U.said = 'Up to date.';
            if force then E.msg('YunaUI is up to date (' .. tostring(U.cur) .. ').'); end
        end
    end);
end
function U.later() if U.state == 'offer' or U.state == 'failed' or U.state == 'manual' or U.state == 'done' then U.state = 'idle'; end U.offer = nil; end
function U.skip()
    if U.offer then E.cfg.upd_skip = U.offer.tag; pcall(E.save); end
    U.later();
end
function U.page() return 'https://github.com/' .. U.REPO .. '/releases/latest'; end

-- The update itself: what changed between the player's version and the new one (GitHub's compare), each changed file
-- downloaded beside the addon (_update), every Lua file checked that it compiles and yunaui.lua that it is the new
-- version, the old files copied to _backup, the new ones written over them, then YunaUI reloads.
local function fail(why, manual)
    U.state, U.why = manual and 'manual' or 'failed', why;
    return false;
end
local function clean(paths, dirs)                                    -- (what was staged: its files, then its folders, deepest first)
    for _, p in ipairs(paths) do pcall(vana.fs.remove, p); end
    table.sort(dirs, function(a, b) return #a > #b; end);
    for _, d in ipairs(dirs) do pcall(vana.fs.remove, d); end
end
function U.start()
    if not E or not U.can() or not U.offer or (U.dev and not U.test) then return; end
    if U.state ~= 'offer' and U.state ~= 'failed' then return; end
    local tag, cur, root, cfg = U.offer.tag, U.cur, U.root, E.cfg;
    U.state, U.done, U.total, U.why = 'listing', 0, 0, nil;
    vana.async(function()
        -- 1. what changed
        local ok, cmp = pcall(function() return vana.http.json('https://api.github.com/repos/' .. U.REPO .. '/compare/' .. enc(cur) .. '...' .. enc(tag), { headers = HDR, timeout = 20 }):await(); end);
        if not ok or type(cmp) ~= 'table' or type(cmp.files) ~= 'table' then
            return fail('Could not work out what changed since ' .. tostring(cur) .. '. Download the new version from the release page.', true);
        end
        if #cmp.files >= 300 then return fail('This update is a big one. Download it from the release page.', true); end
        local get, del = {}, {};
        for _, f in ipairs(cmp.files) do
            local name = tostring(f.filename or '');
            local own = name ~= '' and not name:match('^%.github/') and name ~= '.gitignore' and not name:find('%.%.', 1, false) and not name:match('^[\\/]');
            if own then
                if f.status == 'removed' then del[#del + 1] = name;
                else
                    get[#get + 1] = name;
                    if f.status == 'renamed' and f.previous_filename then del[#del + 1] = tostring(f.previous_filename); end
                end
            end
        end
        if #get == 0 and #del == 0 then return fail('Nothing to update.', false); end
        -- 2. download, beside the addon
        local stage = root .. '\\_update\\' .. tag;
        local staged, dirs = {}, { root .. '\\_update', stage };
        U.state, U.total = 'downloading', #get;
        for _, name in ipairs(get) do
            local to = stage .. '\\' .. win(name);
            local d = dir_of(to);
            local dd = d;                                             -- (every folder made on the way, to clear after)
            while dd and #dd > #stage do dirs[#dirs + 1] = dd; dd = dir_of(dd); end
            if d and not vana.fs.is_dir(d) then vana.fs.create_dir(d); end
            local okd, err = pcall(function()
                return vana.http.download('https://raw.githubusercontent.com/' .. U.REPO .. '/' .. enc(tag) .. '/' .. enc(name), to, { headers = { ['User-Agent'] = HDR['User-Agent'] }, timeout = 30, max_time = 900 }):await();
            end);
            if not okd then
                clean(staged, dirs);
                return fail('The download stopped (' .. name .. '). Nothing was changed. Try again.', false);
            end
            staged[#staged + 1] = to;
            U.done = U.done + 1;
        end
        -- 3. check before anything is touched
        U.state = 'applying';
        local new = {};
        for _, name in ipairs(get) do
            local data = read_all(stage .. '\\' .. win(name));
            if data == nil then clean(staged, dirs); return fail('A downloaded file could not be read (' .. name .. '). Nothing was changed.', false); end
            if name:match('%.lua$') then
                local fn, cerr = loadstring(data, '@' .. name);
                if not fn then clean(staged, dirs); return fail('A downloaded file is broken (' .. name .. '). Nothing was changed.', false); end
            end
            if name == 'yunaui.lua' and not data:find("addon.version = '" .. tag .. "'", 1, true) then
                clean(staged, dirs);
                return fail('The download is not version ' .. tag .. '. Nothing was changed.', false);
            end
            new[name] = data;
        end
        -- 4. the old files kept (only the last update's), then the new ones over them
        local bdir = root .. '\\_backup';
        local old_m = nil;
        pcall(function() local f = loadfile(bdir .. '\\manifest.lua'); old_m = f and f() or nil; end);
        if type(old_m) == 'table' and type(old_m.files) == 'table' then   -- (the backup before this one: cleared)
            local ps, ds = { bdir .. '\\manifest.lua' }, {};
            for _, n in ipairs(old_m.files) do
                local p = bdir .. '\\' .. win(n);
                ps[#ps + 1] = p;
                local dd = dir_of(p);
                while dd and #dd > #bdir do ds[#ds + 1] = dd; dd = dir_of(dd); end
            end
            clean(ps, ds);
        end
        local kept, added = {}, {};
        local function keep(name)
            local data = read_all(root .. '\\' .. win(name));
            if data == nil then added[#added + 1] = name; return true; end   -- (not there before: going back removes it)
            local okw = write_all(bdir .. '\\' .. win(name), data);
            if not okw then return false; end
            kept[#kept + 1] = name;
            return true;
        end
        for _, name in ipairs(get) do if not keep(name) then clean(staged, dirs); return fail('Could not keep a copy of the old files. Nothing was changed.', false); end end
        for _, name in ipairs(del) do if vana.fs.exists(root .. '\\' .. win(name)) and not keep(name) then clean(staged, dirs); return fail('Could not keep a copy of the old files. Nothing was changed.', false); end end
        local man = { 'return { from = ' .. string.format('%q', cur) .. ', to = ' .. string.format('%q', tag) .. ', files = {' };
        for _, n in ipairs(kept) do man[#man + 1] = string.format('%q,', n); end
        man[#man + 1] = '}, added = {';
        for _, n in ipairs(added) do man[#man + 1] = string.format('%q,', n); end
        man[#man + 1] = '} };';
        write_all(bdir .. '\\manifest.lua', table.concat(man, '\n'));
        local written = {};
        for _, name in ipairs(get) do
            local okw = write_all(root .. '\\' .. win(name), new[name]);
            if not okw then                                           -- (a file that can't be written: everything put back as it was)
                for _, w in ipairs(written) do
                    local b = read_all(bdir .. '\\' .. win(w));
                    if b then write_all(root .. '\\' .. win(w), b); else pcall(vana.fs.remove, root .. '\\' .. win(w)); end
                end
                clean(staged, dirs);
                return fail('A file could not be replaced (' .. name .. '). Everything was put back as it was.', false);
            end
            written[#written + 1] = name;
        end
        for _, name in ipairs(del) do pcall(vana.fs.remove, root .. '\\' .. win(name)); end
        clean(staged, dirs);
        -- 5. done: said after the reload
        cfg.upd_done = { from = cur, to = tag };
        cfg.upd_skip = nil;
        pcall(E.save);
        U.state, U.offer = 'done', nil;
        if not U.test and E.reload then E.reload(); end
    end);
end
-- GENERAL > UPDATES > Go back: the files as they were before the last update, then a reload.
function U.back_to()
    local m = nil;
    pcall(function() local f = loadfile(U.root .. '\\_backup\\manifest.lua'); m = f and f() or nil; end);
    if type(m) == 'table' and type(m.files) == 'table' and m.to == U.cur then return m; end
    return nil;
end
function U.back()
    local m = U.back_to();
    if not m or not U.can() or (U.dev and not U.test) then return false; end
    local root, bdir = U.root, U.root .. '\\_backup';
    for _, n in ipairs(m.files) do                                   -- (every kept file must be there before anything is written)
        if read_all(bdir .. '\\' .. win(n)) == nil then E.msg('Go back: the kept files are not all there. Nothing was changed.'); return false; end
    end
    for _, n in ipairs(m.files) do write_all(root .. '\\' .. win(n), read_all(bdir .. '\\' .. win(n))); end
    for _, n in ipairs(m.added or {}) do pcall(vana.fs.remove, root .. '\\' .. win(n)); end
    E.cfg.upd_skip = m.to;                                           -- (that version isn't offered again by itself; Check now still finds it)
    E.cfg.upd_done = nil;
    pcall(E.save);
    E.msg('Back to ' .. tostring(m.from) .. '. Reloading YunaUI...');
    if not U.test and E.reload then E.reload(); end
    return true;
end
return U;
