@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title Win11 深度清理工具 v2.0

:: ============================================================
::  Win11 深度清理工具 v2.0
::  永久删除 · 深度清理 · Win10/11 通用 · UTF-8 无 BOM
:: ============================================================

set "APP=Win11 深度清理工具"
set "VER=2.0"
set "WORK=%SystemDrive%\Windows\Temp\W11Clean"
set "ALLR=%WORK%\all_rules.tsv"
set "RES=%WORK%\result.tsv"
set "DELIN=%WORK%\del_in.txt"
set "DELOUT=%WORK%\del_out.txt"
set "TOOL=%WORK%\tool.ps1"
set "LOG=%WORK%\cleaner.log"

:: ---------- 提权 ----------
net session >nul 2>&1
if errorlevel 1 (
    echo   正在请求管理员权限...
    powershell -NoProfile -Command "Start-Process cmd.exe -ArgumentList '/c','\"%~f0\"' -Verb RunAs" >nul 2>&1
    exit /b
)

if not exist "%WORK%" md "%WORK%" >nul 2>&1

call :GenTool
call :BuildRules

:: ============================================================
::  主菜单
:: ============================================================
:menu
cls
call :Header
echo.
echo   [1]  扫描预览（只读，不删除）
echo   [2]  AppData 深度清理（浏览器 / 开发工具 / 显卡缓存）
echo   [3]  系统更新缓存深度清理（SoftwareDistribution / 传递优化）
echo   [4]  系统临时文件、日志与转储
echo   [5]  所有用户 Temp 深度清理
echo   [6]  清空回收站
echo   [7]  WinSxS 组件存储清理（DISM）
echo   [8]  Windows.old 检测与删除
echo   [9]  一键全部深度清理
echo   [0]  退出
echo.
set "C="
set /p "C=  请选择: "

if "!C!"=="1" (set "CATS=all" & set "MODE=scan" & set "SVC=" & goto :flow)
if "!C!"=="2" (set "CATS=user browser dev gpu" & set "MODE=del" & set "SVC=" & goto :flow)
if "!C!"=="3" (set "CATS=update" & set "MODE=del" & set "SVC=1" & goto :flow)
if "!C!"=="4" (set "CATS=system" & set "MODE=del" & set "SVC=" & goto :flow)
if "!C!"=="5" goto :alltemp
if "!C!"=="6" goto :recycle
if "!C!"=="7" goto :dism
if "!C!"=="8" goto :winold
if "!C!"=="9" (set "CATS=all" & set "MODE=del" & set "SVC=1" & goto :flow)
if "!C!"=="0" goto :quit
goto :menu

:: ============================================================
::  清理流程
:: ============================================================
:flow
cls
call :Header
echo.
echo   正在扫描，请稍候...
echo.
call :DoScan "%CATS%"
if errorlevel 1 (
    echo   扫描失败。
    pause
    goto :menu
)
call :ShowResults

if "!MODE!"=="scan" (
    echo.
    echo   ────────────────────────────────────────────
    echo   合计可释放: !TOTAL_FMT!
    echo   ────────────────────────────────────────────
    pause
    goto :menu
)

if "!ITEM_N!"=="0" (
    echo   没有可清理的项目。
    pause
    goto :menu
)

echo.
echo   ────────────────────────────────────────────
echo   合计可释放: !TOTAL_FMT!
echo   删除方式  : 永久删除（不可恢复）
echo   ────────────────────────────────────────────
echo.
set "CFM="
set /p "CFM=  确认执行永久删除？[Y/N]: "
if /i not "!CFM!"=="Y" goto :menu

if "!SVC!"=="1" call :StopServices

call :BuildDelList
if not exist "%DELIN%" (
    echo   无有效删除项。
    if "!SVC!"=="1" call :StartServices
    pause
    goto :menu
)

echo.
echo   正在永久删除...
call :DoDelete

if "!SVC!"=="1" call :StartServices

set "PREV_FMT=!TOTAL_FMT!"
echo.
echo   正在复核...
call :DoScan "%CATS%" >nul 2>&1

