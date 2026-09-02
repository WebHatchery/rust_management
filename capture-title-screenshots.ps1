param(
    [switch]$Publish = $false,
    [int]$WaitSeconds = 12,
    [int]$Width = 1280,
    [int]$Height = 720,
    [string]$OutputDir = "title_screeshots",
    [string]$ProjectThumbnailName = "catalog_thumbnail.png",
    [string]$PreviewRoot = "\\wsl.localhost\Ubuntu\home\kalai\dev\games",
    [string]$BaseUrl = "http://127.0.0.1/games",
    [string]$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
)

$ErrorActionPreference = "Stop"

function Get-PackageName {
    param([string]$CargoTomlPath)

    $content = Get-Content -LiteralPath $CargoTomlPath -Raw
    if ($content -match '(?m)^name\s*=\s*"([^"]+)"') {
        return $matches[1]
    }

    return $null
}

function ConvertTo-UrlSegment {
    param([string]$Segment)
    return [System.Uri]::EscapeDataString($Segment).Replace("%2F", "/")
}

# This script lives in rust_management/; the games live in its parent.
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path -LiteralPath $ChromePath)) {
    throw "Chrome not found at: $ChromePath"
}

$outputPath = Join-Path $root $OutputDir
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

$excludedFolders = @("Release", "template", "target", "assets", "macroquad-toolkit", "publish-logs", ".vscode")
$projects = Get-ChildItem -LiteralPath $root -Directory |
    Where-Object {
        $excludedFolders -notcontains $_.Name -and
        (Test-Path -LiteralPath (Join-Path $_.FullName "publish.ps1")) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName "index.html")) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName "Cargo.toml"))
    } |
    Sort-Object Name

if ($projects.Count -eq 0) {
    throw "No game projects found under $root"
}

$jobs = New-Object System.Collections.Generic.List[object]

foreach ($project in $projects) {
    $packageName = Get-PackageName (Join-Path $project.FullName "Cargo.toml")
    if ([string]::IsNullOrWhiteSpace($packageName)) {
        $packageName = Get-PackageName (Join-Path $project.FullName "client\Cargo.toml")
    }

    if ([string]::IsNullOrWhiteSpace($packageName)) {
        Write-Warning "Skipping $($project.Name): Cargo package name not found"
        continue
    }

    if ($Publish) {
        Write-Host "Publishing preview: $($project.Name)" -ForegroundColor Cyan
        Push-Location $project.FullName
        try {
            & ".\publish.ps1" -WebGLOnly
            if ($LASTEXITCODE -ne 0) {
                throw "publish.ps1 exited with code $LASTEXITCODE"
            }
        } catch {
            Write-Warning "Publish failed for $($project.Name): $($_.Exception.Message)"
            Pop-Location
            continue
        }
        Pop-Location
    }

    $gameSlug = $project.Name
    $previewDir = Join-Path $PreviewRoot $gameSlug
    if (-not (Test-Path -LiteralPath (Join-Path $previewDir "index.html"))) {
        Write-Warning "Skipping $($project.Name): preview index not found at $previewDir"
        continue
    }

    $fileName = "$($project.Name).png"
    $jobs.Add([pscustomobject]@{
        name = $project.Name
        package = $packageName
        url = "$($BaseUrl.TrimEnd('/'))/$(ConvertTo-UrlSegment $gameSlug)/"
        output = (Join-Path $outputPath $fileName)
        projectThumbnail = (Join-Path $project.FullName $ProjectThumbnailName)
    }) | Out-Null
}

if ($jobs.Count -eq 0) {
    throw "No screenshot jobs were created"
}

$jobsPath = Join-Path $env:TEMP ("rustgames-title-screenshot-jobs-{0}.json" -f [DateTimeOffset]::Now.ToUnixTimeMilliseconds())
$jobsJson = $jobs | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText($jobsPath, $jobsJson, [System.Text.UTF8Encoding]::new($false))

$port = 9240
$profile = Join-Path $root ("publish-logs\chrome-title-screenshots-{0}" -f [DateTimeOffset]::Now.ToUnixTimeMilliseconds())
New-Item -ItemType Directory -Force -Path $profile | Out-Null

$chrome = Start-Process -FilePath $ChromePath -ArgumentList @(
    "--headless=new",
    "--remote-debugging-port=$port",
    "--user-data-dir=$profile",
    "--disable-gpu",
    "about:blank"
) -WindowStyle Hidden -PassThru

