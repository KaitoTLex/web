// src/js/systemTheme.js
document.addEventListener('DOMContentLoaded', function() {
  // Only run if Elm app is initialized
  if (window.elmApp && window.elmApp.ports && window.elmApp.ports.systemThemeChanged) {
    // Check initial preference
    const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    window.elmApp.ports.systemThemeChanged.send(prefersDark);
    
    // Listen for changes
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    mediaQuery.addEventListener('change', function(e) {
      window.elmApp.ports.systemThemeChanged.send(e.matches);
    });
  }
});