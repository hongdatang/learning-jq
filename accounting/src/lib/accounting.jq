# accounting.jq -- Shared library for the Lemonade Stand tutorials
#
# Usage:  import "accounting" as acct;
#    or:  include "accounting";
#    or:  jq -L accounting/src/lib -f program.jq data.json
#
# These are reusable functions that work across Lessons 11-12.

# ──────────────────────────────────────────────────────
#  Currency formatting
# ──────────────────────────────────────────────────────

# Format a number as dollars: 8 -> "$8.00", -4 -> "-$4.00"
def format_currency:
  if . < 0
  then "-$" + ((. * -100 | round / 100) | tostring | split(".")
    | if length == 1 then .[0] + ".00"
      elif (.[1] | length) == 1 then join(".") + "0"
      else join(".")
      end)
  else "$" + (. * 100 | round / 100 | tostring | split(".")
    | if length == 1 then .[0] + ".00"
      elif (.[1] | length) == 1 then join(".") + "0"
      else join(".")
      end)
  end;

# Shorthand alias
def dollars: format_currency;

# ──────────────────────────────────────────────────────
#  Text formatting helpers
# ──────────────────────────────────────────────────────

# Right-pad a string to width w
def pad(w):
  . + " " * ([w - length, 0] | max);

# Left-pad a string to width w (right-align)
def lpad(w):
  " " * ([w - length, 0] | max) + .;

# ──────────────────────────────────────────────────────
#  Transaction aggregation
# ──────────────────────────────────────────────────────

# Sum the debit amounts in an array of transactions
def total_debits:
  [.[] | .debit.amount] | add // 0;

# Sum the credit amounts in an array of transactions
def total_credits:
  [.[] | .credit.amount] | add // 0;

# Get the net balance for a specific account code from transactions.
# Debits increase the account, credits decrease it (for assets/expenses).
# Pass the full transactions array as input.
def account_balance(code):
  ( [.[] | select(.debit.account == code)  | .debit.amount]  | add // 0 ) -
  ( [.[] | select(.credit.account == code) | .credit.amount] | add // 0 );

# ──────────────────────────────────────────────────────
#  Account type predicates
# ──────────────────────────────────────────────────────

# These work on a chart_of_accounts entry (an object with .type)
def is_asset:     .type == "asset";
def is_liability: .type == "liability";
def is_equity:    .type == "equity";
def is_revenue:   .type == "revenue";
def is_expense:   .type == "expense";

# Check if an account code falls in a range
def is_asset_code:     startswith("1");
def is_liability_code: startswith("2");
def is_equity_code:    startswith("3");
def is_revenue_code:   startswith("4");
def is_expense_code:   startswith("5") or startswith("6");

# ──────────────────────────────────────────────────────
#  Percentage and margin
# ──────────────────────────────────────────────────────

# Format a number as a percentage: 0.5098 -> "51.0%"
def pct:
  . * 1000 | round / 10 | tostring + "%";

# margin(part; whole) -> "52.4%"
def margin(part; whole):
  if whole == 0
  then "N/A"
  else ((part / whole * 1000 | floor) / 10 | tostring) + "%"
  end;
