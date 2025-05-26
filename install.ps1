# --- PowerShell 脚本设置 ---
# $ErrorActionPreference = "Stop"：当命令遇到非终止错误时，立即停止脚本执行。
# $ProgressPreference = "SilentlyContinue"：抑制 Invoke-WebRequest 等 Cmdlet 的进度条显示。
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# --- 颜色定义 (适用于 PowerShell) ---
# 这些函数使用 Write-Host Cmdlet 和 -ForegroundColor 参数来输出带颜色的文本。
# 注意：这些颜色在现代的 Windows Terminal 和 PowerShell 7+ 中支持良好，但在旧版控制台中可能显示不正确。
Function Write-Host-Green { param([string]$Message) Write-Host -ForegroundColor Green $Message }
Function Write-Host-Blue { param([string]$Message) Write-Host -ForegroundColor Blue $Message }
Function Write-Host-Yellow { param([string]$Message) Write-Host -ForegroundColor Yellow $Message }
Function Write-Host-Red { param([string]$Message) Write-Host -ForegroundColor Red $Message }
Function Write-Host-Purple { param([string]$Message) Write-Host -ForegroundColor DarkMagenta $Message } # PowerShell 中的紫色通常是 DarkMagenta
Function Write-Host-Cyan { param([string]$Message) Write-Host -ForegroundColor Cyan $Message }

# --- 配置部分 ---
$LADEFREE_REPO_URL_BASE = "https://github.com/bankenhack/ladefrees" # Ladefree 应用的 GitHub 仓库基础URL
$LADEFREE_REPO_BRANCH = "main" # Ladefree 仓库的分支
$LADE_CLI_NAME = "lade.exe" # Lade CLI 可执行文件名 (Windows 上通常是 .exe)
# $env:ProgramFiles 是 Windows 上的标准程序文件目录，例如 C:\Program Files
$LADE_INSTALL_PATH = "$env:ProgramFiles\LadeCLI" # Lade CLI 的标准安装路径

# --- 作者信息 ---
# 作者：Joey
# 博客：joeyblog.net
# Telegram 群：https://t.me/+ft-zI76oovgwNmRh

# --- 辅助函数：显示欢迎信息 ---
Function Display-Welcome {
    Clear-Host # 清除控制台屏幕
    Write-Host-Cyan "#############################################################"
    Write-Host-Cyan "#                                                           #"
    Write-Host-Cyan "#        " -NoNewline; Write-Host-Blue "欢迎使用 Lade CLI 多功能管理脚本 v1.0.0" -NoNewline; Write-Host-Cyan "        #"
    Write-Host-Cyan "#                                                           #"
    Write-Host-Cyan "#############################################################"
    Write-Host-Green ""
    Write-Host "  >> 作者: Joey"
    Write-Host "  >> 博客: joeyblog.net"
    Write-Host "  >> Telegram 群: https://t.me/+ft-zI76oovgwNmRh"
    Write-Host "  >> 部署的代码note.js来自 https://github.com/eooce 老王 "
    Write-Host ""
    Write-Host-Yellow "这是一个自动化 Lade 应用部署和管理工具，旨在简化操作。"
    Write-Host ""
    Read-Host "按 Enter 键开始..." | Out-Null # 等待用户按 Enter 键，并丢弃输入
}

# --- 辅助函数：显示功能区标题 ---
Function Display-SectionHeader {
    param([string]$Title) # 接受一个字符串参数作为标题
    Write-Host ""
    Write-Host-Purple "--- $Title ---"
    Write-Host-Purple "-----------------------------------"
}

# --- 辅助函数：检查命令是否存在 ---
Function Test-CommandExists {
    param([string]$Command) # 接受一个字符串参数作为命令名
    # Get-Command 尝试查找指定的命令。-ErrorAction SilentlyContinue 抑制错误信息。
    # 如果找到命令，它将返回一个对象，否则返回 $null。
    (Get-Command -Name $Command -ErrorAction SilentlyContinue) -ne $null
}

