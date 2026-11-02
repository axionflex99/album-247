# Album 24/7 Zero-Dependency Local Static Preview Server
param(
    [int]$Port = 3000
)

$root = $PSScriptRoot
if (-not $root) { $root = Get-Location }

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".webp" = "image/webp"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".png"  = "image/png"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
}

$tcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
$tcp.Start()
Write-Host "Album 24/7 static server running at http://localhost:$Port/ (and http://127.0.0.1:$Port/)"
Write-Host "Press Ctrl+C to stop."

try {
    while ($true) {
        $client = $tcp.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII)
        $line = $reader.ReadLine()
        if (-not $line) {
            $client.Close()
            continue
        }

        $parts = $line.Split(" ")
        $rawPath = if ($parts.Length -gt 1) { $parts[1] } else { "/" }
        $cleanPath = $rawPath.Split("?")[0]
        if ($cleanPath -eq "/" -or $cleanPath -eq "") { $cleanPath = "/index.html" }

        $relPath = [System.Uri]::UnescapeDataString($cleanPath.TrimStart("/")).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
        $filePath = [System.IO.Path]::Combine($root, $relPath)

        if ([System.IO.File]::Exists($filePath)) {
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $ct = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { "application/octet-stream" }

            $header = "HTTP/1.1 200 OK`r`nContent-Type: $ct`r`nContent-Length: $($bytes.Length)`r`nAccess-Control-Allow-Origin: *`r`nConnection: close`r`n`r`n"
            $hBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
            $stream.Write($hBytes, 0, $hBytes.Length)
            $stream.Write($bytes, 0, $bytes.Length)
        } else {
            $msg = "404 Not Found"
            $msgBytes = [System.Text.Encoding]::ASCII.GetBytes($msg)
            $header = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain`r`nContent-Length: $($msgBytes.Length)`r`nAccess-Control-Allow-Origin: *`r`nConnection: close`r`n`r`n"
            $hBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
            $stream.Write($hBytes, 0, $hBytes.Length)
            $stream.Write($msgBytes, 0, $msgBytes.Length)
        }
        $stream.Flush()
        $client.Close()
    }
} finally {
    $tcp.Stop()
}
