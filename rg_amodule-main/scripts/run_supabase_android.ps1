param(
    [string]$DeviceId = "emulator-5554",
    [string]$EnvFile = ".env"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

if (-not (Test-Path $EnvFile)) {
    throw "Missing $EnvFile. Copy .env.example to .env and fill in Supabase values."
}

$envValues = @{}
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -ne "" -and -not $line.StartsWith("#")) {
        $name, $value = $line -split "=", 2
        if ($name -and $null -ne $value) {
            $envValues[$name.Trim()] = $value.Trim()
        }
    }
}

$supabaseUrl = $envValues["SUPABASE_URL"]
if (-not $supabaseUrl) { $supabaseUrl = $envValues["NEXT_PUBLIC_SUPABASE_URL"] }

$supabaseAnonKey = $envValues["SUPABASE_ANON_KEY"]
if (-not $supabaseAnonKey) { $supabaseAnonKey = $envValues["NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY"] }

if (-not $supabaseUrl -or -not $supabaseAnonKey) {
    throw "Missing Supabase URL/key in $EnvFile."
}

$razorpayKeyId = $envValues["RAZORPAY_KEY_ID"]
$clientDemoAccess = $envValues["CLIENT_DEMO_ACCESS"]

$arguments = @(
    "run",
    "-d",
    $DeviceId,
    "--debug",
    "--dart-define=SUPABASE_URL=$supabaseUrl",
    "--dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey"
)

if ($razorpayKeyId) {
    $arguments += "--dart-define=RAZORPAY_KEY_ID=$razorpayKeyId"
}

if ($clientDemoAccess) {
    $arguments += "--dart-define=CLIENT_DEMO_ACCESS=$clientDemoAccess"
}

& flutter @arguments