# --- 辅助函数：检查 Lade CLI 是否存在且可用 ---
Function Test-LadeCli {
    Test-CommandExists $LADE_CLI_NAME # 调用 Test-CommandExists 检查 Lade CLI
}

# --- 辅助函数：确保已登录 Lade ---
Function Ensure-LadeLogin {
    Write-Host ""
    Write-Host-Purple "--- 检查 Lade 登录状态 ---"
    # 尝试执行一个需要认证的 Lade 命令（例如 `lade apps list`）。
    # 如果该命令失败（抛出错误），则表示未登录或会话过期。
    try {
        # 使用 & 运算符执行外部可执行文件。Out-Null 丢弃命令的标准输出。
        & lade apps list 
        Write-Host-Green "Lade 已登录。"
    } catch {
        Write-Host-Yellow "Lade 登录会话已过期或未登录。请根据提示输入您的 Lade 登录凭据。"
        try {
            & lade login # 提示用户进行登录
            Write-Host-Green "Lade 登录成功！"
        } catch {
            Write-Host-Red "错误：Lade 登录失败。请检查用户名/密码或网络连接。"
            exit 1 # 登录失败，退出脚本
        }
    }
}

# --- 功能函数：部署应用 ---
Function Deploy-App {
    Display-SectionHeader "部署 Lade 应用"

    Ensure-LadeLogin # 确保用户已登录

    $LADE_APP_NAME = Read-Host "请输入您要部署的 Lade 应用名称 (例如: my-ladefree-app):"
    # [string]::IsNullOrWhiteSpace 检查字符串是否为 null、空或仅包含空白字符
    if ([string]::IsNullOrWhiteSpace($LADE_APP_NAME)) {
        Write-Host-Yellow "应用名称不能为空。取消部署。"
        return # 返回函数，不继续执行部署
    }

    Write-Host "正在检查应用 '$LADE_APP_NAME' 是否存在..."
    $app_exists = $false
    try {
        $appList = & lade apps list # 获取应用列表
        # -like 运算符用于通配符匹配。检查列表中是否包含应用名称。
        if ($appList -like "*$LADE_APP_NAME*") {
            $app_exists = $true
        }
    } catch {
        # 如果获取应用列表失败，可能是网络问题或 Lade CLI 问题，但我们仍尝试继续。
        Write-Host-Yellow "无法获取应用列表以验证其是否存在，假定不存在或继续创建/部署。"
    }

    if ($app_exists) {
        Write-Host-Green "应用 '$LADE_APP_NAME' 已存在，将直接部署更新。"
    } else {
        Write-Host-Yellow "应用 '$LADE_APP_NAME' 不存在，将尝试创建新应用。"
        Write-Host-Cyan "注意：创建应用将交互式询问 'Plan' 和 'Region'，请手动选择。"
        try {
            & lade apps create "$LADE_APP_NAME" # 尝试创建应用
            Write-Host-Green "Lade 应用创建命令已发送。"
        } catch {
            Write-Host-Red "错误：Lade 应用创建失败。请检查输入或应用名称是否可用。"
            return # 创建失败，返回函数
        }
    }

    Write-Host ""
    Write-Host-Blue "--- 正在下载 ZIP 并部署 Ladefree 应用 (不依赖 Git) ---"
    # Join-Path Cmdlet 安全地拼接路径，处理不同的路径分隔符。
    $ladefree_temp_download_dir = Join-Path $env:TEMP "ladefree_repo_download_$(Get-Random)"
    # New-Item -ItemType Directory -Force 创建目录，如果存在则不报错。Out-Null 抑制输出。
    New-Item -ItemType Directory -Force -Path $ladefree_temp_download_dir | Out-Null

    $ladefree_download_url = "$LADEFREE_REPO_URL_BASE/archive/refs/heads/$LADEFREE_REPO_BRANCH.zip"
    $temp_ladefree_archive = Join-Path $ladefree_temp_download_dir "ladefree.zip"

    Write-Host "正在下载 $LADEFREE_REPO_URL_BASE ($LADEFREE_REPO_BRANCH 分支) 为 ZIP 包..."
    Write-Host "下载 URL: $ladefree_download_url"

    try {
        # Invoke-WebRequest 是 PowerShell 下载文件和网页内容的主要 Cmdlet。
        Invoke-WebRequest -Uri $ladefree_download_url -OutFile $temp_ladefree_archive
    } catch {
        Write-Host-Red "错误：下载 Ladefree 仓库 ZIP 包失败。请检查 URL 或网络连接。"
        # Remove-Item -Recurse -Force 强制删除目录及其内容，-ErrorAction SilentlyContinue 抑制删除错误。
        Remove-Item -Path $ladefree_temp_download_dir -Recurse -Force -ErrorAction SilentlyContinue
        return # 下载失败，返回函数
    }

    Write-Host "下载完成，正在解压..."
    try {
        # Expand-Archive 是 PowerShell 解压 ZIP 文件的 Cmdlet。
        Expand-Archive -Path $temp_ladefree_archive -DestinationPath $ladefree_temp_download_dir -Force
    } catch {
        Write-Host-Red "错误：解压 Ladefree ZIP 包失败。请确保 'Expand-Archive' 功能可用（PowerShell 5.0+ 内置）。"
        Remove-Item -Path $ladefree_temp_download_dir -Recurse -Force -ErrorAction SilentlyContinue
        return # 解压失败，返回函数
    }

    # 查找解压后的应用程序目录 (例如，ladefree-main)。
    # Get-ChildItem -Directory 仅获取目录，-Filter "ladefree-*" 按名称过滤。
    # Select-Object -ExpandProperty FullName 仅选择完整路径。
    # Select-Object -First 1 确保只取第一个匹配项。
    $extracted_app_path = Get-ChildItem -Path $ladefree_temp_download_dir -Directory -Filter "ladefree-*" | Select-Object -ExpandProperty FullName | Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace($extracted_app_path)) {
        Write-Host-Red "错误：未在临时下载目录中找到解压后的 Ladefree 应用程序目录。"
        Remove-Item -Path $ladefree_temp_download_dir -Recurse -Force -ErrorAction SilentlyContinue
        return # 未找到目录，返回函数
    }

    Write-Host-Blue "正在从本地解压路径 $extracted_app_path 部署到 Lade：$LADE_APP_NAME ..."
    Push-Location $extracted_app_path # 更改当前工作目录到解压路径
    try {
        & lade deploy --app "$LADE_APP_NAME" # 执行部署命令
        $deploy_status = $LASTEXITCODE # 获取外部命令的退出代码
    } catch {
        Write-Host-Red "错误：Lade 应用部署失败。请检查 Ladefree 代码本身的问题或 Lade 平台日志。"
        Pop-Location # 恢复到之前的目录
        Remove-Item -Path $ladefree_temp_download_dir -Recurse -Force -ErrorAction SilentlyContinue
        return # 部署失败，返回函数
    }
    Pop-Location # 恢复到之前的目录

    Write-Host "清理临时下载目录 $ladefree_temp_download_dir..."
    Remove-Item -Path $ladefree_temp_download_dir -Recurse -Force -ErrorAction SilentlyContinue

    if ($deploy_status -ne 0) {
        Write-Host-Red "错误：Lade 应用部署失败。请检查 Ladefree 代码问题或 Lade 平台日志。"
        return # 部署失败，返回函数
    }
    Write-Host-Green "Lade 应用部署成功！"

    Write-Host ""
    Write-Host-Cyan "--- 部署完成 ---"
}

