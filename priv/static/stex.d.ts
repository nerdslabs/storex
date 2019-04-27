declare module "stex" {
    class Stex {
        private session;
        private config;
        private socket;
        state: any;
        static defaults: {
            params: {
                [key: string]: any;
            };
            address?: string;
        };
        constructor(config: any);
        _connected(): void;
        commit(name: string, ...data: any): Promise<void>;
    }
    export default Stex;
}
