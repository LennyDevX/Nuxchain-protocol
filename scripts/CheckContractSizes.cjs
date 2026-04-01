const fs = require("fs");
const path = require("path");

const ARTIFACTS_DIR = path.join(__dirname, "..", "artifacts", "contracts");
const EIP170_LIMIT = 24_576;

function collectArtifacts(dir, output = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      collectArtifacts(fullPath, output);
      continue;
    }

    if (!entry.isFile() || !entry.name.endsWith(".json")) {
      continue;
    }

    const artifact = JSON.parse(fs.readFileSync(fullPath, "utf8"));
    const deployedBytecode = (artifact.deployedBytecode || "").replace(/^0x/, "");

    if (!deployedBytecode) {
      continue;
    }

    output.push({
      name: path.basename(entry.name, ".json"),
      size: deployedBytecode.length / 2,
      path: path.relative(path.join(__dirname, ".."), fullPath),
    });
  }

  return output;
}

function main() {
  if (!fs.existsSync(ARTIFACTS_DIR)) {
    console.error("Artifacts directory not found. Run a Hardhat compile first.");
    process.exit(1);
  }

  const artifacts = collectArtifacts(ARTIFACTS_DIR).sort((left, right) => right.size - left.size);
  const oversized = artifacts.filter((artifact) => artifact.size > EIP170_LIMIT);
  const topContracts = artifacts.slice(0, 10);

  console.log(`Checked ${artifacts.length} compiled contracts against the EIP-170 runtime limit (${EIP170_LIMIT} bytes).`);
  console.log("");
  console.log("Top deployed bytecode sizes:");
  for (const artifact of topContracts) {
    const delta = artifact.size - EIP170_LIMIT;
    const suffix = delta > 0 ? ` (+${delta})` : "";
    console.log(`- ${artifact.name}: ${artifact.size} bytes${suffix}`);
  }

  if (oversized.length === 0) {
    console.log("");
    console.log("All compiled contracts are within the EIP-170 runtime size limit.");
    return;
  }

  console.error("");
  console.error("Oversized contracts detected:");
  for (const artifact of oversized) {
    console.error(`- ${artifact.name}: ${artifact.size} bytes | ${artifact.path}`);
  }

  process.exit(1);
}

main();