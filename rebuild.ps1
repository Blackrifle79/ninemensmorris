# Nine Men's Morris - Clean Rebuild Script
# Run this when you get MSB8066 or other build errors

Write-Host "Stopping any running instances..." -ForegroundColor Yellow
Get-Process nine_mens_morris -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3

Write-Host "Removing build folder..." -ForegroundColor Yellow
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue

Write-Host "Running flutter clean..." -ForegroundColor Yellow
flutter clean

Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "Building and running..." -ForegroundColor Green
flutter run -d windows
