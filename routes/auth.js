const express = require('express');
const membersController = require('../controllers/membersController');
const bcryptMiddleware = require('../middleware/bcryptMiddleware');
const jwtMiddleware = require('../middleware/jwtMiddleware');
const router = express.Router();

// The route /login uses the following middleware functions:
// 1) the usersController.login function to retrieve the user from the database
// 2) the bcryptMiddleware.comparePassword function to compare the password with the one from
// 3) the jwtMiddleware.generateToken function to generate a token
// 4) the jwtMiddleware.sendToken function to send the token to the client.
router.post("/login", membersController.login, bcryptMiddleware.comparePassword, jwtMiddleware.generateToken, jwtMiddleware.sendToken);

module.exports = router;
















// const express = require('express');
// const userModel = require('../models/users');
// const bcryptMiddleware = require('../middleware/bcryptMiddleware');
// const jwtMiddleware = require('../middleware/jwtMiddleware');
// const router = express.Router();


// // TODO: replace with the user controller
// const checkUsernameOrEmailExist = function(req, res, next) {
//     const username = req.body.username;
//     const email = req.body.email;

//     userModel.retrieveByUsername(username)
//         .then(function(user) {
//             if (user) {
//                 return res.status(400).json({ message: 'Username already exists' });
//             }
//             userModel.retrieveByEmail(email)
//                 .then(function(user) {
//                     if (user) {
//                         return res.status(400).json({ message: 'Email already exists' });
//                     }
//                     next();
//                 })
//                 .catch(function(error) {
//                     return res.status(500).json({ message: error.message });
//                 });
//         })
//         .catch(function(error) {
//             return res.status(500).json({ message: error.message });
//         });
// };

// const register = function(req, res, next){
//     const username = req.body.username;
//     const email = req.body.email;
//     const hash = res.locals.hash ;

//     userModel.create(username, email, hash)
//         .then(function(user) {
//             res.locals.userId = user.id;
//             res.locals.message = 'User created';
//             next();
//         })
//         .catch(function(error) {
//             return res.status(500).json({ message: error.message });
//         });
// }


// const login = function(req, res, next) {
//     const username = req.body.username;
//     const password = req.body.password;

//     if (!username || !password) {
//         return res.status(400).json({ message: 'Username and password are required' });
//     }

//     userModel.retrieveByUsername(username)
//         .then(function(user) {
//             if (!user) {
//                 return res.status(401).json({ message: 'Invalid username or password' });
//             }
//             res.locals.hash = user.password;
//             next();
//         })
//         .catch(function(error) {
//             return res.status(500).json({ message: error.message });
//         });
// }

// router.post("/login", login,  bcryptMiddleware.comparePassword, jwtMiddleware.generateToken, jwtMiddleware.sendToken);

// // router.post("/login", userController.login, bcryptMiddleware.comparePassword, jwtMiddleware.generateToken, jwtMiddleware.sendToken);

// router.post("/register", checkUsernameOrEmailExist, bcryptMiddleware.hashPassword, register, jwtMiddleware.generateToken, jwtMiddleware.sendToken);

// module.exports = router;