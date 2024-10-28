function generateClv() {
    const token = localStorage.getItem('token');
    const url = '/members/generateClv';
    return fetch(url, {
        headers: { 'Authorization': `Bearer ${token}` }
    }).then(function (response) {
        return response.json();
    });
}

window.addEventListener('DOMContentLoaded', function () {

    document.querySelector('#generate-clv').onclick = function () {
    
        generateClv()
            .then(function (body) {
                if (body.error) throw new Error(body.error);
                alert("Started Batch Job");
            })
            .catch(function (error) {
                console.log(error)
            });
    }
});


