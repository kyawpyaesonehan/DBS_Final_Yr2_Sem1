const { EMPTY_RESULT_ERROR, UNIQUE_VIOLATION_ERROR, DUPLICATE_TABLE_ERROR } = require('../errors');
const favouritesModel = require('../models/favourites');

module.exports.create = function(req, res) {
    const memberId = res.locals.member_id;
    const productId = req.body.productId;

    return favouritesModel
        .create(productId, memberId)
        .then(function() {
            return res.sendStatus(201);
        })
        .catch(function(error) {
            console.error(error);
            if (error.code === UNIQUE_VIOLATION_ERROR) {
                return res.status(400).json({ error: error.message });
            } else if (error.message) {
                return res.status(400).json({ error: error.message });
            }
            return res.status(500).json({ error: 'Internal server error' });
        });
};

module.exports.retrieveAllFavourite = function (req, res) {
    const memberId = res.locals.member_id;

    return favouritesModel
        .retrieveAllFavourite(memberId)
        .then(function (products) {
            return res.json({ products: products });
        })
        .catch(function (error) {
            console.error(error);
            return res.status(500).json({ error: error.message });
        });
}

module.exports.removeFavourite = function(req, res) {
    const memberId = res.locals.member_id;
    const productId = req.params.product_id;

    return favouritesModel
        .removeFavourite(productId, memberId)
        .then(function() {
            return res.sendStatus(201);
        })
        .catch(function(error) {
            console.error(error);
            if (error.code === UNIQUE_VIOLATION_ERROR) {
                return res.status(400).json({ error: error.message });
            } else if (error.message) {
                return res.status(400).json({ error: error.message });
            }
            return res.status(500).json({ error: 'Internal server error' });
        });
};
