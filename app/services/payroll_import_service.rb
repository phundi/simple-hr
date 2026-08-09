# frozen_string_literal: true

require 'roo'

class PayrollImportService
  attr_reader :company, :file, :actor, :parsed_rows, :detected_rates, :errors

  HEADER_SYNONYMS = {
    /basic/i => :basic_salary,
    /addition benefit|house/i => :house_allowance,
    /name/i => :name,
    /first name/i => :first_name,
    /last name/i => :last_name,
    /position/i => :position,
    /doner|donor|project/i => :department,
    /gender/i => :gender,
    /bank account/i => :bank_account_number
  }.freeze

  def initialize(company, file, actor = nil)
    @company = company
    @file = file
    @actor = actor
    @parsed_rows = []
    @detected_rates = {}
    @errors = []
  end

  def call
    xlsx = Roo::Spreadsheet.open(@file.path)
    sheet = detect_sheet(xlsx)
    raise "No payroll sheet detected" unless sheet

    header_row = find_header_row(sheet)
    headers = normalize_headers(sheet.row(header_row))

    # check for rates row at row 3 if present and numeric
    if sheet.row(3).any? { |c| c.is_a?(Numeric) }
      extract_rates_from_row(sheet.row(3))
    end

    ((header_row + 1)..sheet.last_row).each do |i|
      row = Hash[[headers, sheet.row(i)].transpose]
      next if row.values.all?(&:nil?)

      parsed = map_row(row)
      @parsed_rows << parsed
    end

    { rows: @parsed_rows, rates: @detected_rates, errors: @errors }
  end

  private

  def detect_sheet(xlsx)
    xlsx.sheets.each do |name|
      sh = xlsx.sheet(name)
      first_10 = (1..[sh.last_row, 10].min).map { |r| sh.row(r).join(' ').upcase }
      return sh if first_10.any? { |c| c =~ /BASIC/ }
    end
    # fallback to first sheet
    xlsx.sheet(0)
  end

  def find_header_row(sheet)
    (1..[sheet.last_row, 10].min).each do |r|
      row = sheet.row(r).map { |c| c.to_s.strip }
      return r if row.any? { |c| c =~ /BASIC/i }
    end
    1
  end

  def normalize_headers(headers)
    headers.map do |h|
      next nil if h.nil?
      sym = nil
      HEADER_SYNONYMS.each do |re, to|
        if h.to_s =~ re
          sym = to
          break
        end
      end
      sym || h.to_s.parameterize.underscore.to_sym
    end
  end

  def extract_rates_from_row(row)
    # look for common rates like 0.1, 0.01, 0.165
    row.each do |c|
      next unless c.is_a?(Numeric)
      if (c - 0.1).abs < 0.0001
        @detected_rates[:house_allowance_rate] = 0.1
      elsif (c - 0.01).abs < 0.0001
        (@detected_rates[:small_rates] ||= []) << 0.01
      elsif (c - 0.165).abs < 0.0001
        @detected_rates[:admin_vat_rate] = 0.165
      end
    end
  end

  def map_row(row)
    out = {}
    row.each do |k, v|
      key = k
      if key == :name && v.to_s.include?(' ')
        parts = v.to_s.split(' ', 2)
        out[:first_name] = parts[0]
        out[:last_name] = parts[1]
      else
        out[key] = v
      end
    end
    out
  end
end
