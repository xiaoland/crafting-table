import { invoke } from "@tauri-apps/api/core";
import "./styles.css";

type RuntimeState = "stopped" | "starting" | "running" | "stopping" | "failed";
type BindMode = "local_only" | "local_network";
type EventKind = "status" | "server" | "log" | "error";

interface RuntimeEvent {
  id: number;
  kind: EventKind;
  message: string;
  timestamp: string;
}

interface RuntimeView {
  state: RuntimeState;
  bindMode: BindMode;
  bindAddress: string;
  endpointHint: string;
  codexHome: string;
  events: RuntimeEvent[];
}

const appRoot = document.querySelector<HTMLElement>("#app");

if (!appRoot) {
  throw new Error("app root is missing");
}

const app = appRoot;

let view: RuntimeView | null = null;
let pending = false;

function stateLabel(state: RuntimeState): string {
  switch (state) {
    case "stopped":
      return "Stopped";
    case "starting":
      return "Starting";
    case "running":
      return "Running";
    case "stopping":
      return "Stopping";
    case "failed":
      return "Failed";
  }
}

function bindModeLabel(mode: BindMode): string {
  return mode === "local_network" ? "Local Network" : "This PC";
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function canChangeRuntime(state: RuntimeState): boolean {
  return state === "stopped" || state === "failed" || state === "running";
}

async function invokeRuntime<T>(command: string, args?: Record<string, unknown>): Promise<T> {
  pending = true;
  render();

  try {
    return await invoke<T>(command, args);
  } finally {
    pending = false;
    render();
  }
}

async function refresh(): Promise<void> {
  view = await invokeRuntime<RuntimeView>("runtime_status");
  render();
}

async function startRuntime(): Promise<void> {
  view = await invokeRuntime<RuntimeView>("runtime_start");
  render();
}

async function stopRuntime(): Promise<void> {
  view = await invokeRuntime<RuntimeView>("runtime_stop");
  render();
}

async function setBindMode(mode: BindMode): Promise<void> {
  view = await invokeRuntime<RuntimeView>("runtime_set_bind_mode", { mode });
  render();
}

function render(): void {
  const runtime = view;
  const canChangeBind =
    runtime !== null && (runtime.state === "stopped" || runtime.state === "failed") && !pending;
  const codexHome = runtime ? escapeHtml(runtime.codexHome) : "-";
  const bindAddress = runtime ? escapeHtml(runtime.bindAddress) : "-";
  const endpointHint = runtime ? escapeHtml(runtime.endpointHint) : "-";

  app.innerHTML = `
    <section class="shell">
      <header class="topbar">
        <div>
          <h1>Crafting Table</h1>
          <p>Codex Remote Server</p>
        </div>
        <button id="refresh" class="quiet" type="button" ${pending ? "disabled" : ""}>Refresh</button>
      </header>

      <section class="status-band ${runtime?.state ?? "stopped"}">
        <div>
          <span class="label">Status</span>
          <strong>${runtime ? stateLabel(runtime.state) : "Loading"}</strong>
        </div>
        <div>
          <span class="label">Bind</span>
          <strong>${bindAddress}</strong>
        </div>
        <div>
          <span class="label">Endpoint</span>
          <strong>${endpointHint}</strong>
        </div>
      </section>

      <section class="controls">
        <div class="segmented" role="group" aria-label="Bind mode">
          <button id="local-only" type="button" ${runtime?.bindMode === "local_only" ? "aria-pressed=\"true\"" : ""} ${canChangeBind ? "" : "disabled"}>This PC</button>
          <button id="local-network" type="button" ${runtime?.bindMode === "local_network" ? "aria-pressed=\"true\"" : ""} ${canChangeBind ? "" : "disabled"}>Local Network</button>
        </div>
        <div class="actions">
          <button id="start" class="primary" type="button" ${!runtime || !canChangeRuntime(runtime.state) || runtime.state === "running" || pending ? "disabled" : ""}>Start</button>
          <button id="stop" type="button" ${!runtime || runtime.state !== "running" || pending ? "disabled" : ""}>Stop</button>
        </div>
      </section>

      <section class="details">
        <div>
          <span class="label">Mode</span>
          <strong>${runtime ? bindModeLabel(runtime.bindMode) : "-"}</strong>
        </div>
        <div>
          <span class="label">Codex Home</span>
          <strong>${codexHome}</strong>
        </div>
      </section>

      <section class="events">
        <h2>Events</h2>
        <div class="event-list">
          ${
            runtime && runtime.events.length > 0
              ? runtime.events
                  .map(
                    (event) => `
                      <article class="event ${event.kind}">
                        <span>${escapeHtml(event.timestamp)}</span>
                        <strong>${event.kind}</strong>
                        <p>${escapeHtml(event.message)}</p>
                      </article>
                    `,
                  )
                  .join("")
              : `<p class="empty">No runtime events.</p>`
          }
        </div>
      </section>
    </section>
  `;

  document.querySelector<HTMLButtonElement>("#refresh")?.addEventListener("click", () => {
    void refresh();
  });
  document.querySelector<HTMLButtonElement>("#start")?.addEventListener("click", () => {
    void startRuntime();
  });
  document.querySelector<HTMLButtonElement>("#stop")?.addEventListener("click", () => {
    void stopRuntime();
  });
  document.querySelector<HTMLButtonElement>("#local-only")?.addEventListener("click", () => {
    void setBindMode("local_only");
  });
  document.querySelector<HTMLButtonElement>("#local-network")?.addEventListener("click", () => {
    void setBindMode("local_network");
  });
}

render();
void refresh();
