type Change = {
    a: 'u' | 'd' | 'i';
    p: any[];
    t: unknown;
};

type ResponseJoin<T> = {
    type: "join";
    store: string;
    session: string;
    data: T;
};
type ResponseMutation = {
    type: "mutation";
    store: string;
    session: string;
    message?: string;
    diff: Change[];
};
type Connector = {
    onConnected: (listener: () => void) => void;
    onMutated: (listener: (store: string, session: string, diff: Change[]) => void) => void;
    onDisconnected: (listener: (event: CloseEvent) => void) => void;
    connect: () => void;
    join: <T>(store: string, params: unknown) => Promise<ResponseJoin<T>>;
    mutate: (store: string, session: string, name: string, data: unknown) => Promise<ResponseMutation>;
};
type ConnectorBuilder = (options: {
    address?: string;
}) => Connector;

declare const httpConnector: ConnectorBuilder;

declare const socketConnector: ConnectorBuilder;

type Params = {
    [key: string]: any;
};
type StoreConfig = {
    store: string;
    params: Params;
};
declare const prepare: (params: Params, connector: Connector) => {
    useStorex: <T>(config: StoreConfig) => {
        commit: (name: string, ...data: any) => Promise<string | undefined>;
        readonly state: T;
        readonly session: string;
        subscribe: (listener: (state: T) => void) => () => boolean;
        onConnected: (listener: () => void) => () => boolean;
        onError: (listener: (error: unknown) => void) => () => boolean;
        onDisconnected: (listener: (event: CloseEvent) => void) => () => boolean;
    };
};
declare const _default: <T>(config: StoreConfig) => {
    commit: (name: string, ...data: any) => Promise<string | undefined>;
    readonly state: T;
    readonly session: string;
    subscribe: (listener: (state: T) => void) => () => boolean;
    onConnected: (listener: () => void) => () => boolean;
    onError: (listener: (error: unknown) => void) => () => boolean;
    onDisconnected: (listener: (event: CloseEvent) => void) => () => boolean;
};

export { _default as default, httpConnector, prepare, socketConnector };
