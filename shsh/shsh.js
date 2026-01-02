#!/usr/bin/env node

const Anthropic = require('@anthropic-ai/sdk');
const { spawn } = require('child_process');
const readline = require('readline');
const os = require('os');
const path = require('path');

const RETRY_ADDITION = "\nThe previous command suggestion didn't work or wasn't what I needed. Please provide an alternative approach.";

const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

function buildSystemPrompt(stdinData = null) {
  let prompt = `You are a shell command generator for ${os.platform()} systems.
Generate only the shell command needed to accomplish the user's request.`;

  if (stdinData) {
    prompt += `\n\nThe user has piped the following data as input:
---
${stdinData}
---

Generate a command that works with this piped data.`;
  }

  prompt += `\nOutput ONLY the command itself, with no explanations, markdown formatting, or additional text.
The command will be executed in: ${process.cwd()}`;

  return prompt;
}

async function generateCommand(userPrompt, stdinData = null, isRetry = false) {
  const prompt = isRetry ? userPrompt + RETRY_ADDITION : userPrompt;

  const message = await client.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 1024,
    system: buildSystemPrompt(stdinData),
    messages: [{
      role: 'user',
      content: prompt
    }]
  });

  return message.content[0].text.trim();
}

function executeCommand(command, stdinBuffer = null) {
  return new Promise((resolve, reject) => {
    const shell = process.env.SHELL || '/bin/sh';

    // If we have stdin data, pipe it to the command
    // Otherwise, inherit stdin (for interactive commands)
    const stdioConfig = stdinBuffer ? ['pipe', 'inherit', 'inherit'] : 'inherit';

    const child = spawn(shell, ['-c', command], {
      stdio: stdioConfig,
      cwd: process.cwd()
    });

    // Write buffered stdin to child process
    if (stdinBuffer) {
      child.stdin.write(stdinBuffer);
      child.stdin.end();
    }

    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`Command exited with code ${code}`));
      }
    });

    child.on('error', (err) => {
      reject(err);
    });
  });
}

function prompt(question) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.toLowerCase().trim());
    });
  });
}

async function readStdin() {
  const MAX_SIZE = 500 * 1024 * 1024;  // 500MB safe limit

  return new Promise((resolve, reject) => {
    let data = '';
    let size = 0;
    process.stdin.setEncoding('utf8');

    process.stdin.on('data', chunk => {
      size += Buffer.byteLength(chunk, 'utf8');

      if (size > MAX_SIZE) {
        process.stdin.pause();
        reject(new Error(
          `Stdin exceeds 500MB limit. ` +
          `For large data, redirect from file: shsh "command" < file.txt`
        ));
        return;
      }

      data += chunk;
    });

    process.stdin.on('end', () => {
      resolve(data.trim());
    });

    process.stdin.on('error', reject);
  });
}

function determineMode(isPiped, flags) {
  if (flags.print) return 'print-only';
  if (isPiped && !flags.yes) return 'print-only';
  if (flags.yes) return 'auto-execute';
  return 'interactive';
}

async function main() {
  const args = process.argv.slice(2);

  // Parse flags
  const flags = {
    yes: args.includes('--yes') || args.includes('-y'),
    print: args.includes('--print') || args.includes('-p')
  };

  // Extract user request (non-flag arguments)
  const userRequest = args
    .filter(arg => !arg.startsWith('-'))
    .join(' ');

  // Detect if stdin is piped
  const isPiped = !process.stdin.isTTY;
  let stdinData = null;

  // Read stdin if piped
  if (isPiped) {
    stdinData = await readStdin();
  }

  // Validate arguments
  if (!userRequest) {
    console.error('Usage: shsh [options] "<natural language description>"');
    console.error('');
    console.error('Options:');
    console.error('  --yes, -y     Auto-execute without confirmation');
    console.error('  --print, -p   Print command only, do not execute');
    console.error('');
    console.error('Examples:');
    console.error('  shsh "find all jpeg images"');
    console.error('  shsh "find all jpeg images" | shsh "count output lines"');
    console.error('  echo "file1\\nfile2" | shsh --yes "delete these files"');
    process.exit(1);
  }

  // Determine execution mode
  const mode = determineMode(isPiped, flags);

  try {
    if (mode === 'interactive') {
      // Interactive mode: existing behavior with retry loop
      let currentRequest = userRequest;

      while (true) {
        const command = await generateCommand(currentRequest, stdinData, currentRequest !== userRequest);

        console.log(`Generated command:\n${command}\n`);

        const answer = await prompt('Execute? (y/n/r): ');

        if (answer === 'y' || answer === 'yes') {
          console.log('');
          await executeCommand(command, stdinData);
          break;
        } else if (answer === 'r' || answer === 'retry') {
          currentRequest = userRequest;
          continue;
        } else {
          console.log('Aborted.');
          break;
        }
      }
    } else if (mode === 'print-only') {
      // Print-only mode: generate and print command without execution
      const command = await generateCommand(userRequest, stdinData);
      console.log(command);
    } else if (mode === 'auto-execute') {
      // Auto-execute mode: generate, print, and execute
      const command = await generateCommand(userRequest, stdinData);
      console.log(command);
      await executeCommand(command, stdinData);
    }
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

main();