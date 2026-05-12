param(
    [string]$EnvFile = ".env",
    [string]$Password = "Saral@Client2026"
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

$serviceRoleKey = $envValues["SUPABASE_SERVICE_ROLE_KEY"]
if (-not $supabaseUrl -or -not $serviceRoleKey -or $serviceRoleKey -like "replace-with-*") {
    throw "Add SUPABASE_SERVICE_ROLE_KEY to $EnvFile before provisioning admin/pandit demo accounts."
}

$headers = @{
    apikey = $serviceRoleKey
    Authorization = "Bearer $serviceRoleKey"
    "Content-Type" = "application/json"
}

function Invoke-SupabaseJson {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body = $null,
        [string]$Prefer = $null
    )

    $requestHeaders = $headers.Clone()
    if ($Prefer) { $requestHeaders["Prefer"] = $Prefer }

    $parameters = @{
        Method = $Method
        Uri = "$supabaseUrl$Path"
        Headers = $requestHeaders
        TimeoutSec = 60
    }
    if ($null -ne $Body) {
        $parameters["Body"] = ($Body | ConvertTo-Json -Depth 10)
    }
    Invoke-RestMethod @parameters
}

function Get-AuthUsers {
    $users = @()
    $page = 1
    do {
        $result = Invoke-SupabaseJson -Method "GET" -Path "/auth/v1/admin/users?page=$page&per_page=100"
        $batch = @($result.users)
        $users += $batch
        $page += 1
    } while ($batch.Count -eq 100)
    $users
}

function Upsert-AuthUser {
    param([hashtable]$Account, [array]$ExistingUsers)

    $existing = $ExistingUsers | Where-Object { $_.email -eq $Account.email } | Select-Object -First 1
    $body = @{
        email = $Account.email
        password = $Password
        email_confirm = $true
        user_metadata = @{
            full_name = $Account.name
            phone = $Account.phone
            role = $Account.role
        }
    }

    if ($existing) {
        try {
            return Invoke-SupabaseJson -Method "PUT" -Path "/auth/v1/admin/users/$($existing.id)" -Body $body
        } catch {
            return Invoke-SupabaseJson -Method "PATCH" -Path "/auth/v1/admin/users/$($existing.id)" -Body $body
        }
    }

    Invoke-SupabaseJson -Method "POST" -Path "/auth/v1/admin/users" -Body $body
}

$accounts = @(
    @{ role = "user"; email = "client.user@saralpooja.app"; name = "Client User"; phone = "+919999999981"; wallet = 50000 },
    @{ role = "pandit"; email = "client.pandit@saralpooja.app"; name = "Pt. Client Demo"; phone = "+919999999982"; wallet = 0 },
    @{ role = "admin"; email = "client.admin@saralpooja.app"; name = "Client Admin"; phone = "+919999999983"; wallet = 0 }
)

$existingUsers = Get-AuthUsers
$provisioned = @()

foreach ($account in $accounts) {
    $authUser = Upsert-AuthUser -Account $account -ExistingUsers $existingUsers
    $userId = $authUser.id
    if (-not $userId -and $authUser.user) { $userId = $authUser.user.id }
    if (-not $userId) { throw "Could not determine user id for $($account.email)." }

    $profile = @(
        @{
            id = $userId
            full_name = $account.name
            email = $account.email
            phone = $account.phone
            role = $account.role
            is_active = $true
        }
    )
    Invoke-SupabaseJson -Method "POST" -Path "/rest/v1/profiles?on_conflict=id" -Body $profile -Prefer "resolution=merge-duplicates,return=minimal" | Out-Null

    $wallet = @(
        @{
            user_id = $userId
            balance = $account.wallet
        }
    )
    Invoke-SupabaseJson -Method "POST" -Path "/rest/v1/wallets?on_conflict=user_id" -Body $wallet -Prefer "resolution=merge-duplicates,return=minimal" | Out-Null

    if ($account.role -eq "pandit") {
        $pandit = @(
            @{
                id = $userId
                specialties = @("Griha Pravesh", "Satyanarayan", "Havan", "Kundli")
                languages = @("Hindi", "Sanskrit", "English")
                bio = "Verified demo pandit account for client walkthroughs."
                experience_years = 12
                rating = 4.9
                completed_bookings = 284
                chat_price_per_minute = 25
                is_online = $true
                is_available_offline = $true
                rough_location = "Lucknow"
            }
        )
        Invoke-SupabaseJson -Method "POST" -Path "/rest/v1/pandits?on_conflict=id" -Body $pandit -Prefer "resolution=merge-duplicates,return=minimal" | Out-Null
    }

    $provisioned += [pscustomobject]@{
        Role = $account.role
        Email = $account.email
        Password = $Password
        UserId = $userId
    }
}

$provisioned | Format-Table -AutoSize
Write-Host "Demo accounts are ready. Keep the password private and rotate/remove these accounts after the client review."