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

local function autoGenerateMacroDefinitionFile(dir_name, out_file_name, macro_name, ignore_names)
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

            local ignore = false
            for k, v in pairs(ignore_names or {}) do
                if v == type_name then
                    ignore = true
                    break
                end
            end
            if not ignore then
                    table.insert(types, type_name)
            end
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
    autoGenerateMacroDefinitionFile("states", "States.h", "STATE_LIST", {"SkillState"})
    autoGenerateMacroDefinitionFile("translations", "Translations.h", "TRANSLATION_LIST")
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

typeconf 'mugen::ByteBuffer'
    .ignore_self_type 'true'

typeconf 'mugen::Object'
    .ignore_self_type 'true'
    .exclude "serialize"
    .exclude "deserialize"
    .exclude "copySpecialProperties"

-- typeconf 'mugen::Component'
--     .ignore_self_type 'true'
-- typeconf 'mugen::ECSManager'
--     .ignore_self_type 'true'
-- typeconf 'mugen::Entity'
--     .ignore_self_type 'true'
-- typeconf 'mugen::System'
--     .ignore_self_type 'true'
-- typeconf 'mugen::GameWord'
--     .ignore_self_type 'true'
-- typeconf 'mugen::Signature'
--     .ignore_self_type 'true'

-- typeconf 'mugen::PartData'
--     -- .custom_sol_constructor {
--     --     '"PartData", sol::constructors<mugen::PartData()>()'
--     -- }
-- typeconf 'mugen::AvatarComponent'
--     .exclude "equipments"
--     .custom_sol_function {
-- [[
--     "equipment_count", [](const AvatarComponent& self) {
--         return self.equipments.size();
--     },
--     "get_equipment", [](AvatarComponent& self, int index) -> PartData* {
--         if (index >= 1 && index <= static_cast<int>(self.equipments.size())) {
--             return &self.equipments[index - 1];
--         }
--         return nullptr;
--     }
-- ]]}

-- typeconf 'mugen::AvatarRenderComponent'
-- typeconf 'mugen::DirectorComponent'
-- typeconf 'mugen::GameMapComponent'
-- typeconf 'mugen::GameMapRenderComponent'
-- typeconf 'mugen::IdentityComponent'
-- typeconf 'mugen::InputComponent'
-- typeconf 'mugen::ObstacleComponent'
-- typeconf 'mugen::SoundComponent'

-- typeconf 'mugen::FSM'
-- typeconf 'mugen::State'
-- typeconf 'mugen::Translation'
-- typeconf 'mugen::StatesMachineComponent'

-- typeconf 'mugen::TransformComponent'


-- typeconf 'mugen::GameMapRenderSystem'
--     .exclude "onEntityAdded"
--     .exclude "onEntityRemoved"
-- typeconf 'mugen::GameMapSystem'
--     .exclude "onEntityAdded"
--     .exclude "onEntityRemoved"
-- typeconf 'mugen::ObstacleSystem'
--     .exclude "onEntityAdded"
--     .exclude "onEntityRemoved"
-- typeconf 'mugen::AvatarRenderSystem'
--     .exclude "onEntityAdded"
--     .exclude "onEntityRemoved"

-- math
typeconf 'mugen::Vector2f'
    .custom_sol_constructor {
        '"Vector2f", sol::constructors<mugen::Vector2f()>()'
    }
typeconf 'mugen::Vector2i'
    .custom_sol_constructor {
        '"Vector2i", sol::constructors<mugen::Vector2i()>()'
    }
typeconf 'mugen::Vector3f'
    .custom_sol_constructor {
        '"Vector3f", sol::constructors<mugen::Vector3f()>()'
    }
typeconf 'mugen::Vector3i'
    .custom_sol_constructor {
        '"Vector3i", sol::constructors<mugen::Vector3i()>()'
    }
typeconf 'mugen::DamageBox'
    .custom_sol_constructor {
        '"DamageBox", sol::constructors<mugen::DamageBox()>()'
    }


-- expr
typeconf 'mugen::Vec2Expr'
    .custom_sol_constructor {
        '"Vec2Expr", sol::constructors<mugen::Vec2Expr()>()'
    }
    .exclude "toVec2f"
    .exclude "toVec2i"
    .exclude "f32_x"
    .exclude "f32_y"
    .exclude "i32_x"
    .exclude "i32_y"

typeconf 'mugen::Vec3Expr'
    .custom_sol_constructor {
        '"Vec3Expr", sol::constructors<mugen::Vec3Expr()>()'
    }
    .exclude "toVec3f"
    .exclude "toVec3i"
    .exclude "f32_x"
    .exclude "f32_y"
    .exclude "f32_z"
    .exclude "i32_x"
    .exclude "i32_y"
    .exclude "i32_z"

-- GameDef enums
typeconf 'mugen::JobType'
typeconf 'mugen::HitType'
typeconf 'mugen::ElementalProperty'
typeconf 'mugen::EquipmentType'
typeconf 'mugen::EquipmentSubType'
typeconf 'mugen::EquipmentRarityType'

-- Config
typeconf 'mugen::Frame'
    .custom_sol_constructor {
        '"Frame", sol::constructors<mugen::Frame()>()'
    }

typeconf 'mugen::AniConfig'
    .custom_sol_constructor {
        '"AniConfig", sol::constructors<mugen::AniConfig()>()'
    }

