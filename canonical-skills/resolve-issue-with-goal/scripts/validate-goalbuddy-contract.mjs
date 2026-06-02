#!/usr/bin/env node
import { existsSync, readFileSync } from "node:fs";

const statePath = process.argv[2];
if (!statePath) {
  console.error(JSON.stringify({ ok: false, errors: ["Usage: node validate-goalbuddy-contract.mjs docs/goals/<slug>/state.yaml"] }, null, 2));
  process.exit(2);
}
if (!existsSync(statePath)) {
  console.error(JSON.stringify({ ok: false, errors: [`state file not found: ${statePath}`] }, null, 2));
  process.exit(1);
}

const text = readFileSync(statePath, "utf8");
const errors = [];

function clean(value) {
  if (value === undefined || value === null) return null;
  const cleaned = value.replace(/#.*/, "").trim().replace(/^[\'\"]|[\'\"]$/g, "");
  if (cleaned === "" || cleaned === "null") return null;
  if (cleaned === "true") return true;
  if (cleaned === "false") return false;
  if (/^\d+$/.test(cleaned)) return Number(cleaned);
  return cleaned;
}

function topScalar(key) {
  const match = text.match(new RegExp(`^${key}:\\s*(.*?)\\s*$`, "m"));
  return match ? clean(match[1]) : null;
}

function nestedScalar(section, key) {
  const lines = text.split(/\r?\n/);
  let inSection = false;
  for (const line of lines) {
    if (new RegExp(`^${section}:\\s*$`).test(line)) {
      inSection = true;
      continue;
    }
    if (inSection && /^\S/.test(line)) break;
    if (inSection) {
      const match = line.match(new RegExp(`^\\s{2}${key}:\\s*(.*?)\\s*$`));
      if (match) return clean(match[1]);
    }
  }
  return null;
}

function sectionText(section) {
  const lines = text.split(/\r?\n/);
  const start = lines.findIndex((line) => new RegExp(`^${section}:\\s*$`).test(line));
  if (start === -1) return "";
  const collected = [];
  for (let i = start + 1; i < lines.length; i += 1) {
    if (/^\S/.test(lines[i])) break;
    collected.push(lines[i]);
  }
  return collected.join("\n");
}

function taskScalar(task, key) {
  const match = task.raw.match(new RegExp(`^\\s{4}${key}:\\s*(.*?)\\s*$`, "m"));
  return match ? clean(match[1]) : null;
}

function taskList(task, key) {
  const lines = task.raw.split(/\r?\n/);
  const start = lines.findIndex((line) => new RegExp(`^\\s{4}${key}:\\s*$`).test(line));
  if (start === -1) return [];
  const values = [];
  for (let i = start + 1; i < lines.length; i += 1) {
    if (/^\s{4}\S/.test(lines[i])) break;
    const item = lines[i].match(/^\s{6}-\s*(.+?)\s*$/);
    if (item) values.push(clean(item[1]));
  }
  return values.filter((value) => value !== null);
}

function taskReceiptRaw(task) {
  const lines = task.raw.split(/\r?\n/);
  const start = lines.findIndex((line) => /^\s{4}receipt:\s*/.test(line));
  if (start === -1) return null;
  const inline = clean(lines[start].replace(/^\s{4}receipt:\s*/, ""));
  if (inline !== null) return String(inline);
  const receiptLines = [];
  for (let i = start + 1; i < lines.length; i += 1) {
    if (/^\s{4}\S/.test(lines[i])) break;
    receiptLines.push(lines[i]);
  }
  return receiptLines.join("\n");
}

function parseTasks() {
  const body = sectionText("tasks");
  if (!body) return [];
  const lines = body.split(/\r?\n/);
  const tasks = [];
  let current = null;
  let currentLines = [];

  function finish() {
    if (!current) return;
    current.raw = currentLines.join("\n");
    current.assignee = taskScalar(current, "assignee");
    current.status = taskScalar(current, "status");
    current.objective = taskScalar(current, "objective");
    current.allowedFiles = taskList(current, "allowed_files");
    current.verify = taskList(current, "verify");
    current.stopIf = taskList(current, "stop_if");
    current.receiptRaw = taskReceiptRaw(current);
    tasks.push(current);
  }

  for (const line of lines) {
    const idMatch = line.match(/^\s{2}-\s+id:\s*(.+?)\s*$/);
    if (idMatch) {
      finish();
      current = { id: clean(idMatch[1]) };
      currentLines = [line];
      continue;
    }
    if (current) currentLines.push(line);
  }
  finish();
  return tasks;
}

const goalStatus = nestedScalar("goal", "status");
const activeTask = topScalar("active_task");
const tasks = parseTasks();
const allowedAssignees = new Set(["PM", "Scout", "Judge", "Worker"]);
const assigneeCounts = new Map();

if (tasks.length === 0) {
  errors.push("tasks must be non-empty");
}

for (const task of tasks) {
  if (!task.id || !/^T\d{3,}$/.test(String(task.id))) {
    errors.push(`task has invalid id: ${task.id}`);
  }
  if (!allowedAssignees.has(task.assignee)) {
    errors.push(`task ${task.id} has invalid assignee: ${task.assignee}`);
    continue;
  }
  assigneeCounts.set(task.assignee, (assigneeCounts.get(task.assignee) || 0) + 1);
  if (!task.objective) {
    errors.push(`task ${task.id} is missing objective`);
  }
  if (task.assignee === "Scout" || task.assignee === "Judge") {
    if (task.allowedFiles.length > 0 || task.verify.length > 0 || task.stopIf.length > 0) {
      errors.push(`task ${task.id} is ${task.assignee} but has Worker write fields`);
    }
  }
  if (task.assignee === "Worker") {
    if (task.allowedFiles.length === 0) errors.push(`Worker task ${task.id} missing allowed_files`);
    if (task.verify.length === 0) errors.push(`Worker task ${task.id} missing verify`);
    if (task.stopIf.length === 0) errors.push(`Worker task ${task.id} missing stop_if`);
  }
}

for (const requiredAssignee of ["Scout", "Judge", "Worker"]) {
  if (!assigneeCounts.has(requiredAssignee)) {
    errors.push(`GoalBuddy board must include at least one ${requiredAssignee} task`);
  }
}

if (goalStatus === "active") {
  if (!activeTask) {
    errors.push("active goal must name active_task");
  }
  const activeMatches = tasks.filter((task) => task.id === activeTask);
  if (activeMatches.length !== 1) {
    errors.push("active_task must match exactly one task");
  } else if (activeMatches[0].status !== "active") {
    errors.push("active_task must have status active");
  }
}

const activeWorkers = tasks.filter((task) => task.assignee === "Worker" && task.status === "active");
if (activeWorkers.length > 1) {
  errors.push("at most one write-capable Worker may be active");
}

if (goalStatus === "done") {
  const doneAudit = tasks.find((task) =>
    (task.assignee === "Judge" || task.assignee === "PM")
    && task.status === "done"
    && task.receiptRaw
    && /full_outcome_complete:\s*true/.test(task.receiptRaw)
  );
  if (!doneAudit) {
    errors.push("done goal requires final Judge or PM receipt with full_outcome_complete: true");
  }
}

if (errors.length > 0) {
  console.error(JSON.stringify({ ok: false, errors }, null, 2));
  process.exit(1);
}

console.log(JSON.stringify({
  ok: true,
  tasks: tasks.length,
  assignees: Object.fromEntries(assigneeCounts),
  active_task: activeTask,
}, null, 2));
