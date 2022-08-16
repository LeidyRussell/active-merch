module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AwesomesauceGateway < Gateway
      self.test_url = 'https://awesomesauce-staging.herokuapp.com/api'
      self.live_url = 'https://awesomesauce-staging.herokuapp.com/api'

      self.supported_countries = %w(US GB)
      self.default_currency = 'USD'
      self.supported_cardtypes = %i[visa master american_express]

      self.homepage_url = 'https://awesomesauce-prod.herokuapp.com'
      self.display_name = 'Awesomesauce Gateway'

      STANDARD_ERROR_CODE_MAPPING = {
        '01' => STANDARD_ERROR_CODE[:card_declined],
        '02' => STANDARD_ERROR_CODE[:invalid_number],
        '03' => STANDARD_ERROR_CODE[:expired_card],
        '10' => STANDARD_ERROR_CODE[:bad_transaction_reference]
      }

      def initialize(options = {})
        requires!(options, :merchant, :secret)
        super
      end

      def purchase(money, payment, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(money, payment, options) }
          r.process { capture(money, r.authorization, options) }
        end
      end

      def authorize(money, payment, options = {})
        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_address(post, options)

        commit('auth', post)
      end

      def capture(money, authorization, options = {})
        post = {}
        add_reference(post, authorization) || generate_unique_id

        commit('capture', post)
      end

      def refund(money, authorization, options = {})
        post = {}
        add_reference(post, authorization)

        commit('cancel', post)
      end

      def void(authorization, options = {})
        post = {}
        add_reference(post, authorization)

        commit('cancel', post)
      end

      def verify(credit_card, options = {})
        amountToTest = 100
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(amountToTest, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def supports_scrubbing?
        true
      end

      def scrub(transcript)
        %w(number cv2 secret).each do |field|
          transcript = transcript.gsub(%r((#{field}=)[^&]+), '\1[FILTERED]\2')
        end
        transcript
      end

      private

      def add_address(post, options)
        return unless options[:billing_address]
        post[:billing_address] = options[:billing_address]
      end

      def add_invoice(post, money, options)
        post[:amount] = amount(money)
        post[:currency] = (options[:currency] || default_currency)
      end

      def add_reference(post, authorization)
        post[:ref] = authorization
      end

      def add_payment(post, payment, options)
        post[:name] = "#{payment.first_name} #{payment.last_name}"
        post[:number] = payment.number
        post[:cv2] = payment.verification_value
        post[:exp] = "#{payment.year}#{payment.month.to_s.rjust(2, '0')}"
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters)
        url = build_url(action, (test? ? test_url : live_url))
        response = parse(ssl_post(url, post_data(action, parameters)))

        Response.new(
          success_from(response),
          message_from(response),
          response,
          authorization: authorization_from(response),
          avs_result: nil,
          cvv_result: nil,
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def build_url(action, base)
        base + action
      end

      def message_from(response)
        response[:id]
      end

      def success_from(response)
        response['succeeded'] == true
      end

      def authorization_from(response)
        response['id']
      end

      def post_data(action, parameters = {})
        parameters[:merchant] = @options[:merchant]
        parameters[:secret] = @options[:secret]
        parameters.collect { |k, v| "#{k}=#{v}" }.join('&')
      end

      def error_code_from(response)
        unless success_from(response)
          STANDARD_ERROR_CODE_MAPPING[response['error']]
        end
      end
    end
  end
end