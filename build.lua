require "olua"

inspect = require('inspect')

local ROOT_SOURCE_DIR = 'D:/work/AxmolFighter/client/Source'

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------


local is_windows = package.config:find("\\")

local function listDirectory(path, options)
    options = options or {}
    local pattern = options.pattern or "*"
    local show_dirs = options.show_dirs or false
    local show_files = options.show_files or true
    local recursive = options.recursive or false
    
    local command
    if recursive then
        command = string.format('dir "%s\\%s" /B /S', path, pattern)
    else
        command = string.format('dir "%s\\%s" /B', path, pattern)
    end
    
    local files = {}
    local handle = io.popen(command .. ' 2>nul')
    
    if handle then
        for line in handle:lines() do
            -- 检查是文件还是目录
            local is_dir = line:match("\\[^\\]+$") and true or false
            local name = line:match("\\([^\\]+)$") or line
            
            if (show_files and not is_dir) or (show_dirs and is_dir) then
                table.insert(files, {
                    name = name,
                    path = line,
                    is_dir = is_dir
                })
            end
        end
        handle:close()
    end
    
    return files
end

local function autoGenerateMacroDefinitionFile(dir_name, out_file_name, macro_name)
    local root_dir = ROOT_SOURCE_DIR .. "/mugen"
    local search_dir = root_dir .. "/" .. dir_name
    local items = listDirectory(search_dir, {
        show_dirs = false,
        show_files = true,
        pattern = "*.*"
    })

    local types = {}
    for _, item in ipairs(items) do
        if not item.is_dir and string.sub(item.name, -2) == ".h" then
            local type_name = string.sub(item.name, 1, -3)
            table.insert(types, type_name)
        end
    end

    local lines = {
        "#pragma once",
        "",
    }

    for k, v in pairs(types) do
       table.insert(lines, string.format("#include \"%s/%s.h\"", dir_name, v))
    end
    table.insert(lines, "")

    for k, v in pairs(types) do
        types[k] = string.format("X(%s)", v)
    end
    table.insert(lines, string.format("#define %s %s", macro_name, table.concat(types, " ")))

    local content = table.concat(lines, "\n")
    olua.write(root_dir .. "/" .. out_file_name, content)
end

if is_windows then
    autoGenerateMacroDefinitionFile("component", "Components.h", "COMPONENT_LIST")
    autoGenerateMacroDefinitionFile("system", "Systems.h", "SYSTEM_LIST")
    autoGenerateMacroDefinitionFile("states", "States.h", "STATE_LIST")
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

olua.AUTO_EXPORT_PARENT = true
olua.AUTO_GEN_PROP = false

olua.AUTO_BUILD = true

-------------------------------------------------------------------------------
--- clang compile options
-------------------------------------------------------------------------------
clang {
    '-DOLUA_DEBUG',
    '-I' .. ROOT_SOURCE_DIR
}

-------------------------------------------------------------------------------
--- mugen wrapper
-------------------------------------------------------------------------------
module 'mugen'

output_dir(ROOT_SOURCE_DIR .. '/mugen/tolua/auto')

api_dir 'autobuild/addons/mugen'

headers [[
#include "mugen/core/ecs/Component.h"
#include "mugen/core/ecs/ECSManager.h"
#include "mugen/core/ecs/Entity.h"
#include "mugen/core/ecs/System.h"
#include "mugen/GameWord.h"
#include "mugen/Components.h"
#include "mugen/Systems.h"
#include "mugen/conf/Config.h"
]]

local pattern = {
}

local function luaname(name)
    for _, v in ipairs(pattern) do
        if name:find(v) then
            name = name:gsub(v, '')
        end
    end
    return name
end

local function typeenum(cls)
    return typeconf(cls)
        .luaname(luaname)
end

typeconf 'mugen::fixed_number32'
    .ignore_self_type 'true'
    
typeconf 'mugen::fixed_number64'
    .ignore_self_type 'true'

typeconf 'mugen::fixedPoint'
    .ignore_self_type 'true'

typeconf 'mugen::ByteBuffer'
    .ignore_self_type 'true'

typeconf 'mugen::Object'
    .ignore_self_type 'true'
    .exclude "serialize"
    .exclude "deserialize"
    .exclude "copySpecialProperties"

typeconf 'mugen::Component'
    .ignore_self_type 'true'
typeconf 'mugen::ECSManager'
    .ignore_self_type 'true'
typeconf 'mugen::Entity'
    .ignore_self_type 'true'
typeconf 'mugen::System'
    .ignore_self_type 'true'
typeconf 'mugen::GameWord'
    .ignore_self_type 'true'
typeconf 'mugen::Signature'
    .ignore_self_type 'true'

