local prototypes = {}
local symbols = {}

---@alias idl.gen.writer fun(str:string|nil)

---@param module idl.gen.module_desc
local function has_packable_or_fromtable_class(module)
    for _, cls in ipairs(module.class_types) do
        if cls.options.packable or cls.options.from_table then
            return true
        end
    end
    return false
end

local function starts_with(str, prefix)
    return str:sub(1, #prefix) == prefix
end

function string_contains(str, sub)
    return str:find(sub, 1, true) ~= nil
end

local function string_ltrim(input)
    local lines = {}

    local split_lines = string.split(input, "\n")
    for i, line in ipairs(split_lines) do
        if i == #split_lines and line == "" then
        else
            if i == 1 then
                line = string.gsub(line, "^%s%s%s%s", "")
                table.insert(lines, line)
            else
                -- 其他行增加4个空格
                table.insert(lines, "    " .. line)
            end
        end
    end

    local result = table.concat(lines, "\n")
    return result
end

local function need_export_to_ref(typename)
    if starts_with(typename, "std::") and (string_contains(typename, "vector") or string_contains(typename, "map")) then
        return true
    end
    return starts_with(typename, "mugen::")
end

---@param module idl.gen.module_desc
---@param cls idl.gen.class_desc
---@param write idl.gen.writer
local function gen_class_open(module, cls, write, register_class_arr)
    local typename = cls.cxxcls:match("::([%w_]+)$")

    -- if typename == "JobType" then
    --     print("xxxxxxxxxx", olua.is_enum_type(cls))
    --     print(inspect(cls, {newline='\n', indent="    "}))
    --     error("xx")
    -- end
    if olua.is_enum_type(cls) then
        local headers = ""
        if not has_packable_or_fromtable_class(module) then
            headers = module.headers
        end

        local lines = {}
        for _, v in pairs(cls.enums) do
            table.insert(lines, olua.format([["${v.name}", ${v.value}]]))
        end
        for k, v in pairs(lines) do
            lines[k] = "        " .. v
        end
        local code = table.concat(lines, ",\n")

        write(olua.format([[
#include "../tolua_common.h"
${headers}

NS_MG_BEGIN

void register_${cls.luacls#}_tolua(sol::table& lua)
{
    // clang-format off
    lua.new_enum("${typename}",
${code}
    );
    // clang-format on
}

NS_MG_END
        ]]))

        table.insert(register_class_arr, olua.format([[${cls.luacls#}]]))
        return
    end


    local lines = {}
    if type(cls.options.custom_sol_constructor) == "table" then
        for k, v in pairs(cls.options.custom_sol_constructor) do
            lines[#lines + 1] = string_ltrim(v)
        end
    else
        lines[#lines + 1] = olua.format([["${typename}", sol::no_constructor]])
    end

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

            if cls.options.is_not_extend_object then
                lines[#lines + 1] = olua.format([["${func.cxxfn}", &${cls.cxxcls}::${func.cxxfn}]])
            else
                lines[#lines + 1] = olua.format([[LUA_METHOD_${args_num}(${cls.cxxcls}, ${func.cxxfn}${params})]])
            end
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
    
        if ret_type == nil then
            local str = vi.get.funcdesc
            local last_space = str:find("[^%s]*$") - 1  -- 找到最后一个空格的索引
            if last_space > 0 then
                local result = str:sub(1, last_space - 1)
                if result ~= "" then
                    ret_type = result
                end
            end
        end

        if ret_type == nil or cls.options.is_not_extend_object then
            lines[#lines + 1] = olua.format([["${var_name}", &${cls.cxxcls}::${var_name}]])
        else
            if not starts_with(ret_type, "@") then
                if need_export_to_ref(ret_type) then
                    lines[#lines + 1] = olua.format([[LUA_PROPERTY_GET_REF(${cls.cxxcls}, ${var_name}, ${ret_type})]])
                else
                    lines[#lines + 1] = olua.format([[LUA_PROPERTY_GET_SET(${cls.cxxcls}, ${var_name}, ${ret_type})]])
                end
            end
        end
    end

    if type(cls.options.custom_sol_function) == "table" then
        for k, v in pairs(cls.options.custom_sol_function) do
            lines[#lines + 1] = string_ltrim(v)
        end
    end


    for k, v in pairs(lines) do
        lines[k] = "        " .. v
    end
    local code = table.concat(lines, ",\n")


    local headers = ""
    if not has_packable_or_fromtable_class(module) then
        headers = module.headers
    end

    local custom_code = ""
    if type(cls.options.custom_code) == "table" then
        -- local custom_code_lines = {}
        -- for k, v in pairs(cls.options.custom_code) do
        --     custom_code_lines[#custom_code_lines + 1] = string_ltrim(v)
        -- end
        -- custom_code = table.concat(custom_code_lines, "\n")
        custom_code = table.concat(cls.options.custom_code, "\n")
    end


    write(olua.format([[
    #include "../tolua_common.h"
    ${headers}
${custom_code}

NS_MG_BEGIN

    void register_${cls.luacls#}_tolua(sol::table& lua)
    {
        // clang-format off
        lua.new_usertype<${cls.cxxcls}>(
${code}
        );
        // clang-format on
    }

NS_MG_END
    ]]))

    table.insert(register_class_arr, olua.format([[${cls.luacls#}]]))
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
        #include "../tolua_common.h"

        NS_MG_BEGIN

        void register_auto_module_${module.name}_tolua(sol::table& lua);
        
        NS_MG_END
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

            local cpp_name = olua.format("${cls.luacls#}_tolua.cpp")
            cpp_name = cpp_name:gsub("(%u)", function(c) return "_" .. c:lower() end):gsub("^_", "")
            cpp_name = cpp_name:gsub("__", "_")

            local path = olua.format("${module.output_dir}/${cpp_name}")
            olua.write(path, tostring(arr))
        end
    end
end

---@param module idl.gen.module_desc
---@param write idl.gen.writer
local function gen_include(module, write)
    write(olua.format([[
        //
        // AUTO GENERATED, DO NOT MODIFY!
        //
        #include "${module.name}_tolua.h"

        NS_MG_BEGIN
    ]]))
    write("")

    if module.codeblock and #module.codeblock > 0 then
        write(olua.format(module.codeblock))
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
    write("")
    write("NS_MG_END")
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