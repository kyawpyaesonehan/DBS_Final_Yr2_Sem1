function fetchUserReview() {
    const token = localStorage.getItem('token');

}

document.addEventListener('DOMContentLoaded', function () {
	fetchUserReview()
		.catch(function (error) {
			// Handle error
			console.error(error);
		});
});