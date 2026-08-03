module ApplicationHelper
  def money(amount, company: nil, precision: 2)
    symbol = company&.currency_symbol.presence || "MK"
    value = amount || 0

    "#{symbol} #{number_with_precision(value, precision: precision, delimiter: ",", separator: ".")}"
  end
end
