// Example JavaScript file for webpack bundling
console.log('🚀 PHP App - Assets loaded successfully!');

// Add dynamic behavior
document.addEventListener('DOMContentLoaded', () => {
    console.log('Application initialized');

    // Example: Add timestamp update
    setInterval(() => {
        const timeElements = document.querySelectorAll('.server-time');
        timeElements.forEach(el => {
            el.textContent = new Date().toLocaleTimeString();
        });
    }, 1000);
});
