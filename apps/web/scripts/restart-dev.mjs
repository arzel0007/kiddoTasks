#!/usr/bin/env node
/**
 * Kill any Next dev server on 3000/3001, wipe .next, start on 3000 only.
 * Usage: npm run dev:clean
 */
import { execSync, spawn } from "node:child_process";
import { rmSync } from "node:fs";
import { join } from "node:path";

const webRoot = join(import.meta.dirname, "..");

function killPorts() {
  for (const port of [3000, 3001]) {
    try {
      const pids = execSync(`lsof -nP -iTCP:${port} -sTCP:LISTEN -t`, {
        encoding: "utf8",
      })
        .trim()
        .split("\n")
        .filter(Boolean);
      for (const pid of pids) {
        try {
          process.kill(Number(pid), "SIGKILL");
          console.log(`[dev:clean] killed pid ${pid} on :${port}`);
        } catch {
          /* already gone */
        }
      }
    } catch {
      /* port free */
    }
  }
  try {
    execSync("pkill -9 -f next-server || true", { stdio: "ignore" });
    execSync("pkill -9 -f 'next dev' || true", { stdio: "ignore" });
  } catch {
    /* ignore */
  }
}

killPorts();
rmSync(join(webRoot, ".next"), { recursive: true, force: true });
console.log("[dev:clean] starting next dev on http://localhost:3000");
const child = spawn(
  "npx",
  ["next", "dev", "--port", "3000"],
  { cwd: webRoot, stdio: "inherit" }
);
child.on("exit", (code) => process.exit(code ?? 0));
