
#
# Tables in pay941010
#
# This file generated automatically by getschema.tcl
# on Mon Oct 10 15:22:15 EDT 1994
#

# name of the payment database
set paydb pay941010

# sybase account used for read-write access to the database
set rwaccount pay941010
set rwpassword pay941010

# sybase account used for read-only access to the database
set roaccount state941010
set ropassword state941010


#
# Fields in pay941010.principal
#


# has identity field principal_id
set tables(principal) {
    \"$p(access_name)\",
    \"$p(access_password)\",
    \"$p(principal_name)\",
    \"$p(address_1)\",
    \"$p(address_2)\",
    \"$p(address_3)\",
    \"$p(postal_code)\",
    \"$p(country)\",
    \"$p(telephone)\",
    \"$p(fax)\",
    \"$p(email)\",
    \"$p(secret_key)\",
    $p(secretkey_id),
    \"$p(home_url)\",
    \"$p(status)\",
    \"$p(rtype)\"
}
set identity(principal) principal_id


#
# Fields in pay941010.secretkey
#


# has identity field secretkey_id
set tables(secretkey) {
    $p(principal_id),
    $p(expiration_date),
    \"$p(secret_key)\"
}
set identity(secretkey) secretkey_id


#
# Fields in pay941010.account
#


# has identity field account_id
set tables(account) {
    \"$p(card_number)\",
    \"$p(expiration_date)\",
    \"$p(billing_name)\",
    \"$p(address_1)\",
    \"$p(address_2)\",
    \"$p(address_3)\",
    \"$p(postal_code)\",
    \"$p(country)\",
    \"$p(currency)\",
    \"$p(status)\",
    \"$p(rtype)\"
}
set identity(account) account_id


#
# Fields in pay941010.balance
#


# has identity field balance_id
set tables(balance) {
    $p(account_id),
    $p(cash_balance)
}
set identity(balance) balance_id


#
# Fields in pay941010.principal_account
#


# has identity field principal_account_id
set tables(principal_account) {
    $p(principal_id),
    $p(account_id),
    $p(confirm_threshold),
    $p(max_threshold),
    \"$p(name)\",
    \"$p(flags)\",
    \"$p(status)\",
    $p(omi_confirm),
    $p(omi_max)
}
set identity(principal_account) principal_account_id


#
# Fields in pay941010.challenge
#


# has identity field challenge_id
set tables(challenge) {
    $p(principal_id),
    \"$p(challenge_name)\",
    \"$p(challenge_value)\"
}
set identity(challenge) challenge_id


#
# Fields in pay941010.transaction_log
#


# has identity field transaction_log_id
set tables(transaction_log) {
    $p(amount),
    \"$p(currency)\",
    $p(transaction_date),
    $p(initiator),
    $p(benificiary),
    $p(from_account),
    $p(to_account),
    \"$p(transaction_type)\",
    \"$p(ip_address)\",
    \"$p(domain)\",
    $p(expiration),
    \"$p(url)\",
    \"$p(description)\"
}
set identity(transaction_log) transaction_log_id


#
# Fields in pay941010.duplicate
#


# has identity field duplicate_id
set tables(duplicate) {
    $p(transaction_log_id),
    $p(initiator),
    $p(benificiary),
    \"$p(domain)\",
    $p(expiration)
}
set identity(duplicate) duplicate_id


#
# Fields in pay941010.authorize
#


# has identity field authorize_id
set tables(authorize) {
    $p(amount),
    \"$p(currency)\",
    $p(transaction_log_id),
    \"$p(status)\",
    \"$p(result)\",
    \"$p(request_type)\",
    $p(authorize_date)
}
set identity(authorize) authorize_id


#
# Fields in pay941010.nextchallenge
#


# has identity field nextchallenge_id
set tables(nextchallenge) {
    $p(principal_id),
    $p(challenge_id)
}
set identity(nextchallenge) nextchallenge_id


#
# Fields in pay941010.principal_authentication
#


# has identity field principal_authentication_id
set tables(principal_authentication) {
    $p(principal_id),
    \"$p(scheme)\"
}
set identity(principal_authentication) principal_authentication_id


#
# Fields in pay941010.softnetkey
#


# has identity field softnetkey_id
set tables(softnetkey) {
    $p(principal_id),
    \"$p(secret_key)\"
}
set identity(softnetkey) softnetkey_id


#
# Fields in pay941010.snk
#


# has identity field snk_id
set tables(snk) {
    $p(principal_id),
    \"$p(secret_key)\"
}
set identity(snk) snk_id


#
# Fields in pay941010.ntimes
#


# has identity field ntimes_id
set tables(ntimes) {
    $p(uses),
    $p(maxuses),
    $p(expiration)
}
set identity(ntimes) ntimes_id


#
# Fields in pay941010.shoppingcart
#


# has identity field shoppingcart_id
set tables(shoppingcart) {
    $p(principal_id),
    $p(merchant_id),
    $p(create_date),
    $p(expiration_date),
    $p(purchased)
}
set identity(shoppingcart) shoppingcart_id


#
# Fields in pay941010.scart_item
#


# has identity field scart_item_id
set tables(scart_item) {
    $p(shoppingcart_id),
    $p(amount),
    \"$p(currency)\",
    $p(transaction_date),
    \"$p(domain)\",
    $p(expiration),
    \"$p(url)\",
    \"$p(aurl)\",
    \"$p(description)\",
    $p(valid_until),
    \"$p(detail)\",
    $p(quantity)
}
set identity(scart_item) scart_item_id


#
# Fields in pay941010.settle
#


# has identity field settle_id
set tables(settle) {
    $p(transaction_log_id),
    $p(settle_log_id)
}
set identity(settle) settle_id