typeconf 'mugen::AtkConfig'
    .custom_sol_constructor {
        '"AtkConfig", sol::constructors<mugen::AtkConfig()>()'
    }

typeconf 'mugen::MotionConfig'
    .custom_sol_constructor {
        '"MotionConfig", sol::constructors<mugen::MotionConfig()>()'
    }


typeconf 'mugen::SkillActivationConfig'
    .custom_sol_constructor {
        '"SkillActivationConfig", sol::constructors<mugen::SkillActivationConfig()>()'
    }
typeconf 'mugen::SkillHitConfig'
    .custom_sol_constructor {
        '"SkillHitConfig", sol::constructors<mugen::SkillHitConfig()>()'
    }
typeconf 'mugen::SkillStageConfig'
    .custom_sol_constructor {
        '"SkillStageConfig", sol::constructors<mugen::SkillStageConfig()>()'
    }
typeconf 'mugen::SkillConfig'
    .custom_sol_constructor {
        '"SkillConfig", sol::constructors<mugen::SkillConfig()>()'
    }


typeconf 'mugen::ChrHitReactionConfig'
    .custom_sol_constructor {
        '"ChrHitReactionConfig", sol::constructors<mugen::ChrHitReactionConfig()>()'
    }
typeconf 'mugen::ChrStateConfig'
    .custom_sol_constructor {
        '"ChrStateConfig", sol::constructors<mugen::ChrStateConfig()>()'
    }
typeconf 'mugen::ChrTransitionConditionConfig'
    .custom_sol_constructor {
        '"ChrTransitionConditionConfig", sol::constructors<mugen::ChrTransitionConditionConfig()>()'
    }
typeconf 'mugen::ChrTransitionConfig'
    .custom_sol_constructor {
        '"ChrTransitionConfig", sol::constructors<mugen::ChrTransitionConfig()>()'
    }
typeconf 'mugen::ChrSkillItemConfig'
    .custom_sol_constructor {
        '"ChrSkillItemConfig", sol::constructors<mugen::ChrSkillItemConfig()>()'
    }
typeconf 'mugen::ChrAttributeConfig'
    .custom_sol_constructor {
        '"ChrAttributeConfig", sol::constructors<mugen::ChrAttributeConfig()>()'
    }
typeconf 'mugen::ChrConfig'
    .custom_sol_constructor {
        '"ChrConfig", sol::constructors<mugen::ChrConfig()>()'
    }

typeconf 'mugen::ActorSlotSkillConfig'
    .custom_sol_constructor {
        '"ActorSlotSkillConfig", sol::constructors<mugen::ActorSlotSkillConfig()>()'
    }
typeconf 'mugen::ActorEquipmentConfig'
    .custom_sol_constructor {
        '"ActorEquipmentConfig", sol::constructors<mugen::ActorEquipmentConfig()>()'
    }
typeconf 'mugen::ActorConfig'
    .custom_sol_constructor {
        '"ActorConfig", sol::constructors<mugen::ActorConfig()>()'
    }


typeconf 'mugen::AniLayConfig'
    .custom_sol_constructor {
        '"AniLayConfig", sol::constructors<mugen::AniLayConfig()>()'
    }

typeconf 'mugen::EquAnimationLayerConfig'
    .custom_sol_constructor {
        '"EquAnimationLayerConfig", sol::constructors<mugen::EquAnimationLayerConfig()>()'
    }
typeconf 'mugen::EquAnimationConfig'
    .custom_sol_constructor {
        '"EquAnimationConfig", sol::constructors<mugen::EquAnimationConfig()>()'
    }

typeconf 'mugen::EquConfig'
    .custom_sol_constructor {
        '"EquConfig", sol::constructors<mugen::EquConfig()>()'
    }

typeconf 'mugen::MapItem'
    .custom_sol_constructor {
        '"MapItem", sol::constructors<mugen::MapItem()>()'
    }
typeconf 'mugen::MapLayer'
    .custom_sol_constructor {
        '"MapLayer", sol::constructors<mugen::MapLayer()>()'
    }
typeconf 'mugen::BackgroundLayer'
    .custom_sol_constructor {
        '"BackgroundLayer", sol::constructors<mugen::BackgroundLayer()>()'
    }
typeconf 'mugen::MapScope'
    .custom_sol_constructor {
        '"MapScope", sol::constructors<mugen::MapScope()>()'
    }
typeconf 'mugen::MapActor'
    .custom_sol_constructor {
        '"MapActor", sol::constructors<mugen::MapActor()>()'
    }

typeconf 'mugen::MapConfig'
    .custom_sol_constructor {
        '"MapConfig", sol::constructors<mugen::MapConfig()>()'
    }

typeconf 'mugen::Config'
    .exclude "destroyInstance"
    .exclude "getInstance"
    .exclude "getActorConfig"
    .exclude "getAniConfig"
    .exclude "getAniLayConfig"
    .exclude "getAtkConfig"
    .exclude "getChrConfig"
    .exclude "getEquConfig"
    .exclude "getEquConfigById"
    .exclude "getMapConfig"
    .exclude "getMapConfigById"
    .exclude "getSkillConfig,"
    .exclude "getSkillConfigById"
    .custom_sol_constructor {
        '"Config", sol::constructors<mugen::Config()>()'
    }
    .custom_sol_function {
[[
    "getInstance", []() {
        return mugen::Config::getInstance();
    }
]]
    }
