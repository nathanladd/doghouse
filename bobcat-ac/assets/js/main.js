// Bobcat AC Training - Main JavaScript

// Section navigation (for single-page applications)
function showSection(id, link) {
  // Hide all sections
  document.querySelectorAll('.page-section').forEach(s => s.classList.remove('active'));
  // Show target
  document.getElementById(id).classList.add('active');
  // Update sidebar
  document.querySelectorAll('.sidebar a').forEach(a => a.classList.remove('active'));
  if (link) link.classList.add('active');
  // Scroll to top
  document.querySelector('.main').scrollTop = 0;
  window.scrollTo(0, 0);
}

function showSectionByName(id) {
  const sectionMap = {
    'overview': 0, 'safety': 1, 'refrigerant-cycle': 2, 'components': 3,
    'tools': 4, 'pressures': 5, 'diagnosis': 6, 'exercises': 7, 'specs': 8, 'schedule': 9
  };
  const links = document.querySelectorAll('.sidebar a');
  const idx = sectionMap[id];
  showSection(id, idx !== undefined ? links[idx] : null);
}

// Checklist functionality
function toggleCheck(checkbox) {
  const li = checkbox.closest('li');
  if (checkbox.checked) {
    li.classList.add('checked');
  } else {
    li.classList.remove('checked');
  }
}

// Multi-page navigation
function navigateToPage(url) {
  window.location.href = url;
}

// Set active navigation based on current page
function setActiveNavigation() {
  const currentPath = window.location.pathname;
  const navLinks = document.querySelectorAll('.sidebar a');
  
  navLinks.forEach(link => {
    if (link.getAttribute('href') === currentPath || 
        link.getAttribute('href') === window.location.pathname.split('/').pop()) {
      link.classList.add('active');
    }
  });
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
  setActiveNavigation();
  
  // Add click handlers to all navigation links
  document.querySelectorAll('.sidebar a').forEach(link => {
    link.addEventListener('click', function(e) {
      // Remove active class from all links
      document.querySelectorAll('.sidebar a').forEach(l => l.classList.remove('active'));
      // Add active class to clicked link
      this.classList.add('active');
    });
  });
  
  // Initialize all checkboxes
  document.querySelectorAll('input[type="checkbox"]').forEach(checkbox => {
    checkbox.addEventListener('change', function() {
      toggleCheck(this);
    });
  });
});

// Print functionality for reference pages
function printPage() {
  window.print();
}

// Search functionality (for component pages)
function searchComponents(query) {
  const allComponents = document.querySelectorAll('.component-card');
  const searchTerm = query.toLowerCase();
  
  allComponents.forEach(component => {
    const title = component.querySelector('.component-title').textContent.toLowerCase();
    const description = component.querySelector('.component-description').textContent.toLowerCase();
    
    if (title.includes(searchTerm) || description.includes(searchTerm)) {
      component.style.display = 'block';
    } else {
      component.style.display = 'none';
    }
  });
}

// Expand/collapse sections for better mobile experience
function toggleSection(sectionId) {
  const section = document.getElementById(sectionId);
  const isExpanded = section.classList.contains('expanded');
  
  if (isExpanded) {
    section.classList.remove('expanded');
    section.style.maxHeight = '200px';
  } else {
    section.classList.add('expanded');
    section.style.maxHeight = 'none';
  }
}
