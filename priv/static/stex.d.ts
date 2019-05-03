declare module "stex" {
    interface StoreConfig {
        session?: string;
        store: string;
        params: {
            [key: string]: any;
        };
        subscribe?: () => void;
    }
    class Stex {
        private session;
        private config;
        private socket;
        private listeners;
        state: any;
        static defaults: {
            params: {
                [key: string]: any;
            };
            address?: string;
        };
        constructor(config: StoreConfig);
        _connected(): void;
        _mutate(state: any): void;
        commit(name: string, ...data: any): Promise<{}>;
        subscribe(listener: () => void): () => void;
    }
    export default Stex;
}
