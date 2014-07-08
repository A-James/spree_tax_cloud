require 'spec_helper'

describe 'Checkout', js: true do

  let!(:country) { create(:country, name: "United States of America", states_required: true) }
  let!(:state) { create(:state, name: "Washington", abbr: "WA", country: country) }
  let!(:shipping_method) { create(:shipping_method) }
  let!(:stock_location) { create(:stock_location, country_id: stock_location_address.country.id, state_id: stock_location_address.state.id, address1: stock_location_address.address1, city: stock_location_address.city, zipcode: stock_location_address.zipcode) }
  let!(:mug) { create(:product, name: "RoR Mug") }
  let!(:payment_method) { create(:check_payment_method) }
  let!(:zone) { create(:zone) }

  before do
    Spree::Product.delete_all
    @product = create(:product, name: "RoR Mug", price: 10)
    # Not sure if we should fix spree core to not require a shipping category on products...
    @product.shipping_category = shipping_method.shipping_categories.first
    @product.save!

    stock_location.stock_items.update_all(count_on_hand: 1)
    
    Spree::State.find_or_create_by!(name: "Alabama", abbr: "AL", country: Spree::Country.where(name: "United States of America").first)

    create(:zone)
    tax_rate = Spree::TaxRate.create(amount: 0, name: "Sales Tax", zone: Spree::Zone.first, calculator: Spree::Calculator::TaxCloudCalculator.create, tax_category: Spree::TaxCategory.first, show_rate_in_label: false)
  end

  before do
    visit spree.products_path
    click_link "RoR Mug"
    click_button "add-to-cart-button"
    click_button "Checkout"
  end

  it "should display tax lookup error if invalid address" do
    fill_in "order_email", with: "test@example.com"
    click_button "Continue"

    fill_in_address(alabama_address)
    fill_in "order_bill_address_attributes_zipcode", with: '12345'

    click_button "Save and Continue"
    click_button "Save and Continue"

    click_button "Save and Continue"
    page.should have_content("Address Verification Failed")
  end

  it "should tolerate a missing sku without throwing a Tax Cloud exception" do
    fill_in "order_email", with: "test@example.com"
    click_button "Continue"

    fill_in_address(alabama_address)
    Spree::Product.where(name: "RoR Mug").first.update_attributes(sku: "")

    click_button "Save and Continue"
    page.should_not have_content("Address Verification Failed")
  end

  it "should calculate and display tax on payment step and allow full checkout" do
    fill_in "order_email", with: "test@example.com"
    click_button "Continue"
    fill_in_address(alabama_address)
    click_button "Save and Continue"
    click_button "Save and Continue"
    # page.should have_content("Tax: $0.00") # Alabama orders are configured under this API key to have no tax

    click_on "Save and Continue"
    expect(current_path).to match(spree.order_path(Spree::Order.last))
  end

  it 'should not break when removing all items from cart after a tax calculation has been created' do
    fill_in "order_email", with: "test@example.com"
    click_button "Continue"
    fill_in_address(alabama_address)
    click_button "Save and Continue"
    click_button "Save and Continue"
    page.should have_content("Order Total: $10.00") # Alabama orders are configured under this API key to have no tax
    visit spree.cart_path
    find('a.delete').click
    page.should have_content('Shopping Cart')
    page.should_not have_content('Internal Server Error')
  end

  it 'completes TaxCloud test case 1a' do
    fill_in "order_email", with: "test@example.com"
    click_button "Continue"
    page.should have_content("Order Total: $10")
    fill_in_address(test_case_1a_address)
    click_button "Save and Continue"
    # From TaxCloud:
    # This address will not verify correctly (the VerifyAddress API call
    # will return an error). That is okay. Occasionally an address cannot be verified. When
    # that happens, pass the destination address as originally entered to Lookup. The address
    # can still be passed to Lookup. The only error that should prevent an order from processing
    # is when the USPSID used is not valid, or a customer provided zip code does not exist
    # within the customer provided state (discussed later in Test Case 7, Handling Errors).
    click_button "Save and Continue"
    page.should have_content("Sales Tax $0.94")
  end

  it 'completes TaxCloud test case 1b' do
    fill_in "order_email", with: "test@example.com"
    click_button "Continue"
    page.should have_content("Order Total: $10")
    fill_in_address(test_case_1b_address)
    click_button "Save and Continue"
    # From TaxCloud:
    # The destination address used as-is will not give the most accurate
    # rate. The verified address will give the correct result.
    click_button "Save and Continue"
    page.should have_content("Sales Tax $0.95")
  end
  
  def fill_in_address(address)
    fieldname = "order_bill_address_attributes"
    fill_in "#{fieldname}_firstname", with: address.first_name
    fill_in "#{fieldname}_lastname", with: address.last_name
    fill_in "#{fieldname}_address1", with: address.address1
    fill_in "#{fieldname}_city", with: address.city
    select address.country.name, from: "#{fieldname}_country_id"
    select address.state.name, from: "#{fieldname}_state_id"
    fill_in "#{fieldname}_zipcode", with: address.zipcode
    fill_in "#{fieldname}_phone", with: address.phone
  end
  
  def stock_location_address
    stock_location_address = Spree::Address.new(
    firstname: "Testing",
    lastname: "Location",
    address1: "3121 W Government Way",
    city: "Seattle",
    country: Spree::Country.where(name: "United States of America").first,
    state: Spree::State.where(abbr: "WA").first,
    zipcode: "98199-1402",
    phone: "(555) 5555-555")
  end
  
  def test_case_1a_address
    stock_location_address = Spree::Address.new(
    firstname: "John",
    lastname: "Doe",
    address1: "1 3rd Street",
    city: "Seattle",
    country: Spree::Country.where(name: "United States of America").first,
    state: Spree::State.where(abbr: "WA").first,
    zipcode: "98001",
    phone: "(555) 5555-555")
  end
  
  def test_case_1b_address
    stock_location_address = Spree::Address.new(
    firstname: "John",
    lastname: "Doe",
    address1: "354 Union Ave NE",
    city: "Renton",
    country: Spree::Country.where(name: "United States of America").first,
    state: Spree::State.where(abbr: "WA").first,
    zipcode: "98059",
    phone: "(555) 5555-555")
  end
  
  def alabama_address
    alabama_address = Spree::Address.new(
    firstname: "John",
    lastname: "Doe",
    address1: "143 Swan Street",
    city: "Montgomery",
    country: Spree::Country.where(name: "United States of America").first,
    state: Spree::State.where(name: "Alabama").first,
    zipcode: "36110",
    phone: "(555) 5555-555")
  end
  
end
