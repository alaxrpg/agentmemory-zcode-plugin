#!/usr/bin/env node
import "./env-loader.mjs";
//#region src/hooks/stop.ts
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
	fetch(`${REST_URL}/agentmemory/summarize`, {
		method: "POST",
		headers: authHeaders(),
		body: JSON.stringify({ sessionId }),
		signal: AbortSignal.timeout(12e4)
	}).catch(() => {});
	// session/end intentionally omitted: ZCode context continuation
	// fires Stop hook prematurely, marking sessions as completed
	// while they're still active. Watchdog (every hour) cleans up
	// sessions idle > 6h.
	setTimeout(() => process.exit(0), 1500).unref();
}
main();

//#endregion
export {  };
//# sourceMappingURL=stop.mjs.map