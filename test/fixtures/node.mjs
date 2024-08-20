import { prepare, httpConnector } from "../../priv/static/storex.cjs.js";

const run = async (storeName, json) => {
  const params = JSON.parse(json);

  const result = { state: null, error: null };

  const { useStorex } = prepare(
    {},
    httpConnector({ address: "http://localhost:9996/storex" })
  );
  const store = useStorex({
    store: storeName,
    params: params,
  });

  await new Promise((resolve) => {
    store.subscribe((state) => {
      result.state = state;
      resolve();
    });

    store.onError((error) => {
      result.error = error;
      resolve();
    });
  });

  console.log(JSON.stringify(result));

  return "node";
};

export default run;
