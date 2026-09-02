require "olua"

inspect = require('inspect')

local ROOT_SOURCE_DIR = '../..//AxmolFighter-Client/Source'
local OUTPUT_SOURCE_DIR = '../3rd/mugen_tolua/auto'

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


-- expr (Config 路径不再依赖，保留需自行加 headers)
-- typeconf 'mugen::Vec2Expr'
-- typeconf 'mugen::Vec3Expr'

-- GameDef enums
typeconf 'mugen::SlotTriggerFlag'
typeconf 'mugen::EntityCategory'
typeconf 'mugen::EntityRoleType'
typeconf 'mugen::CharacterClass'
typeconf 'mugen::HitType'
typeconf 'mugen::FacingDirection'
typeconf 'mugen::StateTag'
typeconf 'mugen::BehaviorKind'

-- Table configs
typeconf 'mugen::PortalDestEntry'
    .custom_sol_constructor {
        '"PortalDestEntry", sol::constructors<mugen::PortalDestEntry()>()'
    }
typeconf 'mugen::PortalEntry'
    .custom_sol_constructor {
        '"PortalEntry", sol::constructors<mugen::PortalEntry()>()'
    }
typeconf 'mugen::NpcSlotEntry'
    .custom_sol_constructor {
        '"NpcSlotEntry", sol::constructors<mugen::NpcSlotEntry()>()'
    }
typeconf 'mugen::GoodEntry'
    .custom_sol_constructor {
        '"GoodEntry", sol::constructors<mugen::GoodEntry()>()'
    }
typeconf 'mugen::ObstacleEntry'
    .custom_sol_constructor {
        '"ObstacleEntry", sol::constructors<mugen::ObstacleEntry()>()'
    }
typeconf 'mugen::ActorSpawnEntry'
    .custom_sol_constructor {
        '"ActorSpawnEntry", sol::constructors<mugen::ActorSpawnEntry()>()'
    }
typeconf 'mugen::MonsterEntry'
    .custom_sol_constructor {
        '"MonsterEntry", sol::constructors<mugen::MonsterEntry()>()'
    }
typeconf 'mugen::ConnectCity'
    .custom_sol_constructor {
        '"ConnectCity", sol::constructors<mugen::ConnectCity()>()'
    }
typeconf 'mugen::ChapterRewardPhase'
    .custom_sol_constructor {
        '"ChapterRewardPhase", sol::constructors<mugen::ChapterRewardPhase()>()'
    }
typeconf 'mugen::TownConfig'
    .custom_sol_constructor {
        '"TownConfig", sol::constructors<mugen::TownConfig()>()'
    }
typeconf 'mugen::CampConfig'
    .custom_sol_constructor {
        '"CampConfig", sol::constructors<mugen::CampConfig()>()'
    }
typeconf 'mugen::StageConfig'
    .custom_sol_constructor {
        '"StageConfig", sol::constructors<mugen::StageConfig()>()'
    }
typeconf 'mugen::CopyConfig'
    .custom_sol_constructor {
        '"CopyConfig", sol::constructors<mugen::CopyConfig()>()'
    }
typeconf 'mugen::ChapterConfig'
    .custom_sol_constructor {
        '"ChapterConfig", sol::constructors<mugen::ChapterConfig()>()'
    }
typeconf 'mugen::NpcConfig'
    .custom_sol_constructor {
        '"NpcConfig", sol::constructors<mugen::NpcConfig()>()'
    }
typeconf 'mugen::PortalConfig'
    .custom_sol_constructor {
        '"PortalConfig", sol::constructors<mugen::PortalConfig()>()'
    }
typeconf 'mugen::RoomConfig'
    .custom_sol_constructor {
        '"RoomConfig", sol::constructors<mugen::RoomConfig()>()'
    }
typeconf 'mugen::IntListRow'
    .custom_sol_constructor {
        '"IntListRow", sol::constructors<mugen::IntListRow()>()'
    }
typeconf 'mugen::BehaviorBranchConfig'
    .custom_sol_constructor {
        '"BehaviorBranchConfig", sol::constructors<mugen::BehaviorBranchConfig()>()'
    }
typeconf 'mugen::BehaviorTemplateConfig'
    .custom_sol_constructor {
        '"BehaviorTemplateConfig", sol::constructors<mugen::BehaviorTemplateConfig()>()'
    }
typeconf 'mugen::ActionAttackConfig'
    .custom_sol_constructor {
        '"ActionAttackConfig", sol::constructors<mugen::ActionAttackConfig()>()'
    }
typeconf 'mugen::SkillAttackConfig'
    .custom_sol_constructor {
        '"SkillAttackConfig", sol::constructors<mugen::SkillAttackConfig()>()'
    }
typeconf 'mugen::SkillHitTableConfig'
    .custom_sol_constructor {
        '"SkillHitTableConfig", sol::constructors<mugen::SkillHitTableConfig()>()'
    }
typeconf 'mugen::AttributeTemplateConfig'
    .custom_sol_constructor {
        '"AttributeTemplateConfig", sol::constructors<mugen::AttributeTemplateConfig()>()'
    }
typeconf 'mugen::ResSpineConfig'
    .custom_sol_constructor {
        '"ResSpineConfig", sol::constructors<mugen::ResSpineConfig()>()'
    }
typeconf 'mugen::DisplacementConfig'
    .custom_sol_constructor {
        '"DisplacementConfig", sol::constructors<mugen::DisplacementConfig()>()'
    }
