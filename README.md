# DBS Practical

## Setup

1. Clone this repository

2. Create a .env file with the following content

DB_USER=postgres
DB_PASSWORD=KpsHan247006@
DB_HOST=localhost
DB_DATABASE=ecommerce
DB_CONNECTION_LIMIT=1
PORT=3000
JWT_SECRET_KEY=your-secret-key
JWT_EXPIRES_IN=1d
JWT_ALGORITHM=HS256

3. Update the .env content with your database credentials accordingly.

4. Install dependencies by running `npm install`

5. Start the app by running `npm start`. Alternatively to use hot reload, start the app by running `npm run dev`.

6. You should see `App listening on port 3000`

8. (Optional) install the plugins recommended in `.vscode/extensions.json`

## Instructions

This website allows users to browse products, add them to favorites, write reviews, and for admins to manage product popularity and customer insights.

Logging In
    - Open the page, `http://localhost:3000`. Replace the port number if your app is not listening on port 3000.

Admin Login:

    -Username: admin
    -Password: password

User Logins:

    -Username: johndoe | Password: password
    -Username: janedoe | Password: password
    -Username: mikejones | Password: password
    -Username: emilyclark | Password: password
    -Username: robertbrown | Password: password
    -Username: sarahjohnson | Password: password
    -Username: davidwilson | Password: password
    -Username: amandawhite | Password: password
    -Username: chrislee | Password: password
    -Username: karenmiller | Password: password
    -Username: user | Password: password

Product Navigation

1. Show All Products:

    -Navigate to http://localhost:3000/product/
    -Click on "Show All Products" to go to http://localhost:3000/product/retrieve/all/

2. View Product Details:

    -Click the "View Product" button to see detailed information about a specific product at http://localhost:3000/product/retrieve/
    -Reviews for the product will be displayed, with options to filter by rating and recency.

Favorites

1. Add to Favorites:

    - Click the "Add to favourite" button to be redirected to http://localhost:3000/favourite/create
    - Click the "Add" button to add the product to your favorites list.
    - You will be redirected to http://localhost:3000/favourite/index.html to see all your favorite items.

2. Remove from Favorites:

    - Click the "Remove from Favourite" button to remove a product from your favorites list.

Reviews

1. Create Review:

    - Go to the "Review" tab at http://localhost:3000/review/
    - Click "Create Review" to go to http://localhost:3000/review/create/
    - Select an ordered item and click "Create Review"
    - Provide a rating (1-5) and review text, then click the "Create" button.

2. Retrieve All Reviews:

    - Navigate to http://localhost:3000/review/retrieve/all/ to see all your reviews.

3. Update Review:

    - Click the "Update" button next to a review to go to http://localhost:3000/review/update/
    - Update the rating and review text, then click the "Update" button.

4. Delete Review:

    - Click the "Delete" button next to a review to go to http://localhost:3000/review/delete/
    - Confirm deletion by clicking the "Delete" button.

Admin Dashboard

Access Dashboard:

    - Log in as an admin and navigate to http://localhost:3000/admin/dashboard/

1. Retrieve Age Group Spending:

    - Click "Retrieve Age Group Spending" to go to http://localhost:3000/admin/dashboard/ageGroupSpending/
    - Filter results by gender, minimum total spending, and minimum member total spending, then click "Search".

2. Retrieve Customer Lifetime Value:

    - Click "Retrieve Customer Lifetime Value" to go to http://localhost:3000/admin/dashboard/customerLifetimeValue/
    - Click the "Generate" button to update customer lifetime values.

3. Most Popular Product:

    - Click "Most Popular Product" to go to http://localhost:3000/admin/dashboard/popularProducts/
    - View the statistics for the most favorited products.

Logout

    - Log out and try other accounts to test different user perspectives and functionalities.