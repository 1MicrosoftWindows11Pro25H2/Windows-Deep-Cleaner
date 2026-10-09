# Win11 深度清理工具

> 一个纯批处理实现的 Windows 10 / 11 深度清理工具  
> 规则驱动 · 风险分级 · 回收站优先 · 三级降级删除 · 单文件绿色运行

---

## 简介

`win11-deep-clean.bat` 是一个单文件批处理脚本，用于深度清理 Windows 10 / 11 的：

- 用户 AppData 缓存（Local 层）
- 浏览器缓存（Chrome / Edge / Firefox）
- 开发工具缓存（npm / pip / Gradle / NuGet / Maven / Cargo 等）
- Windows 更新缓存（SoftwareDistribution / Delivery Optimization）
- 系统临时文件与错误报告
- WinSxS 组件存储（通过 DISM）
- Windows.old 检测与处理

所有删除默认走**回收站**，可恢复；系统级缓存会先优雅停止相关服务，清理完成后自动恢复。

---

## 功能特性

- **规则驱动**：清理规则集中在脚本顶部 `:: 2. 清理规则定义` 区域，按格式追加即可。
- **风险分级**：规则分为 `safe` 和 `caution` 两级。快速清理只处理安全项，深度清理包含谨慎项。
- **回收站优先**：默认使用 `Microsoft.VisualBasic.FileIO.FileSystem` 将文件送入回收站。
- **三级降级删除**：回收站失败 → 尝试永久删除 → 记录失败并提示占用。
- **服务优雅启停**：清理系统更新缓存前自动停止 `wuauserv`、`bits`、`dosvc`，完成后重新启动。
- **扫描预览**：执行清理前可先只读扫描，查看每条路径的大小与风险。
- **报告导出**：支持将扫描结果导出为 txt 报告，包含路径、大小、风险等级。
- **日志记录**：关键操作写入 `%ProgramData%\Win11DeepClean\cleaner.log`。
- **Win10 / Win11 通用**：使用系统自带命令与 PowerShell 5.1，无需第三方依赖。

---

## 系统要求

- Windows 10 1903+ 或 Windows 11
- PowerShell 5.1 或更高版本
- 管理员权限（脚本会自动请求 UAC 提权）
- 批处理文件保存为 **UTF-8 无 BOM** 编码（否则中文可能乱码）

---

## 使用方法

1. 将 `win11-deep-clean.bat` 保存到桌面或任意目录。
2. 确保文件编码为 **UTF-8 无 BOM**。
3. 右键选择 **“以管理员身份运行”**，或直接双击，脚本会自动请求提权。
4. 在主菜单中选择功能：
   - `[1] 扫描预览`：只读分析，不删除。
   - `[2] 快速清理`：仅安全项，走回收站。
   - `[3] 深度清理`：安全项 + 谨慎项。
   - `[4] 系统更新缓存`：专项清理 SoftwareDistribution / 传递优化。
   - `[5] WinSxS 清理`：调用 DISM 组件清理。
   - `[6] Windows.old`：检测与处理旧系统备份。
   - `[7] 导出报告`：导出扫描报告。
   - `[8] 设置`：切换回收站 / 永久删除。
   - `[0] 退出`。

---

## 清理范围说明

### AppData 深度清理（仅 Local 层）

| 规则 | 路径 | 风险 |
|---|---|---|
| 用户临时文件 | `%LOCALAPPDATA%\Temp` | safe |
| 崩溃转储 | `%LOCALAPPDATA%\CrashDumps` | safe |
| Windows 错误报告 | `%LOCALAPPDATA%\Microsoft\Windows\WER` | safe |
| 系统错误报告 | `C:\ProgramData\Microsoft\Windows\WER` | safe |
| Chrome 缓存 | `%LOCALAPPDATA%\Google\Chrome\User Data\*\Cache` 等 | safe |
| Edge 缓存 | `%LOCALAPPDATA%\Microsoft\Edge\User Data\*\Cache` 等 | safe |
| Firefox 缓存 | `%LOCALAPPDATA%\Mozilla\Firefox\Profiles\*\cache2` | safe |
| npm 缓存 | `%LOCALAPPDATA%\npm-cache` | safe |
| pip 缓存 | `%LOCALAPPDATA%\pip\Cache` | safe |
| Yarn 缓存 | `%LOCALAPPDATA%\Yarn\Cache` | safe |
| NuGet 缓存 | `%LOCALAPPDATA%\NuGet\v3-cache` | safe |
| NuGet 包目录 | `%USERPROFILE%\.nuget\packages` | safe |
| Gradle 缓存 | `%USERPROFILE%\.gradle\caches` | safe |
| Maven 仓库 | `%USERPROFILE%\.m2\repository` | safe |
| Cargo 缓存 | `%USERPROFILE%\.cargo\registry\cache` | safe |
| VS Code 缓存 | `%APPDATA%\Code\Cache` 等 | safe |

### 系统更新与安装缓存

| 规则 | 路径 | 风险 |
|---|---|---|
| 系统临时文件 | `C:\Windows\Temp` | caution |
| 更新下载缓存 | `C:\Windows\SoftwareDistribution\Download` | caution |
| 传递优化缓存 | `C:\Windows\ServiceProfiles\NetworkService\...\DeliveryOptimization\Cache` | caution |
| 更新日志 | `C:\Windows\Logs\WindowsUpdate` | caution |
| WinSxS | 通过 `DISM /Online /Cleanup-Image /StartComponentCleanup` | caution |
| Windows.old | `C:\Windows.old` | 仅检测，手动处理 |

---

## 风险等级说明

- **safe**：删除后不影响软件正常使用，缓存会自动重建。
- **caution**：涉及系统级缓存或需要停止服务，删除前请确认。
- **dangerous**：本工具不主动提供，Windows.old 删除需用户二次确认。

---

## 报告与日志

- 扫描报告导出到脚本同目录 `reports\clean-report-YYYYMMDD_HHMMSS.txt`。
- 运行日志位于 `%ProgramData%\Win11DeepClean\cleaner.log`。
- 临时文件位于 `%ProgramData%\Win11DeepClean\`。

---

## 常见问题

**Q：中文显示乱码？**  
A：请将批处理文件保存为 **UTF-8 无 BOM** 编码，并确保系统已安装中文语言包。

**Q：提示“部分文件无法删除”？**  
A：被占用的文件会在程序关闭或系统重启后释放。可重启后再次运行，或手动处理。

**Q：回收站被占满？**  
A：大量文件送入回收站会占用空间。可在“设置”中切换为永久删除，或定期清空回收站。

**Q：提权后清理的是哪个用户的 AppData？**  
A：如果当前用户是管理员，UAC 提权后环境变量不变，清理当前用户。  
如果使用其他管理员账户提权，将清理该管理员账户的 AppData。建议直接以当前用户的管理员权限运行。

**Q：Win10 能用吗？**  
A：可以。脚本使用的命令与路径在 Win10 1903+ 和 Win11 中均存在。

---

## 免责声明

本工具会删除文件，虽然默认走回收站，但仍存在数据丢失风险。  
首次使用建议先执行“扫描预览”，确认无误后再清理。  
作者不对因使用本工具造成的任何数据丢失或系统问题负责。

---

## 许可

MIT License
