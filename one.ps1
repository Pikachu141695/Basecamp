# ==========================================
# 0. 관리자 권한 자동 확인 및 승격
# (WSL 및 시스템 프로그램 설치를 위해 관리자 권한 필요)
# ==========================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[안내] WSL 및 프로그램 설치를 위해 관리자 권한으로 다시 실행합니다..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Exit
}

# ==========================================
# 1. Git 기본 정보
# ==========================================
$gitName  = "Pikachu141695"
$gitEmail = "Pikachu141695@users.noreply.github.com"

# ==========================================
# 2. 필수 프로그램 일괄 설치 (winget)
# ==========================================
$packages = @(
    "Git.Git",
    "GitHub.cli",
    "Microsoft.VisualStudioCode",
    "Docker.DockerDesktop",
    "Python.Python.3.14",
    "astral-sh.uv"
)

Write-Host ">>> [1/7] 필수 프로그램 설치 확인 중..." -ForegroundColor Cyan
foreach ($pkg in $packages) {
    Write-Host "Checking / Installing $pkg..." -ForegroundColor Gray
    winget install -e --id $pkg --accept-package-agreements --accept-source-agreements --silent
}

# 현재 터미널에 PATH 즉시 반영
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# ==========================================
# 3. WSL 및 리눅스(Ubuntu) 배포판 완벽 감지 및 설치
# ==========================================
Write-Host "`n>>> [2/7] WSL 및 리눅스 배포판(Ubuntu) 확인 중..." -ForegroundColor Cyan

# 현재 설치된 리눅스 배포판 목록 확인
$installedDistros = @(wsl.exe -l -q 2>$null | Where-Object { $_ -match '\S' })

if ($installedDistros.Count -eq 0) {
    Write-Host "[!] 설치된 리눅스 배포판이 없습니다. Ubuntu 설치를 시작합니다..." -ForegroundColor Yellow
    Write-Host "    (설치 창이 뜨면 잠시 기다린 후 리눅스 계정과 비밀번호를 입력해 주세요)" -ForegroundColor Magenta
    wsl.exe --install -d Ubuntu
    Write-Host "WSL 및 Ubuntu 설치 명령이 실행되었습니다." -ForegroundColor Green
} else {
    Write-Host "WSL 및 리눅스 배포판이 이미 준비되어 있습니다: $($installedDistros -join ', ')" -ForegroundColor Green
}

# ==========================================
# 4. Git 기본 설정 및 GitHub 로그인 연동
# ==========================================
Write-Host "`n>>> [3/7] Git & GitHub 계정 연동..." -ForegroundColor Cyan
git config --global user.name $gitName
git config --global user.email $gitEmail
git config --global init.defaultBranch main
git config --global core.autocrlf true

gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "GitHub 로그인이 필요합니다. 브라우저 인증을 진행해 주세요." -ForegroundColor Yellow
    gh auth login -p https -w
}
gh auth setup-git

# ==========================================
# 5. Basecamp 레포지토리 클론
# ==========================================
Write-Host "`n>>> [4/7] Basecamp 프로젝트 확인..." -ForegroundColor Cyan
$workDir = "C:\workspace"
New-Item -ItemType Directory -Force -Path $workDir | Out-Null
Set-Location $workDir

if (-not (Test-Path "$workDir\Basecamp")) {
    Write-Host "GitHub에서 Basecamp 레포지토리를 클론합니다..." -ForegroundColor Yellow
    gh repo clone Pikachu141695/Basecamp
} else {
    Write-Host "Basecamp 폴더가 이미 존재합니다." -ForegroundColor Green
}

# ==========================================
# 6. VS Code 확장프로그램 일괄 설치 (Antigravity & AI 확장 포함)
# ==========================================
Write-Host "`n>>> [5/7] VS Code 필수 확장 프로그램 설치 중..." -ForegroundColor Cyan
$extensions = @(
    "google.google-antigravity",           # Google Antigravity (AI 어시스턴트)
    "Continue.continue",                   # Continue (AI 코딩 에이전트)
    "openai.chatgpt",                      # OpenAI ChatGPT 공식 확장
    "ms-python.python",                    # Python 지원
    "ms-vscode-remote.remote-wsl",         # WSL 원격 개발 연동
    "ms-vscode-remote.remote-containers",  # Dev Containers 개발
    "ms-azuretools.vscode-docker"          # Docker 관리
)

foreach ($ext in $extensions) {
    Write-Host "Installing extension: $ext..." -ForegroundColor Gray
    code --install-extension $ext --force
}

# ==========================================
# 7. Continue config.yaml 자동 생성
# ==========================================
Write-Host "`n>>> [6/7] Continue AI 설정 파일(config.yaml) 생성..." -ForegroundColor Cyan
$virtualKey = Read-Host "Codyssey virtual-key 입력 (나중에 직접 넣으려면 그냥 Enter)"
if ([string]::IsNullOrWhiteSpace($virtualKey)) {
    $virtualKey = "<virtual-key>"
}

$continueDir = "$env:USERPROFILE\.continue"
New-Item -ItemType Directory -Force -Path $continueDir | Out-Null

$continueConfig = @"
name: Codyssey Public API
version: 1.0.0
schema: v1

models:
  - name: Codyssey GPT-5 mini
    provider: openai
    model: gpt-5-mini
    apiBase: https://copa.codyssey.kr/v1
    apiKey: $virtualKey
    useResponsesApi: false
    requestOptions:
      headers:
        X-Codyssey-Session-Id: my-session-2026-09-18
    roles:
      - chat
      - edit
      - apply
    capabilities:
      - tool_use
    defaultCompletionOptions:
      maxTokens: 4096

context:
  - provider: file
  - provider: code
  - provider: diff
  - provider: terminal
"@

[System.IO.File]::WriteAllText("$continueDir\config.yaml", $continueConfig, (New-Object System.Text.UTF8Encoding $false))
Write-Host "Continue config.yaml 생성 완료: $continueDir\config.yaml" -ForegroundColor Green

# ==========================================
# 8. 완료 안내 및 VS Code 실행
# ==========================================
Write-Host "`n>>> [7/7] 모든 환경 세팅이 완료되었습니다!" -ForegroundColor Green
Write-Host "Basecamp 프로젝트를 VS Code로 엽니다..." -ForegroundColor Cyan
code "$workDir\Basecamp"
