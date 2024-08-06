(function (global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports) :
    typeof define === 'function' && define.amd ? define(['exports'], factory) :
    (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global.useStorex = {}));
})(this, (function (exports) { 'use strict';

    /******************************************************************************
    Copyright (c) Microsoft Corporation.

    Permission to use, copy, modify, and/or distribute this software for any
    purpose with or without fee is hereby granted.

    THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
    REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
    AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
    INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
    LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
    OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
    PERFORMANCE OF THIS SOFTWARE.
    ***************************************************************************** */
    /* global Reflect, Promise, SuppressedError, Symbol */


    var __assign = function() {
        __assign = Object.assign || function __assign(t) {
            for (var s, i = 1, n = arguments.length; i < n; i++) {
                s = arguments[i];
                for (var p in s) if (Object.prototype.hasOwnProperty.call(s, p)) t[p] = s[p];
            }
            return t;
        };
        return __assign.apply(this, arguments);
    };

    function __awaiter(thisArg, _arguments, P, generator) {
        function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
        return new (P || (P = Promise))(function (resolve, reject) {
            function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
            function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
            function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
            step((generator = generator.apply(thisArg, _arguments || [])).next());
        });
    }

    function __generator(thisArg, body) {
        var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g;
        return g = { next: verb(0), "throw": verb(1), "return": verb(2) }, typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
        function verb(n) { return function (v) { return step([n, v]); }; }
        function step(op) {
            if (f) throw new TypeError("Generator is already executing.");
            while (g && (g = 0, op[0] && (_ = 0)), _) try {
                if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
                if (y = 0, t) op = [op[0] & 2, t.value];
                switch (op[0]) {
                    case 0: case 1: t = op; break;
                    case 4: _.label++; return { value: op[1], done: false };
                    case 5: _.label++; y = op[1]; op = [0]; continue;
                    case 7: op = _.ops.pop(); _.trys.pop(); continue;
                    default:
                        if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                        if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                        if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                        if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                        if (t[2]) _.ops.pop();
                        _.trys.pop(); continue;
                }
                op = body.call(thisArg, _);
            } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
            if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
        }
    }

    typeof SuppressedError === "function" ? SuppressedError : function (error, suppressed, message) {
        var e = new Error(message);
        return e.name = "SuppressedError", e.error = error, e.suppressed = suppressed, e;
    };

    var httpConnector = function (_a) {
        var address = _a.address;
        var connectListeners = [];
        var fullAddress;
        if (typeof address !== 'undefined') {
            fullAddress = address;
        }
        else if (typeof window !== 'undefined') {
            fullAddress = "".concat(window.location.protocol, "//").concat(window.location.host, "/storex");
        }
        else {
            throw "Address is required in non-browser environment";
        }
        var join = function (store, params) {
            var queryParams = new URLSearchParams({
                store: store,
                params: JSON.stringify(params)
            }).toString();
            return new Promise(function (resolve, reject) {
                fetch("".concat(fullAddress, "?").concat(queryParams), {
                    method: 'GET',
                    headers: {
                        'Content-Type': 'application/json'
                    }
                })
                    .then(function (response) { return __awaiter(void 0, void 0, void 0, function () {
                    var _a;
                    return __generator(this, function (_b) {
                        switch (_b.label) {
                            case 0:
                                if (!!response.ok) return [3 /*break*/, 2];
                                _a = reject;
                                return [4 /*yield*/, response.json()];
                            case 1:
                                _a.apply(void 0, [_b.sent()]);
                                _b.label = 2;
                            case 2: return [2 /*return*/, response.json()];
                        }
                    });
                }); })
                    .then(resolve)
                    .catch(reject);
            });
        };
        var connect = function () {
            connectListeners.forEach(function (listener) { return listener(); });
        };
        var mutate = function (store, session, name, data) {
            console.warn('Mutation is not supported in the HTTP version');
            return Promise.resolve({ type: 'mutation', store: store, session: session, diff: [] });
        };
        return {
            connect: connect,
            join: join,
            mutate: mutate,
            onConnected: function (listener) {
                connectListeners.push(listener);
            },
            onDisconnected: function (listener) {
            },
            onMutated: function (listener) {
            }
        };
    };

    var generateRequestId = function () {
        var minCharCode = 48;
        var maxCharCode = 122;
        return Array.from({ length: 10 }, function () {
            return String.fromCharCode(Math.floor(Math.random() * (maxCharCode - minCharCode + 1)) + minCharCode);
        }).join('');
    };
    var socketConnector = function (_a) {
        var address = _a.address;
        var socket = null;
        var keeper = null;
        var requests = {};
        var connectListeners = [];
        var mutateListeners = [];
        var disconnectListeners = [];
        function isConnected() {
            return socket !== undefined && (socket === null || socket === void 0 ? void 0 : socket.readyState) === WebSocket.OPEN;
        }
        var connect = function () {
            if (!isConnected() && socket === null) {
                var fullAddress = address || location.host + '/storex';
                var protocol = location.protocol === 'https:' ? 'wss://' : 'ws://';
                socket = new WebSocket(protocol + fullAddress);
                socket.binaryType = 'arraybuffer';
                socket.onopen = onOpen;
                socket.onclose = onClose;
                socket.onmessage = onMessage;
            }
        };
        var onOpen = function (event) {
            if ((socket === null || socket === void 0 ? void 0 : socket.readyState) === WebSocket.OPEN) {
                connectListeners.forEach(function (listener) { return listener(); });
                keeper = setInterval(function () { return send({ type: 'ping' }); }, 30000);
            }
            else {
                setTimeout(function () { return onOpen(); }, 100);
            }
        };
        var onMessage = function (event) {
            var data = JSON.parse(event.data);
            var request = requests[data.request];
            if (request !== undefined) {
                var resolve = request[0], reject = request[1];
                data.type === 'error' ? reject(data) : resolve(data);
            }
            else if (data.type === 'mutation') {
                mutateListeners.forEach(function (listener) { return listener(data.store, data.session, data.diff); });
            }
        };
        var onClose = function (event) {
            socket = null;
            var code = event.code;
            var reason = event.reason;
            if (code >= 4000) {
                console.error('[storex]', reason);
            }
            else if ([1000, 1005, 1006].includes(code)) {
                connect();
            }
            disconnectListeners.forEach(function (listener) { return listener(event); });
            if (keeper !== null) {
                clearInterval(keeper);
            }
        };
        var send = function (data) {
            return new Promise(function (resolve, reject) {
                var request = generateRequestId();
                var payload = __assign(__assign({}, data), { request: request });
                socket === null || socket === void 0 ? void 0 : socket.send(JSON.stringify(payload));
                requests[request] = [resolve, reject];
            });
        };
        var onConnected = function (listener) {
            if (isConnected()) {
                listener();
            }
            connectListeners.push(listener);
        };
        var join = function (store, params) {
            return send({
                type: 'join',
                store: store,
                data: params,
            });
        };
        var mutate = function (store, session, name, data) {
            return send({
                type: 'mutation',
                store: store,
                session: session,
                data: {
                    name: name,
                    data: data,
                },
            });
        };
        return {
            connect: connect,
            join: join,
            mutate: mutate,
            onConnected: onConnected,
            onDisconnected: function (listener) { return disconnectListeners.push(listener); },
            onMutated: function (listener) { return mutateListeners.push(listener); },
        };
    };

    function set(object, path, value) {
        if (path.length > 0) {
            var index = path.pop();
            var parent = path.reduce(function (o, i) { return o[i]; }, object);
            parent[index] = value;
            return object;
        }
        else {
            return value;
        }
    }
    function remove(object, path) {
        var index = path.pop();
        var parent = path.reduce(function (o, i) { return o[i]; }, object);
        if (Array.isArray(parent)) {
            parent.splice(index, 1);
        }
        else {
            delete parent[index];
        }
        return object;
    }
    function patch(source, changes) {
        for (var _i = 0, changes_1 = changes; _i < changes_1.length; _i++) {
            var change = changes_1[_i];
            if (change.a === 'u') {
                source = set(source, change.p, change.t);
            }
            else if (change.a === 'd') {
                source = remove(source, change.p);
            }
            else if (change.a === 'i') {
                source = set(source, change.p, change.t);
            }
        }
        return source;
    }

    var bindStore = function (connector, config) {
        var state;
        var session = null;
        var messageListeners = new Set();
        var connectedListeners = new Set();
        var errorListeners = new Set();
        var disconnectedListeners = new Set();
        var setState = function (newState) {
            state = newState;
            messageListeners.forEach(function (listener) { return listener(state); });
        };
        var handleConnected = function () {
            connector.join(config.store, config.params).then(function (response) {
                session = response.session;
                setState(response.data);
                connectedListeners.forEach(function (listener) { return listener(); });
            }, function (error) {
                errorListeners.forEach(function (listener) { return listener(error.error); });
            });
        };
        var handleMutation = function (store, mutationSession, diff) {
            if (store === config.store && mutationSession === session) {
                setState(patch(state, diff));
            }
        };
        var commit = function (name) {
            var data = [];
            for (var _i = 1; _i < arguments.length; _i++) {
                data[_i - 1] = arguments[_i];
            }
            return new Promise(function (resolve, reject) {
                connector.mutate(config.store, session, name, data).then(function (response) {
                    setState(patch(state, response.diff));
                    resolve(response.message);
                }, function (error) { return reject(error.error); });
            });
        };
        connector.onConnected(handleConnected);
        connector.onDisconnected(function (event) {
            disconnectedListeners.forEach(function (listener) { return listener(event); });
        });
        connector.onMutated(handleMutation);
        connector.connect();
        return {
            commit: commit,
            get state() {
                return state;
            },
            get session() {
                return session;
            },
            subscribe: function (listener) {
                messageListeners.add(listener);
                if (state !== undefined) {
                    listener(state);
                }
                return function () { return messageListeners.delete(listener); };
            },
            onConnected: function (listener) {
                connectedListeners.add(listener);
                return function () { return connectedListeners.delete(listener); };
            },
            onError: function (listener) {
                errorListeners.add(listener);
                return function () { return errorListeners.delete(listener); };
            },
            onDisconnected: function (listener) {
                disconnectedListeners.add(listener);
                return function () { return disconnectedListeners.delete(listener); };
            },
        };
    };
    var prepare = function (params, connector) {
        var useStorex = function (config) {
            return bindStore(connector, {
                store: config.store,
                params: __assign(__assign({}, config.params), params),
            });
        };
        return {
            useStorex: useStorex,
        };
    };
    var useStorex = function () {
        var connector = socketConnector({});
        return function (config) { return bindStore(connector, config); };
    };
    var storex = useStorex();

    exports.default = storex;
    exports.httpConnector = httpConnector;
    exports.prepare = prepare;
    exports.socketConnector = socketConnector;

    Object.defineProperty(exports, '__esModule', { value: true });

}));
