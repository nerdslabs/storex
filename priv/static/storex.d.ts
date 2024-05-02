declare module "storex" {
    interface StoreConfig<T> {
        session?: string;
        store: string;
        params: {
            [key: string]: any;
        };
        subscribe?: (state: T) => void;
        onConnected?: () => void;
        onError?: (error: unknown) => void;
        onDisconnected?: (event: CloseEvent) => void;
    }
    class Storex<T> {
        private session;
        private config;
        private socket;
        private listeners;
        state: T;
        static defaults: {
            params: {
                [key: string]: any;
            };
            address?: string;
        };
        constructor(config: StoreConfig<T>);
        _connected(): void;
        _disconnected(event: CloseEvent): void;
        _mutate(message: any): void;
        commit<T>(name: string, ...data: any): Promise<T | undefined>;
        subscribe(listener: (state: T) => void): () => void;
    }
    export default Storex;
}
