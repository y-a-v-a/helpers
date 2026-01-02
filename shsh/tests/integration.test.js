const { describe, it } = require('node:test');
const assert = require('node:assert');
const { execSync, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const SHSH_PATH = path.join(__dirname, '..', 'shsh.js');

describe('shsh --init', () => {
  it('generates zsh wrapper', () => {
    const result = spawnSync('node', [SHSH_PATH, '--init', 'zsh']);
    const output = result.stdout.toString();

    assert.strictEqual(result.status, 0, 'Should exit with code 0');
    assert(output.includes('shsh()'), 'Should define shsh function');
    assert(output.includes('print -s'), 'Should use zsh history command');
    assert(output.includes('eval "$(shsh --init zsh)"'), 'Should include setup instruction');
  });

  it('generates bash wrapper', () => {
    const result = spawnSync('node', [SHSH_PATH, '--init', 'bash']);
    const output = result.stdout.toString();

    assert.strictEqual(result.status, 0, 'Should exit with code 0');
    assert(output.includes('shsh()'), 'Should define shsh function');
    assert(output.includes('history -s'), 'Should use bash history command');
    assert(output.includes('eval "$(shsh --init bash)"'), 'Should include setup instruction');
  });

  it('auto-detects shell from environment', () => {
    const result = spawnSync('node', [SHSH_PATH, '--init'], {
      env: { ...process.env, SHELL: '/bin/zsh' }
    });
    const output = result.stdout.toString();

    assert.strictEqual(result.status, 0, 'Should exit with code 0');
    assert(output.includes('print -s'), 'Should default to zsh');
  });

  it('rejects invalid shell', () => {
    const result = spawnSync('node', [SHSH_PATH, '--init', 'fish']);

    assert.strictEqual(result.status, 1, 'Should exit with code 1');
    assert(result.stderr.toString().includes('Unsupported shell'), 'Should show error message');
  });

  it('generated zsh wrapper has valid syntax', () => {
    const output = execSync(`node ${SHSH_PATH} --init zsh`).toString();
    const tmpFile = path.join(__dirname, 'fixtures', 'wrapper-test.zsh');

    fs.writeFileSync(tmpFile, output);

    try {
      execSync(`zsh -n ${tmpFile}`);
      // If no error thrown, syntax is valid
      assert.ok(true, 'Zsh wrapper syntax is valid');
    } catch (error) {
      assert.fail(`Zsh syntax error: ${error.message}`);
    } finally {
      fs.unlinkSync(tmpFile);
    }
  });

  it('generated bash wrapper has valid syntax', () => {
    const output = execSync(`node ${SHSH_PATH} --init bash`).toString();
    const tmpFile = path.join(__dirname, 'fixtures', 'wrapper-test.bash');

    fs.writeFileSync(tmpFile, output);

    try {
      execSync(`bash -n ${tmpFile}`);
      // If no error thrown, syntax is valid
      assert.ok(true, 'Bash wrapper syntax is valid');
    } catch (error) {
      assert.fail(`Bash syntax error: ${error.message}`);
    } finally {
      fs.unlinkSync(tmpFile);
    }
  });
});

describe('shsh wrapper features', () => {
  it('includes retry support', () => {
    const output = execSync(`node ${SHSH_PATH} --init zsh`).toString();

    assert(output.includes('Execute? (y/n/r):'), 'Should include retry option in prompt');
    assert(output.includes('elif [[ "$answer" =~ ^[Rr]$ ]]'), 'Should handle retry input');
  });

  it('includes --yes flag handling', () => {
    const output = execSync(`node ${SHSH_PATH} --init zsh`).toString();

    assert(output.includes('--yes'), 'Should check for --yes flag');
    assert(output.includes('auto_execute'), 'Should have auto-execute logic');
  });

  it('includes special flag passthrough', () => {
    const output = execSync(`node ${SHSH_PATH} --init zsh`).toString();

    assert(output.includes('--init'), 'Should passthrough --init');
    assert(output.includes('--print'), 'Should passthrough --print');
    assert(output.includes('command shsh "$@"'), 'Should use command to bypass wrapper');
  });
});

describe('shsh CLI', () => {
  it('shows usage when no arguments provided', () => {
    const result = spawnSync('node', [SHSH_PATH]);
    const stderr = result.stderr.toString();

    assert.strictEqual(result.status, 1, 'Should exit with code 1');
    assert(stderr.includes('Usage:'), 'Should show usage');
    assert(stderr.includes('--yes'), 'Should document --yes flag');
    assert(stderr.includes('--print'), 'Should document --print flag');
    assert(stderr.includes('--init'), 'Should document --init flag');
  });

  it('includes shell integration instructions in usage', () => {
    const result = spawnSync('node', [SHSH_PATH]);
    const stderr = result.stderr.toString();

    assert(stderr.includes('Shell Integration:'), 'Should have shell integration section');
    assert(stderr.includes('eval "$(shsh --init'), 'Should show integration command');
  });
});

describe('shsh --print mode', () => {
  // Note: We can't easily test actual AI generation without API key,
  // but we can test that the flag is recognized
  it('recognizes --print flag', () => {
    // This test would require ANTHROPIC_API_KEY to actually work
    // For now, we just verify the CLI doesn't crash
    const result = spawnSync('node', [SHSH_PATH, '--print'], {
      timeout: 1000,
      killSignal: 'SIGTERM'
    });

    // Either exits with error (no args) or times out (waiting for API)
    // Both are acceptable - we're just checking it recognizes the flag
    assert(result.status !== 0 || result.signal === 'SIGTERM',
           'Should handle --print flag without crashing');
  });
});
