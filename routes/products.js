// See https://expressjs.com/en/guide/routing.html for routing

const express = require('express');
const productsController = require('../controllers/productsController');
const jwtMiddleware = require('../middleware/jwtMiddleware');
const favouritesController = require('../controllers/favouritesController');

const router = express.Router();

// All routes in this file will use the jwtMiddleware to verify the token and check if the user is an admin.
// Here the jwtMiddleware is applied at the router level to apply to all routes in this file
// But you can also apply the jwtMiddleware to individual routes
// router.use(jwtMiddleware.verifyToken, jwtMiddleware.verifyIsAdmin);

router.use(jwtMiddleware.verifyToken);

router.get('/', productsController.retrieveAll);

router.get('/top10', productsController.getTop10FavouriteProducts);

router.get('/favourite', favouritesController.retrieveAllFavourite);

router.get('/:productId/reviews', productsController.fetchReviewsByProductId);

router.get('/:code', productsController.retrieveById);

router.post('/:product_id', favouritesController.create);

router.delete('/:product_id', favouritesController.removeFavourite);

module.exports = router;
