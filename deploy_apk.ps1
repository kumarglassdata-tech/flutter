# Deploy APK to Firebase Hosting
Write-Host "1. Building Release APK..." -ForegroundColor Green
flutter build apk --release --dart-define-from-file=.env.json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter APK build failed!"
    exit 1
}

Write-Host "2. Copying APK to Web Hosting directory..." -ForegroundColor Green
$webDir = "build/web"
if (-not (Test-Path $webDir)) {
    New-Item -ItemType Directory -Path $webDir
}

Copy-Item "build/app/outputs/flutter-apk/app-release.apk" -Destination "$webDir/smartglass.apk" -Force

Write-Host "3. Deploying to Firebase Hosting..." -ForegroundColor Green
firebase deploy --only hosting

Write-Host "Deployment complete! Your APK is hosted at: https://<your-firebase-project>.web.app/smartglass.apk" -ForegroundColor Cyan
