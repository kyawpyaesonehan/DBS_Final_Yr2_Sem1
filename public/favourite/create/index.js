window.addEventListener('DOMContentLoaded', function () {
    const token = localStorage.getItem('token');
    const productId = localStorage.getItem('favouriteProductId');


    const form = document.querySelector('form'); // Only have 1 form in this HTML

    form.querySelector('input[name=productId]').value = productId

    form.onsubmit = function (e) {
        e.preventDefault(); // prevent using the default submit behavior

        // Add favourite using fetch API with method POST
        fetch(`/products/${productId}`, {
            method: "POST",
            headers: {
                Authorization: `Bearer ${token}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                productId: productId
            }),
        })
            .then(function (response) {
                if (response.ok) {
                    alert('Favourite added!');
                    window.location.href = '/favourite/index.html';
                } else {
                    // If fail, show the error message
                    response.json().then(function (data) {
                        alert(`Error adding favourite - ${data.error}`);
                    });
                }
            })
            .catch(function (error) {
                alert('Error adding favourite');
            });
    };
});
