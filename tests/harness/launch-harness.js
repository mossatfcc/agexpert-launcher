// Loads extension.js against a mocked VS Code API and prints the terminals a route would create.
const path = require("path");
const Module = require("module");

const terminals = [];
const errors = [];

const vscodeStub = {
  ThemeColor: class {
    constructor(id) {
      this.id = id;
    }
  },
  ThemeIcon: class {
    constructor(id) {
      this.id = id;
    }
  },
  window: {
    createTerminal(options) {
      const terminal = {
        options,
        commands: [],
        sendText(command) {
          this.commands.push(command);
        },
        show() {},
      };
      terminals.push(terminal);
      return terminal;
    },
    registerUriHandler(handler) {
      vscodeStub.handler = handler;
      return { dispose() {} };
    },
    showErrorMessage(message) {
      errors.push(message);
    },
    showQuickPick: async () => undefined,
  },
  commands: {
    registerCommand() {
      return { dispose() {} };
    },
  },
};

const originalResolve = Module._resolveFilename;
Module._resolveFilename = function (request, ...rest) {
  if (request === "vscode") return "vscode";
  return originalResolve.call(this, request, ...rest);
};

const originalLoad = Module._load;
Module._load = function (request, ...rest) {
  if (request === "vscode") return vscodeStub;
  return originalLoad.call(this, request, ...rest);
};

const extension = require(path.join(__dirname, "..", "..", "src", "extension", "extension.js"));
extension.activate({ subscriptions: { push() {} } });

vscodeStub.handler.handleUri({ query: process.argv[2] || "" });

process.stdout.write(
  JSON.stringify(
    terminals.map((terminal) => ({
      name: terminal.options.name,
      cwd: terminal.options.cwd,
      command: terminal.commands[0],
      errors,
    })),
  ),
);
