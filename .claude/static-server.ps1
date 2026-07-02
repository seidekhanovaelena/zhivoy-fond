param(
    [int]$Port = 5173,
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

Add-Type -AssemblyName System.Web

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Write-Host "Serving $Root on http://127.0.0.1:$Port/"

$mimeMap = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".ico"  = "image/x-icon"
    ".txt"  = "text/plain; charset=utf-8"
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        try {
            $localPath = [System.Uri]::UnescapeDataString($request.Url.LocalPath)
            if ($localPath -eq "/") { $localPath = "/zhivoy-fond.html" }
            $filePath = Join-Path $Root ($localPath.TrimStart("/"))
            $fullRoot = (Resolve-Path $Root).Path
            $resolved = $null
            if (Test-Path $filePath) { $resolved = (Resolve-Path $filePath).Path }

            if ($resolved -and $resolved.StartsWith($fullRoot) -and (Test-Path $resolved -PathType Leaf)) {
                $ext = [System.IO.Path]::GetExtension($resolved).ToLower()
                $contentType = $mimeMap[$ext]
                if (-not $contentType) { $contentType = "application/octet-stream" }
                $bytes = [System.IO.File]::ReadAllBytes($resolved)
                $response.ContentType = $contentType
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $response.StatusCode = 404
                $notFound = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
                $response.OutputStream.Write($notFound, 0, $notFound.Length)
            }
        } catch {
            $response.StatusCode = 500
        } finally {
            $response.OutputStream.Close()
        }
    }
} finally {
    $listener.Stop()
}
