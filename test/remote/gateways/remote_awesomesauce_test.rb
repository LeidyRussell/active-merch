require 'test_helper'

class RemoteAwesomesauceTest < Test::Unit::TestCase
  def setup
    @gateway = AwesomesauceGateway.new(merchant: 'test', secret: 'abc123')

    @amount = 100
    @credit_card = credit_card(number: '4111111111111111')
    @declined_card = credit_card(number: '4000300011112220')
    @invalid_card = credit_card(number: '123')
    @expired_card = credit_card(number: '4111111111111111', year: '2000')

    @options = {
      currency: 'USD'
    }
  end

  def test_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@gateway.options[:secret], transcript)
    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal true, response.params['succeeded']
  end

  def test_successful_purchase_with_more_options
    options = {
      billing_address: address,
      currency: 'GBP'
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal true, response.params['succeeded']
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal false, response.params['succeeded']
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_failed_purchase_with_invalid_number
    response = @gateway.purchase(@amount, @invalid_card, @options)
    assert_failure response
    assert_equal false, response.params['succeeded']
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_successful_authorize
    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal true, response.params['succeeded']
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal false, response.params['succeeded']
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal true, capture.params['succeeded']
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount - 1, auth.authorization)
    assert_success capture
  end

  def test_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal false, response.params['succeeded']
    assert_equal Gateway::STANDARD_ERROR_CODE[:bad_transaction_reference], response.error_code
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal true, refund.params['succeeded']
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount - 1, purchase.authorization)
    assert_success refund
  end

  def test_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal false, response.params['succeeded']
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal true, void.params['succeeded']
  end

  def test_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal false, response.params['succeeded']
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal true, response.params['succeeded']
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_equal false, response.params['succeeded']
  end

  def test_invalid_login
    gateway = AwesomesauceGateway.new(merchant: '', secret: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal false, response.params['succeeded']
  end
end