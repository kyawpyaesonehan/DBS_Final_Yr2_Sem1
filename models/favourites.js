const { query } = require('../database');
const { EMPTY_RESULT_ERROR, SQL_ERROR_CODE, UNIQUE_VIOLATION_ERROR } = require('../errors');

module.exports.create = function create(productId, memberId) {
    return query('CALL add_favourite($1, $2)', [productId, memberId])
        .then(function (result) {
            console.log('Favorite added successfully');
        })
        .catch(function (error) {
            throw error;
        });
};

module.exports.retrieveAllFavourite = function retrieveAllFavourite(memberId) {
    const sql = `SELECT * FROM retrieve_favourites($1)`;
    return query(sql, [memberId]).then(function (result) {
        return result.rows;
    });
};

module.exports.removeFavourite = function removeFavourite(productId, memberId) {
    return query('CALL remove_favourite($1, $2)', [productId, memberId])
        .then(function (result) {
            console.log('Favorite removed successfully');
        })
        .catch(function (error) {
            throw error;
        });
};