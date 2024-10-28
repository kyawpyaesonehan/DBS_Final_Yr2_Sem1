const express = require('express');
const createHttpError = require('http-errors');

const authRoute = require('./routes/auth');
const productsRoute = require('./routes/products');
const reviewsRoute = require('./routes/reviews');
const saleOrdersRoute = require('./routes/saleOrders');
const cartsRoute = require('./routes/carts');
const dashboardRoute = require('./routes/dashboard');
const membersRoute = require('./routes/members');

// to parse NUMERIC types for pg-node
// https://github.com/brianc/node-postgres/issues/811
const types = require('pg').types
types.setTypeParser(1700, function(val) {
    return parseFloat(val);
});

const app = express();
app.use(express.json()); // to process JSON in request body


app.use(express.static('public'));

app.use('/auth', authRoute);
app.use('/reviews', reviewsRoute);
app.use('/products', productsRoute);
app.use('/saleOrders', saleOrdersRoute);
app.use('/carts', cartsRoute);
app.use('/dashboard', dashboardRoute);
app.use('/members', membersRoute);


app.use(function (req, res, next) {
    return next(createHttpError(404, `Unknown Resource ${req.method} ${req.originalUrl}`));
});

// eslint-disable-next-line no-unused-vars
app.use(function (err, req, res, next) {
    return res.status(err.status || 500).json({ error: err.message || 'Unknown Server Error!' });
});

module.exports = app;
