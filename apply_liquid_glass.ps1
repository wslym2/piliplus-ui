# Windows PowerShell 一键适配脚本
Write-Host "正在为 PiliPlus 应用 iOS 液态玻璃底栏效果..." -ForegroundColor Cyan

if (Get-Command python -ErrorAction SilentlyContinue) {
    python apply_liquid_glass.py
} elseif (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host "检测到 Git，尝试使用 git apply..." -ForegroundColor Yellow
    git apply liquid_glass.patch
} else {
    Write-Host "请确保系统安装了 Python 或 Git 环境以运行自动升级补丁。" -ForegroundColor Red
}
