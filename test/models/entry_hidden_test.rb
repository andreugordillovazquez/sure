require "test_helper"

class EntryHiddenTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:empty)
    @account = @family.accounts.create! name: "Checking", currency: "USD", balance: 5000, accountable: Depository.new
  end

  test "excluding_hidden scope filters hidden entries" do
    visible = create_transaction(account: @account, amount: 50)
    hidden = create_transaction(account: @account, amount: 100)
    hidden.update!(hidden: true)

    results = @account.entries.excluding_hidden
    assert_includes results, visible
    assert_not_includes results, hidden
  end

  test "hidden entries are excluded from income statement totals" do
    category = @family.categories.create!(name: "Food")

    create_transaction(account: @account, amount: 80, category: category)
    hidden_entry = create_transaction(account: @account, amount: 200, category: category)
    hidden_entry.update!(hidden: true)

    income_statement = IncomeStatement.new(@family)
    totals = income_statement.totals(date_range: Period.last_30_days.date_range)

    assert_equal Money.new(80, "USD"), totals.expense_money
  end

  test "hidden entries are excluded from transaction search" do
    create_transaction(account: @account, amount: 50)
    hidden_entry = create_transaction(account: @account, amount: 100)
    hidden_entry.update!(hidden: true)

    search = Transaction::Search.new(@family)
    assert_equal 1, search.totals.count
  end

  test "hidden defaults to false" do
    entry = create_transaction(account: @account, amount: 50)
    assert_equal false, entry.hidden
  end
end
