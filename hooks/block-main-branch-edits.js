#!/usr/bin/env node
'use strict';

const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const MUTATING_SUBCOMMANDS = [
  'commit', 'stash', 'merge', 'rebase', 'cherry-pick', 'revert', 'reset',
  'checkout', 'switch', 'restore', 'push', 'pull'
];

const DEV_PROJECT_MARKERS = [
  'package.json', 'pyproject.toml', 'requirements.txt', 'setup.py',
  'Pipfile', 'environment.yml', 'go.mod', 'Cargo.toml', 'pom.xml',
  'build.gradle', 'build.gradle.kts', 'Gemfile', 'composer.json'
];

function gitOutput(dir, args) {
  try {
    return execFileSync('git', ['-C', dir, ...args], { encoding: 'utf8' }).trim();
  } catch (e) {
    return '';
  }
}

function splitCommandSegments(command) {
  return command.split(/&&|\|\||;|\n|\|/);
}

function findGitSubcommand(segment) {
  const match = segment.match(/\bgit\b(.*)/s);
  if (!match) return null;
  const tokens = match[1].trim().split(/\s+/).filter(Boolean);
  for (const token of tokens) {
    if (!token.startsWith('-')) return { subcommand: token, segment };
  }
  return null;
}

function isMutatingSegment(parsed) {
  const { subcommand, segment } = parsed;
  if (MUTATING_SUBCOMMANDS.includes(subcommand)) return true;
  if (subcommand === 'clean' && /(-f|--force|-fd|-fx|-df|-xf)/.test(segment)) return true;
  if (subcommand === 'branch' && /((^|\s)-D(\s|$))|(--delete\s+--force)|(--force\s+--delete)/.test(segment)) return true;
  return false;
}

function findMutatingSegment(command) {
  for (const segment of splitCommandSegments(command)) {
    const parsed = findGitSubcommand(segment);
    if (parsed && isMutatingSegment(parsed)) return segment.trim();
  }
  return null;
}

function deny(reason) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason: reason
    }
  }));
}

let raw = '';
process.stdin.on('data', chunk => { raw += chunk; });
process.stdin.on('end', () => {
  let payload;
  try {
    payload = JSON.parse(raw);
  } catch (e) {
    process.exit(0);
  }

  const toolName = payload.tool_name || '';
  if (toolName !== 'Write' && toolName !== 'Edit' && toolName !== 'Bash') {
    process.exit(0);
  }

  const filePath = (payload.tool_input && payload.tool_input.file_path) || '';
  const command = (payload.tool_input && payload.tool_input.command) || '';
  const sessionCwd = payload.cwd || '';

  let targetDir;
  if (toolName === 'Bash') {
    targetDir = sessionCwd || process.cwd();
  } else {
    const fileDir = filePath ? path.dirname(filePath) : '';
    targetDir = (fileDir && fs.existsSync(fileDir) && fs.statSync(fileDir).isDirectory())
      ? fileDir
      : process.cwd();
  }

  const gitDir = gitOutput(targetDir, ['rev-parse', '--git-dir']);
  if (!gitDir) process.exit(0);

  const branch = gitOutput(targetDir, ['symbolic-ref', '--quiet', '--short', 'HEAD']);
  if (branch !== 'main' && branch !== 'master') process.exit(0);

  const repoRoot = gitOutput(targetDir, ['rev-parse', '--show-toplevel']);
  const isDevProject = repoRoot
    ? DEV_PROJECT_MARKERS.some(marker => fs.existsSync(path.join(repoRoot, marker)))
    : false;
  if (!isDevProject) process.exit(0);

  if (toolName === 'Write' || toolName === 'Edit') {
    deny(
      `Refusing to edit ${filePath}: currently checked out on branch ${branch}. ` +
      'Create a worktree/branch for this task first (see superpowers:using-git-worktrees) ' +
      'instead of editing the shared main branch directly.'
    );
    return;
  }

  const matchedSegment = findMutatingSegment(command);
  if (matchedSegment) {
    deny(
      `Refusing to run "${matchedSegment}": currently checked out on branch ${branch}. ` +
      'This repo uses git worktrees for isolation - create one first, e.g. ' +
      '"git worktree add .worktrees/<branch-name> -b <branch-name>", then retry this command inside that worktree.'
    );
  } else {
    process.exit(0);
  }
});
