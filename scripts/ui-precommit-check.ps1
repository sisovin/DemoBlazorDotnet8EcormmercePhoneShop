param(
    [switch]$Strict,
    [string[]]$StrictFrameworks = @("React", "Vue", "Tailwind")
)

$ErrorActionPreference = "Stop"

function Get-ContrastRatio {
    param(
        [string]$ForegroundHex,
        [string]$BackgroundHex
    )

    function Convert-HexToRgb {
        param([string]$Hex)
        $clean = $Hex.Trim().TrimStart('#')
        if ($clean.Length -eq 3) {
            $clean = "{0}{0}{1}{1}{2}{2}" -f $clean[0], $clean[1], $clean[2]
        }
        if ($clean.Length -ne 6) { return $null }
        return @(
            [Convert]::ToInt32($clean.Substring(0, 2), 16),
            [Convert]::ToInt32($clean.Substring(2, 2), 16),
            [Convert]::ToInt32($clean.Substring(4, 2), 16)
        )
    }

    function Get-RelativeLuminance {
        param([int[]]$Rgb)
        $channels = @()
        foreach ($c in $Rgb) {
            $v = $c / 255.0
            if ($v -le 0.03928) {
                $channels += $v / 12.92
            }
            else {
                $channels += [Math]::Pow((($v + 0.055) / 1.055), 2.4)
            }
        }
        return 0.2126 * $channels[0] + 0.7152 * $channels[1] + 0.0722 * $channels[2]
    }

    $fg = Convert-HexToRgb -Hex $ForegroundHex
    $bg = Convert-HexToRgb -Hex $BackgroundHex
    if (-not $fg -or -not $bg) { return $null }

    $l1 = Get-RelativeLuminance -Rgb $fg
    $l2 = Get-RelativeLuminance -Rgb $bg
    $lighter = [Math]::Max($l1, $l2)
    $darker = [Math]::Min($l1, $l2)
    return ($lighter + 0.05) / ($darker + 0.05)
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Skipping UI checks: git is not available." -ForegroundColor Yellow
    exit 0
}

$frontendPattern = '\.(html|css|scss|sass|less|js|jsx|ts|tsx|vue|svelte|astro)$'
$stagedFiles = git diff --cached --name-only --diff-filter=ACMR 2>$null | Where-Object { $_ -match $frontendPattern }

$normalizedFrameworks = @(
    $StrictFrameworks |
    ForEach-Object { $_ -split ',' } |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ne '' } |
    ForEach-Object { $_.ToLowerInvariant() }
)
$frameworkSet = [System.Collections.Generic.HashSet[string]]::new()
foreach ($framework in $normalizedFrameworks) {
    switch ($framework) {
        'react' { [void]$frameworkSet.Add('react') }
        'vue' { [void]$frameworkSet.Add('vue') }
        'tailwind' { [void]$frameworkSet.Add('tailwind') }
        default { }
    }
}

if ($Strict -and $frameworkSet.Count -eq 0) {
    Write-Host "Strict mode enabled, but no valid frameworks were supplied. Valid values: React, Vue, Tailwind." -ForegroundColor Red
    exit 1
}

if (-not $stagedFiles) {
    exit 0
}

$errors = New-Object System.Collections.Generic.HashSet[string]

foreach ($file in $stagedFiles) {
    if (-not (Test-Path $file)) {
        continue
    }

    $content = git show ":$file" 2>$null
    if (-not $content) {
        $content = Get-Content -Raw $file
    }

    $hasInteractive = $content -match '<button\b|<a\b|<input\b|<select\b|<textarea\b|role\s*=\s*"button"|onClick\s*=' 
    $hasFocusStyle = $content -match ':focus-visible|:focus\b|focus-visible:|focus:'

    if ($hasInteractive -and -not $hasFocusStyle) {
        [void]$errors.Add("${file}: missing visible focus style for interactive elements")
    }

    if ($Strict) {
        $checkReact = $frameworkSet.Contains('react')
        $checkVue = $frameworkSet.Contains('vue')
        $checkTailwind = $frameworkSet.Contains('tailwind')

        $isReactFile = $checkReact -and ($file -match '\.(jsx|tsx)$')
        $isVueFile = $checkVue -and ($file -match '\.vue$')
        $isTailwindLikely = $checkTailwind -and ($content -match 'class(Name)?\s*=\s*"[^"]*focus-visible:|class(Name)?\s*=\s*"[^"]*(hover:|active:|disabled:|cursor-pointer)')

        $frameworkInteractive = $content -match '<button\b|<a\b|<input\b|<select\b|<textarea\b|<RouterLink\b|<Link\b|<NuxtLink\b'
        $hasFrameworkFocusVisible = $content -match ':focus-visible|focus-visible:'

        if (($isReactFile -or $isVueFile -or $isTailwindLikely) -and $frameworkInteractive -and -not $hasFrameworkFocusVisible) {
            $frameworks = @()
            if ($isReactFile) { $frameworks += 'React' }
            if ($isVueFile) { $frameworks += 'Vue' }
            if ($isTailwindLikely) { $frameworks += 'Tailwind' }
            if ($frameworks.Count -eq 0) { $frameworks += 'Selected frameworks' }
            [void]$errors.Add("${file}: strict mode requires explicit focus-visible styles for $($frameworks -join '/') interactive elements")
        }

        if ($checkTailwind -and $isTailwindLikely) {
            $hasTailwindInteractive = $content -match 'class(Name)?\s*=\s*"[^"]*(cursor-pointer|hover:|active:|disabled:)[^"]*"'
            $hasTailwindFocusVisible = $content -match 'class(Name)?\s*=\s*"[^"]*focus-visible:[^"]*"'
            if ($hasTailwindInteractive -and -not $hasTailwindFocusVisible) {
                [void]$errors.Add("${file}: strict mode requires Tailwind focus-visible:* utility on interactive elements")
            }
        }
    }

    $pairs = New-Object System.Collections.Generic.List[object]
    $patternColorThenBg = '(?s)\{[^{}]*color\s*:\s*(#[0-9a-fA-F]{3,6})\s*;[^{}]*background(?:-color)?\s*:\s*(#[0-9a-fA-F]{3,6})\s*;[^{}]*\}'
    $patternBgThenColor = '(?s)\{[^{}]*background(?:-color)?\s*:\s*(#[0-9a-fA-F]{3,6})\s*;[^{}]*color\s*:\s*(#[0-9a-fA-F]{3,6})\s*;[^{}]*\}'

    foreach ($m in [regex]::Matches($content, $patternColorThenBg)) {
        $pairs.Add(@{ Color = $m.Groups[1].Value; Background = $m.Groups[2].Value })
    }
    foreach ($m in [regex]::Matches($content, $patternBgThenColor)) {
        $pairs.Add(@{ Color = $m.Groups[2].Value; Background = $m.Groups[1].Value })
    }

    foreach ($pair in $pairs) {
        $ratio = Get-ContrastRatio -ForegroundHex $pair.Color -BackgroundHex $pair.Background
        if ($null -ne $ratio -and $ratio -lt 4.5) {
            [void]$errors.Add("${file}: potential low contrast pair $($pair.Color) on $($pair.Background) (ratio $([Math]::Round($ratio, 2)))")
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "UI pre-commit checks failed:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    if ($Strict) {
        Write-Host "Strict mode is enabled for frameworks: $($frameworkSet -join ', '). Add framework-appropriate focus-visible styles before commit." -ForegroundColor Yellow
    }
    else {
        Write-Host "Fix issues or update styles before commit." -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "UI pre-commit checks passed." -ForegroundColor Green
exit 0
