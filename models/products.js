const { query } = require('../database');
const { EMPTY_RESULT_ERROR, SQL_ERROR_CODE, UNIQUE_VIOLATION_ERROR } = require('../errors');

module.exports.retrieveById = function retrieveById(productId) {
    const sql = `SELECT * FROM product WHERE id= $1`;
    return query(sql, [productId]).then(function (result) {
        const rows = result.rows;

        if (rows.length === 0) {
            throw new EMPTY_RESULT_ERROR(`Product ${productId} not found!`);
        }

        return rows[0];
    });
};

module.exports.retrieveAll = function retrieveAll() {
    const sql = `SELECT * FROM product`;
    return query(sql).then(function (result) {
        return result.rows;
    });
};

module.exports.getTop10FavouriteProducts = function getTop10FavouriteProducts() {
    const sql = 'SELECT * FROM get_top_10_favourite_products()';
    return query(sql).then(function (result) {
        return result.rows;
    });
};

module.exports.fetchReviewsByProductId = function fetchReviewsByProductId(productId, ratingFilter = null, orderFilter = 'reviewDate') {
    const sql = 'SELECT * FROM get_reviews_by_product_id($1, $2, $3)';
    return query(sql, [productId, ratingFilter, orderFilter])
        .then(function (result) {
            return result.rows;
        })
        .catch(function (error) {
            throw new Error(`Error retrieving reviews by product ID: ${error.message}`);
        });
};