typeconf 'mugen::IdentityComponent'
typeconf 'mugen::TransformComponent'
typeconf 'mugen::ObstacleComponent'
typeconf 'mugen::SoundComponent'
typeconf 'mugen::StatesComponent'

typeconf 'mugen::MapTile'
    .is_not_extend_object 'true'
    .custom_sol_function {
[[
    "from_table", [](const sol::table& tbl) {
        mugen::MapTile t;
        t.url = tbl["url"].get_or(std::string{});
        t.sx = tbl["sx"].get_or(1.0f);
        t.sy = tbl["sy"].get_or(1.0f);
        t.ax = tbl["ax"].get_or(0.0f);
        t.ay = tbl["ay"].get_or(0.0f);
        t.x = static_cast<int>(tbl["x"].get_or(0.0));
        t.y = static_cast<int>(tbl["y"].get_or(0.0));
        t.w = static_cast<int>(tbl["w"].get_or(0.0));
        t.h = static_cast<int>(tbl["h"].get_or(0.0));
        return t;
    }
]]
    }


typeconf 'mugen::LayerGroup'
    .is_not_extend_object 'true'
    .custom_sol_function {
[[
    "from_table", [](const sol::table& tbl) {
        mugen::LayerGroup group;
        auto fill = [](std::vector<mugen::MapTile>& vec, const sol::object& obj) {
            if (obj.is<sol::table>()) {
                for (auto& pair : obj.as<sol::table>()) {
                    if (pair.second.is<sol::table>()) {
                        const sol::table& t = pair.second.as<sol::table>();
                        mugen::MapTile tile;
                        tile.url = t["url"].get_or(std::string{});
                        tile.sx = t["sx"].get_or(1.0f);
                        tile.sy = t["sy"].get_or(1.0f);
                        tile.ax = t["ax"].get_or(0.0f);
                        tile.ay = t["ay"].get_or(0.0f);
                        tile.x = static_cast<int>(t["x"].get_or(0.0));
                        tile.y = static_cast<int>(t["y"].get_or(0.0));
                        tile.w = static_cast<int>(t["w"].get_or(0.0));
                        tile.h = static_cast<int>(t["h"].get_or(0.0));
                        vec.push_back(tile);
                    }
                }
            }
        };
        fill(group.farGroup, tbl["farGroup"]);
        fill(group.nearGroup, tbl["nearGroup"]);
        fill(group.floorGroup, tbl["floorGroup"]);
        fill(group.objectGroup, tbl["objectGroup"]);
        fill(group.effectGroup, tbl["effectGroup"]);
        return group;
    }
]]
    }


typeconf 'mugen::MapScope'
    .is_not_extend_object 'true'
    .custom_sol_function {
[[
    "from_table", [](const sol::table& tbl) {
        mugen::MapScope t;
        t.w = static_cast<int>(tbl["w"].get_or(0.0));
        t.h = static_cast<int>(tbl["h"].get_or(0.0));
        t.x = static_cast<int>(tbl["x"].get_or(0.0));
        t.y = static_cast<int>(tbl["y"].get_or(0.0));
        return t;
    }
]]
    }

typeconf 'mugen::MapInfo'
    .is_not_extend_object 'true'
    .custom_sol_function {
[[
    "from_table", [](const sol::table& tbl) {
        mugen::MapInfo t;
        t.bgm = tbl["bgm"].get_or(std::string{});
        t.name = tbl["name"].get_or(std::string{});
        t.theme = tbl["theme"].get_or(std::string{});
        t.isTown = tbl["isTown"].get_or(false);
        t.width = static_cast<int>(tbl["width"].get_or(0.0));
        t.height = static_cast<int>(tbl["height"].get_or(0.0));
        t.horizon = tbl["horizon"].get_or(0);
        return t;
    }
]]
    }


typeconf 'mugen::GameMapComponent'

typeconf 'mugen::GameMapRenderComponent'



typeconf 'mugen::GameMapRenderSystem'
    .exclude "onEntityAdded"
    .exclude "onEntityRemoved"
typeconf 'mugen::GameMapSystem'
    .exclude "onEntityAdded"
    .exclude "onEntityRemoved"
typeconf 'mugen::ObstacleSystem'
    .exclude "onEntityAdded"
    .exclude "onEntityRemoved"

-- math
typeconf 'mugen::Vector2f'
typeconf 'mugen::Vector2i'
typeconf 'mugen::Vector3f'
typeconf 'mugen::Vector3i'
typeconf 'mugen::DamageBox'

-- GameDef enums
typeconf 'mugen::JobType'
typeconf 'mugen::AtkType'
typeconf 'mugen::ElementalProperty'

-- Config
typeconf 'mugen::Frame'
typeconf 'mugen::AniConfig'
typeconf 'mugen::AtkConfig'
typeconf 'mugen::CharacterConfig'
typeconf 'mugen::EquConfig'
typeconf 'mugen::Config'