echo.
echo   ════════════════════════════════════════════
echo    清理完成
echo   ────────────────────────────────────────────
echo    成功: !OK_N!    失败: !FAIL_N!
echo    清理前: !PREV_FMT!
echo    清理后: !TOTAL_FMT!
echo   ════════════════════════════════════════════
if not "!FAIL_N!"=="0" (
    echo.
    echo   提示: 有 !FAIL_N! 个项目被占用或仅部分清理，重启后可释放更多。
)
echo.
call :Log "清理: 成功 !OK_N! / 失败 !FAIL_N! / 前 !PREV_FMT! / 后 !TOTAL_FMT!"
pause
goto :menu

:: ============================================================
::  所有用户 Temp
:: ============================================================
:alltemp
cls
call :Header
echo.
echo   [所有用户 Temp 深度清理]
echo.
echo   将清理 C:\Users\*\AppData\Local\Temp 和 C:\Windows\Temp
echo.
set "CFM="
set /p "CFM=  确认执行？[Y/N]: "
if /i not "!CFM!"=="Y" goto :menu
echo.
echo   正在清理...
for /d %%u in ("%SystemDrive%\Users\*") do (
    if exist "%%u\AppData\Local\Temp" (
        echo   - %%u\AppData\Local\Temp
        powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%%u\AppData\Local\Temp' -Force -EA 0 | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -EA 0 }" >nul 2>&1
    )
)
if exist "%SystemRoot%\Temp" (
    echo   - %SystemRoot%\Temp
    powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%SystemRoot%\Temp' -Force -EA 0 | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force -EA 0 }" >nul 2>&1
)
echo.
echo   完成。
pause
goto :menu

:: ============================================================
::  清空回收站
:: ============================================================
:recycle
cls
call :Header
echo.
echo   [清空回收站]
echo.
set "CFM="
set /p "CFM=  确认清空所有用户的回收站？[Y/N]: "
if /i not "!CFM!"=="Y" goto :menu
echo.
echo   正在清空...
powershell -NoProfile -Command "Clear-RecycleBin -Force -EA 0" >nul 2>&1
echo   完成。
pause
goto :menu

:: ============================================================
::  DISM
:: ============================================================
:dism
cls
call :Header
echo.
echo   [WinSxS 组件存储清理]
echo.
echo   [1] 常规清理（StartComponentCleanup）
echo   [2] 深度清理（StartComponentCleanup /ResetBase）
echo       ^(之后无法卸载已安装的更新^)
echo   [0] 返回
echo.
set "C="
set /p "C=  选择: "
if "!C!"=="1" (
    echo.
    echo   正在执行 DISM 常规清理，可能需要数分钟...
    dism /Online /Cleanup-Image /StartComponentCleanup
    pause
    goto :menu
)
if "!C!"=="2" (
    echo.
    set "CFM="
    set /p "CFM=  确认 /ResetBase？[Y/N]: "
    if /i "!CFM!"=="Y" (
        echo.
        echo   正在执行 DISM 深度清理，可能需要 10 分钟以上...
        dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase
        pause
    )
    goto :menu
)
goto :menu

:: ============================================================
::  Windows.old
:: ============================================================
:winold
cls
call :Header
echo.
if not exist "%SystemDrive%\Windows.old" (
    echo   未检测到 Windows.old。
    pause
    goto :menu
)
echo   检测到 %SystemDrive%\Windows.old
echo.
echo   [1] 用资源管理器打开
echo   [2] 强制删除（不可回退）
echo   [0] 返回
echo.
set "C="
set /p "C=  选择: "
if "!C!"=="1" (start "" "%SystemDrive%\Windows.old" & goto :menu)
if "!C!"=="2" (
    echo.
    echo   !! 警告: 删除后无法回退到上一个 Windows 版本 !!
    set "CFM="
    set /p "CFM=  输入 YES 确认: "
    if /i "!CFM!"=="YES" (
        echo.
        echo   正在接管所有权...
        takeown /F "%SystemDrive%\Windows.old" /R /A /D Y >nul 2>&1
        icacls "%SystemDrive%\Windows.old" /grant *S-1-5-32-544:F /T /C /Q >nul 2>&1
        echo   正在删除...
        rd /s /q "%SystemDrive%\Windows.old" >nul 2>&1
        if exist "%SystemDrive%\Windows.old" (
            echo   部分内容未能删除，建议重启后再试。
        ) else (
            echo   已删除。
        )
        pause
    )
)
goto :menu

