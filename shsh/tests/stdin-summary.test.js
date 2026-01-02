const { describe, it } = require('node:test');
const assert = require('node:assert');

// Since summarizeStdin isn't exported, we'll extract and test the logic
function summarizeStdin(stdinData) {
  const SMALL_THRESHOLD = 5 * 1024;   // 5KB - send full
  const MEDIUM_THRESHOLD = 50 * 1024; // 50KB - smart sample

  if (stdinData.length <= SMALL_THRESHOLD) {
    return stdinData; // Send full data for small inputs
  }

  const lines = stdinData.split('\n');
  const lineCount = lines.length;

  if (stdinData.length <= MEDIUM_THRESHOLD) {
    // Medium size: show head + tail
    const headLines = 30;
    const tailLines = 30;
    const omitted = lineCount - headLines - tailLines;

    if (omitted <= 0) {
      return stdinData; // Not enough lines to summarize
    }

    return lines.slice(0, headLines).join('\n') +
           `\n\n... (${omitted} lines omitted) ...\n\n` +
           lines.slice(-tailLines).join('\n');
  }

  // Large data: aggressive summary with metadata
  const sampleSize = 15;
  return `[Stdin contains ${lineCount} lines, ${(stdinData.length / 1024).toFixed(1)}KB]

First ${sampleSize} lines:
${lines.slice(0, sampleSize).join('\n')}

Last ${sampleSize} lines:
${lines.slice(-sampleSize).join('\n')}

[Provide a command that processes all ${lineCount} lines from stdin]`;
}

describe('stdin summarization', () => {
  it('sends small stdin unchanged (<5KB)', () => {
    const small = 'line1\nline2\nline3';
    const result = summarizeStdin(small);

    assert.strictEqual(result, small, 'Small input should be unchanged');
    assert(result.length < 5 * 1024, 'Should be under 5KB');
  });

  it('sends medium stdin with head+tail (5-50KB)', () => {
    // Create ~10KB of data (1000 lines)
    const lines = Array(1000).fill(0).map((_, i) => `line ${i}`);
    const medium = lines.join('\n');
    const result = summarizeStdin(medium);

    assert(medium.length > 5 * 1024, 'Input should be over 5KB');
    assert(medium.length < 50 * 1024, 'Input should be under 50KB');
    assert(result.includes('lines omitted'), 'Should include omission notice');
    assert(result.includes('line 0'), 'Should include first line');
    assert(result.includes('line 999'), 'Should include last line');
    assert(result.length < medium.length, 'Result should be smaller than input');
  });

  it('sends large stdin with aggressive summary (>50KB)', () => {
    // Create ~200KB of data (10000 lines)
    const lines = Array(10000).fill(0).map((_, i) => `/path/to/file${i}.txt`);
    const large = lines.join('\n');
    const result = summarizeStdin(large);

    assert(large.length > 50 * 1024, 'Input should be over 50KB');
    assert(result.includes('10000 lines'), 'Should include line count');
    assert(result.includes('KB'), 'Should include size in KB');
    assert(result.includes('/path/to/file0.txt'), 'Should include first line');
    assert(result.includes('/path/to/file9999.txt'), 'Should include last line');
    assert(result.length < large.length / 10, 'Result should be dramatically smaller');
  });

  it('handles edge case at 5KB threshold', () => {
    // Create data just under 5KB
    const justUnder = 'x'.repeat(5 * 1024 - 1);
    const resultUnder = summarizeStdin(justUnder);
    assert.strictEqual(resultUnder, justUnder, 'Data just under threshold should be unchanged');

    // Create data just over 5KB with enough lines to summarize
    const lines = Array(200).fill(0).map((_, i) => 'x'.repeat(30)); // ~6KB
    const justOver = lines.join('\n');
    const resultOver = summarizeStdin(justOver);
    assert.notStrictEqual(resultOver, justOver, 'Data over threshold should be summarized');
    assert(resultOver.includes('lines omitted'), 'Should be summarized with omission notice');
  });

  it('handles edge case at 50KB threshold', () => {
    // Create data just under 50KB
    const linesUnder = Array(2000).fill(0).map((_, i) => 'x'.repeat(20)); // ~40KB
    const justUnder = linesUnder.join('\n');
    const resultUnder = summarizeStdin(justUnder);
    assert(resultUnder.includes('lines omitted'), 'Should use medium summarization');
    assert(!resultUnder.includes('Stdin contains'), 'Should not use aggressive summarization');

    // Create data just over 50KB
    const linesOver = Array(3000).fill(0).map((_, i) => 'x'.repeat(20)); // ~60KB
    const justOver = linesOver.join('\n');
    const resultOver = summarizeStdin(justOver);
    assert(resultOver.includes('Stdin contains'), 'Should use aggressive summarization');
    assert(resultOver.includes('3000 lines'), 'Should include line count');
  });

  it('preserves content quality in summaries', () => {
    // Test with 10k file paths (realistic scenario user mentioned)
    const filePaths = Array(10000).fill(0).map((_, i) => `/home/user/docs/file${i}.pdf`);
    const data = filePaths.join('\n');
    const result = summarizeStdin(data);

    // Verify AI still gets useful context
    assert(result.includes('/home/user/docs/file0.pdf'), 'First file should be visible');
    assert(result.includes('/home/user/docs/file9999.pdf'), 'Last file should be visible');
    assert(result.includes('10000 lines'), 'Total count should be visible');

    // Verify dramatic size reduction
    const compressionRatio = result.length / data.length;
    assert(compressionRatio < 0.05, `Should compress to <5% of original (got ${(compressionRatio * 100).toFixed(1)}%)`);
  });
});
