# host_agent.ps1 - Windows-side bridge agent for RE-Stack.
# Binds 127.0.0.1:27044 (localhost only); the container reaches it through the
# windows-agent socat relay. Endpoints: /health /processes /modules?pid= /run /exec
# SECURITY: /exec runs commands on the host - keep this machine trusted.
param([int]$Port = 27044)
$ErrorActionPreference = 'Stop'
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$listener.Start()
Write-Host "[host-agent] listening on 127.0.0.1:$Port"
while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $path = $req.Url.AbsolutePath.TrimEnd('/')
    $q = $req.QueryString
    try {
      switch -Regex ($path) {
        '^/health$'    { $out = @{ ok = $true; host = $env:COMPUTERNAME; user = $env:USERNAME; arch = $env:PROCESSOR_ARCHITECTURE; time = (Get-Date).ToString('o') } | ConvertTo-Json -Compress }
        '^/processes$' { $out = (Get-Process | Select-Object Id, ProcessName, Path | ConvertTo-Json -Compress) }
        '^/modules$'   { $procId = [int]$q['pid']; $out = ((Get-Process -Id $procId -ErrorAction Stop).Modules | Select-Object ModuleName, FileName | ConvertTo-Json -Compress) }
        '^/run$'       { $p = $q['path']; $a = $q['args']; if ($a) { Start-Process -FilePath $p -ArgumentList $a } else { Start-Process -FilePath $p }; $out = (@{ ok = $true; started = $p } | ConvertTo-Json -Compress) }
        '^/exec$'      { $c = $q['cmd']; $out = (cmd /c $c 2>&1 | Out-String) }
        default        { $res.StatusCode = 404; $out = '{"error":"not found"}' }
      }
    } catch { $out = (@{ ok = $false; error = $_.Exception.Message } | ConvertTo-Json -Compress) }
    $bytes = [Text.Encoding]::UTF8.GetBytes($out)
    $res.ContentType = 'application/json'
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.Close()
  } catch { }
}
