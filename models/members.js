const { query } = require('../database');

module.exports.isAdmin = function isAdmin(memberId) {
    const sql = `SELECT * FROM member m JOIN member_role r ON m.role=r.id WHERE m.id = $1 AND role = 2`;
    return query(sql, [memberId])
        .then(function (result) {
            const rows = result.rows;
            console.log(rows, rows.length);
            if (rows.length == 1)
                return true;
            return false;
        })
        .catch(function (error) {
            throw error;
        });
};

module.exports.retrieveByUsername = function retrieveByUsername(username) {
    const sql = 'SELECT * FROM member WHERE username = $1';
    return query(sql, [username]).then(function (result) {
        const rows = result.rows;
        return rows[0];
    });
};

module.exports.retrieveAgeGroupSpending = function retrieveAgeGroupSpending(gender, minTotalSpending, minMemberTotalSpending) {
    const sql = `SELECT * FROM get_age_group_spending($1, $2, $3)`;
    return query(sql, [gender, minTotalSpending, minMemberTotalSpending]).then(function (result) {
        return result.rows;
    });
};


module.exports.generateCustomerLifetimeValue = function generateCustomerLifetimeValue() {
    const sql = 'CALL compute_customer_lifetime_value()';
    return query(sql)
        .then(function () {
            console.log('Customer Lifetime Value (CLV) calculated successfully.');
        })
        .catch(function (error) {
            throw error;
        });
};