# --- 功能函数：查看所有应用 ---
Function View-Apps {
    Display-SectionHeader "查看所有 Lade 应用"

    Ensure-LadeLogin # 确保用户已登录

    try {
        & lade apps list # 执行查看应用列表命令
    } catch {
        Write-Host-Red "错误：无法获取应用列表。请检查网络或 Lade CLI 状态。"
    }
}

# --- 功能函数：删除应用 ---
Function Delete-App {
    Display-SectionHeader "删除 Lade 应用"

    Ensure-LadeLogin # 确保用户已登录

    $APP_TO_DELETE = Read-Host "请输入您要删除的 Lade 应用名称:"
    if ([string]::IsNullOrWhiteSpace($APP_TO_DELETE)) {
        Write-Host-Yellow "应用名称不能为空。取消删除。"
        return
    }

    Write-Host-Red "警告：您即将删除应用 '$APP_TO_DELETE'。此操作不可撤销！"
    $CONFIRM_DELETE = Read-Host "确定要删除吗？ (y/N):"
    $CONFIRM_DELETE = $CONFIRM_DELETE.ToLower() # 将输入转换为小写

    if ($CONFIRM_DELETE -eq "y") {
        try {
            & lade apps remove "$APP_TO_DELETE" # 将 'delete' 更改为 'remove'
            Write-Host-Green "应用 '$APP_TO_DELETE' 已成功删除。"
        } catch {
            Write-Host-Red "错误：删除应用 '$APP_TO_DELETE' 失败。请检查应用名称是否正确或您是否有权限。"
        }
    } else {
        Write-Host-Yellow "取消删除操作。"
    }
}

