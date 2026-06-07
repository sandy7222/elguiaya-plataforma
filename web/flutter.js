// Flutter Web Loader Standard
(function() {
  "use strict";
  class FlutterLoader {
    async loadEntrypoint(options) {
      const { entrypointUrl = "main.dart.js", onEntrypointLoaded } = options || {};
      const script = document.createElement("script");
      script.src = entrypointUrl;
      script.type = "application/javascript";
      script.addEventListener("load", () => {
        if (onEntrypointLoaded) {
          onEntrypointLoaded({
            initializeEngine: async (engineOptions) => {
              const container = document.createElement("div");
              document.body.appendChild(container);
              const engine = await window._flutter.buildConfig.instantiateViewer(engineOptions);
              return {
                runApp: () => engine.runApp()
              };
            }
          });
        }
      });
      document.body.appendChild(script);
    }
  }
  window._flutter = window._flutter || {};
  window._flutter.loader = new FlutterLoader();
})();
