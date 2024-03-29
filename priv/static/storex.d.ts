declare module "storex" {
    interface StoreConfig {
        session?: string;
        store: string;
        params: {
            [key: string]: any;
        };
        subscribe?: () => void;
        connection?: () => void;
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
        constructor(config: StoreConfig);
        _connected(): void;
        _disconnected(): void;
        _mutate(message: any): void;
        commit<T>(name: string, ...data: any): Promise<T | undefined>;
        subscribe(listener: (state: T) => void): () => void;
        connection(listener: (state: boolean) => void): () => void;
    }
    export default Storex;
}
