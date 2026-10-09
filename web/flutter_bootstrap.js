{{flutter_js}}
{{flutter_build_config}}

// Renderiza o app dentro da "moldura de celular" da página (#nivvo-phone).
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const host = document.querySelector('#nivvo-phone');
    const appRunner = await engineInitializer.initializeEngine({ hostElement: host });
    document.querySelector('#loading')?.remove();
    await appRunner.runApp();
  },
});
