const { EMPTY_RESULT_ERROR, UNIQUE_VIOLATION_ERROR, DUPLICATE_TABLE_ERROR } = require('../errors');
const reviewsModel = require('../models/reviews');


module.exports.create = function(req, res) {
    const memberId = res.locals.member_id;
    const orderId = req.body.orderId;
    const productId = req.body.productId;
    const rating = req.body.rating;
    const reviewText = req.body.reviewText;

    return reviewsModel
        .create(orderId, productId, rating, reviewText, memberId)
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

module.exports.retrieveAll = function (req, res) {
    const memberId = res.locals.member_id;
    // get all modules
    return reviewsModel
        .retrieveAll(memberId)
        .then(function (reviews) {
            return res.json({ reviews: reviews });
        })
        .catch(function (error) {
            console.error(error);
            return res.status(500).json({ error: error.message });
        });
} 

module.exports.deleteById = function (req, res) {
    // Delete module by Code
    const reviewId = req.params.reviewId;
    return reviewsModel
        .deleteById(reviewId)
        .then(function () {
            console.log("delete ok!");
            return res.status(200).json({ msg: "deleted!" });
        })
        .catch(function (error) {
            console.error(error);
            if (error instanceof EMPTY_RESULT_ERROR) {
                // return res.status(404).json({ error: error.message });
                return res.status(404).json({ error: "No such review!" });
            }
            return res.status(500).json({ error: error.message });
        });
}

module.exports.updateById = function (req, res) {
    // You can decide where you want to put the Credit in the Request
    // Implement Update module by Code and the credit is in req.body
    const reviewId = req.params.reviewId;
    const rating = req.body.rating;
    const reviewText = req.body.reviewText;
    return reviewsModel
        .updateById(reviewId, rating, reviewText)
        .then(function () {
            console.log("update ok!");
            return res.status(200).json({ msg: "updated!" });
        })
        .catch(function (error) {
            console.error(error);
            if (error instanceof EMPTY_RESULT_ERROR) {
                return res.status(404).json({ error: error.message });
            }
            return res.status(500).json({ error: error.message });
        });
}