require "olua"

olua.AUTO_EXPORT_PARENT = true
olua.AUTO_GEN_PROP = false

olua.AUTO_BUILD = true

-------------------------------------------------------------------------------
--- clang compile options
-------------------------------------------------------------------------------
clang {
    '-DOLUA_DEBUG',
    '-ID:/work/AxmolFighter/client/Source'
}

-------------------------------------------------------------------------------
--- af wrapper
-------------------------------------------------------------------------------
module 'af'

output_dir 'D:/work/AxmolFighter/client/Source/af/tolua/auto'

api_dir 'autobuild/addons/af'

headers [[
#include "af/ecs/Component.h"
#include "af/ecs/ECSManager.h"
#include "af/ecs/Entity.h"
#include "af/ecs/System.h"
#include "af/GameWord.h"
#include "af/Components.h"
#include "af/Systems.h"
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

typeconf 'af::Object'
    .ignore_self_type 'true'
typeconf 'af::Component'
    .ignore_self_type 'true'
typeconf 'af::ECSManager'
    .ignore_self_type 'true'
typeconf 'af::Entity'
    .ignore_self_type 'true'
typeconf 'af::System'
    .ignore_self_type 'true'
typeconf 'af::GameWord'
    .ignore_self_type 'true'
typeconf 'af::Signature'
    .ignore_self_type 'true'


typeconf 'af::IdentityComponent'
typeconf 'af::TransformComponent'
typeconf 'af::ObstacleComponent'
typeconf 'af::SoundComponent'
typeconf 'af::StatesComponent'

typeconf 'af::MapTile'
    .is_not_extend_object 'true'
typeconf 'af::LayerGroup'
    .is_not_extend_object 'true'
typeconf 'af::MapScope'
    .is_not_extend_object 'true'
typeconf 'af::MapInfo'
    .is_not_extend_object 'true'
typeconf 'af::GameMapComponent'

typeconf 'af::GameMapRenderComponent'



typeconf 'af::GameMapRenderSystem'
typeconf 'af::GameMapSystem'
typeconf 'af::ObstacleSystem'