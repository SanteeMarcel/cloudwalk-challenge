-- Name: identity_validation_status; Type: TYPE

CREATE TYPE public.identity_validation_status AS ENUM (
    'approved',
    'pending',
    'declined'
);

-- Name: status; Type: TYPE

CREATE TYPE public.status AS ENUM (
    'active',
    'inactive',
    'blocked'
);

-- Name: users; Type: TABLE

CREATE TABLE public.users (
    id serial primary key,
    phone_number character varying,
    email character varying(100),
    last_sign_in_at timestamp without time zone,
    identity_validation_status public.identity_validation_status DEFAULT 
'approved'::public.identity_validation_status NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now()
);

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree 
(email);

-- Name: merchants; Type: TABLE

CREATE TABLE public.merchants (
    user_id serial primary key NOT NULL,
    merchant_name character varying(150) NOT NULL,
    mcc character varying(4),
    document_number character varying(14),
    status public.status DEFAULT 'active'::public.status NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX index_merchants_on_document_number_using_hash ON 
public.merchants USING hash (document_number);
CREATE INDEX index_merchants_on_merchant_name_gin_trgm ON public.merchants 
USING gin (merchant_name public.gin_trgm_ops);

-- Name: transactions; Type: TABLE

CREATE TABLE public.transactions (
    id integer NOT NULL,
    merchant_id bigint,
    amount numeric(12,2),
    card_number character varying(30),
    card_holder_name character varying,
    installments integer,
    metadata jsonb,
    card_brand character varying,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);

CREATE INDEX card_number_index ON public.transactions USING btree 
(card_number);
CREATE INDEX idx_transactions_on_merchant_id_and_created_at ON 
public.transactions USING btree (merchant_id, created_at);

-- Name: chargebacks; Type: TABLE
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE public.chargebacks (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    transaction_id bigint NOT NULL,
    amount numeric(12,2),
    reason character varying,
    merchant_id bigint NOT NULL,
    status character varying,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);

CREATE INDEX index_chargebacks_on_merchant_id ON public.chargebacks USING 
btree (merchant_id);
CREATE UNIQUE INDEX index_chargebacks_on_transaction_id ON 
public.chargebacks USING btree (transaction_id);

ALTER TABLE ONLY public.merchants
    ADD CONSTRAINT merchants_user_id_fkey FOREIGN KEY (user_id) REFERENCES 
public.users(id) ON DELETE RESTRICT;

-- MOCK DATA

INSERT INTO public.users (phone_number, email, last_sign_in_at,
identity_validation_status) VALUES ('+5511999999999', 'john@doe.com', '2022-08-11', 'approved');
INSERT INTO public.users (phone_number, email, last_sign_in_at,
identity_validation_status) VALUES ('+5511999999998', 'mary@doe.com', '2022-08-11', 'approved');
INSERT INTO public.users (phone_number, email, last_sign_in_at,
identity_validation_status) VALUES ('+5511999999997', 'arthur@doe.com', '2022-08-11', 'approved');
INSERT INTO public.users (phone_number, email, last_sign_in_at,
identity_validation_status) VALUES ('+5511999999996', 'jane@doe.com', '2022-08-11', 'declined');
INSERT INTO public.users (phone_number, email, last_sign_in_at,
identity_validation_status) VALUES ('+5511999999995', 'ben@doe.com', '2019-08-11', 'approved');

INSERT INTO public.merchants (user_id, merchant_name, mcc, document_number)
VALUES (1, 'Merchant 1', '5912', '12345678901');
INSERT INTO public.merchants (user_id, merchant_name, mcc, document_number)
VALUES (2, 'Merchant 2', '5912', '12345678902');
INSERT INTO public.merchants (user_id, merchant_name, mcc, document_number)
VALUES (3, 'Merchant 3', '5912', '12345678903');
INSERT INTO public.merchants (user_id, merchant_name, mcc, document_number)
VALUES (4, 'Merchant 4', '5912', '12345678904');
INSERT INTO public.merchants (user_id, merchant_name, mcc, document_number)
VALUES (5, 'Merchant 5', '5912', '12345678905');

INSERT INTO public.transactions (id, merchant_id, amount, card_number,
card_holder_name, installments, metadata, card_brand) VALUES (1, 1, 100.00, '12345678901', 'John Doe', 1, '{}', 'visa');
INSERT INTO public.transactions (id, merchant_id, amount, card_number,
card_holder_name, installments, metadata, card_brand) VALUES (2, 2, 200.00, '12345678902', 'Mary Doe', 2, '{}', 'visa');
INSERT INTO public.transactions (id, merchant_id, amount, card_number,
card_holder_name, installments, metadata, card_brand) VALUES (3, 3, 300.00, '12345678903', 'Arthur Doe', 3, '{}', 'visa');
INSERT INTO public.transactions (id, merchant_id, amount, card_number,
card_holder_name, installments, metadata, card_brand) VALUES (4, 4, 500000.00, '12345678904', 'Jane Doe', 4, '{}', 'visa');
INSERT INTO public.transactions (id, merchant_id, amount, card_number,
card_holder_name, installments, metadata, card_brand) VALUES (5, 5, 500.00, '12345678905', 'Ben Doe', 5, '{}', 'visa');

INSERT INTO public.chargebacks (transaction_id, amount, reason, merchant_id,
status) VALUES (3, 100.00, 'reason', 1, 'received');
INSERT INTO public.chargebacks (transaction_id, amount, reason, merchant_id,
status) VALUES (1, 100.00, 'reason', 1, 'pending');

-- Test Query

SELECT users.id AS user_id
FROM   PUBLIC.users
JOIN   PUBLIC.merchants
ON     users.id = merchants.user_id
JOIN
       (
        SELECT   merchant_id,
                Sum(amount)
        FROM     PUBLIC.transactions
        GROUP BY merchant_id) transactionssum
ON     users.id = transactionssum.merchant_id
WHERE  merchants.status = 'active'
AND    merchants.user_id NOT IN
       (
        SELECT merchant_id
        FROM   PUBLIC.chargebacks
        WHERE  status = 'received' )
AND    users.identity_validation_status = 'approved'
AND    transactionssum.sum < 500000.00
AND    users.last_sign_in_at > Now() - interval '1 month'
