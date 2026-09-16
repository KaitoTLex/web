const redirect = sessionStorage.getItem("spa-redirect");

if (redirect) {
  sessionStorage.removeItem("spa-redirect");
  history.replaceState(null, "", redirect);
}

const app = Elm.Main.init({
  node: document.getElementById("root"),
  flags: new Date().getTimezoneOffset(),
});

let engineWorker = null;

function unloadEngine() {
  if (!engineWorker) return;
  engineWorker.terminate();
  engineWorker = null;
}

function worker() {
  if (engineWorker) return engineWorker;

  const activeWorker = new Worker(new URL("./engine/worker.js?v=2", import.meta.url), {
    type: "module",
  });
  engineWorker = activeWorker;
  activeWorker.addEventListener("message", ({ data }) => {
    app.ports.engineEvent.send(data);
  });
  activeWorker.addEventListener("error", ({ message }) => {
    app.ports.engineEvent.send({
      type: "error",
      message: message || "local agent worker failed",
    });
    if (engineWorker === activeWorker) unloadEngine();
  });
  return activeWorker;
}

app.ports.loadEngine.subscribe(() => {
  worker().postMessage({ type: "load" });
});

app.ports.unloadEngine.subscribe(unloadEngine);

app.ports.requestEngineMove.subscribe((payload) => {
  worker().postMessage({ type: "move", payload });
});
