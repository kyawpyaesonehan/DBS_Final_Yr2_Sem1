const { EMPTY_RESULT_ERROR, UNIQUE_VIOLATION_ERROR, DUPLICATE_TABLE_ERROR } = require('../errors');
const productsModel = require('../models/products');

module.exports.retrieveById = function (req, res) {
    const code = req.params.code;

    return productsModel
        .retrieveById(code)
        .then(function (product) {
            return res.json({ product: product });
        })
        .catch(function (error) {
            console.error(error);
            if (error instanceof EMPTY_RESULT_ERROR) {
                return res.status(404).json({ error: error.message });
            }
            return res.status(500).json({ error: error.message });
        });
}


module.exports.retrieveAll = function (req, res) {
    const memberId = res.locals.member_id;

    return productsModel
        .retrieveAll()
        .then(function (products) {
            return res.json({ products: products });
        })
        .catch(function (error) {
            console.error(error);
            return res.status(500).json({ error: error.message });
        });
}

module.exports.getTop10FavouriteProducts = (req, res) => {
    return productsModel.getTop10FavouriteProducts()
        .then(products => {
            res.json(products);
        })
        .catch(error => {
            console.error(error);
            res.status(500).json({ error: error.message });
        });
};

module.exports.fetchReviewsByProductId = function(req, res) {
    const productId = req.params.productId;
    const rating = req.query.rating;
    const order = req.query.order;

    return productsModel
        .fetchReviewsByProductId(productId, rating, order)
        .then(function (reviews) {
            return res.json({ reviews: reviews });
        })
        .catch(function (error) {
            console.error(error);
            return res.status(500).json({ error: error.message });
        });
};
