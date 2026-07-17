<#
.SYNOPSIS
Builds and deploys the Smart Myna Flutter Web App to Amazon S3.

.DESCRIPTION
This script builds the Flutter application for the web and synchronizes the 
output directory (build/web) to the specified Amazon S3 bucket.

Since you noted that AWS CLI is not configured, this script will first check 
if 'aws' is installed and prompt you with instructions if it is missing.
#>

$BucketName = "myna-flutter-web-app-dev-ap-south-1a-global"
$Region = "ap-south-1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Smart Myna Flutter Web Deployer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Check for AWS CLI
try {
    $awsVersion = aws --version 2>&1
} catch {
    Write-Host "`n[ERROR] AWS CLI is not installed or not in your PATH." -ForegroundColor Red
    Write-Host "Please install it from: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    Write-Host "After installing, run 'aws configure' in your terminal to set your Access Key and Secret Key." -ForegroundColor Yellow
    exit 1
}

# 2. Check if AWS CLI is configured
$awsConfigured = aws configure get region 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[ERROR] AWS CLI is installed but NOT configured." -ForegroundColor Red
    Write-Host "Please run 'aws configure' in your terminal and provide your Access Key, Secret Key, and default region (e.g. ap-south-1)." -ForegroundColor Yellow
    exit 1
}

Write-Host "`n[1/3] Building Flutter Web App... (This may take a minute)" -ForegroundColor Blue
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Flutter build failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`n[2/3] Syncing files to S3 bucket: $BucketName ..." -ForegroundColor Blue
aws s3 sync build/web s3://$BucketName --delete
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] S3 Sync failed. Please check your AWS permissions." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Note: If the bucket is already configured for Static Website Hosting, this is the default URL format.
$WebsiteUrl = "http://${BucketName}.s3-website.${Region}.amazonaws.com"

Write-Host "`n[3/3] Deployment Successful! 🎉" -ForegroundColor Green
Write-Host "Your colleagues can view the live changes here:" -ForegroundColor White
Write-Host $WebsiteUrl -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
