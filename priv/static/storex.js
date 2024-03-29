(function (global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory() :
    typeof define === 'function' && define.amd ? define(factory) :
    (global = typeof globalThis !== 'undefined' ? globalThis : global || self, global.storex = factory());
})(this, (function () { 'use strict';

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

    var Diff = /** @class */ (function () {
        function Diff() {
        }
        Diff.set = function (object, path, value) {
            var index = path.pop();
            var parent = path.reduce(function (o, i) { return o[i]; }, object);
            parent[index] = value;
        };
        Diff.remove = function (object, path) {
            var index = path.pop();
            var parent = path.reduce(function (o, i) { return o[i]; }, object);
            if (Array.isArray(parent)) {
                parent.splice(index, 1);
            }
            else {
                delete parent[index];
            }
        };
        Diff.patch = function (source, changes) {
            for (var _i = 0, changes_1 = changes; _i < changes_1.length; _i++) {
                var change = changes_1[_i];
                if (change.a === 'u') {
                    if (change.p.length > 0) {
                        Diff.set(source, change.p, change.t);
                    }
                    else {
                        source = change.t;
                    }
                }
                else if (change.a === 'd') {
                    Diff.remove(source, change.p);
                }
                else if (change.a === 'i') {
                    Diff.set(source, change.p, change.t);
                }
            }
            return source;
        };
        return Diff;
    }());
    var Socket = /** @class */ (function () {
        function Socket() {
            this.socket = null;
            this.connectListeners = [];
            this.keeper = null;
            this.requests = {};
            this.stores = {};
        }
        Socket.prototype.connect = function () {
            if (this.isConnected === false && this.socket === null) {
                var address = Storex.defaults.address || location.host + '/storex';
                var protocol = location.protocol === 'https:' ? 'wss://' : 'ws://';
                this.socket = new WebSocket(protocol + address);
                this.socket.binaryType = 'arraybuffer';
                this.socket.onopen = this.opened.bind(this);
                this.socket.onclose = this.closed.bind(this);
                this.socket.onmessage = this.message.bind(this);
            }
        };
        Socket.prototype.onConnect = function (listener) {
            if (this.isConnected) {
                listener();
            }
            this.connectListeners.push(listener);
        };
        Object.defineProperty(Socket.prototype, "isConnected", {
            get: function () {
                var _a;
                return this.socket !== void 0 && ((_a = this.socket) === null || _a === void 0 ? void 0 : _a.readyState) === WebSocket.OPEN;
            },
            enumerable: false,
            configurable: true
        });
        Socket.prototype.send = function (data) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var _a;
                var request = Math.random().toString(36).substr(2, 5);
                var payload = data;
                payload.request = request;
                (_a = _this.socket) === null || _a === void 0 ? void 0 : _a.send(JSON.stringify(payload));
                _this.requests[request] = [resolve, reject];
            });
        };
        Socket.prototype.message = function (message) {
            var data = JSON.parse(message.data);
            var request = this.requests[data.request];
            if (request !== void 0) {
                var resolve = request[0], reject = request[1];
                if (data.type === 'error') {
                    reject(data);
                }
                else {
                    resolve(data);
                }
            }
            else {
                if (data.type === 'mutation') {
                    var store = this.stores[data.store];
                    if (store !== void 0) {
                        store._mutate(data);
                    }
                }
            }
        };
        Socket.prototype.opened = function (event) {
            var _this = this;
            var _a;
            if (((_a = this.socket) === null || _a === void 0 ? void 0 : _a.readyState) === WebSocket.OPEN) {
                this.connectListeners.forEach(function (listener) { return listener(); });
                this.keeper = setInterval(function () {
                    _this.send({
                        type: 'ping',
                    });
                }, 30000);
            }
            else {
                setTimeout(this.opened.bind(this, event), 100);
            }
        };
        Socket.prototype.closed = function (event) {
            this.socket = null;
            var code = event.code;
            var reason = event.reason;
            if (code >= 4000) {
                console.error('[storex]', reason);
            }
            else if ([1000, 1005, 1006].includes(code)) {
                this.connect();
            }
            Object.values(this.stores).forEach(function (store) { return store._disconnected(); });
            if (this.keeper !== null) {
                clearInterval(this.keeper);
            }
        };
        return Socket;
    }());
    var socket = new Socket();
    var Storex = /** @class */ (function () {
        function Storex(config) {
            this.listeners = {
                connection: [],
                messages: [],
            };
            this.session = config.session || null;
            this.config = config;
            this.socket = socket;
            if (!this.config.store) {
                throw new Error('[storex] Store is required');
            }
            if (this.config.subscribe) {
                if (typeof this.config.subscribe !== 'function') {
                    throw new ErrorEvent('Listener has to be a function.');
                }
                this.listeners.messages.push(this.config.subscribe);
            }
            if (this.config.connection) {
                this.listeners.connection.push(this.config.connection);
            }
            this.socket.onConnect(this._connected.bind(this));
            this.socket.connect();
        }
        Storex.prototype._connected = function () {
            var _this = this;
            this.socket.stores[this.config.store] = this;
            this.socket
                .send({
                type: 'join',
                store: this.config.store,
                data: __assign(__assign({}, Storex.defaults.params), this.config.params),
            })
                .then(function (response) {
                _this.session = response.session;
                _this._mutate(response);
                for (var i = 0; i < _this.listeners.connection.length; i++) {
                    var listener = _this.listeners.connection[i];
                    listener(_this.socket.isConnected);
                }
            });
        };
        Storex.prototype._disconnected = function () {
            for (var i = 0; i < this.listeners.connection.length; i++) {
                var listener = this.listeners.connection[i];
                listener(this.socket.isConnected);
            }
        };
        Storex.prototype._mutate = function (message) {
            if (message.diff !== void 0) {
                this.state = Diff.patch(this.state, message.diff);
            }
            else {
                this.state = message.data;
            }
            for (var i = 0; i < this.listeners.messages.length; i++) {
                var listener = this.listeners.messages[i];
                listener(this.state);
            }
        };
        Storex.prototype.commit = function (name) {
            var _this = this;
            var data = [];
            for (var _i = 1; _i < arguments.length; _i++) {
                data[_i - 1] = arguments[_i];
            }
            return new Promise(function (resolve, reject) {
                _this.socket
                    .send({
                    type: 'mutation',
                    store: _this.config.store,
                    session: _this.session,
                    data: {
                        name: name,
                        data: data,
                    },
                })
                    .then(function (response) {
                    _this._mutate(response);
                    if (response.message !== void 0) {
                        resolve(response.message);
                    }
                    else {
                        resolve(undefined);
                    }
                }, function (error) {
                    reject(error.error);
                });
            });
        };
        Storex.prototype.subscribe = function (listener) {
            if (typeof listener !== 'function') {
                throw new ErrorEvent('Listener has to be a function.');
            }
            this.listeners.messages.push(listener);
            listener(this.state);
            return function unsubscribe() {
                var index = this === null || this === void 0 ? void 0 : this.listeners.messages.indexOf(listener);
                if (index > -1) {
                    this.listeners.messages.splice(index, 1);
                }
            };
        };
        Storex.prototype.connection = function (listener) {
            if (typeof listener !== 'function') {
                throw new ErrorEvent('Listener has to be a function.');
            }
            this.listeners.connection.push(listener);
            if (this.socket.isConnected) {
                listener(this.socket.isConnected);
            }
            return function unsubscribe() {
                var index = this.listeners.connection.indexOf(listener);
                if (index > -1) {
                    this.listeners.connection.splice(index, 1);
                }
            };
        };
        Storex.defaults = {
            params: {},
        };
        return Storex;
    }());

    return Storex;

}));
