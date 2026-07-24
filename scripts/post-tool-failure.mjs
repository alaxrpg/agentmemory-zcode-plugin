#!/usr/bin/env node
import "./env-loader.mjs";

/**
 * PostToolUseFailure hook script for ZCode agentmemory plugin.
 * Captures tool failure events and reports to agentmemory.
 */
function isSdkChildContext(payload) {
  if (process.env["AGENTMEMORY_SDK_CHILD"] === "1") return true;
  if (!payload || typeof payload !== "object") return false;
  return payload.entrypoint === "sdk-ts";
}

const REST_URL = process.env["AGENTMEMORY_URL"] || "http://localhost:3111";
const SECRET = process.env["AGENTMEMORY_SECRET"] || "";

function authHeaders() {
  const h = { "Content-Type": "application/json" };
  if (SECRET) h["Authorization"] = `Bearer ${SECRET}`;
  return h;
}

async function main() {
  let input = "";
  for await (const chunk of process.stdin) input += chunk;

  let data;
  try {
    data = JSON.parse(input);
  } catch {
    return;
  }
  if (isSdkChildContext(data)) return;

  const sessionId = data.session_id || data.sessionId || "unknown";
  const toolName = data.tool_name ?? data.toolName;
  const toolInput = data.tool_input ?? data.toolArgs;
  const error = data.error ?? data.tool_error ?? null;

  fetch(`${REST_URL}/agentmemory/observe`, {
    method: "POST",
    headers: authHeaders(),
    body: JSON.stringify({
      hookType: "post_tool_use_failure",
      sessionId,
      cwd: data.cwd || process.cwd(),
      timestamp: new Date().toISOString(),
      data: {
        tool_name: toolName,
        tool_input: toolInput,
        error: typeof error === "string" ? error.slice(0, 4000) : "[error captured]",
      },
    }),
    signal: AbortSignal.timeout(1500),
  }).catch(() => {});

  setTimeout(() => process.exit(0), 500).unref();
}

main();
