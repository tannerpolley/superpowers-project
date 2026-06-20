import { spawn } from "node:child_process";
import { createReadStream } from "node:fs";
import { mkdir, stat } from "node:fs/promises";
import { createServer } from "node:http";
import { dirname, resolve } from "node:path";

const repoRoot = resolve(new URL("..", import.meta.url).pathname);
const planDir = resolve(process.env.PLAN_DIR || "/repo/plans/agent-native-companion-replacement");
const planKind = process.env.PLAN_KIND || "plan";
const port = Number(process.env.PORT || "8080");
const outPath = "/tmp/agent-native-preview/preview.html";

function run(command, args) {
  return new Promise((resolveRun, reject) => {
    const child = spawn(command, args, {
      cwd: repoRoot,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) {
        resolveRun({ stdout, stderr });
        return;
      }
      reject(new Error(`${command} ${args.join(" ")} failed with ${code}\n${stdout}\n${stderr}`));
    });
  });
}

async function buildPreview() {
  await mkdir(dirname(outPath), { recursive: true });
  await run("agent-native", ["plan", "local", "check", "--dir", planDir]);
  await run("agent-native", [
    "plan",
    "local",
    "preview",
    "--dir",
    planDir,
    "--kind",
    planKind,
    "--out",
    outPath,
  ]);
  await stat(outPath);
}

await buildPreview();

createServer((request, response) => {
  const url = new URL(request.url || "/", `http://127.0.0.1:${port}`);
  if (url.pathname !== "/" && url.pathname !== "/preview.html") {
    response.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
    response.end("Not found");
    return;
  }

  response.writeHead(200, {
    "content-type": "text/html; charset=utf-8",
    "cache-control": "no-store",
  });
  createReadStream(outPath).pipe(response);
}).listen(port, "0.0.0.0", () => {
  console.log(`Agent-Native preview serving ${planDir} at http://0.0.0.0:${port}/preview.html`);
});
