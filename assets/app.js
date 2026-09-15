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

function worker() {
  if (engineWorker) return engineWorker;

  engineWorker = new Worker(new URL("./engine/worker.js", import.meta.url), {
    type: "module",
  });
  engineWorker.addEventListener("message", ({ data }) => {
    app.ports.engineEvent.send(data);
  });
  engineWorker.addEventListener("error", ({ message }) => {
    app.ports.engineEvent.send({
      type: "error",
      message: message || "local agent worker failed",
    });
  });
  return engineWorker;
}

app.ports.loadEngine.subscribe(() => {
  worker().postMessage({ type: "load" });
});

app.ports.requestEngineMove.subscribe((payload) => {
  worker().postMessage({ type: "move", payload });
});
