const CONFIG_PATHS = {
  index: "config/index.json",
  style: "config/style.json",
  telemetry: "config/telemetry.json",
  header: "config/header.json",
  footer: "config/footer.json",
  lhc: "config/lhc.json",
  rhc: "config/rhc.json"
};

const state = {
  startedAt: performance.now(),
  configs: {},
  values: {}
};

async function loadJSON(path) {
  const response = await fetch(path, { cache: "no-store" });
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
  return response.json();
}

function setCSSVars(style) {
  const root = document.documentElement.style;
  const vars = {
    "--canvas-width": `${style.canvas.width}px`,
    "--canvas-height": `${style.canvas.height}px`,
    "--border-width": `${style.border.width}px`,
    "--border-color": style.border.color,
    "--background-color": style.background.color,
    "--text-color": style.text.color,
    "--font-family": style.text.font_family,
    "--font-size": `${style.text.font_size}px`,
    "--region-gap": `${style.regions.gap}px`
  };
  for (const [name, value] of Object.entries(vars)) root.setProperty(name, value);
}

function formatElapsed(ms) {
  const total = Math.floor(ms / 1000);
  const h = String(Math.floor(total / 3600)).padStart(2, "0");
  const m = String(Math.floor((total % 3600) / 60)).padStart(2, "0");
  const s = String(total % 60).padStart(2, "0");
  return `${h}:${m}:${s}`;
}

function resolveVariable(definition) {
  switch (definition.type) {
    case "literal":
      return String(definition.value ?? "");
    case "clock":
      return new Intl.DateTimeFormat(undefined, definition.options ?? {
        hour: "2-digit", minute: "2-digit", second: "2-digit", hour12: false
      }).format(new Date());
    case "elapsed":
      return formatElapsed(performance.now() - state.startedAt);
    default:
      return `<?>`;
  }
}

function updateVariables() {
  const registry = state.configs.telemetry.variables;
  for (const [name, definition] of Object.entries(registry)) {
    state.values[name] = resolveVariable(definition);
  }
}

function renderRegion(regionName) {
  const host = document.getElementById(regionName);
  const config = state.configs[regionName];
  const surfaceEnabled = state.configs.index.regions?.[regionName] !== false;
  const enabled = surfaceEnabled && config?.enabled !== false;

  host.hidden = !enabled;
  if (!enabled) {
    host.replaceChildren();
    return;
  }

  host.replaceChildren(...config.items.map(item => {
    const node = document.createElement("span");
    node.className = "telemetry-item";

    if (item.label) {
      const label = document.createElement("span");
      label.className = "telemetry-label";
      label.textContent = item.label;
      node.append(label);
    }

    const value = document.createElement("span");
    value.dataset.variable = item.variable;
    value.textContent = state.values[item.variable] ?? "";
    node.append(value);
    return node;
  }));
}

function updateRenderedValues() {
  for (const node of document.querySelectorAll("[data-variable]")) {
    node.textContent = state.values[node.dataset.variable] ?? "";
  }
}

async function reloadConfigs() {
  try {
    const entries = await Promise.all(
      Object.entries(CONFIG_PATHS).map(async ([name, path]) => [
        name,
        await loadJSON(path)
      ])
    );

    state.configs = Object.fromEntries(entries);

    setCSSVars(state.configs.style);
    updateVariables();

    ["header", "footer", "lhc", "rhc"].forEach(renderRegion);
  } catch (error) {
    // Keep last-known-good config while a file is being edited.
    console.warn("Config reload failed; preserving previous state.", error);
  }
}

async function boot() {
  await reloadConfigs();

  const tickMs = Math.max(
    100,
    1000 / (state.configs.telemetry.tick_hz || 1)
  );

  setInterval(() => {
    updateVariables();
    updateRenderedValues();
  }, tickMs);

  // Hot-reload declarative configuration.
  setInterval(reloadConfigs, 1000);
}

boot().catch(error => {
  document.body.innerHTML = `<pre style="color:#ff8080;background:#111;padding:16px">${error.stack}</pre>`;
});
