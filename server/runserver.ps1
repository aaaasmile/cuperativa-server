$env:path = "D:\ruby\ruby_3_2_1\bin;" + $env:path

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Write-host "My directory is $dir"

Push-Location $dir #changing the dir to the script location

ruby.exe .\daemon_cup.rb run

Pop-Location # back to the previous