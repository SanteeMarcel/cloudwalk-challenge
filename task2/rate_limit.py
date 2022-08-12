from collections import OrderedDict
from typing import OrderedDict, List
from datetime import datetime
import json

DIFF_IPS_ATTEMPS = 2
MIN_SECONDS_DIFFERENT_IPS = 1800
LARGE_AMOUNT_ATTEMPS = 3
MIN_SECONDS_LARGE_AMOUNTS = 300
LARGE_AMOUNT = 500


class Transaction:
    def __init__(self, user_id: int, card_number: str, amount: int, ip: str, timestamp: str):
        self.user_id = user_id
        self.card_number = card_number
        self.amount = amount
        self.ip = ip
        date, time = timestamp.split('T')
        year, month, day = date.split('-')
        hour, minute, second = time.split(':')
        second = second[:-1]  # remove 'Z'
        self.timestamp = datetime(int(year), int(month), int(
            day), int(hour), int(minute), int(second))


"""
Why a hashmap instead of array, as suggested:
With an array we would need to iterate every transaction O(n) time.
With a dict we can lookup transactions for the same card_number+user_id O(1) time,
and only iterate the array for this card_number+user_id.
Trade-off: We need more space for every different card_number+user_id.
"""
transactions: OrderedDict[str, List[Transaction]] = OrderedDict()


def rate_limit(transaction: Transaction):
    key = transaction.card_number + str(transaction.user_id)
    current_time = transaction.timestamp

    if key in transactions:
        transactions[key].append(transaction)
    else:
        transactions[key] = [transaction]
        return True

    if len(transactions[key]) > DIFF_IPS_ATTEMPS:
        recent_transactions = [t for t in transactions[key] if (
            current_time - t.timestamp).seconds < MIN_SECONDS_DIFFERENT_IPS]
        unique_ips = set([t.ip for t in recent_transactions])
        if len(unique_ips) > DIFF_IPS_ATTEMPS:
            return False

    if len(transactions[key]) > LARGE_AMOUNT_ATTEMPS:
        recent_transactions = [t for t in transactions[key] if (
            current_time - t.timestamp).seconds < MIN_SECONDS_LARGE_AMOUNTS]
        high_value_transactions = [
            t for t in recent_transactions if t.amount > LARGE_AMOUNT]
        if len(high_value_transactions) > LARGE_AMOUNT_ATTEMPS:
            return False

    return True


"""
From time to time, we can delete transactions from the hashmap older than 30 minutes.
deleting during rate_limit is: 1. too much responsibility for the function, 2. slower for the user.
"""


def delete_old_transactions():
    for key in transactions:
        transactions[key] = [t for t in transactions[key]
                             if (datetime.now() - t.timestamp).seconds < max(MIN_SECONDS_DIFFERENT_IPS, MIN_SECONDS_LARGE_AMOUNTS)]


def main():
    with open('transactions.json', 'r') as f:
        transactions = json.load(f)
        for line in transactions:
            transaction = Transaction(
                line['user_id'], line['card_number'], line['amount'], line['ip'], line['timestamp'])
            if rate_limit(transaction):
                print('Success')
            else:
                print('Rate limit exceeded')


if __name__ == "__main__":
    main()