typeconf 'mugen::CameraConfig'
    .custom_sol_constructor {
        '"CameraConfig", sol::constructors<mugen::CameraConfig()>()'
    }
typeconf 'mugen::EffectConfig'
    .custom_sol_constructor {
        '"EffectConfig", sol::constructors<mugen::EffectConfig()>()'
    }
typeconf 'mugen::BuffConfig'
    .custom_sol_constructor {
        '"BuffConfig", sol::constructors<mugen::BuffConfig()>()'
    }
typeconf 'mugen::BuffRuleConfig'
    .custom_sol_constructor {
        '"BuffRuleConfig", sol::constructors<mugen::BuffRuleConfig()>()'
    }
typeconf 'mugen::AiConfig'
    .custom_sol_constructor {
        '"AiConfig", sol::constructors<mugen::AiConfig()>()'
    }
typeconf 'mugen::SkillAiConfig'
    .custom_sol_constructor {
        '"SkillAiConfig", sol::constructors<mugen::SkillAiConfig()>()'
    }
typeconf 'mugen::SkillHurtConfig'
    .custom_sol_constructor {
        '"SkillHurtConfig", sol::constructors<mugen::SkillHurtConfig()>()'
    }
typeconf 'mugen::RoleConfig'
    .custom_sol_constructor {
        '"RoleConfig", sol::constructors<mugen::RoleConfig()>()'
    }
typeconf 'mugen::ResSoundConfig'
    .custom_sol_constructor {
        '"ResSoundConfig", sol::constructors<mugen::ResSoundConfig()>()'
    }
typeconf 'mugen::SoundUiConfig'
    .custom_sol_constructor {
        '"SoundUiConfig", sol::constructors<mugen::SoundUiConfig()>()'
    }
typeconf 'mugen::SoundSpineConfig'
    .custom_sol_constructor {
        '"SoundSpineConfig", sol::constructors<mugen::SoundSpineConfig()>()'
    }
typeconf 'mugen::SoundSpineBgmConfig'
    .custom_sol_constructor {
        '"SoundSpineBgmConfig", sol::constructors<mugen::SoundSpineBgmConfig()>()'
    }
typeconf 'mugen::SoundMapSpineConfig'
    .custom_sol_constructor {
        '"SoundMapSpineConfig", sol::constructors<mugen::SoundMapSpineConfig()>()'
    }
typeconf 'mugen::SoundSendMessageConfig'
    .custom_sol_constructor {
        '"SoundSendMessageConfig", sol::constructors<mugen::SoundSendMessageConfig()>()'
    }
typeconf 'mugen::SoundTalkTextGroup'
    .custom_sol_constructor {
        '"SoundTalkTextGroup", sol::constructors<mugen::SoundTalkTextGroup()>()'
    }
typeconf 'mugen::SoundTalkConfig'
    .custom_sol_constructor {
        '"SoundTalkConfig", sol::constructors<mugen::SoundTalkConfig()>()'
    }
typeconf 'mugen::EquipConfig'
    .custom_sol_constructor {
        '"EquipConfig", sol::constructors<mugen::EquipConfig()>()'
    }
typeconf 'mugen::FashionConfig'
    .custom_sol_constructor {
        '"FashionConfig", sol::constructors<mugen::FashionConfig()>()'
    }
typeconf 'mugen::FashionSuitConfig'
    .custom_sol_constructor {
        '"FashionSuitConfig", sol::constructors<mugen::FashionSuitConfig()>()'
    }
typeconf 'mugen::ItemBaseConfig'
    .custom_sol_constructor {
        '"ItemBaseConfig", sol::constructors<mugen::ItemBaseConfig()>()'
    }
typeconf 'mugen::ResFashionConfig'
    .custom_sol_constructor {
        '"ResFashionConfig", sol::constructors<mugen::ResFashionConfig()>()'
    }

typeconf 'mugen::Config'
    .exclude "destroyInstance"
    .exclude "getInstance"
    .exclude "getTownConfigById"
    .exclude "getCampConfigById"
    .exclude "getStageConfigById"
    .exclude "getCopyConfigById"
    .exclude "getChapterConfigById"
    .exclude "getNpcConfigById"
    .exclude "getPortalConfigById"
    .exclude "getRoomConfigById"
    .exclude "getSkillAttackConfigById"
    .exclude "getActionAttackConfigById"
    .exclude "getSkillHitTableConfigById"
    .exclude "getRoleConfigById"
    .exclude "getResSpineConfigById"
    .exclude "getEquipConfigById"
    .exclude "getFashionConfigById"
    .exclude "getFashionSuitConfigById"
    .exclude "getItemBaseConfigById"
    .exclude "getResFashionConfigById"
    .exclude "getBehaviorTemplateConfigById"
    .exclude "getDisplacementConfigById"
    .exclude "getCameraConfigById"
    .exclude "getEffectConfigById"
    .exclude "getBuffConfigById"
    .exclude "getBuffRuleConfigById"
    .exclude "getAiConfigById"
    .exclude "getSkillAiConfigById"
    .exclude "getSkillHurtConfigById"
    .exclude "getAttributeTemplateConfigById"
    .exclude "getResSoundById"
    .exclude "getSoundUiByViewName"
    .exclude "getSoundSpineById"
    .exclude "getSoundSpineBgmById"
    .exclude "getSoundMapSpineById"
    .exclude "getSoundSendMessageById"
    .exclude "getSoundTalkById"
    .exclude "getChapterConfigs"
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
