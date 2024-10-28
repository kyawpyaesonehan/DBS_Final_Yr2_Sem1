--
-- PostgreSQL database dump
--

-- Dumped from database version 16.2
-- Dumped by pg_dump version 16.2

-- Started on 2024-07-12 15:14:32

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 243 (class 1255 OID 25321)
-- Name: add_favourite(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_favourite(IN p_product_id integer, IN p_member_id integer)
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


ALTER PROCEDURE public.add_favourite(IN p_product_id integer, IN p_member_id integer) OWNER TO postgres;

--
-- TOC entry 245 (class 1255 OID 25301)
-- Name: compute_customer_lifetime_value(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.compute_customer_lifetime_value()
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


ALTER PROCEDURE public.compute_customer_lifetime_value() OWNER TO postgres;

--
-- TOC entry 246 (class 1255 OID 25304)
-- Name: compute_running_total_spending(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.compute_running_total_spending() RETURNS void
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


ALTER FUNCTION public.compute_running_total_spending() OWNER TO postgres;

--
-- TOC entry 251 (class 1255 OID 25297)
-- Name: create_review(integer, integer, integer, text, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.create_review(IN p_order_id integer, IN p_product_id integer, IN p_rating integer, IN p_review_text text, IN p_member_id integer)
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


ALTER PROCEDURE public.create_review(IN p_order_id integer, IN p_product_id integer, IN p_rating integer, IN p_review_text text, IN p_member_id integer) OWNER TO postgres;

--
-- TOC entry 252 (class 1255 OID 25381)
-- Name: delete_review(integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.delete_review(IN p_review_id integer)
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


ALTER PROCEDURE public.delete_review(IN p_review_id integer) OWNER TO postgres;

--
-- TOC entry 249 (class 1255 OID 25302)
-- Name: get_age_group_spending(character varying, numeric, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_age_group_spending(p_gender character varying, p_min_total_spending numeric, p_min_member_total_spending numeric) RETURNS TABLE(age_group character varying, total_spending numeric, member_count integer)
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


ALTER FUNCTION public.get_age_group_spending(p_gender character varying, p_min_total_spending numeric, p_min_member_total_spending numeric) OWNER TO postgres;

--
-- TOC entry 248 (class 1255 OID 25378)
-- Name: get_all_reviews(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_all_reviews(p_member_id integer) RETURNS TABLE(review_id integer, product_name character varying, rating integer, review_text character varying, review_date date)
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


ALTER FUNCTION public.get_all_reviews(p_member_id integer) OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 25382)
-- Name: get_review(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_review(p_review_id integer) RETURNS TABLE(review_id integer, product_name character varying, rating integer, review_text character varying, review_date date)
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


ALTER FUNCTION public.get_review(p_review_id integer) OWNER TO postgres;

--
-- TOC entry 250 (class 1255 OID 25386)
-- Name: get_reviews_by_product_id(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_reviews_by_product_id(p_product_id integer, p_rating_filter integer DEFAULT NULL::integer, p_order_filter character varying DEFAULT 'reviewDate'::character varying) RETURNS TABLE(product_name character varying, rating integer, review_text character varying, review_date date)
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


ALTER FUNCTION public.get_reviews_by_product_id(p_product_id integer, p_rating_filter integer, p_order_filter character varying) OWNER TO postgres;

--
-- TOC entry 229 (class 1255 OID 25383)
-- Name: get_top_10_favourite_products(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_top_10_favourite_products() RETURNS TABLE(product_id integer, product_name character varying, favourite_count integer)
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


ALTER FUNCTION public.get_top_10_favourite_products() OWNER TO postgres;

--
-- TOC entry 242 (class 1255 OID 25367)
-- Name: remove_favourite(integer, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.remove_favourite(IN p_product_id integer, IN p_member_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM favourite
    WHERE member_id = p_member_id AND product_id = p_product_id;
END;
$$;


ALTER PROCEDURE public.remove_favourite(IN p_product_id integer, IN p_member_id integer) OWNER TO postgres;

--
-- TOC entry 241 (class 1255 OID 25361)
-- Name: retrieve_favourites(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.retrieve_favourites(p_member_id integer) RETURNS TABLE(id integer, name character varying, description text, unit_price numeric, country character varying, product_type character varying, image_url character varying, manufactured_on timestamp without time zone)
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


ALTER FUNCTION public.retrieve_favourites(p_member_id integer) OWNER TO postgres;

--
-- TOC entry 244 (class 1255 OID 25380)
-- Name: update_review(integer, integer, character varying); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.update_review(IN p_review_id integer, IN p_new_rating integer, IN p_new_review_text character varying)
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


ALTER PROCEDURE public.update_review(IN p_review_id integer, IN p_new_rating integer, IN p_new_review_text character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 226 (class 1259 OID 25352)
-- Name: favourite; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.favourite (
    fav_id integer NOT NULL,
    product_id integer,
    member_id integer
);


ALTER TABLE public.favourite OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 25351)
-- Name: favourite_fav_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.favourite_fav_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.favourite_fav_id_seq OWNER TO postgres;

--
-- TOC entry 4917 (class 0 OID 0)
-- Dependencies: 225
-- Name: favourite_fav_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.favourite_fav_id_seq OWNED BY public.favourite.fav_id;


--
-- TOC entry 215 (class 1259 OID 25189)
-- Name: member; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.member (
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


ALTER TABLE public.member OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 25193)
-- Name: member_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.member_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.member_id_seq OWNER TO postgres;

--
-- TOC entry 4918 (class 0 OID 0)
-- Dependencies: 216
-- Name: member_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.member_id_seq OWNED BY public.member.id;


--
-- TOC entry 217 (class 1259 OID 25194)
-- Name: member_role; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.member_role (
    id integer NOT NULL,
    name character varying(25)
);


ALTER TABLE public.member_role OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 25197)
-- Name: member_role_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.member_role_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.member_role_id_seq OWNER TO postgres;

--
-- TOC entry 4919 (class 0 OID 0)
-- Dependencies: 218
-- Name: member_role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.member_role_id_seq OWNED BY public.member_role.id;


--
-- TOC entry 219 (class 1259 OID 25198)
-- Name: product; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.product (
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


ALTER TABLE public.product OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 25205)
-- Name: product_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.product_id_seq OWNER TO postgres;

--
-- TOC entry 4920 (class 0 OID 0)
-- Dependencies: 220
-- Name: product_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.product_id_seq OWNED BY public.product.id;


--
-- TOC entry 228 (class 1259 OID 25370)
-- Name: review; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.review (
    review_id integer NOT NULL,
    sale_order_item_id integer,
    rating integer,
    review_text character varying(255),
    review_date date
);


ALTER TABLE public.review OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 25369)
-- Name: review_review_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.review_review_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.review_review_id_seq OWNER TO postgres;

--
-- TOC entry 4921 (class 0 OID 0)
-- Dependencies: 227
-- Name: review_review_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.review_review_id_seq OWNED BY public.review.review_id;


--
-- TOC entry 221 (class 1259 OID 25206)
-- Name: sale_order; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sale_order (
    id integer NOT NULL,
    member_id integer,
    order_datetime timestamp without time zone NOT NULL,
    status character varying(10)
);


ALTER TABLE public.sale_order OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 25209)
-- Name: sale_order_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sale_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sale_order_id_seq OWNER TO postgres;

--
-- TOC entry 4922 (class 0 OID 0)
-- Dependencies: 222
-- Name: sale_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sale_order_id_seq OWNED BY public.sale_order.id;


--
-- TOC entry 223 (class 1259 OID 25210)
-- Name: sale_order_item; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sale_order_item (
    id integer NOT NULL,
    sale_order_id integer NOT NULL,
    product_id integer NOT NULL,
    quantity numeric NOT NULL
);


ALTER TABLE public.sale_order_item OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 25215)
-- Name: sale_order_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sale_order_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sale_order_item_id_seq OWNER TO postgres;

--
-- TOC entry 4923 (class 0 OID 0)
-- Dependencies: 224
-- Name: sale_order_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sale_order_item_id_seq OWNED BY public.sale_order_item.id;


--
-- TOC entry 4739 (class 2604 OID 25355)
-- Name: favourite fav_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favourite ALTER COLUMN fav_id SET DEFAULT nextval('public.favourite_fav_id_seq'::regclass);


--
-- TOC entry 4731 (class 2604 OID 25216)
-- Name: member id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.member ALTER COLUMN id SET DEFAULT nextval('public.member_id_seq'::regclass);


--
-- TOC entry 4733 (class 2604 OID 25217)
-- Name: member_role id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.member_role ALTER COLUMN id SET DEFAULT nextval('public.member_role_id_seq'::regclass);


--
-- TOC entry 4734 (class 2604 OID 25218)
-- Name: product id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product ALTER COLUMN id SET DEFAULT nextval('public.product_id_seq'::regclass);


--
-- TOC entry 4740 (class 2604 OID 25373)
-- Name: review review_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.review ALTER COLUMN review_id SET DEFAULT nextval('public.review_review_id_seq'::regclass);


--
-- TOC entry 4737 (class 2604 OID 25219)
-- Name: sale_order id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order ALTER COLUMN id SET DEFAULT nextval('public.sale_order_id_seq'::regclass);


--
-- TOC entry 4738 (class 2604 OID 25220)
-- Name: sale_order_item id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order_item ALTER COLUMN id SET DEFAULT nextval('public.sale_order_item_id_seq'::regclass);


--
-- TOC entry 4756 (class 2606 OID 25357)
-- Name: favourite favourite_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favourite
    ADD CONSTRAINT favourite_pkey PRIMARY KEY (fav_id);


--
-- TOC entry 4742 (class 2606 OID 25222)
-- Name: member member_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.member
    ADD CONSTRAINT member_email_key UNIQUE (email);


--
-- TOC entry 4744 (class 2606 OID 25224)
-- Name: member member_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.member
    ADD CONSTRAINT member_pkey PRIMARY KEY (id);


--
-- TOC entry 4748 (class 2606 OID 25226)
-- Name: member_role member_role_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.member_role
    ADD CONSTRAINT member_role_pkey PRIMARY KEY (id);


--
-- TOC entry 4746 (class 2606 OID 25228)
-- Name: member member_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.member
    ADD CONSTRAINT member_username_key UNIQUE (username);


--
-- TOC entry 4750 (class 2606 OID 25230)
-- Name: product product_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (id);


--
-- TOC entry 4761 (class 2606 OID 25375)
-- Name: review review_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.review
    ADD CONSTRAINT review_pkey PRIMARY KEY (review_id);


--
-- TOC entry 4754 (class 2606 OID 25232)
-- Name: sale_order_item sale_order_item_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order_item
    ADD CONSTRAINT sale_order_item_pkey PRIMARY KEY (id);


--
-- TOC entry 4752 (class 2606 OID 25234)
-- Name: sale_order sale_order_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order
    ADD CONSTRAINT sale_order_pkey PRIMARY KEY (id);


--
-- TOC entry 4757 (class 1259 OID 25691)
-- Name: fki_member_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_member_id ON public.favourite USING btree (member_id);


--
-- TOC entry 4758 (class 1259 OID 25697)
-- Name: fki_product_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_product_id ON public.favourite USING btree (product_id);


--
-- TOC entry 4759 (class 1259 OID 25680)
-- Name: fki_sale_order_item_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX fki_sale_order_item_id ON public.review USING btree (sale_order_item_id);


--
-- TOC entry 4762 (class 2606 OID 25235)
-- Name: member fk_member_role_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.member
    ADD CONSTRAINT fk_member_role_id FOREIGN KEY (role) REFERENCES public.member_role(id);


--
-- TOC entry 4764 (class 2606 OID 25240)
-- Name: sale_order_item fk_sale_order_item_product; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order_item
    ADD CONSTRAINT fk_sale_order_item_product FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- TOC entry 4765 (class 2606 OID 25245)
-- Name: sale_order_item fk_sale_order_item_sale_order; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order_item
    ADD CONSTRAINT fk_sale_order_item_sale_order FOREIGN KEY (sale_order_id) REFERENCES public.sale_order(id);


--
-- TOC entry 4763 (class 2606 OID 25250)
-- Name: sale_order fk_sale_order_member; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sale_order
    ADD CONSTRAINT fk_sale_order_member FOREIGN KEY (member_id) REFERENCES public.member(id);


--
-- TOC entry 4766 (class 2606 OID 25686)
-- Name: favourite member_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favourite
    ADD CONSTRAINT member_id FOREIGN KEY (member_id) REFERENCES public.member(id) NOT VALID;


--
-- TOC entry 4767 (class 2606 OID 25692)
-- Name: favourite product_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.favourite
    ADD CONSTRAINT product_id FOREIGN KEY (product_id) REFERENCES public.product(id) NOT VALID;


--
-- TOC entry 4768 (class 2606 OID 25681)
-- Name: review sale_order_item_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.review
    ADD CONSTRAINT sale_order_item_id FOREIGN KEY (sale_order_item_id) REFERENCES public.sale_order_item(id) NOT VALID;


-- Completed on 2024-07-12 15:14:32

--
-- PostgreSQL database dump complete
--

