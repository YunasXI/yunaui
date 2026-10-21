--[[
yunalink: YunaUI's little helper on VanaCore. YunaUI is an Ashita addon and can't reach VanaCore's own settings;
this VanaCore addon can, and does what YunaUI asks with a command. YunaUI copies it to Vanacore\addons\vanacore\yunalink
and loads it by itself - nothing to do by hand.

  /yunalink hideown on     your own name over your head hidden (VanaCore's Hide own nameplate), how it was kept
  /yunalink hideown off    put back as it was before
--]]

addon.name    = 'yunalink'
addon.author  = 'Yunas'
addon.version = '1.0'
addon.desc    = "YunaUI's helper: lets YunaUI change a few VanaCore settings."

local function set(section, key, value)
    vana.config.set(section, key, value)
    pcall(function () vana.graphics.reload() end)
end

vana.events.on('command', function (e)
    local what, arg = e.command:lower():match('^/+yunalink%s+(%S+)%s*(%S*)')
    if what == nil then
        return false
    end
    if what == 'hideown' then
        if arg == 'on' then
            if vana.config.get('yunalink', 'hideown.prev') == nil then   -- (how it was, kept once: put back by "off")
                vana.config.set('yunalink', 'hideown.prev', tostring(vana.config.get('graphics', 'nameplates.hideown') or '0'))
            end
            set('graphics', 'nameplates.hideown', '1')
        elseif arg == 'off' then
            local prev = vana.config.get('yunalink', 'hideown.prev')
            if prev ~= nil then
                set('graphics', 'nameplates.hideown', (prev ~= '0' and prev ~= '') and prev or nil)
                vana.config.set('yunalink', 'hideown.prev', nil)
            end
        end
    end
    return true
end)
