# AssetFare execution-core evidence

This public repository is a minimal, reproducible snapshot of the five unique
Solidity executor implementations deployed by AssetFare. It exists so an agent
can verify source hashes, rebuild artifacts, inspect executable invariants, and
compare expected runtime code with the chain independently of the private API
backend.

This repository is project-authored evidence. It is **not** an independent
third-party audit, formal proof, or guarantee that no unknown defect exists.
The canonical signed evidence bundle publishes limitations and the exact commit
of this repository:

- Safety bundle: <https://api.assetfare.dev/.well-known/assetfare-safety.json>
- Signed binding manifest: <https://api.assetfare.dev/.well-known/assetfare-manifest.json>
- Independent verifier: <https://github.com/assetfare/assetfare-mcp/blob/main/scripts/assetfare-verify.mjs>
- On-chain evidence: <https://assetfare.dev/evidence/>
- Immutable evidence/SBOM release with GitHub build-provenance attestations:
  <https://github.com/assetfare/assetfare-core-evidence/releases/tag/v1.0.0>

## Reproduce

```bash
npm ci --ignore-scripts
node compile_source_only_cctp_executor_v2.mjs
node compile_exact_one_bps_executors.mjs
node compile_destination_executor_v3.mjs
git diff --exit-code -- artifacts/
node agent_safety_invariants_preflight.mjs
```

The invariant output explicitly identifies itself as executable property checks,
not a security audit. The package lock includes upstream Solana, Orca, Raydium,
LayerZero and EVM build dependencies with known npm advisories. The safety bundle
does not claim dependency cleanliness; consumers should rerun current scans.

No private key, wallet credential, deployment authorization, customer session,
or transaction-submission capability belongs in this repository.
