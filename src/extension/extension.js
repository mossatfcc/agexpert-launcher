const vscode = require("vscode");
const fs = require("fs");
const os = require("os");
const path = require("path");

const TARGETS = ["all", "client", "server", "api"];
const BUILD_CONFIGURATIONS = ["default", "localized", "development", "production"];

// 'default' passes no flag so angular.json's defaultConfiguration applies.
function configurationArgument(buildConfiguration) {
  return buildConfiguration && buildConfiguration !== "default"
    ? ` --configuration ${buildConfiguration}`
    : "";
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function toWindowsPath(value) {
  return value.replace(/\//g, "\\");
}

// Packaged builds carry config alongside extension.js; running from the repo falls back to config/.
function resolveConfigDirectory() {
  const candidates = [
    path.join(__dirname, "config"),
    path.join(__dirname, "..", "..", "config"),
  ];
  const found = candidates.find((candidate) =>
    fs.existsSync(path.join(candidate, "apis.json")),
  );
  if (!found) {
    throw new Error("AgExpert Launcher: unable to locate apis.json.");
  }
  return found;
}

function loadConfiguration() {
  const configDirectory = resolveConfigDirectory();
  const settings = readJson(
    path.join(configDirectory, "settings.default.json"),
  );

  const overridePath = path.join(
    os.homedir(),
    ".agexpert",
    "launcher.settings.json",
  );
  if (fs.existsSync(overridePath)) {
    Object.assign(settings, readJson(overridePath));
  }

  return {
    repoRoot: toWindowsPath(settings.repoRoot),
    clientPath: path.join(
      toWindowsPath(settings.repoRoot),
      toWindowsPath(settings.clientDirectory),
    ),
    apis: readJson(path.join(configDirectory, "apis.json")).apis,
    apps: readJson(path.join(configDirectory, "apps.json")).apps,
  };
}

function normalizeKey(value) {
  return String(value || "")
    .replace(/[^a-zA-Z0-9]/g, "")
    .toLowerCase();
}

// Every terminal the launcher opens is its own standalone tab; nothing is grouped
// or split, no matter how many terminals a single launch (or `agexpert start`) opens.
function createTerminal(name, cwd, color, icon, command) {
  const terminal = vscode.window.createTerminal({
    name,
    cwd,
    color: new vscode.ThemeColor(color),
    iconPath: new vscode.ThemeIcon(icon),
  });
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
  const api = configuration.apis.find(
    (entry) => normalizeKey(entry.name) === key,
  );

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

function launchApp(configuration, name, target, buildConfiguration) {
  const key = normalizeKey(name);
  const app = configuration.apps.find(
    (entry) => normalizeKey(entry.name) === key,
  );

  if (!app) {
    vscode.window.showErrorMessage(`AgExpert Launcher: unknown app '${name}'.`);
    return;
  }

  const buildConfigurationKey = (buildConfiguration || "default").toLowerCase();
  if (!BUILD_CONFIGURATIONS.includes(buildConfigurationKey)) {
    vscode.window.showErrorMessage(
      `AgExpert Launcher: unknown build configuration '${buildConfiguration}'. Valid: ${BUILD_CONFIGURATIONS.join(", ")}.`,
    );
    return;
  }
  const buildArgument = configurationArgument(buildConfigurationKey);

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
      `ng serve ${app.name}${buildArgument}`,
    );
    return;
  }

  if (target !== "server") {
    createTerminal(
      `${app.name} client`,
      configuration.clientPath,
      "terminal.ansiGreen",
      "browser",
      `ng build ${app.name} --watch${buildArgument}`,
    );
  }

  if (target !== "client") {
    createTerminal(
      `${app.name} server`,
      configuration.clientPath,
      "terminal.ansiCyan",
      "server",
      `dotnet run --no-restore --project ${app.project} --launch-profile "${app.launchProfile}"`,
    );
  }
}

// The third route slot is the launch profile for an API and the Angular build
// configuration for an app.
function launch(name, target = "all", option) {
  const configuration = loadConfiguration();

  if (name === "proxy") {
    launchProxy(configuration);
    return;
  }
  if (!TARGETS.includes(target)) {
    vscode.window.showErrorMessage(
      `AgExpert Launcher: unknown target '${target}'.`,
    );
    return;
  }
  if (target === "api") {
    launchApi(configuration, name, option);
    return;
  }

  launchApp(configuration, name, target, option);
}

function activate(context) {
  // Routes arrive as one encoded parameter: launch=<name>|<target>|<profile or build configuration>
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
    vscode.commands.registerCommand(
      "agexpert.launcher.launch",
      async (name) => {
        const configuration = loadConfiguration();
        const choice =
          name ||
          (await vscode.window.showQuickPick(
            [
              ...configuration.apps.map((app) => ({
                label: app.name,
                description: "app",
              })),
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
        if (choice.description === "api") {
          launch(choice.label, "api");
          return;
        }

        const buildConfiguration = await vscode.window.showQuickPick(
          BUILD_CONFIGURATIONS,
          { placeHolder: "Select the Angular build configuration" },
        );
        if (!buildConfiguration) return;
        launch(choice.label, "all", buildConfiguration);
      },
    ),
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
