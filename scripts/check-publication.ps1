[CmdletBinding()]
param(
    [switch]$AllHistory
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$scannerRelativePath = 'scripts/check-publication.ps1'
$allowedPersonalEmail = 'ARBikmuhametov@yandex.ru'

function Join-Chars {
    param([int[]]$Codes)
    -join ($Codes | ForEach-Object { [char]$_ })
}

$blockedCorporateFragments = @(
    ('BIR' + 'PA'),
    ('1c' + 'bit'),
    ('Первый' + ' Бит'),
    ('Ц' + 'КК'),
    (Join-Chars @(0x0423,0x043D,0x0438,0x0442,0x0440,0x0435,0x0439,0x0434))
)
$blockedLocalFragments = @(
    ('yandex' + '_disk'),
    ('Yandex' + 'Disk'),
    ('01_' + 'birpa'),
    ('pix_3_0_' + 'templates')
)
$blockedInternalUrl = ('https://pi' + 'x:44300')

$corporatePattern = ($blockedCorporateFragments | ForEach-Object { [regex]::Escape($_) }) -join '|'
$localFragmentPattern = ($blockedLocalFragments | ForEach-Object { [regex]::Escape($_) }) -join '|'

$rules = [ordered]@{
    'embedded PIX screenshot' = '(?is)<(?:[^:<>]+:)?_?screens?hotbase64>(?!\s*</)[^<]+</(?:[^:<>]+:)?_?screens?hotbase64>'
    'Windows user profile path' = '(?i)[A-Z]:(?:\\{1,2})Users(?:\\{1,2})[^\\\r\n"''<]+'
    'workspace-specific path' = "(?i)$localFragmentPattern"
    'organization or client marker' = "(?i)$corporatePattern"
    'internal PIX Master URL' = [regex]::Escape($blockedInternalUrl)
    'private key material' = '(?i)-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
    'known access token format' = '(?i)(?:AKIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|ghp_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.)'
    'literal secret assignment' = '(?i)(?:password|passwd|pwd|secret|token|api[_-]?key|client[_-]?secret)\s*[:=]\s*["''][A-Za-z0-9_@#%+=:/.-]{6,}["'']'
}
$emailPattern = '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
$failures = [System.Collections.Generic.List[string]]::new()

function Test-PublicText {
    param(
        [string]$Text,
        [string]$Location
    )

    foreach ($rule in $rules.GetEnumerator()) {
        if ([regex]::IsMatch($Text, $rule.Value)) {
            $failures.Add("${Location}: $($rule.Key)")
        }
    }

    foreach ($emailMatch in [regex]::Matches($Text, $emailPattern)) {
        $email = $emailMatch.Value
        if ($email -ne $allowedPersonalEmail -and $email -notmatch '(?i)@example\.com$') {
            $failures.Add("${Location}: unapproved email address")
        }
    }
}

$gitArgs = @('-c', "safe.directory=$repoRoot", '-C', $repoRoot)
$trackedFiles = @(& git @gitArgs ls-files)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to list tracked files.'
}

if ($trackedFiles -contains 'data/configs/schedule.json') {
    $failures.Add('data/configs/schedule.json: runtime schedule must not be tracked')
}

$candidateFiles = @(& git @gitArgs ls-files --cached --others --exclude-standard) |
    Sort-Object -Unique |
    Where-Object { $_ -ne $scannerRelativePath }

foreach ($relativePath in $candidateFiles) {
    $fullPath = Join-Path $repoRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        continue
    }

    try {
        $text = [System.IO.File]::ReadAllText($fullPath)
        Test-PublicText -Text $text -Location $relativePath
    }
    catch {
        $failures.Add("${relativePath}: cannot inspect as text")
    }
}

if ($AllHistory) {
    $commits = @(& git @gitArgs rev-list --all)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to enumerate Git history.'
    }

    foreach ($commit in $commits) {
        $authorEmail = (& git @gitArgs show -s --format='%ae' $commit).Trim()
        if ($authorEmail -ne $allowedPersonalEmail) {
            $failures.Add("${commit}: unapproved author email")
        }

        $paths = @(& git @gitArgs ls-tree -r --name-only $commit)
        foreach ($relativePath in $paths) {
            if ($relativePath -eq $scannerRelativePath) {
                continue
            }

            $objectSpec = '{0}:{1}' -f $commit,$relativePath
            $content = (& git @gitArgs show $objectSpec 2>$null) -join [Environment]::NewLine
            if ($LASTEXITCODE -eq 0) {
                Test-PublicText -Text $content -Location $objectSpec
            }
        }
    }
}

if ($failures.Count -gt 0) {
    $failures |
        Sort-Object -Unique |
        ForEach-Object { Write-Host "ERROR: $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Publication check passed for $repoRoot"
exit 0
