local prototypes = {}
local symbols = {}

---@alias idl.gen.writer fun(str:string|nil)


---@param module idl.gen.module_desc
---@param cls idl.gen.class_desc
---@param write idl.gen.writer
local function gen_class_open(module, cls, write, register_class_arr)
    local oluacls_class
    
    local typename = cls.cxxcls:match("::([%w_]+)$")

    local lines = {}
    lines[#lines + 1] = olua.format([["${typename}", sol::no_constructor]])

    if not cls.options.reg_luatype then
    elseif cls.supercls then
        lines[#lines + 1] = olua.format([[sol::base_classes, sol::bases<${cls.supercls}>()]])
    else
    end

    -- 函数导出
    for _, arr in ipairs(cls.funcs) do
        local func = arr[1]
        local luafn = func.luafn

        -- if  func.cxxfn == "test" or luafn == "test" then
        --     dump(cls, "FFFFFFFFFFFFFF", 100)
        --     break
        -- end

        if func.is_exposed and #arr == 1 and not func.is_contructor and func.cxxfn ~= "__gc" then
            if func.args == nil then
                dump(cls.funcs)
            end
            local args_num = string.format("%d", #func.args)

            local params = func.prototype:match("%((.*)%)")
            if params == "" or params == nil then
                params = ""
            else
                params = ", " .. params
            end

            lines[#lines + 1] = olua.format([[LUA_METHOD_${args_num}(${typename}, ${func.cxxfn}${params})]])
        end
    end

    -- 变量导出
    for _, vi in ipairs(cls.vars) do
        -- 获取返回值类型
        local ret_type = vi.get.prototype:match('^([%w_:<>*&]+)%s+[%w_()]+$')
        local var_name = vi.name

        -- print("-------------------->")
        -- print(vi.name)
        -- print(vi.get.funcdesc)
        -- print(vi.get.prototype)
        -- print(ret_type)

        lines[#lines + 1] = olua.format([[LUA_PROPERTY_GET_SET(${typename}, ${var_name}, ${ret_type})]])
    end






    for k, v in pairs(lines) do
        lines[k] = "        " .. v
    end
    local code = table.concat(lines, ",\n")


    write(olua.format([[
    void register_${cls.luacls#}_tolua(sol::table& lua)
    {
        // clang-format off
        
        lua.new_usertype<${cls.cxxcls}>(
${code}
        )

        // clang-format on
    }
    ]]))

    table.insert(register_class_arr, olua.format([[${cls.luacls#}]]))
end


---@param module idl.gen.module_desc
local function has_packable_or_fromtable_class(module)
    for _, cls in ipairs(module.class_types) do
        if cls.options.packable or cls.options.from_table then
            return true
        end
    end
    return false
end

---@param module idl.gen.module_desc
local function gen_header(module)
    local arr = olua.array("\n")
    local function write(value)
        if value then
            -- '   #if' => '#if'
            arr:push(value:gsub("\n *#", "\n#"))
        end
    end

    local HEADER = string.upper(module.name)
    local headers = module.headers
    if not has_packable_or_fromtable_class(module) then
        headers = '#include "olua/olua.h"'
    end

    write(olua.format([[
        //
        // AUTO GENERATED, DO NOT MODIFY!
        //
        #pragma once
        #include "tolua_common.h"

        void register_auto_module_${module.name}_tolua(sol::table& lua);
    ]]))
    write("")


    local path = olua.format("${module.output_dir}/${module.name}_tolua.h")
    olua.write(path, tostring(arr))
end

---@param module idl.gen.module_desc
---@param write idl.gen.writer
local function gen_classes(module, register_class_arr)
    for _, cls in ipairs(module.class_types) do
        if not cls.options.ignore_self_type then
            
            local arr = olua.array("\n")
            local function write(value)
                if value then
                    -- '   #if' => '#if'
                    arr:push(value:gsub("\n *#", "\n#"))
                end
            end


            local macro = cls.macro
            write(macro)
            gen_class_open(module, cls, write, register_class_arr)
            write(macro and "#endif" or nil)
            write("")

            local path = olua.format("${module.output_dir}/${cls.luacls#}_tolua.cpp")
            path = path:gsub("(%u)", function(c) return "_" .. c:lower() end):gsub("^_", "")
            path = path:gsub("__", "_")
            olua.write(path, tostring(arr))
        end
    end
end

---@param module idl.gen.module_desc
---@param write idl.gen.writer
local function gen_include(module, write)
    local headers = ""
    if not has_packable_or_fromtable_class(module) then
        headers = module.headers
    end
    write(olua.format([[
        //
        // AUTO GENERATED, DO NOT MODIFY!
        //
        #include "lua_${module.name}.h"
        ${headers}
    ]]))
    write("")

    if module.codeblock and #module.codeblock > 0 then
        write(olua.format(module.codeblock))
        write("")
    end
end

local function gen_entry(module, write, register_class_arr)
    for k, v in pairs(register_class_arr) do
        write(olua.format("extern void register_${v}_tolua(sol::table& lua);"))
    end


    local codeblock = [[

void register_auto_module_${module.name}_tolua(sol::table& lua)
{
]]
    write(olua.format(codeblock))

    for k, v in pairs(register_class_arr) do
        write(olua.format("    register_${v}_tolua(lua);"))
    end

    write("}")
end

---@param module idl.gen.module_desc
function olua.gen_sol_binding(module)
    gen_header(module)

    local register_class_arr = {}

    local arr = olua.array("\n")

    ---@param value string
    local function append(value)
        if value then
            -- '   #if' => '#if'
            if not value then
                print("value is nil")
            end
            arr:push(value:gsub("\n *#", "\n#"))
        end
    end

    gen_include(module, append)
    gen_classes(module, register_class_arr)
    gen_entry(module, append, register_class_arr)

    local path = olua.format("${module.output_dir}/${module.name}_tolua.cpp")
    olua.write(path, tostring(arr))
end