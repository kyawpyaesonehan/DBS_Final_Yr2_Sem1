window.addEventListener('DOMContentLoaded', function () {
    const token = localStorage.getItem("token");

    fetchAgeGroupSpending();

    const form = document.querySelector("form");
    const button = document.querySelector("button");

    function fetchAgeGroupSpending(queryParams = "") {
        fetch(`/dashboard/ageGroupSpending?${queryParams}`, {
            method: 'GET',
            headers: {
                Authorization: `Bearer ${token}`
            }
        })
            .then(function (response) {
                return response.json();
            })
            .then(function (body) {
                if (body.error) {
                    throw new Error(body.error);
                }
                const spendings = body || []; // Use the body directly as an array
                const tbody = document.querySelector("#spending-tbody");
                tbody.innerHTML = '';
                spendings.forEach(function (spending) {
                    const row = document.createElement("tr");
    
                    const ageGroupCell = document.createElement("td");
                    const totalSpendingCell = document.createElement("td");
                    const numberOfMembersCell = document.createElement("td");
                    
                    ageGroupCell.textContent = spending.ageGroup;
                    totalSpendingCell.textContent = spending.totalSpending;
                    numberOfMembersCell.textContent = spending.memberCount;
    
                    row.appendChild(ageGroupCell);
                    row.appendChild(totalSpendingCell);
                    row.appendChild(numberOfMembersCell);
    
                    tbody.appendChild(row);
                });
            })
            .catch(function (error) {
                console.error(error);
                // Handle error display or logging as needed
            });
    }

    function handleFormSubmission(event) {
        event.preventDefault();

        let gender = form.elements.gender.value;
        let minTotalSpending = form.elements.minTotalSpending.value;
        let minMemberTotalSpending = form.elements.minMemberTotalSpending.value;

        // Set empty values to null
        gender = gender === "" ? null : gender;
        minTotalSpending = minTotalSpending === "" ? null : minTotalSpending;
        minMemberTotalSpending = minMemberTotalSpending === "" ? null : minMemberTotalSpending;

        const params = new URLSearchParams();
        if (gender !== null) params.append("gender", gender);
        if (minTotalSpending !== null) params.append("minTotalSpending", minTotalSpending);
        if (minMemberTotalSpending !== null) params.append("minMemberTotalSpending", minMemberTotalSpending);

        fetchAgeGroupSpending(params.toString());
    }

    button.addEventListener("click", handleFormSubmission);
});


//method: 'GET',