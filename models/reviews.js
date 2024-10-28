const { query } = require('../database');
const { EMPTY_RESULT_ERROR, SQL_ERROR_CODE, UNIQUE_VIOLATION_ERROR } = require('../errors');

module.exports.create = function create(orderId, productId, rating, reviewText, memberId) {
    return query('CALL create_review($1, $2, $3, $4, $5)', [orderId, productId, rating, reviewText, memberId])
        .then(function (result) {
            console.log('Review created successfully');
        })
        .catch(function (error) {
            throw error;
        });
};

module.exports.retrieveAll = function retrieveAll(memberId) {
    const sql = `SELECT * FROM get_all_reviews($1)`;
    return query(sql, [memberId]).then(function (result) {
        return result.rows;
    });
};


module.exports.deleteById = function deleteById(reviewId) {
    const sql = `CALL delete_review($1)`;
    return query(sql, [reviewId]).then(function (result) {

    })
};

module.exports.updateById = function updateById(reviewId, rating, reviewText) {
    // Note:
    // If using raw sql: Can use result.rowCount to check the number of rows affected
    // But if using function/stored procedure, result.rowCount will always return null
    const sql = `CALL update_review($1,$2,$3)`;
    return query(sql, [reviewId, rating, reviewText]).then(function (result) {
        
    })
};