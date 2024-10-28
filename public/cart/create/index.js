window.addEventListener('DOMContentLoaded', function () {
    const token = localStorage.getItem("token");
    const cartProductId = localStorage.getItem("cartProductId");

    const productIdInput = document.querySelector("input[name='productId']");
    productIdInput.value = cartProductId;    


});
