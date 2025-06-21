// This file can be used for any global client-side JavaScript.
// For example, handling logout.

document.addEventListener('DOMContentLoaded', () => {
    const logoutLink = document.querySelector('a[href="/logout"]');
    if (logoutLink) {
        logoutLink.addEventListener('click', (event) => {
            event.preventDefault();
            localStorage.removeItem('token'); // Clear the JWT token
            window.location.href = '/login'; // Redirect to login page
        });
    }
});

// Function to check if user is authenticated (by checking for token)
function isAuthenticated() {
    return localStorage.getItem('token') !== null;
}

// Example of conditionally showing/hiding elements based on authentication status
// This would typically be handled by server-side rendering for initial page load,
// but can be useful for dynamic updates or single-page applications.
function updateUIBasedOnAuth() {
    const authLinks = document.getElementById('auth-links'); // Assuming an element with this ID
    const guestLinks = document.getElementById('guest-links'); // Assuming an element with this ID

    if (isAuthenticated()) {
        if (authLinks) authLinks.style.display = 'block';
        if (guestLinks) guestLinks.style.display = 'none';
    } else {
        if (authLinks) authLinks.style.display = 'none';
        if (guestLinks) guestLinks.style.display = 'block';
    }
}

// Call on page load
updateUIBasedOnAuth();