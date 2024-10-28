window.addEventListener('DOMContentLoaded', function () {
    const token = localStorage.getItem("token");

    fetch('/products/top10', {
        headers: {
            Authorization: `Bearer ${token}`
        }
    })
        .then(function (response) {
            return response.json();
        })
        .then(function (body) {
            if (body.error) throw new Error(body.error);
            const products = body || [];
            const tbody = document.querySelector("#favourite-tbody");
            tbody.innerHTML = '';
            products.forEach(function (product) {
                const row = document.createElement("tr");

                const productIdCell = document.createElement("td");
                const productNameCell = document.createElement("td");
                const favouriteCountCell = document.createElement("td");

                productIdCell.textContent = product.productId;
                productNameCell.textContent = product.productName;
                favouriteCountCell.textContent = product.favouriteCount;

                row.appendChild(productIdCell);
                row.appendChild(productNameCell);
                row.appendChild(favouriteCountCell);

                tbody.appendChild(row);
            });
        })
        .catch(function (error) {
            console.error(error);
        });
});
