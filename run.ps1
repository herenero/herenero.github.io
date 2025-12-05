# 한글 깨짐 방지 설정
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ================= 경로 설정 =================
$MovieSource = "G:\내 드라이브\공부\NERO\02_Areas\Movie" # 영화 리뷰 원본 폴더
$ImageSource = "G:\내 드라이브\공부\NERO\temp"          # 모든 이미지가 섞여 있는 폴더

$Dest = Join-Path $PSScriptRoot "content"               # 사이트 글 폴더
$ImageDest = Join-Path $Dest "temp"                     # 사이트 이미지 폴더
# ============================================

Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🎬 스마트 동기화: 리뷰와 관련 이미지만 가져오기" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 1. 영화 리뷰 파일 복사 (이미지 폴더 제외)
Write-Host "`n[1/4] 📝 리뷰 글 복사 중..." -ForegroundColor Yellow
if (!(Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest | Out-Null }
robocopy $MovieSource $Dest /MIR /XD "temp" ".git" ".obsidian" /R:0 /W:0 /NFL /NDL

# 2. 이미지 저장소 폴더 준비 (기존 것 비우고 새로 생성)
Write-Host "[2/4] 🧹 이미지 폴더 정리 중..." -ForegroundColor Yellow
if (Test-Path $ImageDest) { Remove-Item $ImageDest -Recurse -Force }
New-Item -ItemType Directory -Path $ImageDest | Out-Null

# 3. 마크다운 파일을 분석해서 필요한 이미지만 쏙쏙 뽑아오기
Write-Host "[3/4] 🔍 글 내용을 분석하여 이미지 추출 중..." -ForegroundColor Yellow

# content 폴더 안의 모든 .md 파일을 읽음
$mdFiles = Get-ChildItem -Path $Dest -Filter *.md -Recurse

$copyCount = 0

foreach ($file in $mdFiles) {
    # 파일 내용을 읽어옴
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    
    # 정규식으로 ![[파일이름]] 패턴을 찾음 (파이프 | 뒤에 오는 사이즈 정보 등은 무시)
    $matches = [regex]::Matches($content, '!\[\[([^|\]]+)(?:\|[^\]]+)?\]\]')

    foreach ($match in $matches) {
        # 파일명만 추출 (예: image.jpg)
        $imageName = $match.Groups[1].Value.Trim()
        
        $sourceImg = Join-Path $ImageSource $imageName
        $destImg = Join-Path $ImageDest $imageName

        # 원본에 이미지가 실제로 있는지 확인
        if (Test-Path $sourceImg) {
            # 중복 복사 방지
            if (!(Test-Path $destImg)) {
                Copy-Item -Path $sourceImg -Destination $destImg
                Write-Host "  + 복사됨: $imageName" -ForegroundColor DarkGray
                $copyCount++
            }
        }
        else {
            Write-Host "  ⚠️ 경고: '$imageName' 파일을 찾을 수 없습니다. (문서: $($file.Name))" -ForegroundColor Red
        }
    }
}

Write-Host "`n  -> 총 $copyCount 개의 이미지를 가져왔습니다." -ForegroundColor White

# 4. Quartz 서버 실행
Write-Host "`n[4/4] ✅ 완료! Quartz 서버를 시작합니다..." -ForegroundColor Green
Write-Host "   (종료하려면 Ctrl + C를 누르세요)`n" -ForegroundColor Gray

npx quartz build --serve