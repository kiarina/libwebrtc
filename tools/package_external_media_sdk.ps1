param(
 [Parameter(Mandatory=$true)][string]$CoreSource,
 [Parameter(Mandatory=$true)][string]$WrapperSource,
 [Parameter(Mandatory=$true)][string]$SdkRoot,
 [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$inputs=Get-Content -Raw -Encoding UTF8 "$root/integration/windows-x64-inputs.json"|ConvertFrom-Json
if(Test-Path $OutputDirectory){throw 'Use a fresh output directory'}
function SourceHash([string]$path){
 $text=[IO.File]::ReadAllText($path).Replace("`r`n","`n")
 $hash=[Security.Cryptography.SHA256]::Create()
 try{return ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-','').ToLower()}finally{$hash.Dispose()}
}
foreach($item in $inputs.coreChangedProductionFiles.PSObject.Properties){if((SourceHash (Join-Path $CoreSource $item.Name)) -ne $item.Value){throw "Core source mismatch: $($item.Name)"}}
foreach($item in $inputs.wrapperProductionFiles.PSObject.Properties){if((SourceHash (Join-Path $WrapperSource $item.Name)) -ne $item.Value){throw "Wrapper source mismatch: $($item.Name)"}}
foreach($item in $inputs.wrapperBinaryFiles.PSObject.Properties){if((Get-FileHash (Join-Path $WrapperSource $item.Name)).Hash.ToLower() -ne $item.Value){throw "Wrapper binary input mismatch: $($item.Name)"}}
if((Get-FileHash "$SdkRoot/lib/libwebrtc.dll").Hash.ToLower() -ne $inputs.dllSha256){throw 'Candidate DLL mismatch'}
if((Get-FileHash "$SdkRoot/lib/libwebrtc.dll.lib").Hash.ToLower() -ne $inputs.importLibrarySha256){throw 'Import library mismatch'}
foreach($item in $inputs.wrapperProductionFiles.PSObject.Properties){if($item.Name.StartsWith('include/')){if((SourceHash (Join-Path $SdkRoot $item.Name)) -ne $item.Value){throw "SDK header mismatch: $($item.Name)"}}}
$stage=Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) 'libwebrtc'
New-Item -ItemType Directory -Force "$stage/lib","$stage/licenses"|Out-Null
Copy-Item -Recurse "$SdkRoot/include" $stage
Copy-Item "$SdkRoot/lib/libwebrtc.dll","$SdkRoot/lib/libwebrtc.dll.lib" "$stage/lib"
Copy-Item "$CoreSource/LICENSE" "$stage/licenses/LICENSE-WebRTC"
Copy-Item "$CoreSource/NOTICE" "$stage/licenses/NOTICE-WebRTC"
Copy-Item "$WrapperSource/LICENSE" "$stage/licenses/LICENSE-libwebrtc"
Copy-Item "$WrapperSource/NOTICE" "$stage/licenses/NOTICE-libwebrtc"
Copy-Item "$root/integration/windows-x64-inputs.json" "$stage/sdk-inputs.json"
$files=[ordered]@{}
Get-ChildItem -Recurse -File $stage|Sort-Object FullName|ForEach-Object{$name=$_.FullName.Substring($stage.Length+1).Replace('\','/');$files[$name]=(Get-FileHash $_.FullName).Hash.ToLower()}
[ordered]@{schemaVersion=1;target='windows-x64';files=$files;coreIntegration=$inputs.coreIntegration;wrapperProposal=$inputs.wrapperProposal}|ConvertTo-Json -Depth 6|Set-Content -Encoding ASCII "$stage/sdk-manifest.json"
$archive=Join-Path (Split-Path $stage) 'libwebrtc-win-x64-release.zip'
Add-Type -AssemblyName System.IO.Compression
$stream=[IO.File]::Open($archive,[IO.FileMode]::CreateNew)
$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
try {
 foreach($file in (Get-ChildItem -Recurse -File $stage|Sort-Object FullName)) {
  $name='libwebrtc/'+$file.FullName.Substring($stage.Length+1).Replace('\','/')
  $entry=$zip.CreateEntry($name,[IO.Compression.CompressionLevel]::Optimal)
  $entry.LastWriteTime=[DateTimeOffset]::new(1980,1,1,0,0,0,[TimeSpan]::Zero)
  $input=[IO.File]::OpenRead($file.FullName);$output=$entry.Open()
  try{$input.CopyTo($output)}finally{$output.Dispose();$input.Dispose()}
 }
}finally{$zip.Dispose();$stream.Dispose()}
@{archive=[IO.Path]::GetFileName($archive);archiveSha256=(Get-FileHash $archive).Hash.ToLower();dllSha256=$inputs.dllSha256;importLibrarySha256=$inputs.importLibrarySha256}|ConvertTo-Json|Set-Content -Encoding ASCII (Join-Path (Split-Path $stage) 'archive-manifest.json')
Write-Output 'Verified and packaged candidate SDK'