try {
    $ready = $false
    for ($i = 0; $i -lt 80; $i++) {
        try {
            Invoke-RestMethod "http://127.0.0.1:$port/json/version" -TimeoutSec 1 | Out-Null
            $ready = $true
            break
        } catch {
            Start-Sleep -Milliseconds 250
        }
    }

    if (-not $ready) {
        throw "Chrome DevTools endpoint did not start"
    }

    $nodeScript = @'
const fs = require("node:fs/promises");

const port = Number(process.env.CAPTURE_PORT);
const width = Number(process.env.CAPTURE_WIDTH);
const height = Number(process.env.CAPTURE_HEIGHT);
const waitMs = Number(process.env.CAPTURE_WAIT_MS);
const jobsPath = process.env.CAPTURE_JOBS_PATH;

async function openTab(url) {
  const response = await fetch(`http://127.0.0.1:${port}/json/new?${encodeURIComponent(url)}`, {
    method: "PUT",
  });
  if (!response.ok) {
    throw new Error(`Could not open tab for ${url}: ${response.status}`);
  }
  return await response.json();
}

async function capture(job) {
  const target = await openTab("about:blank");
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  let seq = 0;
  const pending = new Map();
  const exceptions = [];
  const failures = [];
  const badResponses = [];

  function send(method, params = {}) {
    const id = ++seq;
    ws.send(JSON.stringify({ id, method, params }));
    return new Promise((resolve, reject) => {
      pending.set(id, { resolve, reject, method });
    });
  }

  ws.addEventListener("message", (event) => {
    const msg = JSON.parse(event.data);
    if (msg.id && pending.has(msg.id)) {
      const pendingCall = pending.get(msg.id);
      pending.delete(msg.id);
      if (msg.error) {
        pendingCall.reject(new Error(`${pendingCall.method}: ${msg.error.message}`));
      } else {
        pendingCall.resolve(msg.result || {});
      }
      return;
    }

    if (msg.method === "Runtime.exceptionThrown") {
      exceptions.push(msg.params.exceptionDetails.exception?.description || msg.params.exceptionDetails.text);
    } else if (msg.method === "Network.loadingFailed" && !msg.params.canceled) {
      failures.push(`${msg.params.type}: ${msg.params.errorText}`);
    } else if (msg.method === "Network.responseReceived") {
      const response = msg.params.response;
      if (response.status >= 400) {
        badResponses.push(`${response.status} ${response.url}`);
      }
    }
  });

  await new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve, { once: true });
    ws.addEventListener("error", reject, { once: true });
  });

  await send("Runtime.enable");
  await send("Page.enable");
  await send("Network.enable");
  await send("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: false,
  });
  await send("Page.navigate", { url: job.url });
  await new Promise((resolve) => setTimeout(resolve, waitMs));

  const screenshot = await send("Page.captureScreenshot", {
    format: "png",
    captureBeyondViewport: false,
  });
  await fs.writeFile(job.output, Buffer.from(screenshot.data, "base64"));

  try {
    await send("Page.close");
  } catch {}
  try {
    ws.close();
  } catch {}

  return {
    name: job.name,
    url: job.url,
    output: job.output,
    exceptions,
    failures,
    badResponses,
  };
}

(async () => {
  const raw = await fs.readFile(jobsPath, "utf8");
  const jobs = JSON.parse(raw);
  const results = [];
  for (const job of jobs) {
    console.log(`Capturing ${job.name} -> ${job.output}`);
    try {
      results.push(await capture(job));
    } catch (error) {
      results.push({
        name: job.name,
        url: job.url,
        output: job.output,
        error: error.stack || String(error),
      });
    }
  }
  console.log(JSON.stringify(results, null, 2));
})();
'@

    $env:CAPTURE_PORT = $port.ToString()
    $env:CAPTURE_WIDTH = $Width.ToString()
    $env:CAPTURE_HEIGHT = $Height.ToString()
    $env:CAPTURE_WAIT_MS = ($WaitSeconds * 1000).ToString()
    $env:CAPTURE_JOBS_PATH = $jobsPath

    $nodeScript | node -
    if ($LASTEXITCODE -ne 0) {
        throw "Node capture process exited with code $LASTEXITCODE"
    }

    foreach ($job in $jobs) {
        if (Test-Path -LiteralPath $job.output -PathType Leaf) {
            Copy-Item $job.output $job.projectThumbnail -Force
            Write-Host "Copied project thumbnail: $($job.name)\$ProjectThumbnailName" -ForegroundColor Gray
        }
    }
} finally {
    if ($chrome -and -not $chrome.HasExited) {
        Stop-Process -Id $chrome.Id -Force
    }
}

Write-Host "Screenshots written to: $outputPath" -ForegroundColor Green