:: ============================================================
::  退出
:: ============================================================
:quit
endlocal
exit /b 0


:: ############################################################
:: #  内部子程序
:: ############################################################

:: ---------- 表头 ----------
:Header
set "DISK=不可用"
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "$d=Get-PSDrive C -EA 0; if($d){'{0:N1} GB 可用 / {1:N1} GB 总计' -f ($d.Free/1GB),(($d.Used+$d.Free)/1GB)}" 2^>nul`) do set "DISK=%%a"
echo   ════════════════════════════════════════════
echo     %APP%  v%VER%
echo     C 盘: %DISK%
echo   ════════════════════════════════════════════
exit /b 0

:: ---------- 日志 ----------
:Log
>>"%LOG%" echo [%DATE% %TIME%] %~1
exit /b 0

:: ---------- 添加规则 ----------
:AddRule
>>"%ALLR%" echo %~1^|%~2^|%~3
exit /b 0

:: ---------- 扫描 ----------
:DoScan
type nul > "%RES%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOL%" scan "%ALLR%" "%RES%" "%~1" >nul 2>&1
if not exist "%RES%" exit /b 1
for %%f in ("%RES%") do if %%~zf LSS 10 exit /b 1
call :ParseResults
exit /b 0

:ParseResults
set "ITEM_N=0"
set "TOTAL_FMT=0 B"
set "TOTAL_BYTES=0"
if not exist "%RES%" exit /b 1
for /f "usebackq tokens=1-6 delims=|" %%a in ("%RES%") do (
    if /i "%%a"=="TOTAL" (
        set "TOTAL_FMT=%%d"
        set "TOTAL_BYTES=%%e"
    ) else (
        set /a ITEM_N+=1
        set "R!ITEM_N!.CAT=%%a"
        set "R!ITEM_N!.NAME=%%b"
        set "R!ITEM_N!.PATH=%%c"
        set "R!ITEM_N!.SIZE=%%d"
        set "R!ITEM_N!.BYTES=%%e"
        set "R!ITEM_N!.STAT=%%f"
    )
)
exit /b 0

:: ---------- 显示 ----------
:ShowResults
echo.
echo   ────────────────────────────────────────────
echo   扫描结果
echo   ────────────────────────────────────────────
if "!ITEM_N!"=="0" (
    echo   未发现可清理项目。
    exit /b 0
)
for /l %%i in (1,1,!ITEM_N!) do (
    if /i "!R%%i.STAT!"=="OK" (
        echo   [!R%%i.SIZE!]  !R%%i.NAME!
        echo             !R%%i.PATH!
    )
)
exit /b 0

:: ---------- 构建待删清单 ----------
:BuildDelList
type nul > "%DELIN%"
for /l %%i in (1,1,!ITEM_N!) do (
    if /i "!R%%i.STAT!"=="OK" >>"%DELIN%" echo(!R%%i.PATH!
)
exit /b 0

:: ---------- 执行删除 ----------
:DoDelete
type nul > "%DELOUT%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOL%" delete "%DELIN%" "%DELOUT%" >nul 2>&1
set "OK_N=0"
set "FAIL_N=0"
if not exist "%DELOUT%" exit /b 1
for /f "usebackq tokens=1,2 delims=|" %%a in ("%DELOUT%") do (
    if /i "%%b"=="OK" set /a OK_N+=1
    if /i "%%b"=="PART" set /a FAIL_N+=1
    if /i "%%b"=="FAIL" set /a FAIL_N+=1
)
exit /b 0

:: ---------- 服务 ----------
:StopServices
echo   正在停止相关服务...
call :StopSvc wuauserv
call :StopSvc bits
call :StopSvc dosvc
call :StopSvc UsoSvc
echo   等待 3 秒让文件句柄释放...
timeout /t 3 /nobreak >nul
exit /b 0

:StopSvc
sc query %~1 >nul 2>&1 || exit /b 0
net stop %~1 >nul 2>&1
if errorlevel 1 (echo     - %~1 未运行或无法停止) else (echo     - %~1 已停止)
exit /b 0

:StartServices
echo   正在重新启动服务...
call :StartSvc wuauserv
call :StartSvc bits
call :StartSvc dosvc
call :StartSvc UsoSvc
exit /b 0

:StartSvc
sc query %~1 >nul 2>&1 || exit /b 0
net start %~1 >nul 2>&1
if errorlevel 1 (echo     - %~1 启动失败) else (echo     - %~1 已启动)
exit /b 0

:: ============================================================
::  规则定义（仅启动时执行一次）
::  格式: 分类|名称|路径
:: ============================================================
:BuildRules
type nul > "%ALLR%"

:: ---------- 用户 AppData ----------
call :AddRule user "用户临时文件"       "%LOCALAPPDATA%\Temp"
call :AddRule user "崩溃转储"           "%LOCALAPPDATA%\CrashDumps"
call :AddRule user "用户错误报告"       "%LOCALAPPDATA%\Microsoft\Windows\WER"
call :AddRule user "INetCache"          "%LOCALAPPDATA%\Microsoft\Windows\INetCache"
call :AddRule user "INetCookies"        "%LOCALAPPDATA%\Microsoft\Windows\INetCookies"
call :AddRule user "图标缓存"           "%LOCALAPPDATA%\IconCache"
call :AddRule user "缩略图缓存"         "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db"
call :AddRule user "终端服务缓存"       "%LOCALAPPDATA%\Microsoft\Terminal Server Client\Cache"
call :AddRule user "通知缓存"           "%LOCALAPPDATA%\Microsoft\Windows\Notifications"
call :AddRule user "UWP 临时状态"       "%LOCALAPPDATA%\Packages\*\TempState"
call :AddRule user "UWP 本地缓存"       "%LOCALAPPDATA%\Packages\*\LocalCache"
call :AddRule user "Windows 搜索缓存"   "%LOCALAPPDATA%\Microsoft\Windows\Explorer\*.db"

:: ---------- 显卡 / 3D 缓存 ----------
call :AddRule gpu "D3D 着色器缓存"      "%LOCALAPPDATA%\D3DSCache"
call :AddRule gpu "NVIDIA DXCache"      "%LOCALAPPDATA%\NVIDIA\DXCache"
call :AddRule gpu "NVIDIA GLCache"      "%LOCALAPPDATA%\NVIDIA\GLCache"
call :AddRule gpu "NVIDIA ComputeCache" "%LOCALAPPDATA%\NVIDIA\ComputeCache"
call :AddRule gpu "NVIDIA NV_Cache"     "%LOCALAPPDATA%\NVIDIA Corporation\NV_Cache"
call :AddRule gpu "AMD DxCache"         "%LOCALAPPDATA%\AMD\DxCache"
call :AddRule gpu "AMD GLCache"         "%LOCALAPPDATA%\AMD\GLCache"
call :AddRule gpu "Intel ShaderCache"   "%LOCALAPPDATA%\Intel\ShaderCache"

:: ---------- Chrome / Chromium 系 ----------
call :AddRule browser "Chrome 缓存"      "%LOCALAPPDATA%\Google\Chrome\User Data\*\Cache"
call :AddRule browser "Chrome 代码缓存"  "%LOCALAPPDATA%\Google\Chrome\User Data\*\Code Cache"
call :AddRule browser "Chrome GPU 缓存"  "%LOCALAPPDATA%\Google\Chrome\User Data\*\GPUCache"
call :AddRule browser "Chrome SW 缓存"   "%LOCALAPPDATA%\Google\Chrome\User Data\*\Service Worker\CacheStorage"
call :AddRule browser "Chrome 着色器"    "%LOCALAPPDATA%\Google\Chrome\User Data\ShaderCache"
call :AddRule browser "Chrome GrShader"  "%LOCALAPPDATA%\Google\Chrome\User Data\GrShaderCache"

call :AddRule browser "Edge 缓存"        "%LOCALAPPDATA%\Microsoft\Edge\User Data\*\Cache"
call :AddRule browser "Edge 代码缓存"    "%LOCALAPPDATA%\Microsoft\Edge\User Data\*\Code Cache"
call :AddRule browser "Edge GPU 缓存"    "%LOCALAPPDATA%\Microsoft\Edge\User Data\*\GPUCache"
call :AddRule browser "Edge SW 缓存"     "%LOCALAPPDATA%\Microsoft\Edge\User Data\*\Service Worker\CacheStorage"
call :AddRule browser "Edge 着色器"      "%LOCALAPPDATA%\Microsoft\Edge\User Data\ShaderCache"
call :AddRule browser "Edge GrShader"    "%LOCALAPPDATA%\Microsoft\Edge\User Data\GrShaderCache"

call :AddRule browser "Brave 缓存"       "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\*\Cache"
call :AddRule browser "Brave 代码缓存"   "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\*\Code Cache"
call :AddRule browser "Brave GPU 缓存"   "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\*\GPUCache"

call :AddRule browser "Vivaldi 缓存"     "%LOCALAPPDATA%\Vivaldi\User Data\*\Cache"
call :AddRule browser "Vivaldi 代码缓存" "%LOCALAPPDATA%\Vivaldi\User Data\*\Code Cache"
call :AddRule browser "Vivaldi GPU 缓存" "%LOCALAPPDATA%\Vivaldi\User Data\*\GPUCache"

call :AddRule browser "Opera 缓存"       "%LOCALAPPDATA%\Opera Software\Opera Stable\Cache"
call :AddRule browser "Opera 代码缓存"   "%LOCALAPPDATA%\Opera Software\Opera Stable\Code Cache"
call :AddRule browser "Opera GPU 缓存"   "%LOCALAPPDATA%\Opera Software\Opera Stable\GPUCache"

call :AddRule browser "Chromium 缓存"    "%LOCALAPPDATA%\Chromium\User Data\*\Cache"

:: ---------- Firefox ----------
call :AddRule browser "Firefox 缓存"     "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\*\cache2"
call :AddRule browser "Firefox 启动缓存" "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\*\startupCache"
call :AddRule browser "Firefox 离线缓存" "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\*\OfflineCache"

:: ---------- 开发工具 ----------
call :AddRule dev "npm 缓存"             "%LOCALAPPDATA%\npm-cache"
call :AddRule dev "npm 缓存 _cacache"    "%LOCALAPPDATA%\npm-cache\_cacache"
call :AddRule dev "pip 缓存"             "%LOCALAPPDATA%\pip\Cache"
call :AddRule dev "Yarn 缓存"            "%LOCALAPPDATA%\Yarn\Cache"
call :AddRule dev "pnpm 存储"            "%LOCALAPPDATA%\pnpm-store"
call :AddRule dev "pnpm 缓存"            "%LOCALAPPDATA%\pnpm-cache"
call :AddRule dev "NuGet HTTP 缓存"      "%LOCALAPPDATA%\NuGet\v3-cache"
call :AddRule dev "NuGet 临时"           "%LOCALAPPDATA%\NuGet\plugins-cache"
call :AddRule dev "NuGet 全局包"         "%USERPROFILE%\.nuget\packages"
call :AddRule dev "Gradle 缓存"          "%USERPROFILE%\.gradle\caches"
call :AddRule dev "Gradle 包装器"        "%USERPROFILE%\.gradle\wrapper\dists"
call :AddRule dev "Maven 仓库"           "%USERPROFILE%\.m2\repository"
call :AddRule dev "Cargo 注册缓存"       "%USERPROFILE%\.cargo\registry\cache"
call :AddRule dev "Cargo 注册源"         "%USERPROFILE%\.cargo\registry\src"
call :AddRule dev "Go 构建缓存"          "%LOCALAPPDATA%\go-build"
call :AddRule dev "Go 模块缓存"          "%USERPROFILE%\go\pkg\mod\cache"
call :AddRule dev "JetBrains 缓存"       "%LOCALAPPDATA%\JetBrains\*\caches"
call :AddRule dev "JetBrains 日志"       "%LOCALAPPDATA%\JetBrains\*\log"
call :AddRule dev "VS Code 网络缓存"     "%APPDATA%\Code\Cache"
call :AddRule dev "VS Code CachedData"   "%APPDATA%\Code\CachedData"
call :AddRule dev "VS Code GPU 缓存"     "%APPDATA%\Code\GPUCache"
call :AddRule dev "VS Code 日志"         "%APPDATA%\Code\logs"
call :AddRule dev "VS Code 备份"         "%APPDATA%\Code\Backups"
call :AddRule dev "Visual Studio 缓存"   "%LOCALAPPDATA%\Microsoft\VisualStudio\*\ComponentModelCache"
call :AddRule dev "Visual Studio 临时"   "%LOCALAPPDATA%\Microsoft\VisualStudio\*\Designer\Cache"

:: ---------- 系统更新缓存 ----------
call :AddRule update "更新下载缓存"       "%SystemRoot%\SoftwareDistribution\Download"
call :AddRule update "更新重启缓存"       "%SystemRoot%\SoftwareDistribution\PostRebootEventCache.V2"
call :AddRule update "更新会话缓存"       "%SystemRoot%\SoftwareDistribution\SelfUpdate"
call :AddRule update "传递优化缓存"       "%SystemRoot%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache"
call :AddRule update "传递优化日志"       "%SystemRoot%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Logs"
call :AddRule update "更新日志"           "%SystemRoot%\Logs\WindowsUpdate"
call :AddRule update "CBS 日志"           "%SystemRoot%\Logs\CBS"
call :AddRule update "DISM 日志"          "%SystemRoot%\Logs\DISM"
call :AddRule update "MoSetup 日志"       "%SystemRoot%\Logs\MoSetup"
call :AddRule update "SIH 日志"           "%SystemRoot%\Logs\SIH"
call :AddRule update "WaaSMedic 日志"     "%SystemRoot%\Logs\waasmedic"
call :AddRule update "WinRE 日志"         "%SystemRoot%\Logs\WinREAgent"
call :AddRule update "Panther 日志"       "%SystemRoot%\Panther"
call :AddRule update "$Windows.~BT"       "%SystemDrive%\$Windows.~BT"
call :AddRule update "$Windows.~WS"       "%SystemDrive%\$Windows.~WS"
call :AddRule update "Installer PatchCache" "%SystemRoot%\Installer\$PatchCache$"

:: ---------- 系统临时 / 日志 ----------
call :AddRule system "系统临时文件"       "%SystemRoot%\Temp"
call :AddRule system "Prefetch"           "%SystemRoot%\Prefetch"
call :AddRule system "系统错误报告"       "%ProgramData%\Microsoft\Windows\WER"
call :AddRule system "WER 归档"           "%ProgramData%\Microsoft\Windows\WER\ReportArchive"
call :AddRule system "WER 队列"           "%ProgramData%\Microsoft\Windows\WER\ReportQueue"
call :AddRule system "ProgramData 缓存"   "%ProgramData%\Microsoft\Windows\Caches"
call :AddRule system "字体缓存"           "%SystemRoot%\ServiceProfiles\LocalService\AppData\Local\FontCache"
call :AddRule system "字体缓存 (Temp)"    "%SystemRoot%\ServiceProfiles\LocalService\AppData\Local\Temp\FontCache"
call :AddRule system "诊断日志"           "%ProgramData%\Microsoft\Diagnosis\ETLLogs"
call :AddRule system "DPM 日志"           "%SystemRoot%\Logs\DPX"
call :AddRule system "下载程序文件"       "%SystemRoot%\Downloaded Program Files"

exit /b 0

:: ============================================================
::  生成 PowerShell 工具脚本
:: ============================================================
:GenTool
type nul > "%TOOL%"
>>"%TOOL%" echo $ErrorActionPreference='SilentlyContinue'
>>"%TOOL%" echo function Get-Size([string]$p){
>>"%TOOL%" echo   try{
>>"%TOOL%" echo     $items=@(Get-Item -Path $p -Force -EA Stop)
>>"%TOOL%" echo     if($items.Count -eq 0){return $null}
>>"%TOOL%" echo     [int64]$t=0
>>"%TOOL%" echo     foreach($i in $items){
>>"%TOOL%" echo       if($i.PSIsContainer){$t+=[int64]((Get-ChildItem -LiteralPath $i.FullName -Recurse -Force -File -EA 0 ^| Measure-Object -Property Length -Sum).Sum)}
>>"%TOOL%" echo       else{$t+=[int64]$i.Length}
>>"%TOOL%" echo     }
>>"%TOOL%" echo     return $t
>>"%TOOL%" echo   }catch{return $null}
>>"%TOOL%" echo }
>>"%TOOL%" echo function Fmt([int64]$b){
>>"%TOOL%" echo   if($b -ge 1073741824){'{0:N2} GB' -f ($b/1073741824)}
>>"%TOOL%" echo   elseif($b -ge 1048576){'{0:N2} MB' -f ($b/1048576)}
>>"%TOOL%" echo   elseif($b -ge 1024){'{0:N2} KB' -f ($b/1024)}
>>"%TOOL%" echo   else{"$b B"}
>>"%TOOL%" echo }
>>"%TOOL%" echo $mode=$args[0];$inF=$args[1];$outF=$args[2]
>>"%TOOL%" echo if($mode -eq 'scan'){
>>"%TOOL%" echo   $cf=if($args.Count -gt 3){$args[3]}else{'all'}
>>"%TOOL%" echo   $useAll=($cf -eq 'all')
>>"%TOOL%" echo   $cats=@($cf -split '\s+')
>>"%TOOL%" echo   $lines=[IO.File]::ReadAllLines($inF,[Text.Encoding]::UTF8)
>>"%TOOL%" echo   $out=New-Object Collections.Generic.List[string]
>>"%TOOL%" echo   [int64]$grand=0
>>"%TOOL%" echo   foreach($line in $lines){
>>"%TOOL%" echo     if(-not $line){continue}
>>"%TOOL%" echo     $p=$line.Split([char]124,3)
>>"%TOOL%" echo     if($p.Length -lt 3){continue}
>>"%TOOL%" echo     if(-not $useAll -and ($cats -notcontains $p[0])){continue}
>>"%TOOL%" echo     $path=[Environment]::ExpandEnvironmentVariables($p[2])
>>"%TOOL%" echo     $size=Get-Size $path
>>"%TOOL%" echo     if($null -eq $size){$out.Add("$($p[0])|$($p[1])|$path|0 B|0|MISS")}
>>"%TOOL%" echo     else{$grand+=$size;$out.Add("$($p[0])|$($p[1])|$path|$(Fmt $size)|$size|OK")}
>>"%TOOL%" echo   }
>>"%TOOL%" echo   $out.Add("TOTAL|TOTAL|#|$(Fmt $grand)|$grand|OK")
>>"%TOOL%" echo   [IO.File]::WriteAllLines($outF,$out,(New-Object Text.UTF8Encoding $false))
>>"%TOOL%" echo }
>>"%TOOL%" echo elseif($mode -eq 'delete'){
>>"%TOOL%" echo   $lines=[IO.File]::ReadAllLines($inF,[Text.Encoding]::UTF8)
>>"%TOOL%" echo   $out=New-Object Collections.Generic.List[string]
>>"%TOOL%" echo   foreach($p in $lines){
>>"%TOOL%" echo     if(-not $p){continue}
>>"%TOOL%" echo     $p=$p.Trim()
>>"%TOOL%" echo     if(-not $p){continue}
>>"%TOOL%" echo     $items=@(Get-Item -Path $p -Force -EA 0)
>>"%TOOL%" echo     if($items.Count -eq 0){$out.Add("$p|MISS");continue}
>>"%TOOL%" echo     foreach($it in $items){
>>"%TOOL%" echo       if($it.PSIsContainer){
>>"%TOOL%" echo         Get-ChildItem -LiteralPath $it.FullName -Force -EA 0 ^| ForEach-Object {Remove-Item -LiteralPath $_.FullName -Recurse -Force -EA 0}
>>"%TOOL%" echo       }else{Remove-Item -LiteralPath $it.FullName -Force -EA 0}
>>"%TOOL%" echo     }
>>"%TOOL%" echo     $left=@(Get-ChildItem -Path $p -Recurse -Force -File -EA 0)
>>"%TOOL%" echo     if($left.Count -gt 0){$out.Add("$p|PART")}else{$out.Add("$p|OK")}
>>"%TOOL%" echo   }
>>"%TOOL%" echo   [IO.File]::WriteAllLines($outF,$out,(New-Object Text.UTF8Encoding $false))
>>"%TOOL%" echo }
exit /b 0
