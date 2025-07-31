// Put your custom JS code here
console.log('=== CUSTOM JS LOADED ===');

// Version Switcher: Robuste Navigation mit Fallback auf existierende Section
document.querySelectorAll('.version-switch-link').forEach(function(link) {
  link.addEventListener('click', function(e) {
    e.preventDefault();
    var targetVersion = link.getAttribute('data-version');
    var defaultVersion = link.getAttribute('data-default-version');
    var currentPath = window.location.pathname;
    var baseUrl = window.location.origin;

    // Hilfsfunktion: Extrahiere Section und Rest
    function parsePath(path, defaultVersion) {
      var parts = path.split('/').filter(Boolean);
      var version = defaultVersion;
      var sectionIdx = 0;
      if (parts.length > 0 && parts[0] === defaultVersion) {
        // Default-Version: /docs/... oder /community/...
        sectionIdx = 0;
      } else if (parts.length > 1 && linkVersions.includes(parts[0])) {
        // Andere Version: /<version>/docs/... oder /<version>/community/...
        version = parts[0];
        sectionIdx = 1;
      }
      var section = parts[sectionIdx] || 'docs';
      var rest = parts.slice(sectionIdx + 1).join('/');
      return { version, section, rest };
    }

    // Hole alle Versionen aus dem Dropdown
    var linkVersions = Array.from(document.querySelectorAll('.version-switch-link')).map(function(l) {
      return l.getAttribute('data-version');
    });

    var parsed = parsePath(currentPath, defaultVersion);
    var section = parsed.section;
    var rest = parsed.rest;

    // Ziel-URL bauen
    function buildUrl(version, section, rest) {
      if (version === defaultVersion) {
        return baseUrl + '/' + section + (rest ? '/' + rest : '/');
      } else {
        return baseUrl + '/' + version + '/' + section + (rest ? '/' + rest : '/');
      }
    }

    // Rekursive Fallback-Logik: Prüfe, ob Seite existiert, springe ggf. zur Section
    function tryNavigate(version, section, rest) {
      var url = buildUrl(version, section, rest);
      fetch(url, { method: 'HEAD' }).then(function(resp) {
        if (resp.ok) {
          window.location.href = url;
        } else {
          // Fallback: eine Ebene höher
          if (rest && rest.includes('/')) {
            var newRest = rest.split('/').slice(0, -1).join('/');
            tryNavigate(version, section, newRest);
          } else {
            // Fallback: nur Section
            var sectionUrl = buildUrl(version, section, '');
            fetch(sectionUrl, { method: 'HEAD' }).then(function(resp2) {
              if (resp2.ok) {
                window.location.href = sectionUrl;
              } else {
                // Fallback: /docs/ oder /community/
                var mainSection = section === 'community' ? 'community' : 'docs';
                var mainUrl = buildUrl(version, mainSection, '');
                window.location.href = mainUrl;
              }
            });
          }
        }
      });
    }

    tryNavigate(targetVersion, section, rest);
  });
});
if (window.ocmSidebarToggleSetup) {
  console.log('OCM Sidebar toggle already setup, skipping...');
} else {
  window.ocmSidebarToggleSetup = true;
  
  // Function to setup the sidebar toggle
  function setupSidebarToggle() {
    console.log('=== Setting up OCM sidebar toggles ===');
    
    // Remove any existing listeners first
    if (window.ocmSidebarClickHandler) {
      document.removeEventListener('click', window.ocmSidebarClickHandler, true);
    }
    
    // Create the click handler
    window.ocmSidebarClickHandler = function(e) {
      // Check if clicked element is a docs-link in a summary
      if (e.target.classList.contains('docs-link')) {
        const closestSummary = e.target.closest('summary');
        if (closestSummary) {
          const link = e.target;
          const summary = closestSummary;
          const details = summary.closest('details');
          
          // Only handle links in the sidebar navigation
          if (details) {
            const sectionNav = details.closest('.section-nav');
            
            if (sectionNav) {
              console.log('Sidebar link clicked:', link.textContent);
              
              // Prevent default link behavior
              e.preventDefault();
              e.stopPropagation();
              
              // Toggle the details state
              details.open = !details.open;
              
              // Only navigate if it's a different page
              const currentPath = window.location.pathname;
              const linkPath = new URL(link.href).pathname;
              
              console.log('Current path:', currentPath);
              console.log('Link path:', linkPath);
              
              if (currentPath !== linkPath) {
                console.log('Different page - navigating...');
                console.log('Navigation start time:', new Date().getTime());
                // Immediate navigation - no delay needed
                window.location.href = link.href;
              } else {
                console.log('Same page - only toggling');
              }
            }
          }
        }
      }
    };
    
    // Add the event listener
    document.addEventListener('click', window.ocmSidebarClickHandler, true);
    console.log('OCM Event delegation setup complete');
  }
  
  // Setup when DOM is ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupSidebarToggle);
  } else {
    // DOM already loaded
    setupSidebarToggle();
  }
}
