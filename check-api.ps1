# Verifi API checker. Run from E:\verifi with uvicorn already running.
#   powershell -ExecutionPolicy Bypass -File .\check-api.ps1
#   powershell -ExecutionPolicy Bypass -File .\check-api.ps1 -RateLimit   (also tests 429, uses ~21 calls)
param(
    [string]$Base = "http://localhost:8000",
    [switch]$RateLimit
)

$api = "$Base/api/v1"
$script:pass = 0
$script:fail = 0

function Call {
    param([string]$Method, [string]$Url, $Body = $null, [string]$Token = $null)
    $headers = @{}
    if ($Token) { $headers["Authorization"] = "Bearer $Token" }
    $args2 = @{ Method = $Method; Uri = $Url; Headers = $headers; UseBasicParsing = $true; TimeoutSec = 60 }
    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Depth 5
        $args2["Body"] = [System.Text.Encoding]::UTF8.GetBytes($json)
        $args2["ContentType"] = "application/json; charset=utf-8"
    }
    $status = 0; $content = ""; $retry = $null
    try {
        $resp = Invoke-WebRequest @args2
        $status = [int]$resp.StatusCode
        $content = $resp.Content
    } catch {
        $r = $_.Exception.Response
        if ($r) {
            $status = [int]$r.StatusCode
            try { $retry = $r.Headers["Retry-After"] } catch {}
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                $content = $_.ErrorDetails.Message
            } else {
                try {
                    $sr = New-Object System.IO.StreamReader($r.GetResponseStream())
                    $content = $sr.ReadToEnd()
                } catch {}
            }
        } else {
            $content = $_.Exception.Message
        }
    }
    $obj = $null
    try { if ($content) { $obj = $content | ConvertFrom-Json } } catch { Write-Host ("       (could not parse JSON from " + $Url + ": " + $_.Exception.Message + ")") -ForegroundColor DarkYellow }
    return [pscustomobject]@{ Status = $status; Raw = $content; Json = $obj; RetryAfter = $retry }
}

function Check {
    param([string]$Name, [bool]$Ok, [string]$Detail = "")
    if ($Ok) {
        $script:pass++
        Write-Host ("[PASS] " + $Name) -ForegroundColor Green
    } else {
        $script:fail++
        Write-Host ("[FAIL] " + $Name) -ForegroundColor Red
        if ($Detail) { Write-Host ("       " + $Detail) -ForegroundColor DarkYellow }
    }
}

function Short($r) {
    $t = "$($r.Raw)"
    if ($t.Length -gt 300) { $t = $t.Substring(0, 300) + "..." }
    return "status=$($r.Status) body=$t"
}

Write-Host "Checking $Base" -ForegroundColor Cyan

# 1. Health
$r = Call GET "$Base/health"
if ($r.Status -ne 200) { $r = Call GET "$api/health" }
Check "health returns 200 and status ok" ($r.Status -eq 200 -and $r.Json.status -eq "ok") (Short $r)

# 2. Install token
$r = Call POST "$api/auth/install" @{}
$token = $null
if ($r.Json) { $token = $r.Json.install_token }
Check "auth/install returns 201 with install_token and expires_in" ($r.Status -eq 201 -and $token -and $r.Json.expires_in -gt 0) (Short $r)
if (-not $token) {
    Write-Host "No token, cannot continue." -ForegroundColor Red
    exit 1
}

# 3. Auth errors
$r = Call POST "$api/quick-check" @{ text = "hi"; lang = "en"; source = "mobile" }
Check "no token -> 401 invalid_token" ($r.Status -eq 401 -and $r.Json.error.code -eq "invalid_token") (Short $r)

$r = Call POST "$api/quick-check" @{ text = "hi"; lang = "en"; source = "mobile" } "not-a-real-token"
Check "bad token -> 401 invalid_token" ($r.Status -eq 401 -and $r.Json.error.code -eq "invalid_token") (Short $r)

# 4. Input errors
$r = Call POST "$api/quick-check" @{ text = ""; lang = "en"; source = "mobile" } $token
Check "empty text -> 400 invalid_input" ($r.Status -eq 400 -and $r.Json.error.code -eq "invalid_input") (Short $r)

$r = Call POST "$api/quick-check" @{ text = ("a" * 2001); lang = "en"; source = "mobile" } $token
Check "2001 chars -> 400 invalid_input" ($r.Status -eq 400 -and $r.Json.error.code -eq "invalid_input") (Short $r)

$r = Call POST "$api/quick-check" @{ text = "The sky is blue"; lang = "xx"; source = "mobile" } $token
Check "bad lang -> 400 invalid_input" ($r.Status -eq 400 -and $r.Json.error.code -eq "invalid_input") (Short $r)

# 5. Real checkable claim
$claim = "The COVID-19 vaccine contains microchips"
$r = Call POST "$api/quick-check" @{ text = $claim; lang = "en"; source = "mobile" } $token
$j = $r.Json
$fp = $null
Check "checkable claim -> 200 with all contract fields" ($r.Status -eq 200 -and $j.checkable -eq $true -and $j.PSObject.Properties.Name -contains "likely_answer" -and $j.PSObject.Properties.Name -contains "confidence_low" -and $j.PSObject.Properties.Name -contains "took_ms") (Short $r)
if ($j) {
    $fp = $j.fingerprint
    Check "evidence is not empty" (@($j.evidence).Count -gt 0) "evidence count = $(@($j.evidence).Count)"
    Check "evidence items have title, url, stance, quality" ((@($j.evidence) | Where-Object { $_.title -and $_.url -and $_.stance -and ($null -ne $_.quality) }).Count -eq @($j.evidence).Count) "some evidence items are missing fields"
    Check "stance values are valid" ((@($j.evidence) | Where-Object { $_.stance -notin @("supporting", "contradicting", "neutral") }).Count -eq 0) "unexpected stance value"
    Check "confidence range is 0..1 and low <= high" ($j.confidence_low -ge 0 -and $j.confidence_high -le 1 -and $j.confidence_low -le $j.confidence_high) "low=$($j.confidence_low) high=$($j.confidence_high)"
    Check "fingerprint is 16 hex and not the mock value" ($fp -match '^[0-9a-f]{16}$' -and $fp -ne "a3f19c2b7d4e8a01" -and $fp -ne "5c01e9aa13b27f64") "fingerprint = $fp"
    $firstCached = [bool]$j.cached
    if ($firstCached) { Write-Host "       (claim was already cached from an earlier run, so the speed check is skipped)" -ForegroundColor Gray }
}

