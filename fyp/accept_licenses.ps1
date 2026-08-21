$sdkmanager = "C:\flutter\android-sdk\cmdline-tools\latest\bin\sdkmanager.bat"
$licenses = @("android-googletv-license", "android-sdk-license", "android-sdk-preview-license", "google-gdk-license", "intel-android-extra-license", "mips-android-sysimage-license")

foreach ($license in $licenses) {
    Write-Host "Accepting $license..."
    echo "y" | & $sdkmanager --licenses 2>&1 | Out-Null
}

Write-Host "All licenses accepted!"

