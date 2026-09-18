# The shop's wholesale book: the same orders table, read as its own kind of
# order. Wholesale is not a status an order moves through, it is what the
# order is from the day it is taken, on trade terms to a trade account, which
# is what makes it a class rather than another value in a column.
#
# It declares no janela block. The dashboard it wants is the one Order already
# declares, and its numbers are its own rows because ActiveRecord adds the
# type condition to every query (ADR 031).
class WholesaleOrder < Order
end
