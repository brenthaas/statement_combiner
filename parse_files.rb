require 'csv'
require 'pry'

# Headers only need to be a subset of the headers in the CSV

SFFIRE_HEADERS = [
  "Transaction ID",
  "Posting Date",
  "Effective Date",
  "Transaction Type",
  "Amount",
  "Check Number",
  "Reference Number",
  "Description",
  "Transaction Category",
  "Type",
  "Balance"
]

CITI_HEADERS = [
  "Status",
  "Date",
  "Description",
  "Debit",
  "Credit"
]

AMAZON_HEADERS = [
  "Order Date",
  "Order ID",
  "Title",
  "Category",
  "ASIN/ISBN",
  "UNSPSC Code"
]

CASH_HEADERS = [
  "date",
  "what",
  "price"
]

MAPPINGS = {
  amazon: {
    date: 'Order Date',
    title: 'Title',
    amount: 'Item Total'
  },
  cash:{
    date: 'date',
    title: 'what',
    amount: 'price'
  },
  citi: {
    date: 'Date',
    title: 'Description',
    amount: 'Debit'
  },
  sffire: {
    date: 'Posting Date',
    title: 'Description',
    amount: 'Amount'
  }
}

IGNORED_ROWS = [
  'AUTO-PMT', # Citi deposit
  'CHASE CREDIT CRD ENTRY: AUTOPAY', # Chase (see Amazon)
]

data = []
ARGV.each do |arg|
  csv = CSV.read(arg, headers: true)

  mapping = ''
  if csv.headers.intersection(SFFIRE_HEADERS) == SFFIRE_HEADERS
    #puts "#{arg} is a SFFire doc"
    mapping = :sffire
    date_format = "%m/%d/%Y"
  elsif csv.headers.intersection(CITI_HEADERS) == CITI_HEADERS
    #puts "#{arg} is a Citi doc"
    mapping = :citi
    date_format = "%m/%d/%Y"
  elsif csv.headers.intersection(AMAZON_HEADERS) == AMAZON_HEADERS
    # puts "#{arg} is a Amazon doc"
    mapping = :amazon
    date_format = "%m/%d/%y"
  elsif csv.headers.intersection(CASH_HEADERS) == CASH_HEADERS
    # puts "#{arg} is a Cash doc"
    mapping = :cash
    date_format = "%m/%d/%y"
  else
    puts "#{arg} is an UNKNOWN doc type!!"
    next
  end

  csv.each do |row|
    amount = if row[MAPPINGS[mapping][:amount]].to_s.start_with? '$'
      row[MAPPINGS[mapping][:amount]][1..-1].to_f
    else
      row[MAPPINGS[mapping][:amount]].to_f
    end

    date = Date.strptime(row[MAPPINGS[mapping][:date]], date_format).strftime('%Y/%m/%d')

    # Inverse amounts
    if %i[citi cash amazon].include? mapping
      amount = 0 - amount
    end

    next if IGNORED_ROWS.any? { |text| row[MAPPINGS[mapping][:title]].include? text }

    data.push(
      {
        date: date,
        title: row[MAPPINGS[mapping][:title]],
        amount: sprintf('%.02f' % amount),
        from: mapping
      }
    )

  end
end

data.sort_by! { |row| row[:date] }

output_csv = CSV.generate(
  write_headers: true,
  headers: ['date', 'description', 'category', 'amount', 'account']
) do |output|
  data.each { |row| output.add_row [row[:date], row[:title], nil, row[:amount], row[:from]] }
end

puts output_csv
