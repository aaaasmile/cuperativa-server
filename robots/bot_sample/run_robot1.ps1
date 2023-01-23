$env:path = "D:\ruby\ruby_3_2_0\bin;" + $env:path

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Write-host "My directory is $dir"

Push-Location $dir #changing the dir to the script location

ruby.exe .\daemon_robot.rb run

Pop-Location # back to the previous