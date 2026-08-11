param(
    [string]$Name = "World",
    [string]$Payload = "",
    [switch]$EmitError,
    [int]$ReturnCode = 0,
    [switch]$EmitUtf8Text
)

# Deterministic stdout content for parser/logging checks.
Write-Output "PS_TEST_START"
Write-Output "Name=$Name"
if ($Payload -ne "") {
    Write-Output "Payload=$Payload"
}

if ($EmitUtf8Text) {
    Write-Output "UTF8_TEXT=aeoeuess"
}

if ($EmitError) {
    # Explicit stderr line to verify stderr capture in perl module.
    [Console]::Error.WriteLine("PS_TEST_ERROR=Simulated error output")
}

Write-Output "PS_TEST_END"
exit $ReturnCode
