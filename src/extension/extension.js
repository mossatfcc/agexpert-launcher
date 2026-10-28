const vscode = require("vscode");
const fs = require("fs");
const os = require("os");
const path = require("path");

const TARGETS = ["all", "client", "server", "api", "env"];
const BUILD_CONFIGURATIONS = ["default", "localized", "development", "production"];
const PROXY_SERVICE_ACTIONS = ["start", "stop", "status"];

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
    defaultApp: settings.defaultApp || "",
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

// Republishing the container ports takes a while, so the toggle gets its own tab.
function launchProxyService(configuration, name, action) {
  const key = normalizeKey(name);
  const service = configuration.apis.find(
    (entry) =>
      normalizeKey(entry.name) === key ||
      normalizeKey(entry.proxyName) === key,
  );

  if (!service) {
    vscode.window.showErrorMessage(
      `AgExpert Launcher: unknown proxy service '${name}'.`,
    );
    return;
  }

  const serviceAction = (action || "status").toLowerCase();
  if (!PROXY_SERVICE_ACTIONS.includes(serviceAction)) {
    vscode.window.showErrorMessage(
      `AgExpert Launcher: unknown proxy service action '${action}'. Valid: ${PROXY_SERVICE_ACTIONS.join(", ")}.`,
    );
    return;
  }

  createTerminal(
    `proxy ${service.name} ${serviceAction}`,
    configuration.repoRoot,
    "terminal.ansiYellow",
    "plug",
    `Set-AgExpertProxyService ${service.name} ${serviceAction}`,
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

// Returns whether any terminal was opened, so a caller can stop before adding the proxy tab.
function launchApp(configuration, name, target, buildConfiguration) {
  const key = normalizeKey(name);
  const app = configuration.apps.find(
    (entry) => normalizeKey(entry.name) === key,
  );

  if (!app) {
    vscode.window.showErrorMessage(`AgExpert Launcher: unknown app '${name}'.`);
    return false;
  }

  const buildConfigurationKey = (buildConfiguration || "default").toLowerCase();
  if (!BUILD_CONFIGURATIONS.includes(buildConfigurationKey)) {
    vscode.window.showErrorMessage(
      `AgExpert Launcher: unknown build configuration '${buildConfiguration}'. Valid: ${BUILD_CONFIGURATIONS.join(", ")}.`,
    );
    return false;
  }
  const buildArgument = configurationArgument(buildConfigurationKey);

  if (app.clientOnly) {
    if (target === "server") {
      vscode.window.showErrorMessage(
        `AgExpert Launcher: ${app.name} does not have a server to start.`,
      );
      return false;
    }
    createTerminal(
      `${app.name} client`,
      configuration.clientPath,
      "terminal.ansiGreen",
      "browser",
      `ng serve ${app.name}${buildArgument}`,
    );
    return true;
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

  return true;
}

// The whole dev environment: the app client watch, its server, and the proxy.
function launchEnvironment(configuration, name, buildConfiguration) {
  const key = normalizeKey(name);
  const app = configuration.apps.find(
    (entry) => normalizeKey(entry.name) === key,
  );

  if (app && app.clientOnly) {
    vscode.window.showErrorMessage(
      `AgExpert Launcher: ${app.name} is client-only and cannot start a full dev environment.`,
    );
    return;
  }

  if (!launchApp(configuration, name, "all", buildConfiguration)) return;
  launchProxy(configuration);
}

// The third route slot is the launch profile for an API, the Angular build configuration
// for an app, and the action for a proxy service.
function launch(name, target = "all", option) {
  const configuration = loadConfiguration();

  if (name === "proxy") {
    if (target && target !== "all") {
      launchProxyService(configuration, target, option);
      return;
    }
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
  if (target === "env") {
    launchEnvironment(configuration, name, option);
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

  context.subscriptions.push(
    vscode.commands.registerCommand("agexpert.launcher.proxy", () =>
      launch("proxy"),
    ),
  );

  context.subscriptions.push(
    vscode.commands.registerCommand(
      "agexpert.launcher.environment",
      async (name) => {
        const configuration = loadConfiguration();
        const defaultKey = normalizeKey(configuration.defaultApp);
        const apps = configuration.apps
          .filter((app) => !app.clientOnly)
          .map((app) => ({
            label: app.name,
            description:
              normalizeKey(app.name) === defaultKey ? "default" : undefined,
          }))
          .sort((first, second) =>
            first.description === second.description
              ? 0
              : first.description
                ? -1
                : 1,
          );

        const choice =
          name ||
          (await vscode.window.showQuickPick(apps, {
            placeHolder: "Select the app to run with its server and the proxy",
          }));
        if (!choice) return;

        const buildConfiguration = await vscode.window.showQuickPick(
          BUILD_CONFIGURATIONS,
          { placeHolder: "Select the Angular build configuration" },
        );
        if (!buildConfiguration) return;

        launch(
          typeof choice === "string" ? choice : choice.label,
          "env",
          buildConfiguration,
        );
      },
    ),
  );

  context.subscriptions.push(
    vscode.commands.registerCommand(
      "agexpert.launcher.proxyService",
      async (name, action) => {
        const configuration = loadConfiguration();
        const service =
          name ||
          (await vscode.window.showQuickPick(
            configuration.apis.map((api) => ({
              label: api.name,
              description: `${api.proxyName} · ${api.port}`,
            })),
            {
              placeHolder: "Select a proxy service",
              matchOnDescription: true,
            },
          ));
        if (!service) return;

        const chosenAction =
          action ||
          (await vscode.window.showQuickPick(PROXY_SERVICE_ACTIONS, {
            placeHolder: "Start, stop, or check the proxy service",
          }));
        if (!chosenAction) return;

        launch(
          "proxy",
          typeof service === "string" ? service : service.label,
          chosenAction,
        );
      },
    ),
  );
}

function deactivate() {}

module.exports = { activate, deactivate };
