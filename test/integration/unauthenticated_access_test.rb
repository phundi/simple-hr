require "test_helper"

class UnauthenticatedAccessTest < ActionDispatch::IntegrationTest
  test "incognito cannot access employees index" do
    get employees_path
    assert_redirected_to new_user_session_path
  end

  test "incognito cannot access pay_periods index" do
    get pay_periods_path
    assert_redirected_to new_user_session_path
  end

  test "incognito cannot access company_configs index" do
    get company_configs_path
    assert_redirected_to new_user_session_path
  end
end
