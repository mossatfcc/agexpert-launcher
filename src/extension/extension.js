const vscode = require("vscode");
const fs = require("fs");
const os = require("os");
const path = require("path");

const TARGETS = ["all", "client", "server", "api"];

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function toWindowsPath(value) {
  return value.replace(/\//g, "\\");
}

// Packaged builds carry config alongside extension.js; running from the repo falls back to config/.
function resolveConfigDirectory() {
  const candidates = [path.join(__dirname, "config"), path.join(__dirname, "..", "..", "config")];
  const found = candidates.find((candidate) => fs.existsSync(path.join(candidate, "apis.json")));
  if (!found) {
    throw new Error("AgExpert Launcher: unable to locate apis.json.");
  }
  return found;
}

function loadConfiguration() {
  const configDirectory = resolveConfigDirectory();
  const settings = readJson(path.join(configDirectory, "settings.default.json"));

  const overridePath = path.join(os.homedir(), ".agexpert", "launcher.settings.json");
  if (fs.existsSync(overridePath)) {
    Object.assign(settings, readJson(overridePath));
  }

  return {
    repoRoot: toWindowsPath(settings.repoRoot),
    clientPath: path.join(toWindowsPath(settings.repoRoot), toWindowsPath(settings.clientDirectory)),
    apis: readJson(path.join(configDirectory, "apis.json")).apis,
    apps: readJson(path.join(configDirectory, "apps.json")).apps,
  };
}

function normalizeKey(value) {
  return String(value || "").replace(/[^a-zA-Z0-9]/g, "").toLowerCase();
}

function createTerminal(name, cwd, color, icon, command, parentTerminal) {
  const options = {
    name,
    cwd,
    color: new vscode.ThemeColor(color),
    iconPath: new vscode.ThemeIcon(icon),
  };
  if (parentTerminal) {
    options.location = { parentTerminal };
  }

  const terminal = vscode.window.createTerminal(options);
  terminal.sendText(command);
  terminal.show();
  return terminal;
}

function launchProxy(configuration) {
  createTerminal(
    "proxy",
    configuration.repoRoot,
    "terminal.ansiYellow",
    "server-process",
    "Start-AgExpertProxy start",
  );
}

function launchApi(configuration, name, launchProfile) {
  const key = normalizeKey(name);
  const api = configuration.apis.find((entry) => normalizeKey(entry.name) === key);

  if (!api) {
    vscode.window.showErrorMessage(`AgExpert Launcher: unknown API '${name}'.`);
    return;
  }
  if (api.proxyOnly) {
    vscode.window.showErrorMessage(
      `AgExpert Launcher: '${api.name}' has no local project; it is available through the proxy only.`,
    );
    return;
  }

  const profile = launchProfile || api.defaultProfile || "Test";
  createTerminal(
    `${api.name} api`,
    path.join(configuration.repoRoot, toWindowsPath(api.directory)),
    "terminal.ansiMagenta",
    "server-process",
    `dotnet run --no-restore --launch-profile "${profile}"`,
  );
}

function launchApp(configuration, name, target) {
  const key = normalizeKey(name);
  const app = configuration.apps.find((entry) => normalizeKey(entry.name) === key);

  if (!app) {
    vscode.window.showErrorMessage(`AgExpert Launcher: unknown app '${name}'.`);
    return;
  }

  if (app.clientOnly) {
    if (target === "server") {
      vscode.window.showErrorMessage(
        `AgExpert Launcher: ${app.name} does not have a server to start.`,
      );
      return;
    }
    createTerminal(
      `${app.name} client`,
      configuration.clientPath,
      "terminal.ansiGreen",
      "browser",
      `ng serve ${app.name}`,
    );
    return;
  }

  let client;
  if (target !== "server") {
    client = createTerminal(
      `${app.name} client`,
      configuration.clientPath,
      "terminal.ansiGreen",
      "browser",
      `ng build ${app.name} --watch`,
    );
  }

  if (target !== "client") {
    createTerminal(
      `${app.name} server`,
      configuration.clientPath,
      "terminal.ansiCyan",
      "server",
      `dotnet run --no-build --no-restore --project ${app.project} --launch-profile "${app.launchProfile}"`,
      client,
    );
  }
}

function launch(name, target = "all", launchProfile) {
  const configuration = loadConfiguration();

  if (name === "proxy") {
    launchProxy(configuration);
    return;
  }
  if (!TARGETS.includes(target)) {
    vscode.window.showErrorMessage(`AgExpert Launcher: unknown target '${target}'.`);
    return;
  }
  if (target === "api") {
    launchApi(configuration, name, launchProfile);
    return;
  }

  launchApp(configuration, name, target);
}

function activate(context) {
  // Routes arrive as one encoded parameter: launch=<name>|<target>|<profile>
  context.subscriptions.push(
    vscode.window.registerUriHandler({
      handleUri(uri) {
        const params = new URLSearchParams(uri.query);
        const route = params.get("launch");
        const [name, target, profile] = route ? route.split("|") : [];
        launch(
          (name || params.get("app") || "").toLowerCase(),
          (target || params.get("target") || "all").toLowerCase(),
          profile || params.get("profile"),
        );
      },
    }),
  );

  context.subscriptions.push(
    vscode.commands.registerCommand("agexpert.launcher.launch", async (name) => {
      const configuration = loadConfiguration();
      const choice =
        name ||
        (await vscode.window.showQuickPick(
          [
            ...configuration.apps.map((app) => ({ label: app.name, description: "app" })),
            ...configuration.apis
              .filter((api) => !api.proxyOnly)
              .map((api) => ({ label: api.name, description: "api" })),
          ],
          { placeHolder: "Select an AgExpert target to launch" },
        ));

      if (!choice) return;
      if (typeof choice === "string") {
        launch(choice);
        return;
      }
      launch(choice.label, choice.description === "api" ? "api" : "all");
    }),
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
