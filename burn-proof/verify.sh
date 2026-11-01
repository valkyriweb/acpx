set -euo pipefail
mkdir -p /tmp/depsec-node /tmp/depsec-pnpm
curl -fsSL https://nodejs.org/dist/v24.11.1/node-v24.11.1-linux-x64.tar.gz -o /tmp/depsec-node.tar.gz
curl -fsSL https://nodejs.org/dist/v24.11.1/SHASUMS256.txt | grep ' node-v24.11.1-linux-x64.tar.gz$' | sed 's@node-v24.11.1-linux-x64.tar.gz@/tmp/depsec-node.tar.gz@' | sha256sum -c -
tar -xzf /tmp/depsec-node.tar.gz -C /tmp/depsec-node --strip-components=1
export PATH=/tmp/depsec-node/bin:/tmp/depsec-pnpm/node_modules/.bin:$PATH
export CI=true DO_NOT_TRACK=1 HUSKY=0
npm install --prefix /tmp/depsec-pnpm --no-audit --no-fund pnpm@10.23.0
trap 'cp /tmp/acpx-*-audit.json burn-proof/ 2>/dev/null || true; tar -czf burn-proof/result.tar.gz package.json pnpm-lock.yaml package-lock.json burn-proof/*.json 2>/dev/null || true' EXIT
pnpm update --depth Infinity
npm audit fix --package-lock-only --ignore-scripts --no-fund || test "$?" -eq 1
pnpm audit --json > /tmp/acpx-pnpm-audit.json || test "$?" -eq 1
npm audit --json > /tmp/acpx-npm-audit.json || test "$?" -eq 1
node --input-type=module -e 'import fs from "node:fs";for(const m of ["npm","pnpm"]){const a=JSON.parse(fs.readFileSync(`/tmp/acpx-${m}-audit.json`));console.log(m,a.metadata.vulnerabilities);if(a.metadata.vulnerabilities.high || a.metadata.vulnerabilities.critical)process.exitCode=1}'
pnpm run check
pnpm run check:docs
pnpm run conformance:run -- --case acp.v1.initialize.handshake
