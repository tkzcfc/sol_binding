# sol_binding

根据客户端 `mugen` 头文件，用 olua/sol 生成 Lua 绑定，输出到 `../3rd/mugen_tolua/auto`。

## 一键入口

```powershell
cd AxmolFighter-Tools
pwsh ./sol_binding/run_sol_binding.ps1
```

等价于在本目录执行：

```powershell
.\lua.exe build.lua
```

## 注意

- 不要手改 `3rd/mugen_tolua/auto/*.cpp`；改绑定配置或头文件后重新跑脚本生成
- 需要本目录自带的 `lua.exe` 与 `build.lua`
