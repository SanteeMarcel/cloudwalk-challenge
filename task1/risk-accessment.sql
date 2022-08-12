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
