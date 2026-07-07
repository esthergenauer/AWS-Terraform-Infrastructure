# Create IAM users for SBL developers with bastion SSM access only.
# Run once as an AWS administrator (e.g. DevOps).
#
# Usage:
#   .\scripts\create-developer-iam-users.ps1
#
# After each user is created, generate access keys in AWS Console or via:
#   aws iam create-access-key --user-name sbl-dev-avigail

$ErrorActionPreference = "Stop"
$Region = "eu-north-1"
$PolicyName = "sbl-staging-bastion-ssm"
$PolicyFile = Join-Path $PSScriptRoot "..\iam\policies\developer-bastion-ssm.json"

$Developers = @(
    @{ GitHub = "Avigail8532";      IamUser = "sbl-dev-avigail" }
    @{ GitHub = "HilaGeula";        IamUser = "sbl-dev-hila" }
    @{ GitHub = "MalkyDoutsch";     IamUser = "sbl-dev-malky" }
    @{ GitHub = "SaraDinaKelerman"; IamUser = "sbl-dev-sara" }
    @{ GitHub = "shirasiroka";      IamUser = "sbl-dev-shira" }
)

Write-Host "Creating IAM policy: $PolicyName"
$PolicyArn = aws iam create-policy `
    --policy-name $PolicyName `
    --policy-document "file://$PolicyFile" `
    --description "SSM port-forward to RDS via staging bastion" `
    --query "Policy.Arn" `
    --output text 2>$null

if (-not $PolicyArn) {
    $AccountId = aws sts get-caller-identity --query Account --output text
    $PolicyArn = "arn:aws:iam::${AccountId}:policy/$PolicyName"
    Write-Host "Policy already exists, using: $PolicyArn"
}

foreach ($dev in $Developers) {
    $user = $dev.IamUser
    Write-Host "`n--- $($dev.GitHub) -> $user ---"

    aws iam get-user --user-name $user 2>$null
    if ($LASTEXITCODE -ne 0) {
        aws iam create-user --user-name $user --tags "Key=Project,Value=sbl" "Key=Environment,Value=staging" "Key=GitHub,Value=$($dev.GitHub)"
        Write-Host "Created IAM user: $user"
    } else {
        Write-Host "IAM user already exists: $user"
    }

    aws iam attach-user-policy --user-name $user --policy-arn $PolicyArn
    Write-Host "Attached bastion SSM policy to $user"
}

Write-Host "`nDone. Create access keys per user in AWS Console (IAM -> Users -> Security credentials)."
Write-Host "Send each developer: Access Key ID + Secret + tunnel command (see developer handoff message)."
