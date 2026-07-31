require "olua"

inspect = require('inspect')

local ROOT_SOURCE_DIR = 'D:/work/AxmolFighter/client/Source'
local OUTPUT_SOURCE_DIR = 'D:/work/AxmolFighter/tools/3rd/mugen_tolua/auto'

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

local function tableContains(tab, value)
    for k, v in pairs(tab or {}) do
        if v == value then return true end
    end
    return false
end

local function autoGenerateMacroDefinitionFile(dir_name, out_file_name, macro_name, ignore_names, macro_cfg)
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


    if not macro_cfg then
        macro_cfg = {}
    end
    macro_cfg.types = macro_cfg.types or {}
    if macro_cfg.macro == nil then
        macro_cfg.types = {}
    end



    local lines = {
        "#pragma once",
        "",
    }
    local macro_types = {}
    for k, v in pairs(types) do
        if tableContains(macro_cfg.types, v) then
            table.insert(macro_types, v)
        else
            table.insert(lines, string.format("#include \"%s/%s.h\"", dir_name, v))
        end
    end
    table.insert(lines, "")

    if #macro_types > 0 then
        table.insert(lines, string.format("#ifdef %s", macro_cfg.macro))

        for k, v in pairs(macro_types) do
            table.insert(lines, string.format("#    include \"%s/%s.h\"", dir_name, v))
        end

        table.insert(lines, "#endif")
        table.insert(lines, "")
    end

    table.insert(lines, "// clang-format off")

    local names = {}
    if macro_cfg.macro then
        table.insert(lines, string.format("#ifdef %s", macro_cfg.macro))

            names = {}
            for k, v in pairs(types) do
                names[#names + 1] = string.format("X(%s)", v)
            end
            table.insert(lines, string.format("#    define %s %s", macro_name, table.concat(names, " ")))

        table.insert(lines, "#else")

            names = {}
            for k, v in pairs(types) do
                if not tableContains(macro_cfg.types, v) then
                    names[#names + 1] = string.format("X(%s)", v)
                end
            end
            table.insert(lines, string.format("#    define %s %s", macro_name, table.concat(names, " ")))
        
        table.insert(lines, "#endif")
    else
        names = {}
        for k, v in pairs(types) do
            names[#names + 1] = string.format("X(%s)", v)
        end
        table.insert(lines, string.format("#define %s %s", macro_name, table.concat(names, " ")))
    end
    
    table.insert(lines, "// clang-format on")

    local content = table.concat(lines, "\n")
    olua.write(root_dir .. "/" .. out_file_name, content)
end

if is_windows then
    autoGenerateMacroDefinitionFile("component", "Components.h", "COMPONENT_LIST")
    autoGenerateMacroDefinitionFile("system", "Systems.h", "SYSTEM_LIST")
    -- autoGenerateMacroDefinitionFile("system", "Systems.h", "SYSTEM_LIST", {}, {
    --     macro = "RUNTIME_IN_AXMOL",
    --     types = {
    --         "AvatarRenderSystem",
    --         "GameMapRenderSystem",
    --     }
    -- })
    autoGenerateMacroDefinitionFile("state", "States.h", "STATE_LIST", {"SkillState"})
    autoGenerateMacroDefinitionFile("transition", "Transitions.h", "TRANSITION_LIST")
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


output_dir(OUTPUT_SOURCE_DIR)

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
-- typeconf 'mugen::DamageBox'
--     .custom_sol_constructor {
--         '"DamageBox", sol::constructors<mugen::DamageBox()>()'
--     }


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
typeconf 'mugen::SpeedType'
typeconf 'mugen::VelocityMode'
typeconf 'mugen::ExitConditionType'
typeconf 'mugen::FacingDirection'
typeconf 'mugen::StateTag'
typeconf 'mugen::AvatarType'
typeconf 'mugen::SeekMode'

-- Config

typeconf 'mugen::ComboInputCondition'
    .custom_sol_constructor {
        '"ComboInputCondition", sol::constructors<mugen::ComboInputCondition()>()'
    }
typeconf 'mugen::InputBufferConfig'
    .custom_sol_constructor {
        '"InputBufferConfig", sol::constructors<mugen::InputBufferConfig()>()'
    }
typeconf 'mugen::SkillActivationConfig'
    .custom_sol_constructor {
        '"SkillActivationConfig", sol::constructors<mugen::SkillActivationConfig()>()'
    }
typeconf 'mugen::SkillHitConfig'
    .custom_sol_constructor {
        '"SkillHitConfig", sol::constructors<mugen::SkillHitConfig()>()'
    }
typeconf 'mugen::SeekToConfig'
    .custom_sol_constructor {
        '"SeekToConfig", sol::constructors<mugen::SeekToConfig()>()'
    }
typeconf 'mugen::SkillStageConfig'
    .custom_sol_constructor {
        '"SkillStageConfig", sol::constructors<mugen::SkillStageConfig()>()'
    }
typeconf 'mugen::SkillConfig'
    .custom_sol_constructor {
        '"SkillConfig", sol::constructors<mugen::SkillConfig()>()'
    }
    .exclude "sourcePath"


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
typeconf 'mugen::ChrEquipmentConfig'
    .custom_sol_constructor {
        '"ChrEquipmentConfig", sol::constructors<mugen::ChrEquipmentConfig()>()'
    }
typeconf 'mugen::ChrConfig'
    .custom_sol_constructor {
        '"ChrConfig", sol::constructors<mugen::ChrConfig()>()'
    }
    .exclude "sourcePath"

typeconf 'mugen::ActorSlotSkillConfig'
    .custom_sol_constructor {
        '"ActorSlotSkillConfig", sol::constructors<mugen::ActorSlotSkillConfig()>()'
    }
typeconf 'mugen::ActorSkillConfig'
    .custom_sol_constructor {
        '"ActorSkillConfig", sol::constructors<mugen::ActorSkillConfig()>()'
    }
typeconf 'mugen::ActorEquipmentConfig'
    .custom_sol_constructor {
        '"ActorEquipmentConfig", sol::constructors<mugen::ActorEquipmentConfig()>()'
    }
typeconf 'mugen::ActorConfig'
    .custom_sol_constructor {
        '"ActorConfig", sol::constructors<mugen::ActorConfig()>()'
    }
    .exclude "sourcePath"

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
    .exclude "sourcePath"

typeconf 'mugen::MapScope'
    .custom_sol_constructor {
        '"MapScope", sol::constructors<mugen::MapScope()>()'
    }
typeconf 'mugen::MapActorSpawn'
    .custom_sol_constructor {
        '"MapActorSpawn", sol::constructors<mugen::MapActorSpawn()>()'
    }

typeconf 'mugen::MapConfig'
    .custom_sol_constructor {
        '"MapConfig", sol::constructors<mugen::MapConfig()>()'
    }
    .exclude "sourcePath"

typeconf 'mugen::SoundConfig'
    .custom_sol_constructor {
        '"SoundConfig", sol::constructors<mugen::SoundConfig()>()'
    }
typeconf 'mugen::SoundItem'
    .custom_sol_constructor {
        '"SoundItem", sol::constructors<mugen::SoundItem()>()'
    }
typeconf 'mugen::SoundRandomItem'
    .custom_sol_constructor {
        '"SoundRandomItem", sol::constructors<mugen::SoundRandomItem()>()'
    }
typeconf 'mugen::SoundRandomGroup'
    .custom_sol_constructor {
        '"SoundRandomGroup", sol::constructors<mugen::SoundRandomGroup()>()'
    }

typeconf 'mugen::Config'
    .exclude "destroyInstance"
    .exclude "getInstance"
    .exclude "getActorConfigByJob"
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
