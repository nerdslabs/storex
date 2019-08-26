(function (global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory() :
    typeof define === 'function' && define.amd ? define(factory) :
    (global = global || self, global.stex = factory());
}(this, function () { 'use strict';

    /*! *****************************************************************************
    Copyright (c) Microsoft Corporation. All rights reserved.
    Licensed under the Apache License, Version 2.0 (the "License"); you may not use
    this file except in compliance with the License. You may obtain a copy of the
    License at http://www.apache.org/licenses/LICENSE-2.0

    THIS CODE IS PROVIDED ON AN *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
    KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
    WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
    MERCHANTABLITY OR NON-INFRINGEMENT.

    See the Apache Version 2.0 License for specific language governing permissions
    and limitations under the License.
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
                if (change.a === "u") {
                    Diff.set(source, change.p, change.t);
                }
                else if (change.a === "d") {
                    Diff.remove(source, change.p);
                }
                else if (change.a === "i") {
                    Diff.set(source, change.p, change.t);
                }
            }
            return source;
        };
        return Diff;
    }());
    var Socket = /** @class */ (function () {
        function Socket() {
            this.connections = [];
            this.keeper = null;
            this.requests = {};
            this.stores = {};
        }
        Socket.prototype.connect = function () {
            var _this = this;
            return new Promise(function (resolve, reject) {
                if (_this.isConnected) {
                    resolve();
                }
                else {
                    _this.connections.push({ resolve: resolve, reject: reject });
                    if (_this.socket === void 0) {
                        var address = Stex.defaults.address || location.host + '/stex';
                        _this.socket = new WebSocket('ws://' + address);
                        _this.socket.binaryType = 'arraybuffer';
                        _this.socket.onopen = _this.opened.bind(_this);
                        _this.socket.onclose = _this.closed.bind(_this);
                        _this.socket.onmessage = _this.message.bind(_this);
                    }
                }
            });
        };
        Object.defineProperty(Socket.prototype, "isConnected", {
            get: function () {
                return this.socket !== void 0 && this.socket.readyState === this.socket.OPEN;
            },
            enumerable: true,
            configurable: true
        });
        Socket.prototype.send = function (data) {
            var _this = this;
            return new Promise(function (resolve, reject) {
                var request = Math.random().toString(36).substr(2, 5);
                var payload = data;
                payload.request = request;
                _this.socket.send(JSON.stringify(payload));
                _this.requests[request] = [resolve, reject];
            });
        };
        Socket.prototype.message = function (message) {
            var data = JSON.parse(message.data);
            var request = this.requests[data.request];
            if (request !== void 0) {
                var resolve = request[0], reject = request[1];
                if (data.type === "error") {
                    reject(data);
                }
                else {
                    resolve(data);
                }
            }
            else {
                if (data.type === "mutation") {
                    var store = this.stores[data.store];
                    if (store !== void 0) {
                        store._mutate(data);
                    }
                }
            }
        };
        Socket.prototype.opened = function (event) {
            var _this = this;
            if (this.socket.readyState === this.socket.OPEN) {
                while (this.connections.length > 0) {
                    var _a = this.connections.shift(), resolve = _a.resolve, _ = _a._;
                    resolve();
                }
                this.keeper = setInterval(function () {
                    _this.send({
                        type: 'ping'
                    });
                }, 30000);
            }
            else {
                setTimeout(this.opened.bind(this, event), 100);
            }
        };
        Socket.prototype.closed = function (event) {
            while (this.connections.length > 0) {
                var _a = this.connections.shift(), _ = _a._, reject = _a.reject;
                reject();
            }
            console.log(event);
            var code = event.code;
            var reason = event.reason;
            if (code >= 4000) {
                console.error('[stex]', reason);
            }
            else if (code === 1000) {
                this.connect();
            }
            if (this.keeper !== null) {
                clearInterval(this.keeper);
            }
        };
        return Socket;
    }());
    var socket = new Socket();
    var Stex = /** @class */ (function () {
        function Stex(config) {
            this.listeners = [];
            this.session = config.session || null;
            this.config = config;
            this.socket = socket;
            this.state = null;
            if (!this.config.store) {
                throw new Error('[stex] Store is required');
            }
            if (this.config.subscribe) {
                if (typeof this.config.subscribe !== "function") {
                    throw new ErrorEvent("Listener has to be a function.");
                }
                this.listeners.push(this.config.subscribe);
            }
            this.socket.connect().then(this._connected.bind(this));
        }
        Stex.prototype._connected = function () {
            var _this = this;
            this.socket.stores[this.config.store] = this;
            this.socket.send({
                type: 'join',
                store: this.config.store,
                data: __assign({}, Stex.defaults.params, this.config.params)
            }).then(function (message) {
                _this.session = message.session;
                _this._mutate(message);
            });
        };
        Stex.prototype._mutate = function (message) {
            if (message.diff !== void 0) {
                this.state = Diff.patch(this.state, message.diff);
            }
            else {
                this.state = message.data;
            }
            for (var i = 0; i < this.listeners.length; i++) {
                var listener = this.listeners[i];
                listener(this.state);
            }
        };
        Stex.prototype.commit = function (name) {
            var _this = this;
            var data = [];
            for (var _i = 1; _i < arguments.length; _i++) {
                data[_i - 1] = arguments[_i];
            }
            return new Promise(function (resolve, reject) {
                _this.socket.send({
                    type: 'mutation',
                    store: _this.config.store,
                    session: _this.session,
                    data: {
                        name: name, data: data
                    }
                }).then(function (message) {
                    _this._mutate(message);
                    if (message.message !== void 0) {
                        resolve({
                            data: message.data,
                            message: message.message
                        });
                    }
                    else {
                        resolve({
                            data: message.data
                        });
                    }
                }, function (error) {
                    reject(error.error);
                });
            });
        };
        Stex.prototype.subscribe = function (listener) {
            if (typeof listener !== "function") {
                throw new ErrorEvent("Listener has to be a function.");
            }
            this.listeners.push(listener);
            listener(this.state);
            return function unsubscribe() {
                var index = this.listeners.indexOf(listener);
                if (index > -1) {
                    this.listeners.splice(index, 1);
                }
            };
        };
        Stex.defaults = {
            params: {},
        };
        return Stex;
    }());

    return Stex;

}));
