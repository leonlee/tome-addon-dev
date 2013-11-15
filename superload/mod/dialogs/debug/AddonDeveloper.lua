-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009, 2010, 2011, 2012, 2013 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

require "engine.class"
local Dialog = require "engine.ui.Dialog"
local List = require "engine.ui.List"
local Module = require "engine.Module"

module(..., package.seeall, class.inherit(engine.ui.Dialog))

function _M:init()
	self:generateList()
	engine.ui.Dialog.init(self, "Addon Developer", 1, 1)

	local list = List.new{width=400, height=500, list=self.list, fct=function(item) self:use(item) end}

	self:loadUI{
		{left=0, top=0, ui=list},
	}
	self:setupUI(true, true)

	self.key:addCommands{ __TEXTINPUT = function(c) if self.list and self.list.chars[c] then self:use(self.list[self.list.chars[c]]) end end}
	self.key:addBinds{ EXIT = function() game:unregisterDialog(self) end, }
end

function _M:on_register()
	game:onTickEnd(function() self.key:unicodeInput(true) end)
end

function _M:listAddons(filter)
	local list = {}
	for short_name, add in pairs(game.__mod_info.addons) do
		if not filter or filter(add) then
			list[#list+1] = {
				name = add.long_name,
				add = add,
			}
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

function _M:zipAddon(add)
	local t = core.game.getTime()

	local base = nil
	if add.teaa then base = fs.getRealPath(add.teaa)
	else base = fs.getRealPath(add.dir) end

	local md5 = require "md5"
	local md5s = {}
	fs.mkdir("/user-generated-addons/")
	local zipname = ("%s-%s.teaa"):format(game.__mod_info.short_name, add.short_name)
	local zip = fs.zipOpen("/user-generated-addons/"..zipname)
	local function fp(dir, initlen)
		for i, file in ipairs(fs.list(dir)) do
			local f = dir.."/"..file
			if file == ".git" or file == ".svn" or file == ".hg" or file == "CVS" or file == "pack.me" then
				-- ignore
			elseif fs.isdir(f) then
				fp(f, initlen)
			else
				local fff = fs.open(f, "r")
				if fff then
					local datas = {}
					while true do
						local data = fff:read(1024 * 1024 * 1024)
						if not data then break end
						datas[#datas+1] = data
					end
					fff:close()
					datas = table.concat(datas)
					zip:add(f:sub(initlen+1), datas, 0)
				end
			end
		end
	end
	fs.mount(base, "/loaded-addons/"..add.short_name, true)
	fp("/loaded-addons/"..add.short_name, #("/loaded-addons/"..add.short_name.."/"))
	fs.umount(base)
	zip:close()

	local more = ""
	if profile.auth then
		more = [[
- Your profile has been enabled for addon uploading, you can go to #{italic}##LIGHT_BLUE#http://te4.org/addons/tome#LAST##{normal}# and upload your addon.
]]
		profile:addonEnableUpload()
	end

	local fmd5 = Module:addonMD5(add, fs.getRealPath("/user-generated-addons/"..zipname))
	core.key.setClipboard(fmd5)
	Dialog:simpleLongPopup("Archive for "..add.long_name, ([[Addon archive created:
- Addon file: #LIGHT_GREEN#%s#LAST# in folder #{bold}#%s#{normal}#
- Addon MD5: #LIGHT_BLUE#%s#LAST# (this was copied to your clipboard)
%s
]]):format(zipname, fs.getRealPath("/user-generated-addons/"), fmd5, more), 780)
end

function _M:use(item)
	if not item then return end
	game:unregisterDialog(self)

	if item.dialog then
		local d = require("mod.dialogs.debug."..item.dialog).new()
		game:registerDialog(d)
		return
	end

	local act = item.action

	local stop = false
	if act == "md5" then Dialog:listPopup("Choose an addon for MD5", "", self:listAddons(), 400, 500, function(item) if item then
		local fmd5 = Module:addonMD5(item.add)
		core.key.setClipboard(fmd5)
		Dialog:simplePopup("MD5 for "..item.name, "Addon MD5: #LIGHT_BLUE#"..fmd5.."#LAST# (this was copied to your clipboard)")
	end end) end

	if act == "zip" then Dialog:listPopup("Choose an addon to archive", "", self:listAddons(function(add) return not add.teaa end), 400, 500, function(item) if item then
		self:zipAddon(item.add)
	end end) end
end

function _M:generateList()
	local list = {}

	list[#list+1] = {name="Generate addon's MD5", action="md5"}
	list[#list+1] = {name="Generate addon's archive", action="zip"}

	local chars = {}
	for i, v in ipairs(list) do
		v.name = self:makeKeyChar(i)..") "..v.name
		chars[self:makeKeyChar(i)] = i
	end
	list.chars = chars

	self.list = list
end
