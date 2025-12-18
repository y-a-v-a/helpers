#!/usr/bin/env node

const Anthropic = require('@anthropic-ai/sdk');
const { spawn } = require('child_process');
const readline = require('readline');
const os = require('os');
const path = require('path');

const SYSTEM_PROMPT = `You are a shell command generator for ${os.platform()} systems.
Generate only the shell command needed to accomplish the user's request.
Output ONLY the command itself, with no explanations, markdown formatting, or additional text.
The command will be executed in: ${process.cwd()}`;

const RETRY_ADDITION = "\nThe previous command suggestion didn't work or wasn't what I needed. Please provide an alternative approach.";

const client = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

async function generateCommand(userPrompt, isRetry = false) {
  const prompt = isRetry ? userPrompt + RETRY_ADDITION : userPrompt;
  
  const message = await client.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 1024,
    system: SYSTEM_PROMPT,
    messages: [{
      role: 'user',
      content: prompt
    }]
  });

  return message.content[0].text.trim();
}

function executeCommand(command) {
  return new Promise((resolve, reject) => {
    const shell = process.env.SHELL || '/bin/sh';
    const child = spawn(shell, ['-c', command], {
      stdio: 'inherit',
      cwd: process.cwd()
    });

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

async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: shsh "<natural language description>"');
    process.exit(1);
  }

  const userRequest = args.join(' ');
  let currentRequest = userRequest;

  while (true) {
    try {
      const command = await generateCommand(currentRequest, currentRequest !== userRequest);
      
      console.log(`Generated command:\n${command}\n`);
      
      const answer = await prompt('Execute? (y/n/r): ');
      
      if (answer === 'y' || answer === 'yes') {
        console.log('');
        await executeCommand(command);
        break;
      } else if (answer === 'r' || answer === 'retry') {
        currentRequest = userRequest;
        continue;
      } else {
        console.log('Aborted.');
        break;
      }
    } catch (error) {
      console.error(`Error: ${error.message}`);
      process.exit(1);
    }
  }
}

main();