require "test_helper"

class ImportTemplatesControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_import_template_url
    assert_response :success
  end

  test "should create and redirect to preview" do
    file = fixture_file_upload("files/employees_sample.csv", "text/csv")

    post import_templates_url, params: {
      import_template: {
        name: "August Import",
        file: file
      }
    }

    assert_response :redirect
    assert_match %r{/import_templates/\d+/preview}, response.redirect_url
  end

  test "should require file on create" do
    post import_templates_url, params: {
      import_template: {
        name: "Missing File"
      }
    }

    assert_response :unprocessable_entity
  end
end
