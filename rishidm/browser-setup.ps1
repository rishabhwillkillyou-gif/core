# RishiDM browser setup. This is a preview-only guided flow.
# Extensions must be approved by the user; no policy/forced installation.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$root=Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'BrowserExtension'
$map=@{
 Chrome=@{folder='Chrome';url='chrome://extensions';exe='chrome.exe'}
 Edge=@{folder='Chrome';url='edge://extensions';exe='msedge.exe'}
 Brave=@{folder='Chrome';url='brave://extensions';exe='brave.exe'}
 Opera=@{folder='Chrome';url='opera://extensions';exe='opera.exe'}
 Firefox=@{folder='Firefox';url='about:debugging#/runtime/this-firefox';exe='firefox.exe'}
}
function Find-Exe([string]$exe){
 foreach($key in @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$exe","HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$exe")){
  try{$p=(Get-Item $key -ErrorAction Stop).GetValue('');if($p -and (Test-Path $p)){return $p}}catch{}
 }
 $c=Get-Command $exe -ErrorAction SilentlyContinue
 if($c){return $c.Source}
 $bases=@($env:ProgramFiles,[Environment]::GetFolderPath('ProgramFilesX86'),$env:LOCALAPPDATA)
 $suffixes=@{
 'chrome.exe'='Google\Chrome\Application\chrome.exe'
 'msedge.exe'='Microsoft\Edge\Application\msedge.exe'
 'brave.exe'='BraveSoftware\Brave-Browser\Application\brave.exe'
 'opera.exe'='Programs\Opera\opera.exe'
 'firefox.exe'='Mozilla Firefox\firefox.exe'
 }
 foreach($b in $bases){if($b){$p=Join-Path $b $suffixes[$exe];if(Test-Path $p){return $p}}}
 return $null
}
$form=New-Object Windows.Forms.Form
$form.Text='RishiDM - Browser Integration'
$form.Width=650;$form.Height=390
$form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false
$form.Font=New-Object Drawing.Font('Segoe UI',10)
$h=New-Object Windows.Forms.Label
$h.Location=New-Object Drawing.Point(24,18);$h.Size=New-Object Drawing.Size(600,42)
$h.Text='Connect your browser to RishiDM'
$h.Font=New-Object Drawing.Font('Segoe UI',15,[Drawing.FontStyle]::Bold)
$form.Controls.Add($h)
$intro=New-Object Windows.Forms.Label
$intro.Location=New-Object Drawing.Point(24,68);$intro.Size=New-Object Drawing.Size(590,47)
$intro.Text='The Windows integration is installed automatically. Choose your browser and approve the extension once. No commands or account needed.'
$form.Controls.Add($intro)
$combo=New-Object Windows.Forms.ComboBox
$combo.Location=New-Object Drawing.Point(24,132);$combo.Size=New-Object Drawing.Size(170,30)
$combo.DropDownStyle='DropDownList'
[void]$combo.Items.AddRange([object[]]@('Chrome','Edge','Brave','Opera','Firefox'))
$combo.SelectedIndex=0;$form.Controls.Add($combo)
$copy=New-Object Windows.Forms.Button
$copy.Location=New-Object Drawing.Point(208,128);$copy.Size=New-Object Drawing.Size(180,38)
$copy.Text='Copy extension path';$form.Controls.Add($copy)
$open=New-Object Windows.Forms.Button
$open.Location=New-Object Drawing.Point(394,128);$open.Size=New-Object Drawing.Size(226,38)
$open.Text='Open browser extensions';$form.Controls.Add($open)
$instructions=New-Object Windows.Forms.Label
$instructions.Location=New-Object Drawing.Point(24,192);$instructions.Size=New-Object Drawing.Size(585,85)
$form.Controls.Add($instructions)
$status=New-Object Windows.Forms.Label
$status.Location=New-Object Drawing.Point(24,293);$status.Size=New-Object Drawing.Size(585,45)
$status.ForeColor=[Drawing.Color]::DarkSlateGray
$form.Controls.Add($status)
function Refresh-Help{
 if($combo.SelectedItem -eq 'Firefox'){
  $instructions.Text='Firefox preview: Open extensions > Load Temporary Add-on > choose manifest.json from the Firefox extension folder. Temporary add-ons disappear after browser restart; permanent release needs store approval.'
 }else{
  $instructions.Text='Chrome / Edge / Brave / Opera preview: Open extensions > enable Developer mode > Load unpacked. In the folder picker press Ctrl+L, Ctrl+V, Enter and Select Folder. Production store installation will require only Add extension.'
 }
 $status.Text='Browser integration is optional: normal RishiDM file downloads work without it.'
}
$combo.Add_SelectedIndexChanged({Refresh-Help})
$copy.Add_Click({
 $folder=Join-Path $root $map[$combo.SelectedItem].folder
 if(!(Test-Path (Join-Path $folder 'manifest.json'))){
  [Windows.Forms.MessageBox]::Show("Extension package missing: $folder",'RishiDM') | Out-Null;return
 }
 [Windows.Forms.Clipboard]::SetText($folder);$status.Text='Extension path copied. Paste it into the browser folder picker.'
})
$open.Add_Click({
 $b=$map[$combo.SelectedItem];$folder=Join-Path $root $b.folder
 if(!(Test-Path (Join-Path $folder 'manifest.json'))){
  [Windows.Forms.MessageBox]::Show("Extension package missing: $folder",'RishiDM') | Out-Null;return
 }
 [Windows.Forms.Clipboard]::SetText($folder)
 $exe=Find-Exe $b.exe
 if(!$exe){$status.Text='Could not find the browser. Open its extensions page manually; the path is copied.';return}
 try{Start-Process -FilePath $exe -ArgumentList @($b.url);$status.Text='Browser page opened; the extension folder is also copied to clipboard.'}
 catch{$status.Text="Could not open browser: $($_.Exception.Message)"}
})
Refresh-Help
[void]$form.ShowDialog()
