#!/usr/bin/env node
// coverage-check.js RESULT_JSON BASE_REF
// Fails (exit 1) if any Apex class changed since BASE_REF has coverage below limits.coverageMin.
// Test classes (@IsTest) are skipped. A changed non-test class with no coverage data also fails.
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

function changedClasses(baseRef, root) {
  const out = execFileSync('git', ['diff', '--name-only', '--diff-filter=AMR', `${baseRef}...HEAD`, '--', 'force-app'], { cwd: root, encoding: 'utf8' });
  return out.split('\n').filter((f) => f.endsWith('.cls'));
}

function isTestClass(file) {
  // Strip comments, then look for @IsTest among the annotations before the first `class` keyword.
  const src = fs.readFileSync(file, 'utf8').replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
  const idx = src.search(/\bclass\b/i);
  return idx >= 0 && /@IsTest\b/i.test(src.slice(0, idx));
}

function coverageMap(result) {
  let cov = (((result || {}).result || {}).details || {}).runTestResult;
  cov = cov && cov.codeCoverage ? cov.codeCoverage : [];
  if (!Array.isArray(cov)) cov = [cov];
  const map = {};
  for (const c of cov) {
    const total = Number(c.numLocations) || 0;
    const missed = Number(c.numLocationsNotCovered) || 0;
    map[c.name] = total === 0 ? 100 : Math.floor(((total - missed) / total) * 100);
  }
  return map;
}

function main() {
  const [resultFile, baseRef] = process.argv.slice(2);
  if (!resultFile || !baseRef) { console.error('usage: coverage-check.js RESULT_JSON BASE_REF'); process.exit(2); }
  const root = path.resolve(__dirname, '../..');
  const min = JSON.parse(fs.readFileSync(path.join(root, 'config/pipeline.json'), 'utf8')).limits.coverageMin;
  const cov = coverageMap(JSON.parse(fs.readFileSync(resultFile, 'utf8')));

  const rows = [];
  let failed = 0;
  for (const file of changedClasses(baseRef, root)) {
    if (!fs.existsSync(path.join(root, file))) continue;
    const name = path.basename(file, '.cls');
    if (isTestClass(path.join(root, file))) { rows.push(`| ${name} | test class | skipped |`); continue; }
    const pct = cov[name];
    const ok = pct !== undefined && pct >= min;
    if (!ok) failed++;
    rows.push(`| ${name} | ${pct === undefined ? 'no data' : pct + '%'} | ${ok ? 'pass' : 'FAIL'} |`);
  }

  const md = rows.length
    ? `### Apex coverage of changed classes (minimum ${min}%)\n\n| Class | Coverage | Result |\n| --- | --- | --- |\n${rows.join('\n')}\n`
    : `### Apex coverage\nNo Apex classes changed.\n`;
  console.log(md);
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, md + '\n');
  process.exit(failed ? 1 : 0);
}

if (require.main === module) main();
module.exports = { coverageMap, isTestClass };
