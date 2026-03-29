$root = "c:\Users\lenny\OneDrive\Documentos\GitHub\nuxchain-protocol"

# 1. Rename Skills folder → NuxPower
Rename-Item "$root\contracts\Skills" "$root\contracts\NuxPower"

# 2. Rename the .sol files
Rename-Item "$root\contracts\NuxPower\IndividualSkillsMarketplace.sol" "NuxPowerMarketplace.sol"
Rename-Item "$root\contracts\NuxPower\IndividualSkillsMarketplaceImpl.sol" "NuxPowerMarketplaceImpl.sol"
Rename-Item "$root\contracts\NuxPower\MarketplaceSkillsNft.sol" "NuxPowerNft.sol"

# 3. Rename interface  
Rename-Item "$root\contracts\interfaces\IIndividualSkills.sol" "INuxPower.sol"

# 4. Global text replacement: contract/interface names + references
$files = @()
$files += Get-ChildItem "$root\contracts"  -Recurse -Include "*.sol"
$files += Get-ChildItem "$root\test"       -Recurse -Include "*.cjs","*.js"
$files += Get-ChildItem "$root\scripts"    -Recurse -Include "*.cjs","*.js"
$files += Get-Item "$root\hardhat.config.cjs"

foreach ($f in $files) {
    $txt = [System.IO.File]::ReadAllText($f.FullName)
    $orig = $txt

    # Specific long names first
    $txt = $txt -replace "IndividualSkillsMarketplaceImpl", "NuxPowerMarketplaceImpl"
    $txt = $txt -replace "IndividualSkillsMarketplace",     "NuxPowerMarketplace"
    $txt = $txt -replace "MarketplaceSkillsNft",            "NuxPowerNft"
    $txt = $txt -replace "IIndividualSkills",               "INuxPower"
    $txt = $txt -replace "IndividualSkill\b",               "NuxPower"
    $txt = $txt -replace "individualSkill",                 "nuxPower"
    $txt = $txt -replace "individual skill",                "NuxPower"
    $txt = $txt -replace "Individual Skills",               "NuxPower"
    $txt = $txt -replace "IndividualSkill",                 "NuxPower"
    $txt = $txt -replace "Skills Marketplace",              "NuxPower Marketplace"
    $txt = $txt -replace "skills marketplace",              "NuxPower marketplace"
    
    if ($txt -ne $orig) {
        [System.IO.File]::WriteAllText($f.FullName, $txt)
        Write-Host "Updated: $($f.Name)"
    }
}

Write-Host "Done."