# 6. Repeat -> cache
$r2 = Call POST "$api/quick-check" @{ text = $claim; lang = "en"; source = "mobile" } $token
Check "repeat call -> cached true" ($r2.Status -eq 200 -and $r2.Json.cached -eq $true) (Short $r2)
if ($r2.Json -and $j) {
    if (-not $firstCached) {
        Check "cached call is faster" ($r2.Json.took_ms -lt $j.took_ms) "first=$($j.took_ms)ms repeat=$($r2.Json.took_ms)ms"
    }
    Check "cached call has same fingerprint" ($r2.Json.fingerprint -eq $fp) "first=$fp repeat=$($r2.Json.fingerprint)"
}

# 7. Opinion -> unchecked
$r = Call POST "$api/quick-check" @{ text = "This party is the worst thing to happen to our country."; lang = "en"; source = "mobile" } $token
Check "opinion -> checkable false, reason opinion, no evidence, null answer" ($r.Status -eq 200 -and $r.Json.checkable -eq $false -and $r.Json.reason_unchecked -eq "opinion" -and @($r.Json.evidence).Count -eq 0 -and $null -eq $r.Json.likely_answer) (Short $r)

# 8. Roman Urdu
$r = Call POST "$api/quick-check" @{ text = "garam pani peene se dengue theek ho jata hai"; lang = "ur-Latn"; source = "mobile" } $token
Check "Roman Urdu -> 200 with lang_detected" ($r.Status -eq 200 -and $r.Json.lang_detected) (Short $r)
if ($r.Json) { Write-Host ("       lang_detected=" + $r.Json.lang_detected + " | answer=" + $r.Json.likely_answer + " | evidence=" + @($r.Json.evidence).Count) -ForegroundColor Gray }

# 9. Urdu script
$urdu = "$([char]0x06AF)$([char]0x0631)$([char]0x0645) $([char]0x067E)$([char]0x0627)$([char]0x0646)$([char]0x06CC) $([char]0x067E)$([char]0x06CC)$([char]0x0646)$([char]0x06D2) $([char]0x0633)$([char]0x06D2) $([char]0x0688)$([char]0x06CC)$([char]0x0646)$([char]0x06AF)$([char]0x06CC) $([char]0x0679)$([char]0x06BE)$([char]0x06CC)$([char]0x06A9) $([char]0x06C1)$([char]0x0648) $([char]0x062C)$([char]0x0627)$([char]0x062A)$([char]0x0627) $([char]0x06C1)$([char]0x06D2)"
$r = Call POST "$api/quick-check" @{ text = $urdu; lang = "ur"; source = "mobile" } $token
Check "Urdu script -> 200" ($r.Status -eq 200 -and $r.Json.lang_detected) (Short $r)

# 10. Lookup
if ($fp) {
    $prefix = $fp.Substring(0, 4)
    $r = Call GET "$api/lookup/$prefix" $null $token
    $found = ("$($r.Raw)" -like ('*"fingerprint":"' + $fp + '"*')) -or ("$($r.Raw)" -like ('*"fingerprint": "' + $fp + '"*'))
    Check "lookup/$prefix -> 200 and contains the claim just checked" ($r.Status -eq 200 -and $found) ("fp=$fp " + (Short $r))
    Check "lookup requires a token" ((Call GET "$api/lookup/$prefix").Status -eq 401) "lookup without a token did not return 401"
}
$r = Call GET "$api/lookup/0000" $null $token
Check "lookup of an empty bucket -> 200 with entries list" ($r.Status -eq 200 -and $null -ne $r.Json -and $r.Json.PSObject.Properties.Name -contains "entries") (Short $r)

# 11. Rate limit (optional)
if ($RateLimit) {
    Write-Host "Rate limit test: 22 requests on a fresh token..." -ForegroundColor Cyan
    $t2 = (Call POST "$api/auth/install" @{}).Json.install_token
    $got429 = $false; $retry = $null; $n = 0
    for ($i = 1; $i -le 22; $i++) {
        $n = $i
        $x = Call POST "$api/quick-check" @{ text = "This is the worst song ever made $i"; lang = "en"; source = "mobile" } $t2
        if ($x.Status -eq 429) { $got429 = $true; $retry = $x.RetryAfter; break }
    }
    Check "429 rate_limited after about 20 requests (hit at request $n)" ($got429 -and $n -ge 20 -and $n -le 22) "never got 429"
    Check "429 has Retry-After header" ($got429 -and $retry) "Retry-After header missing"
} else {
    Write-Host "[SKIP] rate limit (run with -RateLimit to test)" -ForegroundColor DarkGray
}

Write-Host ""
$color = "Green"
if ($script:fail -gt 0) { $color = "Red" }
Write-Host ("Passed: " + $script:pass + "   Failed: " + $script:fail) -ForegroundColor $color
if ($script:fail -gt 0) { exit 1 }