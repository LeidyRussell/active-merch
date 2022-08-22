require 'test_helper'

class AwesomesauceTest < Test::Unit::TestCase

  def setup
    @gateway = AwesomesauceGateway.new(merchant: 'test', secret: 'abc123')

    @amount = 100
    @credit_card = credit_card(number: '4111111111111111', month: '12', year: '2024',
      verification_value: '123', first_name: 'Bobby', last_name: 'Emmit')
    @expired_card = credit_card(number: '4111111111111111', year:2021)

    @reference = 'reference123'
    
    @options = {
      billing_address: address,
      currency: 'USD'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response,
      successful_capture_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal '10.00', response.params['amount']
    assert_equal 'purchb1dawNaJ', response.params['id']
    assert_equal true, response.params['succeeded']
  end

  def test_failed_purchase_with_invalid_card
    @gateway.expects(:ssl_post).returns(failed_purchase_response,
      failed_capture_response)

    response = @gateway.purchase(@amount, credit_card('4222222222222220'), @options)
    assert_failure response
    assert_equal 'autherr01E9gMqudx', response.params['id']
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize_with_failed_capture
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response,
      failed_capture_response)

    response = @gateway.purchase(@amount, credit_card('4222222222222220'), @options)
    assert_failure response
    assert_equal 'autherr01E9gMqudx', response.params['id']
    assert_equal Gateway::STANDARD_ERROR_CODE[:bad_transaction_reference], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_post).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'purchb1dawNaJ', response.params['id']
    assert_equal '10.00', response.params['amount']
    assert_equal true, response.params['succeeded']
  end

  def test_failed_authorize
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @expired_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:expired_card], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.capture(@amount, @reference, @options)
    assert_success response
    assert_equal 'capCm-rFz8N', response.params['id']
  end

  def test_failed_capture
    @gateway.expects(:ssl_post).returns(failed_capture_response)

    response = @gateway.capture(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:bad_transaction_reference], response.error_code
  end

  def test_successful_refund
    @gateway.expects(:ssl_post).returns(successful_capture_response)

    response = @gateway.refund(@amount, @reference, @options)
    assert_success response
    assert_equal 'capCm-rFz8N', response.params['id']
  end

  def test_failed_refund
    @gateway.expects(:ssl_post).returns(failed_refund_response)

    response = @gateway.refund(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:invalid_number], response.error_code
  end

  def test_successful_void
    @gateway.expects(:ssl_post).returns(successful_void_response)

    response = @gateway.void(@reference)
    assert_success response
  end

  def test_failed_void
    @gateway.expects(:ssl_post).returns(failed_void_response)

    response = @gateway.void(@reference)
    assert_failure response
  end

  def test_successful_verify
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response,
    successful_refund_response)

    response = @gateway.verify(@credit_card)
    assert_success response
    assert_equal 'purchb1dawNaJ', response.params['id']
    assert_equal true, response.params['succeeded']
    assert_equal '10.00', response.params['amount']
  end

  def test_successful_verify_with_failed_void
    @gateway.expects(:ssl_post).times(2).returns(successful_authorize_response,
      failed_refund_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_equal 'purchb1dawNaJ', response.params['id']
    assert_equal true, response.params['succeeded']
  end

  def test_failed_verify
    @gateway.expects(:ssl_post).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:expired_card], response.error_code
  end

  def test_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    <<~PRE_SCRUBBED
      opening connection to awesomesauce-staging.herokuapp.com:443...
      opened
      starting SSL for awesomesauce-staging.herokuapp.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /api/auth.json HTTP/1.1\r\nContent-Type: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: awesomesauce-staging.herokuapp.com\r\nContent-Length: 133\r\n\r\n"
      <- "{\"amount\":\"1.00\",\"name\":\"Longbob Longsen\",\"number\":\"4111111111111111\",\"cv2\":\"123\",\"exp\":\"202309\",\"merchant\":\"test\",\"secret\":\"abc123\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Connection: close\r\n"
      -> "Server: Cowboy\r\n"
      -> "Date: Mon, 22 Aug 2022 05:16:15 GMT\r\n"
      -> "Content-Length: 54\r\n"
      -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Via: 1.1 vegur\r\n"
      -> "\r\n"
      reading 54 bytes...
      -> "{\"succeeded\":true,\"id\":\"authrCYqrsXQ\",\"amount\":\"1.00\"}"
      read 54 bytes
      Conn close
    PRE_SCRUBBED
  end

  def post_scrubbed
    <<~POST_SCRUBBED
      opening connection to awesomesauce-staging.herokuapp.com:443...
      opened
      starting SSL for awesomesauce-staging.herokuapp.com:443...
      SSL established, protocol: TLSv1.2, cipher: ECDHE-RSA-AES128-GCM-SHA256
      <- "POST /api/auth.json HTTP/1.1\r\nContent-Type: application/json\r\nConnection: close\r\nAccept-Encoding: gzip;q=1.0,deflate;q=0.6,identity;q=0.3\r\nAccept: */*\r\nUser-Agent: Ruby\r\nHost: awesomesauce-staging.herokuapp.com\r\nContent-Length: 133\r\n\r\n"
      <- "{\"amount\":\"1.00\",\"name\":\"Longbob Longsen\",\"number\":\"[FILTERED]\",\"cv2\":\"[FILTERED]\",\"exp\":\"202309\",\"merchant\":\"test\",\"secret\":\"[FILTERED]\"}"
      -> "HTTP/1.1 200 OK\r\n"
      -> "Connection: close\r\n"
      -> "Server: Cowboy\r\n"
      -> "Date: Mon, 22 Aug 2022 05:16:15 GMT\r\n"
      -> "Content-Length: 54\r\n"
      -> "Cache-Control: max-age=0, private, must-revalidate\r\n"
      -> "Content-Type: application/json; charset=utf-8\r\n"
      -> "Via: 1.1 vegur\r\n"
      -> "\r\n"
      reading 54 bytes...
      -> "{\"succeeded\":true,\"id\":\"authrCYqrsXQ\",\"amount\":\"1.00\"}"
      read 54 bytes
      Conn close
    POST_SCRUBBED
  end

  def successful_purchase_response
    <<~RESPONSE
    {
      "succeeded":true,
      "id":"purchb1dawNaJ",
      "amount":"10.00"
    }
    RESPONSE
  end

  def failed_purchase_response
    <<~RESPONSE
    {
      "succeeded":false,
      "id":"autherr01E9gMqudx",
      "error":"01"
    }
    RESPONSE
  end

  def successful_authorize_response
    <<~RESPONSE
    {
      "succeeded":true,
      "id":"purchb1dawNaJ",
      "amount":"10.00"
    }
    RESPONSE
  end

  def failed_authorize_response
    <<~RESPONSE
    {
      "succeeded":false,
      "id":"autherr01E9gMqudx",
      "error":"03"
    }
    RESPONSE
  end

  def successful_capture_response
    <<~RESPONSE
    {
      "succeeded":true,
      "id":"capCm-rFz8N"
    }
    RESPONSE
  end

  def failed_capture_response
    <<~RESPONSE
    {
      "succeeded":false,
      "id":"autherr01E9gMqudx",
      "error":"10"
    }
    RESPONSE
  end

  def successful_refund_response
    <<~RESPONSE
    {
      "succeeded":true,
      "id":"cancelVTRMTwel"
    }
    RESPONSE
  end

  def failed_refund_response
    <<~RESPONSE
    {
      "succeeded":false,
      "id":"cancelM01E9gMqudx",
      "error":"02"
    }
    RESPONSE
  end

  def successful_void_response
    <<~RESPONSE
    {
      "succeeded":true,
      "id":"voidVTRMTwel"
    }
    RESPONSE
  end

  def failed_void_response
    <<~RESPONSE
    {
      "succeeded":false,
      "id":"voidM01E9gMqudx",
      "error":"02"
    }
    RESPONSE
  end
end