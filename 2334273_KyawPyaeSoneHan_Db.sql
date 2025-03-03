PGDMP  /                    |         	   ecommerce    16.2    16.2 N    @           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            A           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            B           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            C           1262    25188 	   ecommerce    DATABASE     �   CREATE DATABASE ecommerce WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'English_Singapore.1252';
    DROP DATABASE ecommerce;
                postgres    false            �            1255    25321    add_favourite(integer, integer) 	   PROCEDURE     Y  CREATE PROCEDURE public.add_favourite(IN p_product_id integer, IN p_member_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Check if the favourite already exists
    IF EXISTS (
        SELECT 1
        FROM favourite
        WHERE product_id = p_product_id
        AND member_id = p_member_id
    ) THEN
        -- Raise an exception if the favourite already exists
        RAISE EXCEPTION 'Favourite of the product already exists';
    ELSE
        -- Insert the favourite
        INSERT INTO favourite (product_id, member_id)
        VALUES (p_product_id, p_member_id);
    END IF;
END;
$$;
 V   DROP PROCEDURE public.add_favourite(IN p_product_id integer, IN p_member_id integer);
       public          postgres    false            �            1255    25301 !   compute_customer_lifetime_value() 	   PROCEDURE     �  CREATE PROCEDURE public.compute_customer_lifetime_value()
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_member_id INT;
    v_total_spent NUMERIC;
    v_total_orders INT;
    v_first_order_date DATE;
    v_last_order_date DATE;
    v_customer_lifetime NUMERIC;
    v_average_purchase_value NUMERIC;
    v_purchase_frequency NUMERIC;
    v_retention_period NUMERIC := 2; -- Assuming retention period is 2 years
    v_clv NUMERIC;
    member_rec RECORD;
BEGIN
    -- Cursor to iterate over members
    FOR member_rec IN
        SELECT id
        FROM member
    LOOP
        v_member_id := member_rec.id;

        -- Get the total spent and total orders for the member
        SELECT SUM(s.quantity * p.unit_price) AS total_spent,
               COUNT(DISTINCT s.sale_order_id) AS total_orders,
               MIN(so.order_datetime) AS first_order_date,
               MAX(so.order_datetime) AS last_order_date
        INTO v_total_spent, v_total_orders, v_first_order_date, v_last_order_date
        FROM sale_order_item s
        JOIN sale_order so ON s.sale_order_id = so.id
        JOIN product p ON s.product_id = p.id
        WHERE so.member_id = v_member_id AND so.status = 'COMPLETED';

        -- If the member has no orders or only one order, set CLV to null
        IF v_total_orders IS NULL OR v_total_orders < 2 THEN
            UPDATE member
            SET clv = NULL
            WHERE id = v_member_id;
            CONTINUE;
        END IF;

        -- Calculate customer lifetime in years
        v_customer_lifetime := EXTRACT(YEAR FROM AGE(v_last_order_date, v_first_order_date)) +
                               EXTRACT(MONTH FROM AGE(v_last_order_date, v_first_order_date)) / 12.0 +
                               EXTRACT(DAY FROM AGE(v_last_order_date, v_first_order_date)) / 365.25;

        -- Calculate average purchase value
        v_average_purchase_value := v_total_spent / v_total_orders;

        -- Calculate purchase frequency
        v_purchase_frequency := v_total_orders / v_customer_lifetime;

        -- Calculate Customer Lifetime Value (CLV)
        v_clv := v_average_purchase_value * v_purchase_frequency * v_retention_period;

        -- Update the member's CLV
        UPDATE member
        SET clv = v_clv
        WHERE id = v_member_id;
    END LOOP;
END;
$$;
 9   DROP PROCEDURE public.compute_customer_lifetime_value();
       public          postgres    false            �            1255    25304     compute_running_total_spending()    FUNCTION     �  CREATE FUNCTION public.compute_running_total_spending() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update running_total_spending for recently active/less than 6 months members
	UPDATE member m
	SET running_total_spending = (
		SELECT COALESCE(SUM(soi.quantity * p.unit_price), 0)
		FROM sale_order_item soi
		JOIN sale_order so ON soi.sale_order_id = so.id
		JOIN product p ON soi.product_id = p.id
		WHERE so.member_id = m.id
		  AND so.status = 'COMPLETED'
	);

    -- Set running_total_spending to NULL for inactive/more than 6 months members
    UPDATE member
    SET running_total_spending = NULL
    WHERE last_login_on < NOW() - INTERVAL '6 months';
END;
$$;
 7   DROP FUNCTION public.compute_running_total_spending();
       public          postgres    false            �            1255    25297 7   create_review(integer, integer, integer, text, integer) 	   PROCEDURE     n  CREATE PROCEDURE public.create_review(IN p_order_id integer, IN p_product_id integer, IN p_rating integer, IN p_review_text text, IN p_member_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_sale_order_item_id integer;
BEGIN
    -- Validate product_id existence in sale_order_item table
    IF NOT EXISTS (
        SELECT 1
        FROM sale_order_item
        WHERE product_id = p_product_id
    ) THEN
        RAISE EXCEPTION 'Product does not exist.';
    END IF;

    -- Validate order_id existence in sale_order_item table
    IF NOT EXISTS (
        SELECT 1
        FROM sale_order_item
        WHERE sale_order_id = p_order_id
    ) THEN
        RAISE EXCEPTION 'Order does not exist.';
    END IF;

    -- Validate rating range
    IF p_rating < 1 OR p_rating > 5 THEN
        RAISE EXCEPTION 'Rating % is out of the valid range (1-5)', p_rating;
    END IF;

    -- Check if the member has the specific product_id, order_id combination and the status is completed
    SELECT soi.id
    INTO v_sale_order_item_id
    FROM sale_order_item soi
    JOIN sale_order so ON soi.sale_order_id = so.id
    WHERE soi.product_id = p_product_id
      AND soi.sale_order_id = p_order_id
      AND so.member_id = p_member_id
      AND so.status = 'COMPLETED';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order is not completed or does not exist for the member';
    END IF;

    -- Check if the review already exists for the derived sale_order_item_id
    IF EXISTS (
        SELECT 1
        FROM review
        WHERE sale_order_item_id = v_sale_order_item_id
    ) THEN
        RAISE EXCEPTION 'Review already exists for this product';
    END IF;

    -- Insert the new review
    INSERT INTO review (sale_order_item_id, rating, review_text, review_date)
    VALUES (v_sale_order_item_id, p_rating, p_review_text, NOW());

    -- Optionally, you can return something here if needed
END;
$$;
 �   DROP PROCEDURE public.create_review(IN p_order_id integer, IN p_product_id integer, IN p_rating integer, IN p_review_text text, IN p_member_id integer);
       public          postgres    false            �            1255    25381    delete_review(integer) 	   PROCEDURE     �  CREATE PROCEDURE public.delete_review(IN p_review_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Delete the review
    DELETE FROM review
    WHERE review_id = p_review_id;

    -- Optionally, you can add logic to check the number of rows affected and raise an exception if no rows were deleted
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Review does not exist for this product';
    END IF;
END;
$$;
 =   DROP PROCEDURE public.delete_review(IN p_review_id integer);
       public          postgres    false            �            1255    25302 ;   get_age_group_spending(character varying, numeric, numeric)    FUNCTION     �  CREATE FUNCTION public.get_age_group_spending(p_gender character varying, p_min_total_spending numeric, p_min_member_total_spending numeric) RETURNS TABLE(age_group character varying, total_spending numeric, member_count integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        CASE
            WHEN EXTRACT(YEAR FROM AGE(m.dob)) BETWEEN 18 AND 29 THEN '18-29'
            WHEN EXTRACT(YEAR FROM AGE(m.dob)) BETWEEN 30 AND 39 THEN '30-39'
            WHEN EXTRACT(YEAR FROM AGE(m.dob)) BETWEEN 40 AND 49 THEN '40-49'
            WHEN EXTRACT(YEAR FROM AGE(m.dob)) BETWEEN 50 AND 59 THEN '50-59'
            ELSE 'Other'
        END::VARCHAR AS age_group,
        SUM(s.total_spending)::NUMERIC AS total_spending,
        COUNT(*)::INTEGER AS member_count
    FROM (
        SELECT 
            so.member_id,
            SUM(s.quantity * p.unit_price) AS total_spending
        FROM 
            sale_order_item s
        JOIN 
            sale_order so ON s.sale_order_id = so.id
        JOIN 
            product p ON s.product_id = p.id
        GROUP BY 
            so.member_id
    ) s
    JOIN 
        member m ON s.member_id = m.id
    WHERE 
        (p_gender IS NULL OR m.gender = p_gender)
        AND (p_min_total_spending IS NULL OR s.total_spending >= p_min_total_spending)
        AND (p_min_member_total_spending IS NULL OR (
            SELECT SUM(s2.quantity * p2.unit_price)
            FROM sale_order_item s2
            JOIN sale_order so2 ON s2.sale_order_id = so2.id
            JOIN product p2 ON s2.product_id = p2.id
        ) >= p_min_member_total_spending)
    GROUP BY 
        age_group
    ORDER BY 
        age_group;
END;
$$;
 �   DROP FUNCTION public.get_age_group_spending(p_gender character varying, p_min_total_spending numeric, p_min_member_total_spending numeric);
       public          postgres    false            �            1255    25378    get_all_reviews(integer)    FUNCTION     �  CREATE FUNCTION public.get_all_reviews(p_member_id integer) RETURNS TABLE(review_id integer, product_name character varying, rating integer, review_text character varying, review_date date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.review_id AS review_id,
        p.name AS product_name,
        r.rating,
        r.review_text,
        r.review_date
    FROM
        review r
    JOIN
        sale_order_item soi ON r.sale_order_item_id = soi.id
    JOIN
        sale_order so ON soi.sale_order_id = so.id
    JOIN
        product p ON soi.product_id = p.id
    WHERE
        so.member_id = p_member_id
	ORDER BY 
		review_id;
END;
$$;
 ;   DROP FUNCTION public.get_all_reviews(p_member_id integer);
       public          postgres    false            �            1255    25382    get_review(integer)    FUNCTION     �  CREATE FUNCTION public.get_review(p_review_id integer) RETURNS TABLE(review_id integer, product_name character varying, rating integer, review_text character varying, review_date date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        r.review_id AS review_id,
        p.name AS product_name,
        r.rating,
        r.review_text,
        r.review_date
    FROM
        review r
    JOIN
        sale_order_item soi ON r.sale_order_item_id = soi.id
    JOIN
        sale_order so ON soi.sale_order_id = so.id
    JOIN
        product p ON soi.product_id = p.id
    WHERE
        r.review_id = p_review_id;
END;
$$;
 6   DROP FUNCTION public.get_review(p_review_id integer);
       public          postgres    false            �            1255    25386 >   get_reviews_by_product_id(integer, integer, character varying)    FUNCTION     ~  CREATE FUNCTION public.get_reviews_by_product_id(p_product_id integer, p_rating_filter integer DEFAULT NULL::integer, p_order_filter character varying DEFAULT 'reviewDate'::character varying) RETURNS TABLE(product_name character varying, rating integer, review_text character varying, review_date date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.name AS product_name,
        r.rating,
        r.review_text,
        r.review_date
    FROM
        review r
    JOIN
        sale_order_item soi ON r.sale_order_item_id = soi.id
    JOIN
        product p ON soi.product_id = p.id
    WHERE
        soi.product_id = p_product_id
        AND (p_rating_filter IS NULL OR r.rating = p_rating_filter)
    ORDER BY
        CASE WHEN p_order_filter = 'reviewDate' THEN r.review_date END DESC,
        CASE WHEN p_order_filter = 'rating' THEN r.rating END DESC;
END;
$$;
 �   DROP FUNCTION public.get_reviews_by_product_id(p_product_id integer, p_rating_filter integer, p_order_filter character varying);
       public          postgres    false            �            1255    25383    get_top_10_favourite_products()    FUNCTION       CREATE FUNCTION public.get_top_10_favourite_products() RETURNS TABLE(product_id integer, product_name character varying, favourite_count integer)
    LANGUAGE plpgsql ROWS 10
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id AS product_id,
        p.name AS product_name,
        COUNT(f.product_id)::integer AS favourite_count
    FROM
        favourite f
    JOIN
        product p ON f.product_id = p.id
    GROUP BY
        p.id, p.name
    ORDER BY
        favourite_count DESC
    LIMIT 10;
END;
$$;
 6   DROP FUNCTION public.get_top_10_favourite_products();
       public          postgres    false            �            1255    25367 "   remove_favourite(integer, integer) 	   PROCEDURE     �   CREATE PROCEDURE public.remove_favourite(IN p_product_id integer, IN p_member_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM favourite
    WHERE member_id = p_member_id AND product_id = p_product_id;
END;
$$;
 Y   DROP PROCEDURE public.remove_favourite(IN p_product_id integer, IN p_member_id integer);
       public          postgres    false            �            1255    25361    retrieve_favourites(integer)    FUNCTION     �  CREATE FUNCTION public.retrieve_favourites(p_member_id integer) RETURNS TABLE(id integer, name character varying, description text, unit_price numeric, country character varying, product_type character varying, image_url character varying, manufactured_on timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS product_id,
        p.name,
        p.description,
        p.unit_price,
        p.country,
        p.product_type,
        p.image_url,
        p.manufactured_on
    FROM 
        favourite f
    JOIN 
        product p ON f.product_id = p.id
    WHERE 
        f.member_id = p_member_id;
END;
$$;
 ?   DROP FUNCTION public.retrieve_favourites(p_member_id integer);
       public          postgres    false            �            1255    25380 2   update_review(integer, integer, character varying) 	   PROCEDURE     V  CREATE PROCEDURE public.update_review(IN p_review_id integer, IN p_new_rating integer, IN p_new_review_text character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Validate rating range
    IF p_new_rating < 1 OR p_new_rating > 5 THEN
        RAISE EXCEPTION 'Rating % is out of the valid range (1-5)', p_new_rating;
    END IF;

    -- Update the review
    UPDATE review r
    SET
        rating = p_new_rating,
        review_text = p_new_review_text
    WHERE
        review_id = p_review_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Review cannot be found';
    END IF;
END;
$$;
 ~   DROP PROCEDURE public.update_review(IN p_review_id integer, IN p_new_rating integer, IN p_new_review_text character varying);
       public          postgres    false            �            1259    25352 	   favourite    TABLE     n   CREATE TABLE public.favourite (
    fav_id integer NOT NULL,
    product_id integer,
    member_id integer
);
    DROP TABLE public.favourite;
       public         heap    postgres    false            �            1259    25351    favourite_fav_id_seq    SEQUENCE     �   CREATE SEQUENCE public.favourite_fav_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.favourite_fav_id_seq;
       public          postgres    false    226            D           0    0    favourite_fav_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.favourite_fav_id_seq OWNED BY public.favourite.fav_id;
          public          postgres    false    225            �            1259    25189    member    TABLE     �  CREATE TABLE public.member (
    id integer NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(50) NOT NULL,
    dob date NOT NULL,
    password character varying(255) NOT NULL,
    role integer NOT NULL,
    gender character(1) NOT NULL,
    last_login_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    clv numeric(10,3),
    running_total_spending numeric(10,3)
);
    DROP TABLE public.member;
       public         heap    postgres    false            �            1259    25193    member_id_seq    SEQUENCE     �   CREATE SEQUENCE public.member_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.member_id_seq;
       public          postgres    false    215            E           0    0    member_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE public.member_id_seq OWNED BY public.member.id;
          public          postgres    false    216            �            1259    25194    member_role    TABLE     ]   CREATE TABLE public.member_role (
    id integer NOT NULL,
    name character varying(25)
);
    DROP TABLE public.member_role;
       public         heap    postgres    false            �            1259    25197    member_role_id_seq    SEQUENCE     �   CREATE SEQUENCE public.member_role_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.member_role_id_seq;
       public          postgres    false    217            F           0    0    member_role_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.member_role_id_seq OWNED BY public.member_role.id;
          public          postgres    false    218            �            1259    25198    product    TABLE     �  CREATE TABLE public.product (
    id integer NOT NULL,
    name character varying(255),
    description text,
    unit_price numeric NOT NULL,
    stock_quantity numeric DEFAULT 0 NOT NULL,
    country character varying(100),
    product_type character varying(50),
    image_url character varying(255) DEFAULT '/images/product.png'::character varying,
    manufactured_on timestamp without time zone
);
    DROP TABLE public.product;
       public         heap    postgres    false            �            1259    25205    product_id_seq    SEQUENCE     �   CREATE SEQUENCE public.product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.product_id_seq;
       public          postgres    false    219            G           0    0    product_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE public.product_id_seq OWNED BY public.product.id;
          public          postgres    false    220            �            1259    25370    review    TABLE     �   CREATE TABLE public.review (
    review_id integer NOT NULL,
    sale_order_item_id integer,
    rating integer,
    review_text character varying(255),
    review_date date
);
    DROP TABLE public.review;
       public         heap    postgres    false            �            1259    25369    review_review_id_seq    SEQUENCE     �   CREATE SEQUENCE public.review_review_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.review_review_id_seq;
       public          postgres    false    228            H           0    0    review_review_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.review_review_id_seq OWNED BY public.review.review_id;
          public          postgres    false    227            �            1259    25206 
   sale_order    TABLE     �   CREATE TABLE public.sale_order (
    id integer NOT NULL,
    member_id integer,
    order_datetime timestamp without time zone NOT NULL,
    status character varying(10)
);
    DROP TABLE public.sale_order;
       public         heap    postgres    false            �            1259    25209    sale_order_id_seq    SEQUENCE     �   CREATE SEQUENCE public.sale_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.sale_order_id_seq;
       public          postgres    false    221            I           0    0    sale_order_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.sale_order_id_seq OWNED BY public.sale_order.id;
          public          postgres    false    222            �            1259    25210    sale_order_item    TABLE     �   CREATE TABLE public.sale_order_item (
    id integer NOT NULL,
    sale_order_id integer NOT NULL,
    product_id integer NOT NULL,
    quantity numeric NOT NULL
);
 #   DROP TABLE public.sale_order_item;
       public         heap    postgres    false            �            1259    25215    sale_order_item_id_seq    SEQUENCE     �   CREATE SEQUENCE public.sale_order_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.sale_order_item_id_seq;
       public          postgres    false    223            J           0    0    sale_order_item_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.sale_order_item_id_seq OWNED BY public.sale_order_item.id;
          public          postgres    false    224            �           2604    25355    favourite fav_id    DEFAULT     t   ALTER TABLE ONLY public.favourite ALTER COLUMN fav_id SET DEFAULT nextval('public.favourite_fav_id_seq'::regclass);
 ?   ALTER TABLE public.favourite ALTER COLUMN fav_id DROP DEFAULT;
       public          postgres    false    226    225    226            {           2604    25216 	   member id    DEFAULT     f   ALTER TABLE ONLY public.member ALTER COLUMN id SET DEFAULT nextval('public.member_id_seq'::regclass);
 8   ALTER TABLE public.member ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    216    215            }           2604    25217    member_role id    DEFAULT     p   ALTER TABLE ONLY public.member_role ALTER COLUMN id SET DEFAULT nextval('public.member_role_id_seq'::regclass);
 =   ALTER TABLE public.member_role ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    218    217            ~           2604    25218 
   product id    DEFAULT     h   ALTER TABLE ONLY public.product ALTER COLUMN id SET DEFAULT nextval('public.product_id_seq'::regclass);
 9   ALTER TABLE public.product ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    220    219            �           2604    25373    review review_id    DEFAULT     t   ALTER TABLE ONLY public.review ALTER COLUMN review_id SET DEFAULT nextval('public.review_review_id_seq'::regclass);
 ?   ALTER TABLE public.review ALTER COLUMN review_id DROP DEFAULT;
       public          postgres    false    228    227    228            �           2604    25219    sale_order id    DEFAULT     n   ALTER TABLE ONLY public.sale_order ALTER COLUMN id SET DEFAULT nextval('public.sale_order_id_seq'::regclass);
 <   ALTER TABLE public.sale_order ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    222    221            �           2604    25220    sale_order_item id    DEFAULT     x   ALTER TABLE ONLY public.sale_order_item ALTER COLUMN id SET DEFAULT nextval('public.sale_order_item_id_seq'::regclass);
 A   ALTER TABLE public.sale_order_item ALTER COLUMN id DROP DEFAULT;
       public          postgres    false    224    223            ;          0    25352 	   favourite 
   TABLE DATA           B   COPY public.favourite (fav_id, product_id, member_id) FROM stdin;
    public          postgres    false    226   y�       0          0    25189    member 
   TABLE DATA           ~   COPY public.member (id, username, email, dob, password, role, gender, last_login_on, clv, running_total_spending) FROM stdin;
    public          postgres    false    215   ��       2          0    25194    member_role 
   TABLE DATA           /   COPY public.member_role (id, name) FROM stdin;
    public          postgres    false    217   ��       4          0    25198    product 
   TABLE DATA           �   COPY public.product (id, name, description, unit_price, stock_quantity, country, product_type, image_url, manufactured_on) FROM stdin;
    public          postgres    false    219   �       =          0    25370    review 
   TABLE DATA           a   COPY public.review (review_id, sale_order_item_id, rating, review_text, review_date) FROM stdin;
    public          postgres    false    228   E�       6          0    25206 
   sale_order 
   TABLE DATA           K   COPY public.sale_order (id, member_id, order_datetime, status) FROM stdin;
    public          postgres    false    221   b�       8          0    25210    sale_order_item 
   TABLE DATA           R   COPY public.sale_order_item (id, sale_order_id, product_id, quantity) FROM stdin;
    public          postgres    false    223   P�       K           0    0    favourite_fav_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.favourite_fav_id_seq', 1, false);
          public          postgres    false    225            L           0    0    member_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.member_id_seq', 12, true);
          public          postgres    false    216            M           0    0    member_role_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.member_role_id_seq', 2, true);
          public          postgres    false    218            N           0    0    product_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.product_id_seq', 20, true);
          public          postgres    false    220            O           0    0    review_review_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.review_review_id_seq', 1, false);
          public          postgres    false    227            P           0    0    sale_order_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.sale_order_id_seq', 31, true);
          public          postgres    false    222            Q           0    0    sale_order_item_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.sale_order_item_id_seq', 51, true);
          public          postgres    false    224            �           2606    25357    favourite favourite_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.favourite
    ADD CONSTRAINT favourite_pkey PRIMARY KEY (fav_id);
 B   ALTER TABLE ONLY public.favourite DROP CONSTRAINT favourite_pkey;
       public            postgres    false    226            �           2606    25222    member member_email_key 
   CONSTRAINT     S   ALTER TABLE ONLY public.member
    ADD CONSTRAINT member_email_key UNIQUE (email);
 A   ALTER TABLE ONLY public.member DROP CONSTRAINT member_email_key;
       public            postgres    false    215            �           2606    25224    member member_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public.member
    ADD CONSTRAINT member_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.member DROP CONSTRAINT member_pkey;
       public            postgres    false    215            �           2606    25226    member_role member_role_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.member_role
    ADD CONSTRAINT member_role_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.member_role DROP CONSTRAINT member_role_pkey;
       public            postgres    false    217            �           2606    25228    member member_username_key 
   CONSTRAINT     Y   ALTER TABLE ONLY public.member
    ADD CONSTRAINT member_username_key UNIQUE (username);
 D   ALTER TABLE ONLY public.member DROP CONSTRAINT member_username_key;
       public            postgres    false    215            �           2606    25230    product product_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.product DROP CONSTRAINT product_pkey;
       public            postgres    false    219            �           2606    25375    review review_pkey 
   CONSTRAINT     W   ALTER TABLE ONLY public.review
    ADD CONSTRAINT review_pkey PRIMARY KEY (review_id);
 <   ALTER TABLE ONLY public.review DROP CONSTRAINT review_pkey;
       public            postgres    false    228            �           2606    25232 $   sale_order_item sale_order_item_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.sale_order_item
    ADD CONSTRAINT sale_order_item_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.sale_order_item DROP CONSTRAINT sale_order_item_pkey;
       public            postgres    false    223            �           2606    25234    sale_order sale_order_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.sale_order
    ADD CONSTRAINT sale_order_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.sale_order DROP CONSTRAINT sale_order_pkey;
       public            postgres    false    221            �           1259    25691    fki_member_id    INDEX     H   CREATE INDEX fki_member_id ON public.favourite USING btree (member_id);
 !   DROP INDEX public.fki_member_id;
       public            postgres    false    226            �           1259    25697    fki_product_id    INDEX     J   CREATE INDEX fki_product_id ON public.favourite USING btree (product_id);
 "   DROP INDEX public.fki_product_id;
       public            postgres    false    226            �           1259    25680    fki_sale_order_item_id    INDEX     W   CREATE INDEX fki_sale_order_item_id ON public.review USING btree (sale_order_item_id);
 *   DROP INDEX public.fki_sale_order_item_id;
       public            postgres    false    228            �           2606    25235    member fk_member_role_id    FK CONSTRAINT     z   ALTER TABLE ONLY public.member
    ADD CONSTRAINT fk_member_role_id FOREIGN KEY (role) REFERENCES public.member_role(id);
 B   ALTER TABLE ONLY public.member DROP CONSTRAINT fk_member_role_id;
       public          postgres    false    215    217    4748            �           2606    25240 *   sale_order_item fk_sale_order_item_product    FK CONSTRAINT     �   ALTER TABLE ONLY public.sale_order_item
    ADD CONSTRAINT fk_sale_order_item_product FOREIGN KEY (product_id) REFERENCES public.product(id);
 T   ALTER TABLE ONLY public.sale_order_item DROP CONSTRAINT fk_sale_order_item_product;
       public          postgres    false    4750    219    223            �           2606    25245 -   sale_order_item fk_sale_order_item_sale_order    FK CONSTRAINT     �   ALTER TABLE ONLY public.sale_order_item
    ADD CONSTRAINT fk_sale_order_item_sale_order FOREIGN KEY (sale_order_id) REFERENCES public.sale_order(id);
 W   ALTER TABLE ONLY public.sale_order_item DROP CONSTRAINT fk_sale_order_item_sale_order;
       public          postgres    false    4752    223    221            �           2606    25250    sale_order fk_sale_order_member    FK CONSTRAINT     �   ALTER TABLE ONLY public.sale_order
    ADD CONSTRAINT fk_sale_order_member FOREIGN KEY (member_id) REFERENCES public.member(id);
 I   ALTER TABLE ONLY public.sale_order DROP CONSTRAINT fk_sale_order_member;
       public          postgres    false    215    4744    221            �           2606    25686    favourite member_id    FK CONSTRAINT        ALTER TABLE ONLY public.favourite
    ADD CONSTRAINT member_id FOREIGN KEY (member_id) REFERENCES public.member(id) NOT VALID;
 =   ALTER TABLE ONLY public.favourite DROP CONSTRAINT member_id;
       public          postgres    false    215    226    4744            �           2606    25692    favourite product_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.favourite
    ADD CONSTRAINT product_id FOREIGN KEY (product_id) REFERENCES public.product(id) NOT VALID;
 >   ALTER TABLE ONLY public.favourite DROP CONSTRAINT product_id;
       public          postgres    false    4750    219    226            �           2606    25681    review sale_order_item_id    FK CONSTRAINT     �   ALTER TABLE ONLY public.review
    ADD CONSTRAINT sale_order_item_id FOREIGN KEY (sale_order_item_id) REFERENCES public.sale_order_item(id) NOT VALID;
 C   ALTER TABLE ONLY public.review DROP CONSTRAINT sale_order_item_id;
       public          postgres    false    4754    228    223            ;      x������ � �      0     x���Kk�@���_�E�3��<4Z���B���i ��=Ԋ-)��:���(nlY�n,���9�^����&����9T��M%�{���H����������������O���M�j����3|��^����vu}�|����ͷ+�b*HK I.C(�Be�	�Xy�� -bU��ס]���%x�0\���M��Ob�d�&�ay�,�MS�<���W`��1#,�m{,�\�J�	��(� �X���b[�;��Fj$��T�����܋��%R�=������E8�&#��v��)+1h��#@]\/Uߝ�����G�ӭ$c�y�� C�;��&,�r�:nj �v�ܥ�}��f���6�U���Ɉ����q�6ۺ�\6u�ON�o�p�^Ǒ �J[��r�P/�vY>ƾ�%hI�x;�L����48e�t\^̗m�YǸ�^�ˌ���(_��"�[s���:-�ul�z�u�����S��ЋУ�
4	v���H<m���ӫ? �{���K�NM&�?Pg�      2      x�3�v�2�tt�������� ,>�      4   N  x���KS�8���Wh7+Ӓ絃@�L�E�f3E�mMl�%)��_?G��xã
ѵ�s�{$N֍�^Kz���O٦�.��n�FQavTڶ�.�-�o�E҆`�O���y�g���� ]'�j�7݊J�o����睩H��IƊ�-(���b���g��YN��r��,�Tt]�ȵ���-�5CY�uzԡ�b�����JTNy��B�g]k#���3:�>�3�xN�r�O��LȳƷP�Ø�
�⁷J��<��E�L	G��k�(c�W�F�F��%kc[�>I��Š��Q28k�����ό��j:R7%�����8�}R��Y�U���UZJPoN�-�m��)�k=�y���/�	Cn���i���<cӌs��*�ߴd�
�m�(yp:�ҵh�����ӒLK�K���W�Qm�����ɡIO���#M���ي����_�X�@OT=��Q��h�D�ɉ�c*�M�|@�C�L�gj�ȟA4��BJpa?�
M[f|J�tU����M�$�6A����A�h���h_ Ζ��Ѡ�b������)��J��=A��'�$n�ȍr�0�d�ȣxz�	�����m��'���'{��(icː�@l����X�h}Nۃ�c�u���f���kw�z�R,fob���:x��(�'���AR'dD�K�-
�A�1�Mw�Sjƾ>wy��I4h22�3�ﯴ���� ��GT�_�u�)E吰;�ue����� �4�z��4���Q`rN~*�8�`���:�+r	A��h���X���`��퐙)���}|o�f��E����4�W����+����
�ږ�R�R	�ɣƓco���[K*mc��(�bs�S !�H4Aۥ������4M�Hڄ��>q'yh�3`\)ic��`��j���6;�?]�:�+Q��P�:������<_�1Aӷ�e��9�_�'�Ga�����P��^��׷�$��GL[�5g�I�#z�5���Pd8���@�MD=L�xS[�|��G_�*>Vz��.�h�*_�>��a��V���|��y�V��,GV��r$hF�t����Cr#�|�4�Y��>.'_N�Ik�Qg���}�����ZL�!&�d�lN.�j�=D�J���4����P��CԿ6�א�/�OQ���m��=nu$*bЇմO���s��	����x@��"p|��q�'Wp-�I���a��Ո@����]���RT� S8��.�ڽ�أgm�Eb�����*Ρ.8����z���R����໋�+�>����tz⣘B�Ok+�9��8�_��@�d��jND����O����t�z�u��Nǣ�W"j�����&#��9?;;��j��      =      x������ � �      6   �  x�m�;�1�k���)���9�"e������2l�y(�����%QIB�x�1�]��ׯ��?��7>9I4(�L��5�1ƕ��ǉ$�O�Y��B�\	��$�:�mR�c覧�jD��S)�^r��H#ɤ2Y��m\{qT�^���j,��~r6W�v=A֪��Xz�,���/Z2�ޮ(�'�|��ee�Øo?���6a�,f�e�=�	���D�	Xzy�n5�h���i+���`	�
;(8B�U6Po���B�lC�7��V��{�ڼ�a��~՞[s�_l2��7�t[dx!x�2��WEK����=i��X�G��9�hF���	����s��#�5���[�#�}d9�s��[[/T3�C���J�gj�4����������H�g����8�7i��Iv
#s+�f{���VI������O�X��ϐ�]Xn���d,���d=�cu� ��C4����ɰ�B��7�n�b&��      8     x�-���0C��a���K����R�I�i77� �X -�Q��im��
j�V�C��!O�?m����ݖ9��öv���k������N��H���h5�����q��G���B����
��`?�נ�&у�b�L������z��$�3��E�m�]ʁA!Sb#�aI"[xi-כԌ��D��E�m��F1�T()����-��7�0��Fv�P!�(�&GQp�f���A�#����}����vL     