# --- 功能函数：查看应用日志 ---
Function View-AppLogs {
    Display-SectionHeader "查看 Lade 应用日志"

    Ensure-LadeLogin # 确保用户已登录

    $APP_FOR_LOGS = Read-Host "请输入您要查看日志的 Lade 应用名称:"
    if ([string]::IsNullOrWhiteSpace($APP_FOR_LOGS)) {
        Write-Host-Yellow "应用名称不能为空。取消查看日志。"
        return
    }

    Write-Host-Cyan "正在查看应用 '$APP_FOR_LOGS' 的实时日志 (按 Ctrl+C 停止)..."
    try {
        # lade logs 的 -f 标志通常表示“跟随”日志输出
        & lade logs -a "$APP_FOR_LOGS" -f
    } catch {
        Write-Host-Red "错误：无法获取应用 '$APP_FOR_LOGS' 的日志。请检查应用名称是否正确或应用是否正在运行。"
    }
}

# --- 初始化步骤 (确保 Lade CLI 已安装) ---
Function Install-LadeCli {
    Display-SectionHeader "检查或安装 Lade CLI"

    if (Test-LadeCli) {
        Write-Host-Green "Lade CLI 已安装：$(Get-Command $LADE_CLI_NAME).Path"
        return $true # Lade CLI 已经存在，返回 true
    }

    Write-Host-Yellow "Lade CLI 未安装。正在尝试自动安装 Lade CLI..."

    $lade_release_url = "https://github.com/lade-io/lade/releases"
    $lade_temp_dir = Join-Path $env:TEMP "lade_cli_download_temp_$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $lade_temp_dir | Out-Null

    $os_type = "windows" # 在 Windows 上硬编码为 "windows"
    # Get-WmiObject Win32_Processor 获取处理器信息，Architecture 属性表示架构类型。
    $arch_type = (Get-WmiObject Win32_Processor).Architecture

    $arch_suffix = ""
    # 根据处理器架构设置下载文件名后缀
    switch ($arch_type) {
        0 { $arch_suffix = "-amd64" } # x86 架构
        9 { $arch_suffix = "-amd64" } # x64 架构
        6 { $arch_suffix = "-arm64" } # ARM64 架构
        default {
            Write-Host-Red "错误：不支持的 Windows 架构：$arch_type"
            Remove-Item -Path $lade_temp_dir -Recurse -Force -ErrorAction SilentlyContinue
            exit 1
        }
    }
    Write-Host-Blue "检测到 Windows ($((Get-WmiObject Win32_Processor).Caption)) 架构。"

    # 检查必要的工具：Invoke-WebRequest (PowerShell 内置) 或 curl.exe (如果用户安装了)
    if (-not (Test-CommandExists "curl.exe") -and -not (Test-CommandExists "Invoke-WebRequest")) {
        Write-Host-Red "错误：未找到 'curl.exe' 或 'Invoke-WebRequest' (PowerShell 的网络客户端)。请确保 PowerShell 已更新或 curl 已安装。"
        Remove-Item -Path $lade_temp_dir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }
    # 检查 Expand-Archive (PowerShell 内置)
    if (-not (Test-CommandExists "Expand-Archive")) {
        Write-Host-Red "错误：未找到 'Expand-Archive' (PowerShell 的解压命令)。请确保 PowerShell 5.0+ 已安装。"
        Remove-Item -Path $lade_temp_dir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    Write-Host "正在获取最新版本的 Lade CLI..."
    try {
        # Invoke-RestMethod 用于调用 RESTful Web 服务，获取 GitHub API 的 JSON 响应。
        $latest_release_info = Invoke-RestMethod -Uri "https://api.github.com/repos/lade-io/lade/releases/latest"
        $latest_release_tag = $latest_release_info.tag_name # 从 JSON 响应中提取 tag_name
    } catch {
        Write-Host-Red "错误：无法获取最新版本的 Lade CLI。请检查网络或 GitHub API 限制。"
        Remove-Item -Path $lade_temp_dir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($latest_release_tag)) {
        Write-Host-Red "错误：无法确定最新 Lade CLI 版本。"
        Remove-Item -Path $lade_temp_dir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }
    $lade_version = $latest_release_tag
    Write-Host-Green "检测到最新版本：$lade_version"

    $filename_to_download = "lade-${os_type}${arch_suffix}.zip" # Lade CLI for Windows 通常是 .zip
    $download_url = "$lade_release_url/download/$lade_version/$filename_to_download"
    $temp_archive = Join-Path $lade_temp_dir $filename_to_download

    Write-Host "下载 URL: $download_url"
    Write-Host "正在下载 $filename_to_download 到 $temp_archive..."
    try {
        Invoke-WebRequest -Uri $download_url -OutFile $temp_archive # 下载文件
    } catch {
        Write-Host-Red "错误：下载 Lade CLI 失败。请检查网络连接或 URL 是否正确。"
        Remove-Item -Path $lade_temp_dir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    Write-Host "下载完成，正在解压..."
    try {
        Expand-Archive -Path $temp_archive -DestinationPath $lade_temp_dir -Force # 解压 ZIP 文件
    } catch {
        Write-Host-Red "错误：解压 ZIP 文件失败。请确保 'Expand-Archive' Cmdlet 可用 (PowerShell 5.0+)。"
        Remove-Item -Path $lade_temp_dir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # 在解压后的目录中查找 Lade CLI 可执行文件。
    # -Recurse 递归搜索子目录，-File 仅查找文件，-Filter 过滤文件名。
    $extracted_lade_path = Get-ChildItem -Path $lade_temp_dir -Recurse -File -Filter $LADE_CLI_NAME | Select-Object -ExpandProperty FullName | Select-Object -First 1

    if ([string]::IsNullOrWhiteSpace($extracted_lade_path)) {
        Write-Host-Red "错误：在解压后的临时目录中未找到 '$LADE_CLI_NAME' 可执行文件。请检查压缩包内容。"
        Remove-Item -Path $lade_temp_dir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # 确保目标安装路径存在
    if (-not (Test-Path $LADE_INSTALL_PATH)) {
        New-Item -ItemType Directory -Force -Path $LADE_INSTALL_PATH | Out-Null
    }

    Write-Host "正在将 Lade CLI 移动到 $LADE_INSTALL_PATH..."
    try {
        # Move-Item 移动文件。-Force 强制覆盖目标（如果存在）。
        Move-Item -Path $extracted_lade_path -Destination (Join-Path $LADE_INSTALL_PATH $LADE_CLI_NAME) -Force
    } catch {
        Write-Host-Red "错误：移动 Lade CLI 文件失败。可能需要管理员权限或目录不存在。"
        Remove-Item -Path $lade_temp_dir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }

    # 将 Lade CLI 添加到系统 PATH 环境变量 (如果尚未添加)
    # 这通常需要管理员权限才能修改机器级别的环境变量。
    try {
        # [Environment]::GetEnvironmentVariable 获取环境变量。
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        # 检查 PATH 中是否已包含安装路径。
        if (-not ($currentPath -split ';' -contains $LADE_INSTALL_PATH)) {
            Write-Host-Yellow "正在将 '$LADE_INSTALL_PATH' 添加到系统 PATH。这需要管理员权限。"
            $newPath = "$currentPath;$LADE_INSTALL_PATH"
            # [Environment]::SetEnvironmentVariable 设置环境变量。
            [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
            Write-Host-Green "Lade CLI 安装路径已添加到系统 PATH。您可能需要重新启动 PowerShell 会话才能使其生效。"
        }
    } catch {
        Write-Host-Yellow "警告：无法将 Lade CLI 路径添加到系统 PATH 环境变量。请手动添加 '$LADE_INSTALL_PATH' 到您的 PATH，以便从任何位置运行 'lade' 命令。"
    }

    Write-Host-Green "Lade CLI 已成功下载、解压并安装到 $LADE_INSTALL_PATH"
    Remove-Item -Path $lade_temp_dir -Recurse -Force -ErrorAction SilentlyContinue
    return $true # Lade CLI 安装成功
}


# --- 主要执行流程 ---

# 显示欢迎页面
Display-Welcome

# 2. 确保 Lade CLI 已安装
# 如果 Install-LadeCli 返回 false (安装失败)，则退出脚本。
if (-not (Install-LadeCli)) {
    Write-Host-Red "错误：Lade CLI 安装失败。脚本将退出。"
    exit 1
}

# --- 主菜单 ---
while ($true) { # 无限循环，直到用户选择退出
    Write-Host ""
    Write-Host-Cyan "#############################################################"
    Write-Host-Cyan "#          " -NoNewline; Write-Host-Blue "Lade 管理主菜单" -NoNewline; Write-Host-Cyan "                          #"
    Write-Host-Cyan "#############################################################"
    Write-Host-Green "1. " -NoNewline; Write-Host "部署 Ladefree 应用"
    Write-Host-Green "2. " -NoNewline; Write-Host "查看所有 Lade 应用"
    Write-Host-Green "3. " -NoNewline; Write-Host "删除 Lade 应用"
    Write-Host-Green "4. " -NoNewline; Write-Host "查看应用日志"
    Write-Host-Green "5. " -NoNewline; Write-Host "刷新 Lade 登录状态"
    Write-Host-Red "6. " -NoNewline; Write-Host "退出"
    Write-Host-Cyan "-------------------------------------------------------------"
    $CHOICE = Read-Host "请选择一个操作 (1-6):"

    switch ($CHOICE) { # 根据用户选择执行相应函数
        "1" { Deploy-App }
        "2" { View-Apps }
        "3" { Delete-App }
        "4" { View-AppLogs }
        "5" { Ensure-LadeLogin }
        "6" { Write-Host-Cyan "退出脚本。再见！"; break } # 退出循环
        default { Write-Host-Red "无效的选择，请输入 1 到 6 之间的数字。" }
    }
    Write-Host ""
    Read-Host "按 Enter 键继续..." | Out-Null # 等待用户按 Enter 键继续
}

Write-Host-Blue "脚本执行完毕。"
