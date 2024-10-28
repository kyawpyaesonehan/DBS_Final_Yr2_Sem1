// Check if user is logged in and not an admin
if (!localStorage.getItem('token')) {
    console.log('User is not logged in')
    window.location.href = '/login.html'; // Redirect to login page
}


// Function to handle logout
function logout() {
    // Clear the authentication token from localStorage
    localStorage.clear();

    // Redirect the user to the login page or any other desired page
    window.location.href = '/login.html';
}
